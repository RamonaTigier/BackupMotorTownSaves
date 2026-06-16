@echo off
setlocal

REM Start PowerShell silently and run the script
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BackupMotorTownSaves.ps1"

endlocal
exit
