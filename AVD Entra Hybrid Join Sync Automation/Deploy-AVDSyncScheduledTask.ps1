<#
.SYNOPSIS
    Deploy scheduled task to monitor AVD session hosts and trigger Entra ID sync
.DESCRIPTION
    This script creates the monitoring script and scheduled task to detect new AVD session hosts
    in the specified OU and trigger AAD Connect delta sync to expedite Entra Hybrid Join.
.NOTES
    FileName:    Deploy-AVDSyncScheduledTask.ps1
    Author:      Modified for AVD environment
    Created:     18/11/2025
    Version:     1.0.0
    
    Requirements:
    - Run on AAD Connect server
    - Service account with appropriate permissions
    - ActiveDirectory PowerShell module
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ScriptPath = "C:\Scripts\AVD",
    
    [Parameter(Mandatory = $false)]
    [string]$ServiceAccountName
)

# Ensure script directory exists
if (-not (Test-Path $ScriptPath)) {
    New-Item -Path $ScriptPath -ItemType Directory -Force | Out-Null
    Write-Host "Created script directory: $ScriptPath" -ForegroundColor Green
}

# Define the monitoring script content
$monitoringScriptContent = @'
<#
.SYNOPSIS
    Monitor AVD session hosts and trigger AAD Connect sync for new devices
.DESCRIPTION
    This script monitors the AVD OU for session hosts starting with 'vm-sh-' that were created
    in the last 5 minutes. When detected, it triggers an AAD Connect delta sync to expedite
    Entra Hybrid Join for Azure Virtual Desktop session hosts.
.NOTES
    FileName:    Sync-NewAVDSessionHostsToEntraID.ps1
    Author:      Modified for AVD environment
    Created:     18/11/2025
    Version:     1.0.0
#>

#Requires -Modules ActiveDirectory

[CmdletBinding()]
param()

# Configuration
$searchBase = "OU=Production,OU=Desktop,OU=Pooled,OU=Host Pools,OU=AVD,OU=Azure,DC=alexdu,DC=co,DC=uk"
$devicePrefix = "vm-sh-*"
$minutesLookback = 5
$replicationWaitSeconds = 30
$logPath = "C:\Scripts\AVD\Logs"

# Ensure log directory exists
if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

# Function to write log entries
function Write-LogEntry {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Join-Path $logPath "AVDSync_$(Get-Date -Format 'yyyyMMdd').log"
    $logEntry = "$timestamp [$Level] $Message"
    
    Add-Content -Path $logFile -Value $logEntry
    
    switch ($Level) {
        'Warning' { Write-Warning $Message }
        'Error' { Write-Error $Message }
        default { Write-Verbose $Message -Verbose }
    }
}

# Start monitoring
Write-LogEntry "Starting AVD session host monitoring" -Level Info

try {
    # Import Active Directory module
    Import-Module ActiveDirectory -ErrorAction Stop
    
    # Calculate time threshold
    $timeThreshold = [DateTime]::Now.AddMinutes(-$minutesLookback)
    Write-LogEntry "Checking for devices created after: $timeThreshold" -Level Info
    
    # Search for new AVD session hosts
    $filter = "Name -like '$devicePrefix' -and Created -ge `$timeThreshold"
    
    $sessionHosts = Get-ADComputer -Filter $filter `
        -SearchBase $searchBase `
        -Properties Created, Modified, Description, OperatingSystem `
        -ErrorAction Stop
    
    if ($sessionHosts) {
        Write-LogEntry "Found $($sessionHosts.Count) potential AVD session host(s)" -Level Info
        
        $syncRequired = $false
        
        foreach ($host in $sessionHosts) {
            # Calculate age of the computer object
            $createdAge = ([DateTime]::Now - $host.Created).TotalMinutes
            
            Write-LogEntry "Device: $($host.Name), Created: $($host.Created), Age: $([math]::Round($createdAge, 2)) minutes" -Level Info
            
            # Verify it's within our threshold and truly new
            if ($createdAge -le ($minutesLookback + 1)) {
                Write-LogEntry "Device $($host.Name) qualifies for sync (created $([math]::Round($createdAge, 2)) minutes ago)" -Level Info
                $syncRequired = $true
            }
            else {
                Write-LogEntry "Device $($host.Name) is outside threshold (created $([math]::Round($createdAge, 2)) minutes ago)" -Level Warning
            }
        }
        
        if ($syncRequired) {
            # Wait for AD replication
            Write-LogEntry "Waiting $replicationWaitSeconds seconds for AD replication..." -Level Info
            Start-Sleep -Seconds $replicationWaitSeconds
            
            # Trigger AAD Connect sync
            Write-LogEntry "Triggering AAD Connect Delta Sync" -Level Info
            
            try {
                Start-ADSyncSyncCycle -PolicyType Delta -ErrorAction Stop
                Write-LogEntry "AAD Connect Delta Sync triggered successfully" -Level Info
            }
            catch {
                Write-LogEntry "Failed to trigger AAD Connect sync: $($_.Exception.Message)" -Level Error
                throw
            }
        }
        else {
            Write-LogEntry "No devices qualify for sync at this time" -Level Info
        }
    }
    else {
        Write-LogEntry "No new AVD session hosts found in the last $minutesLookback minutes" -Level Info
    }
}
catch {
    Write-LogEntry "Error during monitoring: $($_.Exception.Message)" -Level Error
    Write-LogEntry "Stack Trace: $($_.ScriptStackTrace)" -Level Error
    exit 1
}

Write-LogEntry "Monitoring cycle completed" -Level Info
'@

# Save the monitoring script
$monitoringScriptPath = Join-Path $ScriptPath "Sync-NewAVDSessionHostsToEntraID.ps1"
$monitoringScriptContent | Out-File -FilePath $monitoringScriptPath -Encoding UTF8 -Force

Write-Host "`nMonitoring script created: $monitoringScriptPath" -ForegroundColor Green

# Get service account credentials
if ([string]::IsNullOrEmpty($ServiceAccountName)) {
    Write-Host "`nPlease enter the service account credentials" -ForegroundColor Cyan
    Write-Host "Recommended: svc-avd-sync or svc-aadconnect-avd" -ForegroundColor Yellow
    $credential = Get-Credential -Message "Enter service account credentials (e.g., HHLLP\svc-avd-sync)"
}
else {
    $credential = Get-Credential -UserName $ServiceAccountName -Message "Enter password for $ServiceAccountName"
}

# Create scheduled task
Write-Host "`nCreating scheduled task..." -ForegroundColor Cyan

$taskName = "Sync-NewAVDSessionHostsToEntraID"
$taskDescription = "Monitors AVD OU for new session hosts (vm-sh-*) created in the last 5 minutes and triggers AAD Connect delta sync to expedite Entra Hybrid Join"

# Define task action
$action = New-ScheduledTaskAction `
    -Execute 'Powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$monitoringScriptPath`"" `
    -WorkingDirectory $ScriptPath

# Define task trigger (daily at midnight with 5-minute repetition)
$trigger = New-ScheduledTaskTrigger -Daily -At 12am

# Define task settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew

# Register the task
try {
    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        Write-Host "Scheduled task '$taskName' already exists. Unregistering..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    $task = Register-ScheduledTask `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -TaskName $taskName `
        -Description $taskDescription `
        -User $credential.UserName `
        -Password $credential.GetNetworkCredential().Password `
        -RunLevel Highest
    
    # Configure repetition interval
    $task.Triggers[0].Repetition.Interval = "PT5M"  # Every 5 minutes
    $task.Triggers[0].Repetition.Duration = "PT24H" # For 24 hours
    
    # Update the task with modified trigger
    $task | Set-ScheduledTask -User $credential.UserName -Password $credential.GetNetworkCredential().Password | Out-Null
    
    Write-Host "`nScheduled task created successfully!" -ForegroundColor Green
    Write-Host "Task Name: $taskName" -ForegroundColor Cyan
    Write-Host "Frequency: Every 5 minutes, 24/7" -ForegroundColor Cyan
    Write-Host "Run As: $($credential.UserName)" -ForegroundColor Cyan
    
    # Display next run time
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "Next Run: $($taskInfo.NextRunTime)" -ForegroundColor Cyan
}
catch {
    Write-Host "Error creating scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Summary
Write-Host "`n====== Deployment Summary ======" -ForegroundColor Green
Write-Host "Script Location: $monitoringScriptPath" -ForegroundColor White
Write-Host "Log Location: C:\Scripts\AVD\Logs" -ForegroundColor White
Write-Host "Scheduled Task: $taskName" -ForegroundColor White
Write-Host "Monitored OU: OU=Production,OU=Desktop,OU=Pooled,OU=Host Pools,OU=AVD,OU=Azure,DC=hhllp,DC=co,DC=uk" -ForegroundColor White
Write-Host "Device Pattern: vm-sh-*" -ForegroundColor White
Write-Host "`nThe task will run every 5 minutes and check for new AVD session hosts." -ForegroundColor Yellow
Write-Host "When detected, it will trigger an AAD Connect delta sync automatically." -ForegroundColor Yellow
Write-Host "`nYou can manually test the script by running:" -ForegroundColor Cyan
Write-Host "  $monitoringScriptPath" -ForegroundColor White
