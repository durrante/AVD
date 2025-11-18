<#
.SYNOPSIS
    Create service account for AVD AAD Connect sync automation
.DESCRIPTION
    This script creates a service account with appropriate naming and description
    for use with the AVD session host monitoring and AAD Connect sync automation.
.NOTES
    FileName:    Create-AVDSyncServiceAccount.ps1
    Author:      Modified for AVD environment
    Created:     18/11/2025
    Version:     1.0.0
    
    Requirements:
    - ActiveDirectory PowerShell module
    - Appropriate AD permissions to create user accounts
#>

#Requires -Modules ActiveDirectory
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AccountName = "svc-avd-entra-sync",
    
    [Parameter(Mandatory = $false)]
    [string]$DisplayName = "AVD Entra ID Sync Service",
    
    [Parameter(Mandatory = $false)]
    [string]$Description = "Service account for monitoring AVD session hosts and triggering AAD Connect delta sync to expedite Entra Hybrid Join"
)

Write-Host "====== AVD Sync Service Account Creation ======" -ForegroundColor Cyan
Write-Host ""

# Get the service accounts OU from user
Write-Host "Please provide the Distinguished Name of the OU where service accounts are stored." -ForegroundColor Yellow
Write-Host "Example: OU=Service Accounts,OU=Admin,DC=alexdu,DC=co,DC=uk" -ForegroundColor Gray
Write-Host ""

$serviceAccountOU = Read-Host "Service Account OU (Distinguished Name)"

# Validate OU exists
try {
    $ouExists = Get-ADOrganizationalUnit -Identity $serviceAccountOU -ErrorAction Stop
    Write-Host "✓ OU validated successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error: Unable to find OU: $serviceAccountOU" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check if account already exists
try {
    $existingAccount = Get-ADUser -Identity $AccountName -ErrorAction Stop
    Write-Host "✗ Error: Account '$AccountName' already exists" -ForegroundColor Red
    Write-Host "  Distinguished Name: $($existingAccount.DistinguishedName)" -ForegroundColor Yellow
    
    $overwrite = Read-Host "Do you want to reset this account? (yes/no)"
    if ($overwrite -ne "yes") {
        Write-Host "Exiting without changes" -ForegroundColor Yellow
        exit 0
    }
}
catch {
    # Account doesn't exist, which is what we want
    Write-Host "✓ Account name is available" -ForegroundColor Green
}

# Generate secure password
Write-Host ""
Write-Host "Generating secure password..." -ForegroundColor Cyan

Add-Type -AssemblyName 'System.Web'
$passwordLength = 32
$password = [System.Web.Security.Membership]::GeneratePassword($passwordLength, 8)
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

# Create the service account
Write-Host "Creating service account..." -ForegroundColor Cyan

$accountParams = @{
    Name                  = $AccountName
    SamAccountName        = $AccountName
    UserPrincipalName     = "$AccountName@hhllp.co.uk"
    DisplayName           = $DisplayName
    Description           = $Description
    Path                  = $serviceAccountOU
    AccountPassword       = $securePassword
    Enabled               = $true
    PasswordNeverExpires  = $true
    CannotChangePassword  = $true
    ChangePasswordAtLogon = $false
}

try {
    if ($existingAccount) {
        # Reset existing account
        Set-ADUser -Identity $AccountName @accountParams
        Set-ADAccountPassword -Identity $AccountName -NewPassword $securePassword -Reset
        Write-Host "✓ Service account reset successfully" -ForegroundColor Green
    }
    else {
        # Create new account
        New-ADUser @accountParams
        Write-Host "✓ Service account created successfully" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Error creating service account: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get the created account details
$createdAccount = Get-ADUser -Identity $AccountName -Properties *

# Save password to secure file
$securePasswordFile = "C:\Scripts\AVD\$AccountName-password.txt"
$securePasswordDir = Split-Path $securePasswordFile -Parent

if (-not (Test-Path $securePasswordDir)) {
    New-Item -Path $securePasswordDir -ItemType Directory -Force | Out-Null
}

$password | Out-File -FilePath $securePasswordFile -Encoding UTF8 -Force

# Set restrictive permissions on password file
$acl = Get-Acl $securePasswordFile
$acl.SetAccessRuleProtection($true, $false) # Remove inheritance
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }

# Add only Administrators and SYSTEM
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "Allow")
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "Allow")

$acl.AddAccessRule($adminRule)
$acl.AddAccessRule($systemRule)
Set-Acl -Path $securePasswordFile -AclObject $acl

Write-Host ""
Write-Host "====== Account Details ======" -ForegroundColor Green
Write-Host "Account Name:        $AccountName" -ForegroundColor White
Write-Host "Display Name:        $DisplayName" -ForegroundColor White
Write-Host "UPN:                 $($createdAccount.UserPrincipalName)" -ForegroundColor White
Write-Host "Distinguished Name:  $($createdAccount.DistinguishedName)" -ForegroundColor White
Write-Host "Description:         $Description" -ForegroundColor White
Write-Host ""
Write-Host "Password saved to:   $securePasswordFile" -ForegroundColor Yellow
Write-Host ""
Write-Host "====== Required Permissions ======" -ForegroundColor Cyan
Write-Host ""
Write-Host "This service account requires the following permissions:" -ForegroundColor White
Write-Host ""
Write-Host "1. LOCAL PERMISSIONS (on AAD Connect Server):" -ForegroundColor Yellow
Write-Host "   - Add to local group: ADSyncOperators" -ForegroundColor White
Write-Host "   - Command: " -ForegroundColor Gray
Write-Host "     Add-LocalGroupMember -Group 'ADSyncOperators' -Member 'HHLLP\$AccountName'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. ACTIVE DIRECTORY PERMISSIONS:" -ForegroundColor Yellow
Write-Host "   - Read permissions on the AVD OU:" -ForegroundColor White
Write-Host "     OU=Production,OU=Desktop,OU=Pooled,OU=Host Pools,OU=AVD,OU=Azure,DC=hhllp,DC=co,DC=uk" -ForegroundColor Gray
Write-Host "   - These can be delegated via Active Directory Users and Computers:" -ForegroundColor White
Write-Host "     • Right-click the AVD OU → Delegate Control" -ForegroundColor Gray
Write-Host "     • Add $AccountName" -ForegroundColor Gray
Write-Host "     • Select 'Read all properties' for Computer objects" -ForegroundColor Gray
Write-Host ""
Write-Host "3. SCHEDULED TASK PERMISSIONS:" -ForegroundColor Yellow
Write-Host "   - Log on as a batch job permission via User Rights Assignment " -ForegroundColor White
Write-Host ""
Write-Host "4. FILE SYSTEM PERMISSIONS:" -ForegroundColor Yellow
Write-Host "   - Read/Execute on C:\Scripts\AVD\" -ForegroundColor White
Write-Host "   - Modify on C:\Scripts\AVD\Logs\" -ForegroundColor White
Write-Host ""

# Offer to add to ADSyncOperators now
Write-Host "Would you like to add this account to the local ADSyncOperators group now? (yes/no)" -ForegroundColor Cyan
$addToGroup = Read-Host

if ($addToGroup -eq "yes") {
    try {
        Add-LocalGroupMember -Group "ADSyncOperators" -Member "HHLLP\$AccountName" -ErrorAction Stop
        Write-Host "✓ Successfully added to ADSyncOperators group" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -like "*already a member*") {
            Write-Host "✓ Account is already a member of ADSyncOperators" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Error adding to group: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  You may need to run this manually" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "====== Next Steps ======" -ForegroundColor Cyan
Write-Host "1. Grant AD permissions on the AVD OU (see above)" -ForegroundColor White
Write-Host "2. Set file system permissions on C:\Scripts\AVD\" -ForegroundColor White
Write-Host "3. Run Deploy-AVDSyncScheduledTask.ps1 with this service account" -ForegroundColor White
Write-Host "4. Store the password securely and delete $securePasswordFile" -ForegroundColor White
Write-Host ""
Write-Host "IMPORTANT: Store the password in a secure location (e.g., password vault) before deleting the file!" -ForegroundColor Yellow
Write-Host ""
