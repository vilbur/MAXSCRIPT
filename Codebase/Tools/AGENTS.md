\\\\\\\# Tools Layer

\\\\\\\#\\\\\\\# Purpose

A Tool is one user-facing functional unit built from Operations.

A Tool normally corresponds to one rollout or one clearly bounded UI section with a single coherent purpose.

\\\\\\\#\\\\\\\# Required Tool package

Every Tool directory has exactly three current source files in its root:

\\\\- \\\\\\\`\\\\\\\<ToolName\\\\\\\>.ms\\\\\\\` — main entry file. This is the file executed to run the Tool. It loads required dependencies, then loads the Tool backend and frontend, and finally opens or executes the Tool.      
\\\\- \\\\\\\`\\\\\\\<ToolName\\\\\\\>-UI.ms\\\\\\\` — frontend only. It defines rollouts, dialogs, controls, callbacks, and UI presentation. It must not contain feature-processing logic or act as the package loader.      
\\\\- \\\\\\\`\\\\\\\<ToolName\\\\\\\>-FN.ms\\\\\\\` — backend only. It contains Tool-specific non-UI functions and coordination logic. It may call Operations, but it must not reference rollout controls or create dialogs.

The main entry file is the only Tool file that should auto-execute the Tool.

The UI and FN files must remain loadable independently without automatically opening the Tool.

Keep previous versioned source files in the Tool's \\\\\\\`\\\\\\\_Versions/\\\\\\\` folder so the Tool directory root contains only the three current source files plus support folders.

\\\\\\\#\\\\\\\# Responsibilities

\\\\- Expose Operations through UI controls when UI is required.        
\\\\- Keep one clear functional purpose.        
\\\\- Translate UI state and user input into Operation parameters.        
\\\\- Present Operation results, status, and errors to the user.        
\\\\- Reuse existing Operations instead of duplicating workflow logic.

\\\\\\\#\\\\\\\# Boundaries

Tools must not:

\\\\- Reimplement atomic geometry or data logic from Functions.        
\\\\- Reimplement workflow logic already owned by Operations.        
\\\\- Become a container for unrelated tools.        
\\\\- Own application-wide orchestration that belongs in a Toolset.
\\- Search parent directories for Toolset, manager, orchestration, or application files.
\\- Load or require a parent Toolset/manager in order to run.
\\- Know the name, filename, folder layout, or implementation details of the Toolset that may host it.
\\- Call upward into Toolset APIs or depend on Toolset globals as part of its normal operation.

## No upward dependencies

Dependency direction is strictly downward. A Tool may depend on its own package files, Operations, Functions, and explicitly shared lower-level utilities. It must not depend on any parent Toolset or orchestration layer.

A Tool must remain runnable and testable standalone when its documented downward dependencies are available.

Forbidden patterns include:

```text
Tool -> search parent folders -> find Toolset manager -> fileIn manager
Tool -> require parent Toolset global
Tool -> assume a fixed parent folder name
Tool -> call parent orchestration API
```

Correct ownership:

```text
Toolset / parent
    -> discovers, loads, configures, and embeds Tool

Tool
    -> calls Operations / Functions / shared lower-level utilities
```

If a Tool needs configuration or a service from above, the parent must pass that dependency downward through an explicit parameter, callback, interface, or preloaded shared service. The Tool must not discover the parent by walking upward through the filesystem.

\\\\\\\#\\\\\\\# Composition

The hierarchy is:

\\\\\\\`Functions \\\\-\\\\\\\> Operations \\\\-\\\\\\\> Tools \\\\-\\\\\\\> Toolsets\\\\\\\`

A Tool calls Operations. A Toolset groups related Tools.

\\\\\\\#\\\\\\\# UI rule

UI callback code should stay thin. A button should mainly collect input, call the appropriate Operation, and present the result.

\\\\\\\#\\\\\\\# MaxScript rules

Follow the parent MaxScript \\\\\\\`AGENTS.md\\\\\\\`, \\\\\\\`maxscript-ui-rules.md\\\\\\\` for UI work, and all other relevant shared MaxScript rules.

\\\#\\\# Design file

\\- Keep feature design for the Tools layer in \\\`design.md\\\` in this folder.    
\\- Read \\\`design.md\\\` before implementing or changing a Tool whose design is documented there.    
\\- Update \\\`design.md\\\` when the agreed Tool behavior, backend/frontend responsibilities, UI interactions, state, or constraints change.    
\\- Keep design decisions in \\\`design.md\\\`; keep implementation history, debugging notes, and TODO work in their appropriate files.    
