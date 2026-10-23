#requires -Version 5.1
# Repairs the Windows component store, then protected system files ONLY after DISM succeeds.
# Run elevated. Usually only needed if health checks found damage.
$who=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if(-not $who.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
 Write-Host 'Open Windows Terminal as Administrator to repair Windows.' -ForegroundColor Yellow
 return
}
Write-Host 'Running DISM RestoreHealth. May need internet. This can take time.' -ForegroundColor Cyan
& DISM.exe /Online /Cleanup-Image /RestoreHealth
if($LASTEXITCODE -ne 0){Write-Host "DISM failed (exit $LASTEXITCODE). SFC not started; inspect the error." -ForegroundColor Red;return}
Write-Host 'DISM succeeded. Running SFC /scannow.' -ForegroundColor Cyan
& sfc.exe /scannow
Write-Host "SFC completed with exit code $LASTEXITCODE. Read the final SFC message above."
