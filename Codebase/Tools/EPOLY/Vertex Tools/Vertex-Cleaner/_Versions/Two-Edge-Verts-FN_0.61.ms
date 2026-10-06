/*
    Two Edge Verts Backend 0.61
    Reusable geometry backend for two-edge detection, selection, candidate storage, and visible-edge-only vertex fixes.

    Public input/output API:
    getTwoEdgeVerts node modifier:<Edit_Poly> -> BitArray
    getTJunctionVerts node modifier:<Edit_Poly> -> BitArray
    getVisibleNeighborVertexIds node source_vertex modifier:<Edit_Poly> -> Array
    getClosestVisibleNeighborVertexId node source_vertex modifier:<Edit_Poly> -> Integer
    storeCandidateIds node vertex_bits modifier:<Edit_Poly> -> Array
    getStoredCandidateIds() -> Array
    getNextStoredCandidateId() -> Integer
    selectCandidateById node vertex_id modifier:<Edit_Poly> -> Boolean
    fixCandidateById node source_vertex modifier:<Edit_Poly> -> Boolean
*/

global TwoEdgeVerts
global epoly_tools_project_version

if epoly_tools_project_version == undefined or epoly_tools_project_version < 0.815 then
(
    epoly_tools_project_version = 0.815
)

struct TwoEdgeVerts_v
(
    file_version = 0.61,
    project_version = 0.815,
    ignore_border_corners = true,
    right_angle_dot_tolerance = 0.017452406,
    straight_pair_dot_limit = -0.999847695,
    manual_remove_node = undefined,
    manual_remove_modifier = undefined,
    manual_remove_target_type = undefined,
    manual_remove_vertex_ids = #(),
    manual_remove_candidate_id = 0,

    /*
    Forces an Editable Poly or Edit Poly target to normal component-selection mode.
    The tool never uses selectMode 1.
    */
    function forceSelectModeZero poly_target =
    (
        if poly_target == undefined then return false

        try(poly_target.selectMode = 0)catch()
        try(poly_target.showCage = false)catch()
        true
        -- return
    ),

    /*
    Returns true when the supplied Edit Poly modifier belongs to the selected node.
    This prevents selecting IDs on an unrelated modifier instance.
    */
    function modifierBelongsToNode node modifier =
    (
        if node == undefined or modifier == undefined then return false
        if not(isValidNode node) then return false
        if classOf modifier != Edit_Poly then return false

        for modifier_index = 1 to node.modifiers.count do
        (
            if node.modifiers[modifier_index] == modifier then return true
        )

        false
        -- return
    ),

    /*
    Returns the first existing Edit Poly modifier on one node.
    This is used only for multi-object processing when only one modifier can be current in the Modify panel.
    */
    function getExistingEditPolyModifier node =
    (
        if node == undefined or not(isValidNode node) then return undefined

        for modifier_index = 1 to node.modifiers.count do
        (
            modifier = node.modifiers[modifier_index]
            if classOf modifier == Edit_Poly then return modifier
        )

        undefined
        -- return
    ),

    /*
    Resolves the topology that receives selection on one node.
    Single-object behavior is unchanged; multi-object mode may resolve an existing Edit Poly modifier even when it cannot already be current.
    */
    function getSelectionTarget node multi_object:false =
    (
        if node == undefined or not(isValidNode node) then return undefined

        current_object = try(modPanel.getCurrentObject())catch(undefined)

        if classOf current_object == Edit_Poly and modifierBelongsToNode node current_object then
        (
            return #(#EditPoly, current_object)
        )

        if multi_object then
        (
            existing_modifier = getExistingEditPolyModifier node
            if existing_modifier != undefined then return #(#EditPoly, existing_modifier)
        )

        if classOf node.baseObject == Editable_Poly then
        (
            return #(#EditablePoly, node.baseObject)
        )

        undefined
        -- return
    ),



    /*
    Returns the other endpoint of one Editable Poly edge for the supplied vertex.
    The edge and vertex IDs belong to the same Editable Poly topology.
    */
    function getOtherEditablePolyEdgeVertex poly_value edge_index vertex_index =
    (
        edge_vertices = polyop.getEdgeVerts poly_value edge_index
        if edge_vertices == undefined or edge_vertices.count != 2 then return 0

        if edge_vertices[1] == vertex_index then return edge_vertices[2]
        if edge_vertices[2] == vertex_index then return edge_vertices[1]

        0
        -- return
    ),

    /*
    Returns the visible incident edges for one Editable Poly vertex.
    Hidden triangulation/divider edges are intentionally excluded from degree tests.
    */
    function getVisibleEditablePolyEdgesUsingVert poly_value vertex_index =
    (
        if poly_value == undefined then return #{}

        incident_edges = polyop.getEdgesUsingVert poly_value #{vertex_index}
        visible_edges = #{}
        visible_edges.count = polyop.getNumEdges poly_value

        for edge_index in incident_edges do
        (
            if polyop.getEdgeVis poly_value edge_index then visible_edges[edge_index] = true
        )

        visible_edges
        -- return
    ),

    /*
    Returns true only for a degree-two Editable Poly border vertex whose two visible open edges form a right angle.
    Hidden triangulation/divider edges do not participate in this optional corner filter.
    */
    function isEditablePolyBorderCorner node vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false

        poly_value = node.baseObject
        incident_edges = getVisibleEditablePolyEdgesUsingVert poly_value vertex_index
        if incident_edges.numberSet != 2 then return false

        open_edges = polyop.getOpenEdges poly_value
        border_edges = copy incident_edges
        border_edges *= open_edges
        if border_edges.numberSet != 2 then return false

        edge_array = border_edges as array
        other_vertex_a = getOtherEditablePolyEdgeVertex poly_value edge_array[1] vertex_index
        other_vertex_b = getOtherEditablePolyEdgeVertex poly_value edge_array[2] vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 then return false

        vertex_position = polyop.getVert poly_value vertex_index
        position_a = polyop.getVert poly_value other_vertex_a
        position_b = polyop.getVert poly_value other_vertex_b

        vector_a = position_a - vertex_position
        vector_b = position_b - vertex_position
        if length vector_a <= 0.000001 or length vector_b <= 0.000001 then return false

        vector_a = normalize vector_a
        vector_b = normalize vector_b

        abs(dot vector_a vector_b) <= right_angle_dot_tolerance
        -- return
    ),

    /*
    Returns true when one Edit Poly edge is a border edge with only one valid adjacent face.
    The edge is read directly from the same Edit Poly modifier topology being filtered.
    */
    function isEditPolyBorderEdge node modifier edge_index =
    (
        face_a = try(EditPolyMod.GetEdgeFace modifier edge_index 1 node:node)catch(0)
        face_b = try(EditPolyMod.GetEdgeFace modifier edge_index 2 node:node)catch(0)

        face_a_missing = true
        face_b_missing = true

        if face_a != undefined then face_a_missing = face_a < 1
        if face_b != undefined then face_b_missing = face_b < 1

        face_a_missing != face_b_missing
        -- return
    ),

    /*
    Returns the other endpoint of one Edit Poly edge for the supplied vertex.
    The edge and vertex IDs belong to the same active Edit Poly modifier topology.
    */
    function getOtherEditPolyEdgeVertex node modifier edge_index vertex_index =
    (
        vertex_a = EditPolyMod.GetEdgeVertex modifier edge_index 1 node:node
        vertex_b = EditPolyMod.GetEdgeVertex modifier edge_index 2 node:node

        if vertex_a == vertex_index then return vertex_b
        if vertex_b == vertex_index then return vertex_a

        0
        -- return
    ),

    /*
    Returns all visible polygon-boundary edges in the active Edit Poly modifier topology.
    Face-side edges are visible polygon edges; hidden triangulation edges are intentionally excluded.
    */
    function getVisibleEditPolyEdges node modifier =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if modifier == undefined or classOf modifier != Edit_Poly then return #{}

        edge_count = EditPolyMod.GetNumEdges modifier node:node
        visible_edges = #{}
        visible_edges.count = edge_count

        face_count = EditPolyMod.GetNumFaces modifier node:node
        for face_index = 1 to face_count do
        (
            face_degree = EditPolyMod.GetFaceDegree modifier face_index node:node
            for side_index = 1 to face_degree do
            (
                edge_index = EditPolyMod.GetFaceEdge modifier face_index side_index node:node
                if edge_index >= 1 and edge_index <= edge_count then visible_edges[edge_index] = true
            )
        )

        visible_edges
        -- return
    ),

    /*
    Returns the visible polygon-boundary edges incident to one Edit Poly vertex.
    The optional visible-edge cache avoids rebuilding the face-boundary set for every vertex.
    */
    function getVisibleEditPolyEdgesUsingVert node modifier vertex_index visible_edges:undefined =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if modifier == undefined or classOf modifier != Edit_Poly then return #{}

        if visible_edges == undefined then visible_edges = getVisibleEditPolyEdges node modifier

        result_edges = #{}
        result_edges.count = visible_edges.count
        incident_count = EditPolyMod.GetVertexEdgeCount modifier vertex_index node:node

        for incident_index = 1 to incident_count do
        (
            edge_index = EditPolyMod.GetVertexEdge modifier vertex_index incident_index node:node
            if edge_index >= 1 and edge_index <= visible_edges.count then
            (
                if visible_edges[edge_index] then result_edges[edge_index] = true
            )
        )

        result_edges
        -- return
    ),

    /*
    Returns true only when the evaluated TriMesh contains this exact endpoint pair as a visible edge.
    Endpoint positions identify the live Edit Poly edge without transferring TriMesh edge IDs into Edit Poly topology.
    */
    function isSnapshotVisibleEdgeBetweenPositions snapshot_mesh position_a position_b tolerance:0.0001 =
    (
        if snapshot_mesh == undefined then return false

        face_count = getNumFaces snapshot_mesh

        for face_index = 1 to face_count do
        (
            face_vertices = getFace snapshot_mesh face_index

            for edge_slot = 1 to 3 do
            (
                if getEdgeVis snapshot_mesh face_index edge_slot then
                (
                    case edge_slot of
                    (
                        1:
                        (
                            snapshot_vertex_a = face_vertices.x
                            snapshot_vertex_b = face_vertices.y
                        )
                        2:
                        (
                            snapshot_vertex_a = face_vertices.y
                            snapshot_vertex_b = face_vertices.z
                        )
                        3:
                        (
                            snapshot_vertex_a = face_vertices.z
                            snapshot_vertex_b = face_vertices.x
                        )
                    )

                    snapshot_position_a = getVert snapshot_mesh snapshot_vertex_a
                    snapshot_position_b = getVert snapshot_mesh snapshot_vertex_b

                    direct_match = distance snapshot_position_a position_a <= tolerance and distance snapshot_position_b position_b <= tolerance
                    reverse_match = distance snapshot_position_a position_b <= tolerance and distance snapshot_position_b position_a <= tolerance

                    if direct_match or reverse_match then return true
                )
            )
        )

        false
        -- return
    ),

    /*
    Returns live Edit Poly neighbor vertex IDs connected to the source by edges that are actually visible in the evaluated mesh.
    Hidden/invisible triangulation or polygon edges are rejected even when EditPolyMod reports them as incident topology edges.
    */
    function getActuallyVisibleEditPolyNeighborVerts node modifier source_vertex tolerance:0.0001 =
    (
        if node == undefined or not(isValidNode node) then return #()
        if modifier == undefined or classOf modifier != Edit_Poly then return #()
        if not(modifierBelongsToNode node modifier) then return #()

        vertex_count = EditPolyMod.GetNumVertices modifier node:node
        if source_vertex < 1 or source_vertex > vertex_count then return #()

        update node
        snapshot_mesh = try(snapshotAsMesh node)catch(undefined)
        if snapshot_mesh == undefined then return #()

        source_position = EditPolyMod.GetVertex modifier source_vertex node:node
        neighbor_vertices = #()
        incident_count = EditPolyMod.GetVertexEdgeCount modifier source_vertex node:node

        for incident_index = 1 to incident_count do
        (
            edge_index = EditPolyMod.GetVertexEdge modifier source_vertex incident_index node:node
            neighbor_vertex = getOtherEditPolyEdgeVertex node modifier edge_index source_vertex

            if neighbor_vertex >= 1 and neighbor_vertex <= vertex_count then
            (
                neighbor_position = EditPolyMod.GetVertex modifier neighbor_vertex node:node

                if isSnapshotVisibleEdgeBetweenPositions snapshot_mesh source_position neighbor_position tolerance:tolerance then
                (
                    if findItem neighbor_vertices neighbor_vertex == 0 then append neighbor_vertices neighbor_vertex
                )
            )
        )

        delete snapshot_mesh
        neighbor_vertices
        -- return
    ),

    /*
    Returns true only for a degree-two Edit Poly border vertex whose two visible border edges form a right angle.
    Detection and filtering both use the same active Edit Poly modifier topology.
    */
    function isEditPolyBorderCorner node modifier vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined or classOf modifier != Edit_Poly then return false

        incident_edges = getVisibleEditPolyEdgesUsingVert node modifier vertex_index
        if incident_edges.numberSet != 2 then return false

        edge_array = incident_edges as array
        edge_a = edge_array[1]
        edge_b = edge_array[2]
        if edge_a < 1 or edge_b < 1 then return false

        if not(isEditPolyBorderEdge node modifier edge_a) then return false
        if not(isEditPolyBorderEdge node modifier edge_b) then return false

        other_vertex_a = getOtherEditPolyEdgeVertex node modifier edge_a vertex_index
        other_vertex_b = getOtherEditPolyEdgeVertex node modifier edge_b vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 then return false

        vertex_position = EditPolyMod.GetVertex modifier vertex_index node:node
        position_a = EditPolyMod.GetVertex modifier other_vertex_a node:node
        position_b = EditPolyMod.GetVertex modifier other_vertex_b node:node

        vector_a = position_a - vertex_position
        vector_b = position_b - vertex_position
        if length vector_a <= 0.000001 or length vector_b <= 0.000001 then return false

        vector_a = normalize vector_a
        vector_b = normalize vector_b

        abs(dot vector_a vector_b) <= right_angle_dot_tolerance
        -- return
    ),

    /*
    Returns true when one Editable Poly vertex is a topology T-junction.
    A T-junction has exactly three incident edges and at least one opposite straight-through edge pair.
    */
    function isEditablePolyTJunction node vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false

        poly_value = node.baseObject
        incident_edges = polyop.getEdgesUsingVert poly_value #{vertex_index}
        if incident_edges.numberSet != 3 then return false

        edge_array = incident_edges as array
        other_vertex_a = getOtherEditablePolyEdgeVertex poly_value edge_array[1] vertex_index
        other_vertex_b = getOtherEditablePolyEdgeVertex poly_value edge_array[2] vertex_index
        other_vertex_c = getOtherEditablePolyEdgeVertex poly_value edge_array[3] vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 or other_vertex_c < 1 then return false

        vertex_position = polyop.getVert poly_value vertex_index
        position_a = polyop.getVert poly_value other_vertex_a
        position_b = polyop.getVert poly_value other_vertex_b
        position_c = polyop.getVert poly_value other_vertex_c

        vector_a = position_a - vertex_position
        vector_b = position_b - vertex_position
        vector_c = position_c - vertex_position
        if length vector_a <= 0.000001 or length vector_b <= 0.000001 or length vector_c <= 0.000001 then return false

        vector_a = normalize vector_a
        vector_b = normalize vector_b
        vector_c = normalize vector_c

        dot vector_a vector_b <= straight_pair_dot_limit or dot vector_a vector_c <= straight_pair_dot_limit or dot vector_b vector_c <= straight_pair_dot_limit
        -- return
    ),

    /*
    Returns true when one Edit Poly vertex is a topology T-junction.
    Detection uses only the same active Edit Poly modifier topology that will receive the selection.
    */
    function isEditPolyTJunction node modifier vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined or classOf modifier != Edit_Poly then return false

        edge_count = EditPolyMod.GetVertexEdgeCount modifier vertex_index node:node
        if edge_count != 3 then return false

        edge_a = EditPolyMod.GetVertexEdge modifier vertex_index 1 node:node
        edge_b = EditPolyMod.GetVertexEdge modifier vertex_index 2 node:node
        edge_c = EditPolyMod.GetVertexEdge modifier vertex_index 3 node:node
        if edge_a < 1 or edge_b < 1 or edge_c < 1 then return false

        other_vertex_a = getOtherEditPolyEdgeVertex node modifier edge_a vertex_index
        other_vertex_b = getOtherEditPolyEdgeVertex node modifier edge_b vertex_index
        other_vertex_c = getOtherEditPolyEdgeVertex node modifier edge_c vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 or other_vertex_c < 1 then return false

        vertex_position = EditPolyMod.GetVertex modifier vertex_index node:node
        position_a = EditPolyMod.GetVertex modifier other_vertex_a node:node
        position_b = EditPolyMod.GetVertex modifier other_vertex_b node:node
        position_c = EditPolyMod.GetVertex modifier other_vertex_c node:node

        vector_a = position_a - vertex_position
        vector_b = position_b - vertex_position
        vector_c = position_c - vertex_position
        if length vector_a <= 0.000001 or length vector_b <= 0.000001 or length vector_c <= 0.000001 then return false

        vector_a = normalize vector_a
        vector_b = normalize vector_b
        vector_c = normalize vector_c

        dot vector_a vector_b <= straight_pair_dot_limit or dot vector_a vector_c <= straight_pair_dot_limit or dot vector_b vector_c <= straight_pair_dot_limit
        -- return
    ),

    /*
    Finds topology T-junction vertices on an Editable Poly base object.
    Each result has exactly three incident edges and one straight-through edge pair.
    */
    function findTJunctionVertsOnEditablePoly node =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

        poly_value = node.baseObject
        vertex_count = polyop.getNumVerts poly_value
        candidate_bits = #{}
        candidate_bits.count = vertex_count

        for vertex_index = 1 to vertex_count do
        (
            if isEditablePolyTJunction node vertex_index then candidate_bits[vertex_index] = true
        )

        candidate_bits
        -- return
    ),

    /*
    Finds topology T-junction vertices on one existing Edit Poly modifier.
    The modifier is made current before topology queries, but sub-object mode is entered only when results exist.
    */
    function findTJunctionVertsOnEditPoly node modifier =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if modifier == undefined or classOf modifier != Edit_Poly then return #{}
        if not(modifierBelongsToNode node modifier) then return #{}

        select node
        max modify mode

        modifier.SetPrimaryNode node
        modifier.useStackSelection = false
        modifier.selectMode = 0
        modifier.showCage = false

        modPanel.setCurrentObject modifier node:node

        vertex_count = EditPolyMod.GetNumVertices modifier node:node
        if vertex_count < 1 then return #{}

        candidate_bits = #{}
        candidate_bits.count = vertex_count

        for vertex_index = 1 to vertex_count do
        (
            if isEditPolyTJunction node modifier vertex_index then candidate_bits[vertex_index] = true
        )

        candidate_bits
        -- return
    ),

    /*
    Counts incident visible topology edges on an Editable Poly base object.
    Hidden triangulation/divider edges are ignored; a vertex is a candidate only when its visible edge count is exactly two.
    */
    function findTwoEdgeVertsOnEditablePoly node =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

        poly_value = node.baseObject
        vertex_count = polyop.getNumVerts poly_value
        edge_count = polyop.getNumEdges poly_value
        edge_counts = for vertex_index = 1 to vertex_count collect 0

        for edge_index = 1 to edge_count do
        (
            if polyop.getEdgeVis poly_value edge_index then
            (
                edge_vertices = polyop.getEdgeVerts poly_value edge_index

                if edge_vertices != undefined and edge_vertices.count == 2 then
                (
                    vertex_a = edge_vertices[1]
                    vertex_b = edge_vertices[2]

                    if vertex_a >= 1 and vertex_a <= vertex_count then edge_counts[vertex_a] += 1
                    if vertex_b >= 1 and vertex_b <= vertex_count then edge_counts[vertex_b] += 1
                )
            )
        )

        candidate_bits = #{}
        candidate_bits.count = vertex_count

        for vertex_index = 1 to vertex_count do
        (
            if edge_counts[vertex_index] == 2 then
            (
                if ignore_border_corners then
                (
                    if not(isEditablePolyBorderCorner node vertex_index) then candidate_bits[vertex_index] = true
                )
                else
                (
                    candidate_bits[vertex_index] = true
                )
            )
        )

        candidate_bits
        -- return
    ),

    /*
    Detects two-visible-edge vertices from an evaluated TriMesh snapshot, then maps them back to the live Edit Poly modifier by object-space position.
    This avoids relying on EditPolyMod incident-edge counts, which can disagree with viewport-visible edge topology.
    */
    function findTwoEdgeVertsOnEditPoly node modifier =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if modifier == undefined or classOf modifier != Edit_Poly then return #{}
        if not(modifierBelongsToNode node modifier) then return #{}

        if getCommandPanelTaskMode() != #modify then
        (
            max modify mode
        )

        try(modifier.SetPrimaryNode node)catch()
        modifier.useStackSelection = false
        modifier.selectMode = 0
        modifier.showCage = false

        if modPanel.getCurrentObject() != modifier then
        (
            modPanel.setCurrentObject modifier node:node
        )

        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        modifier_vertex_count = EditPolyMod.GetNumVertices modifier node:node
        if modifier_vertex_count < 1 then return #{}

        snapshot_mesh = try(snapshotAsMesh node)catch(undefined)
        if snapshot_mesh == undefined then return #{}

        snapshot_vertex_count = getNumVerts snapshot_mesh
        snapshot_face_count = getNumFaces snapshot_mesh
        visible_neighbors = for vertex_index = 1 to snapshot_vertex_count collect #()
        edge_keys = #()
        edge_use_counts = #()

        for face_index = 1 to snapshot_face_count do
        (
            face_vertices = getFace snapshot_mesh face_index
            face_vertex_ids = #(face_vertices.x as integer, face_vertices.y as integer, face_vertices.z as integer)

            for edge_slot = 1 to 3 do
            (
                vertex_a = 0
                vertex_b = 0

                case edge_slot of
                (
                    1:
                    (
                        vertex_a = face_vertex_ids[1]
                        vertex_b = face_vertex_ids[2]
                    )
                    2:
                    (
                        vertex_a = face_vertex_ids[2]
                        vertex_b = face_vertex_ids[3]
                    )
                    3:
                    (
                        vertex_a = face_vertex_ids[3]
                        vertex_b = face_vertex_ids[1]
                    )
                )

                if vertex_a >= 1 and vertex_a <= snapshot_vertex_count and vertex_b >= 1 and vertex_b <= snapshot_vertex_count then
                (
                    min_vertex = if vertex_a < vertex_b then vertex_a else vertex_b
                    max_vertex = if vertex_a > vertex_b then vertex_a else vertex_b
                    edge_key = (min_vertex as string) + ":" + (max_vertex as string)
                    edge_key_index = findItem edge_keys edge_key

                    if edge_key_index == 0 then
                    (
                        append edge_keys edge_key
                        append edge_use_counts 1
                    )
                    else
                    (
                        edge_use_counts[edge_key_index] += 1
                    )

                    if getEdgeVis snapshot_mesh face_index edge_slot then
                    (
                        if findItem visible_neighbors[vertex_a] vertex_b == 0 then append visible_neighbors[vertex_a] vertex_b
                        if findItem visible_neighbors[vertex_b] vertex_a == 0 then append visible_neighbors[vertex_b] vertex_a
                    )
                )
            )
        )

        snapshot_candidate_indices = #()

        for snapshot_vertex_index = 1 to snapshot_vertex_count do
        (
            if visible_neighbors[snapshot_vertex_index].count == 2 then
            (
                ignore_candidate = false

                if ignore_border_corners then
                (
                    neighbor_a = visible_neighbors[snapshot_vertex_index][1]
                    neighbor_b = visible_neighbors[snapshot_vertex_index][2]

                    edge_min_a = if snapshot_vertex_index < neighbor_a then snapshot_vertex_index else neighbor_a
                    edge_max_a = if snapshot_vertex_index > neighbor_a then snapshot_vertex_index else neighbor_a
                    edge_min_b = if snapshot_vertex_index < neighbor_b then snapshot_vertex_index else neighbor_b
                    edge_max_b = if snapshot_vertex_index > neighbor_b then snapshot_vertex_index else neighbor_b
                    edge_key_a = (edge_min_a as string) + ":" + (edge_max_a as string)
                    edge_key_b = (edge_min_b as string) + ":" + (edge_max_b as string)
                    edge_key_index_a = findItem edge_keys edge_key_a
                    edge_key_index_b = findItem edge_keys edge_key_b

                    border_a = edge_key_index_a > 0 and edge_use_counts[edge_key_index_a] == 1
                    border_b = edge_key_index_b > 0 and edge_use_counts[edge_key_index_b] == 1

                    if border_a and border_b then
                    (
                        vertex_position = getVert snapshot_mesh snapshot_vertex_index
                        position_a = getVert snapshot_mesh neighbor_a
                        position_b = getVert snapshot_mesh neighbor_b
                        vector_a = position_a - vertex_position
                        vector_b = position_b - vertex_position

                        if length vector_a > 0.000001 and length vector_b > 0.000001 then
                        (
                            vector_a = normalize vector_a
                            vector_b = normalize vector_b
                            ignore_candidate = abs(dot vector_a vector_b) <= right_angle_dot_tolerance
                        )
                    )
                )

                if not(ignore_candidate) then append snapshot_candidate_indices snapshot_vertex_index
            )
        )

        candidate_bits = #{}
        candidate_bits.count = modifier_vertex_count
        position_tolerance = 0.0001

        for snapshot_vertex_index in snapshot_candidate_indices do
        (
            snapshot_position = getVert snapshot_mesh snapshot_vertex_index
            best_modifier_vertex = 0
            best_distance = 1.0e30

            for modifier_vertex_index = 1 to modifier_vertex_count do
            (
                if not(candidate_bits[modifier_vertex_index]) then
                (
                    modifier_position = EditPolyMod.GetVertex modifier modifier_vertex_index node:node
                    position_distance = distance snapshot_position modifier_position

                    if position_distance < best_distance then
                    (
                        best_distance = position_distance
                        best_modifier_vertex = modifier_vertex_index
                    )
                )
            )

            if best_modifier_vertex > 0 and best_distance <= position_tolerance then
            (
                candidate_bits[best_modifier_vertex] = true
            )
        )

        delete snapshot_mesh

        format "Two Edge Verts DETECT | node:% | target:#EditPoly | snapshotCandidates:% | mapped:%\n" node.name snapshot_candidate_indices candidate_bits

        candidate_bits
        -- return
    ),

    /*
    Selects vertices on an Editable Poly base object using only polyop.
    Multi-object mode writes the selection directly and deliberately does not enter sub-object mode.
    */
    function selectEditablePolyVerts node vertex_bits enter_subobject:true =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false

        if enter_subobject then
        (
            select node
            max modify mode

            poly_value = node.baseObject
            forceSelectModeZero poly_value
            try(modPanel.setCurrentObject poly_value)catch()

            polyop.setVertSelection poly_value vertex_bits
            subObjectLevel = 1
            update node
            completeRedraw()
        )
        else
        (
            poly_value = node.baseObject
            forceSelectModeZero poly_value
            polyop.setVertSelection poly_value vertex_bits
            update node
        )

        actual_selection = polyop.getVertSelection poly_value
        actual_selection == vertex_bits
        -- return
    ),

    /*
    Selects vertices on the active Edit Poly modifier using the proven EPoly Basics 0.33 sequence.
    The current modifier is activated first, then its stored Vertex selection is replaced and verified.
    */
    function selectEditPolyVerts node modifier vertex_bits =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined or classOf modifier != Edit_Poly then return false

        select node

        if getCommandPanelTaskMode() != #modify then
        (
            max modify mode
        )

        try(modifier.SetPrimaryNode node)catch()
        modifier.useStackSelection = false
        modifier.selectMode = 0
        modifier.showCage = false

        if modPanel.getCurrentObject() != modifier then
        (
            modPanel.setCurrentObject modifier node:node
        )

        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        old_vertices = modifier.GetSelection #Vertex
        if old_vertices == undefined then old_vertices = #{}

        if old_vertices.numberSet > 0 then
        (
            modifier.Select #Vertex old_vertices select:false
        )

        modifier.Select #Vertex vertex_bits select:true
        stored_selection = modifier.GetSelection #Vertex
        if stored_selection == undefined then stored_selection = #{}

        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1
        modifier.RefreshScreen()
        completeRedraw()

        format "Two Edge Verts | Edit Poly requested:% stored:% level:#Vertex subObjectLevel:%\n" vertex_bits stored_selection subObjectLevel

        stored_selection == vertex_bits
        -- return
    ),

    /*
    Returns the two visible neighboring vertices of one Editable Poly vertex.
    The result follows the same visible-edge topology used by the stable two-edge detector.
    */
    function getEditablePolyVisibleNeighborVerts poly_value vertex_index =
    (
        if poly_value == undefined then return #()

        neighbor_vertices = #()
        incident_edges = getVisibleEditablePolyEdgesUsingVert poly_value vertex_index

        for edge_index in incident_edges do
        (
            other_vertex = getOtherEditablePolyEdgeVertex poly_value edge_index vertex_index

            if other_vertex > 0 and findItem neighbor_vertices other_vertex == 0 then
            (
                append neighbor_vertices other_vertex
            )
        )

        neighbor_vertices
        -- return
    ),

    /*
    Returns the closest Editable Poly vertex connected to the source by an actually visible edge.
    Distance is measured between live object-space vertex positions; equal distances resolve to the lower vertex ID.
    */
    function getClosestEditablePolyVisibleNeighborVert poly_value source_vertex =
    (
        if poly_value == undefined then return 0

        vertex_count = polyop.getNumVerts poly_value
        if source_vertex < 1 or source_vertex > vertex_count then return 0

        neighbor_vertices = getEditablePolyVisibleNeighborVerts poly_value source_vertex
        if neighbor_vertices.count < 1 then return 0

        source_position = polyop.getVert poly_value source_vertex
        closest_vertex = 0
        closest_distance = 0.0

        for neighbor_vertex in neighbor_vertices do
        (
            if neighbor_vertex >= 1 and neighbor_vertex <= vertex_count then
            (
                neighbor_position = polyop.getVert poly_value neighbor_vertex
                neighbor_distance = distance source_position neighbor_position

                if closest_vertex == 0 or neighbor_distance < closest_distance or (neighbor_distance == closest_distance and neighbor_vertex < closest_vertex) then
                (
                    closest_vertex = neighbor_vertex
                    closest_distance = neighbor_distance
                )
            )
        )

        closest_vertex
        -- return
    ),

    /*
    Returns the closest Edit Poly vertex connected to the source by an actually visible edge.
    Distance is measured between live modifier vertex positions; equal distances resolve to the lower vertex ID.
    */
    function getClosestEditPolyVisibleNeighborVert node modifier source_vertex =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or classOf modifier != Edit_Poly then return 0
        if not(modifierBelongsToNode node modifier) then return 0

        vertex_count = EditPolyMod.GetNumVertices modifier node:node
        if source_vertex < 1 or source_vertex > vertex_count then return 0

        neighbor_vertices = getActuallyVisibleEditPolyNeighborVerts node modifier source_vertex
        if neighbor_vertices.count < 1 then return 0

        source_position = EditPolyMod.GetVertex modifier source_vertex node:node
        closest_vertex = 0
        closest_distance = 0.0

        for neighbor_vertex in neighbor_vertices do
        (
            if neighbor_vertex >= 1 and neighbor_vertex <= vertex_count then
            (
                neighbor_position = EditPolyMod.GetVertex modifier neighbor_vertex node:node
                neighbor_distance = distance source_position neighbor_position

                if closest_vertex == 0 or neighbor_distance < closest_distance or (neighbor_distance == closest_distance and neighbor_vertex < closest_vertex) then
                (
                    closest_vertex = neighbor_vertex
                    closest_distance = neighbor_distance
                )
            )
        )

        closest_vertex
        -- return
    ),

    /*
    Returns the neighboring vertices of one Edit Poly vertex.
    The result is read directly from the same Edit Poly modifier topology used by RMB removal.
    */
    function getEditPolyNeighborVerts node modifier vertex_index =
    (
        if node == undefined or not(isValidNode node) then return #()
        if modifier == undefined or classOf modifier != Edit_Poly then return #()

        neighbor_vertices = #()
        edge_count = EditPolyMod.GetVertexEdgeCount modifier vertex_index node:node

        for edge_slot = 1 to edge_count do
        (
            edge_index = EditPolyMod.GetVertexEdge modifier vertex_index edge_slot node:node
            other_vertex = getOtherEditPolyEdgeVertex node modifier edge_index vertex_index

            if other_vertex > 0 and findItem neighbor_vertices other_vertex == 0 then
            (
                append neighbor_vertices other_vertex
            )
        )

        neighbor_vertices
        -- return
    ),

    /*
    Returns the current Editable Poly vertex closest to the supplied object-space position.
    Position lookup keeps RMB stable after Remove Vertex renumbers topology IDs.
    */
    function findEditablePolyVertexByPosition poly_value target_position tolerance:0.0001 =
    (
        if poly_value == undefined then return 0

        vertex_count = polyop.getNumVerts poly_value
        best_vertex = 0
        best_distance = tolerance

        for vertex_index = 1 to vertex_count do
        (
            vertex_position = polyop.getVert poly_value vertex_index
            vertex_distance = length (vertex_position - target_position)

            if vertex_distance <= best_distance then
            (
                best_distance = vertex_distance
                best_vertex = vertex_index
            )
        )

        best_vertex
        -- return
    ),

    /*
    Returns the current Edit Poly vertex closest to the supplied object-space position.
    Position lookup keeps RMB stable after Remove Vertex changes modifier topology IDs.
    */
    function findEditPolyVertexByPosition node modifier target_position tolerance:0.0001 =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or classOf modifier != Edit_Poly then return 0

        vertex_count = EditPolyMod.GetNumVertices modifier node:node
        best_vertex = 0
        best_distance = tolerance

        for vertex_index = 1 to vertex_count do
        (
            vertex_position = EditPolyMod.GetVertex modifier vertex_index node:node
            vertex_distance = length (vertex_position - target_position)

            if vertex_distance <= best_distance then
            (
                best_distance = vertex_distance
                best_vertex = vertex_index
            )
        )

        best_vertex
        -- return
    ),

    /*
    Returns true when the supplied position still belongs to the remaining RMB target list.
    A small tolerance is used because topology operations can introduce minor float noise.
    */
    function positionIsRemovalTarget target_positions test_position tolerance:0.0001 =
    (
        for position_index = 1 to target_positions.count do
        (
            if length (target_positions[position_index] - test_position) <= tolerance then return true
        )

        false
        -- return
    ),

    /*
    Finds the current Editable Poly edge connecting two vertices.
    Edge identity is resolved from endpoint vertices instead of trusting stale edge indices.
    */
    function findEditablePolyEdgeBetweenVerts poly_value vertex_a vertex_b =
    (
        if poly_value == undefined then return 0
        if vertex_a < 1 or vertex_b < 1 then return 0

        incident_edges = polyop.getEdgesUsingVert poly_value #{vertex_a}

        for edge_index in incident_edges do
        (
            edge_vertices = polyop.getEdgeVerts poly_value edge_index

            if edge_vertices != undefined and edge_vertices.count == 2 then
            (
                if (edge_vertices[1] == vertex_a and edge_vertices[2] == vertex_b) or (edge_vertices[1] == vertex_b and edge_vertices[2] == vertex_a) then
                (
                    return edge_index
                )
            )
        )

        0
        -- return
    ),

    /*
    Finds the current Edit Poly edge connecting two vertices.
    Edge identity is resolved from endpoint vertices on the live modifier topology.
    */
    function findEditPolyEdgeBetweenVerts node modifier vertex_a vertex_b =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or classOf modifier != Edit_Poly then return 0
        if vertex_a < 1 or vertex_b < 1 then return 0

        edge_count = EditPolyMod.GetVertexEdgeCount modifier vertex_a node:node

        for edge_slot = 1 to edge_count do
        (
            edge_index = EditPolyMod.GetVertexEdge modifier vertex_a edge_slot node:node
            edge_vertex_a = EditPolyMod.GetEdgeVertex modifier edge_index 1 node:node
            edge_vertex_b = EditPolyMod.GetEdgeVertex modifier edge_index 2 node:node

            if (edge_vertex_a == vertex_a and edge_vertex_b == vertex_b) or (edge_vertex_a == vertex_b and edge_vertex_b == vertex_a) then
            (
                return edge_index
            )
        )

        0
        -- return
    ),

    /*
    Returns current valid Editable Poly target vertices by matching the original object-space positions.
    The stable two-edge detector is rerun every pass so topology renumbering never carries stale vertex IDs forward.
    */
    function resolveEditablePolyTargetsByPosition node target_positions tolerance:0.0001 =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

        poly_value = node.baseObject
        valid_bits = findTwoEdgeVertsOnEditablePoly node
        resolved_bits = #{}

        for target_position in target_positions do
        (
            vertex_index = findEditablePolyVertexByPosition poly_value target_position tolerance:tolerance

            if vertex_index > 0 and valid_bits[vertex_index] then
            (
                resolved_bits[vertex_index] = true
            )
        )

        resolved_bits
        -- return
    ),

    /*
    Returns current valid Edit Poly target vertices by matching the original object-space positions.
    The stable two-edge detector is rerun every pass so topology renumbering never carries stale vertex IDs forward.
    */
    function resolveEditPolyTargetsByPosition node modifier target_positions tolerance:0.0001 =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if modifier == undefined or classOf modifier != Edit_Poly then return #{}

        valid_bits = findTwoEdgeVertsOnEditPoly node modifier
        resolved_bits = #{}

        for target_position in target_positions do
        (
            vertex_index = findEditPolyVertexByPosition node modifier target_position tolerance:tolerance

            if vertex_index > 0 and valid_bits[vertex_index] then
            (
                resolved_bits[vertex_index] = true
            )
        )

        resolved_bits
        -- return
    ),

    /*
    Resolves one current Edit Poly visible-edge neighbor through object-space positions instead of stale vertex IDs.
    The base Editable Poly supplies the viewport-visible edge, then the live modifier vertex is found again by position.
    */
    function getEditPolyVisibleNeighborByPosition node modifier current_vertex tolerance:0.0001 =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or classOf modifier != Edit_Poly then return 0
        if classOf node.baseObject != Editable_Poly then return 0

        current_position = EditPolyMod.GetVertex modifier current_vertex node:node
        base_value = node.baseObject
        base_vertex = findEditablePolyVertexByPosition base_value current_position tolerance:tolerance
        if base_vertex < 1 then return 0

        visible_edges = getVisibleEditablePolyEdgesUsingVert base_value base_vertex

        for edge_index in visible_edges do
        (
            base_neighbor = getOtherEditablePolyEdgeVertex base_value edge_index base_vertex

            if base_neighbor > 0 then
            (
                neighbor_position = polyop.getVert base_value base_neighbor
                modifier_neighbor = findEditPolyVertexByPosition node modifier neighbor_position tolerance:tolerance

                if modifier_neighbor > 0 and modifier_neighbor != current_vertex then
                (
                    return modifier_neighbor
                )
            )
        )

        0
        -- return
    ),

    /*
    Removes selected Editable Poly two-edge vertices by their original selected vertex IDs, highest ID to lowest.
    Each source ID is selected alone; pending lower selected IDs are protected from being chosen as weld targets.
    */
    function weldTwoEdgeEditablePolyVerts node vertex_bits =
    (
        if node == undefined or not(isValidNode node) then return 0
        if classOf node.baseObject != Editable_Poly then return 0
        if vertex_bits == undefined or vertex_bits.numberSet < 1 then return 0

        poly_value = node.baseObject
        forceSelectModeZero poly_value
        target_vertices = vertex_bits as array
        sort target_vertices
        welded_count = 0

        undo "Remove 2-Edge Verts" on
        (
            for target_index = target_vertices.count to 1 by -1 do
            (
                current_vertex = target_vertices[target_index]
                vertex_count = polyop.getNumVerts poly_value

                if current_vertex >= 1 and current_vertex <= vertex_count then
                (
                    single_vertex = #{current_vertex}
                    polyop.setVertSelection poly_value single_vertex
                    selected_bits = polyop.getVertSelection poly_value

                    if selected_bits == single_vertex then
                    (
                        pending_bits = #{}
                        pending_bits.count = vertex_count

                        if target_index > 1 then
                        (
                            for pending_index = 1 to (target_index - 1) do
                            (
                                pending_vertex = target_vertices[pending_index]
                                if pending_vertex >= 1 and pending_vertex <= vertex_count then pending_bits[pending_vertex] = true
                            )
                        )

                        neighbor_vertices = getEditablePolyVisibleNeighborVerts poly_value current_vertex
                        target_vertex = 0

                        for neighbor_vertex in neighbor_vertices while target_vertex == 0 do
                        (
                            neighbor_is_pending = false
                            if neighbor_vertex >= 1 and neighbor_vertex <= pending_bits.count then neighbor_is_pending = pending_bits[neighbor_vertex]

                            if not(neighbor_is_pending) then target_vertex = neighbor_vertex
                        )

                        if target_vertex > 0 then
                        (
                            target_vertex_position = polyop.getVert poly_value target_vertex
                            before_count = vertex_count

                            weld_ok = try
                            (
                                poly_value.weldVerts current_vertex target_vertex target_vertex_position
                            )
                            catch
                            (
                                false
                            )

                            update node

                            if weld_ok then
                            (
                                after_count = polyop.getNumVerts poly_value
                                if after_count < before_count then welded_count += (before_count - after_count)
                            )

                            format "Two Edge Verts RMB | Editable Poly | source:% | target:% | pending:% | welded:%\n" current_vertex target_vertex pending_bits (if weld_ok then 1 else 0)
                        )
                        else
                        (
                            format "Two Edge Verts RMB | Editable Poly | source:% | SKIP: no unprotected visible-edge target | pending:%\n" current_vertex pending_bits
                        )
                    )
                )
            )
        )

        polyop.setVertSelection poly_value #{}
        update node
        completeRedraw()

        welded_count
        -- return
    ),

    /*
    Removes selected Edit Poly two-edge vertices by their original selected vertex IDs, highest ID to lowest.
    Each source ID is selected alone; the weld target comes only from that source vertex's live visible polygon-boundary edges.
    */
    function weldTwoEdgeEditPolyVerts node modifier vertex_bits =
    (
        if node == undefined or not(isValidNode node) then return 0
        if modifier == undefined or classOf modifier != Edit_Poly then return 0
        if not(modifierBelongsToNode node modifier) then return 0
        if vertex_bits == undefined or vertex_bits.numberSet < 1 then return 0

        select node
        max modify mode

        modifier.SetPrimaryNode node
        modifier.useStackSelection = false
        modifier.selectMode = 0
        modifier.showCage = false

        modPanel.setCurrentObject modifier node:node
        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        target_vertices = vertex_bits as array
        sort target_vertices
        welded_count = 0

        undo "Remove 2-Edge Verts" on
        (
            for target_index = target_vertices.count to 1 by -1 do
            (
                current_vertex = target_vertices[target_index]
                vertex_count = EditPolyMod.GetNumVertices modifier node:node

                if current_vertex >= 1 and current_vertex <= vertex_count then
                (
                    current_selection = modifier.GetSelection #Vertex node:node
                    if current_selection == undefined then current_selection = #{}
                    if current_selection.numberSet > 0 then modifier.Select #Vertex current_selection select:false node:node

                    single_vertex = #{current_vertex}
                    modifier.Select #Vertex single_vertex select:true node:node
                    selected_bits = modifier.GetSelection #Vertex node:node

                    if selected_bits == single_vertex then
                    (
                        pending_bits = #{}
                        pending_bits.count = vertex_count

                        if target_index > 1 then
                        (
                            for pending_index = 1 to (target_index - 1) do
                            (
                                pending_vertex = target_vertices[pending_index]
                                if pending_vertex >= 1 and pending_vertex <= vertex_count then pending_bits[pending_vertex] = true
                            )
                        )

                        visible_edges = getVisibleEditPolyEdgesUsingVert node modifier current_vertex
                        target_vertex = 0

                        for edge_index in visible_edges while target_vertex == 0 do
                        (
                            neighbor_vertex = getOtherEditPolyEdgeVertex node modifier edge_index current_vertex

                            if neighbor_vertex > 0 then
                            (
                                neighbor_is_pending = false
                                if neighbor_vertex <= pending_bits.count then neighbor_is_pending = pending_bits[neighbor_vertex]

                                if not(neighbor_is_pending) then target_vertex = neighbor_vertex
                            )
                        )

                        if target_vertex > 0 then
                        (
                            source_vertex_position = EditPolyMod.GetVertex modifier current_vertex node:node
                            target_vertex_position = EditPolyMod.GetVertex modifier target_vertex node:node
                            move_amount = target_vertex_position - source_vertex_position
                            before_count = vertex_count

                            weld_ok = try
                            (
                                modifier.MoveSelection move_amount
                                modifier.Commit()
                                modifier.WeldVertices current_vertex target_vertex node:node
                                modifier.Commit()
                                true
                            )
                            catch
                            (
                                false
                            )

                            modifier.RefreshScreen()
                            update node

                            if weld_ok then
                            (
                                after_count = EditPolyMod.GetNumVertices modifier node:node
                                if after_count < before_count then welded_count += (before_count - after_count)
                            )

                            format "Two Edge Verts RMB | Edit Poly | source:% | target:% | pending:% | welded:%\n" current_vertex target_vertex pending_bits (if weld_ok then 1 else 0)
                        )
                        else
                        (
                            format "Two Edge Verts RMB | Edit Poly | source:% | SKIP: no unprotected visible-edge target | pending:%\n" current_vertex pending_bits
                        )
                    )
                )
            )
        )

        current_selection = modifier.GetSelection #Vertex node:node
        if current_selection == undefined then current_selection = #{}
        if current_selection.numberSet > 0 then modifier.Select #Vertex current_selection select:false node:node

        modifier.RefreshScreen()
        update node
        completeRedraw()

        welded_count
        -- return
    ),

    /*
    Clears the stored manual REMOVE VERT data and the currently armed candidate.
    SEARCH 2-EDGE VERTS LMB creates a fresh stored candidate list.
    */
    function resetManualRemoveState =
    (
        manual_remove_node = undefined
        manual_remove_modifier = undefined
        manual_remove_target_type = undefined
        manual_remove_vertex_ids = #()
        manual_remove_candidate_id = 0
        true
        -- return
    ),

    /*
    Removes one exact processed candidate ID from the stored manual queue.
    Queue state changes only after the matching geometry fix succeeds.
    */
    function removeStoredCandidateId vertex_id =
    (
        if vertex_id < 1 then return false
        if manual_remove_vertex_ids == undefined or manual_remove_vertex_ids.count < 1 then return false
        if (findItem manual_remove_vertex_ids vertex_id) < 1 then return false

        previous_count = manual_remove_vertex_ids.count
        remaining_ids = #()

        for stored_vertex_id in manual_remove_vertex_ids do
        (
            if stored_vertex_id != vertex_id then
            (
                append remaining_ids stored_vertex_id
            )
        )

        manual_remove_vertex_ids = remaining_ids

        if (findItem manual_remove_vertex_ids vertex_id) > 0 then return false
        manual_remove_vertex_ids.count == (previous_count - 1)
        -- return
    ),

    /*
    Selects exactly one Editable Poly vertex by its current live vertex ID.
    This is used by the manual REMOVE VERT stepper after each successful removal.
    */
    function selectManualEditablePolyVertex node vertex_id =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false

        poly_value = node.baseObject
        vertex_count = polyop.getNumVerts poly_value
        if vertex_id < 1 or vertex_id > vertex_count then return false

        single_vertex = #{}
        single_vertex[vertex_id] = true
        polyop.setVertSelection poly_value single_vertex
        update node
        completeRedraw()

        selected_bits = polyop.getVertSelection poly_value
        selected_bits == single_vertex
        -- return
    ),

    /*
    Selects exactly one Edit Poly vertex by its current live vertex ID.
    The modifier is made current so the next manual step is visible and ready in Vertex mode.
    */
    function selectManualEditPolyVertex node modifier vertex_id =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined or classOf modifier != Edit_Poly then return false
        if not(modifierBelongsToNode node modifier) then return false

        vertex_count = EditPolyMod.GetNumVertices modifier node:node
        if vertex_id < 1 or vertex_id > vertex_count then return false

        select node
        max modify mode

        modifier.SetPrimaryNode node
        modifier.useStackSelection = false
        modifier.selectMode = 0
        modifier.showCage = false
        modPanel.setCurrentObject modifier node:node
        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        current_selection = modifier.GetSelection #Vertex node:node
        if current_selection == undefined then current_selection = #{}
        if current_selection.numberSet > 0 then modifier.Select #Vertex current_selection select:false node:node

        single_vertex = #{}
        single_vertex[vertex_id] = true
        modifier.Select #Vertex single_vertex select:true node:node
        modifier.RefreshScreen()
        update node
        completeRedraw()

        selected_bits = modifier.GetSelection #Vertex node:node
        selected_bits == single_vertex
        -- return
    ),

    /*
    Removes one Editable Poly source vertex using the current stored source ID.
    The weld target is the closest vertex connected by an actually visible incident edge.
    */
    function removeOneManualEditablePolyVert node source_vertex protected_bits =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false

        poly_value = node.baseObject
        forceSelectModeZero poly_value
        vertex_count = polyop.getNumVerts poly_value
        if source_vertex < 1 or source_vertex > vertex_count then return false

        single_vertex = #{}
        single_vertex[source_vertex] = true
        polyop.setVertSelection poly_value single_vertex
        selected_bits = polyop.getVertSelection poly_value
        if selected_bits != single_vertex then return false

        target_vertex = getClosestEditablePolyVisibleNeighborVert poly_value source_vertex
        if target_vertex < 1 then return false

        target_position = polyop.getVert poly_value target_vertex
        before_count = vertex_count
        /*
        MNMesh weld keeps the first vertex and kills the second; target survives and source disappears.
        */
        weld_ok = try
        (
            poly_value.weldVerts target_vertex source_vertex target_position
        )
        catch
        (
            exception_text = getCurrentException()
            format "REMOVE VERT | Editable Poly | source:% | target:% | ERROR:%\n" source_vertex target_vertex exception_text
            false
        )

        update node
        after_count = polyop.getNumVerts poly_value
        removed_ok = weld_ok and after_count == (before_count - 1)

        format "REMOVE VERT | Editable Poly | source:% | target:% | removed:%\n" source_vertex target_vertex removed_ok
        removed_ok
        -- return
    ),

    /*
    Removes one Edit Poly source vertex using the current stored source ID.
    The source is explicitly selected and welds to the closest neighbor whose connecting edge is visible in the evaluated mesh.
    */
    function removeOneManualEditPolyVert node modifier source_vertex protected_bits =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined or classOf modifier != Edit_Poly then return false
        if not(modifierBelongsToNode node modifier) then return false

        select node
        max modify mode

        modifier.SetPrimaryNode node
        modifier.useStackSelection = false
        modifier.selectMode = 0
        modifier.showCage = false
        modPanel.setCurrentObject modifier node:node
        modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        vertex_count = EditPolyMod.GetNumVertices modifier node:node
        if source_vertex < 1 or source_vertex > vertex_count then return false

        current_selection = modifier.GetSelection #Vertex node:node
        if current_selection == undefined then current_selection = #{}
        if current_selection.numberSet > 0 then modifier.Select #Vertex current_selection select:false node:node

        single_vertex = #{}
        single_vertex[source_vertex] = true
        modifier.Select #Vertex single_vertex select:true node:node
        selected_bits = modifier.GetSelection #Vertex node:node
        if selected_bits != single_vertex then return false

        target_vertex = getClosestEditPolyVisibleNeighborVert node modifier source_vertex
        if target_vertex < 1 then return false

        source_position = EditPolyMod.GetVertex modifier source_vertex node:node
        target_position = EditPolyMod.GetVertex modifier target_vertex node:node
        move_amount = target_position - source_position
        before_count = vertex_count

        weld_ok = try
        (
            modifier.MoveSelection move_amount
            modifier.Commit()
            /*
            Edit Poly uses the same endpoint ownership: first survives and second is killed.
            */
            modifier.WeldVertices target_vertex source_vertex node:node
            modifier.Commit()
            true
        )
        catch
        (
            exception_text = getCurrentException()
            format "REMOVE VERT | Edit Poly | source:% | target:% | ERROR:%\n" source_vertex target_vertex exception_text
            false
        )

        modifier.RefreshScreen()
        update node
        after_count = EditPolyMod.GetNumVertices modifier node:node
        removed_ok = weld_ok and after_count == (before_count - 1)

        format "REMOVE VERT | Edit Poly | source:% | target:% | removed:%\n" source_vertex target_vertex removed_ok
        removed_ok
        -- return
    ),

    /*
    Captures the currently selected valid two-edge vertex IDs as persistent manual REMOVE VERT data.
    IDs are stored ascending so the highest remaining ID is always the last item and is processed first.
    */
    function initializeManualRemoveState node target_type target_value =
    (
        if node == undefined or not(isValidNode node) then return false

        selected_bits = #{}
        valid_bits = #{}

        if target_type == #EditPoly then
        (
            selected_bits = target_value.GetSelection #Vertex node:node
            if selected_bits == undefined then selected_bits = #{}
            valid_bits = findTwoEdgeVertsOnEditPoly node target_value
        )
        else if target_type == #EditablePoly then
        (
            selected_bits = polyop.getVertSelection node.baseObject
            valid_bits = findTwoEdgeVertsOnEditablePoly node
        )
        else
        (
            return false
        )

        stored_bits = selected_bits * valid_bits
        if stored_bits.numberSet < 1 then return false

        manual_remove_node = node
        manual_remove_target_type = target_type
        manual_remove_modifier = if target_type == #EditPoly then target_value else undefined
        manual_remove_vertex_ids = stored_bits as array
        sort manual_remove_vertex_ids
        manual_remove_candidate_id = 0

        format "REMOVE VERT DATA | node:% | target:% | ids:%\n" node.name target_type manual_remove_vertex_ids
        true
        -- return
    ),

    /*
    Stores the vertex data created by SEARCH 2-EDGE VERTS LMB for one active object.
    Manual REMOVE VERT intentionally supports one object so every stored vertex ID belongs to one live topology target.
    */
    function storeManualRemoveStateFromCurrentSelection =
    (
        this.resetManualRemoveState()

        if selection.count != 1 then
        (
            format "REMOVE VERT DATA | Manual mode requires exactly one selected object.\n"
            return false
        )

        node = selection[1]
        if node == undefined or not(isValidNode node) then return false

        target = getSelectionTarget node multi_object:false
        if target == undefined then return false

        stored_ok = this.initializeManualRemoveState node target[1] target[2]

        if not(stored_ok) then
        (
            format "REMOVE VERT DATA | No selected valid 2-edge vertices were stored.\n"
        )

        stored_ok
        -- return
    ),

    /*
    Checks only that the persistent manual REMOVE VERT data still belongs to the active object and topology target.
    Component selection is deliberately ignored because REMOVE VERT LMB owns candidate selection separately.
    */
    function manualRemoveContextMatches node target_type target_value =
    (
        if manual_remove_node == undefined or not(isValidNode manual_remove_node) then return false
        if manual_remove_node != node then return false
        if manual_remove_target_type != target_type then return false
        if manual_remove_vertex_ids == undefined or manual_remove_vertex_ids.count < 1 then return false
        if target_type == #EditPoly and manual_remove_modifier != target_value then return false

        true
        -- return
    ),

    /*
    Returns true only when the supplied stored candidate ID is the one and only selected vertex.
    RMB uses this guard so it cannot fix a different vertex than the candidate armed by REMOVE VERT LMB.
    */
    function isManualRemoveCandidateSelected node target_type target_value candidate_id =
    (
        if candidate_id < 1 then return false

        expected_bits = #{}
        expected_bits[candidate_id] = true

        if target_type == #EditPoly then
        (
            selected_bits = target_value.GetSelection #Vertex node:node
            if selected_bits == undefined then selected_bits = #{}
            return selected_bits == expected_bits
        )

        if target_type == #EditablePoly then
        (
            selected_bits = polyop.getVertSelection node.baseObject
            return selected_bits == expected_bits
        )

        false
        -- return
    ),

    /*
    Selects the highest-ID candidate still present in the stored manual data without modifying that data.
    This is the LMB half of the manual REMOVE VERT workflow and performs no geometry change.
    */
    function selectNextManualRemoveCandidate =
    (
        if selection.count != 1 then
        (
            format "REMOVE VERT LMB | Select the object whose 2-edge data was stored.\n"
            return false
        )

        node = selection[1]
        if node == undefined or not(isValidNode node) then return false

        target = getSelectionTarget node multi_object:false
        if target == undefined then return false

        target_type = target[1]
        target_value = target[2]

        if not(this.manualRemoveContextMatches node target_type target_value) then
        (
            format "REMOVE VERT LMB | No stored 2-edge data for this object. Run SEARCH 2-EDGE VERTS LMB first.\n"
            return false
        )

        candidate_id = manual_remove_vertex_ids[manual_remove_vertex_ids.count]
        selected_ok = false

        if target_type == #EditPoly then
        (
            selected_ok = this.selectManualEditPolyVertex node target_value candidate_id
        )
        else if target_type == #EditablePoly then
        (
            selected_ok = this.selectManualEditablePolyVertex node candidate_id
        )

        if selected_ok then
        (
            manual_remove_candidate_id = candidate_id
            format "REMOVE VERT LMB | candidate:% | remaining:%\n" candidate_id manual_remove_vertex_ids
        )
        else
        (
            manual_remove_candidate_id = 0
            format "REMOVE VERT LMB | candidate ID % could not be selected.\n" candidate_id
        )

        selected_ok
        -- return
    ),

    /*
    Fixes only the candidate previously armed by REMOVE VERT LMB and removes its ID from stored data after success.
    No next candidate is selected automatically; the next REMOVE VERT LMB explicitly advances the manual workflow.
    */
    function fixManualRemoveCandidate =
    (
        if selection.count != 1 then
        (
            format "REMOVE VERT RMB | Select the object whose candidate is armed.\n"
            return false
        )

        node = selection[1]
        if node == undefined or not(isValidNode node) then return false

        target = getSelectionTarget node multi_object:false
        if target == undefined then return false

        target_type = target[1]
        target_value = target[2]

        if not(this.manualRemoveContextMatches node target_type target_value) then
        (
            format "REMOVE VERT RMB | Stored data does not match the active object.\n"
            return false
        )

        if manual_remove_candidate_id < 1 then
        (
            format "REMOVE VERT RMB | No candidate armed. Use REMOVE VERT LMB first.\n"
            return false
        )

        source_vertex = manual_remove_candidate_id
        expected_vertex = manual_remove_vertex_ids[manual_remove_vertex_ids.count]

        if source_vertex != expected_vertex then
        (
            format "REMOVE VERT RMB | Armed candidate % is not the highest stored ID %. Use REMOVE VERT LMB again.\n" source_vertex expected_vertex
            manual_remove_candidate_id = 0
            return false
        )

        if not(this.isManualRemoveCandidateSelected node target_type target_value source_vertex) then
        (
            format "REMOVE VERT RMB | Candidate % is not the only selected vertex. Nothing changed.\n" source_vertex
            return false
        )

        protected_bits = #{}

        if target_type == #EditPoly then
        (
            protected_bits.count = EditPolyMod.GetNumVertices target_value node:node
        )
        else
        (
            protected_bits.count = polyop.getNumVerts node.baseObject
        )

        if manual_remove_vertex_ids.count > 1 then
        (
            for queue_index = 1 to (manual_remove_vertex_ids.count - 1) do
            (
                pending_vertex = manual_remove_vertex_ids[queue_index]

                if pending_vertex >= 1 and pending_vertex <= protected_bits.count then
                (
                    protected_bits[pending_vertex] = true
                )
            )
        )

        removed_ok = false

        undo "Remove One 2-Edge Vert" on
        (
            if target_type == #EditPoly then
            (
                removed_ok = this.removeOneManualEditPolyVert node target_value source_vertex protected_bits
            )
            else if target_type == #EditablePoly then
            (
                removed_ok = this.removeOneManualEditablePolyVert node source_vertex protected_bits
            )

            if removed_ok then
            (
                queue_updated = this.removeStoredCandidateId source_vertex

                if not(queue_updated) then
                (
                    format "REMOVE VERT RMB | fixed:% | ERROR: processed ID was not found in stored data:%\n" source_vertex manual_remove_vertex_ids
                    this.resetManualRemoveState()
                )
                else
                (
                    manual_remove_candidate_id = 0

                    if target_type == #EditPoly then
                    (
                        current_selection = target_value.GetSelection #Vertex node:node
                        if current_selection == undefined then current_selection = #{}

                        if current_selection.numberSet > 0 then
                        (
                            target_value.Select #Vertex current_selection select:false node:node
                        )

                        target_value.RefreshScreen()
                    )
                    else
                    (
                        polyop.setVertSelection node.baseObject #{}
                    )

                    if manual_remove_vertex_ids.count > 0 then
                    (
                        format "REMOVE VERT RMB | fixed:% | remaining:% | use LMB for next candidate.\n" source_vertex manual_remove_vertex_ids
                    )
                    else
                    (
                        format "REMOVE VERT RMB | fixed:% | stored data complete.\n" source_vertex
                        this.resetManualRemoveState()
                    )
                )
            )
        )

        update node
        completeRedraw()
        removed_ok
        -- return
    ),

    /*
    Removes only the currently selected vertices that are still valid two-edge targets on each selected Epoly object.
    RMB snapshots the selected valid vertex IDs once, then processes those exact IDs from highest to lowest without any position-based source remapping.
    */
    function removeTwoEdgeVerts =
    (
        if selection.count < 1 then return false

        selected_nodes = selection as array
        multi_object = selected_nodes.count > 1
        removed_nodes = #()
        total_removed = 0
        final_edit_poly_node = undefined
        final_edit_poly_modifier = undefined

        for node in selected_nodes do
        (
            if node != undefined and isValidNode node then
            (
                target = getSelectionTarget node multi_object:multi_object

                if target != undefined then
                (
                    target_type = target[1]
                    target_value = target[2]
                    selected_bits = #{}
                    valid_bits = #{}
                    remove_bits = #{}
                    removed_count = 0

                    if target_type == #EditPoly then
                    (
                        selected_bits = target_value.GetSelection #Vertex node:node
                        if selected_bits == undefined then selected_bits = #{}
                        valid_bits = findTwoEdgeVertsOnEditPoly node target_value
                        remove_bits = selected_bits * valid_bits

                        if remove_bits.numberSet > 0 then
                        (
                            removed_count = weldTwoEdgeEditPolyVerts node target_value remove_bits
                        )

                        if removed_count > 0 then
                        (
                            final_edit_poly_node = node
                            final_edit_poly_modifier = target_value
                        )
                    )
                    else if target_type == #EditablePoly then
                    (
                        selected_bits = polyop.getVertSelection node.baseObject
                        valid_bits = findTwoEdgeVertsOnEditablePoly node
                        remove_bits = selected_bits * valid_bits

                        if remove_bits.numberSet > 0 then
                        (
                            removed_count = weldTwoEdgeEditablePolyVerts node remove_bits
                        )
                    )

                    if removed_count > 0 then
                    (
                        if findItem removed_nodes node == 0 then append removed_nodes node
                        total_removed += removed_count
                    )

                    format "Two Edge Verts REMOVE | node:% | target:% | selected:% | valid:% | remove:% | removed:%\n" node.name target_type selected_bits.numberSet valid_bits.numberSet remove_bits.numberSet removed_count
                )
            )
        )

        if removed_nodes.count > 0 then
        (
            select removed_nodes

            if final_edit_poly_node != undefined and final_edit_poly_modifier != undefined then
            (
                max modify mode

                final_edit_poly_modifier.SetPrimaryNode final_edit_poly_node
                final_edit_poly_modifier.useStackSelection = false
                final_edit_poly_modifier.selectMode = 0
                final_edit_poly_modifier.showCage = false

                modPanel.setCurrentObject final_edit_poly_modifier node:final_edit_poly_node
                final_edit_poly_modifier.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                final_edit_poly_modifier.RefreshScreen()
            )

            completeRedraw()
        )

        format "Two Edge Verts REMOVE | objects:% | removed:%\n" removed_nodes.count total_removed

        total_removed > 0
        -- return
    ),

    /*
    Clears stored Vertex, Edge, and Face selections from every Edit Poly modifier on all currently selected nodes.
    The original selected-node list is captured before Modify-panel activation changes the live object selection.
    */
    function clearAllEditPolySelections =
    (
        if selection.count < 1 then return false

        selected_nodes = selection as array
        processed_modifiers = 0

        for node in selected_nodes do
        (
            if node != undefined and isValidNode node then
            (
                for modifier_index = 1 to node.modifiers.count do
                (
                    modifier = node.modifiers[modifier_index]

                    if classOf modifier == Edit_Poly then
                    (
                        select node
                        max modify mode

                        modifier.SetPrimaryNode node
                        modifier.useStackSelection = false
                        modifier.selectMode = 0
                        modifier.showCage = false

                        modPanel.setCurrentObject modifier node:node

                        modifier.SetEPolySelLevel #Vertex
                        subObjectLevel = 1
                        old_vertices = modifier.GetSelection #Vertex node:node
                        if old_vertices != undefined and old_vertices.numberSet > 0 then
                        (
                            modifier.Select #Vertex old_vertices select:false node:node
                        )

                        modifier.SetEPolySelLevel #Edge
                        subObjectLevel = 2
                        old_edges = modifier.GetSelection #Edge node:node
                        if old_edges != undefined and old_edges.numberSet > 0 then
                        (
                            modifier.Select #Edge old_edges select:false node:node
                        )

                        modifier.SetEPolySelLevel #Face
                        subObjectLevel = 4
                        old_faces = modifier.GetSelection #Face node:node
                        if old_faces != undefined and old_faces.numberSet > 0 then
                        (
                            modifier.Select #Face old_faces select:false node:node
                        )

                        modifier.RefreshScreen()
                        processed_modifiers += 1
                    )
                )
            )
        )

        subObjectLevel = 0
        if selected_nodes.count > 0 then select selected_nodes
        completeRedraw()

        format "Two Edge Verts DEBUG | cleared Edit Poly selections | objects:% | modifiers:%\n" selected_nodes.count processed_modifiers

        processed_modifiers > 0
        -- return
    ),

    /*
    Finds T-junction vertices independently on every selected object and selects them on the same topology.
    Multiple Editable Poly objects stay at object level; Edit Poly enters Vertex sub-object mode only once at the end when results exist.
    */
    function selectTJunctionVerts =
    (
        if selection.count < 1 then
        (
            messageBox "Select one or more Editable Poly / Edit Poly objects." title:"T-Junction Verts"
            return false
        )

        selected_nodes = selection as array
        multi_object = selected_nodes.count > 1
        overall_ok = true
        processed_count = 0
        found_nodes = #()
        final_edit_poly_node = undefined
        final_edit_poly_modifier = undefined

        for node in selected_nodes do
        (
            target = getSelectionTarget node multi_object:multi_object

            if target == undefined then
            (
                format "T-Junction Verts | node:% | target:#Unsupported | selected:#{} | count:0 | ok:false\n" node.name
                overall_ok = false
            )
            else
            (
                target_type = target[1]
                target_value = target[2]
                candidate_bits = #{}
                selection_ok = false

                if target_type == #EditPoly then
                (
                    candidate_bits = findTJunctionVertsOnEditPoly node target_value

                    if candidate_bits.numberSet > 0 then
                    (
                        selection_ok = selectEditPolyVerts node target_value candidate_bits
                        if findItem found_nodes node == 0 then append found_nodes node
                        final_edit_poly_node = node
                        final_edit_poly_modifier = target_value
                    )
                    else
                    (
                        selection_ok = true
                    )
                )
                else if target_type == #EditablePoly then
                (
                    candidate_bits = findTJunctionVertsOnEditablePoly node
                    selection_ok = selectEditablePolyVerts node candidate_bits enter_subobject:(not multi_object and candidate_bits.numberSet > 0)

                    if candidate_bits.numberSet > 0 then
                    (
                        if findItem found_nodes node == 0 then append found_nodes node
                    )
                )

                format "T-Junction Verts | node:% | target:% | selected:% | count:% | ok:%\n" node.name target_type candidate_bits candidate_bits.numberSet selection_ok
                processed_count += 1

                if not(selection_ok) then overall_ok = false
            )
        )

        if multi_object then
        (
            if found_nodes.count > 0 then
            (
                select found_nodes

                if final_edit_poly_node != undefined and final_edit_poly_modifier != undefined then
                (
                    max modify mode

                    final_edit_poly_modifier.SetPrimaryNode final_edit_poly_node
                    final_edit_poly_modifier.useStackSelection = false
                    final_edit_poly_modifier.selectMode = 0
                    final_edit_poly_modifier.showCage = false

                    modPanel.setCurrentObject final_edit_poly_modifier node:final_edit_poly_node
                    final_edit_poly_modifier.SetEPolySelLevel #Vertex
                    subObjectLevel = 1
                    final_edit_poly_modifier.RefreshScreen()
                )
            )
            else
            (
                if selected_nodes.count > 0 then select selected_nodes
            )

            completeRedraw()
        )

        processed_count > 0 and overall_ok
        -- return
    ),

    /*
    Finds degree-two vertices independently on every selected object.
    Multiple Editable Poly objects stay at object level; multiple Edit Poly objects restore the full object selection and enter Vertex level once at the end.
    */
    function selectTwoEdgeVerts =
    (
        if selection.count < 1 then
        (
            messageBox "Select one or more Editable Poly / Edit Poly objects." title:"Two Edge Verts"
            return false
        )

        selected_nodes = selection as array
        multi_object = selected_nodes.count > 1
        overall_ok = true
        processed_count = 0
        found_nodes = #()
        final_edit_poly_node = undefined
        final_edit_poly_modifier = undefined

        for node in selected_nodes do
        (
            target = getSelectionTarget node multi_object:multi_object

            if target == undefined then
            (
                format "Two Edge Verts | node:% | target:#Unsupported | selected:#{} | count:0 | ok:false\n" node.name
                overall_ok = false
            )
            else
            (
                target_type = target[1]
                target_value = target[2]
                candidate_bits = #{}
                selection_ok = false

                if target_type == #EditPoly then
                (
                    candidate_bits = findTwoEdgeVertsOnEditPoly node target_value

                    if candidate_bits.numberSet > 0 then
                    (
                        selection_ok = selectEditPolyVerts node target_value candidate_bits
                        if findItem found_nodes node == 0 then append found_nodes node
                        final_edit_poly_node = node
                        final_edit_poly_modifier = target_value
                    )
                    else
                    (
                        selection_ok = true
                    )
                )
                else if target_type == #EditablePoly then
                (
                    candidate_bits = findTwoEdgeVertsOnEditablePoly node
                    selection_ok = selectEditablePolyVerts node candidate_bits enter_subobject:(not multi_object and candidate_bits.numberSet > 0)

                    if candidate_bits.numberSet > 0 then
                    (
                        if findItem found_nodes node == 0 then append found_nodes node
                    )
                )

                format "Two Edge Verts | node:% | target:% | selected:% | count:% | ok:%\n" node.name target_type candidate_bits candidate_bits.numberSet selection_ok
                processed_count += 1

                if not(selection_ok) then overall_ok = false
            )
        )

        if multi_object then
        (
            if found_nodes.count > 0 then
            (
                select found_nodes

                if final_edit_poly_node != undefined and final_edit_poly_modifier != undefined then
                (
                    max modify mode

                    final_edit_poly_modifier.SetPrimaryNode final_edit_poly_node
                    final_edit_poly_modifier.useStackSelection = false
                    final_edit_poly_modifier.selectMode = 0
                    final_edit_poly_modifier.showCage = false

                    modPanel.setCurrentObject final_edit_poly_modifier node:final_edit_poly_node
                    final_edit_poly_modifier.SetEPolySelLevel #Vertex
                    subObjectLevel = 1
                    final_edit_poly_modifier.RefreshScreen()
                )
            )
            else
            (
                if selected_nodes.count > 0 then select selected_nodes
            )

            completeRedraw()
        )

        processed_count > 0 and overall_ok
        -- return
    ),

    /*
    Returns valid two-visible-edge vertex IDs for one explicit EPoly node.
    INPUT: node and optional Edit Poly modifier. OUTPUT: BitArray of vertex IDs on that same live topology.
    */
    function getTwoEdgeVerts node modifier:undefined =
    (
        if node == undefined or not(isValidNode node) then return #{}

        target = undefined

        if modifier != undefined then
        (
            if classOf modifier != Edit_Poly then return #{}
            if not(modifierBelongsToNode node modifier) then return #{}
            target = #(#EditPoly, modifier)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return #{}

        case target[1] of
        (
            #EditPoly: findTwoEdgeVertsOnEditPoly node target[2]
            #EditablePoly: findTwoEdgeVertsOnEditablePoly node
            default: #{}
        )
        -- return
    ),

    /*
    Returns valid T-junction vertex IDs for one explicit EPoly node.
    INPUT: node and optional Edit Poly modifier. OUTPUT: BitArray of vertex IDs on that same live topology.
    */
    function getTJunctionVerts node modifier:undefined =
    (
        if node == undefined or not(isValidNode node) then return #{}

        target = undefined

        if modifier != undefined then
        (
            if classOf modifier != Edit_Poly then return #{}
            if not(modifierBelongsToNode node modifier) then return #{}
            target = #(#EditPoly, modifier)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return #{}

        case target[1] of
        (
            #EditPoly: findTJunctionVertsOnEditPoly node target[2]
            #EditablePoly: findTJunctionVertsOnEditablePoly node
            default: #{}
        )
        -- return
    ),

    /*
    Returns only vertices connected to the source by actually visible edges.
    INPUT: node, source vertex ID, optional Edit Poly modifier. OUTPUT: Array of live neighbor vertex IDs.
    */
    function getVisibleNeighborVertexIds node source_vertex modifier:undefined =
    (
        if node == undefined or not(isValidNode node) then return #()
        if source_vertex < 1 then return #()

        if modifier != undefined then
        (
            if classOf modifier != Edit_Poly then return #()
            if not(modifierBelongsToNode node modifier) then return #()
            return getActuallyVisibleEditPolyNeighborVerts node modifier source_vertex
        )

        target = getSelectionTarget node multi_object:true
        if target == undefined then return #()

        case target[1] of
        (
            #EditPoly: getActuallyVisibleEditPolyNeighborVerts node target[2] source_vertex
            #EditablePoly: getEditablePolyVisibleNeighborVerts node.baseObject source_vertex
            default: #()
        )
        -- return
    ),

    /*
    Returns the closest vertex connected to the source by an actually visible edge.
    INPUT: node, source vertex ID, optional Edit Poly modifier. OUTPUT: live neighbor vertex ID, or 0 when none exists.
    */
    function getClosestVisibleNeighborVertexId node source_vertex modifier:undefined =
    (
        if node == undefined or not(isValidNode node) then return 0
        if source_vertex < 1 then return 0

        if modifier != undefined then
        (
            if classOf modifier != Edit_Poly then return 0
            if not(modifierBelongsToNode node modifier) then return 0
            return getClosestEditPolyVisibleNeighborVert node modifier source_vertex
        )

        target = getSelectionTarget node multi_object:true
        if target == undefined then return 0

        case target[1] of
        (
            #EditPoly: getClosestEditPolyVisibleNeighborVert node target[2] source_vertex
            #EditablePoly: getClosestEditablePolyVisibleNeighborVert node.baseObject source_vertex
            default: 0
        )
        -- return
    ),

    /*
    Stores an explicit candidate BitArray for later manual processing after intersecting it with current valid two-edge vertices.
    INPUT: node, candidate BitArray, optional Edit Poly modifier. OUTPUT: ascending Array of stored live vertex IDs.
    */
    function storeCandidateIds node vertex_bits modifier:undefined =
    (
        this.resetManualRemoveState()

        if node == undefined or not(isValidNode node) then return #()
        if vertex_bits == undefined or classOf vertex_bits != BitArray then return #()

        target = undefined

        if modifier != undefined then
        (
            if classOf modifier != Edit_Poly then return #()
            if not(modifierBelongsToNode node modifier) then return #()
            target = #(#EditPoly, modifier)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return #()

        valid_bits = #{}

        if target[1] == #EditPoly then
        (
            valid_bits = findTwoEdgeVertsOnEditPoly node target[2]
        )
        else if target[1] == #EditablePoly then
        (
            valid_bits = findTwoEdgeVertsOnEditablePoly node
        )
        else
        (
            return #()
        )

        stored_bits = vertex_bits * valid_bits
        if stored_bits.numberSet < 1 then return #()

        manual_remove_node = node
        manual_remove_target_type = target[1]
        manual_remove_modifier = if target[1] == #EditPoly then target[2] else undefined
        manual_remove_vertex_ids = stored_bits as array
        sort manual_remove_vertex_ids
        manual_remove_candidate_id = 0

        copy manual_remove_vertex_ids
        -- return
    ),

    /*
    Returns a copy of the currently stored manual candidate IDs.
    INPUT: none. OUTPUT: ascending Array; the highest remaining ID is the last item.
    */
    function getStoredCandidateIds =
    (
        copy manual_remove_vertex_ids
        -- return
    ),

    /*
    Returns the highest currently stored candidate ID without changing backend state.
    INPUT: none. OUTPUT: vertex ID Integer, or 0 when no candidate remains.
    */
    function getNextStoredCandidateId =
    (
        if manual_remove_vertex_ids == undefined or manual_remove_vertex_ids.count < 1 then return 0
        manual_remove_vertex_ids[manual_remove_vertex_ids.count]
        -- return
    ),

    /*
    Selects exactly one explicit live vertex ID on the requested EPoly topology.
    INPUT: node, vertex ID, optional Edit Poly modifier. OUTPUT: Boolean success.
    */
    function selectCandidateById node vertex_id modifier:undefined =
    (
        if node == undefined or not(isValidNode node) then return false
        if vertex_id < 1 then return false

        if modifier != undefined then
        (
            return selectManualEditPolyVertex node modifier vertex_id
        )

        target = getSelectionTarget node multi_object:true
        if target == undefined then return false

        if target[1] == #EditPoly then return selectManualEditPolyVertex node target[2] vertex_id
        if target[1] == #EditablePoly then return selectManualEditablePolyVertex node vertex_id

        false
        -- return
    ),

    /*
    Fixes one explicit source vertex by welding it to the closest neighbor across an actually visible incident edge.
    INPUT: node, source vertex ID, optional Edit Poly modifier. OUTPUT: Boolean success; stored manual state is not modified.
    */
    function fixCandidateById node source_vertex modifier:undefined =
    (
        if node == undefined or not(isValidNode node) then return false
        if source_vertex < 1 then return false

        removed_ok = false
        protected_bits = #{}

        undo "Remove One 2-Edge Vert" on
        (
            if modifier != undefined then
            (
                removed_ok = removeOneManualEditPolyVert node modifier source_vertex protected_bits
            )
            else
            (
                target = getSelectionTarget node multi_object:true

                if target != undefined then
                (
                    if target[1] == #EditPoly then
                    (
                        removed_ok = removeOneManualEditPolyVert node target[2] source_vertex protected_bits
                    )
                    else if target[1] == #EditablePoly then
                    (
                        removed_ok = removeOneManualEditablePolyVert node source_vertex protected_bits
                    )
                )
            )
        )

        removed_ok
        -- return
    ),

    on create do
    (
    )
)

TwoEdgeVerts = TwoEdgeVerts_v()
