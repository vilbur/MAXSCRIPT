\\\# Operations Layer


\\\#\\\# Purpose


Operations compose reusable Functions into one complete logical procedure.


An Operation controls sequence, branching, validation, and error handling across multiple Functions, but does not own the user interface.


\\\#\\\# Responsibilities


\\- Call one or more Functions in a defined order.    
\\- Pass outputs from one Function into the next.    
\\- Validate intermediate results.    
\\- Stop or fail cleanly when a required Function fails.    
\\- Return one clear result to the caller.    
\\- Keep workflow logic reusable by multiple Tools.


\\\#\\\# Boundaries


Operations must not:


\\- Implement UI controls, rollouts, or dialogs.    
\\- Reimplement atomic behavior that belongs in Functions.    
\\- Depend on one specific Toolset.    
\\- Hide unrelated workflows inside one oversized procedure.


\\\#\\\# Composition


The hierarchy is:


\\\`Functions \\-\\\> Operations \\-\\\> Tools \\-\\\> Toolsets\\\`


Operations call Functions. Tools call Operations.


\\\#\\\# Example


An Operation named \\\`selectMoveAndWeld\\\` may:


1\\. call a Function that resolves the target vertices,    
2\\. call a Function that selects them,    
3\\. call a Function that moves them,    
4\\. call a Function that welds them,    
5\\. return success or failure.


The individual select, move, and weld behaviors remain separate Functions.


\\\#\\\# MaxScript rules


Follow the parent MaxScript \\\`AGENTS.md\\\` and all referenced shared MaxScript rules.


\#\# Design file


\- Keep feature design for the Operations layer in \`design.md\` in this folder.  
\- Read \`design.md\` before implementing or changing an Operation whose design is documented there.  
\- Update \`design.md\` when the agreed Operation workflow, contract, Function dependencies, or constraints change.  
\- Keep design decisions in \`design.md\`; keep implementation history, debugging notes, and TODO work in their appropriate files.  




## Directory organization


Canonical Operation packages live under `Codebase/Operations/`.


Operations may be grouped under domain/category folders when that improves reuse and discovery. The current shared Editable Poly operation domain lives under `Codebase/Operations/Epoly/`.


Nested folders inside an Operation domain are organizational only. They do not create new architecture layers and they do not permit upward dependencies.


Place new reusable operation-level Editable Poly behavior under the appropriate `Codebase/Operations/Epoly/` area instead of the legacy root `Epoly/` location.