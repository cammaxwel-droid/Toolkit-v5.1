#requires -Version 5.1
# Reviewed definitions and synthetic files only. Never run an application entrypoint.
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

$helperNames=@('Get-ToolkitLegacyReportNames','Get-ToolkitReportFolders','Get-ToolkitReportFiles','Read-ToolkitHistory','Test-ToolkitSnapshotSchema','Resolve-ToolkitUndoFile','Open-ToolkitReports')
. ([scriptblock]::Create((Get-ReviewedDefinitions (Join-Path $root 'modules\Toolkit-Compatibility.ps1') $helperNames)))
. ([scriptblock]::Create((Get-ReviewedDefinitions (Join-Path $root 'modules\Toolkit-Utilities.ps1') @('Compare-SystemBaseline','Get-ToolkitProfileFile','Write-ToolkitActivity','Get-ToolkitSnapshot','Save-SystemBaseline'))))
. ([scriptblock]::Create((Get-ReviewedDefinitions (Join-Path $root 'modules\Toolkit-Workflows.ps1') @('Save-ToolkitDiagnostics','Write-ToolkitRepairHistory'))))

# Test doubles prevent windows, hardware queries and real report destinations.
$script:opened=@()
$script:answers=New-Object 'System.Collections.Generic.Queue[string]'
$script:blockedFolder=$null
function Start-Process { param([string]$FilePath) $script:opened += $FilePath }
function Read-Host { param([string]$Prompt) if($script:answers.Count -eq 0){throw ('Unexpected prompt: '+$Prompt)}; return $script:answers.Dequeue() }
function Get-ToolkitReportsPath {
    param([switch]$Create)
    if($Create -and -not (Test-Path -LiteralPath $script:comparisonFolder)){New-Item -ItemType Directory -Path $script:comparisonFolder | Out-Null}
    return $script:comparisonFolder
}
function Get-ToolkitReportFolder { return $script:writerFolder }
function Get-ChildItem {
    [CmdletBinding()]param([string]$LiteralPath,[string]$Filter,[switch]$File)
    if($LiteralPath -eq $script:blockedFolder){throw 'Synthetic unreadable directory'}
    Microsoft.PowerShell.Management\Get-ChildItem @PSBoundParameters
}
function Get-CimInstance {
    [CmdletBinding()]param([string]$ClassName)
    switch($ClassName){
        'Win32_OperatingSystem' {[pscustomobject]@{Caption='Fixture OS';BuildNumber='100';FreePhysicalMemory=4194304}}
        'Win32_BIOS' {[pscustomobject]@{SMBIOSBIOSVersion='fixture'}}
        'Win32_PnPSignedDriver' {[pscustomobject]@{DeviceID='fixture-device';DeviceName='Fixture';DriverVersion='1.0'}}
        default {throw ('Unexpected hardware query: '+$ClassName)}
    }
}
function Get-PnpDevice { [CmdletBinding()]param(); [pscustomobject]@{Status='OK';FriendlyName='Fixture'} }
function Get-PhysicalDisk { [CmdletBinding()]param(); [pscustomobject]@{FriendlyName='Fixture';FirmwareVersion='1';HealthStatus='Healthy'} }

$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$fixture=Join-Path $tempBase ('ToolkitReportsTest-'+[guid]::NewGuid().ToString('N'))
$savedLocalAppData=$env:LOCALAPPDATA
$savedComputerName=$env:COMPUTERNAME
$protected=@{}
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $legacyNames=@(Get-ToolkitLegacyReportNames)
    Assert-Check ($legacyNames.Count -eq 8 -and @($legacyNames | Sort-Object -Unique).Count -eq 8) 'All eight previous report folders are recognised'
    $current=Join-Path $fixture 'Toolkit-Reports'
    $utilityLegacy=@('ToolkitV4-Reports','Windows11-ToolkitV4-Reports')
    Assert-Check (@(Get-ToolkitReportFiles $current $utilityLegacy 'Snapshot-*.json').Count -eq 0) 'Fresh install has no snapshots'
    Assert-Check (-not (Test-Path -LiteralPath $current)) 'Read-only discovery does not create folders'
    $schemas=@('Toolkit-Snapshot-1','ToolkitV4-Snapshot-1','Windows11-ToolkitV4-Snapshot-1')
    $snapshotFolders=@($current,(Join-Path $fixture $utilityLegacy[0]),(Join-Path $fixture $utilityLegacy[1]))
    for($i=0;$i -lt 3;$i++){
        New-Item -ItemType Directory -Path $snapshotFolders[$i] | Out-Null
        $path=Join-Path $snapshotFolders[$i] 'Snapshot-same.json'
        [pscustomobject]@{Schema=$schemas[$i]} | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
        [IO.File]::SetLastWriteTimeUtc($path,[datetime]::UtcNow.AddMinutes(-$i))
        $protected[$path]=(Get-FileHash -LiteralPath $path).Hash
        Assert-Check (Test-ToolkitSnapshotSchema $schemas[$i]) ('Snapshot schema accepted: '+$schemas[$i])
    }
    $files=@(Get-ToolkitReportFiles $current @('ToolkitV4-Reports','Windows11-ToolkitV4-Reports','ToolkitV4-Reports','Toolkit-Reports') 'Snapshot-*.json')
    Assert-Check ($files.Count -eq 3 -and @($files.FullName | Sort-Object -Unique).Count -eq 3) 'Equal filenames in three locations remain distinct; duplicate paths are read once'
    Assert-Check ($files[0].FullName -eq (Join-Path $current 'Snapshot-same.json')) 'Snapshot discovery retains newest-first ordering'
    Assert-Check (-not (Test-ToolkitSnapshotSchema 'Unknown-1') -and -not (Test-ToolkitSnapshotSchema '')) 'Unknown or missing snapshot schemas are rejected'
    $script:blockedFolder=$snapshotFolders[1]
    $savedWarningPreference=$WarningPreference; $WarningPreference='SilentlyContinue'
    try {$readable=@(Get-ToolkitReportFiles $current $utilityLegacy 'Snapshot-*.json')}
    finally {$WarningPreference=$savedWarningPreference; $script:blockedFolder=$null}
    Assert-Check ($readable.Count -eq 2) 'An unreadable old folder does not hide the remaining snapshots'

    # Exercise every pair of the three real schema identifiers using the actual comparison function.
    for($beforeKind=0;$beforeKind -lt 3;$beforeKind++){
        for($afterKind=0;$afterKind -lt 3;$afterKind++){
            $caseRoot=Join-Path $fixture ('comparison-'+$beforeKind+'-'+$afterKind)
            $script:comparisonFolder=Join-Path $caseRoot 'Toolkit-Reports'
            $caseFolders=@($script:comparisonFolder,(Join-Path $caseRoot $utilityLegacy[0]),(Join-Path $caseRoot $utilityLegacy[1]))
            foreach($folder in $caseFolders){New-Item -ItemType Directory -Path $folder -Force | Out-Null}
            $kinds=@($beforeKind,$afterKind)
            for($i=0;$i -lt 2;$i++){
                $path=Join-Path $caseFolders[$kinds[$i]] ('Snapshot-'+$i+'.json')
                [pscustomobject]@{Schema=$schemas[$kinds[$i]];Date=('2026-10-2'+$i+'T10:00:00');Build=[string](100+$i);BIOS='fixture';RAMFreeGB=4;DevicesWithErrors=@();Storage=@();Drivers=@()} |
                    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
                [IO.File]::SetLastWriteTimeUtc($path,[datetime]::UtcNow.AddMinutes(-10+$i))
                $protected[$path]=(Get-FileHash -LiteralPath $path).Hash
            }
            $script:answers.Enqueue('2'); $script:answers.Enqueue('1')
            Compare-SystemBaseline
            $comparison=@(Get-ChildItem -LiteralPath $script:comparisonFolder -Filter 'Comparison-*.txt' -File)
            Assert-Check ($comparison.Count -eq 1 -and (Get-Content -LiteralPath $comparison[0].FullName -Raw) -match 'Build: 100 -> 101') ('Schema pair '+$beforeKind+'/'+$afterKind+' compares into the shared folder')
        }
    }

    $workflowLegacy=@('ToolkitV5-Reports','Windows11-ToolkitV5-Reports')
    $workflowFolders=@($current,(Join-Path $fixture $workflowLegacy[0]),(Join-Path $fixture $workflowLegacy[1]))
    for($i=0;$i -lt 3;$i++){
        $actionPath=Join-Path $snapshotFolders[$i] 'Repair-History.csv'
        [pscustomobject]@{Time=('2026-10-2'+(2-$i)+'T10:00:00');Id=('action-'+$i);Action='Fixture action';Class='REPORT';Outcome='INVOKED'} |
            Export-Csv -LiteralPath $actionPath -NoTypeInformation -Encoding UTF8
        New-Item -ItemType Directory -Path $workflowFolders[$i] -Force | Out-Null
        $historyName=if($i -eq 0){'Workflow-Repair-History.csv'}else{'V5-Repair-History.csv'}
        $workflowPath=Join-Path $workflowFolders[$i] $historyName
        [pscustomobject]@{Time=('2026-10-2'+(2-$i)+'T10:00:00');Mode='Fixture';Id=('workflow-'+$i);Title='Fixture workflow';Outcome='CANCELLED';Notes='synthetic'} |
            Export-Csv -LiteralPath $workflowPath -NoTypeInformation -Encoding UTF8
        if($i -gt 0){$protected[$actionPath]=(Get-FileHash -LiteralPath $actionPath).Hash; $protected[$workflowPath]=(Get-FileHash -LiteralPath $workflowPath).Hash}
    }
    $actions=@(Read-ToolkitHistory $current $utilityLegacy 'Repair-History.csv' 25)
    $workflows=@(Read-ToolkitHistory $current $workflowLegacy 'Workflow-Repair-History.csv' 30 @('V5-Repair-History.csv','V5-Repair-History.csv'))
    Assert-Check ($actions.Count -eq 3 -and $actions[0].Id -eq 'action-2' -and $actions[-1].Id -eq 'action-0') 'Action history combines all three locations chronologically'
    Assert-Check ($workflows.Count -eq 3 -and $workflows[0].Id -eq 'workflow-2' -and $workflows[-1].Id -eq 'workflow-0') 'Workflow history recognises the old filename without duplicate reads'
    Assert-Check ($actions[0].PSObject.Properties.Name -contains 'Class' -and $actions[0].PSObject.Properties.Name -notcontains 'Mode' -and $workflows[0].PSObject.Properties.Name -contains 'Mode' -and $workflows[0].PSObject.Properties.Name -notcontains 'Class') 'Action and workflow CSV formats stay separate'
    Assert-Check (@(Read-ToolkitHistory $current $utilityLegacy 'Missing.csv' 25).Count -eq 0) 'Missing histories return an empty result'
    $many=1..40 | ForEach-Object {[pscustomobject]@{Time=('2026-10-23T10:'+('{0:00}' -f $_)+':00');Id=[string]$_}}
    $many | Export-Csv -LiteralPath (Join-Path $current 'Repair-History.csv') -NoTypeInformation -Encoding UTF8
    $many | Export-Csv -LiteralPath (Join-Path $current 'Workflow-Repair-History.csv') -NoTypeInformation -Encoding UTF8
    $actions=@(Read-ToolkitHistory $current $utilityLegacy 'Repair-History.csv' 25)
    $workflows=@(Read-ToolkitHistory $current $workflowLegacy 'Workflow-Repair-History.csv' 30 @('V5-Repair-History.csv'))
    Assert-Check ($actions.Count -eq 25 -and $actions[0].Id -eq '16' -and $actions[-1].Id -eq '40') 'Action history retains the latest 25 rows'
    Assert-Check ($workflows.Count -eq 30 -and $workflows[0].Id -eq '11' -and $workflows[-1].Id -eq '40') 'Workflow history retains the latest 30 rows'

    # Every combination of current and both previous undo locations is checked.
    $valid='{"InitialScheme":"381b4222-f694-41f0-9685-ff5bb260df2e","SavedAt":"2026-10-20T10:00:00"}'
    for($mask=0;$mask -lt 8;$mask++){
        $env:LOCALAPPDATA=Join-Path $fixture ('undo-'+$mask)
        $paths=@('Toolkit','ToolkitV4','Windows11ToolkitV4') | ForEach-Object {Join-Path (Join-Path $env:LOCALAPPDATA $_) 'PowerPlan-Undo.json'}
        $present=@()
        for($i=0;$i -lt 3;$i++){
            if($mask -band (1 -shl $i)){
                New-Item -ItemType Directory -Path (Split-Path -Parent $paths[$i]) -Force | Out-Null
                $valid | Set-Content -LiteralPath $paths[$i] -Encoding UTF8
                $protected[$paths[$i]]=(Get-FileHash -LiteralPath $paths[$i]).Hash
                $present += $paths[$i]
            }
        }
        if($present.Count -gt 1){Assert-Throws {Get-ToolkitProfileFile} 'Multiple power-plan undo records' ('Undo combination '+$mask+' stops on conflicts')}
        else {
            $expected=if($present.Count){$present[0]}else{$paths[0]}
            Assert-Check ((Get-ToolkitProfileFile) -eq $expected) ('Undo combination '+$mask+' selects the sole record or fresh neutral location')
            if($present.Count){Assert-Check ((Resolve-ToolkitUndoFile $paths[0] @($paths[1],$paths[2],$expected)) -eq $expected) 'Repeated references to the same undo path are not conflicts'}
        }
        if($mask -eq 0){
            Assert-Check (-not (Test-Path -LiteralPath $env:LOCALAPPDATA)) 'Undo discovery alone does not create a data folder'
            $null=Get-ToolkitProfileFile -Create
            Assert-Check ((Test-Path -LiteralPath (Split-Path -Parent $paths[0])) -and -not (Test-Path -LiteralPath $paths[0])) 'Explicit preparation creates only the neutral undo directory'
        }
    }
    for($kind=0;$kind -lt 3;$kind++){
        foreach($bad in @('not json','null','{}','{"InitialScheme":"invalid"}')){
            $env:LOCALAPPDATA=Join-Path $fixture ('bad-'+[guid]::NewGuid().ToString('N'))
            $name=@('Toolkit','ToolkitV4','Windows11ToolkitV4')[$kind]
            $badPath=Join-Path (Join-Path $env:LOCALAPPDATA $name) 'PowerPlan-Undo.json'
            New-Item -ItemType Directory -Path (Split-Path -Parent $badPath) -Force | Out-Null
            $bad | Set-Content -LiteralPath $badPath -Encoding UTF8
            $protected[$badPath]=(Get-FileHash -LiteralPath $badPath).Hash
            Assert-Throws {Get-ToolkitProfileFile} 'Cannot use undo record' ('Invalid undo stops in location '+$kind+': '+$bad)
        }
    }
    $directoryRecord=Join-Path $fixture 'directory-undo.json'
    New-Item -ItemType Directory -Path $directoryRecord | Out-Null
    Assert-Throws {Resolve-ToolkitUndoFile $directoryRecord @()} 'not a file' 'An undo record must be a file'

    $chooserRoot=Join-Path $fixture 'chooser'
    $chooserCurrent=Join-Path $chooserRoot 'Toolkit-Reports'
    $script:opened=@()
    Open-ToolkitReports -CurrentFolder $chooserCurrent
    Assert-Check ($script:opened.Count -eq 1 -and $script:opened[0] -eq $chooserCurrent) 'Fresh report action opens the shared folder (mocked)'
    foreach($name in $legacyNames){New-Item -ItemType Directory -Path (Join-Path $chooserRoot $name) -Force | Out-Null}
    $choices=@($chooserCurrent) + @($legacyNames | ForEach-Object {Join-Path $chooserRoot $_})
    for($i=0;$i -lt $choices.Count;$i++){
        $script:opened=@(); $script:answers.Enqueue([string]($i+1))
        Open-ToolkitReports -CurrentFolder $chooserCurrent
        Assert-Check ($script:opened.Count -eq 1 -and $script:opened[0] -eq $choices[$i]) ('Report folder choice '+($i+1)+' selects its exact location (mocked)')
    }
    foreach($answer in @('0','unexpected','99')){
        $script:opened=@(); $script:answers.Enqueue($answer)
        Open-ToolkitReports -CurrentFolder $chooserCurrent
        Assert-Check ($script:opened.Count -eq 0) 'Cancel or invalid report choice opens nothing'
    }

    # Exercise real export functions with fake findings/hardware and isolated destinations.
    $script:writerFolder=Join-Path (Join-Path $fixture 'writers') 'Toolkit-Reports'
    $script:comparisonFolder=$script:writerFolder
    New-Item -ItemType Directory -Path $script:writerFolder -Force | Out-Null
    $env:COMPUTERNAME='ToolkitFixture'
    $findings=New-Object System.Collections.ArrayList
    [void]$findings.Add([pscustomobject]@{Id='FIXTURE';Check='Fixture';Status='PASS';Summary='Synthetic';Detail='';SuggestedAction=''})
    $saved=Save-ToolkitDiagnostics -Mode 'Fixture' -Results $findings
    $diagnostic=Get-Content -LiteralPath $saved.JsonPath -Raw | ConvertFrom-Json
    Assert-Check ($diagnostic.Schema -eq 'Toolkit-Diagnostic-2' -and $diagnostic.Count -eq 1 -and $diagnostic.Findings[0].Id -eq 'FIXTURE') 'Actual diagnostic exporter writes the neutral schema with unchanged finding fields'
    Assert-Check ((Get-Content -LiteralPath $saved.TextPath -Raw) -match '^TOOLKIT V5\.1 - FIXTURE' -and (Split-Path -Parent $saved.TextPath) -eq $script:writerFolder) 'Actual diagnostic text uses current branding and the shared destination'
    Write-ToolkitActivity -Id '113' -Name 'Fixture action' -Risk 'REPORT' -Outcome 'INVOKED'
    Write-ToolkitRepairHistory -Mode 'Fixture' -Id 'FIXTURE' -Title 'Fixture workflow' -Outcome 'CANCELLED' -Notes 'synthetic'
    $actionRecord=Import-Csv -LiteralPath (Join-Path $script:writerFolder 'Repair-History.csv')
    $workflowRecord=Import-Csv -LiteralPath (Join-Path $script:writerFolder 'Workflow-Repair-History.csv')
    Assert-Check ($actionRecord.Class -eq 'REPORT' -and $workflowRecord.Mode -eq 'Fixture') 'Actual history writers keep their distinct files and columns'
    Assert-Check (-not (Test-Path -LiteralPath (Join-Path $script:writerFolder 'V5-Repair-History.csv'))) 'New workflow history never creates the old versioned filename'
    Save-SystemBaseline
    $snapshots=@(Get-ChildItem -LiteralPath $script:writerFolder -Filter 'Snapshot-*.json' -File)
    $snapshot=Get-Content -LiteralPath $snapshots[0].FullName -Raw | ConvertFrom-Json
    Assert-Check ($snapshots.Count -eq 1 -and $snapshot.Schema -eq 'Toolkit-Snapshot-1' -and $snapshot.Drivers[0].ID -eq 'fixture-device') 'Actual snapshot exporter uses the neutral schema with mocked hardware'

    foreach($path in $protected.Keys){Assert-Check ((Get-FileHash -LiteralPath $path).Hash -eq $protected[$path]) 'Existing fixture bytes remain unchanged'}
    Assert-Check ($script:answers.Count -eq 0) 'All expected menu choices were consumed'
    $profileDefinition=Get-ReviewedDefinitions (Join-Path $root 'modules\Toolkit-Utilities.ps1') @('Set-ExperienceProfile')
    Assert-Check ($profileDefinition.Contains('$null=Get-ToolkitProfileFile') -and $profileDefinition.IndexOf('$null=Get-ToolkitProfileFile') -lt $profileDefinition.IndexOf('Show-ProfilePreview -Name $Name')) 'Undo validation still precedes profile preview and changes'
    Write-Host ("PASS: $script:checks compatibility checks; synthetic files and mocked hardware only, no maintenance actions or windows launched.")
} finally {
    $env:LOCALAPPDATA=$savedLocalAppData
    $env:COMPUTERNAME=$savedComputerName
    $resolvedFixture=[IO.Path]::GetFullPath($fixture)
    if(-not $resolvedFixture.StartsWith($tempBase+'\',[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolvedFixture) -notmatch '^ToolkitReportsTest-[0-9a-f]{32}$'){throw 'Refusing unsafe fixture cleanup.'}
    if(Test-Path -LiteralPath $resolvedFixture){Remove-Item -LiteralPath $resolvedFixture -Recurse -Force}
}
