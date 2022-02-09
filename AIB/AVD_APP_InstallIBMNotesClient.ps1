## Installs latest version of IBM Notes from Azure Storage Account via PowerShell

 # Download and install IBM Notes Client
 write-host 'AIB Customisation: Downloading IBM Notes Client'
 $appName = 'IBMNotesClient'
 $drive = 'C:\Temp'
 New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
 $LocalPath = $drive + '\' + $appName 
 set-Location $LocalPath
 $IBMNotesClientURL = 'https://letsconfigmgr998.blob.core.windows.net/applications/IBM%20Notes/Notes%209.0.1%20client.zip'
 $IBMNotesClientexe = 'IBMClientInstall.zip'
 $outputPath = $LocalPath + '\' + $IBMNotesClientexe
 Invoke-WebRequest -Uri $IBMNotesClientURL -OutFile $outputPath -UseBasicParsing
 Expand-Archive -LiteralPath 'C:\\Temp\\IBMNotesClient\\IBMClientInstall.zip' -DestinationPath $Localpath -Force -Verbose
 $FullPath = $drive + '\' + $appName + '\' + 'Notes 9.0.1 client\setup.exe'
 write-host 'AIB Customisation: Starting Install of IBM Notes Client'
 Start-Process -FilePath $FullPath -ArgumentList '/s', '/v"SETMULTIUSER=1 /qn /norestart"' -Wait
 Start-Sleep 2
 write-host 'AIB Customisation: Finished Installation of IBM Notes Client'

 # Download and Install IBM Notes

 write-host 'AIB Customisation: Downloading IBM Notes'
 $appName = 'IBMNotesClient'
 $drive = 'C:\Temp'
 New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
 $LocalPath = $drive + '\' + $appName 
 set-Location $LocalPath
 $IBMNotesURL = 'https://letsconfigmgr998.blob.core.windows.net/applications/IBM%20Notes/notes901FP7_win.exe'
 $IBMNotesexe = 'notes901FP7_win.exe'
 $outputPath = $LocalPath + '\' + $IBMNotesexe
 Invoke-WebRequest -Uri $IBMNotesURL -OutFile $outputPath -UseBasicParsing
 write-host 'AIB Customisation: Starting Install of IBM Notes'
 Start-Process -FilePath $Outputpath -ArgumentList '-s', '-a', '/s', '/v"/qn /norestart"' -Wait
 Start-Sleep 2
 write-host 'AIB Customisation: Finished Installation of IBM Notes'

# Cleanup temp directory
Set-location "c:\"
Remove-Item -Path "C:\Temp\IBMNotesClient" -Force -Recurse -ErrorAction SilentlyContinue
