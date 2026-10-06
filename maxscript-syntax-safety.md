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
- no hidden rounding, numeric truncation, Float-to-Integer coercion, or unapproved epsilon/tolerance introduced by the change.

Static validation does not replace actual 3ds Max runtime testing. Never claim runtime verification unless the code was actually executed in 3ds Max.
