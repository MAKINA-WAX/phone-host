@echo off
rem tell the reconnect watcher to stay quiet until a mode is started again
echo paused > "%~dp0paused.flag"
rem Stop PC mode CLEANLY: close the mirror, kill the scrcpy server on the phone,
rem so no orphan virtual display / server process is left behind
rem (leftovers are what made the phone stutter and flicker).
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
set "ADB=%~dp0..\scrcpy-win64-v5.0.1\adb.exe"
if not exist "%ADB%" set "ADB=adb"

echo [1/3] closing scrcpy window...
taskkill /IM scrcpy.exe /F >nul 2>nul

echo [2/3] killing scrcpy server on the phone...
"%ADB%" -d shell "pkill -f com.genymobile.scrcpy" >nul 2>nul
"%ADB%" -d shell "pkill -f scrcpy" >nul 2>nul
timeout /t 2 /nobreak >nul

echo [3/3] checking state...
echo displays:
"%ADB%" -d shell "dumpsys display | grep -o -E 'displayId [0-9]+' | sort -u"
echo home app:
"%ADB%" -d shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME" | findstr /i "Launcher HSL"
echo Done. Only displayId 0 should be left.
