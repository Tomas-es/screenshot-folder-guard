<#
    .SYNOPSIS
        Install a protection mechanism for the Screenshots folder using a hidden
        VBScript and a scheduled task.
    .DESCRIPTION
        This script creates a hidden .ancla file in the Screenshots folder and a
        VBScript that continuously checks for its existence. A scheduled task is set
        up to run the VBScript at user logon, ensuring the protection is active 
        at all times.
    .USE
        Eventhough you can run this script from console, it is desinged to be executed
        by double-clicking the Setup.link, which will open a console window and run
        this script with the necessary permissions.
    .NOTES
        ProgramData is used to store the VBScript to ensure it is hidden from the user
        but reachable by the scheduled task.
        The script is idempotent, meaning it can be run multiple times without causing
        issues or creating duplicate tasks.
        ComObject "Schedule.Service" is used beacause it provides RestartOnIdle property.
        If not, Powershell ScheduledTasks Module could be used.   
    .DEPENDENCIES
        This script requires administrator privileges to create the scheduled task.
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
$anchor = Join-Path $screens ".ancla"
if (-not (Test-Path $anchor)) {
    Write-Host "Creating anchor file..."
    New-Item -Path $anchor -ItemType File
}

# Create VBScript in ProgramData
$vbsPath = Join-Path $env:ProgramData "bloqueo_screenshots.vbs"
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
(Get-Item $vbsPath).Attributes += 'Hidden'
(Get-Item $anchor).Attributes += 'Hidden'

# Create scheduled task with schtasks (maximum compatibility)
$taskName = "BloqueoScreenshots"


# Create hidden task that runs at login and confirms its creation
Write-Host @"
Creating scheduled task..."
Task parameters:
Name: \aj\$taskName
Action: wscript.exe `"$vbsPath`"
"@


# Connect with scheduled task service
$service = New-Object -ComObject "Schedule.Service"
$service.Connect()

# Get root folder
$root = $service.GetFolder("\")
try {
    $folder = $root.GetFolder("aj")
} catch {
    $folder = $root.CreateFolder("aj", $null)
}

# Remove task if it exists to avoid duplicates and ensure idempotency
Write-Host "Removing existing task (if any)..."
try {
    $folder.DeleteTask($taskName, 0)
} catch {
    # Ignore if it does not exist
}

# Create task definition
$task = $service.NewTask(0)

# General information
$task.RegistrationInfo.Description = "Proteccion de carpeta mediante VBS"
$task.Settings.Enabled = $true
$task.Settings.Hidden  = $false

# --- IMPORTANT CONDITIONS ---
# Allow execution with battery power (laptops)
$task.Settings.DisallowStartIfOnBatteries = $false
$task.Settings.StopIfGoingOnBatteries = $false

# Do not stop if it leaves the idle state
$task.Settings.IdleSettings.StopOnIdleEnd = $false
$task.Settings.IdleSettings.RestartOnIdle = $false

# Do not depend on the idle state
$task.Settings.RunOnlyIfIdle = $false

# Execute even if the user is active
$task.Settings.RunOnlyIfNetworkAvailable = $false

# Trigger ONLOGON
$trigger = $task.Triggers.Create(9)   # 9 = ONLOGON

# Action: run wscript with the VBS
$action = $task.Actions.Create(0)     # 0 = ejecutar programa
$action.Path = "wscript.exe"
$action.Arguments = "`"$vbsPath`""

# Register the task
# Flags = 6 → create or update
# LogonType = 3 → InteractiveToken (equivalent to /IT)
$folder.RegisterTaskDefinition(
    $taskName,
    $task,
    6,
    $env:USERNAME,
    $null,
    3
)

# You should not show this message unless all steps succeeded.

Write-Host @"
===============================================
   ScreenShotFolderGuard - Instalación completa
===============================================

La protección de la carpeta de capturas se ha activado correctamente.

A partir de ahora:
  • La carpeta 'Screenshots' permanecerá fija y protegida.
  • El sistema iniciará la protección automáticamente al iniciar sesión.

Puede cerrar esta ventana.
Gracias por usar ScreenShotFolderGuard.
"@