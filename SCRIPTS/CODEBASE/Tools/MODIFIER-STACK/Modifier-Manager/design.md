# Modifier Manager

Split from **Modifier Set Stack 0.087** (read-only backup) on 2026-10-24.

- Entry: `Modifier-Manager.ms`
- Backend: `Modifier-Manager-FN.ms` (no UI dependencies)
- Shared presets: `Modifier-Manager-Presets.ms` (native instances, scene-root snapshots)
- Preset editors: `Modifier-Manager-Preset-UI.ms` (reusable list controller, MeshSmooth, Chamfer)
- Frontend: `Modifier-Manager-UI.ms` (standalone dialog)
- Test entry: `Modifier-Manager-Test.ms` (run in a disposable 3ds Max scene)
- Initial independent version: **0.001**
- Current project version: **0.022**
- Slice backend: `Modifier-Manager-Slice.ms` (native Slice, context-bbox gizmo translation)
- Slice UI: `Modifier-Manager-Slice-UI.ms` (coordinate radio, axis locks, sliders, Slice modes)
- Slice tests: `Modifier-Manager-Slice-Test.ms` (run in a disposable 3ds Max scene)
- Bundled UI framework: `Modifier-Manager-Framework.ms` (self-contained IniSettings, RolloutState, DialogHost, ScriptReload, ToolTitleButton)

Owns **sr_params** and the extracted **Volume Select**, **Material**, **Push**, and **Symmetry** child rollouts. Uses its own modifier selection and scoped parameter operations. The parameter subrollout slot is resized with the owning dialog. Does not own sets or LIVE STACK.

## MeshSmooth / Chamfer scene presets

- Native modifiers only; generated objects never depend on a scripted modifier class.
- Two independent rollout lists share `modifierPresetList_v` for Save, Load, Add, and Re-instance.
- Preset values are stored as typed indexed properties of `rootNode` in the `.max` scene. They survive even when the last instance of a modifier has been removed.
- Preset instances have an AppData identity tag. The manager finds a live instance through the scene instead of matching modifier names.
- Save (LMB) snapshots the controls or the selected native modifier; Save (RMB), Load, list double-click, or list RMB loads the preset into controls without editing geometry.
- Add applies the same tagged native modifier instance to all selected compatible objects. **Unique** makes a separate modifier on each object.
- Re-instance replaces the topmost matching native modifier on each selected compatible object with the selected shared preset modifier, preserving other modifiers and verifying stack position.
- MeshSmooth controls: viewport/render iterations, render override, material/smoothing separation, whole mesh, enable state.
- Chamfer controls: amount, segments, Quad/Standard, tension, open/enabled, selection source, material/smoothing filters; Inset checkbox, amount, offset and segments in one row.
- Only currently scoped native modifiers receive remote property changes; changing a tagged instance updates its scene preset snapshot.

## Slice rollout

- Uses Autodesk's native `SliceModifier` and the actual Slice Plane sub-object gizmo.
- X/Y/Z checkbuttons independently lock sliders; each enabled slider moves the plane from the bounding-box minimum (-100%) through its center (0%) to maximum (+100%).
- Local / Gizmo / World radio buttons select the coordinate system; translating the gizmo does not change its rotation.
- The modifier context bounds are captured before Slice alters the evaluated mesh, then frozen during slider gestures.
- Refine / Split / Remove Positive / Remove Negative map exactly to native `Slice_Type` 0 / 1 / 2 / 3.
- Operate On defaults to Poly. Native Slice only exposes Polygon and Face; Automatic picks Poly for Editable Poly or lower Edit Poly stacks, otherwise Face/Mesh.
- The Automatic UI choice is saved in modifier AppData; no scripted modifier is created.
- Gizmo Mode enters/leaves level 1 on the native Slice modifier through the Modify panel. Add Slice applies unique native modifiers to the current selection.

## Dialog baseline

The owning dialog includes one reusable `.NET tool title button` (18 px, Segoe UI Bold 14 px), LMB restart, a floatable left/right CUI dialog bar, and a stable `Modifier-Manager.ini` alongside the entry script. Dialog position and vertical height persist through `DialogHost`; UI-only dropdown states persist through `RolloutState` (where relevant). The launcher loads those framework helpers from its own folder, independent of an external `UI/Default` tree. UI children do not duplicate the title button. The user can increase dialog height to see more list rows or subrollout content.

## Verification

Static checks only in this environment; run `Modifier-Manager-Test.ms` and `Modifier-Manager-Slice-Test.ms` from disposable scenes in 3ds Max 2023/2026 for native end-to-end verification.
