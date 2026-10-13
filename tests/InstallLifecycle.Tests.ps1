# Installer refresh, literal launcher arguments, and package-manager routing.
BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RepoRoot 'install.ps1'), [ref]$null, [ref]$null)
    foreach ($definition in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
        . ([scriptblock]::Create($definition.Extent.Text))
        Set-Item -Path "function:script:$($definition.Name)" -Value (Get-Item "function:$($definition.Name)").ScriptBlock
    }
    . (Join-Path $script:RepoRoot 'lib\core\tui_binaries.ps1')
    $script:Colors = @{ Red=''; Green=''; Yellow=''; Blue=''; Cyan=''; Gray=''; NC='' }
}

Describe 'Source native tool refresh' {
    BeforeEach {
        $script:Root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $script:Root 'bin'), (Join-Path $script:Root '.git') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:Root 'bin\analyze.exe') -Value 'old'
        Set-Content -LiteralPath (Join-Path $script:Root 'bin\status.exe') -Value 'old'
        Mock Get-Command { [pscustomobject]@{ Name='go' } } -ParameterFilter { $Name -eq 'go' }
        Mock Build-TuiBinary { Set-Content -LiteralPath $DestinationPath -Value 'current source'; $true }
        Mock Restore-PrebuiltTuiBinary { throw 'A source refresh must not silently use the older tagged binary' }
    }
    It 'Refreshes both existing tools from the current source' {
        Ensure-OptionalTuiTools -RootDir $script:Root 6>$null
        (Get-Content -LiteralPath (Join-Path $script:Root 'bin\analyze.exe') -Raw).Trim() | Should -Be 'current source'
        (Get-Content -LiteralPath (Join-Path $script:Root 'bin\status.exe') -Raw).Trim() | Should -Be 'current source'
        Should -Invoke Build-TuiBinary -Times 2 -Exactly
    }
    It 'Uses a verified prebuilt refresh when the local source matches the release' {
        Mock Test-TuiSourceMatchesRelease { $true }
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'go' }
        Mock Restore-PrebuiltTuiBinary { Set-Content -LiteralPath $DestinationPath -Value 'verified release'; 'ok' }
        Ensure-OptionalTuiTools -RootDir $script:Root 6>$null
        (Get-Content -LiteralPath (Join-Path $script:Root 'bin\analyze.exe') -Raw).Trim() | Should -Be 'verified release'
        Should -Invoke Restore-PrebuiltTuiBinary -Times 2 -Exactly
        Should -Invoke Build-TuiBinary -Times 0
    }
    It 'Keeps old tools and fails when a current source build fails' {
        Mock Build-TuiBinary { $false }
        { Ensure-OptionalTuiTools -RootDir $script:Root 6>$null } | Should -Throw '*refresh*'
        (Get-Content -LiteralPath (Join-Path $script:Root 'bin\analyze.exe') -Raw).Trim() | Should -Be 'old'
    }
    It 'Does not claim a successful refresh when Go is unavailable' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'go' }
        { Ensure-OptionalTuiTools -RootDir $script:Root 6>$null } | Should -Throw '*Go*'
        (Get-Content -LiteralPath (Join-Path $script:Root 'bin\analyze.exe') -Raw).Trim() | Should -Be 'old'
    }
}

Describe 'Generated cmd launchers' {
    BeforeEach {
        $script:SourceDir = Join-Path $TestDrive "Bob's tools! & files"
        New-Item -ItemType Directory -Path $script:SourceDir -Force | Out-Null
        $script:VERSION = 'test'
        $script:InstallDir = $script:SourceDir
        $script:Force = $false
        $script:AddToPath = $false
        $script:CreateShortcut = $false
        Mock Ensure-OptionalTuiTools {}
        Mock Test-ProtectedInstallRoot { $false }
        @'
[Environment]::GetCommandLineArgs() | Out-Null
[System.IO.File]::WriteAllText($env:MOLE_TEST_CAPTURE, (ConvertTo-Json -InputObject @($args) -Compress))
exit 7
'@ | Set-Content -LiteralPath (Join-Path $script:SourceDir 'mole.ps1')
        Install-Mole 6>$null | Should -BeTrue
    }
    It 'Returns the script exit code when removal deletes its running batch file' {
        @'
Remove-Item -LiteralPath (Join-Path $PSScriptRoot 'mo.cmd') -Force
exit 7
'@ | Set-Content -LiteralPath (Join-Path $script:SourceDir 'mole.ps1')
        $start = New-Object System.Diagnostics.ProcessStartInfo
        $start.FileName = $env:ComSpec
        $start.UseShellExecute = $false
        $start.Arguments = '/d /s /c ""' + (Join-Path $script:SourceDir 'mo.cmd') + '" remove"'
        $process = [System.Diagnostics.Process]::Start($start)
        $process.WaitForExit()
        $process.ExitCode | Should -Be 7
        $process.Dispose()
        (Join-Path $script:SourceDir 'mo.cmd') | Should -Not -Exist
    }
    It 'Preserves apostrophes, exclamation marks, spaces, metacharacters and long flags' {
        $capture = Join-Path $TestDrive 'literal-args.json'
        $saved = $env:MOLE_TEST_CAPTURE
        $env:MOLE_TEST_CAPTURE = $capture
        try {
            $start = New-Object System.Diagnostics.ProcessStartInfo
            $start.FileName = $env:ComSpec
            $start.UseShellExecute = $false
            $start.Arguments = '/d /s /c ""' + (Join-Path $script:SourceDir 'mo.cmd') + '" analyze "D:\Bob''s files! & notes" --dry-run "percent%value""'
            $process = [System.Diagnostics.Process]::Start($start)
            $process.WaitForExit()
            $process.ExitCode | Should -Be 7
            $process.Dispose()
            $actual = Get-Content -LiteralPath $capture -Raw | ConvertFrom-Json
            $actual.Count | Should -Be 4
            $actual[0] | Should -Be 'analyze'
            $actual[1] | Should -Be "D:\Bob's files! & notes"
            $actual[2] | Should -Be '--dry-run'
            $actual[3] | Should -Be 'percent%value'
        }
        finally { $env:MOLE_TEST_CAPTURE = $saved }
    }
}

Describe 'Package manager update without Git' {
    It 'Prints the winget command before requiring Git' {
        $root = Join-Path $TestDrive 'Microsoft\WinGet\Packages\tw93.Mole_fixture'
        New-Item -ItemType Directory -Path (Join-Path $root 'bin') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:RepoRoot 'bin\update.ps1') -Destination (Join-Path $root 'bin\update.ps1')
        Set-Content -LiteralPath (Join-Path $root 'install.ps1') -Value '# fixture'
        $saved = $env:PATH
        try {
            $env:PATH = ''
            $output = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'bin\update.ps1') 2>&1
            ($output -join "`n") | Should -Match 'winget upgrade tw93.Mole'
            ($output -join "`n") | Should -Not -Match 'Git is not installed'
        }
        finally { $env:PATH = $saved }
    }
}

Describe 'Release source equivalence' {
    AfterEach {
        # Git marks loose objects read-only; Pester 5.7 cannot remove those files.
        # Restore attributes only in this test's own object store before teardown.
        if ($script:SourceFixture) {
            $objects = Join-Path $script:SourceFixture '.git\objects'
            if (Test-Path -LiteralPath $objects) {
                Get-ChildItem -LiteralPath $objects -Recurse -File -Force | ForEach-Object {
                    $_.Attributes = $_.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
                }
            }
        }
    }
    BeforeEach {
        $script:SourceFixture = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $script:SourceFixture 'cmd\analyze') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:SourceFixture 'cmd\analyze\main.go') -Value 'package main'
        Set-Content -LiteralPath (Join-Path $script:SourceFixture 'go.mod') -Value 'module fixture'
        Set-Content -LiteralPath (Join-Path $script:SourceFixture 'go.sum') -Value ''
        & git init --quiet $script:SourceFixture
        & git -C $script:SourceFixture add .
        # Build a fixture commit directly; do not invoke repository submission hooks.
        $tree = & git -C $script:SourceFixture write-tree
        $commit = & git -C $script:SourceFixture -c user.name=Fixture -c user.email=fixture@example.invalid commit-tree $tree -m fixture
        $LASTEXITCODE | Should -Be 0
        & git -C $script:SourceFixture update-ref HEAD $commit
        & git -C $script:SourceFixture update-ref refs/tags/V9.9.9-windows $commit
    }
    It 'Accepts the released source even when unrelated files differ' {
        Set-Content -LiteralPath (Join-Path $script:SourceFixture 'README.md') -Value 'local documentation'
        Test-TuiSourceMatchesRelease -WindowsDir $script:SourceFixture -Name analyze -Version '9.9.9' | Should -BeTrue
    }
    It 'Refuses an inherited Git index override instead of inspecting another index' {
        $saved = $env:GIT_INDEX_FILE
        try {
            $env:GIT_INDEX_FILE = Join-Path $script:SourceFixture '.git\index'
            Test-TuiSourceMatchesRelease -WindowsDir $script:SourceFixture -Name analyze -Version '9.9.9' | Should -BeFalse
        }
        finally { $env:GIT_INDEX_FILE = $saved }
    }
    It 'Refuses source modifications, untracked compilation units and missing tags' {
        Test-TuiSourceMatchesRelease -WindowsDir $script:SourceFixture -Name analyze -Version '9.9.8' | Should -BeFalse
        $extra = Join-Path $script:SourceFixture 'cmd\analyze\extra.go'
        Set-Content -LiteralPath $extra -Value 'package main'
        Test-TuiSourceMatchesRelease -WindowsDir $script:SourceFixture -Name analyze -Version '9.9.9' | Should -BeFalse
        Remove-Item -LiteralPath $extra
        Add-Content -LiteralPath (Join-Path $script:SourceFixture 'cmd\analyze\main.go') -Value '// changed'
        Test-TuiSourceMatchesRelease -WindowsDir $script:SourceFixture -Name analyze -Version '9.9.9' | Should -BeFalse
    }
}

Describe 'Native build replacement' {
    BeforeEach {
        $script:BuildRoot = Join-Path $TestDrive ('source with spaces ' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:BuildRoot -Force | Out-Null
        $script:BuildDestination = Join-Path $script:BuildRoot 'analyze.exe'
        Set-Content -LiteralPath $script:BuildDestination -Value 'old'
        Mock Start-Process {
            $ArgumentList[2] | Should -Match '^".*"$'
            Set-Content -LiteralPath $ArgumentList[2].Trim('"') -Value 'new'
            [pscustomobject]@{ ExitCode = 0 }
        }
    }
    It 'Replaces the binary only after a successful build with empty logs' {
        Build-TuiBinary -Name analyze -WindowsDir $script:BuildRoot -DestinationPath $script:BuildDestination -SourcePath './cmd/analyze/' 6>$null | Should -BeTrue
        (Get-Content -LiteralPath $script:BuildDestination -Raw).Trim() | Should -Be 'new'
        @(Get-ChildItem -LiteralPath $script:BuildRoot -Force).Count | Should -Be 1
    }
    It 'Preserves the existing binary after a failed build' {
        Mock Start-Process {
            Set-Content -LiteralPath $ArgumentList[2].Trim('"') -Value 'incomplete'
            [pscustomobject]@{ ExitCode = 1 }
        }
        Build-TuiBinary -Name analyze -WindowsDir $script:BuildRoot -DestinationPath $script:BuildDestination -SourcePath './cmd/analyze/' 6>$null | Should -BeFalse
        (Get-Content -LiteralPath $script:BuildDestination -Raw).Trim() | Should -Be 'old'
        @(Get-ChildItem -LiteralPath $script:BuildRoot -Force).Count | Should -Be 1
    }
}

Describe 'Native File launcher routing' {
    BeforeAll {
        $entryAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:RepoRoot 'mole.ps1'), [ref]$null, [ref]$null)
        $main = $entryAst.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Main' }, $true)
        . ([scriptblock]::Create(($main.Extent.Text -replace '^function Main', 'function Invoke-RootRouting')))
        function Initialize-Mole {}
        function Show-Version {}
        function Show-MainHelp {}
        function Show-MainMenu { return $null }
        function Invoke-MoleCommand { param($CommandName, $Arguments) }
    }
    BeforeEach {
        $script:Command = ''
        $script:CommandArgs = $null
        $script:ShowHelp = $false
        $script:Version = $false
        Mock Initialize-Mole {}
        Mock Show-Version {}
        Mock Show-MainHelp {}
        Mock Show-MainMenu { return $null }
        Mock Clear-Host {}
        Mock Invoke-MoleCommand {}
    }
    It 'Handles root long help passed through remaining arguments' {
        $script:CommandArgs = @('--help')
        Invoke-RootRouting
        Should -Invoke Show-MainHelp -Times 1 -Exactly
        Should -Invoke Show-MainMenu -Times 0
    }
    It 'Forwards a bound short help switch to the selected command' {
        $script:Command = 'analyze'
        $script:ShowHelp = $true
        Invoke-RootRouting
        Should -Invoke Invoke-MoleCommand -Times 1 -Exactly -ParameterFilter { $CommandName -eq 'analyze' -and $Arguments -contains '--help' }
        Should -Invoke Show-MainHelp -Times 0
    }
    It 'Keeps a command-local version flag in the child arguments' {
        $script:Command = 'status'
        $script:Version = $true
        Invoke-RootRouting
        Should -Invoke Invoke-MoleCommand -Times 1 -Exactly -ParameterFilter { $CommandName -eq 'status' -and $Arguments -contains '--version' }
        Should -Invoke Show-Version -Times 0
    }
    It 'Keeps root short help and version working' {
        $script:ShowHelp = $true
        Invoke-RootRouting
        Should -Invoke Show-MainHelp -Times 1 -Exactly
        $script:ShowHelp = $false
        $script:Version = $true
        Invoke-RootRouting
        Should -Invoke Show-Version -Times 1 -Exactly
    }
    It 'Keeps command dry-run flags in the child arguments' {
        $script:Command = 'clean'
        $script:CommandArgs = @('--dry-run')
        Invoke-RootRouting
        Should -Invoke Invoke-MoleCommand -Times 1 -Exactly -ParameterFilter { $CommandName -eq 'clean' -and $Arguments -contains '--dry-run' }
    }
}
