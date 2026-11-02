@echo off
setlocal
cd /d "%~dp0"
echo Starting installer...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set RC=%ERRORLEVEL%
echo.
if not "%RC%"=="0" echo Installer exited with code %RC%
echo (window will stay open - press any key to close)
pause >nul