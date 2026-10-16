# Mole - Analyze Command
# Disk space analyzer wrapper

#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path,
    
    [Alias('h')]
    [switch]$ShowHelp,

    [Alias('d')]
    [switch]$DebugMode
)

$ErrorActionPreference = "Stop"

# Script location
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$windowsDir = Split-Path -Parent $scriptDir
$defaultBinPath = Join-Path $windowsDir "bin\analyze.exe"
. (Join-Path $windowsDir "lib\core\tui_binaries.ps1")

# Help
function Show-AnalyzeHelp {
    $esc = [char]27
    Write-Host ""
    Write-Host "$esc[1;35mmo analyze$esc[0m - Interactive disk space analyzer"
    Write-Host ""
    Write-Host "$esc[33mUsage:$esc[0m mo analyze [path]"
    Write-Host ""
    Write-Host "$esc[33mOptions:$esc[0m"
    Write-Host "  [path]     Path to analyze (default: overview of folders and drives)"
    Write-Host "  --help     Show this help message"
    Write-Host ""
    Write-Host "$esc[33mKeybindings:$esc[0m"
    Write-Host "  Up/Down          Navigate entries"
    Write-Host "  Enter/Right      Open folder"
    Write-Host "  Left/Backspace   Go back"
    Write-Host "  Space            Select"
    Write-Host "  Delete           Move selected to the Recycle Bin"
    Write-Host "  T                Top large files"
    Write-Host "  /                Filter"
    Write-Host "  O / F / P        Open, show in Explorer, preview"
    Write-Host "  R                Refresh"
    Write-Host "  Esc              Back"
    Write-Host "  Q                Quit"
    Write-Host ""
}

if ($ShowHelp) {
    Show-AnalyzeHelp
    return
}

$binPath = Ensure-TuiBinary -Name "analyze" -WindowsDir $windowsDir -DestinationPath $defaultBinPath -SourcePath "./cmd/analyze/"
if (-not $binPath) {
    Write-Host "Could not download the verified analyze tool for this version from GitHub Releases." -ForegroundColor Red
    Write-Host "Check the network and run 'mo analyze' again. With Go installed, Mole builds it locally instead." -ForegroundColor Yellow
    exit 1
}

$previousDebug = $env:MOLE_DEBUG
if ($DebugMode) { $env:MOLE_DEBUG = "1" }

# Pass the path for this run only: without one the analyzer opens the overview,
# so a path left in the session by an earlier run must not leak into the next.
$previousPath = $env:MO_ANALYZE_PATH
$env:MO_ANALYZE_PATH = $Path
try {
    & $binPath
}
finally {
    $env:MO_ANALYZE_PATH = $previousPath
    $env:MOLE_DEBUG = $previousDebug
}

# Explicitly propagate native failures through powershell.exe -File as well
# as the executable launcher. Help returns before reaching this point.
exit $LASTEXITCODE
