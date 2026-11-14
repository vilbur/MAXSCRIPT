# Script-Manager

## Script loading checkbox

- **Unchecked (false)**: Skip loading the script.
- **Checked (true)**: Load the script in the shared group dialog.
- **Indeterminate (third state)**: Load the script standalone.

`G:\CODE\MAXSCRIPT\Script-Manager\Script-Manager.ms` is the generic MaxScript loader and optional rollout host for the managed MaxScript source tree.

It is not owned by EPolyTools. The repository lives in `G:\CODE\MAXSCRIPT\Script-Manager\`. Its parent `G:\CODE\MAXSCRIPT\` is the default managed root; OPTIONS can persist a different source root.

## 1.211 CLEAN SCRIPTS tri-state

- OPTIONS → SHOW now uses a native three-state **CLEAN SCRIPTS** checkbox: **0 unchecked** shows the normal script list, **1 checked** keeps only the unversioned script matching the immediate parent folder, and **2 indeterminate** keeps that clean file when available but shows otherwise hidden scripts when a folder has no matching canonical file.
- For example, `MatchingTool/MatchingTool.ms` hides its sibling `Helper.ms` in states 1 and 2. An unmatched folder such as `UnclearTool/Utility.ms` and `UnclearTool/Another.ms` is empty in state 1 and shows both files in state 2. Unmatched versioned files are included in state 2; CLEAN SCRIPTS continues to take priority over VERSIONED FILES.
- Checkbox clicks cycle **0 → 1 → 2 → 0**, with `[Filter] CleanScriptsOnly` persisting `0`, `1`, or `2`. Saved `0`/`1` values and the original Boolean API retain their behavior. Discovery, ignore masks, tree load modes, and startup scripts are unchanged.
- Production v1.211; regression suite v1.205 adds part 48. Live 3ds Max verification pending; stable v1.188 untouched.

## 1.210 native TreeView load exceptions in Listener

- On RMB **LOAD SCRIPT** or script-item double-click, preserve the v1.209 failure dialog while printing the original MAXScript exception, source file, line number and full MAXScript stack trace to the Listener.
- Rethrow the original exception through the manual-load path (`throw()` in catch). Restore temporary runtime modes and the Script-Manager busy flag before propagation; unsuccessful loads still do not register as successful. Non-exception failures also signal a native error after the dialog.
- Normal configured HOST/DIRECT loading and the independent startup launchers retain their existing non-throwing contracts. Regression suite v1.204 adds part 47 for exception propagation and cleanup; live 3ds Max verification remains pending.

## 1.209 per-script startup menu and visible load errors

- SCRIPTS script-file rows now have **ADD TO STARTUP SCRIPTS** or **REMOVE FROM STARTUP SCRIPTS** on RMB. The action toggles a dedicated startup launcher for that exact source file; folders do not show it.
- Launchers live in 3ds Max's user startup-scripts directory (`getDir #userStartupScripts`) and execute the original source via `fileIn ... quiet:true` on the next 3ds Max startup. They are uniquely identified by source path; removing startup deletes only the marked launcher. Script files, other startup entries, Script-Manager's preset STARTUP loader, and SKIP/HOST/DIRECT states are not modified.
- Failed manual script loads from a double-click or RMB `LOAD SCRIPT` now show a message dialog containing `[TREE LOAD] FAILED`, script path, action, and captured reason/exception. The existing full Listener logging stays enabled; successful loads show no message.
- Development production version `1.209`; regression test `1.203`, including isolated startup launcher tests in part 46. Live 3ds Max testing is required before confirming full runtime behavior.

## 1.208 SHOW / IGNORE moved to OPTIONS

- Replace the combined **SHOW & IGNORE** subrollout in SCRIPTS with two independently collapsible sections inside **OPTIONS**: **SHOW** contains VERSIONED FILES, CLEAN SCRIPTS, and COLLAPSE DIRS; **IGNORE** contains the persistent script-ignore edit field.
- Preserve the existing filters, callbacks, ROOT PATH, REFRESH-to-save IGNORE, live SCRIPTS FILTER, and 1032 px TreeView. SCRIPTS no longer owns a nested configuration slot.
- Persist `[Loader] ShowOpen` and `[Loader] IgnoreOpen` separately, migrating missing values from the former `[Loader] ShowIgnoreOpen`. Keep the old helper for compatibility. Tests advance to v1.202; stable v1.188 remains untouched.

## 1.207 nested SHOW & IGNORE

- Move the entire collapsible **SHOW & IGNORE** rollout into the top of the **SCRIPTS** rollout. The manager now has four top-level loader rollouts: PRESETS, OPTIONS, SOURCES, and SCRIPTS.
- Keep the three checkboxes, IGNORE field, callbacks, and `[Loader] ShowIgnoreOpen` persistence. SCRIPTS actions, live FILTER, and the full-height 1032 px TreeView move down when SHOW & IGNORE opens and up when it closes; the TreeView retains its height.

## 1.206 version in main title button

- Show the currently loaded manager version as **v1.206** after **REFRESH \\ RESTART** on the main .NET title button. Use the same formatted project-version value already used by the rollout title; preserve existing LMB/RMB actions and styling.

## 1.205 live SCRIPTS FILTER

- Add an editable **FILTER** field directly between the SCRIPTS action buttons and the 1032 px TreeView. Each text change filters the already-discovered script filenames and their relative folder paths, case-insensitively. A matching folder shows its scripts and descendants, with parent folders retained.
- Matching branches expand temporarily while searching. Clearing FILTER restores the complete SCRIPTS tree and previously persisted folder expansion states. The filter is session-only, is never saved to INI, and does not alter HOST / DIRECT / SKIP modes.
- Filtering rebuilds the visible TreeView nodes from cached script/group arrays; it does not rescan directories, execute scripts, or affect the separate persistent SHOW & IGNORE controls. Test v1.200 adds part 45. Live 3ds Max verification is pending.

## 1.204 SHOW & IGNORE rollout

- Move **VERSIONED FILES**, **CLEAN SCRIPTS**, **COLLAPSE DIRS**, and the single-line **IGNORE** field from SCRIPTS into their own collapsible **SHOW & IGNORE** rollout, placed between SOURCES and SCRIPTS.
- SCRIPTS now contains only `LOAD SCRIPTS`, `CREATE TOOLBAR`, `SAVE UI`, and the 1032 px script TreeView. The TreeView moves upward without losing height.
- The new rollout has an independent `[Loader] ShowIgnoreOpen` state (expanded by default). Filter INI keys, immediate checkbox behavior, deferred IGNORE save via LMB REFRESH, and source discovery remain unchanged. Test v1.199 adds part 44; live 3ds Max verification is pending.

## 1.203 SCRIPTS directory pruning

- SCRIPTS discovery now omits directories that contain no `.ms`, `.mcr`, `.mzp`, or `.mse` files in their complete non-ignored subtree. A parent with qualifying files further below remains visible; empty folders and directories containing only unrelated files disappear by default.
- One native dictionary caches directory eligibility per discovery pass. This applies in both **COLLAPSE DIRS** modes without changing its same-name folder flattening rule, saved load modes, or source paths. Existing `.git` and IGNORE exclusions remain active.
- `.mzp` counts toward directory presence only; execution and script-leaf discovery retain their existing supported types. Regression test v1.198 adds part 43. Live SCRIPTS rendering in 3ds Max is not yet verified; stable v1.188 is untouched.

## 1.202 SCRIPTS TreeView load diagnostics

- Double-click on `.ms` / `.mcr` and RMB **LOAD SCRIPT** now print `[Script-Manager][TREE LOAD] START`, `OK` or `FAILED` to MAXScript Listener. Each record identifies the triggering action, selected item, actual `.ms`/`.mcr` path and its existence, configured load mode, and forced `#standalone` execution mode.
- Failed loads also log a reason (missing file, unsupported type, manager busy/excluded) or the captured `fileIn` exception, including errors from nested script dependencies. This is diagnostic-only; original direct-load behavior and persisted load modes are unchanged.
- Regression test v1.197 adds part 42. Static validation done; live tree-item load testing is pending.

## 1.201 registered floating-dialog position restoration

- Adopt the user-verified `CODEBASE/Functions/UI/Registered-Dialog-Position-Offset-Fix` v0.04 geometry calculation for floating dialogs. Convert saved registered raw position to the unregistered `createDialog` position by subtracting the pre-registration `[6,-2]` and measured native registration shift `[6,29]`, then apply `[6,-2]` **before** `cui.RegisterDialogBar`. Never call `setDialogPos` while registered.
- Guard `moved` and `resized` INI writes throughout shutdown (including removal of child rollouts) using `is_destroying_manager` or `is_destroying_host`. The previous restart path saved the correct floating position, then `cui.UnRegisterDialogBar` could raise another move/resize callback that overwrote the INI with unregistered coordinates. Save once while still registered, before unregister/destroy.
- Keep docked left/right placement, existing INI keys, the main/host dialog sizes, and the `[Script-Manager][XY]` Listener diagnostics unchanged. Main and host use the same pre-registration function; no unrelated script execution behavior is modified.
- The three SCRIPTS filter checkboxes from v1.200 remain on the same row, with titles **VERSIONED FILES**, **CLEAN SCRIPTS**, and **COLLAPSE DIRS**. Regression suite v1.196 updates part 34 and adds part 41 for pre-registration geometry, repeated mathematical cycles, and shutdown-save suppression.
- Static checks passed. Full floating/docked restart behavior must be tested in 3ds Max because the MCP bridge was disconnected. Working CODEBASE baseline v0.04 and stable Script-Manager v1.188 are unchanged.

## 1.200 SCRIPTS checkbox labels and single-row layout

- Rename `SHOW VERSIONED FILES` to **VERSIONED FILES**, and `CLEAN SCRIPTS ONLY` to **CLEAN SCRIPTS**. Keep **COLLAPSE DIRS** unchanged.
- Place all three native checkboxes on one horizontal row directly beneath the SCRIPTS action buttons, without changing the dialog width, the IGNORE field or TreeView positions.
- Preserve all three existing event handlers, filter logic, and `script_manager.ini` keys (`ShowVersionedFiles`, `CleanScriptsOnly`, `CollapseDirs`). Test v1.195 adds regression part 40. Stable v1.188 remains untouched.

## 1.199 COLLAPSE DIRS toggle

- Add **COLLAPSE DIRS** to the SCRIPTS rollout beside IGNORE, without reducing the 1032 px TreeView viewport. Its default is ON, preserving the compact display from earlier releases; the new `[Filter] CollapseDirs` key in `script_manager.ini` saves OFF/ON as `0`/`1`.
- **ON:** Hide a tool directory only when its sole displayed script shares its name and no other visible child scripts or branches require the folder. **OFF:** Show the complete discovered SCRIPTS directory hierarchy, including those same-named tool folders. The checkbox immediately repopulates the existing SCRIPTS TreeView without rescanning or running scripts.
- Folder paths, TreeView state keys, saved expansion states, SKIP/HOST/DIRECT modes, script loading, and SOURCES behavior are unchanged. Regression test v1.194 adds part 39; real 3ds Max UI verification remains required. Stable v1.188 is untouched.

## 1.198 double-click script execution

- SCRIPTS single-click selects a filename without running it. Double-click on the `.ms` or `.mcr` **filename label** runs that script through the existing forced standalone `LOAD SCRIPT` path.
- The checkbox image still cycles the persisted SKIP/HOST/DIRECT mode; double-clicking the image, a folder, or an `.mse` filename does not execute a script. RMB `LOAD SCRIPT` is unchanged.
- Regression suite v1.193 updates part 35 to verify the double-click event binding, label-only execution gate, and MS/MCR loading versus MSE/folder exclusion. Stable v1.188 remains unchanged; runtime UI clicking still needs confirmation in 3ds Max.

## 1.197 main dialog minimum height

- The main floating Script-Manager dialog can resize down to **1024 px**. CUI registration uses `minSize:[336,1024]`, and any saved height below 1024 is clamped to 1024 when restored.
- Keep the original 1970 px default height, existing maximum of 2000 px, and independent hosted-dialog minimum of 300 px unchanged. No changes to the 1032 px SCRIPTS TreeView content height or expansion/position behavior.
- Regression test v1.192 adds part 38 for the minimum, saved taller sizes, maximum clamp, and CUI minSize. Stable v1.188 stays unchanged. Full runtime verification is pending.

## 1.196 SCRIPTS expansion-state persistence

- SCRIPTS startup now restores folder expand/collapse values persisted in `script_manager.ini` instead of forcing every folder collapsed. Newly discovered folders default to collapsed.
- While clearing or repopulating the SCRIPTS TreeView, programmatic events cannot overwrite the saved expansion values. Test v1.191 adds part 37.

## Version

Production uses one synchronized release number everywhere:

- file version: `1.211`
- project version: `1.211`
- loader dialog title: `Script-Manager 1.211`
- generated host-dialog titles: `<Parent Folder>`
- visible loader version is shown in the main dialog title; the redundant top info/version labels are removed

The production snapshot for this release is `Script-Manager_1.211.ms`.

**Stable MVP baseline: `1.188` (user-confirmed, 2026-10-28).** The immutable reference is `Script-Manager_1.188.ms`. The previous stable baseline was `1.153`; future development should branch from the last stable v1.188 snapshot and preserve that release unchanged.

## 1.195 dialog position Listener diagnostics

- Prints `[Script-Manager][XY]` diagnostics in the MAXScript Listener for the main Script-Manager window and hosted rollout dialogs. Each entry includes dialog identifier, lifecycle stage, dock state, saved INI X/Y, actual `getDialogPos` X/Y, and their difference.
- Logged stages: INI-RESTORE, BEFORE-CUI-REGISTER, AFTER-CUI-REGISTER, AFTER-DOCK-RESTORE, READY, and SAVE-BEFORE-WRITE; MAIN and HOST MOVED-EVENT callbacks are also logged to expose late CUI moves after restoration.
- This is a diagnostic-only build: the v1.193 floating X−1/Y−1 correction and INI save behavior are unchanged. The test file advances to v1.190 and adds part 36 for trace coverage and side-effect-free invocation.

## 1.194 single-click script execution

- Left-click on the **filename label** of an `.ms` or `.mcr` SCRIPTS TreeView leaf now immediately uses the existing forced standalone `LOAD SCRIPT` path, independently of its SKIP/HOST/DIRECT state. Persisted mode and batch/host dialogs remain unchanged.
- Clicking the checkbox image still **only changes its saved mode**; clicking folders, expansion glyphs, empty/indent areas, or `.mse` labels does not execute scripts.
- Removed the duplicate `NodeMouseDoubleClick` event registration; `NodeMouseClick` filters `Clicks > 1` so the second click of a double-click does not trigger an extra run. Existing helper methods remain available for compatibility.
- Regression test v1.189 adds part 35 for event wiring, label/checkbox hit gates, and standalone execution of MS/MCR versus ignored MSE/folder rows. Stable v1.188 stays unchanged. Live 3ds Max testing is still required.

## 1.193 pre-registration floating-dialog XY correction

- Compensate the reported 1-pixel drift from CUI registration by placing **floating** main and hosted dialogs at saved X−1, Y−1 before `cui.RegisterDialogBar`. Keep the exact saved INI position unchanged; A temporary live 3ds Max probe confirmed that decreasing the pre-registration coordinates by one pixel decreases the final registered coordinates by one pixel on each axis. Exact saved-position restoration still needs an integrated reopen test.
- Align the pre-registration `getDialogPos` / `setDialogPos` verification with the corrected initial position. Do not call `setDialogPos` on a registered rollout, which Autodesk explicitly prohibits. Docked left/right dialogs retain the original position parameter.
- Test v1.188 adds part 34 covering the floating (−1, −1) offset, docked no-op, and preservation of the supplied position. The isolated CUI comparison passed in 3ds Max; full Script-Manager repeat-open geometry testing is still pending. Stable MVP v1.188 remains unchanged.

## 1.192 fix .NET context-menu separator reference crash

- Fixed v1.191 `Unknown property: "visible" in 3` at line 5426: `ContextMenuStrip.Items.Add(dotNetObject "ToolStripSeparator")` returns the numeric insertion index, not the separator object. The update callback then attempted `.Visible` on that integer.
- Create each `ToolStripSeparator` in a persistent manager field **before** calling `Items.Add separator`, keeping four real .NET object references in SOURCES and SCRIPTS. Both existing menu section separators and context-sensitive visibility are preserved.
- Regression test v1.187 adds part 33 to verify all four separator references are .NET `ToolStripSeparator` objects and both context-state callbacks complete without the integer-property exception. The SOURCES `.git`/script-bearing discovery and grouped menu order from v1.191 remain unchanged.
- Static checks passed; runtime verification inside 3ds Max is still required. Stable v1.188 remains untouched.

## 1.191 context-menu sections and SOURCES script-only filtering

- SOURCES and SCRIPTS right-click menus group commands in **OPEN**, **COLLAPSE**, and **EXPAND** order with separators between visible groups. OPEN includes existing load/open commands; COLLAPSE precedes EXPAND and its ENABLED variant. File-row menus hide inappropriate branch commands without leaving empty separators.
- SOURCES lists only directories with at least one `.ms`, `.mcr`, or `.mse` file somewhere inside their subtree. Empty folders, non-MaxScript-only folders, and their non-script descendants are excluded. A per-discovery dictionary cache avoids repeat scans. This check is independent of the SCRIPTS version filter, clean-only filter, and IGNORE mask.
- `.git` directories are always excluded from SOURCES and recursively skipped by SCRIPTS discovery even if the editable SCRIPTS IGNORE input is cleared. Existing user-defined SCRIPTS IGNORE patterns are unchanged. The `.git` default text remains available in IGNORE.
- Regression test v1.186 updates part 2 and adds part 32 for menu ordering/separators, nested `.mcr`/`.mse` source recognition, non-script-only directories, and `.git` exclusion. Stable MVP v1.188 remains unchanged. Runtime verification in 3ds Max pending.

## 1.190 disable checked-state text formatting

- SCRIPTS TreeView text uses one neutral foreground for SKIP, HOST, and DIRECT; checkbox glyphs still communicate each load mode and folders retain their existing bold labels.
- `applyScriptTreeNodeColor` remains as a compatibility helper but resets any old orange/batch color to the standard foreground. SCRIPTS state synchronization no longer builds the expensive batch-dialog color cache.
- Rendering hierarchy, persisted modes, SOURCES, ROOT PATH, filters, startup, and stable v1.188 are unchanged. Regression test part 31 covers the neutral text for all three modes; test version 1.185. Runtime verification in 3ds Max is pending.

## 1.189 SCRIPTS parent-folder precedence

- SCRIPTS renders all folders that must be visible **before** adding script file leaves. A script is always nested under its containing directory when that directory is displayed in the tree, even if the legacy one-script flattening rule would otherwise place it in the parent's parent.
- Same-name script folders with no visible folder node can still be flattened for a compact view. Directory names, script load modes, ROOT PATH, filters, host assignments, and node tooltips remain unchanged.
- The folder-preparation pass is cached in the existing native dictionary and stays inside the TreeView update batch. Regression test part 30 (test file v1.184) checks a present-parent case, no duplicate leaf, legacy flattening when the parent is absent, and restoration of the test configuration.
- Stable MVP stays v1.188; v1.189 needs user confirmation in 3ds Max before being marked stable.

## 1.188 default script-file visibility and floating position stability

- `SHOW VERSIONED FILES` starts **checked** on new installations or when `[Filter] ShowVersionedFiles` is absent. A saved `0` remains OFF and a saved `1` remains ON. No existing user setting is overwritten.
- While creating/re-registering floating Script-Manager and hosted tool dialogs, suppress automatic `moved`/`resized` INI geometry writes. This prevents initialization's transient 1-pixel movements from replacing the previous position.
- Before CUI registration, compare each newly created floating dialog's actual `getDialogPos` with its saved `pos` and correct it with `setDialogPos` if needed. No undocumented hardcoded pixel offset or forced move of already registered dock bars.
- Test v1.183 adds parts 28/29 for missing-versus-saved version filter states and dialog-restore callback guards. Exact on-screen drift after CUI registration still requires confirmation in 3ds Max.

## 1.187 first-start and REFRESH scope repair

- Explicitly declare `script_manager_options_ui` global before the dynamically executed OPTIONS rollout is compiled. PRESETS, OPTIONS, SOURCES, and SCRIPTS now use persistent rollout slots rather than an accidental file-local binding.
- Explicitly declare the runtime callbacks `scriptManagerRefreshButtonMouseUpHandler`, `scriptManagerInitialLoaderTickHandler`, `scriptManagerTreeOpenGroupContextHandler`, and the `scriptManagerPersistIgnoreMask` helper global before those functions are defined. This prevents a function/parameter from referencing an expired `fileIn` lexical frame (the observed `requested_mask` local-thunk error).
- `buildLoaderRollout()` now reports attached rollout counts and which sections were resolved on failure instead of only a generic exception.
- No change to the accepted 1.186 render optimization, root-path save logic, IGNORE value semantics, or script execution. Test 1.182 adds `partOfTest27()` for persistent global slots and four attached UI sections, and corrects stale version assertions in test 1. Static checks only; runtime verification in 3ds Max remains necessary.

## 1.186 SCRIPTS TreeView render optimization

- Build one sorted batch-dialog color palette and script-to-host dictionary per TreeView state synchronization, rather than rebuilding the entire script/source/INI lookup for every HOST script row.
- Reuse cached host paths to assign the identical stable palette index and HOST colors. Discard both caches at the end of synchronization, including error cases, so source changes and manual script-state updates cannot reuse stale data.
- Apply node states and colors inside `BeginUpdate()` / `EndUpdate()` to avoid repainting once per node. Report folder-building, file-building, and state/color synchronization durations separately from the total render time.
- Keep SOURCES, ROOT PATH, IGNORE, dialog grouping, and file discovery unchanged. Test 1.181 adds part 26 for cache parity and cleanup; live 3ds Max timing still needs verification.

## 1.185 IGNORE local-thunk repair

- `saveScriptIgnoreMask()` raised `Bad local thunk local member index when accessing local: mask_text` at its entry on v1.184. The error occurs before the intended INI write; it is not evidence of a failed INI setting.
- The validated IGNORE save/readback and active-mask update were moved to a standalone global function `scriptManagerPersistIgnoreMask`, outside the large `script_manager_v` method frame. `applyPendingScriptOptions()` calls it directly from the edited control value; the existing `saveScriptIgnoreMask` API remains as a thin compatibility wrapper.
- No changes to ROOT PATH, BROWSE, SOURCES or TreeView discovery. Test 1.180 adds `partOfTest25()` for nonempty/empty IGNORE persistence, normalized patterns, and compatibility API invocation, restoring all test state on exit.
- This remains a development candidate until the user confirms runtime behavior inside 3ds Max.

## 1.184 repair status

ROOT PATH and SOURCES were user-confirmed working in 1.183. The subsequent SCRIPTS `get_Item` runtime failure is addressed by native MAXScript dictionaries for SCRIPTS render caches. The supplied trace also confirms IGNORE passed INI write/readback before that rendering failure. A dedicated save-success message now exposes its persisted value and INI location independently of tree success.


BROWSE saves the accepted ROOT PATH and immediately rebuilds SOURCES/SCRIPTS. Cancel leaves the edit unchanged. Manually typed ROOT PATH and IGNORE edits remain pending until LMB REFRESH; browsing also commits the pending IGNORE value through that same pipeline.

Declared rollout controls are accessed directly after rollout-existence checks. Loader errors preserve their references, and missing IGNORE controls produce an explicit save failure. Existing INI values are retained; the supplied INI still points to its previously saved root until a new selection is applied.

Regression suite 1.179 includes part 24 for browse commit, both trees, and empty/nonempty IGNORE round trips. Live verification remains pending because the 3ds Max connection returned `Session terminated`. Static checks do not establish runtime correctness.

## Purpose

Script-Manager manages which parts of the shared MaxScript tree are scanned and which scripts are loaded.

Supported script types are `.ms`, `.mcr`, and `.mse`. When the same directory contains `<Name>.ms` and `<Name>.mcr`, the `.mcr` entry is hidden and only the `.ms` file is exposed as the managed script.

The loader has two TreeViews:

- `SOURCES` — an organizational directory tree below the active source root. `OPTIONS` contains ROOT PATH/BROWSE and the SHOW and IGNORE sections. The default root is derived from the Script-Manager location, while a custom root can be typed (apply with LMB REFRESH) or selected (BROWSE applies immediately) and persisted in the repository-local `script_manager.ini`. On first use, an existing legacy INI in 3ds Max `plugcfg` is copied into the repository if the new INI is missing. Missing drives do not erase the remembered ROOT PATH. The editable SCRIPTS IGNORE filter does not affect SOURCES; SOURCES independently excludes `.git` and directories with no `.ms`/`.mcr`/`.mse` descendants. The ROOT PATH edit is single-line, and its saved value is assigned to the OPTIONS control after the rollout is attached, so it is visible on first launch and remains correct after a full reload. A directory becomes a display-only hierarchy stopper when it contains an unversioned `.ms` file whose basename exactly matches the directory name, for example `script-name\script-name.ms`, and has a supported script descendant. Stopper rows stay visible, have no checkbox at any nesting depth, and do not show children. Other directories remain selectable recursive sources with the existing checkbox glyph style. SOURCES reserves image slot 0 as a transparent row image so stopper rows remain visually checkbox-free. The managed root itself is not shown as a redundant source item.
- `SCRIPTS` — scripts found under the checked sources, displayed in the 1032 px TreeView with persisted tri-state load modes. `LOAD SCRIPTS` LMB performs a soft update and RMB performs a full hard reload. The visibility filters and IGNORE mask live in OPTIONS under SHOW and IGNORE. IGNORE masks are pipe-separated and case-insensitive; plain names match exactly, while `*` and `?` use native wildcard matching. Matching folder names remove that complete subtree from SCRIPTS, while matching script filenames or basenames remove only those script leaves. Legacy `.*` wildcard shorthand is normalized to `*`. Editing IGNORE does not scan live; LMB `REFRESH \ RESTART` saves it to `[Filter] ScriptIgnoreMask` in `script_manager.ini` and rebuilds the filtered SCRIPTS tree. Its single .NET `MouseUp` dispatcher saves IGNORE before validating ROOT PATH; failure diagnostics and refresh counts are printed to the MAXScript Listener. If ROOT PATH is invalid, IGNORE is still saved but the tree cannot be rebuilt until ROOT PATH is corrected. Keeping the native editText under 17 px prevents ENTER from adding a newline to its mask.

`SCRIPTS` also mirrors organizational directories from the checked source tree when the directory does not contain its own canonical same-name `.ms` file. Each checked SOURCES item becomes a top-level SCRIPTS root for its discovered subtree; unchecked ancestors above that source are omitted instead of wrapping the visible scripts. SCRIPTS now prunes organizational categories without `.ms`/`.mcr`/`.mzp`/`.mse` files anywhere in their non-ignored subtree; SOURCES independently applies its existing script-bearing directory filter. Directories that do contain `<FolderName>.ms` remain tool folders and are represented by their script rows instead.

On initial loader creation, SCRIPTS restores saved folder expansion states and unseen folders start collapsed. Later in-place refreshes may restore saved folder expansion state. Initial filesystem discovery and construction of PRESETS, OPTIONS (with SHOW and IGNORE), SOURCES, and SCRIPTS are performed immediately after the manager dialog is created, registered, docked, and has processed its first window messages; no delayed Windows Forms timer is needed. This makes both trees available on the first UI opening. Each tree is populated only once during that startup: the child rollout `open` event handles initialization when its control becomes available, and the loader's guarded fallback covers already-created controls without rendering twice. Source discovery is completed before TreeView population, and render-local lookup tables replace repeated linear folder lookups (native dictionaries in SCRIPTS; a .NET Hashtable in SOURCES). SCRIPTS computes a temporary index of direct script counts and descendant groups once per render to speed up single-script folder flattening. Manual REFRESH still rescans the filesystem to include added, removed, and renamed files.

For display only, `SCRIPTS` flattens redundant terminal tool folders **only when that folder does not already exist as a visible tree node**. When a folder has exactly one visible script, has no visible descendant scripts, and that script basename matches the folder name, the folder node may be omitted and the script leaf shown directly in the parent. For example, `Loop Tools > Remove-Verts > Remove-Verts.ms` is displayed as `Loop Tools > Remove-Verts.ms`. The real script path, persisted load mode, and HOST/DIRECT behavior are unchanged.

The loader UI uses four top-level collapsible rollouts plus two nested OPTIONS sections:

- the main dialog header contains a full-width .NET `REFRESH \ RESTART` title-style button; LMB saves/applies pending OPTIONS and refreshes the existing SOURCES/SCRIPTS trees in place, while RMB restarts/version-reloads Script-Manager;
- `PRESETS` is the top rollout and contains the preset dropdown plus `SAVE \ REMOVE`, `LOAD`, `MACRO`, and `STARTUP`;
- `OPTIONS` contains ROOT PATH with BROWSE and two nested sections: **SHOW** for the three SCRIPTS visibility checkboxes, and **IGNORE** for the persistent mask;
- `SOURCES` contains only the SOURCES TreeView;
- `SCRIPTS` contains `LOAD SCRIPTS`, `CREATE TOOLBAR`, `SAVE UI`, a transient live FILTER field, and the SCRIPTS TreeView.

The rollout titles provide the section names. PRESETS, OPTIONS, SOURCES, SCRIPTS, and nested SHOW/IGNORE expanded states are persisted independently in `script_manager.ini`.

Selecting a preset only selects it. `LOAD` restores its SOURCES and SKIP / HOST / DIRECT configuration and then performs a hard configured-script load. `SAVE \ REMOVE` keeps the existing save/remove behavior. `MACRO` creates or updates a persistent MacroScript action in the `Script-Manager Presets` category for the selected preset; that action can be placed on a toolbar and uses the same full preset-load path. `STARTUP` marks the selected preset as the unique startup preset. Script-Manager installs a small loader in the current 3ds Max user startup-scripts folder; on the next 3ds Max launch it opens Script-Manager, applies that preset, and loads its configured scripts once. Clearing STARTUP removes that loader.

Source checkbox states and script tri-state modes are stored in `G:\CODE\MAXSCRIPT\Script-Manager\script_manager.ini` (beside the main script). Newly configured roots that have no enabled sources automatically enable selectable top-level SOURCES directories once; later intentional all-OFF source choices remain off. If the root contains only terminal tool folders (no selectable SOURCES rows), SCRIPTS scans those root children directly instead of remaining blank. Filter states, the custom source root, the SCRIPTS ignore mask, TreeView expanded/collapsed states, rollout states, dialog geometry, and dock states are also persisted there. If both a parent source and one of its descendants are checked, the descendant is not scanned a second time because the parent already covers that subtree.

When a previously checked hierarchy-stopper folder becomes a display-only no-checkbox row in `SOURCES`, Script-Manager migrates that checked state to its visible selectable parent and clears the stopper-folder source setting. Stopper classification is content-based: `FolderName\FolderName.ms` ends SOURCES hierarchy traversal at `FolderName`, even when helper files or child directories exist below that tool folder. A directory without supported MaxScript descendants is omitted entirely from SOURCES. A non-empty leaf folder without a same-name `.ms` file remains a selectable source.

A checked SOURCES item can also explicitly define a batch dialog. The first checked ancestor is discovery-only and is ignored for batch ownership; the second checked ancestor owns the complete batch subtree. RMB on that explicit checked dialog item shows `LOAD \ RELOAD DIALOG`, which loads or hard reloads only configured HOST scripts assigned to that one batch dialog. DIRECT and skipped scripts, other batch dialogs, and the first checked discovery source are not affected.


## Hosted tool dialogs

The loader stays in the single `Script-Manager` dialog. Loaded tool UI is no longer routed through one central `Loaded Scripts` dialog.

For a script discovered in a tool folder, Script-Manager uses the tool folder's immediate parent path as the organizational host path. All tool folders that share that parent therefore share one dialog.

Example:

```text
Wall Tools/
├─ Wall-Cleaner/
│  └─ Wall-Cleaner.ms
└─ Wall-Thickness/
   └─ Wall-Thickness.ms
```

creates one `Wall Tools` dialog. The declared rollout from `Wall-Cleaner` and the declared rollout from `Wall-Thickness` are added directly to that dialog's single subrollout slot. No generated intermediate category rollout exists between the dialog and the tool rollout.

Host dialogs are created lazily only when a successfully executed script exposes at least one rollout. Scripts without UI do not create empty dialogs. Failed embedding removes any newly empty host dialog.

Every organizational host dialog persists its own floating position, height, and left/right dock state in `script_manager.ini`. Tool rollout open/closed state remains persisted as well.

Host dialogs use a fixed 336 px dialog width with a 312 px content width, leaving enough room for the standard 288 px tool rollout plus native borders/scrollbar allowance.

Before an embedded HOST load redefines a script's rollout globals, Script-Manager closes any already-open standalone rollout instances resolved from the script source declarations or runtime registry. This prevents an old standalone window from surviving beside the newly embedded rollout after a batch load/reload.

Each generated host dialog has a full-width .NET button above the tool subrollout. Production host dialogs intentionally omit the Script-Manager version from both the native dialog caption and this button label; both show only the organizational parent-folder name. The button is flat and borderless, keeps the dark host background, and uses light-blue text `RGB 62,158,255`. LMB reloads only the HOST-mode scripts currently represented by that dialog; other host dialogs and DIRECT scripts are left untouched.
## Version filtering

`SHOW VERSIONED FILES` is off by default.

With the filter off, files in each directory are grouped by filename family:

- when an unversioned canonical file exists, only that file is shown;
- when no unversioned file exists, only the highest numeric `_version` file is shown;
- older versioned files stay hidden.

Example:

```text
Tool.ms
Tool_0.01.ms
Tool_0.02.ms
Only_0.01.ms
Only_0.03.ms
```

Default visible result:

```text
Tool.ms
Only_0.03.ms
```

Enable `SHOW VERSIONED FILES` to expose all versions.

`CLEAN SCRIPTS` is a persisted tri-state filter. OFF uses normal visibility; ON keeps only an unversioned script matching its immediate folder name, for example `MyTool\MyTool.ms`; MIXED (indeterminate) uses the same strict rule when a matching script exists, otherwise displays all eligible scripts in that unmatched directory. The setting takes priority over `VERSIONED FILES` while ON or MIXED.

For `.ms` files, an optional sibling `<ScriptName>-UI.ms` companion is loaded automatically when present. Paired UI companions stay hidden as separate manual-load targets.

## Tree layout and ordering

The `SOURCES` TreeView has a fixed working height of 512 px for clearer source-tree navigation.

The `SCRIPTS` TreeView has a minimum working height of 1032 px so large source sets can remain visible with much less scrolling. Moving preset controls into PRESETS restores the full 1032 px script viewport. The floating manager dialog opens tall enough to expose PRESETS and both tree viewports by default.

Inside each script folder, visible script files are ordered by filesystem last-write time with the newest files at the top. Folder hierarchy ordering remains alphabetical.

Script file rows always use the standard foreground color, regardless of their HOST, DIRECT, or SKIP load mode. The checkbox glyph shows the mode, and bold folder labels are preserved.

`.ms` script leaves use three always-visible checkbox glyphs drawn by Script-Manager instead of the Windows themed checkbox renderer:

- empty box — do not load;
- checked box — load in embedded mode and add declared rollouts to the shared parent-folder dialog;
- box with `-` — load only the selected script in standalone mode and run it normally without adding its rollouts to a shared dialog.

The glyph is rendered through the TreeView image column so it remains visible in 3ds Max dark UI.

Folder rows use a derived activity indicator: if any descendant script is configured as HOST or DIRECT, that folder and every ancestor folder show the checked glyph. This makes active content visible even while a branch is collapsed. If no descendant script is active, the folder shows the empty glyph.

Legacy INI values remain compatible: `0`/missing means unchecked, `1` means checked/hosted, and the new direct mode is stored as `2`.

RMB behavior is context-sensitive. The first folder-only command, `OPEN GROUP`, loads every visible script below the clicked folder (including all nested subfolders) as hosted scripts in a single shared rollout dialog titled for that folder. It deliberately includes OFF and DIRECT scripts without changing their saved OFF/HOST/DIRECT modes; scripts with no rollout still execute, but contribute no visible panel. Repeating `OPEN GROUP` reloads its dialog, and the dialog title button preserves this forced grouping during reload. IGNORE and other visible-tree filters continue to define which scripts appear in the subtree. Folder items keep the tree navigation commands (`EXPAND`, `COLLAPSE`, `EXPAND ALL`, `COLLAPSE ALL`). `EXPAND ENABLED` is also available from the SCRIPTS right-click menu on either folder or file rows: it collapses inactive branches, then expands only the folders containing configured HOST or DIRECT scripts. It uses the already-synchronized tree state images without rescanning directories or loading scripts. Script leaves show `LOAD SCRIPT`. Both script leaves and folder rows show the same single `OPEN IN EXPLORER` command. It requests administrator elevation (`runas` / Windows UAC) by default while selecting a script file or opening the represented folder. Windows Explorer may instead reuse its existing non-elevated desktop process, so the resulting window's administrator rights are not guaranteed. Cancelling elevation is reported as a launch failure. `LOAD SCRIPT` force-runs only the selected script in standalone/direct mode regardless of its saved OFF/HOST/DIRECT mode or current-running state. It never embeds the script or its rollout into a Script-Manager batch/host dialog, never host-loads an optional `-UI.ms` companion, does not clear or rebuild existing batch dialogs, and leaves the saved tri-state mode unchanged. Double-clicking the `.ms` or `.mcr` filename uses this same direct-load path. Single-click selects only; clicking the state image only changes the saved mode; `.mse` and folders are not executed. Manual or menu-driven expansion state is stored in `script_manager.ini` and restored when the loader is rebuilt.

## Loading behavior

`RELOAD` is discovery-only:

1. restores `SHOW VERSIONED FILES` and `CLEAN SCRIPTS ONLY` from `script_manager.ini`;
2. reads checked `SOURCES`;
3. scans only those source trees using the restored filter state;
4. rebuilds the `SCRIPTS` tree;
5. restores the persisted tri-state display;
6. does not execute discovered scripts.

The same filter restore happens during initial dialog creation, so the first `SCRIPTS` tree already matches the saved INI filter settings without requiring a manual filter toggle or extra reload.

`LOAD SCRIPTS` has two related load modes on one button.

LMB performs a soft update of the configured scripts:

1. skips unchecked scripts;
2. checks whether each configured script is actually running before executing it;
3. first treats an open standalone rollout/dialog owned by the script as running;
4. then treats a live Script-Manager HOST/batch dialog containing that script as running;
5. for scripts with no detectable UI, treats one successful load in the current manager session as running;
6. loads only scripts that are not currently running.

This means closing a standalone tool dialog makes only that tool eligible for the next soft update. Closing one HOST/batch dialog similarly makes only scripts represented by that closed host eligible for recovery. Scripts whose dialogs/hosts are still live are not re-executed.

RMB performs the hard reload behavior:

1. clears manager-hosted rollouts/dialogs from the previous hosted load set;
2. skips unchecked scripts;
3. re-executes every configured HOST/DIRECT script regardless of current running state;
4. recreates required organizational host dialogs and embeds exposed rollouts.

Changing a script state updates only the persistent load mode. It does not immediately execute the script. `LOAD SCRIPTS` LMB applies it softly; RMB forces a complete reload.

`CREATE TOOLBAR` prompts for a toolbar name prefilled as `<Windows username> SCRIPT-MANAGER`. It creates a native toolbar with Script-Manager first, followed by every HOST and DIRECT script in the current SCRIPTS tree order; OFF scripts are omitted. Script actions use standalone loading behavior. The current UI is saved to a temporary CUIX, that temporary file is patched and loaded immediately, and the new toolbar is shown without a manual UI reload.

`SAVE UI` is enabled by default. When enabled, toolbar creation also saves the loaded configuration back to the CUIX that was active before generation and reloads that original CUIX. Turn it off to keep the generated toolbar only in the temporary CUIX loaded for the current session.

Double-click on an `.ms` or `.mcr` filename executes it immediately through the forced direct-load path. Single-click only selects; LMB on its checkbox glyph cycles the persisted load mode. RMB `LOAD SCRIPT` on a script leaf is a forced direct execution path: it re-runs that script immediately, bypasses batch hosting, and does not change the persisted checkbox mode.

A script with no rollout is still a successful load when `fileIn` succeeds, but it does not create an empty host dialog. Soft update remembers that no-UI script as loaded for the current Script-Manager session so it is not executed repeatedly.

## Refresh / Load Scripts / Restart

The loader exposes these primary actions:

- `REFRESH \ RESTART` in the main dialog header — `LMB` rescans selected sources and rebuilds the loader trees without executing scripts.
- `REFRESH \ RESTART` — `RMB` restarts Script-Manager by loading the newest numeric `Script-Manager_*.ms` release when available, otherwise reloads the currently running source.
- `LOAD SCRIPTS` in the `SCRIPTS` rollout — `LMB` soft-updates only configured scripts that are not currently running.
- `LOAD SCRIPTS` — `RMB` hard-reloads every configured script, rebuilding manager-hosted UI as needed.
- `CREATE TOOLBAR` — prompts for a name and immediately builds a native toolbar from all HOST and DIRECT scripts.
- `SAVE UI` — controls whether that generated toolbar is persisted to the previously active CUIX; it starts enabled.

F1 still performs the same restart action.

Restart uses quiet `fileIn` loading.

## Listener output

Normal discovery, reload stages, successful script loads, source paths, and per-file scan messages are quiet by default because heavy Listener output significantly slows large scans.

Detailed success tracing remains behind the internal `debug_logging` flag. Errors continue to report normally.

Tree-performance diagnostics are printed independently of `debug_logging` while this performance investigation is active. Each refresh/build reports separate millisecond timings for `SOURCES DATA PREP`, `SOURCES TREE RENDER`, `SCRIPTS DATA PREP`, and `SCRIPTS TREE RENDER`, including folder/script counts so filesystem discovery can be distinguished from WinForms TreeView rendering.

## Runtime modes

The generic runtime modes are:

- `#standalone`
- `#library`
- `#embedded`

The generic globals are:

```maxscript
global SCRIPT_MANAGER_RUNTIME_MODE
global SCRIPT_MANAGER_REGISTRY
global script_manager_project_version
global ScriptManagerIntegration
```

Existing EPoly tools remain compatible through the `EPolyToolsIntegration` and `EPOLY_TOOLS_RUNTIME_MODE` compatibility aliases.

## Package

```text
Maxscript/
├─ Script-Manager/
│  ├─ Script-Manager.ms
│  ├─ Script-Manager_1.187.ms
│  ├─ Script-Manager.md
│  ├─ changes.md
│  └─ tests/
│     ├─ Script-Manager-test.ms
│     ├─ Script-Manager-test_1.175.ms
│     ├─ Script-Manager-test_1.160.ms
│     ├─ Script-Manager-test_1.158.ms
│     ├─ Script-Manager-test_1.153.ms
│     └─ Script-Manager-test_1.139.ms
├─ Epoly/
├─ Modules/
├─ UI/
└─ ...
```

The canonical regression test is `tests/Script-Manager-test.ms`. This release uses test version `1.205` and project version `1.211`; part 45 covers live FILTER filename/folder matching, case-insensitivity, no-result handling, mode persistence, and expansion restoration. Part 44 retains the independent SHOW & IGNORE tests. The suite also covers repository-local INI, ROOT PATH persistence, script discovery after switching root, two synchronous cold-start openings without a RESTART, the IGNORE/REFRESH interaction, `OPEN GROUP`, Explorer elevation, selective expansion, caching, and INI persistence.

## Safety

- Unchecked source trees are not recursively scanned.
- Display-only `SOURCES` tool-directory rows have no checkbox and are never treated as selectable source roots.
- Script discovery does not execute files by itself.
- Runtime rollout/dialog titles are resolved before declaration and are never mutated after creation.
- Load failures remain failures.
- Failed rollout embedding is never recorded as a loaded script.
- Script-Manager does not prune unrelated entries from the shared registry.
- Generic and EPoly compatibility runtime modes are restored after managed loads.
- Soft update checks live standalone/host dialog state instead of trusting only a historical loaded flag.
- Scripts with detectable UI are eligible for recovery when that UI is closed; no-UI scripts are executed only once per manager session unless a hard reload is requested.
- Toolbar creation patches only the same-named toolbar block in a temporary CUIX and preserves other toolbar definitions. Canceling the name prompt changes nothing.

