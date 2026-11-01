#requires -Version 5.1
# Loaded only in the disposable desktop worker. Answers remain literal strings.
if ($env:TOOLKIT_DESKTOP_CHANNEL -notmatch '\A[a-f0-9]{32}\z') { throw 'Desktop answer channel is missing.' }
function global:Read-Host {
    [CmdletBinding()]
    param([Parameter(Position=0)][object]$Prompt = '')
    $question = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$Prompt))
    [Console]::Out.WriteLine('@@TOOLKIT_PROMPT:' + $env:TOOLKIT_DESKTOP_CHANNEL + ':' + $question)
    [Console]::Out.Flush()
    $reply = [Console]::In.ReadLine()
    if ($null -eq $reply) { throw 'Desktop answer channel closed; no answer was supplied.' }
    if ($reply.Length -gt 90000) { throw 'Desktop answer is too long.' }
    return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($reply))
}
