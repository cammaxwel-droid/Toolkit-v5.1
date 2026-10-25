# Contributing

Thanks for helping improve Toolkit V5.1. The package lives in `Toolkit-V5.1-GitHub/Toolkit-V5.1/`; read its `AGENTS.md` first.

## Ground rules

- Target Windows 11 and **Windows PowerShell 5.1**. Do not use PowerShell 7-only syntax or APIs.
- Keep diagnostics read-only. Repairs must stay individually selected with the existing explicit confirmation flow. No automatic firmware, security, boot or bulk changes.
- Preserve the 180 main-menu action IDs and the 51 Repair Kit action IDs unless a change explicitly requires otherwise.
- Keep `src/`, `modules/`, `scripts/` and `repair-kit/` in their current relative locations.
- Never commit generated reports, event logs, device details or credentials.
- Do not run toolkit scripts as a validation shortcut; they may need elevation or change the system.

## Validating a change

From `Toolkit-V5.1-GitHub/Toolkit-V5.1/` in Windows PowerShell 5.1:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tests\Check-PowerShell-Syntax.ps1
```

This parses every script without executing it and verifies the action ID catalogues. Follow `TESTING.md` for manual smoke tests. CI runs the same check on every push and pull request.

## Distribution files

If you change distributed files, update the docs and regenerate `SHA256SUMS.txt`. If the packaged ZIP changes, regenerate `Toolkit-V5.1-GitHub.zip.sha256` too.

## Pull requests

Keep changes focused, describe the behaviour change and any side effects of the affected actions, and note how you validated it.
