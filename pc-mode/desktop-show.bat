@echo off
rem Show the Linux desktop that is already running on the phone onto the PC.
rem Creates a virtual display if needed, then opens Termux:X11 on it.
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desktop-show.ps1"
pause