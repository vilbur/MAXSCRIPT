# Changes

- **2026-10-28, 0.002:** Reworked to canonical `Entry / UI / FN` Tool structure per `Tools/AGENTS.md`; corrected shared UI framework resolution for the Codebase path; retained undo, restart and persisted dialog geometry; added exception reporting and selection-restoration guard for Hide Unselected; added tests, design contract and previous-version history.
- **2026-10-28, 0.001:** Initial Hide Selected, Hide Unselected, Unhide All prototype.

## 2026-10-28 — Project v0.003
- `Spline-Editor.ms`: bump canonical project/file version.
- `Spline-Editor-FN.ms`: add native knot Fuse/Weld/Cross Insert, numerical Divide, Attach Selected, native Attach/Detach/Explode commands, quick object move/clone, in-shape spline copy, sequential spline Material IDs; enforce validation and diagnostics.
- `Spline-Editor-UI.ms`: new grouped controls, preset radios, native operation triggers, shared UI settings persistence, and updated 384×732 dialog.
- `Tests/Spline-Editor-Test.ms`: new v0.003 geometry smoke test suite.
- `README.md` and `design.md`: document feature contracts and explicit unsupported native Cross Insert threshold setting.
- Runtime verification deferred: 3ds Max connection unavailable.

## 2026-10-29 — Project v0.004
- `Spline-Editor.ms`: project and main-file version increment to 0.004.
- `Spline-Editor-UI.ms`: file version 0.003, 144 px single-column dockable layout with a five-section selector; all original actions retained, numeric/radio values and selected section saved to the shared INI; minimum/default height 432 px.
- `README.md` and `design.md`: describe compact interface and section persistence.
- Backend and tests unchanged; 3ds Max runtime layout verification pending.
