\\\# Functions Layer

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

\\\#\\\# Purpose

Functions are the lowest reusable MaxScript layer.

A Function performs one small, clearly defined action. It receives explicit input, performs that action, and returns a result that the caller can evaluate.


\#\# Canonical core library — mandatory reuse

`Functions/` is the shared low-level core for every MaxScript development that uses this agent system.

\- Treat verified Functions here as canonical source-of-truth implementations to inspect and fork into downstream tool-local source; do not make downstream tools load them from the central Codebase at runtime.  
\- Before adding any atomic helper in a project, Operation, Tool, or Toolset, inspect this Functions layer for an existing equivalent first.  
\- If a matching Function exists, use it as the source implementation and fork the required behavior into the downstream tool/project rather than reimplementing it from scratch or loading the central Codebase at runtime.  
\- Do not invent an unrelated project-local reimplementation when a verified Function already exists. Place the deliberate fork in the tool/project module that owns that behavior.  
\- The canonical Function remains the upstream reference. Downstream tools own their forked copy and may use thin adapters or project-specific changes without creating a runtime link back to this folder.  
\- Keep Function APIs project-independent and UI-independent so the same implementation can work across unrelated MaxScript developments.  
\- New generally reusable atomic behavior belongs in this layer instead of being permanently buried in an Operation, Tool, or Toolset.  
\- This layer is READ-ONLY by default under the parent protected-Codebase rule. Creating or changing a shared Function requires explicit permission in the current user prompt.  
\- A downstream bug or missing feature does not by itself authorize editing this layer; without explicit permission, use it read-only and report the needed shared change.

\#\# Reuse preflight

Before implementing low-level behavior, the active chat must answer internally:

```text
SHARED FUNCTION REUSE CHECK

Required atomic behavior: <behavior>
Relevant Functions area inspected: YES
Existing canonical Function found: YES | NO
If YES: canonical Function forked into tool/project source: YES
If NO and reusable across projects: shared Functions write explicitly authorized: YES | NO
```

If an existing canonical Function is available, independently reinventing the behavior is a design error. A deliberate per-tool source fork is the required reuse mechanism.

\\\#\\\# Responsibilities

\\- Implement one atomic behavior.    
\\- Keep inputs and outputs explicit.    
\\- Return a useful result such as a value, object, collection, \\\`true\\\`, or \\\`false\\\`.    
\\- Be reusable by Operations and other Functions where appropriate.    
\\- Keep geometry and data manipulation independent from UI.

\\\#\\\# Boundaries

Functions must not:

\\- Own a rollout, dialog, button, or other UI.    
\\- Orchestrate a complete user workflow.    
\\- Depend on a specific Tool or Toolset.    
\\- Duplicate behavior already provided by an existing verified Function.

\\\#\\\# Composition

The hierarchy is:

\\\`Functions \\-\\\> Operations \\-\\\> Tools \\-\\\> Toolsets\\\`

Functions are called by Operations. They should remain useful outside any single Operation.

\\\#\\\# Example

Separate atomic Functions may:

\\- find vertices,    
\\- select vertices,    
\\- move a vertex,    
\\- weld a vertex.

A sequence such as select \\+ move \\+ weld belongs in an Operation, not in one Function.

\\\#\\\# MaxScript rules

Follow the parent MaxScript \\\`AGENTS.md\\\` and all referenced shared MaxScript rules.

\#\# Design file

\- Keep feature design for the Functions layer in \`design.md\` in this folder.  
\- Read \`design.md\` before implementing or changing a Function whose design is documented there.  
\- Update \`design.md\` when the agreed Function behavior, contract, dependencies, or constraints change.  
\- Keep design decisions in \`design.md\`; keep implementation history, debugging notes, and TODO work in their appropriate files.  
