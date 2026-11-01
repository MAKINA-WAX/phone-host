@echo off
rem Close everything: mirror + watcher + tray + disable the scheduled task.
rem (Use stop-pc.bat if you only want to pause.)
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0shutdown-all.ps1"
pause