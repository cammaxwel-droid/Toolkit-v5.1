#requires -Version 5.1
# Desktop adapter only. The original scripts and their confirmation logic are unchanged.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('\A(?:00[1-9]|0[1-9][0-9]|1[0-7][0-9]|180|R0[1-9]|R[1-4][0-9]|R5[01])\z', Options='None')]
    [string]$ToolId,
    [Parameter(Mandatory=$true)][string]$ToolkitRoot,
    [switch]$ConsoleMode
)
$ErrorActionPreference = 'Stop'
$exitCode = 1
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator access is required. Start Toolkit.Desktop.exe and approve its Windows prompt.'
    }
    $relative = if ($ToolId.StartsWith('R')) { 'repair-kit\src\RepairKit.ps1' } else { 'src\Toolkit.ps1' }
    $entry = Join-Path ([IO.Path]::GetFullPath($ToolkitRoot)) $relative
    if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw 'Toolkit source folder was not found.' }
    if ($ConsoleMode) { throw 'Desktop commands run in the Toolkit window.' }
    [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $OutputEncoding = [Console]::OutputEncoding
    $ProgressPreference = 'SilentlyContinue'
    . (Join-Path $PSScriptRoot 'PromptBridge.ps1')
    # No ElevatedCall, preapproval, rewritten action, or generated command string.
    & $entry -ToolId $ToolId
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    $exitCode = 1
}
exit $exitCode
