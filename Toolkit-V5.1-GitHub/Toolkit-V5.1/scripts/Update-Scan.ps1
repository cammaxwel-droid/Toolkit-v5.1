#requires -Version 5.1
$ErrorActionPreference = 'Continue'
function Get-ReportFolder {
  $docs=[Environment]::GetFolderPath('MyDocuments')
  if(-not $docs -or -not (Test-Path -LiteralPath $docs)){$docs=$env:USERPROFILE}
  $p=Join-Path $docs 'ToolkitV3-Reports'
  if(-not (Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
  return $p
}

$out=Join-Path (Get-ReportFolder) ('Update-Scan-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$lines=New-Object System.Collections.Generic.List[string]
$lines.Add('TOOLKIT V3 - UPDATES SCAN (READ ONLY)')
$lines.Add('Created: '+(Get-Date))
$lines.Add('WinGet scans recognised apps only; drivers are installed-version inventory, not online vendor comparison.')
$lines.Add('')
$lines.Add('=== WinGet available APP upgrades ===')
if(Get-Command winget -ErrorAction SilentlyContinue){
  try{$output=@(winget upgrade 2>&1 | Out-String);$lines.Add(($output -join "`n"))}
  catch{$lines.Add('WinGet error: '+$_.Exception.Message)}
}else{$lines.Add('WinGet is unavailable.')}
$lines.Add('')
$lines.Add('=== Device errors ===')
try{$lines.Add(((Get-PnpDevice | Where-Object Status -eq Error | Select-Object FriendlyName,Class,Problem | Format-Table -Wrap | Out-String -Width 170)))}catch{$lines.Add($_.Exception.Message)}
$lines.Add('')
$lines.Add('=== Key installed driver versions ===')
try{$lines.Add(((Get-CimInstance Win32_PnPSignedDriver | Where-Object DeviceName -match 'Intel.*(Graphics|Wireless|Bluetooth|Management Engine)|Thunderbolt|Realtek' | Select-Object DeviceName,DriverVersion,DriverDate | Format-Table -Wrap | Out-String -Width 170)))}catch{$lines.Add($_.Exception.Message)}
$lines.Add('')
$lines.Add('=== How to check the latest driver ===')
$lines.Add('Windows Update > Advanced options > Optional updates > Driver updates')
$lines.Add('Lenovo System Update or official manufacturer support page for exact machine')
$lines.Add('Never install a BIOS / Thunderbolt / SSD firmware update from this script.')
$lines | Set-Content -LiteralPath $out -Encoding UTF8
Write-Host "Report saved: $out" -ForegroundColor Green
