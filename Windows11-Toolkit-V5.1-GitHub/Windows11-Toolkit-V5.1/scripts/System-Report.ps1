#requires -Version 5.1
$ErrorActionPreference = 'Continue'
function Get-ReportFolder {
  $docs=[Environment]::GetFolderPath('MyDocuments')
  if(-not $docs -or -not (Test-Path -LiteralPath $docs)){$docs=$env:USERPROFILE}
  $p=Join-Path $docs 'Windows11-ToolkitV3-Reports'
  if(-not (Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
  return $p
}

$out=Join-Path (Get-ReportFolder) ('System-Report-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$sections=[ordered]@{
 'OS / uptime' = {Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,LastBootUpTime | Format-List}
 'Profile paths' = {[pscustomobject]@{Username=$env:USERNAME;Profile=$env:USERPROFILE;Documents=[Environment]::GetFolderPath('MyDocuments')} | Format-List}
 'System / RAM' = {Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,@{N='RAM_GB';E={[math]::Round($_.TotalPhysicalMemory/1GB,2)}} | Format-List}
 'BIOS' = {Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion,ReleaseDate | Format-List}
 'CPU / graphics' = {Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | Format-List;Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion | Format-List}
 'Firmware and device errors' = {Get-PnpDevice | Where-Object Status -eq Error | Select-Object Class,FriendlyName,Problem | Format-Table -Wrap}
 'Storage' = {Get-PhysicalDisk | Select-Object FriendlyName,MediaType,FirmwareVersion,HealthStatus | Format-Table -AutoSize}
 'Free disk space' = {Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter,@{N='Free_GB';E={[math]::Round($_.SizeRemaining/1GB,2)}},@{N='Size_GB';E={[math]::Round($_.Size/1GB,2)}} | Format-Table -AutoSize}
 'RAM overview' = {$os=Get-CimInstance Win32_OperatingSystem;[pscustomobject]@{Available_GB=[math]::Round($os.FreePhysicalMemory/1MB,2);Used_Percent=[math]::Round(100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize),1)} | Format-List}
 'Top running processes' = {Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Name,Id,@{N='WorkingSet_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize}
 'Wi-Fi connection (local link only)' = {netsh wlan show interfaces}
 'Network / proxy' = {Get-NetAdapter | Select-Object Name,Status,LinkSpeed | Format-Table -AutoSize;netsh winhttp show proxy}
 'Last Windows patches (partial)' = {Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 12 HotFixID,InstalledOn | Format-Table -AutoSize}
}
@('Windows 11 System Snapshot';('Created: '+(Get-Date));'Read-only inspection. Personal and device data: do not post publicly.';'') + @(
 foreach($name in $sections.Keys){'='*58;$name;'='*58;try{& $sections[$name] | Out-String -Width 170}catch{'ERROR: '+$_.Exception.Message};''}
) | Set-Content -LiteralPath $out -Encoding UTF8
Write-Host "Saved: $out" -ForegroundColor Green
