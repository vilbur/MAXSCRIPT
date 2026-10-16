/*
Shared Edit Poly context and action helpers. Version 0.01.
Functions expect an existing Edit_Poly modifier; no automatic modifier creation.
*/

/*
Checks the node and exact Edit Poly modifier at an external workflow boundary.
Returns true only if the instance is in the node's modifier stack.
*/
function epolyHasContext node_value edit_poly_mod =
(
    local context_valid = (isValidNode node_value and edit_poly_mod != undefined)
    if context_valid then context_valid = (classOf edit_poly_mod == Edit_Poly)
    if context_valid then
    (
        context_valid = false
        for stack_mod in node_value.modifiers while not context_valid do
        (
            if stack_mod == edit_poly_mod then context_valid = true
        )
    )
    context_valid
    -- return
)

/*
Executes a native Edit Poly operation once on a batch of component IDs.
Selection and level change occur once per call, with no viewport redraw.
*/
function epolyRunBatch node_value edit_poly_mod component_level component_bits operation_name =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        edit_poly_mod.SetEPolySelLevel component_level
        operation_ok = edit_poly_mod.SetSelection component_level component_bits node:node_value
        if operation_ok then
        (
            edit_poly_mod.ButtonOp operation_name
            edit_poly_mod.Commit()
        )
    )
    if not operation_ok then format "EPOLY BATCH FAILED | operation:% | node:% | level:% | ids:%\n" operation_name node_value component_level component_bits
    operation_ok
    -- return
)

/*
Returns a canonical BitArray from a single 1-based component index.
*/
function epolySingleBit component_id =
(
    local component_bits = #{}
    if component_id > 0 then component_bits[component_id] = true
    component_bits
    -- return
)
