# Surface-Intersections — AGENTS.md

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

## Scope and precedence

This file applies to `AI/AGENTS/Maxscript/Codebase/Tools/GEOMETRY/Surface-Intersections/` and its descendants. Before any change, read the current shared MaxScript `AGENTS.md`, the `Codebase/Tools/AGENTS.md` layer rules, and their relevant referenced rules (especially MaxScript syntax, protected identifiers, numeric precision, architecture, UI, test and logging rules). If a rule conflicts with this file, the higher-level shared rule wins. `test/AGENTS.md` and `doc/AGENTS.md` add instructions for their respective folders.

This directory is inside the **protected, normally read-only** shared Codebase/Tools layer. Reading and testing do not grant permission to edit it. A current user request must explicitly authorize the particular Surface-Intersections files or documentation to change. Recheck the latest Google Drive copies before writing; preserve changes from other chats. Update the existing canonical Drive file ID, not a duplicate or renamed copy. Do not change unrelated shared Functions/Operations/Tools.

## Project purpose and current state

The project extracts intersections among **two or more finite, one-sided/open source surfaces** and emits piecewise-linear splines in one `Surface_Intersections` scene node. Source evaluation supports mixed object types and modifier stacks by `snapshotAsMesh`. The result node is updated in place. Dynamic changes are monitored *in the running 3ds Max session*; a saved/reopened `.max` scene does not automatically reinstate callback registrations.

Canonical entry file: `Surface-Intersections.ms` (entry v0.07, backend/UI v0.01, stored project v0.10 at the time of this update). Do **not** use this header as version authority: read the script's current values. This is a **curves prototype**, not a working procedural trimmed-mesh generator. A dockable source-priority UI now exists in `Surface-Intersections-UI.ms`, with geometry/backend in `Surface-Intersections-FN.ms`. Runtime tests remain pending; do not claim the new clipping is certified.

Read `design.md` for implementation boundaries, the project plan, and known failure modes. `doc/Surface-Intersections-Guide.md` is older user guidance and may contain obsolete baseline statements; verify anything there against canonical code before repeating it.

## Architecture / behavioral invariants

- Input: array of at least two valid geometry scene nodes. Never alter the sources to calculate intersections.
- Intersection engine: world-space evaluated triangle caches; face-pair bounding-box rejection; finite triangle/triangle intersections; support a source triangle edge lying in the opposite triangle's plane; deduplicate at explicit position precision; assemble curve chains.
- Supported point-identity precision selections: 1 mm, 0.1 mm, 0.01 mm (default 0.01 mm), converted with `units.decodeValue`. This precision affects temporary endpoint identity only. Do not silently snap original vertices or impose new epsilons.
- Current output: a stable `SplineShape` scene node whose spline content can change. A stable node **does not guarantee** stable knot IDs or downstream modifier selections.
- Live tracking: `NodeEventCallback`, transform change handler, debounced WinForms timer; do not regenerate synchronously from callbacks; do not let callbacks recursively trigger regeneration. Modes are `#live`, `#manual`, and `#freeze`; `stop()` detaches monitors while leaving geometry.
- Important public methods: `startLive`, `run`, `refresh`, `setMode`, `stop`, `createFromSelection`. Keep these compatible unless a versioned API change is explicitly requested.
- Coplanar face/face overlap, tangencies, degenerate triangles, robust arbitrary patch trimming, scene-persistent links and direct mesh output are **not solved** by this version.
- Do not describe applying the native `Surface` modifier as a verified mesh solution. Creating a valid multi-patch three-/four-sided spline cage is a separate geometry/topology problem.

## Change procedure

1. Identify exactly which canonical files need edits. Read their latest Google Drive versions and relevant shared agent/rule files first; do not silently switch to attachments, legacy releases or stale documentation.
2. Use established shared Functions/Operations where appropriate; inspect them before implementing new generic geometry, precision, path or logging helpers. Their protected files are not automatically authorized to be modified.
3. Preserve existing APIs and source/object identity. For algorithm edits, explicitly cover shared boundary edges, non-intersecting pairs, branch junctions, open chains, and negative coordinates.
4. Follow MAXScript style: `function`, `if ... then`, camelCase functions, snake_case local variables, opening parentheses on new lines. No protected identifier shadowing (especially `modifier`), no silent fatal catches, no invented MAXScript APIs, no fake success.
5. For each modified **code** file increment its own version by the established precision step; increment the shared project version once for the change set, and store it in all modified code files. Do not touch version fields in unchanged code files. The highest loaded project version wins; UI (when present) must display the global project version.
6. Keep the canonical entry name `Surface-Intersections.ms`. Follow repository `_Versions/` history policy for versioned releases, without creating same-name duplicates or suffixes such as `(1)`/`copy`.
7. Run focused static checks and the relevant test scripts. Do not claim a 3ds Max runtime pass from static or Python-only analysis. Preserve raw actual/expected coordinates and the test log's failure count.
8. Update `design.md`, applicable agent files, and `changes.md` only when their descriptions actually change; keep observed results separate from proposed designs.

## Safe execution

**Production tool** must never reset or delete scene contents. **Diagnostic tests** delete all scene nodes (including hidden/frozen) without resetting the Max scene. This preserves scene settings but destroys existing objects; never run tests casually in a user's working scene. See `test/AGENTS.md` for test order, log format and acceptance conditions.

## Current file map

- `Surface-Intersections.ms` — canonical entry loader.
- `Surface-Intersections-FN.ms` — independent backend, geometry and live callbacks.
- `Surface-Intersections-UI.ms` — independent frontend, source order, kept-side controls and update modes.
- `design.md` — source-derived implementation/design status and future roadmap.
- `test/Surface-Intersections-Test.ms` — original six-plane end-to-end test.
- `test/Surface-Intersections-Diagnostics.ms` — shared logging, geometry setup and 12-edge checks.
- `test/Surface-Intersections-Curves-Test.ms` — curve extraction and refresh regression test.
- `test/Surface-Intersections-Surface-Test.ms` — experimental native Surface modifier evaluation.
- `test/logs/` — runtime logs written during tests; logs are not source-version authority.
- `doc/Surface-Intersections-Guide.md` — user guide; check its release/version claims against current code.
- `_Versions/` — historical release area, not a replacement for the canonical entry.

## Ordered clipping and hidden-edge knot invariants

- Source list order is meaningful. Earlier planar sources are cutters of intersections between later source pairs. The selected kept side must be explicit or use the Auto center heuristic. Do not claim Auto is unambiguous for arbitrary open geometry.
- Cutter footprints are finite; a nonplanar source must not be silently treated as an infinite cutting plane. A failed cutter should report its limitation, not corrupt other geometric results.
- Hidden edges refer to evaluated triangulation edge visibility (`getEdgeVis`), **not** hidden scene nodes. Remove only redundant collinear interior curve knots on hidden edges, never real corners, branches, or endpoints. Preserve the unmodified source geometry.
- The source-order UI is not a mesh trimming tool. Direct mesh result remains experimental/future.
