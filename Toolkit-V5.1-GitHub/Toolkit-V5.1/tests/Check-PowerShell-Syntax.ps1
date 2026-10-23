#requires -Version 5.1
# Syntax-only parser check: does not dot-source or run toolkit actions.
$root = Split-Path -Parent $PSScriptRoot
$files = @(Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse -File)
$failures = 0
foreach ($file in $files) {
    $tokens=$null
    $errors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $failures++
        Write-Host "ERROR: $($file.FullName)" -ForegroundColor Red
        foreach($e in $errors) {Write-Host "  $($e.Extent.StartLineNumber):$($e.Extent.StartColumnNumber) $($e.Message)" -ForegroundColor Red}
    } else {Write-Host "PASS: $($file.FullName)" -ForegroundColor Green}
}
if ($files.Count -eq 0) {Write-Host 'ERROR: No PowerShell scripts were found.' -ForegroundColor Red;exit 2}
Write-Host "Checked $($files.Count) scripts; syntax failures $failures."
if ($failures -gt 0) {exit 1}

# V5.1: Check that all catalogue IDs are unique without importing/running toolkit.
$main = Join-Path $root 'src\Toolkit.ps1'
$source = Get-Content -LiteralPath $main -Raw -ErrorAction Stop
$ids = [regex]::Matches($source, "Add-ToolkitTool\s+-Id\s+'(\d{3})'") | ForEach-Object { $_.Groups[1].Value }
$duplicates = @($ids | Group-Object | Where-Object Count -gt 1)
if ($ids.Count -ne 180 -or $duplicates.Count -gt 0) {
  Write-Host "ERROR: Action IDs expected 180 unique entries; found $($ids.Count), duplicates $($duplicates.Count)" -ForegroundColor Red
  exit 1
}
Write-Host "PASS: $($ids.Count) unique main-menu IDs." -ForegroundColor Green


# The separate Repair Kit retains all 51 action IDs.
$repair = Get-Content -LiteralPath (Join-Path $root 'repair-kit\src\RepairKit.ps1') -Raw -ErrorAction Stop
$repairIds = [regex]::Matches($repair, "Add-RepairTool\s+-Id\s+'(R\d{2})'") | ForEach-Object { $_.Groups[1].Value }
if ($repairIds.Count -ne 51 -or @($repairIds | Sort-Object -Unique).Count -ne 51) {
    Write-Host 'ERROR: Expected 51 unique Repair Kit IDs.' -ForegroundColor Red
    exit 1
}
Write-Host 'PASS: 51 unique Repair Kit IDs.' -ForegroundColor Green
