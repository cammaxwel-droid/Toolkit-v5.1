#requires -Version 5.1
<#
Windows 11 Repair Kit V1
Select actions from a menu. Read-only by default.
Elevation only requested for explicitly privileged actions.
Never disables Defender/firewall, flashes firmware, edits boot keys, or wipes disks.
#>
param(
    [string]$ToolId = '',
    [switch]$ElevatedCall
)

$ErrorActionPreference = 'Continue'
$script:Tools = @()
$script:Categories = @(
    [pscustomobject]@{Id=1;Name='Windows corruption & reliability';Hint='DISM, SFC, restart flags and system errors'},
    [pscustomobject]@{Id=2;Name='Explorer, display, audio & apps';Hint='Taskbar, Task Manager, Store and app diagnostics'},
    [pscustomobject]@{Id=3;Name='Security checks and scans';Hint='Defender, firewall, Secure Boot, TPM, BitLocker'},
    [pscustomobject]@{Id=4;Name='Hotspot & connectivity';Hint='DNS, network, downloads and optional Winsock reset'},
    [pscustomobject]@{Id=5;Name='Drivers, storage & ZIPs';Hint='Driver warnings, disk health and download integrity'},
    [pscustomobject]@{Id=6;Name='Updates, recovery & reports';Hint='WinGet, update logs, battery, RAM and printing'}
)
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($identity)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-OutputDir {
    $folder = [Environment]::GetFolderPath('MyDocuments')
    if (-not $folder -or -not (Test-Path -LiteralPath $folder)) {$folder = $env:USERPROFILE}
    $target = Join-Path $folder 'Windows11-RepairKit-Reports'
    if (-not (Test-Path -LiteralPath $target)) {
        New-Item -ItemType Directory -Force -Path $target | Out-Null
    }
    return $target
}
function Add-RepairTool {
    param([string]$Id,[int]$Category,[string]$Title,[string]$Description,
          [ValidateSet('VIEW','REPORT','CHANGE','REPAIR')][string]$Risk='VIEW',
          [bool]$Admin=$false,[scriptblock]$Action)
    $script:Tools += [pscustomobject]@{
       Id=$Id;Category=$Category;Title=$Title;Description=$Description;
       Risk=$Risk;Admin=$Admin;Action=$Action
    }
}
Add-RepairTool -Id 'R01' -Category 1 -Title 'Component store: quick check' -Description 'DISM CheckHealth. Reads corruption flag; does not repair.' -Risk 'VIEW' -Admin $true -Action {
    & dism.exe /Online /Cleanup-Image /CheckHealth
}
Add-RepairTool -Id 'R02' -Category 1 -Title 'Component store: thorough scan' -Description 'DISM ScanHealth. Longer diagnostic, no repair.' -Risk 'VIEW' -Admin $true -Action {
    & dism.exe /Online /Cleanup-Image /ScanHealth
}
Add-RepairTool -Id 'R03' -Category 1 -Title 'Protected files: verification' -Description 'SFC VerifyOnly. Reports integrity violations without repairs.' -Risk 'VIEW' -Admin $true -Action {
    & sfc.exe /verifyonly
}
Add-RepairTool -Id 'R04' -Category 1 -Title 'Repair component store then files' -Description 'DISM RestoreHealth followed by SFC only if DISM succeeds. May download files.' -Risk 'REPAIR' -Admin $true -Action {
    & dism.exe /Online /Cleanup-Image /RestoreHealth
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'DISM succeeded. Starting SFC.' -ForegroundColor Green
        & sfc.exe /scannow
    } else {
        Write-Host "DISM failed (exit $LASTEXITCODE). Skipping SFC." -ForegroundColor Red
    }
}
Add-RepairTool -Id 'R05' -Category 1 -Title 'Repair protected files (SFC)' -Description 'Runs sfc /scannow independently; can take time.' -Risk 'REPAIR' -Admin $true -Action {
    & sfc.exe /scannow
}
Add-RepairTool -Id 'R06' -Category 1 -Title 'Pending restart indicators' -Description 'Checks update, servicing and file-operation restart markers.' -Risk 'VIEW' -Admin $false -Action {
    [pscustomobject]@{
        WindowsUpdate=(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
        ComponentServicing=(Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
        PendingFileOperations=[bool](Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
    } | Format-List
}
Add-RepairTool -Id 'R07' -Category 1 -Title 'Recent Windows system errors' -Description 'Recent Level 2 System event entries, not a repair.' -Risk 'VIEW' -Admin $false -Action {
    Get-WinEvent -FilterHashtable @{LogName='System';Level=2;StartTime=(Get-Date).AddDays(-2)} -ErrorAction SilentlyContinue |
     Select-Object -First 15 TimeCreated,Id,ProviderName,Message | Format-List
}
Add-RepairTool -Id 'R08' -Category 1 -Title 'Reliability Monitor' -Description 'Opens crash and update reliability history.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process perfmon.exe -ArgumentList '/rel'
}
Add-RepairTool -Id 'R09' -Category 2 -Title 'Restart Explorer and taskbar' -Description 'Closes Explorer windows and reloads taskbar/desktop; no reboot.' -Risk 'CHANGE' -Admin $false -Action {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
}
Add-RepairTool -Id 'R10' -Category 2 -Title 'Explorer and taskbar settings' -Description 'Open taskbar configuration and Explorer options.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process 'ms-settings:taskbar'
    Start-Process control.exe -ArgumentList 'folders'
}
Add-RepairTool -Id 'R11' -Category 2 -Title 'Task Manager and Resource Monitor' -Description 'Open diagnostic GUIs; no task is terminated.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process taskmgr.exe
    Start-Process resmon.exe
}
Add-RepairTool -Id 'R12' -Category 2 -Title 'Recent Explorer/Task Manager crashes' -Description 'Scans Application errors for explorer.exe and Taskmgr.exe.' -Risk 'VIEW' -Admin $false -Action {
    Get-WinEvent -FilterHashtable @{LogName='Application';Level=2;StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
     Where-Object { $_.Message -match '(?i)explorer\.exe|taskmgr\.exe' } |
     Select-Object -First 12 TimeCreated,Id,ProviderName,Message | Format-List
}
Add-RepairTool -Id 'R13' -Category 2 -Title 'Reset Microsoft Store cache' -Description 'Runs Microsoft''s wsreset.exe. Not app uninstall; Store may open.' -Risk 'REPAIR' -Admin $false -Action {
    Start-Process wsreset.exe -Wait
    Write-Host 'Store cache reset command exited. Test the app again.'
}
Add-RepairTool -Id 'R14' -Category 2 -Title 'Installed app repair options' -Description 'Open Settings: Installed apps > ... > Advanced options > Repair.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process 'ms-settings:appsfeatures'
}
Add-RepairTool -Id 'R15' -Category 2 -Title 'Display and graphics diagnostics' -Description 'DirectX Diagnostic Tool and installed graphics driver details.' -Risk 'VIEW' -Admin $false -Action {
    Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution | Format-List
    Start-Process dxdiag.exe
    Write-Host 'Display driver refresh shortcut: Win+Ctrl+Shift+B (manual, brief flicker).'
}
Add-RepairTool -Id 'R16' -Category 2 -Title 'Display settings / scale' -Description 'Open display settings; no resolution changes automated.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process 'ms-settings:display'
}
Add-RepairTool -Id 'R17' -Category 2 -Title 'Audio device and service check' -Description 'Lists audio devices, service states, and opens sound controls.' -Risk 'VIEW' -Admin $false -Action {
    Get-Service Audiosrv,AudioEndpointBuilder -ErrorAction SilentlyContinue | Format-Table -AutoSize
    Get-PnpDevice -Class MEDIA -ErrorAction SilentlyContinue | Select-Object FriendlyName,Status | Format-Table -AutoSize
    Start-Process mmsys.cpl
}
Add-RepairTool -Id 'R18' -Category 2 -Title 'Restart Windows Audio service' -Description 'May interrupt playback or recordings. Does not reinstall audio drivers.' -Risk 'REPAIR' -Admin $true -Action {
    Restart-Service -Name Audiosrv -Force -ErrorAction Stop
    Get-Service Audiosrv | Format-Table Name,Status -AutoSize
}
Add-RepairTool -Id 'R19' -Category 3 -Title 'Defender protection summary' -Description 'Check antivirus, real-time protection and signature age.' -Risk 'VIEW' -Admin $false -Action {
    Get-MpComputerStatus -ErrorAction Stop |
     Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,QuickScanEndTime | Format-List
}
Add-RepairTool -Id 'R20' -Category 3 -Title 'Defender and recent detections' -Description 'Reads recent detections; requires permissions on some systems.' -Risk 'VIEW' -Admin $true -Action {
    Get-MpThreatDetection -ErrorAction Stop |
     Sort-Object InitialDetectionTime -Descending |
     Select-Object -First 12 InitialDetectionTime,ThreatID,ActionSuccess | Format-Table -AutoSize
}
Add-RepairTool -Id 'R21' -Category 3 -Title 'Start Defender quick scan' -Description 'Starts on-demand malware scan. May take minutes.' -Risk 'CHANGE' -Admin $true -Action {
    Start-MpScan -ScanType QuickScan -ErrorAction Stop
    Write-Host 'Quick scan requested/completed; review Windows Security history.'
}
Add-RepairTool -Id 'R22' -Category 3 -Title 'Update Defender security signatures' -Description 'Downloads supported antivirus signatures; internet required.' -Risk 'CHANGE' -Admin $true -Action {
    Update-MpSignature -ErrorAction Stop
    Write-Host 'Defender signature-update command completed.'
}
Add-RepairTool -Id 'R23' -Category 3 -Title 'Firewall profiles' -Description 'Displays firewall status; never turns protection off.' -Risk 'VIEW' -Admin $false -Action {
    Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction | Format-Table -AutoSize
}
Add-RepairTool -Id 'R24' -Category 3 -Title 'Windows Security dashboard' -Description 'Open graphical Windows Security controls without changing them.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process 'ms-settings:windowsdefender'
}
Add-RepairTool -Id 'R25' -Category 3 -Title 'TPM, Secure Boot and encryption' -Description 'Inspect security chip, Secure Boot and BitLocker on C:.' -Risk 'VIEW' -Admin $false -Action {
    try {Get-Tpm | Select-Object TpmPresent,TpmReady,TpmEnabled,TpmActivated | Format-List} catch {Write-Host $_.Exception.Message}
    try { "Secure Boot enabled: $(Confirm-SecureBootUEFI)" } catch {Write-Host "Secure Boot query: $($_.Exception.Message)"}
    & manage-bde.exe -status C:
}
Add-RepairTool -Id 'R26' -Category 3 -Title 'Controlled folder access / PUA' -Description 'Reads selected Defender preferences; never alters security.' -Risk 'VIEW' -Admin $false -Action {
    Get-MpPreference -ErrorAction Stop |
     Select-Object EnableControlledFolderAccess,PUAProtection,DisableRealtimeMonitoring | Format-List
}
Add-RepairTool -Id 'R27' -Category 4 -Title 'Wi-Fi hotspot link' -Description 'Displays negotiated Wi-Fi link rate, NOT mobile tower throughput.' -Risk 'VIEW' -Admin $false -Action {
    & netsh.exe wlan show interfaces
}
Add-RepairTool -Id 'R28' -Category 4 -Title 'DNS, proxy and IP snapshot' -Description 'Read configured DNS, IP adapters and Windows proxy.' -Risk 'VIEW' -Admin $false -Action {
    Get-DnsClientServerAddress -AddressFamily IPv4 | Format-Table InterfaceAlias,ServerAddresses -AutoSize
    & netsh.exe winhttp show proxy
    Get-NetIPInterface -AddressFamily IPv4 | Select-Object InterfaceAlias,ConnectionState,NlMtu | Format-Table -AutoSize
}
Add-RepairTool -Id 'R29' -Category 4 -Title 'Internet latency and DNS' -Description '20 ICMP echo packets plus a DNS query; no downloads.' -Risk 'VIEW' -Admin $false -Action {
    & ping.exe -n 20 1.1.1.1
    & nslookup.exe microsoft.com
}
Add-RepairTool -Id 'R30' -Category 4 -Title 'HTTPS connection check' -Description 'Checks TCP 443 only; successful result does not prove ZIP integrity.' -Risk 'VIEW' -Admin $false -Action {
    Test-NetConnection www.microsoft.com -Port 443 |
     Select-Object ComputerName,RemoteAddress,TcpTestSucceeded | Format-List
}
Add-RepairTool -Id 'R31' -Category 4 -Title 'Flush DNS resolver cache' -Description 'Clears cached DNS answers. Not a download-speed booster.' -Risk 'CHANGE' -Admin $false -Action {
    & ipconfig.exe /flushdns
}
Add-RepairTool -Id 'R32' -Category 4 -Title 'Reset Winsock networking' -Description 'Advanced repair when sockets malfunction; restart later, connections may change.' -Risk 'REPAIR' -Admin $true -Action {
    & netsh.exe winsock reset
    Write-Host 'A restart is normally required. Do not restart until current work is saved.'
}
Add-RepairTool -Id 'R33' -Category 4 -Title 'Open network troubleshooting' -Description 'Open Windows diagnostics UI; does not reset all adapters.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process 'ms-settings:troubleshoot'
}
Add-RepairTool -Id 'R34' -Category 5 -Title 'Driver error codes' -Description 'Show only devices with actual Error status and their problem codes.' -Risk 'VIEW' -Admin $false -Action {
    Get-PnpDevice -ErrorAction Stop | Where-Object Status -eq 'Error' |
     ForEach-Object {
      $pr=Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName DEVPKEY_Device_ProblemCode -ErrorAction SilentlyContinue
      [pscustomobject]@{Device=$_.FriendlyName;Class=$_.Class;Problem=$pr.Data}
     } | Format-Table -AutoSize -Wrap
}
Add-RepairTool -Id 'R35' -Category 5 -Title 'Installed driver inventory CSV' -Description 'Save version inventory, NOT latest-vendor comparison.' -Risk 'REPORT' -Admin $false -Action {
    $path = Join-Path (Get-OutputDir) ("Drivers-{0}.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Get-CimInstance Win32_PnPSignedDriver |
     Select-Object DeviceName,Manufacturer,DriverProviderName,DriverVersion,DriverDate,InfName |
     Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
    Write-Host "Saved: $path"
}
Add-RepairTool -Id 'R36' -Category 5 -Title 'Windows optional driver offers' -Description 'Opens official Windows Update page; no drivers installed.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process 'ms-settings:windowsupdate-optionalupdates'
}
Add-RepairTool -Id 'R37' -Category 5 -Title 'Drive health and firmware' -Description 'Basic Windows storage health and firmware; not a full SMART test.' -Risk 'VIEW' -Admin $false -Action {
    Get-PhysicalDisk | Select-Object FriendlyName,MediaType,FirmwareVersion,HealthStatus | Format-Table -AutoSize
}
Add-RepairTool -Id 'R38' -Category 5 -Title 'Scan C: online for filesystem issues' -Description 'chkdsk /scan reads/scans C: online; does not schedule offline /f.' -Risk 'VIEW' -Admin $true -Action {
    & chkdsk.exe C: /scan
}
Add-RepairTool -Id 'R39' -Category 5 -Title 'Verify ZIP completely' -Description 'Checks ZIP directory and decompresses all entries without extraction.' -Risk 'VIEW' -Admin $false -Action {
    $path=Read-Host 'Full ZIP file path'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'File not found.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $path).Path)
    try {
     $count=0
     foreach($entry in $zip.Entries) {
      if(-not $entry.Name){continue}
      $stream=$entry.Open()
      try{$stream.CopyTo([IO.Stream]::Null);$count++}finally{$stream.Dispose()}
     }
     Write-Host "ZIP entries fully read: $count" -ForegroundColor Green
    } finally {$zip.Dispose()}
}
Add-RepairTool -Id 'R40' -Category 5 -Title 'File SHA-256 checksum' -Description 'Compare with a publisher checksum when provided.' -Risk 'VIEW' -Admin $false -Action {
    $p=Read-Host 'Full downloaded file path'
    Get-FileHash -LiteralPath $p -Algorithm SHA256 | Format-List
}
Add-RepairTool -Id 'R41' -Category 6 -Title 'App upgrades (WinGet)' -Description 'Checks supported installed apps; not Windows OS or firmware.' -Risk 'VIEW' -Admin $false -Action {
    if (Get-Command winget -ErrorAction SilentlyContinue){ & winget.exe upgrade }else{Write-Host 'WinGet unavailable.'}
}
Add-RepairTool -Id 'R42' -Category 6 -Title 'Upgrade supported apps' -Description 'Runs winget upgrade --all. Can download installers and prompt.' -Risk 'CHANGE' -Admin $false -Action {
    if (Get-Command winget -ErrorAction SilentlyContinue){ & winget.exe upgrade --all }else{Write-Host 'WinGet unavailable.'}
}
Add-RepairTool -Id 'R43' -Category 6 -Title 'Windows Update troubleshooting' -Description 'Windows Update settings and troubleshooting UI; no reset.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process 'ms-settings:windowsupdate'
    Start-Process 'ms-settings:troubleshoot'
}
Add-RepairTool -Id 'R44' -Category 6 -Title 'Windows Update log export' -Description 'Creates a readable Windows Update log file for analysis.' -Risk 'REPORT' -Admin $false -Action {
    $p=Join-Path (Get-OutputDir) ("WindowsUpdate-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    Get-WindowsUpdateLog -LogPath $p -ErrorAction Stop | Out-Null
    Write-Host "Log exported: $p"
}
Add-RepairTool -Id 'R45' -Category 6 -Title 'Battery report' -Description 'Creates HTML battery report in your Documents report folder.' -Risk 'REPORT' -Admin $false -Action {
    $p=Join-Path (Get-OutputDir) ("Battery-{0}.html" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    & powercfg.exe /batteryreport /output $p
    Write-Host "Report: $p"
}
Add-RepairTool -Id 'R46' -Category 6 -Title 'RAM usage snapshot' -Description 'Top 15 processes plus system available memory.' -Risk 'VIEW' -Admin $false -Action {
    $os=Get-CimInstance Win32_OperatingSystem
    [pscustomobject]@{UsedPct=[math]::Round(100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize),1);AvailableGB=[math]::Round($os.FreePhysicalMemory/1MB,2)} | Format-List
    Get-Process | Sort-Object WorkingSet64 -Descending |
     Select-Object -First 15 ProcessName,Id,@{N='WorkingSetMB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize
}
Add-RepairTool -Id 'R47' -Category 6 -Title 'Print spooler status' -Description 'Shows printer spooler state, no changes.' -Risk 'VIEW' -Admin $false -Action {
    Get-Service -Name Spooler -ErrorAction Stop | Format-Table Name,Status,StartType -AutoSize
}
Add-RepairTool -Id 'R48' -Category 6 -Title 'Restart print spooler' -Description 'May interrupt outstanding print jobs. Use if printing is stuck.' -Risk 'REPAIR' -Admin $true -Action {
    Restart-Service -Name Spooler -Force -ErrorAction Stop
    Get-Service Spooler | Format-Table Name,Status -AutoSize
}
Add-RepairTool -Id 'R49' -Category 6 -Title 'Create Windows restore point' -Description 'Only if System Protection enabled; may fail due to 24-hour limit.' -Risk 'CHANGE' -Admin $true -Action {
    Checkpoint-Computer -Description ("Windows Repair Kit - "+(Get-Date -Format 'yyyy-MM-dd HH:mm')) -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Host 'Restore point requested.'
}
Add-RepairTool -Id 'R50' -Category 6 -Title 'Startup apps and power requests' -Description 'Open Startup and list current sleep blockers.' -Risk 'VIEW' -Admin $false -Action {
    Start-Process 'ms-settings:startupapps'
    & powercfg.exe /requests
}
Add-RepairTool -Id 'R51' -Category 6 -Title 'System summary report' -Description 'Generate OS, RAM, storage, device and security snapshot in Documents.' -Risk 'REPORT' -Admin $false -Action {
    $out=Join-Path (Get-OutputDir) ("RepairKit-Report-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $os=Get-CimInstance Win32_OperatingSystem
    $parts=@()
    $parts+=("Windows Repair Kit snapshot "+(Get-Date))
    $parts+=("OS: "+$os.Caption+" | Build "+$os.BuildNumber)
    $parts+=("Computer: "+((Get-CimInstance Win32_ComputerSystem).Model))
    $parts+=("BIOS: "+((Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion))
    $parts+=("RAM free GB: "+[math]::Round($os.FreePhysicalMemory/1MB,2))
    $parts+=("Firmware errors:"+((Get-PnpDevice -Class Firmware -ErrorAction SilentlyContinue|Where-Object Status -eq 'Error'| Select-Object -ExpandProperty FriendlyName) -join '; '))
    $parts+=("Disks:`n"+((Get-PhysicalDisk|Select-Object FriendlyName,HealthStatus,FirmwareVersion|Format-Table -AutoSize|Out-String)))
    $parts+=("Firewall:`n"+((Get-NetFirewallProfile|Select-Object Name,Enabled|Format-Table -AutoSize|Out-String)))
    $parts|Out-File -FilePath $out -Encoding UTF8 -Width 180
    Write-Host "Report saved: $out"
}

function Show-RepairHelp {
    param([string]$Id)
    $tool=$script:Tools|Where-Object Id -eq $Id|Select-Object -First 1
    if(-not $tool){Write-Host "Unknown tool: $Id";return}
    Write-Host "`n$($tool.Id) - $($tool.Title)" -ForegroundColor Cyan
    Write-Host $tool.Description
    Write-Host "Class: $($tool.Risk) | Administrator: $($tool.Admin)"
    if($tool.Admin){Write-Host 'UAC requested only if this tool is selected.' -ForegroundColor Gray}
}
function Invoke-RepairAction {
    param($Tool,[switch]$Preapproved)
    Show-RepairHelp $Tool.Id
    if (-not $Preapproved -and $Tool.Risk -in @('CHANGE','REPAIR')) {
        Write-Host 'This action makes a change. Save relevant work first.' -ForegroundColor Yellow
        $answer=Read-Host 'Type YES to continue (anything else cancels)'
        if($answer -cne 'YES'){Write-Host 'Cancelled.';return}
    }
    if($Tool.Admin -and -not (Test-IsAdmin)){
        Write-Host 'Requesting Administrator permission for only this action...' -ForegroundColor Cyan
        try {
            $argsLine='-NoProfile -ExecutionPolicy Bypass -File "{0}" -ToolId "{1}" -ElevatedCall' -f $PSCommandPath,$Tool.Id
            Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $argsLine -Verb RunAs -Wait -ErrorAction Stop
        } catch {
            Write-Host "Administrator request cancelled/failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        return
    }
    Write-Host "`n--- RUNNING ---" -ForegroundColor Cyan
    $printed=0;$failed=$false
    try { & $Tool.Action 2>&1 | ForEach-Object {$printed++;$_} | Out-Host }
    catch {$failed=$true; Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red}
    if (-not $failed) {
        if($printed -eq 0){
            Write-Host 'NO DATA: No pipeline rows were returned. This does NOT prove a successful scan.' -ForegroundColor Yellow
            Write-Host 'Commands may write directly to console or open a separate Windows window.'
        }else{Write-Host 'COMPLETED: Output received; review messages above for actual result.' -ForegroundColor Cyan}
    }
    Write-Host "`n--- COMPLETED ---" -ForegroundColor Cyan
}
if ($ToolId) {
    $t=$script:Tools|Where-Object Id -eq $ToolId|Select-Object -First 1
    if(-not $t){Write-Host 'Unknown tool ID';exit 2}
    if($ElevatedCall -and -not (Test-IsAdmin)){Write-Host 'Administrator permission not granted.';exit 3}
    Invoke-RepairAction -Tool $t -Preapproved:$ElevatedCall
    if($ElevatedCall){[void](Read-Host 'Press Enter to close this Administrator window')}
    exit 0
}
function Show-RepairCategory {
    param([int]$Category)
    while($true){
        Clear-Host
        Write-Host ('='*75) -ForegroundColor DarkCyan
        Write-Host " WINDOWS 11 REPAIR KIT V1 - $($script:Categories[$Category-1].Name)" -ForegroundColor Cyan
        Write-Host " $($script:Categories[$Category-1].Hint)" -ForegroundColor Gray
        Write-Host ('='*75) -ForegroundColor DarkCyan
        foreach($t in $script:Tools|Where-Object Category -eq $Category){
            Write-Host (" {0}  {1,-38} [{2}]" -f $t.Id,$t.Title,$t.Risk)
        }
        Write-Host "`nEnter ID to run | ?ID for help | B back | Q quit"
        $choice=(Read-Host 'Choice').Trim()
        if($choice -match '^(?i:q)$'){return 'QUIT'}
        if($choice -match '^(?i:b)$' -or -not $choice){return}
        if($choice -match '^\?(R\d\d)$'){
            Show-RepairHelp $matches[1].ToUpper()
            [void](Read-Host 'Press Enter');continue
        }
        if($choice -match '^(?i:R\d\d)$'){
            $t=$script:Tools|Where-Object { $_.Id -eq $choice.ToUpper() -and $_.Category -eq $Category }|Select-Object -First 1
            if($t){Invoke-RepairAction -Tool $t}else{Write-Host 'Not in this category.'}
            [void](Read-Host 'Press Enter');continue
        }
    }
}
while($true){
    Clear-Host
    Write-Host '===============================================================' -ForegroundColor DarkCyan
    Write-Host ' WINDOWS 11 REPAIR KIT V1 - LAUNCHES WITHOUT ADMIN' -ForegroundColor Cyan
    Write-Host '===============================================================' -ForegroundColor DarkCyan
    foreach($c in $script:Categories){
      Write-Host (" {0}. {1,-32} {2}" -f $c.Id,$c.Name,$c.Hint)
    }
    Write-Host "`n$($script:Tools.Count) actions | VIEW reads | REPORT saves file | CHANGE/REPAIR confirms"
    Write-Host 'Admin needed? UAC prompts only for the chosen action.'
    Write-Host ' Q = quit'
    $choice=(Read-Host 'Category').Trim()
    if($choice -match '^(?i:q)$' -or $choice -eq '0'){break}
    if($choice -match '^[1-6]$'){
        $result=Show-RepairCategory ([int]$choice)
        if($result -eq 'QUIT'){break}
    }
}
