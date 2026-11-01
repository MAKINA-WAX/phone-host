@echo off
rem Stop the XFCE desktop (keeps the mirror window and the virtual display running)
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-xfce.ps1" -Stop
