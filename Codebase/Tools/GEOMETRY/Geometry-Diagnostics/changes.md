# Changes

## 2026-10-06 — Project 0.07

- Updated Geometry Diagnostics for `VertexColorPainter` 0.02: cleanup now calls `clearPaint()` instead of the collision-prone `clear()` name.
- Corrected the shared Operation dependency path to the canonical `Codebase/Operations/Vertex-Color-Painter` repository used by the current synchronized workspace.
- Updated the standalone regression loader to the same canonical Operation path.

## 2026-10-06 — Project 0.06

- Extracted reusable vertex-color painting from Geometry Diagnostics into `Codebase/Operations/Epoly/Vertex-Color-Painter/Vertex-Color-Painter.ms`.
- Added stateful `VertexColorPainter_v` / `VertexColorPainter` API with bound `source_node` + `stack_index`, cached polygon topology, cached evaluated mesh, explicit `paintCorner`, `paintVertex`, `paintVertices`, `paintEdge`, `paintFace`, bulk `paintCorners`, and paint transaction methods.
- Positive stack targets now bind to an exact `Edit_Poly` reference and place the operation-owned `PaintLayerMod` immediately above it; stack-index shifts are tracked without losing target identity.
- Geometry Diagnostics backend now delegates paint work to `VertexColorPainter` instead of owning duplicate channel-0 / PaintLayerMod logic.
- Geometry Diagnostics main entry now loads the shared Operation dependency before the backend and supports both the canonical `Tools/GEOMETRY/Geometry-Diagnostics` path and the previous direct `Tools/Geometry-Diagnostics` path while locating shared UI helpers.
- Added `Vertex-Color-Painter-Test.ms` regression coverage for exact base corner mapping, vertex/edge/face painting, restore, Edit Poly tessellation, evaluated-only vertex painting, exact modifier face/vertex painting, and safe PaintLayer removal.
- Updated Geometry Diagnostics regression loading and PaintState release behavior for the extracted Operation.

## 2026-10-06 — Project 0.05

- Fixed the standalone entry dependency path for the current `Codebase/Tools/Geometry-Diagnostics` location so shared `UI/Default` helpers resolve from the MaxScript project root.
- Moved `Geometry-Diagnostics.ini` persistence from the 3ds Max user-scripts directory to the Geometry Diagnostics script folder.
- Updated `Geometry-Diagnostics.ms` and `Geometry-Diagnostics-UI.ms`; backend and tests are unchanged.

## 2026-10-06 — Project 0.04

- Updated `debug/Geometry-Diagnostics-Test.ms` so the VertexPaint modifier test targets only evaluated vertex IDs created by Edit Poly tessellation, instead of repainting base vertex `1`.
- The modifier-path validation now verifies every tessellation-created evaluated vertex receives the diagnostic orange color while the Editable Poly base channel remains untouched.
- Added `clearListener()` immediately before the test execution queue so every test run starts with clean Listener output.

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
- Project 0.03: added automatic VertexPaint modifier routing when a node has a modifier stack.
- Added a tool-owned `PaintLayerMod` on channel 0 that paints evaluated geometry without changing the Editable Poly base channel.
- Added safe removal of only the Geometry Diagnostics paint layer while preserving unrelated modifiers.
- Added an Edit Poly tessellation test proving the evaluated topology changes, VertexPaint paints above it, and the 24-entry base color map remains untouched.
