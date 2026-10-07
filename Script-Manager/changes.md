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
