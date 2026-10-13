# Mole Windows - uninstall regression tests

BeforeAll {
    $script:WindowsDir = Split-Path -Parent $PSScriptRoot
    $libDir = Join-Path $script:WindowsDir "lib"
    . "$libDir\core\base.ps1"
    . "$libDir\core\log.ps1"
    . "$libDir\core\ui.ps1"
    . "$libDir\core\file_ops.ps1"

    # Load the script's settings and functions without running Main, so tests never
    # scan installed apps or run an uninstaller.
    $path = Join-Path $script:WindowsDir "bin\uninstall.ps1"
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw $parseErrors[0] }
    foreach ($statement in $ast.EndBlock.Statements) {
        if ($statement -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $statement.Left.Extent.Text -like '$script:*') {
            . ([scriptblock]::Create($statement.Extent.Text))
        }
    }
    $definitions = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $false)
    foreach ($definition in $definitions) {
        . ([scriptblock]::Create($definition.Extent.Text))
    }

    $script:CacheDir = Join-Path $TestDrive "cache"
    $script:AppCacheFile = Join-Path $script:CacheDir "apps.json"

    # A real, throwaway Uninstall-like key, so the "is it gone" check reads the registry.
    $script:RegistryRoot = "HKCU:\Software\MoleCliTests\$([guid]::NewGuid().ToString('N'))"

    function New-TestUninstallKey {
        param([string]$Name, [hashtable]$Values)
        $key = Join-Path $script:RegistryRoot $Name
        New-Item -Path $key -Force | Out-Null
        foreach ($entry in $Values.GetEnumerator()) {
            New-ItemProperty -Path $key -Name $entry.Key -Value $entry.Value -Force | Out-Null
        }
        # The scan stores the provider-qualified PSPath, so the tests use that form too.
        return (Get-Item -LiteralPath $key).PSPath
    }

    function New-TestFolder {
        param([string]$Name)
        $folder = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Set-Content -Path (Join-Path $folder "app.dll") -Value ("x" * 8192)
        return $folder
    }
}

AfterAll {
    Set-DryRunMode -Enabled $false
    if (Test-Path -LiteralPath $script:RegistryRoot) {
        Remove-Item -LiteralPath $script:RegistryRoot -Recurse
    }
    $parent = Split-Path -Parent $script:RegistryRoot
    if ((Test-Path -LiteralPath $parent) -and -not (Get-ChildItem -LiteralPath $parent)) {
        Remove-Item -LiteralPath $parent
    }
}

Describe "Uninstall selection under strict mode" {
    BeforeAll {
        $DryRun = $false
        $DebugMode = $false
        $ShowHelp = $false
        $Rescan = $false
        $script:Icons = @{ List = "-" }
        $script:MoleDryRunMode = $false
        $script:TestApps = @(
            [PSCustomObject]@{ Name = "First app"; SizeHuman = "1MB" }
            [PSCustomObject]@{ Name = "Second app"; SizeHuman = "2MB" }
        )

        function Get-InstalledApplications { param([switch]$ForceRescan) }
        function Show-AppSelectionMenu { param([array]$Apps) }
        function Uninstall-SelectedApps { param([array]$Apps) throw "Real uninstall must never run" }
        function Write-Info { param([string]$Message) }
        function Write-MoleWarning { param([string]$Message) }
    }

    BeforeEach {
        Mock Clear-Host {}
        Mock Write-Host {}
        Mock Write-Info {}
        Mock Write-MoleWarning {}
        Mock Get-InstalledApplications { $script:TestApps }
        Mock Show-AppSelectionMenu { $script:TestApps[0] }
        Mock Read-Host { "y" }
        Mock Uninstall-SelectedApps {}
    }

    It "Confirms and passes a single selected app to the uninstaller" {
        & { Set-StrictMode -Version Latest; Main }

        Should -Invoke Read-Host -Times 1 -Exactly
        Should -Invoke Uninstall-SelectedApps -Times 1 -Exactly -ParameterFilter {
            $Apps.Count -eq 1 -and $Apps[0].Name -eq "First app"
        }
    }

    It "Returns without confirmation when the selection is cancelled" {
        Mock Show-AppSelectionMenu { return @() }

        & { Set-StrictMode -Version Latest; Main }

        Should -Invoke Write-Info -Times 1 -Exactly -ParameterFilter { $Message -eq "No applications selected" }
        Should -Invoke Read-Host -Times 0 -Exactly
        Should -Invoke Uninstall-SelectedApps -Times 0 -Exactly
    }

    It "Preserves multiple selected apps" {
        Mock Show-AppSelectionMenu { $script:TestApps }

        & { Set-StrictMode -Version Latest; Main }

        Should -Invoke Uninstall-SelectedApps -Times 1 -Exactly -ParameterFilter {
            $Apps.Count -eq 2 -and $Apps[0].Name -eq "First app" -and $Apps[1].Name -eq "Second app"
        }
    }

    It "Does not uninstall when confirmation is declined" {
        Mock Read-Host { "n" }

        & { Set-StrictMode -Version Latest; Main }

        Should -Invoke Read-Host -Times 1 -Exactly
        Should -Invoke Uninstall-SelectedApps -Times 0 -Exactly
    }

    It "Handles a single discovered app" {
        Mock Get-InstalledApplications { $script:TestApps[0] }

        & { Set-StrictMode -Version Latest; Main }

        Should -Invoke Show-AppSelectionMenu -Times 1 -Exactly -ParameterFilter { $Apps.Count -eq 1 }
        Should -Invoke Uninstall-SelectedApps -Times 1 -Exactly
    }

    It "Returns without showing the menu when no apps are discovered" {
        Mock Get-InstalledApplications { return @() }

        & { Set-StrictMode -Version Latest; Main }

        Should -Invoke Write-MoleWarning -Times 1 -Exactly -ParameterFilter { $Message -eq "No applications found" }
        Should -Invoke Show-AppSelectionMenu -Times 0 -Exactly
        Should -Invoke Read-Host -Times 0 -Exactly
        Should -Invoke Uninstall-SelectedApps -Times 0 -Exactly
    }
}

Describe "Install folder eligibility" {
    It "Rejects <Label>" -TestCases @(
        @{ Label = "a drive root"; Path = "C:\" }
        @{ Label = "another drive root"; Path = "D:\" }
        @{ Label = "the Users folder"; Path = "C:\Users" }
        @{ Label = "the user profile"; Path = $env:USERPROFILE }
        @{ Label = "AppData"; Path = "$env:USERPROFILE\AppData" }
        @{ Label = "Local"; Path = $env:LOCALAPPDATA }
        @{ Label = "Roaming"; Path = $env:APPDATA }
        @{ Label = "LocalLow"; Path = "$env:USERPROFILE\AppData\LocalLow" }
        @{ Label = "Documents"; Path = "$env:USERPROFILE\Documents" }
        @{ Label = "Desktop"; Path = "$env:USERPROFILE\Desktop" }
        @{ Label = "Downloads"; Path = "$env:USERPROFILE\Downloads" }
        @{ Label = "Music"; Path = "$env:USERPROFILE\Music" }
        @{ Label = "Pictures"; Path = "$env:USERPROFILE\Pictures" }
        @{ Label = "ProgramData"; Path = $env:ProgramData }
        @{ Label = "Program Files"; Path = $env:ProgramFiles }
        @{ Label = "Program Files (x86)"; Path = ${env:ProgramFiles(x86)} }
        @{ Label = "Common Files"; Path = $env:CommonProgramFiles }
        @{ Label = "Windows"; Path = $env:windir }
        @{ Label = "a folder inside Windows"; Path = "$env:windir\System32" }
        @{ Label = "a quoted Program Files with a trailing slash"; Path = "`"$env:ProgramFiles\`"" }
        @{ Label = "a path with dot segments"; Path = "$env:ProgramFiles\Contoso\..\" }
        @{ Label = "an empty value"; Path = "" }
    ) {
        Test-MoleInstallFolder -Path $Path | Should -BeFalse
    }

    It "Rejects container and shared names on any drive: <Name>" -TestCases @(
        @{ Name = "Program Files" }
        @{ Name = "Program Files (x86)" }
        @{ Name = "Common Files" }
        @{ Name = "AppData" }
        @{ Name = "Downloads" }
        @{ Name = "Microsoft" }
        @{ Name = "Package Cache" }
    ) {
        $folder = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path $folder -Force | Out-Null

        Test-MoleInstallFolder -Path $folder | Should -BeFalse
    }

    It "Accepts an app's own folder, quoted or with a trailing slash" {
        $folder = New-TestFolder -Name "Contoso App"

        Test-MoleInstallFolder -Path $folder | Should -BeTrue
        Test-MoleInstallFolder -Path "`"$folder\`"" | Should -BeTrue
    }

    It "Rejects a folder that does not exist" {
        Test-MoleInstallFolder -Path (Join-Path $TestDrive "Missing App") | Should -BeFalse
    }
}

Describe "Uninstall entry removal check" {
    It "Treats a missing key as removed" {
        $root = New-TestUninstallKey -Name "parent" -Values @{}
        Test-UninstallEntryGone -KeyPath "$root\never-created" | Should -BeTrue
    }

    It "Treats a key that still names an app as installed" {
        $key = New-TestUninstallKey -Name "present" -Values @{ DisplayName = "Present"; UninstallString = "C:\x\uninstall.exe" }

        Test-UninstallEntryGone -KeyPath $key | Should -BeFalse
    }

    It "Treats a key emptied of its name and uninstall command as removed" {
        $key = New-TestUninstallKey -Name "emptied" -Values @{ EstimatedSize = 1024 }

        Test-UninstallEntryGone -KeyPath $key | Should -BeTrue
    }

    It "Treats an unknown key as still installed" {
        Test-UninstallEntryGone -KeyPath "" | Should -BeFalse
    }
}

Describe "Uninstalling registry apps" {
    BeforeAll {
        Set-DryRunMode -Enabled $false
        $script:Icons = Get-MoleDefaultIcons
    }

    BeforeEach {
        Set-DryRunMode -Enabled $false
        Mock Write-Host {}
        Mock Start-Process { [PSCustomObject]@{ ExitCode = 1 } }
        Mock Remove-SafeItem { $true }
        Mock Remove-AppxPackage { throw "Remove-AppxPackage must not run" }

        $script:AppFolder = New-TestFolder -Name "Contoso Tool"
        $script:Uninstaller = Join-Path $script:AppFolder "uninstall.exe"
        Set-Content -Path $script:Uninstaller -Value "not an installer we recognise"
        $script:PresentKey = New-TestUninstallKey -Name "contoso" -Values @{ DisplayName = "Contoso Tool"; UninstallString = $script:Uninstaller }
        $script:GoneKey = "$((Get-Item -LiteralPath $script:RegistryRoot).PSPath)\removed-by-uninstaller"
    }

    It "Runs an unrecognised uninstaller exactly once, as registered" {
        $app = [PSCustomObject]@{
            Name = "Contoso Tool"; Source = "Registry"; UninstallString = "`"$script:Uninstaller`""
            InstallLocation = $script:AppFolder; RegistryKey = $script:PresentKey; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Start-Process -Times 1 -Exactly
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $script:Uninstaller -and $null -eq $ArgumentList
        }
    }

    It "Keeps the install folder when the uninstall entry is still there" {
        $app = [PSCustomObject]@{
            Name = "Contoso Tool"; Source = "Registry"; UninstallString = "`"$script:Uninstaller`""
            InstallLocation = $script:AppFolder; RegistryKey = $script:PresentKey; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Remove-SafeItem -Times 0 -Exactly
        Should -Invoke Write-Host -ParameterFilter { "$Object" -like "*still installed, exit code 1*" }
    }

    It "Recycles the install folder once the uninstall entry is gone" {
        $app = [PSCustomObject]@{
            Name = "Contoso Tool"; Source = "Registry"; UninstallString = "`"$script:Uninstaller`""
            InstallLocation = $script:AppFolder; RegistryKey = $script:GoneKey; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Remove-SafeItem -Times 1 -Exactly -ParameterFilter { $Path -eq $script:AppFolder -and $Recycle }
    }

    It "Never removes a profile or system folder named as the install location" {
        $apps = @(
            [PSCustomObject]@{
                Name = "Profile App"; Source = "Registry"; UninstallString = "`"$script:Uninstaller`""
                InstallLocation = $env:USERPROFILE; RegistryKey = $script:GoneKey; PackageFullName = $null
            },
            [PSCustomObject]@{
                Name = "Program Files App"; Source = "Registry"; UninstallString = "`"$script:Uninstaller`""
                InstallLocation = $env:ProgramFiles; RegistryKey = $script:GoneKey; PackageFullName = $null
            }
        )

        Uninstall-SelectedApps -Apps $apps

        Should -Invoke Remove-SafeItem -Times 0 -Exactly
    }

    It "Removes MSI products with msiexec /passive" {
        $code = "{11111111-2222-3333-4444-555555555555}"
        $app = [PSCustomObject]@{
            Name = "Msi App"; Source = "Registry"; UninstallString = "MsiExec.exe /X$code"; KeyName = $code
            InstallLocation = $null; RegistryKey = $script:PresentKey; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -like "*\System32\msiexec.exe" -and
            ($ArgumentList -join " ") -eq "/x $code /passive REBOOT=ReallySuppress /norestart"
        }
    }

    It "Prefers the vendor's QuietUninstallString" {
        $app = [PSCustomObject]@{
            Name = "Quiet App"; Source = "Registry"; UninstallString = "`"$script:Uninstaller`""
            QuietUninstallString = "`"$script:Uninstaller`" --mode unattended"
            InstallLocation = $null; RegistryKey = $script:PresentKey; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $script:Uninstaller -and ($ArgumentList -join " ") -eq "--mode unattended"
        }
    }

    It "Adds the Inno Setup switches only to an Inno uninstaller" {
        $inno = Join-Path $script:AppFolder "unins000.exe"
        Set-Content -Path $inno -Value "inno"
        Set-Content -Path (Join-Path $script:AppFolder "unins000.dat") -Value "inno data"
        $app = [PSCustomObject]@{
            Name = "Inno App"; Source = "Registry"; UninstallString = "`"$inno`""
            InstallLocation = $null; RegistryKey = $script:PresentKey; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $inno -and ($ArgumentList -join " ") -eq "/SILENT /SUPPRESSMSGBOXES /NORESTART"
        }
    }

    It "Adds /S only to an uninstaller carrying the NSIS marker" {
        $nsis = Join-Path $script:AppFolder "uninst.exe"
        [System.IO.File]::WriteAllBytes($nsis, [System.Text.Encoding]::ASCII.GetBytes("MZ....Nullsoft.NSIS.exehead...."))
        $app = [PSCustomObject]@{
            Name = "Nsis App"; Source = "Registry"; UninstallString = "`"$nsis`""
            InstallLocation = $null; RegistryKey = $script:PresentKey; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq $nsis -and ($ArgumentList -join " ") -eq "/S"
        }
    }

    It "Starts nothing when the registered uninstaller does not exist" {
        $app = [PSCustomObject]@{
            Name = "Missing App"; Source = "Registry"; UninstallString = "`"$TestDrive\gone\uninstall.exe`""
            InstallLocation = $script:AppFolder; RegistryKey = $script:GoneKey; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Start-Process -Times 0 -Exactly
        Should -Invoke Remove-SafeItem -Times 0 -Exactly
    }
}

Describe "Uninstall dry run leftovers" {
    BeforeEach {
        Set-DryRunMode -Enabled $true
        $script:Icons = Get-MoleDefaultIcons
        Mock Write-Host {}
        Mock Start-Process { throw "Start-Process must not run in a dry run" }
        Mock Remove-SafeItem { $true }
    }

    AfterEach {
        Set-DryRunMode -Enabled $false
    }

    It "Previews no folder that would not be removed" {
        $app = [PSCustomObject]@{
            Name = "Profile App"; Source = "Registry"; UninstallString = "C:\nowhere\uninstall.exe"
            InstallLocation = $env:USERPROFILE; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Remove-SafeItem -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
    }

    It "Previews an app's own folder" {
        $folder = New-TestFolder -Name "Preview App"
        $app = [PSCustomObject]@{
            Name = "Preview App"; Source = "Registry"; UninstallString = "C:\nowhere\uninstall.exe"
            InstallLocation = $folder; PackageFullName = $null
        }

        Uninstall-SelectedApps -Apps @($app)

        Should -Invoke Remove-SafeItem -Times 1 -Exactly -ParameterFilter { $Path -eq $folder -and $Recycle }
    }
}

Describe "Scanning installed apps" {
    BeforeEach {
        Mock Write-Info {}
        Mock Write-Progress {}
        Mock Get-AppxPackage { @() }
        Mock Get-AppxPackageManifest { $null }
        $script:RegistryFixtures = @()
        Mock Get-ItemProperty {
            if ("$Path" -like "HKLM:\SOFTWARE\Microsoft\*") { $script:RegistryFixtures }
        } -ParameterFilter { "$Path" -like "HK*" }
        if (Test-Path -LiteralPath $script:AppCacheFile) { Remove-Item -LiteralPath $script:AppCacheFile }
    }

    It "Shows a RustDesk-like outlier size as measured, once, beside its duplicate key (#1717)" {
        $folder = New-TestFolder -Name "RustDesk"
        $code = "{3BF1D48C-7A7B-4E4F-9D1F-0123456789AB}"
        $base = "Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        $script:RegistryFixtures = @(
            [PSCustomObject]@{
                PSPath = "$base\$code"; PSChildName = $code; DisplayName = "RustDesk"; DisplayVersion = "1.2.3"
                Publisher = "Purslane"; UninstallString = "MsiExec.exe /X$code"; EstimatedSize = 70987979
                InstallLocation = $folder; WindowsInstaller = 1
            },
            [PSCustomObject]@{
                PSPath = "$base\RustDesk"; PSChildName = "RustDesk"; DisplayName = "RustDesk"; DisplayVersion = "1.2.3"
                Publisher = "Purslane"; UninstallString = "`"$folder\RustDesk.exe`" --uninstall"; InstallLocation = $folder
            }
        )
        $measuredKB = Get-PathSizeKB -Path $folder

        $apps = @(Get-InstalledApplications -ForceRescan)

        $rustDesk = @($apps | Where-Object { $_.Name -eq "RustDesk" })
        $rustDesk.Count | Should -Be 1
        $rustDesk[0].SizeKB | Should -Be $measuredKB
        $rustDesk[0].SizeKB | Should -BeLessThan 1024
    }

    It "Keeps a large size that the install folder cannot disprove" {
        $folder = New-TestFolder -Name "Big Game"
        $script:RegistryFixtures = @(
            [PSCustomObject]@{
                PSPath = "HKLM-test\big"; PSChildName = "big"; DisplayName = "Big Game"; UninstallString = "C:\x\u.exe"
                EstimatedSize = 20971520
            },
            [PSCustomObject]@{
                PSPath = "HKLM-test\small"; PSChildName = "small"; DisplayName = "Small Tool"; UninstallString = "C:\y\u.exe"
                EstimatedSize = 2048; InstallLocation = $folder
            }
        )

        $apps = @(Get-InstalledApplications -ForceRescan)

        @($apps | Where-Object { $_.Name -eq "Big Game" })[0].SizeKB | Should -Be 20971520
        @($apps | Where-Object { $_.Name -eq "Small Tool" })[0].SizeKB | Should -Be 2048
    }

    It "Keeps two copies with one name in different install folders" {
        $first = New-TestFolder -Name "Tool x86"
        $second = New-TestFolder -Name "Tool x64"
        $script:RegistryFixtures = @(
            [PSCustomObject]@{
                PSPath = "HKLM-test\tool32"; PSChildName = "tool32"; DisplayName = "Tool"; DisplayVersion = "1.0"
                Publisher = "Contoso"; UninstallString = "`"$first\uninstall.exe`""; InstallLocation = $first
            },
            [PSCustomObject]@{
                PSPath = "HKLM-test\tool64"; PSChildName = "tool64"; DisplayName = "Tool"; DisplayVersion = "1.0"
                Publisher = "Contoso"; UninstallString = "`"$second\uninstall.exe`""; InstallLocation = $second
            }
        )

        $apps = @(Get-InstalledApplications -ForceRescan)

        @($apps | Where-Object { $_.Name -eq "Tool" }).Count | Should -Be 2
    }

    It "Merges entries with one name, version and publisher" {
        $script:RegistryFixtures = @(
            [PSCustomObject]@{
                PSPath = "HKLM-test\a"; PSChildName = "a"; DisplayName = "Twin"; DisplayVersion = "2.0"
                Publisher = "Contoso"; UninstallString = "C:\a\uninstall.exe"
            },
            [PSCustomObject]@{
                PSPath = "HKLM-test\b"; PSChildName = "b"; DisplayName = "Twin"; DisplayVersion = "2.0"
                Publisher = "Contoso"; UninstallString = "C:\b\uninstall.exe"
            }
        )

        $apps = @(Get-InstalledApplications -ForceRescan)

        @($apps | Where-Object { $_.Name -eq "Twin" }).Count | Should -Be 1
    }

    It "Hides system components, updates and child entries" {
        $script:RegistryFixtures = @(
            [PSCustomObject]@{ PSPath = "HKLM-test\c"; PSChildName = "c"; DisplayName = "Hidden Component"; UninstallString = "x"; SystemComponent = 1 }
            [PSCustomObject]@{ PSPath = "HKLM-test\u"; PSChildName = "u"; DisplayName = "Security Update for Thing"; UninstallString = "x"; ReleaseType = "Security Update" }
            [PSCustomObject]@{ PSPath = "HKLM-test\h"; PSChildName = "h"; DisplayName = "Hotfix for Thing"; UninstallString = "x"; ReleaseType = "Hotfix" }
            [PSCustomObject]@{ PSPath = "HKLM-test\p"; PSChildName = "p"; DisplayName = "Child Package"; UninstallString = "x"; ParentKeyName = "Parent" }
            [PSCustomObject]@{ PSPath = "HKLM-test\v"; PSChildName = "v"; DisplayName = "Visible App"; UninstallString = "x" }
        )

        $apps = @(Get-InstalledApplications -ForceRescan)

        @($apps | ForEach-Object { $_.Name }) | Should -Be @("Visible App")
    }

    It "Reads the per-user 32-bit Uninstall key too" {
        Get-InstalledApplications -ForceRescan | Out-Null

        Should -Invoke Get-ItemProperty -Times 1 -Exactly -ParameterFilter {
            "$Path" -eq "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        }
    }

    It "Leaves out Store packages Windows depends on" {
        Mock Get-AppxPackage {
            $names = @(
                "Microsoft.WindowsStore", "Microsoft.StorePurchaseApp", "Microsoft.DesktopAppInstaller",
                "Microsoft.SecHealthUI", "Microsoft.GetHelp", "Microsoft.Windows.Photos", "Contoso.Notes"
            )
            foreach ($name in $names) {
                [PSCustomObject]@{
                    Name = $name; PackageFullName = "${name}_1.0.0.0_x64__abc"; Publisher = "CN=Test"; Version = "1.0.0.0"
                    IsFramework = $false; IsResourcePackage = $false; IsBundle = $false; SignatureKind = "Store"; InstallLocation = $null
                }
            }
            [PSCustomObject]@{
                Name = "Contoso.Resources"; PackageFullName = "Contoso.Resources_1.0.0.0_neutral_split.scale-100_abc"; Publisher = "CN=Test"
                Version = "1.0.0.0"; IsFramework = $false; IsResourcePackage = $true; IsBundle = $false; SignatureKind = "Store"; InstallLocation = $null
            }
            [PSCustomObject]@{
                Name = "Contoso.Bundle"; PackageFullName = "Contoso.Bundle_1.0.0.0_neutral_~_abc"; Publisher = "CN=Test"
                Version = "1.0.0.0"; IsFramework = $false; IsResourcePackage = $false; IsBundle = $true; SignatureKind = "Store"; InstallLocation = $null
            }
        }

        $apps = @(Get-InstalledApplications -ForceRescan)

        @($apps | ForEach-Object { $_.Name }) | Should -Be @("Contoso.Notes")
    }
}

Describe "Selecting apps that share a name" {
    BeforeEach {
        Mock Clear-Host {}
        Mock Write-Host {}
        $script:MenuKeys = @("Spacebar", "Enter")
        $script:MenuKeyIndex = 0
        Mock Read-MenuKey {
            $key = $script:MenuKeys[$script:MenuKeyIndex]
            $script:MenuKeyIndex++
            [PSCustomObject]@{ Key = $key }
        }
    }

    It "Toggles each entry by its registry key, not its name" {
        $apps = @(
            [PSCustomObject]@{ Name = "Same Name"; SizeKB = 1; SizeHuman = "1KB"; RegistryKey = "HKLM-test\first"; PackageFullName = $null }
            [PSCustomObject]@{ Name = "Same Name"; SizeKB = 2; SizeHuman = "2KB"; RegistryKey = "HKLM-test\second"; PackageFullName = $null }
        )

        $selected = @(Show-AppSelectionMenu -Apps $apps)

        $selected.Count | Should -Be 1
        $selected[0].RegistryKey | Should -Be "HKLM-test\first"
    }
}
