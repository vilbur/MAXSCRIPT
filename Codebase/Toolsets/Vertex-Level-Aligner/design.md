# Vertex Level Aligner — Align TO Design

## Required path

For the latest project, Align TO must stay deliberately simple.

1. Read the live world-axis position from the current TreeView item's actual vertices.
2. Resolve the complete parent-group vertex BitArray.
3. For Editable Poly, read and write the complete group through PolyOp in `coordsys world` with the scanned node supplied. Set every group vertex directly to the same world X/Y/Z coordinate with one `polyop.setVert` batch, preserving the other two world coordinates.
4. Rescan the same object with the same threshold and active axis, then rebuild the TreeView.

Exactly two child levels must work the same as three or more. X, Y, and Z must use the same direct position-setting path. TreeView text is display-only and is never geometry data.

## Axis symmetry

X, Y, and Z must use the same native world-coordinate PolyOp path. Do not manually special-case Z or manually convert Editable Poly target points with `objectTransform` / inverse transforms for `Align TO`.

A 2-level group and a 3-level group must both collapse to exactly one level after Align TO and rescan, including translated/rotated objects at large world coordinates.


## Numeric precision

Editable Poly stores Point3 vertex coordinates with finite precision. At large translated/rotated world coordinates, setting the same world X or Y on several vertices can round-trip back with tiny per-vertex differences even though they represent the same geometric plane.

Exact-level comparison therefore accepts only a few single-precision ULPs of world-axis difference. This is a numeric-noise floor, not a user threshold: meaningful level spacing remains separate, while an aligned group must rescan as one level on X, Y, or Z.

## Broken-group vertex-color diagnostics

Vertex Level Aligner owns classification. `VertexColorPainter` owns only color storage. The painter Operation is a read-only external dependency and must not be copied or modified inside this Tool.

First-pass diagnostic behavior:

1. Use the current stored scan and its active X/Y/Z threshold groups.
2. Process only groups whose stored `is_broken` flag is true.
3. For each broken group, resolve polygons through the existing exclusive-face rule: every polygon vertex must belong to that same group.
4. Paint the union of those exclusive polygons red through an independent `VertexColorPainter_v()` session.
5. Leave valid groups and non-exclusive polygons unchanged.
6. Editable Poly uses painter stack index `0`; Edit Poly uses the current stack index of the exact stored `scan_modifier` instance. Component IDs must remain in that exact topology domain.
7. Rescan and Tool close clear the Aligner-owned painter session through `clearPaint()` so the original base color channel/display state is restored or the exact owned `PaintLayerMod` is removed.

Future axis-specific coloring may extend the color-classification layer in Vertex Level Aligner, but it must continue to use the painter public API rather than duplicating painting code.

