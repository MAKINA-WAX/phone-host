@echo off
rem Bring the mirror window back to the front (it is a normal window, so clicking
rem the browser covers it). Run this whenever the phone screen "disappears".
setlocal
set "TEMP=%~dp0tmp"
set "TMP=%~dp0tmp"
if not exist "%TEMP%" mkdir "%TEMP%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0focus-scrcpy.ps1"
