# Windows 11 Toolkit release history

## V5.1 — Diagnostic Accuracy & Event Details
- More robust Explorer Event ID 1000 detection (structured payload + text, seven days).
- More honest log-retention caveat for cleared / rotated event logs.
- System and Application event summaries now group provider + Event ID and show last-occurrence and since-boot context.
- Deep Diagnostics exports private detailed event-log TXT files, including underlying event data where messages are blank.
- SFC /verifyonly output is saved to a separate report and ambiguous output remains NO DATA (not false PASS).
- 180 menu actions, guided opt-in repairs, administrator launch and V4 utilities preserved.
- No changes to Insider Program enrollment or Windows security settings.

# Changelog

## V5 — consolidated diagnostic and repair release

- Major version bump from V4 to reflect a new workflow-based design.
- **Four home-screen workflows**: A General Diagnostics, B Deep Diagnostics, C General Repair, D Deep Repair.
- Added category **15** with tools **171–180**; main menu now has **180** actions, plus 51-action integrated legacy Repair Kit.
- New checks return **PASS/WARNING/ERROR/NO DATA**, with details of what was checked; TXT + JSON reports exported under `Documents\Windows11-ToolkitV5-Reports`.
- New guided repairs first run fresh diagnostics, then offer only contextually relevant individual actions. No blanket invasive fixes.
- Deep diagnosis can optionally run non-repair DISM/SFC integrity scans; Deep Repair is only offered if findings support it, with additional confirmation.
- Updated common V4 menu wrapper and integrated Repair Kit to explain when a legacy tool returns no pipeline output; repaired firmware/Explorer-crash check to avoid blank screens.
- V5 repair history logs individual attempted actions and outcomes distinctly from older V4 invocation history.
- **Preserved Administrator-required launcher** and updated README to accurately document it.
- Preserved original V4 security scans, app installer, experience profiles, project/backup comparisons, Developer Doctor, harmless tricks and advanced tool menus.
- No changes to Windows Insider enrollment, device firmware, TPM, Secure Boot, antivirus/firewall protection or actual user profile paths.

## V4 and earlier

See V4's original features and preserved legacy modules and documentation. The V4 source is retained in the previous V4 ZIP, not overwritten by V5.
