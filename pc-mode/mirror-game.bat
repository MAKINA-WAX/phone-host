@echo off
rem Game mode: phone looks off (brightness 0, OLED), gamepad passthrough, fullscreen mirror.
rem 1) plug the controller into the PC first (Xbox works out of the box; PS4/PS5 via DS4Windows)
rem 2) phone must be unlocked when starting
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0game-mode.ps1"
echo.
pause