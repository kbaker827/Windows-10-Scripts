# WiFi Metered Connection Manager

PowerShell script to manage Windows WiFi network metered connection settings.

## What is a Metered Connection?

A **metered connection** tells Windows that your network has limited data (like a mobile hotspot). When set to "Fixed" (metered), Windows reduces background data usage:

- Pauses Windows Updates (except critical security updates)
- Disables automatic Microsoft Store app updates
- Reduces OneDrive and email sync frequency
- Disables peer-to-peer update uploads
- May block some live tile updates

**Unrestricted** means normal, unlimited data usage.

## Files

| File | Description |
|------|-------------|
| `Manage-MeteredConnection.ps1` | Main PowerShell script (replaces old batch files) |

## Quick Start

### Interactive Mode
```powershell
.\Manage-MeteredConnection.ps1
```
Prompts for SSID and action.

### Set a Network as Metered
```powershell
.\Manage-MeteredConnection.ps1 -SSID "MyHotspot" -Cost Fixed
```

### Set a Network as Unmetered
```powershell
.\Manage-MeteredConnection.ps1 -SSID "HomeWiFi" -Cost Unrestricted
```

### Check Current Status
```powershell
.\Manage-MeteredConnection.ps1 -SSID "MyHotspot"
```

### List All Profiles and Their Status
```powershell
.\Manage-MeteredConnection.ps1 -AllProfiles
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `SSID` | String | WiFi network name to configure |
| `Cost` | String | `Fixed` (metered), `Unrestricted` (unmetered), or `Get` (check only) |
| `AllProfiles` | Switch | Show all saved WiFi profiles and their status |
| `Interactive` | Switch | Force interactive mode |

## Examples

### Common Scenarios

**Before traveling with a mobile hotspot:**
```powershell
.\Manage-MeteredConnection.ps1 -SSID "iPhone Hotspot" -Cost Fixed
```

**Back home on unlimited WiFi:**
```powershell
.\Manage-MeteredConnection.ps1 -SSID "Home Fiber" -Cost Unrestricted
```

**Check if a network is metered:**
```powershell
.\Manage-MeteredConnection.ps1 -SSID "CoffeeShop WiFi"
```

**View all profiles:**
```powershell
.\Manage-MeteredConnection.ps1 -AllProfiles
```

### What-If Mode (Dry Run)
```powershell
.\Manage-MeteredConnection.ps1 -SSID "Test" -Cost Fixed -WhatIf
```

## Requirements

- Windows 8/Server 2012 or later
- PowerShell 5.1 or PowerShell 7+
- WiFi profile must already exist (you've connected to it before)

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Profile not found |
| 2 | Invalid parameter |
| 3 | netsh command failed |
| 4 | Unsupported Windows version |

## Migration from Batch Files

This PowerShell script replaces the old batch files:

| Old Batch File | New PowerShell Equivalent |
|----------------|---------------------------|
| `Fixed.bat` | `.\Manage-MeteredConnection.ps1 -SSID "name" -Cost Fixed` |
| `Unrestricted.bat` | `.\Manage-MeteredConnection.ps1 -SSID "name" -Cost Unrestricted` |
| `check for metered connection.bat` | `.\Manage-MeteredConnection.ps1 -SSID "name"` |

## Troubleshooting

### "Profile not found"
- You must have connected to the WiFi network at least once before
- SSID is case-sensitive
- Run `-AllProfiles` to see available profiles

### "Access denied"
- Some changes may require Administrator privileges
- Right-click PowerShell and select "Run as Administrator"

### Command fails silently
- Check Windows version (must be Windows 8 or later)
- Verify the WiFi adapter is enabled

## Technical Details

This script uses `netsh wlan` commands:

```cmd
# Set metered
netsh wlan set profileparameter name="SSID" cost=Fixed

# Set unmetered
netsh wlan set profileparameter name="SSID" cost=Unrestricted

# Show profile details
netsh wlan show profile name="SSID"
```

## Why PowerShell?

- Better error handling
- Parameter validation
- Pipeline support
- Progress indicators
- WhatIf support for testing
- Consistent with modern Windows administration

## Version History

### 2.0 (2026-02-12)
- Converted from batch files to PowerShell
- Added `-AllProfiles` to list all networks
- Added `-Interactive` mode
- Added `-WhatIf` support
- Better error handling and exit codes
- Shows available profiles when SSID not found

### 1.0
- Original batch files (Fixed.bat, Unrestricted.bat, check.bat)

## License

MIT License
