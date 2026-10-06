# Changes

## 2026-10-06 — Project 0.02

- Reworked geometry-vertex painting to resolve every channel-0 face-corner map vertex explicitly from Editable Poly polygon topology.
- Removed dependence on implicit geometry-vertex/map-vertex ID correspondence for geometry-vertex painting.
- Added map-resolution validation for Integer, BitArray, and Array geometry-vertex targets.
- Extended `debug/Geometry-Diagnostics-Test.ms` to verify geometry vertex `1` fans out to map vertices `#(1, 9, 22)`, changes only those three colors, preserves map topology, restores the original white map, and rebuilds the final visual state.

## 2026-10-06 — Project 0.01

- Project 0.01: created the first Geometry Diagnostics Tool package.
- Added the direct Editable Poly channel-0 paint backend with reversible paint-session backup/restore.
- Added geometry-vertex and face-corner public paint functions without assuming geometry-vertex IDs equal map-vertex IDs.
- Added a generated six-face Editable Poly test box with 24 fully split channel-0 map vertices and six independent face colors.
- Added the standalone UI with canonical .NET tool title/restart button, test creation, paint, restore, and channel dump controls.
- Added `debug/Geometry-Diagnostics-Test.ms` with one executable numbered test workflow and inspectable undo stages.
- No mesh diagnostics are implemented yet; version 0.01 proves the paint/display layer only.
