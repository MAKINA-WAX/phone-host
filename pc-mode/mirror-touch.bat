@echo off
rem ============================================================
rem  Touch mirror: --mouse=sdk injects real touch events.
rem  Prereq: developer options -> "USB debugging (Security settings)"
rem ============================================================
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
set "ADB=%~dp0..\scrcpy-win64-v5.0.1\adb.exe"
if not exist "%ADB%" set "ADB=adb"

echo [1/2] checking input injection permission...
"%ADB%" -d shell "input keyevent 0" > "%TEMP%\inject-test.txt" 2>&1
findstr /i "SecurityException INJECT_EVENTS" "%TEMP%\inject-test.txt" >nul
if not errorlevel 1 (
  echo.
  echo [X] No input injection permission. sdk mouse will not work.
  echo     On the phone: Settings ^> Additional settings ^> Developer options
  echo     ^> turn ON "USB debugging [Security settings]", allow the popup,
  echo     then run this script again.
  echo.
  pause
  exit /b 1
)

echo [2/2] starting touch-injection mirror...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mirror-phone.ps1" -Mouse sdk
echo.
echo Left click = tap, right click = back, wheel = scroll.
pause
