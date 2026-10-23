#requires -Version 5.1
# Synthetic saved-data checks. Never import an application entrypoint or maintenance module.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script:checks = 0

function Assert-Check {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw ('FAIL: '+$Message) }
    $script:checks++
    Write-Host ('PASS: '+$Message)
}
function Assert-Throws {
    param([scriptblock]$Operation, [string]$Pattern, [string]$Message)
    $caught = $null
    try { & $Operation | Out-Null } catch { $caught = $_.Exception.Message }
    Assert-Check ($null -ne $caught -and $caught -match $Pattern) $Message
}
function Get-ReviewedDefinitions {
    param([string]$Path, [string[]]$Names)
    $tokens=$null; $errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw ('Syntax errors in '+$Path)}
    $definitions=@($ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true) | Where-Object {$_.Name -in $Names})
    if($definitions.Count -ne $Names.Count){throw 'Reviewed function definitions are missing or duplicated.'}
    return (($definitions | ForEach-Object {$_.Extent.Text}) -join "`n")
}

# Only these reviewed functions are loaded; all their paths are supplied by fixtures.
$helperNames=@('Get-ToolkitReportFiles','Read-ToolkitHistory','Test-ToolkitSnapshotSchema','Resolve-ToolkitUndoFile','Open-ToolkitReports')
. ([scriptblock]::Create((Get-ReviewedDefinitions (Join-Path $root 'modules\Toolkit-Compatibility.ps1') $helperNames)))
. ([scriptblock]::Create((Get-ReviewedDefinitions (Join-Path $root 'modules\V4-Extras.ps1') @('Compare-SystemBaseline'))))

# Test doubles prevent windows from opening and provide controlled menu choices.
$script:opened=@()
$script:answers=New-Object 'System.Collections.Generic.Queue[string]'
function Start-Process { param([string]$FilePath) $script:opened += $FilePath }
function Read-Host { param([string]$Prompt) if($script:answers.Count -eq 0){throw ('Unexpected prompt: '+$Prompt)}; return $script:answers.Dequeue() }
function Get-V4ReportsPath { param([switch]$Create) return $script:comparisonFolder }

$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$fixture=Join-Path $tempBase ('ToolkitRenameTest-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $current=Join-Path $fixture 'ToolkitV4-Reports'
    $legacy=Join-Path $fixture 'Windows11-ToolkitV4-Reports'
    Assert-Check (@(Get-ToolkitReportFiles $current 'Windows11-ToolkitV4-Reports' 'Snapshot-*.json').Count -eq 0) 'Fresh install has no snapshots'
    Assert-Check (-not (Test-Path -LiteralPath $current)) 'Read-only discovery does not create folders'
    New-Item -ItemType Directory -Path $legacy | Out-Null
    $oldSnapshot=Join-Path $legacy 'Snapshot-same.json'
    '{"Schema":"Windows11-ToolkitV4-Snapshot-1"}' | Set-Content -LiteralPath $oldSnapshot -Encoding UTF8
    $oldHash=(Get-FileHash -LiteralPath $oldSnapshot).Hash
    Assert-Check (@(Get-ToolkitReportFiles $current 'Windows11-ToolkitV4-Reports' 'Snapshot-*.json').Count -eq 1) 'Legacy-only snapshots remain discoverable'
    New-Item -ItemType Directory -Path $current | Out-Null
    '{"Schema":"ToolkitV4-Snapshot-1"}' | Set-Content -LiteralPath (Join-Path $current 'Snapshot-same.json') -Encoding UTF8
    $files=@(Get-ToolkitReportFiles $current 'Windows11-ToolkitV4-Reports' 'Snapshot-*.json')
    Assert-Check ($files.Count -eq 2 -and @($files.FullName | Sort-Object -Unique).Count -eq 2) 'Equal snapshot filenames retain distinct locations'
    @([pscustomobject]@{Time='2026-10-20T10:00:00';Id='old';Action='Earlier'}) | Export-Csv -LiteralPath (Join-Path $legacy 'Repair-History.csv') -NoTypeInformation
    @([pscustomobject]@{Time='2026-10-22T10:00:00';Id='new';Action='Later'}) | Export-Csv -LiteralPath (Join-Path $current 'Repair-History.csv') -NoTypeInformation
    $history=@(Read-ToolkitHistory $current 'Windows11-ToolkitV4-Reports' 'Repair-History.csv' 25)
    Assert-Check ($history.Count -eq 2 -and $history[0].Id -eq 'old' -and $history[1].Id -eq 'new') 'History combines both locations in chronological order'
    $limited=@(Read-ToolkitHistory $current 'Windows11-ToolkitV4-Reports' 'Repair-History.csv' 1)
    Assert-Check ($limited.Count -eq 1 -and $limited[0].Id -eq 'new') 'History display limit retains the latest rows'
    Assert-Check (@(Read-ToolkitHistory $current 'Windows11-ToolkitV4-Reports' 'Missing-History.csv' 25).Count -eq 0) 'Missing histories return an empty result'
    Assert-Check (Test-ToolkitSnapshotSchema 'Windows11-ToolkitV4-Snapshot-1') 'Previous snapshot identifier accepted'
    Assert-Check (Test-ToolkitSnapshotSchema 'ToolkitV4-Snapshot-1') 'New snapshot identifier accepted'
    Assert-Check (-not (Test-ToolkitSnapshotSchema 'Unknown-1')) 'Unknown snapshot identifier rejected'
    Assert-Check (-not (Test-ToolkitSnapshotSchema '')) 'Missing snapshot identifier rejected'

    foreach($kind in @('legacy','new','mixed')) {
        $caseRoot=Join-Path $fixture ('comparison-'+$kind)
        $script:comparisonFolder=Join-Path $caseRoot 'ToolkitV4-Reports'
        $oldFolder=Join-Path $caseRoot 'Windows11-ToolkitV4-Reports'
        New-Item -ItemType Directory -Path $script:comparisonFolder,$oldFolder | Out-Null
        for($i=0;$i -lt 2;$i++) {
            $isLegacy=($kind -eq 'legacy' -or ($kind -eq 'mixed' -and $i -eq 0))
            $schema='ToolkitV4-Snapshot-1'; $folder=$script:comparisonFolder
            if($isLegacy){$schema='Windows11-ToolkitV4-Snapshot-1';$folder=$oldFolder}
            $path=Join-Path $folder ('Snapshot-'+$i+'.json')
            [pscustomobject]@{Schema=$schema;Date=('2026-10-2'+$i+'T10:00:00');Build=[string](100+$i);BIOS='fixture';RAMFreeGB=4;DevicesWithErrors=@();Storage=@();Drivers=@()} |
                ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
            [IO.File]::SetLastWriteTimeUtc($path,[datetime]::UtcNow.AddMinutes(-10+$i))
        }
        $script:answers.Enqueue('2');$script:answers.Enqueue('1')
        Compare-SystemBaseline
        $comparison=@(Get-ChildItem -LiteralPath $script:comparisonFolder -Filter 'Comparison-*.txt' -File)
        Assert-Check ($comparison.Count -eq 1 -and (Get-Content -LiteralPath $comparison[0].FullName -Raw) -match 'Build: 100 -> 101') ($kind+' snapshot pair compares successfully')
    }

    $undoRoot=Join-Path $fixture 'undo'
    $currentUndo=Join-Path (Join-Path $undoRoot 'ToolkitV4') 'PowerPlan-Undo.json'
    $legacyUndo=Join-Path (Join-Path $undoRoot 'Windows11ToolkitV4') 'PowerPlan-Undo.json'
    $valid='{"InitialScheme":"381b4222-f694-41f0-9685-ff5bb260df2e","SavedAt":"2026-10-20T10:00:00"}'
    Assert-Check ((Resolve-ToolkitUndoFile $currentUndo $legacyUndo) -eq $currentUndo) 'Fresh undo uses the neutral path'
    Assert-Check (-not (Test-Path -LiteralPath $undoRoot)) 'Undo resolution alone does not create data'
    New-Item -ItemType Directory -Path (Split-Path -Parent $legacyUndo) | Out-Null
    $valid | Set-Content -LiteralPath $legacyUndo -Encoding UTF8
    $undoHash=(Get-FileHash -LiteralPath $legacyUndo).Hash
    Assert-Check ((Resolve-ToolkitUndoFile $currentUndo $legacyUndo) -eq $legacyUndo) 'Sole previous undo record is reused in place'
    Assert-Check ((Get-FileHash -LiteralPath $legacyUndo).Hash -eq $undoHash) 'Reading undo preserves its bytes'
    New-Item -ItemType Directory -Path (Split-Path -Parent $currentUndo) | Out-Null
    $valid | Set-Content -LiteralPath $currentUndo -Encoding UTF8
    Assert-Throws {Resolve-ToolkitUndoFile $currentUndo $legacyUndo} 'Two power-plan undo records' 'Two undo records stop resolution even when identical'
    Assert-Check ((Get-FileHash -LiteralPath $legacyUndo).Hash -eq $undoHash -and (Get-FileHash -LiteralPath $currentUndo).Hash -eq $undoHash) 'Conflicting record check preserves both files'
    $absentLegacy=Join-Path $fixture 'absent-undo.json'
    Assert-Check ((Resolve-ToolkitUndoFile $currentUndo $absentLegacy) -eq $currentUndo) 'Sole current undo record is reused'
    foreach($bad in @('not json','null','{}','{"InitialScheme":"invalid"}')) {
        $badPath=Join-Path $fixture ('invalid-'+[guid]::NewGuid().ToString('N')+'.json')
        $bad | Set-Content -LiteralPath $badPath -Encoding UTF8
        $badHash=(Get-FileHash -LiteralPath $badPath).Hash
        Assert-Throws {Resolve-ToolkitUndoFile $badPath $absentLegacy} 'Cannot use undo record' ('Invalid undo stopped: '+$bad)
        Assert-Check ((Get-FileHash -LiteralPath $badPath).Hash -eq $badHash) 'Invalid undo remains unchanged'
    }
    Assert-Throws {Resolve-ToolkitUndoFile $undoRoot $absentLegacy} 'not a file' 'A directory cannot be used as an undo record'

    $script:opened=@()
    Open-ToolkitReports -CurrentFolder (Join-Path $fixture 'fresh-reports') -LegacyName 'absent-reports'
    Assert-Check ($script:opened.Count -eq 1 -and $script:opened[0] -eq (Join-Path $fixture 'fresh-reports')) 'Fresh report action opens only the current location (mocked)'
    foreach($choice in @('1','2','0','unexpected')) {
        $script:opened=@();$script:answers.Enqueue($choice)
        Open-ToolkitReports -CurrentFolder $current -LegacyName 'Windows11-ToolkitV4-Reports'
        if($choice -eq '1'){Assert-Check ($script:opened.Count -eq 1 -and $script:opened[0] -eq $current) 'Current reports choice routes correctly (mocked)'}
        elseif($choice -eq '2'){Assert-Check ($script:opened.Count -eq 1 -and $script:opened[0] -eq $legacy) 'Previous reports choice routes correctly (mocked)'}
        else{Assert-Check ($script:opened.Count -eq 0) 'Cancel or invalid folder choice opens nothing'}
    }
    Assert-Check ((Get-FileHash -LiteralPath $oldSnapshot).Hash -eq $oldHash) 'Previous snapshot bytes remain unchanged throughout tests'
    Assert-Check ($script:answers.Count -eq 0) 'All expected test choices were consumed'
    $v4=Get-Content -LiteralPath (Join-Path $root 'modules\V4-Extras.ps1') -Raw
    $profileDefinition=Get-ReviewedDefinitions (Join-Path $root 'modules\V4-Extras.ps1') @('Set-ExperienceProfile')
    Assert-Check ($profileDefinition.IndexOf('$null=Get-V4ProfileFile') -lt $profileDefinition.IndexOf('Show-ProfilePreview -Name $Name') -and $profileDefinition.Contains('$null=Get-V4ProfileFile')) 'Undo validation precedes profile preview and changes'
    Assert-Check ($v4.Contains('$files[$i].FullName')) 'Snapshot menu identifies full paths for duplicate names'
    Write-Host ("PASS: $script:checks compatibility checks; synthetic files only, no maintenance actions or windows launched.")
} finally {
    $resolvedFixture=[IO.Path]::GetFullPath($fixture)
    if(-not $resolvedFixture.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolvedFixture) -notmatch '^ToolkitRenameTest-[0-9a-f]{32}$') { throw 'Refusing unsafe fixture cleanup.' }
    if(Test-Path -LiteralPath $resolvedFixture){Remove-Item -LiteralPath $resolvedFixture -Recurse -Force}
}
