## Installs latest version of VCE from Azure Storage Account via PowerShell

 # Download and VCE
 write-host 'AIB Customisation: Downloading VCE'
 $appName = 'VCE'
 $drive = 'C:\Temp'
 New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
 $LocalPath = $drive + '\' + $appName 
 set-Location $LocalPath
 $VCEURL = 'https://stlcmaibuks001.blob.core.windows.net/azureimagebuilder/Applications/VCE/vce_exam_simulator_setup.exe'
 $VCEexe = 'vce_exam_simulator_setup.exe'
 $outputPath = $LocalPath + '\' + $VCEexe
 Invoke-WebRequest -Uri $VCEURL -OutFile $outputPath -UseBasicParsing
 $FullPath = $drive + '\' + $appName + '\' + 'vce_exam_simulator_setup.exe'
 write-host 'AIB Customisation: Starting Install of VCE'
 Start-Process -FilePath $FullPath -ArgumentList '/VerySilent' -Wait
 Start-Sleep 2
 write-host 'AIB Customisation: Finished Installation of VCE'
