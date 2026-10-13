# Mole Windows - installer uninstall tests
# %LOCALAPPDATA%\Mole is also the Mole for Windows app's data folder, so
# removing the CLI must never take that app's files with it.

BeforeAll {
    $script:WindowsDir = Split-Path -Parent $PSScriptRoot
    $installScript = Join-Path $script:WindowsDir "install.ps1"
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($installScript, [ref]$null, [ref]$null)
    foreach ($name in @("Get-NormalizedPath", "Test-ProtectedInstallRoot", "Get-MoleInstallEntries", "Get-MoleInstallNestedFiles", "Remove-MoleNestedFiles", "Test-MoleInstallDir", "Uninstall-Mole")) {
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
    function Remove-StartMenuShortcut { param($InstallDir) $true }

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

    It "Removes the docs screenshots Mole ships and the folders they leave empty" {
        $own = Join-Path $env:LOCALAPPDATA "Programs\mole-cli"
        New-CliTree -Root $own
        foreach ($file in Get-MoleInstallNestedFiles) {
            $path = Join-Path $own $file
            New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
            Set-Content -Path $path -Value "png"
        }
        $InstallDir = $own

        Uninstall-Mole | Should -BeTrue

        Test-Path $own | Should -BeFalse
    }

    It "Keeps a docs folder that holds the user's own files" {
        $shared = Join-Path $env:LOCALAPPDATA "Tools"
        New-CliTree -Root $shared
        New-Item -ItemType Directory -Path (Join-Path $shared "docs\img") -Force | Out-Null
        Set-Content -Path (Join-Path $shared "docs\img\mole-windows.png") -Value "png"
        Set-Content -Path (Join-Path $shared "docs\notes.md") -Value "mine"
        $InstallDir = $shared

        Uninstall-Mole | Should -BeTrue

        Test-Path (Join-Path $shared "docs\notes.md") | Should -BeTrue
        Test-Path (Join-Path $shared "docs\img") | Should -BeFalse
        Test-Path (Join-Path $shared "mole.ps1") | Should -BeFalse
    }

    It "Knows every top-level entry and docs file the repository ships" {
        $known = @(Get-MoleInstallEntries)
        $nested = @(Get-MoleInstallNestedFiles)
        $roots = @($nested | ForEach-Object { ($_ -split '\\')[0] } | Select-Object -Unique)
        foreach ($entry in @(Get-ChildItem -LiteralPath $script:WindowsDir -Force)) {
            ($known -contains $entry.Name -or $roots -contains $entry.Name) | Should -BeTrue -Because "$($entry.Name) must be removable by mo remove"
        }
        foreach ($root in $roots) {
            $base = Join-Path $script:WindowsDir $root
            foreach ($file in @(Get-ChildItem -LiteralPath $base -Recurse -File -Force)) {
                $relative = $file.FullName.Substring($script:WindowsDir.TrimEnd('\').Length + 1)
                $nested | Should -Contain $relative
            }
        }
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

Describe "Start menu shortcut removal" {
    BeforeAll {
        $installScript = Join-Path $script:WindowsDir "install.ps1"
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($installScript, [ref]$null, [ref]$null)
        $definition = $ast.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq "Remove-StartMenuShortcut"
            }, $true)
        $text = $definition.Extent.Text -replace '^function Remove-StartMenuShortcut', 'function Remove-ShortcutUnderTest'
        . ([scriptblock]::Create($text))
        Set-Item -Path "function:script:Remove-ShortcutUnderTest" -Value (Get-Item "function:Remove-ShortcutUnderTest").ScriptBlock

        function New-TestShortcut {
            param([string]$Path, [string]$Target, [string]$Arguments)
            $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($Path)
            $shortcut.TargetPath = $Target
            $shortcut.Arguments = $Arguments
            $shortcut.Save()
        }
    }

    It "Removes this install's shortcut and keeps the Mole for Windows app's" {
        $programs = Join-Path $TestDrive "Programs"
        New-Item -ItemType Directory -Path $programs -Force | Out-Null
        $install = Join-Path $TestDrive "mole-cli"
        New-TestShortcut -Path (Join-Path $programs "Mole.lnk") -Target (Join-Path $TestDrive "Tw93.Mole\Mole.exe") -Arguments ""
        New-TestShortcut -Path (Join-Path $programs "Mole CLI.lnk") -Target "powershell.exe" -Arguments "-NoExit -ExecutionPolicy Bypass -File `"$install\mole.ps1`""

        Remove-ShortcutUnderTest -InstallDir $install -ProgramsPath $programs | Should -BeTrue

        Test-Path (Join-Path $programs "Mole.lnk") | Should -BeTrue
        Test-Path (Join-Path $programs "Mole CLI.lnk") | Should -BeFalse
    }

    It "Removes a 1.30.0 Mole.lnk that starts this install" {
        $programs = Join-Path $TestDrive "Programs-legacy"
        New-Item -ItemType Directory -Path $programs -Force | Out-Null
        $install = Join-Path $TestDrive "legacy-install"
        New-TestShortcut -Path (Join-Path $programs "Mole.lnk") -Target "powershell.exe" -Arguments "-NoExit -ExecutionPolicy Bypass -File `"$install\mole.ps1`""

        Remove-ShortcutUnderTest -InstallDir $install -ProgramsPath $programs | Should -BeTrue

        Test-Path (Join-Path $programs "Mole.lnk") | Should -BeFalse
    }
}
