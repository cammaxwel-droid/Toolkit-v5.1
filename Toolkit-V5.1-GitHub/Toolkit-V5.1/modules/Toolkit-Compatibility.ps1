#requires -Version 5.1
# Toolkit saved-data compatibility. Definitions only; no work runs on import.

function Get-ToolkitLegacyReportNames {
    return @('ToolkitV3-Reports','ToolkitV4-Reports','ToolkitV5-Reports','RepairKit-Reports',
        'Windows11-ToolkitV3-Reports','Windows11-ToolkitV4-Reports','Windows11-ToolkitV5-Reports','Windows11-RepairKit-Reports')
}

function Get-ToolkitReportFolders {
    param([string]$CurrentFolder, [Alias('LegacyName')][string[]]$LegacyNames = @())
    $parent = Split-Path -Parent $CurrentFolder
    $candidates = @($CurrentFolder)
    foreach ($name in $LegacyNames) { $candidates += (Join-Path $parent $name) }
    $seen = @{}
    foreach ($candidate in $candidates) {
        $path = [IO.Path]::GetFullPath($candidate)
        if (-not $seen.ContainsKey($path)) { $seen[$path] = $true; $path }
    }
}

function Get-ToolkitReportFiles {
    param([string]$CurrentFolder, [Alias('LegacyName')][string[]]$LegacyNames, [string]$Pattern)
    $files = @()
    $seen = @{}
    foreach ($folder in @(Get-ToolkitReportFolders -CurrentFolder $CurrentFolder -LegacyNames $LegacyNames)) {
        try {
            if (Test-Path -LiteralPath $folder -PathType Container -ErrorAction Stop) {
                foreach ($file in @(Get-ChildItem -LiteralPath $folder -Filter $Pattern -File -ErrorAction Stop)) {
                    if (-not $seen.ContainsKey($file.FullName)) { $seen[$file.FullName] = $true; $files += $file }
                }
            }
        } catch { Write-Warning ("Could not read reports in {0}: {1}" -f $folder, $_.Exception.Message) }
    }
    return @($files | Sort-Object LastWriteTime,FullName -Descending)
}

function Read-ToolkitHistory {
    param([string]$CurrentFolder, [Alias('LegacyName')][string[]]$LegacyNames,
        [string]$FileName, [int]$Limit, [string[]]$LegacyFileNames = @())
    $rows = @()
    $seen = @{}
    foreach ($name in (@($FileName) + @($LegacyFileNames))) {
        foreach ($file in @(Get-ToolkitReportFiles -CurrentFolder $CurrentFolder -LegacyNames $LegacyNames -Pattern $name)) {
            if ($seen.ContainsKey($file.FullName)) { continue }
            $seen[$file.FullName] = $true
            try { $rows += @(Import-Csv -LiteralPath $file.FullName -ErrorAction Stop) }
            catch { Write-Warning ("Could not read history {0}: {1}" -f $file.FullName, $_.Exception.Message) }
        }
    }
    return @($rows | Sort-Object Time | Select-Object -Last $Limit)
}

function Test-ToolkitSnapshotSchema {
    param([string]$Schema)
    return ($Schema -in @('Toolkit-Snapshot-1','ToolkitV4-Snapshot-1','Windows11-ToolkitV4-Snapshot-1'))
}

function Resolve-ToolkitUndoFile {
    param([string]$CurrentFile, [Alias('LegacyFile')][string[]]$LegacyFiles)
    $existing = @()
    $seen = @{}
    foreach ($candidate in (@($CurrentFile) + @($LegacyFiles))) {
        $path = [IO.Path]::GetFullPath($candidate)
        if ($seen.ContainsKey($path)) { continue }
        $seen[$path] = $true
        if (Test-Path -LiteralPath $path -ErrorAction Stop) { $existing += $path }
    }
    if ($existing.Count -gt 1) {
        throw ('Multiple power-plan undo records exist. Profile changes and undo are stopped; resolve the conflict before continuing: '+($existing -join ' | '))
    }
    if ($existing.Count -eq 0) { return $CurrentFile }
    $selected = $existing[0]
    try {
        if (-not (Test-Path -LiteralPath $selected -PathType Leaf)) { throw 'The undo-record path is not a file.' }
        $record = Get-Content -LiteralPath $selected -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $record -or [string]$record.InitialScheme -notmatch '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$') {
            throw 'The undo record does not contain a valid original power-plan GUID.'
        }
    } catch { throw ("Cannot use undo record {0}. Profile changes and undo are stopped. {1}" -f $selected, $_.Exception.Message) }
    return $selected
}

function Open-ToolkitReports {
    param([string]$CurrentFolder, [Alias('LegacyName')][string[]]$LegacyNames = @(Get-ToolkitLegacyReportNames))
    $previous = @()
    foreach ($folder in @(Get-ToolkitReportFolders -CurrentFolder $CurrentFolder -LegacyNames $LegacyNames | Select-Object -Skip 1)) {
        try {
            if (Test-Path -LiteralPath $folder -PathType Container -ErrorAction Stop) { $previous += $folder }
        } catch { Write-Warning ("Could not read reports in {0}: {1}" -f $folder, $_.Exception.Message) }
    }
    if ($previous.Count -eq 0) { Start-Process -FilePath $CurrentFolder; return }
    $choices = @($CurrentFolder) + $previous
    Write-Host ('1: Current reports - '+$CurrentFolder)
    for ($i = 0; $i -lt $previous.Count; $i++) { Write-Host ('{0}: Previous reports - {1}' -f ($i+2),$previous[$i]) }
    Write-Host '0: Cancel'
    $choice = Read-Host 'Choose reports location'
    [int]$number = 0
    if ([int]::TryParse(([string]$choice).Trim(), [ref]$number) -and $number -ge 1 -and $number -le $choices.Count) {
        Start-Process -FilePath $choices[$number-1]
    } else { Write-Host 'No folder opened.' }
}
