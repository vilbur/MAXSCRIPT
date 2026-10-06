I want you to perform a full safety and code-quality audit of this MaxScript repository.

Repository: `<REPOSITORY NAME / GOOGLE DRIVE FOLDER>`

Treat the canonical repository copy as the source of truth. Always read the latest repository version of a file before editing it. Do not overwrite newer work with older chat attachments or cached copies.

For this audit, work only in the repository root unless I explicitly tell you to inspect subfolders.

Do NOT make changes immediately.

First analyze the repository and report what you find. After the report, wait for my approval before editing.

The audit should be thorough, but do not rewrite working code just for style.

Main things to audit:

1. MAXScript reserved / preserved identifiers

Look for reserved, preserved, built-in, or dangerous MAXScript identifiers being used as:

- local/global variables
- function parameters
- loop variables
- struct members where problematic
- temporary variables

Pay particular attention to names such as:

`modifier`

and any other MAXScript keyword, built-in, or preserved identifier that could cause parser/runtime ambiguity.

Rename them semantically, for example:

`stack_modifier`
`edit_poly_modifier`
`slice_modifier`
`modifier_ref`

Do not blindly rename property access such as:

`node.modifiers`

or class/function names.

Check executable code, not just text matching.

2. Invalid / dirty MAXScript syntax

Find and fix patterns such as:

`if condition do`

The project convention is:

`if condition then`

Do not modify legitimate:

`for ... do`
`while ... do`
`on ... do`

Also look for:

- old `fn` declarations where project style requires `function`
- parser-risk expressions
- stray commas
- invalid method/property chains
- malformed Point3/Array expressions
- accidental duplicate/orphaned code blocks
- forward-reference problems
- undefined function calls

3. Function return contracts

Audit every important function for consistent return types.

If a function conceptually returns an Array, it must return an Array on every normal no-result path.

Example:

Good:

`#()`

Bad:

`undefined`
`OK`
`false`

Do the same for other contracts.

Examples:

- Integer function: use one documented Integer failure sentinel such as `-1`
- Boolean function: always Boolean
- BitArray function: always BitArray when absence is legitimate
- Result record: keep the same record shape on every path

Be especially suspicious of bugs such as:

`Unknown property: "count" in OK`

or callers assuming `.count` on values that are not guaranteed Arrays.

Do not normalize a real API failure into an empty Array/BitArray unless “no data” and “failed to read data” are genuinely equivalent.

4. Fake-success paths

Find functions that catch or ignore an error and then return success.

Examples:

- operation fails but function returns `true`
- modifier deletion partially fails but caller reports success
- topology read fails and returns `0`
- selection read fails and returns `#{}`
- failed attach/weld/conversion still increments a success counter
- failed state restoration is forgotten
- failed setter is followed by `success = true`

These are high priority.

A function must not report success unless the operation actually completed.

5. try / catch audit

This is the dangerous phase. Do NOT start by mechanically rewriting every catch.

Classify catches first.

Categories:

A. Harmless cleanup / best-effort cleanup

Examples:

- destroying an already-closed dialog
- deleting a temporary object during cleanup
- restoring UI state where failure is genuinely non-critical

These may stay protected, but the catch should still read:

`getCurrentException()`

unless there is a strong reason not to.

B. Capability probes / optional API probes

These may intentionally fail, but the exception should still be captured.

They may remain quiet if failure is expected.

C. Operation-critical failures

These must not silently continue.

Topology reads, selection reads, geometry operations, modifier manipulation, attach/weld, destructive edits, transform reads, stack manipulation, etc. must propagate or explicitly return failure.

Every real catch should inspect:

`getCurrentException()`

Avoid empty:

`catch()`

Do not simply add logging everywhere if the caller will still continue with fake data.

Fix the control flow.

6. False-empty topology / selection reads

This deserves its own audit.

Look for code where failed native queries become:

`#()`
`#{}`
`0`
`undefined`
identity matrix
default position
default normal

Then check the caller.

If the caller interprets that as:

“nothing selected”
“no geometry”
“no border”
“no candidate”
“no slice required”
“clean result”

then the failure must be distinguished from a legitimate empty result.

This is especially important before destructive operations.

7. Destructive operations

Audit operations such as:

- delete
- weld
- attach
- collapse
- RemoveEdge
- DeleteFace
- vertex movement
- topology splitting
- modifier deletion
- modifier stack edits
- converting geometry
- replacing selections
- Slice operations

Verify that:

- preconditions are checked
- native API failures abort safely
- partial completion cannot be reported as full success
- post-operation state is verified where practical
- selection/state restoration does not overwrite the true failure

8. Modifier-stack and editing-state safety

Check:

- `suspendEditing`
- `resumeEditing`
- Modify/Create panel switching
- active modifier state
- primary-node binding
- sub-object level
- selection restoration
- cage state
- redraw/undo suspension

If restoration fails, do not blindly clear the flag that says restoration is still needed.

9. Bundle/source synchronization

If the repository has a bundled launcher containing standalone source files:

- treat standalone source files as development sources
- rebuild the bundle from the current canonical sources after changes
- verify each component appears exactly once
- verify bundled component text matches standalone source exactly

Do not manually maintain two divergent versions.

10. Versioning

Follow THIS repository's own canonical versioning rules.

Do not invent a new version scheme.

On a change set:

- increment only modified code files
- increment shared project version once
- store the new project version only where required by repository rules
- do not bump untouched files
- update the bundled launcher if its contents changed

11. changes.md

Maintain the repository change log.

Add a concise entry containing:

- date
- files changed
- important behavioral fixes
- file/project versions if that repository records them

Do not use `changes.md` as version authority.

12. Deployment / repository hygiene

Check root deployment/config files for problems such as:

- backups accidentally included in releases
- releases recursively copying themselves
- `.git` copied into distributions
- stale launch instructions
- obsolete filenames
- README describing old tools/workflows
- ignored files that should not be deployed

Do not spend time rewriting documentation unrelated to the current tool.

13. Regression tests

For every behavioral fix, add or update a focused test where practical.

Tests should target the actual failure contract, not merely test that the function exists.

Examples:

- failed topology read propagates
- failed selection read does not become empty selection
- destructive helper reports failure
- Array-producing helper always returns Array
- partial operation does not return success

Do not claim runtime testing if you cannot run 3ds Max.

Clearly separate:

- static/source verification
- actual 3ds Max runtime verification

14. Final static validation

Before writing canonical files, check at minimum:

- balanced `()`
- balanced `[]`
- balanced `{}`
- no accidental `),,`
- no executable reserved identifier misuse
- no real `if ... do`
- no prohibited `fn` if repository style requires `function`
- no empty catches
- every catch captures `getCurrentException()`
- no obvious mixed return contracts
- bundle/component equality
- correct versions

After uploading, read the canonical files back and compare them against the validated local build.

Do not assume a successful upload means the contents are correct.

WORKFLOW

Phase 1 — Analysis only

Audit the current canonical repository.

Report findings grouped roughly as:

CRITICAL
HIGH
MEDIUM
LOW

For each important issue include:

- file
- function / approximate location
- current behavior
- why it is dangerous
- recommended fix

Do not edit yet.

Phase 2 — Low-risk cleanup

After I approve:

- reserved identifiers
- syntax cleanup
- return contracts
- obvious fake-success contracts

Run static validation.

Then update canonical files and create a backup/checkpoint.

Phase 3 — Exception handling

Only after the backup:

- fix try/catch behavior
- propagate operation-critical failures
- distinguish failed reads from legitimate empty results
- harden destructive operations

Do not mechanically remove catches.

Phase 4 — Final semantic audit

After exception cleanup, go through the repository again looking for second-order versions of the same problems:

- failure converted to empty data
- fake success
- partial success
- default transform/position masking an API failure
- caller interpreting failure sentinel as clean geometry

Also finish repository/deployment/documentation problems discovered in the original audit.

Phase 5 — Final verification

Rebuild bundle if applicable.

Verify canonical Drive files by reading them back.

Create a final post-audit backup.

Then tell me explicitly whether:

- source audit is complete
- static validation passed
- runtime testing is still required in 3ds Max

IMPORTANT

Do not blindly “clean up” working geometry algorithms.

Prefer minimal, targeted changes.

Do not change behavior unless the audit identifies a concrete correctness, safety, parser, contract, or failure-handling reason.

When a catch is intentionally harmless, preserve that behavior instead of turning every minor cleanup failure into a fatal error.

When unsure whether an empty result is legitimate or represents a native API failure, trace the caller before changing it.

The goal is not prettier code.

The goal is:

**predictable contracts, no fake success, no silent critical failures, safe destructive operations, synchronized source/bundle files, and a repository state we can trust.**