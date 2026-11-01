@echo off
rem Anti burn-in: truly power off the phone panel (virtual display keeps running).
rem   anti-burn.bat        -> turn panel off
rem   anti-burn.bat off    -> wake the screen
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
if /i "%~1"=="off" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0anti-burn.ps1" -Off
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0anti-burn.ps1" -On
)
pause