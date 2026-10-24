# Experience profiles — simple and reversible

Use the **Preview** option before **Apply**. Admin rights are already provided when you open the Toolkit launcher as Administrator.

| Profile | Automatic setting change, only when available | Opens for you to configure |
|---|---|---|
| Gaming | Existing **High Performance** Windows power plan | Game Mode, per-app graphics, notifications |
| Programming | Existing **Balanced** power plan | Developer options, Startup apps |
| Studying | Existing **Balanced** power plan | Notifications, Night light, screen & sleep |
| Battery Saver | Existing **Power saver** plan | Windows Power & battery settings |

## How the layers work

1. **Preview (READ):** Shows what would be proposed. Does not write settings or change power plan.
2. **Apply (CHANGE):** Prompts for `YES` and changes only the active power plan if the requested scheme already exists. Saves the **original** scheme before the first change.
3. **Manual extras:** Opens relevant Windows Settings pages; you make any other selections yourself. The kit does **not** automatically disable notifications, alter registry performance tweaks, disable security, terminate processes, or install drivers.
4. **Undo:** Restores the saved original power plan and clears the toolkit's undo record. It does **not** reverse manual Windows Settings changes you made afterward.

New undo records are saved under `%LOCALAPPDATA%\Toolkit\PowerPlan-Undo.json`. Existing records are reused in place; conflicting or unreadable records stop profile changes. See [Rename compatibility](Rename-Compatibility.md). Read it with **Show current plan/profile**; the toolkit creates it only when it successfully prepares to switch schemes. If no compatible target plan is installed on your laptop, the kit leaves the power plan unchanged and opens the settings pages.

**Note:** High Performance can increase heat, fan noise and power use without increasing RAM capacity or dramatically improving performance. Keep Balanced for normal tasks if that suits your ThinkPad.
