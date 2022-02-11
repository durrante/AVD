## Downloads and sets the start menu layout xml file

 # Download and install Start menu layout
 write-host 'AIB Customisation: Downloading Start Menu'
 $appName = 'StartMenu'
 $drive = 'C:\Temp'
 New-Item -Path $drive -Name $appName  -ItemType Directory -ErrorAction SilentlyContinue
 $LocalPath = $drive + '\' + $appName 
 set-Location $LocalPath
 $ClientURL = 'https://letsconfigmgr998.blob.core.windows.net/applications/Windows%20Customisations/Start%20Menu%20Layout/startlayout.xml'
 $Clientexe = 'startlayout.xml'
 $outputPath = $LocalPath + '\' + $Clientexe
 Invoke-WebRequest -Uri $ClientURL -OutFile $outputPath -UseBasicParsing
 write-host 'AIB Customisation: Starting Install of Start Menu Layout'
 Import-StartLayout -LayoutPath c:\\windows\\temp\\startmenu.xml -MountPath $env:SystemDrive\ -verbose
 Start-Sleep 1
 write-host 'AIB Customisation: Finished Installation of start menu'

# Cleanup temp directory
Set-location "c:\"
Remove-Item -Path $outputpath -Force -Recurse -ErrorAction SilentlyContinue
