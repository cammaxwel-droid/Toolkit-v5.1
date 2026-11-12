# Contributing

Thanks for helping improve Toolkit V5.1. The original Toolkit lives in `Toolkit-V5.1-GitHub/Toolkit-V5.1/`; read its `AGENTS.md` first. The separate WPF desktop source lives beside it in `Toolkit-V5.1-GitHub/Toolkit-Desktop/` and targets .NET 10 for Windows.

## Ground rules

- Target Windows 11. Keep Toolkit scripts and desktop PowerShell helpers compatible with **Windows PowerShell 5.1**; do not introduce PowerShell 7-only syntax or APIs.
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

This parses every script without executing it and verifies the action ID catalogues. Follow `TESTING.md` for manual smoke tests. CI runs the same original Toolkit check on every push and pull request.

For desktop changes, install the .NET 10 SDK and run from `Toolkit-V5.1-GitHub/Toolkit-Desktop/`:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Build-Desktop.ps1 -Verify
```

The desktop suite uses disposable fixtures and off-screen WPF checks. It does not run real Toolkit repairs or installers. A non-elevated run explicitly reports the additional elevated-worker stub check as not run. See the desktop `VALIDATION.md` for the evidence and limits.

## Distribution files

Desktop and console downloads belong in GitHub Releases with SHA-256 checksums. Keep the original Toolkit unchanged when updating only the desktop. Keep the supplied icon, tests, repair kit and documentation.

For console release packages, copy [README-FIRST.txt](Toolkit-V5.1-GitHub/README-FIRST.txt) to the ZIP staging root beside the `Toolkit-V5.1` folder before generating the package checksums.

Do not commit generated desktop `app/`, `bin/`, `obj/` or `artifacts/` folders, local release staging or checkpoints. These remain local; source, assets and tests stay in Git.

If you intentionally change distributed files, update their docs and regenerate the relevant `SHA256SUMS.txt`. The earlier tracked `Toolkit-V5.1-GitHub.zip` and its checksum are preserved; regenerate its `.sha256` file only if that archive is intentionally replaced.

## Pull requests

Keep changes focused, describe the behaviour change and any side effects of the affected actions, and note how you validated it.
