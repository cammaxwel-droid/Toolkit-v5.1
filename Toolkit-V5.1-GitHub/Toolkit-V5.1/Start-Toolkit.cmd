@echo off
setlocal
cd /d "%~dp0"
title Toolkit V5.1
if not exist "%~dp0src\Toolkit.ps1" (
  echo Missing src\Toolkit.ps1. Extract the entire ZIP first.
  pause
  exit /b 1
)
rem V5.1 intentionally requires right-click Run as administrator from the start.
powershell.exe -NoProfile -Command "$u=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()); if(-not $u.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 1}"
if errorlevel 1 (
  echo.
  echo Toolkit V5.1: Administrator is required.
  echo Close this window, right-click Start-Toolkit.cmd, and choose Run as administrator.
  echo No settings have been changed.
  pause
  exit /b 1
)
rem Execution policy override applies only to this PowerShell process.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Toolkit.ps1"
if errorlevel 1 (
  echo Toolkit returned an error. Please review it above.
  pause
)
