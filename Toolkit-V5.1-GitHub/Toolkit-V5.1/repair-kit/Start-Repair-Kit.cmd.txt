@echo off
setlocal
cd /d "%~dp0"
title Toolkit V5.1 - Repair Kit
if not exist "%~dp0src\RepairKit.ps1" (
  echo Missing RepairKit.ps1. Extract the whole ZIP.
  pause
  exit /b 1
)
powershell.exe -NoProfile -Command "$u=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()); if(-not $u.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 1}"
if errorlevel 1 (
  echo Right-click Start-Repair-Kit.cmd then Run as administrator.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\RepairKit.ps1"
if errorlevel 1 pause
