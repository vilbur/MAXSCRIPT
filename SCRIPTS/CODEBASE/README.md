# MAXScript Codebase

## Main categories

- [Tools](Tools/) — Standalone tools and user-facing interfaces organized by workflow.
- [Toolsets](Toolsets/) — Related tools combined into larger coordinated workflows.
- [Operations](Operations/) — Reusable procedures that compose shared functions.
- [Functions](Functions/) — Low-level reusable MaxScript function libraries.
- [UI](UI/) — Shared UI framework, controls, and layout templates.
- [Globals](Globals/) — Shared global services, settings, and editors.

## Tool categories

### SPLINE

- [Spline Editor](Tools/SPLINE/Spline-Editor/Spline-Editor.ms) — Edits Editable Spline visibility, knots, segments, attachment, division, and material IDs.

### MODIFIER-STACK

- [Modifier Stack Live](Tools/MODIFIER-STACK/Modifier-Stack-Live/Modifier-Stack-Live.ms) — Displays and controls the selected object’s modifier stack in a live remote interface.
- [Modifier Sets](Tools/MODIFIER-STACK/Modifier-Sets/Modifier-Sets.ms) — Organizes modifiers into named sets for coordinated stack control.
- [Modifier Manager](Tools/MODIFIER-STACK/Modifier-Manager/Modifier-Manager.ms) — Manages modifier stacks, presets, and slice-related workflows.

### MODIFIERS

- [World Symmetry](Tools/MODIFIERS/World-Symmetry/World-Symmetry-Startup.ms) — Provides world-space symmetry alignment and startup integration.

### DEV

- [Print Debug](Tools/DEV/Print-Debug/Print-Debug.ms) — Prints object topology, modifier properties, and rollout or control geometry for debugging.
- [Preset Manager](Tools/DEV/Preset-Manager/Preset-Manager.ms) — Creates, loads, renames, and removes reusable named presets.
- [EPoly Stack Test](Tools/DEV/EPoly-Stack-Test/EPoly-Stack-Test.ms) — Diagnoses Edit Poly operations performed in separate modifiers in the stack.

### LAYERS

- [Object Layer Manager](Tools/LAYERS/Object-Layer-Manager/Object-Layer-Manager.ms) — Provides compact selection and layer tools for large imported architectural scenes.

### SELECTION

- [Selection History](Tools/SELECTION/Selection-History/Selection-History.ms) — Records scene selections and restores earlier selection states.
- [Select By Props](Tools/SELECTION/Select-By-Props/Select-By-Props_0.003.ms) — Selects scene objects by matching object properties.

### GEOMETRY

- [Surface Intersections](Tools/GEOMETRY/Surface-Intersections/Surface-Intersections.ms) — Builds and updates trimmed intersection results from grouped surface sources.
- [Geometry Diagnostics](Tools/GEOMETRY/Geometry-Diagnostics/Geometry-Diagnostics.ms) — Finds, selects, and reports geometry and topology problems.
- [Rebuild Mesh](Tools/GEOMETRY/Rebuild-Mesh/Rebuild-Mesh.ms) — Rebuilds and cleans problematic low-poly mesh topology.
- [Wall Thickness](Tools/GEOMETRY/Wall-Thickness/Wall-Thickness.ms) — Measures and manages wall thickness on architectural geometry.

### EPOLY

- [Straight Edge Fixer](Tools/EPOLY/Edge%20Tools/Straight-Edge-Fixer/Straight-Edge-Fixer.ms) — Straightens selected Editable Poly edge chains.
- [Degenerate Face Selector](Tools/EPOLY/Face%20Tools/Degenerate-Face-Selector/Degenerate-Face-Selector.ms) — Finds and selects degenerate polygon faces.
- [Loop Cleaner](Tools/EPOLY/Loop%20Tools/Loop-Cleaner/Loop-Cleaner.ms) — Detects and cleans redundant topology loops.
- [Missing Loop Rebuilder](Tools/EPOLY/Loop%20Tools/Missing-Loop-Rebuilder/Missing-Loop-Rebuilder.ms) — Reconstructs missing edge loops in Editable Poly topology.
- [Redundant Ring Collapser](Tools/EPOLY/Loop%20Tools/Redundant-Ring-Collapser/Redundant-Ring-Collapser.ms) — Finds and collapses redundant edge rings.
- [EPoly Weld Test](Tools/EPOLY/Vertex%20Tools/EPoly-Weld-Test/epoly-weld-test.ms) — Tests Editable Poly vertex-welding behavior.
- [Vertex Cleaner](Tools/EPOLY/Vertex%20Tools/Vertex-Cleaner/Vertex-Cleaner.ms) — Finds and repairs problematic or duplicate vertices.
- [Vertex Welder](Tools/EPOLY/Vertex%20Tools/Vertex-Welder/Vertex-Welder.ms) — Welds border and element vertices using configurable matching modes.

### SCENE

- [Blueprint Manager](Tools/SCENE/Blueprint-Manager/Blueprint-Manager.ms) — Manages viewport blueprint references, views, offsets, and scaling.
- [Scene Asset Manager](Tools/SCENE/Scene-Asset-Manager/Scene-Asset-Manager.ms) — Manages asset-related data and operations in the current scene.
- [GIF Recorder](Tools/SCENE/Gif-Recorder/Gif-Recorder_0.002.ms) — Records 3ds Max viewport output as an animated GIF sequence.
- [Scene Model Manager](Tools/SCENE/Scene-Model-Manager/Scene-Model-Manager.ms) — Organizes model nodes and related scene-management workflows.
- [Scene Offset Tool](Tools/SCENE/Scene-Offset-Tool/Scene-Offset-Tool_0.13.ms) — Applies controlled scene offsets while preserving scene relationships.

### MATERIALS

- [Material Library Manager](Tools/MATERIALS/Material-Library-Manager/Material-Library-Manager.ms) — Imports MaterialX folders, builds previews, saves MAT libraries, and generates an HTML catalog.
- [Material ID Manager](Tools/MATERIALS/Material-ID-Manager/Material-ID-Manager.ms) — Assigns, selects, stores, and manages material IDs.

### DUMP

- [DUMP](Tools/DUMP/DUMP.ms) — Provides reusable diagnostic dumps for objects, modifiers, and MaxScript UI state.

### Deprecated

- [Modifier Set Stack](Tools/Modifier-Set-Stack-DEPRECATED/Modifier-Set-Stack.ms) — Preserves the deprecated combined modifier-set and remote-stack prototype.
- [Modifier Sets](Tools/MATERIALS/Modifier-Sets%20DEPRECATED/Modifier-Sets.ms) — Preserves the deprecated material-area Modifier Sets implementation.
