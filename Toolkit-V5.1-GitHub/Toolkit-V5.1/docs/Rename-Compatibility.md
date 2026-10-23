# Toolkit V5.1 - existing reports and settings

Toolkit V5.1 uses the same console layout, actions and confirmation gates. Windows 11 and Windows PowerShell 5.1 remain the target. The main launcher is `Start-Toolkit.cmd`; run it as Administrator as before.

## Reports

New files use the actual Windows Documents folder, with the existing user-profile fallback when Documents is unavailable.

| Purpose | New folder | Previous folder retained in place |
|---|---|---|
| Original single-action reports | `ToolkitV3-Reports` | `Windows11-ToolkitV3-Reports` |
| V4 histories and snapshots | `ToolkitV4-Reports` | `Windows11-ToolkitV4-Reports` |
| Guided workflow reports and history | `ToolkitV5-Reports` | `Windows11-ToolkitV5-Reports` |
| Repair Kit reports | `RepairKit-Reports` | `Windows11-RepairKit-Reports` |

Preparation does not move, rewrite or delete earlier files. The existing V3 and V5 report-folder actions offer current and previous locations when the previous folder exists. The standalone Repair Kit's earlier reports remain available in the previous folder shown above.

History views read both locations, order rows by time and retain the existing 25-row V4 / 30-row V5 display limits. Snapshot comparison lists files from both folders and shows full paths so equal filenames remain distinguishable. Unreadable report locations or history files produce a warning; available records can still be displayed.

## JSON identifiers

New snapshots use `ToolkitV4-Snapshot-1`. Comparison accepts this and the previous `Windows11-ToolkitV4-Snapshot-1`, including a mixed pair. The data fields are unchanged.

New diagnostic exports use `ToolkitV5.1-Diagnostic-2` instead of `Windows11-ToolkitV5.1-Diagnostic-2`, with unchanged data fields. Existing reports are not rewritten. External consumers that check this identifier must accept the new name; older toolkit copies are not modified by this preparation.

## Power-plan undo

New undo records use `%LOCALAPPDATA%\ToolkitV4\PowerPlan-Undo.json`. Existing records at `%LOCALAPPDATA%\Windows11ToolkitV4\PowerPlan-Undo.json` remain supported in place.

- If exactly one record exists, it must contain readable JSON and a valid original power-plan GUID; that record is reused.
- If neither exists, the next explicitly selected profile change saves a new record in the neutral location.
- If both exist, or the existing record is unreadable or invalid, profile changes and undo stop with the relevant paths. No record is automatically preferred, merged, moved or overwritten.
- The normal, explicitly selected undo action still removes its record only after Windows reports a successful restoration. Preparation and verification do not run this action.

Old names remain in compatibility code, tests and this document so earlier data can be recognized. They are not current product branding.
