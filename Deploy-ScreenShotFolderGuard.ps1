<#
    .SYNOPSIS
        Install a protection mechanism for the Screenshots folder using a hidden
        VBScript and a scheduled task.
    .DESCRIPTION
        This script creates a hidden .anchor file in the Screenshots folder and a
        VBScript that continuously checks for its existence. A scheduled task is set
        up to run the VBScript at user logon, ensuring the protection is active 
        at all times.
    .USE
        Eventhough you can run this script from console, it is desinged to be executed
        by double-clicking the Setup.link, which will open a console window and run
        this script.
		Not elevated permissions needed.
    .NOTES
        ProgramData is used to store the VBScript to ensure it is hidden from the user
        but reachable by the scheduled task.
        The script is idempotent, meaning it can be run multiple times without causing
        issues or creating duplicate tasks.
        ComObject "Schedule.Service" is used beacause it provides RestartOnIdle property.
    .DEPENDENCIES
        It is compatible with PowerShell 5.1 and later.
        UTF8-BOOM encoding to ensure special characters are handled correctly.
        Otherwise the results on conlsoles with different locales may look inconsistent.      
#>

# Avoid scripting errors to exit the scipt at every step.
$ErrorActionPreference = "Stop"

Write-Host "Installing Screenshots folder protection..."

# Locate or create the Screenshots folder
$pictures = [Environment]::GetFolderPath("MyPictures")
$screens = Join-Path $pictures "Screenshots"
Write-Host "Deafault folder: $screens"

if (-not (Test-Path $screens)) {
    Write-Host "Folder not found. Creating it..."
    New-Item -Path $screens -ItemType Directory
}

# Create .anchor file
$anchor = Join-Path $screens ".anchor"
if (-not (Test-Path $anchor)) {
    Write-Host "Creating anchor file..."
    New-Item -Path $anchor -ItemType File
}

# Create VBScript in ProgramData
$vbsPath = Join-Path $env:ProgramData "screenshots_folder_bloker.vbs"
Write-Host "Creating VBScript at $vbsPath..."

$vbs = @"
Set fso = CreateObject("Scripting.FileSystemObject")
Set anchor = fso.OpenTextFile("$anchor", 1)
Do
  WScript.Sleep 60000
Loop
"@

$vbs | Set-Content -Path $vbsPath -Encoding ASCII

# Hide files
Write-Host "Hidding files $vbsPath and $anchor"
(Get-Item $vbsPath -Force).Attributes += 'Hidden'
(Get-Item $anchor -Force).Attributes += 'Hidden'

# Call New-SSFGTask.ps1 
# This is tha part that needs elevated permissions
Write-Host "Creating the task"
$scriptPath =".\New-SSFGTask.ps1"
if ($scriptPath) {
	Write-Host "$scriptPath exists"
}


# First I used Start-Process to get elevated privileges
# Later i managed to do it without them but I prefer to keep this part separated.
Start-Process powershell.exe -ArgumentList @(
"-ExecutionPolicy", "Bypass",
"-File", "$scriptPath",
"-userName", "$env:USERNAME",
"-vbsPath", "$vbsPath" 
)


