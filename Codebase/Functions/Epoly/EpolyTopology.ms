/*
Edit Poly topology query helpers. Version 0.01.
All index queries operate on the supplied modifier; no base-object collapse.
*/

/*
Returns adjacent vertex IDs in a BitArray by inspecting each incident edge.
*/
function epolyGetVertexNeighbors node_value edit_poly_mod vertex_id =
(
    local neighbor_bits = #{}
    if epolyHasContext node_value edit_poly_mod then
    (
        local adjacent_count = edit_poly_mod.GetVertexEdgeCount vertex_id node:node_value
        for slot_id = 1 to adjacent_count do
        (
            local edge_id = edit_poly_mod.GetVertexEdge vertex_id slot_id node:node_value
            local first_id = edit_poly_mod.GetEdgeVertex edge_id 1 node:node_value
            local second_id = edit_poly_mod.GetEdgeVertex edge_id 2 node:node_value
            local neighbor_id = if first_id == vertex_id then second_id else first_id
            if neighbor_id > 0 then neighbor_bits[neighbor_id] = true
        )
    )
    neighbor_bits
    -- return
)

/*
Returns each face-connected element as a Face BitArray in an Array.
Connectivity is by shared polygon edges; no viewport selection is needed.
*/
function epolyGetConnectedElements node_value edit_poly_mod =
(
    local element_sets = #()
    if epolyHasContext node_value edit_poly_mod then
    (
        local face_count = edit_poly_mod.GetNumFaces node:node_value
        local visited_bits = #{}
        visited_bits.count = face_count
        local face_queue = #()
        face_queue.count = face_count
        for seed_id = 1 to face_count do
        (
            if not visited_bits[seed_id] then
            (
                local element_bits = #{}
                local head_id = 1
                local tail_id = 1
                face_queue[1] = seed_id
                visited_bits[seed_id] = true
                while head_id <= tail_id do
                (
                    local face_id = face_queue[head_id]
                    head_id += 1
                    element_bits[face_id] = true
                    local face_degree = edit_poly_mod.GetFaceDegree face_id node:node_value
                    for side_id = 1 to face_degree do
                    (
                        local edge_id = edit_poly_mod.GetFaceEdge face_id side_id node:node_value
                        for edge_side = 1 to 2 do
                        (
                            local adjacent_face = edit_poly_mod.GetEdgeFace edge_id edge_side node:node_value
                            if adjacent_face > 0 and not visited_bits[adjacent_face] then
                            (
                                visited_bits[adjacent_face] = true
                                tail_id += 1
                                face_queue[tail_id] = adjacent_face
                            )
                        )
                    )
                )
                append element_sets element_bits
            )
        )
    )
    element_sets
    -- return
)

/*
Returns connected groups of open-border edges as an Array of Edge BitArrays.
An irregular or branching open border is returned as one connected group, not an ordered cycle.
*/
function epolyGetBorderLoops node_value edit_poly_mod =
(
    local result_groups = #()
    if epolyHasContext node_value edit_poly_mod then
    (
        local vertex_count = edit_poly_mod.GetNumVertices node:node_value
        local edge_count = edit_poly_mod.GetNumEdges node:node_value
        local border_bits = #{}
        border_bits.count = edge_count
        local visited_bits = #{}
        visited_bits.count = edge_count
        local vertex_to_edges = #()
        vertex_to_edges.count = vertex_count
        for vertex_id = 1 to vertex_count do vertex_to_edges[vertex_id] = #()
        for edge_id = 1 to edge_count do
        (
            local face_a = edit_poly_mod.GetEdgeFace edge_id 1 node:node_value
            local face_b = edit_poly_mod.GetEdgeFace edge_id 2 node:node_value
            if face_a <= 0 or face_b <= 0 then
            (
                border_bits[edge_id] = true
                local edge_a = edit_poly_mod.GetEdgeVertex edge_id 1 node:node_value
                local edge_b = edit_poly_mod.GetEdgeVertex edge_id 2 node:node_value
                append vertex_to_edges[edge_a] edge_id
                append vertex_to_edges[edge_b] edge_id
            )
        )
        local edge_queue = #()
        edge_queue.count = edge_count
        for seed_id in border_bits do
        (
            if not visited_bits[seed_id] then
            (
                local group_bits = #{}
                local head_id = 1
                local tail_id = 1
                visited_bits[seed_id] = true
                edge_queue[1] = seed_id
                while head_id <= tail_id do
                (
                    local current_edge = edge_queue[head_id]
                    head_id += 1
                    group_bits[current_edge] = true
                    for edge_end = 1 to 2 do
                    (
                        local vertex_id = edit_poly_mod.GetEdgeVertex current_edge edge_end node:node_value
                        for candidate_id in vertex_to_edges[vertex_id] do
                        (
                            if not visited_bits[candidate_id] then
                            (
                                visited_bits[candidate_id] = true
                                tail_id += 1
                                edge_queue[tail_id] = candidate_id
                            )
                        )
                    )
                )
                append result_groups group_bits
            )
        )
    )
    result_groups
    -- return
)
