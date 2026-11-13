# Surface Intersections — live prototype 0.02

The `.ms` tool calculates all pairwise intersections of finite open meshes and places the curves into one **stable SplineShape scene node**. The node is recalculated **in place**, so its name, identity, and modifier stack can survive a refresh. Curve topology/knot counts are free to change, so topology-dependent modifiers may still lose their selections.

## Load and use in 3ds Max 2023 / 2026

1. Select two or more open geometry objects. One may be a Mesh, another Editable Poly, another an object with an Edit Poly modifier.
2. Run `Surface-Intersections.ms` using **Scripting > Run Script**. The result `Surface_Intersections` will be selected.
3. Move, rotate or scale a source object (then release the mouse), or change its vertices/topology. After a short debounce, the output spline should update automatically.
4. The original source geometry and modifier stacks are never intentionally changed by intersection extraction.
5. Run `Surface-Intersections-Test.ms` (after loading the main `.ms`) to create perpendicular test surfaces, exercise a same-node manual refresh, and reenable interactive live tracking.

## Listener commands

```maxscript
-- Select at least two source objects, then replace the current active link:
SurfaceIntersections.run position_precision_mm:0.01

-- Disable automatic updates, but allow explicit refresh:
SurfaceIntersections.setMode #manual
SurfaceIntersections.refresh()

-- Reenable automatic updates:
SurfaceIntersections.setMode #live

-- Keep the current spline as-is, disabling both automatic and manual refresh:
SurfaceIntersections.setMode #freeze

-- Resume manual mode and rebuild when requested:
SurfaceIntersections.setMode #manual
SurfaceIntersections.refresh()

-- Completely stop tracking, while leaving the current spline object in the scene:
SurfaceIntersections.stop()
```

The precision choices for endpoint matching are `1.0`, `0.1`, and `0.01` millimeters. They do not snap source vertices. The default is 0.01 mm. The spline remains a piecewise-linear approximation from evaluated mesh triangles.

## Live mechanism

- `NodeEventCallback` monitors geometry, topology, model-structure, controller and deletion events on the registered source AnimHandles, including many undo/redo changes.
- A separate `when transform` change handler monitors source object movement/rotation/scale. Animated-controller changes are **not guaranteed** to trigger it.
- Callbacks only mark the geometry as dirty. A `System.Windows.Forms.Timer` waits 350 ms before regenerating. The node callback also defers changes until mouse release and/or idle.
- If a source node is deleted or an evaluation fails, an error is reported rather than silently accepting an empty output. The live tool then switches to Manual mode.
- The script manages one active linked result at a time. Starting a new link detaches the old monitors without deleting the old spline.
- Links are **session-local**. Saving the `.max` scene preserves the output spline, but does **not** serialize/reinstall MaxScript change handlers. Run the script again to re-establish tracking.
- This version does not have a rollout; it exposes three update modes through the Listener. It does not use the shared UI templates until a UI is implemented.

## Limitations

- Mesh **curve output only**. This version does not generate trimmed mesh regions or a closed solid. There is no unambiguous way to choose which open surface patches to keep without a region-selection policy.
- Applying the Surface modifier to a result works only if the splines can make an appropriate patch network (usually 3/4-sided regions); arbitrary intersecting curves do not automatically become surface patches.
- Coplanar overlaps, tangent/grazing intersections, coincident regions and unstable degenerate triangles are not resolved robustly.
- Intersections are recomputed from triangulated evaluated meshes. High-poly combinations may be slow because all face pairs are examined with bounding-box rejection, not a spatial index.
- A curve topology change can invalidate downstream shape modifiers, even though the output node itself is preserved.
- Node events and WinForms timers need Max's UI message loop. For scripted edits, or if automatic detection has not fired, use `SurfaceIntersections.refresh()`.
- Automatic relinking across file save/reopen, multiple persistent independent result objects, dynamic final-mesh output, and full shared-template UI are future improvements.

## Test expectations

`TEST 3 | Same node and changed curve geometry: true` is the critical structural check for the same result node being modified after a source transform. `TEST 4` reenables live mode, after which an actual mouse-driven change must be checked visually. This scripted test does not prove asynchronous automatic delivery without running inside 3ds Max.

The `.ms` and test underwent local static inspection. They have **not** been executed in 3ds Max in this session. They have **not** been uploaded to a canonical Google Drive tool directory, and no protected Codebase files were changed.
