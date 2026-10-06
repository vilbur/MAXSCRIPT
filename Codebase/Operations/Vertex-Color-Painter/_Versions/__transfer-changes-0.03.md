# Changes

## 2026-10-06 — 0.03

- Fixed positive Edit Poly target caching after runtime test showed `EditPolyMod.GetNumVertices/GetNumEdges/GetNumFaces` returning zero outside a usable modifier query context.
- Positive targets now evaluate one temporary copied node at the exact bound stack level, strip only modifiers above the target, collapse the copy to Editable Poly, and cache polygon/edge/vertex IDs from that evaluated result.
- Reuses the same temporary evaluated result to build `evaluated_mesh`, avoiding a second modifier-topology discovery pass.
- `isTargetValid()` now validates the bound node/modifier reference for cached positive targets; callers still explicitly invalidate and refresh after external topology edits.
- Strengthened the regression test so failed PaintLayer creation cannot produce false adjacency/index passes, and exact modifier-corner verification uses `GetRawIndex()` + `GetRawColor()`.

## 2026-10-06 — 0.02

- Fixed target switching after a previous paint session: the internal bare `clear()` call was resolving to MAXScript's built-in `clear` generic and raising `generic apply wanted 1, got 0`.
- Renamed the public cleanup method to `clearPaint()` to avoid the built-in identifier collision and updated callers/tests.
- `getCurrentTargetStackIndex()` now synchronizes the stored `stack_index` property after the operation-owned PaintLayerMod changes stack positions.

## 2026-10-06 — 0.01

- Added the first reusable `VertexColorPainter_v` operation and canonical `VertexColorPainter` instance.
- Added cached base Editable Poly and Edit Poly topology, direct channel-0 paint, PaintLayerMod paint, exact face-corner paint, vertex/edge/face helpers, reversible paint state, and regression test.
