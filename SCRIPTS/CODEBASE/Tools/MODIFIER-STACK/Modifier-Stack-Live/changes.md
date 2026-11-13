# Changes

## 2026-10-25 — v0.002: Shared UI baseline

- Added the canonical 18 px `.NET tool title button` (LMB restarts the newest version) to the owning dialog.
- Reused shared UI/Default helpers, left/right dockable DialogHost, immediate paint, and tool-local INI state/position/height persistence.
- Adjusted margins and vertically resizing list/subrollout space while keeping actions and status visible.
- Preserved existing feature backends, scene data, and independent UI packages.
- Static validation passed; native MaxScript dialog runtime test pending.

## 2026-10-24 — Modifier-Stack-Live v0.001

- Extracted independent entry, frontend and backend from Modifier Set Stack v0.087.
- Removed UI dependencies on other tools.
- Preserved relevant native modifier actions and callbacks.
- Static structure checks passed; runtime 3ds Max test pending.
