# Toolkit V5.1

**A menu-driven Windows troubleshooting, diagnostics, repair and utility toolkit**, organised around **four reliable guided workflows**.

- **180 main-menu actions across 15 categories**, plus the integrated **51-action legacy Repair Kit**.
- Built for **Windows 11 Pro and Windows PowerShell 5.1**. Windows modules and available commands vary by device and edition.
- **Administrator required when starting the main launcher** — this is intentional and matches actual use on the target laptop.
- Every check inside the general/deep workflows returns **PASS / WARNING / ERROR / NO DATA** with what was tested and a report saved to disk.
- Guided general/deep repairs are **not** a one-click system reset: fresh diagnosis, optional reported symptom, clear options, explicit confirmation, separate operations, log outcomes.
- Does **not** change Windows Insider Program enrollment. Keep Insider off if you prefer a stable, non-Insider installation.

## Why V5.1 exists

This is the **diagnostic accuracy and event-triage update** based on real diagnostic reports. It does not add speculative "optimizer" commands or perform mass repairs.

- Explorer crash detection now examines both rendered error text and **structured Event ID 1000 fields** over **seven days**, avoiding double-counting follow-up WER 1001 entries. A clean accessible log **does not erase confirmed earlier crashes** or guarantee none occurred.
- System/Application warning summaries include provider **and Event ID**, last event time, and number since last boot; detailed **read-only per-event TXT logs** are created alongside the diagnostic report, including event payloads when rendered messages are empty (e.g. Codex Sandbox).
- `sfc /verifyonly` saves its raw captured output separately. If PowerShell cannot interpret its text, status stays **NO DATA** with a specific path and warning, rather than inventing a PASS.
- Existing 180 main menu actions, four guided workflows, report history, app installer, experience profiles and secondary Repair Kit retained.
- **No software installs, WinGet package upgrades, BIOS/Thunderbolt flashes, Insider Program changes or repair operations occur during a diagnostic.**

## Quick start

1. Extract the ZIP to its own folder; **do not run from inside the ZIP**.
2. **Right-click `Start-Toolkit.cmd` and choose `Run as administrator`**. This launcher intentionally refuses to start without an elevated console. Do not double-click normally and expect per-action elevation.
3. Press `A` **General Diagnostics**, `B` **Deep Diagnostics**, `C` **General Repair** or `D` **Deep Repair** from the main menu. Or choose category 15 and enter an action ID such as `171`.
4. The diagnostic workflows show meaningful results in the console and export a **TXT summary + JSON findings** to the actual Windows Documents folder, under `Toolkit-Reports`.
5. For guided repairs, optionally identify your current symptom, review suggested actions and select **one**. You may always exit. Changes require typing `YES`; advanced repairs require `DEEP REPAIR` and `YES`.

**Important:** `CHANGE` and `REPAIR` labels on single-action tools describe potential side effects, and those actions remain available. The *new guided workflows* are the preferred path for diagnosis and targeted repair.

### Main screen shortcuts

| Key | Workflow | Impact |
|---|---|---|
| `A` | General Diagnostics | Read-only checks + saved report |
| `B` | Deep Diagnostics | More checks, optional lengthy SFC/DISM verification + report |
| `C` | General Repair | Runs General Diagnostics, proposes individually confirmed relevant actions |
| `D` | Deep Repair | Runs Deep Diagnostics, proposes advanced fixes only on supporting findings |
| `S` | Search the 180 options | No system change |
| `Q` | Quit | No system change |

[Read the full workflow guide](docs/Guided-Workflows.md).

## Included features

| Feature | Location |
|---|---|
| Four guided workflows | Main menu `A`–`D`, category 15, IDs 171–174 |
| Toolkit diagnostic self-test | Category 15, ID 175 |
| Workflow instructions / saved reports / repair history | Category 15, IDs 176–180 |
| File Explorer, taskbar, desktop | Category 1 |
| Windows Update / WinGet app upgrades | Category 2 |
| Microsoft Defender, firewall, TPM, Secure Boot | Category 3 |
| Driver inventories, firmware status | Category 4 |
| RAM / CPU / battery and power | Category 5 |
| Phone hotspot / Wi-Fi / networking | Category 6 |
| Disks, ZIP verification and downloaded files | Category 7 |
| Older single-action diagnostics and repairs | Category 8 |
| System and developer utilities | Category 9 |
| Reports, shortcuts and help | Category 10 |
| Security reports, baseline comparisons, folder integrity | Category 11 |
| Gaming / Programming / Studying / Battery Saver profiles | Category 12 |
| Individual app installer, Developer Doctor, package checks | Category 13 |
| Hidden Windows, harmless tricks and advanced built-ins | Category 14 |
| 51-action secondary Repair Kit | `repair-kit/Start-Repair-Kit.cmd` or main tool 166 |

Profiles only select existing Windows power plans where supported and open relevant Settings pages; they do not automatically rewrite dozens of registry or security settings. Previous plan can be restored from their menu. WinGet app installation requires separate consent. No mandatory installs.

## Reporting and meaningful outputs

**Guided workflows** use these statuses:

- `PASS` — this precise check passed; not a guarantee Windows is perfect
- `WARNING` — noteworthy result; can be historical or intentional
- `ERROR` — the diagnostic command failed; the check may be inconclusive
- `NO DATA` — missing/skipped/unclassifiable result, **not** proof of success

A result can be `ERROR` because a management module is unavailable, without implying a Windows hardware problem.

**Single-action tools** remain compatible with the old catalog and sometimes open external windows or report through `Write-Host` instead of a PowerShell pipeline. Their execution wrapper now explains that empty pipeline output is **NO DATA**, rather than silently showing `OUTPUT / END`. This is *not* a complete rewrite of all old tools into validated diagnostics; use the consolidated guided workflows for that.

V5.1 adds private `System-Events-*.txt`, `Application-Events-*.txt` and, when SFC is run, `SFC-VerifyOnly-*.txt` diagnostic evidence files. These are **not safe to upload publicly without reviewing/redacting**, and event logs may contain local paths and hardware or network data.

All new toolkit and Repair Kit reports use `Toolkit-Reports` under the actual Documents folder. Existing reports, histories, snapshots and power-plan undo records remain accessible through the behaviour described in [Saved-data compatibility](docs/Rename-Compatibility.md). Existing saved data is not automatically moved or rewritten.

## Security and limitations

- **Never automatically** flashes BIOS/SSD/Thunderbolt firmware, changes Secure Boot keys, clears TPM, changes BitLocker encryption state, edits boot entries, disables Defender/firewall, deletes partitions or changes Windows Insider channel.
- The toolkit **does not** perform invasive Windows Update resets, blanket service resets, speculative registry optimizations, or force a reboot.
- `DISM /ScanHealth` and `sfc /verifyonly` run only after choosing **Deep Diagnostics or Deep Repair** and explicitly typing `SCAN`. They can take substantial time, especially on an 8 GB laptop.
- Even if a repair command exits successfully, **re-run the diagnostic and verify the original symptom** before calling the problem resolved.
- Do not blindly run the entire older Repair Kit; those are individually selectable tools.
- No bundled executables, third-party binaries, online installers or API keys. `winget` uses the installed Windows Package Manager and standard app sources when **explicitly chosen**.
- Review downloaded script content. The CMD launcher uses a **process-only** `-ExecutionPolicy Bypass`; it does not modify system policy.

## Repository/file structure

```text
Start-Toolkit.cmd       Main launcher; Administrator required
Start-Toolkit.cmd.txt   Text fallback for blocked .cmd downloads
src/Toolkit.ps1                 Interactive 180-tool menu
modules/Toolkit-Utilities.ps1          Additional toolkit utilities
modules/Toolkit-Workflows.ps1       Four guided diagnostic/repair workflows
scripts/                       Existing standalone audit and maintenance scripts
repair-kit/                    Existing 51-action repair kit (integrated copy)
docs/Guided-Workflows.md           Workflow descriptions / safety boundaries
docs/Tool-Index.json           Base main-menu tool metadata
legacy/                        Historical V2 references
TESTING.md                     Windows parser/smoke test checklist
tests/Check-PowerShell-Syntax.ps1
SHA256SUMS.txt                 SHA-256 digest list of distributed files
```

`src/Toolkit.ps1`, modules and scripts must stay in their relative locations. A `.cmd.txt` file will **not** run as a batch file until saved as `.cmd` with **Save as type: All files**.

## First-time test (recommended)

1. Run the included syntax check from **Windows PowerShell 5.1** (see [TESTING.md](TESTING.md)).
2. Launch as Administrator and run **175: Toolkit diagnostic self-test**.
3. Run **171: General Diagnostics** and check the report folder; verify each line includes a meaningful status.
4. Explore **172: Deep Diagnostics**, but skip the long optional integrity scans on the first run.
5. Open **173 / 174** and exit without choosing repairs to confirm no changes occur without consent.

**Validation disclosure:** The included Windows PowerShell 5.1 parser and synthetic compatibility checks validate source structure and saved-data handling without running maintenance actions. Archive contents and checksums are verified separately. Interactive menu/title-bar behavior, UAC, Windows diagnostic providers and actual repairs require runtime acceptance; those are not established by these checks.

## Privacy / GitHub

**Do not upload reports, WER crash dumps, network configuration, project paths, tokens or personal device details to a public GitHub repository.** Reports are intentionally generated under Documents, outside the source tree. Review and redact before sharing elsewhere.

## Reference documentation

- [DISM image repair](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/repair-a-windows-image)
- [Microsoft SFC](https://support.microsoft.com/en-us/windows/using-system-file-checker-in-windows-365e0031-36b1-45b1-9b4c-d65dbfa400c8)
- [Windows Package Manager](https://learn.microsoft.com/en-us/windows/package-manager/winget/upgrade)
- [Windows Event Log](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent)
