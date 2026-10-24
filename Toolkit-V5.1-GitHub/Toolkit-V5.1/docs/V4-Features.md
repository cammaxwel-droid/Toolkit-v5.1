> Historical V4 release reference. For current operation and report locations, see [Toolkit V5.1](../README.md).

# What's new in Toolkit V4

V4 includes every V3.1 main-menu command plus these additions. Use `?ID` in the launcher to see a brief explanation before running anything.

**Safety classes:** `VIEW` = no system changes; `REPORT` = creates a report; `CHANGE`/`REPAIR` = requires explicit `YES`. The launcher is intentionally run as Administrator from the start.

## Deep audits / before-after comparison

| ID | Tool | Class |
|---|---|---|
| `126` | Security posture overview | REPORT |
| `127` | Repair & change history | VIEW |
| `128` | Save baseline snapshot | REPORT |
| `129` | Compare two snapshots | REPORT |
| `130` | Folder backup comparison | REPORT |
| `131` | Package + driver update scan | REPORT |
| `132` | Startup & heavy RAM report | REPORT |
| `133` | Security check in console | VIEW |
| `134` | System reliability events | VIEW |
| `135` | Check restore point status | VIEW |
| `167` | RAM usage delta (10 seconds) | VIEW |
| `168` | Save driver inventory CSV | REPORT |

## Experience profiles

| ID | Tool | Class |
|---|---|---|
| `136` | Preview Gaming profile | VIEW |
| `137` | Apply Gaming profile | CHANGE |
| `138` | Preview Programming profile | VIEW |
| `139` | Apply Programming profile | CHANGE |
| `140` | Preview Studying profile | VIEW |
| `141` | Apply Studying profile | CHANGE |
| `142` | Preview Battery Saver profile | VIEW |
| `143` | Apply Battery Saver profile | CHANGE |
| `144` | Restore pre-profile power plan | CHANGE |
| `145` | Show current plan/profile | VIEW |

## Optional app installer / development tools

| ID | Tool | Class |
|---|---|---|
| `146` | Curated app installer menu | CHANGE |
| `147` | Developer environment doctor | REPORT |
| `148` | Windows installed apps/repair UI | VIEW |
| `149` | App upgrades scan (WinGet) | VIEW |
| `150` | Official Windows driver offers | VIEW |
| `151` | Find tool executable paths | VIEW |
| `152` | Check signed download file | VIEW |
| `169` | Open Windows Store | VIEW |

## Hidden tools / advanced troubleshooting

| ID | Tool | Class |
|---|---|---|
| `153` | Symptom-guided troubleshooting | VIEW |
| `154` | Open All Tasks (God Mode) | VIEW |
| `155` | Open hidden shell folders | VIEW |
| `156` | Hidden Run shortcuts | VIEW |
| `157` | Windows keyboard tricks | VIEW |
| `158` | Fun Matrix-style terminal rain | VIEW |
| `159` | Random Windows tip | VIEW |
| `160` | Advanced boot entry view | VIEW |
| `161` | Advanced services insight | VIEW |
| `162` | Advanced task triggers | VIEW |
| `163` | Advanced network routes | VIEW |
| `164` | Windows performance tools | VIEW |
| `165` | Taskbar/Explorer recovery | CHANGE |
| `166` | View integrated repair kit | VIEW |
| `170` | Unsigned driver inventory | VIEW |

## Suggested quick workflows

**Before/after:** 128 Save baseline → make your planned change → 128 Save another baseline → 129 Compare snapshots.

**Corrupt ZIP or incomplete backup:** 130 Compare folders (size/optional hashes) plus existing ZIP integrity test (see older menu category 7).

**Too much RAM:** 132 Startup & heavy RAM report → choose one app to close normally → repeat report. Do not mass-disable Windows services.

**Security review:** 126 Security posture overview → inspect report → Repair Kit R21/R22 only if an actual malware/signature task is needed.

**Programming setup:** 147 Developer environment doctor → inspect installed runtimes → 146 Curated installer if a missing utility is genuinely wanted.

**Symptom unknown:** 153 Troubleshooting wizard → select a symptom → review suggested read-only checks.

**Gaming/studying/programming:** use Preview (136/138/140) before Apply (137/139/141), and use Undo 144 when finished. Power plan choices depend on what your laptop supports.

## Other references

- `Command-Reference-V3.txt` holds the legacy and V3 command reference.
- `Windows-Shortcuts.txt` holds existing keyboard shortcuts.
- `V4-Windows-Shortcuts.txt` adds harmless useful shortcuts.
- `V4-Tools-Index.json` is a structured catalogue; it is not an installer.
