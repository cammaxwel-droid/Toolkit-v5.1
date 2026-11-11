# Plan — Toolkit V5.1 UI update

**Status:** The three-panel candidate is implemented locally and passed the documented automated checks. Packaging and the public 0.3.3 release are still pending.

## User direction

- Preserve the Toolkit's working command behavior and existing safety prompts.
- Make the interface easier to read.
- Use one large main desktop panel on the left, about three fifths of the width.
- Use two stacked panels in the right two fifths: the command runner above, with a lower tab area for Repair Kit actions or terminal output, findings and history.
- Provide a rotate control for a taller arrangement: the main panel across the top and the runner/output panels side by side below.
- Keep the layout fitted to the available screen and let the user resize the panels.

## Source and constraints

- Repository: `https://github.com/cammaxwel-droid/Toolkit-v5.1`
- Local clone: `C:\Users\cam2t\Documents\SOURCE\GitHub\Toolkit-v5.1-UI-BUFF`
- Source base: `main` at `12ca1a93ef0c74f3ab4af4385efce312aea34d66`.
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

## Verification evidence

- `Build-Desktop.ps1 -Verify`: 348 checks passed.
- Coverage includes all 231 commands, all Repair Kit categories, selection into the shared runner, prompt layout at compact size, both arrangements, 150% rendering, startup bounds and no binding warnings.
- The checks use fixtures and off-screen WPF renders. They did not run Toolkit diagnostics, repairs, installers or real machine operations.
- Elevated production-worker routing was reported as not run; manual UAC and Cam's own display/scaling acceptance remain unverified.

## Remaining release steps

1. Inspect the final source and docs diff; confirm the original Toolkit tree is unchanged and the old tracked archive/checksum remain untouched.
2. Build the portable Desktop 0.3.3 package with the unchanged Toolkit, both launch methods and current README/validation files.
3. Verify package contents and SHA-256 manifests; exclude staging, caches and this planning file from the download.
4. Publish the updated source and Desktop 0.3.3 release with notes that state automated checks and manual limits accurately.

## Acceptance

- The main panel, command runner, Repair Kit and output match the requested three-panel arrangement in both orientations.
- All 231 actions remain connected, and the Repair Kit picker exposes all 51 actions across six categories.
- Search, details, output, prompts and explicit confirmations remain legible and functional.
- The packaged release matches the reviewed source and contains no generated caches or private reports.
