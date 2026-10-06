\\\\\\\# Toolsets Layer

\\\\\\\#\\\\\\\# Purpose

A Toolset is the highest layer of this hierarchy.

It groups related Tools into one larger dialog, utility, or coherent MaxScript system.

\\\\\\\#\\\\\\\# Required Toolset package

Every Toolset directory has exactly three current source files in its root:

\\\\- \\\\\\\`\\\\\\\<ToolsetName\\\\\\\>.ms\\\\\\\` — main entry file. This is the file executed to run the Toolset. It loads required Function, Operation, Tool backend/frontend, and Toolset backend/frontend dependencies, then opens the Toolset.      
\\\\- \\\\\\\`\\\\\\\<ToolsetName\\\\\\\>-UI.ms\\\\\\\` — frontend only. It owns the main Toolset dialog or top-level container and composes Tool rollouts. It must not contain feature-processing logic or act as the package loader.      
\\\\- \\\\\\\`\\\\\\\<ToolsetName\\\\\\\>-FN.ms\\\\\\\` — backend only. It contains Toolset-specific non-UI coordination logic and shared Toolset state. It must not create dialogs or reference rollout controls.

The main entry file is the only Toolset file that should auto-execute the Toolset.

The UI and FN files must remain loadable independently without automatically opening the Toolset.

When embedding a Tool, a Toolset must load that Tool's \\\\\\\`-FN.ms\\\\\\\` and \\\\\\\`-UI.ms\\\\\\\` files directly. Do not load the Tool's main \\\\\\\`.ms\\\\\\\` entry file because that file executes the standalone Tool.

Keep previous versioned source files in the Toolset's \\\\\\\`\\\\\\\_Versions/\\\\\\\` folder so the Toolset directory root contains only the three current source files plus support folders.

\\\\\\\#\\\\\\\# Responsibilities

\\\\- Compose related Tools into one larger user-facing system.      
\\\\- Own the main dialog or top-level container when one exists.      
\\\\- Coordinate shared state that genuinely belongs across multiple Tools.      
\\\\- Control Tool loading, visibility, ordering, and high-level integration.      
\\\\- Keep the overall system organized without absorbing lower-layer responsibilities.

\\\\\\\#\\\\\\\# Boundaries

Toolsets must not:

\\\\- Reimplement atomic behavior from Functions.      
\\\\- Reimplement workflow logic from Operations.      
\\\\- Move Tool-specific UI behavior into the top-level container without a clear cross-tool reason.      
\\\\- Create hidden dependencies between unrelated Tools.

\\\\\\\#\\\\\\\# Composition

The hierarchy is:

\\\\\\\`Functions \\\\-\\\\\\\> Operations \\\\-\\\\\\\> Tools \\\\-\\\\\\\> Toolsets\\\\\\\`

Toolsets contain or coordinate Tools. Tools call Operations. Operations call Functions.

\\\\\\\#\\\\\\\# Design principle

Dependencies should normally point downward through the hierarchy. Lower layers must remain usable without knowledge of higher layers.

\\\\\\\#\\\\\\\# MaxScript rules

Follow the parent MaxScript \\\\\\\`AGENTS.md\\\\\\\`, \\\\\\\`maxscript-project-architecture.md\\\\\\\`, \\\\\\\`maxscript-ui-rules.md\\\\\\\` when applicable, and all other relevant shared MaxScript rules.

\\\#\\\# Design file

\\- Keep feature design for the Toolsets layer in \\\`design.md\\\` in this folder.    
\\- Read \\\`design.md\\\` before implementing or changing a Toolset whose design is documented there.    
\\- Update \\\`design.md\\\` when the agreed Toolset composition, top-level UI, shared state, Tool ordering, or integration constraints change.    
\\- Keep design decisions in \\\`design.md\\\`; keep implementation history, debugging notes, and TODO work in their appropriate files.    
