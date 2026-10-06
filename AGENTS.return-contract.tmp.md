\\\\\\\#\\\\\\\# REQUIRED BEFORE ANY MAXSCRIPT CHANGE

These rules are mandatory for every MaxScript project change and do not need to be repeated by the user in each chat.

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

- Every function must preserve its documented return-type contract on every code path.
- A function that returns an array must return an array. If nothing is found, return an empty array `#()` when zero results are a valid outcome.
- A function that returns a count must return a number. If nothing is found, return `0`.
- A function that returns a BitArray must return a BitArray. If nothing is found, return an empty BitArray `#{}`.
- A function that returns another specific type must use the corresponding empty/zero/false value when that value correctly represents a valid empty result.
- Use `undefined` only when the function contract explicitly defines it as meaning that no valid result exists or the operation is not applicable.
- Never return an unrelated datatype as a status indicator. In particular, an array-returning function must never return strings such as `"ok"`, `"failed"`, or `"error"`, and must not return booleans or numbers instead of an array.
- Do not overload return values to carry status messages. Report status separately through logging, Listener output, a result struct, or another explicit channel.
- Before delivery, inspect normal returns, early returns, failure paths, `catch` paths, and fall-through expressions to ensure the return datatype remains consistent.

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

Count example:

```maxscript
function countNodes nodes =
(
    if nodes == undefined then return 0
    nodes.count
)
```

Use `undefined` only when it is explicitly part of the function contract.


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

\\\\\\\#\\\\\\\# UI templates

\\\\- Follow \\\\\\\`maxscript-ui-rules.md\\\\\\\` for MaxScript UI work.      
\\\\- Treat reusable files in the shared UI template folder as canonical templates.      
\\\\- Use a matching shared template when one exists instead of creating a project-specific duplicate.      
\\\\- Update the appropriate canonical shared template when changing a shared default instead of creating competing variants.

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
