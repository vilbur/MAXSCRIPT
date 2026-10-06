# MaxScript Modifier Rules

Use these rules whenever MaxScript adds, removes, searches, or batch-processes object modifiers.

## Bulk modifier deletion performance

Deleting many modifiers can be slow when 3ds Max repeatedly updates the viewport, undo system, and Command Panel.

For performance-oriented bulk deletion:

1. Delete from the modifier stack backwards, from the highest index to `1`, so index changes caused by deletion cannot invalidate the remaining loop.
2. Wrap the deletion batch in `with redraw off`.
3. Wrap the deletion batch in `with undo off` when the operation is explicitly intended to be non-undoable for maximum speed.
4. Call `suspendEditing()` once before the deletion loop to prevent Command Panel updates during the batch.
5. Call `resumeEditing()` once after the batch.
6. Call `completeRedraw()` only once after the batch, and only when something was actually deleted.
7. Do not select modifiers in the stack one by one or call `modPanel.setCurrentObject` merely to delete them.
8. Do not iterate forward while deleting modifier indices.
9. When deleting across many objects, keep redraw/undo suppression and Command Panel suspension outside the outer object loop whenever practical, so they are entered only once for the whole batch.

The fast helper below is intentionally non-undoable because it uses `with undo off`. Use another path when the operation must remain undoable.

## Canonical reusable deletion helper

`deleteModifiersFast obj modifiers_to_delete` deletes matching modifiers from one object and returns an integer count of deleted modifiers.

`modifiers_to_delete` may be:

- one modifier class, such as `SliceModifier` or `Edit_Poly`;
- one exact modifier instance;
- an array containing modifier classes and/or exact modifier instances.

The function must never use `modifier` as a variable or parameter name.

```maxscript
/*
Deletes matching modifiers from one node using the fast batch-delete pattern.
Returns the number of deleted modifiers.
*/
function deleteModifiersFast obj modifiers_to_delete =
(
    if not isValidNode obj then return 0
    if modifiers_to_delete == undefined then return 0
    if obj.modifiers.count == 0 then return 0

    local delete_targets = if classOf modifiers_to_delete == Array then modifiers_to_delete else #(modifiers_to_delete)
    if delete_targets.count == 0 then return 0

    local deleted_count = 0

    with redraw off
    with undo off
    (
        suspendEditing()

        try
        (
            for mod_index = obj.modifiers.count to 1 by -1 do
            (
                local stack_mod = obj.modifiers[mod_index]
                local matches_instance = (findItem delete_targets stack_mod) > 0
                local matches_class = (findItem delete_targets (classOf stack_mod)) > 0

                if matches_instance or matches_class then
                (
                    deleteModifier obj mod_index
                    deleted_count += 1
                )
            )
        )
        catch
        (
            local exception_text = getCurrentException()
            resumeEditing()
            format "deleteModifiersFast ERROR: %\\n" exception_text
            throw exception_text
        )

        resumeEditing()
    )

    if deleted_count > 0 then completeRedraw()

    deleted_count
)
```

Examples:

```maxscript
-- Delete every Slice modifier from one object.
deleted_count = deleteModifiersFast obj SliceModifier

-- Delete every Slice and Edit Poly modifier from one object.
deleted_count = deleteModifiersFast obj #(SliceModifier, Edit_Poly)

-- Delete only two exact modifier instances.
deleted_count = deleteModifiersFast obj #(target_mod_a, target_mod_b)
```

## Bulk modifier addition performance

Adding many modifiers can be slow for the same reason as deleting them: 3ds Max may repeatedly update the viewport, undo system, modifier stack UI, and Command Panel.

For performance-oriented bulk addition:

1. Prepare all modifier instances before starting the batch.
2. Wrap the addition batch in `with redraw off`.
3. Wrap the addition batch in `with undo off` when the operation is explicitly intended to be non-undoable for maximum speed.
4. Call `suspendEditing()` once before adding the modifiers.
5. Add all prepared modifier instances while editing is suspended.
6. Call `resumeEditing()` once after the batch.
7. Call `completeRedraw()` only once after the batch, and only when something was actually added.
8. Do not select each newly added modifier in the stack or call `modPanel.setCurrentObject` merely to add it.
9. When adding modifiers across many objects, keep redraw/undo suppression and Command Panel suspension outside the outer object loop whenever practical.

The fast helper below is intentionally non-undoable because it uses `with undo off`. Use another path when the operation must remain undoable.

## Canonical reusable addition helper

`addModifiersFast obj modifiers_to_add` adds prepared modifier instances to one object and returns an integer count of added modifiers.

`modifiers_to_add` may be:

- one modifier instance;
- an array of modifier instances.

Pass actual modifier instances, not modifier classes. Create and configure the modifiers before calling the helper.

```maxscript
/*
Adds prepared modifiers to one node using the fast batch-add pattern.
Returns the number of added modifiers.
*/
function addModifiersFast obj modifiers_to_add =
(
    if not isValidNode obj then return 0
    if modifiers_to_add == undefined then return 0

    local add_targets = if classOf modifiers_to_add == Array then modifiers_to_add else #(modifiers_to_add)
    if add_targets.count == 0 then return 0

    local added_count = 0

    with redraw off
    with undo off
    (
        suspendEditing()

        try
        (
            for stack_mod in add_targets do
            (
                addModifier obj stack_mod
                added_count += 1
            )
        )
        catch
        (
            local exception_text = getCurrentException()
            resumeEditing()
            format "addModifiersFast ERROR: %\\n" exception_text
            throw exception_text
        )

        resumeEditing()
    )

    if added_count > 0 then completeRedraw()

    added_count
)
```

Example:

```maxscript
target_obj = selection[1]

mods_to_add = #(
    SliceModifier slice_type:3,
    SliceModifier slice_type:4
)

added_count = addModifiersFast target_obj mods_to_add
```

The `addModifier` calls execute in the same order as `modifiers_to_add`. Do not repeatedly suspend/resume editing or redraw after each added modifier.

If the same modifier instance is intentionally added to multiple nodes, it creates a shared/instanced modifier relationship. When independent modifiers are required per object, create separate modifier instances for each object.

## Large multi-object batches

For a very large set of objects, do not repeatedly suspend/resume editing for every object when adding or deleting modifiers if maximum performance matters.

Use the same pattern at the outer batch level:

```text
with redraw off
with undo off
    suspendEditing()
        for each object
            delete matching modifiers backwards
    resumeEditing()
completeRedraw once
```

The important performance rule is not merely `deleteModifier`; it is minimizing UI, redraw, undo, and modifier-stack update overhead around the entire batch.

## Error-safety requirement

Because `suspendEditing()` changes global 3ds Max UI state, any code path that can fail after suspension must restore editing before propagating the error.

If `try/catch` is required for this cleanup, follow the shared error-handling rule:

- obtain the original error with `getCurrentException()`;
- call `resumeEditing()`;
- report or rethrow the original exception;
- never silently swallow the failure.

## Return contract

The canonical helper returns an integer on every normal code path:

- `0` when no modifier was deleted or the supplied node/targets are not usable;
- a positive integer when modifiers were deleted.

Do not return strings such as `"ok"`, `"failed"`, or `"error"` from this function.
