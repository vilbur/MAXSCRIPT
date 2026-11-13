/*
Edit Poly face functions. Version 0.01.
Depends on EpolyCore.ms.
*/

/*
Returns ordered vertex IDs around the specified polygon as an Array.
*/
function epolyGetFaceVertices node_value edit_poly_mod face_id =
(
    local result_ids = #()
    if epolyHasContext node_value edit_poly_mod then
    (
        local face_degree = edit_poly_mod.GetFaceDegree face_id node:node_value
        result_ids.count = face_degree
        for corner_id = 1 to face_degree do result_ids[corner_id] = edit_poly_mod.GetFaceVertex face_id corner_id node:node_value
    )
    result_ids
    -- return
)

/*
Deletes the selected polygons through the native Delete Face action.
*/
function epolyDeleteFaces node_value edit_poly_mod face_bits =
(
    epolyRunBatch node_value edit_poly_mod #Face face_bits #DeleteFace
    -- return
)

/*
Extrudes a group of polygons by the supplied height and extrusion type.
*/
function epolyExtrudeFaces node_value edit_poly_mod face_bits height_value extrude_type:0 =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        edit_poly_mod.extrudeFaceHeight = height_value
        edit_poly_mod.extrudeFaceType = extrude_type
        operation_ok = epolyRunBatch node_value edit_poly_mod #Face face_bits #ExtrudeFace
    )
    operation_ok
    -- return
)

/*
Insets the selected polygons by a specified distance and mode.
*/
function epolyInsetFaces node_value edit_poly_mod face_bits amount_value inset_type:0 =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        edit_poly_mod.insetAmount = amount_value
        edit_poly_mod.insetType = inset_type
        operation_ok = epolyRunBatch node_value edit_poly_mod #Face face_bits #Inset
    )
    operation_ok
    -- return
)

/*
Bevels selected polygons using explicit height, outline and mode.
*/
function epolyBevelFaces node_value edit_poly_mod face_bits height_value outline_value bevel_type:0 =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        edit_poly_mod.bevelHeight = height_value
        edit_poly_mod.bevelOutline = outline_value
        edit_poly_mod.bevelType = bevel_type
        operation_ok = epolyRunBatch node_value edit_poly_mod #Face face_bits #Bevel
    )
    operation_ok
    -- return
)
