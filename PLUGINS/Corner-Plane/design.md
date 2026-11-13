# Corner Plane — Design

## Purpose

Provide a corner-anchored Plane primitive in Autodesk 3ds Max while retaining the native Plane procedural geometry and its core parameters.

## Implementation

- `Corner-Plane.ms` declares the scripted Geometry plugin `CornerPlane_CP` using `extends:Plane`, `replaceUI:true`, and a fixed class ID.
- Delegated native Plane parameters store the generated surface; the custom parameter block stores Width, Length, Width Segs, Length Segs, Generate Mapping Coords, and the sign of the original creation drag.
- The creation tool records the starting grid point as the node's transform origin. The drag delta establishes Width/Length and the X/Y growth direction.
- `updateCornerOffset` updates `objectOffsetPos` to one half of the native Plane's dimensions, with signs from the saved drag direction, on nodes depending on the plugin base object.
- `postCreate`, `postLoad`, `attachedToNode`, and parameter-set handlers resynchronize the delegate/offset. The implementation does not add XForm or other modifiers.
- Width and Length are currently non-animatable. The custom Modify rollout is the intended editing interface.

## Horizontal pivot flipping (v0.002)

- The Pivot group adds a button `Flip Pivot Horizontal` to the plugin's native Modify rollout.
- `flipPivotHorizontally` reads the saved `corner_x_sign` and moves the node pivot by the full delegated Plane width along its current local X axis.
- The documented MAXScript `node.pivot` setter preserves the node's world-space geometry. The plugin then reverses `corner_x_sign`, and the existing `on corner_x_sign set` callback synchronizes the object offset.
- The operation is a toggle: pressing again restores the previous horizontal corner, without moving the visible surface.
- Sign changes persist as part of the existing scene-saved parameter block; no separate flip flag is needed.
- Node instancing is handled by applying the pivot move to every valid dependent node of the same plugin base object.
- Modified Width afterward grows away from the newly selected pivot.
- The button wraps the operation in a named undo entry; the exposed function is also callable directly from MAXScript when the caller owns undo control.
- Creation drag direction remains the initial state; the feature does not affect Y-axis anchoring.

## Plugin update handler (v0.003)

- The event must use `on update do` directly followed by its body. The previous token `updated_node` was invalid and caused a parser error at the next opening parenthesis.
- No geometry behavior or persistent data contract was intentionally changed in this release.

## Public contract

- Plugin class: `CornerPlane_CP`.
- Category: `Vilbur`, display name `Corner Plane`.
- Native Plane is the geometry delegate; this is not an independent mesh generator.
- Local corner coordinates remain at the node pivot for the selected original drag quadrant when editing through the custom parameter rollout.
- Multiple nodes referencing the same base object should update offsets together.

## Known constraints and verification

Version **0.003** is an unverified incremental implementation and has **not been runtime-verified in 3ds Max**. In particular, test the horizontal pivot button, geometry invariance during flip, the interactive creation path, the correct corner after resizing, negative X/Y drag quadrants, cloned/instanced objects, scene reopen, and modifier-free parameter editing before production use.

Native delegate parameters edited directly may bypass the plugin's parameter change handlers. The plugin does not expose every native Plane option (including renderScale, density, and real-world mapping size) in its custom rollout. Dimension animation is disabled.

## Source and tests

- `Corner-Plane.ms` — canonical plugin entry file.
- `Corner-Plane-Test.ms` — numbered scene tests, undoable and intentionally left in scene for inspection.
- `README.md` — installation and basic usage.
- `changes.md` — release change log.
- `AGENTS.md` — project-local development directions.

## Future checks

1. Execute `Corner-Plane-Test.ms` (v0.002) in 3ds Max and verify all six numbered test stages in Listener.
2. Exercise all four mouse-drag quadrants and confirm corner positioning after changing dimensions.
3. Confirm save/reopen, cloning and instancing preserve node pivot/offset behavior.
4. Verify the native geometry extension, pivot setter behavior, instancing, Undo and UI behavior in the target 3ds Max version before shipping a production release.
