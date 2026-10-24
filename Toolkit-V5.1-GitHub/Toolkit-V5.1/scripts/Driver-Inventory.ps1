#requires -Version 5.1
$ErrorActionPreference = 'Continue'
function Get-ReportFolder {
  $docs=[Environment]::GetFolderPath('MyDocuments')
  if(-not $docs -or -not (Test-Path -LiteralPath $docs)){$docs=$env:USERPROFILE}
  $p=Join-Path $docs 'Toolkit-Reports'
  if(-not (Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
  return $p
}

$out=Join-Path (Get-ReportFolder) ('Installed-Drivers-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$drivers=@(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
  Where-Object DeviceName |
  Select-Object DeviceName,DeviceClass,DriverProviderName,DriverVersion,DriverDate,InfName)
if($drivers.Count){$drivers | Sort-Object DeviceClass,DeviceName | Export-Csv -LiteralPath $out -Encoding UTF8 -NoTypeInformation;Write-Host "Saved $($drivers.Count) driver records: $out" -ForegroundColor Green}
else{Write-Host 'No driver inventory available.' -ForegroundColor Yellow}
Write-Host 'This lists INSTALLED versions only. For newest versions use Windows Optional Updates or Lenovo/Intel support.'
