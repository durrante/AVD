## Installs latest version of Visual Studio tools for Office x64 via PowerShell

 # install vs tools for Office 365 x64
 write-host 'AIB Customization: Install the latest Microsoft Visual Studio Tools for Office x64'
 $appName = 'VisualStudioTools'
 $drive = 'C:\Temp'
 New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
 $LocalPath = $drive + '\' + $appName 
 set-Location $LocalPath
 $visStudioToolsURL = 'http://download.microsoft.com/download/C/A/8/CA86DFA0-81F3-4568-875A-7E7A598D4C1C/vstor_redist.exe'
 $visStudioToolsexe = 'vstor_redist.exe'
 $outputPath = $LocalPath + '\' + $visStudioToolsexe
 Invoke-WebRequest -Uri $visStudioToolsURL -OutFile $outputPath
 write-host 'AIB Customization: Starting Install the latest Microsoft Visual Studio Tools for Office'
 Start-Process -FilePath $outputPath -Args "/q /norestart" -Wait
 write-host 'AIB Customization: Finished Install the latest Microsoft Visual Studio Tools for Office'

# Cleanup temp directory
Set-location "c:\"
Remove-Item -Path "C:\Temp\VisualStudioTools" -Force -Recurse -ErrorAction SilentlyContinue
