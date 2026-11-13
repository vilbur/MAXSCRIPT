# Modifier Sets

Split from **Modifier Set Stack 0.087** (read-only backup) on 2026-10-24.

- Entry: `Modifier-Sets.ms`
- Backend: `Modifier-Sets-FN.ms` (no UI dependencies)
- Frontend: `Modifier-Sets-UI.ms` (standalone dialog)
- Initial independent version: **0.001**
- Current project version: **0.002**

Owns named sets, scene-backed membership (the original custom-attribute schema/ID is preserved for saved scene compatibility), assignment, ungrouping, set ON/OFF and its independent modifier-availability list. No dependency on LIVE STACK or Modifier Manager UI.

## Dialog baseline

The owning dialog includes one shared `.NET tool title button` (18 px, Segoe UI Bold 14 px), LMB restart, a floatable left/right CUI dialog bar, and a stable `Modifier-Sets.ini` alongside the entry script. Dialog position and vertical height persist through `DialogHost`; UI-only dropdown states persist through `RolloutState` (where relevant). UI children do not duplicate the title button. The user can increase dialog height to see more list rows or subrollout content.

## Verification

Static checks only; native 3ds Max bridge unavailable for end-to-end UI and modifier runtime testing.
