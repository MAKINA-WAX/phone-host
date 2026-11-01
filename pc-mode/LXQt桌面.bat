@echo off
rem Start the LXQt desktop on the virtual display (one click).
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-lxqt.ps1"
pause