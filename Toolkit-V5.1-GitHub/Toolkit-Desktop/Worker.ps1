#requires -Version 5.1
# Desktop adapter only. The original scripts and their confirmation logic are unchanged.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('\A(?:00[1-9]|0[1-9][0-9]|1[0-7][0-9]|180|R0[1-9]|R[1-4][0-9]|R5[01])\z', Options='None')]
    [string]$ToolId,
    [Parameter(Mandatory=$true)][string]$ToolkitRoot,
    [switch]$ConsoleMode,
    [string]$TranscriptPath = ''
)
$ErrorActionPreference = 'Stop'
$exitCode = 1
$transcribing = $false
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator access is required. Start Toolkit.Desktop.exe and approve its Windows prompt.'
    }
    $relative = if ($ToolId.StartsWith('R')) { 'repair-kit\src\RepairKit.ps1' } else { 'src\Toolkit.ps1' }
    $entry = Join-Path ([IO.Path]::GetFullPath($ToolkitRoot)) $relative
    if (-not (Test-Path -LiteralPath $entry -PathType Leaf)) { throw 'Toolkit source folder was not found.' }
    $needsConsole = $ToolId -in @('018','019','020','050','116','121','131','146','149','158','166','R41','R42')
    if ($needsConsole -ne [bool]$ConsoleMode) { throw 'This command requires its assigned desktop or console mode.' }
    if ($ConsoleMode) {
        $Host.UI.RawUI.WindowTitle = 'Toolkit Desktop - ' + $ToolId
        if ($TranscriptPath) {
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($TranscriptPath)))
            Start-Transcript -LiteralPath $TranscriptPath -NoClobber -ErrorAction Stop | Out-Null
            $transcribing = $true
        }
    } else {
        [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
        [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
        $OutputEncoding = [Console]::OutputEncoding
        $ProgressPreference = 'SilentlyContinue'
        . (Join-Path $PSScriptRoot 'PromptBridge.ps1')
    }
    # No ElevatedCall, preapproval, rewritten action, or generated command string.
    & $entry -ToolId $ToolId
    $exitCode = $LASTEXITCODE
    if ($null -eq $exitCode) { $exitCode = 0 }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    $exitCode = 1
} finally {
    if ($ConsoleMode) {
        Write-Host "`nDesktop command $ToolId has returned. Review its output above."
        if ($transcribing) { Stop-Transcript | Out-Null }
        [void](Microsoft.PowerShell.Utility\Read-Host 'Press Enter to return to the desktop app')
    }
}
exit $exitCode
