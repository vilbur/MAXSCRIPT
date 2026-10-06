# Changes

## 2026-10-05 - 0.033

- Replaced the MODEL MEMBERS `BIND MATCHING LAYER` push button with a per-MODEL-NODE `BIND MATCHING LAYER` checkbutton mode.
- The checkbutton is connected to persistent MODEL NODE user property `SMM_BIND_MATCHING_LAYER`; new nodes explicitly store OFF, selecting a different MODEL NODE restores that node's own checked state, and missing metadata defaults to OFF for older scenes.
- Enabling BIND MATCHING LAYER immediately synchronizes membership: missing eligible top hierarchy roots from the exact matching layer are linked, while stale stored roots that no longer belong to that layer are unlinked.
- Synchronization preserves world transforms, group heads, child hierarchies, and the rule that a descendant is never detached when its true hierarchy root is outside the matching layer.
- `ADD SELECTED` and `REMOVE SELECTED` are disabled while BIND MATCHING LAYER is enabled and remain guarded against programmatic/manual invocation.
- BIND MATCHING LAYER synchronization runs before `SELECT MEMBERS`, `SET ORTHO DIRECTION`, and `ORTHO / ORIGINAL`; batch OBJ export also synchronizes enabled nodes in the backend.
- A BIND MATCHING LAYER failure, including a missing exact layer, aborts the requested member-dependent operation instead of continuing with stale membership.
- Moved the substantial MODEL NODES rollout into dedicated canonical module `Scene-Model-Manager-Model-Nodes-UI.ms`; the main entry loads it after the common UI file and before the dialog opens.
- Added DUMP traces for BIND MATCHING LAYER mode changes, synchronization inputs/results, rollback errors, and pre-operation synchronization.
- Added focused test `Scene-Model-Manager-Test_0.008.ms` for the node user property, authoritative layer synchronization, stale-root unlinking, new-root linking, exact world-transform preservation, and untouched child/outside hierarchies.
- Main entry file version advanced to 0.024; backend file version advanced to 0.028; MODEL NODES UI module starts at 0.001; shared project version advanced to 0.033. The common UI file remains unchanged at 0.032.

## 2026-10-05 - 0.032

- Moved `CREATE MODEL NODE` and `REFRESH` into one compact row directly above the MODEL NODES listbox.
- Removed the `UPDATE NODE` button.
- Ratio and Size now use live selected-node editing: changing Ratio immediately updates the selected MODEL NODE ratio/list entry; changing Size immediately updates the selected Text size in the viewport.
- Added guarded spinner synchronization so selecting/refreshing a MODEL NODE can populate Ratio/Size controls without accidentally writing settings back through the live change handlers.
- Without a selected MODEL NODE, Ratio and Size continue to act as creation defaults and remain persisted in the existing UI INI settings.
- Shifted MODEL MEMBERS and ORTHO controls upward and reduced the MODEL NODES rollout body height from 540 px to 504 px.
- No backend membership, hierarchy, ORTHO, offset, rotation, export, or geometry behavior was changed.
- UI file/project version advanced to 0.032; shared project version advanced to 0.032.

## 2026-10-05 - 0.031

- Added a dedicated `MODEL MEMBERS` section inside the `MODEL NODES` rollout.
- Added `BIND MATCHING LAYER`: the selected MODEL NODE logical name is matched exactly against a scene layer name; only that exact layer is used.
- Membership linking now operates on top hierarchy roots only. If both a hierarchy parent/group head and its descendants are supplied, only the top root is linked to the MODEL NODE, preserving the existing child/group hierarchy unchanged.
- Candidate descendants whose true hierarchy root is not part of the supplied selection/layer are skipped instead of being detached from their parent hierarchy.
- Roots already owned by another MODEL NODE are excluded from automatic binding, preventing layer binding from stealing another MODEL NODE hierarchy.
- `CREATE MODEL NODE` and `ADD SELECTED` now use the same top-root filtering rule, so new membership cannot flatten or break object/group hierarchies.
- Existing `REMOVE SELECTED` and `SELECT MEMBERS` are grouped under `MODEL MEMBERS`; status/list wording now reports member roots.
- Added DUMP traces for hierarchy-root filtering, generic member linking, and exact-layer binding.
- Backend file version advanced to 0.027; UI file version advanced to 0.031; shared project version advanced to 0.031.

## 2026-10-05 - 0.030

- Fixed fresh-launch runtime failure `Call needs function or class, got: undefined` at `openSceneModelManager()` in the main entry.
- Declared `openSceneModelManager` as an explicit global contract in both the main entry and UI file so UI loading through `fileIn` inside `launchSceneModelManager()` exports the entry function reliably.
- Added a post-UI-load validation before the call; if the UI entry is ever unavailable again, DUMP records `ERROR | UI ENTRY UNAVAILABLE | openSceneModelManager` and the tool raises a specific load error instead of an undefined-call type error.
- No backend scene, offset, rotation, MODEL NODE, ORTHO, scaling, or export behavior was changed.
- Main entry file version advanced to 0.023; UI file version advanced to 0.030; shared project version advanced to 0.030.

## 2026-10-02 - 0.029

- Changed MODEL NODES `ORTHO / ORIGINAL` to affect only the selected MODEL NODE Text object.
- ORTHO no longer parents, rotates, or otherwise transforms unrelated scene roots.
- Linked MODEL NODE members keep their exact world transforms while the Text node switches between ORTHO and ORIGINAL.
- ORTHO state is now evaluated per selected MODEL NODE, so the radio row reflects that node instead of a scene-wide ORTHO state.
- `SET ORTHO DIRECTION` and pivot editing are blocked only when that same MODEL NODE is in ORTHO; another MODEL NODE may keep its own independent ORTHO display state.
- Export orientation is now separated from interactive ORTHO: held MAX/OBJ transactions apply the stored ORTHO correction only to the selected MODEL NODE membership through the node hierarchy, while other scene roots remain untouched.
- Removed interactive dependencies on temporary bound scene-root handles; legacy `SMM_ORTHO_BOUND_HANDLES` is cleared but no longer populated by ORTHO / ORIGINAL.
- Updated MODEL NODE ORTHO tooltips and focused test to `Scene-Model-Manager-Test_0.005.ms`.
- Main entry file version advanced to 0.022; backend file version advanced to 0.026; UI file version advanced to 0.029; shared project version advanced to 0.029.

## 2026-10-01 - 0.028

- Removed the temporary `SCENE_MODEL_ORTHO_DRIVER` dependency from MODEL NODE ORTHO editing.
- ORTHO now uses the selected MODEL NODE Text itself as the temporary scene rotation parent at its own pivot.
- Activating ORTHO neutralizes the MODEL NODE rotation without moving its persistent linked members, temporarily links the other current scene roots under that MODEL NODE with world transforms preserved, then applies the stored ORTHO Z correction on the MODEL NODE itself.
- ORIGINAL applies the inverse through the same MODEL NODE, unlinks temporary scene roots back to world with their restored transforms, then restores the MODEL NODE's pre-ORTHO rotation without moving its persistent members.
- New top-level roots created while ORTHO is active are linked to the active MODEL NODE before ORIGINAL or bake so they participate in the same inverse/bake transform.
- ORTHO active state, original node rotation, and temporary bound-root handles are stored on the MODEL NODE itself; no additional ORTHO scene object is created.
- MAX/OBJ held transactions now bake the MODEL NODE-owned ORTHO transform directly and leave no ORTHO helper object in the temporary output scene.
- SET ORTHO DIRECTION is blocked while an ORTHO view is active so the active MODEL NODE cannot have its pivot/direction redefined mid-transform.
- Updated the focused MODEL NODE test to `0.004` to verify node-owned ORTHO activation/restoration and the absence of a separate ORTHO driver.
- Backend file version advanced to 0.025; UI file/project version advanced to 0.028; shared project version advanced to 0.028.

## 2026-10-01 - 0.027

- `SET ORTHO DIRECTION` now always aligns the selected MODEL NODE pivot exactly to the first picked vector point; the Yes/No pivot prompt was removed.
- The picked XY vector still defines and stores the MODEL NODE ORTHO correction.
- When PREPARE SCENE `ROTATION ON` is active, defining the MODEL NODE ORTHO direction rotates the visible MODEL NODE to the nearest world X/Y axis.
- When `ROTATION OFF` is active, defining the ORTHO direction leaves the MODEL NODE rotation unchanged while still storing the correction.
- Linked MODEL members keep their world transforms while the MODEL NODE pivot and visible orientation are updated.
- Added DUMP data for pivot alignment, source angle, correction delta, snapped angle, and current rotation-active state.
- Updated the focused MODEL NODE test to `0.003` for exact pivot placement plus ROTATION OFF / ON behavior.
- Backend file version advanced to 0.024; UI file version advanced to 0.027; shared project version advanced to 0.027.

## 2026-10-01 - 0.026

- After a valid two-point `SET ORTHO DIRECTION` vector is picked, the UI now asks whether the selected MODEL NODE should move to vector START and use that point as the ORTHO rotation pivot.
- Choosing Yes moves the MODEL NODE exactly to the first picked point while preserving all linked member world transforms; choosing No leaves the current MODEL NODE position unchanged.
- ORTHO direction metadata is then calculated from the same picked vector using the MODEL NODE's resulting pivot position.
- Rotating the visible MODEL NODE Text to show the picked source direction now also preserves linked member world transforms, so defining ORTHO no longer moves linked geometry before ORTHO view is activated.
- Added DUMP markers for the pivot prompt, pivot move result, exact target position, and transform-preservation path.
- Added focused test `Scene-Model-Manager-Test_0.002.ms` covering exact pivot relocation and member-transform preservation through pivot move and ORTHO direction definition.
- Backend file version advanced to 0.023; UI file version advanced to 0.026; shared project version advanced to 0.026.

## 2026-10-01 - 0.025

- Changed `SET ORTHO DIRECTION` to the same immediate two-point viewport vector workflow used by `DEFINE ROTATION VECTOR`.
- LMB now picks ORTHO vector START, then END with a rubber-band preview; the picked XY vector defines the selected MODEL NODE's stored ORTHO correction.
- The picked vector is translated to the MODEL NODE pivot before calling the existing backend ORTHO-direction function, so backend angle math and stored ORTHO behavior remain unchanged.
- Added explicit DUMP markers and separate START/END cancellation status messages for the ORTHO vector picker.
- UI file/project version advanced to 0.025.

## 2026-10-01 - 0.024

- Fixed MODEL NODE list/status member counting after runtime error `Unknown property: count` on a MODEL NODE Text object.
- Removed both ambiguous chained expressions `SceneModelManager.getModelNodeMembers(model_node).count`.
- The UI now resolves `getModelNodeMembers model_node` into an explicit array variable before reading `.count`, matching the backend array return contract and avoiding MAXScript call/property binding ambiguity.
- No MODEL NODE creation, linking, hierarchy, ratio, size, ORTHO, offset, or export behavior was changed.
- UI file/project version advanced to 0.024.

## 2026-10-01 - 0.023

- Replaced the MODEL NODE name prompt with the supplied native 3ds Max `MaxCustomControls.RenameInstanceDialog` pattern.
- The selected layer name remains the prefilled default passed to the dialog constructor.
- The dialog title is `MODEL NODE Name`; `ShowModal()` is called before reading `InstanceName`.
- Removed the Visual Basic `InputBox` dependency and its prompt-specific `try/catch`.
- UI file/project version advanced to 0.023.

## 2026-10-01 - 0.022

- Rebuilt MODEL NODE creation to the requested direct workflow: ask for name, read current selection, create the Text at the selection bounding-box center with Z forced to 0, then link the selected objects under the Text node.
- MODEL name prompt remains prefilled from the selected objects' layer name.
- Removed the CREATE fallback viewport pivot pick; an empty selection now stops creation explicitly.
- MODEL NODE viewport Text now displays only the logical MODEL name.
- Linking preserves each selected object's world transform and rolls back the hierarchy if creation linking fails.
- Active scene-offset metadata now replaces newly parented member handles with the MODEL NODE root so REAL-WORLD restore remains valid after linking.
- ADD / REMOVE membership now also links / unlinks objects consistently with MODEL NODE parenting while preserving world transforms.
- ORTHO root collection now includes MODEL NODE roots so linked member geometry continues to rotate with scene-wide ORTHO view.
- MODEL NODE discovery now scans the shape collection so Text nodes remain discoverable while temporarily parented during ORTHO.
- Backend and UI file/project versions advanced to 0.022.

## 2026-10-01 - 0.021

- Fixed Scene Model Manager DUMP initialization: the shared `Modules/DUMP/DUMP.ms` module is now loaded at top-level entry-script scope before `DumpDevLoggerStruct()` is constructed.
- Removed the failing function-local `fileIn` DUMP load that left the constructor undefined at runtime.
- Fixed CREATE MODEL NODE name prompting by removing the unavailable `getString` call.
- CREATE now uses the verified .NET `Microsoft.VisualBasic.Interaction.InputBox` prompt, preserving the selected objects' layer-name default.
- Cancel or an empty MODEL name stops creation cleanly instead of creating a fallback name silently.
- No MODEL NODE backend membership, pivot, ratio, size, ORTHO, scale, or export behavior was changed.
- Main entry and UI file/project versions advanced to 0.021.

## 2026-10-01 - 0.020

- Narrowed the MODEL NODES Ratio and Size spinners to 96 px each and kept them together in one centered row above the listbox.
- Changed MODEL NODE Size from a Float spinner to an explicit Integer-centimeter spinner and shortened the caption from `Text cm:` to `Size:`.
- Removed the persistent MODEL name edit field from the rollout.
- CREATE MODEL NODE still asks for the name at creation time, but the prompt is now prefilled from the layer name of the current member-object selection; without usable members it falls back to a unique `MODEL_` name.
- UPDATE NODE now preserves the existing MODEL name and updates only Ratio and Size.
- Centered the REAL-WORLD / OFFSET, ROTATION OFF / ON, and ORTHO / ORIGINAL radio-button groups within the 288 px dialog.
- Shifted the remaining MODEL NODES controls upward after removing the Name field and reduced that nested rollout body height accordingly.
- No backend MODEL NODE membership, ORTHO transform, offset, rotation, scale, or export behavior was changed.
- UI file/project version advanced to 0.020.

## 2026-10-01 - 0.019

- Reworked `2. MODEL NODES` UI for the creation/edit workflow.
- Moved Ratio and Text cm controls into one compact row above the MODEL NODES listbox.
- Added tooltips across MODEL NODE creation, settings, membership, ORTHO-direction, list, and ORTHO/ORIGINAL controls.
- MODEL NODE creation is now dynamic: CREATE asks for the MODEL name at click-time, prefilled from a single selected member when available; current non-MODEL-NODE selection is used automatically as initial membership and pivot bounds.
- When no usable current selection exists, CREATE falls back to the existing viewport pivot pick.
- The persistent Name edit remains available for later UPDATE NODE operations.
- Replaced separate ORTHO and ORIGINAL buttons with one horizontal `ORTHO / ORIGINAL` radio control synchronized from the actual scene ORTHO driver state.
- Added DUMP markers for dynamic creation and ORTHO radio changes.
- No backend MODEL NODE membership, ORTHO transform, scale, offset, or export logic was changed.
- UI file/project version advanced to 0.019.

## 2026-10-01 - 0.018

- Added RMB behavior to PREPARE SCENE button 6: each RMB adds exactly +90 degrees to the stored main-rotation definition.
- When ROTATION ON is active, the +90-degree step is applied immediately to the scene around world origin; when ROTATION OFF is active, only the stored target angle changes.
- LMB remains the two-point viewport vector picker and is unchanged.
- Added backend `addMainRotationAngle()` so the angle-step operation remains separate from UI handling and can be reused without coupling to viewport picking.
- Added DUMP markers for the +90-degree request, target angle, stored angle, and UI result.
- Backend and UI file/project versions advanced to 0.018.

## 2026-10-01 - 0.017

- Integrated the canonical shared `Modules/DUMP/DUMP.ms` DEV logger through the Scene Model Manager entry point.
- Each tool run or RESTART/F1 reload starts a fresh `logs\Scene-Model-Manager-DUMP.txt` file under the project root and mirrors every DUMP line to the 3ds Max Listener.
- DUMP initialization is optional diagnostic infrastructure: missing or failed logging reports to the Listener but does not change Scene Model Manager functional behavior.
- Added run/load/dialog lifecycle markers plus PREPARE, offset, rotation-vector, MODEL NODE ORTHO, MAX-copy, and OBJ-export process markers.
- Added backend stage data for rotation angles/deltas, offset anchors/root counts, ORTHO root counts, export scale factors, geometry counts, and key operation results.
- Existing runtime exceptions remain real exceptions; DUMP does not convert failures into success.
- Main entry, backend, and UI file/project versions advanced to 0.017.

## 2026-10-01 - 0.016

- Fixed the runtime `Call needs function or class, got: undefined` failure in nearest-axis rotation snapping.
- Removed the unavailable `round(...)` call from `getNearestAxisRotationDelta()`.
- Replaced it with explicit 45/135-degree quadrant boundaries that snap to the nearest 90-degree world axis without relying on another native rounding helper.
- The fix is shared by scene MAIN ROTATION and MODEL NODE ORTHO because both use the same backend rotation-delta function.
- No offset, stored rotation, membership, scaling, export, or UI behavior was changed.
- Backend file/project version advanced to 0.016.

## 2026-10-01 - 0.015

- Fixed PREPARE SCENE button 6 so LMB immediately enters the two-point viewport vector picker.
- Rotation-vector definition no longer requires OFFSET TO ORIGIN to be active; `SCENE_OFFSET_DATA` is created as metadata storage when needed.
- The stored rotation definition now survives later activation of OFFSET TO ORIGIN instead of being reset by offset metadata initialization.
- ROTATION OFF / ROTATION ON remains a separate horizontal toggle; applying scene rotation still requires an active scene offset.
- When OFFSET is inactive, PREPARE SCENE shows any stored rotation definition while keeping the apply toggle disabled.
- Existing shared vector-to-angle functions remain reusable by MODEL NODE rotation.
- Backend and UI file/project versions advanced to 0.015.

## 2026-10-01 - 0.013

- Changed PREPARE SCENE button 6 from a single direction point measured from world origin to a true two-point viewport vector pick.
- LMB now picks vector START, then vector END with a rubber-band preview; the resulting XY vector defines the main rotation correction angle.
- The complete offset scene still rotates around world origin, and RMB still resets MAIN ROTATION to zero.
- Updated button label and tooltip to describe the two-point vector workflow.
- No backend rotation math, offset storage, MODEL NODE logic, scaling, or export behavior was changed.
- UI file/project version advanced to 0.013.

## 2026-10-01 - 0.012

- Increased the fixed Scene Model Manager dialog width from 192 px to 288 px.
- Expanded the subrollout slot to the full 288 px dialog width and widened full-row controls to 264 px with 12 px outer margins.
- Expanded paired MODEL NODE action buttons while retaining the 12 px / 6 px UI grid.
- Added version-independent single-instance cleanup before the new UI rollout is defined: any existing `scene_model_manager_rollout` dialog referenced by the stable global is destroyed before reload continues.
- RESTART/F1 therefore replaces the old Scene Model Manager dialog instead of stacking another version beside it.
- Dialog width remains fixed and is not persisted; position, height, rollout state, and other existing UI preferences remain persisted.
- No backend scene, offset, rotation, MODEL NODE, scaling, or export behavior was changed.
- UI file/project version advanced to 0.012.

## 2026-10-01 - 0.011

- Added persistent UI state storage in `Scene-Model-Manager.ini` under the 3ds Max plugcfg directory.
- Dialog X/Y position and resizable height are restored on the next tool launch; width remains fixed at 192 px.
- PREPARE SCENE, MODEL NODES, and MODEL / EXPORT open/rolled-up states are restored.
- MODEL NODE default ratio/text-size controls and MODEL / EXPORT unit dropdown selections are persisted.
- Scene-specific state remains authoritative in the scene: REAL-WORLD/OFFSET state, MAIN ROTATION, MODEL NODE selection/name, and export paths are not restored from the UI INI.
- Added close/move/resize persistence hooks and restored subrollout layout from the saved dialog height.
- No backend scene, offset, rotation, MODEL NODE, scaling, or export behavior was changed.
- UI file/project version advanced to 0.011.

## 2026-10-01 - 0.010

- Added a persistent MAIN ROTATION stage after OFFSET TO ORIGIN.
- MAIN ROTATION rotates all current top-level scene content around world origin and mirrors the exact accumulated Z rotation on `SCENE_OFFSET_DATA`.
- LMB on MAIN ROTATION picks an XY direction from world origin and applies the tested nearest-world-X/Y alignment rule; RMB resets the main rotation to zero.
- `SCENE_OFFSET_DATA` now stores `SO_MAIN_ROTATION_Z` and keeps its Point-helper Z rotation synchronized for visible scene-state inspection.
- RESTORE REAL-WORLD now resets the stored main rotation around origin before restoring the physical real-world offset.
- MAIN ROTATION is available only while OFFSET TO ORIGIN is active and is blocked while a MODEL NODE ORTHO driver is active.
- No MODEL NODE membership, model-ratio scaling, or OBJ/MAX export behavior was changed.
- Backend and UI file/project versions advanced to 0.010.

## 2026-10-01 - 0.009

- Fixed the 192 px dialog/subrollout geometry so nested rollout controls are not clipped horizontally.
- Expanded the `sr_sections` slot to the full 192 px parent width at X = 0; nested controls retain 12 px inner margins and 168 px usable control width.
- Added explicit 12 px-grid rollout content heights: PREPARE SCENE = 372 px, MODEL NODES = 576 px, MODEL / EXPORT = 444 px.
- The 612 px subrollout viewport is now 24 px taller than the largest nested rollout body, matching the shared subrollout sizing rule while retaining vertical scrolling for the stacked workflow sections.
- No backend, scene, offset, MODEL NODE, ORTHO, scaling, export, or callback behavior was changed.
- UI file/project version advanced to 0.009.

## 2026-10-01 - 0.008

- Reduced the Scene Model Manager dialog width to exactly 192 px as requested.
- Reflowed PREPARE SCENE, MODEL NODES, MODEL / EXPORT, RESTART, and footer controls to stay within the 192 px dialog.
- Kept the 12 px UI grid, 24 px standard control height, and at most two controls per visual row.
- Paired compact actions use 72 px buttons; longer actions use the available 168 px inner width.
- No backend scene, offset, MODEL NODE, ORTHO, scaling, or export behavior was changed.
- UI file/project version advanced to 0.008.

## 2026-10-01 - 0.007

- Added a RESTART button at the top of the main dialog; F1 uses the same canonical Toolset reload action.
- Merged PREPARE SCENE outlier controls into one button: LMB selects outlier candidates, RMB confirms and deletes the candidates from the latest scan.
- Renumbered the PREPARE SCENE workflow after merging the two outlier controls.
- Applied the 12 px UI base grid: 480 px dialog width, 24 px standard control height, 12 px primary spacing, and 6 px half-grid spacing only where compact placement is required.
- Kept every visual row at a maximum of two controls.
- No backend scene, offset, MODEL NODE, ORTHO, scaling, or export behavior was changed.
- UI file/project version advanced to 0.007.

## 2026-10-01 - 0.006

- Replaced separate OFFSET TO ORIGIN / RESTORE REAL-WORLD buttons with one two-state radio control.
- The radio state is synchronized from the authoritative stored offset state whenever PREPARE SCENE refreshes.
- Selecting OFFSET TO ORIGIN runs the existing offset operation; selecting REAL-WORLD runs the existing restore operation.
- If either operation fails, UI refresh returns the radio control to the actual stored scene state.
- No backend offset math, stored data, scene transform logic, MODEL NODE logic, ORTHO logic, or export logic was changed.
- UI file/project version advanced to 0.006.

## 2026-10-01 - 0.005

- Reflowed the UI so each visual row contains at most two controls.
- Preserved a clear top-to-bottom workflow through PREPARE SCENE, MODEL NODES, and MODEL / EXPORT.
- Combined field captions into native edit/spinner/dropdown controls where useful to reduce horizontal clutter.
- No scene-processing, MODEL NODE, ORTHO, offset, scale, or export behavior was changed.
- UI file/project version advanced to 0.005.

## 2026-10-01 - 0.004

- Fixed MODEL NODES rollout parser error by declaring `model_node_refs` as a rollout-local variable.
- No MODEL NODE behavior, membership, ORTHO logic, scene transforms, or export logic was changed.
- UI file/project version advanced to 0.004 and now raises the running project version before the rollout title is resolved.

## 2026-10-01 - 0.003

- Fixed MAXScript Point3 parser syntax in `getStoredOffsetSystemUnits()`: the closing `]` now stays on the same line as the third Point3 component.
- No offset values, unit conversion math, or scene-transform behavior was changed.
- Backend file/project version advanced to 0.003.
- Synced the canonical main entry and UI file/project version metadata to 0.003 so the dialog title matches the project version.

## 2026-10-01 - 0.002

- Fixed a MAXScript parser error in the mm-to-meter preparation flow by keeping multiline `messageBox` and `queryBox` calls parser-safe with their keyword parameters.
- No conversion behavior or geometry logic was changed.
- Synced the main entry and UI project/file version metadata to 0.002 so the dialog title reports the current project version.

## 2026-10-01 - 0.001

- Created Scene Model Manager Toolset.
- Added native mm-to-meter Merge preparation flow with centimeter display.
- Added safe outlier candidate selection/deletion workflow.
- Integrated pivot centering and reversible real-world scene offset.
- Added visible Text MODEL NODEs with persistent ratio, ORTHO orientation, and membership.
- Added reversible scene-wide ORTHO editing view.
- Added per-MODEL-NODE rescaled MAX copy and OBJ export plus batch OBJ export.
- Preserved all four uploaded tested source scripts unchanged in `_Source`.
