# Mole Windows - Cleanup Module Tests
# Pester tests for lib/clean functionality

BeforeAll {
    # Get the windows directory path (tests are in windows/tests/)
    $script:WindowsDir = Split-Path -Parent $PSScriptRoot
    $script:LibDir = Join-Path $script:WindowsDir "lib"
    
    # Import core modules first
    . "$script:LibDir\core\base.ps1"
    . "$script:LibDir\core\log.ps1"
    . "$script:LibDir\core\ui.ps1"
    . "$script:LibDir\core\file_ops.ps1"
    
    # Import cleanup modules
    . "$script:LibDir\clean\user.ps1"
    . "$script:LibDir\clean\caches.ps1"
    . "$script:LibDir\clean\dev.ps1"
    . "$script:LibDir\clean\apps.ps1"
    . "$script:LibDir\clean\system.ps1"
    
    # Enable dry-run mode for all tests
    $env:MOLE_DRY_RUN = "1"
    Set-DryRunMode -Enabled $true
}

AfterAll {
    $env:MOLE_DRY_RUN = $null
    Set-DryRunMode -Enabled $false
}

Describe "User Cleanup Module" {
    Context "Clear-UserTempFiles" {
        It "Should have Clear-UserTempFiles function" {
            Get-Command Clear-UserTempFiles -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should run without error in dry-run mode" {
            { Clear-UserTempFiles } | Should -Not -Throw
        }
    }
    
    Context "Clear-OldDownloads" {
        It "Should have Clear-OldDownloads function" {
            Get-Command Clear-OldDownloads -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Clear-RecycleBin" {
        It "Should have Clear-RecycleBin function" {
            Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-UserCleanup" {
        It "Should have main user cleanup function" {
            Get-Command Invoke-UserCleanup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Cache Cleanup Module" {
    Context "Browser Cache Functions" {
        It "Should have Clear-BrowserCaches function" {
            Get-Command Clear-BrowserCaches -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should run browser cache cleanup without error" {
            { Clear-BrowserCaches } | Should -Not -Throw
        }
    }
    
    Context "Application Cache Functions" {
        It "Should have Clear-AppCaches function" {
            Get-Command Clear-AppCaches -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Windows Update Cache" {
        It "Should have Clear-WindowsUpdateCache function" {
            Get-Command Clear-WindowsUpdateCache -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-CacheCleanup" {
        It "Should have main cache cleanup function" {
            Get-Command Invoke-CacheCleanup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Developer Tools Cleanup Module" {
    Context "Node.js Cleanup" {
        It "Should have npm cache cleanup function" {
            Get-Command Clear-NpmCache -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Python Cleanup" {
        It "Should have Python cache cleanup function" {
            Get-Command Clear-PythonCaches -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Go Cleanup" {
        It "Should have Go cache cleanup function" {
            Get-Command Clear-GoCaches -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context "mise Cleanup" {
        It "Should have mise cache cleanup function" {
            Get-Command Clear-MiseCache -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Rust Cleanup" {
        It "Should have Rust cache cleanup function" {
            Get-Command Clear-RustCaches -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Docker Cleanup" {
        It "Should have Docker cache cleanup function" {
            Get-Command Clear-DockerCaches -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-DevToolsCleanup" {
        It "Should have main dev tools cleanup function" {
            Get-Command Invoke-DevToolsCleanup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should run without error in dry-run mode" {
            { Invoke-DevToolsCleanup } | Should -Not -Throw
        }
    }
}

Describe "Apps Cleanup Module" {
    Context "Orphan Detection" {
        It "Should have Find-OrphanedAppData function" {
            Get-Command Find-OrphanedAppData -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Clear-OrphanedAppData function" {
            Get-Command Clear-OrphanedAppData -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Specific App Cleanup" {
        It "Should have Clear-OfficeCache function" {
            Get-Command Clear-OfficeCache -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Clear-AdobeData function" {
            Get-Command Clear-AdobeData -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Invoke-AppCleanup" {
        It "Should have main app cleanup function" {
            Get-Command Invoke-AppCleanup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "System Cleanup Module" {
    Context "System Temp" {
        It "Should have Clear-SystemTempFiles function" {
            Get-Command Clear-SystemTempFiles -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Windows Logs" {
        It "Should have Clear-WindowsLogs function" {
            Get-Command Clear-WindowsLogs -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Windows Update Cleanup" {
        It "Should have Clear-WindowsUpdateFiles function" {
            Get-Command Clear-WindowsUpdateFiles -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Memory Dumps" {
        It "Should have Clear-MemoryDumps function" {
            Get-Command Clear-MemoryDumps -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Admin Requirements" {
        It "Should check for admin when needed" {
            # System cleanup should handle non-admin gracefully
            { Clear-SystemTempFiles } | Should -Not -Throw
        }
    }
    
    Context "Invoke-SystemCleanup" {
        It "Should have main system cleanup function" {
            Get-Command Invoke-SystemCleanup -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Cleanup accounting" {
    BeforeEach {
        $script:SavedLocalAppData = $env:LOCALAPPDATA
        $script:SavedUserProfile = $env:USERPROFILE
        $script:SavedAppData = $env:APPDATA
        $script:Root = Join-Path $TestDrive ([guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $script:Root -Force | Out-Null
        Reset-CleanupStats
    }

    AfterEach {
        $env:LOCALAPPDATA = $script:SavedLocalAppData
        $env:USERPROFILE = $script:SavedUserProfile
        $env:APPDATA = $script:SavedAppData
    }

    It "Writes nothing to the pipeline from the bulk helpers" {
        $dir = Join-Path $script:Root "cache"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -Path (Join-Path $dir "a.tmp") -Value "x"
        $old = Join-Path $dir "b.tmp"
        Set-Content -Path $old -Value "x"
        (Get-Item $old).LastWriteTime = (Get-Date).AddDays(-30)

        @(Clear-DirectoryContents -Path $dir -Description "Test cache").Count | Should -Be 0
        @(Remove-SafeItems -Paths @($old) -Description "Test items").Count | Should -Be 0
        @(Remove-OldFiles -Path $dir -DaysOld 7 -Description "Test old").Count | Should -Be 0
        @(Remove-EmptyDirectories -Path $script:Root).Count | Should -Be 0
    }

    It "Counts what a dry run would remove" {
        $dir = Join-Path $script:Root "cache"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -Path (Join-Path $dir "a.tmp") -Value ("x" * 4096)
        Set-Content -Path (Join-Path $dir "b.tmp") -Value ("x" * 4096)

        Clear-DirectoryContents -Path $dir -Description "Test cache"

        $stats = Get-CleanupStats
        $stats.FilesCleaned | Should -Be 2
        $stats.TotalSizeKB | Should -BeGreaterThan 0
        Test-Path (Join-Path $dir "a.tmp") | Should -BeTrue
    }

    It "Lists every path a dry run would remove in the preview file" {
        $dir = Join-Path $script:Root "cache"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $file = Join-Path $dir "a.tmp"
        Set-Content -Path $file -Value "x"
        $script:ExportListFile = Join-Path $script:Root "clean-list.txt"
        try {
            Clear-DirectoryContents -Path $dir -Description "Test cache"
            $lines = Get-Content $script:ExportListFile
            $lines | Should -Contain "# Test cache"
            $lines | Should -Contain $file
        }
        finally {
            Remove-Variable -Name ExportListFile -Scope Script -ErrorAction SilentlyContinue
        }
    }

    It "Counts each crash dump and error report once" {
        $env:LOCALAPPDATA = Join-Path $script:Root "AppData\Local"
        $env:USERPROFILE = $script:Root
        $wer = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\WER\ReportArchive\AppCrash_1"
        $dumps = Join-Path $env:LOCALAPPDATA "CrashDumps"
        New-Item -ItemType Directory -Path $wer, $dumps -Force | Out-Null
        Set-Content -Path (Join-Path $wer "Report.wer") -Value "report"
        Set-Content -Path (Join-Path $dumps "app.dmp") -Value "dump"

        Clear-ErrorReports

        # One WER root entry (ReportArchive) plus one dump.
        (Get-CleanupStats).FilesCleaned | Should -Be 2
    }

    It "Never hands ~/.gitconfig.lock to a delete helper" {
        $env:USERPROFILE = $script:Root
        $env:APPDATA = Join-Path $script:Root "AppData\Roaming"
        $env:LOCALAPPDATA = Join-Path $script:Root "AppData\Local"
        Set-Content -Path (Join-Path $script:Root ".gitconfig.lock") -Value "lock"
        Mock Remove-SafeItem { $true }
        Mock Remove-SafeItems { }

        Clear-GitCaches

        Should -Invoke Remove-SafeItem -Times 0 -ParameterFilter { $Path -like "*.gitconfig.lock" }
        Should -Invoke Remove-SafeItems -Times 0 -ParameterFilter { @($Paths) -like "*.gitconfig.lock" }
    }
}
