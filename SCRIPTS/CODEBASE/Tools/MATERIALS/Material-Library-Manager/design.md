# Material-Library-Manager design

## Intent
Batch-import a folder-organized MaterialX library into 3ds Max and provide managed preview objects.
Preserve categories as separate native material libraries so the library remains usable after import.

## Confirmed requirements
- Tool location: Codebase/Tools/MATERIALS/Material-Library-Manager/.
- Main filename: Material-Library-Manager.ms.
- Target: 3ds Max 2026, primarily Arnold; compatibility is desired but must be verified.
- Input categories are optional: accept .mtlx files directly at the root, root / material folder / .mtlx, and root / category / material folder / .mtlx, with associated textures.
- Do not require or manufacture an extra Materials input directory.
- Give both imported materials and their preview objects meaningful names.
- Select the root using Browse in the UI.
- Keep category organization in output material libraries.
- Create an object for each imported material and assign the material to that object.
- Offer Sphere, Teapot, Knot, Custom, and Placeholder preview types.
- Use geometry instances for previews.
- Manage preview objects through the UI.
- Include project-local AGENTS.md and design.md.

## Approach and rationale
Use MAXScript with Autodesk's MaterialX importer, category-oriented .mat output, and managed geometry instances.
This follows the requested Import MaterialX utility workflow and avoids manually rebuilding shader graphs.
Arnold-specific MAXToAOps.ImportMaterials is a separate route and must not be silently used for general AMD MaterialX documents.
Retain external textures at their source paths; a .mat library does not package those texture assets.
Full renderer/version equivalence is not promised.

## Package responsibilities
Material-Library-Manager.ms loads documented downward dependencies and its sibling FN/UI files, then opens the dialog.
Material-Library-Manager-FN.ms owns discovery, import coordination, source identities, category aggregation, library saving, and managed scene-node actions.
Material-Library-Manager-UI.ms owns controls, user choices, status presentation, and shared UI-state integration.
Shared Functions/Operations/UI helpers remain canonical and read-only unless separately authorized.

## UI and workflow
1. Browse for root and output folders.
2. Scan root recursively and display categories and discovered .mtlx files.
3. Select categories/materials to process.
4. Choose preview type, size, spacing, and column count; pick a scene template for Custom.
5. Import chosen entries, retaining every material returned by a document.
6. Create or update corresponding preview instances; arrange by category in a grid.
7. Save one .mat library per category.
8. Select, hide/show, replace preview geometry, or remove managed previews without deleting unrelated nodes.

## Proposed defaults — implementation choices, not additional user answers
- Output goes to a selectable folder, initially the chosen material root itself (latest confirmed requirement).
- Each category has a separate scene layer; nested categories retain relative-path identity.
- Preview spacing is center-to-center; size and spacing show scene units.
- Sphere is the initial preview choice.
- Reimport updates the existing source/material record rather than appending a duplicate.
- Geometry replacement preserves material assignments and transforms.
- Save refuses accidental overwriting unless overwrite is explicitly enabled.
- Placeholder uses a renderable box as a labeled proposed default, allowing a visible material assignment; its final intended shape remains open.

## Instance contract
Preview nodes of a selected template share object geometry.
Material assignment is per node and must remain independent across previews.
Changing shared template geometry should propagate; changing a single preview material should not.
Custom uses instances of a picked scene node without changing that source node's material or transform.
No matching or ownership decisions use approximate world positions.

## Persistence and ownership
The unversioned Material-Library-Manager.ini beside the entry script stores paths, UI state, preview options, and dialog geometry.
Scene metadata stores source document path, category path, material identity, and the tool ownership marker.
Source identity must handle multiple materials in one document and identical material names in separate categories.
Reopening the tool rebuilds managed-node state from scene metadata.

## Errors and partial results
Missing importer: stop before scene creation and report the missing dependency.
Missing/unreadable input or textures: identify the source and report the original diagnostic.
A document failure must remain visible; report imported/failed counts separately.
Do not silently save a partial category library as complete.
Library saving is not undoable; scene preview actions use named undo blocks.

## API verification and implementation status
First implementation: v0.01, 27 October 2026.
The exact general API `MtlXIOUtil.importMtlx absolute_file_path` was verified in Autodesk USD 0.16.2's shipped MaterialX material script, in its importMaterial implementation.
The importer returns a collection of materials; the backend retains all returned materials, rejects empty results, and compares directly defined surfacematerial counts.
All three production source files and the staged test workflow now exist.
Focused static checks and a separate source review were performed. No 3ds Max execution was available; runtime compatibility remains unverified.
Source reference: https://github.com/Autodesk/3dsmax-usd/releases/tag/v0.16.2 .

## Implemented first-version choices
- MAT outputs and HTML default directly to the input root, with optional output Browse.
- Root library uses the root folder name; category filenames use `Category--` plus URL-encoded relative category paths.
- Category sections in HTML collapse independently and show their full relative ancestry in the label; all assets use relative URI links where the chosen output permits them.
- Scan follows normal directories, skips directory reparse points, and recognizes exact material/document preview filenames plus preview/thumbnail/render patterns.
- Scene records require a committed completeness marker, unique material identities, matching counts and valid material assignments before recovering Imported state.
- Custom sources must be unmanaged geometry nodes; replacing previews cannot destroy the picked source. Replacement preserves category layer membership.
- Preview management requires selected documents; Arrange intentionally targets the whole current root.
- Custom picking is session-only. Other visible choices and dialog state persist beside the main entry.
- Rendered appearance, shared-host registered-window position restoration, docking and actual Android image access remain runtime checks.

## Test plan
A single tests/Material-Library-Manager-Test.ms will use numbered setup, execution, and assertion stages.
Cover two categories, repeated names, a multi-material document, missing importer, invalid document, and a missing texture.
Verify category library round trips, geometry instancing with distinct materials, repeat-import identity, and scope of preview removal.
Leave generated test objects available for inspection through named undo history.
Static validation must be followed by a real 3ds Max 2026 test before claiming runtime compatibility.

## Folder interpretation and naming
A folder containing .mtlx files is a material folder. Preserve category ancestry above that folder relative to the selected root.
Entries with no category use the selected root's name for the output library; do not fabricate a Materials category.
A mixed tree may contain root-level materials and categorized materials together.
Use the material folder name as the display name, or the .mtlx basename for root-level documents.
For multiple materials in one document, append the imported material name; resolve remaining collisions deterministically.
Source paths and material identities remain independent of editable display names.
The user confirmed the Tools/MATERIALS installation category independently from the browsed input material root; the tool stays in its canonical destination.

