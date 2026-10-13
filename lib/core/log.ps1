# Mole - Logging Module
# Provides consistent logging functions with colors and icons

#Requires -Version 5.1
Set-StrictMode -Version Latest

# Prevent multiple sourcing
if ((Get-Variable -Name 'MOLE_LOG_LOADED' -Scope Script -ErrorAction SilentlyContinue) -and $script:MOLE_LOG_LOADED) { return }
$script:MOLE_LOG_LOADED = $true

# Import base module
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\base.ps1"
Initialize-MoleVisualDefaults

# ============================================================================
# Log Configuration
# ============================================================================

$script:LogConfig = @{
    DebugEnabled = $env:MOLE_DEBUG -eq "1"
    LogFile      = $null
    Verbose      = $false
}

# ============================================================================
# Core Logging Functions
# ============================================================================

function Write-LogMessage {
    <#
    .SYNOPSIS
        Internal function to write formatted log message
    #>
    param(
        [string]$Message,
        [string]$Level,
        [string]$Color,
        [string]$Icon
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $colorCode = Get-MoleColor -Name $Color
    $nc = Get-MoleColor -Name "NC"

    $formattedIcon = if ($Icon) { "$Icon " } else { "" }
    $output = "  ${colorCode}${formattedIcon}${nc}${Message}"

    Stop-Spinner
    Write-Host $output
    if ($script:CurrentSection.Active) { Start-Spinner }

    # Also write to log file if configured
    if ($script:LogConfig.LogFile) {
        "$timestamp [$Level] $Message" | Out-File -Append -FilePath $script:LogConfig.LogFile -Encoding UTF8
    }
}

function Write-Info {
    <#
    .SYNOPSIS
        Write an informational message
    #>
    param([string]$Message)
    Write-LogMessage -Message $Message -Level "INFO" -Color "Cyan" -Icon (Get-MoleIcon -Name "List")
}

function Write-Success {
    <#
    .SYNOPSIS
        Write a success message
    #>
    param([string]$Message)
    Write-LogMessage -Message $Message -Level "SUCCESS" -Color "Green" -Icon (Get-MoleIcon -Name "Success")
}


function Write-MoleWarning {
    <#
    .SYNOPSIS
        Write a warning message
    #>
    param([string]$Message)
    Write-LogMessage -Message $Message -Level "WARN" -Color "Yellow" -Icon (Get-MoleIcon -Name "Warning")
}

function Write-MoleError {
    <#
    .SYNOPSIS
        Write an error message
    #>
    param([string]$Message)
    Write-LogMessage -Message $Message -Level "ERROR" -Color "Red" -Icon (Get-MoleIcon -Name "Error")
}


function Write-Debug {
    <#
    .SYNOPSIS
        Write a debug message (only if debug mode is enabled)
    #>
    param([string]$Message)

    if ($script:LogConfig.DebugEnabled) {
        $gray = Get-MoleColor -Name "Gray"
        $nc = Get-MoleColor -Name "NC"
        Stop-Spinner
        Write-Host "  ${gray}[DEBUG] $Message${nc}"
        if ($script:CurrentSection.Active) { Start-Spinner }
    }
}

function Write-DryRun {
    <#
    .SYNOPSIS
        Write a dry-run message (action that would be taken)
    #>
    param([string]$Message)
    Write-LogMessage -Message $Message -Level "DRYRUN" -Color "Yellow" -Icon (Get-MoleIcon -Name "DryRun")
}

# ============================================================================
# Section Functions (for progress indication)
# ============================================================================

$script:CurrentSection = @{
    Active   = $false
    Activity = $false
    Name     = ""
}

function Start-Section {
    <#
    .SYNOPSIS
        Start a new section with a title
    #>
    param([string]$Title)

    Stop-Spinner
    $script:CurrentSection.Active = $true
    $script:CurrentSection.Activity = $false
    $script:CurrentSection.Name = $Title

    $purple = Get-MoleColor -Name "PurpleBold"
    $nc = Get-MoleColor -Name "NC"
    $arrow = Get-MoleIcon -Name "Arrow"

    Write-Host ""
    Write-Host "${purple}${arrow} ${Title}${nc}"
    Start-Spinner
}

function Stop-Section {
    <#
    .SYNOPSIS
        End the current section
    #>
    Stop-Spinner
    if ($script:CurrentSection.Active -and -not $script:CurrentSection.Activity) {
        Write-Success "Nothing to tidy"
    }
    $script:CurrentSection.Active = $false
    Stop-Spinner
}

function Set-SectionActivity {
    <#
    .SYNOPSIS
        Mark that activity occurred in current section
    #>
    if ($script:CurrentSection.Active) {
        $script:CurrentSection.Activity = $true
    }
}

# ============================================================================
# Progress Spinner
# ============================================================================

function Test-MoleInteractiveOutput {
    try {
        return $Host.Name -eq 'ConsoleHost' -and -not [Console]::IsOutputRedirected -and
            -not [Console]::IsInputRedirected -and $env:TERM -ne 'dumb'
    }
    catch { return $false }
}

function Initialize-MoleSpinner {
    if ('Mole.TerminalSpinner' -as [type]) { return }
    # A CLR timer continues while PowerShell waits on synchronous filesystem work.
    # It never calls PowerShell from a background thread. Stop drains its callback
    # before the foreground writes a row or returns control to the caller.
    Add-Type -TypeDefinition @'
using System;
using System.Threading;
namespace Mole {
    public static class TerminalSpinner {
        static readonly object Gate = new object();
        static readonly char[] Frames = { '\u2816', '\u2832', '\u2834', '\u2826' };
        static Timer timer;
        static string text;
        static int frame;
        static bool drawn;
        public static void Start(string message) {
            lock (Gate) {
                text = message;
                if (timer != null) return;
                frame = 0;
                timer = new Timer(Draw, null, 80, 80);
            }
        }
        static void Draw(object state) {
            lock (Gate) {
                if (timer == null) return;
                try {
                    int columns = 80;
                    try { columns = Console.WindowWidth; } catch (System.IO.IOException) { }
                    int width = Math.Max(1, columns - 5);
                    string label = text.Length > width ? text.Substring(0, width) : text;
                    Console.Write("\r\x1b[2K  \x1b[34m" + Frames[frame++ % Frames.Length] + "\x1b[0m " + label);
                    drawn = true;
                } catch { /* Losing a terminal must not interrupt maintenance. */ }
            }
        }
        public static void Stop() {
            lock (Gate) {
                if (timer != null) { timer.Dispose(); timer = null; }
                if (drawn) {
                    try { Console.Write("\r\x1b[2K"); } catch { }
                    drawn = false;
                }
            }
        }
    }
}
'@
}

function Start-Spinner {
    param([string]$Message = "Scanning...")
    if (-not (Test-MoleInteractiveOutput)) { return }
    try {
        Initialize-MoleSpinner
        # Messages are terminal text, never control sequences supplied by paths.
        $safeMessage = $Message -replace '[\x00-\x1f\x7f]', ' '
        [Mole.TerminalSpinner]::Start($safeMessage)
    }
    catch { } # A host without dynamic compilation keeps the normal static output.
}

function Update-Spinner {
    param([string]$Message = "Scanning...")
    Start-Spinner -Message $Message
}

function Stop-Spinner {
    if ('Mole.TerminalSpinner' -as [type]) { [Mole.TerminalSpinner]::Stop() }
}

function Write-Progress {
    # Match the built-in parameter names used by the application/project scanners.
    param(
        [string]$Activity = "Scanning...",
        [string]$Status = "",
        [int]$PercentComplete = -1,
        [switch]$Completed,
        [int]$Current = 0,
        [int]$Total = 0,
        [string]$Message = "",
        [int]$Width = 30
    )
    if ($Completed) { Stop-Spinner; return }
    $label = if ($Message) { $Message } elseif ($Status) { "$Activity, $Status" } else { $Activity }
    Update-Spinner -Message $label
}

function Complete-Progress { Stop-Spinner }

# ============================================================================
# Log File Management
# ============================================================================

function Set-LogFile {
    <#
    .SYNOPSIS
        Set a log file for persistent logging
    #>
    param([string]$Path)

    $script:LogConfig.LogFile = $Path
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Enable-DebugMode {
    <#
    .SYNOPSIS
        Enable debug logging
    #>
    $script:LogConfig.DebugEnabled = $true
}

function Disable-DebugMode {
    <#
    .SYNOPSIS
        Disable debug logging
    #>
    $script:LogConfig.DebugEnabled = $false
}

# ============================================================================
# Exports (functions are available via dot-sourcing)
# ============================================================================
# Functions: Write-Info, Write-Success, Write-Warning, Write-Error, etc.
