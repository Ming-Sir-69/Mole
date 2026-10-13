# Mole - Safe File Operations Module
# Provides safe file deletion and manipulation functions with protection checks

#Requires -Version 5.1
Set-StrictMode -Version Latest

# Prevent multiple sourcing
if ((Get-Variable -Name 'MOLE_FILEOPS_LOADED' -Scope Script -ErrorAction SilentlyContinue) -and $script:MOLE_FILEOPS_LOADED) { return }
$script:MOLE_FILEOPS_LOADED = $true

# Import dependencies
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\base.ps1"
. "$scriptDir\log.ps1"

# ============================================================================
# Global State
# ============================================================================

$script:MoleDryRunMode = $env:MOLE_DRY_RUN -eq "1"
$script:TotalSizeCleaned = 0
$script:FilesCleaned = 0
$script:TotalItems = 0

# ============================================================================
# Safety Validation Functions
# ============================================================================

# Bind each existing path component to its Windows volume/file identity. Path
# spelling alone cannot distinguish a directory replaced after preview/sizing.
function Get-MolePathSnapshot {
    param([string]$Path, [switch]$AllowLeafLink)

    try {
        if (-not ('Mole.SafePathIdentity' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
namespace Mole {
    public sealed class SafePathIdentity {
        [StructLayout(LayoutKind.Sequential)]
        private struct Info {
            public uint Attributes, CreationLow, CreationHigh, AccessLow, AccessHigh;
            public uint WriteLow, WriteHigh, Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
        }
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        private static extern SafeFileHandle CreateFile(string path, uint access, uint share,
            IntPtr security, uint disposition, uint flags, IntPtr template);
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out Info info);
        public string Identity;
        public bool Link;
        public static SafePathIdentity Read(string path) {
            using (SafeFileHandle handle = CreateFile(path, 0x80, 7, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero)) {
                if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
                Info info;
                if (!GetFileInformationByHandle(handle, out info)) throw new Win32Exception(Marshal.GetLastWin32Error());
                return new SafePathIdentity { Identity = info.Volume + ":" + info.IndexHigh + ":" + info.IndexLow,
                    Link = (info.Attributes & 0x400) != 0 };
            }
        }
    }
}
'@ -ErrorAction Stop
        }
        $fullPath = [IO.Path]::GetFullPath($Path)
        # Device/provider paths and network roots are not automatic cleanup roots.
        if ($fullPath -notmatch '^[A-Za-z]:\\') { return $null }
        $entries = @{}
        $current = $fullPath.TrimEnd('\')
        if ($current -match '^[A-Za-z]:$') { $current += '\' }
        $leaf = $true
        while ($current) {
            $info = [Mole.SafePathIdentity]::Read($current)
            if ($info.Link -and (-not $leaf -or -not $AllowLeafLink)) { return $null }
            $entries[$current] = $info.Identity
            $parent = [IO.Path]::GetDirectoryName($current)
            if ($parent -eq $current) { break }
            $current = $parent
            $leaf = $false
        }
        return @{ Path = $fullPath; Entries = $entries; AllowLeafLink = [bool]$AllowLeafLink }
    }
    catch {
        Write-Debug "Could not bind cleanup path: $Path - $_"
        return $null
    }
}

function Test-MolePathSnapshot {
    param($Snapshot)

    if ($null -eq $Snapshot) { return $false }
    $now = Get-MolePathSnapshot -Path $Snapshot.Path -AllowLeafLink:$Snapshot.AllowLeafLink
    if ($null -eq $now -or $now.Entries.Count -ne $Snapshot.Entries.Count) { return $false }
    foreach ($path in $Snapshot.Entries.Keys) {
        if ($now.Entries[$path] -ne $Snapshot.Entries[$path]) { return $false }
    }
    return $true
}

function Test-SafePath {
    <#
    .SYNOPSIS
        Validate that a path is safe to operate on
    .DESCRIPTION
        Checks against protected paths and whitelist
    .OUTPUTS
        $true if safe, $false if protected
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    # Must have a path
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Debug "Empty path rejected"
        return $false
    }
    
    # Resolve to full path
    $fullPath = Resolve-SafePath -Path $Path
    if (-not $fullPath) {
        Write-Debug "Could not resolve path: $Path"
        return $false
    }
    
    # Check protected paths
    if (Test-ProtectedPath -Path $fullPath) {
        Write-Debug "Protected path rejected: $fullPath"
        return $false
    }
    
    # Check whitelist
    if (Test-Whitelisted -Path $fullPath) {
        Write-Debug "Whitelisted path rejected: $fullPath"
        return $false
    }
    
    return $true
}

# A junction or symbolic link points at someone else's files. Mole lists and
# removes the link itself but never walks into it: in Windows PowerShell 5.1,
# Remove-Item on a junction with children stops at an "Are you sure?" prompt,
# and answering Yes deletes the files the link points to.
function Test-IsReparsePoint {
    param([string]$Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    return ($null -ne $item) -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

# Everything under $Path, depth first, without entering junctions or
# directory symbolic links (the link itself is listed).
function Get-TreeItemsNoFollow {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$SkipUnreadable
    )

    $errorAction = if ($SkipUnreadable) { "SilentlyContinue" } else { "Stop" }
    $walkTimer = [Diagnostics.Stopwatch]::StartNew()
    $pending = New-Object System.Collections.Generic.Stack[string]
    $rootSnapshot = Get-MolePathSnapshot -Path $Path
    if (-not $rootSnapshot) { throw "Unverified directory: $Path" }
    $pending.Push($Path)
    $snapshots = @{ $Path = $rootSnapshot }
    while ($pending.Count -gt 0) {
        if ($walkTimer.Elapsed.TotalSeconds -ge 15) { throw 'Cleanup walk timed out' }
        $directory = $pending.Pop()
        if (-not (Test-MolePathSnapshot $snapshots[$directory])) { throw "Directory changed: $directory" }
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction $errorAction)) {
            if ($walkTimer.Elapsed.TotalSeconds -ge 15) { throw 'Cleanup walk timed out' }
            $snapshot = Get-MolePathSnapshot -Path $item.FullName -AllowLeafLink
            if (-not $snapshot) { throw "Unverified child: $($item.FullName)" }
            $item | Add-Member -NotePropertyName MolePathSnapshot -NotePropertyValue $snapshot -Force
            $item
            if ($item.PSIsContainer -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
                $snapshots[$item.FullName] = $snapshot
                $pending.Push($item.FullName)
            }
        }
    }
}

# Deletes one entry; a linked directory loses only its link.
function Remove-TreeEntry {
    param([string]$Path)

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.PSIsContainer -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        [System.IO.Directory]::Delete($item.FullName, $false)
    }
    else {
        Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
    }
}

function Get-PathSize {
    <#
    .SYNOPSIS
        Get the size of a file or directory in bytes
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    
    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }
    
    try {
        if (Test-Path -LiteralPath $Path -PathType Container) {
            # A linked directory's files are not Mole's to count.
            if (Test-IsReparsePoint -Path $Path) {
                return 0
            }
            $size = (Get-TreeItemsNoFollow -Path $Path -SkipUnreadable |
                     Where-Object { -not $_.PSIsContainer } |
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            if ($null -eq $size) { return 0 }
            return [long]$size
        }
        else {
            return (Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue).Length
        }
    }
    catch {
        return 0
    }
}

function Get-PathSizeKB {
    <#
    .SYNOPSIS
        Get the size of a file or directory in kilobytes
    #>
    param([string]$Path)
    
    $bytes = Get-PathSize -Path $Path
    return [Math]::Ceiling($bytes / 1024)
}

# ============================================================================
# Safe Removal Functions
# ============================================================================

function Get-SafeDirectoryTreeItems {
    <#
    .SYNOPSIS
        Enumerate and validate every child before recursive directory removal.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $rootSnapshot = Get-MolePathSnapshot -Path $Path -AllowLeafLink
    if (-not $rootSnapshot) { return @{ Success = $false; Items = @() } }
    # A linked directory is removed as a link; nothing under it is listed.
    if (Test-IsReparsePoint -Path $Path) {
        return @{
            Success = $true
            Items   = @()
            RootSnapshot = $rootSnapshot
        }
    }

    try {
        $items = @(Get-TreeItemsNoFollow -Path $Path)
    }
    catch {
        Write-Debug "Could not enumerate directory before removal: $Path - $_"
        return @{
            Success = $false
            Items   = @()
        }
    }

    foreach ($item in $items) {
        if (-not (Test-SafePath -Path $item.FullName)) {
            Write-Debug "Protected/whitelisted child rejected before recursive removal: $($item.FullName)"
            return @{
                Success = $false
                Items   = @()
            }
        }
    }

    return @{
        Success = $true
        Items   = $items
        RootSnapshot = $rootSnapshot
    }
}

function Remove-SafeDirectoryTree {
    <#
    .SYNOPSIS
        Remove a directory only after all descendants pass safety checks.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [hashtable]$ValidatedTree = $null
    )

    $tree = if ($null -ne $ValidatedTree) {
        $ValidatedTree
    }
    else {
        Get-SafeDirectoryTreeItems -Path $Path
    }

    if (-not $tree.Success -or -not (Test-SafePath $Path) -or
        -not (Test-MolePathSnapshot $tree.RootSnapshot)) {
        return $false
    }

    $orderedItems = @()
    if ($null -ne $tree.Items) {
        $orderedItems = @($tree.Items | Sort-Object { $_.FullName.Length } -Descending)
    }

    foreach ($item in $orderedItems) {
        try {
            if (-not (Test-SafePath $item.FullName) -or
                -not (Test-MolePathSnapshot $item.MolePathSnapshot)) { return $false }
            Remove-TreeEntry -Path $item.FullName
            Write-Debug "Removed child item: $($item.FullName)"
        }
        catch {
            Write-Debug "Failed to remove child item: $($item.FullName) - $_"
            return $false
        }
    }

    try {
        if (-not (Test-SafePath $Path) -or -not (Test-MolePathSnapshot $tree.RootSnapshot)) { return $false }
        Remove-TreeEntry -Path $Path
        Write-Debug "Removed directory root: $Path"
        return $true
    }
    catch {
        Write-Debug "Failed to remove directory root: $Path - $_"
        return $false
    }
}

function Remove-SafeItem {
    <#
    .SYNOPSIS
        Safely remove a file or directory with all protection checks
    .DESCRIPTION
        This is the main safe deletion function. It:
        - Validates the path is not protected
        - Checks against whitelist
        - Supports dry-run mode
        - Tracks cleanup statistics
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Description = "",
        
        [switch]$Force,
        
        [switch]$Recurse,

        [scriptblock]$Guard = $null
    )
    
    # Validate path safety
    if (-not (Test-SafePath -Path $Path)) {
        Write-Debug "Skipping protected/whitelisted path: $Path"
        return $false
    }
    
    # Check if path exists
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Debug "Path does not exist: $Path"
        return $false
    }

    $pathSnapshot = Get-MolePathSnapshot -Path $Path -AllowLeafLink
    if (-not $pathSnapshot) { return $false }
    $isDirectory = Test-Path -LiteralPath $Path -PathType Container
    $validatedTree = $null
    if ($isDirectory) {
        $validatedTree = Get-SafeDirectoryTreeItems -Path $Path
        if (-not $validatedTree.Success) {
            return $false
        }
    }

    # Get size before removal
    $size = Get-PathSize -Path $Path
    $sizeKB = [Math]::Ceiling($size / 1024)
    $sizeHuman = Format-ByteSize -Bytes $size
    
    if (-not (Test-SafePath $Path) -or -not (Test-MolePathSnapshot $pathSnapshot)) { return $false }

    if ($null -ne $Guard) {
        try { $allowed = & $Guard $Path } catch { return $false }
        if ($allowed -isnot [bool] -or -not $allowed) { return $false }
    }
    if (-not (Test-MolePathSnapshot $pathSnapshot)) { return $false }

    # Handle dry run
    if ($script:MoleDryRunMode) {
        $script:TotalSizeCleaned += $sizeKB
        $script:FilesCleaned++
        $script:TotalItems++
        $name = if ($Description) { $Description } else { Split-Path -Leaf $Path }
        Write-DryRun "$name $($script:Colors.Yellow)($sizeHuman dry)$($script:Colors.NC)"
        Add-DryRunListEntries -Description $name -Paths @($Path)
        Set-SectionActivity
        return $true
    }
    
    # Perform removal
    try {
        if ($isDirectory) {
            if (-not (Remove-SafeDirectoryTree -Path $Path -ValidatedTree $validatedTree)) {
                return $false
            }
        }
        else {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        }
        
        # Update statistics
        $script:TotalSizeCleaned += $sizeKB
        $script:FilesCleaned++
        $script:TotalItems++
        
        # Log success
        $name = if ($Description) { $Description } else { Split-Path -Leaf $Path }
        Write-Success "$name $($script:Colors.Green)($sizeHuman)$($script:Colors.NC)"
        Set-SectionActivity
        
        return $true
    }
    catch {
        Write-Debug "Failed to remove $Path : $_"
        return $false
    }
}

function Remove-SafeItems {
    <#
    .SYNOPSIS
        Safely remove multiple items with a collective description
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths,
        
        [string]$Description = "Items"
    )
    
    $totalSize = 0
    $removedCount = 0
    $failedCount = 0
    $dryRunPaths = New-Object System.Collections.Generic.List[string]
    
    foreach ($path in $Paths) {
        if (-not (Test-SafePath -Path $path)) {
            continue
        }
        
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $pathSnapshot = Get-MolePathSnapshot -Path $path -AllowLeafLink
        if (-not $pathSnapshot) { continue }
        $isDirectory = Test-Path -LiteralPath $path -PathType Container
        $validatedTree = $null
        if ($isDirectory) {
            $validatedTree = Get-SafeDirectoryTreeItems -Path $path
            if (-not $validatedTree.Success) {
                $failedCount++
                continue
            }
        }
        
        $size = Get-PathSize -Path $path
        if (-not (Test-SafePath $path) -or -not (Test-MolePathSnapshot $pathSnapshot)) { continue }

        if ($script:MoleDryRunMode) {
            $totalSize += $size
            $removedCount++
            $dryRunPaths.Add($path)
            continue
        }
        
        try {
            if ($isDirectory) {
                if (-not (Remove-SafeDirectoryTree -Path $path -ValidatedTree $validatedTree)) {
                    $failedCount++
                    continue
                }
            }
            else {
                Remove-Item -LiteralPath $path -Force -ErrorAction Stop
            }
            $totalSize += $size
            $removedCount++
        }
        catch {
            $failedCount++
            Write-Debug "Failed to remove: $path - $_"
        }
    }
    
    if ($removedCount -gt 0) {
        $sizeKB = [Math]::Ceiling($totalSize / 1024)
        $sizeHuman = Format-ByteSize -Bytes $totalSize
        
        # A dry run counts what it would remove, so its summary can report it.
        $script:TotalSizeCleaned += $sizeKB
        $script:FilesCleaned += $removedCount
        $script:TotalItems++
        if ($script:MoleDryRunMode) {
            Write-DryRun "$Description $($script:Colors.Yellow)($removedCount items, $sizeHuman dry)$($script:Colors.NC)"
            Add-DryRunListEntries -Description $Description -Paths $dryRunPaths.ToArray()
        }
        else {
            Write-Success "$Description $($script:Colors.Green)($removedCount items, $sizeHuman)$($script:Colors.NC)"
        }
        Set-SectionActivity
    }
}

# Appends a dry run's paths to the preview list clean.ps1 announces. Commands
# that set no list (purge, uninstall) write nothing.
function Add-DryRunListEntries {
    param(
        [string]$Description,
        [string[]]$Paths
    )

    if (-not (Test-Path variable:script:ExportListFile) -or -not $script:ExportListFile) {
        return
    }
    if (-not $Paths -or $Paths.Count -eq 0) {
        return
    }
    $lines = @("# $Description") + $Paths + @("")
    Add-Content -Path $script:ExportListFile -Value $lines -ErrorAction SilentlyContinue
}

# ============================================================================
# Pattern-Based Cleanup Functions
# ============================================================================

function Remove-OldFiles {
    <#
    .SYNOPSIS
        Remove files older than specified days
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [int]$DaysOld = 7,
        
        [string]$Filter = "*",
        
        [string]$Description = "Old files"
    )
    
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    
    $rootSnapshot = Get-MolePathSnapshot -Path $Path
    if (-not $rootSnapshot) { return }
    $cutoffDate = (Get-Date).AddDays(-$DaysOld)
    
    $oldFiles = Get-ChildItem -LiteralPath $Path -Filter $Filter -File -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    if ($oldFiles -and (Test-MolePathSnapshot $rootSnapshot)) {
        $paths = $oldFiles | ForEach-Object { $_.FullName }
        Remove-SafeItems -Paths $paths -Description "$Description (>${DaysOld}d old)"
    }
}

function Remove-EmptyDirectories {
    <#
    .SYNOPSIS
        Remove empty directories recursively
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Description = "Empty directories"
    )
    
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    
    $removedCount = 0
    $maxIterations = 5
    
    for ($i = 0; $i -lt $maxIterations; $i++) {
        # @() keeps a single empty folder an array: a lone DirectoryInfo has no
        # .Count, which Windows PowerShell 5.1 strict mode rejects.
        try {
            $emptyDirs = @(Get-TreeItemsNoFollow -Path $Path -SkipUnreadable |
                     Where-Object { $_.PSIsContainer -and -not (Test-IsReparsePoint $_.FullName) } |
                     Where-Object { 
                         (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0
                     })
        }
        catch { return }

        if (-not $emptyDirs -or $emptyDirs.Count -eq 0) {
            break
        }
        
        foreach ($dir in $emptyDirs) {
            if (Test-SafePath -Path $dir.FullName) {
                if (-not $script:MoleDryRunMode) {
                    try {
                        if ((Test-MolePathSnapshot $dir.MolePathSnapshot) -and
                            (Remove-SafeItem -Path $dir.FullName)) { $removedCount++ }
                    }
                    catch {
                        Write-Debug "Could not remove empty dir: $($dir.FullName)"
                    }
                }
                else {
                    $removedCount++
                }
            }
        }
    }
    
    if ($removedCount -gt 0) {
        if ($script:MoleDryRunMode) {
            Write-DryRun "$Description $($script:Colors.Yellow)($removedCount dirs dry)$($script:Colors.NC)"
        }
        else {
            Write-Success "$Description $($script:Colors.Green)($removedCount dirs)$($script:Colors.NC)"
        }
        Set-SectionActivity
    }
}

function Clear-DirectoryContents {
    <#
    .SYNOPSIS
        Clear all contents of a directory but keep the directory itself
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [string]$Description = ""
    )
    
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    
    if (-not (Test-SafePath -Path $Path)) {
        return
    }
    
    $rootSnapshot = Get-MolePathSnapshot -Path $Path
    if (-not $rootSnapshot) { return }
    $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($items -and (Test-MolePathSnapshot $rootSnapshot)) {
        $paths = $items | ForEach-Object { $_.FullName }
        $desc = if ($Description) { $Description } else { Split-Path -Leaf $Path }
        Remove-SafeItems -Paths $paths -Description $desc
    }
}

# ============================================================================
# Statistics Functions
# ============================================================================

function Get-CleanupStats {
    <#
    .SYNOPSIS
        Get current cleanup statistics
    #>
    return @{
        TotalSizeKB   = $script:TotalSizeCleaned
        TotalSizeHuman = Format-ByteSize -Bytes ($script:TotalSizeCleaned * 1024)
        FilesCleaned  = $script:FilesCleaned
        TotalItems    = $script:TotalItems
    }
}

function Reset-CleanupStats {
    <#
    .SYNOPSIS
        Reset cleanup statistics
    #>
    $script:TotalSizeCleaned = 0
    $script:FilesCleaned = 0
    $script:TotalItems = 0
}

function Set-DryRunMode {
    <#
    .SYNOPSIS
        Enable or disable dry-run mode
    #>
    param([bool]$Enabled)
    $script:MoleDryRunMode = $Enabled
}

function Test-DryRunMode {
    <#
    .SYNOPSIS
        Check if dry-run mode is enabled
    #>
    return $script:MoleDryRunMode
}

# ============================================================================
# Exports (functions are available via dot-sourcing)
# ============================================================================
# Functions: Test-SafePath, Get-PathSize, Remove-SafeItem, etc.
