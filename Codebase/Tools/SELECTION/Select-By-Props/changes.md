# Select-By-Props changes

## 2026-10-03 — 0.001
- Renamed the tool and UI title to `Select-By-Props`.
- Removed the `Selection and Layers` rollout from the tool UI.
- Reduced the floater height to fit the remaining property-selection rollout.
- Renamed the tool INI file to `Select-By-Props.ini`.

## 2026-10-03 — 0.002
- Added a bottom `Restart` button that reloads the newest numeric `Select-By-Props_*.ms` version beside the running script.
- Added `FACING CAMERA` polygon selection using the active camera or viewport orientation with no angle tolerance.
- Added node-aware Edit Poly face reads and selection so the camera-facing operation works with both Editable Poly and Edit Poly.
- Added `Select-By-Props_TEST_0.002.ms` for Editable Poly, Edit Poly, and Restart resolver checks.

## 2026-10-03 — 0.003
- Tightened `FACING CAMERA` to require a normal/view alignment of at least `0.95` instead of any positive front-facing alignment.
- Added a named camera-face alignment threshold and a focused threshold test.
- Added `Select-By-Props_TEST_0.003.ms`.
