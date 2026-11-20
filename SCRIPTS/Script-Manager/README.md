# Script-Manager

Script-Manager helps you find, group, and launch MaxScript tools in Autodesk 3ds Max. Use it to load related tool rollouts into a shared dialog, run tools in their own windows, and save reusable setups.

## Script loading checkbox

The checkbox beside a script in **SCRIPTS** stores its mode for **LOAD SCRIPTS**.

| Checkbox state | Loading behavior |
| --- | --- |
| Unchecked (`false`) | Skip the script. |
| Checked (`true`) | Load the script and show its rollouts in the shared group dialog. |
| Indeterminate (`–`) | Run the script standalone. |

Parent folders display a mixed checkbox when only some descendant scripts are active; SOURCES parents display mixed when descendants are enabled but the parent itself is not. Ctrl-click toggles selected rows, Shift-click selects a visible range, and Ctrl+Shift-click adds a range. Selection does not alter checkbox settings. Click the checkbox to change the saved mode. Click **LOAD SCRIPTS** to start configured scripts that are currently closed. Right-click it to reload every configured script in the current load set.

## Get started

1. In 3ds Max, choose **Scripting → Run Script** and open [Script-Manager.ms](Script-Manager.ms).
2. In **OPTIONS → ROOT PATH**, use **BROWSE** to choose your scripts folder. If you type a path, left-click **REFRESH / RESTART** to apply it.
3. In **SOURCES**, check the folders to scan. Their scripts appear in **SCRIPTS**.
4. Set the script checkboxes, then click **LOAD SCRIPTS**.

## Run and organize tools

- Double-click an `.ms` or `.mcr` filename, or right-click a script and choose **LOAD SCRIPT**, to run it standalone. Its saved checkbox mode stays in place.
- Right-click a folder in **SCRIPTS** and choose **OPEN GROUP** to load all visible scripts beneath it into one shared dialog, including scripts marked unchecked or standalone. Their saved modes stay in place.
- Use **EXPAND ENABLED** to find configured scripts or **OPEN IN EXPLORER** to locate a script or folder on disk.
- **GROUP MANAGER UI** is maintained in [`Script-Manager-Group-Loader-UI.ms`](Script-Manager-Group-Loader-UI.ms). The dialog is vertically resizable; both listboxes expand while the width stays locked. The main Script-Manager dialog and GROUP MANAGER show the active loaded version in their titles and top action buttons.
- Right-click any item in **SCRIPTS** → **ADD TO TOOLBAR** → **GROUP MANAGER** (first submenu item) to open a separate dialog with **USER GROUPS** and **CUSTOM TOOLBARS**. Only explicitly saved named groups appear in USER GROUPS; ordinary folders never create groups automatically.
- Right-click a script in **SCRIPTS** → **ADD TO GROUP** → **GROUP MANAGER** to open the manager, or select a user group to add the script, or choose **NEW GROUP** to create a group containing that script. Group membership is saved to `script_manager.ini`; an existing toolbar button for the group loads the updated membership the next time it runs. Duplicate entries are ignored.
- Click **NEW GROUP** to create a named group (optionally from the currently selected SCRIPTS script/folder). Select a user group and use **ADD TREE SELECTION** to add scripts or a folder across the hierarchy. Folders are saved as dynamic references and expanded to their eligible scripts at load time; new scripts inside them are included automatically. **DELETE GROUP** removes only the saved group definition, not files.
- Toolbars renamed in native **Customize User Interface → Toolbars → Rename** appear under their new names when GROUP MANAGER or ADD TO TOOLBAR refreshes. Their existing MacroScript buttons are resolved by stable action IDs rather than the toolbar name. Each GROUP MANAGER or ADD TO TOOLBAR refresh saves the live native state to the active CUIX before reading names, so successive native renames are reflected.
- To create a toolbar, use **NEW TOOLBAR** at the bottom of SCRIPTS → **ADD TO TOOLBAR** (after the separator) to start with that script. The **NEW TOOLBAR** button in GROUP MANAGER starts with the selected user group, or a Script-Manager launcher when no group is selected. To add a named group to an existing toolbar, select a **USER GROUP** and a **CUSTOM TOOLBAR**, then click **ADD SELECTED GROUP TO TOOLBAR**. Each group becomes one toolbar button; several group buttons can share the same toolbar. Clicking a group button loads all current group scripts into one shared host dialog. Updates to a group take effect on the next button click without rebuilding the toolbar.
- Select a user group or Toolbar-Creator toolbar, then double-click or press its LOAD button to open its scripts together in one dialog. The toolbar's script order is preserved across folders. The selected source, script count and invalid/missing paths are previewed before loading; REFRESH preserves the selection when it still exists. Saved script modes and toolbar membership stay unchanged. ADD TREE SELECTION accepts multiple highlighted SCRIPTS rows.

- Left-click **REFRESH / RESTART** to rescan sources and apply pending options. Right-click it to restart Script-Manager.

## Find scripts

- **SCRIPTS → FILTER** searches filenames and folder names as you type. Clear it before a batch load if you want the full list.
- **OPTIONS → SHOW → VERSIONED FILES** shows every script version. With it off, Script-Manager shows the unversioned file or the newest version when there is no unversioned file.
- **OPTIONS → SHOW → CLEAN SCRIPTS** controls listing. Unchecked uses normal visibility. Checked shows only unversioned scripts that match their folder names. Indeterminate also shows eligible scripts in folders with no matching script. Checked and indeterminate take priority over **VERSIONED FILES**.
- **OPTIONS → SHOW → COLLAPSE DIRS** hides redundant single-script folder rows. All three SHOW checkboxes are on one row.
- **OPTIONS → IGNORE** hides matching files or folder branches. Separate names or wildcard patterns with `|`, then left-click **REFRESH / RESTART** to apply.

## Presets, startup, and toolbars

- **PRESETS** saves your selected source folders and script loading modes. Choose a preset and click **LOAD** to apply it. Use **MACRO** to create a toolbar action for it or **STARTUP** to load it when 3ds Max opens.
- Right-click an individual script and use the final context-menu item to add or remove it from the 3ds Max startup scripts.
- **CREATE TOOLBAR** builds a native 3ds Max toolbar from configured scripts. **SAVE UI** controls whether the toolbar is saved to your active UI configuration.

Loaded script dialogs use wider script-rollout slots (32 px extra, shifted 16 px left). Hosted rollout headings use **——— Script Title ———** and omit a trailing numeric `| vX.Y` suffix. This applies to hosted rollouts only; source scripts and independent dialogs are not modified.

Settings are saved in `script_manager.ini` beside the manager.

[Changelog](changes.md)
