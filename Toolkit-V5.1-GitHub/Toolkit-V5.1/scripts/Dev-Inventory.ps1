#requires -Version 5.1
Write-Host "`nPYTHON / PACKAGE MANAGERS" -ForegroundColor Cyan
# Deliberately use a variable for the foreach output in Windows PowerShell 5.1.
$rows=@(foreach($tool in @('py','python','node','npm','git','dotnet','cmake','ninja','winget')){
 $cmd=Get-Command $tool -ErrorAction SilentlyContinue | Select-Object -First 1
 [pscustomobject]@{Tool=$tool;Found=[bool]$cmd;Path=if($cmd){$cmd.Source}else{'Not globally on PATH'}}
})
$rows | Format-Table -Wrap
Write-Host "`nINSTALLED .NET SDKs" -ForegroundColor Cyan
if(Get-Command dotnet -ErrorAction SilentlyContinue){dotnet --list-sdks}
Write-Host "`nVISUAL STUDIO BUILD TOOLS" -ForegroundColor Cyan
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if(Test-Path -LiteralPath $vswhere){& $vswhere -products '*' -property installationPath}else{Write-Host 'vswhere not found.'}
Write-Host 'Visual Studio CMake/Ninja may exist without being globally on PATH.'
