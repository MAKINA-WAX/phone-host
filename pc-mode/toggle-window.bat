@echo off
rem Toggle the mirror window between fullscreen and a 1280x720 window.
rem Bind it to a hotkey with ????.lnk (Ctrl+Alt+F) if you like.
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0window-toggle.ps1"