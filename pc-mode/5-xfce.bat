@echo off
rem Start the real Linux desktop (XFCE) and show it fullscreen on the virtual display.
rem Prereq: 2-start-pc.bat already running (it creates the virtual display).
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-xfce.ps1"
echo.
echo This is a real X11 desktop: drag windows with the mouse, double-click a title bar to maximize.
echo Right-click the desktop for the menu; the panel at the bottom is the taskbar.
pause
