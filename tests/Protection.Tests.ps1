# Mole Windows - user data clean must not touch

BeforeAll {
    $script:WindowsDir = Split-Path -Parent $PSScriptRoot
    $script:LibDir = Join-Path $script:WindowsDir "lib"

    . "$script:LibDir\core\base.ps1"
    . "$script:LibDir\core\log.ps1"
    . "$script:LibDir\core\ui.ps1"
    . "$script:LibDir\core\file_ops.ps1"

    . "$script:LibDir\clean\user.ps1"
    . "$script:LibDir\clean\caches.ps1"
    . "$script:LibDir\clean\dev.ps1"
    . "$script:LibDir\clean\apps.ps1"
    . "$script:LibDir\clean\system.ps1"

    $env:MOLE_DRY_RUN = "1"
    Set-DryRunMode -Enabled $true
}

AfterAll {
    $env:MOLE_DRY_RUN = $null
    Set-DryRunMode -Enabled $false
}

Describe "Clean leaves user data alone" {
    BeforeAll {
        $script:Saved = @{
            USERPROFILE  = $env:USERPROFILE
            APPDATA      = $env:APPDATA
            LOCALAPPDATA = $env:LOCALAPPDATA
            TEMP         = $env:TEMP
            TMP          = $env:TMP
        }

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString("N"))
        $env:USERPROFILE = Join-Path $root "Users\tester"
        $env:APPDATA = Join-Path $env:USERPROFILE "AppData\Roaming"
        $env:LOCALAPPDATA = Join-Path $env:USERPROFILE "AppData\Local"
        $env:TEMP = Join-Path $env:LOCALAPPDATA "Temp"
        $env:TMP = $env:TEMP
        $old = (Get-Date).AddDays(-200)

        function New-OldFile {
            param([string]$Path)
            New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
            Set-Content -Path $Path -Value ("x" * 2048)
            (Get-Item -LiteralPath $Path).LastWriteTime = $old
        }

        $dropbox = Join-Path $root "Dropbox"
        # Folders clean used to empty or prune that hold user data.
        $script:UserData = @(
            "$env:APPDATA\Zoom\data"
            "$env:APPDATA\Microsoft\Teams\IndexedDB"
            "$env:APPDATA\Microsoft\Teams\Local Storage"
            "$env:APPDATA\Microsoft\Teams\databases"
            "$env:APPDATA\Microsoft\Windows\Recent"
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache"
            "$env:LOCALAPPDATA\Microsoft\Office\15.0\OfficeFileCache"
            "$env:LOCALAPPDATA\Microsoft\Outlook\RoamCache"
            "$env:LOCALAPPDATA\Microsoft\OneDrive\logs"
            "$dropbox\.dropbox.cache"
            "$env:USERPROFILE\.aws"
            "$env:USERPROFILE\.azure"
            "$env:USERPROFILE\.kube"
            "$env:APPDATA\jupyter\runtime"
            "$env:USERPROFILE\.hex\packages"
            "$env:USERPROFILE\.cabal\packages"
            "$env:USERPROFILE\.stack\programs"
        )
        $files = @(
            "$env:APPDATA\Zoom\data\zoomus.enc.db"
            "$env:APPDATA\Microsoft\Teams\IndexedDB\https_teams.microsoft.com_0.indexeddb.leveldb\000003.log"
            "$env:APPDATA\Microsoft\Teams\Local Storage\leveldb\000003.log"
            "$env:APPDATA\Microsoft\Teams\databases\Databases.db"
            "$env:APPDATA\Microsoft\Windows\Recent\report.docx.lnk"
            "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\5f7b5f1e01b83767.automaticDestinations-ms"
            "$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache\FSD-1.FSD"
            "$env:LOCALAPPDATA\Microsoft\Office\15.0\OfficeFileCache\FSD-1.FSD"
            "$env:LOCALAPPDATA\Microsoft\Outlook\RoamCache\Stream_Autocomplete_0.dat"
            "$env:LOCALAPPDATA\Microsoft\OneDrive\logs\Personal\general.keystore"
            "$env:LOCALAPPDATA\Microsoft\OneDrive\logs\SyncDiagnostics.log"
            "$dropbox\.dropbox.cache\unsynced.bin"
            "$env:USERPROFILE\.aws\cli\cache\assumed-role.json"
            "$env:USERPROFILE\.azure\logs\az.log"
            "$env:USERPROFILE\.kube\cache\discovery\x.json"
            "$env:APPDATA\jupyter\runtime\kernel-1.json"
            "$env:USERPROFILE\.hex\packages\hexpm\phoenix\mix.exs"
            "$env:USERPROFILE\.cabal\packages\hackage.haskell.org\aeson\aeson.tar.gz"
            "$env:USERPROFILE\.stack\programs\x86_64-windows\ghc-9.4.7\bin\ghc.exe"
            "$env:USERPROFILE\memory.dmp"
            "$env:USERPROFILE\install.log"
            # Kept rows, the positive control that the run below lists what it would clean.
            "$env:APPDATA\Microsoft\Teams\Cache\data_0"
            "$env:APPDATA\Microsoft\Teams\GPUCache\data_1"
            "$env:LOCALAPPDATA\CrashDumps\app.exe.1234.dmp"
            "$env:APPDATA\gcloud\logs\gcloud.log"
        )
        foreach ($file in $files) {
            New-OldFile -Path $file
        }
        # The Hex and Stack rows pruned top-level folders by their own age.
        Get-ChildItem -Path "$env:USERPROFILE\.hex\packages" -Directory | ForEach-Object { $_.LastWriteTime = $old }
        Get-ChildItem -Path "$env:USERPROFILE\.stack\programs" -Directory | ForEach-Object { $_.LastWriteTime = $old }
        New-Item -ItemType Directory -Path "$env:LOCALAPPDATA\Dropbox" -Force | Out-Null
        @{ personal = @{ path = $dropbox } } | ConvertTo-Json | Set-Content -Path "$env:LOCALAPPDATA\Dropbox\info.json"

        $script:ExportListFile = Join-Path $root "clean-list.txt"
        Reset-CleanupStats

        & {
            Invoke-UserCleanup -TempDaysOld 7 -LogDaysOld 7
            Clear-AppCaches
            Invoke-AppCleanup
            Clear-PythonCaches
            Clear-CloudCliCaches
            Clear-ElixirCaches
            Clear-HaskellCaches
        } 6>$null

        $script:Listed = @()
        if (Test-Path $script:ExportListFile) {
            $script:Listed = @(Get-Content -Path $script:ExportListFile | Where-Object { $_ -and -not $_.StartsWith("#") })
        }
        $script:Stats = Get-CleanupStats
    }

    AfterAll {
        foreach ($name in $script:Saved.Keys) {
            Set-Item -Path "env:$name" -Value $script:Saved[$name]
        }
        Remove-Variable -Name ExportListFile -Scope Script -ErrorAction SilentlyContinue
    }

    It "Lists the cache rows it keeps" {
        $script:Listed | Should -Contain "$env:APPDATA\Microsoft\Teams\Cache\data_0"
        $script:Listed | Should -Contain "$env:APPDATA\Microsoft\Teams\GPUCache\data_1"
        $script:Listed | Should -Contain "$env:LOCALAPPDATA\CrashDumps\app.exe.1234.dmp"
        $script:Listed | Should -Contain "$env:APPDATA\gcloud\logs\gcloud.log"
    }

    It "Never offers <_>" -ForEach @(
        "Zoom\data", "Teams\IndexedDB", "Teams\Local Storage", "Teams\databases", "Windows\Recent",
        "Office\16.0\OfficeFileCache", "Office\15.0\OfficeFileCache", "Outlook\RoamCache", "OneDrive\logs",
        ".dropbox.cache", ".aws", ".azure", ".kube", "jupyter\runtime", ".hex\packages", ".cabal\packages",
        ".stack\programs"
    ) {
        $leaf = $_
        $dir = @($script:UserData | Where-Object { $_.EndsWith("\$leaf") })[0]
        $dir | Should -Not -BeNullOrEmpty
        @($script:Listed | Where-Object { $_ -eq $dir -or $_.StartsWith("$dir\") }) | Should -BeNullOrEmpty
    }

    It "Never offers dumps or logs at the profile root" {
        $script:Listed | Should -Not -Contain "$env:USERPROFILE\memory.dmp"
        $script:Listed | Should -Not -Contain "$env:USERPROFILE\install.log"
    }

    It "Counts exactly the paths it lists" {
        $script:Stats.FilesCleaned | Should -Be $script:Listed.Count
    }
}
