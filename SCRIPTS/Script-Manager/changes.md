## 2026-11-24 - 1.285

- Initialize Script-Manager PRESETS, OPTIONS, SOURCES, SHOW and IGNORE rollouts collapsed; open only SCRIPTS on each manager initialization, independently of previously saved rollout-open INI states. Manual expand/collapse continues to work and existing filter/preset values remain unchanged.
- When the three other main rollouts are collapsed, size SCRIPTS and its TreeView to the available manager height, subtracting the outer header area, three collapsed rollout headers, SCRIPTS header, and 64 px internal controls/margin. Recompute on docking/resize and rollout toggle. When another section is opened, retain the original 1280 px scrollable tree layout.
- Test suite v1.238 updates height assertions and adds read-only regression part 74. Native 3ds Max live UI and docked resize test pending.

## 2026-11-24 - 1.284

- Hide only the trailing `.ms` extension in displayed script names in both SCRIPTS TreeView construction paths and the GROUP SCRIPTS listbox.
- Apply the same display rule to script names in GROUP MANAGER right-click action labels; `.mcr`, `.mse`, and other suffixes remain visible.
- Preserve original script paths in TreeNode Tag/ToolTipText, group member arrays, INI, filtering, loading, right-click actions, and toolbar references; no files are renamed.
- Static render-site and path-identity checks completed; full 3ds Max UI verification pending.

## 2026-11-24 - 1.283

- Add a dedicated dark right-click menu to each GROUP MANAGER listbox: USER GROUPS, GROUP SCRIPTS and CUSTOM TOOLBARS. Every menu mirrors the action buttons below its list.
- Build selection-specific captions at popup opening (for example `Load <toolbar name> as group`, `Add <selected tree item> to group <group name>`, `Remove <script filename> from <group name>`); disable commands when their corresponding buttons are disabled.
- Right-click selects the row under the pointer; empty-space right-click keeps creation commands available. Retain existing validation, confirmations, group and toolbar persistence, and action callbacks. Dispose menu event handlers on dialog close.
- Source-level checks and live isolated .NET event binding validated; complete dialog runtime verification still required.

## 2026-11-24 - 1.282

- Integrate the former EDIT GROUP SCRIPTS popup into GROUP MANAGER as a third, middle column between USER GROUPS and CUSTOM TOOLBARS. GROUP MANAGER now opens at 1248 x 430 with three matching list heights and vertical resize support.
- Display only script filenames in GROUP SCRIPTS, retaining full paths internally per row and showing a selected script's full path in the shared preview. Missing script-file entries remain removable; invalid directory diagnostic strings are not displayed as scripts.
- Move ADD TREE SELECTION and REMOVE SELECTED SCRIPT into the GROUP SCRIPTS column; delete the obsolete EDIT GROUP SCRIPTS button and standalone rollout creation. Group selection refreshes member rows, and group edits refresh without deleting actual script files.
- Adding back an excluded script via ADD TREE SELECTION clears its persisted exclusion; deleting a member keeps the existing exclusion-based treatment for dynamic folder groups.
- Preserve group/toolbar loading, existing saved groups, CUIX toolbar state, horizontal layout behavior, and previous release snapshots. Static checks completed; native 3ds Max UI verification pending.

## 2026-11-24 - 1.281

- Rework GROUP MANAGER to a horizontal 840 x 430 dialog: USER GROUPS on the left, CUSTOM TOOLBARS on the right, with independent action rows beneath each list.
- Keep dialog width locked and resize both listbox heights together when dialog height changes; preserve selection previews, dark list styling, and all existing group/toolbar actions.
- Add DELETE TOOLBAR beside NEW TOOLBAR, with selection-dependent enablement and a confirmation prompt. Deletion is delegated to the existing Toolbar-Creator #delete backend; user groups and source scripts remain untouched.
- Static geometry/source checks passed. Live 3ds Max display and toolbar deletion still require testing.

## 2026-11-24 - 1.280

- Change mass-loaded/hosted script rollout titles from the three-dash frame to uppercase, letter-spaced text. CamelCase transitions, hyphens and spaces create three-space word gaps; individual letters are separated by single spaces (ThisIs-Tool Name -> T H I S   I S   T O O L   N A M E).
- Preserve trailing numeric | vX.Y removal, rollout fallback names and idempotence on repeated embedding. Standalone titles and actual group/host operations are untouched.
- Native 3ds Max isolated formatter tests passed for five cases and repeated calls. Active hosted dialogs were not recreated; visual rendering in the real mass-loaded dialog remains to be verified on next reload.

## 2026-11-22 - 1.279

- Skip secondary fileIn of a -UI.ms companion when its parent script already compiles it through an include directive. Preserve normal companion loading for separate UI scripts.
- Fix grouped hosting across separate folders when Blueprint-Manager is included with Modifier-Manager; the Blueprint UI depends on parent-local variables and failed when separately loaded twice.
- Runtime verified in 3ds Max 2026: one temporary shared host contained blueprintManagerRollout and modifierManagerUI (2 scripts, 2 rollouts). Test host and test-specific INI state were removed afterwards.

## 2026-11-21 - 1.278

- Fix SCRIPTS script-item right-click ADD TO GROUP submenu remaining empty. WinForms ToolStripMenuItem.Visible is false while the parent context menu is closed, even for an available item. Use the selected script path to decide whether to populate the saved groups list.
- Keep existing saved group names, NEW GROUP creation, script assignment handler, dark styling, and folder-only group actions unchanged.
- Live 3ds Max verification: with one saved group, script submenu shows TEST-MULTI-DIRS, separator, NEW GROUP; four folder/script selection cycles preserved all three entries. No group INI changes or actual script assignment were made during testing.

## 2026-11-21 - 1.277

- Directory right-click menu now has two sibling root actions: ADD TO TOOLBAR and ADD TO TOOLBAR AS GROUP, each with NEW TOOLBAR, a separator, and existing custom toolbar targets.
- Each submenu populates only on its own DropDownOpening event; root menu items remain attached, and group/toolbar data is unchanged.
- Verified in running 3ds Max: v1.277 loaded, both DropDownOpening events fired via ShowDropDown, and both submenus contained NEW TOOLBAR, separator, vilbur-CORE and vilbur-vilTools3. Actual toolbar-button creation was not tested.

## 2026-11-21 - 1.273

- Version the folder toolbar menu fixes and ASCII subrollout title decorations previously saved under 1.272. Synchronize header, file_version and project_version; preserve the existing 1.272 snapshot.

## 2026-11-21 - Folder toolbar menu correction

- Expose ADD TO TOOLBAR AS GROUP directly in folder context menus. Script items retain ADD TO TOOLBAR.
- Replace stale action popups with fresh dark ToolStripDropDownMenu instances before populating targets. Four folder/script switching cycles retained all four targets in live Max.
- Toolbar creation and mass loading were not executed during this menu test.

## 2026-11-21 — 1.272

- Guard GROUP MANAGER callbacks after dialog destruction; closed refresh and reopen verified in Max.
- Add EDIT GROUP SCRIPTS with add-tree-selection and remove-script actions. Persist exclusions separately so dynamic folder groups retain membership edits.
- Preserve existing folder-group toolbar references and bulk loading.
- Live checks: editor opens; excluded script disappears and returns after clearing exclusion. Toolbar click loading not tested.

## 2026-11-21 — 1.271

- Fix right-click menu not opening in v1.270: avoid disposing and recreating the root ContextMenuStrip inside SCRIPTS TreeView NodeMouseClick. Keep the already-created menu alive and update visible item states and submenu targets in place.
- Preserve directory/script actions, saved groups, INI and CUIX. Static source checks only; verify actual popup and nested toolbar targets in 3ds Max.

## 2026-11-21 — 1.270

- Fix directory ADD TO TOOLBAR menu levels observed in v1.269: toolbar target rows and both action labels were placed together at the same level by MAXScript/.NET submenu collection rebinding.
- Attach the two folder action headers first and defer populating each separate dark submenu to its own DropDownOpening event. Retain script-item menu behavior, separate-script / group-button actions, toolbar names, and existing INI/CUIX data.
- Extend regression test v1.237 to trigger each action opening explicitly and verify children after repeated folder/script switching. Source checks completed; verify the actual hover menus in 3ds Max before treating the fix as confirmed.

## 2026-11-21 — 1.269

- Fix the directory **ADD TO TOOLBAR** menu showing the internal `__TOOLBAR_DIRECT_INIT__` item instead of the **ADD TO TOOLBAR** action. Live 3ds Max inspection showed the populated direct-action menu had become detached from its parent while the group action remained attached.
- Build both fully populated, dark-themed .NET `ToolStripMenuItem` action submenus before attaching them to the owner. Preserve **ADD TO TOOLBAR** (separate script buttons) and **ADD TO TOOLBAR AS GROUP** (single dynamic group button), each with **NEW TOOLBAR** first and the existing toolbar targets below.
- Remove temporary submenu initialization placeholders, preserve all toolbar actions, script-item menus, group INI records and CUIX data. Update regression suite to v1.236, including parent-owned action verification and six folder/script switching cycles. An isolated live .NET menu composition test passed; full Script-Manager reload and button creation await user testing.

## 2026-11-21 — 1.268

- Redesign directory-item **ADD TO TOOLBAR** as a nested action menu: **ADD TO TOOLBAR > NEW TOOLBAR, {existing toolbars}** adds the folder's visible scripts as separate buttons; **ADD TO TOOLBAR AS GROUP > NEW TOOLBAR, {existing toolbars}** adds one dynamic folder-group button.
- Keep **CREATE GROUP / DELETE GROUP** independent, preserve the script-item ADD TO GROUP and ADD TO TOOLBAR behavior, existing toolbar assignments, INI and CUIX data, and the dark WinForms submenu theme.
- Use owner-bound submenu collections and explicit handler cleanup when switching repeatedly between folder and script items. Static validation completed; interactive 3ds Max verification pending.

## 2026-11-21 — 1.266

- Keep **ADD TO GROUP > {saved groups}, NEW GROUP** and **ADD TO TOOLBAR > {custom toolbars}, NEW TOOLBAR** as independent SCRIPTS context submenus for script leaves. These commands assign individual scripts to user groups or to single toolbar buttons, respectively.
- For directory items, always retain the individual-script **ADD TO TOOLBAR** targets and place **ADD TO TOOLBAR AS GROUP > {custom toolbars}, NEW TOOLBAR** at the bottom of the same submenu. Both target lists are available whether the folder already has a saved group or not.
- When an AS GROUP target is chosen, reuse the exact saved folder group or create a dedicated dynamic folder group. Roll back a newly created group when toolbar creation is cancelled or fails; preserve existing user groups and toolbar buttons.
- Preserve dark .NET submenu styling and avoid detaching the persistent third-level menu item by inserting individual toolbar targets before it.
- Source v1.266; regression suite v1.235 updates part 71 with script, grouped-folder, and ungrouped-folder menu assertions. Static checks passed; live 3ds Max verification is pending because the MCP bridge session terminated.

## 2026-11-21 — 1.265

- Fix runtime `Type error: Call needs function or class, got: undefined` at the former line 7140 when `clearToolbarSubmenu remove_group:true` invokes `clearToolbarGroupSubmenu` before its struct method has been initialized. Define the nested-group cleanup method before its parent cleanup caller, retaining the same behavior and handler cleanup.
- Add regression test v1.234 / part 72 for direct nested-group cleanup and rebuilding the SCRIPTS context menu. Preserve v1.264 toolbar hierarchy, persistent group dialogs, and saved groups/INI/CUIX.

## 2026-11-20 — 1.264

- Place **ADD TO TOOLBAR AS GROUP** inside the existing folder **ADD TO TOOLBAR** popup instead of on the right-click root. For folders without a saved group, ADD TO TOOLBAR continues listing individual toolbar targets and NEW TOOLBAR; for folders with an exact saved group, the popup contains only **ADD TO TOOLBAR AS GROUP > {toolbars}, NEW TOOLBAR**, adding a single dynamic group button.
- Preserve folder CREATE GROUP / DELETE GROUP switching, individual-script menus, root GROUP MANAGER, dark popup styling, group-dialog persistence and all existing Toolbar-Creator actions. Rebuild and dispose nested ToolStripItemCollections in owner order to avoid stale .NET wrappers; evaluate intended menu availability from saved-group state rather than WinForms Visible (which is false before the context menu opens). Recover when MAXScript detaches the third-level group item from its owner during alternating menu rebuilds. Dispose nested menu items through the root menu on teardown to avoid duplicate .NET collection registration.
- Main source v1.264; test suite v1.233, part 71 covering grouped, ungrouped and script-item menu nesting without altering user INI or CUIX.

## 2026-11-20 — 1.263

- Switch SCRIPTS folder-item RMB menu by whether an explicitly saved single-folder user group matches the clicked folder's exact normalized path. Ungrouped folders display **CREATE GROUP** and **ADD TO TOOLBAR** (individual visible descendant scripts); grouped folders display **DELETE GROUP** and **ADD TO TOOLBAR AS GROUP** (one saved-group toolbar button).
- CREATE GROUP uses the existing editable name dialog and stores one dynamic directory reference. DELETE GROUP keeps confirmation and removes only the matching saved INI group; never delete scripts or physical directories. Do not infer existence from a matching group name, a broader ancestor, or arbitrary group membership.
- Script-file right-click menus are unchanged. Group toolbar assignment no longer implicitly creates a group; it requires the folder group to exist. Keep GROUP MANAGER, group-dialog persistence, and all other context actions intact.
- Main source 1.263; regression suite 1.232, part 70. Folder-state and runtime tests are separate from actual CUIX writes.

## 2026-11-20 — 1.262

- Keep explicitly group-loaded dialogs alive when the Script-Manager UI is closed, restarted through F1/RESTART, or the manager script is reloaded. Organizational HOST dialogs keep their existing cleanup behavior.
- Track group dialog ownership separately, preserve the currently embedded rollout instances, host-script references and title-button reload behavior across manager instance replacement. Maintain unique generated host-rollout identifiers and remove the persistence marker only when the group dialog itself closes or is explicitly rebuilt.
- Update the previous-dialog cleanup guard to allow intentional live group dialogs. Live 3ds Max smoke test: an empty group and a group with one embedded test rollout both survived manager hide and version reload; temporary test dialog was removed afterwards.
- Main source v1.262; regression suite v1.231 (part 69). Preserve all saved user groups and existing toolbar definitions.

## 2026-11-20 — 1.261

- Add folder-only **ADD TO TOOLBAR AS GROUP** beside **ADD TO TOOLBAR** in the SCRIPTS right-click root. Its dark submenu lists existing managed toolbars and **NEW TOOLBAR**, while individual script right-click menus remain unchanged.
- Save or reuse a user group containing one dynamic reference to the clicked folder, proposing its name through the existing category/parent-folder naming rule, then append a **single group toolbar button** using the existing `__SCRIPT_MANAGER_GROUP__` reference format. Newly discovered scripts in the folder are resolved at group-load time instead of creating individual buttons. Do not overwrite a same-named group belonging to a different folder; use a numbered unique name if necessary.
- Preserve existing toolbar buttons and skip duplicate group references. Roll back a newly created group if toolbar creation is cancelled or the toolbar write fails. Keep the existing individual-script ADD TO TOOLBAR action unchanged.
- Main source v1.261; regression test v1.230 (part 68) and updated root-menu item count/positions. Toolbar creation is not exercised by the non-destructive regression test.

## 2026-11-20 — 1.260

- On SCRIPTS **folder** right-click menus, replace **ADD TO GROUP** with **ADD TO TOOLBAR**. Script-file menus retain both submenus; **GROUP MANAGER** remains available in the root.
- Folder **ADD TO TOOLBAR** lists existing custom toolbars and **NEW TOOLBAR**. Adding a folder collects its currently displayed descendant scripts as individual toolbar buttons, deduplicates existing buttons, and saves one CUIX update. Creating a toolbar starts with those same scripts; folder filters are respected, and no user groups are created or deleted.
- Main source 1.260 and regression suite 1.229 update folder/menu tests. Static verification passed; live 3ds Max UI and CUIX writes require testing.

## 2026-11-20 — 1.259

- Enable **ADD TO GROUP** on SCRIPTS folder-item right-click menus, allowing a clicked folder to be added to an existing saved group as a dynamic directory reference, or used to seed **NEW GROUP** with its folder/category name proposed.
- Add folder-only **ADD TO GROUP → DELETE GROUP → {saved group}** with explicit confirmation; deleting removes only the selected `UserGroup|...` INI section and never deletes scripts, directories, or toolbar definitions. Existing script-item menus remain unchanged. Rebind the parent .NET submenu collection after constructing DELETE GROUP so NEW GROUP stays in the correct submenu.
- Harden cross-version reload after nonfatal .NET menu disposal warnings: proceed only when every old manager and hosted dialog can be verified closed; retain the error when any dialog remains open or cannot be inspected. Preserve existing UI state persistence.
- Main source advances to 1.259; regression test to 1.228 (new part 66). Static and live verification status reported separately.

## 2026-11-20 — 1.258

- Restrict **EXPAND ENABLED** to SCRIPTS **folder** right-click menus. Script-file right-click menus no longer show this action; its folder-only expansion handler is unchanged.
- Hide the separator after **OPEN IN EXPLORER** for script-file selections to avoid an empty expansion section and adjacent separators. Preserve the final divider before **ADD TO STARTUP SCRIPTS / REMOVE FROM STARTUP SCRIPTS**.
- Advance production to v1.258 and regression tests to v1.227. Test both script and folder menu visibility. Source-level checks passed; interactive UI confirmation pending.

## 2026-11-20 — 1.257

- Reorder SCRIPTS TreeView right-click root commands into five sections: LOAD GROUP / LOAD SCRIPT; ADD TO GROUP / ADD TO TOOLBAR; GROUP MANAGER / OPEN IN EXPLORER; COLLAPSE / COLLAPSE ALL; EXPAND / EXPAND ALL / EXPAND ENABLED; final standalone startup action.
- Rename visible **OPEN GROUP** to **LOAD GROUP** without changing the group-loading handler or script loading behavior. Add three root separators, preserving the existing dark theme, and dynamically hide dividers that would be empty or adjacent for folder vs. script selection.
- Update regression test suite to v1.226 / project v1.257 (menu root ordering, all five separators, submenu refresh and root-only GROUP MANAGER). Preserve existing source scripts and saved settings. Static checks passed; live UI validation pending.

## 2026-11-20 — 1.256

- Correct NEW GROUP / NEW TOOLBAR naming for canonical tool subfolders: `...\MODIFIER-STACK\Modifier-Manager\Modifier-Manager.ms` proposes **MODIFIER-STACK**, not `Modifier-Manager`.
- Skip the containing folder when it is a canonical tool directory (`<FolderName>.ms` or its versioned variant). Scripts directly inside a category still use their containing folder. Multi-selection continues to use the closest shared category; user can edit the suggestion.
- Preserve all group/toolbar creation and existing naming validation. Static source checks passed; native 3ds Max runtime verification pending.

## 2026-11-20 — 1.255

- Pre-fill **NEW GROUP** and **NEW TOOLBAR** names with the selected tool's immediate parent folder name. For group creation from several scripts in different subfolders, propose their nearest shared parent folder.
- Apply the same suggestion when creating a toolbar from a selected user group. Keep the rename dialogs editable, reject invalid names as before, and retain the existing fallback when no folder can be derived.
- Updated original `Script-Manager.ms` and saved `versions/Script-Manager_1.255.ms`. Source readback verified; 3ds Max UI regression test pending.

## 2026-11-20 — 1.254

- Move **GROUP MANAGER** into the SCRIPTS right-click root menu immediately before **OPEN IN EXPLORER**; remove both prior submenu entries from **ADD TO GROUP** and **ADD TO TOOLBAR**.
- Keep its existing dialog-opening handler and dark-menu styling.

## 2026-11-20 — 1.253

- Repair SCRIPTS right-click **ADD TO TOOLBAR** and **ADD TO GROUP** submenus. MAXScript can hold detached .NET `ToolStripItemCollection` wrappers after another submenu is created; refresh from each actual parent submenu before modifying the children. Initialize both collections before first refresh.
- Restore **GROUP MANAGER** as the first command in both submenus, preserving custom toolbar and saved-group entries, NEW TOOLBAR and NEW GROUP. Move **ADD TO STARTUP SCRIPTS / REMOVE FROM STARTUP SCRIPTS** to the last root-menu position.
- Retain 1.252 loaded-script host slot widening and formatted rollout titles. Regression test 1.224 adds part 65 for repeated submenu rebuilding and STARTUP ordering; 3ds Max 2026 live menu-state checks passed.

## 2026-11-20 — 1.252

- Widen the loaded-script host `sr_tools` slot by 32 px and shift it 16 px left in both the original dynamic UI declaration and resize layout. Keep the host width, title button and saved geometry unchanged.
- Format hosted script rollout captions as `——— {original rollout title} ———`, stripping a trailing numeric `| vX.Y` suffix. Re-embedding remains idempotent; source rollouts, filenames, INI keys, script execution and standalone dialogs are untouched.
- Regression suite 1.223 adds part 64 for title cleanup, consistent decoration, slot creation and resize wiring. Native runtime validation pending.

## 2026-11-20 — 1.251

- Add **ADD TO GROUP** to the SCRIPTS item right-click menu, parallel to **ADD TO TOOLBAR**. Populate its dark submenu dynamically from saved USER GROUPS and provide **NEW GROUP** at the bottom.
- Add the right-clicked script to the chosen group while retaining existing members, ignoring duplicates, and preserving saved script checkbox modes and toolbar membership. Newly created groups start with the selected script. Group toolbar buttons resolve the updated INI membership on their next run.
- Bump Script-Manager to 1.251 and regression suite to 1.222 (part 63). Runtime verification in 3ds Max remains pending.

## 2026-11-20 — 1.250

- Rename visible GROUP LOADER to GROUP MANAGER in the SCRIPTS → ADD TO TOOLBAR submenu, dialog caption, refresh title, confirmation dialogs and diagnostics.
- Keep internal functions, UI module filename, group data and toolbar behavior unchanged. Regression test 1.221.

## 2026-11-19 — 1.250

- Rename the visible **GROUP LOADER** action to **GROUP MANAGER** in SCRIPTS → ADD TO TOOLBAR (first submenu item), native dialog caption, title/refresh button, confirmation dialogs and diagnostics.
- Keep internal group-loader function names and separate `Script-Manager-Group-Loader-UI.ms` module filename unchanged for compatibility. No changes to group definitions, toolbar actions, storage, or dialog layout.
- Update Script-Manager UI version to 1.250 and regression tests to 1.221.

## 2026-11-19 — 1.249

- Move **GROUP LOADER** from the SCRIPTS right-click root menu into the first position of **ADD TO TOOLBAR**. Place a separator before existing toolbar names; keep **NEW TOOLBAR** as the final submenu item.
- Keep **ADD TO TOOLBAR → GROUP LOADER** available when right-clicking folders and scripts. Folder selections show only GROUP LOADER; script selections retain toolbar assignment and creation.
- Reuse the cached .NET submenu collection and existing GROUP LOADER click handler. Regression test 1.220 checks order, separator, repeated menu rebuilds, and folder/script selection. UI version is 1.249.

## 2026-11-19 — 1.248

- Repair native Customize User Interface rename refresh after subsequent toolbar renames. Toolbar-Creator backend 0.16 removed `sync_live` and was silently reading stale CUIX metadata even though Script-Manager requested `listManagedScriptToolbars sync_live:true`.
- Toolbar-Creator backend 0.17 / shared project 0.33 restores the explicit live synchronization API, calls native `cui.saveConfig()` before reading current managed-toolbar names, and uses the actual CUI `name` attribute rather than interpreting the MacroScript filename as a title.
- Script-Manager requires backend 0.17 so older loaded code is replaced. If native CUIX retains old and new toolbar entries with identical action IDs, the toolbar list displays the most recent entry without deleting either toolbar. Existing buttons remain associated by stable MacroScript action IDs. A two-successive-renames regression test and live-sync contract check were added in test suite 1.219; no existing toolbar is automatically renamed.

## 2026-11-19 — 1.247

- Display the exact loaded Script-Manager implementation version in the main dialog title and REFRESH / RESTART title button. Do not derive this label from a previously registered project version.
- Show the same version in the separately maintained GROUP LOADER dialog title and its REFRESH title button. Both labels are calculated when the UI module loads, so no version text needs manual editing on future releases.
- Replace obsolete hard-coded v1.244 UI expectations in the regression test with checks derived from the current file version; add read-only part 61 for both dialog titles. No group/toolbar behavior or dialog geometry changed.

## 2026-11-19 — 1.246

- Detect native **Customize User Interface → Toolbars → Rename** edits when the Script-Manager toolbar lists refresh. Explicit UI refresh uses `cui.saveConfig()` to synchronize the active CUIX before reading names; no temporary CUIX is activated.
- Toolbar-Creator backend v0.15 / project 0.27 reads the native `name` attribute (with `objectName` fallback) and resolves renamed toolbars by either attribute. Locate the original generated MacroScript through the unchanged action IDs, so changing a title does not break button readback or group assignment.
- Do not rename or regenerate existing MacroScript files just to display a native rename. Reject ambiguous/mixed action mappings rather than overwriting buttons. Preserve existing toolbar content, groups, CUIX operations, and previous versions. Regression test v1.217 adds part 60 for native-rename metadata and generated MacroScript action-ID matching.

## 2026-11-19 — 1.245

- Fix missing **GROUP LOADER** in the SCRIPTS right-click menu. MAXScript could return a different .NET `ToolStripItemCollection` wrapper on repeated `ContextMenuStrip.Items` accesses, leaving the first item unattached.
- Cache the root context-menu Items collection exactly once during construction, just like the existing ADD TO TOOLBAR submenu. Reuse the cached collection for every menu item and clear the reference during teardown, preventing the repeated collection-wrapper exception on rebuild.
- Regression test 1.216 adds part 59: rebuild the menu twice and confirm GROUP LOADER is item zero and remains available. Preserve all existing menu commands, GROUP LOADER UI, and custom toolbar behavior.

## 2026-11-18 — 1.244

- Add **NEW TOOLBAR** after a dark separator at the bottom of SCRIPTS → ADD TO TOOLBAR, even when no custom toolbars exist. The action asks for a toolbar name and creates a Toolbar-Creator-managed toolbar initialized with the clicked script.
- Add **NEW TOOLBAR** to the separate, vertically resizable GROUP LOADER UI. The action initializes a new toolbar with the selected user-defined group; without a group selection, it initializes with the Script-Manager script so a new toolbar can still be created. Refresh the toolbar list and select the result.
- Reuse Toolbar-Creator `manageScriptToolbar #create` (never overwrite an existing toolbar). Keep existing custom toolbars and script-mode settings unchanged. Regression test v1.215 adds non-destructive part 58; live CUIX write/toolbar-button interaction remains to be verified.

## 2026-11-18 — 1.243

- Integrate GROUP LOADER user-defined groups with existing Toolbar-Creator custom toolbars. Select one user group and one toolbar, then ADD SELECTED GROUP TO TOOLBAR to append exactly one group button, preserving the existing buttons and their order. Multiple group buttons can share a toolbar; duplicates are ignored.
- Toolbar-Creator backend 0.14 recognizes explicit `__SCRIPT_MANAGER_GROUP__|<manager>|<group>` references, generates a MacroScript for each group button, and retains `target_script_path` metadata for toolbar readback and later edits. Individual script-button behavior remains unchanged.
- Clicking a group button reloads current group members from `script_manager.ini` and opens them in a single shared host dialog without changing OFF/HOST/DIRECT modes. GROUP LOADER can also resolve group buttons when loading a toolbar as one group.
- Keep GROUP LOADER UI in `Script-Manager-Group-Loader-UI.ms`, preserving its vertical resizing and all v1.242 multi-selection improvements. Add non-destructive regression part 57; runtime testing required for CUIX changes.

## 2026-11-17 — 1.242

- Add Ctrl-click toggle, Shift-click visible range and Ctrl+Shift-click add-range selection to both SOURCES and SCRIPTS. Use independent highlighted row sets; checkbox image clicks still perform their original source-enable and SKIP/HOST/DIRECT actions.
- Display intermediate checkbox glyph for SOURCES parents with enabled descendants but no explicit enable of their own. Explicitly enabled parents remain checked. No source INI values are rewritten by hierarchy synchronization.
- SCRIPTS parent folders show unchecked when no descendants are active, checked when every descendant is HOST/DIRECT, and intermediate when only some descendants are active. DIRECT script leaves retain their existing indeterminate glyph. EXPAND ENABLED includes partially active branches.
- GROUP LOADER's ADD TREE SELECTION accepts all highlighted SCRIPTS files/folders instead of only the WinForms native SelectedNode. Selection is temporary and does not change script loading modes.
- Keep VERSIONED FILES, CLEAN SCRIPTS and COLLAPSE DIRS on one horizontal row in SHOW; adjust SHOW content height to fit a single row.
- Regression test 1.213 adds part 56 and updates part 6 parent-state expectations. Earlier versions retained.

## 2026-11-17 — 1.241

- Correct GROUP LOADER's first list: **USER GROUPS** lists only explicitly defined `[UserGroup|name]` INI sections, not the directory hierarchy. Ordinary folder **OPEN GROUP** remains separate.
- Add NEW GROUP, ADD TREE SELECTION and DELETE GROUP to the separate resizable GROUP LOADER UI. Group members can be scripts or folder references across directories; saved folders resolve current script contents at load time. Name-only empty groups are supported until members are added.
- Persist each group's ordered members relative to ROOT PATH when possible; keep invalid/missing-path previews and prevent loads that would replace an existing host with an invalid group. Leave toolbar integration and script load-mode settings untouched.
- Regression v1.212 adds part 55 for explicit-only discovery, INI round trip, dynamic folders and deletion. Verify interactive dialog in 3ds Max before adopting as stable.

## 2026-11-16 — 1.240

- Extract GROUP LOADER rollout and all UI event handlers into `Script-Manager-Group-Loader-UI.ms`, keeping group discovery and script-loading backend in `Script-Manager.ms`.
- Make GROUP LOADER vertically resizable with a locked width. Both listboxes grow/shrink with the dialog, preserving their action buttons and bottom preview/status alignment.
- The manager resolves the UI module from its own folder or the parent of `versions/` for versioned snapshots. Missing-module and creation errors go to the MAXScript Listener.
- Regression v1.211 adds part 54 for module separation and dynamic list layout.

## 2026-11-16 — 1.239

- Continue GROUP LOADER on the current v1.238 baseline. Keep separate SCRIPTS-tree and Toolbar-Creator lists with shared-dialog group loading.
- Exclude empty tree folders, show each group's visible script count, and provide an active-source preview and enabled load button only when the selection is usable.
- Restore the selected tree group or toolbar on REFRESH; switching lists clears the other selection. The independent dark title/refresh button and load actions remain.
- Resolve toolbar buttons in original order, deduplicate identical paths, and explicitly report missing/unsupported files before replacing an existing group dialog. No script checkbox state or toolbar membership is modified.
- Regression v1.210 adds part 53 for non-executing group selection/refresh and toolbar preview. Runtime validation performed separately from any script execution.

## 2026-11-16 — 1.238

- Darken the ADD TO TOOLBAR popup surface, including its empty-state row; preserve the v1.237 cached submenu collection fix.
- Add SCRIPTS right-click > GROUP LOADER with separate script-tree group and custom-toolbar lists, refresh, double-click and load buttons.
- Load toolbar scripts in button order into a shared dialog across folder hierarchies, resolving portable paths and skipping duplicates. Validate paths before replacing a group dialog.
- Reuse the existing shared group loader without changing stored script modes or toolbar membership.

## 2026-11-15 — 1.237

- Fix SCRIPTS context-menu `ADD TO TOOLBAR` .NET error at former line 6006: `ToolStripItemCollection` could be wrapped multiple times by repeatedly accessing `DropDownItems`.
- Cache the toolbar submenu collection once when the SCRIPTS context menu is constructed; reuse it for item creation, clearing, and handler disposal, and release the cached reference when the menu is destroyed. Preserve toolbar behavior and all unrelated v1.236 features.
- On upgrade from 1.236, skip only the old broken submenu wrapper during old-manager teardown; the parent menu still disposes the submenu.
- Regression test v1.209 / part 52 repeatedly adds and clears submenu items. Live 3ds Max validation pending.

## 2026-11-15 — 1.236

- Add SCRIPTS item context menu: ADD TO TOOLBAR > Toolbar-Creator custom toolbar names. Refresh names when opening the menu.
- Append the clicked script through Toolbar-Creator, preserving existing buttons and skipping duplicate paths. Load the backend without opening its UI.
- Runtime validation pending: MCP Python execution is blocked by safe mode.

## 2026-11-15 — 1.235

- Remove repeated right-side width deductions from PRESETS, OPTIONS, SHOW, IGNORE, SOURCES and SCRIPTS. Reserve the outer scrollbar once and only when required. Expand nested slots and their controls within the existing dialog.
- Keep the BROWSE vertical offset and IGNORE horizontal position.

## 2026-11-15 — 1.234

- Give SOURCES and SCRIPTS more width when the loader fits without a vertical scrollbar. Keep full scrollbar clearance when it needs to scroll.

## 2026-11-15 — 1.233

- Widen the SOURCES and SCRIPTS trees by another 16 px. Add the matching space to the dialog while preserving the OPTIONS layout.

## 2026-11-15 — 1.232

- Align the IGNORE field with its label and reserve room for the nested rollout gutter and side margins.

## 2026-11-15 — 1.231

- Apply the additional 16 px to the subrollouts as well as the lists. Keep the BROWSE and IGNORE offsets.

## 2026-11-15 — 1.230

- Widen the SOURCES and SCRIPTS lists by 16 px. Add the same width to the main dialog and loader to retain scrollbar clearance.
- Move BROWSE up 4 px and the IGNORE field left 8 px.

## 2026-11-15 — 1.229

- Add 16 px directly to the nested SHOW and IGNORE slots at creation and during layout.

## 2026-11-15 — 1.228

- Widen the loader slot and its nested SHOW and IGNORE slots by 16 px inside the existing 352 px dialog. Use 4 px outer loader margins and retain the scrollbar gutter.

## 2026-11-15 — 1.227

- Widen the main dialog and loader by 16 px so subrollouts gain 16 px with the existing scrollbar clearance.

## 2026-11-15 — 1.226

- Reserve the Windows scrollbar width plus padding inside the Script-Manager loader. Size nested OPTIONS panels and their controls to the remaining width.
- Move COLLAPSE DIRS to a second row in SHOW so the label stays visible.

## 2026-11-15 — 1.225

- Read checked SOURCES once per SCRIPTS state refresh and reuse resolved group hosts by script directory. Group coloring previously repeated source INI reads for every script row.
- Keep the existing second checked ancestor rule and palette inheritance. Clear the temporary lookups after each refresh so subsequent checkbox and color changes take effect.
- The reported v1.224 baseline was 27,891 ms for node states across 433 scripts. Static checks passed; live timing is pending.

## 2026-11-14 — 1.224

- Restyle GROUP COLOR palette buttons with a consistent dark `RGB 55,55,59` background and bold Segoe UI font; paint palette RGB only on button **foreground text**, not on button backgrounds. CLEAR also follows the dark button style.
- Leave selected group colors, storage, script tree coloring, hosted-dialog titles, palette service, and 640/1280 px TreeView dimensions unchanged. Regression test v1.208 adds part 51. v1.223 retained.

## 2026-11-14 — 1.223

- Reduce SOURCES TreeView from 1280 to **640 px** and its rollout content height from 1292 to 652; retain SCRIPTS at 1280 px.
- Add **GROUP COLOR** to the SOURCES parent-folder context menu. Open a swatch-button dialog using the canonical `SCRIPTS/CODEBASE/Globals/ColorPaletteService.ms` palette, excluding transparent colors and providing a CLEAR choice. The source palette and scene/materials are unchanged.
- Save group color by numeric palette ID under `[GroupColors]` in `script_manager.ini`. Child groups inherit a parent assignment unless they have their own.
- Reapply group color to SCRIPTS tree-item text independent of the tri-state loading mode and to the custom title-button font of existing/new hosted group dialogs. Unassigned groups remain neutral. Preserve the dialog's native system caption style.
- Version source 1.223 and regression tests 1.207 (part 50 and updated menu/size expectations). Previous v1.222 and stable v1.188 retained.

## 2026-11-14 — 1.222

- Update from the latest canonical Script-Manager v1.221 source, preserving its existing functionality and unrelated changes.
- Change both SOURCES and SCRIPTS TreeViews to 1280 px in initial declarations and the live resize layout. Adjust their rollout content heights (1292/1344), cached loader height (2958), and SCRIPTS minimum tree-height bookkeeping.
- Keep the 1970 px default/2000 px max manager dialog height and its scrollable subrollout. Regression v1.206 adds part 49 for both initial and resized TreeViews. Stable v1.188 remains untouched.

## 2026-11-12 — 1.211

- Change OPTIONS → SHOW / **CLEAN SCRIPTS** into native tri-state checkbox (`triState:0/1/2`): 0 unchanged normal discovery; 1 previous strict clean view; 2 retains the matched canonical file when present, otherwise exposes scripts in folders with no same-name canonical script.
- Cycle 0 → 1 → 2 → 0 explicitly through the checkbox event. Preserve legacy Boolean helpers, existing `CleanScriptsOnly=0/1` INI values, and add `2` to the same setting. No changes to startup commands, load error diagnostics, or other filters.
- Production v1.211; regression suite v1.205 with part 48 covers three discovery modes, case-insensitive matching, version-only fallback, migration, UI wiring, and cycle. Stable v1.188 unchanged. Static tests completed; live 3ds Max testing pending.

## 2026-11-12 — 1.210

- For SCRIPTS TreeView manual loads, emit the native MAXScript exception source path, source line and complete stack trace in the Listener, and rethrow the original exception after the v1.209 failure dialog. Non-exception load failures also throw a descriptive error after the dialog.
- Restore ScriptManagerIntegration runtime modes and the manager busy flag before rethrowing; retain legacy false/error returns for configured HOST/DIRECT loads and direct helper calls that do not opt in. No changes to startup scripts or saved modes.
- Regression test v1.204 adds part 47 for rethrow and cleanup. Static checks only until 3ds Max MCP runtime validation. Stable v1.188 and v1.209 snapshot untouched.

## 2026-11-12 — 1.209

- Add a script-leaf SCRIPTS TreeView right-click command that toggles **ADD TO STARTUP SCRIPTS** / **REMOVE FROM STARTUP SCRIPTS**. The command is hidden on folders and dynamically follows the selected script's startup status.
- Create an individual `Script-Manager-Autostart-*.ms` launcher in 3ds Max's `#userStartupScripts` folder, referencing the original `.ms` / `.mcr` / `.mse` file. Deterministic SHA-256-based filenames avoid collisions between similarly named tools. Removing startup removes only the verified Script-Manager-owned launcher; it does not modify the original or the independent preset STARTUP loader.
- On double-click or RMB **LOAD SCRIPT** failure, keep the existing `[Script-Manager][TREE LOAD] FAILED` Listener trace and also display a native error message with the action, file path and captured load error/exception. Successful loads remain silent.
- Production v1.209, regression suite v1.203 with part 46 for isolated launcher add/remove, collision and foreign-file protection, menu wiring, and failure-dialog wiring. Stable v1.188 and previous v1.208 remain unchanged. Static tests completed; live 3ds Max validation pending.

## 2026-11-12 — 1.208

- Move the former **SHOW & IGNORE** subrollout out of SCRIPTS and into **OPTIONS**, separating it into two independently collapsible sections: **SHOW** (VERSIONED FILES / CLEAN SCRIPTS / COLLAPSE DIRS) and **IGNORE** (persistent mask field).
- Correct the subrollout ownership: `OPTIONS.sr_show` and `OPTIONS.sr_ignore` own their respective child rollouts. SCRIPTS has no configuration subrollout and restores its original action/FILTER/1032 px TreeView positions. Resize OPTIONS dynamically as either section expands or collapses.
- Preserve filter handlers and persistent values. Store independent `[Loader] ShowOpen` and `[Loader] IgnoreOpen` flags, falling back to `[Loader] ShowIgnoreOpen` for existing installations. Advance production to 1.208 and regression suite to 1.202. Stable 1.188 unchanged.

## 2026-11-11 — 1.207

- Nest the collapsible **SHOW & IGNORE** rollout inside SCRIPTS, above LOAD SCRIPTS / CREATE TOOLBAR / SAVE UI and the live FILTER. Remove its former separate top-level slot; the loader now has four top-level rollouts.
- Preserve the checkboxes, IGNORE behavior, and saved expanded state. Dynamically shift the buttons, filter, and 1032 px TreeView as SHOW & IGNORE expands/collapses without reducing tree height. Production v1.207; regression test v1.201; v1.206 preserved.

## 2026-11-11 — 1.206

- Append the active manager version to the main **REFRESH \\ RESTART** .NET title button using the existing `script_manager_version_text`. The button's styling, LMB refresh, and RMB restart are unchanged. Preserve v1.205 as a versioned snapshot.

## 2026-11-11 — 1.205

- Add a live, case-insensitive **FILTER** edit field above the SCRIPTS TreeView. Match discovered script filenames and parent folder paths; matching folders expose all contained scripts. Clear the field to restore the full tree.
- Rebuild only the visible .NET TreeView from existing discovery arrays on each edit; do not rescan directories, fileIn scripts, save the filter, or modify HOST/DIRECT/SKIP modes. Expand matching parent paths temporarily and protect persisted folder-open settings while searching.
- Keep the existing 1032 px script TreeView and resize its containing SCRIPTS rollout. Advance production to v1.205, regression test to v1.200 with part 45, and preserve stable v1.188. Static tests passed; live 3ds Max validation pending.

## 2026-11-11 — 1.204

- Move **VERSIONED FILES**, **CLEAN SCRIPTS**, **COLLAPSE DIRS**, and the **IGNORE** edit from the SCRIPTS rollout into a separate collapsible **SHOW & IGNORE** rollout, positioned between SOURCES and SCRIPTS. Keep checkbox callbacks, saved filter values, and IGNORE-on-REFRESH behavior unchanged.
- Move the 1032 px SCRIPTS TreeView upward beneath the existing LOAD SCRIPTS / CREATE TOOLBAR / SAVE UI row. Add `[Loader] ShowIgnoreOpen` independent rollout-state persistence, expanded by default, and include the fifth rollout in creation, cleanup, sizing, and state-save paths.
- Advance production to v1.204 and regression test to v1.199. Add test part 44 and update earlier rollout/checkbox assertions. Local static layout tests passed; 3ds Max runtime verification remains pending because the MCP connection timed out. Stable v1.188 unchanged.

## 2026-11-08 — 1.203

- Hide SCRIPTS folders that have no `.ms`, `.mcr`, `.mzp`, or `.mse` files recursively, retaining parents of script-containing descendants and pruning blank/text-only branches by default. Honor existing IGNORE and `.git` exclusions.
- Cache directory-presence checks in one native dictionary per discovery pass; apply regardless of COLLAPSE DIRS setting. Do not change execution, displayed script file types, saved modes, SOURCES or tree expansion behavior. `.mzp` contributes to folder qualification only.
- Regression v1.198 adds part 43 for nested scripts, non-script branches, MCR/MSE/MZP, `.git`, and live TreeView population. Stable v1.188 untouched. Static verification only; 3ds Max runtime test pending.

## 2026-11-08 — 1.202

- Add unconditional `[Script-Manager][TREE LOAD]` Listener tracing for the SCRIPTS TreeView's double-click and RMB `LOAD SCRIPT` paths. Every attempted load reports action, selected item, exact file path, exists state, saved SKIP/HOST/DIRECT mode, forced standalone mode, and OK/FAILED result.
- Report explicit skip reasons for missing/unsupported files, manager-busy and manager-package blocks, and retain `fileIn` exceptions and underlying nested-load errors. No execution mode, script discovery, or fileIn quiet setting changes.
- Test v1.197 adds part 42 to verify trace wiring and rejected/missing/exception-throwing files; fixes a pre-existing malformed path literal in part 35. Stable v1.188 stays unchanged. Live 3ds Max load diagnosis pending.

## 2026-11-08 — 1.201

- Replace Script-Manager's floating-position -1/-1 workaround with the pre-registration save/restore geometry from the working CODEBASE `Registered-Dialog-Position-Offset-Fix` v0.04: raw create position = saved registered raw X/Y - ([6,-2] + [6,29]); pre-registration adjustment = +[6,-2]. Apply to main and host floating dialogs before CUI registration; left/right docking unchanged.
- Prevent child-rollout removal and unregister-time movement/resize callbacks from overwriting the position saved before destroy. Main moved/resized handlers now check `is_destroying_manager`; generated host handlers check `is_destroying_host`. Preserve INI keys, docking, dimensions, and existing position Listener output.
- Include pending v1.200 three-checkbox single-row layout with **VERSIONED FILES**, **CLEAN SCRIPTS**, **COLLAPSE DIRS**; saved filtering behavior remains unchanged.
- Tests v1.196 update part 34 geometry invariants and add part 41 callback/registration safety coverage. Static syntax and source tests passed; live repeated restart proof pending because MCP bridge is disconnected. Stable v1.188 and CODEBASE v0.04 untouched.

## 2026-11-08 — 1.200

- Rename the SCRIPTS filter checkboxes to **VERSIONED FILES**, **CLEAN SCRIPTS**, and unchanged **COLLAPSE DIRS**. Align all three on the same Y=42 row within the existing dialog width, with non-overlapping native checkbox controls.
- Do not change checkbox actions, saved INI keys, IGNORE/TreeView layout, or any script-loading behavior. Test v1.195 adds part 40 for labels, positions, and preserved handlers; stable v1.188 remains untouched.

## 2026-11-07 — 1.199

- Add **COLLAPSE DIRS** checkbox to SCRIPTS. Default ON keeps the previous compact tree; OFF exposes the complete discovered hierarchy including same-named tool directories. Persist the toggle in `[Filter] CollapseDirs` (0/1); toggling re-renders SCRIPTS immediately without filesystem discovery or script execution.
- Preserve checkbox states, real script file paths, existing expansion preferences, and the double-click-only load path. A folder with additional visible scripts or subdirectories is never flattened by the same-name shortcut.
- Add regression part 39 in test v1.194 for default, INI round-trip, ON/OFF rendering, multi-script preservation, and real leaf paths. Stable v1.188 remains unchanged. Live UI verification pending.

## 2026-11-07 — 1.198

- Restore **double-click** execution for `.ms` and `.mcr` filename labels in SCRIPTS. A single-click now only selects a row; checkbox image clicks still cycle the saved load mode.
- Bind `NodeMouseDoubleClick` and require left-button plus `Label` hit before calling the existing forced standalone loader. Folder nodes, `.mse` files, checkboxes, and non-label regions do not load scripts. RMB `LOAD SCRIPT` is unchanged.
- Regression test v1.193 revises part 35 for event wiring, label gating, and existing MS/MCR execution and exclusion cases. Source, docs, and tests advance to project 1.198; stable MVP v1.188 remains untouched. Live 3ds Max click test pending.

## 2026-11-02 — 1.197

- Lower Script-Manager main CUI dialog minimum height from 1970 to **1024 px** in `RegisterDialogBar minSize` and the INI-restored height validation. Default height remains 1970; saved heights 1024–2000 remain honored; values above 2000 still clamp to 2000.
- Hosted dialogs retain their independent 300 px minimum. The native SCRIPTS TreeView still has 1032 px of content; scrolling handles smaller manager windows. Dialog XY diagnostics and v1.196 expansion-state restoration remain intact.
- Regression suite v1.192 adds part 38; user-confirmed stable v1.188 remains unchanged. Live 3ds Max test pending.

## 2026-11-01 — 1.196

- Restore SCRIPTS folder expansion state on the first tree build from persisted `[ScriptTreeOpen]` instead of forcing all folders collapsed; unseen folders start collapsed. Suppress TreeView expand/collapse persistence while clearing/rebuilding/restoring its nodes. Test v1.191 adds part 37.

## 2026-11-01 — 1.195

- Instrument main and hosted dialog startup, registration, CUI restore, ready, and floating state save with `[Script-Manager][XY]` Listener entries: saved coordinates, actual screen coordinates reported by `getDialogPos`, and XY delta.
- Log main and hosted rollout `moved` callbacks even when geometry writes are suppressed, so late callback movement can be compared with the INI and registration stages.
- Preserve all current positioning/INI behavior; this version only diagnoses repeated +1 X/Y drift. Test v1.190 adds part 36. Stable v1.188 remains untouched.

## 2026-11-01 — 1.194

- SCRIPTS TreeView now direct-loads `.ms` and `.mcr` files on a single left-click on their filename labels. Reuse the forced standalone load path without changing SKIP/HOST/DIRECT mode or hosted dialogs.
- Checkbox image clicks still only cycle load mode; folder rows, disclosure controls, non-label areas, and `.mse` leaves do not execute.
- Unbind redundant `NodeMouseDoubleClick` event and ignore `Clicks > 1` from the regular click handler to prevent an additional direct load. Preserve the former helper API for compatibility.
- Regression test v1.189 adds part 35. Stable v1.188 remains untouched. Live verification in 3ds Max is pending.

## 2026-11-01 — 1.193

- Apply an explicit X−1/Y−1 pre-registration position to **floating** Script-Manager and hosted rollout dialogs to counter the user-observed 1-pixel move after CUI registration. The INI position remains the target/final position; docked dialogs are not offset.
- Pre-registration position verification uses the adjusted coordinates for both dialogs. Registered rollouts are never moved via `setDialogPos`.
- Regression test v1.188 adds part 34 for exact floating XY correction, docked no-op, and unchanged input. Stable v1.188 untouched. Static checks passed. A temporary dockable rollout compared with and without the pre-registration correction in live 3ds Max confirmed an exact 1px X/Y difference. Reopening the production manager/hosts is still unverified.

## 2026-10-29 — 1.192

- Fixed `Unknown property: "visible" in 3` in `updateScriptTreeContextMenuState`: the v1.191 separator setup stored the integer result of `Items.Add(separator)` instead of the actual .NET `ToolStripSeparator`.
- Keep explicit object references for both separators in each SOURCES/SCRIPTS context menu, adding them to the collection without replacing their stored object variables with the numeric index. The existing OPEN / COLLAPSE / EXPAND layout and conditional visibility are unchanged.
- Regression test v1.187 adds part 33 for all four typed separator references and both context-menu state updates. Stable baseline v1.188 is preserved. Static verification only; live 3ds Max test pending.

## 2026-10-29 — 1.191

- Group right-click menus in consistent **OPEN / COLLAPSE / EXPAND** order with visible separators in SOURCES and SCRIPTS. OPEN actions preserve context-specific visibility; selected script-file rows retain `EXPAND ENABLED` without unrelated branch-collapse commands.
- Restrict SOURCES discovery to directories containing `.ms`, `.mcr`, or `.mse` files at any depth, using a discovery-pass native dictionary cache. Source visibility is independent from SCRIPTS version, clean-only, and IGNORE filters.
- Exclude `.git` folders from both SOURCES and SCRIPTS recursion by default (even when user clears SCRIPTS IGNORE); preserve existing editable IGNORE values and `.git` default text.
- Regression v1.186 adjusts existing source visibility assertions and adds part 32 for menu layout and script-bearing subtree checks. Stable v1.188 untouched. Static checks only; live Max test not performed.

## 2026-10-28 — 1.190

- Disable load-mode text-color formatting in SCRIPTS TreeView: HOST, DIRECT, and SKIP rows all use the normal text foreground; existing tri-state checkbox glyphs, active-folder indicator, and bold folder labels remain intact.
- Keep `applyScriptTreeNodeColor` as a compatibility method that resets any previous colored text to neutral; remove now-unnecessary batch color-cache creation from the normal checkbox/state synchronization path, retaining the optimized hierarchy and updates.
- Regression test v1.185 adds part 31 for neutral formatting across HOST/DIRECT/SKIP and adjusts part 6 expectations. Stable MVP v1.188 remains untouched. Static validation only; 3ds Max runtime confirmation pending.

## 2026-10-28 — 1.189

- Preserve user-confirmed stable v1.188 unchanged. New development candidate 1.189 gives the visible SCRIPTS parent folder priority over the single-script same-name flattening shortcut.
- Pre-create the tree paths for all unflattened script rows before attaching any script leaves. When the raw parent folder is present in the node lookup, attach the script under it rather than flattening it outside the folder. This makes nesting independent of script discovery order.
- Reuse the existing native folder dictionary and TreeView BeginUpdate/EndUpdate optimization, retaining ROOT PATH, filters, saved modes, color caches, and load behavior.
- Regression test v1.184 adds part 30 for a same-name script with a forced visible parent, no duplicate file at the ancestor level, preserved flattening when the parent is absent, and restored TreeView state. Static verification only; runtime validation remains pending.

## 2026-10-28 — 1.188

- **STABLE MVP — user-confirmed 2026-10-28.** Version `1.188` is the new stable development baseline, superseding `1.153`. Preserve `Script-Manager_1.188.ms` unchanged and use the canonical v1.188 source as the base for subsequent development. This designation changes documentation only; source code, test code, and runtime settings are unchanged.
- `SHOW VERSIONED FILES` defaults to checked when its INI key is missing, while preserving explicitly saved OFF (`0`) and ON (`1`) states.
- Prevent startup/registration and restore-time move/resize callbacks from writing transient floating dialog positions back to INI, for both main and hosted dialogs.
- Before `cui.RegisterDialogBar`, correct any `getDialogPos` mismatch against the requested saved position using `setDialogPos`; avoid moving a registered dialog bar or hardcoding a guessed one-pixel offset.
- New tests 28/29 (test v1.183) check default filter persistence and geometry-restore guards. Runtime position behavior awaits 3ds Max verification.

## 2026-10-28 — 1.187

- Fixed the `Bad local thunk local member index when accessing local: requested_mask` REFRESH exception: the standalone IGNORE persistence helper was defined without a persistent `global` declaration, so runtime callbacks could reference an invalid fileIn-local thunk. Explicitly declare it before function definition.
- Fixed first-start loader showing only PRESETS: `script_manager_options_ui` was missing from the global rollout declarations although dynamically created OPTIONS is referenced after `execute`. Declare it explicitly alongside PRESETS/SOURCES/SCRIPTS.
- Also explicitly declared the three later-added .NET callback function slots (REFRESH MouseUp, startup loader Tick, OPEN GROUP) so they stay valid after file evaluation. Added counts/section flags to loader-construction failure diagnostics.
- Preserved 1.186 TreeView speed optimizations, ROOT PATH handling, script filter semantics, and group loading.
- Regression test v1.182/project 1.187 adds `partOfTest27` for global slots and fully constructed UI, retains cold-start and IGNORE tests, and fixes version-identity expectations in part 1. Static validation; live 3ds Max still needed.

## 2026-10-28 — 1.186

- Eliminated repeated full batch-dialog palette construction from each HOST row during SCRIPTS TreeView state/color synchronization. A single per-sync palette and native Dictionary of script-to-host paths now preserve identical colors without quadratic source/INI work.
- Moved TreeView `EndUpdate()` after checkbox/color synchronization to avoid per-node repaint while constructing the tree. Both render-only caches are discarded after synchronization, including failures.
- Added phase timing for folder nodes, script leaves, and state/color synchronization, to identify remaining bottlenecks from live Max timings. A failed state/color pass now correctly reports rendering failure instead of success.
- Test file advances to 1.181/project 1.186 with part 26 verifying sorted HOST palette parity, host lookup, and cache cleanup. Static checks only; the reported 13,554-ms render is the pre-fix baseline and no new runtime timing is claimed.

## 2026-10-28 — 1.185

- Fixed the v1.184 runtime error `Bad local thunk local member index when accessing local: mask_text` in `saveScriptIgnoreMask()` at its entry around line 1518.
- Moved IGNORE INI write/readback/active-state code to `scriptManagerPersistIgnoreMask()` outside the large `script_manager_v` struct method frame. `applyPendingScriptOptions()` uses that global function directly, while `saveScriptIgnoreMask` remains as a thin compatibility API.
- Added regression `partOfTest25()` for nonempty and empty IGNORE saving through the actual pending-control path and compatibility wrapper. Test file v1.180, project v1.185.
- Kept ROOT PATH, BROWSE, SOURCES, filtering, and hosted loading behavior unchanged. Static verification only; runtime execution in 3ds Max still needs confirmation.

## 2026-10-28 — 1.184

- User verified ROOT PATH persistence and SOURCES rendering in 1.183. Preserve those paths.
- Runtime evidence: discovery found 111 groups / 178 scripts, then SCRIPTS rendering failed with `No get_Item method found which matched argument list` before adding any script leaves.
- Replace the SCRIPTS folder-node, direct-script-count, and descendant-group Hashtables with native `Dictionary #string`, `HasDictValue`, `GetDictValue`, and `PutDictValue`. This removes .NET object-indexer binding from those render caches. SOURCES rendering is unchanged.
- IGNORE save/readback already succeeded in the supplied trace: execution reached SOURCES/SCRIPTS discovery, which happens only after the verified save returns true. Add an explicit `IGNORE saved and verified` Listener message including the actual INI path/value before rendering. No speculative persistence-format change.
- Test 1.179 retains indexed-versus-uncached display-path comparison and repeated folder-node lookup coverage, updated to the native dictionary contract; existing part 24 covers empty and nonempty IGNORE round trips.
- Static checks and upload readback are available; live post-fix execution remains unverified while 3ds Max MCP is disconnected.

## 2026-10-28 — 1.183

- BROWSE now commits the accepted ROOT PATH through the existing verified INI save and discovery pipeline after closing the folder dialog. SOURCES and SCRIPTS rebuild immediately; Cancel does not change the field. Typed ROOT PATH and IGNORE edits still commit with LMB REFRESH.
- Removed `isProperty` gates from declared rollout controls (ROOT PATH, IGNORE, trees, and preset controls). Access uses the actual declared controls after checking that their rollout exists; MAXWrapper property inspection no longer decides whether these UI controls are available.
- Missing IGNORE control now fails explicitly instead of silently saving the previous in-memory mask. Existing empty-mask handling and INI readback checks are retained.
- Restore ROOT PATH before attaching tree rollouts. Preserve rollout references on later loader-building failures so visible controls remain reachable for diagnostics and retry.
- Regression test 1.178 adds part 24 for accepted browse, root INI readback, both nonempty trees, empty and nonempty IGNORE save/reload, and restoration of isolated test settings.
- Audit: the supplied INI already contains both settings, including a root under the former C:\GoogleDrive location. This release does not replace user settings or infer a new root. Browse-only behavior is confirmed by source inspection; the runtime cause of the other symptoms is not yet proven.
- Validation: source/diff and lexical checks only. 3ds Max MCP returns `Session terminated`; the MAXScript suite and native BROWSE interaction have NOT been executed. Version 1.183 is a development candidate, not a runtime-confirmed stable release.

## 2026-10-28 — 1.182

- Corrected ROOT PATH persistence after moving Script-Manager: canonical `script_manager.ini` now lives beside `Script-Manager.ms`, shared across 3ds Max versions. If the repository INI does not yet exist, settings are copied once from the former `plugcfg` INI (the old file is not deleted).
- `loadSourceRootDirectory()` preserves the actual saved path even if the drive is temporarily unavailable rather than silently replacing it with the default. ROOT PATH is read from the instance-owned OPTIONS rollout; manual REFRESH fails visibly if that control is missing. Loader construction no longer reloads ROOT PATH a second time.
- Removed reliance on the deferred WinForms startup-timer callback: after dialog creation, docking, and UI message processing, initial discovery and all four child rollouts are completed synchronously. A cold opening no longer requires a restart to populate the TreeViews.
- For a freshly configured source root without enabled sources, enables first-level selectable SOURCES once; intentional all-off selections for an unchanged root are respected. When the root contains only terminal tool directories, script discovery includes those root children directly. Failure to write source checkboxes now reports the INI key/value instead of claiming success.
- Updated test version 1.177: local INI path, changed ROOT PATH save/reload with visible SCRIPTS entries, and two synchronous cold opens. Static inspection only; live 3ds Max execution is still pending.

## 2026-10-27 — 1.181

- Fixed the OPTIONS ROOT PATH input initialization after the 1.180 deferred rollout construction: ROOT PATH is now assigned only after the OPTIONS subrollout has been added and its native editText exists.
- Reduced ROOT PATH editText height from 24 to 16 px so it stays single-line, consistent with the SCRIPTS IGNORE input. Previously, pressing Enter could insert a newline and fail directory validation.
- Added an explicit missing-control diagnostic so failed rollout creation cannot silently claim success.
- Regression test `partOfTest23()` changes ROOT PATH using LMB REFRESH, verifies INI persistence, source discovery, and full rollout reload/readback, then restores the previous test root. The cold-start test also asserts ROOT PATH text matches the active root. Test version `1.176` / production `1.181`.
- Source and tests statically checked; live 3ds Max behavior still requires validation.

## 2026-10-27 — 1.180

- Deferred first-run `reloadScripts()` until the registered/docked manager dialog has returned to the WinForms message loop. The previous synchronous creation path could build nested rollouts before their parent UI had completed opening, leaving initial content blank until RESTART.
- Added a one-shot startup timer with cleanup on completion, close, and restart. Initial discovery, rollout construction, and optional startup-preset load now run in that deferred initialization path.
- Added cold-start regression `partOfTest22()` that opens the manager twice, confirms deferred construction, and asserts that PRESETS/OPTIONS/SOURCES/SCRIPTS and their TreeViews become available without using RESTART. Canonical test `1.175`, project `1.180`.
- Source lives at `G:\CODE\MAXSCRIPT\Script-Manager\`; canonical Drive file IDs remain unchanged. Live 3ds Max runtime verification is pending.

## 2026-10-25 — 1.179

- Routed both .NET `REFRESH \\ RESTART` button actions through one `MouseUp` dispatcher (LMB refresh, RMB version reload) to avoid a silent LMB action path.
- `handleManualRefresh()` now saves the edited SCRIPTS IGNORE mask before validating ROOT PATH, so an invalid root cannot prevent IGNORE persistence.
- REFRESH reports entry, busy/unavailable guards, save failures, and final scan counts to the MAXScript Listener instead of silently returning false.
- Added an isolated regression that edits IGNORE, first fails ROOT validation while verifying the INI write, then simulates a .NET LMB MouseUp and checks that SCRIPTS was filtered while SOURCES remained complete. Canonical test `1.174`, project `1.179`; live 3ds Max verification pending.

## 2026-10-25 — 1.178

- Added `OPEN GROUP` as the first SCRIPTS folder right-click item, hidden for script leaves. It collects visible nested script leaves beneath only the clicked folder.
- A group loads all its scripts into one shared hosted rollout dialog (even saved OFF/DIRECT scripts) without changing persisted modes; no-rollout scripts execute but create no panel.
- Hosted script loading accepts an explicit temporary dialog-path override, and the dialog title-button reload retains that override so nested scripts stay together.
- Added an isolated group-loading regression covering submenu order, folder-only visibility, subtree scope, shared dialog, mode preservation, and reload. Canonical test `1.173`, project `1.178`; live 3ds Max run pending.

## 2026-10-25 — 1.177

- Kept one SCRIPTS context-menu command named `OPEN IN EXPLORER` for both files and folders.
- Both paths now request administrator elevation with `System.Diagnostics.ProcessStartInfo`, `UseShellExecute=true`, and `Verb=runas`; script files retain Explorer `/select` and folders retain direct navigation.
- UAC cancellation is handled by existing diagnostic catches. Windows Explorer can reuse its existing unelevated desktop process, so administrator rights in the opened window cannot be guaranteed.
- Added a regression for both launch configurations (without launching Explorer or requesting UAC); canonical test advances to `1.172` / project `1.177`. 3ds Max runtime verification pending.

## 2026-10-25 — 1.176

- Added SCRIPTS TreeView RMB command `EXPAND ENABLED` next to the existing expansion commands.
- The command collapses all folders, then opens only ancestor folders of configured HOST and DIRECT scripts, leaving skipped branches closed. Its traversal reads already-cached TreeNode state images, so no additional filesystem scan or INI mode reads are needed.
- The command is available from folder and script-leaf context menus and persists the resulting expanded/collapsed states.
- Added a regression scenario for nested DIRECT scripts, HOST scripts, skipped branches, and the no-enabled-scripts case. Canonical test advances to `1.171` / project `1.176`.

## 2026-10-25 — 1.175

- Restored SOURCES and SCRIPTS rollout `open` callbacks after the 1.174 optimization could leave the initial TreeView blank until the manager ran a second time.
- Introduced `populateInitialSourceTree()` and `populateInitialScriptTree()` guards shared by rollout-open callbacks and the initial loader fallback. Each successful initial render occurs once and starts collapsed; subsequent explicit refresh retains its normal behavior.
- Added an isolated first-load regression check that clears both trees, rebuilds them from the existing discovery cache, and verifies repeating initialization does not rebuild populated nodes.
- Canonical test advances to file version `1.170` / project `1.175`; runtime validation in 3ds Max is still pending.

## 2026-10-24 — 1.174

- SOURCES and SCRIPTS now initialize collapsed. Later explicit refreshes can restore persisted folder expansion states.
- Removed duplicate TreeView population from the two dynamic rollout `open` callbacks; startup now populates each tree once.
- Removed redundant SOURCES rediscovery from `populateSourceTree()` because every caller already prepares the source data.
- Added per-render `.NET Hashtable` lookup caches for SOURCES/SCRIPTS folder nodes and SCRIPTS group counts/descendant flags, removing repeated linear searches during TreeView construction.
- Cached whether each discovered SCRIPTS folder is an organizational row, eliminating a repeat same-name `.ms` filesystem check during render.
- Updated canonical test to file version `1.169` / project `1.174`, including cache equivalence, collapsed initialization, folder deduplication, and duplicate-population regression checks. Added 1.174 source/test snapshots.
- Stable MVP remains `1.153`; no live 3ds Max execution was performed.

## 2026-10-24 — 1.173

- Fixed SCRIPTS IGNORE input behaving as a multiline native editText: its 24 px height allowed ENTER to insert a newline into the mask, which could break INI readback verification and leave the preview unfiltered.
- Changed the IGNORE edit field to 16 px (single-line) without changing its full width or the existing LMB `REFRESH \ RESTART` save/apply contract.
- `tests/Script-Manager-test.ms` advances to `1.168` / project `1.173` and asserts the IGNORE control remains single-line, alongside the existing save/reload/filter checks.
- Added versioned source/test snapshots for 1.173; stable MVP baseline remains 1.153.

## 2026-10-24 — 1.172

- `Script-Manager.ms` advances to `1.172`; stable MVP remains `1.153`.
- SCRIPTS TreeView folder rows now use a shared bold font; script-file rows keep the normal TreeView font.
- The bold font is created once per Script-Manager instance and reused by folder nodes instead of constructing a separate font for every row.
- The canonical regression test is unchanged in this focused UI-only pass.
- Added production snapshot `Script-Manager_1.172.ms`.

## 2026-10-24 — 1.171

- `Script-Manager.ms` advances to `1.171`; stable MVP remains `1.153`.
- Moved `IGNORE` from OPTIONS into the SCRIPTS rollout and kept the edit field full-width. OPTIONS now contains only ROOT PATH/BROWSE.
- IGNORE is now a SCRIPTS-only filter: SOURCES remains fully visible, matching SCRIPTS folder names hide their complete subtree, and matching script filenames or basenames hide those leaves.
- The value is persisted under `[Filter] ScriptIgnoreMask` in `script_manager.ini`; the old `SourceIgnoreMask` key is accepted as a migration fallback. Editing remains draft-only and LMB `REFRESH \ RESTART` saves/applies it.
- `tests/Script-Manager-test.ms` advances to file version `1.166` / project `1.171` with coverage for UI placement, INI persistence, SOURCES remaining unfiltered, and ignored SCRIPTS folders/files being absent from the rendered tree.
- Added snapshots `Script-Manager_1.171.ms` and `tests/Script-Manager-test_1.166.ms`.

## 2026-10-24 — 1.170

- `Script-Manager.ms` advances to `1.170`; stable MVP remains `1.153`.
- Fixed SCRIPTS hierarchy wrapping: each checked SOURCES directory now becomes the visible root of its own SCRIPTS subtree, so unchecked ancestors such as `CODEBASE` are not inserted above checked `Tools` / `Toolsets`.
- Discovery keeps the original root-relative group paths for loading, persistence, batching, and filtering, while separate display paths are cached for SCRIPTS rendering.
- Tree folder nodes retain their real filesystem directories for tooltips, expansion-state persistence, and `OPEN IN EXPLORER` even when display-only ancestor folders are omitted.
- `tests/Script-Manager-test.ms` advances to file version `1.165` / project `1.170` with regression coverage for a checked nested source becoming a top-level SCRIPTS node and its unchecked parent remaining absent.
- Added snapshots `Script-Manager_1.170.ms` and `tests/Script-Manager-test_1.165.ms`.

## 2026-10-24 — 1.169

- `Script-Manager.ms` advances to `1.169`; stable MVP remains `1.153`.
- Added always-visible performance timing around the two expensive TreeView phases so slowdown can be isolated before optimization.
- `SOURCES DATA PREP` and `SCRIPTS DATA PREP` report filesystem/discovery time in milliseconds plus discovered item counts.
- `SOURCES TREE RENDER` and `SCRIPTS TREE RENDER` separately report WinForms TreeView population/synchronization time in milliseconds plus item counts and success state.
- Added production snapshot `Script-Manager_1.169.ms`. The canonical regression test is unchanged in this diagnostic-only pass.

## 2026-10-24 — 1.168

- `Script-Manager.ms` advances to `1.168`; stable MVP remains `1.153`.
- Fixed the 1.167 empty-loader regression: the IGNORE matcher rewrite accidentally removed `isShadowedMcrScriptPath()`, while script discovery still called it. Initial discovery therefore aborted before PRESETS / OPTIONS / SOURCES / SCRIPTS were added, leaving only the `.NET` `REFRESH \ RESTART` button visible.
- Restored the same-name `.mcr` suppression helper without changing the 1.167 native IGNORE matcher. Initial discovery can now complete and build all four loader rollouts again.
- Fixed manual REFRESH so it runs `discoverSources()` after saving ROOT PATH / IGNORE and before repopulating SOURCES. This makes a newly edited IGNORE list actually rebuild the source set instead of repainting stale source data.
- Added production snapshot `Script-Manager_1.168.ms`. The canonical regression test remains unchanged in this repair pass.

## 2026-10-24 — 1.167

- `Script-Manager.ms` advances to `1.167`; stable MVP remains `1.153`.
- Replaced the IGNORE matcher with a deterministic native wildcard matcher instead of .NET regular-expression objects. Plain entries match folder names exactly; `*` and `?` are case-insensitive wildcards.
- Kept backward compatibility for existing masks by normalizing legacy `.*` wildcard shorthand to `*`, so masks such as `.*-DELETED` continue to work.
- IGNORE remains draft-only while typing. LMB `REFRESH \\ RESTART` persists the raw text, rebuilds the in-memory pattern list, then repopulates SOURCES and SCRIPTS in place.
- `tests/Script-Manager-test.ms` advances to file version `1.165` / project `1.167` with direct native matcher coverage for `.git`, `.*-DELETED`, and `*-OLD`, plus persistence and tree/script exclusion checks. Added snapshots `Script-Manager_1.167.ms` and `tests/Script-Manager-test_1.165.ms`.

## 2026-10-23 — 1.166

- `Script-Manager.ms` advanced to `1.166` as a repair attempt for the broken deferred refresh introduced in 1.165.
- Removed the timer-based refresh queue and made LMB `REFRESH \\ RESTART` apply OPTIONS and repopulate the existing trees directly instead of rebuilding loader rollouts.
- This version was not accepted as stable because IGNORE matching still failed in real use.

## 2026-10-23 — 1.165

- `Script-Manager.ms` advances to `1.165`; stable MVP remains `1.153`.
- Fixed the 1.164 `.NET` `REFRESH \ RESTART` regression where rebuilding native loader subrollouts directly inside the WinForms mouse callback could leave the UI partially rebuilt and append another PRESETS rollout.
- The title-style button now only queues `#refresh` or `#restart`; a short native rollout timer executes the requested action after the WinForms callback returns, preserving the 1.164 appearance and LMB/RMB behavior without re-entrant subrollout mutation.
- `tests/Script-Manager-test.ms` advances to file version `1.164` / project `1.165` and verifies that the main action uses the deferred timer path and no direct `.NET` Click refresh handler remains. Added snapshots `Script-Manager_1.165.ms` and `tests/Script-Manager-test_1.164.ms`.

## 2026-10-23 — 1.164

- `Script-Manager.ms` advances to `1.164`; stable MVP remains `1.153`.
- Replaced the native main `REFRESH \\ RESTART` button with a full-width WinForms `.NET` button using the canonical `tool title button` appearance: dark `RGB 45,45,48`, blue `RGB 62,158,255`, borderless flat style, `Segoe UI` 14 px bold, 18 px height, and no tab stop.
- Preserved the existing interaction contract: LMB saves/applies pending OPTIONS and refreshes discovery; RMB restarts/version-reloads Script-Manager. The LMB/RMB tooltip remains available.
- `tests/Script-Manager-test.ms` advances to file version `1.163` / project `1.164` with control-type and title-button-style coverage. Added snapshots `Script-Manager_1.164.ms` and `tests/Script-Manager-test_1.163.ms`.

## 2026-10-23 — 1.163

- `Script-Manager.ms` advances to `1.163`; stable MVP remains `1.153`.
- Moved source configuration out of SOURCES into a dedicated `OPTIONS` rollout. OPTIONS now contains a persisted ROOT PATH selector plus IGNORE; SOURCES contains only its TreeView.
- ROOT PATH can be typed or selected with `BROWSE`. Both ROOT PATH and IGNORE remain draft UI values while editing and are saved/applied only by LMB `REFRESH \ RESTART`.
- Removed live IGNORE persistence/rescanning while typing so editing the field no longer repeatedly rebuilds the trees.
- Expanded the IGNORE edit box to the full usable rollout width and updated tooltips to make the manual-refresh requirement explicit.
- `tests/Script-Manager-test.ms` advances to file version `1.162` / project `1.163` with OPTIONS/root-path persistence, deferred IGNORE application, tooltip, and full-width edit-field coverage. Added snapshots `Script-Manager_1.163.ms` and `tests/Script-Manager-test_1.162.ms`.

## 2026-10-23 — 1.162

- `Script-Manager.ms` advances to `1.162`; stable MVP remains `1.153`.
- Fixed SOURCES `IGNORE:` persistence by verifying the INI write/readback instead of reporting success unconditionally. Failed persistence now reports the INI path plus expected/actual values.
- Valid IGNORE edits are now applied immediately to both SOURCES and SCRIPTS while typing; programmatic control synchronization is guarded so rebuilding the rollout cannot recursively trigger another refresh.
- Updated the IGNORE tooltip with the `|` separator, wildcard behavior, an example, and the fact that changes are saved/applied immediately.
- `tests/Script-Manager-test.ms` advances to file version `1.161` / project `1.162` with immediate-application, persistence, and tooltip coverage. Added snapshots `Script-Manager_1.162.ms` and `tests/Script-Manager-test_1.161.ms`.

## 2026-10-22 — 1.161

- `Script-Manager.ms` advances to `1.161`; stable MVP remains `1.153`.
- Double-clicking a SCRIPTS `.ms` item now uses the same forced standalone/direct `LOAD SCRIPT` path already used by `.mcr` double-clicks. `.mse` double-click remains non-executing.
- Double-clicking the checkbox glyph still does not execute the script, and the saved OFF / HOST / DIRECT mode is left unchanged.
- `tests/Script-Manager-test.ms` advances to file version `1.160` / project `1.161` with regression coverage for both MS and MCR double-click loading plus MSE exclusion. Added snapshots `Script-Manager_1.161.ms` and `tests/Script-Manager-test_1.160.ms`.

## 2026-10-21 — 1.160

- `Script-Manager.ms` advances to `1.160`; stable MVP remains `1.153`.
- SCRIPTS now keeps organizational directories visible when they do not contain a canonical same-name `<FolderName>.ms`, even when the directory currently contains no supported scripts. This makes newly checked category/source folders visible in the script preview instead of disappearing until a script is added.
- Canonical same-name tool folders keep the existing behavior and remain represented by their script rows/flattening rules rather than receiving an extra empty folder row.
- `tests/Script-Manager-test.ms` advances to file version `1.159` / project `1.160` with regression coverage for a selectable `PendingTools` directory containing only a non-script file appearing in SCRIPTS. Added snapshots `Script-Manager_1.160.ms` and `tests/Script-Manager-test_1.159.ms`.

## 2026-10-21 — 1.159

- `Script-Manager.ms` advances to `1.159`; stable MVP remains `1.153`.
- SCRIPTS folder rows now show the checked glyph whenever any descendant script is active in HOST or DIRECT mode, so collapsed parent branches visibly indicate that they contain configured scripts.
- The indicator propagates through every ancestor folder and is display-derived only; script load modes and persistence remain unchanged.
- `tests/Script-Manager-test.ms` advances to file version `1.158` / project `1.159` with regression coverage for mixed HOST / DIRECT / OFF descendants marking both their immediate parent and the collapsed top ancestor. Added snapshots `Script-Manager_1.159.ms` and `tests/Script-Manager-test_1.158.ms`.

## 2026-10-20 — 1.158

- `Script-Manager.ms` advances to `1.158`; stable MVP remains `1.153`.
- Double-clicking an `.mcr` entry in the SCRIPTS tree now force-loads that MacroScript through the same standalone/direct path as RMB `LOAD SCRIPT`. Double-clicking `.ms` or `.mse` rows remains non-executing.
- Added `OPEN IN EXPLORER` to the SCRIPTS RMB menu. Script leaves open Explorer with the file selected; folder rows open the represented directory.
- `tests/Script-Manager-test.ms` advances to file version `1.157` / project `1.158` with coverage for MCR double-click loading, non-MCR double-click exclusion, and Explorer context-menu visibility. Added snapshots `Script-Manager_1.158.ms` and `tests/Script-Manager-test_1.157.ms`.

## 2026-10-17 — 1.157

- `Script-Manager.ms` advances to `1.157`; stable MVP remains `1.153`.
- Added `CREATE TOOLBAR` beside `LOAD SCRIPTS`. The prompted name defaults to `<Windows username> SCRIPT-MANAGER`; the generated toolbar places Script-Manager first and then every HOST/DIRECT script in current SCRIPTS tree order, omitting OFF scripts.
- Toolbar generation saves the current UI to a temporary CUIX, patches and loads that file immediately, and shows the toolbar without a manual reload. Same-named generated toolbars are replaced while unrelated CUIX toolbar definitions remain intact.
- Added `SAVE UI`, enabled by default, so generation persists the loaded toolbar back to the previously active CUIX unless the user explicitly chooses a temporary-only toolbar.
- `tests/Script-Manager-test.ms` advances to file version `1.156` / project `1.157` with coverage for default naming, HOST/DIRECT selection and order, generated MacroScript actions, same-named CUIX replacement, and the new UI controls. Added snapshots `Script-Manager_1.157.ms` and `tests/Script-Manager-test_1.156.ms`.
- Per user request, the live CUIX load/save path was not executed against the running 3ds Max session during integration.

## 2026-10-17 — 1.156

- `Script-Manager.ms` advances to `1.156`; stable MVP remains `1.153`.
- Script discovery now suppresses a `.mcr` file whenever the same directory contains an `.ms` file with the exact same basename, so `Tool.ms` + `Tool.mcr` appears only as `Tool.ms` in SCRIPTS.
- The suppression applies before version filtering, so it remains in effect even with `SHOW VERSIONED FILES` enabled.
- `tests/Script-Manager-test.ms` advances to file version `1.155` / project `1.156` and covers same-name MS/MCR preference in both default and show-all-version views. Added snapshots `Script-Manager_1.156.ms` and `tests/Script-Manager-test_1.155.ms`.

## 2026-10-17 — 1.155

- `Script-Manager.ms` advances to `1.155` from the 1.154 preset/startup candidate; stable MVP remains `1.153`.
- Fixed the SOURCES `IGNORE:` edit workflow so every valid text edit is persisted immediately instead of relying only on the ENTER event.
- ENTER now applies the control's actual current text, rebuilds SOURCES, and refreshes configured discovery. The remembered valid mask is restored after Script-Manager/3ds Max restart.
- `tests/Script-Manager-test.ms` advances to file version `1.154` / project `1.155` and adds persistence coverage for the remembered ignore entry. Added snapshots `Script-Manager_1.155.ms` and `tests/Script-Manager-test_1.154.ms`.

## 2026-10-17 — 1.154

- `Script-Manager.ms` advances to `1.154` from the user-confirmed 1.153 stable MVP baseline. Stable MVP remains `1.153` while 1.154 is evaluated.
- Moved all preset controls into a dedicated top `PRESETS` rollout. Selecting a preset is now selection-only; `LOAD` restores the preset and hard-loads its configured scripts. The SCRIPTS rollout returns to a 1032 px tree viewport.
- Added `MACRO` to create or update a persistent `Script-Manager Presets` MacroScript action for the selected preset, allowing the same preset-load path to be assigned to a toolbar button.
- Added unique `STARTUP` preset support. The selected preset is stored in `script_manager.ini`, and a dedicated user-startup loader applies and loads it once when 3ds Max starts; clearing STARTUP removes the loader.
- `tests/Script-Manager-test.ms` advances to file version `1.153` / project `1.154` with PRESETS UI, macro-body, startup-loader, startup-once, and preset execution regression coverage. Added snapshots `Script-Manager_1.154.ms` and `tests/Script-Manager-test_1.153.ms`.

## 2026-10-17 — 1.153 STABLE MVP

- User-confirmed `Script-Manager 1.153` as the stable MVP baseline.
- Canonical production code remains unchanged at file/project version `1.153`; this is a status/documentation update only.
- `Script-Manager_1.153.ms` is the corresponding stable production snapshot.
- Future development must branch from the latest canonical `Script-Manager.ms` at 1.153 or a subsequently confirmed stable baseline.

## 2026-10-06 — 1.153

- `Script-Manager.ms` advances to `1.153` from the 1.152 destroy-first batch-dialog reload candidate.
- Fixed a HOST reload edge case where a script that already had a standalone rollout open could be executed again in embedded mode, redefining the rollout global while leaving the old standalone instance alive.
- Embedded/HOST loads now collect the current source-declared and registry-owned rollout instances and close any standalone dialogs **before** the script is `fileIn`-loaded in `#embedded` mode. The new rollout instance can then be embedded without leaving a duplicate standalone window.
- `tests/Script-Manager-test.ms` advances to file version `1.152` / project `1.153` and adds a regression sequence that direct-loads a rollout first, then HOST-loads it and verifies the stale standalone instance is closed before the hosted reload continues.
- Stable baseline remains `1.149` until a newer version is explicitly confirmed stable.

## 2026-10-06 — 1.152

- `Script-Manager.ms` advances to `1.152` from the 1.151 per-dialog SOURCES reload candidate.
- Per-dialog reload now kills the existing batch host first: the old host dialog is saved, unregistered when docked, fully destroyed, and removed from manager tracking before any assigned HOST scripts are executed again.
- The same destroy-first behavior is used by both SOURCES `LOAD \ RELOAD DIALOG` and the generated batch dialog title-button reload path, preventing stale docked dialog-bar state from interfering with recreation.
- Other batch dialogs and DIRECT/standalone scripts remain untouched. `tests/Script-Manager-test.ms` advances to file version `1.151` / project `1.152` and verifies that per-dialog reload recreates a new host instance.
- Stable baseline remains `1.149` until a newer version is explicitly confirmed stable.

## 2026-10-06 — 1.151

- `Script-Manager.ms` advances to `1.151` from the 1.150 batch-grouping candidate.
- Added `LOAD \ RELOAD DIALOG` to the SOURCES RMB menu for an explicit checked batch-dialog item. The command is shown only when that checked source is the second matching checked ancestor for at least one configured HOST script; the first checked discovery source is ignored.
- The command loads a not-yet-open batch or hard reloads an existing one using only the currently configured HOST scripts assigned to that dialog. Other HOST dialogs, DIRECT/standalone scripts, and skipped scripts are untouched.
- Added source-dialog targeting helpers and regression coverage for cross-parent HOST membership, DIRECT exclusion, first-source exclusion, and context-menu visibility. `tests/Script-Manager-test.ms` advances to file version `1.150` / project `1.151`.
- Stable baseline remains `1.149` until a newer version is explicitly confirmed stable.

## 2026-10-06 — 1.150

- `Script-Manager.ms` advances to `1.150` to correct cross-parent batch ownership.
- The first checked SOURCES ancestor is discovery-only. The second checked ancestor becomes the batch-dialog owner for the complete subtree, and deeper checked descendants no longer split that batch into separate dialogs.
- HOST script coloring follows the resolved batch dialog; DIRECT/standalone scripts remain orange.
- `tests/Script-Manager-test.ms` advances to file version `1.149` / project `1.150` with a regression case proving scripts from different parent folders resolve to one explicit batch dialog.
- Version `1.149` remains the latest user-confirmed stable baseline.

## 2026-10-06 — 1.148

- `Script-Manager.ms` advances to `1.148` while preserving the 1.147 same-name/empty-directory SOURCES stopper behavior.
- Added a persisted `IGNORE:` edit field above the SOURCES tree. The default mask is `.git`; ENTER applies the current mask and refreshes SOURCES/SCRIPTS without loading scripts.
- Ignore masks are pipe-separated and case-insensitive. Plain names match literally, regular-expression patterns are accepted, and `*` is supported as wildcard shorthand so examples such as `.git|.*-DELETED|*-OLD|` work as entered. Matching directories are omitted together with their complete subtrees.
- `tests/Script-Manager-test.ms` advances to file version `1.147` / project `1.148` and verifies the default `.git` exclusion plus custom `-DELETED` and `-OLD` masks. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.147

- `Script-Manager.ms` advances to `1.147` while preserving the 1.146 exact same-basename SOURCES hierarchy-stopper rule and checkbox rendering.
- Completely empty directories now use the same display-only SOURCES behavior: the directory row remains visible, has no checkbox, and has no children.
- Non-empty directories without a same-name `.ms` file remain selectable sources exactly as in 1.146.
- `tests/Script-Manager-test.ms` advances to file version `1.146` / project `1.147` and adds an explicit empty-directory no-checkbox regression case. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.146

- `Script-Manager.ms` advances to `1.146` and keeps the 1.144/1.143 custom SOURCES checkbox rendering.
- Corrected the hierarchy-stopper rule to match the exact folder/file basename condition at every nesting depth: if a folder contains `<FolderName>.ms`, that folder is a display-only stopper row with no checkbox.
- A stopper row never shows child directories in SOURCES. The previous direct-root reachability exception was removed because it violated the same-name stopper rule and could make checkboxes reappear.
- `tests/Script-Manager-test.ms` advances to file version `1.145` / project `1.146` and now verifies the same-name stopper behavior both directly below the managed root and at deeper nested levels, including hidden descendants. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.145

- `Script-Manager.ms` advances to `1.145` while preserving the 1.140 preset workflow and 1.143 explicit blank-image rendering for checkbox-free SOURCES rows.
- Replaced the broad 1.144 structural terminal-folder rule with the requested hierarchy-stopper rule: a SOURCES directory stops traversal when it contains an unversioned same-name `.ms` file such as `script-name\script-name.ms`.
- Nested hierarchy stoppers remain visible as directory rows without checkboxes, and Script-Manager no longer shows any child directories below them in SOURCES, even when helper subfolders exist.
- Leaf directories without a same-name `.ms` file remain selectable sources. Direct root-level stoppers remain selectable only for reachability, but still stop recursion.
- `tests/Script-Manager-test.ms` advances to file version `1.144` / project `1.145` and verifies same-name stopping, hidden descendants below a stopper, and a differently named leaf remaining selectable. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.144

- `Script-Manager.ms` advances to `1.144` while preserving the 1.140 preset workflow and the 1.143 explicit blank-image rendering for checkbox-free SOURCES rows.
- Restored the 1.141 SOURCES terminal-folder classification because it behaves better in the real tree: every nested directory with no child directories is an informational tool row with no checkbox, regardless of the script filename inside it.
- Parent/category directories remain selectable recursive sources with the existing checkbox glyph style; direct root-level terminal folders remain selectable for reachability.
- `tests/Script-Manager-test.ms` advances to file version `1.143` / project `1.144` and restores regression coverage for a differently named script inside a nested terminal folder remaining checkbox-free. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.143

- `Script-Manager.ms` advances to `1.143` while preserving the 1.142 same-name terminal-tool classification and the 1.140 preset workflow.
- Fixed the actual SOURCES rendering bug that could still show an unchecked checkbox on a display-only `SOURCE_TOOL` row: the source ImageList now reserves index `0` as an explicit transparent image instead of relying on `ImageIndex = -1`.
- Selectable source rows now use image index `1` for unchecked and `2` for checked; same-name terminal tool rows use index `0`, so WinForms cannot fall back to the first checkbox image.
- `tests/Script-Manager-test.ms` advances to file version `1.142` / project `1.143` and verifies the three-image source list plus explicit blank-image indices for terminal tool rows. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.142

- `Script-Manager.ms` advances to `1.142` while preserving the 1.140 preset workflow and current SOURCES checkbox rendering.
- Corrected the 1.141 terminal-directory rule: a nested SOURCES directory is now display-only/no-checkbox only when it contains its canonical same-name `.ms` file, such as `Parent Tools > script-tool > script-tool.ms`.
- A nested leaf directory whose script filename does not match the directory name remains a selectable source and keeps the existing checkbox glyph; direct root-level tool folders remain selectable for reachability.
- Existing checked state migrates to the parent only for same-name tool directories that become display-only.
- `tests/Script-Manager-test.ms` advances to file version `1.141` / project `1.142` and explicitly verifies both cases: same-name tool folder = no checkbox, differently named leaf folder = selectable checkbox. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.141

- `Script-Manager.ms` advances to `1.141` while preserving the 1.140 preset workflow and the existing SOURCES checkbox appearance.
- Generalized the SOURCES terminal-row rule: every nested terminal directory is now shown as an informational directory item with no checkbox, whether or not it contains a same-name `.ms` file.
- Parent/category directories keep the current custom checkbox glyphs and remain selectable recursive sources. Direct root-level terminal folders remain selectable so their scripts cannot become unreachable.
- A previously checked nested terminal directory still migrates its source state to the visible selectable parent and clears its own obsolete source setting.
- `tests/Script-Manager-test.ms` advances to file version `1.140` / project `1.141` and adds regression coverage for a checkbox-free terminal directory whose script filename does not match the directory name. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.140

- `Script-Manager.ms` advances to `1.140` and adds named loader presets using the established dropdown preset pattern from `Material-ID-Manager_0.063.ms`.
- Added a neutral `<Preset>` dropdown row plus `SAVE \ REMOVE`: LMB saves the current enabled SOURCES and non-skipped SKIP / HOST / DIRECT script configuration under a name; RMB removes the selected preset after confirmation.
- Selecting a named preset asks for confirmation, restores SOURCES first, then restores script load modes and refreshes both trees without executing configured scripts.
- Presets are stored as isolated `Preset|<name>` sections inside the existing `script_manager.ini`; overwrite and load writes use rollback-safe section replacement so failed writes do not leave partial configuration.
- Reduced the visible SCRIPTS TreeView by 36 px to make room for the preset row without increasing the existing manager dialog height.
- `tests/Script-Manager-test.ms` advances to file version `1.139` / project `1.140` with preset UI/API, save/list/load/remove, exact state restoration, and no-auto-execution regression coverage. Added snapshots `Script-Manager_1.140.ms` and `tests/Script-Manager-test_1.139.ms`. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.139

- `Script-Manager.ms` advances to `1.139` while preserving the 1.138 custom SOURCES checkbox style and all existing loading behavior.
- Refined nested same-name tool directories in `SOURCES`: `Parent Tools > script-tool > script-tool.ms` is now represented by the directory row `Parent Tools > script-tool`, not by a flattened `script-tool.ms` file leaf.
- Matching nested tool-directory rows remain visible but have no checkbox; parent/category source rows keep the existing custom checkbox glyphs unchanged.
- The no-checkbox tool row is selection/information only and is never treated as a source root. Existing checked terminal-tool state still migrates to the visible selectable parent.
- `tests/Script-Manager-test.ms` advances to file version `1.138` / project `1.139` and updates SOURCES mixed-row expectations. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-06 — 1.138

- `Script-Manager.ms` advances to `1.138` while preserving the 1.137 forced `LOAD SCRIPT` behavior, the 1.136 SCRIPTS flattening, and the 1.135 soft/hard loading model.
- Refined `SOURCES` with the same terminal-tool flattening idea: when a nested terminal directory contains its canonical same-name `.ms` file, `Parent Tools > script-tool > script-tool.ms` is displayed as `Parent Tools > script-tool.ms`.
- The flattened SOURCES tool leaf is display-only and has no checkbox. Parent/category rows keep selectable source checkbox glyphs; direct root-level terminal folders remain selectable so they cannot become unreachable.
- SOURCES now uses explicit checkbox images instead of native TreeView checkboxes so selectable and display-only rows can coexist in the same tree. Clicking a display-only tool leaf only selects it; clicking a selectable source checkbox glyph toggles that source and refreshes discovery.
- Existing checked nested terminal-tool source state migrates to its visible selectable parent and the old terminal-folder source setting is cleared.
- `tests/Script-Manager-test.ms` advances to file version `1.137` / project `1.138` with regression coverage for selectable parent rows, checkbox-free flattened tool leaves, state migration, and mixed SOURCES rendering. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-05 — 1.137

- `Script-Manager.ms` advances to `1.137` while preserving the 1.136 SCRIPTS-tree flattening and all 1.135 soft/hard loading behavior.
- SCRIPTS item RMB `LOAD SCRIPT` is now a forced direct/standalone execution path. It re-runs the selected script even when that script is already running and ignores its persisted OFF/HOST/DIRECT mode for this one action.
- Forced `LOAD SCRIPT` never adds the script or its rollout to a Script-Manager batch/host dialog, never host-loads an optional `-UI.ms` companion, and does not clear, rebuild, or otherwise modify existing batch dialogs.
- The script's persisted tri-state mode remains unchanged, so later `LOAD SCRIPTS` LMB/RMB behavior still follows the configured OFF/HOST/DIRECT state.
- `tests/Script-Manager-test.ms` advances to file version `1.136` / project `1.137` and verifies repeated forced execution, `#standalone` runtime mode, unchanged HOST mode, and zero batch-dialog membership. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-05 — 1.136

- `Script-Manager.ms` advances to `1.136` while preserving all 1.135 soft/hard loading and source-tree behavior.
- Simplified the `SCRIPTS` TreeView by flattening redundant terminal tool folders: when a folder contains exactly one visible script, has no visible descendant scripts, and the script basename matches the folder name, the script leaf is displayed directly under the parent.
- Flattening is display-only. The real source path, persisted OFF/HOST/DIRECT mode, host-dialog grouping, and loading behavior remain unchanged.
- Example: `Loop Tools > Remove-Verts > Remove-Verts.ms` is shown as `Loop Tools > Remove-Verts.ms`.
- Updated the current `tests/Script-Manager-test.ms` with regression coverage for root, nested, and non-flattened parent cases. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-05 — 1.135

- `Script-Manager.ms` advances to `1.135`. `LOAD SCRIPTS` now combines both load behaviors: LMB performs a light/soft update that executes only configured scripts that are not currently running, while RMB keeps the full hard-reload path and re-executes the complete configured load set.
- Soft running-state detection prioritizes a script's live standalone rollout/dialog, then a live Script-Manager HOST/batch dialog containing that script. Scripts with no detectable UI are treated as running after one successful load in the current manager session, preventing repeated execution on every soft update.
- Closing a standalone tool dialog or a HOST/batch dialog makes only the affected script(s) eligible for the next soft update; scripts whose UI is still live are left untouched.
- SCRIPTS TreeView RMB is now item-specific: script leaves show `LOAD SCRIPT` and no tree expand/collapse commands. `LOAD SCRIPT` soft-loads only that script independently of its persisted tri-state; an unchecked script defaults to standalone/direct loading. Folder items retain the existing expand/collapse menu commands.
- SOURCES now focuses on organizational parent folders instead of duplicating terminal tool folders already represented by SCRIPTS. Nested terminal leaf tool directories are hidden, direct root-level leaves remain visible so they cannot become unreachable, and a previously checked hidden leaf migrates its source state to the visible parent.
- `tests/Script-Manager-test.ms` advances to file version `1.134` / project `1.135` with regression coverage for soft-vs-hard loading, live standalone recovery, closed HOST recovery, no-UI single-load behavior, script-item `LOAD SCRIPT`, checkbox-independent single-script loading, and terminal-source-folder filtering. Added snapshot `Script-Manager-test_1.134.ms`.
- Added production snapshot `Script-Manager_1.135.ms` and updated `Script-Manager.md`. Stable MVP baseline remains `1.134` until a newer stable baseline is explicitly confirmed.

## 2026-10-05 — 1.134

- Marked `1.134` as the stable MVP development baseline; future changes must branch from the latest canonical repository copy of this baseline or a subsequently confirmed stable baseline.
- Version `1.134`: synchronized Script-Manager file/project/loader-title version.
- Removed the redundant top info/version labels from the main Script-Manager dialog.
- Moved the refresh/restart action into the main top row and renamed it to `REFRESH \ RESTART`; LMB refreshes discovery and RMB keeps the existing restart/version-reload behavior.
- The `SOURCES` rollout now contains only its TreeView.
- Moved `SHOW VERSIONED FILES` and `CLEAN SCRIPTS ONLY` onto one row in the `SCRIPTS` rollout while preserving the 1032 px script TreeView height.
- Reduced the minimum/default manager height to match the more compact layout without reducing either TreeView height.

## 2026-10-05 — 1.133

- Version `1.133`: synchronized Script-Manager file/project/loader-title version.
- Removed the Script-Manager version suffix from generated production host-dialog captions and their interactive title-button labels; host dialogs now show only the organizational parent-folder name.
- Restyled the host .NET title button as flat and borderless while keeping the dark background and using light-blue text `RGB 62,158,255`.
- Dialog-local LMB reload behavior is unchanged.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.

## 2026-10-05 — 1.132

- Version `1.132`: synchronized production file/project/title version.
- Added a full-width .NET title button at the top of every generated organizational host dialog; its label matches the dialog title so docked tool batches retain a clear interactive title.
- LMB on the host title button reloads only the HOST-mode scripts currently represented in that dialog, without reloading other dialogs or DIRECT scripts.
- Added explicit per-dialog hosted-script tracking so dialog-local reload uses the actual current hosted set.
- The title button occupies its own 24 px row above the existing 312 px-wide tool subrollout; standard 288 px tool rollout width remains preserved.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.

# Changes

## 2026-10-05 — 1.131

- Version `1.131`: synchronized production file/project/title version.
- Fixed initial SCRIPTS tree filtering so persisted `SHOW VERSIONED FILES` and `CLEAN SCRIPTS ONLY` values are restored from `script_manager.ini` before discovery runs.
- The first tree build after opening/restarting now matches the saved filter state immediately; no manual filter toggle or extra RELOAD is required.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.

## 2026-10-05 — 1.130

- Version `1.130`: synchronized production file/project/title version.
- Replaced the unreliable themed SCRIPTS state-image rendering with explicit dark-UI-safe checkbox glyphs rendered through the TreeView image column, making OFF / HOST / DIRECT visibly distinct in 3ds Max.
- `.ms` rows now show an empty box, checked box, or box-with-minus glyph for the persisted tri-state mode.
- Clicking a script row no longer executes it. Clicking the checkbox glyph only cycles the persisted load mode; `LOAD SCRIPTS` is the only TreeView-configured execution path.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.

## 2026-10-05 — 1.129

- Version `1.129`: synchronized production file/project/title version.
- Fixed `LOAD SCRIPTS` so it loads from the actual currently displayed `SCRIPTS` TreeView instead of depending only on cached discovery arrays.
- Hosted loads now resolve tool UI after `fileIn` from both source-declared rollout names and matching `ScriptManagerIntegration` registry entries, allowing dynamically registered rollouts to create their parent-folder dialogs correctly.
- `LOAD SCRIPTS` status now reports loaded scripts, embedded rollout count, and created dialog count.
- Empty dialogs are still not created for scripts that expose no rollout.
- Updated the single current `tests/Script-Manager-test.ms` with a runtime-registry hosted-rollout regression; no versioned test snapshot is created.

## 2026-10-05 — 1.128

- Version `1.128`: synchronized production file/project/title version.
- Split the loader UI into two independent collapsible rollouts: `SOURCES` owns `RELOAD\RESTART` plus the source tree; `SCRIPTS` owns `LOAD SCRIPTS`, script filters, and the scripts tree.
- Renamed the source action button from `RELOAD` to `RELOAD\RESTART`; `LMB` remains discovery reload and `RMB` remains manager restart/version reload.
- Removed the redundant `SOURCES` and `SCRIPTS` labels above the TreeViews because rollout titles now identify each section.
- SOURCES and SCRIPTS rollout expanded/collapsed states are persisted independently in `script_manager.ini`, migrating from the previous combined loader-open state.
- Preserved the 512 px SOURCES TreeView and 1032 px SCRIPTS TreeView working heights.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.


## 2026-10-05 — 1.127

- Version `1.127`: synchronized production file/project/title version.
- Added a dedicated `LOAD SCRIPTS` button. `RELOAD` now only rescans selected sources and rebuilds the loader trees; it no longer executes configured scripts.
- `LOAD SCRIPTS` applies the persisted tri-state modes to the already discovered scripts, rebuilding manager-hosted rollout dialogs as needed while leaving DIRECT scripts standalone.
- Script mode changes now prompt `Press LOAD SCRIPTS to apply.` The existing `RELOAD` RMB restart/version-reload behavior and F1 restart behavior remain unchanged.
- Adjusted the loader header layout to fit both primary buttons while preserving the existing tree sizes and INI-persisted UI state.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.

## 2026-10-05 — 1.126

- Version `1.126`: synchronized production file/project/title version.
- Increased the `SOURCES` TreeView height to 512 px and increased the persisted minimum loader-dialog height so both trees remain fully usable.
- Replaced Boolean SCRIPTS checkboxes with a persisted tri-state load mode for `.ms` files: unchecked = skip, checked = load/embed in the shared parent-folder dialog, indeterminate `-` = standalone/direct run without shared-dialog embedding.
- Existing INI `0/1` values migrate in place; direct mode is stored as `2`. Active hosted/direct script items retain `RGB 62,158,255`.
- Direct mode fileIns only the selected script in `#standalone`, does not auto-load its companion for hosting, does not source-scan rollouts for embedding, and never creates a shared host dialog.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.

## 2026-10-05 — 1.125

- Version `1.125`: synchronized production file/project/title version.
- Removed the central `Loaded Scripts` host. Each organizational parent/subdirectory now gets its own dialog, created only when a loaded child tool actually exposes a rollout.
- A tool folder's rollout is embedded directly into its parent-directory dialog, removing the generated intermediate category-rollout level.
- Tool folders sharing the same parent path share the same dialog. Nested organizational paths remain distinct by their full root-relative path even when leaf folder names match.
- Each generated host dialog persists its own position, height, and left/right dock state in `script_manager.ini`; tool rollout open/closed state remains persisted.
- Host dialogs are 336 px wide with a 312 px subrollout slot so standard 288 px tool rollouts keep at least their intended working width.
- Empty host dialogs are not created for no-UI scripts and are removed after failed rollout embedding.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.

## 2026-10-05 — 1.124

- Version `1.124`: synchronized production file/project/title version.
- `Loaded Scripts` now creates category rollouts lazily only for scripts that actually expose rollouts; scripts without rollouts and failed embeddings no longer leave empty category rollouts.
- Merged `RELOAD` and `RESTART` into the existing top-left `RELOAD` button: `LMB` reloads checked scripts and `RMB` performs restart/version reload.
- Removed the separate `RESTART` buttons from both the loader and `Loaded Scripts` dialogs; F1 restart behavior remains available.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.

## 2026-10-05 — 1.123

- Version `1.123`: synchronized production file/project/title version.
- Added persisted `CLEAN SCRIPTS ONLY`. It shows only the unversioned script whose basename matches its parent folder, giving a minimal useful-script view; it takes priority over the versioned-files filter.
- Checked script items now use font color `RGB 62,158,255`.
- Added `EXPAND ALL` / `COLLAPSE ALL` to RMB menus for both `SOURCES` and `SCRIPTS`; SCRIPTS retains selected-branch `EXPAND` / `COLLAPSE`.
- Tree expanded/collapsed states are now persisted in `script_manager.ini` alongside existing filters, checkbox states, dialog geometry, dock state, and rollout states.
- Updated the single current `tests/Script-Manager-test.ms`; no versioned test snapshot is created.

## 2026-10-05 — 1.122

- Version `1.122`: synchronized production file/project/title version.
- Split the UI into two dialogs. `Script-Manager` now contains only loader/configuration controls and TreeViews; the previous hosted rollout area was removed from it.
- Added a separate dockable `Loaded Scripts 1.122` dialog that owns category rollouts and all embedded rollouts from loaded scripts.
- Loader and Loaded Scripts dialogs persist their floating geometry and dock state independently. Closing the host clears stale rollout references, and later `RELOAD`/manual loading recreates the host automatically.
- The hierarchy layout timer moved with the hosted rollout hierarchy into the Loaded Scripts dialog. Both dialogs expose the same `RESTART` behavior.
- `Script-Manager-test.ms` remains the single current test file under `tests/` and is updated to verify the split-dialog contract; no versioned test snapshot is created.

## 2026-10-05 — 1.121

- Version `1.121`: synchronized production file/project/title version.
- `SOURCES` is now a recursive subfolder TreeView; the redundant `<ROOT>` source item was removed.
- Enabled nested sources are de-duplicated so a checked descendant is not scanned again when a checked parent already covers it.
- `SCRIPTS` now has a minimum 1032 px TreeView height, with the default floating manager height increased to expose it.
- Script files inside each folder are sorted by last-write time, newest first. Folder ordering remains alphabetical.

## 2026-10-05

- Version `1.120`: production `Script-Manager.ms` now uses the same version number for file version, project version, dialog title, and visible version label.
- Added a permanent bottom `RESTART` button; F1 uses the same restart path. Restart loads the newest newer `Script-Manager_*.ms` release when available, otherwise reloads the current source, using quiet `fileIn`.
- Reworked loader UI into two TreeViews: `SOURCES` selects which first-level folders are recursively scanned, while `SCRIPTS` contains the scripts discovered only inside checked sources.
- Source and script checkbox states are persisted. Script checkboxes now define the load set; `RELOAD` loads only checked scripts instead of executing a script immediately when its checkbox changes.
- Added `SHOW VERSIONED FILES`. Default discovery shows the unversioned canonical file when present, otherwise only the newest numeric versioned file. Enabling the filter shows all versions.
- Normal discovery/reload/success tracing is quiet by default to avoid 3ds Max Listener performance costs. Detailed success output is available only when `debug_logging` is enabled; errors still report normally.
- `Script-Manager-test.ms` is maintained as the single current production regression file and is moved under `tests/`; no new versioned test snapshot is created for this release.

## 2026-10-05 — previous 1.119

- `Script-Manager.ms` advanced to 0.28. The manager dialog title and visible version label used the highest loaded Script-Manager project version instead of the file version.
- Generic reload/load operations stopped pruning root-scoped entries from the shared script registry.
- Failed rollout-host requests stopped marking scripts or companions as loaded.
- Paired `<Backend>-UI.ms` companions were hidden from generic discovery when the sibling backend exists.

## 2026-10-04

- Project 1.118: moved the former `EPolyToolsManager` package out of EPolyTools into the shared MaxScript agent root and renamed it `Script-Manager`.
- `Script-Manager.ms` became a generic `.ms` / `.mcr` / `.mse` loader instead of an EPoly-owned manager.
- Added generic `ScriptManagerIntegration` runtime/registry globals and retained EPoly compatibility aliases.

