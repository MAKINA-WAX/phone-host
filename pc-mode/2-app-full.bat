@echo off
rem Open an app FULLSCREEN on the virtual display (fills 16:10, layout adapts like a PC app)
rem Usage:  2-app-full.bat com.android.settings
rem         (no argument = Chrome)
setlocal
set "APP=%~1"
if "%APP%"=="" set "APP=com.android.chrome"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-app.ps1" "%APP%"
