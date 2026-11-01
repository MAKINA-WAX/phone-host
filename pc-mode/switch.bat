@echo off
rem ??????????????
rem   1 = Linux ???XFCE?
rem   2 = ???? App????
rem   3 = ?????????????????????
chcp 65001 >nul
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
set "ADB=%~dp0..\scrcpy-win64-v5.0.1\adb.exe"
set "SCRCPY=%~dp0..\scrcpy-win64-v5.0.1\scrcpy.exe"
if not exist "%ADB%" set "ADB=adb"
if not exist "%SCRCPY%" set "SCRCPY=scrcpy"

echo ===== ???? =====
echo   1 = Linux ??
echo   2 = ?? App??????
echo   3 = ??????
echo.
choice /c 123 /m "??"
if errorlevel 3 goto mirror
if errorlevel 2 goto app
if errorlevel 1 goto desktop

:desktop
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-xfce.ps1" -Attach
goto end

:app
set /p PKG=??????? com.tencent.mm?:
if "%PKG%"=="" goto end
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-app.ps1" "%PKG%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0focus-scrcpy.ps1"
goto end

:mirror
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mirror-phone.ps1"
goto end

:end
echo.
pause
