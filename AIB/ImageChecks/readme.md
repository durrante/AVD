# Post-Build Checks for Azure Image Builds

This document outlines a set of PowerShell commands used to verify the state of a Windows image either **during the build process** (e.g. via [Azure Run Command](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/run-command)) or **after image creation** when testing a completed deployment.

These checks help validate that required applications, features, and system configurations are correctly present and configured in the final image output from **Azure Image Builder (AIB)**.

---

## ✅ Check Installed Applications

List all applications installed in the image:

```powershell
Get-WmiObject -Class Win32_Product | 
    Select-Object Name, Version, InstallDate | 
    Sort-Object Name | 
    Format-Table -AutoSize
```

---

## 🔍 Check for Specific Applications

For example, verify if Google Chrome is installed:

```powershell
Get-WmiObject -Class Win32_Product | 
    Where-Object { $_.Name -like "*Chrome*" } | 
    Select-Object Name, Version, InstallDate | 
    Sort-Object Name | 
    Format-Table -AutoSize
```

---

## 🧩 Check .NET Framework 3.5 Installation

```powershell
Get-WindowsCapability -Online -Name NetFx3
```

---

## ⚙️ Check Enabled Optional Features

```powershell
Get-WindowsOptionalFeatures -Online | 
    Where-object {$_.State -eq "Enabled"}
```

---

## 📦 View AppX Provisioned Packages

```powershell
Get-AppXProvisionedPackage -Online | 
    Select-Object DisplayName, PackageName
```

---

## 🌐 Check Installed Languages

```powershell
Get-InstalledLanguage
```

---

## 🌍 Get Default UI Language

```powershell
Get-SystemPreferredUILanguage
```

---

## 🌎 Check Regional Settings

```powershell
Get-WinHomeLocation
Get-Culture
Get-WinSystemLocale
```

---

## 🖥️ Retrieve Windows Version and Build Information

```powershell
$OSInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" | ForEach-Object {
    "Version: {0}, Build: {1}.{2}.{3}.{4}" -f
        $(If ($_.PSobject.Properties.Name.Contains('DisplayVersion')) { $_.DisplayVersion } 
          Else { $_.ReleaseId }),
        $_.CurrentMajorVersionNumber,
        $_.CurrentMinorVersionNumber,
        $_.CurrentBuild,
        $_.UBR
}
$OSInfo
```

---

## Support
For questions or assistance, contact:
**Alex Durrant**  
Email: Alex.Durrant@hybrit.co.uk

---

## Changelog
- **1.0 - 30th May 2025** - Initial version by Alex Durrant


---
