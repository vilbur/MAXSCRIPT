# Spline Editor - Design

## Purpose

Expose frequently used Editable Spline base-object commands in a dockable Tool, preserving the established visibility operations.

## Boundaries

- **Entry** `Spline-Editor.ms`: sets version and runtime paths, loads shared UI helpers, then FN and UI, and opens the UI.
- **Backend** `Spline-Editor-FN.ms`: checks one selected `SplineShape` (Editable Spline), manages selection inversion and restoration, and calls Autodesk native spline operations. No UI logic.
- **Frontend** `Spline-Editor-UI.ms`: compact section-selector UI for all geometry actions, status text, shared title-button restart, native undo frames, and shared DialogHost integration. No geometry algorithms.
- **Tests** isolated `Tests/Spline-Editor-Test.ms` with numbered steps and retained fixture.

There are no general-purpose shared Functions or reusable Operations copied into this Tool. The only visibility primitives used are Autodesk-native `hideSelectedVerts`, `hideSelectedSegments`, `hideSelectedSplines`, and `unhideSegments`.

## Visibility contract

- Requires exactly one selected Editable Spline; Hide actions additionally require `subObjectLevel` 1, 2, or 3.
- Hide Selected does nothing when the active component selection is empty.
- Hide Unselected does nothing with empty selection or no complementary components.
- For Hide Unselected, the current component selection is stored per spline, its inverse is selected, the native Hide action runs, and the stored selection is restored. Expected native-operation exceptions are reported; failed selection restoration must not report success.
- Native vertex hiding affects adjacent segments and does not precisely isolate only unselected knots.
- Unhide All works without an active sub-object level, and calls native `unhideSegments`.
- Actions are undoable; no deletion or topology changes are part of the feature.

## UI contract

- v0.004: 144 px wide; 12 px grid; 24 px action buttons; 18 px canonical .NET tool-title button.
- Version displayed in native rollout title only; the .NET title button displays `Spline Editor`.
- Dialog location and vertical height persist beside the entry script in `Spline-Editor.ini`.
- Dialog floats initially and supports left/right docking through the canonical shared helper.
- No position-based matching is performed, so no position-precision control is required.

## Dependencies / limits

- Existing shared read-only UI framework at `G:\AI\AGENTS\Maxscript\UI\Default\`, or a user-set `spline_editor_ui_framework_path`.
- Operates on the Editable Spline base object, not an Edit Spline modifier's distinct selection context; no modifier-stack rewrite is attempted.
- 3ds Max runtime tests are pending; static validation is not a substitute for runtime validation.

## v0.003 geometry feature contract

- Knot Fuse uses native `splineOps.fuse`, and Weld uses `weldSpline` with a visible system-unit distance spinner (exact zero by default).
- Cross Insert starts native `splineOps.startCrossInsert`. The native threshold is not exposed as a MAXScript property, so the disabled threshold field is explanatory only.
- Divide inserts `division_count` equally-spaced knots using documented `refineSegment`, walking saved original segment IDs backward.
- Native Attach Pick, Attach Multiple, Detach Dialog and Explode retain native 3ds Max UI/command semantics.
- Attach Selected performs `addAndWeld` with explicit 0.0 weld threshold, verifies target spline count growth, and deletes sources only after all succeed. World-transform correctness needs runtime testing.
- Object Move/Clone: copy the current shape object, delete unselected splines from the clone, then optionally delete selected source splines after verification.
- Spline Copy Inside: copy exact knot types/positions/tangents/segment types/segment Material IDs/closure from a temporary shape into new splines within the target shape.
- Material IDs are sequential from 1, assigned per selected (or all) spline in ascending spline-index order. The same ID is assigned to every segment of that spline.
- No no-dialog Detach of arbitrary segments is claimed. Quick no-dialog Detach requires selected whole splines at level 3.
- Native geometry commands are subject to base-object context and modifier stack topology effects.

## v0.003 UI

v0.003 used a 384-px-wide dockable UI with grouped controls. **v0.004** reduces the dialog to **144 px**, with one full-width column and a persisted category selector (Visibility, Knots, Segments, Splines, Material IDs) to keep all controls accessible without horizontal clipping. Shared tool-title button and DialogHost remain unchanged; numeric settings, radio modes, selected category, position, and height persist through the canonical INI helpers. New default/minimum dialog height is 432 px; previously saved larger heights are still honoured.

## v0.004 compact UI

- Exactly 144 px dialog width via the shared DialogHost, with width locked and left/right docking intact.
- Existing control handlers and backend contracts are unchanged; switching the selected category changes only `.visible` on controls.
- No live 3ds Max run has been performed; controls and layout require in-app verification.

## Testing

`Tests/Spline-Editor-Test.ms` includes deterministic smoke cases for Divide, per-spline Material IDs, in-shape spline copy, detach-to-object, object clone, and Attach Selected; interactive modes, Native Detach/Explode modal choices, and docking require manual validation in 3ds Max. Static validation completed; live 3ds Max connection unavailable.
