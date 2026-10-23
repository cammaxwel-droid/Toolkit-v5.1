#requires -Version 5.1
# Toolkit V4: new interactive tools. PowerShell 5.1.
# Dot-sourced by src/Toolkit.ps1. Functions run only on explicit selection.

function Get-V4ReportsPath {
    param([switch]$Create)
    $directory = [Environment]::GetFolderPath('MyDocuments')
    if (-not $directory -or -not (Test-Path -LiteralPath $directory)) { $directory = $env:USERPROFILE }
    $directory = Join-Path $directory 'ToolkitV4-Reports'
    if ($Create -and -not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop | Out-Null }
    return $directory
}
function Write-ToolkitActivity {
    param([string]$Id, [string]$Name, [string]$Risk, [string]$Outcome)
    # An action was attempted; does not independently prove repair success.
    try {
        $path = Join-Path (Get-V4ReportsPath -Create) 'Repair-History.csv'
        [pscustomobject]@{Time=(Get-Date).ToString('s');Id=$Id;Action=$Name;Class=$Risk;Outcome=$Outcome} |
           Export-Csv -Path $path -NoTypeInformation -Encoding UTF8 -Append
    } catch { Write-Host "Unable to write optional repair history: $($_.Exception.Message)" -ForegroundColor Yellow }
}
function Show-RepairHistory {
    $rows = @(Read-ToolkitHistory -CurrentFolder (Get-V4ReportsPath) -LegacyName 'Windows11-ToolkitV4-Reports' -FileName 'Repair-History.csv' -Limit 25)
    if ($rows.Count -eq 0) { Write-Host 'No readable toolkit repair or change history was found.'; return }
    $rows | Format-Table Time,Id,Action,Class,Outcome -AutoSize -Wrap
    Write-Host 'History records an action invocation, NOT confirmed repair success.' -ForegroundColor Yellow
}
function Get-V4SecurityInformation {
    $out = @('WINDOWS SECURITY AUDIT - '+(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
    try { $out += 'DEFENDER'; $out += ((Get-MpComputerStatus -ErrorAction Stop | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated | Format-List | Out-String -Width 180)) }
    catch { $out += ('Defender information unavailable: '+$_.Exception.Message) }
    try { $out += 'FIREWALL'; $out += (Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction | Format-Table -AutoSize | Out-String -Width 180) }
    catch { $out += ('Firewall information unavailable: '+$_.Exception.Message) }
    try { $out += 'TPM'; $out += (Get-Tpm | Select-Object TpmPresent,TpmReady,TpmEnabled,TpmActivated | Format-List | Out-String -Width 180) }
    catch { $out += ('TPM information unavailable: '+$_.Exception.Message) }
    try { $out += 'Secure Boot enabled: '+(Confirm-SecureBootUEFI) }
    catch { $out += ('Secure Boot information unavailable: '+$_.Exception.Message) }
    try { $out += 'BITLOCKER C:'; $out += (& manage-bde.exe -status C: | Out-String -Width 180) }
    catch { $out += ('BitLocker information unavailable: '+$_.Exception.Message) }
    return $out
}
function New-SecurityAudit {
    $path=Join-Path (Get-V4ReportsPath -Create) ('Security-Audit-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Get-V4SecurityInformation | Out-File -LiteralPath $path -Encoding UTF8 -Width 200
    Write-Host "Security audit saved: $path" -ForegroundColor Green
    Write-Host 'Reports may contain system information. Review before uploading to GitHub.'
}
function Show-SecurityQuick { (Get-V4SecurityInformation) | Select-Object -First 15 | ForEach-Object {Write-Host $_} }
function Show-RecentReliability {
    foreach($log in @('System','Application')){
        Write-Host "`n$log errors and critical events:" -ForegroundColor Cyan
        try {
            Get-WinEvent -FilterHashtable @{LogName=$log;Level=@(1,2);StartTime=(Get-Date).AddDays(-2)} -MaxEvents 8 -ErrorAction Stop |
               Select-Object TimeCreated,Id,ProviderName,LevelDisplayName,Message | Format-List
        } catch { Write-Host "No accessible events: $($_.Exception.Message)" }
    }
}
function Show-RestorePointStatus {
    try { Get-ComputerRestorePoint -ErrorAction Stop | Select-Object -Last 8 SequenceNumber,CreationTime,Description | Format-Table -AutoSize }
    catch { Write-Host "Restore points unavailable or System Protection off: $($_.Exception.Message)" -ForegroundColor Yellow }
    Start-Process SystemPropertiesProtection.exe
}
function New-StartupRamReport {
    $path=Join-Path (Get-V4ReportsPath -Create) ('Startup-RAM-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $results=@('STARTUP AND RAM REPORT '+(Get-Date),'Process working sets can include shared memory; they are not private-memory totals.','')
    try{
        $results+= 'TOP RAM PROCESS NAMES (WORKING SETS)'
        $results+= (Get-Process | Group-Object ProcessName | ForEach-Object {
          [pscustomobject]@{Name=$_.Name;Processes=$_.Count;WorkingSetMB=[math]::Round(($_.Group|Measure-Object WorkingSet64 -Sum).Sum/1MB,1)}
        } | Sort-Object WorkingSetMB -Descending | Select-Object -First 30 | Format-Table -AutoSize | Out-String -Width 180)
        $os=Get-CimInstance Win32_OperatingSystem
        $results+= ('RAM available: {0:N2} GB' -f ($os.FreePhysicalMemory/1MB))
    } catch {$results+=('Memory query failed: '+$_.Exception.Message)}
    try{$results+= 'STARTUP REGISTRATIONS';$results+= (Get-CimInstance Win32_StartupCommand | Select-Object Name,Location,User | Format-Table -AutoSize | Out-String -Width 180)}
    catch{$results+=('Startup inventory failed: '+$_.Exception.Message)}
    $results | Out-File -LiteralPath $path -Encoding UTF8 -Width 200
    Write-Host "Report saved: $path" -ForegroundColor Green
}
function Get-V4Snapshot {
    $os=Get-CimInstance Win32_OperatingSystem
    $bios=Get-CimInstance Win32_BIOS
    $dr=@(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object DeviceID |
        ForEach-Object{[pscustomobject]@{ID=[string]$_.DeviceID;Name=[string]$_.DeviceName;Version=[string]$_.DriverVersion}})
    $problems=@(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object Status -eq 'Error' | Select-Object -ExpandProperty FriendlyName)
    $storage=@(Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object FriendlyName,FirmwareVersion,HealthStatus)
    [pscustomobject]@{
      Schema='ToolkitV4-Snapshot-1'
      Date=(Get-Date).ToString('o')
      OS=$os.Caption
      Build=$os.BuildNumber
      BIOS=$bios.SMBIOSBIOSVersion
      RAMFreeGB=[math]::Round($os.FreePhysicalMemory/1MB,2)
      DevicesWithErrors=$problems
      Storage=$storage
      Drivers=$dr
    }
}
function Save-SystemBaseline {
    $path=Join-Path (Get-V4ReportsPath -Create) ('Snapshot-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Get-V4Snapshot | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $path -Encoding UTF8 -Width 350
    Write-Host "Snapshot saved: $path" -ForegroundColor Green
    Write-Host 'Save another later, then select Compare two snapshots.'
}
function Compare-SystemBaseline {
    $files=@(Get-ToolkitReportFiles -CurrentFolder (Get-V4ReportsPath) -LegacyName 'Windows11-ToolkitV4-Reports' -Pattern 'Snapshot-*.json')
    if($files.Count -lt 2){Write-Host 'Need at least two saved V4 snapshots. Run Save baseline now and later.' -ForegroundColor Yellow;return}
    Write-Host 'Select two snapshots by number:' -ForegroundColor Cyan
    for($i=0;$i -lt [math]::Min($files.Count,20);$i++){Write-Host (' {0}: {1}' -f ($i+1),$files[$i].FullName)}
    $oldPick=Read-Host 'BEFORE snapshot number (default 2)';$newPick=Read-Host 'AFTER snapshot number (default 1)'
    if(-not $oldPick){$oldPick='2'};if(-not $newPick){$newPick='1'}
    [int]$a=0;[int]$b=0
    if(-not [int]::TryParse($oldPick,[ref]$a) -or -not [int]::TryParse($newPick,[ref]$b) -or $a -lt 1 -or $b -lt 1 -or $a -gt $files.Count -or $b -gt $files.Count){Write-Host 'Invalid selection.';return}
    $before=Get-Content -LiteralPath $files[$a-1].FullName -Raw | ConvertFrom-Json
    $after=Get-Content -LiteralPath $files[$b-1].FullName -Raw | ConvertFrom-Json
    if(-not (Test-ToolkitSnapshotSchema $before.Schema) -or -not (Test-ToolkitSnapshotSchema $after.Schema)){throw 'Unknown snapshot format.'}
    $report=@("BEFORE: $($before.Date)","AFTER: $($after.Date)","Build: $($before.Build) -> $($after.Build)","BIOS: $($before.BIOS) -> $($after.BIOS)","Available RAM GB (point-in-time, not controlled benchmark): $($before.RAMFreeGB) -> $($after.RAMFreeGB)","Device errors: $(@($before.DevicesWithErrors | Where-Object { $_ }).Count) -> $(@($after.DevicesWithErrors).Count)", '')
    $index=@{};foreach($d in @($before.Drivers)){if($d.ID){$index[[string]$d.ID]=$d}}
    $changed=@()
    foreach($d in @($after.Drivers)){
        if($d.ID -and $index.ContainsKey([string]$d.ID) -and $index[[string]$d.ID].Version -ne $d.Version){
           $changed += [pscustomobject]@{Name=$d.Name;Old=$index[[string]$d.ID].Version;New=$d.Version}
        }
    }
    $report+= "DRIVER VERSION CHANGES ($($changed.Count))"
    $report+=($changed | Select-Object -First 40 | Format-Table -AutoSize -Wrap | Out-String -Width 180)
    $out=Join-Path (Get-V4ReportsPath -Create) ('Comparison-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $report | Out-File -LiteralPath $out -Encoding UTF8 -Width 190
    $report | ForEach-Object {Write-Host $_}
    Write-Host "Comparison saved: $out" -ForegroundColor Green
}
function Compare-BackupFolders {
    $src=(Read-Host 'Original folder path').Trim().Trim('"')
    $dst=(Read-Host 'Backup folder path').Trim().Trim('"')
    if(-not (Test-Path -LiteralPath $src -PathType Container) -or -not (Test-Path -LiteralPath $dst -PathType Container)){
       Write-Host 'One or both folders are missing. No files changed.' -ForegroundColor Yellow;return
    }
    $src=(Resolve-Path -LiteralPath $src).Path.TrimEnd('\')
    $dst=(Resolve-Path -LiteralPath $dst).Path.TrimEnd('\')
    if($src -eq $dst){Write-Host 'Source and backup are the same folder; select different folders.';return}
    Write-Host 'Reading file metadata. Large folders may take some time...' -ForegroundColor Cyan
    $a=@(Get-ChildItem -LiteralPath $src -Recurse -File -ErrorAction SilentlyContinue)
    $b=@(Get-ChildItem -LiteralPath $dst -Recurse -File -ErrorAction SilentlyContinue)
    $amap=@{};$bmap=@{}
    foreach($f in $a){$amap[$f.FullName.Substring($src.Length).TrimStart('\')]=$f}
    foreach($f in $b){$bmap[$f.FullName.Substring($dst.Length).TrimStart('\')]=$f}
    $mismatch=New-Object 'System.Collections.Generic.List[object]'
    foreach($relative in $amap.Keys){
       if(-not $bmap.ContainsKey($relative)){
          $mismatch.Add([pscustomobject]@{RelativePath=$relative;Difference='Missing in backup'})
       } elseif($amap[$relative].Length -ne $bmap[$relative].Length){
          $mismatch.Add([pscustomobject]@{RelativePath=$relative;Difference='Different file size'})
       }
    }
    foreach($relative in $bmap.Keys){if(-not $amap.ContainsKey($relative)){$mismatch.Add([pscustomobject]@{RelativePath=$relative;Difference='Only in backup'})}}
    Write-Host "Source: $($a.Count) files | Backup: $($b.Count) files | Differences: $($mismatch.Count)" -ForegroundColor Cyan
    if($mismatch.Count){$mismatch | Select-Object -First 40 | Format-Table -Wrap -AutoSize}
    $hashes=Read-Host 'Optional SHA256 comparison of matching files? Type HASH (can be slow), anything else skips'
    if($hashes -ceq 'HASH'){
       if($a.Count -gt 5000){Write-Host 'Over 5000 files; hash run skipped to avoid an extremely long scan. Split the folder.' -ForegroundColor Yellow}
       else {
          $count=0
          foreach($relative in $amap.Keys){
             if(-not $bmap.ContainsKey($relative) -or $amap[$relative].Length -ne $bmap[$relative].Length){continue}
             try{
                if((Get-FileHash -LiteralPath $amap[$relative].FullName -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $bmap[$relative].FullName -Algorithm SHA256).Hash){
                    $mismatch.Add([pscustomobject]@{RelativePath=$relative;Difference='Different SHA256 content'})
                }
             }catch{$mismatch.Add([pscustomobject]@{RelativePath=$relative;Difference='Hash could not be read'})}
             $count++
          }
          Write-Host "Hash-compared: $count matching files" -ForegroundColor Green
       }
    }
    $out=Join-Path (Get-V4ReportsPath -Create) ('Backup-Comparison-{0}.csv' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if($mismatch.Count){$mismatch | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $out;Write-Host "Differences saved: $out"}
    else{Write-Host 'No differences found by the selected checks. This does not establish storage media reliability.' -ForegroundColor Green}
}

# Experience profiles use existing power schemes only. They never download/enable new plans.
# Extra preferences are user-controlled Windows Settings pages, not registry hacks.
function Get-V4PowerScheme {
    $output=(& powercfg.exe /getactivescheme 2>&1 | Out-String)
    if($LASTEXITCODE -ne 0){throw "Cannot query active power plan: $output"}
    $match=[regex]::Match($output,'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}','IgnoreCase')
    if(-not $match.Success){throw "Cannot parse the active power plan: $output"}
    return $match.Value.ToLowerInvariant()
}
function Get-V4AvailableSchemes {
    $output=(& powercfg.exe /list 2>&1 | Out-String)
    if($LASTEXITCODE -ne 0){throw "Unable to list existing power schemes: $output"}
    return $output
}
function Get-V4ProfileFile {
    param([switch]$Create)
    $current=Join-Path (Join-Path $env:LOCALAPPDATA 'ToolkitV4') 'PowerPlan-Undo.json'
    $legacy=Join-Path (Join-Path $env:LOCALAPPDATA 'Windows11ToolkitV4') 'PowerPlan-Undo.json'
    $selected=Resolve-ToolkitUndoFile -CurrentFile $current -LegacyFile $legacy
    $dir=Split-Path -Parent $selected
    if($Create -and -not (Test-Path -LiteralPath $dir)){New-Item -Path $dir -ItemType Directory -Force | Out-Null}
    return $selected
}
function Get-V4DesiredScheme {
    param([string]$Name)
    switch ($Name) {
      'Gaming' {return '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'} # High Performance
      'Battery Saver' {return 'a1841308-3541-4fab-bc81-f71556f20b4a'}
      default {return '381b4222-f694-41f0-9685-ff5bb260df2e'} # Balanced
    }
}
function Show-ProfilePreview {
    param([ValidateSet('Gaming','Programming','Studying','Battery Saver')][string]$Name)
    Write-Host "`n$Name experience profile" -ForegroundColor Cyan
    $plan=switch($Name){'Gaming'{'High Performance (only if present)'}'Battery Saver'{'Power saver (only if present)'}default{'Balanced (only if present)'}}
    Write-Host "Layer 1: may change only your active power plan to $plan."
    switch($Name){
      'Gaming' { Write-Host 'Layer 2: opens Game Mode, per-app graphics, and notifications settings. It does NOT turn off Defender or force GPU settings.' }
      'Programming' { Write-Host 'Layer 2: opens Developer settings and Startup Apps. No service changes, no background app killing.' }
      'Studying' { Write-Host 'Layer 2: opens Notifications, Night Light and Power settings. No automatic silencing of reminders.' }
      'Battery Saver' { Write-Host 'Layer 2: opens Power & Battery settings. No battery/charging firmware changes.' }
    }
    Write-Host 'Layer 3: undo restores the original power plan saved before the first V4 profile change.'
    Write-Host 'If no requested power plan exists on this laptop, V4 leaves the active plan untouched.' -ForegroundColor Yellow
    try { Write-Host "Current power plan: $(Get-V4PowerScheme)" }
    catch { Write-Host $_.Exception.Message -ForegroundColor Yellow }
}
function Set-ExperienceProfile {
    param([ValidateSet('Gaming','Programming','Studying','Battery Saver')][string]$Name)
    # Validate any existing undo record before opening pages or changing a plan.
    $null=Get-V4ProfileFile
    Show-ProfilePreview -Name $Name
    $current=Get-V4PowerScheme
    $desired=Get-V4DesiredScheme -Name $Name
    $available=Get-V4AvailableSchemes
    if($current -eq $desired){Write-Host 'Requested power plan is already active. No power plan change needed.' -ForegroundColor Green}
    elseif($available -notmatch [regex]::Escape($desired)){
        Write-Host 'Requested scheme is not installed. No power plan change; only opening the relevant Windows settings.' -ForegroundColor Yellow
    } else {
        $state=Get-V4ProfileFile -Create
        $original=$null
        if(Test-Path -LiteralPath $state){
            try{$original=Get-Content -LiteralPath $state -Raw | ConvertFrom-Json}
            catch{Write-Host 'Previous undo record cannot be read. Power-plan change stopped.' -ForegroundColor Yellow;return}
        }
        if(-not $original){
           $original=[pscustomobject]@{InitialScheme=$current;SavedAt=(Get-Date).ToString('o')}
           $original | ConvertTo-Json | Out-File -LiteralPath $state -Encoding UTF8
        }
        & powercfg.exe /setactive $desired
        if($LASTEXITCODE -ne 0){Write-Host 'Windows rejected this power-plan change.' -ForegroundColor Red;return}
        Write-Host "Changed active scheme to $desired. Original is saved for undo." -ForegroundColor Green
    }
    $pages=switch($Name){
       'Gaming' {@('ms-settings:gaming-gamemode','ms-settings:display-advancedgraphics','ms-settings:notifications')}
       'Programming' {@('ms-settings:developers','ms-settings:startupapps')}
       'Studying' {@('ms-settings:notifications','ms-settings:nightlight','ms-settings:powersleep')}
       'Battery Saver' {@('ms-settings:powersleep')}
    }
    foreach($page in $pages){
       try {Start-Process $page -ErrorAction Stop} catch {Write-Host "Could not open $page" -ForegroundColor Yellow}
    }
}
function Restore-ExperienceProfile {
    $state=Get-V4ProfileFile
    if(-not (Test-Path -LiteralPath $state)){Write-Host 'No V4 original power plan saved. Nothing to restore.';return}
    $info=Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
    $guid=[string]$info.InitialScheme
    if($guid -notmatch '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'){throw 'Undo record contains an invalid scheme GUID. No changes made.'}
    if((Get-V4AvailableSchemes) -notmatch [regex]::Escape($guid)){Write-Host 'Original plan is no longer listed. Undo skipped; state retained.' -ForegroundColor Yellow;return}
    & powercfg.exe /setactive $guid
    if($LASTEXITCODE -eq 0){
       Remove-Item -LiteralPath $state -Force
       Write-Host "Original power plan $guid restored; toolkit undo marker cleared." -ForegroundColor Green
    } else {Write-Host 'Power plan restore failed. Undo marker retained.' -ForegroundColor Red}
}
function Show-ProfileState {
    try{Write-Host "Active power plan: $(Get-V4PowerScheme)"}catch{Write-Host $_.Exception.Message}
    $path=Get-V4ProfileFile
    if(Test-Path -LiteralPath $path){Get-Content -LiteralPath $path -Raw | Write-Host}
    else {Write-Host 'No saved V4 power-plan change.'}
}

# Optional, explicitly chosen WinGet packages only. Do not suggest these are required OS apps.
$script:CuratedApps=@(
  [pscustomobject]@{Name='Microsoft PowerToys';Id='Microsoft.PowerToys';Use='Windows productivity shortcuts'},
  [pscustomobject]@{Name='Windows Terminal';Id='Microsoft.WindowsTerminal';Use='Tabbed console'},
  [pscustomobject]@{Name='PowerShell 7';Id='Microsoft.PowerShell';Use='Optional modern PowerShell alongside 5.1'},
  [pscustomobject]@{Name='Visual Studio Code';Id='Microsoft.VisualStudioCode';Use='Lightweight code editor'},
  [pscustomobject]@{Name='Git';Id='Git.Git';Use='Local version control'},
  [pscustomobject]@{Name='7-Zip';Id='7zip.7zip';Use='Local ZIP/7z archive tool'},
  [pscustomobject]@{Name='Notepad++';Id='Notepad++.Notepad++';Use='Text editor'},
  [pscustomobject]@{Name='VLC media player';Id='VideoLAN.VLC';Use='Video and audio playback'},
  [pscustomobject]@{Name='Google Chrome';Id='Google.Chrome';Use='Web browser'},
  [pscustomobject]@{Name='.NET 10 SDK';Id='Microsoft.DotNet.SDK.10';Use='C#/.NET development'}
)
function Show-CuratedInstaller {
    if(-not (Get-Command winget -ErrorAction SilentlyContinue)){Write-Host 'WinGet not found. Open Microsoft Store > App Installer.' -ForegroundColor Yellow;return}
    Write-Host "`nOPTIONAL APPLICATIONS - Not all are needed. Select ONE." -ForegroundColor Cyan
    for($i=0;$i -lt $script:CuratedApps.Count;$i++){
       $app=$script:CuratedApps[$i];Write-Host (' {0,2}. {1,-25} {2}' -f ($i+1),$app.Name,$app.Use)
    }
    $pick=Read-Host 'App number to preview, or Enter to cancel'
    if($pick -notmatch '^\d{1,2}$'){Write-Host 'Cancelled.';return}
    $idx=[int]$pick-1
    if($idx -lt 0 -or $idx -ge $script:CuratedApps.Count){Write-Host 'No such entry.';return}
    $selected=$script:CuratedApps[$idx]
    Write-Host "`nWinGet package metadata for $($selected.Name):" -ForegroundColor Cyan
    & winget.exe show --id $selected.Id --exact --source winget
    if($LASTEXITCODE -ne 0){Write-Host 'Package not found in source. Nothing installed.' -ForegroundColor Yellow;return}
    Write-Host 'Review publisher, version and terms above. This is a third-party/app download, NOT a Windows security requirement.' -ForegroundColor Yellow
    $confirm=Read-Host "Type INSTALL to run only $($selected.Name), or anything else to cancel"
    if($confirm -cne 'INSTALL'){Write-Host 'Cancelled.';return}
    & winget.exe install --id $selected.Id --exact --source winget
    if($LASTEXITCODE -ne 0){Write-Host "Install exited with code $LASTEXITCODE; review the output." -ForegroundColor Yellow}
}
function New-DeveloperDoctor {
    $path=Join-Path (Get-V4ReportsPath -Create) ('Developer-Doctor-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $out=@('DEVELOPER ENVIRONMENT DOCTOR '+(Get-Date),'No dependencies installed or changed.', '')
    foreach($tool in @('python','py','node','npm','dotnet','git','cmake','ninja','winget')){
        $cmd=Get-Command $tool -ErrorAction SilentlyContinue
        if($cmd){$out+= ('{0}: {1}' -f $tool,$cmd.Source)}else{$out+= "${tool}: NOT ON PATH (may still be installed inside Visual Studio)"}
    }
    $out+='PYTHON LAUNCHER VERSIONS:'
    if(Get-Command py -ErrorAction SilentlyContinue){$out+=(& py --list-paths 2>&1|Out-String)}
    $out+='DOTNET SDK VERSIONS:'
    if(Get-Command dotnet -ErrorAction SilentlyContinue){$out+=(& dotnet --list-sdks 2>&1|Out-String)}
    $vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $out+='VISUAL STUDIO BUILD TOOLS:'
    if(Test-Path -LiteralPath $vswhere){$out+=(& $vswhere -products '*' -property installationPath |Out-String)}
    else{$out+='vswhere.exe not found'}
    $out | Out-File -LiteralPath $path -Encoding UTF8 -Width 180
    Write-Host "Developer report saved: $path" -ForegroundColor Green
}
function Show-WinGetUpdates {
    if(Get-Command winget -ErrorAction SilentlyContinue){& winget.exe upgrade}
    else{Write-Host 'WinGet unavailable.'}
}
function Show-CommandPaths {
    foreach($name in @('powershell','python','py','node','npm','dotnet','git','winget','cmake','ninja')){
       $cmd=Get-Command $name -ErrorAction SilentlyContinue
       if($cmd){Write-Host ('{0,-15} {1}' -f $name,$cmd.Source)}else{Write-Host ('{0,-15} {1}' -f $name,'Not on PATH')}
    }
}
function Test-DownloadSignature {
    $path=(Read-Host 'Full path to downloaded file').Trim('"')
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){Write-Host 'File not found';return}
    Write-Host 'Digital signature:' -ForegroundColor Cyan
    Get-AuthenticodeSignature -LiteralPath $path | Select-Object Status,StatusMessage,@{N='Signer';E={$_.SignerCertificate.Subject}} | Format-List
    Write-Host 'SHA256 (compare with a publisher-provided checksum):' -ForegroundColor Cyan
    Get-FileHash -LiteralPath $path -Algorithm SHA256 | Format-List
    Write-Host 'A valid signature and matching official checksum help validate source/integrity; neither guarantees software quality.'
}

function Show-TroubleshootingWizard {
    $issues=@(
      [pscustomobject]@{Title='Windows errors or corrupt files';Checks='DISM CheckHealth (R01), SFC verify (R03), recent event log (R07)';Next='If corruption found: Repair Kit R04 (DISM then SFC)'},
      [pscustomobject]@{Title='Taskbar/Explorer unresponsive';Checks='Crash history (R12), Task Manager (R11)';Next='Repair Kit R09 - Restart Explorer/taskbar'},
      [pscustomobject]@{Title='Slow RAM / background applications';Checks='V4 tool 132 Startup & heavy RAM report; baseline V4 tool 128';Next='Close unneeded applications individually, not Windows processes'},
      [pscustomobject]@{Title='Windows Security warning';Checks='V4 tool 126 Security overview; Repair Kit R19/R23/R25';Next='Defender scan (R21), signature update (R22) only when relevant'},
      [pscustomobject]@{Title='Broken downloads / mobile hotspot';Checks='Repair Kit R27-R30 connectivity, R39 ZIP integrity';Next='Network checks first; DNS flush R31 only when DNS fails'},
      [pscustomobject]@{Title='Screen flicker or graphics trouble';Checks='Repair Kit R15 display diagnostics, Device Manager (R34)';Next='Win+Ctrl+Shift+B for short display-driver refresh'},
      [pscustomobject]@{Title='Apps / Microsoft Store failures';Checks='Repair Kit R14 installed app Repair option; event log R07';Next='Store cache reset R13 if Store specifically affected'},
      [pscustomobject]@{Title='Driver problem or yellow warning';Checks='Repair Kit R34; V4 snapshot before changes';Next='Official Windows optional updates R36 or device vendor support'},
      [pscustomobject]@{Title='Backup copied incompletely';Checks='V4 tool 130 Folder backup comparison; R39 ZIP integrity';Next='Copy missing files after report, no automated deletions'},
      [pscustomobject]@{Title='Audio / printer / update stuck';Checks='R17 (audio), R47 (spooler), R43 (updates)';Next='Targeted R18/R48 repairs, only if that component fails'}
    )
    Write-Host "`nCHOOSE A SYMPTOM - SUGGESTS ONLY, DOES NOT AUTO-RUN REPAIRS" -ForegroundColor Cyan
    for($i=0;$i -lt $issues.Count;$i++){Write-Host (' {0,2}. {1}' -f ($i+1),$issues[$i].Title)}
    $num=Read-Host 'Number or Enter to return'
    if($num -notmatch '^\d{1,2}$'){return}
    $ix=[int]$num-1
    if($ix -lt 0 -or $ix -ge $issues.Count){Write-Host 'Unknown symptom.';return}
    $choice=$issues[$ix]
    Write-Host "`n$($choice.Title)" -ForegroundColor Yellow
    Write-Host "CHECK FIRST: $($choice.Checks)"
    Write-Host "IF NEEDED: $($choice.Next)"
    Write-Host 'Open the Repair Kit separately (main tool 121), choose the indicated read-only checks, then decide whether a repair is justified.'
}
function Show-AllTasks {
    Write-Host 'Opening Windows All Tasks (sometimes called God Mode). This only opens a shell view.'
    Start-Process explorer.exe -ArgumentList 'shell:::{ED7BA470-8E54-465E-825C-99712043E01C}'
}
function Show-HiddenFolders {
    $destinations=@(
     [pscustomobject]@{Label='Installed Apps Folder';Path='shell:AppsFolder'},
     [pscustomobject]@{Label='Send To shortcuts';Path='shell:SendTo'},
     [pscustomobject]@{Label='Your startup shortcuts';Path='shell:Startup'},
     [pscustomobject]@{Label='Recycle Bin';Path='shell:RecycleBinFolder'},
     [pscustomobject]@{Label='Downloads';Path='shell:Downloads'}
    )
    for($i=0;$i -lt $destinations.Count;$i++){Write-Host " $($i+1). $($destinations[$i].Label)"}
    $s=Read-Host 'Number to open or Enter to cancel'
    if($s -notmatch '^[1-5]$'){return}
    Start-Process explorer.exe -ArgumentList $destinations[[int]$s-1].Path
}
function Show-RunTricks {
    @('
HIDDEN WIN+R SHORTCUTS',
    ' perfmon /rel    Reliability Monitor',
    ' resmon          Resource Monitor',
    ' dxdiag          DirectX details',
    ' joy.cpl         Game controller configuration',
    ' colorcpl        Color management',
    ' dccw            Display calibration wizard',
    ' shell:AppsFolder All applications',
    ' shell:SendTo    Send-to shortcuts',
    ' optionalfeatures Windows optional features',
    ' msinfo32        System Information',
    ' winver          Windows version',
    ' control folders File Explorer options',
    ' mstsc           Remote Desktop Connection (only if needed)',
    ' cmd            Command Prompt') | ForEach-Object{Write-Host $_}
}
function Show-KeyboardTricks {
    @('WINDOWS 11 KEYBOARD TRICKS',
    ' Win + .                Emoji picker',
    ' Win + V                Clipboard history',
    ' Win + Shift + S        Snipping overlay',
    ' Win + Ctrl + Shift + B Refresh graphics driver display pipeline',
    ' Win + Ctrl + D         Create virtual desktop',
    ' Win + Ctrl + Left/Right Switch virtual desktops',
    ' Win + Ctrl + F4        Close current virtual desktop',
    ' Win + Tab              Task View',
    ' Win + R                Run dialog',
    ' Win + X                Quick Link menu',
    ' Win + E                File Explorer',
    ' Win + L                Lock session',
    ' Ctrl + Shift + Esc     Task Manager',
    ' Win + Z                Snap Layouts') | ForEach-Object{Write-Host $_}
}
function Show-MatrixRain {
    Write-Host 'Harmless terminal-only animation. Press Ctrl+C to stop.' -ForegroundColor Green
    $alphabet='01ABCDEF#$%@'
    for($i=0;$i -lt 36;$i++){
       $line=-join (1..65 | ForEach-Object{$alphabet[(Get-Random -Minimum 0 -Maximum $alphabet.Length)]})
       Write-Host $line -ForegroundColor Green
       Start-Sleep -Milliseconds 60
    }
    Write-Host 'Matrix effect finished. No Windows settings changed.' -ForegroundColor Cyan
}
function Show-FunTip {
    $tips=@(
      'Try Win + . for emoji, kaomoji, and symbols.',
      'Press Win + V to enable or inspect Clipboard History.',
      'Press Win + Z to view Snap Layouts.',
      'Type shell:AppsFolder into Win+R for a list of applications.',
      'Try perfmon /rel for a surprisingly useful reliability timeline.',
      'Hold Shift while right-clicking a folder for more context-menu actions.',
      'Use Win + Ctrl + D to create an extra virtual desktop.',
      'You can use Win + Shift + S to capture only part of the screen.',
      'USB tethering and Wi-Fi hotspot are different ways to connect your phone.',
      'File Explorer can show hidden extensions in View > Show > File name extensions.'
    )
    Write-Host (Get-Random -InputObject $tips) -ForegroundColor Green
}
function Show-BootEntries {
    Write-Host 'Read-only firmware boot entries. Do not edit BCD merely to remove an old Ubuntu label.' -ForegroundColor Yellow
    & bcdedit.exe /enum firmware
}
function Show-ServiceInsight {
    $name=Read-Host 'Service name fragment (e.g. Spooler, wuauserv) or Enter for a short list'
    if(-not $name){Get-Service | Select-Object -First 35 Name,Status,StartType | Format-Table -AutoSize;return}
    Get-CimInstance Win32_Service | Where-Object {$_.Name -like "*$name*" -or $_.DisplayName -like "*$name*"} |
      Select-Object Name,DisplayName,State,StartMode,PathName | Format-List
}
function Show-TaskInsight {
    $filter=Read-Host 'Scheduled task name fragment (blank to list 25 tasks)'
    $tasks=@(Get-ScheduledTask -ErrorAction SilentlyContinue)
    if($filter){$tasks=@($tasks | Where-Object {$_.TaskName -like "*$filter*" -or $_.TaskPath -like "*$filter*"})}
    $tasks|Select-Object -First 25 TaskName,TaskPath,State | Format-Table -AutoSize
    Write-Host "Matching task count: $($tasks.Count). Nothing enabled/disabled." -ForegroundColor Cyan
}
function Show-NetworkRoutes {
    Get-NetRoute -AddressFamily IPv4 | Sort-Object RouteMetric | Select-Object -First 25 InterfaceAlias,DestinationPrefix,NextHop,RouteMetric | Format-Table -AutoSize
    Get-NetAdapter | Select-Object Name,Status,LinkSpeed | Format-Table -AutoSize
}
function Show-PerformanceTools {
    Start-Process resmon.exe
    Start-Process perfmon.exe
    Start-Process perfmon.exe -ArgumentList '/rel'
}
function Restart-ExplorerV4 {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-Host 'Explorer and taskbar restart requested. Open Explorer windows may have closed.'
}

function Show-MemoryDelta {
    $before=@{}
    foreach($p in (Get-Process -ErrorAction SilentlyContinue)){$before[[string]$p.Id]=[pscustomobject]@{Name=$p.ProcessName;MB=[math]::Round($p.WorkingSet64/1MB,1)}}
    Write-Host 'Sampling working-set memory for 10 seconds (read-only)...' -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    $rows=@()
    foreach($p in (Get-Process -ErrorAction SilentlyContinue)){
      $key=[string]$p.Id
      if($before.ContainsKey($key)){
        $delta=[math]::Round(($p.WorkingSet64/1MB)-$before[$key].MB,1)
        if([math]::Abs($delta) -ge 3){$rows += [pscustomobject]@{Name=$p.ProcessName;PID=$p.Id;DeltaMB=$delta}}
      }
    }
    $rows | Sort-Object {[math]::Abs($_.DeltaMB)} -Descending | Select-Object -First 20 | Format-Table -AutoSize
    Write-Host 'Working-set changes are not proof of leaks; shared/cached memory can fluctuate.'
}
function Show-UnsignedDrivers {
    $drivers=@(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.IsSigned -eq $false })
    Write-Host "Windows reports $($drivers.Count) installed driver records marked unsigned." -ForegroundColor Cyan
    $drivers | Select-Object -First 30 DeviceName,DriverProviderName,DriverVersion,InfName | Format-Table -AutoSize -Wrap
    Write-Host 'Some drivers may lack an inspectable signature in this inventory. Do not remove them automatically.'
}
