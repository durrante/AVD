# Start Log
$Context.Log("Starting uninstallation...")

# Get the installer path from Nerdio
try {
    $installerPath = $Context.GetAttachedBinary()
    $Context.Log("Installer binary downloaded successfully. Path: $installerPath")
}
catch {
    $Context.Log("Error downloading installer binary: " + $_.Exception.Message)
    throw
}

# Define temporary working directories
$tempDir = "C:\AppTemp"

# Ensure temporary directory exists
try {
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -ErrorAction Stop | Out-Null
        $Context.Log("Temporary directory created: $tempDir")
    } else {
        $Context.Log("Temporary directory already exists: $tempDir")
    }
}
catch {
    $Context.Log("Error creating or verifying temporary directory: " + $_.Exception.Message)
    throw
}

# Unzip the file to the temporary directory
try {
    $Context.Log("Extracting zip file to temporary directory...")
    Expand-Archive -LiteralPath $installerPath -DestinationPath $tempDir -Force
    $Context.Log("Zip file extracted successfully to: $tempDir")
}
catch {
    $Context.Log("Error during zip file extraction: " + $_.Exception.Message)
    throw
}

# Append the Deploy-Application.exe to the installer path
try {
    $Context.Log("Locating Deploy-Application.exe...")
    $deployExecutable = Join-Path -Path $tempDir -ChildPath "Deploy-Application.exe"
    $Context.Log("Executable path set to: $deployExecutable")
}
catch {
    $Context.Log("Error constructing executable path: " + $_.Exception.Message)
    throw
}

# Uninstall application
try {
    $Context.Log("Preparing to execute uninstaller...")
    $commandToExecute = "`"$deployExecutable`" -DeploymentType uninstall"
    $Context.Log("Command to execute: $commandToExecute")
    
    Start-Process -FilePath "`"$deployExecutable`"" -ArgumentList "-DeploymentType uninstall" -Wait -ErrorAction Stop
    
    $Context.Log("Uninstallation command executed successfully.")
    $Context.Log("Uninstallation completed successfully.")
}
catch {
    $Context.Log("Error during uninstallation execution: " + $_.Exception.Message)
    throw
}

# Cleanup temporary files
try {
    $Context.Log("Cleaning up temporary files...")
    Remove-Item -Path $tempDir -Force -Recurse -ErrorAction SilentlyContinue
    $Context.Log("Temporary files cleaned up successfully.")
}
catch {
    $Context.Log("Error during cleanup: " + $_.Exception.Message)
}