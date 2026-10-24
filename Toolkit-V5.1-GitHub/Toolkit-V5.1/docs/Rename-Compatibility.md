# Toolkit V5.1 - reports and saved-data compatibility

Toolkit V5.1 keeps the existing console layout, action IDs and confirmation gates. Windows 11 and Windows PowerShell 5.1 remain the target.

## One destination for new reports

All toolkit-managed reports now use **Toolkit-Reports** under the actual Windows Documents folder. If that Documents location is unavailable, the existing user-profile fallback remains. This includes standalone reports, guided diagnostics, detailed event logs, snapshots, comparisons, driver exports, battery reports and Repair Kit reports.

The report-folder menu actions offer the current location and every existing previous location. Merely discovering previous folders does not create or change them.

| Previous report family | Earlier neutral folder | Original folder |
|---|---|---|
| Single-action reports | `ToolkitV3-Reports` | `Windows11-ToolkitV3-Reports` |
| Utility history and snapshots | `ToolkitV4-Reports` | `Windows11-ToolkitV4-Reports` |
| Guided diagnostics and workflow history | `ToolkitV5-Reports` | `Windows11-ToolkitV5-Reports` |
| Repair Kit | `RepairKit-Reports` | `Windows11-RepairKit-Reports` |

Existing files stay in place. No automatic move, merge, rename or rewrite of previous saved data occurs.

## Histories and snapshots

New action-invocation history uses `Repair-History.csv`; new guided repair-attempt history uses `Workflow-Repair-History.csv`. These have different columns and remain separate. The respective history views also read their earlier folders; guided history recognises the previous `V5-Repair-History.csv` filename. Rows remain ordered by time with the existing 25-row action / 30-row workflow display limits.

Snapshot comparison discovers files in the shared folder and both previous utility folders. Equal filenames in different folders remain separate, with full paths shown in the selection menu. Duplicate references to the same path are read once. Unreadable locations produce a warning while available files remain usable.

New snapshots identify their format as `Toolkit-Snapshot-1`. The reader also accepts `ToolkitV4-Snapshot-1` and `Windows11-ToolkitV4-Snapshot-1`, including mixed pairs. Snapshot fields are unchanged.

New diagnostic JSON identifies its format as `Toolkit-Diagnostic-2`, replacing `ToolkitV5.1-Diagnostic-2` and the earlier `Windows11-ToolkitV5.1-Diagnostic-2`. Diagnostic fields are unchanged. External consumers that check the identifier must recognise the new name. Previous reports are not rewritten, and older toolkit copies are not upgraded to read the new identifiers.

## Power-plan undo

Fresh undo records use `%LOCALAPPDATA%\Toolkit\PowerPlan-Undo.json`. Existing records at `%LOCALAPPDATA%\ToolkitV4\PowerPlan-Undo.json` and `%LOCALAPPDATA%\Windows11ToolkitV4\PowerPlan-Undo.json` remain supported in place.

- No existing record: use the new location when a profile change needs a saved original plan.
- Exactly one valid record: reuse that record in its existing location.
- Multiple records, even identical ones, or a sole unreadable/invalid record: stop profile changes and undo with the relevant paths. Do not automatically choose or merge a record.
- The explicitly selected undo action still removes its record only after Windows reports a successful restoration.

## Current and historical names

Active modules, function names, guides and report headers use neutral names or Toolkit V5.1. Historical release notes and archived catalogues retain their actual release labels. Previous folder, filename and schema identifiers remain only where needed to explain or test compatibility.

Preparation and verification use static checks and synthetic files. They do not run maintenance actions or alter existing reports or power settings.
