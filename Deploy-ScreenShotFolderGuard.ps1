# Screenshot Folder Lock Installer (compatible with PowerShell 5.1)
# Run as the user who will use the computer.

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

# If it exists, delete it
schtasks /Delete /TN $taskName /F > $null 2>&1

# Create hidden task that runs at login and confirms its creation
schtasks /Create `
    /TN "\aj\$taskName" `
    /TR "wscript.exe `"$vbsPath`"" `
    /SC ONLOGON `
    /RL LIMITED `
    /RU $env:USERNAME `
    /F `
    /IT

if ($LASTEXITCODE -ne 0) {
    throw "Error al crear la tarea programada. Código de salida: $LASTEXITCODE"
}

# You should not show this message unless all steps succeeded.

Write-Host ""
Write-Host "==============================================="
Write-Host "   ScreenShotFolderGuard – Instalación completa"
Write-Host "==============================================="
Write-Host ""
Write-Host "La protección de la carpeta de capturas se ha activado correctamente."
Write-Host ""
Write-Host "A partir de ahora:"
Write-Host "  • La carpeta 'Screenshots' permanecerá fija y protegida."
Write-Host "  • El sistema iniciará la protección automáticamente al iniciar sesión."
Write-Host ""
Write-Host "Puede cerrar esta ventana."
Write-Host ""

