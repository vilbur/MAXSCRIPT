# Surface-Intersections doc/ — AGENTS.md

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

This file supplements `../AGENTS.md` and the shared MaxScript project/Tools rules. This folder holds human-readable guides and user workflows, not source code.

- Read the latest canonical `../Surface-Intersections.ms`, `../design.md`, and the relevant test script before documenting actual behavior. A guide may lag behind code; never treat an older guide as the version authority.
- Distinguish **implemented**, **runtime-tested**, **observed failure**, **theoretical**, and **planned** features. In particular, currently supported curve extraction does not imply direct trimmed mesh generation or a successful native Surface modifier output.
- Label all scene-resetting test commands with a warning: `resetMaxFile #noPrompt` destroys unsaved scene changes.
- Document the `#live`, `#manual`, `#freeze`, `refresh()` and `stop()` workflows accurately. The result node identity may persist after a refresh, but knots and segments can change; links are session-local.
- Show where each diagnostic scenario saves its output under `../test/logs/`, and do not paste fictional PASS results as observed output.
- Preserve reproducible steps, version provenance, supported Max version notes, example inputs, numeric units/precision, limitations, and actual error messages. Prefer short operational guidance to speculative promises.
- For documentation changes, keep `design.md` as the authoritative project-level design/status document; the guide should focus on user operation. Do not change code versions merely for document edits.
