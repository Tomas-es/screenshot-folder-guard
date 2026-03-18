# Screenshot Folder Lock Installer (compatible with PowerShell 5.1)
# Use the .
# UTF8-BOOM encoding to ensure special characters are handled correctly.
# Otherwise the results on conlsoles with different locales may look inconsistent.

# Avoid scripting errors to exit the scipt at every step.
$ErrorActionPreference = "Stop"

Write-Host "Installing Screenshots folder protection..."

# 1. Locate or create the Screenshots folder
$pictures = [Environment]::GetFolderPath("MyPictures")
$screens = Join-Path $pictures "Screenshots"
Write-Host "Deafault folder: $screens"

if (-not (Test-Path $screens)) {
    Write-Host "Folder not found. Creating it..."
    New-Item -Path $screens -ItemType Directory
}

# 2. Create .anchor file
$anchor = Join-Path $screens ".ancla"
if (-not (Test-Path $anchor)) {
    Write-Host "Creating anchor file..."
    New-Item -Path $anchor -ItemType File
}

# 3. Create VBScript in ProgramData
$vbsPath = Join-Path $env:ProgramData "bloqueo_screenshots.vbs"
Write-Host "Creating VBScript at $vbsPath..."

$vbs = @"
Set fso = CreateObject("Scripting.FileSystemObject")
Set anchor = fso.OpenTextFile("$anchor", 1)
Do
  WScript.Sleep 60000
Loop
"@

$vbs | Set-Content -Path $vbsPath -Encoding ASCII -ErrorAction Stop

# 4. Hide files
attrib +h "$anchor"
attrib +h "$vbsPath"

# 5. Create scheduled task with schtasks (maximum compatibility)
$taskName = "BloqueoScreenshots"


# Create hidden task that runs at login and confirms its creation
Write-Host "Creating scheduled task..."
Write-Host "Task parameters:"
Write-Host "  Name: \aj\$taskName"
Write-Host "  Action: wscript.exe `"$vbsPath`""


# Conectar con el servicio del Programador
$service = New-Object -ComObject "Schedule.Service"
$service.Connect()

# Obtener carpeta raíz
$root = $service.GetFolder("\")
try {
    $folder = $root.GetFolder("aj")
} catch {
    $folder = $root.CreateFolder("aj", $null)
}

# Eliminar tarea si existe
Write-Host "Removing existing task (if any)..."
try {
    $folder.DeleteTask($taskName, 0)
} catch {
    # Ignorar si no existe
}

# Crear definición de la tarea
$task = $service.NewTask(0)

# Información general
$task.RegistrationInfo.Description = "Proteccion de carpeta mediante VBS"
$task.Settings.Enabled = $true
$task.Settings.Hidden  = $false

# --- CONDICIONES IMPORTANTES ---
# Permitir ejecución con batería
$task.Settings.DisallowStartIfOnBatteries = $false
$task.Settings.StopIfGoingOnBatteries = $false

# No detener si deja de estar inactivo
$task.Settings.IdleSettings.StopOnIdleEnd = $false
$task.Settings.IdleSettings.RestartOnIdle = $false

# No depende del estado idle
$task.Settings.RunOnlyIfIdle = $false

# Ejecutar incluso si el usuario está activo
$task.Settings.RunOnlyIfNetworkAvailable = $false

# Trigger ONLOGON
$trigger = $task.Triggers.Create(9)   # 9 = ONLOGON

# Acción: ejecutar wscript con el VBS
$action = $task.Actions.Create(0)     # 0 = ejecutar programa
$action.Path = "wscript.exe"
$action.Arguments = "`"$vbsPath`""

# Registrar la tarea
# Flags = 6 → crear o actualizar
# LogonType = 3 → InteractiveToken (equivalente a /IT)
$folder.RegisterTaskDefinition(
    $taskName,
    $task,
    6,
    $env:USERNAME,
    $null,
    3
)

# You should not show this message unless all steps succeeded.

Write-Host ""
Write-Host "==============================================="
Write-Host "   ScreenShotFolderGuard - Instalación completa"
Write-Host "==============================================="
Write-Host ""
Write-Host "La protección de la carpeta de capturas se ha activado correctamente."
Write-Host ""
Write-Host "A partir de ahora:"
Write-Host "  • La carpeta 'Screenshots' permanecerá fija y protegida."
Write-Host "  • El sistema iniciará la protección automáticamente al iniciar sesión."
Write-Host ""
Write-Host "Puede cerrar esta ventana."
Write-Host "Gracias por usar ScreenShotFolderGuard."