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
    function Get-MoleDebugHeader { param($CommandLine) "header: $CommandLine" }
    function Start-MoleDebugSession { param($Header) $script:DebugSessionCalls += "start:$($Header -join '|')" }
    function Complete-MoleDebugSession { $script:DebugSessionCalls += "complete" }

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
        $script:DebugSessionCalls = @()
    }

    It "Maps <Flag> to the command's own parameter" -ForEach @(
        @{ Flag = "--help"; Expected = "HELP" },
        @{ Flag = "-h"; Expected = "HELP" },
        @{ Flag = "--dry-run"; Expected = "DRYRUN" },
        @{ Flag = "--debug"; Expected = "DEBUG" }
    ) {
        Invoke-MoleCommand -CommandName "fake" -Arguments @($Flag) | Should -Be $Expected
    }

    It "Opens one debug session around a --debug command and closes it" {
        Invoke-MoleCommand -CommandName "fake" -Arguments @("--debug") | Should -Be "DEBUG"
        $script:DebugSessionCalls | Should -Be @("start:header: fake --debug", "complete")
    }

    It "Leaves the debug session alone without --debug" {
        Invoke-MoleCommand -CommandName "fake" -Arguments @("--dry-run") | Should -Be "DRYRUN"
        Invoke-MoleCommand -CommandName "fake" -Arguments @() | Should -Be "ACTED"
        $script:DebugSessionCalls | Should -BeNullOrEmpty
    }

    It "Refuses an unknown option without running the command" {
        $output = @(Invoke-MoleCommand -CommandName "fake" -Arguments @("--bogus"))
        $output | Should -Not -Contain "ACTED"
        $script:MoleExitCode | Should -Be 2
    }

    It "Preserves a literal trailing apostrophe in positional and named paths" {
        Set-Content -LiteralPath (Join-Path $script:MOLE_BIN "path.ps1") -Value 'param([string]$Path) $Path'
        $literal = "C:\fixture\reports'"
        Invoke-MoleCommand -CommandName "path" -Arguments @($literal) | Should -BeExactly $literal
        Invoke-MoleCommand -CommandName "path" -Arguments @("--path=$literal") | Should -BeExactly $literal
    }

    It "Refuses an unknown command with a failure exit code" {
        Invoke-MoleCommand -CommandName "missing" -Arguments @()
        $script:MoleExitCode | Should -Be 2
    }

    It "Preserves native TUI exit codes and resets stale results for help" {
        Set-Content -LiteralPath (Join-Path $script:MOLE_BIN "status.ps1") -Value 'param([switch]$ShowHelp) if ($ShowHelp) { return }; & $env:ComSpec /d /c exit 7; exit $LASTEXITCODE'
        Invoke-MoleCommand -CommandName "status" -Arguments @()
        $script:MoleExitCode | Should -Be 7
        Invoke-MoleCommand -CommandName "status" -Arguments @("--help")
        $script:MoleExitCode | Should -Be 0
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

    It "Shows the logo with the Windows website and the macOS command layout" {
        $output = (& powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$($script:Mole)' '--help'" 2>&1 | Out-String)
        $output | Should -Match "https://mole\.fit/windows"
        $output | Should -Match "COMMANDS"
        $output | Should -Match "mo uninstall --dry-run"
    }

    It "Returns failure for an unknown command from the installed File entrypoint" {
        & powershell -NoProfile -ExecutionPolicy Bypass -File $script:Mole not-a-command 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 2
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

Describe "mo --version install line" {
    BeforeAll {
        $windowsDir = Split-Path -Parent $PSScriptRoot
        $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $windowsDir "mole.ps1"), [ref]$null, [ref]$null)
        foreach ($name in @("Get-MoleSourceCommit", "Get-MoleInstallDescription", "Get-MoleInstallMethod")) {
            $definition = $ast.Find({
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
                }, $true)
            . ([scriptblock]::Create($definition.Extent.Text))
            Set-Item -Path "function:script:$name" -Value (Get-Item "function:$name").ScriptBlock
        }
        $script:Sha = "0123456789abcdef0123456789abcdef01234567"
    }

    BeforeEach {
        $script:Root = Join-Path $TestDrive ([guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path (Join-Path $script:Root ".git\refs\heads") -Force | Out-Null
    }

    It "Names the commit of a checked-out release tag" {
        Set-Content -LiteralPath (Join-Path $script:Root ".git\HEAD") -Value $script:Sha
        Get-MoleInstallDescription -RootDir $script:Root | Should -BeExactly "Source (0123456)"
    }

    It "Follows a branch ref, loose or packed" {
        Set-Content -LiteralPath (Join-Path $script:Root ".git\HEAD") -Value "ref: refs/heads/windows"
        Set-Content -LiteralPath (Join-Path $script:Root ".git\packed-refs") -Value @("# pack-refs with: peeled", "$($script:Sha) refs/heads/windows")
        Get-MoleInstallDescription -RootDir $script:Root | Should -BeExactly "Source (0123456)"

        Set-Content -LiteralPath (Join-Path $script:Root ".git\refs\heads\windows") -Value ("f" * 40)
        Get-MoleInstallDescription -RootDir $script:Root | Should -BeExactly "Source (fffffff)"
    }

    It "Says Source without a commit when the metadata cannot be read" {
        Set-Content -LiteralPath (Join-Path $script:Root ".git\HEAD") -Value "ref: refs/heads/missing"
        Get-MoleInstallDescription -RootDir $script:Root | Should -BeExactly "Source"
    }

    It "Leaves a copy without Git metadata as Portable" {
        Remove-Item -LiteralPath (Join-Path $script:Root ".git") -Recurse -Force
        Get-MoleInstallDescription -RootDir $script:Root | Should -BeExactly "Portable"
    }
}

Describe "Debug through installed launcher call shapes" {
    It "Creates a debug session through <_>" -ForEach @("File", "Command") {
        $profile = Join-Path $TestDrive ("debug-" + $_)
        New-Item -ItemType Directory -Path $profile -Force | Out-Null
        $savedProfile = $env:USERPROFILE
        $savedDebug = $env:MOLE_DEBUG
        $mole = Join-Path (Split-Path -Parent $PSScriptRoot) "mole.ps1"
        try {
            $env:USERPROFILE = $profile
            $env:MOLE_DEBUG = $null
            if ($_ -eq "File") {
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $mole clean --help --debug 2>&1 | Out-String
            }
            else {
                $command = "& '" + $mole.Replace("'", "''") + "' 'clean' '--help' '--debug'; exit `$LASTEXITCODE"
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $command 2>&1 | Out-String
            }
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Debug logging enabled'
            $output | Should -Match 'Debug session log saved'
            $log = Join-Path $profile ".config\mole\mole_debug_session.log"
            Test-Path -LiteralPath $log | Should -BeTrue
            [System.IO.File]::ReadAllText($log) | Should -Match 'Command: mo clean .*--debug'
        }
        finally {
            $env:USERPROFILE = $savedProfile
            $env:MOLE_DEBUG = $savedDebug
        }
    }
}

Describe "Analyze debug routing" {
    It "Accepts the shared debug option and starts a session before Analyze help" {
        $profile = Join-Path $TestDrive "analyze-debug"
        New-Item -ItemType Directory -Path $profile -Force | Out-Null
        $previous = $env:USERPROFILE
        try {
            $env:USERPROFILE = $profile
            $mole = Join-Path $script:WindowsDir 'mole.ps1'
            $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $mole analyze --help --debug 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Interactive disk space analyzer'
            $log = Join-Path $profile '.config\mole\mole_debug_session.log'
            [System.IO.File]::ReadAllText($log) | Should -Match 'Command: mo analyze .*--debug'
        }
        finally { $env:USERPROFILE = $previous }
    }
}
