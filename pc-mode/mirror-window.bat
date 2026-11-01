@echo off
rem Phone mirror in a NORMAL window: title bar, drag with the mouse, resize by edges.
rem Left click = tap (sdk mouse), right click = back, wheel = scroll.
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mirror-phone.ps1" -Mode window -Mouse sdk
echo.
echo Window mode: drag the title bar to move, drag edges to resize.
pause
