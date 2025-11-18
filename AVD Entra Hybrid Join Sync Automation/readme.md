# AVD Entra Hybrid Join Sync Automation

## Overview

This solution automates the synchronisation of Azure Virtual Desktop (AVD) session hosts to Entra ID (Azure AD) to expedite **Entra Hybrid Join** operations. When new AVD session hosts are created in Active Directory, this tool automatically triggers an AAD Connect delta sync, significantly reducing the time it takes for devices to appear in Entra ID and complete hybrid join.

> **Important**: This solution is specifically designed for **Entra Hybrid Join** scenarios only. It does not apply to cloud-native Entra ID joined hosts.

## Version

**Current Version**: 1.0.0  
**Release Date**: 18 November 2025  
**Author**: Alex Durrant

## Features

- 🔄 Automated monitoring of AVD session host creation
- ⚡ Immediate AAD Connect delta sync triggering
- 📝 Comprehensive logging with daily rotation
- 🛡️ Secure service account creation and management
- 🎯 Targeted monitoring (only devices matching `vm-sh-*` pattern)
- ⏱️ Configurable time window (default: 5 minutes)
- 🔧 Easy deployment with single-script installation

## Use Case

This solution is ideal for environments where:
- You're using **Azure Virtual Desktop with Entra Hybrid Join**
- AVD session hosts are domain-joined on-premises first
- You need to reduce the delay between AD creation and Entra ID sync
- You want to speed up the hybrid join process for better user experience

## Components

### 1. Create-AVDSyncServiceAccount.ps1
Creates a dedicated service account with appropriate permissions and security settings.

**Features:**
- Generates secure 32-character password
- Sets account to never expire
- Prompts for service account OU location
- Provides detailed permission requirements
- Optionally adds account to ADSyncOperators group

### 2. Deploy-AVDSyncScheduledTask.ps1
Main deployment script that creates the monitoring script and scheduled task.

**Features:**
- Creates monitoring script in `C:\Scripts\AVD\`
- Sets up scheduled task running every 5 minutes
- Configures logging to `C:\Scripts\AVD\Logs\`
- Validates prerequisites and permissions

### 3. Sync-NewAVDSessionHostsToEntraID.ps1
The monitoring script that performs the actual checking and sync triggering (created automatically by deployment script).

**Features:**
- Monitors specific AVD OU for new devices
- Filters devices by naming pattern (`vm-sh-*`)
- Checks creation time within configurable window
- Triggers AAD Connect delta sync when conditions met
- Comprehensive logging of all operations

## Prerequisites

- Windows Server with AAD Connect installed
- Active Directory PowerShell module
- Administrator access to AAD Connect server
- Permissions to create service accounts in AD
- Permissions to create scheduled tasks

## Installation

### Step 1: Create Service Account

Run the service account creation script on a domain controller or server with AD management tools:

```powershell
.\Create-AVDSyncServiceAccount.ps1
```

When prompted:
- Provide the Distinguished Name of your service accounts OU
- Optionally add the account to ADSyncOperators group immediately
- Securely store the generated password

**Default account name**: `svc-avd-entra-sync`

### Step 2: Grant Required Permissions

#### Active Directory Permissions
1. Open **Active Directory Users and Computers**
2. Navigate to: `OU=Production,OU=Desktop,OU=Pooled,OU=Host Pools,OU=AVD,OU=Azure,DC=hhllp,DC=co,DC=uk`
3. Right-click the OU → **Delegate Control**
4. Add the service account (`svc-avd-entra-sync`)
5. Select **"Read all properties"** for Computer objects
6. Complete the wizard

#### Local Server Permissions (AAD Connect Server)
Add the service account to the **ADSyncOperators** local group:

```powershell
Add-LocalGroupMember -Group 'ADSyncOperators' -Member 'YOURDOMAIN\svc-avd-entra-sync'
```
#### Log on as a batch job
Add the service account to the **Log on as a batch job** user right assignment on the Entra Connect Sync Server:

<img width="432" height="368" alt="image" src="https://github.com/user-attachments/assets/5463c94d-71c7-4035-9c4c-e8432c67b050" />

#### File System Permissions
Grant the following permissions on the AAD Connect server:

- **C:\Scripts\AVD\** - Read & Execute
- **C:\Scripts\AVD\Logs\** - Modify

```powershell
# Create directories if they don't exist
New-Item -Path "C:\Scripts\AVD" -ItemType Directory -Force
New-Item -Path "C:\Scripts\AVD\Logs" -ItemType Directory -Force

# Grant permissions
$acl = Get-Acl "C:\Scripts\AVD"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("YOURDOMAIN\svc-avd-entra-sync","ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow")
$acl.AddAccessRule($rule)
Set-Acl "C:\Scripts\AVD" $acl

$acl = Get-Acl "C:\Scripts\AVD\Logs"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("YOURDOMAIN\svc-avd-entra-sync","Modify","ContainerInherit,ObjectInherit","None","Allow")
$acl.AddAccessRule($rule)
Set-Acl "C:\Scripts\AVD\Logs" $acl
```

### Step 3: Deploy the Solution

Run the deployment script on your **AAD Connect server**:

```powershell
.\Deploy-AVDSyncScheduledTask.ps1
```

When prompted, enter the service account credentials.

### Step 4: Verify Installation

Check that the scheduled task was created successfully:

```powershell
Get-ScheduledTask -TaskName "Sync-NewAVDSessionHostsToEntraID"
```

Manually test the monitoring script:

```powershell
C:\Scripts\AVD\Sync-NewAVDSessionHostsToEntraID.ps1
```

Check the logs:

```powershell
Get-Content "C:\Scripts\AVD\Logs\AVDSync_$(Get-Date -Format 'yyyyMMdd').log"
```

## Configuration

### Modify Monitored OU
Edit the `$searchBase` variable in `Sync-NewAVDSessionHostsToEntraID.ps1`:

```powershell
$searchBase = "OU=YourOU,DC=yourdomain,DC=com"
```

### Change Device Name Pattern
Edit the `$devicePrefix` variable in `Sync-NewAVDSessionHostsToEntraID.ps1`:

```powershell
$devicePrefix = "your-pattern-*"
```

### Adjust Time Window
Edit the `$minutesLookback` variable in `Sync-NewAVDSessionHostsToEntraID.ps1`:

```powershell
$minutesLookback = 10  # Check for devices created in last 10 minutes
```

### Change Scheduled Task Frequency
Modify the task trigger after deployment:

```powershell
$task = Get-ScheduledTask -TaskName "Sync-NewAVDSessionHostsToEntraID"
$task.Triggers[0].Repetition.Interval = "PT10M"  # Every 10 minutes
$task | Set-ScheduledTask
```

## Logging

Logs are stored in: `C:\Scripts\AVD\Logs\`

Log files are named: `AVDSync_YYYYMMDD.log`

**Log entries include:**
- Timestamp of each monitoring cycle
- Devices discovered matching criteria
- Device creation times and ages
- AAD Connect sync trigger events
- Errors and warnings

**Example log entry:**
```
2025-11-18 14:32:15 [Info] Starting AVD session host monitoring
2025-11-18 14:32:16 [Info] Checking for devices created after: 18/11/2025 14:27:16
2025-11-18 14:32:17 [Info] Found 1 potential AVD session host(s)
2025-11-18 14:32:17 [Info] Device: vm-sh-001, Created: 18/11/2025 14:30:22, Age: 1.92 minutes
2025-11-18 14:32:17 [Info] Device vm-sh-001 qualifies for sync (created 1.92 minutes ago)
2025-11-18 14:32:17 [Info] Waiting 30 seconds for AD replication...
2025-11-18 14:32:47 [Info] Triggering AAD Connect Delta Sync
2025-11-18 14:32:52 [Info] AAD Connect Delta Sync triggered successfully
2025-11-18 14:32:52 [Info] Monitoring cycle completed
```

## Troubleshooting

### Scheduled Task Not Running

Check task history:
```powershell
Get-ScheduledTaskInfo -TaskName "Sync-NewAVDSessionHostsToEntraID"
```

Verify service account permissions on ADSyncOperators group:
```powershell
Get-LocalGroupMember -Group "ADSyncOperators"
```

### AAD Connect Sync Fails

Ensure the service account is member of **ADSyncOperators**:
```powershell
Add-LocalGroupMember -Group 'ADSyncOperators' -Member 'YOURDOMAIN\svc-avd-entra-sync'
```

Manually test sync:
```powershell
Start-ADSyncSyncCycle -PolicyType Delta
```

### Devices Not Detected

Verify the OU path is correct:
```powershell
Get-ADOrganizationalUnit -Identity "OU=Production,OU=Desktop,OU=Pooled,OU=Host Pools,OU=AVD,OU=Azure,DC=alexdu,DC=co,DC=uk"
```

Check service account has read permissions on the AVD OU:
```powershell
# Run as the service account or verify delegation
Get-ADComputer -Filter "Name -like 'vm-sh-*'" -SearchBase "OU=Production,OU=Desktop,OU=Pooled,OU=Host Pools,OU=AVD,OU=Azure,DC=alexdu,DC=co,DC=uk"
```

### Log Files Not Created

Verify service account has modify permissions on the Logs folder:
```powershell
Get-Acl "C:\Scripts\AVD\Logs" | Format-List
```

Manually create a test log:
```powershell
"Test" | Out-File "C:\Scripts\AVD\Logs\test.log"
```

## Security Considerations

- Service account password is 32 characters and randomly generated
- Password file is created with restricted NTFS permissions (Administrators and SYSTEM only)
- Service account is configured with "Password never expires" (change according to your security policy)
- Service account has minimal permissions (read-only on AD, sync trigger only)
- All operations are logged for audit purposes

## Support

For issues, questions, or feature requests, please:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review the log files in `C:\Scripts\AVD\Logs\`
3. Open an issue on [GitHub](https://github.com/durrante/avd/issues)

When reporting issues, please include:
- Windows Server version
- AAD Connect version
- Relevant log entries
- Steps to reproduce the issue

## Version History

### Version 1.0.0 (18 November 2025)
- Initial release
- Service account creation script
- Automated deployment script
- Monitoring and sync script
- Comprehensive logging
- Support for Entra Hybrid Join scenarios

## License

This project is provided as-is without warranty. Use at your own risk.

## Author

**Alex Durrant**

---

**Note**: This solution is specifically designed for Entra Hybrid Join scenarios. If you're using cloud-native Entra ID joined session hosts, this solution is not required as those devices sync directly to Entra ID without AAD Connect.
