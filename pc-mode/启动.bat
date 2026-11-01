@echo off
rem re-enable the watchdog task and clear the pause flag
schtasks /change /tn "PhoneHost-WatchReconnect" /enable >nul 2>nul
del /q "%~dp0paused.flag" 2>nul
rem start the auto-reconnect watcher (single instance) 
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0watch-reconnect.ps1"
rem restore last used mode (lxqt/desktop/mirror) when idle
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0restore-last-mode.ps1"
rem system tray controller (right-click for detect / start mirroring)
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0tray.ps1"
rem ???????? ?? PC ??????????????????
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0pc-launcher.ps1"
