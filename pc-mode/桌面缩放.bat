@echo off
rem Linux desktop UI scaling. Usage:
rem   ????.bat          2x (recommended)
rem   ????.bat 1.5      1.5x
rem   ????.bat show     show current values
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
if /i "%~1"=="show" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desktop-scale.ps1" -Show
) else if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desktop-scale.ps1" -Scale 2
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desktop-scale.ps1" -Scale %~1
)
pause