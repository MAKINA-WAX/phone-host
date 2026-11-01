@echo off
rem Switch the virtual display back to the running Linux desktop (no restart)
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-xfce.ps1" -Attach
