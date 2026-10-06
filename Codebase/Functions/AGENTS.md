\\\# Functions Layer

\\\#\\\# Purpose

Functions are the lowest reusable MaxScript layer.

A Function performs one small, clearly defined action. It receives explicit input, performs that action, and returns a result that the caller can evaluate.

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
