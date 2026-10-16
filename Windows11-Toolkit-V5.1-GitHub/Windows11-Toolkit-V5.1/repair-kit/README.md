# Windows 11 Repair Kit — V5 legacy edition (51 actions)

A **separate, menu-driven Windows troubleshooting and repair toolkit**. Designed for Windows 11 and Windows PowerShell 5.1, including 8 GB laptops.

**51 selectable single-action tools across six categories.** The *four consolidated V5 workflows* are available through the main toolkit, not in this smaller standalone kit. This V5-integrated copy keeps the user's requested **Administrator from startup** workflow. Start read-only, review results, and run only repairs that match a real problem.

## Launch

1. Extract this ZIP completely. Keep `src/RepairKit.ps1` beside the launcher.
2. For the **V5 integrated edition**, right-click `Start-Repair-Kit.cmd` and select **Run as administrator**. Administrator privileges are required from the start by design.
3. Enter a category number, then an action ID such as `R04`.
4. Type `?R04` to see its purpose, whether it changes anything, and whether it needs Admin.
5. The V5 launcher is already elevated at launch. Never execute untrusted toolkit copies as Administrator.
6. `CHANGE`/`REPAIR` actions require typing `YES` before running.

**If CMD downloads are blocked:** `Start-Repair-Kit.cmd.txt` is the same launcher as text. In Notepad choose Save As > Save as type **All files** > `Start-Repair-Kit.cmd` in the extracted kit's root.

The launcher uses `-ExecutionPolicy Bypass` **only for its PowerShell process** to run the reviewed local script. It does not change system execution-policy settings. Read and verify scripts before running them, particularly from third-party copies.

## Categories

| Menu | Contents |
|---|---|
| 1. Windows corruption & reliability | DISM read-only checks, SFC, repair chain, restart indicators, crash history |
| 2. Explorer, display, audio & apps | Restart taskbar/Explorer, Task Manager, audio service, Store cache, graphics reports |
| 3. Security checks and scans | Defender scans/signature update, firewall status, TPM, Secure Boot, BitLocker |
| 4. Hotspot & connectivity | Wi-Fi, DNS, proxy, TCP 443, cache flush, optional Winsock reset |
| 5. Drivers, storage & ZIPs | Device problem codes, CSV driver inventory, disk scan/health, ZIP integrity and SHA-256 |
| 6. Updates, recovery & reports | WinGet, Windows Update logs, print spooler, restore point, RAM/battery report |

See `docs/Repair-Command-Reference.txt` for the ID catalogue and common copy/paste commands. `TROUBLESHOOTING.md` covers recommended sequences.

## Safety boundaries

- No flashing BIOS/Thunderbolt/Intel ME/SSD firmware, and no third-party driver installers.
- No blanket antivirus/firewall disabling, TPM clearing, Secure Boot key changes, boot edits, partition deletion, or user-profile renaming.
- Won't silently reset every Windows Update component, Windows permissions, or the entire network.
- **SFC/DISM** repair Windows protected files and the Windows component store; they are **not a performance boost**.
- **Defender Quick Scan** and **signature update** are different tasks; they can take time.
- **Winsock reset** is deliberately marked `REPAIR` and may require a Windows restart; use it only if relevant.
- **Restart Explorer** closes Explorer windows; **audio/spooler restarts** interrupt their respective functions.
- *Open Settings* commands may expose controls with side effects, but the kit does not activate them.

## Update scans: what is (and is not) checked

- `winget upgrade` queries supported application updates; `winget upgrade --all` installs supported **apps** only after consent.
- Driver inventory lists **installed versions**, not latest available vendor-approved versions. Windows Update Optional updates can offer compatible drivers, but not all models or firmware.
- Windows Update handles Windows OS patches; WinGet cannot substitute for it.
- **Never assume `winget upgrade` knows all installed applications or drivers.**

## Reports and privacy

Reports are created in the **actual Windows Documents folder**, under `Windows11-RepairKit-Reports`, not in this repository. They can include local paths, usernames, software, network and hardware data. Review before sharing, and never commit private reports, tokens or credential files.

## Output caveat

This standalone Repair Kit preserves the older 51 individual commands. The wrapper now displays a result explanation when there is no structured PowerShell pipeline output, but **some older actions still write to the console or launch GUI settings**. No data is not proof of no errors. For actual PASS/WARNING/ERROR/NO DATA classifications and consolidated TXT/JSON reports, use the four guided workflows in **Windows 11 Toolkit V5**.

## Compatibility

Script uses common Windows 11 features, with some commands requiring Windows Pro, PowerShell management modules, installed Windows Security providers, or enabled System Protection. Any unavailable tool should show a message; it must not be interpreted as a failed system. The ZIP, paths, manifest and scripts have been **statically checked**, but interactive Windows execution and administrator prompts need to be tested on your device.

## Official reference starting points

- [DISM](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/repair-a-windows-image)
- [SFC](https://support.microsoft.com/en-us/windows/using-system-file-checker-in-windows-365e0031-36b1-45b1-9b4c-d65dbfa400c8)
- [WinGet upgrade](https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade)
- [Windows Security](https://support.microsoft.com/en-us/windows/stay-protected-with-the-windows-security-app)
- [Defender PowerShell](https://learn.microsoft.com/en-us/powershell/module/defender/start-mpscan)

Do not post logs or reports to a public GitHub repo without redacting personal information.
