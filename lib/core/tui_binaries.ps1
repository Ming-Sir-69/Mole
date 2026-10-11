# Mole - TUI binary helper
# Resolves, downloads, or builds analyze/status executables on Windows.

#Requires -Version 5.1
Set-StrictMode -Version Latest

if ((Get-Variable -Name 'MOLE_TUI_BINARIES_LOADED' -Scope Script -ErrorAction SilentlyContinue) -and $script:MOLE_TUI_BINARIES_LOADED) {
    return
}
$script:MOLE_TUI_BINARIES_LOADED = $true

$script:MOLE_TUI_CORE_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$script:MOLE_TUI_CORE_DIR\version.ps1"

$script:MoleGitHubRepo = "tw93/Mole"
$script:MoleGitHubApiRoot = "https://api.github.com/repos/$($script:MoleGitHubRepo)"
$script:MoleGitHubHeaders = @{
    "User-Agent" = "Mole-Windows"
    "Accept"     = "application/vnd.github+json"
}

function Get-MoleVersionFromScriptFile {
    param([string]$WindowsDir)

    return Get-MoleVersionString -RootDir $WindowsDir
}

function Get-TuiBinaryAssetName {
    param([string]$Name)

    return "$Name-windows-x64.exe"
}

function Resolve-TuiBinaryPath {
    param(
        [string]$WindowsDir,
        [string]$Name
    )

    $candidates = @(
        (Join-Path $WindowsDir "bin\$Name.exe"),
        (Join-Path $WindowsDir "$Name.exe")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-WindowsPrereleaseReleaseInfo {
    param([string]$Version)

    if (-not $Version) {
        return $null
    }

    $tagCandidates = @(
        "V$Version-windows",
        "v$Version-windows"
    )

    foreach ($tag in $tagCandidates) {
        $uri = "$($script:MoleGitHubApiRoot)/releases/tags/$tag"
        try {
            return Invoke-RestMethod -Uri $uri -Headers $script:MoleGitHubHeaders -Method Get
        }
        catch {
            continue
        }
    }

    return $null
}

# The SHA-256 the release's SHA256SUMS.txt publishes for one asset, or $null
# when the release has no checksum file or does not list that asset.
function Get-ReleaseAssetSha256 {
    param(
        $ReleaseInfo,
        [string]$AssetName
    )

    $sumsAsset = $ReleaseInfo.assets | Where-Object { $_.name -eq "SHA256SUMS.txt" } | Select-Object -First 1
    if (-not $sumsAsset) {
        return $null
    }

    $content = (Invoke-WebRequest -Uri $sumsAsset.browser_download_url -Headers $script:MoleGitHubHeaders -UseBasicParsing).Content
    if ($content -is [byte[]]) {
        $content = [System.Text.Encoding]::UTF8.GetString($content)
    }

    foreach ($line in ($content -split "`r?`n")) {
        $entry = $line.Trim([char]0xFEFF).Trim()
        if ($entry -match '^([0-9a-fA-F]{64})\s+\*?(.+)$' -and $Matches[2].Trim() -eq $AssetName) {
            return $Matches[1].ToLowerInvariant()
        }
    }

    return $null
}

# Returns "ok", "unavailable" (no release, asset or published checksum) or
# "mismatch" (the download did not match its published checksum and was deleted).
function Restore-PrebuiltTuiBinary {
    param(
        [string]$Name,
        [string]$WindowsDir,
        [string]$DestinationPath,
        [string]$Version
    )

    $releaseInfo = Get-WindowsPrereleaseReleaseInfo -Version $Version
    if (-not $releaseInfo) {
        return "unavailable"
    }

    $assetName = Get-TuiBinaryAssetName -Name $Name
    $asset = $releaseInfo.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    if (-not $asset) {
        return "unavailable"
    }

    # An executable is never used without a published checksum to compare.
    $expectedHash = Get-ReleaseAssetSha256 -ReleaseInfo $releaseInfo -AssetName $assetName
    if (-not $expectedHash) {
        return "unavailable"
    }

    $binDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }

    Write-Host "Downloading prebuilt $Name tool..." -ForegroundColor Cyan

    $downloadPath = "$DestinationPath.download"
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -Headers $script:MoleGitHubHeaders -OutFile $downloadPath -UseBasicParsing
        $actualHash = (Get-FileHash -Path $downloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
            return "mismatch"
        }
        Move-Item -Path $downloadPath -Destination $DestinationPath -Force
        return "ok"
    }
    catch {
        if (Test-Path $downloadPath) {
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
        }
        return "unavailable"
    }
}

function Build-TuiBinary {
    param(
        [string]$Name,
        [string]$WindowsDir,
        [string]$DestinationPath,
        [string]$SourcePath
    )

    $binDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }

    Write-Host "Building $Name tool..." -ForegroundColor Cyan

    $stdoutPath = Join-Path $env:TEMP "mole-$Name-build.stdout.log"
    $stderrPath = Join-Path $env:TEMP "mole-$Name-build.stderr.log"

    foreach ($path in @($stdoutPath, $stderrPath)) {
        if (Test-Path $path) {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        }
    }

    Push-Location $WindowsDir
    try {
        $process = Start-Process -FilePath "go" `
            -ArgumentList @("build", "-o", $DestinationPath, $SourcePath) `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath
    }
    catch {
        Write-Host "Failed to start go build for $Name tool: $_" -ForegroundColor Red
        return $false
    }
    finally {
        Pop-Location
    }

    $buildOutput = @()
    foreach ($path in @($stdoutPath, $stderrPath)) {
        if (Test-Path $path) {
            $content = (Get-Content $path -Raw).Trim()
            if ($content) {
                $buildOutput += $content
            }
            Remove-Item $path -Force -ErrorAction SilentlyContinue
        }
    }

    if ($process.ExitCode -ne 0) {
        $message = if ($buildOutput.Count -gt 0) { $buildOutput -join [Environment]::NewLine } else { "go build exited with code $($process.ExitCode)" }
        Write-Host "Failed to build $Name tool: $message" -ForegroundColor Red
        return $false
    }

    return $true
}

function Ensure-TuiBinary {
    param(
        [string]$Name,
        [string]$WindowsDir,
        [string]$DestinationPath,
        [string]$SourcePath,
        [string]$Version
    )

    $existingBin = Resolve-TuiBinaryPath -WindowsDir $WindowsDir -Name $Name
    if ($existingBin) {
        return $existingBin
    }

    if (-not $Version) {
        $Version = Get-MoleVersionFromScriptFile -WindowsDir $WindowsDir
    }

    $restoreResult = "unavailable"
    try {
        $restoreResult = Restore-PrebuiltTuiBinary -Name $Name -WindowsDir $WindowsDir -DestinationPath $DestinationPath -Version $Version
    }
    catch {
        Write-Host "Failed to restore prebuilt $Name tool: $_" -ForegroundColor Yellow
    }
    if ($restoreResult -eq "ok") {
        return $DestinationPath
    }
    # A checksum mismatch means the published file is not the one released;
    # stop here instead of quietly building something else.
    if ($restoreResult -eq "mismatch") {
        Write-Host "The downloaded $Name tool did not match its published checksum and was deleted. Run 'mo update' and try again, or report it at https://github.com/tw93/Mole/issues." -ForegroundColor Red
        return $null
    }

    if (Get-Command go -ErrorAction SilentlyContinue) {
        try {
            if (Build-TuiBinary -Name $Name -WindowsDir $WindowsDir -DestinationPath $DestinationPath -SourcePath $SourcePath) {
                return $DestinationPath
            }
        }
        catch {
            Write-Host "Failed to prepare $Name tool: $_" -ForegroundColor Yellow
        }
    }

    return $null
}
