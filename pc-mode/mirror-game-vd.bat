@echo off
rem ============================================================
rem  Anti burn-in game mode: run the game on a VIRTUAL display,
rem  really power the phone panel off (DOZE), keep mirroring.
rem  The game must be able to render on a secondary display.
rem ============================================================
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
set "PKG=%~1"
if "%PKG%"=="" set "PKG=com.kurogame.mingchao"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0game-vd.ps1" -Package %PKG%
echo.
pause