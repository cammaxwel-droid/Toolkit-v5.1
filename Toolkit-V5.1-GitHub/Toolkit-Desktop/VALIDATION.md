# Desktop 0.3.3 release validation

Checked on Windows 11, 12 November 2026, using .NET SDK 10.0.403 and Windows PowerShell 5.1.

## Build and automated checks

- The original Toolkit source tree, tracked archive and checksum are unchanged by this desktop-only update.
- `Build-Desktop.ps1 -Verify` completed successfully after the layout and readability changes: **348 checks passed**.
- All **231 command IDs** were checked through the desktop dispatcher with a fake process transport: 180 main commands and 51 Repair Kit commands. The original command ID and source path are retained without supplying `-ElevatedCall`.
- Harmless Windows PowerShell fixtures checked stdout/stderr, literal prompt answers, Unicode, blank and case-sensitive responses, cancellation and paths containing spaces. They did not execute real Toolkit operations.
- Native WPF checks covered the 3:2 main-to-side-panel layout, the stacked right runner/output arrangement, the rotated layout with the main screen above two side-by-side panels, Repair Kit category filtering and selection, search and Run bindings, prompt input, history, startup window bounds before Show, both native window icons, compact output space and 150% rendering. No WPF binding warnings were reported. Test windows were not shown.
- The original static check passed: **14 PowerShell scripts, zero syntax failures, 180 unique main IDs and 51 unique Repair Kit IDs**.
- Desktop PowerShell scripts also passed the Windows PowerShell 5.1 parser checks.

## Explicit limits

The release verification process was not elevated. The suite explicitly reported **production-worker routing against disposable stub scripts as NOT RUN**, because that additional test requires an Administrator process.

The automated checks do not establish that every real command, native console, repair or installer works on every machine. No actual Toolkit diagnostic, repair or installer was executed for release preparation. A returned process is not evidence that a repair succeeded. UI readability was checked in off-screen renders; manual inspection on Cam's display and scaling remains unverified.

The app requires Windows 11 x64 and the .NET 10 Windows Desktop Runtime for x64. It requests Administrator access through the existing desktop manifest. Actual UAC interaction and machine-specific command results remain manual runtime checks.

## Packaging

The desktop package contains the compiled app, supplied icon, matching unchanged Toolkit, repair kit, documents and both launch methods. The separate console package contains the original Toolkit. Source and tests remain available in the repository; development caches, local reports and private test artifacts are excluded from downloads.

Each package has a file checksum manifest. The release also includes `SHA256SUMS.txt` for the two ZIP downloads. Packaging verification checks the extracted files, original Toolkit hashes, command catalog source hashes, launcher paths and desktop runtime dependencies.

## Reproduce the checks

From this folder, with the .NET 10 SDK installed:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Build-Desktop.ps1 -Verify
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ..\Toolkit-V5.1\tests\Check-PowerShell-Syntax.ps1
```

Build output and rendered previews are generated locally and excluded from Git. See the original Toolkit's `TESTING.md` for runtime testing boundaries. Run only individually selected operations and review their existing output and confirmations.
