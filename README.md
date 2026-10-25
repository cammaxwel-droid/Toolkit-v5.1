# Toolkit V5.1

A menu-driven **Windows 11 troubleshooting, diagnostics and repair toolkit** built with Windows PowerShell 5.1.

- 180 actions across 15 categories, plus a 51-action Repair Kit.
- Four guided workflows: General Diagnostics, Deep Diagnostics, General Repair and Deep Repair.
- Diagnostics are **read-only** and save a TXT and JSON report.
- Repairs are never automatic: you pick one action and confirm it by typing `YES`.
- No bundled executables, no API keys, and no Windows Insider changes.

## Quick start

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
