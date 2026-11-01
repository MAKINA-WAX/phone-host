@echo off
rem Auto-reconnect: when the phone is replugged, restart the last mirror mode.
rem last-mode.txt remembers what you used last (game-vd / mirror-full / mirror-window / desktop).
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0watch-reconnect.ps1" %*