# Toolbar-Creator Design

## Intent

Toolbar-Creator is a reusable low-level UI function that allows unrelated MaxScript projects to manage their own 3ds Max toolbars without depending on Script Manager or requiring manual Customize User Interface work.

## Separate frontend and recursive discovery (project 0.02)

- Historically `Toolbar-Creator.ms` held the backend; since project 0.12, the independent backend lives in `Toolbar-Creator-FN.ms`. The public `manageScriptToolbar()` API remains unchanged, and loading the backend alone has no UI side effects.
- `collectToolbarScripts source_paths recursive:true` is a backend function accepting an ordered Array of directory or individual `.ms` paths. It recursively collects `.ms` files via the native `getFiles recurse:` API and deduplicates normalized paths case-insensitively. Valid results are ordered button-data records; malformed or missing sources return `undefined` with a diagnostic.
- `Toolbar-Creator-UI.ms` is the separately launchable frontend. It uses native rollout controls, a .NET list and multi-file picker, and the shared Default UI template helpers. It passes curated data to `manageScriptToolbar()` instead of duplicating CUIX logic.
- Multiple folders may be added through repeated folder selections; file selections can contain several `.ms` files at once. The UI supports removal, reorder, label/tooltip editing, creation, replacement, and confirmation before deletion.
- UI state is stored in the stable `Toolbar-Creator-UI.ini` beside the owning script. The dialog is floatable/dockable left/right and uses the canonical title-restart control; native title displays the highest loaded global project version.
- `Save UI` and `Show Toolbar` both default to true. The dialog never mutates CUIX merely by opening, scanning or editing its preview list.

## Backend helper scope (project 0.03)

- Helper functions are declared at the backend file's top level, outside `manageScriptToolbar()` and `collectToolbarScripts()`, to avoid nested references to the enclosing function's local definitions.
- All implementation helpers use the `toolbarCreator` prefix to avoid colliding with functions from other scripts.
- The script collector passes its mutable result Arrays and path-class reference directly to its append helper; no helper captures these from its caller.
- The UI remains in its own file, and both public function signatures and recursive scanning behavior are unchanged.
- The MaxScript integration test checks backend compilation/loading before any CUIX changes, and stops if loading fails.

## Browse defaults (project 0.04)

- The UI opens both folder and file selection dialogs with `getDir #userScripts` as their initial directory.
- `getSavePath initialDir:` is used for folders; `System.Windows.Forms.OpenFileDialog.InitialDirectory` is used for files.
- Only frontend dialog defaults change; the backend's script collector and CUIX management APIs are unchanged.

## File selection and dark preview (project 0.05)

- The `OpenFileDialog.FileNames` collection is enumerated directly, avoiding the unsupported `.Length` and `.GetValue` assumptions when 3ds Max converts the result to a native Array.
- The .NET `ListBox` receives explicit charcoal `BackColor` and light `ForeColor` in the rollout open handler, matching the rest of the Max UI.
- No changes to the CUIX backend, recursive scan, or other dialog controls.

## Rollout helper ordering (project 0.06)

- `applyCurrentButtonText()` is defined before `saveToolbarUiState()`, which calls it while saving selected-item edits.
- MAXScript rollout-local functions depend on source order unless explicitly forward-declared. Keep every helper definition before its first call from another rollout helper.
- A static regression check enforces the function-order requirement. The dialog, persisted state format, dark colors, and backend API remain unchanged.

## Named argument integration (project 0.07)

- The backend declares `button_data:#()` as a keyword parameter, after two positional parameters (`operation` and `toolbar_name`). All callers must therefore pass `button_data:<records>`.
- The UI's Create/Update actions, integration tests and public examples now use this named parameter consistently; Delete still requires only the two positional arguments.
- Kept the independent backend function signature, recursive discovery, persistence, and dark dialog appearance unchanged.

## Native CUI return values (project 0.08)

- A native `cui.saveConfigAs`, `cui.loadConfig`, or `cui.showToolbar` operation may return the MAXScript `OK` value (`OkClass`), which cannot be used as the condition of an `if` statement.
- The backend now normalizes returned values into strict Booleans. Save also verifies that the target file exists. Exceptions remain failure results and preserve the existing rollback path.
- The UI dialog and backend stay separated; dark styling and recursive collection remain unchanged.

## Deferred title-button restart (project 0.09)

- The shared `restartTool` helper evaluates the UI script immediately, and `DialogHost.createManagedDialog` destroys the existing rollout before creating its replacement. Calling it directly from that rollout's own .NET title-button Click handler is unsafe.
- The frontend now schedules a one-shot `System.Windows.Forms.Timer`. Its Tick handler stops the timer before calling the unchanged shared restart helper, so the original Click callback has already exited.
- The dark title appearance, UI persistence, and the independent CUI backend remain unchanged. Do not invoke a synchronous `fileIn`/`restartTool` from the title Click handler.

## XML child-node iteration (project 0.10)

- `.NET XmlNode.ChildNodes` is an `XmlNodeList` wrapper that does not support native MAXScript `for ... in` mapping. `toolbarCreatorFindXmlNode` reads `ChildNodes.Count` and accesses the zero-based `.ItemOf[index]` property instead.
- The in-Max integration test uses the same indexed traversal and includes in-memory XML assertions for both matching and missing toolbar names.
- No changes to toolbar content generation, the dialog controls, dark styling, or the CUI mutation sequence.

## Managed-toolbar second list (project 0.11)

- The new read-only backend `listManagedScriptToolbars()` loads the active saved CUIX and returns names of `type="T"` Windows with at least one generated action ID beginning `ToolbarCreator_`. The pure helper `toolbarCreatorCollectManagedNames windows_node` allows testing the XML filter without loading/saving user UI.
- The dark dialog is 840 pixels wide, with script records in the left list and managed toolbar names in a right list. Refresh reads names from the backend; selection copies the exact `objectName` into the Toolbar input field. It does not load or replace the script records.
- Rebuild the right list after a successful Create, Update, or Delete, and preserve the left selection and label editing behavior. The list reflects the saved active CUIX; temporary unsaved toolbars can be absent.
- Unknown, built-in, or third-party toolbar entries are excluded. No backend toolbar-management operation or generated macro format changes.

## Canonical launcher and independent backend (project 0.12)

- `Toolbar-Creator.ms` is now a minimal startup file; it loads `Toolbar-Creator-UI.ms` from the same directory so executing the canonical filename opens the dialog.
- `Toolbar-Creator-UI.ms` loads `Toolbar-Creator-FN.ms` directly. It must never load the launcher, as that would recursively reopen the UI.
- The MAXScript integration test loads `Toolbar-Creator-FN.ms` directly to preserve its backend compilation check without showing the dialog. Other backend consumers should likewise load the `-FN` file.
- Preserve the legacy `Versions/Toolbar-Creator_0.01.ms` to `_0.07.ms` backend snapshots. New release names identify `Toolbar-Creator-Launcher` and `Toolbar-Creator-FN` separately.
- Dark UI colors, deferred title restart, two listboxes, recursive script discovery, and toolbar management behavior are unchanged.

## Managed Toolbars left / Toolbar Config right (project 0.13)

- The native rollout retains an 840 × 648 minimum layout with a 238-pixel-wide **Managed Toolbars** sidebar at the left and a 552-pixel-wide **Toolbar Config** panel to the right.
- The left sidebar contains the managed-toolbar list, expanded vertically, followed by Refresh. Selecting a name still writes the name to the right-side Toolbar edit field without changing its script records.
- All script discovery, preview/reorder, button text/tooltip, Save UI, Show Toolbar, and Create/Update/Delete controls fit in the right column. The dark list colors and independent backend API are preserved.
- When the dialog height grows, both listboxes expand and Refresh and the bottom configuration controls move downward together, without changing the two-column horizontal arrangement.

## Safe single-instance UI loading (project 0.14)

- A reported 3ds Max crash occurs during an attempted UI restart while the dialog is still displayed. The previous path re-evaluated the UI rollout and called `DialogHost.createManagedDialog`, which can destroy a live rollout containing .NET controls. A delayed Windows Forms timer does not remove the destructive recreation step.
- `Toolbar-Creator-UI.ms` now checks the existing global rollout using Autodesk's documented `RolloutClass` and `.isDisplayed` before evaluating any rollout definition. On an already-open instance it calls `setForegroundWindow` (with a `setFocus` fallback) instead of reloading. On a closed instance it loads `Toolbar-Creator-UI-Core.ms`.
- The core contains the dark UI, CUIX workflows, and resize behavior. Its title click now saves edits and refreshes managed-toolbar names in place; it no longer calls `restartTool` or starts a delayed timer. Updated code is loaded by explicitly closing the dialog, then running the launcher again.
- `Toolbar-Creator-FN.ms` stays independent and unchanged. The integration test remains backend-only. Confirm the repeated-run crash is resolved in an actual 3ds Max session; offline source tests cannot exercise native dialog destruction.

## Portable userScripts path aliases (project 0.15)

- The backend's `toolbarCreatorToPortablePath` shortens only the case-insensitive exact `getDir #userScripts` directory or its `\\`-separated descendants to `$userScripts` (such as `$userScripts\\CODEBASE\\Tool.ms`). Similar-looking siblings and other roots stay absolute, preventing accidental rewriting.
- `toolbarCreatorResolveScriptPath` expands symbolic input paths before `.NET System.IO.Path.GetFullPath` and file validation; MAXScript-native `fileIn` already supports `$userScripts` symbolic paths, so generated MacroScripts can embed the alias directly without relying on Toolbar-Creator functions at execution time.
- `collectToolbarScripts` scans resolved directories and returns portable button paths. The dark preview shows the abbreviation; INI persistence writes it, and load accepts both new symbolic paths and older absolute INI entries, normalizing them when the user-scripts root matches.
- MacroScript name hashing uses the portable path for stable identities between absolute and symbolic references to the same user-scripts file. Duplicate validation resolves the prefix before comparing paths so alias and absolute references cannot bypass duplicate checks.
- In-Max path tests verify the root, nested files, case-insensitive matching, sibling boundaries, and generated macro source without creating or deleting any toolbar.

## Two-column Scripts ListView and inline editors (project 0.16)

- Replace only the right Toolbar Config column's Scripts `System.Windows.Forms.ListBox` with a `System.Windows.Forms.ListView` in `View.Details` mode. Its two headers are **Button Text** (144 px) and **Script Path** (384 px). Rows remain in the existing button-data Array order; sorting by clicking column headers is disabled.
- Use WinForms single-row `SelectedItems.Item[0].Index` (zero-based), converted to the existing one-based button record index. Populate each row with a `ListViewItem` and one path subitem. A preview refresh selects its matching `Items.Item[index]` row, so Apply, Up/Down, Remove, and saved INI behavior remain unchanged.
- Keep the dark ListView background and light text; enable full-row selection. The left Managed Toolbars ListBox and independent backend are untouched.
- Place **Button Text** and **Tooltip** native edit controls on the same horizontal row inside the right column. Use the freed vertical row to enlarge the Scripts ListView by 36 px; preserve 12 px spacing and ensure all controls below the list move correctly during vertical resizing.

## Starting a new toolbar (project 0.17)

- The left Managed Toolbars sidebar has **New Toolbar** and **Refresh** buttons on one row below the list. Both buttons move with the list when the dialog grows vertically, preserving the dark two-column layout.
- **New Toolbar** deselects the currently selected managed toolbar, clears the right-side name field, saves the blank name to UI state, and focuses the name field. It preserves the staged button records, including any valid edits to the selected record, so the same script configuration can be used for a different new toolbar.
- A new name plus at least one script record can then be submitted with the existing **Create** button. The action continues through `manageScriptToolbar #create` with the named `button_data:` parameter; the backend and CUIX validation semantics remain unchanged.

## Clean drafts and Windows username defaults (project 0.18)

- **New Toolbar** starts a genuinely empty draft: deselect the left-hand managed toolbar, reset the right-hand script records to an empty Array, rebuild the Scripts ListView (which also clears Button Text and Tooltip edits), and prefill the Toolbar name from `systemTools.getEnvVariable "USERNAME"` (fall back to `sysInfo.username`). Save the new draft state to the existing INI and focus the name field.
- After a successful `manageScriptToolbar #create` call and managed-list refresh, call the same draft-reset helper so the newly created toolbar stays saved in Max but the editor becomes ready for another toolbar. A failed Create and any Update/Delete operation must not clear the editor.
- This intentionally changes the prior project 0.17 staging behavior; the backend API, CUIX save logic, dark UI, two-column layout, and guarded single-instance launcher remain unchanged.

## Safe title restart with disk reload (project 0.19)

- Restore title-button restart behavior without re-evaluating a rollout from its own .NET Click callback. The click only saves state and schedules a project-scoped WinForms Timer, managed by global functions outside the rollout.
- First timer tick: stop the timer, call the canonical `DialogHost.destroyToolDialogs "Toolbar-Creator"` to unregister docked state and destroy the old dialog, and schedule the second tick only if the close operation reports success. The title callback has already returned by this point.
- Second timer tick: assert the previous rollout's `.isDisplayed` is false; otherwise cancel. Stop, detach and dispose of the timer **before** loading the stable `Toolbar-Creator.ms` launcher from disk via `fileIn`. That launcher leads through the guarded UI entry to the newest canonical UI core and backend files. Do not load numbered backups under `Versions` or invoke `ScriptReload.reloadLatest` against historical `Toolbar-Creator_*.ms` backend snapshots.
- Failure paths print the actual exception or state to Listener and cancel reload. No auto-retry or synchronous destruction from the .NET Click handler. The dark UI, two-column layout, and independent toolbar backend are unchanged.

## Managed toolbar script reload and 1024 px layout (project 0.20)

- The backend read-only `getManagedScriptToolbarButtons toolbar_name macro_file_path:undefined` loads the active saved CUIX, finds its matching toolbar window, and uses each `Item` action ID in CUIX order to locate its source script in the corresponding Toolbar-Creator-generated `.mcr` file. Restore button label and tooltip from CUIX, and shorten matching paths to `$userScripts`. An incomplete mapping returns `undefined` with diagnostics, never a partial editable toolbar.
- The source parser only understands Toolbar-Creator's generated `macroScript` and `target_script_path = "..."` format; it reverses escaped Windows path separators before returning records. A nondefault `macro_file_path:` can be supplied by API callers. This does not modify the toolbar or launch its button scripts.
- Selecting a Managed Toolbar name loads its saved records into the right Scripts ListView, replacing a previous draft only after the complete read succeeds. The name, script order, button text and tooltip controls are synchronized and saved to the existing UI INI. Failed reads deselect the toolbar and retain the current draft.
- Increase the default rollout and DialogHost width from 840 to **1024 px**. Keep the left sidebar at 238 px and enlarge the right configuration panel to 736 px, widening the Scripts ListView, its Script Path column and inline editor row. Resizing widens right-side controls; vertical resizing stays unchanged. The current shared `DialogHost.createManagedDialog` uses `lockWidth:true`, so floating width is fixed at 1024 by that host; the tool does not change protected framework code.

## Default script text sanitization (project 0.21)

- When `collectToolbarScripts` discovers a new `.ms` file through Add Files, Add Folder, or the public collector API, the backend derives its default Button Text from `getFilenameFile`, replaces each `-` and `_` with a space, and joins whitespace-separated words with single spaces. A filename made entirely of separators falls back to `Script`.
- The default Tooltip remains `Run ` followed by that cleaned Button Text. The script source path stays original/portable, and explicitly provided button data is never rewritten. Selecting an existing managed toolbar continues to restore its saved CUIX label and tooltip as-is.

## UI file tracking and styled actions (project 0.22)

- Preserve the 1024 px two-column dark dialog. Increase minimum height to 720 px to reserve a bottom-right **UI files** area. This read-only .NET multiline text field remains selectable and horizontally scrollable so the user can inspect/copy complete paths even when long.
- The file tracker displays three runtime-derived locations: `Toolbar-Creator-UI.ini` beside the launcher (always saved on state changes/close), the generated `.mcr` target resolved by the existing backend helper from the entered toolbar name (created/updated or deleted by toolbar actions), and the currently active `.cuix` returned by `cui.getConfigFile()` (permanent when Save UI is checked, temporary session config otherwise). Refresh it when changing toolbar name, selecting a managed toolbar, resetting to New Toolbar, toggling Save UI, and after successful toolbar actions. Temporary CUIX and rollback backups remain an implementation detail of the backend.
- The separate **Apply Text** button is removed. The two editor `changed` callbacks keep selected script records in sync while typing, including edits across multiple rows; `executeToolbarAction` validates/commits pending text before both Create and Update. Existing INI state saving and list-reorder preservation continue working. **Clear List** prompts for confirmation on nonempty lists; Cancel keeps all records intact. No backend changes.
- Increase ordinary buttons from 24 to 28 px while leaving the canonical 20 px title/restart button unchanged. Convert Create/Update/Delete only to WinForms Buttons, retaining dark standard backgrounds, borders, hover, pressed, and Segoe UI Bold 9 font, with green foreground for Create/Update and orange foreground for Delete. Wire `.NET Click` rather than native `pressed` callbacks.
- Document the new local installation target `G:\CODE\MAXSCRIPT\SCRIPTS\CODEBASE\Functions\UI\Toolbar-Creator\` using the `$userScripts\CODEBASE\Functions\UI\Toolbar-Creator\` native symbolic prefix when that path is under the configured `getDir #userScripts` root. The launcher and UI's relative file loading require no hardcoded drive path.

## Managed toolbar rename (project 0.23)

- Add a `.NET Rename` button in the primary action row, between Update and Delete. It uses the selected name in the left Managed Toolbars list as the old identity and the editable Toolbar name on the right as the new identity. A confirmation dialog shows both names; no selected managed toolbar or an unchanged/empty name is rejected without modifying CUIX.
- `renameManagedScriptToolbar old_toolbar_name new_toolbar_name button_data:#()` accepts the ordered editable records, or reads the current saved managed toolbar records if none are supplied. It checks the original belongs to Toolbar-Creator, rejects same-name and existing managed target, validates new button data, and rejects any old/new macro-file path collision.
- Rename uses the already-tested backend `manageScriptToolbar` create/delete transactions: create the replacement first with new stable MacroScript action IDs/file, then delete the old toolbar and its `.mcr`. On failure to delete the old toolbar, try to remove the replacement and report any rollback failure. A failed operation returns `false`, not a successful-looking status; no immediate irreversible in-place CUIX string replacement is used.
- On successful Rename, the UI selects the new name, refreshes managed scripts and the actual INI/MCR/CUIX tracking panel, and retains the dark theme, 28 px action height and 1024 px width. Existing Add Folder, Add Files, Clear List, Create/Update/Delete behavior is unchanged.

## One-line file log and delete targeting (project 0.24)

- Replace the project 0.22 multiline output field with a single dark `.NET Label` displaying the INI, generated MCR, and current CUIX locations separated on one line. `AutoEllipsis` prevents clipping artifacts; a native WinForms `ToolTip` shows all three full paths on hover. Dispose the tooltip on rollout close. Reduce minimum/default dialog height back to 648 px without changing the 1024 px width, other controls, or title-button behavior.
- The Delete button must operate on the **selected name** from the left Managed Toolbars list, not the editable name used for Create, Update and Rename. Without a selection, Delete stops with a diagnostic instead of deleting a possibly different toolbar typed in the editor.
- A managed toolbar that cannot reconstruct its scripts due to a missing/outdated generated `.mcr` remains selected and may still be deleted. Clear only the right-side Scripts preview and report the readback problem; do not turn missing button details into an empty valid Update or an implicit delete.
- After successful deletion, reset the right configuration to a new empty draft and show the original deleted name in status. The backend `manageScriptToolbar #delete` already requires no button data and treats an absent generated MCR as harmless; the in-Max regression test deletes a saved test toolbar after removing its MCR to pin this behavior.

## Consolidated managed-toolbar actions (project 0.26)

- Place the existing dark .NET Create, Update, Rename and Delete controls in a 2×2 grid immediately below the **Managed Toolbars** list; remove the redundant native New Toolbar and Refresh buttons. Keep the existing 28 px action height and semantic text colors.
- **Create** has two contextual actions: with a managed toolbar selected (or no proposed scripts), it prepares a blank username-prefilled draft using `resetNewToolbarDraft`; with an unselected populated draft, it creates the toolbar through the existing backend. A successful creation still prepares a blank draft.
- **Update** commits changes through `manageScriptToolbar #update` when a managed toolbar is selected. With no selection, it refreshes saved managed toolbar names only, preserving the unfinished draft.
- Managed-list refresh should restore the *actual selected toolbar identity*, not match the editable Toolbar name. For Rename, explicitly select the newly renamed toolbar. This prevents a fresh unselected draft whose proposed name matches a saved toolbar from being silently replaced during Refresh.
- Reallocate the now-unused right action row to 36 px additional height for the Scripts ListView, moving its following controls downward. Preserve the 1024 × 648 layout, vertical resizing, button-record persistence, restart safety and independent backend.

## Toolbar action row and missing-path repair (project 0.29)

- Keep the two-column dark UI and existing `.NET System.Windows.Forms.ListView` for Scripts. Place Add Folder, Add Files, Clear List, Up, Down, Remove and Customize Toolbars on one row above it; remove the previous lower Up/Down/Remove row.
- Customize Toolbars invokes Autodesk's documented `max customize UI` command. The user can select the Toolbars tab in the native dialog; do not depend on undocumented tab-selection APIs.
- Reconstruct every nonempty saved script path from the UI INI, even when its file no longer exists. Resolve `$userScripts` through the backend and color only the missing file's Script Path subitem red. Do not automatically delete or apply broken paths to the live toolbar; the existing LMB double-click replacement workflow repairs them.
- Use the lowest left/right control bounds plus 16 px to establish the compact 600 px minimum height. Keep larger stored/user-resized heights, expand both lists vertically, and move lower controls with the resize delta. Preserve the 1024 px width and backend interfaces.

## Startup managed-toolbar synchronization (project 0.30)

- `loadToolbarUiState` restores the name and checkboxes but clears the Scripts preview; it does not repopulate Scripts from the old INI `Buttons` records on startup.
- Persist the selected managed toolbar's exact identity under `MainUI/SelectedToolbar`, independent of the editable `ToolbarName` field. On startup, restore this saved selection (using ToolbarName as a compatibility fallback), or select the first available managed toolbar. With no managed toolbar, leave Scripts empty.
- Rely on the existing Managed Toolbars selection handler to reconstruct scripts, labels and order from CUIX/MCR. The currently selected toolbar always determines the Scripts contents; preserve the existing readback failure behavior and editable new-toolbar draft flow while the dialog remains open.

## Public contract

The supported public APIs are `manageScriptToolbar` and `collectToolbarScripts`. The prefixed helpers are implementation details.

- `operation`: `#create`, `#update`, or `#delete`.
- `toolbar_name`: exact CUIX toolbar `objectName` and display name.
- `button_data:`: optional named parameter containing ordered Arrays in the form `#(script_path, button_text, tooltip)`. Pass explicitly for Create and Update.
- `macro_category`: generated MacroScript category and CUI action category.
- `save_ui`: when true, persist the result to the original active CUIX.
- `show_toolbar`: when true, show a created or updated toolbar after loading.
- `macro_file_path`: optional explicit generated `.mcr` path; otherwise use `#userMacros`.
- `delete_macro_file`: remove the generated combined `.mcr` source during `#delete`.
- `register_macros`: evaluate the generated `.mcr` immediately; disabling this is intended for controlled tests.

The function has a strict Boolean return contract. Fatal branches print a diagnostic before returning false.

## Operation semantics

- `#create` requires the toolbar to be absent.
- `#update` requires the toolbar to exist and replaces it completely.
- `#delete` requires the toolbar to exist and removes it completely.

The function does not silently convert one operation into another.

## MacroScript identity

Action names are derived from toolbar name, script filename, and a stable hash of the complete script path. Reordering buttons therefore does not change action identity. Duplicate source paths and detected action-name collisions are rejected.

Generated actions load source scripts directly through `fileIn`.

## CUIX workflow

1. Resolve and back up the original active CUIX.
2. Save the current UI to a temporary CUIX.
3. Load the XML through `System.Xml.XmlDocument`.
4. Validate the requested create/update/delete state.
5. Remove or append the exact named `Window` node.
6. Generate and optionally register MacroScript actions.
7. Load the temporary CUIX and optionally show the toolbar.
8. When `save_ui` is true, save and reload the original active CUIX path.

If a critical stage fails, the original CUIX bytes and former generated MacroScript source are restored when possible. Rollback failures are reported separately and never converted to success.

## Constraints

- Keep canonical launcher, backend (`-FN`), UI, tests, and documentation in the project root; move every version-numbered release to the `Versions` subfolder.
- Run toolbar management only while no other CUI customization is in progress.
- Source scripts must exist when creating or updating a toolbar.
- MacroScript categories cannot contain the CUI action delimiter backtick.
- The active CUIX must be XML with `/ADSK_CUI/CUIWindows`, as used by supported 3ds Max CUIX configurations.
- Runtime behavior must be verified inside 3ds Max with `Toolbar-Creator-Test.ms`; external static checks do not replace that test.




