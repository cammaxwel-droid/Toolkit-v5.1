@echo off
setlocal
if not exist "%~dp0Toolkit-Desktop\app\Toolkit.Desktop.exe" (
  echo Build the desktop app first with Toolkit-Desktop\Build-Desktop.ps1.
  pause
  exit /b 1
)
start "" "%~dp0Toolkit-Desktop\app\Toolkit.Desktop.exe"
