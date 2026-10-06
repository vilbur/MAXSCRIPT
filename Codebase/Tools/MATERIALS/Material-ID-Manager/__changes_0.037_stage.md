# Material ID Manager changes

## 2026-10-03 — v0.037

- Moved `Material-ID-Manager.ini` from the global 3ds Max plugcfg directory to the same directory as the running `Material-ID-Manager_0.037.ms` script.
- Material ID names, Material ID Set rows, saturation, dialog position, and dialog height now persist beside the script, so the tool carries its configuration with the module folder.
- Added regression coverage that verifies the production INI path resolves to `<script directory>\\Material-ID-Manager.ini`.

## 2026-10-03 — v0.036

- `Multi ID Material` LMB now copies the successfully generated Material ID Set names into the first `Material IDs` rollout.
- Generated names are written to Material IDs 1..N in config order; Material ID name fields above the generated count are cleared so the first rollout exactly matches the generated Multi/Sub slot set.
- Every synchronized Material ID name, including cleared trailing blanks, is persisted to `Material-ID-Manager.ini` as an explicit user value.
- Name synchronization runs only after Multi/Sub generation/update succeeds; invalid config or failed material generation leaves the first-rollout names unchanged.
- Added `Material-ID-Manager_TEST_0.036.ms` coverage for generated first-rollout names, stale trailing-name clearing, and INI persistence.

## 2026-10-03 — v0.035

- Fixed `Multi ID Material` LMB so it no longer requires a selected scene object. With one selected object it creates/updates that object's material; with no selection it creates/updates the active top-level Material Editor slot.
- Added an explicit empty/invalid Material Setup status message instead of leaving the action looking like a no-op when no suffixes are configured.
- Existing Multi/Sub materials in the active Material Editor slot are updated in place using the same config reconciliation path as selected-object materials.
- New Multi/Sub materials created with no selection are placed into the current Material Editor slot and verified there after generation.
- Added exact exception reporting to the `Multi ID Material` LMB callback so unexpected failures are shown in the tool status and Listener instead of appearing silent.
- Added `Material-ID-Manager_TEST_0.035.ms` coverage for no-selection Material Editor creation from current Material ID Set config.

## 2026-10-03 — v0.034

- Removed all built-in Material ID semantic-name defaults; a fresh dialog now opens Material ID name fields blank unless the user has saved values in the INI file.
- Removed the built-in Material ID Set row defaults; fresh Material Setup rows now start blank instead of preloading WALL / FLOOR / CEILING / BALCONY names and suffixes.
- Material ID semantic names and Material ID Set rows now use explicit user-defined INI markers so blank values are valid persistent settings and are not replaced by hard-coded labels.
- Older non-default custom INI values migrate forward automatically and are marked as user-defined.
- Historical values that older versions wrote automatically are treated as unset when no user-defined marker exists, preventing old hard-coded defaults from reappearing after the upgrade.
- Added `Material-ID-Manager_TEST_0.034.ms` coverage for blank fresh defaults, explicit blank persistence, INI-backed row/name reload, legacy-default clearing, and custom-value migration.

## 2026-10-03 — v0.033

- Fixed `Multi ID Material` LMB so an already assigned Multi/Sub-Object material is actually mutated in place instead of relying on `materialList.count` resizing alone.
- Existing Multi/Sub detection now targets the real `MultiMaterial` class, preserves compatible Standard sub-materials by explicit Material ID, and resizes the same material instance through its supported `numsubs` setter before rewriting slots.
- Reconciled `materialList`, `materialIDList`, `names`, and `mapEnabled` to the exact configured count, then rewrites IDs 1..N, configured names, and saturation-derived diffuse colors.
- Added `updateMTLInMedit` plus viewport redraw after a successful mutation so the Material Editor/browser and scene reflect the updated existing material immediately.
- Strengthened verification to require the same assigned material instance, exact array counts, normalized `numsubs`, configured IDs/names/colors, and enabled slots.
- Expanded `Material-ID-Manager_TEST_0.033.ms` with a sparse Material ID 20 regression so config updates must collapse the existing Multi/Sub back to the configured size and then expand that same instance again.

## 2026-10-03 — v0.032

- Changed `Multi ID Material` LMB from create-only behavior to generate/update behavior driven by the current Material ID Set configuration.
- When the selected object has no Multi/Sub-Object material, the action creates and assigns one exactly as configured.
- When a compatible Multi/Sub-Object material already exists, the same material instance is updated in place: slot count is resized to the configured count, explicit Material IDs are reconciled to 1..N, slot/sub-material names are regenerated from the config, and diffuse colors are regenerated from the current saturation.
- Existing Standard sub-materials are preserved by explicit Material ID when possible so their non-diffuse settings/maps survive configuration updates; missing or incompatible sub-materials are regenerated as Standard materials.
- IDs removed from the configuration are removed from the generated Multi/Sub slot set; adding them back expands the same material again.
- Updated the Material Setup tooltip and undo label to describe generate/update behavior.
- Added `Material-ID-Manager_TEST_0.032.ms` regression coverage for in-place Multi/Sub updates, config-driven shrinking/expanding, preserved sub-material identity by Material ID, renamed slots, and regenerated saturation colors.

## 2026-10-03 — v0.031

- Added `Select Faces by camera` to the `EDIT MESH` rollout and expanded the fixed rollout height while keeping the dialog width at 288 px.
- Added the user-specified camera-facing polygon detector with global `asc_camera_face_alignment_threshold = 0.95`; an active camera is preferred and the active viewport is used when no camera is active.
- Camera-facing detection computes world-space polygon normals with Newell accumulation for triangles, quads, and N-gons, then selects faces whose view-space Z alignment is at least the configured threshold.
- The action supports one selected visible Editable Poly or the topmost Edit Poly modifier and leaves the result visible at Polygon sub-object level.
- Native camera/topology failures remain distinct from a legitimate empty face selection and are reported instead of being converted into false success.
- Added `Material-ID-Manager_TEST_0.031.ms` coverage for the 0.95 threshold, Newell normal direction, camera-facing classification, Editable Poly selection, Edit Poly selection, and the new EDIT MESH control.

## 2026-10-03 — v0.030

- Reworked `Material Setup` so diffuse saturation is the first control at the top of the rollout.
- Replaced the fixed `Walls` label with editable Material ID Set rows. Each row contains an optional base material name plus a pipe-separated suffix list.
- Material ID Set rows expand top-to-bottom into consecutive explicit Material IDs. For example, `WALL` + `INT|EXT|L|R|F|B` generates IDs 1-6 as `WALL-INT` through `WALL-B`.
- A blank Material ID Set base name is valid and makes each suffix the complete material name, so `""` + `FLOOR|CEILING` generates `FLOOR` and `CEILING`.
- Added four persistent Material ID Set rows. Defaults preserve the current wall/floor/ceiling/balcony layout: `WALL` + six wall suffixes, blank + `FLOOR|CEILING`, and `BALCONY` + `EXT|INT`.
- Multi/Sub creation now creates exactly the configured number of sub-materials instead of always creating 12 slots. The combined Material ID Set output must contain 1-12 unique final names.
- `Add Multi ID` now adds the lowest missing ID from the currently configured Material ID Set output.
- Existing legacy `Wall Config` is migrated into Material ID Set row 1 when the new settings are first loaded; intentionally blank base names remain persistently blank.
- Expanded the fixed `Material Setup` area while keeping the overall dialog width at 288 px and retaining vertical resize behavior.
- Added `Material-ID-Manager_TEST_0.030.ms` coverage for six-wall generation, multiple Material ID Set rows, blank-base suffix-only names, duplicate/overflow rejection, persisted blank names, saturation placement, configured Multi/Sub creation, and configured incremental IDs.

## 2026-10-03 — v0.029

- Added a new `EDIT MESH` rollout while keeping the dialog width fixed at 288 px.
- Added one combined `ATTACH \ EXPLODE by ID` control: `LMB` groups the selected visible objects by the lowest Material ID used on each object and attaches each group into one collapsed Editable Poly result; `RMB` explodes every selected object into separate objects by face Material ID.
- Attach treats an object containing multiple face Material IDs as belonging to its lowest used ID and names each resulting group from the corresponding Material ID semantic name.
- Explode names every detached Material-ID object from the corresponding Material ID semantic name and preserves the source material reference on the output.
- Added `Detach`, which detaches the current selected polygon faces as a new object named from the lowest Material ID used by those faces while preserving the unselected remainder under the original object name.
- EDIT MESH operations build and verify independent Editable Poly working copies before deleting the original source nodes; failed preparation/output verification leaves the original source geometry untouched.
- Detach aborts when the evaluated face count does not match the active Editable Poly / Edit Poly selection context instead of applying potentially mismatched face indexes.
- Added `Material-ID-Manager_TEST_0.029.ms` coverage for lowest-ID Attach grouping, per-ID Explode naming/face counts, Detach naming/remainder preservation, and the new rollout/button wiring.

## 2026-10-03 — v0.028

- Added a dedicated `Material Setup` rollout while keeping the dialog width fixed at 288 px.
- Added a persistent wall-token config edit field. The default `INT|EXT|L|R|F|B` generates the first six helper sub-material names as `WALL-INT`, `WALL-EXT`, `WALL-L`, `WALL-R`, `WALL-F`, and `WALL-B`.
- Aligned the built-in semantic rows with the six-wall setup: IDs 1-6 are `Walls INT`, `Walls EXT`, `Walls L`, `Walls R`, `Walls F`, `Walls B`; Floors/Ceiling move to 7/8 and Balcony Exterior/Interior to 9/10. Older untouched built-in labels migrate automatically while custom labels remain unchanged.
- Added a persistent diffuse-saturation slider with a 65% default. Generated helper colors use 12 evenly spaced hues at the selected shared saturation and full value, preserving one unique diffuse color per Material ID.
- Moved `Multi ID Material` and `Add Multi ID` into `Material Setup`; both actions now use the current wall config and saturation.
- `Add Multi ID` applies the same wall-name pattern and saturation palette when the lowest missing ID is appended.
- Added `Material-ID-Manager_TEST_0.028.ms` coverage for wall config parsing/naming, 65% diffuse saturation, Material Setup controls, unique colors, and config-aware incremental ID creation.

## 2026-10-03 — v0.026

- Changed the built-in semantic defaults so Material IDs 1-4 are directional wall classifications: `Walls L`, `Walls R`, `Walls F`, and `Walls B`.
- Preserved the existing non-wall categories by shifting them down: ID 5 `Floors`, ID 6 `Ceiling`, ID 7 `Balcony Exterior`, and ID 8 `Balcony Interior`.
- Existing INI values that still exactly match the previous built-in defaults migrate automatically to the new defaults; custom user labels are left unchanged.
- Centralized the 12 helper Multi/Sub-Object diffuse colors into one deterministic palette and added explicit duplicate-color validation before material creation.
- Helper Multi/Sub-Object creation now guarantees one unique diffuse color per Material ID and verifies the explicit ID mapping after assignment.
- Added `Material-ID-Manager_TEST_0.026.ms` coverage for directional wall defaults, preserved floor/ceiling/balcony defaults, 12-slot helper material mapping, and unique diffuse colors.

## 2026-10-03 — v0.025

- Material ID button backgrounds now mirror the diffuse color of the material explicitly mapped to that Material ID on the selected object.
- Multi/Sub-Object materials are resolved through `materialIDList`, so button colors follow explicit Material IDs rather than sub-material slot order.
- A single non-Multi material supplies the Material ID 1 button color when it exposes a diffuse property; missing diffuse/material data falls back to the normal system button background.
- Button colors refresh when the Material IDs rollout opens, object selection changes, a Material ID button is used, or the helper Multi/Sub-Object material is created.
- Added `Material-ID-Manager_TEST_0.025.ms` regression coverage for explicit ID-to-sub-material diffuse lookup and .NET button background RGB values.

## 2026-10-03 — v0.024

- Reduced the complete dialog width to 288 px and kept it vertically resizable.
- Changed the Material IDs rollout to one Material ID per row with its editable semantic name beside it.
- Added explicit LMB/RMB tooltips to every Material ID button.
- Material-button LMB now writes a repository-local diagnostic log to `logs\Material-ID-Manager-LMB.txt`; the log is cleared when the tool starts and each selection writes the resolved context, matching faces, Edit Poly before/after selections, and verification result.
- Fixed LMB selection on an already-active Edit Poly modifier by using the shared EPoly selection sequence: deselect the previous Face selection, select the requested Material-ID faces, then verify the stored Face selection.
- Added `Material-ID-Manager_TEST_0.024.ms` coverage for existing Edit Poly LMB replacement, LMB log creation, and the 288 px dialog width.

## 2026-10-03 — v0.023

- Redesigned the UI into two independent rollouts stacked vertically: `Material IDs` and `Volume Select / Material Stack`.
- Added persistent semantic names beside Material IDs 1-12; the same names are used when creating the helper 12-slot Multi/Sub-Object material.
- Material ID buttons now use `LMB` to select faces by explicit Material ID and `RMB` to assign that explicit ID.
- `RMB` edits selected Editable Poly / Edit Poly faces, an active `MaterialModifier`, or the Material modifier directly paired above an active Volume Select according to the current Modify-panel context.
- Removed Material-modifier ordinal/index ID control. Pair synchronization now only repairs missing `MaterialModifier` partners and never renumbers existing Material IDs.
- `LMB` selection automatically adds a new Edit Poly when the current stack context is not already Editable Poly or Edit Poly; when starting from an active Volume Select pair, insertion occurs above the paired Material modifier so the pair remains adjacent.
- Volume Select creation now requires an active Editable Poly / Edit Poly source face selection, uses that selection only to bootstrap Auto Fit, freezes the gizmo, clears the original source face selection, reapplies the saved world-space gizmo size/position after deselection, and verifies the bottom remains exactly anchored to `center.z`.
- If Volume Select creation fails after source deselection, the original source face selection is restored and newly added modifiers are cleaned up.
- Added `Material-ID-Manager_TEST_0.023.ms` covering direct selection, direct assignment, explicit pair IDs, non-renumbering pair synchronization, source-selection cleanup, and automatic continuation with a new Edit Poly.
- Added `redesign.md` as the clean design specification for the new workflow.

## 2026-10-03 — v0.018

- Volume Select center Z is now treated as the permanent bottom anchor of the gizmo during resizing.
- Changing the Z size spinner changes only gizmo Z scale, preserves gizmo X/Y scale and X/Y position, then realigns gizmo Z so the live gizmo bottom is exactly on `Vol__Select.center.z`.
- General gizmo resizing also preserves the center-bottom invariant by realigning only gizmo Z after applying the requested size.
- The final Z position is calculated from the live post-scale gizmo height, not from a rounded UI approximation.
- Updated tests to verify exact center-to-bottom alignment after both general resize and dedicated Z-height resize, including recovery from a deliberately drifted gizmo position.

## 2026-10-03 — v0.017

- Reworked `Vol__Select` creation so the add operation never calls the global pair synchronizer and never collapses or rebuilds the modifier stack.
- `Vol__Select` is added with `modPanel.addModToSelection` at the current Modify-panel stack context, then one `MaterialModifier` is added through the Modify panel while that new Volume Select is current, placing it directly above the new Volume Select.
- The new paired Material modifier receives `materialID` equal to its 1-based ordinal among all `MaterialModifier` instances in the current stack.
- Added a core creation guard so modifier-added callbacks cannot re-enter pair synchronization while the two-modifier pair is being created.
- Creation cleanup now removes the paired Material modifier first and the Volume Select second if the pair cannot be completed.
- Updated tests to verify that each add increases the modifier count by exactly two, preserves the editable base object, keeps the pair adjacent, and assigns the new Material modifier its stack ordinal as Material ID.

## 2026-10-03 — v0.016

- Dialog startup now performs one authoritative Volume Select stack refresh after `windows.processPostedMessages()`, when the parent dialog and child rollout are fully initialized.
- Existing `Vol__Select` / Material pairs from the currently selected object's live modifier stack are therefore loaded immediately when the tool opens, without requiring a selection change or manual refresh.
- Added a regression test that reloads the production script with an existing Volume Select stack selected and verifies the list is populated during dialog initialization.

## 2026-10-03 — v0.015

- Volume Select creation now preserves the fresh Auto Fit gizmo size and complete position.
- Post-add initialization captures the initial gizmo position, offsets only `center.z` to the gizmo bottom, then explicitly restores the original gizmo position.
- The post-add center-offset helper verifies that gizmo position and gizmo scale remain unchanged.
- Updated tests to verify center-Z offset behavior while preserving the initial gizmo size and position.

## 2026-10-03 — v0.014

- Volume Select size editing now preserves the complete `gizmo.position` exactly, including Z.
- Changing X/Y/Z size updates only the gizmo scale; it no longer recomputes gizmo Z from `center.z + height / 2`.
- `Center Z` remains a separate control that can move the gizmo vertically by the existing center-anchor rule.
- Updated tests to verify that gizmo position does not change when its size/height is edited.

## 2026-10-03 — v0.013

- Every `Vol__Select` is now automatically paired with a `MaterialModifier` inserted directly above it in the visible modifier stack when a pair is missing.
- Corrected modifier-stack indexing to the documented top-to-bottom order; the paired Material modifier is the entry immediately above its Volume Select.
- All `MaterialModifier.materialID` values on the managed object are automatically renumbered from 1 upward using MaterialModifier order in the visible stack, so Material ID always equals the Material-modifier ordinal.
- Pair synchronization runs after tool-created Volume Select modifiers, on list refresh, and after modifier add/delete notifications; recursive refresh during tool creation is guarded.
- Material ID buttons no longer override automatic pair IDs; they retain their original direct Editable Poly / Edit Poly assignment behavior.
- Updated tests for automatic pair creation, direct-above placement, top-to-bottom Material ID numbering, renumbering after stack changes, and list display synchronization.

## 2026-10-03 — v0.012

- Made the dialog vertically resizable with fixed width, persisted dialog height, and a minimum usable height.
- The `Select faces` list box now grows and shrinks to fill the available rollout height while the status and Restart footer stay aligned.
- Volume Select rows now resolve only the `MaterialModifier` directly above each `Vol__Select` as its pair and display that exact modifier's `materialID`; unpaired Volume Select modifiers remain visible with `ID --`.
- Material ID buttons 1–12 now set the selected pair's exact `MaterialModifier.materialID`; when no pair row is selected, the original direct Editable Poly / Edit Poly Material ID assignment behavior remains available.
- Added backend pair lookup and pair-specific Material ID assignment without relying on ambiguous modifier names.
- Expanded tests for two independent Volume Select / Material pairs, pair-specific Material IDs, pair list labels, and list-box growth with dialog height.

## 2026-10-03 — v0.011

- Flipped the Volume Select list so entries follow the visible modifier stack from top to bottom.
- Adding or selecting a Volume Select reloads the live gizmo X/Y/Z size and `center.z` into the tool controls.
- X/Y/Z and Center Z act as remote controls for the active Volume Select; after each successful edit, the tool re-reads the live modifier state and refreshes the spinners.
- Changing Center Z moves the gizmo vertically while keeping its bottom anchored to `center.z` and preserving gizmo X/Y.
- Expanded tests for top-to-bottom stack ordering and live control synchronization after add/list selection.

## 2026-10-03 — v0.010

- Kept the X/Y/Z Volume Select size spinners on one row and expanded each to the maximum equal width available inside the 288 px control area.
- Added a Volume Select list box showing every `Vol__Select` / `VolumeSelect` modifier in the single selected object's current modifier stack, in stack order.
- List entries include the modifier stack index and modifier name so multiple Volume Select modifiers are distinguishable.
- Selecting a list item makes that exact Volume Select modifier current in the Modify panel and loads its live X/Y/Z gizmo size and Center Z into the controls.
- The list highlights the current Volume Select when refreshed and refreshes after tool-created Volume Select modifiers and when the object selection changes.
- Added test coverage for stack listing, active-item highlighting, and list-driven switching between multiple Volume Select modifiers.

## 2026-10-03 — v0.009

- Hardened Volume Select creation after the reported access-violation crash.
- Kept the required `modPanel.addModToSelection (Vol__Select ()) ui:on` creation call, then allows the Modify panel to finish native initialization before accessing the added modifier.
- Removed redundant writes to Volume Select properties that already match Autodesk defaults, including `node`, `texture`, method/type/volume, Auto Fit, and soft-selection values.
- After creation, only the non-default Face selection level is set (`level = 2`) before bottom-center placement and UI synchronization.
- Creation errors now report the exact creation stage (`adding`, `resolving`, `setting Face level`, `placing center`, or `verifying`) to isolate any remaining native failure.

## 2026-10-03 — v0.008

- Volume Select creation now preserves the freshly Auto Fit gizmo instead of forcing the existing X/Y/Z spinner values onto the new modifier.
- Immediately after creation, `Vol__Select.center.z` is moved to the current gizmo bottom: `gizmo.position.z - gizmoSize.z / 2`.
- Moving the center to the bottom does not move the newly created gizmo.
- After successful creation, the live gizmo X/Y/Z size and `center.z` are loaded back into the `Select faces` spinners.
- Spinner callbacks are suspended while live modifier values are loaded so UI synchronization cannot resize or move the modifier.
- Updated Volume Select tests for Auto Fit preservation, bottom-center placement, live state reading, and spinner synchronization.

## 2026-10-03 — v0.007

- Replaced direct `addModifier` creation for Volume Select with `modPanel.addModToSelection (Vol__Select ()) ui:on` to avoid the reported native access-violation crash.
- Volume Select properties, center anchoring, gizmo sizing, current-modifier verification, and cleanup now run after the Modify panel creates the modifier.

## 2026-10-03 — v0.006

- Fixed the MAXScript parser error caused by multiline Point3 literals in the Volume Select size code and matching tests.
- Added a `Center Z` world-units spinner to the `Select faces` rollout for editing `Vol__Select.center.z`.
- Volume Select Z resizing now keeps the gizmo bottom locked to `center.z`; gizmo X/Y position remains unchanged.
- Moving `Center Z` moves the gizmo vertically by the same anchor rule while preserving gizmo X/Y.
- New Volume Select modifiers use the Center Z spinner value immediately when created.
- Expanded tests to verify scene-unit sizing, center-Z editing, bottom anchoring, and X/Y position preservation.

## 2026-10-03 — v0.005

- Changed the Select faces X/Y/Z controls from raw gizmo scale factors to absolute Volume Select box dimensions.
- X/Y/Z spinners now use `#worldunits`, so values display in the current 3ds Max scene Display Units while remaining system-unit values internally.
- Volume Select size is resolved from the modifier-context bounding box and converted to the required gizmo scale.
- Resizing an active Volume Select captures and restores `gizmo.position` exactly, so changing X/Y/Z does not move the selection gizmo.
- Updated Volume Select tests to verify absolute size conversion and gizmo-position preservation.


## 2026-10-03 — v0.004

- Added the `Select faces` rollout below the Material ID buttons.
- Added a `Volume Select` LMB action that creates a face-level, Replace, Window, Box `Vol__Select` modifier and makes it current in the Modify panel.
- Added X/Y/Z gizmo-scale spinners; changing any spinner updates `gizmo.scale` on the currently active Volume Select modifier.
- New Volume Select modifiers use the requested baseline properties, including Auto Fit enabled, Affect Region disabled, Material ID 1, Smoothing Group 1, and center `[0,0,0]`.
- Added test coverage for Volume Select creation, requested modifier settings, current-modifier activation, initial gizmo scale, and live gizmo resizing.

## 2026-10-03 — v0.003

- Added the required bottom `Restart` button to the Material ID Manager dialog.
- Restart loads the newest matching versioned script when available and otherwise reloads the current script.
- Removed the old F1/help reload callback.
- Increased the dialog height to preserve the 12 px layout spacing around the new footer action.
- Added restart tests for both fallback-to-current and newer-version resolution.

## 2026-10-03 — v0.002

- Fixed Material ID assignment through an active Edit Poly modifier.
- Edit Poly now follows the required committed operation sequence: select node, activate modifier, switch temporarily to Face, set the temporary face selection, run `SetOperation #SetMaterial`, set the zero-based material ID, and `Commit()`.
- Preserved and restored the previous Edit Poly face selection, selection mode, stack-selection mode, material-ID field, and sub-object level after assignment.
- Updated the Edit Poly tests to use an Edit Poly modifier directly on a parametric Box base object.

## 2026-10-03 — v0.001

- Added the first Material ID Manager release with 12 enlarged LMB Material ID buttons.
- Added Editable Poly and active Edit Poly support.
- Object level assigns the chosen ID to all faces.
- Vertex, Edge, Border, Polygon, and Element levels assign the chosen ID to faces belonging to the current sub-object selection.
- Edit Poly operations restore the previous face selection and sub-object level after assignment.
- Added a self-contained MAXScript scene test covering Editable Poly and Edit Poly object/sub-object workflows.
