# MaxScript Syntax and Code Safety

These rules apply whenever new MaxScript code is written or existing MaxScript code is changed.

The goal is to prevent parser errors, type-contract bugs, fake success, silent native-operation failures, and unsafe destructive edits before code reaches runtime testing.

## Core syntax

- Use `function` for function declarations. Do not use the `fn` alias.
- For `if` expressions, always use `then`. Do not write `if condition do`.
- Do not change legitimate `do` syntax used by `for ... do`, `while ... do`, or `on ... do`.
- Keep executable expressions parser-safe. Avoid stray commas, malformed property or method chains, orphaned code blocks, and ambiguous nested expressions.
- Keep Array, BitArray, Point3, Matrix3, struct, and function-call expressions syntactically complete and balanced.
- Do not call undefined helper functions, invented native methods, or APIs that have not been verified to exist in MAXScript/3ds Max.
- Avoid forward-reference problems. A function or symbol must be available when the code path that uses it executes.

## Identifier safety

Follow `maxscript-protected-identifiers.md` for reserved keywords, protected globals, built-in classes, interfaces, constructors, and other collision-prone identifiers.

Do not rename legitimate property access or API symbols merely because part of the expression matches a protected word. For example, `obj.modifiers` is valid property access; a user-defined variable named `modifier` is not.

## Performance-sensitive control flow

- Prefer the function's final expression as its result. Do not use `return` for routine function exits.
- Avoid `break`, `exit`, `continue`, and `throw` for ordinary control flow. Autodesk documents that executing these commands uses slow C++ exceptions. Use normal `if ... then ... else ...` / `case ... of` expressions or a `for ... while ...` stop condition instead.
- Minimize `try/catch`: use it only for necessary exception handling, not normal decisions or repetitive per-component operations. Preserve the existing error-reporting and narrow harmless-cleanup rules below.
- Do not add extra helper layers or complex control flow solely to avoid a rare, necessary exceptional exit; keep the frequent execution path simple and fast.

Autodesk MAXScript Help: [Do not use return, break, exit or continue](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/Frequently-Asked-Questions/Writing-Better-and-Faster/How-To-Make-It-Faster-/GUID-DEFAF4D3-ADE9-469E-963A-440996D64BE1.html).

## Array and BitArray performance

- Choose the collection by purpose, not by a blanket preference. Use `BitArray` for large sets of positive integer component IDs, selections, and true/false flags over a known index domain. Use `Array` for ordered or heterogeneous values and growing lists whose size is not yet known.
- When the final size is known, allocate it **once** before filling (`values = #(); values.count = item_count` or `flags = #{}; flags.count = item_count`), then assign by index. Avoid repeated growth in hot loops; in particular, appending to a growing `BitArray` is slow.
- For large fixed-size Arrays, prefer indexed assignment to repeated `append`, which can repeatedly copy/reallocate array storage. `append` remains acceptable for small collections or legitimately dynamic results; do not introduce complicated bookkeeping solely to avoid it.
- For filtered/dynamically produced Arrays, prefer an appropriate `for ... collect` expression over manually building an Array with `append`, when the expression remains clear.
- Do not repeatedly convert `Array` to `BitArray` and back within loops or construct needless intermediate copies of large collections. Reuse a stable collection and cached values where that improves the actual work.
- `BitArray.count` is its **capacity/index domain**, not the number of selected elements; use `.numberSet` for the count of set bits. Do not interpret an empty BitArray as a failed native query unless that meaning is explicit in the caller contract.
- Never make oversized allocations by guessing an enormous upper bound. Preserve stable topology IDs during a compound Edit Poly operation; rebuild selections only when a documented topology/index boundary invalidates them.

Autodesk MAXScript Help: [Use bitArrays instead of Arrays when possible](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/Frequently-Asked-Questions/Writing-Better-and-Faster/How-To-Make-It-Faster-/GUID-E2FA13DE-C491-4244-A7AA-62631FB03CA4.html), [Pre-initialize arrays when final size is known](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/Frequently-Asked-Questions/Writing-Better-and-Faster/How-To-Make-It-Faster-/GUID-20124F54-0FDC-4A56-A252-18DFE79A7C41.html), [For Loop Collect Vs For Loop Do Performance](https://help.autodesk.com/cloudhelp/2026/ENU/MAXScript-Help/files/Frequently-Asked-Questions/Writing-Better-and-Faster/How-To-Make-It-Faster-/GUID-F6D660D1-D0EE-41DB-804D-7404E513E2B6.html).

## Return contracts

- Every function must preserve one documented return contract on every normal code path.
- Array-producing functions must return an Array on legitimate no-result paths when absence is represented by an empty result.
- BitArray-producing functions must return a BitArray when legitimate absence is represented by an empty selection.
- Boolean functions must return only Boolean values on normal paths.
- Integer functions must use one documented Integer failure/no-result sentinel when such a sentinel is required.
- Result structs or records must keep the same shape on every path.
- Do not let status strings such as `"OK"`, `"failed"`, or exception text leak into a function whose caller expects another type.
- Do not normalize a real API failure into an empty Array, empty BitArray, zero, identity matrix, default position, default normal, or another valid-looking value unless the function contract explicitly defines failure and legitimate empty data as equivalent.

Before using `.count`, indexing, arithmetic, property access, or another type-specific operation on a function result, ensure the callee contract guarantees that type.

## No fake success

A function must not report success unless the requested operation actually completed.

Do not:

- return `true` after an operation failed;
- increment success counters for failed attach, weld, conversion, delete, slice, or topology operations;
- set a success flag after a failed setter or native command;
- report full success after only partial completion;
- let cleanup or state-restoration code overwrite the real failure state.

## Error handling

- Prefer explicit validation and normal condition checks before risky operations.
- Do not use `try/catch` to hide unexpected failures or continue with fabricated fallback data.
- Operation-critical failures must propagate or return an explicit failure result according to the function contract.
- When a real `catch` is necessary, obtain the exception with `getCurrentException()`.
- Do not use an empty `catch()` for topology reads, selection reads, geometry edits, modifier operations, transform reads, attach/weld operations, or other correctness-critical work.
- Quiet catches are allowed only for intentionally harmless best-effort cleanup or capability probes where failure is expected and cannot corrupt the result.

## Fatal-condition diagnostics

Any condition that represents a required precondition, postcondition, invariant, or verification and whose failure stops or invalidates the operation must be diagnosable at the exact failure site.

Required behavior:

- Before propagating a critical failure result (`false` or `undefined`), setting a failure flag, or skipping a required commit, emit a diagnostic with the values that caused the failure.
- For `actual != expected`, range checks, count checks, topology checks, transform checks, and selection checks, print the actual value and the expected/required value whenever both are available.
- Include the relevant object/node, exact modifier instance or name, component ID(s), operation/stage name, and input/delta values when they materially help reproduce the failure.
- Preserve raw backend values in diagnostics. Do not round or format them to UI display precision.
- Do not hide the decisive state behind a generic `"failed"` message.
- If DUMP is active, use the shared logger so the diagnostic reaches both Listener and dump file. If DUMP is not active, use `format` or the tool's normal logger.
- Logging is diagnostic only: the operation must still return/propagate its real failure state.
- Never respond to a failing exact verification by silently adding epsilon/tolerance, rounding, clamping, or removing the check.

Bad:

```maxscript
if moved_position != expected_position then
(
    return false
)
```

Good:

```maxscript
local operation_ok = moved_position == expected_position
if not operation_ok then
(
    format "MOVE FAILED | vertex:% expected:% actual:% delta:%\n" \
        vertex_id expected_position moved_position (moved_position - expected_position)
)
operation_ok
```

## Topology and selection reads

Do not convert a failed native topology or selection query into a legitimate-looking empty result and then continue as if the scene contained no data.

Keep these states distinct when they have different meanings:

- successful read with no geometry or no selection;
- failed read;
- invalid object or editing context;
- unsupported operation.

This distinction is mandatory before destructive operations.

## Destructive operations

For delete, weld, attach, collapse, RemoveEdge, DeleteFace, vertex movement, topology splitting, modifier deletion, conversion, selection replacement, Slice, and similar operations:

- validate preconditions first;
- abort safely on native API failure;
- do not report partial completion as full success;
- verify the post-operation result where practical;
- preserve the true failure state even if cleanup or restoration also fails.

## Modifier-stack and editing-state safety

When code changes global or editor state such as `suspendEditing()`, redraw/undo suspension, Command Panel mode, active modifier, primary-node binding, sub-object level, cage state, or selection state:

- track what must be restored;
- restore it on every exit path that follows the state change;
- do not clear a restoration-needed flag until restoration actually succeeds;
- do not let restoration failures silently convert the main operation into success.

## Unit and numeric precision safety

Follow `maxscript-unit-precision.md` whenever numeric values represent scene units, distances, coordinates, geometry measurements, angles, scales, thresholds, or tolerances.

- Do not introduce hidden rounding, truncation, Float-to-Integer coercion, quantization, snapping, clamping, epsilon values, or private precision tolerances.
- Exact behavior must stay exact unless the feature contract explicitly defines a tolerance.
- A hard-coded tolerance is not a harmless implementation detail when it changes selection, classification, geometry, or destructive behavior.
- UI formatting precision must remain separate from backend numeric precision.
- If an algorithm genuinely requires a tolerance and none is specified, do not invent one.

## Static validation before delivery

Before delivering changed MaxScript code, perform a focused static check of the changed code for:

- balanced `()`;
- balanced `[]`;
- balanced `{}`;
- no accidental duplicate separators such as `),,`;
- no executable protected-identifier misuse;
- no `if ... do`;
- no `fn` declarations;
- no undefined or invented helper/native calls;
- no empty critical catches;
- every real catch obtains `getCurrentException()`;
- no obvious mixed return contracts;
- no fake-success paths introduced by the change.
- no silent fatal verification branches that discard the actual/expected values needed to diagnose the failure;
- no hidden rounding, numeric truncation, Float-to-Integer coercion, or unapproved epsilon/tolerance introduced by the change.

Static validation does not replace actual 3ds Max runtime testing. Never claim runtime verification unless the code was actually executed in 3ds Max.
