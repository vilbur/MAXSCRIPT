\# Functions Design

Use this file as the source of truth for feature design at the Functions layer.

Record the intended behavior of reusable atomic Functions here before or while implementing them. Keep design separate from code history, debugging notes, and TODO queues.

\#\# What belongs here

For each Function feature, record only the design information needed to implement and maintain it:

\- purpose;  
\- inputs;  
\- output or return value;  
\- expected behavior;  
\- supported object or data types;  
\- dependencies on other shared Functions, if any;  
\- important edge cases or constraints;  
\- design decisions that other layers depend on.

\#\# Feature design template

\#\#\# \<Function feature name\>

\*\*Purpose:\*\*    
\<What single atomic behavior this Function provides.\>

\*\*Inputs:\*\*    
\<Required parameters and accepted values.\>

\*\*Output:\*\*    
\<Return value or result contract.\>

\*\*Behavior:\*\*    
\<Required behavior and important rules.\>

\*\*Dependencies:\*\*    
\<Other Functions or shared utilities, if any.\>

\*\*Edge cases / constraints:\*\*    
\<Important limits, unsupported cases, or failure behavior.\>

\#\# Feature designs

Add approved Function designs below this heading.  

## Epoly shared functions — first development design (0.01)

**Purpose:** Reusable elementary operations on an existing `Edit_Poly` modifier. Function groups: selection (5), vertices (9), edges (6), faces (5), topology (3), create/cut (6).

**Inputs:** Explicit scene node, exact modifier instance, component IDs/BitArrays, operation mode, and numeric parameters in scene system units; no hidden viewport-selection state.

**Output:** A documented boolean for actions, geometry ID/BitArray/Array for queries or construction, or `undefined` when a query cannot resolve its object context. Native unexpected failures remain visible.

**Behavior:** Keep one caller-owned modifier context across related calls. Batch component selection and native operations. Commit at logical operation boundaries, not after each component. Allow existing low-level edit operations to be composed without changing the base mesh underneath the modifier. Cutting supports creating vertex, dividing edge/face, connecting existing vertices, cutting vertex-to-edge and edge-to-edge.

**Dependencies:** `Codebase/Functions/Epoly/EpolyCore.ms`, then the relevant themed Epoly modules. No dependency on Operations or Tools.

**Constraints:** IDs cached before topology-changing operations may be invalid afterward; do not collapse dead topology mid compound operation. `targetWeldBatch` requires disjoint source-target records with stable IDs. `getBorderLoops` v0.01 returns connected boundary edge sets (not ordered vertex rings). `Functions/Epoly/test/test.ms` owns the one testing UI and never becomes a production dependency.

**Current status:** Development baseline only; static delimiter checks performed. Execution inside 3ds Max still needs user confirmation. Further details in `Codebase/Functions/Epoly/README.md`.
