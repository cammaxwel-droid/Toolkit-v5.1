# Repository Guidance

## Project constraints

- Target Windows 11 and Windows PowerShell 5.1. Keep scripts compatible with 5.1; do not introduce PowerShell 7-only syntax or APIs.
- Preserve the main toolkit's 180 action IDs and the integrated Repair Kit's existing action IDs and behavior unless a change explicitly requires otherwise.
- Keep `src/Toolkit.ps1`, `modules/`, `scripts/`, and `repair-kit/` in their existing relative locations; the launchers depend on this layout.
- Keep diagnostics read-only. Repairs and other system changes must remain individually selected and require the existing explicit confirmation flow. Never add automatic firmware, security, boot, or bulk repair changes.
- Do not execute or dot-source toolkit scripts as a validation shortcut. They may require elevation or make system changes. Prefer static checks and inspect any command side effects before changing them.
- Treat generated reports and system/event details as private; do not add device-specific data, credentials, or reports to source control.

## Validation

- Run the syntax and catalogue check from this directory with Windows PowerShell 5.1:

  ```powershell
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tests\Check-PowerShell-Syntax.ps1
  ```

- This check parses scripts without executing them and also verifies 180 unique main-menu IDs. It does not replace runtime testing on Windows; follow `TESTING.md` for manual smoke tests and safety boundaries.
- For changes to distributed files, check whether `SHA256SUMS.txt` must be regenerated and keep documentation and checksums consistent with the shipped files.