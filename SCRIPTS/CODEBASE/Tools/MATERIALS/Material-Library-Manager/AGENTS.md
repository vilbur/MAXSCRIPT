# Material-Library-Manager

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

## Scope and source of truth
Canonical location: Codebase/Tools/MATERIALS/Material-Library-Manager/.
Use the latest Google Drive files. Replace existing files by their existing IDs; never create duplicate copies.
Follow the parent MaxScript AGENTS.md and Tools/AGENTS.md and the shared syntax, protected-identifiers, UI, architecture, unit-precision, and DUMP rules.
Authorization covers this tool only, not edits to shared Functions, Operations, or UI templates.

## Package contract
- Material-Library-Manager.ms: dependency loader and only automatic entry point. It may load only dependencies shipped/forked inside the tool project; it must not runtime-load the central Codebase.
- Material-Library-Manager-FN.ms: backend coordination, no rollout references.
- Material-Library-Manager-UI.ms: frontend controls and thin callbacks.
- tests/Material-Library-Manager-Test.ms: one executable staged test workflow.
- design.md: intended behavior and explicitly unresolved decisions.
- README.md: installation, dependencies, operation, and current limitations.
Do not claim planned files or features already exist.

## Versions and conventions
Each code file stores its internal version and shared project version.
Increment each modified file by 0.01 and the project once per change set.
Update the global project version only when the loaded value is higher.
Show the global version in the UI title. Unchanged files retain their values.
Use full function declarations, camelCase function names, snake_case variables, opening parentheses on new lines, struct names ending _v, and on create do at the end.
Comment every function. Do not shadow native identifiers or invent APIs.

## Import and scene safety
Target 3ds Max 2026 with Arnold first. Other versions/renderers require capability checks, not assumed compatibility.
Use the verified Autodesk MaterialX import API for general MaterialX documents.
Do not silently substitute Arnold-specific material import for general MaterialX import.
Preserve source .mtlx files, texture folders, unrelated scene nodes, and existing material libraries.
Track tool-owned nodes by source identity and tool metadata, not by name alone.
Preview nodes share geometry through instancing but retain independently assigned materials.
Repeat import must not create duplicate managed previews.
Scope selection, replacement, hiding, and removal to tool-owned nodes.
Never report an empty or partially failed import as successful.
Keep runtime diagnostic files in logs/ and include the source file and original exception.

## UI
Reuse the canonical Default UI baseline and shared helpers.
Provide a root-folder Browse control, category/material listing, output folder, import/library actions, and preview management.
Preview choices: Sphere, Teapot, Knot, Custom, Placeholder.
Custom picks a scene object. Placeholder is a renderable box in v0.01 and remains labeled as a proposed default.
Persist UI state and dialog geometry in an unversioned INI beside the entry script.
Keep tooltips concise with uppercase event labels and blank lines between events.

## Verification
Static review: delimiters, identifiers, syntax, result contracts, dependency paths, and false-success branches.
Runtime tests: discovery, multi-material documents, missing textures/plugin, category output, geometry instances with independent materials, repeat import, and managed-node scope.
Use numbered test stages with explicit execution queue and named undo entries.
Report whether tests were actually run; never equate static inspection with a Max runtime test.

## Folder discovery and naming
Input category folders are optional. Accept .mtlx files at the selected root, material folders directly below it, and categorized material folders.
Do not require or invent an extra Materials input folder.
Name imported materials and preview nodes from the material folder; disambiguate multiple document materials and collisions deterministically.
Keep stable source identity separately from display names.
The tool installation category is Tools/MATERIALS, confirmed separately from the browsed material library root. Do not move the tool unless explicitly requested.


## First implementation baseline
Version 0.01 contains the canonical entry/FN/UI files and tests. General API `MtlXIOUtil.importMtlx path` is verified from Autodesk shipped source; Max runtime is unverified. Output defaults directly to the selected material root. Keep known limitations and actual test status in README.md.
