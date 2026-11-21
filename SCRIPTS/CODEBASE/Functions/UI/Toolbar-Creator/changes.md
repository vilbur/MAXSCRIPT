# Changes

## 2026-11-21 — project 0.37

- `Toolbar-Creator-UI-Core.ms` 0.21: disable CUI docking by opening Toolbar-Creator with standard `createDialog` and omitting `registerDockableDialog`. Keep fixed 1024 px width, control-fitted 600 px startup height, manual vertical resizing, and floating position persistence.
- Clean up legacy Toolbar-Creator dialog registration before opening; the safe two-stage restart now destroys only its non-dockable rollout. Toolbar management, saved MacroScripts and CUIX contents remain untouched. Offline validation passed; in-Max UI verification pending.

## 2026-11-19 — project 0.36

- `Toolbar-Creator-UI-Core.ms` 0.20: fit the dialog's startup height to its lowest controls plus 16 px bottom margin, overriding oversized Height values previously saved to the UI INI. Preserve manual vertical resize after opening and keep existing 1024 px width.
- Correct the content-height helper to use the checkbox's declared 24 px height; native MAXScript CheckboxControl does not expose `.height`. Avoid `setDialogSize` on registered dockable dialogs. No toolbar/CUIX backend changes.

## 2026-11-19 — project 0.35

- `Toolbar-Creator-UI-Core.ms` 0.19: changed Rename .NET button font to the same orange (`RGB 230, 165, 75`) as Delete. Create/Update remain green. No backend, CUIX, toolbar actions or layout changes.

## 2026-11-19 — project 0.34

- `Toolbar-Creator-UI-Core.ms` 0.18: Managed Toolbars refresh and initialization now use the verified backend `listManagedScriptToolbars sync_live:true` path, which calls `cui.saveConfig()` before reading native `name`/`objectName` attributes from the active CUIX.
- UI pairs those current names with `getManagedScriptToolbarRecords()` and `toolbarCreatorFilterRenamedRecords` for stable action signatures; only the latest native-renamed alias is displayed, while the selected toolbar and its Scripts buttons stay intact.
- The UI reuses the existing backend v0.17 without modifying toolbar content or regenerating `.mcr` actions. Live API verified in 3ds Max 2026; full UI rename-twice smoke test pending.

## 2026-11-19 — project 0.32

- `Toolbar-Creator-FN.ms` 0.16: when native Customize changes only one of the CUIX `Window` attributes (`name` / `objectName`), resolve the visible name by checking which attribute still matches the original generated `.mcr` path; the other is the renamed name. Continue matching the toolbar by its action IDs without modifying its buttons.
- Preserve the resolved native name when Update rebuilds a managed toolbar, rather than restoring a stale CUIX label.
- `Toolbar-Creator-UI-Core.ms` 0.17: synchronize Managed Toolbars on both mouse entry and mouse down; existing selection is preserved by its action signature. No CUIX writes on list refresh. The native UI change must be saved to the active CUIX before the list can read it.
- Static source and simulated CUIX mismatch checks passed; live 3ds Max testing pending.

## 2026-11-19 — project 0.31

- `Toolbar-Creator-FN.ms` 0.15: detect externally renamed managed toolbars using native CUIX display names, preserving the original object identity and matching generated `.mcr` files by the toolbar's `ToolbarCreator_` action IDs. Native rename no longer breaks script button readback or direct Update/Delete actions.
- `Toolbar-Creator-UI-Core.ms` 0.16: refresh the Managed Toolbars list when the mouse re-enters it, keeping the selected toolbar by its action signature even when both native name attributes change. Startup restores the selection using the same signature.
- No automatic CUIX save or regenerated toolbar actions during synchronization. Save changes from native Customize User Interface to the active CUIX before expecting external changes to appear. Static source checks passed; live 3ds Max verification pending (MCP session unavailable).

## 2026-11-08 — project 0.30

- `Toolbar-Creator-UI-Core.ms` 0.15: on dialog startup, Scripts now loads from the selected saved managed toolbar instead of restoring unrelated draft button records from `Toolbar-Creator-UI.ini`.
- The INI stores the selected toolbar identity separately from the editable Toolbar name. Startup restores that toolbar when present, otherwise selects the first managed toolbar; an empty managed list leaves Scripts empty.
- Preserved the existing live selection-change readback, Create/Update/Rename/Delete behavior, dark layout and backend. Offline static regression checks passed; runtime validation inside 3ds Max is pending.

## 2026-11-08 — project 0.29

- `Toolbar-Creator-UI-Core.ms` 0.14: added **Customize Toolbars** using the native `max customize UI` command. The Toolbars tab can be selected in the opened Autodesk dialog.
- Consolidated **Add Folder**, **Add Files**, **Clear List**, **Up**, **Down**, **Remove**, and **Customize Toolbars** on one row above the existing .NET Scripts ListView.
- Missing script paths display in bright red in the Script Path column. Saved INI records with missing files stay editable instead of disappearing, so LMB double-click can repair them; toolbar changes still require Create/Update.
- Reflowed both columns and based the compact 600 px minimum dialog height on their bottom control bounds; taller saved and user-resized dialog heights remain supported. Static checks passed; live 3ds Max validation pending.

## 2026-11-07 — project 0.28

- `Toolbar-Creator-UI-Core.ms` 0.13: LMB double-clicking a populated Scripts ListView row opens a single-file `.ms` browser, initially in that script's directory. Replaces only the clicked row's path and preserves its Button Text, Tooltip, and order.
- Rejects missing/non-`.ms` files and duplicate script paths. Normalizes paths under the user scripts directory to `$userScripts`, updates the displayed Script Path and INI draft, and leaves the actual 3ds Max toolbar unchanged until Create/Update.
- Added the double-click instruction to the Scripts ListView's dark UI tooltip. Existing backend, dialog geometry, and action buttons remain unchanged; offline checks passed and in-Max interaction remains unverified.

## 2026-11-07 — project 0.27

- `Toolbar-Creator-UI-Core.ms` 0.12: moved **Save UI** and **Show Toolbar** from the right Toolbar Config column to a shared row directly below the Create/Update/Rename/Delete grid in the left Managed Toolbars column.
- Reduced the managed-toolbar list by 40 px and shifted its four action buttons up by 40 px so both checkboxes fit within the unchanged 1024 × 648 minimum dialog. Resize handling keeps the new positions aligned.
- Checkbox defaults, tooltips, INI persistence, CUI behavior, other controls and backend remain unchanged. Offline geometry and binding checks passed; runtime validation in 3ds Max is pending.

## 2026-11-07 — project 0.26

- `Toolbar-Creator-UI-Core.ms` 0.11: moved Create, Update, Rename and Delete to a 2×2 .NET button grid beneath Managed Toolbars. Removed duplicate New Toolbar and Refresh controls.
- With a saved toolbar selected, Create starts a fresh username-prefilled draft; with an unselected populated draft, it creates the toolbar. Update saves the selected toolbar, or simply refreshes the managed list when no toolbar is selected.
- Managed-list refresh now preserves actual selection rather than matching the draft name; Rename explicitly selects its replacement. The Scripts ListView gains 36 px height. Backend and tests remain unchanged.
- Updated README/design; archived the UI release in `Versions`. Offline source/layout checks passed; live 3ds Max UI validation remains pending.


## 2026-11-07 — project 0.25

- `Toolbar-Creator-FN.ms` 0.13: fixed managed-toolbar deletion persistence by committing the patched CUIX XML bytes directly to the active configuration instead of calling `cui.saveConfigAs`, which can serialize stale live toolbar state over the deletion. Reloads the committed CUIX and verifies the toolbar is absent before reporting success.
- Delete now refuses toolbars not recognized as Toolbar-Creator-managed. Existing rollback restores the previous CUIX and generated macros if deletion fails.
- `Toolbar-Creator-Test.ms` 0.13: extends Delete verification to confirm removal from the managed-toolbar list and saved CUIX. Interactive 3ds Max testing remains pending.
- Numbered backend and test snapshots are stored under `Versions`. The UI files remain unchanged.

## 2026-11-03 — project 0.24

- `Toolbar-Creator-UI-Core.ms` 0.10: condensed the INI/MCR/CUIX tracker into a single-line dark label with full paths available on hover. Restored minimum dialog height to 648 px.
- **Delete** now always targets the existing toolbar selected in the left Managed Toolbars list, never the editable name being used to prepare a Rename. Unselected Delete is rejected. After successful deletion the right side becomes a clean draft.
- If a saved toolbar's generated `.mcr` is missing or unreadable, its managed selection stays available for deletion even though its script details cannot be edited. Failure remains visible in the status label and Listener.
- `Toolbar-Creator-Test.ms` 0.12: deletes a saved toolbar with its generated `.mcr` deliberately absent; updated offline checks for the single-line log and selection-safe deletion. The existing backend code is unchanged at 0.12 / project 0.23.
- Added the UI and test versions to `Versions`, preserving older snapshots.

## 2026-11-03 — project 0.23

- `Toolbar-Creator-FN.ms` 0.12: added public `renameManagedScriptToolbar old_toolbar_name new_toolbar_name` API. Retains button order/text/tooltip, generates new macro IDs and `.mcr`, removes the old toolbar/macro, and attempts removal of the replacement if deleting the original fails. Invalid names, unmanaged sources and macro collisions abort with diagnostics.
- `Toolbar-Creator-UI-Core.ms` 0.09: added dark .NET **Rename** action alongside Create/Update/Delete. Select an existing managed toolbar, edit the toolbar name, then confirm Rename. The UI refreshes the managed list, scripts and file-path tracker on success.
- `Toolbar-Creator-Test.ms` 0.11: expanded the 3ds Max integration flow to CREATE -> UPDATE -> RENAME -> DELETE, asserting preserved button records and old toolbar/macro cleanup.
- Numbered releases saved in `Versions`, with prior v0.22 UI preserved as its own snapshot. All v0.22 changes remain in the new core; unchanged launcher and UI entry versions are retained.

## 2026-11-02 — project 0.22

- `Toolbar-Creator-UI-Core.ms` 0.08: expanded the dark dialog height to accommodate a selectable file tracker showing the dialog INI, generated toolbar MCR and active CUIX. Paths and the Save UI state refresh with the toolbar name, managed-toolbar selection, checkbox and successful actions.
- Removed separate Apply Text button; Create/Update use the pending Button Text/Tooltip automatically. Nonempty Clear List now requires confirmation and Cancel keeps the scripts.
- Increased ordinary button heights to 28 px; Create and Update are dark WinForms buttons with green text, Delete is a dark WinForms button with orange text. The shared 20 px tool title button is unchanged.
- Changed the installation/Listener examples to `$userScripts\CODEBASE\Functions\UI\Toolbar-Creator\` for the new `G:\CODE\MAXSCRIPT\SCRIPTS\CODEBASE\Functions\UI\Toolbar-Creator\` layout. No backend code or protected shared UI files changed.
- Saved the numbered UI core snapshot under `Versions/Toolbar-Creator-UI-Core_0.08.ms`.

## 2026-11-02 — project 0.21

- `Toolbar-Creator-FN.ms` 0.11: newly collected `.ms` files now prefill Button Text from their filename with hyphens and underscores replaced by single spaces, and Tooltip as `Run <cleaned name>`. Existing paths and user-edited labels remain unchanged.
- `Toolbar-Creator-Test.ms` 0.10: added recursive-collector regression coverage for repeated dashes and underscores in filenames. Archived the numbered backend and test releases under `Versions`.
- Dark UI, managed-toolbar readback, 1024 px layout, and safe title restart remain unchanged.

## 2026-11-02 — project 0.20

- `Toolbar-Creator-FN.ms` 0.10: added read-only managed-toolbar button retrieval by matching saved CUIX action IDs to script source paths in the generated MacroScript file. Incomplete mappings fail explicitly and cannot silently replace a toolbar's scripts.
- `Toolbar-Creator-UI-Core.ms` 0.07: selecting a managed toolbar refreshes the right Scripts list with its saved paths, labels, tooltips and order. Increased dialog width to 1024 px, expanded the right configuration column, and preserved the dark two-panel layout and safe title restart.
- `Toolbar-Creator-Test.ms` 0.09: added generated-path parser and CUIX readback regression checks for create/update workflows. Added offline UI/layout checks. Archived all three source releases in `Versions`.
- The shared dialog host still fixes floating dialog width; true free horizontal resizing requires a separately authorized shared-framework change. No shared Functions files were modified.

## 2026-11-02 — project 0.19

- `Toolbar-Creator-UI-Core.ms` 0.06: clicking the dark title button again restarts Toolbar-Creator and loads the current on-disk canonical scripts, including a newly synchronized version when present.
- A globally handled two-stage WinForms timer closes/unregisters the old rollout first, then checks `.isDisplayed == false` before starting the launcher in a later timer tick. The title Click callback never destroys or reloads itself; the timer is stopped and disposed before file loading.
- Failed close, still-displayed dialog, missing launcher, and reload exceptions are logged to Listener; unsafe recreation is cancelled. Added offline safety checks and archived the numbered UI release in `Versions`. Live 3ds Max restart/crash testing remains necessary.

## 2026-11-02 — project 0.18

- `Toolbar-Creator-UI-Core.ms` 0.05: **New Toolbar** now clears the Scripts list and selected button edits, and prefills the toolbar name from Windows `%USERNAME%` (with a MAXScript username fallback).
- After a successful **Create**, the same fresh draft appears automatically. Failed Create operations preserve the script configuration; Update and Delete retain their previous behavior.
- Saved UI state is synchronized with the new empty draft; the dark layout and separate backend are unchanged. Archived the release in `Versions` and updated offline regression checks.

## 2026-11-02 — project 0.17

- `Toolbar-Creator-UI-Core.ms` 0.04: added **New Toolbar** beside Refresh in the left Managed Toolbars sidebar. It deselects any existing toolbar, clears and focuses the Toolbar name, and preserves staged script buttons and edits for a new Create action.
- Both sidebar buttons stay aligned when the dialog is resized. The dark two-column layout, existing Create/Update/Delete backend, and single-instance UI guard are unchanged.
- Added an offline regression check for the new-toolbar workflow and archived the numbered release in `Versions`.

## 2026-11-02 — project 0.16

- `Toolbar-Creator-UI-Core.ms` 0.03: converted the Scripts preview from a .NET ListBox to a dark, single-select two-column ListView displaying Button Text and Script Path. Script order, selection, editing and toolbar actions retain their existing data model.
- Moved **Button Text** and **Tooltip** edits onto one row, enlarged the Scripts view by 36 px, and updated vertical resizing. The Managed Toolbars left list and backend remain unchanged.
- Added offline regression checks for the ListView, selection mapping, two-column rows, and non-overlapping editor layout. Saved the numbered release in `Versions`.

## 2026-11-02 — project 0.15

- `Toolbar-Creator-FN.ms` 0.09: converts paths under the configured `getDir #userScripts` directory into portable `$userScripts\\...` filenames. Expands symbolic inputs before .NET folder scanning and validation; generated MacroScripts keep native symbolic file paths without a runtime dependency on Toolbar-Creator.
- `Toolbar-Creator-UI-Core.ms` 0.02: the Scripts list and saved INI paths use portable filenames. Older absolute INI paths are recognized and shortened on reload when they match the current user-scripts root.
- `Toolbar-Creator-Test.ms` 0.08: added path-alias, directory-boundary and generated-macro test cases. Dark UI, the left Managed Toolbars/right Toolbar Config layout, and safe single-instance startup remain unchanged.
- Archived the new backend, UI core, and integration-test releases in `Versions`.

## 2026-11-02 — project 0.14

- Addressed the 3ds Max crash path caused by re-evaluating a live Toolbar-Creator rollout: `Toolbar-Creator-UI.ms` 0.12 now detects an already displayed dialog and focuses it rather than loading the UI implementation again.
- Moved the full dark rollout into `Toolbar-Creator-UI-Core.ms` 0.01, loaded only by the guarded entry. Clicking the title now saves pending edits and refreshes the managed-toolbar list in place; destructive title-button restart and its delayed timer were removed.
- Preserved the independent backend, two-column layout, and numbered snapshots in `Versions`. Added regression checks for the no-reload-while-open rule; in-Max crash testing is still required.

## 2026-11-02 — project 0.13

- `Toolbar-Creator-UI.ms` 0.11: reversed the two-panel layout. **Managed Toolbars** now occupies the left sidebar, with Refresh beneath its tall dark list. **Toolbar Config** fills the right column, holding the name, script list, button editing, and toolbar actions.
- Both lists still grow with dialog height; selection updates the toolbar name without changing the script collection. Preserved the dark styling, independent `-FN` backend, recursive scanning, and deferred title restart.
- Added layout regression checks and archived the UI release as `Versions/Toolbar-Creator-UI_0.11.ms`.

## 2026-11-02 — project 0.12

- Renamed the independent backend to `Toolbar-Creator-FN.ms` 0.08. Its public functions and toolbar-management behavior are unchanged.
- Created `Toolbar-Creator.ms` launcher 0.01: running the canonical script now opens the dark UI. The UI (`Toolbar-Creator-UI.ms` 0.10) directly loads the `-FN` backend, preventing launcher recursion.
- `Toolbar-Creator-Test.ms` 0.07 also imports `-FN` so its backend-loading checks remain UI-free.
- Numbered snapshots stored in `Versions` under unique launcher/backend filenames, preserving historical backend releases.

## 2026-11-02 — project 0.11

- `Toolbar-Creator.ms` 0.07: added read-only `listManagedScriptToolbars()` and `toolbarCreatorCollectManagedNames` to discover saved, Toolbar-Creator-generated toolbars from CUIX action IDs.
- `Toolbar-Creator-UI.ms` 0.09: added a second charcoal ListBox and Refresh button; selecting a managed toolbar fills the name field, while the scripts on the left remain unchanged. Both lists grow vertically with the window.
- `Toolbar-Creator-Test.ms` 0.06: added in-memory XML coverage for managed, built-in, empty, and non-toolbar windows.
- Preserved the separated backend, recursive scripts, dark UI and deferred title restart. Numbered releases archived in `Versions`.

## 2026-11-01 — project 0.10

- `Toolbar-Creator.ms` 0.06: fixed `No "map" function for dotNetObject:System.Xml.XmlChildNodes` by indexing `.NET` child nodes via `.ItemOf[index]` rather than iterating them as a native MAXScript collection.
- `Toolbar-Creator-Test.ms` 0.05: updated the same XML traversal and added read-only in-memory XML search assertions.
- `Toolbar-Creator-UI.ms` 0.08: version display updated; dark UI and deferred restart preserved.
- Verified indexed traversal against an isolated live 3ds Max XML document and archived numbered releases in `Versions`.

## 2026-11-01 — project 0.09

- `Toolbar-Creator-UI.ms` 0.07: replaced synchronous title-button `restartTool` inside a .NET Click handler with a deferred one-shot Windows Forms timer, avoiding reentrant destruction of the clicked dialog.
- Kept the dark title button and shared restart behavior, while leaving the backend at 0.05. Archived the UI release in `Versions` and added a restart regression guard.

## 2026-11-01 — project 0.08

- `Toolbar-Creator.ms` 0.05: fixed `Type error: if-test requires BooleanClass, got: OK` by normalizing native CUI save, load and show returns to Booleans. Saved files must also exist before reporting success.
- `Toolbar-Creator-UI.ms` 0.06: bumped shared project display version without changing dark UI behavior.
- Added a regression guard for unsafe direct assignment of CUI return values to Boolean workflow flags and archived both releases in `Versions`.

## 2026-11-01 — project 0.07

- `Toolbar-Creator-UI.ms` 0.05: fixed `Argument count error: manageScriptToolbar wanted 2, got 3` by passing button records as the backend's named keyword `button_data:`.
- `Toolbar-Creator.ms` 0.04: corrected its public usage examples while preserving its actual API and behavior.
- `Toolbar-Creator-Test.ms` 0.04 and README examples: corrected the same invalid positional calls, with a source regression check for future callers.
- Preserved the dark dialog and separate backend. Archived the new file versions under `Versions`.

## 2026-11-01 — project 0.06

- `Toolbar-Creator-UI.ms` 0.04: fixed an undefined-function call at the start of `saveToolbarUiState()` by defining `applyCurrentButtonText()` earlier in the rollout.
- Added an offline regression check against rollout helper forward references, and verified the corrected helper order with an isolated MAXScript test in a connected 3ds Max instance.
- Archived the UI release as `Versions/Toolbar-Creator-UI_0.04.ms`. Dark UI and backend behavior are unchanged.

## 2026-11-01 — project 0.05

- `Toolbar-Creator-UI.ms` 0.03: fixed multi-file browsing error from treating the `FileNames` MAXScript Array as a .NET array with `.Length` and `.GetValue`.
- Applied dark background and readable light text to the .NET script preview list, preserving the surrounding dark UI.
- Added regression checks and archived the UI release as `Versions/Toolbar-Creator-UI_0.03.ms`.

## 2026-11-01 — project 0.04

- `Toolbar-Creator-UI.ms` 0.02: both Add Folder and Add Files browse from the current 3ds Max `#userScripts` directory by default.
- Archived the UI release as `Versions/Toolbar-Creator-UI_0.02.ms`, preserving backend version 0.03.
- Updated browse-dialog smoke test instructions; backend interface and recursive scan unchanged.

## 2026-11-01 — Repository layout

- Created `Versions` and moved `Toolbar-Creator_0.01.ms`, `Toolbar-Creator_0.02.ms`, and `Toolbar-Creator_0.03.ms` there without changing file IDs or contents.
- Future numbered release files belong in `Versions`; canonical entry points remain in the root.

## 2026-11-01 — project 0.03

- Moved private backend helpers to the file's top-level function scope and prefixed their names to avoid outer-local references during MAXScript compilation.
- Removed the collector helper's captures of parent local Arrays and the .NET path class by passing those explicitly.
- Kept the public `manageScriptToolbar` and `collectToolbarScripts` APIs and separate dialog unchanged.
- Added backend compile/load detection and fail-fast behavior to the in-Max integration test.
- Added a static regression guard for nested backend helper declarations and a 0.03 versioned backend snapshot.

## 2026-10-28 — 0.01

- Added standalone `manageScriptToolbar` create/update/delete API.
- Added stable direct-loading MacroScript generation.
- Added transactional CUIX backup and rollback behavior.
- Added executable create/update/delete integration test.
- Added README and design contract.

# 2026-11-01 — project 0.02

- `Toolbar-Creator.ms` 0.02: added backend `collectToolbarScripts()` for recursive folders, individual files, and duplicate prevention; original management API preserved.
- `Toolbar-Creator-UI.ms` 0.01: new separate dialog with button preview/editing, CUI integration actions, and INI persistence.
- `Toolbar-Creator-Test.ms` 0.02: added script-discovery assertions before the existing CUIX integration sequence.
- Updated README and design contracts; runtime UI verification remains required in 3ds Max.



