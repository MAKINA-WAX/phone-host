@echo off
rem Linux desktop UI scale
rem   tu-mian-suo-fang.bat        1.25x (default)
rem   tu-mian-suo-fang.bat 1.5    1.5x
rem   tu-mian-suo-fang.bat 1.0    back to 100%
rem   tu-mian-suo-fang.bat show   show current values
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
if /i "%~1"=="show" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desktop-scale.ps1" -Show
) else if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desktop-scale.ps1" -Scale 1.25
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0desktop-scale.ps1" -Scale %~1
)
pause