@echo off
rem Windows 1252 encoding is needed or the script will fail.
rem This batch file is used to deploy the ScreenShotFolderGuard script.
rem Administrator privieges are not required.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Deploy-ScreenShotFolderGuard.ps1"
pause