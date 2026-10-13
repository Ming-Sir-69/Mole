# Real file mutations below are restricted to Pester's temporary TestDrive.
BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    . "$script:RepoRoot\lib\core\base.ps1"
    . "$script:RepoRoot\lib\core\log.ps1"
    . "$script:RepoRoot\lib\core\file_ops.ps1"
    . "$script:RepoRoot\lib\clean\dev.ps1"
    function Set-SectionActivity { }
}

Describe 'Cleanup physical boundaries' {
    BeforeEach {
        $script:Root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Root | Out-Null
        $script:SavedWhitelist = $script:Config.WhitelistFile
        $script:Config.WhitelistFile = Join-Path $script:Root 'whitelist.txt'
        Set-DryRunMode -Enabled $false
    }
    AfterEach {
        $script:Config.WhitelistFile = $script:SavedWhitelist
        Set-DryRunMode -Enabled $true
    }
    It 'Keeps the contents of a junction used as a cache root' {
        $target = Join-Path $script:Root 'target'
        New-Item -ItemType Directory -Path $target | Out-Null
        $sentinel = Join-Path $target 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'
        $link = Join-Path $script:Root 'cache'
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        Clear-DirectoryContents -Path $link
        Test-Path -LiteralPath $sentinel | Should -BeTrue
    }
    It 'Keeps a file reached through a junction ancestor' {
        $target = Join-Path $script:Root 'target'
        New-Item -ItemType Directory -Path $target | Out-Null
        $sentinel = Join-Path $target 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'
        $link = Join-Path $script:Root 'cache'
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        Remove-SafeItem -Path (Join-Path $link 'keep.txt') | Should -BeFalse
        Test-Path -LiteralPath $sentinel | Should -BeTrue
    }
    It 'Keeps an old file reached through a junction cleanup root' {
        $target = Join-Path $script:Root 'target'
        New-Item -ItemType Directory -Path $target | Out-Null
        $sentinel = Join-Path $target 'keep.txt'
        Set-Content -LiteralPath $sentinel -Value 'keep'
        (Get-Item -LiteralPath $sentinel).LastWriteTime = (Get-Date).AddDays(-30)
        $link = Join-Path $script:Root 'cache'
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
        Remove-OldFiles -Path $link
        Test-Path -LiteralPath $sentinel | Should -BeTrue
    }
    It 'Keeps a replacement directory installed during sizing' {
        $script:Cache = Join-Path $script:Root 'cache'
        New-Item -ItemType Directory -Path $script:Cache | Out-Null
        Set-Content -LiteralPath (Join-Path $script:Cache 'same.txt') -Value 'original'
        Mock Get-PathSize {
            Move-Item -LiteralPath $script:Cache -Destination (Join-Path $script:Root 'original')
            New-Item -ItemType Directory -Path $script:Cache | Out-Null
            Set-Content -LiteralPath (Join-Path $script:Cache 'same.txt') -Value 'replacement'
            return 8
        }
        Remove-SafeItem -Path $script:Cache -Recurse | Should -BeFalse
        Get-Content -LiteralPath (Join-Path $script:Cache 'same.txt') | Should -Be 'replacement'
    }
    It 'Still removes an ordinary cache directory' {
        $cache = Join-Path $script:Root 'cache'
        New-Item -ItemType Directory -Path $cache | Out-Null
        Set-Content -LiteralPath (Join-Path $cache 'data.bin') -Value 'cache'
        Remove-SafeItem -Path $cache -Recurse | Should -BeTrue
        Test-Path -LiteralPath $cache | Should -BeFalse
    }
    It 'Protects children of a literal directory whitelist without covering a prefix sibling' {
        $cache = Join-Path $script:Root 'cache'
        Set-Content -LiteralPath $script:Config.WhitelistFile -Value $cache
        Test-Whitelisted -Path (Join-Path $cache 'nested\data.bin') | Should -BeTrue
        Test-Whitelisted -Path (Join-Path $script:Root 'cache-other\data.bin') | Should -BeFalse
    }
}


Describe 'Literal bracket whitelist paths' {
    It 'Protects the exact bracket path and its children without matching siblings' {
        $root = Join-Path $TestDrive '[demo]\cache'
        Test-WhitelistPattern $root $root | Should -BeTrue
        Test-WhitelistPattern ($root + '\keep.txt') $root | Should -BeTrue
        Test-WhitelistPattern ($root + '-other\keep.txt') $root | Should -BeFalse
        Test-WhitelistPattern (Join-Path $TestDrive 'other\cache') (Join-Path $TestDrive '*\cache') | Should -BeTrue
    }
}

Describe 'Owner cache cleanup whitelist' {
    BeforeAll {
        function npm { }
        function pnpm { }
        function pip { }
        function go { }
        function mise { }
        function docker { }
        # Resolution is a read-only probe; the fallback lets the old implementation
        # run so each assertion observes its mutation instead of a missing command.
        if (-not (Get-Command Get-MoleOwnerCachePath -ErrorAction SilentlyContinue)) {
            function Get-MoleOwnerCachePath { param($Name,$Arguments) $null }
        }
    }
    BeforeEach {
        $script:OwnerRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:OwnerRoot | Out-Null
        $script:SavedOwnerWhitelist = $script:Config.WhitelistFile
        $script:SavedOwnerLocal = $env:LOCALAPPDATA
        $script:SavedOwnerProfile = $env:USERPROFILE
        $script:SavedOwnerApp = $env:APPDATA
        $script:SavedOwnerGo = $env:GOPATH
        $script:SavedOwnerMise = $env:MISE_CACHE_DIR
        $env:LOCALAPPDATA = $script:OwnerRoot
        $env:USERPROFILE = $script:OwnerRoot
        $env:APPDATA = $script:OwnerRoot
        $env:GOPATH = $script:OwnerRoot
        $script:Config.WhitelistFile = Join-Path $script:OwnerRoot 'whitelist.txt'
        $script:OwnerCache = Join-Path $script:OwnerRoot 'cache'
        New-Item -ItemType Directory -Path $script:OwnerCache | Out-Null
        $env:MISE_CACHE_DIR = $script:OwnerCache
        New-Item -ItemType Directory -Path (Join-Path $script:OwnerRoot 'pnpm\store') -Force | Out-Null
        Set-Content -LiteralPath $script:Config.WhitelistFile -Value $script:OwnerCache
        Mock Get-MoleOwnerCachePath { $script:OwnerCache }
        Mock Invoke-MoleOwnerProcess { [pscustomobject]@{ Output = '' } }
        Mock npm { $global:LASTEXITCODE=0 }
        Mock pnpm { $global:LASTEXITCODE=0 }
        Mock pip { $global:LASTEXITCODE=0 }
        Mock go { $global:LASTEXITCODE=0 }
        Mock mise { $global:LASTEXITCODE=0; $script:OwnerCache }
        Mock docker { $global:LASTEXITCODE=0 }
        Set-DryRunMode -Enabled $false
    }
    AfterEach {
        $script:Config.WhitelistFile = $script:SavedOwnerWhitelist
        $env:LOCALAPPDATA = $script:SavedOwnerLocal
        $env:USERPROFILE = $script:SavedOwnerProfile
        $env:APPDATA = $script:SavedOwnerApp
        $env:GOPATH = $script:SavedOwnerGo
        $env:MISE_CACHE_DIR = $script:SavedOwnerMise
        Set-DryRunMode -Enabled $true
    }
    It 'Does not invoke npm or pnpm mutations for a whitelisted resolved root' {
        Clear-NpmCache
        Should -Invoke Invoke-MoleOwnerProcess -Times 0
        Should -Invoke npm -Times 0 -ParameterFilter { $args -contains 'clean' }
        Should -Invoke pnpm -Times 0 -ParameterFilter { $args -contains 'prune' }
    }
    It 'Does not invoke pip purge for a whitelisted resolved root' {
        Clear-PythonCaches
        Should -Invoke Invoke-MoleOwnerProcess -Times 0
        Should -Invoke pip -Times 0 -ParameterFilter { $args -contains 'purge' }
    }
    It 'Does not invoke go clean for a whitelisted resolved root' {
        Clear-GoCaches
        Should -Invoke Invoke-MoleOwnerProcess -Times 0
        Should -Invoke go -Times 0 -ParameterFilter { $args -contains 'clean' }
    }
    It 'Does not invoke mise clear for a whitelisted resolved root' {
        Clear-MiseCache
        Should -Invoke Invoke-MoleOwnerProcess -Times 0
        Should -Invoke mise -Times 0 -ParameterFilter { $args -contains 'clear' }
    }
    It 'Runs an owner for a known unprotected ordinary cache' {
        Set-Content -LiteralPath $script:Config.WhitelistFile -Value '# no exclusions'
        Invoke-MoleOwnerCacheCleanup -Name 'npm' -Query @('config','get','cache') -Arguments @('cache','clean','--force') -Description 'fixture'
        Should -Invoke Invoke-MoleOwnerProcess -Times 1 -ParameterFilter { $TimeoutSeconds -eq 120 }
    }
    It 'Keeps a cache containing a specifically whitelisted child' {
        $child = Join-Path $script:OwnerCache 'keep.txt'
        Set-Content -LiteralPath $child -Value 'keep'
        Set-Content -LiteralPath $script:Config.WhitelistFile -Value $child
        Invoke-MoleOwnerCacheCleanup -Name 'npm' -Query @('config','get','cache') -Arguments @('cache','clean','--force') -Description 'fixture'
        Should -Invoke Invoke-MoleOwnerProcess -Times 0
    }
    It 'Keeps a cache when its owner cannot resolve the root' {
        Mock Get-MoleOwnerCachePath { $null }
        Clear-NpmCache
        Should -Invoke Invoke-MoleOwnerProcess -Times 0
    }
    It 'Preserves Gradle transaction locks' {
        $lock = Join-Path $env:USERPROFILE '.gradle\caches\build-cache-1\build-cache-1.lock'
        New-Item -ItemType Directory -Path (Split-Path -Parent $lock) -Force | Out-Null
        Set-Content -LiteralPath $lock -Value 'lock'
        Clear-JvmCaches
        Test-Path -LiteralPath $lock | Should -BeTrue
    }
    It 'Keeps Docker builders whose mutation cannot be mapped to whitelist paths' {
        Clear-DockerCaches
        Should -Invoke docker -Times 0
        Should -Invoke Invoke-MoleOwnerProcess -Times 0
    }
}

Describe 'Bounded owner process execution' {
    BeforeEach {
        $script:ProcessFixture = Join-Path $TestDrive ('owner tools ' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:ProcessFixture | Out-Null
        $script:OwnerCommand = Join-Path $script:ProcessFixture 'fixture.cmd'
    }
    It 'Captures an actual read-only owner response with a spaced executable path' {
        Set-Content -LiteralPath $script:OwnerCommand -Encoding ASCII -Value @('@echo off', 'echo fixture-cache-root', 'exit /b 0')
        $result = Invoke-MoleOwnerProcess -Name $script:OwnerCommand -Arguments @('query')
        $result.Output | Should -Be 'fixture-cache-root'
    }
    It 'Rejects an actual nonzero owner exit even when stdout looks like a path' {
        Set-Content -LiteralPath $script:OwnerCommand -Encoding ASCII -Value @('@echo off', 'echo C:\looks-like-a-cache', 'exit /b 9')
        Invoke-MoleOwnerProcess -Name $script:OwnerCommand -Arguments @('query') | Should -BeNullOrEmpty
    }
    It 'Bounds a slow owner and terminates its sleeping child' {
        $child = Join-Path $script:ProcessFixture 'sleep.ps1'
        Set-Content -LiteralPath $child -Encoding ASCII -Value @(
            'Set-Content -LiteralPath (Join-Path $PSScriptRoot "child.pid") -Value $PID',
            'Start-Sleep -Seconds 30'
        )
        Set-Content -LiteralPath $script:OwnerCommand -Encoding ASCII -Value @(
            '@echo off',
            '"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -File "%~dp0sleep.ps1"'
        )
        $timer = [Diagnostics.Stopwatch]::StartNew()
        Invoke-MoleOwnerProcess -Name $script:OwnerCommand -Arguments @('query') -TimeoutSeconds 3 | Should -BeNullOrEmpty
        $timer.Stop()
        $timer.Elapsed.TotalSeconds | Should -BeLessThan 12
        $pidFile = Join-Path $script:ProcessFixture 'child.pid'
        Test-Path -LiteralPath $pidFile | Should -BeTrue
        $childId = [int](Get-Content -LiteralPath $pidFile)
        Get-Process -Id $childId -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}
