/*
Edit Poly selection functions. Version 0.01.
Depends on EpolyCore.ms. No command-panel activation.
*/

/*
Returns the modifier's stored Vertex, Edge or Face selection as BitArray.
*/
function epolyGetSelection node_value edit_poly_mod component_level =
(
    local result_bits = undefined
    if epolyHasContext node_value edit_poly_mod then result_bits = edit_poly_mod.GetSelection component_level node:node_value
    result_bits
    -- return
)

/*
Replaces the stored modifier selection with the supplied complete BitArray.
*/
function epolySetSelection node_value edit_poly_mod component_level component_bits =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then operation_ok = edit_poly_mod.SetSelection component_level component_bits node:node_value
    operation_ok
    -- return
)

/*
Clears only the requested component domain, preserving other domains.
*/
function epolyClearSelection node_value edit_poly_mod component_level =
(
    epolySetSelection node_value edit_poly_mod component_level #{}
    -- return
)

/*
Adds the supplied BitArray to the stored modifier selection in one update.
*/
function epolyAddToSelection node_value edit_poly_mod component_level component_bits =
(
    local operation_ok = false
    local old_bits = epolyGetSelection node_value edit_poly_mod component_level
    if old_bits != undefined then
    (
        old_bits += component_bits
        operation_ok = epolySetSelection node_value edit_poly_mod component_level old_bits
    )
    operation_ok
    -- return
)

/*
Converts the current stored selection between two subobject domains.
This operates on existing selection; it does not open the Modify panel.
*/
function epolyConvertSelection node_value edit_poly_mod from_level to_level require_all:false =
(
    local result_count = undefined
    if epolyHasContext node_value edit_poly_mod then
    (
        edit_poly_mod.SetPrimaryNode node_value
        result_count = edit_poly_mod.ConvertSelection from_level to_level requireAll:require_all
    )
    result_count
    -- return
)
