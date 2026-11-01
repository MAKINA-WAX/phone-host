@echo off
rem Resume the auto-reconnect watcher after a manual close (clears paused.flag)
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
del /q "%~dp0paused.flag" 2>nul
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0watch-reconnect.ps1"
echo Watcher resumed.