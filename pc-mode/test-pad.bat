@echo off
rem Live XInput gamepad test: press buttons and watch the values change.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-pad.ps1"
pause