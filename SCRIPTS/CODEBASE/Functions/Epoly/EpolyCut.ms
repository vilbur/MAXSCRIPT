/*
Edit Poly construction and cut helpers. Version 0.01.
New IDs are returned directly from modifier methods; do not reindex inside compound cuts.
*/

/*
Creates an isolated vertex at a local/object-space Point3 position.
*/
function epolyCreateVertex node_value edit_poly_mod position_value =
(
    local result_id = undefined
    if epolyHasContext node_value edit_poly_mod then
    (
        result_id = edit_poly_mod.CreateVertex position_value node:node_value
        edit_poly_mod.Commit()
    )
    result_id
    -- return
)

/*
Inserts a vertex on an edge at a proportional position between endpoints.
A proportion of 0.5 requests the midpoint.
*/
function epolyDivideEdge node_value edit_poly_mod edge_id proportion_value =
(
    local result_id = undefined
    if epolyHasContext node_value edit_poly_mod then
    (
        result_id = edit_poly_mod.DivideEdge edge_id proportion_value node:node_value
        edit_poly_mod.Commit()
    )
    result_id
    -- return
)

/*
Inserts a vertex inside a polygon with explicit face vertex coefficients.
The coefficients must correspond to the polygon corner order.
*/
function epolyDivideFace node_value edit_poly_mod face_id vertex_coefficients =
(
    local result_id = undefined
    if epolyHasContext node_value edit_poly_mod then
    (
        result_id = edit_poly_mod.DivideFace face_id vertex_coefficients node:node_value
        edit_poly_mod.Commit()
    )
    result_id
    -- return
)

/*
Creates a topology edge between two existing vertices.
The modifier decides whether the proposed edge can legally split the face.
*/
function epolyCreateEdge node_value edit_poly_mod vertex_a vertex_b =
(
    local result_id = undefined
    if epolyHasContext node_value edit_poly_mod then
    (
        result_id = edit_poly_mod.CreateEdge vertex_a vertex_b node:node_value
        edit_poly_mod.Commit()
    )
    result_id
    -- return
)

/*
Cuts from an existing vertex to a proportionally divided target edge.
One compound operation; the returned Array contains new vertex and edge IDs.
*/
function epolyCutVertexToEdge node_value edit_poly_mod vertex_id edge_id proportion_value =
(
    local result_ids = #()
    if epolyHasContext node_value edit_poly_mod then
    (
        local new_vertex_id = edit_poly_mod.DivideEdge edge_id proportion_value node:node_value
        local new_edge_id = edit_poly_mod.CreateEdge vertex_id new_vertex_id node:node_value
        edit_poly_mod.Commit()
        result_ids = #(new_vertex_id, new_edge_id)
    )
    result_ids
    -- return
)

/*
Cuts between two edges by dividing each and connecting the new vertices.
Returned Array contains the two vertex IDs followed by the created edge ID.
*/
function epolyCutEdgeToEdge node_value edit_poly_mod edge_a proportion_a edge_b proportion_b =
(
    local result_ids = #()
    if epolyHasContext node_value edit_poly_mod then
    (
        local vertex_a = edit_poly_mod.DivideEdge edge_a proportion_a node:node_value
        local vertex_b = edit_poly_mod.DivideEdge edge_b proportion_b node:node_value
        local new_edge = edit_poly_mod.CreateEdge vertex_a vertex_b node:node_value
        edit_poly_mod.Commit()
        result_ids = #(vertex_a, vertex_b, new_edge)
    )
    result_ids
    -- return
)
