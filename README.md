# Toolkit V5.1

A menu-driven **Windows 11 troubleshooting, diagnostics and repair toolkit** built with Windows PowerShell 5.1.

- 180 actions across 15 categories, plus a 51-action Repair Kit.
- Four guided workflows: General Diagnostics, Deep Diagnostics, General Repair and Deep Repair.
- Diagnostics are **read-only** and save a TXT and JSON report.
- Repairs are never automatic: you pick one action and confirm it by typing `YES`.
- The original console package contains no bundled executables. The optional desktop package includes a compiled WPF app that runs the same Toolkit scripts.
- No API keys and no Windows Insider changes.

## Choose how to open Toolkit

| Version | Download or source | Requirements |
| --- | --- | --- |
| Original command-prompt Toolkit V5.1 | [Original Toolkit ZIP](Toolkit-V5.1-GitHub.zip) | Windows 11 and Windows PowerShell 5.1 |
| Toolkit Desktop 0.3.2 | [Desktop releases](https://github.com/cammaxwel-droid/Toolkit-v5.1/releases) · [Desktop source](Toolkit-V5.1-GitHub/Toolkit-Desktop/) | Windows 11 x64 and [.NET 10 Windows Desktop Runtime, x64](https://dotnet.microsoft.com/en-us/download/dotnet/10.0) |

The first desktop release is being prepared as a draft. Its tested ZIP will include the matching, unchanged Toolkit V5.1 and both launch methods. Until that release is published, the desktop can be built from source using the instructions below. The original Toolkit download remains available.

For a published desktop package, extract the whole ZIP and open `Start-Toolkit-Desktop.cmd`. Keep `Toolkit-Desktop` and `Toolkit-V5.1` together. To use the console instead, open `Toolkit-V5.1/Start-Toolkit.cmd` as administrator.

The desktop connects all 180 main commands and 51 Repair Kit commands, including the four existing guided workflows. The original questions and confirmations remain in place; 13 commands retain a console for native input or menus. Read the [desktop instructions and testing limits](Toolkit-V5.1-GitHub/Toolkit-Desktop/README.md) before using it.

## Build the desktop from source

Install the .NET 10 SDK, then run in Windows PowerShell from the repository root:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Toolkit-V5.1-GitHub\Toolkit-Desktop\Build-Desktop.ps1 -Verify
```

Then open `Toolkit-V5.1-GitHub/Start-Toolkit-Desktop.cmd`. The build reads the existing Toolkit source to generate its command catalog; it does not modify the original Toolkit. Automated checks use disposable fixtures and off-screen WPF rendering, not real repairs or installers.

## Original Toolkit quick start

1. Download `Toolkit-V5.1-GitHub.zip` from this repository (open the file, then click **Download**).
2. Right-click the zip → **Properties** → tick **Unblock** if it appears → **OK**.
3. Extract it into its own folder. Do not run it from inside the zip.
4. Open the `Toolkit-V5.1` folder, right-click `Start-Toolkit.cmd` and choose **Run as administrator**.
5. Press `A` for General Diagnostics to get started.

## Verify your download

In PowerShell, in the folder containing the zip:

```powershell
Get-FileHash .\Toolkit-V5.1-GitHub.zip -Algorithm SHA256
```

Compare the result with `Toolkit-V5.1-GitHub.zip.sha256` in this repository.

## Privacy

Reports are saved to `Documents\Toolkit-Reports` on your PC. They can contain usernames, local paths and hardware or network details. **Review and redact them before sharing anywhere**, including GitHub issues.

## Documentation

The full package lives in [`Toolkit-V5.1-GitHub/Toolkit-V5.1/`](Toolkit-V5.1-GitHub/Toolkit-V5.1/):

- [Full README](Toolkit-V5.1-GitHub/Toolkit-V5.1/README.md): features, categories and safety limits
- [Guided workflows](Toolkit-V5.1-GitHub/Toolkit-V5.1/docs/Guided-Workflows.md)
- [Testing checklist](Toolkit-V5.1-GitHub/Toolkit-V5.1/TESTING.md)
- [Changelog](Toolkit-V5.1-GitHub/Toolkit-V5.1/CHANGELOG.md)

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). Please report vulnerabilities privately, not in public issues.

## Disclaimer

Use at your own risk. Read what an action does before confirming any change, and keep a backup of important data. Not affiliated with Microsoft.

## License

[MIT](LICENSE)
