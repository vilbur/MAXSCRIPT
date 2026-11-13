/*
Edit Poly edge functions. Version 0.01.
Depends on EpolyCore.ms.
*/

/*
Returns the two vertex IDs of an edge, as a two-element Array.
*/
function epolyGetEdgeVertices node_value edit_poly_mod edge_id =
(
    local result_ids = #()
    if epolyHasContext node_value edit_poly_mod then
    (
        result_ids = #( (edit_poly_mod.GetEdgeVertex edge_id 1 node:node_value), (edit_poly_mod.GetEdgeVertex edge_id 2 node:node_value) )
    )
    result_ids
    -- return
)

/*
Removes edges without automatically deleting their boundary vertices.
*/
function epolyRemoveEdges node_value edit_poly_mod edge_bits remove_vertices:false =
(
    local action_name = if remove_vertices then #RemoveEdgeRemoveVertices else #RemoveEdge
    epolyRunBatch node_value edit_poly_mod #Edge edge_bits action_name
    -- return
)

/*
Deletes edges and the incident polygons in a single native operation.
*/
function epolyDeleteEdges node_value edit_poly_mod edge_bits =
(
    epolyRunBatch node_value edit_poly_mod #Edge edge_bits #DeleteEdge
    -- return
)

/*
Connects the chosen edge ring with the requested segment count.
*/
function epolyConnectEdges node_value edit_poly_mod edge_bits segments:1 pinch:0 slide:0 =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        edit_poly_mod.connectEdgeSegments = segments
        edit_poly_mod.connectEdgePinch = pinch
        edit_poly_mod.connectEdgeSlide = slide
        operation_ok = epolyRunBatch node_value edit_poly_mod #Edge edge_bits #ConnectEdges
    )
    operation_ok
    -- return
)

/*
Splits the requested edges with the modifier's native Split Edges action.
*/
function epolySplitEdges node_value edit_poly_mod edge_bits =
(
    epolyRunBatch node_value edit_poly_mod #Edge edge_bits #SplitEdges
    -- return
)

/*
Bridges two specified edges directly without changing the Modify panel.
*/
function epolyBridgeEdges node_value edit_poly_mod edge_a edge_b =
(
    local operation_ok = epolyHasContext node_value edit_poly_mod
    if operation_ok then
    (
        edit_poly_mod.BridgeEdges edge_a edge_b node:node_value
        edit_poly_mod.Commit()
    )
    operation_ok
    -- return
)
