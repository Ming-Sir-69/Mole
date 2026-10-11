# Mole Windows - command router tests
# mole.ps1 turns --flags into parameters of bin\<command>.ps1. A flag the
# command does not declare must be refused, never passed on: a script without
# [CmdletBinding()] ignores unknown parameters, and `mo remove --help` used to
# uninstall Mole.

BeforeAll {
    $script:WindowsDir = Split-Path -Parent $PSScriptRoot
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:WindowsDir "mole.ps1"), [ref]$null, [ref]$null)
    foreach ($name in @("Resolve-CommandParameterName", "Invoke-MoleCommand")) {
        $definition = $ast.Find({
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
            }, $true)
        . ([scriptblock]::Create($definition.Extent.Text))
        Set-Item -Path "function:script:$name" -Value (Get-Item "function:$name").ScriptBlock
    }
    function Write-MoleError { param($Message) }

    $script:MOLE_BIN = Join-Path $TestDrive "bin"
    New-Item -ItemType Directory -Path $script:MOLE_BIN -Force | Out-Null
    # Shaped like bin\remove.ps1 before it gained [CmdletBinding()].
    Set-Content -Path (Join-Path $script:MOLE_BIN "fake.ps1") -Value @'
param(
    [Alias('h')]
    [switch]$ShowHelp,
    [Alias('dry-run')]
    [switch]$DryRun,
    [Alias('d')]
    [switch]$DebugMode
)
if ($ShowHelp) { "HELP" } elseif ($DryRun) { "DRYRUN" } elseif ($DebugMode) { "DEBUG" } else { "ACTED" }
'@
}

Describe "mole.ps1 command router" {
    BeforeEach {
        $script:MoleExitCode = 0
    }

    It "Maps <Flag> to the command's own parameter" -ForEach @(
        @{ Flag = "--help"; Expected = "HELP" },
        @{ Flag = "-h"; Expected = "HELP" },
        @{ Flag = "--dry-run"; Expected = "DRYRUN" },
        @{ Flag = "--debug"; Expected = "DEBUG" }
    ) {
        Invoke-MoleCommand -CommandName "fake" -Arguments @($Flag) | Should -Be $Expected
    }

    It "Refuses an unknown option without running the command" {
        $output = @(Invoke-MoleCommand -CommandName "fake" -Arguments @("--bogus"))
        $output | Should -Not -Contain "ACTED"
        $script:MoleExitCode | Should -Be 2
    }

    It "Shows help for every real command" -ForEach @(
        "clean", "uninstall", "optimize", "analyze", "status", "purge", "update", "remove"
    ) {
        $declared = (Get-Command -Name (Join-Path $script:WindowsDir "bin\$_.ps1") -CommandType ExternalScript).Parameters
        Resolve-CommandParameterName -Parameters $declared -Flag "help" | Should -Be "ShowHelp"
    }
}

Describe "mo --help and --version" {
    BeforeAll {
        $script:Mole = Join-Path $script:WindowsDir "mole.ps1"
    }

    It "Shows the logo with the Windows branch link and the macOS command layout" {
        $output = (& powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$($script:Mole)' '--help'" 2>&1 | Out-String)
        $output | Should -Match "https://github\.com/tw93/Mole/tree/windows"
        $output | Should -Match "COMMANDS"
        $output | Should -Match "mo uninstall --dry-run"
    }

    It "Reports the version, platform and install method" {
        $output = (& powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$($script:Mole)' '--version'" 2>&1 | Out-String)
        $output | Should -Match "Mole version \d+\.\d+\.\d+"
        $output | Should -Match "Architecture: "
        $output | Should -Match "Install: (Source|Portable|winget|Scoop)"
    }
}

Describe "mo remove" {
    BeforeAll {
        $script:Fake = Join-Path $TestDrive "fake-install"
        New-Item -ItemType Directory -Path (Join-Path $script:Fake "bin") -Force | Out-Null
        Copy-Item (Join-Path $script:WindowsDir "bin\remove.ps1") (Join-Path $script:Fake "bin\remove.ps1")
        # Stands in for the real installer: records that removal was requested.
        Set-Content -Path (Join-Path $script:Fake "install.ps1") -Value 'param([string]$InstallDir, [switch]$Uninstall) Set-Content -Path (Join-Path $InstallDir "uninstall-called.txt") -Value $InstallDir'
    }

    It "Removes nothing when the answer is not y" {
        $output = ("n" | & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:Fake "bin\remove.ps1") 2>&1 | Out-String)
        $output | Should -Match "Cancelled"
        Test-Path (Join-Path $script:Fake "uninstall-called.txt") | Should -BeFalse
    }

    It "Asks with the install path and removes on y" {
        $output = ("y" | & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $script:Fake "bin\remove.ps1") 2>&1 | Out-String)
        $output | Should -Not -Match "cannot be retrieved"
        Test-Path (Join-Path $script:Fake "uninstall-called.txt") | Should -BeTrue
    }
}
