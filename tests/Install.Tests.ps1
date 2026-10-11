# Mole Windows - installer uninstall tests
# %LOCALAPPDATA%\Mole is also the Mole for Windows app's data folder, so
# removing the CLI must never take that app's files with it.

BeforeAll {
    $script:WindowsDir = Split-Path -Parent $PSScriptRoot
    $installScript = Join-Path $script:WindowsDir "install.ps1"
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($installScript, [ref]$null, [ref]$null)
    foreach ($name in @("Get-NormalizedPath", "Test-ProtectedInstallRoot", "Get-MoleInstallEntries", "Test-MoleInstallDir", "Uninstall-Mole")) {
        $definition = $ast.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
            }, $true)
        if (-not $definition) { throw "$name not found in install.ps1" }
        . ([scriptblock]::Create($definition.Extent.Text))
        Set-Item -Path "function:script:$name" -Value (Get-Item "function:$name").ScriptBlock
    }

    function Write-Info { param($Message) }
    function Write-Success { param($Message) }
    function Write-MoleWarning { param($Message) }
    function Write-MoleError { param($Message) }
    function Remove-FromUserPath { param($Directory) }
    function Remove-StartMenuShortcut { param($ShortcutName) }
    $script:ShortcutName = "Mole"

    function New-CliTree {
        param([string]$Root)
        New-Item -ItemType Directory -Path (Join-Path $Root "lib\core"), (Join-Path $Root "bin"), (Join-Path $Root ".git") -Force | Out-Null
        Set-Content -Path (Join-Path $Root "mole.ps1") -Value "#"
        Set-Content -Path (Join-Path $Root "lib\core\base.ps1") -Value "#"
        Set-Content -Path (Join-Path $Root "mo.cmd") -Value "@echo off"
        Set-Content -Path (Join-Path $Root "VERSION") -Value "1.30.0"
    }
}

Describe "install.ps1 -Uninstall" {
    BeforeEach {
        $script:SavedLocalAppData = $env:LOCALAPPDATA
        $env:LOCALAPPDATA = Join-Path $TestDrive ([guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $env:LOCALAPPDATA -Force | Out-Null
        $script:USERPROFILE_SAVED = $env:USERPROFILE
        $env:USERPROFILE = Join-Path $TestDrive "profile-without-config"
        $script:InstallDirGiven = $true
        $script:SourceDir = $null
    }

    AfterEach {
        $env:LOCALAPPDATA = $script:SavedLocalAppData
        $env:USERPROFILE = $script:USERPROFILE_SAVED
    }

    It "Keeps the Mole for Windows app's files when the CLI shares its folder" {
        $shared = Join-Path $env:LOCALAPPDATA "Mole"
        New-CliTree -Root $shared
        Set-Content -Path (Join-Path $shared "license.dat") -Value "license"
        New-Item -ItemType Directory -Path (Join-Path $shared "backups") -Force | Out-Null
        $InstallDir = $shared

        Uninstall-Mole | Should -BeTrue

        Test-Path (Join-Path $shared "license.dat") | Should -BeTrue
        Test-Path (Join-Path $shared "backups") | Should -BeTrue
        Test-Path (Join-Path $shared "mole.ps1") | Should -BeFalse
        Test-Path (Join-Path $shared "lib") | Should -BeFalse
        Test-Path (Join-Path $shared ".git") | Should -BeFalse
    }

    It "Removes a folder that holds only the CLI" {
        $own = Join-Path $env:LOCALAPPDATA "Programs\mole-cli"
        New-CliTree -Root $own
        $InstallDir = $own

        Uninstall-Mole | Should -BeTrue

        Test-Path $own | Should -BeFalse
    }

    It "Removes nothing from a folder that is not a Mole install" {
        $appData = Join-Path $env:LOCALAPPDATA "Mole"
        New-Item -ItemType Directory -Path $appData -Force | Out-Null
        Set-Content -Path (Join-Path $appData "license.dat") -Value "license"
        Set-Content -Path (Join-Path $appData "VERSION") -Value "app"
        $InstallDir = $appData

        Uninstall-Mole | Should -BeFalse

        Test-Path (Join-Path $appData "license.dat") | Should -BeTrue
        Test-Path (Join-Path $appData "VERSION") | Should -BeTrue
    }

    It "Never falls back to %LOCALAPPDATA%\Mole when the install folder is gone" {
        $appData = Join-Path $env:LOCALAPPDATA "Mole"
        New-Item -ItemType Directory -Path $appData -Force | Out-Null
        Set-Content -Path (Join-Path $appData "license.dat") -Value "license"
        $InstallDir = Join-Path $env:LOCALAPPDATA "Programs\mole-cli"

        Uninstall-Mole | Should -BeTrue

        Test-Path (Join-Path $appData "license.dat") | Should -BeTrue
    }
}
