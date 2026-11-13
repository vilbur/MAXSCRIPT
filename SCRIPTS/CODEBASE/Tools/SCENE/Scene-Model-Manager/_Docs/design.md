# Scene Model Manager 0.001 design

## Purpose

Manage the conversion of an imported real-world architectural scene into a safe editing scene and then into multiple model/export definitions.

## Section 1 - PREPARE SCENE

1. Convert saved `1 Unit = 1 Millimeter` source through native Merge into `1 Unit = 1 Meter` while preserving physical size.
2. Use centimeter display for editing.
3. Detect import outlier candidates before offset. Geometry bounds are authoritative; detection only selects top-level non-geometry leaf nodes whose pivot is outside those exact bounds.
4. Center geometry pivots.
5. Offset the complete scene to a convenient work origin while persistently storing the real-world offset.
6. The working scene remains near origin. Restore exists only for returning to original real-world coordinates when needed.

## Section 2 - MODEL NODES

- A MODEL NODE is a visible Text shape in the scene.
- Its position is the rotation/export pivot.
- Its visible Z orientation shows the picked source XY direction.
- It stores one ORTHO correction, one model ratio, and persistent membership handles.
- Membership does not reparent scene objects.
- ORTHO VIEW rotates the complete editing scene through a temporary scene driver, adapted from the tested Rotate-To-Ortho parenting workflow.
- Only MODEL NODE members are exported.

## Section 3 - MODEL / EXPORT

- Each MODEL NODE owns its ratio such as `1:100` or `1:150`.
- MAX copy and OBJ export are temporary Hold/Fetch transactions.
- The transaction normalizes any currently active editing ORTHO view, applies the selected MODEL NODE ORTHO, bakes it in the held copy, applies model ratio and target units, writes output, then Fetch restores the working editing scene.
- Batch OBJ export runs one independent transaction per MODEL NODE.

## Source tools

The `_Source` folder contains unchanged copies of the four uploaded tested tools used as the behavioral baseline for version 0.001.
