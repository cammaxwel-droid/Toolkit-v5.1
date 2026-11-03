# Toolkit V5.1 Desktop — all existing commands connected

The separate WPF desktop app provides access to the original Toolkit: **001–180 and R01–R51**, including its four existing guided workflows. The `Toolkit-V5.1` folder and its original CMD launchers are preserved.

## Open it

Download the [Desktop 0.3.2 ZIP](https://github.com/cammaxwel-droid/Toolkit-v5.1/releases/download/desktop-v0.3.2/Toolkit-Desktop-0.3.2-Windows-x64.zip) and extract it completely. This is a published full release; [release notes](https://github.com/cammaxwel-droid/Toolkit-v5.1/releases/tag/desktop-v0.3.2) describe the checks and remaining runtime limits. The package targets Windows 11 x64 and requires the [.NET 10 Windows Desktop Runtime for x64](https://dotnet.microsoft.com/en-us/download/dotnet/10.0), installed separately. The SDK is only needed to build the source.

Double-click `app\Toolkit.Desktop.exe`, or `Start-Toolkit-Desktop.cmd` in the parent folder. Approve the Windows Administrator prompt. Keep `Toolkit-Desktop` beside `Toolkit-V5.1`; the pair can be moved together. The original console remains available at `Toolkit-V5.1\Start-Toolkit.cmd` (Run as administrator).

The app opens at its minimum size (1000 × 680, or smaller when display scaling leaves less usable screen space), with space above the title bar. Its position is fitted before the window is shown. You can resize it afterward.

The executable and app window use the supplied `Toolkit_Amber_Thin_Rounded_Glow.ico`, preserving all ten sizes. A copy is kept in `Assets`; the original icon is unchanged.

Search by name or ID. Short IDs such as `3`, `R1` and workflow aliases `A`–`D` work. Ctrl+F focuses search; arrows select a result; Enter in search focuses Run; Escape clears search. Browsing and copying do not execute commands.

## Running commands

Select a command, review its description, then select **Run**. One command runs at a time.

- **218 commands** use the desktop output area. When the Toolkit asks a question, its exact question appears below the output. Type your answer and select **Send answer** or press Enter. Sending an empty box supplies the Toolkit's normal blank answer.
- **13 commands** retain a console: 018, 019, 020, 050, 116, 121, 131, 146, 149, 158, 166, R41 and R42. These cover WinGet/native input, the full Repair Kit menu, and the terminal animation. Answer in that window. When the command returns, press Enter to close it and return to the desktop. For the Repair Kit menu, Q exits the menu first.
- Existing YES, SCAN, INSTALL and DEEP REPAIR gates remain in the original scripts. The desktop does not preapprove or automatically answer them.
- Commands that open Windows settings, native tools, reports or source documents use the original paths and applications.
- A returned process is not proof that a repair succeeded. Read the original messages and check the result yourself.

The accepted layout and Base44 styling are retained. The only additional control is the answer box when an existing command needs input.

## Results

Output and up to 50 history entries remain available for the session. Findings for 171–175 show the original diagnostic statuses and TXT/JSON report pair. For 173/174 these are the diagnostics used by the repair workflow, not proof of a successful repair.

Other report paths remain in the original command output. Commands 120 and 178 open the existing report locations, including their original location-choice question when applicable. Reports remain where the Toolkit puts them, normally Documents\Toolkit-Reports.

Console transcripts are private desktop records in `%LOCALAPPDATA%\ToolkitDesktop\Console`. They are displayed after the console closes and are not copied into the source or distributed app. Native program output may not all appear in a PowerShell transcript; review the console itself before closing it.

**Stop check** remains available for 052, 171 and 175 only. It stops their worker and marks the result incomplete. Repairs, installers and other operations are allowed to finish. Closing the desktop is deferred while a command is active.

## Build and verify

```powershell
.\Build-Desktop.ps1 -Verify
```

Requires the .NET 10 SDK. No third-party NuGet packages are used. The catalog generator parses the actual source definitions without executing them and records hashes of the original PowerShell files. Changed original source requires rebuilding the desktop catalog.

The worker calls either `src\Toolkit.ps1 -ToolId` or `repair-kit\src\RepairKit.ps1 -ToolId`. It never supplies `-ElevatedCall`. The desktop answer adapter exists only inside that temporary worker and transports literal text, without editing the original scripts.

The tests use fake process results, disposable PowerShell fixtures and off-screen native WPF rendering. They do not run the real repairs, installers or diagnostics. Production-worker routing against disposable stub scripts is additionally checked when the test process is elevated; a normal test run explicitly reports that check as not run. See [VALIDATION.md](VALIDATION.md) for the release checks and remaining runtime limits. Local test renders are generated in `artifacts`; they are excluded from source control.

## Current stage

Desktop 0.3.2 includes all command connections, the corrected initial window size and position, and the supplied app icon. The release is a portable ZIP with the original Toolkit included. No installer or uninstaller is provided, and no Start menu or desktop shortcut is created automatically. The download excludes development build caches and local test output; source and tests remain in the repository.

The original Toolkit scripts, repair kit, documents and launchers are preserved. The desktop is a second way to access their existing behavior. Automated checks do not establish that every command or repair has been manually verified on a real machine.
