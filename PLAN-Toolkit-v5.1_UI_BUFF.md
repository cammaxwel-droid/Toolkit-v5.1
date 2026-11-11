# Plan — Toolkit V5.1 UI update

**Status:** Desktop 0.3.4 is published. The main workspace, command runner, Repair Kit actions and interactive terminal input stay inside one app window.

## User direction

- Preserve the Toolkit's working command behavior and existing safety prompts.
- Make the interface easier to read.
- Use one large main desktop panel on the left, about three fifths of the width.
- Use two stacked panels in the right two fifths: the command runner above, with a lower tab area for Repair Kit actions or terminal output, findings and history.
- Provide a rotate control for a taller arrangement: the main panel across the top and the runner/output panels side by side below.
- Keep command execution, terminal prompts and Repair Kit activity inside the same app window; do not open a separate console for desktop-run commands.
- Keep the layout fitted to the available screen and let the user resize the panels.

## Source and constraints

- Repository: `https://github.com/cammaxwel-droid/Toolkit-v5.1`
- Local clone: `C:\Users\cam2t\Documents\SOURCE\GitHub\Toolkit-v5.1-UI-BUFF`
- Final source: `main` at `91de4ee644c0d3ed9bf957292d0167f0790867d3`.
- Desktop source: `Toolkit-V5.1-GitHub\Toolkit-Desktop\` (WPF/.NET 10).
- Original Toolkit source: `Toolkit-V5.1-GitHub\Toolkit-V5.1\`.
- Preserve all 180 main IDs, all 51 Repair Kit IDs, original scripts, launchers, report behavior and confirmation gates.
- Browsing, searching and copying stay non-executing. Repairs remain individually selected and retain the original confirmation flow.
- Do not include user reports, logs, machine details, or build caches in public artifacts.

## Implemented candidate

- Increased text size and contrast in navigation, command details, prompts, output, findings and tabs.
- Reworked the window into a 3:2 main workspace and right-side runner/output stack.
- Added a Repair Kit tab with six category filters and all 51 selectable actions; selecting an action feeds the shared guarded runner.
- Added `Rotate Layout`; in the alternate arrangement the main screen spans the top and the runner/output panels sit side by side below.
- Enlarged and fit the startup window to the available work area while preserving the smaller resize minimum.
- Added landscape and rotated preview images under `docs\images\`.
- Routed all 231 command workers through the same in-app output/input surface; replaced the 13 separate console windows with in-window terminal input while retaining the original Toolkit scripts.

## Verification evidence

- `Build-Desktop.ps1 -Verify`: 350 checks passed.
- Coverage includes all 231 commands, all Repair Kit categories, selection into the shared runner, prompt layout at compact size, both arrangements, 150% rendering, startup bounds and no binding warnings.
- The checks use fixtures and off-screen WPF renders. They did not run Toolkit diagnostics, repairs, installers or real machine operations.
- Elevated production-worker routing was reported as not run; manual UAC and Cam's own display/scaling acceptance remain unverified.

## Release record

- PR #12 merged the single-window terminal change into `main`.
- Desktop 0.3.4 published at https://github.com/cammaxwel-droid/Toolkit-v5.1/releases/tag/desktop-v0.3.4.
- The 350 automated checks passed; real diagnostics, repairs, installers and live WinGet prompts were not executed.
- The original Toolkit tree and console ZIP remain unchanged.

## Acceptance

- The main panel, command runner, Repair Kit and output match the requested three-panel arrangement in both orientations.
- All 231 actions remain connected, and the Repair Kit picker exposes all 51 actions across six categories.
- Search, details, output, prompts and explicit confirmations remain legible and functional.
- The packaged release matches the reviewed source and contains no generated caches or private reports.
