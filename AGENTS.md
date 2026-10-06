\\\\\\\#\\\\\\\# REQUIRED BEFORE ANY MAXSCRIPT CHANGE

These rules are mandatory for every MaxScript project change and do not need to be repeated by the user in each chat.

## CRITICAL SYNTAX AND CODE SAFETY

- Before writing or editing MaxScript code, follow `maxscript-syntax-safety.md`.
- Use `function`, never the `fn` alias.
- Use `if ... then`; never write `if ... do`. Legitimate `for ... do`, `while ... do`, and `on ... do` syntax remains valid.
- Do not call undefined helpers, invented native methods, or unverified MAXScript/3ds Max APIs.
- Do not convert a failed topology/selection/native read into valid-looking empty data and continue as if the read succeeded.
- Do not report success after a failed or partially completed destructive operation.
- Before delivery, statically validate changed code for balanced delimiters, protected identifiers, prohibited syntax, critical catches, return-contract consistency, and fake-success paths.

## CRITICAL UNIT AND NUMERIC PRECISION SAFETY

- Before writing or editing unit-, geometry-, distance-, coordinate-, threshold-, or tolerance-sensitive code, follow `maxscript-unit-precision.md`.
- Never introduce hidden rounding, truncation, quantization, snapping, clamping, epsilon values, or a private "float precision tolerance" into backend calculations.
- Exact comparisons must remain exact unless the feature specification explicitly defines a tolerance.
- Do not convert very small non-zero values to zero unless explicitly required.
- A tolerance must be named, documented, and come from an explicit feature/user/project contract; do not invent one to make an algorithm behave.
- UI display rounding is allowed for presentation only; it must not alter the stored/computed backend value.
- Before delivery, inspect changed unit/geometry code for hidden `round`, `floor`, `ceil`, Float-to-Integer conversion, decimal truncation, and hard-coded epsilon/tolerance constants.

## CRITICAL IDENTIFIER SAFETY

- Never use MAXScript reserved keywords or protected built-in identifiers as user-defined names.
- `modifier` is explicitly forbidden as a variable name, function parameter, function name, struct member, rollout-control identifier, loop variable, or temporary variable.
- Before writing or editing MaxScript code, follow `maxscript-protected-identifiers.md`.
- Before delivery, review newly introduced identifiers and rename any collision with MAXScript/3ds Max built-ins.

## CRITICAL ERROR HANDLING

- Avoid `try/catch` by default. Do not use it to hide unexpected errors or keep broken code running silently.
- Prefer explicit validation and normal condition checks before an operation instead of wrapping the operation in `try/catch`.
- Silent `catch()` is allowed only for simple, expected, harmless cleanup where failure is intentionally irrelevant, such as `try (destroyDialog some_rollout) catch ()`.
- If `try/catch` is necessary for a real operation, the `catch` block must obtain the exception with `getCurrentException()` and report or log it clearly.
- Do not replace a useful runtime error with a generic failure message that hides the original exception text.
- When appropriate, rethrow with `throw()` after cleanup so the original error remains visible to the caller.

Example:

```maxscript
try
(
    runOperation()
)
catch
(
    local exception_text = getCurrentException()
    format "ERROR: %\n" exception_text
)
```

## CRITICAL RETURN TYPE SAFETY

- Every function must preserve its return-type contract on every code path.
- If a function is designed to return an array, return an array on success and return an empty array `#()` or `undefined` when there is no valid result, according to the function contract.
- Never return unrelated status strings such as `"ok"`, `"failed"`, `"error"`, or arbitrary text from a function whose callers expect an array.
- Likewise, do not return `true`, `false`, integers, or other unrelated types from an array-returning function unless the function contract explicitly defines such a union type.
- Do not overload return values to carry status messages. Report status separately through logging, Listener output, a result struct, or another explicit channel.
- Apply the same rule to other return types: a function expected to return a node, BitArray, boolean, number, string, struct, or other type must not silently return an unrelated type.
- Before delivery, inspect all early returns, failure paths, `catch` paths, and fall-through expressions to ensure they return the documented type or `undefined` where explicitly allowed.

Bad:

```maxscript
function collectNodes source_node =
(
    if source_node == undefined then return "failed"
    #()
)
```

Good:

```maxscript
function collectNodes source_node =
(
    if source_node == undefined then return #()
    #()
)
```

Or, when `undefined` is part of the documented contract:

```maxscript
function findNodeByRole role_name =
(
    if role_name == "" then return undefined
    undefined
)
```


## CRITICAL EDITABLE POLY DEAD TOPOLOGY / INDEX SAFETY

When a MaxScript tool relies on Editable Poly vertex, edge, or face IDs, never assume that `1..polyop.getNumVerts`, `1..polyop.getNumEdges`, or `1..polyop.getNumFaces` contains only currently valid sub-objects.

Editable Poly can temporarily or persistently contain dead vertices, edges, or faces. Dead sub-objects may still occupy index slots and are included in the values returned by the `getNum*` functions.

### Required rule

Before the first index-sensitive topology stage on an `Editable_Poly`, check whether dead topology exists:

```maxscript
if polyop.getHasDeadStructs poly_value != 0 then
(
    polyop.collapseDeadStructs poly_value
)
```

This check and possible cleanup MUST happen before reading, caching, comparing, selecting, or otherwise storing vertex, edge, or face IDs for that topology stage.

### Do not run cleanup unnecessarily

Do NOT call `polyop.collapseDeadStructs` repeatedly before every function or every topology query.

Treat cleanup as a topology-state boundary.

A script should normally:

1. Mark topology as needing validation at the beginning of an index-sensitive workflow.
2. Check `polyop.getHasDeadStructs` once.
3. Call `polyop.collapseDeadStructs` only if dead structures are actually present.
4. Read and cache topology IDs only after that check.
5. Reuse those IDs while topology remains unchanged.
6. Mark topology as dirty again only after an operation that changes topology.
7. Before the next stage that relies on component IDs, perform the dead-structure check again.

Conceptually:

```text
topology dirty
    ↓
check getHasDeadStructs
    ↓
collapseDeadStructs only if required
    ↓
topology clean
    ↓
read vertex / edge / face IDs
    ↓
analysis using stable topology
    ↓
topology-changing operation
    ↓
topology dirty again
```

### Topology-changing operations

Treat the topology as dirty after any operation that can add, remove, merge, split, attach, detach, or otherwise reindex vertices, edges, or faces.

Typical examples include:

- vertex or edge weld operations
- deletion of vertices, edges, or faces
- collapse operations
- attach or detach operations
- creation or removal of topology
- operations that split or merge topology
- any compound Editable Poly operation whose result changes vertex, edge, or face membership

Do not insert `collapseDeadStructs` between individual steps of one compound topology operation merely as a precaution.

Dead sub-objects may intentionally exist during an operation so that existing indices remain stable until the operation finishes.

For example, during a weld, one of the merged vertices may be marked dead while the remaining operation still uses the original indexing. Collapsing dead structures in the middle of that process may renumber IDs that the operation still depends on.

Run the cleanup only at the boundary between completed topology-changing work and a new stage that needs reliable IDs.

### Cached ID invalidation

If `polyop.collapseDeadStructs` is executed, assume that vertex, edge, and face IDs may have been renumbered.

Therefore:

- discard every cached vertex ID
- discard every cached edge ID
- discard every cached face ID
- discard BitArrays containing topology selections from before the collapse
- rebuild topology maps and adjacency data
- query the current topology again

Never use topology IDs collected before `collapseDeadStructs` after the collapse has occurred.

### Selection and count safety

Do not use this pattern on an unvalidated Editable Poly:

```maxscript
edge_count = polyop.getNumEdges poly_value

for edge_index = 1 to edge_count do
(
    ...
)
```

unless the dead topology state has already been validated for the current topology state.

`getNumVerts`, `getNumEdges`, and `getNumFaces` may include dead index slots.

### Recommended helper

Use one centralized helper instead of scattering cleanup logic throughout the script:

```maxscript
/*
Ensures Editable Poly topology is compact before index-sensitive work.
Returns true when the supplied Editable Poly can safely be queried afterwards.
*/
function ensureCleanEditablePolyTopology poly_value =
(
    if poly_value == undefined or classOf poly_value != Editable_Poly then return false

    if polyop.getHasDeadStructs poly_value != 0 then
    (
        polyop.collapseDeadStructs poly_value
    )

    true
    -- return
)
```

Call it once at the beginning of an index-sensitive topology phase:

```maxscript
if not ensureCleanEditablePolyTopology poly_value then return false

edge_count = polyop.getNumEdges poly_value
```

After a topology-changing operation, do not automatically call the helper immediately unless new IDs are required.

Instead:

```text
perform topology-changing operations
→ finish the topology phase
→ before the next ID-dependent phase
→ ensureCleanEditablePolyTopology
→ read fresh IDs
```

### Edit Poly modifier safety

`polyop.collapseDeadStructs` applies to `Editable_Poly`.

Do not automatically run it on the base object underneath an active `Edit_Poly` modifier.

An Edit Poly modifier may depend on the component indexing of the topology below it. Reindexing the base object underneath the modifier can invalidate that relationship.

When working with `Edit_Poly`, operate on and query the modifier's own topology using the Edit Poly API unless the task explicitly requires modifying the base Editable Poly and the consequences of reindexing have been handled.

### Diagnose dead topology explicitly

Do not infer that a selection mismatch, missing component IDs, or a `getNum*` range gap is caused by dead topology.

Before blaming dead topology, inspect `polyop.getHasDeadStructs` or the relevant `polyop.getDeadVerts`, `polyop.getDeadEdges`, and `polyop.getDeadFaces` result.

If the dead-structure state is clean, do not call `collapseDeadStructs` as a speculative fix. Investigate the actual component domain instead, including:

- whether the same exact Editable Poly representation is used for analysis and selection;
- hidden vertex/face state;
- edge visibility versus actual selectable/displayable sub-objects;
- modifier-stack topology identity.

A dead-topology cleanup is a verified topology-state repair, not a generic selection repair.

### Core principle

`collapseDeadStructs` is not a routine call to sprinkle throughout topology code.

Use it as a controlled synchronization point:

```text
topology changes
→ operation finishes
→ before IDs matter again
→ check dead structures
→ collapse only if needed
→ discard old IDs
→ read fresh topology
```

This keeps topology IDs stable during operations while ensuring later index-sensitive analysis never works with stale or dead Editable Poly component slots.

1\\\\. Read the latest canonical project file from the designated Google Drive repository before editing it.      
2\\\\. Preserve unrelated existing changes and modify only what the current task requires.      
3\\\\. Update the existing canonical Google Drive file in place using the same file ID.      
4\\\\. Never create duplicate project files, replacement copies, \\\\\\\`(1)\\\\\\\`, \\\\\\\`(2)\\\\\\\`, \\\\\\\`copy\\\\\\\`, or similar variants unless explicitly requested.      
5\\\\. Apply the shared versioning convention on every code change.      
6\\\\. Increment the shared project version once per change set.      
7\\\\. Update internal file versions and stored project-version values only in code files whose code actually changed.      
8\\\\. The tool/dialog title must display the actual current global project version; never leave a stale or hardcoded version in the title.      
9\\\\. Update only the canonical files required by the requested change.      
10\\\\. Before implementation, read the specialized shared rules relevant to the task, such as UI, TODO, architecture, or Epoly rules.      
11\\\\. Do not make the user redefine these baseline rules when the project already points to this \\\\\\\`AGENTS.md\\\\\\\`.

\\\\\\\#\\\\\\\# Shared-agent scope

\\\\- Keep all shared MaxScript agent instructions project- and tool-agnostic.      
\\\\- Do not store exact project names, tool names, project-specific source filenames, project versions, repository IDs, or project-only implementation details in shared agent files.      
\\\\- Put project-specific instructions in the project repository or project-local instruction files instead.      
\\\\- Use generic placeholders and neutral examples when an example is required.      
\\\\- Shared rules may reference other shared rule files and generic reusable folders by purpose.

\\\\\\\#\\\\\\\# Shared MaxScript rules

\\\\- Follow \\\\\\\`Project-settings/maxscript-project-settings.md\\\\\\\` for project, repository, versioning, and canonical-file behavior.      
\\\\- Follow \\\\\\\`Project-settings/maxscript-todo-rules.md\\\\\\\` for TODO queue and TODO mass-processing behavior.      
\\\\- Follow \\\\\\\`maxscript-project-architecture.md\\\\\\\` for modular architecture and multi-rollout projects.      
\\\\- Follow \\\\\\\`maxscript-ui-rules.md\\\\\\\` for MaxScript UI work.      
\\- Follow `maxscript-protected-identifiers.md` for reserved keywords, protected built-in identifiers, and identifier-collision rules.
- Follow `maxscript-syntax-safety.md` for default syntax, return-contract, failure-handling, destructive-operation, and static-validation rules.
- Follow `maxscript-unit-precision.md` for exact unit handling, numeric precision, rounding, and explicit-tolerance rules.
- Follow `maxscript-modifier-rules.md` for modifier-stack operations, especially fast bulk modifier addition and deletion.
- Follow `maxscript-dump-debug.md` for DEV-mode DUMP logging to both the 3ds Max Listener and a repository-local dump file.
\\\\- For \\\\\\\`Editable\\\\\\\_Poly\\\\\\\` or \\\\\\\`Edit\\\\\\\_Poly\\\\\\\` development, inspect the relevant shared material under \\\\\\\`Epoly/\\\\\\\` before reimplementing existing working methods or snippets.

\\\\\\\#\\\\\\\# Hierarchy Design

For layered MaxScript architecture, use the shared hierarchy:

\\\\\\\`Functions \\\\-\\\\\\\> Operations \\\\-\\\\\\\> Tools \\\\-\\\\\\\> Toolsets\\\\\\\`

Each layer has its own instructions under \\\\\\\`Hierarchy Design/\\\\\\\`:

\\\\- \\\\\\\`Functions/AGENTS.md\\\\\\\`      
\\\\- \\\\\\\`Operations/AGENTS.md\\\\\\\`      
\\\\- \\\\\\\`Tools/AGENTS.md\\\\\\\`      
\\\\- \\\\\\\`Toolsets/AGENTS.md\\\\\\\`

When working in one of these layers, follow that layer's \\\\\\\`AGENTS.md\\\\\\\` in addition to this parent file and the other relevant shared rules.

\\\\\\\#\\\\\\\# UI tooltips

\\\\- In control tooltips, put each callback description on its own line and separate callback descriptions with an empty line.      
\\\\- Write callback names in CAPITAL letters, followed by a colon and a space. Examples: \\\\\\\`LMB: \\\\\\\`, \\\\\\\`RMB: \\\\\\\`, \\\\\\\`CTRL \\\\+ RMB: \\\\\\\`.

Example:

\\\\\\\`\\\\\\\`\\\\\\\`maxscript      
tooltip:"LMB: Run the primary action.\\\\\\\\n\\\\\\\\nCTRL \\\\+ RMB: Open additional options."      
\\\\\\\`\\\\\\\`\\\\\\\`
\\\\\\#\\\\\\# UI templates

\\\\- For any task that creates a new MaxScript dialog/rollout or begins a new tool UI, read \\\\\\`maxscript-ui-rules.md\\\\\\` and \\\\\\`UI/Default/README.md\\\\\\` **before writing the first UI code**.      
\\\\- Start the first runnable UI version from the canonical \\\\\\`UI/Default/Default-UI-Template.ms\\\\\\` baseline. Do not build a stripped-down UI first and retrofit the shared defaults later.      
\\\\- From the first UI version, every standalone tool dialog or owning rollout must include the canonical \\\\\\`tool title button\\\\\\`, restart behavior, INI-backed UI state persistence, dialog position/size persistence, and the shared sizing/layout defaults unless the project explicitly overrides a default.      
\\\\- Every owning dialog must also use a stable, version-independent tool key and the shared dialog-host registry so creating/restarting any version destroys the still-open dialog from older versions of the same tool before the new dialog is created.      
\\\\- Embedded child/subrollouts inside one owning tool UI do not duplicate the tool title button; they still follow the shared layout/state rules and persist their own relevant control state. If a rollout can run as its own dialog, it receives the full baseline.      
\\\\- Treat reusable files in the shared UI template folder as canonical templates and helpers. Load/reuse them instead of copying their implementation into each tool.      
\\\\- Use a matching shared template when one exists instead of creating a project-specific duplicate.      
\\\\- Update the appropriate canonical shared template when changing a shared default instead of creating competing variants.      
\\\\- Omitting a baseline UI default requires an explicit project/user requirement; silence is not an opt-out.


\\\\\\\#\\\\\\\# Verification

\\\\- Keep verification proportional to the risk and complexity of the change.      
\\\\- For simple, low-risk edits such as UI text, spacing, sizing, colors, or tooltip changes, do not create or run unnecessary tests.      
\\\\- Run targeted checks only when they provide meaningful confidence for the specific change.

\\\\\\\#\\\\\\\# MaxScript test behavior

\\\\- Keep the complete test workflow in one executable \\\\\\\`.ms\\\\\\\` test file instead of splitting its stages across multiple files.      
\\\\- Implement each stage as a numbered function such as \\\\\\\`partOfTest1()\\\\\\\`, \\\\\\\`partOfTest2()\\\\\\\`, and \\\\\\\`partOfTest3()\\\\\\\`.      
\\\\- Put an explicit execution queue at the end of the file, with one stage call per line in execution order.      
\\\\- Typical stage order is: create/setup objects, establish selections and context, then run the operation and assertions.      
\\\\- Give each meaningful scene-changing stage its own clearly named undo entry so the result can be inspected by stepping backward through the undo history.      
\\\\- Leave the scene in the final tested state after execution. Do not reset or delete the test scene at the end when doing so would prevent visual inspection through undo.      
\\\\- Print the undo order when the test finishes so it is clear what each undo step restores.      
