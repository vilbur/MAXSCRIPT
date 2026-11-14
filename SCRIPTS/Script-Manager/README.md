# Script-Manager

Script-Manager helps you find, group, and launch MaxScript tools in Autodesk 3ds Max. Use it to load related tool rollouts into a shared dialog, run tools in their own windows, and save reusable setups.

## Script loading checkbox

The checkbox beside a script in **SCRIPTS** stores its mode for **LOAD SCRIPTS**.

| Checkbox state | Loading behavior |
| --- | --- |
| Unchecked (`false`) | Skip the script. |
| Checked (`true`) | Load the script and show its rollouts in the shared group dialog. |
| Indeterminate (`–`) | Run the script standalone. |

Click the checkbox to change the saved mode. Click **LOAD SCRIPTS** to start configured scripts that are currently closed. Right-click it to reload every configured script in the current load set.

## Get started

1. In 3ds Max, choose **Scripting → Run Script** and open [Script-Manager.ms](Script-Manager.ms).
2. In **OPTIONS → ROOT PATH**, use **BROWSE** to choose your scripts folder. If you type a path, left-click **REFRESH / RESTART** to apply it.
3. In **SOURCES**, check the folders to scan. Their scripts appear in **SCRIPTS**.
4. Set the script checkboxes, then click **LOAD SCRIPTS**.

## Run and organize tools

- Double-click an `.ms` or `.mcr` filename, or right-click a script and choose **LOAD SCRIPT**, to run it standalone. Its saved checkbox mode stays in place.
- Right-click a folder in **SCRIPTS** and choose **OPEN GROUP** to load all visible scripts beneath it into one shared dialog, including scripts marked unchecked or standalone. Their saved modes stay in place.
- Use **EXPAND ENABLED** to find configured scripts or **OPEN IN EXPLORER** to locate a script or folder on disk.
- Left-click **REFRESH / RESTART** to rescan sources and apply pending options. Right-click it to restart Script-Manager.

## Find scripts

- **SCRIPTS → FILTER** searches filenames and folder names as you type. Clear it before a batch load if you want the full list.
- **OPTIONS → SHOW → VERSIONED FILES** shows every script version. With it off, Script-Manager shows the unversioned file or the newest version when there is no unversioned file.
- **OPTIONS → SHOW → CLEAN SCRIPTS** controls listing. Unchecked uses normal visibility. Checked shows only unversioned scripts that match their folder names. Indeterminate also shows eligible scripts in folders with no matching script. Checked and indeterminate take priority over **VERSIONED FILES**.
- **OPTIONS → SHOW → COLLAPSE DIRS** hides redundant single-script folder rows.
- **OPTIONS → IGNORE** hides matching files or folder branches. Separate names or wildcard patterns with `|`, then left-click **REFRESH / RESTART** to apply.

## Presets, startup, and toolbars

- **PRESETS** saves your selected source folders and script loading modes. Choose a preset and click **LOAD** to apply it. Use **MACRO** to create a toolbar action for it or **STARTUP** to load it when 3ds Max opens.
- Right-click an individual script to add or remove it from the 3ds Max startup scripts.
- **CREATE TOOLBAR** builds a native 3ds Max toolbar from configured scripts. **SAVE UI** controls whether the toolbar is saved to your active UI configuration.

Settings are saved in `script_manager.ini` beside the manager.

[Changelog](changes.md)
