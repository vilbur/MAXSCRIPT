# Print-Debug Design

## Intent

Print focused scene and user-interface diagnostics to the 3ds Max Listener while debugging MaxScript tools.

## Scope

- Print selected evaluated-object vertex IDs, positions, vertex normals, triangle faces, geometric face normals, polygons, and material IDs by checkbox.
- Print properties of the modifier currently selected in the Modify panel.
- Choose a globally accessible rollout or rollout floater and print its properties, bounds, dock state when registered as a dialog bar, MaxScript control names/positions/sizes/properties, and native child-window details.

## Approach

The tool is a three-file package: `Print-Debug.ms` loads `Print-Debug-FN.ms` and `Print-Debug-UI.ms` from its own directory. The backend uses `snapshotAsMesh` so the object report includes modifier-stack effects without editing the scene. Polygons are groups of adjacent evaluated triangles connected across invisible edges. The UI selector reads globally accessible Rollout and RolloutFloater values; native control IDs are reported when the installed 3ds Max API exposes them.

The UI loads `IniSettings.ms`, `RolloutState.ms`, `DialogHost.ms`, `ScriptReload.ms`, and `ToolTitleButton.ms` from the canonical `CODEBASE/UI/Default` folder through a path relative to this tool package. The standalone dialog uses the shared title/restart button, persists its controls and size/state to the unversioned `Print-Debug.ini` beside the entry script, and floats by default while supporting left/right docking. It applies the user's measured `[6,29]` registered-dialog position correction.

## Constraints

- All output goes to the Listener.
- Inspection does not alter scene geometry, selections, modifiers, or user-interface state.
- Dialog-bar dock state is available only for registered dockable rollouts/floaters; other windows report the native API reason it is unavailable.
- The rollout selector can only list globally accessible Rollout and RolloutFloater values.
- The native control ID API is attempted where available; the MaxScript control name remains the reported control ID on older supported Max versions.
- Each source file stores an internal version and the shared project version; the UI displays the global project version.
