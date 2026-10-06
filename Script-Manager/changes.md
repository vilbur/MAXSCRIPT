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
