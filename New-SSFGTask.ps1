<#
.SYNOPSIS
    Create a task using com objec
.DESCRIPTION
    Takes $userName and $scriptPath to create a task.
    The tashk is run by $userName
    The trigguer is $userName logon
    The action is to run $scriptPath
.NOTES
    Elevated permision is needed
    File Name  : New-SSFGTask.ps1
    Author     : Tomas 
.EXAMPLE
    Start-Process powershell.exe -ArgumentList @(
    "-ExecutionPolicy", "Bypass",
    "-File", ".\New-SSFGTask.ps1",
    "-userName", "$env:USERNAME",
    "-vbsPaht", "$vbsPath" 
    ) -Verb RunAs -Wait
.EXAMPLE
    The second example - more text documentation
    This would be an example calling the script differently. You can have lots
    and lots, and lots of examples if this is useful.
    Appears in -detailed and -full
.INPUTTYPE
   Input type  [string]
.RETURNVALUE
   Output type  No output
#>
param (
    [string]$userName,
    [string]$vbsPath
)


$taskName = "BloqueoScreenshots"
$userId = $env:COMPUTERNAME + "\" + $userName 

Write-Host @"
Creating scheduled task..."
Task parameters:
Name: \aj\$taskName
Action: wscript.exe `"$vbsPath`"
"@


Write-Host "Connecting with scheduled task service"
$service = New-Object -ComObject "Schedule.Service"
$service.Connect()

Write-Host "Getting root folder"
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

Write-Host "Creating task definition"
$task = $service.NewTask(0)

Write-Host "General information"
$task.RegistrationInfo.Description = "Proteccion de carpeta mediante VBS"
$task.Settings.Enabled = $true
$task.Settings.Hidden  = $false

# --- IMPORTANT CONDITIONS ---
Write-Host "Allow execution with battery power (laptops)"
$task.Settings.DisallowStartIfOnBatteries = $false
$task.Settings.StopIfGoingOnBatteries = $false

Write-Host "Do not stop if it leaves the idle state"
$task.Settings.IdleSettings.StopOnIdleEnd = $false
$task.Settings.IdleSettings.RestartOnIdle = $false

Write-Host "Do not depend on the idle state"
$task.Settings.RunOnlyIfIdle = $false

Write-Host "Execute even if the user is active"
$task.Settings.RunOnlyIfNetworkAvailable = $false

Write-Host "Trigger ONLOGON"
$trigger = $task.Triggers.Create(9)   # 9 = ONLOGON
$trigger.UserId = "$userId"

Write-Host "Action: run wscript with the VBS"
$action = $task.Actions.Create(0)     # 0 = ejecutar programa
$action.Path = "wscript.exe"
$action.Arguments = "`"$vbsPath`""

Write-Host "Registering the task"
# Flags = 6 → create or update
# LogonType = 3 → InteractiveToken (equivalent to /IT)
try {
	
	$folder.RegisterTaskDefinition(
		$taskName,
		$task,
		6,
		$userName,
		$null,
		3
	)
	
	Write-Host @"
===============================================
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
	
	Read-Host -Prompt "Press Enter to continue"
	Exit 0
} catch {
	Write-Error "Failed to register the task"
	Read-Host -Prompt "Press Enter to continue"
	Exit 1
}