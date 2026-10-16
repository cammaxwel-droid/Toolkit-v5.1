#requires -Version 5.1
param([string]$ToolId = "", [switch]$ElevatedCall)
# Windows 11 Toolkit V5.1. PowerShell 5.1+; no modules downloaded.
# Actions execute ONLY after menu selection. Firmware flashing is deliberately absent.
$ErrorActionPreference = 'Continue'
$script:Root = Split-Path -Parent $PSScriptRoot
$script:Tools = @()
$script:Categories = @(
    [pscustomobject]@{Id=1;Name='Desktop & Explorer';Hint='Windows interface, file navigation, taskbar'},
    [pscustomobject]@{Id=2;Name='Updates & Software';Hint='Windows Update and application update discovery'},
    [pscustomobject]@{Id=3;Name='Security & Privacy';Hint='Defender, firewall, TPM, BitLocker, Secure Boot'},
    [pscustomobject]@{Id=4;Name='Hardware & Drivers';Hint='Installed device versions; vendor update discovery'},
    [pscustomobject]@{Id=5;Name='Performance & Power';Hint='RAM, CPU, startup and battery insights'},
    [pscustomobject]@{Id=6;Name='Hotspot & Network';Hint='Wi-Fi, DNS, proxy and connectivity checks'},
    [pscustomobject]@{Id=7;Name='Disks & Downloads';Hint='Storage status and download integrity'},
    [pscustomobject]@{Id=8;Name='Troubleshooting & Repair';Hint='Optional scans and deliberate repair actions'},
    [pscustomobject]@{Id=9;Name='System & Developer Tools';Hint='Advanced settings and installed dev tools'},
    [pscustomobject]@{Id=10;Name='Reports & Help';Hint='Generate reports, help, shortcuts and source files'},
    [pscustomobject]@{Id=11;Name='Deep Audits & Comparison';Hint='Security, history, baseline and folder verification'},
    [pscustomobject]@{Id=12;Name='Experience Profiles';Hint='Gaming, Programming, Studying and undo'},
    [pscustomobject]@{Id=13;Name='App Installer & Doctor';Hint='Optional curated WinGet installs and dev environment'},
    [pscustomobject]@{Id=14;Name='Hidden Windows & Advanced';Hint='Useful built-ins, harmless tricks and expert diagnostics'},
    [pscustomobject]@{Id=15;Name='Four Guided Workflows';Hint='General / Deep Diagnostics and General / Deep Repair'}
)

function Get-ReportFolder {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    if (-not $docs -or -not (Test-Path -LiteralPath $docs)) { $docs = $env:USERPROFILE }
    $p = Join-Path $docs 'Windows11-ToolkitV3-Reports'
    if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
    return $p
}
function Test-IsAdministrator {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Add-ToolkitTool {
    param([string]$Id,[int]$Category,[string]$Title,[string]$Description,
          [ValidateSet('VIEW','REPORT','CHANGE','REPAIR')][string]$Risk='VIEW',
          [bool]$Admin=$false,[scriptblock]$Action)
    $script:Tools += [pscustomobject]@{Id=$Id; Category=$Category; Title=$Title;
        Description=$Description; Risk=$Risk; Admin=$Admin; Action=$Action}
}

# The tool catalog is below, each tool has a short description and a safety class.
Add-ToolkitTool -Id '001' -Category 1 -Title 'Restart File Explorer + taskbar' -Description 'Reloads Windows shell; open Explorer windows may close.' -Risk 'CHANGE' -Admin $false -Action { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2; Start-Process explorer.exe }
Add-ToolkitTool -Id '002' -Category 1 -Title 'Open File Explorer' -Description 'Start File Explorer.' -Risk 'VIEW' -Admin $false -Action { Start-Process explorer.exe }
Add-ToolkitTool -Id '003' -Category 1 -Title 'Open Documents' -Description 'Uses actual Documents known folder, not username substitution.' -Risk 'VIEW' -Admin $false -Action { Start-Process ([Environment]::GetFolderPath('MyDocuments')) }
Add-ToolkitTool -Id '004' -Category 1 -Title 'Open Downloads' -Description 'Open Downloads under the actual user profile.' -Risk 'VIEW' -Admin $false -Action { Start-Process (Join-Path $env:USERPROFILE 'Downloads') }
Add-ToolkitTool -Id '005' -Category 1 -Title 'Open Desktop folder' -Description 'Open actual Windows desktop folder.' -Risk 'VIEW' -Admin $false -Action { Start-Process ([Environment]::GetFolderPath('Desktop')) }
Add-ToolkitTool -Id '006' -Category 1 -Title 'File Explorer options' -Description 'Folders, view and search behaviour.' -Risk 'VIEW' -Admin $false -Action { Start-Process control.exe -ArgumentList 'folders' }
Add-ToolkitTool -Id '007' -Category 1 -Title 'Taskbar settings' -Description 'Windows taskbar personalization.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:taskbar' }
Add-ToolkitTool -Id '008' -Category 1 -Title 'Task Manager' -Description 'Open process and startup inspection tools.' -Risk 'VIEW' -Admin $false -Action { Start-Process taskmgr.exe }
Add-ToolkitTool -Id '009' -Category 1 -Title 'Clipboard history settings' -Description 'Inspect clipboard history settings.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:clipboard' }
Add-ToolkitTool -Id '010' -Category 1 -Title 'Desktop background' -Description 'Restore a missing desktop wallpaper.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:personalization-background' }
Add-ToolkitTool -Id '011' -Category 1 -Title 'Screen display settings' -Description 'Resolution, scaling and monitors.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:display' }
Add-ToolkitTool -Id '012' -Category 1 -Title 'Graphics app preferences' -Description 'Select Windows graphics preferences per app.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:display-advancedgraphics' }
Add-ToolkitTool -Id '013' -Category 1 -Title 'Default apps' -Description 'Choose Chrome or other default handlers.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:defaultapps' }
Add-ToolkitTool -Id '014' -Category 2 -Title 'Windows Update settings' -Description 'Check official OS updates offered to this device.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:windowsupdate' }
Add-ToolkitTool -Id '015' -Category 2 -Title 'Windows Update history' -Description 'Review already installed system updates.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:windowsupdate-history' }
Add-ToolkitTool -Id '016' -Category 2 -Title 'Optional driver updates' -Description 'Windows Update offers some, not all, hardware drivers.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:windowsupdate-optionalupdates' }
Add-ToolkitTool -Id '017' -Category 2 -Title 'Recent hotfix history' -Description 'Get-HotFix is partial, not complete update inventory.' -Risk 'VIEW' -Admin $false -Action { Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 15 HotFixID,InstalledOn | Format-Table -AutoSize }
Add-ToolkitTool -Id '018' -Category 2 -Title 'WinGet app update scan' -Description 'Lists available app updates. Does NOT update Windows or firmware.' -Risk 'VIEW' -Admin $false -Action { if(Get-Command winget -ErrorAction SilentlyContinue){ winget upgrade }else{ Write-Host 'WinGet unavailable.' } }
Add-ToolkitTool -Id '019' -Category 2 -Title 'WinGet installed apps' -Description 'Lists supported registered applications.' -Risk 'VIEW' -Admin $false -Action { if(Get-Command winget -ErrorAction SilentlyContinue){ winget list }else{ Write-Host 'WinGet unavailable.' } }
Add-ToolkitTool -Id '020' -Category 2 -Title 'Update supported apps' -Description 'Runs WinGet upgrade --all. May prompt/need internet.' -Risk 'CHANGE' -Admin $false -Action { if(Get-Command winget -ErrorAction SilentlyContinue){ winget upgrade --all }else{ Write-Host 'WinGet unavailable.' } }
Add-ToolkitTool -Id '021' -Category 2 -Title 'Installed apps settings' -Description 'Use Modify, Repair or Uninstall only when needed.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:appsfeatures' }
Add-ToolkitTool -Id '022' -Category 2 -Title 'Startup apps' -Description 'Disable unwanted app startup, not Windows services.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:startupapps' }
Add-ToolkitTool -Id '023' -Category 2 -Title 'WinGet version' -Description 'Check package manager version.' -Risk 'VIEW' -Admin $false -Action { if(Get-Command winget -ErrorAction SilentlyContinue){winget --version}else{Write-Host 'WinGet unavailable.'} }
Add-ToolkitTool -Id '024' -Category 2 -Title 'Microsoft Store library' -Description 'Open Store for apps distributed outside WinGet.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-windows-store:' }
Add-ToolkitTool -Id '025' -Category 3 -Title 'Windows Security dashboard' -Description 'Open Windows Security, no toggles changed.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:windowsdefender' }
Add-ToolkitTool -Id '026' -Category 3 -Title 'Defender protection status' -Description 'Antivirus state, definitions age and scanning status.' -Risk 'VIEW' -Admin $false -Action { try {Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,QuickScanEndTime | Format-List}catch{Write-Host $_.Exception.Message} }
Add-ToolkitTool -Id '027' -Category 3 -Title 'Defender configuration' -Description 'Read controlled folder access, PUA and AV preferences.' -Risk 'VIEW' -Admin $false -Action { try {Get-MpPreference | Select-Object EnableControlledFolderAccess,PUAProtection,DisableRealtimeMonitoring | Format-List}catch{Write-Host $_.Exception.Message} }
Add-ToolkitTool -Id '028' -Category 3 -Title 'Firewall profile status' -Description 'Firewall enabled states on Domain/Private/Public.' -Risk 'VIEW' -Admin $false -Action { Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction | Format-Table -AutoSize }
Add-ToolkitTool -Id '029' -Category 3 -Title 'Advanced firewall console' -Description 'View or manage firewall rules in Windows UI.' -Risk 'VIEW' -Admin $false -Action { Start-Process wf.msc }
Add-ToolkitTool -Id '030' -Category 3 -Title 'TPM security chip' -Description 'Read presence and readiness. Never clears TPM.' -Risk 'VIEW' -Admin $false -Action { try{Get-Tpm | Select-Object TpmPresent,TpmReady,TpmEnabled,TpmActivated | Format-List}catch{Write-Host $_.Exception.Message} }
Add-ToolkitTool -Id '031' -Category 3 -Title 'Secure Boot check' -Description 'Reports enabled/disabled; does not alter BIOS keys.' -Risk 'VIEW' -Admin $false -Action { try{Confirm-SecureBootUEFI}catch{Write-Host $_.Exception.Message} }
Add-ToolkitTool -Id '032' -Category 3 -Title 'BitLocker C: status' -Description 'View system-drive encryption and protector state.' -Risk 'VIEW' -Admin $false -Action { manage-bde -status C: }
Add-ToolkitTool -Id '033' -Category 3 -Title 'Recent Defender detections' -Description 'Threat history can require Admin, no changes.' -Risk 'VIEW' -Admin $false -Action { try {Get-MpThreatDetection -ErrorAction Stop | Select-Object -First 12 InitialDetectionTime,ThreatID,ActionSuccess | Format-Table -AutoSize}catch{Write-Host $_.Exception.Message} }
Add-ToolkitTool -Id '034' -Category 3 -Title 'Controlled Folder Access settings' -Description 'Open Windows Security to inspect ransomware protection.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'windowsdefender://RansomwareProtection' }
Add-ToolkitTool -Id '035' -Category 3 -Title 'Defender quick scan' -Description 'Starts a security scan; may take time.' -Risk 'CHANGE' -Admin $true -Action { try{Start-MpScan -ScanType QuickScan -ErrorAction Stop;Write-Host 'Scan requested/completed; inspect Security history.'}catch{Write-Host $_.Exception.Message} }
Add-ToolkitTool -Id '036' -Category 3 -Title 'Update Defender signatures' -Description 'Downloads current signatures (internet needed).' -Risk 'CHANGE' -Admin $true -Action { try{Update-MpSignature -ErrorAction Stop;Write-Host 'Signature update command completed.'}catch{Write-Host $_.Exception.Message} }
Add-ToolkitTool -Id '037' -Category 3 -Title 'Local security policy' -Description 'Windows 11 Pro security options; view before editing.' -Risk 'VIEW' -Admin $false -Action { Start-Process secpol.msc }
Add-ToolkitTool -Id '038' -Category 3 -Title 'Security summary to file' -Description 'Generate a security report in Documents (sensitive; do not post publicly).' -Risk 'REPORT' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Security-Report.ps1') }
Add-ToolkitTool -Id '039' -Category 4 -Title 'Device Manager' -Description 'Inspect installed drivers and warning codes.' -Risk 'VIEW' -Admin $false -Action { Start-Process devmgmt.msc }
Add-ToolkitTool -Id '040' -Category 4 -Title 'Problem devices only' -Description 'Codes may include intentional camera disable.' -Risk 'VIEW' -Admin $false -Action { Get-PnpDevice | Where-Object Status -eq 'Error' | Select-Object Class,FriendlyName,Status,Problem | Format-Table -Wrap }
Add-ToolkitTool -Id '041' -Category 4 -Title 'All hardware driver inventory' -Description 'Create CSV with installed driver versions. Does not discover newest vendor version.' -Risk 'REPORT' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Driver-Inventory.ps1') }
Add-ToolkitTool -Id '042' -Category 4 -Title 'Current graphics drivers' -Description 'Versions currently installed.' -Risk 'VIEW' -Admin $false -Action { Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion | Format-Table -AutoSize }
Add-ToolkitTool -Id '043' -Category 4 -Title 'Firmware errors' -Description 'Read firmware class warnings only.' -Risk 'VIEW' -Admin $false -Action { $f=@(Get-PnpDevice -Class Firmware -ErrorAction Stop | Where-Object Status -eq 'Error')
    if($f.Count){ Write-Host "WARNING: $($f.Count) firmware-class device(s) report errors." -ForegroundColor Yellow; $f | Select-Object FriendlyName,Status | Format-List }
    else { Write-Host 'PASS: No firmware-class devices report Error status.' -ForegroundColor Green } }
Add-ToolkitTool -Id '044' -Category 4 -Title 'Thunderbolt + Intel ME devices' -Description 'Check interfaces; not actual installed ME firmware version.' -Risk 'VIEW' -Admin $false -Action { Get-PnpDevice | Where-Object FriendlyName -match 'Thunderbolt|Management Engine' | Select-Object FriendlyName,Status | Format-Table -Wrap }
Add-ToolkitTool -Id '045' -Category 4 -Title 'BIOS version' -Description 'Reads current BIOS reported by firmware.' -Risk 'VIEW' -Admin $false -Action { Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion,ReleaseDate | Format-List }
Add-ToolkitTool -Id '046' -Category 4 -Title 'CPU and physical memory' -Description 'Read model, cores and installed physical memory.' -Risk 'VIEW' -Admin $false -Action { Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,TotalPhysicalMemory | Format-List;Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | Format-List }
Add-ToolkitTool -Id '047' -Category 4 -Title 'Disk firmware + basic health' -Description 'Storage health flag is not a comprehensive diagnostic.' -Risk 'VIEW' -Admin $false -Action { Get-PhysicalDisk | Select-Object FriendlyName,MediaType,FirmwareVersion,HealthStatus | Format-Table -AutoSize }
Add-ToolkitTool -Id '048' -Category 4 -Title 'Windows optional driver offers' -Description 'Open optional driver update list; review before selecting.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:windowsupdate-optionalupdates' }
Add-ToolkitTool -Id '049' -Category 4 -Title 'Lenovo System Update in Start menu' -Description 'Locate Lenovo update tool; do not auto-install firmware.' -Risk 'VIEW' -Admin $false -Action { Get-StartApps | Where-Object Name -match 'Lenovo.*(System Update|Vantage)' | Select-Object Name,AppID | Format-Table -AutoSize }
Add-ToolkitTool -Id '050' -Category 4 -Title 'Driver and software update scan' -Description 'Runs local driver inventory + winget listing; vendor firmware NOT flashed.' -Risk 'REPORT' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Update-Scan.ps1') }
Add-ToolkitTool -Id '051' -Category 5 -Title 'Top memory processes' -Description 'Per-process working sets; shared memory may double count.' -Risk 'VIEW' -Admin $false -Action { Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 20 Name,Id,@{N='RAM_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}} | Format-Table -AutoSize }
Add-ToolkitTool -Id '052' -Category 5 -Title 'Available and used RAM' -Description 'Windows memory snapshot.' -Risk 'VIEW' -Admin $false -Action { $os=Get-CimInstance Win32_OperatingSystem;[pscustomobject]@{RAM_GB=[math]::Round($os.TotalVisibleMemorySize/1MB,2);Available_GB=[math]::Round($os.FreePhysicalMemory/1MB,2);Used_Percent=[math]::Round(100*(1-$os.FreePhysicalMemory/$os.TotalVisibleMemorySize),1)} | Format-List }
Add-ToolkitTool -Id '053' -Category 5 -Title 'Resource Monitor' -Description 'Detailed CPU, memory, disk, and network activity.' -Risk 'VIEW' -Admin $false -Action { Start-Process resmon.exe }
Add-ToolkitTool -Id '054' -Category 5 -Title 'Reliability Monitor' -Description 'Review app crashes and unsuccessful installs.' -Risk 'VIEW' -Admin $false -Action { Start-Process perfmon.exe -ArgumentList '/rel' }
Add-ToolkitTool -Id '055' -Category 5 -Title 'Performance Monitor' -Description 'Counters and diagnostics.' -Risk 'VIEW' -Admin $false -Action { Start-Process perfmon.exe }
Add-ToolkitTool -Id '056' -Category 5 -Title 'Startup apps settings' -Description 'Check app sign-in load.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:startupapps' }
Add-ToolkitTool -Id '057' -Category 5 -Title 'Current power scheme' -Description 'Read the active Windows power plan.' -Risk 'VIEW' -Admin $false -Action { powercfg /getactivescheme }
Add-ToolkitTool -Id '058' -Category 5 -Title 'Supported sleep states' -Description 'See available sleep and hibernate modes.' -Risk 'VIEW' -Admin $false -Action { powercfg /a }
Add-ToolkitTool -Id '059' -Category 5 -Title 'Power requests' -Description 'See programs preventing sleep.' -Risk 'VIEW' -Admin $false -Action { powercfg /requests }
Add-ToolkitTool -Id '060' -Category 5 -Title 'Battery report' -Description 'Write standard battery-report.html to Documents report folder.' -Risk 'REPORT' -Admin $false -Action { $out=Join-Path (Get-ReportFolder) 'battery-report.html';powercfg /batteryreport /output $out;Write-Host $out }
Add-ToolkitTool -Id '061' -Category 5 -Title 'System performance options' -Description 'Windows visual effects and virtual memory configuration.' -Risk 'VIEW' -Admin $false -Action { Start-Process SystemPropertiesPerformance.exe }
Add-ToolkitTool -Id '062' -Category 6 -Title 'Wi-Fi link signal and rate' -Description 'Shows connection to phone hotspot, NOT mobile tower quality.' -Risk 'VIEW' -Admin $false -Action { netsh wlan show interfaces }
Add-ToolkitTool -Id '063' -Category 6 -Title 'Wi-Fi adapter capabilities' -Description 'View bands, wireless mode support and driver capabilities.' -Risk 'VIEW' -Admin $false -Action { netsh wlan show drivers }
Add-ToolkitTool -Id '064' -Category 6 -Title 'IP and DNS configuration' -Description 'View network addressing and DNS.' -Risk 'VIEW' -Admin $false -Action { ipconfig /all }
Add-ToolkitTool -Id '065' -Category 6 -Title 'Packet loss: 20 pings' -Description 'Sample connectivity to a public IPv4 address.' -Risk 'VIEW' -Admin $false -Action { ping -n 20 1.1.1.1 }
Add-ToolkitTool -Id '066' -Category 6 -Title 'DNS lookup test' -Description 'Check whether example domain resolves.' -Risk 'VIEW' -Admin $false -Action { nslookup microsoft.com }
Add-ToolkitTool -Id '067' -Category 6 -Title 'WinHTTP proxy' -Description 'Proxy used by some Windows services.' -Risk 'VIEW' -Admin $false -Action { netsh winhttp show proxy }
Add-ToolkitTool -Id '068' -Category 6 -Title 'DNS server listing' -Description 'Per network interface DNS settings.' -Risk 'VIEW' -Admin $false -Action { Get-DnsClientServerAddress -AddressFamily IPv4 | Format-Table -AutoSize }
Add-ToolkitTool -Id '069' -Category 6 -Title 'Network interfaces and MTU' -Description 'MTU readout; no tuning performed.' -Risk 'VIEW' -Admin $false -Action { Get-NetIPInterface | Select-Object InterfaceAlias,AddressFamily,ConnectionState,NlMtu | Format-Table -AutoSize }
Add-ToolkitTool -Id '070' -Category 6 -Title 'HTTPS connectivity test' -Description 'Tests TCP/443 connectivity, not full file downloads.' -Risk 'VIEW' -Admin $false -Action { Test-NetConnection microsoft.com -Port 443 }
Add-ToolkitTool -Id '071' -Category 6 -Title 'Wi-Fi adapter settings' -Description 'Open network adapter control panel.' -Risk 'VIEW' -Admin $false -Action { Start-Process ncpa.cpl }
Add-ToolkitTool -Id '072' -Category 6 -Title 'Advanced network settings' -Description 'Inspect network driver and properties.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:network-advancedsettings' }
Add-ToolkitTool -Id '073' -Category 6 -Title 'Flush DNS cache' -Description 'Clears DNS cache; not a general speed booster.' -Risk 'CHANGE' -Admin $false -Action { ipconfig /flushdns }
Add-ToolkitTool -Id '074' -Category 6 -Title 'Network Troubleshooter' -Description 'Open Windows troubleshoot settings.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:troubleshoot' }
Add-ToolkitTool -Id '075' -Category 7 -Title 'Disk health overview' -Description 'Read reported media health; no repairs performed.' -Risk 'VIEW' -Admin $false -Action { Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,FirmwareVersion | Format-Table -AutoSize }
Add-ToolkitTool -Id '076' -Category 7 -Title 'Drive free space' -Description 'Physical volume total and available size.' -Risk 'VIEW' -Admin $false -Action { Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter,FileSystemLabel,@{N='Free_GB';E={[math]::Round($_.SizeRemaining/1GB,1)}},@{N='Size_GB';E={[math]::Round($_.Size/1GB,1)}} | Format-Table -AutoSize }
Add-ToolkitTool -Id '077' -Category 7 -Title 'Disk Management UI' -Description 'Inspect volumes; do not repartition casually.' -Risk 'VIEW' -Admin $false -Action { Start-Process diskmgmt.msc }
Add-ToolkitTool -Id '078' -Category 7 -Title 'Online disk scan C:' -Description 'chkdsk /scan checks NTFS online; needs elevated access on some systems.' -Risk 'VIEW' -Admin $true -Action { chkdsk C: /scan }
Add-ToolkitTool -Id '079' -Category 7 -Title 'Recent downloads' -Description 'Recent files under your actual profile.' -Risk 'VIEW' -Admin $false -Action { $p=Join-Path $env:USERPROFILE 'Downloads';Get-ChildItem -LiteralPath $p -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 25 Name,Length,LastWriteTime | Format-Table -AutoSize }
Add-ToolkitTool -Id '080' -Category 7 -Title 'Validate ZIP fully' -Description 'Choose ZIP; read/decompress entries without extracting files.' -Risk 'VIEW' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Test-ZipIntegrity.ps1') }
Add-ToolkitTool -Id '081' -Category 7 -Title 'File SHA256 checksum' -Description 'Choose file, calculate hash. Compare with official hash.' -Risk 'VIEW' -Admin $false -Action { $p=Read-Host 'Enter full path to file';if(Test-Path -LiteralPath $p -PathType Leaf){Get-FileHash -LiteralPath $p -Algorithm SHA256 | Format-List}else{Write-Host 'File not found.'} }
Add-ToolkitTool -Id '082' -Category 7 -Title 'Optimize Drives UI' -Description 'Windows decides SSD trim or HDD defrag as appropriate.' -Risk 'VIEW' -Admin $false -Action { Start-Process dfrgui.exe }
Add-ToolkitTool -Id '083' -Category 7 -Title 'Find incomplete downloads' -Description 'Look for Chrome/Edge temporary .crdownload files.' -Risk 'VIEW' -Admin $false -Action { $p=Join-Path $env:USERPROFILE 'Downloads';Get-ChildItem -LiteralPath $p -Filter '*.crdownload' -File -ErrorAction SilentlyContinue | Select-Object Name,Length,LastWriteTime | Format-Table -AutoSize }
Add-ToolkitTool -Id '084' -Category 7 -Title 'Storage settings' -Description 'Manage storage and cleanup through Windows UI.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:storagesense' }
Add-ToolkitTool -Id '085' -Category 8 -Title 'Quick DISM health check' -Description 'Read repairability flag; does not repair.' -Risk 'VIEW' -Admin $true -Action { DISM /Online /Cleanup-Image /CheckHealth }
Add-ToolkitTool -Id '086' -Category 8 -Title 'Deep DISM store scan' -Description 'Scans Windows component store; can take time.' -Risk 'VIEW' -Admin $true -Action { DISM /Online /Cleanup-Image /ScanHealth }
Add-ToolkitTool -Id '087' -Category 8 -Title 'SFC verify only' -Description 'Check system files without repairing.' -Risk 'VIEW' -Admin $true -Action { sfc /verifyonly }
Add-ToolkitTool -Id '088' -Category 8 -Title 'DISM RestoreHealth + SFC repair' -Description 'Repair detected Windows corruption; internet may be used.' -Risk 'REPAIR' -Admin $true -Action { & (Join-Path $script:Root 'scripts\Repair-Windows.ps1') }
Add-ToolkitTool -Id '089' -Category 8 -Title 'Recent system errors' -Description 'Latest OS error events, not automatic diagnosis.' -Risk 'VIEW' -Admin $false -Action { Get-WinEvent -FilterHashtable @{LogName='System';Level=2;StartTime=(Get-Date).AddDays(-3)} -MaxEvents 20 -ErrorAction SilentlyContinue | Select-Object TimeCreated,Id,ProviderName | Format-Table -AutoSize }
Add-ToolkitTool -Id '090' -Category 8 -Title 'Reliability Monitor' -Description 'Crash, driver and install history.' -Risk 'VIEW' -Admin $false -Action { Start-Process perfmon.exe -ArgumentList '/rel' }
Add-ToolkitTool -Id '091' -Category 8 -Title 'Windows Update troubleshooting' -Description 'Opens Windows troubleshooter UI.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:troubleshoot' }
Add-ToolkitTool -Id '092' -Category 8 -Title 'App repair / reset settings' -Description 'Repair or reset one app through Windows UI; inspect options first.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:appsfeatures' }
Add-ToolkitTool -Id '093' -Category 8 -Title 'Explorer/taskbar shell restart' -Description 'Restarts Explorer. Windows desktop briefly disappears.' -Risk 'CHANGE' -Admin $false -Action { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue;Start-Sleep -Seconds 2;Start-Process explorer.exe }
Add-ToolkitTool -Id '094' -Category 8 -Title 'Display diagnostics' -Description 'dxdiag shows graphics hardware and driver; no repair.' -Risk 'VIEW' -Admin $false -Action { Start-Process dxdiag.exe }
Add-ToolkitTool -Id '095' -Category 8 -Title 'Graphics display settings' -Description 'Windows display options and scaling.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:display' }
Add-ToolkitTool -Id '096' -Category 8 -Title 'Task Manager' -Description 'Start or reopen Task Manager for stalled-app inspection.' -Risk 'VIEW' -Admin $false -Action { Start-Process taskmgr.exe }
Add-ToolkitTool -Id '097' -Category 8 -Title 'Windows recovery options' -Description 'Opens recovery tools UI; no automatic reset.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:recovery' }
Add-ToolkitTool -Id '098' -Category 8 -Title 'Event Viewer' -Description 'Inspect application and system failures.' -Risk 'VIEW' -Admin $false -Action { Start-Process eventvwr.msc }
Add-ToolkitTool -Id '099' -Category 9 -Title 'System Properties' -Description 'Computer name, domain, environment and restore.' -Risk 'VIEW' -Admin $false -Action { Start-Process sysdm.cpl }
Add-ToolkitTool -Id '100' -Category 9 -Title 'Advanced system settings' -Description 'Performance, profiles and environment variables.' -Risk 'VIEW' -Admin $false -Action { Start-Process SystemPropertiesAdvanced.exe }
Add-ToolkitTool -Id '101' -Category 9 -Title 'System restore settings' -Description 'Check available restore points and protection.' -Risk 'VIEW' -Admin $false -Action { Start-Process SystemPropertiesProtection.exe }
Add-ToolkitTool -Id '102' -Category 9 -Title 'Windows features' -Description 'Optional OS components such as WSL or Hyper-V.' -Risk 'VIEW' -Admin $false -Action { Start-Process optionalfeatures.exe }
Add-ToolkitTool -Id '103' -Category 9 -Title 'Computer Management' -Description 'Local disk, services, events and users.' -Risk 'VIEW' -Admin $false -Action { Start-Process compmgmt.msc }
Add-ToolkitTool -Id '104' -Category 9 -Title 'Device Manager' -Description 'Inspect hardware and driver properties.' -Risk 'VIEW' -Admin $false -Action { Start-Process devmgmt.msc }
Add-ToolkitTool -Id '105' -Category 9 -Title 'Task Scheduler' -Description 'Inspect installed jobs; no modification.' -Risk 'VIEW' -Admin $false -Action { Start-Process taskschd.msc }
Add-ToolkitTool -Id '106' -Category 9 -Title 'Services console' -Description 'Manage background services carefully.' -Risk 'VIEW' -Admin $false -Action { Start-Process services.msc }
Add-ToolkitTool -Id '107' -Category 9 -Title 'Local Group Policy Editor' -Description 'Windows 11 Pro administrative policy.' -Risk 'VIEW' -Admin $false -Action { Start-Process gpedit.msc }
Add-ToolkitTool -Id '108' -Category 9 -Title 'DirectX diagnostic' -Description 'Display and sound driver diagnostics.' -Risk 'VIEW' -Admin $false -Action { Start-Process dxdiag.exe }
Add-ToolkitTool -Id '109' -Category 9 -Title 'Developer settings' -Description 'Windows developer mode and device features.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:developers' }
Add-ToolkitTool -Id '110' -Category 9 -Title 'Toolchain versions' -Description 'Reports Python, Node, npm, .NET, Git and Visual Studio paths.' -Risk 'VIEW' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Dev-Inventory.ps1') }
Add-ToolkitTool -Id '111' -Category 9 -Title 'Windows version' -Description 'Display Windows build.' -Risk 'VIEW' -Admin $false -Action { Start-Process winver.exe }
Add-ToolkitTool -Id '112' -Category 9 -Title 'Actual profile path' -Description 'Show profile/document folders and name; no renames.' -Risk 'VIEW' -Admin $false -Action { [pscustomobject]@{Username=$env:USERNAME;UserProfile=$env:USERPROFILE;Documents=[Environment]::GetFolderPath('MyDocuments')} | Format-List }
Add-ToolkitTool -Id '113' -Category 10 -Title 'Comprehensive system report' -Description 'Writes a readable report to Documents/Windows11-ToolkitV3-Reports.' -Risk 'REPORT' -Admin $false -Action { & (Join-Path $script:Root 'scripts\System-Report.ps1') }
Add-ToolkitTool -Id '114' -Category 10 -Title 'Windows Security report' -Description 'Defender, firewall, encryption and TPM only.' -Risk 'REPORT' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Security-Report.ps1') }
Add-ToolkitTool -Id '115' -Category 10 -Title 'Driver inventory CSV' -Description 'Installed driver versions, not online latest-version lookup.' -Risk 'REPORT' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Driver-Inventory.ps1') }
Add-ToolkitTool -Id '116' -Category 10 -Title 'Software + driver update scan' -Description 'WinGet available updates + local devices; no installation.' -Risk 'REPORT' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Update-Scan.ps1') }
Add-ToolkitTool -Id '117' -Category 10 -Title 'Open toolkit README' -Description 'Open GitHub-ready README instructions.' -Risk 'VIEW' -Admin $false -Action { Start-Process (Join-Path $script:Root 'README.md') }
Add-ToolkitTool -Id '118' -Category 10 -Title 'Open command reference' -Description 'Open expanded command reference .txt.' -Risk 'VIEW' -Admin $false -Action { Start-Process (Join-Path $script:Root 'docs\Command-Reference-V5.txt') }
Add-ToolkitTool -Id '119' -Category 10 -Title 'Open keyboard shortcuts' -Description 'Open keyboard and Win+R shortcuts .txt.' -Risk 'VIEW' -Admin $false -Action { Start-Process (Join-Path $script:Root 'docs\Windows-Shortcuts.txt') }
Add-ToolkitTool -Id '120' -Category 10 -Title 'Open reports folder' -Description 'Opens previous reports; creates folder if missing.' -Risk 'REPORT' -Admin $false -Action { Start-Process (Get-ReportFolder) }


# V3.1 additions - focused troubleshooting and standalone repair toolkit.
Add-ToolkitTool -Id '121' -Category 8 -Title 'Open Repair Kit (51 tools)' -Description 'Separate menu for security, Explorer, audio, Windows, updates and diagnostics. Elevates per repair.' -Risk 'VIEW' -Admin $false -Action { & (Join-Path $script:Root 'repair-kit\src\RepairKit.ps1') }
Add-ToolkitTool -Id '122' -Category 8 -Title 'Windows Update troubleshooter' -Description 'Open built-in Windows troubleshooting and update settings.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:troubleshoot'; Start-Process 'ms-settings:windowsupdate' }
Add-ToolkitTool -Id '123' -Category 8 -Title 'Recent Explorer crashes' -Description 'Explorer Application Error 1000 events from available last 7 days; historical logs may be cleared.' -Risk 'VIEW' -Admin $false -Action { $c=Get-V5RecentExplorerCrashes -Days 7
    if(-not $c.Success){Write-Host "ERROR: $($c.Message)" -ForegroundColor Red}
    elseif(@($c.Data).Count -eq 0){Write-Host 'PASS: No Explorer crash detected in the accessible seven-day event log (not proof no crash ever occurred).'  -ForegroundColor Green}
    else{Write-Host "WARNING: $(@($c.Data).Count) Explorer crash event(s)." -ForegroundColor Yellow; $c.Data | Select-Object TimeCreated,Id,ProviderName,Message | Format-List} }
Add-ToolkitTool -Id '124' -Category 8 -Title 'Printer spooler status' -Description 'Reports spooler service state; use Repair Kit to restart it.' -Risk 'VIEW' -Admin $false -Action { Get-Service Spooler | Select-Object Name,Status,StartType | Format-Table -AutoSize }
Add-ToolkitTool -Id '125' -Category 2 -Title 'App repair / reset options' -Description 'Open installed apps. Choose a specific app then Advanced options > Repair if available.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:appsfeatures' }

# New V4 functions. Side-effect operations are only invoked after explicit menu selection.
. (Join-Path $script:Root 'modules\V4-Extras.ps1')
. (Join-Path $script:Root 'modules\V5-Workflows.ps1')


# V4 features preserved; V5 introduces four guided diagnostic and repair workflows.
Add-ToolkitTool -Id '126' -Category 11 -Title 'Security posture overview' -Description 'Local Defender, firewall, TPM, BitLocker, Secure Boot; creates a private report.' -Risk 'REPORT' -Admin $false -Action { New-SecurityAudit }
Add-ToolkitTool -Id '127' -Category 11 -Title 'Repair & change history' -Description 'Shows actions selected using this toolkit. An invocation is not proof of repair success.' -Risk 'VIEW' -Admin $false -Action { Show-RepairHistory }
Add-ToolkitTool -Id '128' -Category 11 -Title 'Save baseline snapshot' -Description 'Stores selected OS/driver/RAM/firmware facts for later comparison.' -Risk 'REPORT' -Admin $false -Action { Save-SystemBaseline }
Add-ToolkitTool -Id '129' -Category 11 -Title 'Compare two snapshots' -Description 'Highlights changed drivers, memory and firmware; select two saved snapshots.' -Risk 'REPORT' -Admin $false -Action { Compare-SystemBaseline }
Add-ToolkitTool -Id '130' -Category 11 -Title 'Folder backup comparison' -Description 'Compare two local folders by path/size, optionally SHA-256 hashes; no changes.' -Risk 'REPORT' -Admin $false -Action { Compare-BackupFolders }
Add-ToolkitTool -Id '131' -Category 11 -Title 'Package + driver update scan' -Description 'Use V3 combined report: installed drivers + WinGet app updates only.' -Risk 'REPORT' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Update-Scan.ps1') }
Add-ToolkitTool -Id '132' -Category 11 -Title 'Startup & heavy RAM report' -Description 'App memory working sets and startup registrations; no termination.' -Risk 'REPORT' -Admin $false -Action { New-StartupRamReport }
Add-ToolkitTool -Id '133' -Category 11 -Title 'Security check in console' -Description 'Quick Defender/firewall/encryption status; does not make changes.' -Risk 'VIEW' -Admin $false -Action { Show-SecurityQuick }
Add-ToolkitTool -Id '134' -Category 11 -Title 'System reliability events' -Description 'Critical/error System & Application events from the last 48 hours.' -Risk 'VIEW' -Admin $false -Action { Show-RecentReliability }
Add-ToolkitTool -Id '135' -Category 11 -Title 'Check restore point status' -Description 'Inspect shadow-copy/restore support; no restore point created.' -Risk 'VIEW' -Admin $false -Action { Show-RestorePointStatus }
Add-ToolkitTool -Id '136' -Category 12 -Title 'Preview Gaming profile' -Description 'See proposed power profile and settings pages, no changes.' -Risk 'VIEW' -Admin $false -Action { Show-ProfilePreview -Name 'Gaming' }
Add-ToolkitTool -Id '137' -Category 12 -Title 'Apply Gaming profile' -Description 'Use existing High Performance plan if installed and open Game Mode/settings. Undo supported.' -Risk 'CHANGE' -Admin $true -Action { Set-ExperienceProfile -Name 'Gaming' }
Add-ToolkitTool -Id '138' -Category 12 -Title 'Preview Programming profile' -Description 'See proposed power mode and developer settings, no changes.' -Risk 'VIEW' -Admin $false -Action { Show-ProfilePreview -Name 'Programming' }
Add-ToolkitTool -Id '139' -Category 12 -Title 'Apply Programming profile' -Description 'Select Balanced plan if available; open Developer & Startup Settings. Undo supported.' -Risk 'CHANGE' -Admin $true -Action { Set-ExperienceProfile -Name 'Programming' }
Add-ToolkitTool -Id '140' -Category 12 -Title 'Preview Studying profile' -Description 'See study-friendly settings and changes before applying.' -Risk 'VIEW' -Admin $false -Action { Show-ProfilePreview -Name 'Studying' }
Add-ToolkitTool -Id '141' -Category 12 -Title 'Apply Studying profile' -Description 'Select Balanced plan; open Notifications/Display. Never disables notifications automatically.' -Risk 'CHANGE' -Admin $true -Action { Set-ExperienceProfile -Name 'Studying' }
Add-ToolkitTool -Id '142' -Category 12 -Title 'Preview Battery Saver profile' -Description 'Use installed power saver plan if available; show battery settings.' -Risk 'VIEW' -Admin $false -Action { Show-ProfilePreview -Name 'Battery Saver' }
Add-ToolkitTool -Id '143' -Category 12 -Title 'Apply Battery Saver profile' -Description 'Choose existing Power Saver plan if present; Undo supported.' -Risk 'CHANGE' -Admin $true -Action { Set-ExperienceProfile -Name 'Battery Saver' }
Add-ToolkitTool -Id '144' -Category 12 -Title 'Restore pre-profile power plan' -Description 'Restore original saved power plan before this toolkit changed it.' -Risk 'CHANGE' -Admin $true -Action { Restore-ExperienceProfile }
Add-ToolkitTool -Id '145' -Category 12 -Title 'Show current plan/profile' -Description 'Read current Windows power plan and any toolkit backup.' -Risk 'VIEW' -Admin $false -Action { Show-ProfileState }
Add-ToolkitTool -Id '146' -Category 13 -Title 'Curated app installer menu' -Description 'Optional single-app WinGet install. Shows package details before YES. Never installs all.' -Risk 'CHANGE' -Admin $true -Action { Show-CuratedInstaller }
Add-ToolkitTool -Id '147' -Category 13 -Title 'Developer environment doctor' -Description 'Report Python, pip, Node, .NET, Git, Visual Studio, CMake and Ninja.' -Risk 'REPORT' -Admin $false -Action { New-DeveloperDoctor }
Add-ToolkitTool -Id '148' -Category 13 -Title 'Windows installed apps/repair UI' -Description 'Opens app controls; you choose Repair/Modify for an individual app.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:appsfeatures' }
Add-ToolkitTool -Id '149' -Category 13 -Title 'App upgrades scan (WinGet)' -Description 'Find supported app updates. Does not install apps or drivers.' -Risk 'VIEW' -Admin $false -Action { Show-WinGetUpdates }
Add-ToolkitTool -Id '150' -Category 13 -Title 'Official Windows driver offers' -Description 'Opens Optional updates; checks offered compatible drivers only.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-settings:windowsupdate-optionalupdates' }
Add-ToolkitTool -Id '151' -Category 13 -Title 'Find tool executable paths' -Description 'Inspect locations for powershell, python, git, node and winget.' -Risk 'VIEW' -Admin $false -Action { Show-CommandPaths }
Add-ToolkitTool -Id '152' -Category 13 -Title 'Check signed download file' -Description 'Read Authenticode status and SHA256 hash for a selected file.' -Risk 'VIEW' -Admin $false -Action { Test-DownloadSignature }
Add-ToolkitTool -Id '153' -Category 14 -Title 'Symptom-guided troubleshooting' -Description 'Choose a problem for focused read-only checks and optional repair recommendations.' -Risk 'VIEW' -Admin $false -Action { Show-TroubleshootingWizard }
Add-ToolkitTool -Id '154' -Category 14 -Title 'Open All Tasks (God Mode)' -Description 'Open Windows All Tasks shell folder, no system changes.' -Risk 'VIEW' -Admin $false -Action { Show-AllTasks }
Add-ToolkitTool -Id '155' -Category 14 -Title 'Open hidden shell folders' -Description 'Choose AppsFolder, SendTo, Startup, Recycle Bin or Downloads.' -Risk 'VIEW' -Admin $false -Action { Show-HiddenFolders }
Add-ToolkitTool -Id '156' -Category 14 -Title 'Hidden Run shortcuts' -Description 'Show useful Win+R tools such as perfmon /rel, dxdiag and joy.cpl.' -Risk 'VIEW' -Admin $false -Action { Show-RunTricks }
Add-ToolkitTool -Id '157' -Category 14 -Title 'Windows keyboard tricks' -Description 'Emoji, clipboard, snip, GPU refresh and virtual-desktop shortcuts.' -Risk 'VIEW' -Admin $false -Action { Show-KeyboardTricks }
Add-ToolkitTool -Id '158' -Category 14 -Title 'Fun Matrix-style terminal rain' -Description 'Harmless terminal animation lasting a few seconds; no filesystem/network action.' -Risk 'VIEW' -Admin $false -Action { Show-MatrixRain }
Add-ToolkitTool -Id '159' -Category 14 -Title 'Random Windows tip' -Description 'Fun short tip from built-in Windows functions.' -Risk 'VIEW' -Admin $false -Action { Show-FunTip }
Add-ToolkitTool -Id '160' -Category 14 -Title 'Advanced boot entry view' -Description 'Read BCD firmware entries only; do not delete old boot entries.' -Risk 'VIEW' -Admin $true -Action { Show-BootEntries }
Add-ToolkitTool -Id '161' -Category 14 -Title 'Advanced services insight' -Description 'Read service details, no stopping/reconfiguration.' -Risk 'VIEW' -Admin $false -Action { Show-ServiceInsight }
Add-ToolkitTool -Id '162' -Category 14 -Title 'Advanced task triggers' -Description 'Read scheduled tasks matching optional search term; no modifications.' -Risk 'VIEW' -Admin $false -Action { Show-TaskInsight }
Add-ToolkitTool -Id '163' -Category 14 -Title 'Advanced network routes' -Description 'Read routing and network interface diagnostics.' -Risk 'VIEW' -Admin $false -Action { Show-NetworkRoutes }
Add-ToolkitTool -Id '164' -Category 14 -Title 'Windows performance tools' -Description 'Open Resource, Performance and Reliability Monitor.' -Risk 'VIEW' -Admin $false -Action { Show-PerformanceTools }
Add-ToolkitTool -Id '165' -Category 14 -Title 'Taskbar/Explorer recovery' -Description 'Restart Explorer and taskbar on confirmation.' -Risk 'CHANGE' -Admin $false -Action { Restart-ExplorerV4 }
Add-ToolkitTool -Id '166' -Category 14 -Title 'View integrated repair kit' -Description 'Open the integrated 51-action diagnostic/repair menu.' -Risk 'VIEW' -Admin $false -Action { & (Join-Path $script:Root 'repair-kit\src\RepairKit.ps1') }
Add-ToolkitTool -Id '167' -Category 11 -Title 'RAM usage delta (10 seconds)' -Description 'Samples top process working sets twice and shows changes; does not close processes.' -Risk 'VIEW' -Admin $false -Action { Show-MemoryDelta }
Add-ToolkitTool -Id '168' -Category 11 -Title 'Save driver inventory CSV' -Description 'Read drivers to file without updating or replacing hardware drivers.' -Risk 'REPORT' -Admin $false -Action { & (Join-Path $script:Root 'scripts\Driver-Inventory.ps1') }
Add-ToolkitTool -Id '169' -Category 13 -Title 'Open Windows Store' -Description 'Browse Store apps independently from WinGet; no auto install.' -Risk 'VIEW' -Admin $false -Action { Start-Process 'ms-windows-store:' }
Add-ToolkitTool -Id '170' -Category 14 -Title 'Unsigned driver inventory' -Description 'Reports installed drivers Windows marks unsigned; unsigned does not automatically mean malware.' -Risk 'VIEW' -Admin $false -Action { Show-UnsignedDrivers }


# V5: Four consolidated workflows plus reliability and log views.
Add-ToolkitTool -Id '171' -Category 15 -Title 'GENERAL DIAGNOSTICS' -Description 'Fast multi-system read-only checks; explicit statuses, TXT + JSON report.' -Risk 'REPORT' -Admin $true -Action { Invoke-V5Diagnostics -Mode General }
Add-ToolkitTool -Id '172' -Category 15 -Title 'DEEP DIAGNOSTICS' -Description 'Broader read-only audit of Windows, Explorer, logs, processes and optional DISM/SFC verification.' -Risk 'REPORT' -Admin $true -Action { Invoke-V5Diagnostics -Mode Deep }
Add-ToolkitTool -Id '173' -Category 15 -Title 'GENERAL REPAIR (guided)' -Description 'Runs diagnostics, then offers individual low-impact fixes only when indicated.' -Risk 'REPAIR' -Admin $true -Action { Invoke-V5RepairWorkflow -Mode General }
Add-ToolkitTool -Id '174' -Category 15 -Title 'DEEP REPAIR (guided)' -Description 'Runs deeper diagnostics, offers repair of verified issues with two explicit confirmations.' -Risk 'REPAIR' -Admin $true -Action { Invoke-V5RepairWorkflow -Mode Deep }
Add-ToolkitTool -Id '175' -Category 15 -Title 'Toolkit diagnostic self-test' -Description 'Checks availability of diagnostic commands and report-folder writing; exports report.' -Risk 'REPORT' -Admin $true -Action { Invoke-V5DiagnosticSelfTest }
Add-ToolkitTool -Id '176' -Category 15 -Title 'How the 4 workflows work' -Description 'Read safety rules and expected output. No changes.' -Risk 'VIEW' -Admin $false -Action { Show-V5WorkflowHelp }
Add-ToolkitTool -Id '177' -Category 15 -Title 'V5 repair attempt history' -Description 'Show attempted operations and their actual outcomes (not assumed fixes).' -Risk 'VIEW' -Admin $false -Action { Show-V5RepairHistory }
Add-ToolkitTool -Id '178' -Category 15 -Title 'Open V5 reports folder' -Description 'Private local Documents folder containing readable TXT and structured JSON reports.' -Risk 'VIEW' -Admin $false -Action { Start-Process (Get-V5ReportFolder) }
Add-ToolkitTool -Id '179' -Category 15 -Title 'Open workflow user guide' -Description 'What each diagnostic checks and which repairs are available.' -Risk 'VIEW' -Admin $false -Action { Start-Process (Join-Path $script:Root 'docs\V5-Workflows.md') }
Add-ToolkitTool -Id '180' -Category 15 -Title 'PowerShell syntax-check guide' -Description 'Instructions and included parser self-test. No scans or repairs.' -Risk 'VIEW' -Admin $false -Action { Start-Process (Join-Path $script:Root 'TESTING.md') }

function Show-ToolHelp {
    param([string]$Id)
    $tool = $script:Tools | Where-Object Id -eq $Id | Select-Object -First 1
    if (-not $tool) { Write-Host "Unknown ID $Id" -ForegroundColor Yellow;return }
    Write-Host "`n[$($tool.Id)] $($tool.Title)" -ForegroundColor Cyan
    Write-Host $tool.Description
    Write-Host "Category: $($script:Categories[$tool.Category - 1].Name)"
    Write-Host "Safety: $($tool.Risk) | Requires Admin: $($tool.Admin)"
}

function Invoke-ToolkitTool {
    param($Tool,[switch]$Preapproved)
    Clear-Host
    Show-ToolHelp $Tool.Id
    if (-not $Preapproved -and $Tool.Risk -in @('REPAIR','CHANGE') -and $Tool.Id -notin @('173','174')) {
        Write-Host "`nThis action changes Windows or application state." -ForegroundColor Yellow
        $ok = Read-Host 'Type YES to run, anything else to cancel'
        if ($ok -cne 'YES') { Write-Host 'Cancelled.'; return }
    }
    if ($Tool.Admin -and -not (Test-IsAdministrator)) {
        Write-Host "`nRequesting Administrator access for this tool only." -ForegroundColor Cyan
        try {
            $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -ToolId "{1}" -ElevatedCall' -f $PSCommandPath,$Tool.Id
            Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -Verb RunAs -Wait -ErrorAction Stop
        } catch {
            Write-Host "UAC cancelled or failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        return
    }
    Write-Host "`n--- OUTPUT ---" -ForegroundColor Cyan
    $outcome = 'Invoked; outcome not independently verified'
    $errorEncountered = $false
    $emitted = 0
    try {
        & $Tool.Action 2>&1 | ForEach-Object {
            $emitted++
            $_
        } | Out-Host
    } catch {
        $errorEncountered = $true
        $outcome = 'Terminating error: ' + $_.Exception.Message
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
    if (-not $errorEncountered) {
        if (([int]$Tool.Id -ge 171 -and [int]$Tool.Id -le 180) -or $Tool.Id -in @('043','123')) {
            Write-Host 'COMPLETED: See the explicit findings or guidance above.' -ForegroundColor Cyan
        } elseif ($emitted -eq 0) {
            if($Tool.Title -match '(?i)^(open|launch|show|view) (settings|windows|file|device|control|resource|system|task|power|security|terminal|disk|driver|advanced|event|report|hidden|startup|network|reliability|all tasks|installed|store)') {
                Write-Host 'EXTERNAL UI INVOKED: Check whether the selected window or page opened.' -ForegroundColor Cyan
            } else {
                Write-Host 'NO STRUCTURED DATA: No pipeline rows were emitted.' -ForegroundColor Yellow
                Write-Host 'A command may print directly to screen or legitimately return zero matches.'
                Write-Host 'This does NOT prove a PASS. Use workflow A or B for individually classified checks.'
            }
        } else {
            Write-Host 'COMPLETED: Output was returned above; command success is not independently verified.' -ForegroundColor Cyan
        }
    }
    if ($Tool.Risk -in @('REPAIR','CHANGE')) {
        Write-ToolkitActivity -Id $Tool.Id -Name $Tool.Title -Risk $Tool.Risk -Outcome $outcome
    }
    Write-Host "`n--- END ---" -ForegroundColor Cyan
}
if ($ToolId) {
    $selected = $script:Tools | Where-Object Id -eq $ToolId | Select-Object -First 1
    if (-not $selected) { Write-Host 'Invalid tool ID.' -ForegroundColor Red; exit 2 }
    if ($ElevatedCall -and -not (Test-IsAdministrator)) { Write-Host 'Administrator approval not granted.'; exit 3 }
    Invoke-ToolkitTool -Tool $selected -Preapproved:$ElevatedCall
    if ($ElevatedCall) { [void](Read-Host 'Press Enter to close this Administrator window') }
    exit 0
}
function Show-Category {
    param([int]$Number)
    if ($Number -lt 1 -or $Number -gt $script:Categories.Count) { return }
    while ($true) {
        Clear-Host
        Write-Host ('='*74) -ForegroundColor DarkCyan
        Write-Host ("WINDOWS 11 TOOLKIT V5.1 - " + $script:Categories[$Number-1].Name) -ForegroundColor Cyan
        Write-Host $script:Categories[$Number-1].Hint -ForegroundColor Gray
        Write-Host ('='*74) -ForegroundColor DarkCyan
        foreach ($tool in $script:Tools | Where-Object Category -eq $Number) {
            Write-Host ("{0}  {1,-36} [{2}]" -f $tool.Id,$tool.Title,$tool.Risk)
        }
        Write-Host "`nID = run tool   ?ID = explain tool   B = back   Q = quit"
        $choice = (Read-Host 'Choose').Trim()
        if ($choice -match '^(?i:q)$') { return 'QUIT' }
        if ($choice -match '^(?i:b)$' -or -not $choice) { return }
        if ($choice -match '^\?(\d{1,3})$') {
            Show-ToolHelp $matches[1].PadLeft(3,'0')
            [void](Read-Host 'Press Enter')
            continue
        }
        if ($choice -match '^\d{1,3}$') {
            $selected = $script:Tools | Where-Object { $_.Id -eq $choice.PadLeft(3,'0') -and $_.Category -eq $Number } | Select-Object -First 1
            if ($selected) {Invoke-ToolkitTool $selected} else { Write-Host 'ID not in this category.' }
            [void](Read-Host 'Press Enter to continue')
        }
    }
}
function Search-Tools {
    $word = (Read-Host 'Search tools by name or description').Trim()
    if (-not $word) { return }
    $hits = @($script:Tools | Where-Object { $_.Title.IndexOf($word,[StringComparison]::OrdinalIgnoreCase) -ge 0 -or $_.Description.IndexOf($word,[StringComparison]::OrdinalIgnoreCase) -ge 0 })
    if (-not $hits.Count) { Write-Host 'No matches found.';[void](Read-Host 'Press Enter'); return }
    $hits | Select-Object Id,Title,Risk | Format-Table -AutoSize
    Write-Host 'Use the ID from its category menu to run it.'
    [void](Read-Host 'Press Enter')
}
while ($true) {
    Clear-Host
    Write-Host ('='*74) -ForegroundColor DarkCyan
    Write-Host 'WINDOWS 11 TOOLKIT V5.1  |  Explore / diagnose / repair by choice.' -ForegroundColor Cyan
    Write-Host ('='*74) -ForegroundColor DarkCyan
    foreach ($c in $script:Categories) { Write-Host (' {0,2}. {1,-28}  {2}' -f $c.Id,$c.Name,$c.Hint) }
    Write-Host "`nTOOLS: $($script:Tools.Count) | VIEW=read only | REPORT=writes file | CHANGE/REPAIR=confirm"
    Write-Host ' A = General Diagnostics | B = Deep Diagnostics | C = General Repair | D = Deep Repair'
    Write-Host ' S = search tools   Q = quit'
    $pick = (Read-Host 'Choose category').Trim()
    if ($pick -match '^(?i:q)$' -or $pick -eq '0') { break }
    if ($pick -match '^(?i:s)$') { Search-Tools;continue }
    if ($pick -match '^(?i:[abcd])$') {
        $id = switch ($pick.ToUpper()) { 'A' {'171'} 'B' {'172'} 'C' {'173'} 'D' {'174'} }
        $tool=$script:Tools|Where-Object Id -eq $id|Select-Object -First 1
        if($tool){Invoke-ToolkitTool $tool}
        [void](Read-Host 'Press Enter to continue')
        continue
    }
    if ($pick -match '^\d+$') {
        $n = [int]$pick
        if ($n -ge 1 -and $n -le $script:Categories.Count) {
            $outcome = Show-Category $n
            if ($outcome -eq 'QUIT') { break }
        }
    }
}
