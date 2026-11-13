# Surface-Intersections test/ — AGENTS.md

## CODEBASE SOURCE-FORK RULE — NO RUNTIME DEPENDENCY

- The shared Codebase is a canonical **source/reference library**, not a runtime dependency location for downstream tools.
- Before implementing equivalent behavior, inspect the relevant Codebase Function, Operation, Tool, or Toolset and use the verified implementation as the starting source.
- When a new or downstream tool uses Codebase behavior, copy/fork the required implementation into that tool's own project files and version. The fork becomes tool-owned source for that tool version.
- Never create a runtime dependency from a downstream tool to the shared Codebase. Do not `fileIn`, import, load, search for, or reference an absolute/relative Codebase path at runtime.
- A delivered tool must continue to run when the shared Codebase folder is unavailable.
- Fork only the minimum required source and its required lower-level behavior. Preserve verified contracts where practical, then adapt the tool-local fork when project-specific behavior is needed.
- Codebase changes do not automatically propagate into existing tools. Updating a tool from newer Codebase source is an explicit, reviewed source-sync/fork operation.
- Promote a generally useful fix back into the canonical Codebase only when the current user prompt explicitly authorizes that protected Codebase change.
- The `Functions -> Operations -> Tools -> Toolsets` hierarchy remains the Codebase's source-organization model. References to lower-layer calls/dependencies inside Codebase documentation describe logical composition; downstream deliverables must vendor/fork the required source locally rather than depend on the central Codebase at runtime.

This file supplements `../AGENTS.md`, the shared MaxScript agents and the shared Tools rules. It governs **test-only** files in this folder. Do not change protected Codebase files without explicit current-prompt authorization.

## Safety first

Before testing, delete all scene nodes with `$* as array` and `delete scene_nodes`, including hidden/frozen nodes. **This permanently removes scene objects without prompting**, but unlike a complete scene reset it preserves scene-level settings such as units, render settings and animation range. Never run tests in a scene containing objects the user wants to keep. Stop existing live callbacks before deleting nodes, then load the current `../Surface-Intersections.ms` with selection cleared to avoid unintended results. **Never call `resetMaxFile` from these tests.**

## Test fixtures and truth conditions

Build six independent one-sided planes as faces of a 100-scene-unit cube: `BOTTOM`, `TOP`, `LEFT`, `RIGHT`, `FRONT`, `BACK`, at ±50 along X/Y/Z. Keep one Editable Poly and one Edit Poly modifier in the mix to exercise evaluated stacks, with `showCage = off`. Do not replace this fixture with three crossing planes: the 6-plane case deliberately exercises shared boundary edges.

- Six source planes -> 15 source pairs: 12 adjacent pairs should have **one full 100-unit edge** each, and three opposite pairs have none. Compare actual endpoints to the 12 explicit expected cube edges; count alone is insufficient.
- Curves test: use the same linked result node before and after a TOP-plane move of `[0,0,-15]`; assert manual refresh succeeded and knot positions changed; restore `#live` for interactive inspection.
- Surface test: apply native `Surface()` above the extracted spline, log evaluated vertices and faces before/after moving TOP, and report a genuine **FAIL** if zero faces are produced. Do not fabricate patches, silently loosen tolerances, or call curve completeness a Surface success.
- Preserve negative-coordinate cases, shared coplanar *edges* in noncoplanar triangle pairs, intersecting interior edges, duplicate segments, branch junctions and topology changes in future regression tests. Truly coplanar face/face overlap is not currently supported.
- `#live` reenabled is not proof that async edits actually update. Manual source edits with LMB release, modifier changes, undo and scene reload must be observed inside 3ds Max and reported separately.

## Logs and diagnostics

`Surface-Intersections-Diagnostics.ms` is the canonical test-only logger. Tests write per-scenario `test/logs/Surface-Intersections-{Curves|Surface}-Debug.txt`. Keep diagnostic records parseable: `SI DEBUG | STAGE | details`, `PASS/FAIL`, original object identity, source transforms, world-space evaluated mesh vertex positions and face indices, spline counts, knot coordinates and in/out vectors, and raw before/after comparisons. Include both expected and actual values on failure; preserve unrounded numerical data.

Do not replace a failed mesh snapshot with `#()`, a zero face count, or success. Always close/flush log streams. Tests may overwrite their scenario log when rerun; log artifacts are not source code. Update fixture or diagnostic expectations only when algorithm behavior/specification justifies the change—never to mask failure.

## How to run

Use one saved test file per execution. `Surface-Intersections-Curves-Test.ms` is the first correctness gate; `Surface-Intersections-Surface-Test.ms` is a separate experimental second gate. `Surface-Intersections-Test.ms` is a simpler regression test. All tests should load the current parent script from the repository and leave the generated geometry available for inspection after the run. No test may claim runtime validation unless run in 3ds Max.
