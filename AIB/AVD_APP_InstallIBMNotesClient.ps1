## Installs latest version of IBM Notes Client from Synthomers Storage Account via PowerShell

 # Download and install IBM Notes Client
 write-host 'AIB Customization: Downloading IBM Notes Client'
 $appName = 'IBMNotesClient'
 $drive = 'C:\Temp'
 New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
 $LocalPath = $drive + '\' + $appName 
 set-Location $LocalPath
 $IBMNotesClientURL = 'https://letsconfigmgr998.blob.core.windows.net/applications/IBM%20Notes/Notes%209.0.1%20client/'
 $IBMNotesClientexe = 'setup.exe'
 $outputPath = $LocalPath + '\' + $IBMNotesClientexe
 Invoke-WebRequest -Uri $IBMNotesClientURL -OutFile $outputPath
 write-host 'AIB Customization: Starting Install of IBM Notes Client'
 Start-Process -FilePath $outputPath -Args "/s /v"SETMULTIUSER=1 /qn /norestart" -Wait
 write-host 'AIB Customization: Finished Installation of IBM Notes Client'

# Cleanup temp directory
Set-location "c:\"
Remove-Item -Path "C:\Temp\IBMNotesClient" -Force -Recurse -ErrorAction SilentlyContinue
