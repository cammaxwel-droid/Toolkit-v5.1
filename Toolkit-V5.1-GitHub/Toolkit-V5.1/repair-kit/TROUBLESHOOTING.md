# Quick Troubleshooting Playbook

These are **symptom-based sequences**. Choose individual actions; don't run them all automatically.

| Problem | Check first | Consider only if needed |
|---|---|---|
| Windows files corrupt or update installation errors | R01, R02, R03, R06 | R04 (DISM then SFC) |
| Taskbar or desktop frozen | R12 (crash history), R11 (Task Manager) | R09 (restart Explorer/taskbar) |
| Display is black/flickering | R15 (dxdiag/driver), R16 (display Settings) | Win+Ctrl+Shift+B *manually* |
| Settings/Store app won't open or install | R14 (repair UI), R07 (errors) | R13 (Store cache reset) |
| Sound stops working | R17 (audio status) | R18 (restart Windows Audio) |
| Printer queue appears stuck | R47 (spooler status) | R48 (restart spooler) |
| Defender seems outdated | R19, R26 | R22 (signatures) / R21 (quick scan) |
| Download is truncated | R27, R28, R29, R39, R40 | R31 DNS cache flush; R32 Winsock reset only when relevant |
| Device Manager shows a warning | R34 | Official vendor support + Windows Optional updates R36 |
| Drive errors | R37 (health), R38 (C: scan) | Seek backup/vendor repair guidance; no automatic destructive repair |
| App updates | R41 WinGet scan | R42 app upgrades after reviewing |
| Windows update stalls | R06 pending reboot, R07 errors, R43 troubleshooting | R44 log export, use Microsoft troubleshooters |

**Use DISM/SFC only after scans indicate corruption.** Some actions may require network access or a restart. Close ongoing installations before starting repairs.

**For a laptop using phone hotspot:** `netsh wlan show interfaces` measures the **Wi-Fi link to the phone**, not mobile signal strength or actual download speed. A successful ping does not prove a large HTTPS download will finish.

**For an intentionally disabled laptop camera:** an `Unknown` or `CM_PROB_PHANTOM` device entry after BIOS disable is expected and is not, by itself, a fault to repair.

**For multiple Python/Node/.NET versions:** existing runtimes and Visual Studio components are not errors just because newer versions exist. They may be required by individual projects.
