# Changes

## 2026-10-31 — Modifier-Manager v0.022

- Added native Slice modifier rollout, gizmo-mode toggle and Add Slice button.
- Added signed X/Y/Z sliders constrained to the modifier-context bounding box, independently locked by axis checkbuttons.
- Added Local / Gizmo / World movement axes; sliders preserve the plane's rotation.
- Added Refine / Split / Remove Positive / Remove Negative Slice Type controls.
- Added Automatic / Poly / Mesh processing (Poly default); Automatic resolves native Face or Polygon per upstream stack.
- Included a Slice-specific MaxScript runtime test. Static validation only outside 3ds Max.
- Bundled the five required UI framework helpers next to the launcher; startup no longer depends on a separate `UI/Default` directory.

## 2026-10-25 — v0.012: Shared UI baseline

- Added the canonical 18 px `.NET tool title button` (LMB restarts the newest version) to the owning dialog.
- Reused shared UI/Default helpers, left/right dockable DialogHost, immediate paint, and tool-local INI state/position/height persistence.
- Adjusted margins and vertically resizing list/subrollout space while keeping actions and status visible.
- Preserved existing feature backends, scene data, and independent UI packages.
- Static validation passed; native MaxScript dialog runtime test pending.

## 2026-10-25 — Modifier-Manager v0.011

- Added MeshSmooth and Chamfer scene preset rollouts using one reusable list controller.
- Added shared native modifier preset backend, root-node persistence, generated names and tagged live instances.
- Added Add as instance / Unique and exact-position topmost Re-instance workflows.
- Added full MeshSmooth subdivision/separation and Chamfer edge filters, open state, and compact Inset row.
- Included an independent MaxScript test harness and upgraded the launcher, UI, and backend global project-version guards.
- Full native 3ds Max runtime/UI testing pending; static validation performed outside 3ds Max.

## 2026-10-24 — Modifier-Manager v0.001

- Extracted independent entry, frontend and backend from Modifier Set Stack v0.087.
- Removed UI dependencies on other tools.
- Preserved relevant native modifier actions and callbacks.
- Static structure checks passed; runtime 3ds Max test pending.
