# Vertex Color Painter Agent Instructions

These instructions apply to `Codebase/Operations/Vertex-Color-Painter/`.

## Required reading before changes

1. Read the shared MaxScript `AGENTS.md`.
2. Read `Codebase/Operations/AGENTS.md`.
3. Read this package `design.md`.
4. Read the latest canonical `Vertex-Color-Painter.ms` and `Vertex-Color-Painter-Test.ms` before editing either file.

The canonical Google Drive package is the source of truth. Preserve existing Drive IDs for canonical files.

## Package scope

Vertex Color Painter is a generic Operation-level color-paint service. It is not an Edit Poly operation and must remain directly under `Codebase/Operations/Vertex-Color-Painter/`.

Editable Poly, Edit Poly, Tessellate, and PaintLayerMod are implementation/topology sources used by the Operation; they do not change the package's architecture category.

## Ownership invariant

`PaintLayerMod` ownership is exact-instance only.

Never reintroduce lookup, adoption, cleanup, or recovery by modifier name. `VERTEX COLOR PAINTER` is display text only. A same-name foreign layer must remain untouched.

## Topology invariant

Component IDs belong to the exact topology cached by `setTarget()`. Never mix IDs from another stack level. Never use TriMesh triangle face IDs as Editable Poly polygon face IDs.

After external topology changes, cached IDs are stale until `invalidate()` + `refresh()` completes successfully.

Do not compact the Editable Poly base underneath active modifiers. Follow the shared dead-topology rules exactly.

## Supported stack targets

Current regression-proven positive target classes are:

- `Edit_Poly`
- `Tessellate`

Do not add another supported class merely because it evaluates to geometry. Adding a target class requires a dedicated regression fixture that proves cached polygon topology, PaintLayer placement, paint application, cleanup, and base-channel isolation.

## Regression requirement

Any production-code change must update the regression test when needed and must preserve coverage for:

- direct base painting;
- exact corner painting;
- modifier-stack painting on generated topology;
- `clearPaint()` restoration/removal;
- same-name foreign PaintLayer isolation;
- final inspectable visual state.

Do not simplify away the exact-corner test or the same-name ownership test.

## Public API stability

Preserve the established public API unless a deliberate contract change is documented in `design.md`:

`setTarget`, `beginPaint`, `paintCorner`, `paintVertex`, `paintVertices`, `paintEdge`, `paintFace`, `paintCorners`, `endPaint`, `invalidate`, `refresh`, `isTargetValid`, `clearPaint`.

Higher-level Tools should depend on this API rather than internal helpers.

## Versioning and delivery

Follow shared versioning rules:

- bump the production file version only when production code changes;
- bump the test file version only when test code changes;
- create a new `_Versions` snapshot for each changed script version;
- update canonical files in place;
- update `changes.md` for package changes;
- do not create duplicate canonical files.

Before delivery, verify the canonical Drive contents and package location.
