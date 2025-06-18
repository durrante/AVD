# Azure Image Builder (AIB) Prerequisites Script

## Overview
This PowerShell script automates the deployment of prerequisite resources needed to use Azure Image Builder (AIB). It ensures a consistent and standardised environment for AIB image creation by:

- Checks the presence of and imports the Az PowerShell module
- Logging into Azure and selecting a subscription
- Creating a resource group if not already present
- Registering necessary Azure resource providers
- Creating a storage account and private blob container to store AIB assets
- Creating a managed identity and assigning it the required roles
- Creating an Azure Compute Gallery and associated image definition
- **(Optional)** Configuring a dedicated virtual network, network security group, and assigning additional custom networking roles

---

## ⚠️ Important Warning
**Before running the script, ensure that all variables are correctly configured.**

The script will prompt you to confirm before proceeding. To cancel and review, press `Ctrl+C`.

---

## Prerequisites
- PowerShell 7 or higher
- Az PowerShell module installed
- Sufficient Azure RBAC permissions (Owner or Contributor + User Access Administrator)

---

## Usage

### Basic Usage (Networking Disabled by Default)

```powershell
.\Deploy-AIBPrerequisites.ps1 -ResourceGroupName 'rg-myproject-aib' -Location 'uksouth' -CompanyID 'XYZ'
```

### Enable Networking Configuration

```powershell
.\Deploy-AIBPrerequisites.ps1 -EnableNetworking $true
```

### Pass Custom Tags as a Hashtable

You can pass tags using a hashtable inline:

```powershell
.\Deploy-AIBPrerequisites.ps1 -Tags @{ApplicationName='AVD'; BusinessUnit='Shared'; Environment='Production'; Owner='Alex@letsconfigmgr.com'}
```

Or define it first in your session and pass the variable:

```powershell
$tags = @{
    ApplicationName = 'AVD'
    BusinessUnit    = 'Shared'
    Environment     = 'Production'
    Owner           = 'alex.durrant@hybrit.co.uk'
}
.\Deploy-AIBPrerequisites.ps1 -Tags $tags
```

---

## Parameters

| Parameter              | Type       | Description                                                                 |
|------------------------|------------|-----------------------------------------------------------------------------|
| `ResourceGroupName`    | String     | Name of the resource group to create/use                                    |
| `Location`             | String     | Azure region for deployment (e.g. 'uksouth')                                |
| `CompanyID`            | String     | Three-letter company identifier used in naming conventions                  |
| `Tags`                 | Hashtable  | Tags to apply to all resources                                              |
| `EnableNetworking`     | Boolean    | Whether to deploy networking resources (default: `$false`)                  |
| `vnetName`             | String     | Name of the virtual network                                                 |
| `subnetName`           | String     | Name of the subnet                                                          |
| `vNetAddressSpace`     | CIDR       | vNet address range (e.g. `'192.168.0.0/16'`)                                |
| `AIBSubnetAddressSpace`| CIDR       | Subnet address range (e.g. `'192.168.1.0/24'`)                              |

---

## Expected Output Examples

### ✅ With Networking Enabled
![image](https://github.com/user-attachments/assets/9dc2064d-2aa2-4a1f-acab-8b237abc9591)

![image](https://github.com/user-attachments/assets/43ad78e4-fbaf-4b22-8659-5a22b82716f6)
- NSG created
- Subnet created and associated
- Networking permissions assigned
- Storage account and container created
- Azure Compute Gallery and Image Definition created
- Managed identity and roles created

### ✅ With Networking Disabled
- Storage account and container created
- Azure Compute Gallery and Image Definition created
- Managed identity and roles created
- No networking components mentioned

---

## Support
For questions or assistance, contact:
**Alex Durrant**  
Email: Alex.Durrant@hybrit.co.uk

---

## Changelog
- **1.0 - 23rd May 2025** - Initial version by Alex Durrant
- **1.1 - 16th June 2025** - Updated screenshots by Alex Durrant

---

## 🔍 Full Example with All Parameters

```powershell
.\Deploy-AIBPrereqs.ps1 `
    -ResourceGroupName 'rg-aib-uks-002' `
    -Location 'uksouth' `
    -CompanyID 'AUD' `
    -Tags @{ApplicationName='AVD'; BusinessUnit='Shared'; Environment='Production'; Owner='Alex@letsconfigmgr.com'} `
    -EnableNetworking $true `
    -vNetAddressSpace '172.16.0.0/16' `
    -AIBSubnetAddressSpace '172.16.100.0/24'
```

This will:
- Create all required resources in `uksouth`
- Use the `AUD` company ID in resource naming
- Apply specified tags
- Deploy and configure a dedicated virtual network and subnet

