# Corner Plane — Changes

## 2026-10-29 — v0.003 (plugin update-handler syntax fix)

- Replaced `on update do updated_node` with the documented `on update do` syntax.
- Corrected the MAXScript parse error reported at line 265 of v0.002.
- Preserved the native Plane delegate, stable class ID, horizontal pivot-flip logic, and parameters.
- Advanced plugin `version:` to 3.
- Runtime compilation and interactive geometry behavior still require verification in 3ds Max.

## 2026-10-29 — v0.002 (horizontal pivot flip)

- Added a `Flip Pivot Horizontal` button to the Corner Plane Modify rollout.
- The command moves each dependent node's pivot to the opposite horizontal corner, preserving visible geometry in world space.
- Reuses the existing scene-saved `corner_x_sign` so changing Width grows away from the new corner.
- Kept the native `extends:Plane` delegate, fixed class ID, and modifier-free architecture.
- Incremented the scripted plugin definition version from 1 to 2.
- Added undoable pivot-flip, flip-back and flipped-pivot-resize test stages.
- Updated README and design documentation.
- Runtime verification in 3ds Max remains pending.

## 2026-10-29 — v0.001 (initial repository package)

- Added the scripted Geometry plugin `CornerPlane_CP` extending the native `Plane` primitive.
- Added corner-anchored interactive dragging, signed growth direction, and offset updates when Width or Length changes through plugin parameters.
- Added controls for dimensions, segments, and mapping coordinates.
- Added `Corner-Plane-Test.ms` with creation, resizing, and rotation checks.
- Added `README.md`, `design.md`, `AGENTS.md`, and this change log.
- Archived the initial release as `Corner-Plane-Plugin-v0.001.zip`.
- Runtime execution in 3ds Max **not yet verified**; this change log describes implementation intent, not a validated production build.
