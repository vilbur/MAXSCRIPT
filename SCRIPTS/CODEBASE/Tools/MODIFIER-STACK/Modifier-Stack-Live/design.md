# Modifier Stack Live

Split from **Modifier Set Stack 0.087** (read-only backup) on 2026-10-24.

- Entry: `Modifier-Stack-Live.ms`
- Backend: `Modifier-Stack-Live-FN.ms` (no UI dependencies)
- Frontend: `Modifier-Stack-Live-UI.ms` (standalone dialog)
- Initial independent version: **0.001**
- Current project version: **0.002**

Owns the extracted **LIVE STACK** 30-row child rollout. Reads the selected object's real modifier stack by handles, imports native Modify-panel selection and applies ON/OFF/Toggle to checked modifiers. Does not own named sets or parameter-specific child rollouts.

## Dialog baseline

The owning dialog includes one shared `.NET tool title button` (18 px, Segoe UI Bold 14 px), LMB restart, a floatable left/right CUI dialog bar, and a stable `Modifier-Stack-Live.ini` alongside the entry script. Dialog position and vertical height persist through `DialogHost`; UI-only dropdown states persist through `RolloutState` (where relevant). UI children do not duplicate the title button. The user can increase dialog height to see more list rows or subrollout content.

## Verification

Static checks only; native 3ds Max bridge unavailable for end-to-end UI and modifier runtime testing.
