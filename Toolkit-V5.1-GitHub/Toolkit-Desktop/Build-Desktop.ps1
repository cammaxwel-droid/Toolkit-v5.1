#requires -Version 5.1
param([switch]$Verify)
$ErrorActionPreference='Stop'
Push-Location $PSScriptRoot
try {
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Generate-Catalog.ps1')
    if($LASTEXITCODE -ne 0) {throw 'Catalog generation failed.'}
    & dotnet publish (Join-Path $PSScriptRoot 'Toolkit.Desktop.csproj') -c Release -r win-x64 --self-contained false -o (Join-Path $PSScriptRoot 'app') --nologo
    if($LASTEXITCODE -ne 0) {throw 'Desktop build failed.'}
    if($Verify) {
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tests\Check-Script-Syntax.ps1')
        if($LASTEXITCODE -ne 0) {throw 'Desktop script syntax checks failed.'}
        & dotnet run --project (Join-Path $PSScriptRoot 'tests\Toolkit.Desktop.Checks.csproj') -c Release
        if($LASTEXITCODE -ne 0) {throw 'Desktop checks failed.'}
    }
    $package=Join-Path $PSScriptRoot 'app'
    $manifest=@(Get-ChildItem -LiteralPath $package -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object { '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant(),$_.Name })
    [IO.File]::WriteAllLines((Join-Path $package 'SHA256SUMS.txt'),$manifest,(New-Object Text.UTF8Encoding($false)))
    Write-Output 'Ready: Toolkit-Desktop\app\Toolkit.Desktop.exe (Windows will request Administrator access).'
} finally {Pop-Location}
