\\\# Functions Layer

\\\#\\\# Purpose

Functions are the lowest reusable MaxScript layer.

A Function performs one small, clearly defined action. It receives explicit input, performs that action, and returns a result that the caller can evaluate.


\#\# Canonical core library — mandatory reuse

`Codebase/Functions/` is the shared low-level core for every MaxScript development that uses this agent system.

\- Treat verified Functions here as canonical source-of-truth implementations, not snippets or examples to reproduce elsewhere.  
\- Before adding any atomic helper in a project, Operation, Tool, or Toolset, inspect this Functions layer for an existing equivalent first.  
\- If a matching Function exists, callers must reuse it rather than copy, rename, rewrite, or locally fork its implementation.  
\- Do not create project-local `Helpers`, `Utils`, `Common`, or similar support scripts merely to duplicate a Function that already exists here.  
\- Downstream code may use thin adapters for input/output shape only; the actual atomic behavior must remain owned by the canonical Function.  
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
If YES: canonical Function reused: YES
If NO and reusable across projects: shared Functions write explicitly authorized: YES | NO
```

If an existing canonical Function is available, creating a duplicate implementation is a design error.

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
