# Changes

## 2026-10-06 — package organization

- Moved the canonical package from `Codebase/Operations/Epoly/Vertex-Color-Painter/` to `Codebase/Operations/Vertex-Color-Painter/`; Vertex Color Painter is a generic Operation that can consume Editable Poly and multiple evaluated modifier targets, not an Edit Poly-specific operation.
- Added package-local `design.md` as the authoritative behavior/integration contract.
- Added package-local `AGENTS.md` with ownership, topology-domain, regression, API-stability, and versioning rules for future development agents.
- Added `README.md` with package layout and basic integration usage.
- Removed the duplicated Vertex Color Painter feature block from the layer-level `Operations/design.md`; package-specific design now lives with the package.

## 2026-10-06 — 0.06

- Finalized PaintLayerMod ownership as exact-instance only; `getPaintLayerMod()` no longer adopts a same-name layer after the owned reference is lost.
- Added regression test 0.09 proving an unrelated PaintLayerMod named `VERTEX COLOR PAINTER` is neither adopted nor removed by `clearPaint()`.
- Added shared package-version metadata to the production module and regression test.
- Moved the canonical package into `Codebase/Operations/Epoly/Vertex-Color-Painter/` to match the shared Operations architecture while preserving the existing Drive folder and file IDs.

## 2026-10-06 — test 0.08

- Kept both `clearPaint()` regression checks before the final visual inspection state.
- Final Part 9 now rebuilds direct-base colors after cleanup using a separate `VertexColorPainter_v` instance, so switching the main painter to the Tessellate target cannot clear the base visualization.
- The final scene intentionally leaves both test objects visibly colored: direct channel 0 on the base object and PaintLayerMod colors above Tessellate on the stack object.

## 2026-10-06 — test 0.07

- Set the Tessellate regression fixture to `faceType = 1`, `type = 0`, `tension = 0`, and `iterations = 0` exactly.
- Modifier-path paint now targets the tessellation-created vertex range `#{21..26}` instead of mixing one original and one generated vertex.
- Exact face-corner verification and the final visual state now use generated vertex 21, while all vertices 21 through 26 are painted orange.

## 2026-10-06 — 0.05

- Extended positive stack targets from Edit Poly-only to verified `Edit_Poly` and `Tessellate` modifier targets.
- Renamed the internal evaluated cache path to modifier-generic topology caching; supported positive targets are evaluated on a disposable copy and converted to Editable Poly for stable cached vertex/edge/face adjacency.
- Regression test 0.06 replaces the neutral Edit Poly fixture with a real face-center `Tessellate` modifier.
- The modifier-path test now paints one original vertex and one Tessellate-created vertex, verifies PaintLayerMod sits immediately above Tessellate, keeps the base channel untouched, and retains the exact face-corner independence test.

## 2026-10-06 — 0.04

- Fixed PaintLayerMod placement above a positive `Edit_Poly` target.
- MAXScript modifier indices are top-to-bottom, but `addModifier ... before:N` inserts the new modifier below visual stack index `N`; the previous code passed the target index directly and therefore placed Vertex Color Painter below the target.
- The painter now adds at the top when the target is stack index 1, otherwise inserts with `before:(target_index - 1)`, then verifies `target_index == paint_index + 1`.
- Regression test 0.05 prints both resulting stack indices before validating PaintLayerMod state.

## 2026-10-06 — 0.04

- Refocused the regression test on Vertex Color Painter itself and removed Edit Poly tessellation/topology-generation behavior from the paint test fixture.
- Modifier-path coverage now uses a neutral stable Edit Poly target, paints known vertices through PaintLayerMod, verifies the base channel remains untouched, and proves exact face-corner independence by keeping one corner red while another corner of the same geometry vertex remains orange.
- Edit Poly operation authoring/preview/commit semantics are explicitly outside the Vertex Color Painter regression contract.

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
