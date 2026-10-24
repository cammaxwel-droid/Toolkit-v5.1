#requires -Version 5.1
$ErrorActionPreference = 'Continue'
function Get-ReportFolder {
  $docs=[Environment]::GetFolderPath('MyDocuments')
  if(-not $docs -or -not (Test-Path -LiteralPath $docs)){$docs=$env:USERPROFILE}
  $p=Join-Path $docs 'Toolkit-Reports'
  if(-not (Test-Path -LiteralPath $p)){New-Item -ItemType Directory -Path $p -Force|Out-Null}
  return $p
}

$out=Join-Path (Get-ReportFolder) ('Security-Report-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$sections = [ordered]@{
 'Defender protection' = {Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,QuickScanEndTime | Format-List}
 'Defender preferences' = {Get-MpPreference | Select-Object EnableControlledFolderAccess,PUAProtection,DisableRealtimeMonitoring | Format-List}
 'Firewall profiles' = {Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction | Format-Table -AutoSize}
 'TPM' = {Get-Tpm | Select-Object TpmPresent,TpmReady,TpmEnabled,TpmActivated | Format-List}
 'Secure Boot' = {Confirm-SecureBootUEFI}
 'BitLocker C drive' = {manage-bde -status C:}
}
@('Toolkit Security Snapshot';('Created: '+(Get-Date));'Read-only inspection. Do NOT upload private system reports to public GitHub.';'') + @(
 foreach($name in $sections.Keys){'='*58;$name;'='*58;try{& $sections[$name] | Out-String -Width 170}catch{'ERROR: '+$_.Exception.Message};''}
) | Set-Content -LiteralPath $out -Encoding UTF8
Write-Host "Saved: $out" -ForegroundColor Green
