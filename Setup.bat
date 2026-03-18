@echo off
rem Windows 1252 encoding is needed or the script will fail.
rem Check the last line. Perhaps you are changing once here and once in the PS1 file.
rem This batch file is used to deploy the ScreenShotFolderGuard script.
rem Administrator privieges are required.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Deploy-ScreenShotFolderGuard.ps1"
pause