# Toolbar-Creator

Standalone MaxScript tool for collecting scripts from folders/files and creating, updating, or deleting named 3ds Max toolbars.

## Files

- `Toolbar-Creator.ms` — canonical launcher; running it opens the UI.
- `Toolbar-Creator-FN.ms` — independent backend defining `manageScriptToolbar()`, `collectToolbarScripts()`, `listManagedScriptToolbars()`, and `getManagedScriptToolbarButtons()`; loading it does not open the UI.
- `Toolbar-Creator-UI.ms` — guarded UI entry point: focuses the existing dialog when already running and opens it only when closed.
- `Toolbar-Creator-UI-Core.ms` — separate dark dialog implementation with recursive folder browsing, multi-file selection, managed-toolbar list, and button editing; load only through the guarded entry point.
- `Versions/Toolbar-Creator_0.01.ms` — initial versioned release.
- `Versions/Toolbar-Creator_0.02.ms` — recursive scanning and initial dialog release.
- `Versions/Toolbar-Creator_0.03.ms` — backend helper-scope repair.
- `Versions/Toolbar-Creator_0.04.ms` — corrected public API examples (named `button_data:` argument).
- `Versions/Toolbar-Creator_0.05.ms` — native CUI success-return normalization (project 0.08).
- `Versions/Toolbar-Creator_0.06.ms` — indexed .NET XML child lookup (project 0.10).
- `Versions/Toolbar-Creator_0.07.ms` — historic backend managed-toolbar listing (project 0.11); preserved under its original filename.
- `Versions/Toolbar-Creator-FN_0.08.ms` — current independent backend, renamed from `Toolbar-Creator.ms` (project 0.12).
- `Versions/Toolbar-Creator-FN_0.09.ms` — portable `$userScripts` paths for discovery, validation, and generated MacroScripts (project 0.15).
- `Versions/Toolbar-Creator-FN_0.10.ms` — read-only reconstruction of saved managed-toolbar buttons from CUIX and generated MacroScripts (project 0.20).
- `Versions/Toolbar-Creator-FN_0.11.ms` — readable default labels/tooltips by replacing filename dashes and underscores with spaces (project 0.21).
- `Versions/Toolbar-Creator-FN_0.12.ms` — managed-toolbar rename with replacement rollback if removal fails (project 0.23).
- `Versions/Toolbar-Creator-FN_0.16.ms` — resolve name/objectName divergence after native Customize rename while retaining the original .mcr (project 0.32).
- `Versions/Toolbar-Creator-Launcher_0.01.ms` — current startup launcher (project 0.12); distinct name avoids colliding with historical backend releases.
- `Versions/Toolbar-Creator-UI_0.02.ms` — dialog version with user-scripts browse defaults (project 0.04).
- `Versions/Toolbar-Creator-UI_0.03.ms` — dark list and multi-file selection fix (project 0.05).
- `Versions/Toolbar-Creator-UI_0.04.ms` — rollout helper definition-order fix (project 0.06).
- `Versions/Toolbar-Creator-UI_0.05.ms` — correctly calls the backend using `button_data:` (project 0.07).
- `Versions/Toolbar-Creator-UI_0.06.ms` — project 0.08 release with the backend CUI result fix and unchanged dark dialog.
- `Versions/Toolbar-Creator-UI_0.07.ms` — defers title-button restart to prevent destroying the dialog from its own .NET click event (project 0.09).
- `Versions/Toolbar-Creator-UI_0.08.ms` — project 0.10 dialog release with unchanged dark styling.
- `Versions/Toolbar-Creator-UI_0.09.ms` — side-by-side script and managed-toolbar lists (project 0.11).
- `Versions/Toolbar-Creator-UI_0.10.ms` — updated backend load path for the canonical launcher (project 0.12).
- `Versions/Toolbar-Creator-UI_0.11.ms` — left Managed Toolbars column and right Toolbar Config column (project 0.13).
- `Versions/Toolbar-Creator-UI_0.12.ms` — guarded single-instance UI entry, preventing a second launch from replacing an open dialog (project 0.14).
- `Versions/Toolbar-Creator-UI-Core_0.01.ms` — independent UI rollout implementation with a safe title-button data refresh (project 0.14).
- `Versions/Toolbar-Creator-UI-Core_0.02.ms` — portable script paths in the UI list and saved INI (project 0.15).
- `Versions/Toolbar-Creator-UI-Core_0.03.ms` — two-column Scripts ListView and side-by-side Button Text/Tooltip controls (project 0.16).
- `Versions/Toolbar-Creator-UI-Core_0.04.ms` — New Toolbar action beside Refresh, clearing the selected toolbar name while keeping script button records (project 0.17).
- `Versions/Toolbar-Creator-UI-Core_0.05.ms` — New Toolbar starts with an empty Scripts list and prefilled Windows username; successful Create prepares another clean draft (project 0.18).
- `Versions/Toolbar-Creator-UI-Core_0.06.ms` — safe two-stage restart when clicking the dark title button, loading the latest canonical source files from disk (project 0.19).
- `Versions/Toolbar-Creator-UI-Core_0.07.ms` — 1024 px dialog and scripts synchronized when a managed toolbar is selected (project 0.20).
- `Versions/Toolbar-Creator-UI-Core_0.08.ms` — output file tracker, taller buttons, green/orange .NET actions, Clear List confirmation and combined label-edit Update (project 0.22).
- `Versions/Toolbar-Creator-UI-Core_0.09.ms` — adds the Rename action alongside Create, Update and Delete (project 0.23).
- `Versions/Toolbar-Creator-UI-Core_0.10.ms` — single-line file log and selected-toolbar Delete target (project 0.24).
- `Versions/Toolbar-Creator-UI-Core_0.11.ms` — left-side Create/Update/Rename/Delete actions, removing duplicate New Toolbar and Refresh buttons (project 0.26).
- `Versions/Toolbar-Creator-UI-Core_0.14.ms` — Customize Toolbars button, consolidated script actions, missing-path highlighting and compact content-based layout (project 0.29).
- `Versions/Toolbar-Creator-UI-Core_0.15.ms` — start with the last selected managed toolbar's actual buttons, not cached INI draft records (project 0.30).
- `Versions/Toolbar-Creator-UI-Core_0.17.ms` — refresh native renamed names on mouse enter/click, including single-attribute CUIX renames (project 0.32).
- `Versions/Toolbar-Creator-UI-Core_0.18.ms` — synchronized live native toolbar discovery through backend v0.17 (project 0.34).
- `Versions/Toolbar-Creator-UI-Core_0.19.ms` — Rename button text uses the same orange as Delete (project 0.35).
- `Versions/Toolbar-Creator-UI-Core_0.20.ms` — startup height fitted to controls (project 0.36).
- `Versions/Toolbar-Creator-UI-Core_0.21.ms` — non-dockable floating dialog (project 0.37).
- `Toolbar-Creator-Test.ms` — executable create/update/delete integration test.
- `Versions/Toolbar-Creator-Test_0.04.ms` — integration test updated to use `button_data:`.
- `Versions/Toolbar-Creator-Test_0.05.ms` — indexed .NET child-node inspection and XML lookup regression checks.
- `Versions/Toolbar-Creator-Test_0.06.ms` — managed-toolbar identity tests using in-memory XML.
- `Versions/Toolbar-Creator-Test_0.07.ms` — integration test loads backend directly without opening the dialog.
- `Versions/Toolbar-Creator-Test_0.08.ms` — portable-path conversion, boundary and generated macro checks.
- `Versions/Toolbar-Creator-Test_0.09.ms` — generated-path parsing and saved-toolbar button reconstruction tests (project 0.20).
- `Versions/Toolbar-Creator-Test_0.10.ms` — default label/tooltip cleanup regression checks (project 0.21).
- `Versions/Toolbar-Creator-Test_0.11.ms` — rename integration coverage for preserved buttons and removal of the old toolbar/macro (project 0.23).
- `Versions/Toolbar-Creator-Test_0.12.ms` — deletion regression with a missing generated MacroScript file (project 0.24).
- `design.md` — maintained behavior and architecture contract.
- `changes.md` — concise change history.

Keep the latest unversioned entry points in the project root. Store all numbered release copies in the `Versions` subfolder.

To create a toolbar, select an existing managed toolbar and click **Create** to start a new empty draft (or click Create with an empty unselected draft). This clears the Scripts list and prefills the Toolbar name with your Windows `%USERNAME%` value. Add at least one `.ms` script and click **Create** again to save the toolbar. A successful Create prepares the next empty draft; a failed Create preserves your edits. **Update** saves changes to a selected managed toolbar and refreshes the list. With no toolbar selected, **Update** only refreshes the managed list, preserving the current draft.

## Load

Run **`Toolbar-Creator.ms`** in 3ds Max to open the dialog. It launches `Toolbar-Creator-UI.ms`, which opens `Toolbar-Creator-UI-Core.ms` only if no Toolbar-Creator dialog is already displayed. Re-running either entry file brings the existing window forward without reconstructing its controls. The UI core loads `Toolbar-Creator-FN.ms` from the same directory. Keep all four files together; opening the independent backend **does not open the dialog**. Do not launch `Toolbar-Creator-UI-Core.ms` directly.

The frontend uses the canonical shared UI framework at `G:\AI\AGENTS\Maxscript\UI\Default\`. If your synchronized Drive mount is elsewhere, set `toolbarCreatorUiFrameworkDir` to the folder containing `IniSettings.ms`, `RolloutState.ms`, `DialogHost.ms`, `ScriptReload.ms`, and `ToolTitleButton.ms` before running the UI. Settings are saved in `Toolbar-Creator-UI.ini` beside the scripts.

Evaluate `Toolbar-Creator-FN.ms` alone for the independent backend functions. It defines:

```maxscript
manageScriptToolbar operation toolbar_name button_data:#() \
    macro_category:"Toolbar-Creator" \
    save_ui:true \
    show_toolbar:true \
    macro_file_path:undefined \
    delete_macro_file:true \
    register_macros:true
```

The function returns `true` only when the complete requested operation succeeds.
The backend finds toolbar nodes by indexing `.NET XmlNodeList` elements with `ItemOf[0]`, `ItemOf[1]`, and so on; MAXScript's `for ... in` does not support the .NET `XmlChildNodes` wrapper.
Native CUI operations can return `OK` instead of a Boolean. The backend converts their results to Boolean success values before checking save, load, and show outcomes.

`listManagedScriptToolbars()` is an additional read-only backend function that returns the names of saved toolbars containing Toolbar-Creator-generated `ToolbarCreator_` MacroScript actions. It excludes built-in and unrelated custom toolbars. An empty result is an empty Array; an unreadable CUIX returns `undefined` and prints a Listener diagnostic.

`getManagedScriptToolbarButtons toolbar_name macro_file_path:undefined` reads a saved toolbar's button order, labels and tooltips from CUIX, and resolves their scripts through the generated `.mcr` file. It returns ordered `#(script_path, button_text, tooltip)` records or `undefined` with Listener diagnostics for incomplete mappings. `macro_file_path:` supports callers using a nondefault generated macro path; the UI uses the default path.

## Discover scripts from folders and files

`collectToolbarScripts()` accepts an Array of directory paths and individual `.ms` paths. It scans every subdirectory by default, removes duplicate paths, and returns records ready for `manageScriptToolbar()`. Invalid paths return `undefined` with a Listener diagnostic; valid empty folders return an empty Array.

For newly added scripts, Button Text is initialized from the filename without `.ms`. Hyphens (`-`) and underscores (`_`) become spaces, and repeated spaces are collapsed. For example, `Tank-Panel_Generator.ms` produces **Tank Panel Generator** and the default tooltip **Run Tank Panel Generator**. Existing toolbar labels, manually edited text, and actual script paths are not changed by this rule.

Paths under the current 3ds Max `getDir #userScripts` directory are shortened to the native symbolic `$userScripts` prefix. For example, if `getDir #userScripts` returns `C:\GoogleDrive\CODE\MAXSCRIPT\SCRIPTS`, then:

```text
C:\GoogleDrive\CODE\MAXSCRIPT\SCRIPTS\CODEBASE\Tool.ms
   -> $userScripts\CODEBASE\Tool.ms
```

The exact user-scripts root becomes `$userScripts`; paths elsewhere are not changed. Matching is case-insensitive and respects directory boundaries (so a sibling folder such as `SCRIPTS_Backup` is never shortened). The abbreviation appears in the Scripts list, saved `Toolbar-Creator-UI.ini`, and generated `.mcr` buttons. On execution, 3ds Max resolves `$userScripts` using the current user's configured scripts directory. The collector also accepts `$userScripts\folder` as an input directory.

```maxscript
source_paths = #(
    @"C:\Tools\MaxScripts",
    @"D:\ExtraTools\OneTool.ms"
)

toolbar_buttons = collectToolbarScripts source_paths recursive:true

if toolbar_buttons != undefined and toolbar_buttons.count > 0 then
(
    manageScriptToolbar #create "MY TOOLS" button_data:toolbar_buttons save_ui:true
)
```

The dialog offers **Add Folder**, **Add Files**, **Remove**, **Up/Down**, and editable button text/tooltip. Enter a toolbar name and press **Create** or **Update**. Label/tooltip edits are applied automatically when creating or updating the toolbar; there is no separate Apply Text button. To **Rename**, select an existing entry in Managed Toolbars, edit the Toolbar name, then click Rename and confirm; its scripts, labels and tooltips remain in order. **Clear List** asks for confirmation before discarding a nonempty draft. **Save UI** defaults to enabled, so the toolbar persists across restarts; **Show Toolbar** defaults to enabled. **Delete** asks for confirmation. Create and Update use green .NET button text; Rename and Delete use matching orange text. All ordinary buttons are 28 px tall, while the canonical title/restart button remains 20 px. Clicking the dark blue tool title saves pending edits, then schedules a safe two-stage restart: unregister and close the old dialog after its Click callback exits, then reopen through `Toolbar-Creator.ms` after confirming the old rollout is no longer displayed. This reads the newest canonical `.ms` files currently synchronized on disk, not backup versions in `Versions`. If the old dialog cannot close, the reload is cancelled instead of recreating a live rollout.

The dialog has two columns: **Managed Toolbars** on the left and **Toolbar Config** on the right. The left column shows a tall dark list of saved toolbars and a 2×2 action grid (**Create**, **Update**, **Rename**, **Delete**). The right column contains the **Toolbar** name, a dark .NET two-column **Scripts** ListView (**Button Text** | **Script Path**), and side-by-side **Button Text** and **Tooltip** edit fields. **Add Folder**, **Add Files**, **Clear List**, **Up**, **Down**, **Remove** and **Customize Toolbars** share the row above the Scripts list. **Customize Toolbars** opens the native 3ds Max Customize User Interface dialog; select its **Toolbars** tab if needed. Clicking a script row selects the corresponding record for text edits or Up/Down/Remove; LMB double-click browses for a replacement script path without changing the label or tooltip. Missing file paths appear red and remain editable for repair. On startup, the last selected Managed Toolbar is restored (or the first available toolbar is selected), and Scripts loads its actual saved buttons; old INI draft buttons are not used to populate the list. Selecting another managed toolbar loads that toolbar's scripts, labels and tooltips. A successful Create/Update/Delete refreshes the left list. Toolbars created with **Save UI** disabled may not appear, because listing reads the saved CUIX.

**Native toolbar renaming:** Rename a Toolbar-Creator toolbar in **Customize User Interface > Toolbars**. Moving the pointer back over **Managed Toolbars**, clicking that list, or refreshing the toolbar list invokes the existing backend `listManagedScriptToolbars sync_live:true`. This saves the current native UI through `cui.saveConfig()` and reads each toolbar's XML `name` attribute from the active CUIX (`objectName` is a fallback only). Toolbar-Creator identifies managed entries through their `ToolbarCreator_` action IDs, keeps the latest name when repeated native renames leave stale same-action aliases, and retains the selected toolbar by action signature. The Scripts list continues to read the unchanged generated `.mcr`; discovery does not regenerate button actions, delete toolbars or edit their contents. The backend is independent and reusable by Script-Manager.

The single-line **UI file log** at the bottom shows the dialog INI, generated `.mcr` and active `.cuix` locations; hover over it for complete paths if the text is truncated. Changing Toolbar name or Save UI refreshes the line. With **Save UI** checked, Create/Update/Delete persist the active CUIX; unchecked, the backend loads a temporary session CUIX instead. `.mcr` is written for Create/Update or removed for Delete, independently of Save UI. The dialog now starts at its content-fitted 600 px height (16 px below the last control), ignoring oversized heights saved from previous sessions. It remains vertically resizable while open and cannot dock to the 3ds Max interface.

Both **Add Folder** and **Add Files** initially browse the directory returned by `getDir #userScripts` in the running 3ds Max. This resolves the active Windows profile and Max version without a hardcoded path.
The script list is dark to match the rest of the dialog. Add Files iterates the selected paths directly, because MaxScript may expose `OpenFileDialog.FileNames` as a native MAXScript Array.

## Button data

Each button is an Array containing a script path, button text, and optional tooltip:

```maxscript
toolbar_buttons = #(
    #(@"C:\Tools\Tool-A.ms", "TOOL A", "Run Tool A"),
    #(@"C:\Tools\Tool-B.ms", "TOOL B", "Run Tool B")
)
```

Button text is automatically limited to ten characters. Each generated MacroScript loads its script directly with `fileIn` and does not depend on Script Manager.
MAXScript natively supports `$userScripts` symbolic filenames in `fileIn`, so generated toolbar actions remain independent of Toolbar-Creator after installation.

## Create

```maxscript
manageScriptToolbar #create "MY TOOLS" button_data:toolbar_buttons \
    macro_category:"My Tools"
```

`#create` fails when a same-named toolbar already exists.

## Update

```maxscript
manageScriptToolbar #update "MY TOOLS" button_data:toolbar_buttons \
    macro_category:"My Tools"
```

`#update` replaces the complete same-named toolbar and fails when it does not exist.

## Delete

```maxscript
manageScriptToolbar #delete "MY TOOLS"
```

`#delete` removes the toolbar and its generated combined `.mcr` source file. MacroScript actions already registered in the current 3ds Max process can remain in memory until restart, but the toolbar is removed immediately.

In the UI, select the existing toolbar in **Managed Toolbars** before clicking Delete. Delete always uses this selected existing name, even if the editable Toolbar name is different. The toolbar remains available for deletion when its generated `.mcr` file has gone missing; script readback is not required.

## Test

Use the canonical launcher at the new installation path `G:\CODE\MAXSCRIPT\SCRIPTS\CODEBASE\Functions\UI\Toolbar-Creator\Toolbar-Creator.ms`. Provided `getDir #userScripts` points to `G:\CODE\MAXSCRIPT\SCRIPTS`, the portable equivalent is `$userScripts\CODEBASE\Functions\UI\Toolbar-Creator\Toolbar-Creator.ms`. Both launcher and UI resolve their neighboring source files relative to their current directory, not to a fixed `G:` path.

To check loading/compilation **without modifying 3ds Max toolbars**, evaluate this in the Listener using the portable location:

```maxscript
fileIn @"$userScripts\CODEBASE\Functions\UI\Toolbar-Creator\Toolbar-Creator-FN.ms" quiet:true
format "Toolbar-Creator backend: % | collector: %\n" (manageScriptToolbar != undefined) (collectToolbarScripts != undefined)
```

Evaluate `Toolbar-Creator-Test.ms` while no other CUI customization is in progress. It verifies nested script discovery and deduplication, creates a temporary one-button toolbar, updates it to two buttons, renames it, deliberately removes the generated `.mcr`, then deletes the saved toolbar and prints PASS/FAIL results to the Listener. The CUIX portion modifies the active 3ds Max UI while the test runs, then removes its own temporary toolbar.
The integration test first catches backend load/compile failures and aborts before changing the UI if loading fails.

UI smoke test: launch `Toolbar-Creator.ms` and check the 1024 px wide dark layout, Managed Toolbars left with Create/Update/Rename/Delete in a 2×2 grid beneath the list, and Toolbar Config right. Select a toolbar and click Create to verify that it starts an empty username-prefilled draft; click Update with no selection to refresh the list without losing that draft. Add a nested folder and several scripts; verify Button Text and Script Path columns, Up/Down and Remove all on the upper action row. Change Button Text, press Update and verify the new text in the toolbar. Check Clear List cancel and confirm. Click Customize Toolbars and verify that the native Customize User Interface dialog opens, then inspect its Toolbars tab. Temporarily make a script used by a saved managed toolbar unavailable, reopen the UI, and verify its path appears red and can be repaired with LMB double-click. Verify green Create/Update and orange Rename/Delete .NET button text, and 28 px ordinary button height. Inspect the single-line INI/MCR/CUIX file log and its full-path hover text. Run the launcher while the dialog is open to verify single-instance focus. Click the title to verify safe two-stage restart and saved UI state restoration, while floating. Select an existing managed toolbar and verify its scripts and labels. Change the Toolbar name field without renaming, click Delete, and confirm that the selected old name—not the edited text—is targeted. For a managed toolbar with a missing generated MCR, selecting it must retain the managed selection so Delete remains possible. Enter a different Toolbar name, click Rename and verify old/new names and button preservation. Check horizontal layout at 1024 px, compact minimum height 600 px, vertical resizing, and disabled left/right docking. All runtime behavior must be verified in 3ds Max; offline source checks do not replace it.

Native rename smoke test: select a managed toolbar, open Customize User Interface > Toolbars, rename it, save the native UI configuration, and return the pointer to Managed Toolbars. Verify that the displayed name updates without launching a second dialog and that Scripts still lists its buttons. Also verify the renamed toolbar after closing and reopening Toolbar-Creator. Keep a CUIX backup before testing Update/Delete.

Startup selection test: select a managed toolbar that is not the first entry, close Toolbar-Creator, and run `Toolbar-Creator.ms` again. The same Managed Toolbar should be selected and Scripts should match its actual saved buttons, not old INI draft rows. Selecting a different managed toolbar should immediately replace the Scripts contents. If no previously selected toolbar exists, the first available toolbar is selected; if no managed toolbars exist, Scripts stays empty.

Browse-dialog smoke test: in the Listener evaluate `getDir #userScripts`, then click **Add Folder** and **Add Files** separately. Each dialog should initially open at the reported directory.

UI selection test: use **Add Files**, select two or more `.ms` scripts together, and check that each appears in the dark preview list without a `FileNames.Length` exception. The background should be charcoal and the text light gray.

UI state-save test: select a listed script, change its button text, then close the dialog and reopen it. The edited text should persist in the INI state without a `Call needs function or class, got: undefined` error.




