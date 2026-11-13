\\\\\\\# Toolsets Layer

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

\\\\\\\#\\\\\\\# Purpose

A Toolset is the highest layer of this hierarchy.

It groups related Tools into one larger dialog, utility, or coherent MaxScript system.

\\\\\\\#\\\\\\\# Required Toolset package

Every Toolset directory has exactly three current source files in its root:

\\\\- \\\\\\\`\\\\\\\<ToolsetName\\\\\\\>.ms\\\\\\\` — main entry file. This is the file executed to run the Toolset. It loads required **toolset-local/forked** Function, Operation, Tool backend/frontend, and Toolset backend/frontend dependencies, then opens the Toolset. A downstream Toolset must never load those dependencies from the central Codebase path at runtime.      
\\\\- \\\\\\\`\\\\\\\<ToolsetName\\\\\\\>-UI.ms\\\\\\\` — frontend only. It owns the main Toolset dialog or top-level container and composes Tool rollouts. It must not contain feature-processing logic or act as the package loader.      
\\\\- \\\\\\\`\\\\\\\<ToolsetName\\\\\\\>-FN.ms\\\\\\\` — backend only. It contains Toolset-specific non-UI coordination logic and shared Toolset state. It must not create dialogs or reference rollout controls.

The main entry file is the only Toolset file that should auto-execute the Toolset.

The UI and FN files must remain loadable independently without automatically opening the Toolset.

When embedding a Tool, a Toolset must use the Tool's project-local fork and load that Tool's \\\\\\\`-FN.ms\\\\\\\` and \\\\\\\`-UI.ms\\\\\\\` files directly. Do not load the Tool's main \\\\\\\`.ms\\\\\\\` entry file because that file executes the standalone Tool.

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
