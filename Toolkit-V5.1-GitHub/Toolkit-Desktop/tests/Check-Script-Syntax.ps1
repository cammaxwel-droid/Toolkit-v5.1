#requires -Version 5.1
# Static parsing only; no desktop worker or toolkit action is invoked.
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
foreach($relative in @('Worker.ps1','PromptBridge.ps1','Generate-Catalog.ps1','Build-Desktop.ps1','tests\Check-Script-Syntax.ps1')) {
    $tokens=$null; $errors=$null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $relative),[ref]$tokens,[ref]$errors)
    if($errors.Count) { throw ($relative+': '+(($errors|ForEach-Object Message)-join '; ')) }
    Write-Output ('PASS: Windows PowerShell 5.1 syntax - '+$relative)
}
