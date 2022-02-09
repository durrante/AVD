## Installs latest version of SAP 2021 from Azure Storage Account via PowerShell

 # Download and install SAP 2021 Pathway Client
 write-host 'AIB Customisation: Downloading SAP 2021'
 $appName = 'SAP'
 $drive = 'C:\Temp'
 New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
 $LocalPath = $drive + '\' + $appName 
 set-Location $LocalPath
 $ClientURL = 'https://letsconfigmgr998.blob.core.windows.net/applications/SAP%202021/Install.zip'
 $Clientexe = 'Install.zip'
 $outputPath = $LocalPath + '\' + $Clientexe
 Invoke-WebRequest -Uri $ClientURL -OutFile $outputPath -UseBasicParsing
 Expand-Archive -LiteralPath 'C:\\Temp\\SAP\\Install.zip' -DestinationPath $Localpath -Force -Verbose
 $FullPath = $drive + '\' + $appName + '\' + 'Setup\NwSapSetup.exe'
 write-host 'AIB Customisation: Starting Install of SAP 2021'
 Start-Process -FilePath $FullPath -ArgumentList '/Silent', '/Package="pathway_2021"' -Wait
 Start-Sleep 2
 write-host 'AIB Customisation: Finished Installation of SAP 2021'

# Cleanup temp directory
Set-location "c:\"
Remove-Item -Path "C:\Temp\SAP" -Force -Recurse -ErrorAction SilentlyContinue
