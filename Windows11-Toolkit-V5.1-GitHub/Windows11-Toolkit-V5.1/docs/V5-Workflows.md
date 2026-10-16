# Windows 11 Toolkit V5.1 — Four guided workflows

**All four are accessible immediately from the home screen:** `A` General Diagnostics, `B` Deep Diagnostics, `C` General Repair, `D` Deep Repair. Also available under category **15: Four Guided Workflows**, IDs **171–174**.

## A. General Diagnostics

Runs a concise **read-only** sweep of Windows version/build, instantaneous memory and CPU load, C: free space, basic physical disk health, Explorer process state, Explorer application-crash events, PnP Error devices, Defender status, firewall profiles, and selected pending-restart indicators. Every check produces **PASS**, **WARNING**, **ERROR**, or **NO DATA** (not an empty screen).

It does **not** claim every old driver date is bad. The file `twinui.pcshell.dll` is not checked for corruption merely because Explorer once crashed. Historic error events are not proof that an issue is still occurring.

Exports both a plain-text summary and machine-readable JSON to **Documents\Windows11-ToolkitV5-Reports**. It takes a snapshot, not a long-term performance benchmark.

## B. Deep Diagnostics

Runs every general check, then adds:

- Recent System and Application critical/error events (most recent 48 hours, up to 100 of each)
- The largest process working sets and registered startup applications
- Windows Terminal and PowerToys/Command Palette process presence
- Basic network adapter and DNS checks (not mobile-tower signal or throughput)
- Windows Audio and print spooler status, restore-point availability, update-service status
- Existence and version of `twinui.pcshell.dll` (not automatically an integrity verdict)
- **Optional lengthy** `DISM /Online /Cleanup-Image /ScanHealth` and `sfc /verifyonly` after you type `SCAN`

SFC/DISM check output may be localised. When it cannot be reliably interpreted, the result is **NO DATA**, not an invented PASS. Both optional commands are verification-only, not repairs.

## C. General Repair — guided, not automatic

Runs **fresh general diagnostics first**, then asks whether you have an **actual ongoing symptom**. It offers relevant evidence-based options and, where the scan cannot establish a cause, a small targeted action only for the symptom you explicitly select, such as:

- Open Task Manager if actual RAM use is high (no process termination)
- Restart Explorer/taskbar **only if it is presently not running** (closes Explorer windows)
- Open Reliability Monitor to investigate logged Explorer crashes, without assuming they're ongoing
- Explain pending restart flags; **does not reboot your PC**
- For a **reported** issue: reset Microsoft Store cache, flush DNS cache, restart Windows Audio or print spooler (may interrupt work); or open Windows Update / per-app repair settings without automatically resetting them

Type the option number, review the reason, then type **YES** for actions that change Windows state. You can exit without changing anything.

## D. Deep Repair — guided, evidence-based

Runs **fresh deep diagnostics first** and asks about a current symptom. You may elect to include the lengthy integrity verification step. Potential options appear **only if the relevant problem is detected**:

- `DISM /Online /Cleanup-Image /RestoreHealth` if the DISM integrity scan reports repairable component-store damage
- `sfc /scannow` if verification reports protected-file integrity violations
- DNS cache flush if DNS resolution fails (after verifying internet/hotspot connectivity)
- Restart the Windows Audio service if it is not running (only if sound is malfunctioning)
- The general repair review options above

An evidence-supported advanced `REPAIR` action requires typing **DEEP REPAIR** and then **YES**. Other changes still require **YES**. Each action runs separately; the toolkit does **not** run every fix or claim the underlying problem is resolved merely because a command returned success. Re-run diagnostics afterward.

**Deep Repair intentionally does not:** reset all Windows Update services, reset every networking adapter, edit permissions en masse, modify Windows Insider enrollment, flash BIOS/Thunderbolt firmware, change Secure Boot/TPM keys, wipe drives, remove drivers, or disable Windows Security.

## Status meanings

| Status | Interpretation |
|---|---|
| PASS | Specific test completed and met its stated condition; not a whole-PC health guarantee |
| WARNING | Specific observation merits context or attention; may be intentional/historic |
| ERROR | Check itself failed; **do not interpret as a system defect** without inspecting the error |
| NO DATA | Unavailable, deliberately skipped, or output could not be classified; **not a PASS** |

For older V4 tools still included in V5, a blank command pipeline now says `NO DATA`; many legacy tools open a GUI or write directly to console and cannot be independently classified. Use workflow A/B for well-defined checks.

## Reports and sharing

V5 diagnostic TXT/JSON reports and V5 repair-attempt history are written under the actual Documents folder, without constructing an account directory from the displayed Windows username. Legacy V4 and V3 tools still use their original legacy report folders.

**Private information:** Reports may contain computer names, program names, local paths, network addresses, and Windows errors. Redact anything sensitive before posting to a public issue or GitHub repository. Detailed SFC/DISM output is displayed on screen; the V5 summary is concise and does not automatically attach full CBS logs.

## Existing V4 features kept

Security audit, RAM/startup report, repair history, driver CSV, folder/backup comparison, before-and-after snapshots, Developer Doctor, WinGet curated installer, Gaming/Programming/Studying/Battery Saver previews and undo, 51-action integrated Repair Kit, harmless tricks, and advanced Windows viewers remain in their earlier menus.

## V5.1 event/crash reporting additions

- Explorer crash detection checks structured Event ID 1000 payload and the readable message when present. It checks seven days of accessible Application log entries and does not count WER follow-ups as new crashes. Windows updates, log clearing and retention can remove older records; "not found" does not erase a previously confirmed incident.
- Deep Diagnostics includes two warning summaries: System and Application critical/error logs over 48 hours. The summaries name the frequent providers and their Event IDs; separate event-detail TXT reports list times, IDs and event messages/payloads. Many events clustered at startup may describe one incident.
- Optional SFC verification captures the raw console output in `SFC-VerifyOnly-*.txt`. If text cannot be classified, output is NO DATA with a link to that file; exit code 0 alone must not be interpreted as proof of clean system files.
- Raw System/Application logs and error messages may include names, local paths or URLs. Do not post them to a public GitHub repository.

**Caution:** This is triage, not proof of a fault. The toolkit does not reset Codex, Thunderbolt, Windows Update, TPM or services because log entries were recorded. A repair should target a current symptom or verified fault.
