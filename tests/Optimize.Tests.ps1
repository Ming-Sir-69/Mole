# Mole Windows - optimize step tests
# Main is lifted out of bin/optimize.ps1 and run with every side effect mocked,
# so no real repair, reset or prompt runs on the test machine.

BeforeAll {
    $script:WindowsDir = Split-Path -Parent $PSScriptRoot
    $script:LibDir = Join-Path $script:WindowsDir "lib"
    $script:OptimizeScript = Join-Path $script:WindowsDir "bin\optimize.ps1"
    . "$script:LibDir\core\base.ps1"
    . "$script:LibDir\core\log.ps1"
    . "$script:LibDir\core\ui.ps1"
    . "$script:LibDir\core\file_ops.ps1"

    $script:OptimizeAst = [System.Management.Automation.Language.Parser]::ParseFile($script:OptimizeScript, [ref]$null, [ref]$null)
    $definitions = $script:OptimizeAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $false)
    $script:OptimizeFunctionNames = @()
    foreach ($definition in $definitions) {
        . ([scriptblock]::Create($definition.Extent.Text))
        Set-Item -Path "function:script:$($definition.Name)" -Value (Get-Item "function:$($definition.Name)").ScriptBlock
        $script:OptimizeFunctionNames += $definition.Name
    }

    # Storage and DnsClient cmdlets are CDXML, which Pester cannot mock on
    # Windows PowerShell 5.1; plain functions shadow them so they can be.
    function script:Get-PhysicalDisk { }
    function script:Get-Volume { param($DriveLetter) }
    function script:Optimize-Volume { param($DriveLetter) }
    function script:Clear-DnsClientCache { }
    function script:Repair-WindowsImage { param([switch]$Online, [switch]$CheckHealth, [switch]$RestoreHealth) }
}

Describe "mo optimize steps" {
    BeforeEach {
        $script:OptimizationsApplied = 0
        $script:IssuesFound = 0
        $script:IssuesFixed = 0
        $script:SavedLocalAppData = $env:LOCALAPPDATA
        $script:SavedProgramData = $env:ProgramData
        $env:LOCALAPPDATA = Join-Path $TestDrive "LocalAppData"
        $env:ProgramData = Join-Path $TestDrive "ProgramData"

        Mock Test-IsAdmin { $true }
        Mock Clear-Host { }
        Mock Read-Host { "n" }
        Mock Get-SystemHealth { @{ MemoryUsedGB = 1; MemoryTotalGB = 2; DiskUsedGB = 1; DiskTotalGB = 2; UptimeDays = 1 } }
        Mock Get-StartupPrograms { }
        Mock Test-WindowsUpdate { }
        Mock Get-PhysicalDisk { [pscustomobject]@{ FriendlyName = "Test SSD"; HealthStatus = "Healthy" } }
        Mock Get-Volume { [pscustomobject]@{ DriveLetter = "C" } }
        Mock Optimize-Volume { }
        Mock Clear-DnsClientCache { }
        Mock Repair-WindowsImage { [pscustomobject]@{ ImageHealthState = "Healthy" } }
        Mock netsh { $global:LASTEXITCODE = 0 }
        Mock Start-Sleep { }
        Mock Get-Service { throw "Get-Service must not run" }
        Mock Stop-Service { }
        Mock Start-Service { }
        Mock Start-Process { }
        Mock Stop-Process { }
        Mock Remove-Item { }
    }

    AfterEach {
        $env:LOCALAPPDATA = $script:SavedLocalAppData
        $env:ProgramData = $script:SavedProgramData
    }

    It "Never resets Winsock or rebuilds search, icon, font or Store caches when elevated" {
        $DryRun = $false
        $ShowHelp = $false
        $DebugMode = $false

        $output = Main 6>&1 | Out-String

        Should -Invoke netsh -ParameterFilter { $args -contains "winsock" } -Times 0 -Exactly
        Should -Invoke Get-Service -Times 0 -Exactly
        Should -Invoke Stop-Service -Times 0 -Exactly
        Should -Invoke Start-Service -Times 0 -Exactly
        Should -Invoke Start-Process -Times 0 -Exactly
        Should -Invoke Stop-Process -Times 0 -Exactly
        Should -Invoke Remove-Item -Times 0 -Exactly
        $output | Should -Not -Match "Winsock|Font Cache|Icon Cache|Search Index|Store Cache|wsreset"

        # The bounded steps that remain still run.
        Should -Invoke Clear-DnsClientCache -Times 1 -Exactly
        Should -Invoke Optimize-Volume -Times 1 -Exactly
        Should -Invoke netsh -ParameterFilter { $args -contains "arpcache" } -Times 1 -Exactly
        $output | Should -Match "Optimizations applied: \S*3"
    }

    It "Counts only the steps it lists in an elevated dry run" {
        $DryRun = $true
        $ShowHelp = $false
        $DebugMode = $false

        $output = Main 6>&1 | Out-String

        Should -Invoke netsh -Times 0 -Exactly
        Should -Invoke Clear-DnsClientCache -Times 0 -Exactly
        Should -Invoke Optimize-Volume -Times 0 -Exactly
        $output | Should -Match "Would optimize"
        $output | Should -Match "Would flush DNS cache"
        $output | Should -Match "Would clear ARP cache"
        $output | Should -Match "Would apply \S*3\S* optimizations"
        $output | Should -Not -Match "Winsock|TCP/IP|Font Cache|Icon Cache|Search Index|Store Cache|wsreset"
    }

    It "Uses the singular noun when a non-admin dry run has one step" {
        Mock Test-IsAdmin { $false }
        $DryRun = $true
        $ShowHelp = $false
        $DebugMode = $false

        $output = Main 6>&1 | Out-String

        $output | Should -Match "Would apply \S*1\S* optimization\b"
        $output | Should -Not -Match "Would apply \S*1\S* optimizations"
    }

    It "No longer defines the removed repair functions" {
        foreach ($name in @("Repair-FontCache", "Repair-IconCache", "Repair-SearchIndex", "Repair-StoreCache")) {
            $script:OptimizeFunctionNames | Should -Not -Contain $name
        }
    }
}

Describe "Native optimization outcomes" {
    BeforeEach {
        $script:OptimizationsApplied = 0
        $script:DryRun = $false
        Mock Test-IsAdmin { $true }
    }
    It "Does not count a failing native ARP operation as applied" {
        Mock netsh { $global:LASTEXITCODE = 5 }
        $output = Optimize-Network 6>&1 | Out-String
        $script:OptimizationsApplied | Should -Be 0
        $output | Should -Not -Match 'ARP cache cleared'
        $output | Should -Match 'ARP cache clear failed'
    }
    It "Counts a successful native ARP operation" {
        Mock netsh { $global:LASTEXITCODE = 0 }
        Optimize-Network 6>$null
        $script:OptimizationsApplied | Should -Be 1
    }
}

Describe "System image and file checks" {
    BeforeEach {
        $script:IssuesFound = 0
        $script:IssuesFixed = 0
        $script:DryRun = $false
        Mock Test-IsAdmin { $true }
    }

    It "Reads the image verdict as '<State>' and only suggests the repair" -ForEach @(
        @{ State = "Healthy"; Line = "System image is healthy"; Issues = 0 }
        @{ State = "Repairable"; Line = "System image can be repaired"; Issues = 1 }
        @{ State = "NonRepairable"; Line = "cannot be repaired by Windows"; Issues = 1 }
    ) {
        Mock Repair-WindowsImage { [pscustomobject]@{ ImageHealthState = $State } }

        $output = Test-SystemImage 6>&1 | Out-String

        $output | Should -Match $Line
        $script:IssuesFound | Should -Be $Issues
        Should -Invoke Repair-WindowsImage -ParameterFilter { $CheckHealth -and -not $RestoreHealth } -Times 1 -Exactly
        Should -Invoke Repair-WindowsImage -ParameterFilter { $RestoreHealth } -Times 0 -Exactly
        if ($State -eq "Repairable") { $output | Should -Match "(?s)RestoreHealth.*30 minutes" }
    }

    It "Says it could not check when DISM fails, without counting an issue" {
        Mock Repair-WindowsImage { throw "DISM unavailable" }
        $output = Test-SystemImage 6>&1 | Out-String
        $output | Should -Match "Could not check the system image"
        $script:IssuesFound | Should -Be 0
    }

    It "Does not call DISM without administrator rights or in a dry run" {
        Mock Repair-WindowsImage { [pscustomobject]@{ ImageHealthState = "Healthy" } }
        Mock Test-IsAdmin { $false }
        Test-SystemImage 6>$null
        Mock Test-IsAdmin { $true }
        $script:DryRun = $true
        Test-SystemImage 6>$null
        Should -Invoke Repair-WindowsImage -Times 0 -Exactly
    }

    It "Decodes sfc output, which is UTF-16 without a byte order mark" {
        $path = Join-Path $TestDrive "sfc.txt"
        $text = "Windows Resource Protection did not find any integrity violations."
        [System.IO.File]::WriteAllBytes($path, [System.Text.Encoding]::Unicode.GetBytes($text))
        Read-SfcOutput $path | Should -Be $text
        Read-SfcOutput (Join-Path $TestDrive "missing.txt") | Should -Be ""
    }

    It "Reports '<Expect>' for sfc output '<Text>'" -ForEach @(
        @{ Text = "Windows Resource Protection did not find any integrity violations."; Expect = "No integrity violations found" }
        @{ Text = "Windows Resource Protection found corrupt files and successfully repaired them."; Expect = "Corrupt files were repaired" }
        @{ Text = "Der Windows-Ressourcenschutz hat keine Integritaetsverletzungen gefunden."; Expect = "Scan finished; details are in" }
    ) {
        $savedTemp = $env:TEMP
        try {
            $env:TEMP = $TestDrive
            [System.IO.File]::WriteAllBytes((Join-Path $TestDrive "sfc_output.txt"), [System.Text.Encoding]::Unicode.GetBytes($Text))
            Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
            Mock Remove-Item { }
            $output = Test-SystemFiles 6>&1 | Out-String
            $output | Should -Match ([regex]::Escape($Expect))
            $output | Should -Not -Match "Scan completed"
        }
        finally { $env:TEMP = $savedTemp }
    }
}

Describe 'Review regressions: health summary' {
    It 'Does not turn an unknown DISM result into a healthy summary' -ForEach @('failure', 'unknown') {
        $script:IssuesFound = 0
        $script:IssuesFixed = 0
        $script:OptimizationsApplied = 0
        $script:DryRun = $false
        Mock Test-IsAdmin { $true }
        if ($_ -eq 'failure') { Mock Repair-WindowsImage { throw 'unavailable' } }
        else { Mock Repair-WindowsImage { [pscustomobject]@{ ImageHealthState = 'Unknown' } } }
        Mock Show-SummaryBlock { Write-Output ($Details -join "`n") }
        Test-SystemImage 6>$null
        $script:IssuesFound | Should -Be 0
        Show-OptimizeSummary | Should -Not -Match 'System health: Good'
    }
}
