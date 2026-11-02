@echo off
setlocal
cd /d "%~dp0"
echo Starting uninstaller...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
set RC=%ERRORLEVEL%
echo.
if not "%RC%"=="0" echo Uninstaller exited with code %RC%
echo (window will stay open - press any key to close)
pause >nul