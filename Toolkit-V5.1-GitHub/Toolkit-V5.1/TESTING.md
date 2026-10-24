# Toolkit V5.1 — validation / smoke tests

> Keep a copy of the previous package as a fallback until the current package passes on your computer.
> **Do not run repair actions just to test the menu.**

## 1. PowerShell parser test (non-executing)

Open Windows PowerShell in the **extracted Toolkit root directory** and run:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tests\Check-PowerShell-Syntax.ps1
```

This uses `System.Management.Automation.Language.Parser` to check syntax without executing the scripts. Expected: one PASS per `.ps1` file and an overall PASS. If a file fails, copy the error line/column to report.

## 2. Launcher and output

- Right-click `Start-Toolkit.cmd` → **Run as administrator**. A normal non-admin run should refuse and explain why.
- Confirm the menu shows **Toolkit V5.1** and four `A/B/C/D` shortcuts.
- Select **category 15** and inspect 171–180.
- Run **175 Diagnostic Self-Test** to verify commands and report path.
- Run **171 General Diagnostics**; expect specific rows e.g. `[PASS]`, `[WARNING]`, `[ERROR]`, `[NO DATA]`, and exactly one TXT and one JSON report saved.
- Inspect the report. A true error shouldn't appear as a blank `OUTPUT / END` block.
- Run **172 Deep Diagnostics**, enter anything other than `SCAN` to skip optional long SFC/DISM verification; expect `NO DATA — skipped` for both optional tests.
- Test legacy firmware tool **043**: expect explicit `PASS — no firmware-class devices report Error status` or error list.
- Test legacy Explorer-crash tool **123**: expect crash details or explicit `PASS — no crashes`.

## 3. Confirm repairs are opt-in

- Select **173 General Repair** and **174 Deep Repair**; let diagnostics run, choose reported symptom `0`, then enter `0` to exit without a change.
- **Do not** type `DEEP REPAIR`/`YES` unless addressing a real detected issue.
- For a symptom-only dry run, choose a symptom but select `0` at the final options menu. Check `Workflow-Repair-History.csv` only when an action was selected; it logs `CANCELLED`, `OPENED`, `INVOKED`, `COMMAND SUCCEEDED`, `VERIFIED`, or `ERROR` without asserting the symptom is cured.
- Deep Repair must **not** suggest DISM RestoreHealth if the DISM scan was skipped or found no corruption; must **not** suggest SFC repair if verification passed/skipped.
- Unavailable commands should yield `ERROR` or `NO DATA` with context, not `PASS`.

## 4. Privacy and portability

- Report files must go under the actual Windows Documents folder (whatever the login display name).
- Snapshot/history tools read the current location and both previous folder-name generations; all new reports use Toolkit-Reports as documented in docs/Rename-Compatibility.md.
- Ensure no system report, personal path, API key, WER memory dump, or account data is committed to public GitHub.
- Confirm the archived ZIP and SHA256SUMS list using Windows `Get-FileHash` if desired.

## 5. Troubleshooting runtime errors

If a diagnostics action fails, provide the **exact `ERROR` line and action ID**, not a screenshot of a blank output box. The diagnostic TXT/JSON can be shared after removing sensitive details. Do not paste crash dumps, passwords or API keys.

The rename is checked with the Windows PowerShell 5.1 parser, synthetic compatibility tests and package integrity verification. These do **not** establish interactive Windows runtime or UAC acceptance.

## 6. V5.1 regression checks (no repairs)

- Under Windows PowerShell 5.1 (admin), run syntax test from `tests\Check-PowerShell-Syntax.ps1`. **No changes should be made by this test.**
- Re-run `171` / General Diagnostics. If known Explorer crashes exist in the last seven days *in the accessible Application log*, verify Explorer warning displays a count and faulting module. If earlier logs have been cleared, do not claim the crash never happened.
- Run `172` / Deep Diagnostics, optionally skip SFC/DISM on first pass; verify reports state `NO DATA - Skipped by user` for each skipped integrity scan.
- Verify Deep Diagnostics writes **System-Events** and **Application-Events** TXT files when matching events exist, and these show source, event ID, time and message or raw event payload. Confirm two WER follow-up Event 1001 entries do not count as three Explorer crashes.
- If you elect to run SFC /verifyonly, ensure `SFC-VerifyOnly-*.txt` exists, is readable, and an unclassifiable result is NO DATA with an explanation instead of a fake PASS.
- Open General Repair and Deep Repair, select `0` symptom and `0` to exit. Confirm no settings change. Do not execute repairs merely to test them.
- Confirm `Start-Toolkit.cmd` still explicitly requires **Run as administrator**.
- Avoid uploading raw TXT/JSON system data to GitHub, especially new event-detail files.

Test limitation: a PowerShell parser check detects syntax errors but **not** faulty Windows module behavior, unreliable event source output or unsafe settings made elsewhere.

## 7. Product rename and saved-data compatibility

Run this isolated test from the extracted root in Windows PowerShell 5.1:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tests\Check-Rename-Compatibility.ps1
```

It loads only reviewed function definitions, uses temporary synthetic reports and undo records, and mocks menu input and window launches. It does not import an application entrypoint or run maintenance actions. Expected: 39 compatibility checks pass; fixture cleanup completes without errors.

Coverage includes empty and legacy/current report folders, combined histories, duplicate snapshot filenames, old/new/mixed snapshot pairs, missing/invalid/conflicting undo records, unchanged existing data, and report-folder selection. See [Rename compatibility](docs/Rename-Compatibility.md) for the resulting behavior.

For a separate manual menu-only acceptance check, verify the main launcher title and home/category headings show **Toolkit V5.1**, and the Repair Kit launcher/menu headings omit the old product prefix. Exit without selecting diagnostics or repairs. Static and mocked tests do not verify native title-bar rendering.

## Unified reports and saved-data compatibility

- Run the synthetic compatibility check in Windows PowerShell 5.1. It loads only reviewed function definitions, substitutes report destinations and process launchers, and uses temporary fixture files.
- Check new, both previous and mixed snapshot/history locations, duplicate filenames, distinct action/workflow CSV formats, current/previous schema identifiers and report-folder choices.
- Check fresh, sole current/previous, conflicting and invalid undo records across all three locations. Existing fixture files must remain byte-identical.
- Verify the renamed modules/functions and current documentation links, all 180 main IDs and 51 Repair Kit IDs, both checksum manifests and the packaged ZIP.
- Do not run maintenance or repair actions as part of automated verification. Native UI and real diagnostic/repair acceptance remain separate manual checks.
