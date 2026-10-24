#requires -Version 5.1
# Toolkit - guided diagnostics and repairs.
# Loaded without side effects; all actions require explicit menu selection.
# No firmware, boot configuration, Insider settings, TPM or encryption changes.

function Get-ToolkitReportFolder {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if (-not $docs -or -not (Test-Path -LiteralPath $docs)) { $docs = $env:USERPROFILE }
    $folder = Join-Path $docs 'Toolkit-Reports'
    if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null }
    return $folder
}
function New-ToolkitFinding {
    param(
        [string]$Id, [string]$Check,
        [ValidateSet('PASS','WARNING','ERROR','NO DATA')][string]$Status,
        [string]$Summary, [string]$Detail = '', [string]$SuggestedAction = ''
    )
    return [pscustomobject]@{
        Id = $Id; Check = $Check; Status = $Status
        Summary = $Summary; Detail = $Detail; SuggestedAction = $SuggestedAction
    }
}
function Add-ToolkitFinding {
    param([System.Collections.ArrayList]$Results,[string]$Id,[string]$Check,[string]$Status,[string]$Summary,
          [string]$Detail='', [string]$SuggestedAction='')
    [void]$Results.Add((New-ToolkitFinding -Id $Id -Check $Check -Status $Status -Summary $Summary -Detail $Detail -SuggestedAction $SuggestedAction))
}
function Show-ToolkitFinding {
    param($Finding)
    $color = switch($Finding.Status){ 'PASS' {'Green'} 'WARNING' {'Yellow'} 'ERROR' {'Red'} default {'Gray'} }
    Write-Host ('[{0,-7}] {1,-25} {2}' -f $Finding.Status,$Finding.Check,$Finding.Summary) -ForegroundColor $color
}
function Save-ToolkitDiagnostics {
    param([string]$Mode,[System.Collections.ArrayList]$Results)
    $time = Get-Date
    $stamp = $time.ToString('yyyyMMdd-HHmmss-fff')
    $dir = Get-ToolkitReportFolder
    $base = ('{0}-{1}' -f $Mode.Replace(' ','-'),$stamp)
    $txt = Join-Path $dir ($base+'.txt')
    $json = Join-Path $dir ($base+'.json')
    $counts = @{}
    foreach($s in @('PASS','WARNING','ERROR','NO DATA')) { $counts[$s] = @($Results | Where-Object Status -eq $s).Count }
    $report = [pscustomobject]@{
        Schema='Toolkit-Diagnostic-2';Mode=$Mode;Generated=$time.ToString('o');
        Computer=$env:COMPUTERNAME;Count=$Results.Count;Summary=$counts;Findings=@($Results.ToArray())
    }
    $report | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $json -Encoding UTF8 -Width 300
    $lines=New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('TOOLKIT V5.1 - '+$Mode.ToUpper())
    $lines.Add('Created: '+$time.ToString('yyyy-MM-dd HH:mm:ss zzz'))
    $lines.Add('Read-only diagnostics. Report can contain private computer and network details.')
    $lines.Add('PASS='+$counts['PASS']+' | WARNING='+$counts['WARNING']+' | ERROR='+$counts['ERROR']+' | NO DATA='+$counts['NO DATA'])
    $lines.Add('')
    foreach($item in $Results){
        $lines.Add(('['+$item.Status+'] '+$item.Id+' '+$item.Check+': '+$item.Summary))
        if($item.Detail) {$lines.Add('   Checked: '+$item.Detail)}
        if($item.SuggestedAction) {$lines.Add('   Suggested: '+$item.SuggestedAction)}
    }
    $lines | Out-File -LiteralPath $txt -Encoding UTF8 -Width 220
    Write-Host "`nRESULT: $($Results.Count) checks | PASS $($counts['PASS']) | WARNING $($counts['WARNING']) | ERROR $($counts['ERROR']) | NO DATA $($counts['NO DATA'])" -ForegroundColor Cyan
    Write-Host "SAVED: $txt" -ForegroundColor Green
    Write-Host "SAVED: $json" -ForegroundColor Green
    Write-Host 'Review/redact reports before uploading or sharing.' -ForegroundColor DarkYellow
    return [pscustomobject]@{Mode=$Mode;Items=@($Results.ToArray());TextPath=$txt;JsonPath=$json;Summary=$counts}
}
function Get-ToolkitRecentExplorerCrashes {
    param([int]$Days=7)
    # Restrict by event ID/provider first, then match structured payload instead of English-only Message.
    # WER 1001 can describe the same incident; never count it again as an extra crash.
    try {
        $events=@(Get-WinEvent -FilterHashtable @{
            LogName='Application'; Id=1000; StartTime=(Get-Date).AddDays(-$Days)
        } -ErrorAction Stop)
        $matches=New-Object System.Collections.ArrayList
        foreach($event in $events){
            $match=$false
            if(([string]$event.Message) -match '(?i)Faulting application name:\s*Explorer(?:\.exe)?\b'){$match=$true}
            if(-not $match -and @($event.Properties).Count -gt 0){
                $name=[string]$event.Properties[0].Value
                if($name -match '(?i)^Explorer(?:\.exe)?$'){$match=$true}
            }
            if(-not $match){
                try {
                    $xml=[xml]$event.ToXml()
                    $d=@($xml.Event.EventData.Data)
                    if($d.Count -and ([string]$d[0].'#text') -match '(?i)^Explorer(?:\.exe)?$'){$match=$true}
                }catch{}
            }
            if($match){[void]$matches.Add($event)}
        }
        return @{Success=$true;Data=@($matches.ToArray());Inspected=$events.Count;WindowDays=$Days}
    } catch {
        if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound' -or $_.Exception.Message -match 'No events were found') {
            return @{Success=$true;Data=@();Inspected=0;WindowDays=$Days}
        }
        return @{Success=$false;Message=$_.Exception.Message;Data=@();Inspected=0;WindowDays=$Days}
    }
}
function Get-ToolkitEventMessage {
    param($Event)
    $msg=([string]$Event.Message).Trim()
    if($msg){return $msg}
    try {
        # Some CodexSandboxService and driver events have no rendered message.
        $parts=New-Object 'System.Collections.Generic.List[string]'
        $xml=[xml]$Event.ToXml()
        foreach($d in @($xml.Event.EventData.Data)){
            if($null -ne $d){
                $label=if($d.Name){[string]$d.Name}else{'EventData'}
                $value=[string]$d.'#text'
                if($value){$parts.Add(('{0}: {1}' -f $label,$value))}
            }
        }
        if($parts.Count){return ($parts -join '; ')}
    }catch{}
    return 'No readable event text or event payload; look up the Event ID in Event Viewer.'
}
function Add-ToolkitEventLogFindings {
    param([System.Collections.ArrayList]$Results,[string]$LogName,[string]$Id,[string]$Title)
    $since=(Get-Date).AddHours(-48)
    try {
        $events=@(Get-WinEvent -FilterHashtable @{
            LogName=$LogName;Level=@(1,2);StartTime=$since
        } -MaxEvents 300 -ErrorAction Stop)
        $groups=@($events | Group-Object ProviderName,Id | Sort-Object Count -Descending)
        $top=(($groups | Select-Object -First 4 | ForEach-Object {
            # Include event IDs so repeated failures can be diagnosed without a second command.
            '{0} (ID {1})={2}' -f $_.Group[0].ProviderName,$_.Group[0].Id,$_.Count
        }) -join '; ')
        $latest=($events|Sort-Object TimeCreated -Descending|Select-Object -First 1).TimeCreated
        $boot=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $sinceBoot=@($events|Where-Object {$boot -and $_.TimeCreated -ge $boot.LastBootUpTime}).Count
        $dir=Get-ToolkitReportFolder
        $path=Join-Path $dir ('{0}-Events-{1}.txt' -f $LogName,(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        $lines=New-Object 'System.Collections.Generic.List[string]'
        $lines.Add('Toolkit V5.1 - '+$LogName+' events (read-only)')
        $lines.Add('Created: '+(Get-Date).ToString('o'))
        $lines.Add('This report may contain local paths and private information. Review before sharing.')
        $lines.Add('Last 48 hours: '+$events.Count+' events (maximum 300 shown)')
        $lines.Add('Since current boot: '+$sinceBoot+' events (based on boot timestamp)')
        $lines.Add('')
        foreach($event in ($events|Sort-Object TimeCreated -Descending)){
            $lines.Add(('--- {0:o} | {1} | Event {2} | Level {3} ---' -f $event.TimeCreated,$event.ProviderName,$event.Id,$event.LevelDisplayName))
            $lines.Add((Get-ToolkitEventMessage $event))
            $lines.Add('')
        }
        $lines|Out-File -LiteralPath $path -Encoding UTF8 -Width 250 -ErrorAction Stop
        $desc='{0} event(s) in 48h; {1} since last boot; latest {2}; top: {3}' -f $events.Count,$sinceBoot,$latest,$top
        Add-ToolkitFinding $Results $Id $Title 'WARNING' $desc ('Provider / Event ID / timestamp / event payload. Full details saved: '+$path) 'Correlate event time with real symptoms; avoid resetting drivers/services based on log counts alone.'
    } catch {
        if ($_.FullyQualifiedErrorId -match 'NoMatchingEventsFound' -or $_.Exception.Message -match 'No events were found') {
            Add-ToolkitFinding $Results $Id $Title 'PASS' 'No matching critical/error events in the accessible 48-hour log.' ('Windows '+$LogName+' event log; levels 1 and 2; absence of events is not proof of zero historical faults.')
        }else{
            Add-ToolkitFinding $Results $Id $Title 'ERROR' $_.Exception.Message ('Event log: '+$LogName+'; possible permissions or report write failure.')
        }
    }
}
function Get-ToolkitGeneralDiagnostics {
    param([System.Collections.ArrayList]$Results)
    Write-Host "`nRunning general read-only Windows diagnostics..." -ForegroundColor Cyan
    try {
        $reg=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $build=''+$reg.CurrentBuild+'.'+$reg.UBR
        Add-ToolkitFinding $Results 'OS' 'Windows version' 'PASS' ("Version $($reg.DisplayVersion) / build $build") 'Registry DisplayVersion, CurrentBuild and UBR; legacy ProductName may say Windows 10.'
    } catch {Add-ToolkitFinding $Results 'OS' 'Windows version' 'ERROR' $_.Exception.Message 'CurrentVersion registry path'}
    try {
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        if ($os.TotalVisibleMemorySize -le 0) {throw 'Invalid memory totals from Windows.'}
        $used=[math]::Round(100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize),1)
        $free=[math]::Round($os.FreePhysicalMemory/1MB,2)
        $status=if($used -ge 80){'WARNING'}else{'PASS'}
        Add-ToolkitFinding $Results 'MEMORY' 'Memory pressure' $status ("$used% used; $free GB available") 'CIM physical memory; 80%+ is a performance flag, not proof of a defect.' 'Close unused memory-heavy apps if responsiveness suffers.'
    } catch {Add-ToolkitFinding $Results 'MEMORY' 'Memory pressure' 'ERROR' $_.Exception.Message 'Win32_OperatingSystem memory counters'}
    try {
        $cpus=@(Get-CimInstance Win32_Processor -ErrorAction Stop | Where-Object {$null -ne $_.LoadPercentage})
        if($cpus.Count -eq 0){Add-ToolkitFinding $Results 'CPU' 'CPU activity' 'NO DATA' 'CPU load counters unavailable.' 'Win32_Processor LoadPercentage'}
        else {
            $load=[math]::Round(($cpus|Measure-Object LoadPercentage -Average).Average,0)
            $s=if($load -ge 85){'WARNING'}else{'PASS'}
            Add-ToolkitFinding $Results 'CPU' 'CPU activity' $s ("Approximate CPU load: $load%") 'Single snapshot; short bursts may be normal.'
        }
    } catch {Add-ToolkitFinding $Results 'CPU' 'CPU activity' 'ERROR' $_.Exception.Message 'Win32_Processor'}
    try {
        $disk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        if(-not $disk -or $disk.Size -le 0){Add-ToolkitFinding $Results 'SPACE' 'Windows drive space' 'NO DATA' 'System drive capacity unavailable.' 'Win32_LogicalDisk C:'}
        else {
            $pct=[math]::Round(100*$disk.FreeSpace/$disk.Size,1)
            $gb=[math]::Round($disk.FreeSpace/1GB,1)
            $st=if($pct -lt 15){'WARNING'}else{'PASS'}
            Add-ToolkitFinding $Results 'SPACE' 'Windows drive space' $st ("$gb GB free ($pct%) on C:") 'Logical C: drive free space' 'Consider Storage Settings if free space is under 15%.'
        }
    } catch {Add-ToolkitFinding $Results 'SPACE' 'Windows drive space' 'ERROR' $_.Exception.Message 'Win32_LogicalDisk'}
    try {
        $physical=@(Get-PhysicalDisk -ErrorAction Stop)
        if($physical.Count -eq 0){Add-ToolkitFinding $Results 'DISKS' 'Drive health' 'NO DATA' 'Physical disk provider returned no disks.' 'Get-PhysicalDisk'}
        else {
            $bad=@($physical|Where-Object {$_.HealthStatus -ne 'Healthy'})
            $info=($physical|ForEach-Object {"$($_.FriendlyName)=$($_.HealthStatus)"}) -join '; '
            $st=if($bad.Count -gt 0){'WARNING'}else{'PASS'}
            Add-ToolkitFinding $Results 'DISKS' 'Drive health' $st $info 'Windows storage provider basic health only; not a complete SMART test.'
        }
    } catch {Add-ToolkitFinding $Results 'DISKS' 'Drive health' 'ERROR' $_.Exception.Message 'Get-PhysicalDisk'}
    try {
        $explorer=@(Get-Process explorer -ErrorAction SilentlyContinue)
        $st=if($explorer.Count){'PASS'}else{'WARNING'}
        Add-ToolkitFinding $Results 'EXPLORER' 'Explorer running' $st ("Process count: $($explorer.Count)") 'Explorer.exe current process status, not stability.' 'If the shell is stuck, use guided Restart Explorer.'
    } catch {Add-ToolkitFinding $Results 'EXPLORER' 'Explorer running' 'ERROR' $_.Exception.Message 'Get-Process explorer'}
    $crash=Get-ToolkitRecentExplorerCrashes -Days 7
    if(-not $crash.Success){Add-ToolkitFinding $Results 'EXPLORER_CRASH' 'Explorer crash history' 'ERROR' $crash.Message 'Application event ID 1000, last 7 days.'}
    elseif(@($crash.Data).Count -eq 0){Add-ToolkitFinding $Results 'EXPLORER_CRASH' 'Explorer crash history' 'PASS' 'No Explorer crash found in accessible 7-day event log.' ('Application error events inspected: '+$crash.Inspected+'; events may have been cleared or rotated, so this is not proof that no crash occurred.')}
    else {
        $latest=@($crash.Data|Sort-Object TimeCreated -Descending)[0]
        $module=if($latest.Message -match '(?im)^Faulting module name:\s*([^,\r\n]+)'){$matches[1]}else{'unknown'}
        $code=if($latest.Message -match '(?im)^Exception code:\s*([^\r\n]+)'){$matches[1]}else{'not in event'}
        Add-ToolkitFinding $Results 'EXPLORER_CRASH' 'Explorer crash history' 'WARNING' ("$(@($crash.Data).Count) crashes; newest $($latest.TimeCreated); module $module; exception $code") 'Application Event ID 1000, last 7 days; WER 1001 entries are not double-counted; past crash does not prove a current fault.' 'Only restart Explorer if it is presently unresponsive.'
    }
    try {
        $faults=@(Get-PnpDevice -ErrorAction Stop | Where-Object Status -eq 'Error')
        if($faults.Count -gt 0){Add-ToolkitFinding $Results 'DEVICES' 'Device errors' 'WARNING' ("$($faults.Count): " + (($faults|Select-Object -First 4 -ExpandProperty FriendlyName) -join ', ')) 'Get-PnpDevice actual Error status; intentionally disabled/Unknown devices excluded.' 'Inspect Device Manager and official vendor support.'}
        else{Add-ToolkitFinding $Results 'DEVICES' 'Device errors' 'PASS' 'No devices with Error status detected.' 'Get-PnpDevice Status=Error; not an online latest-driver check.'}
    } catch {Add-ToolkitFinding $Results 'DEVICES' 'Device errors' 'ERROR' $_.Exception.Message 'Get-PnpDevice'}
    try {
        $mp=Get-MpComputerStatus -ErrorAction Stop
        if($null -eq $mp -or $null -eq $mp.RealTimeProtectionEnabled){Add-ToolkitFinding $Results 'DEFENDER' 'Defender status' 'NO DATA' 'No readable Defender status.' 'Get-MpComputerStatus'}
        else {
            $st=if($mp.RealTimeProtectionEnabled -and $mp.AntivirusEnabled){'PASS'}else{'WARNING'}
            $sig=[string]$mp.AntivirusSignatureLastUpdated
            Add-ToolkitFinding $Results 'DEFENDER' 'Defender status' $st ("Antivirus=$($mp.AntivirusEnabled); real time=$($mp.RealTimeProtectionEnabled); definitions=$sig") 'Read-only Microsoft Defender status.'
        }
    } catch {Add-ToolkitFinding $Results 'DEFENDER' 'Defender status' 'NO DATA' $_.Exception.Message 'Third-party antivirus or absent Defender module may explain this.'}
    try {
        $profiles=@(Get-NetFirewallProfile -ErrorAction Stop)
        if($profiles.Count -eq 0){Add-ToolkitFinding $Results 'FIREWALL' 'Firewall status' 'NO DATA' 'No firewall profiles were returned.' 'Get-NetFirewallProfile'}
        else {
            $off=@($profiles|Where-Object {-not $_.Enabled})
            $st=if($off.Count){'WARNING'}else{'PASS'}
            $desc=($profiles|ForEach-Object {"$($_.Name)=$($_.Enabled)"}) -join ', '
            Add-ToolkitFinding $Results 'FIREWALL' 'Firewall status' $st $desc 'No firewall settings changed.'
        }
    } catch {Add-ToolkitFinding $Results 'FIREWALL' 'Firewall status' 'ERROR' $_.Exception.Message 'Get-NetFirewallProfile'}
    try {
        $pending=@()
        if(Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'){$pending+='Component servicing'}
        if(Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'){$pending+='Windows Update'}
        $st=if($pending.Count){'WARNING'}else{'PASS'}
        $desc=if($pending.Count){'Restart marker(s): '+($pending -join ', ')}else{'No checked restart markers found.'}
        Add-ToolkitFinding $Results 'REBOOT' 'Pending restart' $st $desc 'Checks two update and servicing markers; other restart reasons may exist.' 'Restart at a convenient time after saving work.'
    } catch {Add-ToolkitFinding $Results 'REBOOT' 'Pending restart' 'ERROR' $_.Exception.Message 'Registry restart indicators'}
}
function Add-ToolkitDeepDiagnostics {
    param([System.Collections.ArrayList]$Results)
    Write-Host "`nRunning additional deep read-only inspections..." -ForegroundColor Cyan
    Add-ToolkitEventLogFindings -Results $Results -LogName 'System' -Id 'SYSTEM_EVENTS' -Title 'System error events'
    Add-ToolkitEventLogFindings -Results $Results -LogName 'Application' -Id 'APP_EVENTS' -Title 'Application error events'
    try {
        $tops=@(Get-Process -ErrorAction Stop|Group-Object ProcessName|ForEach-Object {
            [pscustomobject]@{Name=$_.Name;Count=$_.Count;MB=[math]::Round(($_.Group|Measure-Object WorkingSet64 -Sum).Sum/1MB,0)}
        }|Sort-Object MB -Descending|Select-Object -First 8)
        $summary=($tops|ForEach-Object {"$($_.Name)=$($_.MB)MB ($($_.Count))"}) -join '; '
        Add-ToolkitFinding $Results 'TOP_PROCESSES' 'Memory-heavy apps' 'PASS' $summary 'Summed working sets are approximate and can double-count shared memory; no processes terminated.'
    } catch {Add-ToolkitFinding $Results 'TOP_PROCESSES' 'Memory-heavy apps' 'ERROR' $_.Exception.Message 'Get-Process working sets'}
    try {
        $start=@(Get-CimInstance Win32_StartupCommand -ErrorAction Stop)
        Add-ToolkitFinding $Results 'STARTUP' 'Startup registrations' 'PASS' ("$($start.Count) registrations inventoried; not automatically problematic.") 'Win32_StartupCommand; no startup settings changed.'
    } catch {Add-ToolkitFinding $Results 'STARTUP' 'Startup registrations' 'ERROR' $_.Exception.Message 'Win32_StartupCommand'}
    try {
        $t=Get-Command wt.exe -ErrorAction SilentlyContinue
        $package=@(Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue)
        if($t -or $package.Count){Add-ToolkitFinding $Results 'TERMINAL' 'Windows Terminal' 'PASS' ("wt.exe found=$([bool]$t); packages=$($package.Count)") 'Presence only; does not measure launch time or prove healthy configuration.'}
        else{Add-ToolkitFinding $Results 'TERMINAL' 'Windows Terminal' 'NO DATA' 'Windows Terminal package/command not found.' 'Installed-package registration; Windows Terminal may not be installed.'}
    } catch {Add-ToolkitFinding $Results 'TERMINAL' 'Windows Terminal' 'ERROR' $_.Exception.Message 'Windows Terminal registration'}
    try {
        $pt=@(Get-Process -Name 'PowerToys*','Microsoft.CmdPal*','CmdPal*' -ErrorAction SilentlyContinue)
        Add-ToolkitFinding $Results 'POWERTOYS' 'PowerToys / Cmd Palette' 'PASS' ("$($pt.Count) matching process(es) detected.") 'Presence only; no blame or settings changes. Exit temporarily if testing interaction.'
    } catch {Add-ToolkitFinding $Results 'POWERTOYS' 'PowerToys / Cmd Palette' 'ERROR' $_.Exception.Message 'Process name inspection'}
    try {
        $net=@(Get-NetAdapter -ErrorAction Stop|Where-Object Status -eq 'Up')
        if($net.Count){Add-ToolkitFinding $Results 'NETWORK' 'Connected adapters' 'PASS' ("$($net.Count) up: " + (($net|Select-Object -ExpandProperty Name) -join ', ')) 'Link-up does not prove mobile hotspot internet access or throughput.'}
        else{Add-ToolkitFinding $Results 'NETWORK' 'Connected adapters' 'WARNING' 'No adapters report an Up state.' 'Get-NetAdapter status' 'Check phone hotspot connection if internet is needed.'}
    }catch{Add-ToolkitFinding $Results 'NETWORK' 'Connected adapters' 'ERROR' $_.Exception.Message 'Get-NetAdapter'}
    try {
        $dns=Resolve-DnsName -Name 'www.microsoft.com' -Type A -DnsOnly -ErrorAction Stop
        $ips=@($dns|Where-Object IPAddress|Select-Object -ExpandProperty IPAddress)
        if($ips.Count){Add-ToolkitFinding $Results 'DNS' 'DNS resolution' 'PASS' ("Resolved www.microsoft.com: "+($ips -join ', ')) 'External network dependency; not a bandwidth measurement.'}
        else{Add-ToolkitFinding $Results 'DNS' 'DNS resolution' 'NO DATA' 'No IPv4 address returned.' 'Resolve-DnsName DNSOnly'}
    }catch{Add-ToolkitFinding $Results 'DNS' 'DNS resolution' 'WARNING' $_.Exception.Message 'DNS request; offline networks also cause failure.' 'Check connectivity and hotspot before flushing DNS.'}
    try {
        $audio=Get-Service Audiosrv -ErrorAction Stop
        $st=if($audio.Status -eq 'Running'){'PASS'}else{'WARNING'}
        Add-ToolkitFinding $Results 'AUDIO' 'Audio service' $st ("$($audio.Status) (startup type $($audio.StartType))") 'Windows Audio service state.' 'Only restart service if audio is actually malfunctioning.'
    }catch{Add-ToolkitFinding $Results 'AUDIO' 'Audio service' 'NO DATA' $_.Exception.Message 'Service Audiosrv'}
    try {
        $spool=Get-Service Spooler -ErrorAction Stop
        # Disabled/manual printing setups can intentionally keep the service stopped.
        Add-ToolkitFinding $Results 'PRINT' 'Print spooler' 'PASS' ("$($spool.Status); startup $($spool.StartType). Stopped may be intentional.") 'Service state is informational unless a user reports a printing problem.'
    }catch{Add-ToolkitFinding $Results 'PRINT' 'Print spooler' 'NO DATA' $_.Exception.Message 'Service Spooler'}
    try {
        $rp=@(Get-ComputerRestorePoint -ErrorAction Stop)
        if($rp.Count){Add-ToolkitFinding $Results 'RESTORE' 'System restore points' 'PASS' ("$($rp.Count) restore point(s) returned.") 'Restore points are not a substitute for file backups.'}
        else{Add-ToolkitFinding $Results 'RESTORE' 'System restore points' 'NO DATA' 'No restore points returned (protection may be disabled).' 'Get-ComputerRestorePoint'}
    }catch{Add-ToolkitFinding $Results 'RESTORE' 'System restore points' 'NO DATA' $_.Exception.Message 'Get-ComputerRestorePoint; provider may be disabled.'}
    try {
        $tpm=Get-Tpm -ErrorAction Stop
        if($null -eq $tpm){Add-ToolkitFinding $Results 'TPM' 'TPM security chip' 'NO DATA' 'TPM provider returned no data.' 'Get-Tpm'}
        else {
            $st=if($tpm.TpmPresent -and $tpm.TpmReady){'PASS'}else{'WARNING'}
            Add-ToolkitFinding $Results 'TPM' 'TPM security chip' $st ("Present=$($tpm.TpmPresent); Ready=$($tpm.TpmReady)") 'Read-only TPM status; no ownership or key changes.'
        }
    }catch{Add-ToolkitFinding $Results 'TPM' 'TPM security chip' 'NO DATA' $_.Exception.Message 'Get-Tpm may be unavailable.'}
    try {
        $sb=Confirm-SecureBootUEFI -ErrorAction Stop
        Add-ToolkitFinding $Results 'SECURE_BOOT' 'Secure Boot status' 'PASS' ("Enabled=$sb (informational; disabled may be intentional)") 'Read-only BIOS Secure Boot status; the toolkit never enables/disables it.'
    }catch{Add-ToolkitFinding $Results 'SECURE_BOOT' 'Secure Boot status' 'NO DATA' $_.Exception.Message 'Unsupported firmware/privileges may prevent query.'}
    try {
        $bl=Get-BitLockerVolume -MountPoint 'C:' -ErrorAction Stop
        if($null -eq $bl){Add-ToolkitFinding $Results 'BITLOCKER' 'C: encryption status' 'NO DATA' 'No data from BitLocker cmdlet.' 'Get-BitLockerVolume'}
        else{Add-ToolkitFinding $Results 'BITLOCKER' 'C: encryption status' 'PASS' ("Protection=$($bl.ProtectionStatus); Volume=$($bl.VolumeStatus) (informational)") 'Read-only; disabled encryption may be an explicit user choice.'}
    }catch{Add-ToolkitFinding $Results 'BITLOCKER' 'C: encryption status' 'NO DATA' $_.Exception.Message 'BitLocker cmdlet unavailable or unsupported.'}
    try {
        $disk=Get-PhysicalDisk -ErrorAction Stop|Select-Object -First 1
        if($disk){
            $s=if($disk.HealthStatus -eq 'Healthy'){'PASS'}else{'WARNING'}
            Add-ToolkitFinding $Results 'DISK_DETAIL' 'Storage provider detail' $s ("$($disk.FriendlyName), $($disk.MediaType), $($disk.HealthStatus), $($disk.OperationalStatus)") 'Basic health provider, not full vendor SMART diagnostics.'
        }else{Add-ToolkitFinding $Results 'DISK_DETAIL' 'Storage provider detail' 'NO DATA' 'No physical disk data.' 'Get-PhysicalDisk'}
    }catch{Add-ToolkitFinding $Results 'DISK_DETAIL' 'Storage provider detail' 'ERROR' $_.Exception.Message 'Get-PhysicalDisk'}
    try {
        $p=Join-Path $env:WINDIR 'System32\twinui.pcshell.dll'
        if(Test-Path -LiteralPath $p){
            $ver=(Get-Item -LiteralPath $p -ErrorAction Stop).VersionInfo.FileVersion
            Add-ToolkitFinding $Results 'SHELL_DLL' 'Explorer shell DLL' 'PASS' ("Exists: twinui.pcshell.dll ($ver)") 'Existence/version only; not an integrity test. Optional SFC verification is separate.'
        }else{Add-ToolkitFinding $Results 'SHELL_DLL' 'Explorer shell DLL' 'WARNING' 'Windows shell DLL not found at standard location.' 'System32\twinui.pcshell.dll'}
    }catch{Add-ToolkitFinding $Results 'SHELL_DLL' 'Explorer shell DLL' 'ERROR' $_.Exception.Message 'File version query'}
    try {
        $update=Get-Service wuauserv -ErrorAction Stop
        Add-ToolkitFinding $Results 'UPDATE_SERVICE' 'Windows Update service' 'PASS' ("Current status: $($update.Status); startup: $($update.StartType)") 'A stopped/manual Windows Update service is normal on some systems; not proof of failure.'
    }catch{Add-ToolkitFinding $Results 'UPDATE_SERVICE' 'Windows Update service' 'NO DATA' $_.Exception.Message 'Get-Service wuauserv'}
}
function Add-ToolkitOptionalIntegrityChecks {
    param([System.Collections.ArrayList]$Results)
    Write-Host "`nDEEP OPTIONAL INTEGRITY CHECKS" -ForegroundColor Yellow
    Write-Host 'DISM ScanHealth + SFC VerifyOnly can take considerable time and CPU/disk activity.'
    Write-Host 'Both are verification only; they do NOT attempt repairs.'
    $ok=Read-Host 'Type SCAN to include both checks; anything else skips'
    if($ok -cne 'SCAN'){
        Add-ToolkitFinding $Results 'DISM_SCAN' 'DISM integrity scan' 'NO DATA' 'Skipped by user.' 'Optional DISM ScanHealth not run.'
        Add-ToolkitFinding $Results 'SFC_VERIFY' 'Protected file integrity' 'NO DATA' 'Skipped by user.' 'Optional SFC /verifyonly not run.'
        return
    }
    try {
        Write-Host 'Running DISM /ScanHealth (no repair)...' -ForegroundColor Cyan
        $captured=@()
        & dism.exe /Online /Cleanup-Image /ScanHealth 2>&1 | Tee-Object -Variable captured | Out-Host
        $ec=$LASTEXITCODE
        $msg=($captured | Out-String).Trim()
        if($ec -ne 0){Add-ToolkitFinding $Results 'DISM_SCAN' 'DISM integrity scan' 'ERROR' ("DISM exit=$ec; $($msg.Substring(0,[math]::Min(350,$msg.Length)))") 'DISM /Online /Cleanup-Image /ScanHealth'}
        elseif($msg -match '(?i)component store is repairable'){
            Add-ToolkitFinding $Results 'DISM_SCAN' 'DISM integrity scan' 'WARNING' 'DISM reports component-store corruption is repairable.' 'DISM ScanHealth' 'Deep Repair can offer DISM RestoreHealth after explicit confirmation.'
        }elseif($msg -match '(?i)no component store corruption detected'){
            Add-ToolkitFinding $Results 'DISM_SCAN' 'DISM integrity scan' 'PASS' 'No component-store corruption detected.' 'DISM ScanHealth'}
        else{Add-ToolkitFinding $Results 'DISM_SCAN' 'DISM integrity scan' 'NO DATA' ("DISM exited $ec; text could not be classified. Check console/log, possibly localised output.") 'No automated conclusion drawn.'}
    }catch{Add-ToolkitFinding $Results 'DISM_SCAN' 'DISM integrity scan' 'ERROR' $_.Exception.Message 'dism.exe /ScanHealth'}
    try {
        Write-Host 'Running SFC /verifyonly (no repair)...' -ForegroundColor Cyan
        $captured=@()
        & sfc.exe /verifyonly 2>&1 | Tee-Object -Variable captured | Out-Host
        $ec=$LASTEXITCODE
        $msg=($captured | Out-String) -replace "`0",''
        $msg=$msg.Trim()
        $dir=Get-ToolkitReportFolder
        $sfcLog=Join-Path $dir ('SFC-VerifyOnly-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        @("SFC /verifyonly exit code: $ec",'Unprocessed console output follows:','',$msg) | Out-File -LiteralPath $sfcLog -Encoding UTF8 -Width 220 -ErrorAction Stop
        if($ec -ne 0){
            Add-ToolkitFinding $Results 'SFC_VERIFY' 'Protected file integrity' 'ERROR' ("SFC exit=$ec; inspect the saved output.") ('Full SFC output: '+$sfcLog)
        }elseif($msg -match '(?i)did not find any integrity violations|no integrity violations found'){
            Add-ToolkitFinding $Results 'SFC_VERIFY' 'Protected file integrity' 'PASS' 'Windows Resource Protection reported no integrity violations.' ('SFC /verifyonly; raw output saved: '+$sfcLog)
        }elseif($msg -match '(?i)found integrity violations'){
            Add-ToolkitFinding $Results 'SFC_VERIFY' 'Protected file integrity' 'WARNING' 'Windows Resource Protection reported integrity violations.' ('SFC /verifyonly; raw output saved: '+$sfcLog) 'Deep Repair can offer SFC /scannow after approval.'
        }else{
            Add-ToolkitFinding $Results 'SFC_VERIFY' 'Protected file integrity' 'NO DATA' ("SFC exited $ec, but output cannot be safely classified; don't assume success.") ('Raw SFC output saved: '+$sfcLog+'; PowerShell 5.1 native output encoding or language can affect parsing.') 'Review the saved SFC message or Windows CBS log before choosing a repair.'
        }
    }catch{Add-ToolkitFinding $Results 'SFC_VERIFY' 'Protected file integrity' 'ERROR' $_.Exception.Message 'sfc.exe /verifyonly or report saving failed'}

}
function Invoke-ToolkitDiagnostics {
    param([ValidateSet('General','Deep')][string]$Mode='General',[switch]$ReturnResult)
    $results=New-Object System.Collections.ArrayList
    $start=Get-Date
    Get-ToolkitGeneralDiagnostics -Results $results
    if($Mode -eq 'Deep'){
        Add-ToolkitDeepDiagnostics -Results $results
        Add-ToolkitOptionalIntegrityChecks -Results $results
    }
    Write-Host "`n================ $Mode DIAGNOSTICS ================" -ForegroundColor Cyan
    foreach($r in $results){Show-ToolkitFinding $r}
    $saved=Save-ToolkitDiagnostics -Mode ($Mode+'-Diagnostics') -Results $results
    Write-Host ('Duration: {0:N1} seconds' -f ((Get-Date)-$start).TotalSeconds)
    if($ReturnResult){return $saved}
}
function Get-ToolkitFindingStatus {
    param($Report,[string]$Id)
    $f=@($Report.Items|Where-Object Id -eq $Id|Select-Object -First 1)
    if($f.Count){return $f[0].Status}
    return 'NO DATA'
}
function Get-ToolkitRepairOptions {
    param($Report,[string]$Mode)
    $options=New-Object 'System.Collections.Generic.List[object]'
    if((Get-ToolkitFindingStatus $Report 'EXPLORER') -eq 'WARNING'){
        $options.Add([pscustomobject]@{Id='EXPLORER';Title='Restart File Explorer/taskbar';Why='Explorer was not running';Risk='CHANGE'})
    }
    if((Get-ToolkitFindingStatus $Report 'MEMORY') -eq 'WARNING'){
        $options.Add([pscustomobject]@{Id='MEMORY_UI';Title='Open Task Manager for memory review';Why='High RAM pressure (read-only follow-up)';Risk='VIEW'})
    }
    if((Get-ToolkitFindingStatus $Report 'REBOOT') -eq 'WARNING'){
        $options.Add([pscustomobject]@{Id='RESTART_ADVICE';Title='Display restart guidance';Why='Pending Windows restart detected';Risk='VIEW'})
    }
    if((Get-ToolkitFindingStatus $Report 'DNS') -eq 'WARNING' -and $Mode -eq 'Deep'){
        $options.Add([pscustomobject]@{Id='DNS_FLUSH';Title='Flush DNS resolver cache';Why='DNS resolution failed; only useful after connectivity is checked';Risk='CHANGE'})
    }
    if((Get-ToolkitFindingStatus $Report 'AUDIO') -eq 'WARNING' -and $Mode -eq 'Deep'){
        $options.Add([pscustomobject]@{Id='AUDIO';Title='Restart Windows Audio service';Why='Audio service not running';Risk='REPAIR'})
    }
    if((Get-ToolkitFindingStatus $Report 'DISM_SCAN') -eq 'WARNING' -and $Mode -eq 'Deep'){
        $options.Add([pscustomobject]@{Id='DISM';Title='Repair component store (DISM)';Why='DISM /ScanHealth reported repairable corruption';Risk='REPAIR'})
    }
    if((Get-ToolkitFindingStatus $Report 'SFC_VERIFY') -eq 'WARNING' -and $Mode -eq 'Deep'){
        $options.Add([pscustomobject]@{Id='SFC';Title='Repair protected files (SFC)';Why='SFC /verifyonly found integrity violations';Risk='REPAIR'})
    }
    if((Get-ToolkitFindingStatus $Report 'EXPLORER_CRASH') -eq 'WARNING'){
        $options.Add([pscustomobject]@{Id='CRASH_GUIDE';Title='Open Reliability Monitor / investigate crash';Why='Historical Explorer crash logged; does not warrant automatic repair';Risk='VIEW'})
    }
    return @($options.ToArray())
}
function Get-ToolkitReportedSymptomOption {
    Write-Host "`nOPTIONAL: IS SOMETHING ACTUALLY MALFUNCTIONING?" -ForegroundColor Cyan
    Write-Host 'Choose a symptom to add ONE targeted option, even if diagnostics are inconclusive.'
    Write-Host ' 0 = None (only show diagnostics-based recommendations)'
    Write-Host ' 1 = File Explorer/taskbar frozen or sluggish'
    Write-Host ' 2 = Microsoft Store cache/app installation trouble'
    Write-Host ' 3 = DNS lookups fail despite an otherwise working hotspot'
    Write-Host ' 4 = Windows audio not working'
    Write-Host ' 5 = Print queue stuck'
    Write-Host ' 6 = Windows Update malfunction (open repair settings, no automatic reset)'
    Write-Host ' 7 = Windows Terminal app slow/broken (open app repair settings)'
    $v=(Read-Host 'Reported symptom 0-7').Trim()
    switch($v){
        '1' {return [pscustomobject]@{Id='EXPLORER';Title='Restart File Explorer/taskbar';Why='You reported an Explorer/taskbar malfunction';Risk='CHANGE'}}
        '2' {return [pscustomobject]@{Id='STORE_CACHE';Title='Reset Microsoft Store cache';Why='You reported Store installation/cache trouble';Risk='REPAIR'}}
        '3' {return [pscustomobject]@{Id='DNS_FLUSH';Title='Flush DNS resolver cache';Why='You reported a DNS lookup problem';Risk='CHANGE'}}
        '4' {return [pscustomobject]@{Id='AUDIO';Title='Restart Windows Audio service';Why='You reported an audio malfunction';Risk='REPAIR'}}
        '5' {return [pscustomobject]@{Id='PRINT';Title='Restart print spooler';Why='You reported a stuck print queue';Risk='REPAIR'}}
        '6' {return [pscustomobject]@{Id='UPDATES_UI';Title='Open Windows Update troubleshoot/settings';Why='You reported update trouble; no automatic cache/service reset';Risk='VIEW'}}
        '7' {return [pscustomobject]@{Id='APP_REPAIR_UI';Title='Open per-app Windows repair settings';Why='You reported Windows Terminal trouble; use Repair for that app if offered';Risk='VIEW'}}
        default {return $null}
    }
}
function Write-ToolkitRepairHistory {
    param([string]$Mode,[string]$Id,[string]$Title,[string]$Outcome,[string]$Notes)
    try {
        $dir=Get-ToolkitReportFolder
        $file=Join-Path $dir 'Workflow-Repair-History.csv'
        [pscustomobject]@{Time=(Get-Date).ToString('o');Mode=$Mode;Id=$Id;Title=$Title;Outcome=$Outcome;Notes=$Notes} |
            Export-Csv -LiteralPath $file -Encoding UTF8 -NoTypeInformation -Append -ErrorAction Stop
        Write-Host "History: $file" -ForegroundColor DarkGray
    }catch{Write-Host "WARNING: Repair history could not be saved: $($_.Exception.Message)" -ForegroundColor Yellow}
}
function Invoke-ToolkitRepairStep {
    param([string]$Id,[string]$Title,[string]$Mode,[string]$Reason)
    $status='NOT RUN';$note=''
    Write-Host "`nSelected: $Id | Reason: $Reason" -ForegroundColor Cyan
    if($Id -in @('EXPLORER','DNS_FLUSH','AUDIO','PRINT','STORE_CACHE','DISM','SFC')){
        Write-Host 'This may change Windows state. Save relevant work first.' -ForegroundColor Yellow
        $ok=Read-Host "Type YES to execute $Id; anything else cancels"
        if($ok -cne 'YES'){
            Write-Host 'CANCELLED — no repair performed.' -ForegroundColor Yellow
            Write-ToolkitRepairHistory $Mode $Id $Title 'CANCELLED' 'User declined'
            return
        }
    }
    try {
        switch($Id){
            'EXPLORER' {
                Write-Host 'Stopping and restarting explorer.exe; open Explorer windows can close.' -ForegroundColor Yellow
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
                Start-Process -FilePath explorer.exe -ErrorAction Stop
                $status='INVOKED';$note='Explorer started; confirm UI operation manually.'
            }
            'MEMORY_UI' {
                Start-Process taskmgr.exe -ErrorAction Stop
                $status='OPENED';$note='Task Manager requested; user to inspect resource pressure.'
            }
            'RESTART_ADVICE' {
                Write-Host 'Save work, finish outstanding updates, and restart normally when convenient. Toolkit will NOT restart for you.'
                $status='GUIDANCE';$note='No system restart performed.'
            }
            'DNS_FLUSH' {
                & ipconfig.exe /flushdns
                $ec=$LASTEXITCODE
                if($ec -ne 0){throw "ipconfig exit code $ec"}
                $status='COMMAND SUCCEEDED';$note='Flushed resolver cache; connectivity not independently verified.'
            }
            'AUDIO' {
                Restart-Service Audiosrv -Force -ErrorAction Stop
                $svc=Get-Service Audiosrv -ErrorAction Stop
                if($svc.Status -ne 'Running'){throw "Audio service now $($svc.Status)"}
                $status='VERIFIED';$note='Audiosrv is running; audio playback not independently verified.'
            }
            'DISM' {
                Write-Host 'DISM RestoreHealth can download components. A restart may be necessary.' -ForegroundColor Yellow
                & dism.exe /Online /Cleanup-Image /RestoreHealth
                $ec=$LASTEXITCODE
                if($ec -ne 0){throw "DISM exited with $ec"}
                $status='COMMAND SUCCEEDED';$note='DISM returned exit code zero; rerun ScanHealth to verify component integrity.'
            }
            'SFC' {
                & sfc.exe /scannow
                $ec=$LASTEXITCODE
                if($ec -ne 0){throw "SFC returned exit code $ec; inspect CBS log and final SFC output"}
                $status='COMMAND SUCCEEDED';$note='SFC returned zero; inspect final message and rerun verifyonly.'
            }
            'CRASH_GUIDE' {
                Start-Process perfmon.exe -ArgumentList '/rel' -ErrorAction Stop
                Write-Host 'Review Explorer crash details and faulting modules in Reliability Monitor.'
                $status='OPENED';$note='Reliability Monitor requested; no repair attempted.'
            }
            'STORE_CACHE' {
                Start-Process -FilePath wsreset.exe -Wait -ErrorAction Stop
                $status='INVOKED';$note='Microsoft Store cache-reset utility exited; check Store functionality manually.'
            }
            'PRINT' {
                Restart-Service Spooler -Force -ErrorAction Stop
                $svc=Get-Service Spooler -ErrorAction Stop
                if($svc.Status -ne 'Running'){throw "Print spooler now $($svc.Status)"}
                $status='VERIFIED';$note='Print spooler running; print jobs not independently verified.'
            }
            'UPDATES_UI' {
                Start-Process 'ms-settings:windowsupdate' -ErrorAction Stop
                Start-Process 'ms-settings:troubleshoot' -ErrorAction Stop
                $status='OPENED';$note='Settings requested; no update cache or services reset.'
            }
            'APP_REPAIR_UI' {
                Start-Process 'ms-settings:appsfeatures' -ErrorAction Stop
                Write-Host 'Find Windows Terminal > Advanced options > Repair if offered; do not Reset without reviewing data impact.'
                $status='OPENED';$note='Installed apps settings opened; no app altered.'
            }
            default{throw "Unknown allowed repair action: $Id"}
        }
        Write-Host "RESULT: $status — $note" -ForegroundColor Green
    }catch{
        $status='ERROR';$note=$_.Exception.Message
        Write-Host "ERROR: $note" -ForegroundColor Red
    }
    Write-ToolkitRepairHistory $Mode $Id $Title $status $note
}
function Invoke-ToolkitRepairWorkflow {
    param([ValidateSet('General','Deep')][string]$Mode)
    Write-Host "`n===== $Mode REPAIR — GUIDED ONLY =====" -ForegroundColor Cyan
    Write-Host 'First, run fresh read-only diagnostics. Repairs are never applied automatically.'
    if($Mode -eq 'Deep'){
        Write-Host 'Deep diagnosis can optionally run SFC VerifyOnly and DISM ScanHealth.' -ForegroundColor Yellow
    }
    $report=Invoke-ToolkitDiagnostics -Mode $Mode -ReturnResult
    $options=@(Get-ToolkitRepairOptions -Report $report -Mode $Mode)
    $symptom=Get-ToolkitReportedSymptomOption
    if($null -ne $symptom -and @($options|Where-Object Id -eq $symptom.Id).Count -eq 0){
        $options+=@($symptom)
    }
    Write-Host "`nDIAGNOSTICS/SYMPTOM-BASED OPTIONS:" -ForegroundColor Cyan
    if(-not $options.Count){
        Write-Host 'PASS: No repair actions indicated from the checks or your reported symptoms.' -ForegroundColor Green
        Write-Host 'A clean scan does not guarantee the absence of intermittent faults.'
        return
    }
    for($i=0;$i -lt $options.Count;$i++){
        $o=$options[$i]
        Write-Host (" {0}. {1} [{2}] — {3}" -f ($i+1),$o.Title,$o.Risk,$o.Why)
    }
    Write-Host ' 0. EXIT — no changes (recommended if symptom is gone)'
    Write-Host 'Deep Repair is not a blanket reset and does not run everything on this list.'
    while($true){
        $entry=(Read-Host 'Choose ONE option number, or 0 to exit').Trim()
        if($entry -eq '0' -or -not $entry){Write-Host 'Exited guided repair.';return}
        [int]$n=0
        if(-not [int]::TryParse($entry,[ref]$n) -or $n -lt 1 -or $n -gt $options.Count){Write-Host 'Invalid option.' -ForegroundColor Yellow;continue}
        $option=$options[$n-1]
        if($option.Risk -eq 'REPAIR' -and $Mode -eq 'Deep'){
            $confirm=(Read-Host 'Advanced repair. Type DEEP REPAIR to permit confirmation step').Trim()
            if($confirm -cne 'DEEP REPAIR'){Write-Host 'Advanced repair cancelled.';Write-ToolkitRepairHistory ($Mode+' Repair') $option.Id $option.Title 'CANCELLED' 'Did not approve deep repair gate';continue}
        }
        Invoke-ToolkitRepairStep -Id $option.Id -Title $option.Title -Mode ($Mode+' Repair') -Reason $option.Why
        Write-Host 'Re-run diagnostics afterward to check the relevant status; do not assume the issue is resolved.'
        return
    }
}
function Show-ToolkitWorkflowHelp {
    Write-Host @'
FOUR TOOLKIT V5.1 WORKFLOWS

 A — GENERAL DIAGNOSTICS: Fast read-only OS/CPU/RAM/Explorer/disk/security scan.
     Every check reports PASS/WARNING/ERROR/NO DATA. Writes TXT + JSON.
 B — DEEP DIAGNOSTICS: General + application/system events, startup,
     PowerToys/Terminal, network, services, and optional SFC/DISM verification.
 C — GENERAL REPAIR: Reruns fresh diagnostics, asks your symptom, and offers a SHORT, specific,
     individually confirmed action when findings support it.
 D — DEEP REPAIR: Reruns deeper diagnostics and offers advanced repairs ONLY
     when a particular integrity check detects a suitable issue. Requires
     explicit DEEP REPAIR and YES confirmations.

NOTHING modifies Insider enrollment, Secure Boot, TPM, encryption, BIOS,
firmware or Windows Update channels. No mass service resets or registry cleaners.

Reports: Documents\Toolkit-Reports (private; redact before sharing)
'@
}
function Show-ToolkitRepairHistory {
    $rows=@(Read-ToolkitHistory -CurrentFolder (Get-ToolkitReportFolder) -LegacyNames @('ToolkitV5-Reports','Windows11-ToolkitV5-Reports') -FileName 'Workflow-Repair-History.csv' -Limit 30 -LegacyFileNames @('V5-Repair-History.csv'))
    if($rows.Count -eq 0){Write-Host 'NO DATA: No readable workflow repair history was found.';return}
    $rows|Format-Table Time,Mode,Title,Outcome,Notes -AutoSize -Wrap
    Write-Host 'A successful command is not proof that an original symptom is fixed.' -ForegroundColor Yellow
}
function Invoke-ToolkitDiagnosticSelfTest {
    $checks=New-Object System.Collections.ArrayList
    foreach($c in @('Get-CimInstance','Get-WinEvent','Get-PnpDevice','Get-MpComputerStatus','Get-NetFirewallProfile','Get-PhysicalDisk','Resolve-DnsName','Get-AppxPackage','Get-ComputerRestorePoint')){
        $found=Get-Command $c -ErrorAction SilentlyContinue
        if($found){Add-ToolkitFinding $checks $c $c 'PASS' 'Command is available.' 'Availability only; permissions and successful execution not yet confirmed.'}
        else{Add-ToolkitFinding $checks $c $c 'NO DATA' 'Command unavailable in this PowerShell environment.' 'Some components are optional.'}
    }
    try{
        $dir=Get-ToolkitReportFolder
        $test=Join-Path $dir ('Toolkit-write-test-'+[guid]::NewGuid().ToString('N')+'.tmp')
        'write test'|Out-File -LiteralPath $test -Encoding Ascii -ErrorAction Stop
        Remove-Item -LiteralPath $test -ErrorAction Stop
        Add-ToolkitFinding $checks 'WRITING' 'Report folder' 'PASS' "Write/read cleanup check succeeded: $dir" 'Creates then deletes a temporary file.'
    }catch{Add-ToolkitFinding $checks 'WRITING' 'Report folder' 'ERROR' $_.Exception.Message 'Reports cannot be reliably saved.'}
    foreach($x in $checks){Show-ToolkitFinding $x}
    [void](Save-ToolkitDiagnostics -Mode 'Toolkit-Self-Test' -Results $checks)
    Write-Host 'A PASS here means command available, not proof every toolkit action works.'
}
