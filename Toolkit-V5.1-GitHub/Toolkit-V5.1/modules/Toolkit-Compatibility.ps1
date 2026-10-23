#requires -Version 5.1
# Toolkit saved-data compatibility. Definitions only; no work runs on import.

function Get-ToolkitReportFiles {
    param([string]$CurrentFolder, [string]$LegacyName, [string]$Pattern)
    $legacy = Join-Path (Split-Path -Parent $CurrentFolder) $LegacyName
    $files = @()
    foreach ($folder in @($CurrentFolder, $legacy)) {
        try {
            if (Test-Path -LiteralPath $folder -PathType Container -ErrorAction Stop) {
                $files += @(Get-ChildItem -LiteralPath $folder -Filter $Pattern -File -ErrorAction Stop)
            }
        } catch { Write-Warning ("Could not read reports in {0}: {1}" -f $folder, $_.Exception.Message) }
    }
    return @($files | Sort-Object LastWriteTime,FullName -Descending)
}

function Read-ToolkitHistory {
    param([string]$CurrentFolder, [string]$LegacyName, [string]$FileName, [int]$Limit)
    $rows = @()
    foreach ($file in @(Get-ToolkitReportFiles -CurrentFolder $CurrentFolder -LegacyName $LegacyName -Pattern $FileName)) {
        try { $rows += @(Import-Csv -LiteralPath $file.FullName -ErrorAction Stop) }
        catch { Write-Warning ("Could not read history {0}: {1}" -f $file.FullName, $_.Exception.Message) }
    }
    return @($rows | Sort-Object Time | Select-Object -Last $Limit)
}

function Test-ToolkitSnapshotSchema {
    param([string]$Schema)
    return ($Schema -in @('ToolkitV4-Snapshot-1', 'Windows11-ToolkitV4-Snapshot-1'))
}

function Resolve-ToolkitUndoFile {
    param([string]$CurrentFile, [string]$LegacyFile)
    $currentExists = Test-Path -LiteralPath $CurrentFile -ErrorAction Stop
    $legacyExists = Test-Path -LiteralPath $LegacyFile -ErrorAction Stop
    if ($currentExists -and $legacyExists) {
        throw "Two power-plan undo records exist. Profile changes and undo are stopped; resolve the conflict before continuing: $CurrentFile | $LegacyFile"
    }
    $selected = $CurrentFile
    if ($legacyExists) { $selected = $LegacyFile }
    if ($currentExists -or $legacyExists) {
        try {
            if (-not (Test-Path -LiteralPath $selected -PathType Leaf)) { throw 'The undo-record path is not a file.' }
            $record = Get-Content -LiteralPath $selected -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if (-not $record -or [string]$record.InitialScheme -notmatch '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$') {
                throw 'The undo record does not contain a valid original power-plan GUID.'
            }
        } catch { throw ("Cannot use undo record {0}. Profile changes and undo are stopped. {1}" -f $selected, $_.Exception.Message) }
    }
    return $selected
}

function Open-ToolkitReports {
    param([string]$CurrentFolder, [string]$LegacyName)
    $legacy = Join-Path (Split-Path -Parent $CurrentFolder) $LegacyName
    if (-not (Test-Path -LiteralPath $legacy -PathType Container)) {
        Start-Process -FilePath $CurrentFolder
        return
    }
    Write-Host ('1: Current reports - '+$CurrentFolder)
    Write-Host ('2: Previous reports - '+$legacy)
    Write-Host '0: Cancel'
    $choice = Read-Host 'Choose reports location'
    switch ($choice.Trim()) {
        '1' { Start-Process -FilePath $CurrentFolder }
        '2' { Start-Process -FilePath $legacy }
        default { Write-Host 'No folder opened.' }
    }
}
