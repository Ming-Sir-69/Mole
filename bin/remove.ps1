# Mole - Remove Command
# Removes Mole from the current installation directory.

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Alias('h')]
    [switch]$ShowHelp
)

$ErrorActionPreference = "Stop"

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$windowsDir = Split-Path -Parent $scriptDir
$installScript = Join-Path $windowsDir "install.ps1"

function Show-RemoveHelp {
    $esc = [char]27
    Write-Host ""
    Write-Host "$esc[1;35mmo remove$esc[0m - Remove Mole from this system"
    Write-Host ""
    Write-Host "$esc[33mUsage:$esc[0m mo remove"
    Write-Host ""
    Write-Host "$esc[33mBehavior:$esc[0m"
    Write-Host "  - Removes the current Mole installation directory"
    Write-Host "  - Removes PATH entries created for this install"
    Write-Host "  - Prompts before deleting Mole config files"
    Write-Host "  - Removes the Mole cache folder after a successful uninstall"
    Write-Host ""
}

if ($ShowHelp) {
    Show-RemoveHelp
    return
}

# winget and Scoop track their own files; removing them here leaves the
# package registered, so hand the user that manager's command instead.
function Get-PackageManagerRemoveCommand {
    param([string]$InstallDir)

    $path = $InstallDir.TrimEnd('\') + '\'
    if ($path -like "*\Microsoft\WinGet\Packages\tw93.MoleCLI_*") {
        return "winget uninstall tw93.MoleCLI"
    }
    if ($path -like "*\scoop\apps\mole\*") {
        return "scoop uninstall mole"
    }
    return $null
}

$removeCommand = Get-PackageManagerRemoveCommand -InstallDir $windowsDir
if ($removeCommand) {
    Write-Host "This copy of Mole is managed by a package manager." -ForegroundColor Yellow
    Write-Host "Remove it with: $removeCommand" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $installScript)) {
    Write-Host "Installer not found at: $installScript" -ForegroundColor Red
    exit 1
}

# The cache folder is Mole-owned and rebuildable, like the macOS CLI's
# ~/.cache/mole. Walk it without following links and delete each entry
# non-recursively, the same rule install.ps1 uses for the config folder: a
# junction or symbolic link loses only its link, never its target.
function Remove-MoleCacheEntry {
    param([System.IO.FileSystemInfo]$Item)

    if ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        if ($Item.Attributes -band [System.IO.FileAttributes]::Directory) {
            [System.IO.Directory]::Delete($Item.FullName, $false)
        }
        else {
            [System.IO.File]::Delete($Item.FullName)
        }
        return
    }
    if ($Item.Attributes -band [System.IO.FileAttributes]::Directory) {
        foreach ($child in @(Get-ChildItem -LiteralPath $Item.FullName -Force -ErrorAction Stop)) {
            Remove-MoleCacheEntry -Item $child
        }
        if ($Item.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
            $Item.Attributes = $Item.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
        }
        [System.IO.Directory]::Delete($Item.FullName, $false)
        return
    }
    Remove-Item -LiteralPath $Item.FullName -Force -ErrorAction Stop
}

# Removing Mole is not undoable, so it is never a side effect of a typo.
$answer = "$(Read-Host "Remove Mole from ${windowsDir}? (y/N)")".Trim()
if ($answer -ne "y" -and $answer -ne "Y") {
    Write-Host "Cancelled"
    exit 0
}

# Reset the automatic status so a caller's earlier native command cannot make a
# successful uninstall look failed.
$global:LASTEXITCODE = 0
& $installScript -InstallDir $windowsDir -Uninstall
$uninstallExit = $LASTEXITCODE

# The cache outlives the config folder and holds downloaded tool binaries and
# scan caches, never user-authored state. Keep it whenever the install itself
# was not removed.
if (($null -eq $uninstallExit -or $uninstallExit -eq 0) -and
    -not (Test-Path -LiteralPath (Join-Path $windowsDir "mole.ps1")) -and
    -not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
    $cachePath = Join-Path $env:USERPROFILE ".cache\mole"
    if (Test-Path -LiteralPath $cachePath) {
        try {
            $cacheRoot = Get-Item -LiteralPath $cachePath -Force -ErrorAction Stop
            if ($cacheRoot.PSIsContainer -and
                -not ($cacheRoot.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                Remove-MoleCacheEntry -Item $cacheRoot
                if (Get-Command Write-MoleOperation -ErrorAction SilentlyContinue) {
                    Write-MoleOperation -Action "REMOVED" -Path $cachePath -Detail "cache"
                }
                Write-Host "  Removed Mole cache: $cachePath" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "  Kept Mole cache: $cachePath ($($_.Exception.Message))" -ForegroundColor Yellow
        }
    }
}
