<#
.SYNOPSIS
    Manage Windows WiFi connection metered status.

.DESCRIPTION
    Configures WiFi profiles as metered (Fixed) or unmetered (Unrestricted),
    or checks the current status of a WiFi profile. Windows uses this setting
    to reduce data usage on metered connections (e.g., mobile hotspots).

.PARAMETER SSID
    The WiFi network name (SSID) to configure. If not specified, shows all WiFi profiles.

.PARAMETER Cost
    The cost setting to apply:
    - Fixed: Treat as metered connection (reduces background data usage)
    - Unrestricted: Treat as unmetered (normal data usage)
    - Get: Show current profile details (default if no cost specified)

.PARAMETER AllProfiles
    Display all WiFi profiles and their metered status.

.PARAMETER Interactive
    Prompt for SSID interactively if not provided.

.EXAMPLE
    .\Manage-MeteredConnection.ps1 -SSID "MyHotspot" -Cost Fixed
    Sets "MyHotspot" as a metered connection.

.EXAMPLE
    .\Manage-MeteredConnection.ps1 -SSID "MyHotspot" -Cost Unrestricted
    Sets "MyHotspot" as unmetered.

.EXAMPLE
    .\Manage-MeteredConnection.ps1 -SSID "MyHotspot"
    Shows details for "MyHotspot" without changing settings.

.EXAMPLE
    .\Manage-MeteredConnection.ps1 -AllProfiles
    Lists all saved WiFi profiles and their metered status.

.EXAMPLE
    .\Manage-MeteredConnection.ps1 -Interactive
    Prompts for SSID and shows options interactively.

.NOTES
    Version:        2.0
    Author:         IT Admin
    Creation Date:  2026-02-12
    
    Requires Windows 8/Server 2012 or later (netsh wlan cost parameter support).
    
    What "Fixed" (metered) does:
    - Pauses Windows Updates (except critical security updates)
    - Disables automatic app updates from Microsoft Store
    - Reduces background sync (OneDrive, email sync frequency)
    - Disables peer-to-peer update uploads
    - May block some live tile updates
    
    Exit Codes:
    0   - Success
    1   - Profile not found
    2   - Invalid parameter
    3   - netsh command failed
    4   - Not running on supported Windows version
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(HelpMessage="WiFi network name (SSID) to configure")]
    [string]$SSID,
    
    [Parameter(HelpMessage="Cost setting: Fixed (metered), Unrestricted (unmetered), or Get (check only)")]
    [ValidateSet("Fixed", "Unrestricted", "Get")]
    [string]$Cost,
    
    [Parameter(HelpMessage="List all WiFi profiles")]
    [switch]$AllProfiles,
    
    [Parameter(HelpMessage="Prompt for SSID interactively")]
    [switch]$Interactive
)

#region Initialization
$ErrorActionPreference = 'Stop'
$script:Version = "2.0"

function Show-Header {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  WiFi Metered Connection Manager v$Version" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-NetshCommand {
    param([string]$Arguments)
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "netsh"
    $psi.Arguments = $Arguments
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    
    return @{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Get-WiFiProfileStatus {
    param([string]$ProfileName)
    
    $result = Invoke-NetshCommand "wlan show profile name=`"$ProfileName`""
    
    if ($result.ExitCode -ne 0 -or $result.StdOut -match "not found") {
        return $null
    }
    
    # Parse the output for cost information
    $costLine = $result.StdOut -split "`r?`n" | Where-Object { $_ -match "Cost\s+:" }
    $connectionMode = $result.StdOut -split "`r?`n" | Where-Object { $_ -match "Connection mode" }
    $authentication = $result.StdOut -split "`r?`n" | Where-Object { $_ -match "Authentication" }
    
    return @{
        ProfileName = $ProfileName
        Cost = if ($costLine) { ($costLine -split ":")[1].Trim() } else { "Unknown" }
        ConnectionMode = if ($connectionMode) { ($connectionMode -split ":")[1].Trim() } else { "Unknown" }
        Authentication = if ($authentication) { ($authentication -split ":")[1].Trim() } else { "Unknown" }
        RawOutput = $result.StdOut
    }
}

function Get-AllWiFiProfiles {
    $result = Invoke-NetshCommand "wlan show profiles"
    
    if ($result.ExitCode -ne 0) {
        Write-Error "Failed to retrieve WiFi profiles"
        return @()
    }
    
    # Extract profile names
    $profileNames = $result.StdOut -split "`r?`n" | 
        Where-Object { $_ -match "All User Profile\s+:\s*(.+)$" } |
        ForEach-Object { $matches[1].Trim() }
    
    return $profileNames
}

function Show-ProfileStatus {
    param([hashtable]$Status)
    
    Write-Host "Profile: " -NoNewline
    Write-Host $Status.ProfileName -ForegroundColor Yellow
    Write-Host "  Cost Setting: " -NoNewline
    
    switch -Regex ($Status.Cost) {
        "Fixed" { Write-Host $Status.Cost -ForegroundColor Red -NoNewline; Write-Host " (metered)" }
        "Unrestricted" { Write-Host $Status.Cost -ForegroundColor Green -NoNewline; Write-Host " (unmetered)" }
        default { Write-Host $Status.Cost -ForegroundColor Gray }
    }
    
    Write-Host "  Connection Mode: $($Status.ConnectionMode)"
    Write-Host "  Authentication: $($Status.Authentication)"
    Write-Host ""
}
#endregion

#region Main Execution
Show-Header

# Check if running on supported Windows
$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Major -lt 6 -or ($osVersion.Major -eq 6 -and $osVersion.Minor -lt 2)) {
    Write-Error "This script requires Windows 8/Server 2012 or later."
    exit 4
}

# Warn if not admin (netsh usually works without admin for viewing, but changes may fail)
if (-not (Test-Admin)) {
    Write-Warning "Not running as Administrator. Setting changes may fail."
    Write-Host ""
}

# Handle AllProfiles switch
if ($AllProfiles) {
    Write-Host "Retrieving all WiFi profiles..." -ForegroundColor Cyan
    Write-Host ""
    
    $profiles = Get-AllWiFiProfiles
    
    if ($profiles.Count -eq 0) {
        Write-Host "No WiFi profiles found." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Found $($profiles.Count) profile(s):" -ForegroundColor Green
    Write-Host ""
    
    foreach ($profile in $profiles) {
        $status = Get-WiFiProfileStatus -ProfileName $profile
        if ($status) {
            Show-ProfileStatus -Status $status
        }
    }
    exit 0
}

# Interactive mode
if ($Interactive -or (-not $SSID -and -not $Cost)) {
    Write-Host "Interactive Mode" -ForegroundColor Cyan
    Write-Host ""
    
    # Show available profiles
    $profiles = Get-AllWiFiProfiles
    if ($profiles.Count -gt 0) {
        Write-Host "Available WiFi profiles:" -ForegroundColor Green
        $profiles | ForEach-Object { Write-Host "  - $_" }
        Write-Host ""
    }
    
    $SSID = Read-Host "Enter the WiFi network name (SSID)"
    
    if ([string]::IsNullOrWhiteSpace($SSID)) {
        Write-Error "SSID cannot be empty."
        exit 2
    }
    
    Write-Host ""
    Write-Host "Select action:" -ForegroundColor Cyan
    Write-Host "  1. Check current status"
    Write-Host "  2. Set as metered (Fixed)"
    Write-Host "  3. Set as unmetered (Unrestricted)"
    Write-Host ""
    
    $choice = Read-Host "Enter choice (1-3)"
    
    switch ($choice) {
        "1" { $Cost = "Get" }
        "2" { $Cost = "Fixed" }
        "3" { $Cost = "Unrestricted" }
        default { 
            Write-Error "Invalid choice."
            exit 2
        }
    }
}

# If SSID provided but no Cost specified, default to Get
if ($SSID -and -not $Cost) {
    $Cost = "Get"
}

# Get current status before making changes
Write-Host "Checking current status for: $SSID" -ForegroundColor Cyan
Write-Host ""

$currentStatus = Get-WiFiProfileStatus -ProfileName $SSID

if (-not $currentStatus) {
    Write-Error "WiFi profile '$SSID' not found."
    Write-Host ""
    Write-Host "Available profiles:" -ForegroundColor Yellow
    Get-AllWiFiProfiles | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

Show-ProfileStatus -Status $currentStatus

# Apply changes if requested
if ($Cost -ne "Get") {
    Write-Host "Setting cost to: $Cost" -ForegroundColor Cyan
    
    if ($PSCmdlet.ShouldProcess($SSID, "Set cost to $Cost")) {
        $result = Invoke-NetshCommand "wlan set profileparameter name=`"$SSID`" cost=$Cost"
        
        if ($result.ExitCode -ne 0) {
            Write-Error "Failed to update profile. Error: $($result.StdErr)"
            exit 3
        }
        
        Write-Host "Success!" -ForegroundColor Green
        Write-Host ""
        
        # Show updated status
        $newStatus = Get-WiFiProfileStatus -ProfileName $SSID
        if ($newStatus) {
            Write-Host "Updated profile status:" -ForegroundColor Cyan
            Show-ProfileStatus -Status $newStatus
        }
    }
}

Write-Host "Operation complete." -ForegroundColor Green
#endregion
