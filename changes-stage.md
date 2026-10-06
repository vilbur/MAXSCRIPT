# Changes

## 2026-09-26

- Project 0.23: `EPoly-Basics-selection.ms` 0.03 persists the tool sub-object mode and floating dialog position in `EPoly-Basics-selection.ini`; rollout button state is rebuilt from INI and no longer serves as persistent state.
- Project 0.22: `EPoly-Basics-selection.ms` 0.02 fully disconnects the rollout Vertex/Edge/Border/Polygon/Element state from the Modify-panel sub-object state; Get/Set use the rollout-owned level, and Edit Poly Set writes selection directly without activating or changing the modifier UI level.
- Project 0.21: `PolyToosManager.ms` 0.19 restricts CUI docking to the left and right sides only; floating and dock handles remain enabled, while top/bottom/all-edge docking flags are removed.
- Legacy saved `top` / `bottom` dock states now restore as floating, and `dockStateToText()` persists unsupported dock states as `float`.
- `PolyToosManager-test.ms` 0.16 / project 0.21 verifies the allowed registration-style flags and sanitization of old top/bottom INI states.
- Project 0.20: `EPoly-Basics-selection.ms` 0.01 adds explicit file/project version metadata and changes the rollout title to the beautified filename, `EPoly Basics Selection | v0.20`.
- Moved `Two-Visible-Edge-Verts` into its own canonical folder at `Vertex Tools/Two-Visible-Edge-Verts/`; the canonical `Two-Visible-Edge-Verts_0.31.ms` file ID and code/version are unchanged.
- Project 0.19: `Vertex Tools/Two-Visible-Edge-Verts_0.31.ms` 0.31 fixes RMB removal by using the currently selected vertices intersected with the stable 2-edge detector, then calling native Remove Vertex on `Editable_Poly` / `Edit_Poly`; custom reconnect, weld, delete, and topology-remapping logic is no longer used by RMB.

## 2026-09-25

- Project 0.18: `PolyToosManager.ms` 0.18 makes the root `sr_tools` slot extend from its current Y position to the full bottom edge of the manager dialog with no bottom margin; nested category slots remain content-sized.
- `PolyToosManager-test.ms` 0.15 / project 0.18 verifies the root slot uses the full remaining dialog height.
- Project 0.17: `PolyToosManager.ms` 0.17 now sizes nested subrollout slots from the actual rendered HWND height of every child rollout, including native headers/borders/DPI, so all simultaneously open rollouts fit without clipping; the previous estimated header-height fallback remains for unavailable HWNDs.
- `PolyToosManager-test.ms` 0.14 / project 0.17 adds a multi-open regression that opens every child in one category and verifies the slot is at least the sum of their rendered heights plus the slot allowance.
- Project 0.16: `PolyToosManager.ms` 0.16 fixes nested `subRollout` sizing on the first category/tool open by scheduling one deferred forced hierarchy-layout pass after live rollout-state changes; the second measurement runs after 3ds Max finishes native rollout expansion.
- Category `rolledUp` events now queue the settling pass explicitly, while watcher-detected tool rollout changes queue the same pass automatically; the root `sr_tools` maximum-height policy is unchanged.
- `PolyToosManager-test.ms` 0.13 / project 0.16 adds a first-open regression that rebuilds a category closed, opens it once, processes the deferred pass, and verifies its child slot reaches the measured required height.
- Project 0.15: `PolyToosManager.ms` 0.15 resizes every nested category `subRollout` slot from the visible heights of its currently open/closed child rollouts; nested slots keep one extra 24 px rollout-header allowance, while the root `sr_tools` slot remains the only content slot maximized to the dialog height.
- Added a lightweight native rollout timer that refreshes nested slot heights only when tool/category open state or rollout content height changes, so opening or closing embedded tool rollouts immediately compacts/expands their parent slots.
- `PolyToosManager-test.ms` 0.12 / project 0.15 verifies root maximum-height layout and live nested slot resizing when a real embedded tool rollout is opened and closed.
- Project 0.14: added one directory-category layer below `EPolyTools`; current categories are `Loop Tools`, `Face Tools`, `Edge Tools`, and `General`.
- Moved `Redundant-Loop-Collapser`, `Redundant-Loop-Detector`, and `Missing-Loop-Rebuilder` under `Loop Tools`; moved `Degenerate-Face-Selector` under `Face Tools`; moved `Straight-Edge-Fixer` and `Two-Visible-Edge-Verts` under `Edge Tools`; `General` is the empty fallback category.
- `PolyToosManager.ms` 0.14 / integration 0.05 now discovers EPolyTools recursively and generates nested category rollouts from directory structure at arbitrary depth.
- Manager tool-enable persistence now uses relative tool paths while preserving legacy leaf-name settings as a fallback.
- `EPolyToolsIntegration.loadAllTools()` now resolves tools recursively below category directories.
- All current tools now search parent directories for `PolyToosManager.ms`, so standalone loading survives category moves and future deeper nesting.
- Updated tools: `Redundant-Loop-Collapser.ms` 0.05, `Redundant-Loop-Detector.ms` 0.27, `Degenerate-Face-Selector.ms` 0.10, `Two-Visible-Edge-Verts_0.30.ms` 0.30, and `Straight-Edge-Fixer.ms` 0.53.
- `PolyToosManager-test.ms` 0.11 covers recursive discovery, category rollout nesting, persistence, nested library loading, and canonical tool placement.
- Updated `PolyToosManager.md` with the directory-driven rollout contract and canonical tree.

## 2026-09-25

- Project 0.13: `PolyToosManager.ms` 0.13 fixes the generated loader rollout event signature to `on epoly_tools_loader_ui rolledUp state do`; the Boolean state now drives saved loader open/closed state, and the invalid separate `rolledDown` handler was removed.
- `PolyToosManager-test.ms` 0.10 / project 0.13 now toggles the actual loader rollout `.open` state and verifies the rollout event updates manager state without an argument-count error.
- Project 0.12: `PolyToosManager.ms` 0.12 fixes manager struct forward-reference calls by dispatching internal methods through `this`, preventing `Call needs function or class, got: undefined` during reload.
- Manager reload now formats `MANAGER SOURCE`, `MANAGER ROOT`, `ROOT PATH`, each `TOOL DIRECTORY`, each resolved `LOAD PATH`, and every reload stage to the Listener.
- `EPolyToolsIntegration_v` 0.04 accepts the sole `.ms` file in a tool subdirectory as a fallback when its basename differs from the folder basename.
- `PolyToosManager-test.ms` 0.09 / project 0.12 verifies resolved tool script paths during startup.
- Project 0.11: renamed the canonical self-contained manager from `EPolyToosManager.ms` to `PolyToosManager.ms`.
- `PolyToosManager.ms` 0.11 now owns the complete EPolyTools integration runtime; the separate `EPolyTools-Integration.ms` compatibility shim is removed.
- All current EPolyTools now bootstrap the integration runtime directly from `..\PolyToosManager.ms` in temporary `#library` mode and restore the caller runtime mode afterward.
- Updated tools: `Redundant-Loop-Collapser.ms` 0.04, `Redundant-Loop-Detector.ms` 0.26, `Degenerate-Face-Selector.ms` 0.09, `Two-Visible-Edge-Verts_0.29.ms` 0.29, and `Straight-Edge-Fixer.ms` 0.52.
- Renamed/updated the manager regression test to `PolyToosManager-test.ms` 0.08 and merged integration-runtime regression coverage into it; removed the separate `EPolyTools-Integration-test.ms`.
- Renamed integration documentation to `PolyToosManager.md` and updated examples to use the single manager entry point.

## 2026-09-25

- Project 0.10: `EPolyToosManager.ms` 0.10 now contains the complete EPolyTools integration runtime, so the manager is a self-contained single-file entry point with no runtime dependency on `EPolyTools-Integration.ms`.
- `EPolyTools-Integration.ms` 0.02 is now a compatibility shim only; it loads the manager headlessly in `#library` mode so existing standalone tools and external integrations keep working without duplicating the integration implementation.
- `EPolyToosManager-test.ms` 0.07 now loads only the manager file and verifies the embedded integration runtime; `EPolyTools-Integration-test.ms` 0.02 verifies compatibility-shim initialization against project 0.10.
- Updated `EPolyTools-Integration.md` to document the manager as the canonical integration source and the shim as backward compatibility.
- Project 0.09: added `EPolyTools-Integration.ms` 0.01 as the shared registry/runtime contract for standalone, library, and embedded loading.
- All current EPolyTools now register a stable tool ID, expose their API struct and rollout through the registry, support explicit `showUI()` / `hideUI()`, and remain headless in `#library` / `#embedded` mode.
- Updated current tools: `Redundant-Loop-Collapser.ms` 0.03, `Redundant-Loop-Detector.ms` 0.25, `Degenerate-Face-Selector.ms` 0.08, `Two-Visible-Edge-Verts` 0.28, and `Straight-Edge-Fixer.ms` 0.51.
- `EPolyToosManager.ms` 0.09 now loads tools through the shared `#embedded` runtime contract instead of allowing each tool to create and then close a standalone dialog.
- `EPolyToosManager-test.ms` 0.06 and new `EPolyTools-Integration-test.ms` 0.01 cover runtime-mode restoration, registry/API availability, manager embedding, and persisted manager UI state.
- Added `EPolyTools-Integration.md` with the integration contract and copy-paste examples for hosting one tool or all tools from another MaxScript.

## 2026-09-25

- Renamed `Redundant-Ring-Detector` to `Redundant-Loop-Collapser`; canonical folder/file and internal tool/UI identifiers now use the new name. `Redundant-Loop-Collapser.ms` is 0.02 / project 0.08; geometry behavior and `SELECT REDUNDANT RINGS` workflow are unchanged.
- `EPolyToosManager.ms` 0.08 / project 0.07: moved initial tool reload out of the rollout `open` callback and into a separate post-create stage after dialog creation/CUI registration; startup errors now report the exact failing stage instead of being masked as `Dialog creation failed`.
- `EPolyToosManager-test.ms` 0.05 uses project 0.07 and continues to require actual embedded rollouts after startup.
- `EPolyToosManager.ms` 0.06 / project 0.05: fixed startup loading by moving rollout-title assignment before CUI dialog-bar registration; `updateVersionLabel()` no longer writes `.title`.
- `EPolyToosManager-test.ms` 0.04 now requires at least one actual embedded tool rollout after startup, preventing an empty manager from passing regression tests.
- `EPolyToosManager.ms` 0.05 / project 0.04: added separate loader and tool subrollout slots.
- Added per-tool checkbuttons and INI persistence for enabled tools and loader open state.
- Closing the loader rollout collapses its slot and expands the tool slot.
- Removed the old 8 px child-rollout height adjustment.
- `EPolyToosManager-test.ms` 0.03 covers the new UI state behavior.

## 2026-09-25

- `EPolyToosManager.ms` 0.04 now shows the current global EPolyTools project version in the manager rollout/dialog title and refreshes it after tool reload.
- `EPolyToosManager-test.ms` 0.02 verifies that the manager title matches `epoly_tools_project_version`.
- `EPolyToosManager.ms` 0.03 / project 0.02: added an 8 px vertical offset to embedded EPolyTool rollouts for clearer visual separation.
- Manager restores each rollout's original height when removing or reloading it, so standalone tool UI sizes are unchanged.
- Updated `EPolyToosManager-test.ms` to verify the applied rollout spacing during reload.
- Renamed `load-all-epoly-tools.ms` to `EPolyToosManager.ms` and expanded it into the dockable EPolyTools manager UI.
- Manager discovers current tool scripts in direct subdirectories, embeds every declared rollout, and provides a `RELOAD` action.
- Added INI persistence for floating position, dialog height, dock state, and child rollout expanded/collapsed state.
- Added `EPolyToosManager-test.ms` covering manager creation, tool reload, INI persistence, docking registration, and reopen behavior.

## 2026-09-24

- Added `load-all-epoly-tools.ms` 0.01 to load one current EPolyTools script from every direct tool subdirectory.
- Loader prefers canonical `<FolderName>.ms`; when absent, it selects the highest numeric `<FolderName>_<version>.ms` so archived versions are not loaded over the current tool.
- `Redundant-Loop-Detector.ms` 0.20: zero-result scans no longer delete or clear an existing `SELECT REDUNDANT LOOPS` modifier.
- Failed selection-storage updates now delete only a modifier created by the current run; reused selectors restore their previous edge selection.
- Added a regression check that a zero-result scan preserves the existing selector and its stored edge selection.
