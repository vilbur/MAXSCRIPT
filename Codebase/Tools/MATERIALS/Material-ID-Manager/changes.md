## 2026-10-09 — v0.066

- Updated the `.NET` tool title/restart button to the current shared style: `18 px` height and the pre-style button font size increased by `2.0`.
- Preserved the existing RGB `45,45,48` normal/hover/pressed background, RGB `62,158,255` title text, zero border, full-width layout, and LMB `restartTool` behavior.
- `Material-ID-Manager_0.065.ms` remains unchanged; `Material-ID-Manager_0.066.ms` is the new versioned release and `Material-ID-Manager.ms` mirrors it.

# Material ID Manager changes

## 2026-10-05 — v0.065

- Added one controlled Editable Poly dead-topology synchronization boundary using `polyop.getHasDeadStructs` / `polyop.collapseDeadStructs` before ID-sensitive base-poly phases; dead base topology is not compacted when an Edit Poly modifier depends on that indexing.
- Material ID assignment/selection, camera-facing detection, Volume Select source capture, and Edit Mesh Material-ID scans now read selections, component counts, adjacency, and face IDs only after the current Editable Poly topology has been validated.
- Edit Mesh attach/explode/detach workflows now treat conversion, attach, detach, and face deletion as topology-dirty boundaries, invalidate stale topology BitArrays, and resynchronize only before the next phase that needs reliable component IDs.
- Detach no longer accepts face-count equality as sufficient topology correspondence: selected source face IDs must also match the temporary Editable Poly by Material ID and exact world-space polygon vertex positions before those IDs are transferred.
- Edit Poly paths remain on the Edit Poly modifier API; no `collapseDeadStructs` call is applied to modifier topology or blindly to an Editable Poly base underneath an Edit Poly dependency.

## 2026-10-05 — v0.064

- Fixed `restartTool` failing with `No ">" function for undefined` while scanning nearby `.ms` files whose suffix is not parseable as a numeric version.
- Version candidates are now compared only after `version_text as float` returns a valid numeric value; non-version files are ignored without affecting restart.

## 2026-10-05 — v0.063

- Changed Material Select Modifier Set stack naming to `{material name} material i` for the Material modifier and `{material name} select i` for the Volume Select modifier, using a one-based top-to-bottom index for every set, including a single set.
- Material Select Modifier Sets list labels remain role-neutral and now display `{material name} i`, matching the same set index without exposing the `material` / `select` role text.

## 2026-10-05 — v0.062

- Added the top `.NET System.Windows.Forms.Button` **tool title button** for `Material ID Manager`, using the requested dark RGB `45,45,48` background, light-blue RGB `62,158,255` text, flat styling, zero border, and identical normal/hover/pressed backgrounds.
- Added the reusable `restartTool current_script file_prefix` helper; LMB on the tool title button restarts from the newest matching versioned script, or reloads the current script when no versioned match is available.
- The tool title button is 24 px high, fills the usable dialog width, and is resized by the main dialog layout. The duplicate bottom Restart button was removed because the tool title button now owns restart behavior.
- Added `Material-ID-Manager_UI_TEST_0.062.ms` coverage for the tool title button appearance, sizing, and `restartTool` availability while retaining the shared-rollout tests from v0.061.

## 2026-10-05 — v0.061

- Moved `Material Setup` above `Material IDs` in the main tool stack.
- Replaced the five fixed child subRollout slots with one shared native `subRollout` using `scrollBar:#asNeeded`; child rollouts now pack together and roll up/down with native 3ds Max behavior instead of leaving empty fixed-position slots.
- The shared rollout viewport fills the space above the status / Restart footer and can scroll when the combined open rollout content is taller than the dialog.
- Changed `Scene Data` to a five-item default list height and expanded that rollout so the transform-lock control remains below the list without overlap.
- Added `Material-ID-Manager_UI_TEST_0.061.ms` to verify the shared rollout order, native roll-up/down state, and Scene Data list/control spacing.

## 2026-10-05 — v0.060

- Added a top `Scene Data` rollout backed by a persistent Custom Attribute on `rootNode`, keeping Material Select recovery data independent from mesh hierarchy and host-node lifetime.
- A node is managed whenever it contains at least one Volume Select; a paired Material modifier is optional. Deleting a Material modifier no longer triggers automatic pair repair during list refresh.
- `Refresh` performs the only full-scene managed-node scan on demand. The list shows live managed hosts plus `[MISSING]` recovery records, and a normal list click only selects the live scene node without changing visibility.
- Stored recovery data preserves each Volume Select's modifier context transform/bounds, center, gizmo position/rotation/scale, level, Auto Fit state, name, and paired Material ID when present.
- `Relink Selected` restores a missing host's saved Volume Select data onto the currently selected Editable Poly / Edit Poly host and merges it with any managed sets already present on that replacement node.
- Added scene-level `Lock managed-node transforms`, enabled by default. Managed nodes lock all Position / Rotation / Scale channels; disabling management or the preference restores the lock flags captured before the host became managed.
- Tool-driven Volume Select creation, copy/remove, preset loading, Material ID changes, and gizmo/center edits now synchronize the selected managed node back to rootNode Scene Data without scanning the complete scene.
- Added a standalone `Material-ID-Manager_SCENE-DATA_TEST_0.060.ms` regression test for unpaired Volume Select persistence, orphan recovery/relink, and transform-lock restore/reapply behavior.

## 2026-10-05 — v0.059

- Added `EDIT MESH > Select ID` immediately before `Detach`. LMB expands the current Polygon/Element selection to every face using the same Material ID or Material IDs as the currently selected seed faces.
- `Select ID` reads Material IDs from the exact active Editable Poly or Edit Poly topology, applies the complete matching face BitArray in one selection update, and leaves Polygon mode visible for continued editing.
- `EDIT MESH > Detach` now records the pre-operation Isolate Selection state and, when isolation was originally off, prevents an operation/callback side effect from leaving Isolate Selection enabled.
- Kept `Select ID` and `Detach` on one 228 px row as two equal-width controls. No new versioned TEST script was created.

## 2026-10-05 — v0.058

- Fixed the docked-dialog callback exception `Cannot set property while registered as dialogBar` caused by `layoutDialog()` calling `setDialogSize` after CUI registration.
- `layoutDialog()` may still establish the required minimum height before the window is registered, but once registered as a dialog bar it only relays out child controls and never resizes the top-level rollout.
- Registered/docked layouts keep the CUI-owned actual height for persistence while using the full calculated content height for non-overlapping child placement.
- Preserved left/right docking, the five-item default Material Select list behavior, dynamic list growth, and the unversioned latest `Material-ID-Manager.ms` mirror.

## 2026-10-05 — v0.057

- Material Select Modifier Sets list height no longer expands to fill the whole available rollout/dialog height.
- The list now keeps a five-item default height; each set beyond five adds one row of height dynamically.
- The preset dropdown / `Add \ Remove` row stays directly below the list, and the Material Select rollout/subrollout follows the calculated list height.
- Tall floating or docked dialogs can keep extra vertical workspace without stretching the Material Select list.

## 2026-10-05 — v0.056

- Registered the main Material ID Manager dialog as a dockable CUI dialog bar that can dock only to the left or right side of the 3ds Max frame while remaining floatable.
- Added CUI gripper handles for normal drag-to-dock behavior and kept the existing fixed 288 px dialog width / vertical resize layout.
- Added safe dialog-bar unregistration before tool reload/cleanup so Restart can replace a docked instance without calling `destroyDialog` on a still-registered dialog bar.

## 2026-10-04 — v0.055

- Fixed Material Select Modifier Set creation when the active source Edit Poly sits in the middle of an existing modifier stack. After the new Volume Select + Material pair is inserted above the source, the exact source poly context is now explicitly reactivated before its face selection is cleared or restored.
- Added the same source-context reactivation to failure rollback so an Edit Poly selection can be restored even when modifier insertion changed the active stack object.
- Preserved the new pair's middle-stack placement and all pre-existing modifier instances/order; no stack collapse/rebuild path was introduced.
- Added regression coverage with existing modifiers both above and below the source Edit Poly, requiring the new pair to remain between the upper modifier and source while the source face selection is cleared successfully.

## 2026-10-04 — v0.054

- Disabled Volume Select development tracing during normal Material Select Modifier Set creation. The existing diagnostic helpers remain available as an explicit opt-in, but ordinary adds no longer activate the DUMP trace or print stage-by-stage debug output.
- Moved the Material Select preset dropdown and `Add \ Remove` control below the Material Select Modifier Set list. X/Y/Z and Center Z now remain directly below the main action row, while the list expands vertically above the bottom-pinned preset row.
- Updated regression coverage to require silent default creation and to verify the preset controls remain directly below the resized set list.

## 2026-10-04 — v0.053

- Added scene-local Material Select presets. A saved scene writes presets to `<scene name>.Material-ID-Manager.ini` beside the `.max` file, with each preset stored as its own INI section named exactly from the user-entered preset name.
- Each preset stores every complete Material Select Modifier Set in visible stack order as explicit Material ID, Material name metadata, and exact Volume Select gizmo X/Y/Z size. Gizmo position and center are intentionally not persisted.
- Added a preset dropdown plus `Add \ Remove`: LMB prompts for a preset name and saves/replaces the selected object's current sets; RMB confirms and deletes the selected preset section. Picking a dropdown preset asks for confirmation before loading.
- Preset loading stages whole-object Material Select sets first, restores saved gizmo sizes and Material IDs, then removes the object's previous Material Select sets and resynchronizes `{material name}[i]` names. Unsaved scenes are rejected until the `.max` file has a scene path.
- Preset dropdown contents refresh on scene Open/New and after Save/Save As so the visible preset list always follows the current saved `.max` scene.
- Added regression coverage for preset section persistence/enumeration, Material ID/name and exact gizmo-size readback, loading onto another Editable Poly, preset removal, and the new preset-row layout.

## 2026-10-04 — v0.052

- Added `Copy \ Remove` beside `Volume Select` in the Material Select Modifier Sets top row. LMB copies the selected set; RMB removes the selected set.
- Copy creates independent Volume Select and Material modifier instances directly above the source set, preserves the explicit Material ID, and copies Volume Select local modifier data so the fitted selection/gizmo is retained.
- Remove deletes the paired Material modifier first and then its Volume Select while the pair-refresh callback guard is active, preventing automatic pair repair from recreating the set during deletion.
- Copy/remove resynchronize `{material name}[i]` naming and the list after the stack changes. Added regression coverage for independent copy, Material ID/gizmo preservation, exact two-modifier removal, surviving-source preservation, duplicate-index renaming, and the new two-button row.

## 2026-10-04 — v0.051

- `Material IDs` now shows exactly the number of rows present in the current Multi/Sub-Object material's explicit Material ID list; rows above the current material count are hidden instead of remaining as empty capacity rows.
- Removed the Material IDs subrollout scrollbar. The Material IDs rollout and its parent subrollout now resize to the exact visible row count, and all lower rollouts are repositioned underneath it.
- Generate / Update immediately refits Material IDs after successful current-material readback, Restart/open refits from the current selected object or active Material Editor Multi/Sub, and selection changes refit the row count automatically.
- Added regression coverage for both shrinking to a two-ID material and expanding to a fifteen-ID material, including exact rollout heights and hidden/visible row boundaries.

## 2026-10-04 — v0.050

- Fixed appended Material Setup rows that appeared in the UI/INI but did not affect `Multi ID Material`: a row with a non-empty `Name` and blank `Suffixes` now creates one material using the Name itself.
- Raised the generated Material ID capacity from 14 to 24. The four seeded rows still occupy IDs 1-14, leaving IDs 15-24 for the ten additional setup rows that `Add Multi ID` can append.
- Extended the `Material IDs` rollout with IDs 15-24. The existing subrollout viewport stays the same size and scrolls as needed, so the rest of the dialog layout does not grow.
- Extended the deterministic diffuse palette through ID 24 by continuing the existing unused 15-degree interleaved hues; existing ID 1-14 colors remain unchanged.
- `Multi ID Material` continues to update/verify the current Multi/Sub first, then reads its explicit IDs/names back into the Material IDs rollout and persists them to the script-local INI.
- Added regression coverage for a seeded 14-ID setup plus an appended Name-only `ROOF` row, verifying Multi/Sub ID 15, rollout ID 15, and INI persistence.

## 2026-10-04 — v0.049

- Reconciled the development branches by rebasing the v0.046 `Material Setup > Multi ID Material` current-material readback workflow onto the latest v0.048 codebase.
- Preserved all v0.047 fixed-spinner behavior and v0.048 whole-object Material Select Modifier Set fallback changes while keeping the v0.046 operation order: update/verify the current Multi/Sub material first, then read explicit Material IDs/names back from that material and synchronize the `Material IDs` rollout.
- Kept the v0.045 dynamic Material Setup row workflow intact; `Add Multi ID` still appends setup rows and is not reverted to the old incremental material-slot behavior.
- Promoted the merged branch to the canonical v0.049 release and carried the full latest regression suite forward.

## 2026-10-04 — v0.048

- Material Select Modifier Set creation now falls back to the whole object when the active Editable Poly / Edit Poly is at Object level, at a non-Face/Element sub-object level, or has an empty Face/Element selection.
- Whole-object fallback temporarily selects all source faces only for Volume Select Auto Fit, then restores the original stored source face selection exactly while keeping the frozen Volume Select context and gizmo unchanged.
- Existing non-empty Face / Element selection behavior is preserved: the selected faces bootstrap Auto Fit and are cleared after successful set creation.
- Updated the Volume Select tooltip/status text and added regression coverage for both Object-level and empty-Face whole-object fallback paths.

## 2026-10-04 — v0.047

- Fixed X/Y/Z Volume Select size spinner arrow clicks on 3ds Max 2024+ by disabling spinner Auto Scale, which otherwise derives the increment from the current spinner value and can produce roughly 1% jumps.
- After disabling Auto Scale, X/Y/Z explicitly restore the existing fixed `scale:0.1`, giving the intended constant one-unit LMB increment in the current project unit setup instead of a size-dependent increment.
- Added regression coverage for disabled X/Y/Z Auto Scale and the fixed spinner scale on supported 3ds Max versions.

## 2026-10-04 — v0.046

- Changed `Material Setup > Multi ID Material` LMB to make the operation order explicit: update and verify the current Multi/Sub material first, then synchronize the `Material IDs` rollout.
- Added current-material name readback that resolves names by explicit `materialIDList` values from the selected object's updated Multi/Sub material, or from the active Material Editor slot when no object is selected.
- The `Material IDs` rollout is now populated from the resulting current material instead of from the pre-update configuration array; INI persistence and Material Select Modifier Set renaming still run only after material update/readback succeeds.
- Added regression coverage for selected-object and active-Material-Editor readback plus rollout synchronization from the updated material.

## 2026-10-04 — v0.045

- Changed `Material Setup > Add Multi ID` LMB from adding a material slot to appending one new blank Material ID Set setup row.
- Material Setup now supports up to 14 persisted setup rows. Existing four-row INI files still open with four rows; each Add Multi ID click appends exactly one additional row.
- Newly appended rows are stored immediately as `Set_XX_Defined=1`, `Set_XX_UserDefined=1`, with blank `Name` and `Suffixes`, so blank rows survive Restart/reload.
- Material Setup grows by 30 px per appended row, moves `Multi ID Material` / `Add Multi ID` below the last visible row, and pushes EDIT MESH / Material Select Modifier Sets down while preserving the 288 px dialog width and vertical resize behavior.
- `Multi ID Material` continues to generate/update the actual Multi/Sub material from all visible setup rows. The old incremental material-slot helper remains internal but is no longer wired to Add Multi ID LMB.
- Added regression coverage for appending row 5, INI persistence, row visibility, setup height growth, button repositioning, and reloading appended values.

## 2026-10-04 — v0.044

- Reordered Material Select Modifier Set stack names so the set name comes first: `{material name}[i] SELECT` and `{material name}[i] MATERIAL`.
- The Material Select Modifier Sets list box now shows only the shared set name, for example `WALL-L[1]`, without stack indices, modifier-role text, or Material ID diagnostics.
- Duplicate `[i]` assignment and automatic suffix removal remain unchanged and continue to follow explicit Material ID grouping in visible stack order.
- Updated regression coverage for modifier-name order and paired list-box display names.

## 2026-10-04 — v0.043

- Renamed the Volume Select + paired Material modifier concept in the UI to `Material Select Modifier Sets`.
- Every complete set now derives both modifier names from its explicit Material ID semantic name: `SELECT {material name}` and `MATERIAL {material name}`. Blank semantic names fall back to `ID {n}` so stack names remain readable.
- When multiple sets on the same node use the same explicit Material ID, both modifiers receive the same top-to-bottom set index, for example `SELECT WALL-L[1]` / `MATERIAL WALL-L[1]` and `[2]`; the suffix is removed automatically when that Material ID becomes unique again.
- Set names are resynchronized after pair creation/repair, Material ID changes, semantic-name edits, generated Material ID Set name updates, stack refreshes, and modifier add/delete refresh callbacks.
- Added regression coverage for two sets sharing one Material ID, matching `[1]` / `[2]` names, and automatic suffix removal after one set changes to a different Material ID.

## 2026-10-04 — v0.042

- `EDIT MESH` Explode now keeps every generated Material-ID object in the same scene layer as its own source object, including multi-source explode operations where sources come from different layers.
- `EDIT MESH` Detach now keeps the detached object in the source layer and explicitly keeps the collapsed remainder replacement in that same layer before the original source node is removed.
- Added regression coverage that places Explode and Detach sources in dedicated non-default layers and verifies all generated/replacement objects preserve the source layer.

## 2026-10-03 — v0.041

- Fixed the apparent modifier-stack collapse after `Volume Select` LMB. The debug trace showed the new `Material ID + Vol. Select` pair was created correctly, but source-face deselection changed the Volume Select modifier context, triggered the frozen-gizmo verification failure, and cleanup then removed both newly added modifiers.
- Volume Select creation now freezes the modifier-context transform and bounding box together with center and gizmo PRS. After the source face selection is cleared, the captured modifier context is restored before the exact frozen center/gizmo values are reapplied.
- Removed the old post-deselection scale reconstruction path that recalculated against the changed modifier-context bounds and could report a false frozen-gizmo failure.
- Extended the Volume Select DUMP with before/after modifier-context transform, bounds, center, scale, and position values around source deselection and restore.
- Added direct Editable Poly regression coverage matching the reported case: three selected base faces must produce a persistent `Material + Volume Select` pair, clear the original source selection, preserve the base object, and leave Volume Select active.

## 2026-10-03 — v0.040

- Added DEV DUMP instrumentation to the `Volume Select` LMB creation workflow without changing its modifier-add algorithm.
- Each LMB attempt now writes a fresh `logs\Material-ID-Manager-Volume-Select-DUMP.txt` trace and mirrors the same diagnostic lines to the 3ds Max Listener through the shared `Modules\DUMP\DUMP.ms` logger.
- Added formatted stage snapshots around Modify-panel mode changes, source/current-object activation, Volume Select insertion, posted-message processing, Face-level redraw, Auto Fit/gizmo freezing, paired Material insertion, source-selection clearing, final Volume Select activation, failure handling, and cleanup.
- Extended the trace through the rollout's post-add `refreshVolumeSelectList()` path, including pair-sync detection, pair enumeration, list-box item/selection assignment, active-gizmo control reload, and the final callback state. This covers work that happens after `addVolumeSelect()` itself has already returned.
- Every stage snapshot records Modify-panel mode, `subObjectLevel`, current stack object, base object, modifier count, and the complete modifier stack with the current modifier marked, allowing a UI-only stack collapse to be distinguished from an actual scene-stack collapse.
- Updated `Material-ID-Manager_TEST_0.040.ms` to require the shared DUMP module and verify that Volume Select creation produces the repository-local DUMP file while preserving the existing modifier-stack regression checks.

## 2026-10-03 — v0.039

- Fixed `Volume Select` creation so it no longer re-selects the already active target node before modifier insertion, preventing the Modify-panel stack from being reset/collapsed during the add workflow.
- Added explicit stack-preservation verification: the original base object and every pre-existing modifier instance must remain present and in the same relative order after the new `Volume Select + Material` pair is inserted.
- Expanded the regression test to create the pair above an existing Edit Poly modifier and verify the base object is unchanged, the existing modifier survives, and exactly two modifiers are added.

## 2026-10-03 — v0.038

- Added first-run creation of the script-local `Material-ID-Manager.ini` with the requested Material Setup defaults: `LEVELS` + `1|2|3|4`, `WALLS` + `INT|EXT|L|R|F|B`, `BALCONY` + `INT|EXT`, and suffix-only `FLOOR|CEILING`.
- First-run defaults are written only when the INI file does not yet exist; any existing INI remains authoritative and is never reset by initialization.
- The requested default configuration expands to 14 material IDs, so Material ID generation, the diffuse palette, and the first `Material IDs` rollout now support IDs 1-14.
- Added Material ID 13 and 14 controls and expanded the fixed Material IDs rollout/dialog minimum height accordingly.
- Added regression coverage for exact first-run INI values, no-overwrite behavior on later initialization, valid 14-name expansion, 14 unique diffuse colors, and Material ID 14 UI support.

## 2026-10-03 — v0.037

- Moved `Material-ID-Manager.ini` from the global 3ds Max plugcfg directory to the same directory as the running `Material-ID-Manager_0.037.ms` script.
- Material ID names, Material ID Set rows, saturation, dialog position, and dialog height now persist beside the script, so the tool carries its configuration with the module folder.
- Added regression coverage that verifies the production INI path resolves to `<script directory>\Material-ID-Manager.ini`.

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
