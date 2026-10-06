/*
    Redundant Vertex Cleaner Backend 0.79
    Reusable geometry backend for redundant-vertex detection, selection, exact duplicate collapse, and two-edge cleanup.

    Public input/output API:
    getSelectedVertexCounts() -> Array
    getTwoEdgeVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    selectTwoEdgeVerts force_mode:<Boolean> -> Boolean
    wasLastTwoEdgeDetectionSuccessful() -> Boolean
    getTJunctionVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    getBorderCornerVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    getInnerBorderCornerVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    getOuterBorderCornerVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    getBorderTJunctionVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    getDuplicatePositionVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    selectTJunctionVerts() -> Boolean
    selectBorderCornerVerts() -> Boolean
    selectInnerBorderCornerVerts() -> Boolean
    selectOuterBorderCornerVerts() -> Boolean
    selectBorderTJunctionVerts() -> Boolean
    selectDuplicatePositionVerts() -> Boolean
    collapseDuplicatePositionVerts node edit_poly_mod:<Edit_Poly> -> Integer
    collapseDuplicatePositionVertsOnSelection() -> Integer
    getVisibleNeighborVertexIds node source_vertex edit_poly_mod:<Edit_Poly> -> Array
    getClosestVisibleNeighborVertexId node source_vertex edit_poly_mod:<Edit_Poly> -> Integer
    storeCandidateIds node vertex_bits edit_poly_mod:<Edit_Poly> -> Array
    getStoredCandidateIds() -> Array
    getNextStoredCandidateId() -> Integer
    selectCandidateById node vertex_id edit_poly_mod:<Edit_Poly> -> Boolean
    fixCandidateById node source_vertex edit_poly_mod:<Edit_Poly> -> Boolean
    fixSelectedVertex() -> Boolean
    removeTwoEdgeVertsUntilStable() -> Integer
    removeSelectedTwoEdgeVertsBatch() -> Integer
*/

global TwoEdgeVerts
global epoly_tools_project_version

if epoly_tools_project_version == undefined or epoly_tools_project_version < 0.836 then
(
    epoly_tools_project_version = 0.836
)

struct TwoEdgeVerts_v
(
    file_version = 0.79,
    project_version = 0.836,
    straight_pair_dot_limit = -0.999847695,
    manual_remove_node = undefined,
    manual_remove_modifier = undefined,
    manual_remove_target_type = undefined,
    manual_remove_vertex_ids = #(),
    manual_remove_candidate_id = 0,
    last_two_edge_detection_ok = false,

    /*
    Returns whether the most recent true two-edge detector completed successfully.
    An empty candidate BitArray is valid only when this state is true.
    */
    function wasLastTwoEdgeDetectionSuccessful =
    (
        last_two_edge_detection_ok
        -- return
    ),

    /*
    Forces an Editable Poly or Edit Poly target to normal component-selection mode.
    The tool never uses selectMode 1.
    */
    function forceSelectModeZero poly_target =
    (
        if poly_target == undefined then return false

        if isProperty poly_target #selectMode then poly_target.selectMode = 0
        if isProperty poly_target #showCage then poly_target.showCage = false

        true
        -- return
    ),


    /*
    Returns true when the supplied Edit Poly modifier belongs to the selected node.
    This prevents selecting IDs on an unrelated modifier instance.
    */
    function modifierBelongsToNode node edit_poly_mod =
    (
        if node == undefined or edit_poly_mod == undefined then return false
        if not(isValidNode node) then return false
        if classOf edit_poly_mod != Edit_Poly then return false

        for modifier_index = 1 to node.modifiers.count do
        (
            if node.modifiers[modifier_index] == edit_poly_mod then return true
        )

        false
        -- return
    ),

    /*
    Invalidates persistent component-ID state for one node after topology membership or indexing changes.
    Vertex IDs are never carried across an Editable Poly collapse or another confirmed topology change.
    */
    function invalidateStoredTopologyIdsForNode node =
    (
        if node != undefined and this.manual_remove_node == node then
        (
            manual_remove_node = undefined
            manual_remove_modifier = undefined
            manual_remove_target_type = undefined
            manual_remove_vertex_ids = #()
            manual_remove_candidate_id = 0
        )

        last_two_edge_detection_ok = false

        true
        -- return
    ),

    /*
    Synchronizes one Editable Poly at a controlled boundary before index-sensitive topology work.
    OUTPUT: #clean, #collapsed, #blocked, or #failed; detecting dead topology invalidates persistent cached component IDs, and #collapsed reindexes the base.
    */
    function ensureCleanEditablePolyTopology node =
    (
        if node == undefined or not(isValidNode node) then return #failed
        if classOf node.baseObject != Editable_Poly then return #failed

        poly_value = node.baseObject
        dead_structs = polyop.getHasDeadStructs poly_value

        if dead_structs == 0 then return #clean

        this.invalidateStoredTopologyIdsForNode node
        edit_poly_above_base = false

        for modifier_index = 1 to node.modifiers.count while not(edit_poly_above_base) do
        (
            edit_poly_mod = node.modifiers[modifier_index]
            if classOf edit_poly_mod == Edit_Poly then edit_poly_above_base = true
        )

        if edit_poly_above_base then
        (
            format "Redundant Vertex Cleaner | Editable Poly topology sync blocked because collapsing the base would reindex topology below an Edit Poly modifier | node:%\n" node.name
            return #blocked
        )

        try
        (
            polyop.collapseDeadStructs poly_value
        )
        catch
        (
            exception_text = getCurrentException()
            format "Redundant Vertex Cleaner | Editable Poly collapseDeadStructs failed | node:% | ERROR:%\n" node.name exception_text
            return #failed
        )

        if polyop.getHasDeadStructs poly_value != 0 then
        (
            format "Redundant Vertex Cleaner | Editable Poly topology sync failed | node:% | dead structures remain after collapseDeadStructs.\n" node.name
            return #failed
        )

        update node

        #collapsed
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
            edit_poly_mod = node.modifiers[modifier_index]
            if classOf edit_poly_mod == Edit_Poly then return edit_poly_mod
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

        current_object = undefined

        if getCommandPanelTaskMode() == #modify then
        (
            current_object = modPanel.getCurrentObject()
        )

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
    Returns #(all_vertices, selected_vertices, unselected_vertices) for the single selected supported topology target.
    INPUT: current scene selection. OUTPUT: three-Integer Array, or #() when no single supported target is active.
    */
    function getSelectedVertexCounts =
    (
        if selection.count != 1 then return #()

        node = selection[1]
        if node == undefined or not(isValidNode node) then return #()

        target = getSelectionTarget node
        if target == undefined then return #()

        vertex_count = 0
        selected_bits = undefined

        if target[1] == #EditPoly then
        (
            vertex_count = EditPolyMod.GetNumVertices target[2] node:node
            selected_bits = target[2].GetSelection #Vertex node:node
        )
        else if target[1] == #EditablePoly then
        (
            topology_state = this.ensureCleanEditablePolyTopology node
            if topology_state == #failed or topology_state == #blocked then return #()

            vertex_count = polyop.getNumVerts node.baseObject
            selected_bits = polyop.getVertSelection node.baseObject
        )
        else
        (
            return #()
        )

        if classOf selected_bits != BitArray then return #()

        selected_count = selected_bits.numberSet
        if vertex_count < 0 or selected_count < 0 or selected_count > vertex_count then return #()

        #(vertex_count, selected_count, vertex_count - selected_count)
        -- return
    ),



    /*
    Editable Poly adjacency helpers below are phase-local and never synchronize topology themselves.
    Their callers must pass through ensureCleanEditablePolyTopology first and must not change topology until the helper chain finishes.
    */

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
    Returns true when one live Edit Poly edge is a border edge with exactly one valid adjacent face.
    Border classification stays on the live Edit Poly topology.
    */
    function isEditPolyBorderEdge node edit_poly_mod edge_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if not(modifierBelongsToNode node edit_poly_mod) then return false

        edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node
        if edge_index < 1 or edge_index > edge_count then return false

        face_a = EditPolyMod.GetEdgeFace edit_poly_mod edge_index 1 node:node
        face_b = EditPolyMod.GetEdgeFace edit_poly_mod edge_index 2 node:node
        face_a_missing = face_a == undefined or face_a < 1
        face_b_missing = face_b == undefined or face_b < 1

        face_a_missing != face_b_missing
        -- return
    ),

    /*
    Returns the other endpoint of one Edit Poly edge for the supplied vertex.
    The edge and vertex IDs belong to the same active Edit Poly modifier topology.
    */
    function getOtherEditPolyEdgeVertex node edit_poly_mod edge_index vertex_index =
    (
        vertex_a = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 1 node:node
        vertex_b = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 2 node:node

        if vertex_a == vertex_index then return vertex_b
        if vertex_b == vertex_index then return vertex_a

        0
        -- return
    ),

    /*
    Returns evaluated visible TriMesh edges as endpoint-position pairs.
    Raw TriMesh edge IDs are never transferred into Edit Poly topology.
    */
    function getSnapshotVisibleEdgePositionPairs snapshot_mesh =
    (
        if snapshot_mesh == undefined then return #()

        visible_pairs = #()
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

                    append visible_pairs #(
                        getVert snapshot_mesh snapshot_vertex_a,
                        getVert snapshot_mesh snapshot_vertex_b
                    )
                )
            )
        )

        visible_pairs
        -- return
    ),

    /*
    Returns true when one live endpoint-position pair exists in the evaluated visible-edge cache.
    The cache avoids rescanning every TriMesh face for each live Edit Poly edge.
    */
    function isSnapshotVisibleEdgeBetweenPositions snapshot_mesh position_a position_b tolerance:0.0001 visible_pairs:undefined =
    (
        if snapshot_mesh == undefined then return false
        if visible_pairs == undefined then visible_pairs = getSnapshotVisibleEdgePositionPairs snapshot_mesh

        for edge_positions in visible_pairs do
        (
            if edge_positions != undefined and edge_positions.count == 2 then
            (
                snapshot_position_a = edge_positions[1]
                snapshot_position_b = edge_positions[2]

                direct_match = distance snapshot_position_a position_a <= tolerance and distance snapshot_position_b position_b <= tolerance
                reverse_match = distance snapshot_position_a position_b <= tolerance and distance snapshot_position_b position_a <= tolerance

                if direct_match or reverse_match then return true
            )
        )

        false
        -- return
    ),

    /*
    Returns live Edit Poly neighbor vertex IDs connected to the source by edges that are actually visible in the evaluated mesh.
    Hidden/invisible triangulation or polygon edges are rejected even when EditPolyMod reports them as incident topology edges.
    */
    function getActuallyVisibleEditPolyNeighborVerts node edit_poly_mod source_vertex tolerance:0.0001 =
    (
        if node == undefined or not(isValidNode node) then return #()
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #()
        if not(modifierBelongsToNode node edit_poly_mod) then return #()

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        if source_vertex < 1 or source_vertex > vertex_count then return #()

        update node
        snapshot_mesh = undefined

        try
        (
            snapshot_mesh = snapshotAsMesh node
        )
        catch
        (
            exception_text = getCurrentException()
            format "Two Edge Verts | snapshot failed | node:% | ERROR:%\n" node.name exception_text
            return #()
        )

        if snapshot_mesh == undefined then return #()

        visible_pairs = getSnapshotVisibleEdgePositionPairs snapshot_mesh
        source_position = EditPolyMod.GetVertex edit_poly_mod source_vertex node:node
        neighbor_vertices = #()
        incident_count = EditPolyMod.GetVertexEdgeCount edit_poly_mod source_vertex node:node

        for incident_index = 1 to incident_count do
        (
            edge_index = EditPolyMod.GetVertexEdge edit_poly_mod source_vertex incident_index node:node
            neighbor_vertex = getOtherEditPolyEdgeVertex node edit_poly_mod edge_index source_vertex

            if neighbor_vertex >= 1 and neighbor_vertex <= vertex_count then
            (
                neighbor_position = EditPolyMod.GetVertex edit_poly_mod neighbor_vertex node:node

                if isSnapshotVisibleEdgeBetweenPositions snapshot_mesh source_position neighbor_position tolerance:tolerance visible_pairs:visible_pairs then
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
    function isEditPolyTJunction node edit_poly_mod vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false

        edge_count = EditPolyMod.GetVertexEdgeCount edit_poly_mod vertex_index node:node
        if edge_count != 3 then return false

        edge_a = EditPolyMod.GetVertexEdge edit_poly_mod vertex_index 1 node:node
        edge_b = EditPolyMod.GetVertexEdge edit_poly_mod vertex_index 2 node:node
        edge_c = EditPolyMod.GetVertexEdge edit_poly_mod vertex_index 3 node:node
        if edge_a < 1 or edge_b < 1 or edge_c < 1 then return false

        other_vertex_a = getOtherEditPolyEdgeVertex node edit_poly_mod edge_a vertex_index
        other_vertex_b = getOtherEditPolyEdgeVertex node edit_poly_mod edge_b vertex_index
        other_vertex_c = getOtherEditPolyEdgeVertex node edit_poly_mod edge_c vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 or other_vertex_c < 1 then return false

        vertex_position = EditPolyMod.GetVertex edit_poly_mod vertex_index node:node
        position_a = EditPolyMod.GetVertex edit_poly_mod other_vertex_a node:node
        position_b = EditPolyMod.GetVertex edit_poly_mod other_vertex_b node:node
        position_c = EditPolyMod.GetVertex edit_poly_mod other_vertex_c node:node

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
    Returns how one face boundary traverses a supplied edge endpoint pair.
    OUTPUT: 1 for vertex -> other, -1 for other -> vertex, or 0 when the pair is not consecutive on the face.
    */
    function getFaceEdgeDirection face_vertices vertex_index other_vertex =
    (
        if face_vertices == undefined or face_vertices.count < 2 then return 0

        face_vertex_count = face_vertices.count

        for corner_index = 1 to face_vertex_count do
        (
            next_corner_index = if corner_index == face_vertex_count then 1 else corner_index + 1
            face_vertex_a = face_vertices[corner_index]
            face_vertex_b = face_vertices[next_corner_index]

            if face_vertex_a == vertex_index and face_vertex_b == other_vertex then return 1
            if face_vertex_a == other_vertex and face_vertex_b == vertex_index then return -1
        )

        0
        -- return
    ),

    /*
    Returns the single adjacent face of one Editable Poly open-border edge.
    OUTPUT: Integer face ID, or 0 when the edge is not owned by exactly one live face.
    */
    function getEditablePolyBorderEdgeFaceId poly_value edge_index =
    (
        if poly_value == undefined or edge_index < 1 then return 0

        edge_faces = polyop.getFacesUsingEdge poly_value #{edge_index}
        if edge_faces == undefined or edge_faces.numberSet != 1 then return 0

        edge_face_ids = edge_faces as array
        if edge_face_ids.count != 1 then return 0

        edge_face_ids[1]
        -- return
    ),

    /*
    Returns the single adjacent face of one live Edit Poly open-border edge.
    OUTPUT: Integer face ID, or 0 when the edge is not owned by exactly one live face.
    */
    function getEditPolyBorderEdgeFaceId node edit_poly_mod edge_index =
    (
        if node == undefined or not(isValidNode node) then return 0
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return 0
        if not(modifierBelongsToNode node edit_poly_mod) then return 0
        if edge_index < 1 then return 0

        face_a = EditPolyMod.GetEdgeFace edit_poly_mod edge_index 1 node:node
        face_b = EditPolyMod.GetEdgeFace edit_poly_mod edge_index 2 node:node
        face_a_valid = face_a != undefined and face_a > 0
        face_b_valid = face_b != undefined and face_b > 0

        if face_a_valid == face_b_valid then return 0
        if face_a_valid then face_a else face_b
        -- return
    ),

    /*
    Computes the raw winding normal of one Editable Poly polygon from its ordered live vertices.
    OUTPUT: Point3 vector; a zero vector means the polygon winding cannot provide a valid normal.
    */
    function getEditablePolyFaceWindingNormal poly_value face_index =
    (
        if poly_value == undefined or face_index < 1 then return [0,0,0]

        face_vertices = polyop.getFaceVerts poly_value face_index
        if face_vertices == undefined or face_vertices.count < 3 then return [0,0,0]

        normal_value = [0,0,0]
        face_vertex_count = face_vertices.count

        for corner_index = 1 to face_vertex_count do
        (
            next_corner_index = if corner_index == face_vertex_count then 1 else corner_index + 1
            point_a = polyop.getVert poly_value face_vertices[corner_index]
            point_b = polyop.getVert poly_value face_vertices[next_corner_index]

            normal_value.x += (point_a.y - point_b.y) * (point_a.z + point_b.z)
            normal_value.y += (point_a.z - point_b.z) * (point_a.x + point_b.x)
            normal_value.z += (point_a.x - point_b.x) * (point_a.y + point_b.y)
        )

        normal_value
        -- return
    ),

    /*
    Computes the raw winding normal of one live Edit Poly polygon from its ordered modifier vertices.
    OUTPUT: Point3 vector; a zero vector means the polygon winding cannot provide a valid normal.
    */
    function getEditPolyFaceWindingNormal node edit_poly_mod face_index =
    (
        if node == undefined or not(isValidNode node) then return [0,0,0]
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return [0,0,0]
        if not(modifierBelongsToNode node edit_poly_mod) then return [0,0,0]
        if face_index < 1 then return [0,0,0]

        face_degree = EditPolyMod.GetFaceDegree edit_poly_mod face_index node:node
        if face_degree < 3 then return [0,0,0]

        face_vertices = #()

        for corner_index = 1 to face_degree do
        (
            face_vertex = EditPolyMod.GetFaceVertex edit_poly_mod face_index corner_index node:node
            if face_vertex < 1 then return [0,0,0]
            append face_vertices face_vertex
        )

        normal_value = [0,0,0]

        for corner_index = 1 to face_degree do
        (
            next_corner_index = if corner_index == face_degree then 1 else corner_index + 1
            point_a = EditPolyMod.GetVertex edit_poly_mod face_vertices[corner_index] node:node
            point_b = EditPolyMod.GetVertex edit_poly_mod face_vertices[next_corner_index] node:node

            normal_value.x += (point_a.y - point_b.y) * (point_a.z + point_b.z)
            normal_value.y += (point_a.z - point_b.z) * (point_a.x + point_b.x)
            normal_value.z += (point_a.x - point_b.x) * (point_a.y + point_b.y)
        )

        normal_value
        -- return
    ),

    /*
    Returns true for an Editable Poly border corner owned by the border-corner classifier.
    T-junctions are excluded first; two border edges form a corner when they are not a straight-through pair.
    */
    function isEditablePolyBorderCorner node vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false
        if isEditablePolyTJunction node vertex_index then return false

        poly_value = node.baseObject
        vertex_count = polyop.getNumVerts poly_value
        if vertex_index < 1 or vertex_index > vertex_count then return false

        incident_edges = polyop.getEdgesUsingVert poly_value #{vertex_index}
        open_edges = polyop.getOpenEdges poly_value
        border_edges = incident_edges * open_edges
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
        if length vector_a == 0.0 or length vector_b == 0.0 then return false

        vector_a = normalize vector_a
        vector_b = normalize vector_b

        dot vector_a vector_b > straight_pair_dot_limit
        -- return
    ),

    /*
    Returns true for an Edit Poly border corner owned by the border-corner classifier.
    T-junctions are excluded first; the two live border edges must not form a straight-through pair.
    */
    function isEditPolyBorderCorner node edit_poly_mod vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if not(modifierBelongsToNode node edit_poly_mod) then return false
        if isEditPolyTJunction node edit_poly_mod vertex_index then return false

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        if vertex_index < 1 or vertex_index > vertex_count then return false

        border_edges = #()
        incident_count = EditPolyMod.GetVertexEdgeCount edit_poly_mod vertex_index node:node

        for incident_index = 1 to incident_count do
        (
            edge_index = EditPolyMod.GetVertexEdge edit_poly_mod vertex_index incident_index node:node
            if isEditPolyBorderEdge node edit_poly_mod edge_index then append border_edges edge_index
        )

        if border_edges.count != 2 then return false

        other_vertex_a = getOtherEditPolyEdgeVertex node edit_poly_mod border_edges[1] vertex_index
        other_vertex_b = getOtherEditPolyEdgeVertex node edit_poly_mod border_edges[2] vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 then return false

        vertex_position = EditPolyMod.GetVertex edit_poly_mod vertex_index node:node
        position_a = EditPolyMod.GetVertex edit_poly_mod other_vertex_a node:node
        position_b = EditPolyMod.GetVertex edit_poly_mod other_vertex_b node:node
        vector_a = position_a - vertex_position
        vector_b = position_b - vertex_position
        if length vector_a == 0.0 or length vector_b == 0.0 then return false

        vector_a = normalize vector_a
        vector_b = normalize vector_b

        dot vector_a vector_b > straight_pair_dot_limit
        -- return
    ),

    /*
    Classifies one valid Editable Poly border corner from the oriented border turn and adjacent face winding.
    OUTPUT: #inner for a hole/reflex border, #outer for the exterior perimeter, or #none when the turn cannot be resolved.
    */
    function getEditablePolyBorderCornerClass node vertex_index =
    (
        if not(isEditablePolyBorderCorner node vertex_index) then return #none

        poly_value = node.baseObject
        incident_edges = polyop.getEdgesUsingVert poly_value #{vertex_index}
        border_edges = incident_edges * (polyop.getOpenEdges poly_value)
        if border_edges.numberSet != 2 then return #none

        edge_array = border_edges as array
        other_vertex_a = getOtherEditablePolyEdgeVertex poly_value edge_array[1] vertex_index
        other_vertex_b = getOtherEditablePolyEdgeVertex poly_value edge_array[2] vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 then return #none

        face_a = getEditablePolyBorderEdgeFaceId poly_value edge_array[1]
        face_b = getEditablePolyBorderEdgeFaceId poly_value edge_array[2]
        if face_a < 1 or face_b < 1 then return #none

        face_vertices_a = polyop.getFaceVerts poly_value face_a
        face_vertices_b = polyop.getFaceVerts poly_value face_b
        direction_a = getFaceEdgeDirection face_vertices_a vertex_index other_vertex_a
        direction_b = getFaceEdgeDirection face_vertices_b vertex_index other_vertex_b

        if direction_a == 0 or direction_b == 0 or direction_a == direction_b then return #none

        incoming_vertex = if direction_a < 0 then other_vertex_a else other_vertex_b
        outgoing_vertex = if direction_a > 0 then other_vertex_a else other_vertex_b

        vertex_position = polyop.getVert poly_value vertex_index
        incoming_position = polyop.getVert poly_value incoming_vertex
        outgoing_position = polyop.getVert poly_value outgoing_vertex
        incoming_vector = vertex_position - incoming_position
        outgoing_vector = outgoing_position - vertex_position
        turn_normal = cross incoming_vector outgoing_vector
        if length turn_normal == 0.0 then return #none

        reference_normal = (getEditablePolyFaceWindingNormal poly_value face_a) + (getEditablePolyFaceWindingNormal poly_value face_b)
        if length reference_normal == 0.0 then return #none

        turn_value = dot turn_normal reference_normal

        if turn_value > 0.0 then return #outer
        if turn_value < 0.0 then return #inner

        #none
        -- return
    ),

    /*
    Classifies one valid live Edit Poly border corner from the oriented border turn and adjacent face winding.
    OUTPUT: #inner for a hole/reflex border, #outer for the exterior perimeter, or #none when the turn cannot be resolved.
    */
    function getEditPolyBorderCornerClass node edit_poly_mod vertex_index =
    (
        if not(isEditPolyBorderCorner node edit_poly_mod vertex_index) then return #none

        border_edges = #()
        incident_count = EditPolyMod.GetVertexEdgeCount edit_poly_mod vertex_index node:node

        for incident_index = 1 to incident_count do
        (
            edge_index = EditPolyMod.GetVertexEdge edit_poly_mod vertex_index incident_index node:node
            if isEditPolyBorderEdge node edit_poly_mod edge_index then append border_edges edge_index
        )

        if border_edges.count != 2 then return #none

        other_vertex_a = getOtherEditPolyEdgeVertex node edit_poly_mod border_edges[1] vertex_index
        other_vertex_b = getOtherEditPolyEdgeVertex node edit_poly_mod border_edges[2] vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 then return #none

        face_a = getEditPolyBorderEdgeFaceId node edit_poly_mod border_edges[1]
        face_b = getEditPolyBorderEdgeFaceId node edit_poly_mod border_edges[2]
        if face_a < 1 or face_b < 1 then return #none

        face_degree_a = EditPolyMod.GetFaceDegree edit_poly_mod face_a node:node
        face_degree_b = EditPolyMod.GetFaceDegree edit_poly_mod face_b node:node
        if face_degree_a < 3 or face_degree_b < 3 then return #none

        face_vertices_a = #()
        face_vertices_b = #()

        for corner_index = 1 to face_degree_a do
        (
            append face_vertices_a (EditPolyMod.GetFaceVertex edit_poly_mod face_a corner_index node:node)
        )

        for corner_index = 1 to face_degree_b do
        (
            append face_vertices_b (EditPolyMod.GetFaceVertex edit_poly_mod face_b corner_index node:node)
        )

        direction_a = getFaceEdgeDirection face_vertices_a vertex_index other_vertex_a
        direction_b = getFaceEdgeDirection face_vertices_b vertex_index other_vertex_b

        if direction_a == 0 or direction_b == 0 or direction_a == direction_b then return #none

        incoming_vertex = if direction_a < 0 then other_vertex_a else other_vertex_b
        outgoing_vertex = if direction_a > 0 then other_vertex_a else other_vertex_b

        vertex_position = EditPolyMod.GetVertex edit_poly_mod vertex_index node:node
        incoming_position = EditPolyMod.GetVertex edit_poly_mod incoming_vertex node:node
        outgoing_position = EditPolyMod.GetVertex edit_poly_mod outgoing_vertex node:node
        incoming_vector = vertex_position - incoming_position
        outgoing_vector = outgoing_position - vertex_position
        turn_normal = cross incoming_vector outgoing_vector
        if length turn_normal == 0.0 then return #none

        reference_normal = (getEditPolyFaceWindingNormal node edit_poly_mod face_a) + (getEditPolyFaceWindingNormal node edit_poly_mod face_b)
        if length reference_normal == 0.0 then return #none

        turn_value = dot turn_normal reference_normal

        if turn_value > 0.0 then return #outer
        if turn_value < 0.0 then return #inner

        #none
        -- return
    ),

    /*
    Returns true when one Editable Poly T-junction lies on an open border.
    The two border edges must form the straight-through pair and the third edge is the branch.
    */
    function isEditablePolyBorderTJunction node vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false
        if not(isEditablePolyTJunction node vertex_index) then return false

        poly_value = node.baseObject
        incident_edges = polyop.getEdgesUsingVert poly_value #{vertex_index}
        open_edges = polyop.getOpenEdges poly_value
        border_edges = incident_edges * open_edges
        if border_edges.numberSet != 2 then return false

        edge_array = border_edges as array
        other_vertex_a = getOtherEditablePolyEdgeVertex poly_value edge_array[1] vertex_index
        other_vertex_b = getOtherEditablePolyEdgeVertex poly_value edge_array[2] vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 then return false

        vertex_position = polyop.getVert poly_value vertex_index
        vector_a = (polyop.getVert poly_value other_vertex_a) - vertex_position
        vector_b = (polyop.getVert poly_value other_vertex_b) - vertex_position
        if length vector_a == 0.0 or length vector_b == 0.0 then return false

        vector_a = normalize vector_a
        vector_b = normalize vector_b

        dot vector_a vector_b <= straight_pair_dot_limit
        -- return
    ),

    /*
    Returns true when one live Edit Poly T-junction lies on an open border.
    Exactly two incident edges must be border edges and they must form the straight-through pair.
    */
    function isEditPolyBorderTJunction node edit_poly_mod vertex_index =
    (
        if node == undefined or not(isValidNode node) then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if not(modifierBelongsToNode node edit_poly_mod) then return false
        if not(isEditPolyTJunction node edit_poly_mod vertex_index) then return false

        border_edges = #()
        incident_count = EditPolyMod.GetVertexEdgeCount edit_poly_mod vertex_index node:node

        for incident_index = 1 to incident_count do
        (
            edge_index = EditPolyMod.GetVertexEdge edit_poly_mod vertex_index incident_index node:node
            if isEditPolyBorderEdge node edit_poly_mod edge_index then append border_edges edge_index
        )

        if border_edges.count != 2 then return false

        other_vertex_a = getOtherEditPolyEdgeVertex node edit_poly_mod border_edges[1] vertex_index
        other_vertex_b = getOtherEditPolyEdgeVertex node edit_poly_mod border_edges[2] vertex_index
        if other_vertex_a < 1 or other_vertex_b < 1 then return false

        vertex_position = EditPolyMod.GetVertex edit_poly_mod vertex_index node:node
        vector_a = (EditPolyMod.GetVertex edit_poly_mod other_vertex_a node:node) - vertex_position
        vector_b = (EditPolyMod.GetVertex edit_poly_mod other_vertex_b node:node) - vertex_position
        if length vector_a == 0.0 or length vector_b == 0.0 then return false

        vector_a = normalize vector_a
        vector_b = normalize vector_b

        dot vector_a vector_b <= straight_pair_dot_limit
        -- return
    ),

    /*
    Finds border T-junctions on one Editable Poly base object.
    Border T-junctions are a dedicated subset of the general T-junction class.
    */
    function findBorderTJunctionVertsOnEditablePoly node =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return #{}

        vertex_count = polyop.getNumVerts node.baseObject
        candidate_bits = #{}
        candidate_bits.count = vertex_count

        for vertex_index = 1 to vertex_count do
        (
            if isEditablePolyBorderTJunction node vertex_index then candidate_bits[vertex_index] = true
        )

        candidate_bits
        -- return
    ),

    /*
    Finds border T-junctions on one live Edit Poly modifier.
    Candidate IDs remain the exact modifier vertex IDs that receive the selection.
    */
    function findBorderTJunctionVertsOnEditPoly node edit_poly_mod =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #{}
        if not(modifierBelongsToNode node edit_poly_mod) then return #{}

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        candidate_bits = #{}
        candidate_bits.count = vertex_count

        for vertex_index = 1 to vertex_count do
        (
            if isEditPolyBorderTJunction node edit_poly_mod vertex_index then candidate_bits[vertex_index] = true
        )

        candidate_bits
        -- return
    ),

    /*
    Groups exact Editable Poly vertex positions without tolerance or formatting conversion.
    Each returned item is #(Point3 position, Array vertex_ids) and only duplicate groups are retained.
    */
    function getEditablePolyDuplicatePositionGroups node =
    (
        if node == undefined or not(isValidNode node) then return #()
        if classOf node.baseObject != Editable_Poly then return #()

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return #()

        poly_value = node.baseObject
        vertex_count = polyop.getNumVerts poly_value
        all_groups = #()

        for vertex_index = 1 to vertex_count do
        (
            vertex_position = polyop.getVert poly_value vertex_index
            matching_group_index = 0

            for group_index = 1 to all_groups.count while matching_group_index == 0 do
            (
                if all_groups[group_index][1] == vertex_position then matching_group_index = group_index
            )

            if matching_group_index == 0 then
            (
                append all_groups #(vertex_position, #(vertex_index))
            )
            else
            (
                append all_groups[matching_group_index][2] vertex_index
            )
        )

        duplicate_groups = #()
        for position_group in all_groups do
        (
            if position_group[2].count > 1 then append duplicate_groups position_group
        )

        duplicate_groups
        -- return
    ),

    /*
    Groups exact live Edit Poly vertex positions without tolerance or evaluated-ID remapping.
    Each returned item is #(Point3 position, Array vertex_ids) and only duplicate groups are retained.
    */
    function getEditPolyDuplicatePositionGroups node edit_poly_mod =
    (
        if node == undefined or not(isValidNode node) then return #()
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #()
        if not(modifierBelongsToNode node edit_poly_mod) then return #()

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        all_groups = #()

        for vertex_index = 1 to vertex_count do
        (
            vertex_position = EditPolyMod.GetVertex edit_poly_mod vertex_index node:node
            matching_group_index = 0

            for group_index = 1 to all_groups.count while matching_group_index == 0 do
            (
                if all_groups[group_index][1] == vertex_position then matching_group_index = group_index
            )

            if matching_group_index == 0 then
            (
                append all_groups #(vertex_position, #(vertex_index))
            )
            else
            (
                append all_groups[matching_group_index][2] vertex_index
            )
        )

        duplicate_groups = #()
        for position_group in all_groups do
        (
            if position_group[2].count > 1 then append duplicate_groups position_group
        )

        duplicate_groups
        -- return
    ),

    /*
    Returns current Editable Poly vertex IDs whose position exactly equals one Point3.
    Equality is exact; no distance threshold is used.
    */
    function getEditablePolyVertexIdsAtExactPosition node target_position =
    (
        if node == undefined or not(isValidNode node) then return #()
        if classOf node.baseObject != Editable_Poly then return #()

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return #()

        poly_value = node.baseObject
        matching_ids = #()
        vertex_count = polyop.getNumVerts poly_value

        for vertex_index = 1 to vertex_count do
        (
            if polyop.getVert poly_value vertex_index == target_position then append matching_ids vertex_index
        )

        matching_ids
        -- return
    ),

    /*
    Returns current live Edit Poly vertex IDs whose position exactly equals one Point3.
    Equality is exact; no distance threshold is used.
    */
    function getEditPolyVertexIdsAtExactPosition node edit_poly_mod target_position =
    (
        if node == undefined or not(isValidNode node) then return #()
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #()
        if not(modifierBelongsToNode node edit_poly_mod) then return #()

        matching_ids = #()
        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node

        for vertex_index = 1 to vertex_count do
        (
            if EditPolyMod.GetVertex edit_poly_mod vertex_index node:node == target_position then append matching_ids vertex_index
        )

        matching_ids
        -- return
    ),

    /*
    Finds Editable Poly border corners independently from the true two-edge and T-junction classifications.
    Border corners have two border edges, are not T-junctions, and are not straight-through.
    */
    function findBorderCornerVertsOnEditablePoly node =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return #{}

        poly_value = node.baseObject
        vertex_count = polyop.getNumVerts poly_value
        candidate_bits = #{}
        candidate_bits.count = vertex_count

        for vertex_index = 1 to vertex_count do
        (
            if isEditablePolyBorderCorner node vertex_index then candidate_bits[vertex_index] = true
        )

        candidate_bits
        -- return
    ),

    /*
    Finds Edit Poly border corners independently on the exact live modifier topology.
    Candidate IDs are never remapped through evaluated TriMesh IDs.
    */
    function findBorderCornerVertsOnEditPoly node edit_poly_mod =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #{}
        if not(modifierBelongsToNode node edit_poly_mod) then return #{}

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        candidate_bits = #{}
        candidate_bits.count = vertex_count

        for vertex_index = 1 to vertex_count do
        (
            if isEditPolyBorderCorner node edit_poly_mod vertex_index then candidate_bits[vertex_index] = true
        )

        candidate_bits
        -- return
    ),

    /*
    Finds only inner/hole border corners on one Editable Poly base object.
    The result is a strict subset of the compatibility border-corner union.
    */
    function findInnerBorderCornerVertsOnEditablePoly node =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return #{}

        corner_bits = findBorderCornerVertsOnEditablePoly node
        inner_bits = #{}
        inner_bits.count = polyop.getNumVerts node.baseObject

        for vertex_index in corner_bits do
        (
            if getEditablePolyBorderCornerClass node vertex_index == #inner then inner_bits[vertex_index] = true
        )

        inner_bits
        -- return
    ),

    /*
    Finds only exterior-perimeter border corners on one Editable Poly base object.
    The result is a strict subset of the compatibility border-corner union.
    */
    function findOuterBorderCornerVertsOnEditablePoly node =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return #{}

        corner_bits = findBorderCornerVertsOnEditablePoly node
        outer_bits = #{}
        outer_bits.count = polyop.getNumVerts node.baseObject

        for vertex_index in corner_bits do
        (
            if getEditablePolyBorderCornerClass node vertex_index == #outer then outer_bits[vertex_index] = true
        )

        outer_bits
        -- return
    ),

    /*
    Finds only inner/hole border corners on one live Edit Poly modifier.
    Candidate IDs remain exact live modifier vertex IDs.
    */
    function findInnerBorderCornerVertsOnEditPoly node edit_poly_mod =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #{}
        if not(modifierBelongsToNode node edit_poly_mod) then return #{}

        corner_bits = findBorderCornerVertsOnEditPoly node edit_poly_mod
        inner_bits = #{}
        inner_bits.count = EditPolyMod.GetNumVertices edit_poly_mod node:node

        for vertex_index in corner_bits do
        (
            if getEditPolyBorderCornerClass node edit_poly_mod vertex_index == #inner then inner_bits[vertex_index] = true
        )

        inner_bits
        -- return
    ),

    /*
    Finds only exterior-perimeter border corners on one live Edit Poly modifier.
    Candidate IDs remain exact live modifier vertex IDs.
    */
    function findOuterBorderCornerVertsOnEditPoly node edit_poly_mod =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #{}
        if not(modifierBelongsToNode node edit_poly_mod) then return #{}

        corner_bits = findBorderCornerVertsOnEditPoly node edit_poly_mod
        outer_bits = #{}
        outer_bits.count = EditPolyMod.GetNumVertices edit_poly_mod node:node

        for vertex_index in corner_bits do
        (
            if getEditPolyBorderCornerClass node edit_poly_mod vertex_index == #outer then outer_bits[vertex_index] = true
        )

        outer_bits
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

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return #{}

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
    function findTJunctionVertsOnEditPoly node edit_poly_mod =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #{}
        if not(modifierBelongsToNode node edit_poly_mod) then return #{}

        select node
        max modify mode

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = false

        modPanel.setCurrentObject edit_poly_mod node:node

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        if vertex_count < 1 then return #{}

        candidate_bits = #{}
        candidate_bits.count = vertex_count

        for vertex_index = 1 to vertex_count do
        (
            if isEditPolyTJunction node edit_poly_mod vertex_index then candidate_bits[vertex_index] = true
        )

        candidate_bits
        -- return
    ),

    /*
    Counts incident visible topology edges on an Editable Poly base object.
    Hidden triangulation/divider edges are ignored; a vertex is a candidate only when its visible edge count is exactly two.
    */
    function findTwoEdgeVertsOnEditablePoly node force_mode:false =
    (
        last_two_edge_detection_ok = false

        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return #{}

        poly_value = node.baseObject
        forceSelectModeZero poly_value
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
                if force_mode then
                (
                    candidate_bits[vertex_index] = true
                )
                else if not(isEditablePolyTJunction node vertex_index) and not(isEditablePolyBorderCorner node vertex_index) then
                (
                    candidate_bits[vertex_index] = true
                )
            )
        )

        last_two_edge_detection_ok = true
        candidate_bits
        -- return
    ),

    /*
    Detects exact live Edit Poly vertex IDs by counting only live incident edges whose endpoint pair is visible in the evaluated mesh.
    The evaluated TriMesh is used only as an edge-visibility oracle; no TriMesh vertex or edge ID is copied into Edit Poly topology.
    */
    function findTwoEdgeVertsOnEditPoly node edit_poly_mod quiet_mode:false force_mode:false =
    (
        last_two_edge_detection_ok = false

        if node == undefined or not(isValidNode node) then return #{}
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #{}
        if not(modifierBelongsToNode node edit_poly_mod) then return #{}

        if getCommandPanelTaskMode() != #modify then
        (
            max modify mode
        )

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = false

        if modPanel.getCurrentObject() != edit_poly_mod then
        (
            modPanel.setCurrentObject edit_poly_mod node:node
        )

        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node
        if vertex_count < 1 or edge_count < 1 then
        (
            last_two_edge_detection_ok = true
            return #{}
        )

        update node
        snapshot_mesh = undefined

        try
        (
            snapshot_mesh = snapshotAsMesh node
        )
        catch
        (
            exception_text = getCurrentException()
            format "Two Edge Verts DETECT | node:% | target:#EditPoly | snapshot ERROR:%\n" node.name exception_text
            return #{}
        )

        if snapshot_mesh == undefined then
        (
            format "Two Edge Verts DETECT | node:% | target:#EditPoly | snapshot ERROR: snapshotAsMesh returned undefined.\n" node.name
            return #{}
        )

        visible_pairs = getSnapshotVisibleEdgePositionPairs snapshot_mesh
        edge_counts = for vertex_index = 1 to vertex_count collect 0

        for edge_index = 1 to edge_count do
        (
            vertex_a = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 1 node:node
            vertex_b = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 2 node:node

            if vertex_a >= 1 and vertex_a <= vertex_count and vertex_b >= 1 and vertex_b <= vertex_count then
            (
                position_a = EditPolyMod.GetVertex edit_poly_mod vertex_a node:node
                position_b = EditPolyMod.GetVertex edit_poly_mod vertex_b node:node

                if isSnapshotVisibleEdgeBetweenPositions snapshot_mesh position_a position_b visible_pairs:visible_pairs then
                (
                    edge_counts[vertex_a] += 1
                    edge_counts[vertex_b] += 1
                )
            )
        )

        candidate_bits = #{}
        candidate_bits.count = vertex_count

        for vertex_index = 1 to vertex_count do
        (
            if edge_counts[vertex_index] == 2 then
            (
                if force_mode then
                (
                    candidate_bits[vertex_index] = true
                )
                else if not(isEditPolyTJunction node edit_poly_mod vertex_index) and not(isEditPolyBorderCorner node edit_poly_mod vertex_index) then
                (
                    candidate_bits[vertex_index] = true
                )
            )
        )

        delete snapshot_mesh
        last_two_edge_detection_ok = true

        if not(quiet_mode) then
        (
            format "Two Edge Verts DETECT | node:% | target:#EditPoly | mode:% | candidates:% | count:%\n" node.name (if force_mode then #Force else #Filtered) candidate_bits candidate_bits.numberSet
        )
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
        if classOf vertex_bits != BitArray then return false

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return false

        if topology_state == #collapsed then
        (
            format "Redundant Vertex Cleaner | Editable Poly selection aborted because collapseDeadStructs invalidated the supplied vertex IDs. Rebuild the selection from current topology.\n"
            return false
        )

        if enter_subobject then
        (
            select node
            max modify mode

            poly_value = node.baseObject
            forceSelectModeZero poly_value
            modPanel.setCurrentObject poly_value node:node

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
    function selectEditPolyVerts node edit_poly_mod vertex_bits =
    (
        if node == undefined or not(isValidNode node) then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if classOf vertex_bits != BitArray then return false

        select node

        if getCommandPanelTaskMode() != #modify then
        (
            max modify mode
        )

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = false

        if modPanel.getCurrentObject() != edit_poly_mod then
        (
            modPanel.setCurrentObject edit_poly_mod node:node
        )

        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        old_vertices = edit_poly_mod.GetSelection #Vertex node:node
        if old_vertices == undefined then
        (
            format "Two Edge Verts | Edit Poly selection read failed before selection update.\n"
            return false
        )

        if old_vertices.numberSet > 0 then
        (
            edit_poly_mod.Select #Vertex old_vertices select:false node:node
        )

        edit_poly_mod.Select #Vertex vertex_bits select:true node:node
        stored_selection = edit_poly_mod.GetSelection #Vertex node:node
        if stored_selection == undefined then
        (
            format "Two Edge Verts | Edit Poly selection verification read failed.\n"
            return false
        )

        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1
        edit_poly_mod.RefreshScreen()
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
    function getClosestEditPolyVisibleNeighborVert node edit_poly_mod source_vertex =
    (
        if node == undefined or not(isValidNode node) then return 0
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return 0
        if not(modifierBelongsToNode node edit_poly_mod) then return 0

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        if source_vertex < 1 or source_vertex > vertex_count then return 0

        neighbor_vertices = getActuallyVisibleEditPolyNeighborVerts node edit_poly_mod source_vertex
        if neighbor_vertices.count < 1 then return 0

        source_position = EditPolyMod.GetVertex edit_poly_mod source_vertex node:node
        closest_vertex = 0
        closest_distance = 0.0

        for neighbor_vertex in neighbor_vertices do
        (
            if neighbor_vertex >= 1 and neighbor_vertex <= vertex_count then
            (
                neighbor_position = EditPolyMod.GetVertex edit_poly_mod neighbor_vertex node:node
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
        if this.manual_remove_vertex_ids == undefined or this.manual_remove_vertex_ids.count < 1 then return false

        source_index = findItem this.manual_remove_vertex_ids vertex_id
        if source_index < 1 then return false

        queue_before = for stored_vertex_id in this.manual_remove_vertex_ids collect stored_vertex_id
        queue_after = #()

        for queue_vertex_id in queue_before do
        (
            if queue_vertex_id != vertex_id then
            (
                append queue_after queue_vertex_id
            )
        )

        if queue_after.count != (queue_before.count - 1) then return false
        if (findItem queue_after vertex_id) > 0 then return false

        this.manual_remove_vertex_ids = for queue_vertex_id in queue_after collect queue_vertex_id
        stored_after = for stored_vertex_id in this.manual_remove_vertex_ids collect stored_vertex_id
        stored_matches = stored_after.count == queue_after.count

        if stored_matches then
        (
            for item_index = 1 to stored_after.count while stored_matches do
            (
                if stored_after[item_index] != queue_after[item_index] then stored_matches = false
            )
        )

        if not(stored_matches) then
        (
            format "REMOVE VERT DATA | ERROR: stored queue write failed | removed:% | before:% | requested:% | actual:%\n" vertex_id queue_before queue_after stored_after
            return false
        )

        format "REMOVE VERT DATA | removed:% | before:% | remaining:%\n" vertex_id queue_before stored_after
        true
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

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return false

        if topology_state == #collapsed then
        (
            format "REMOVE VERT LMB | Editable Poly candidate IDs were invalidated by topology synchronization.\n"
            return false
        )

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
    function selectManualEditPolyVertex node edit_poly_mod vertex_id =
    (
        if node == undefined or not(isValidNode node) then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if not(modifierBelongsToNode node edit_poly_mod) then return false

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        if vertex_id < 1 or vertex_id > vertex_count then return false

        select node
        max modify mode

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = false
        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        current_selection = edit_poly_mod.GetSelection #Vertex node:node
        if current_selection == undefined then
        (
            format "REMOVE VERT LMB | Edit Poly selection read failed.\n"
            return false
        )
        if current_selection.numberSet > 0 then edit_poly_mod.Select #Vertex current_selection select:false node:node

        single_vertex = #{}
        single_vertex[vertex_id] = true
        edit_poly_mod.Select #Vertex single_vertex select:true node:node
        edit_poly_mod.RefreshScreen()
        update node
        completeRedraw()

        selected_bits = edit_poly_mod.GetSelection #Vertex node:node
        selected_bits == single_vertex
        -- return
    ),

    /*
    Removes one Editable Poly source vertex with native Remove Vertex and falls back to the proven target-weld path only when native Remove changes nothing.
    Native Remove preserves the surrounding faces and reconnects the source vertex's two-edge path directly.
    */
    function removeOneManualEditablePolyVert node source_vertex quiet_mode:false =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return false

        if topology_state == #collapsed then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Editable Poly | source:% | ABORT: collapseDeadStructs invalidated the supplied source ID.\n" source_vertex
            )
            return false
        )

        poly_value = node.baseObject
        forceSelectModeZero poly_value
        vertex_count = polyop.getNumVerts poly_value
        if source_vertex < 1 or source_vertex > vertex_count then return false

        valid_bits = findTwoEdgeVertsOnEditablePoly node
        if not(last_two_edge_detection_ok) then return false

        if source_vertex > valid_bits.count or not(valid_bits[source_vertex]) then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Editable Poly | source:% | SKIP: source is no longer a valid true 2-edge vertex.\n" source_vertex
            )
            return false
        )

        source_position = polyop.getVert poly_value source_vertex

        single_vertex = #{}
        single_vertex[source_vertex] = true
        polyop.setVertSelection poly_value single_vertex
        selected_bits = polyop.getVertSelection poly_value
        if selected_bits != single_vertex then return false

        before_count = vertex_count
        native_remove_invoked = false

        try
        (
            native_remove_invoked = node.EditablePoly.Remove selLevel:#Vertex
        )
        catch
        (
            exception_text = getCurrentException()
            format "REMOVE VERT | Editable Poly | source:% | mode:#NativeRemove | ERROR:%\n" source_vertex exception_text
            native_remove_invoked = false
        )

        update node
        this.invalidateStoredTopologyIdsForNode node
        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return false

        after_native_count = polyop.getNumVerts poly_value
        native_removed = after_native_count == (before_count - 1)

        if native_removed then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Editable Poly | mode:#NativeRemove | removed:true\n"
            )
            return true
        )

        if after_native_count != before_count then
        (
            format "REMOVE VERT | Editable Poly | mode:#NativeRemove | ERROR: unexpected vertex count % -> %.\n" before_count after_native_count
            return false
        )

        refreshed_source_ids = getEditablePolyVertexIdsAtExactPosition node source_position
        if refreshed_source_ids.count != 1 then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Editable Poly | mode:#TargetWeldFallback | ABORT: source could not be uniquely reacquired after native Remove.\n"
            )
            return false
        )

        source_vertex = refreshed_source_ids[1]
        valid_bits = findTwoEdgeVertsOnEditablePoly node

        if not(last_two_edge_detection_ok) or source_vertex > valid_bits.count or not(valid_bits[source_vertex]) then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Editable Poly | mode:#TargetWeldFallback | ABORT: reacquired source is not a current true 2-edge vertex.\n"
            )
            return false
        )

        target_vertex = getClosestEditablePolyVisibleNeighborVert poly_value source_vertex
        if target_vertex < 1 then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Editable Poly | source:% | mode:#TargetWeldFallback | SKIP: no visible-edge target.\n" source_vertex
            )
            return false
        )

        target_position = polyop.getVert poly_value target_vertex
        weld_ok = false

        try
        (
            weld_result = poly_value.weldVerts target_vertex source_vertex target_position
            weld_ok = weld_result == true
        )
        catch
        (
            exception_text = getCurrentException()
            format "REMOVE VERT | Editable Poly | source:% | target:% | mode:#TargetWeldFallback | ERROR:%\n" source_vertex target_vertex exception_text
            weld_ok = false
        )

        update node
        this.invalidateStoredTopologyIdsForNode node
        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return false

        after_count = polyop.getNumVerts poly_value
        removed_ok = weld_ok and after_count == (before_count - 1)

        if not(quiet_mode) then
        (
            format "REMOVE VERT | Editable Poly | mode:#TargetWeldFallback | removed:% | nativeInvoked:%\n" removed_ok native_remove_invoked
        )
        removed_ok
        -- return
    ),

    /*
    Removes one Edit Poly source vertex with the modifier's native Remove Vertex button operation.
    The existing target-weld path is retained only as a fallback when native Remove leaves topology unchanged.
    */
    function removeOneManualEditPolyVert node edit_poly_mod source_vertex quiet_mode:false =
    (
        if node == undefined or not(isValidNode node) then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if not(modifierBelongsToNode node edit_poly_mod) then return false

        select node
        max modify mode

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = false
        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        if source_vertex < 1 or source_vertex > vertex_count then return false

        valid_bits = findTwoEdgeVertsOnEditPoly node edit_poly_mod quiet_mode:quiet_mode
        if not(last_two_edge_detection_ok) then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Edit Poly | source:% | ERROR: true 2-edge detection failed.\n" source_vertex
            )
            return false
        )

        if source_vertex > valid_bits.count or not(valid_bits[source_vertex]) then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Edit Poly | source:% | SKIP: source is no longer a valid true 2-edge vertex.\n" source_vertex
            )
            return false
        )

        current_selection = edit_poly_mod.GetSelection #Vertex node:node
        if current_selection == undefined then
        (
            format "REMOVE VERT | Edit Poly | source:% | ERROR: selection read failed before native Remove.\n" source_vertex
            return false
        )
        if current_selection.numberSet > 0 then edit_poly_mod.Select #Vertex current_selection select:false node:node

        single_vertex = #{}
        single_vertex[source_vertex] = true
        edit_poly_mod.Select #Vertex single_vertex select:true node:node
        selected_bits = edit_poly_mod.GetSelection #Vertex node:node
        if selected_bits != single_vertex then return false

        source_position = EditPolyMod.GetVertex edit_poly_mod source_vertex node:node
        before_count = vertex_count
        native_remove_invoked = false

        try
        (
            edit_poly_mod.ButtonOp #RemoveVertex
            native_remove_invoked = true
        )
        catch
        (
            exception_text = getCurrentException()
            format "REMOVE VERT | Edit Poly | source:% | mode:#NativeRemove | ERROR:%\n" source_vertex exception_text
            native_remove_invoked = false
        )

        edit_poly_mod.RefreshScreen()
        update node
        this.invalidateStoredTopologyIdsForNode node
        after_native_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        native_removed = after_native_count == (before_count - 1)

        if native_removed then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Edit Poly | source:% | mode:#NativeRemove | removed:true\n" source_vertex
            )
            return true
        )

        if after_native_count != before_count then
        (
            format "REMOVE VERT | Edit Poly | source:% | mode:#NativeRemove | ERROR: unexpected vertex count % -> %.\n" source_vertex before_count after_native_count
            return false
        )

        refreshed_source_ids = getEditPolyVertexIdsAtExactPosition node edit_poly_mod source_position
        if refreshed_source_ids.count != 1 then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Edit Poly | mode:#TargetWeldFallback | ABORT: source could not be uniquely reacquired after native Remove.\n"
            )
            return false
        )

        source_vertex = refreshed_source_ids[1]
        valid_bits = findTwoEdgeVertsOnEditPoly node edit_poly_mod quiet_mode:quiet_mode

        if not(last_two_edge_detection_ok) or source_vertex > valid_bits.count or not(valid_bits[source_vertex]) then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Edit Poly | mode:#TargetWeldFallback | ABORT: reacquired source is not a current true 2-edge vertex.\n"
            )
            return false
        )

        current_selection = edit_poly_mod.GetSelection #Vertex node:node
        if current_selection == undefined then
        (
            format "REMOVE VERT | Edit Poly | source:% | mode:#TargetWeldFallback | ERROR: selection read failed.\n" source_vertex
            return false
        )
        if current_selection.numberSet > 0 then edit_poly_mod.Select #Vertex current_selection select:false node:node

        single_vertex = #{}
        single_vertex[source_vertex] = true
        edit_poly_mod.Select #Vertex single_vertex select:true node:node
        selected_bits = edit_poly_mod.GetSelection #Vertex node:node
        if selected_bits != single_vertex then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Edit Poly | source:% | mode:#TargetWeldFallback | SKIP: reacquired source could not be selected.\n" source_vertex
            )
            return false
        )

        target_vertex = getClosestEditPolyVisibleNeighborVert node edit_poly_mod source_vertex
        if target_vertex < 1 then
        (
            if not(quiet_mode) then
            (
                format "REMOVE VERT | Edit Poly | source:% | mode:#TargetWeldFallback | SKIP: no visible-edge target.\n" source_vertex
            )
            return false
        )

        source_position = EditPolyMod.GetVertex edit_poly_mod source_vertex node:node
        target_position = EditPolyMod.GetVertex edit_poly_mod target_vertex node:node
        move_amount = target_position - source_position
        weld_ok = false

        try
        (
            edit_poly_mod.MoveSelection move_amount
            edit_poly_mod.Commit()
            edit_poly_mod.WeldVertices target_vertex source_vertex node:node
            edit_poly_mod.Commit()
            weld_ok = true
        )
        catch
        (
            exception_text = getCurrentException()
            format "REMOVE VERT | Edit Poly | source:% | target:% | mode:#TargetWeldFallback | ERROR:%\n" source_vertex target_vertex exception_text
            weld_ok = false
        )

        edit_poly_mod.RefreshScreen()
        update node
        this.invalidateStoredTopologyIdsForNode node
        after_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        removed_ok = weld_ok and after_count == (before_count - 1)

        if not(quiet_mode) then
        (
            format "REMOVE VERT | Edit Poly | source:% | target:% | mode:#TargetWeldFallback | removed:% | nativeInvoked:%\n" source_vertex target_vertex removed_ok native_remove_invoked
        )
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
            if selected_bits == undefined then
            (
                format "REMOVE VERT DATA | Edit Poly vertex selection read failed.\n"
                return false
            )

            valid_bits = findTwoEdgeVertsOnEditPoly node target_value
            if not(last_two_edge_detection_ok) then
            (
                format "REMOVE VERT DATA | Edit Poly true 2-edge detection failed.\n"
                return false
            )
        )
        else if target_type == #EditablePoly then
        (
            valid_bits = findTwoEdgeVertsOnEditablePoly node
            if not(last_two_edge_detection_ok) then return false

            selected_bits = polyop.getVertSelection node.baseObject
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
    Rebuilds manual candidate IDs from the current topology after a completed topology change.
    No pre-change component ID survives; the next manual LMB uses only freshly detected current IDs.
    */
    function rebuildManualRemoveStateFromCurrentTopology node target_type target_value =
    (
        if node == undefined or not(isValidNode node) then return false

        fresh_bits = #{}

        if target_type == #EditPoly then
        (
            if target_value == undefined or classOf target_value != Edit_Poly then return false
            if not(modifierBelongsToNode node target_value) then return false

            fresh_bits = findTwoEdgeVertsOnEditPoly node target_value
            if not(last_two_edge_detection_ok) then
            (
                this.resetManualRemoveState()
                return false
            )
        )
        else if target_type == #EditablePoly then
        (
            fresh_bits = findTwoEdgeVertsOnEditablePoly node
            if not(last_two_edge_detection_ok) then
            (
                this.resetManualRemoveState()
                return false
            )
        )
        else
        (
            this.resetManualRemoveState()
            return false
        )

        if fresh_bits.numberSet < 1 then
        (
            this.resetManualRemoveState()
            return true
        )

        manual_remove_node = node
        manual_remove_target_type = target_type
        manual_remove_modifier = if target_type == #EditPoly then target_value else undefined
        manual_remove_vertex_ids = fresh_bits as array
        sort manual_remove_vertex_ids
        manual_remove_candidate_id = 0

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
            if selected_bits == undefined then return false
            return selected_bits == expected_bits
        )

        if target_type == #EditablePoly then
        (
            topology_state = this.ensureCleanEditablePolyTopology node
            if topology_state != #clean then return false

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

        if target_type == #EditablePoly then
        (
            topology_state = this.ensureCleanEditablePolyTopology node

            if topology_state == #collapsed then
            (
                rebuilt_ok = this.rebuildManualRemoveStateFromCurrentTopology node target_type target_value
                if not(rebuilt_ok) then return false
            )
            else if topology_state == #failed or topology_state == #blocked then
            (
                return false
            )
        )

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
    Fixes only the candidate previously armed by REMOVE VERT LMB and rebuilds candidate IDs from current topology after success.
    RMB does not carry pre-change component IDs across the topology change; the next LMB arms a freshly detected current ID.
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

        if target_type == #EditablePoly then
        (
            topology_state = this.ensureCleanEditablePolyTopology node

            if topology_state == #collapsed then
            (
                this.rebuildManualRemoveStateFromCurrentTopology node target_type target_value
                format "REMOVE VERT RMB | Editable Poly topology was synchronized; the armed candidate ID was invalidated. Use LMB to arm a fresh candidate.\n"
                return false
            )
            else if topology_state == #failed or topology_state == #blocked then
            (
                return false
            )
        )

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

        removed_ok = false

        undo "Remove One 2-Edge Vert" on
        (
            if target_type == #EditPoly then
            (
                removed_ok = this.removeOneManualEditPolyVert node target_value source_vertex
            )
            else if target_type == #EditablePoly then
            (
                removed_ok = this.removeOneManualEditablePolyVert node source_vertex
            )
        )

        if removed_ok then
        (
            rebuilt_ok = this.rebuildManualRemoveStateFromCurrentTopology node target_type target_value
            remaining_ids = this.getStoredCandidateIds()

            if target_type == #EditPoly then
            (
                current_selection = target_value.GetSelection #Vertex node:node
                if current_selection == undefined then
                (
                    format "REMOVE VERT RMB | fixed:% | ERROR: final Edit Poly selection read failed; selection was not cleared.\n" source_vertex
                )
                else if current_selection.numberSet > 0 then
                (
                    target_value.Select #Vertex current_selection select:false node:node
                )

                target_value.RefreshScreen()
            )
            else
            (
                topology_state = this.ensureCleanEditablePolyTopology node

                if topology_state == #failed or topology_state == #blocked then
                (
                    rebuilt_ok = false
                )
                else
                (
                    polyop.setVertSelection node.baseObject #{}
                )
            )

            if not(rebuilt_ok) then
            (
                format "REMOVE VERT RMB | fixed:% | ERROR: current candidate data could not be rebuilt after topology change.\n" source_vertex
                this.resetManualRemoveState()
            )
            else if remaining_ids.count > 0 then
            (
                format "REMOVE VERT RMB | fixed:% | remaining:% | use LMB for next current candidate.\n" source_vertex remaining_ids
            )
            else
            (
                format "REMOVE VERT RMB | fixed:% | stored data complete.\n" source_vertex
            )
        )

        update node
        completeRedraw()
        removed_ok
        -- return
    ),

    /*
    Returns all exact-position duplicate vertices on one explicit EPoly target.
    Every vertex in a position group with two or more exact matches is returned.
    */
    function getDuplicatePositionVerts node edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return #{}

        target = undefined

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return #{}
            if not(modifierBelongsToNode node edit_poly_mod) then return #{}
            target = #(#EditPoly, edit_poly_mod)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return #{}

        duplicate_groups = #()
        vertex_count = 0

        if target[1] == #EditablePoly then
        (
            topology_state = this.ensureCleanEditablePolyTopology node
            if topology_state == #failed or topology_state == #blocked then return #{}
        )

        if target[1] == #EditPoly then
        (
            duplicate_groups = getEditPolyDuplicatePositionGroups node target[2]
            vertex_count = EditPolyMod.GetNumVertices target[2] node:node
        )
        else if target[1] == #EditablePoly then
        (
            duplicate_groups = getEditablePolyDuplicatePositionGroups node
            vertex_count = polyop.getNumVerts node.baseObject
        )
        else
        (
            return #{}
        )

        duplicate_bits = #{}
        duplicate_bits.count = vertex_count

        for position_group in duplicate_groups do
        (
            for vertex_id in position_group[2] do duplicate_bits[vertex_id] = true
        )

        duplicate_bits
        -- return
    ),

    /*
    Selects all exact-position duplicate vertices on exactly one selected supported object.
    Detection uses exact Point3 equality and never introduces a weld threshold.
    */
    function selectDuplicatePositionVerts =
    (
        if selection.count != 1 then
        (
            format "Redundant Vertex Cleaner | DUPLICATES requires exactly one selected Editable Poly / Edit Poly object.\n"
            return false
        )

        node = selection[1]
        if node == undefined or not(isValidNode node) then return false

        target = getSelectionTarget node multi_object:false
        if target == undefined then return false

        duplicate_bits = #{}
        selection_ok = false

        if target[1] == #EditPoly then
        (
            duplicate_bits = this.getDuplicatePositionVerts node edit_poly_mod:target[2]
            selection_ok = selectEditPolyVerts node target[2] duplicate_bits
        )
        else if target[1] == #EditablePoly then
        (
            duplicate_bits = this.getDuplicatePositionVerts node
            selection_ok = selectEditablePolyVerts node duplicate_bits enter_subobject:(duplicate_bits.numberSet > 0)
        )

        format "Redundant Vertex Cleaner | duplicate exact-position verts:% | count:% | ok:%\n" duplicate_bits duplicate_bits.numberSet selection_ok
        selection_ok
        -- return
    ),

    /*
    Collapses all exact-position duplicate groups on one Editable Poly base object.
    The first current vertex at each exact position survives; every weld is verified by a one-vertex count drop.
    */
    function collapseEditablePolyDuplicatePositions node =
    (
        if node == undefined or not(isValidNode node) then return 0
        if classOf node.baseObject != Editable_Poly then return 0

        poly_value = node.baseObject
        forceSelectModeZero poly_value
        duplicate_groups = getEditablePolyDuplicatePositionGroups node
        duplicate_positions = for position_group in duplicate_groups collect position_group[1]
        removed_count = 0

        for duplicate_position in duplicate_positions do
        (
            keep_collapsing = true

            while keep_collapsing do
            (
                matching_ids = getEditablePolyVertexIdsAtExactPosition node duplicate_position

                if matching_ids.count < 2 then
                (
                    keep_collapsing = false
                )
                else
                (
                    target_vertex = matching_ids[1]
                    source_vertex = matching_ids[matching_ids.count]
                    before_count = polyop.getNumVerts poly_value
                    weld_ok = false

                    try
                    (
                        weld_result = poly_value.weldVerts target_vertex source_vertex duplicate_position
                        weld_ok = weld_result == true
                    )
                    catch
                    (
                        exception_text = getCurrentException()
                        format "Redundant Vertex Cleaner | exact duplicate weld ERROR | source:% | target:% | %\n" source_vertex target_vertex exception_text
                        weld_ok = false
                    )

                    update node
                    this.invalidateStoredTopologyIdsForNode node
                    topology_state = this.ensureCleanEditablePolyTopology node

                    if topology_state == #failed or topology_state == #blocked then
                    (
                        keep_collapsing = false
                        format "Redundant Vertex Cleaner | exact duplicate collapse stopped | position:% | topology sync failed after weld.\n" duplicate_position
                    )
                    else
                    (
                        after_count = polyop.getNumVerts poly_value

                        if weld_ok and after_count == (before_count - 1) then
                        (
                            removed_count += 1
                        )
                        else
                        (
                            format "Redundant Vertex Cleaner | exact duplicate collapse stopped | position:% | source:% | target:% | before:% | after:%\n" duplicate_position source_vertex target_vertex before_count after_count
                            keep_collapsing = false
                        )
                    )
                )
            )
        )

        removed_count
        -- return
    ),

    /*
    Collapses all exact-position duplicate groups on one live Edit Poly modifier.
    Each pair weld is committed and verified before IDs are reacquired from the changed topology.
    */
    function collapseEditPolyDuplicatePositions node edit_poly_mod =
    (
        if node == undefined or not(isValidNode node) then return 0
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return 0
        if not(modifierBelongsToNode node edit_poly_mod) then return 0

        select node
        max modify mode
        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = false
        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1
        EditPolyMod.Cancel edit_poly_mod

        duplicate_groups = getEditPolyDuplicatePositionGroups node edit_poly_mod
        duplicate_positions = for position_group in duplicate_groups collect position_group[1]
        removed_count = 0

        for duplicate_position in duplicate_positions do
        (
            keep_collapsing = true

            while keep_collapsing do
            (
                matching_ids = getEditPolyVertexIdsAtExactPosition node edit_poly_mod duplicate_position

                if matching_ids.count < 2 then
                (
                    keep_collapsing = false
                )
                else
                (
                    target_vertex = matching_ids[1]
                    source_vertex = matching_ids[matching_ids.count]
                    before_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
                    weld_ok = false

                    try
                    (
                        EditPolyMod.WeldVertices edit_poly_mod target_vertex source_vertex node:node
                        edit_poly_mod.Commit()
                        weld_ok = true
                    )
                    catch
                    (
                        exception_text = getCurrentException()
                        format "Redundant Vertex Cleaner | exact duplicate Edit Poly weld ERROR | source:% | target:% | %\n" source_vertex target_vertex exception_text
                        weld_ok = false
                    )

                    edit_poly_mod.RefreshScreen()
                    update node
                    this.invalidateStoredTopologyIdsForNode node
                    after_count = EditPolyMod.GetNumVertices edit_poly_mod node:node

                    if weld_ok and after_count == (before_count - 1) then
                    (
                        removed_count += 1
                    )
                    else
                    (
                        format "Redundant Vertex Cleaner | exact duplicate Edit Poly collapse stopped | position:% | source:% | target:% | before:% | after:%\n" duplicate_position source_vertex target_vertex before_count after_count
                        keep_collapsing = false
                    )
                )
            )
        )

        edit_poly_mod.RefreshScreen()
        completeRedraw()
        removed_count
        -- return
    ),

    /*
    Collapses all exact-position duplicate vertices on one explicit supported EPoly target.
    OUTPUT: Integer count of vertices removed; zero means no exact duplicate was collapsed.
    */
    function collapseDuplicatePositionVerts node edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return 0

        target = undefined

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return 0
            if not(modifierBelongsToNode node edit_poly_mod) then return 0
            target = #(#EditPoly, edit_poly_mod)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return 0

        removed_count = 0

        undo "Collapse Exact Duplicate Verts" on
        (
            if target[1] == #EditPoly then
            (
                removed_count = this.collapseEditPolyDuplicatePositions node target[2]
            )
            else if target[1] == #EditablePoly then
            (
                removed_count = this.collapseEditablePolyDuplicatePositions node
            )
        )

        format "Redundant Vertex Cleaner | exact duplicate collapse | node:% | removed:%\n" node.name removed_count
        removed_count
        -- return
    ),

    /*
    Collapses exact-position duplicates on exactly one selected supported object.
    OUTPUT: Integer count of vertices removed.
    */
    function collapseDuplicatePositionVertsOnSelection =
    (
        if selection.count != 1 then
        (
            format "Redundant Vertex Cleaner | COLLAPSE DUPLICATES requires exactly one selected object.\n"
            return 0
        )

        node = selection[1]
        if node == undefined or not(isValidNode node) then return 0
        this.collapseDuplicatePositionVerts node
        -- return
    ),

    /*
    Selects border T-junction vertices independently on every selected object.
    Border T-junctions are a subset of the general T-junction detector.
    */
    function selectBorderTJunctionVerts =
    (
        if selection.count < 1 then
        (
            format "Border T-Junction Verts | Select one or more Editable Poly / Edit Poly objects.\n"
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
                format "Border T-Junction Verts | node:% | target:#Unsupported | selected:#{} | count:0 | ok:false\n" node.name
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
                    candidate_bits = findBorderTJunctionVertsOnEditPoly node target_value

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
                    candidate_bits = findBorderTJunctionVertsOnEditablePoly node
                    selection_ok = selectEditablePolyVerts node candidate_bits enter_subobject:(not multi_object and candidate_bits.numberSet > 0)

                    if candidate_bits.numberSet > 0 then
                    (
                        if findItem found_nodes node == 0 then append found_nodes node
                    )
                )

                format "Border T-Junction Verts | node:% | target:% | selected:% | count:% | ok:%\n" node.name target_type candidate_bits candidate_bits.numberSet selection_ok
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
    Finds T-junction vertices independently on every selected object and selects them on the same topology.
    Multiple Editable Poly objects stay at object level; Edit Poly enters Vertex sub-object mode only once at the end when results exist.
    */
    function selectTJunctionVerts =
    (
        if selection.count < 1 then
        (
            format "T-Junction Verts | Select one or more Editable Poly / Edit Poly objects.\n"
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
    Selects one requested border-corner class independently on every selected object.
    INPUT: #all, #inner, or #outer. OUTPUT: Boolean processing/selection success.
    */
    function selectBorderCornerVertsByClass corner_class =
    (
        if corner_class != #all and corner_class != #inner and corner_class != #outer then return false

        if selection.count < 1 then
        (
            format "Border Corner Verts | Select one or more Editable Poly / Edit Poly objects.\n"
            return false
        )

        selected_nodes = selection as array
        multi_object = selected_nodes.count > 1
        overall_ok = true
        processed_count = 0
        found_nodes = #()
        final_edit_poly_node = undefined
        final_edit_poly_modifier = undefined
        class_label = case corner_class of
        (
            #inner: "Inner Border Corner Verts"
            #outer: "Outer Border Corner Verts"
            default: "Border Corner Verts"
        )

        for node in selected_nodes do
        (
            target = getSelectionTarget node multi_object:multi_object

            if target == undefined then
            (
                format "% | node:% | target:#Unsupported | selected:#{} | count:0 | ok:false\n" class_label node.name
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
                    candidate_bits = case corner_class of
                    (
                        #inner: findInnerBorderCornerVertsOnEditPoly node target_value
                        #outer: findOuterBorderCornerVertsOnEditPoly node target_value
                        default: findBorderCornerVertsOnEditPoly node target_value
                    )

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
                    candidate_bits = case corner_class of
                    (
                        #inner: findInnerBorderCornerVertsOnEditablePoly node
                        #outer: findOuterBorderCornerVertsOnEditablePoly node
                        default: findBorderCornerVertsOnEditablePoly node
                    )

                    selection_ok = selectEditablePolyVerts node candidate_bits enter_subobject:(not multi_object and candidate_bits.numberSet > 0)

                    if candidate_bits.numberSet > 0 then
                    (
                        if findItem found_nodes node == 0 then append found_nodes node
                    )
                )

                format "% | node:% | target:% | selected:% | count:% | ok:%\n" class_label node.name target_type candidate_bits candidate_bits.numberSet selection_ok
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
    Selects the compatibility union of all non-T border corners.
    Existing callers keep the pre-split behavior.
    */
    function selectBorderCornerVerts =
    (
        this.selectBorderCornerVertsByClass #all
        -- return
    ),

    /*
    Selects only hole/reflex border corners such as the corners of an inner square opening.
    Existing true-two-edge and T-junction classifications are unaffected.
    */
    function selectInnerBorderCornerVerts =
    (
        this.selectBorderCornerVertsByClass #inner
        -- return
    ),

    /*
    Selects only exterior-perimeter border corners opposite to the inner-hole class.
    Existing true-two-edge and T-junction classifications are unaffected.
    */
    function selectOuterBorderCornerVerts =
    (
        this.selectBorderCornerVertsByClass #outer
        -- return
    ),

    /*
    Repeatedly searches the live topology and removes one highest-ID true two-edge vertex until no candidates remain.
    A fresh detector pass runs after every successful removal so topology changes never leave a stale candidate batch.
    */
    function removeTwoEdgeVertsUntilStable =
    (
        if selection.count != 1 then
        (
            format "Redundant Vertex Cleaner | REMOVE requires exactly one selected Editable Poly / Edit Poly object.\n"
            return 0
        )

        node = selection[1]
        if node == undefined or not(isValidNode node) then return 0

        target = getSelectionTarget node multi_object:false
        if target == undefined then return 0

        target_type = target[1]
        target_value = target[2]
        removed_count = 0
        search_count = 0
        failed_source = 0
        remaining_count = -1
        detection_failed = false
        selection_clear_failed = false
        keep_processing = true

        this.resetManualRemoveState()

        undo "Remove 2-Edge Verts Until Stable" on
        (
            while keep_processing do
            (
                valid_bits = #{}

                if target_type == #EditPoly then
                (
                    valid_bits = findTwoEdgeVertsOnEditPoly node target_value quiet_mode:true

                    if not(last_two_edge_detection_ok) then
                    (
                        detection_failed = true
                        keep_processing = false
                    )
                )
                else if target_type == #EditablePoly then
                (
                    valid_bits = findTwoEdgeVertsOnEditablePoly node

                    if not(last_two_edge_detection_ok) then
                    (
                        detection_failed = true
                        keep_processing = false
                    )
                )
                else
                (
                    keep_processing = false
                )

                if keep_processing then
                (
                    search_count += 1

                    if valid_bits.numberSet < 1 then
                    (
                        keep_processing = false
                    )
                    else
                    (
                        candidate_ids = valid_bits as array
                        sort candidate_ids
                        source_vertex = candidate_ids[candidate_ids.count]
                        removed_ok = false

                        if target_type == #EditPoly then
                        (
                            removed_ok = this.removeOneManualEditPolyVert node target_value source_vertex quiet_mode:true
                        )
                        else if target_type == #EditablePoly then
                        (
                            removed_ok = this.removeOneManualEditablePolyVert node source_vertex quiet_mode:true
                        )

                        if removed_ok then
                        (
                            removed_count += 1
                        )
                        else
                        (
                            failed_source = source_vertex
                            keep_processing = false
                        )
                    )
                )
            )
        )

        remaining_bits = #{}

        if target_type == #EditPoly then
        (
            remaining_bits = findTwoEdgeVertsOnEditPoly node target_value quiet_mode:true

            if last_two_edge_detection_ok then
            (
                remaining_count = remaining_bits.numberSet
            )
            else
            (
                detection_failed = true
            )

            current_selection = target_value.GetSelection #Vertex node:node

            if current_selection == undefined then
            (
                selection_clear_failed = true
                format "Redundant Vertex Cleaner | REMOVE | Edit Poly selection clear skipped because selection read failed.\n"
            )
            else if current_selection.numberSet > 0 then
            (
                target_value.Select #Vertex current_selection select:false node:node
            )

            target_value.RefreshScreen()
        )
        else if target_type == #EditablePoly then
        (
            remaining_bits = findTwoEdgeVertsOnEditablePoly node

            if last_two_edge_detection_ok then
            (
                remaining_count = remaining_bits.numberSet
                polyop.setVertSelection node.baseObject #{}
            )
            else
            (
                detection_failed = true
                selection_clear_failed = true
            )
        )

        this.resetManualRemoveState()
        update node
        completeRedraw()

        if detection_failed or selection_clear_failed or failed_source > 0 or remaining_count > 0 then
        (
            format "Redundant Vertex Cleaner | REMOVE incomplete | searches:% | removed:% | failedSource:% | detectionFailed:% | selectionClearFailed:% | remaining:%\n" search_count removed_count failed_source detection_failed selection_clear_failed remaining_count
        )

        removed_count
        -- return
    ),

    /*
    Compatibility wrapper for the project 0.824 batch API.
    The operation now performs fixed-point live SEARCH / REMOVE passes instead of consuming one captured selection.
    */
    function removeSelectedTwoEdgeVertsBatch =
    (
        this.removeTwoEdgeVertsUntilStable()
        -- return
    ),


    /*
    Selects degree-two vertices on exactly one selected supported object.
    force_mode:true selects every vertex with exactly two visible incident edges; false keeps the existing filtered classification.
    */
    function selectTwoEdgeVerts force_mode:false =
    (
        if selection.count != 1 then
        (
            format "Two Edge Verts | SEARCH requires exactly one selected Editable Poly / Edit Poly object.\n"
            return false
        )

        node = selection[1]
        if node == undefined or not(isValidNode node) then return false

        target = getSelectionTarget node multi_object:false
        if target == undefined then
        (
            format "Two Edge Verts | node:% | target:#Unsupported | selected:#{} | count:0 | ok:false\n" node.name
            return false
        )

        target_type = target[1]
        target_value = target[2]
        candidate_bits = #{}
        selection_ok = false

        if target_type == #EditPoly then
        (
            candidate_bits = findTwoEdgeVertsOnEditPoly node target_value force_mode:force_mode

            if not(last_two_edge_detection_ok) then
            (
                format "Two Edge Verts | node:% | target:#EditPoly | DETECT FAILED | ok:false\n" node.name
                return false
            )

            selection_ok = selectEditPolyVerts node target_value candidate_bits
        )
        else if target_type == #EditablePoly then
        (
            candidate_bits = findTwoEdgeVertsOnEditablePoly node force_mode:force_mode

            if not(last_two_edge_detection_ok) then
            (
                format "Two Edge Verts | node:% | target:#EditablePoly | DETECT FAILED | ok:false\n" node.name
                return false
            )

            selection_ok = selectEditablePolyVerts node candidate_bits enter_subobject:(candidate_bits.numberSet > 0)
        )

        format "Two Edge Verts | node:% | target:% | mode:% | selected:% | count:% | ok:%\n" node.name target_type (if force_mode then #Force else #Filtered) candidate_bits candidate_bits.numberSet selection_ok
        selection_ok
        -- return
    ),

    /*
    Returns valid two-visible-edge vertex IDs for one explicit EPoly node.
    INPUT: node and optional Edit Poly modifier. OUTPUT: BitArray of vertex IDs on that same live topology.
    */
    function getTwoEdgeVerts node edit_poly_mod:undefined =
    (
        last_two_edge_detection_ok = false

        if node == undefined or not(isValidNode node) then return #{}

        target = undefined

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return #{}
            if not(modifierBelongsToNode node edit_poly_mod) then return #{}
            target = #(#EditPoly, edit_poly_mod)
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
    function getTJunctionVerts node edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return #{}

        target = undefined

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return #{}
            if not(modifierBelongsToNode node edit_poly_mod) then return #{}
            target = #(#EditPoly, edit_poly_mod)
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
    Returns border T-junction vertex IDs for one explicit EPoly node.
    Border T-junctions are the T-junction subset whose straight-through pair lies on the open border.
    */
    function getBorderTJunctionVerts node edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return #{}

        target = undefined

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return #{}
            if not(modifierBelongsToNode node edit_poly_mod) then return #{}
            target = #(#EditPoly, edit_poly_mod)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return #{}

        case target[1] of
        (
            #EditPoly: findBorderTJunctionVertsOnEditPoly node target[2]
            #EditablePoly: findBorderTJunctionVertsOnEditablePoly node
            default: #{}
        )
        -- return
    ),

    /*
    Returns border-corner vertex IDs for one explicit EPoly node.
    INPUT: node and optional Edit Poly modifier. OUTPUT: BitArray on that same live topology.
    */
    function getBorderCornerVerts node edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return #{}

        target = undefined

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return #{}
            if not(modifierBelongsToNode node edit_poly_mod) then return #{}
            target = #(#EditPoly, edit_poly_mod)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return #{}

        case target[1] of
        (
            #EditPoly: findBorderCornerVertsOnEditPoly node target[2]
            #EditablePoly: findBorderCornerVertsOnEditablePoly node
            default: #{}
        )
        -- return
    ),

    /*
    Returns only inner/hole border-corner vertex IDs for one explicit EPoly node.
    INPUT: node and optional Edit Poly modifier. OUTPUT: BitArray on that same live topology.
    */
    function getInnerBorderCornerVerts node edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return #{}

        target = undefined

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return #{}
            if not(modifierBelongsToNode node edit_poly_mod) then return #{}
            target = #(#EditPoly, edit_poly_mod)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return #{}

        case target[1] of
        (
            #EditPoly: findInnerBorderCornerVertsOnEditPoly node target[2]
            #EditablePoly: findInnerBorderCornerVertsOnEditablePoly node
            default: #{}
        )
        -- return
    ),

    /*
    Returns only exterior-perimeter border-corner vertex IDs for one explicit EPoly node.
    INPUT: node and optional Edit Poly modifier. OUTPUT: BitArray on that same live topology.
    */
    function getOuterBorderCornerVerts node edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return #{}

        target = undefined

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return #{}
            if not(modifierBelongsToNode node edit_poly_mod) then return #{}
            target = #(#EditPoly, edit_poly_mod)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return #{}

        case target[1] of
        (
            #EditPoly: findOuterBorderCornerVertsOnEditPoly node target[2]
            #EditablePoly: findOuterBorderCornerVertsOnEditablePoly node
            default: #{}
        )
        -- return
    ),

    /*
    Returns only vertices connected to the source by actually visible edges.
    INPUT: node, source vertex ID, optional Edit Poly modifier. OUTPUT: Array of live neighbor vertex IDs.
    */
    function getVisibleNeighborVertexIds node source_vertex edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return #()
        if source_vertex < 1 then return #()

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return #()
            if not(modifierBelongsToNode node edit_poly_mod) then return #()
            return getActuallyVisibleEditPolyNeighborVerts node edit_poly_mod source_vertex
        )

        target = getSelectionTarget node multi_object:true
        if target == undefined then return #()

        case target[1] of
        (
            #EditPoly: getActuallyVisibleEditPolyNeighborVerts node target[2] source_vertex
            #EditablePoly:
            (
                topology_state = this.ensureCleanEditablePolyTopology node
                if topology_state != #clean then #() else getEditablePolyVisibleNeighborVerts node.baseObject source_vertex
            )
            default: #()
        )
        -- return
    ),

    /*
    Returns the closest vertex connected to the source by an actually visible edge.
    INPUT: node, source vertex ID, optional Edit Poly modifier. OUTPUT: live neighbor vertex ID, or 0 when none exists.
    */
    function getClosestVisibleNeighborVertexId node source_vertex edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return 0
        if source_vertex < 1 then return 0

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return 0
            if not(modifierBelongsToNode node edit_poly_mod) then return 0
            return getClosestEditPolyVisibleNeighborVert node edit_poly_mod source_vertex
        )

        target = getSelectionTarget node multi_object:true
        if target == undefined then return 0

        case target[1] of
        (
            #EditPoly: getClosestEditPolyVisibleNeighborVert node target[2] source_vertex
            #EditablePoly:
            (
                topology_state = this.ensureCleanEditablePolyTopology node
                if topology_state != #clean then 0 else getClosestEditablePolyVisibleNeighborVert node.baseObject source_vertex
            )
            default: 0
        )
        -- return
    ),

    /*
    Stores an explicit candidate BitArray for later manual processing after intersecting it with current valid two-edge vertices.
    INPUT: node, candidate BitArray, optional Edit Poly modifier. OUTPUT: ascending Array of stored live vertex IDs.
    */
    function storeCandidateIds node vertex_bits edit_poly_mod:undefined =
    (
        this.resetManualRemoveState()

        if node == undefined or not(isValidNode node) then return #()
        if vertex_bits == undefined or classOf vertex_bits != BitArray then return #()

        target = undefined

        if edit_poly_mod != undefined then
        (
            if classOf edit_poly_mod != Edit_Poly then return #()
            if not(modifierBelongsToNode node edit_poly_mod) then return #()
            target = #(#EditPoly, edit_poly_mod)
        )
        else
        (
            target = getSelectionTarget node multi_object:true
        )

        if target == undefined then return #()

        if target[1] == #EditablePoly then
        (
            topology_state = this.ensureCleanEditablePolyTopology node

            if topology_state == #collapsed then
            (
                format "REMOVE VERT DATA | Editable Poly input candidate IDs were invalidated by topology synchronization. Rebuild candidates from current topology.\n"
                return #()
            )

            if topology_state == #failed or topology_state == #blocked then return #()
        )

        valid_bits = #{}

        if target[1] == #EditPoly then
        (
            valid_bits = findTwoEdgeVertsOnEditPoly node target[2]

            if not(last_two_edge_detection_ok) then
            (
                format "REMOVE VERT DATA | Edit Poly true 2-edge detection failed while storing candidates.\n"
                return #()
            )
        )
        else if target[1] == #EditablePoly then
        (
            valid_bits = findTwoEdgeVertsOnEditablePoly node

            if not(last_two_edge_detection_ok) then return #()
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

        stored_id_copy = for stored_vertex_id in manual_remove_vertex_ids collect stored_vertex_id
        stored_id_copy
        -- return
    ),

    /*
    Returns a copy of the currently stored manual candidate IDs.
    INPUT: none. OUTPUT: ascending Array; the highest remaining ID is the last item.
    */
    function getStoredCandidateIds =
    (
        stored_id_copy = for stored_vertex_id in this.manual_remove_vertex_ids collect stored_vertex_id
        stored_id_copy
        -- return
    ),

    /*
    Returns the highest currently stored candidate ID without changing backend state.
    INPUT: none. OUTPUT: vertex ID Integer, or 0 when no candidate remains.
    */
    function getNextStoredCandidateId =
    (
        if this.manual_remove_vertex_ids == undefined or this.manual_remove_vertex_ids.count < 1 then return 0
        this.manual_remove_vertex_ids[this.manual_remove_vertex_ids.count]
        -- return
    ),

    /*
    Selects exactly one explicit live vertex ID on the requested EPoly topology.
    INPUT: node, vertex ID, optional Edit Poly modifier. OUTPUT: Boolean success.
    */
    function selectCandidateById node vertex_id edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return false
        if vertex_id < 1 then return false

        if edit_poly_mod != undefined then
        (
            return selectManualEditPolyVertex node edit_poly_mod vertex_id
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
    function fixCandidateById node source_vertex edit_poly_mod:undefined =
    (
        if node == undefined or not(isValidNode node) then return false
        if source_vertex < 1 then return false

        removed_ok = false
        undo "Remove One 2-Edge Vert" on
        (
            if edit_poly_mod != undefined then
            (
                removed_ok = removeOneManualEditPolyVert node edit_poly_mod source_vertex
            )
            else
            (
                target = getSelectionTarget node multi_object:true

                if target != undefined then
                (
                    if target[1] == #EditPoly then
                    (
                        removed_ok = removeOneManualEditPolyVert node target[2] source_vertex
                    )
                    else if target[1] == #EditablePoly then
                    (
                        removed_ok = removeOneManualEditablePolyVert node source_vertex
                    )
                )
            )
        )

        removed_ok
        -- return
    ),

    /*
    Welds one true two-edge Editable Poly source into its closest visible neighbor while preserving the opposite edge path.
    The source is removed by target weld only; native Remove Vertex is intentionally not used by FIX SELECTED VERT.
    */
    function fixSelectedEditablePolyVertKeepEdge node source_vertex =
    (
        if node == undefined or not(isValidNode node) then return false
        if classOf node.baseObject != Editable_Poly then return false

        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return false

        if topology_state == #collapsed then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Editable Poly | ABORT: collapseDeadStructs invalidated the supplied source ID.\n"
            return false
        )

        poly_value = node.baseObject
        forceSelectModeZero poly_value

        vertex_count = polyop.getNumVerts poly_value
        if source_vertex < 1 or source_vertex > vertex_count then return false

        valid_bits = findTwoEdgeVertsOnEditablePoly node
        if not(last_two_edge_detection_ok) then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Editable Poly | source:% | ERROR: true 2-edge detection failed.\n" source_vertex
            return false
        )

        if source_vertex > valid_bits.count or not(valid_bits[source_vertex]) then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Editable Poly | source:% | SKIP: source is not a live true 2-edge vertex.\n" source_vertex
            return false
        )

        visible_neighbors = getEditablePolyVisibleNeighborVerts poly_value source_vertex
        if visible_neighbors.count != 2 then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Editable Poly | source:% | ERROR: expected exactly two visible neighbors, got:%.\n" source_vertex visible_neighbors.count
            return false
        )

        target_vertex = getClosestEditablePolyVisibleNeighborVert poly_value source_vertex
        if target_vertex < 1 or findItem visible_neighbors target_vertex == 0 then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Editable Poly | source:% | ERROR: no valid visible-edge weld target.\n" source_vertex
            return false
        )

        target_position = polyop.getVert poly_value target_vertex
        before_count = vertex_count
        weld_ok = false

        try
        (
            weld_result = poly_value.weldVerts target_vertex source_vertex target_position
            weld_ok = weld_result == true
        )
        catch
        (
            exception_text = getCurrentException()
            format "Redundant Vertex Cleaner | FIX SELECTED | Editable Poly | source:% | target:% | mode:#TargetWeldKeepEdge | ERROR:%\n" source_vertex target_vertex exception_text
            weld_ok = false
        )

        update node
        this.invalidateStoredTopologyIdsForNode node
        topology_state = this.ensureCleanEditablePolyTopology node
        if topology_state == #failed or topology_state == #blocked then return false

        after_count = polyop.getNumVerts poly_value
        fixed_ok = weld_ok and after_count == (before_count - 1)

        format "Redundant Vertex Cleaner | FIX SELECTED | Editable Poly | source:% | target:% | mode:#TargetWeldKeepEdge | fixed:%\n" source_vertex target_vertex fixed_ok
        fixed_ok
        -- return
    ),

    /*
    Welds one true two-edge Edit Poly source into its closest visible neighbor while preserving the opposite edge path.
    The source is moved exactly onto the target before WeldVertices so the surviving target position does not move.
    */
    function fixSelectedEditPolyVertKeepEdge node edit_poly_mod source_vertex =
    (
        if node == undefined or not(isValidNode node) then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if not(modifierBelongsToNode node edit_poly_mod) then return false

        select node
        max modify mode

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = false
        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        if source_vertex < 1 or source_vertex > vertex_count then return false

        valid_bits = findTwoEdgeVertsOnEditPoly node edit_poly_mod quiet_mode:false
        if not(last_two_edge_detection_ok) then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Edit Poly | source:% | ERROR: true 2-edge detection failed.\n" source_vertex
            return false
        )

        if source_vertex > valid_bits.count or not(valid_bits[source_vertex]) then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Edit Poly | source:% | SKIP: source is not a live true 2-edge vertex.\n" source_vertex
            return false
        )

        visible_neighbors = getActuallyVisibleEditPolyNeighborVerts node edit_poly_mod source_vertex
        if visible_neighbors.count != 2 then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Edit Poly | source:% | ERROR: expected exactly two visible neighbors, got:%.\n" source_vertex visible_neighbors.count
            return false
        )

        target_vertex = getClosestEditPolyVisibleNeighborVert node edit_poly_mod source_vertex
        if target_vertex < 1 or findItem visible_neighbors target_vertex == 0 then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Edit Poly | source:% | ERROR: no valid visible-edge weld target.\n" source_vertex
            return false
        )

        current_selection = edit_poly_mod.GetSelection #Vertex node:node
        if current_selection == undefined then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Edit Poly | source:% | ERROR: selection read failed before target weld.\n" source_vertex
            return false
        )

        if current_selection.numberSet > 0 then
        (
            edit_poly_mod.Select #Vertex current_selection select:false node:node
        )

        single_vertex = #{}
        single_vertex[source_vertex] = true
        edit_poly_mod.Select #Vertex single_vertex select:true node:node

        selected_bits = edit_poly_mod.GetSelection #Vertex node:node
        if selected_bits == undefined or selected_bits != single_vertex then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED | Edit Poly | source:% | ERROR: source could not be selected for target weld.\n" source_vertex
            return false
        )

        source_position = EditPolyMod.GetVertex edit_poly_mod source_vertex node:node
        target_position = EditPolyMod.GetVertex edit_poly_mod target_vertex node:node
        move_amount = target_position - source_position
        before_count = vertex_count
        weld_ok = false

        try
        (
            edit_poly_mod.MoveSelection move_amount
            edit_poly_mod.Commit()
            edit_poly_mod.WeldVertices target_vertex source_vertex node:node
            edit_poly_mod.Commit()
            weld_ok = true
        )
        catch
        (
            exception_text = getCurrentException()
            format "Redundant Vertex Cleaner | FIX SELECTED | Edit Poly | source:% | target:% | mode:#TargetWeldKeepEdge | ERROR:%\n" source_vertex target_vertex exception_text
            weld_ok = false
        )

        edit_poly_mod.RefreshScreen()
        update node
        this.invalidateStoredTopologyIdsForNode node

        after_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        fixed_ok = weld_ok and after_count == (before_count - 1)

        format "Redundant Vertex Cleaner | FIX SELECTED | Edit Poly | source:% | target:% | mode:#TargetWeldKeepEdge | fixed:%\n" source_vertex target_vertex fixed_ok
        fixed_ok
        -- return
    ),

    /*
    Fixes the one currently selected true two-edge vertex without requiring stored SEARCH/manual queue state.
    INPUT: exactly one supported object with exactly one selected vertex. OUTPUT: Boolean success; successful topology change resets stale manual candidate state.
    */
    function fixSelectedVertex =
    (
        if selection.count != 1 then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED requires exactly one selected object.\n"
            return false
        )

        node = selection[1]
        if node == undefined or not(isValidNode node) then return false

        target = getSelectionTarget node multi_object:false
        if target == undefined then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED requires Editable Poly or Edit Poly.\n"
            return false
        )

        target_type = target[1]
        target_value = target[2]
        selected_bits = #{}

        if target_type == #EditPoly then
        (
            selected_bits = target_value.GetSelection #Vertex node:node
            if selected_bits == undefined then
            (
                format "Redundant Vertex Cleaner | FIX SELECTED | Edit Poly vertex selection read failed.\n"
                return false
            )
        )
        else if target_type == #EditablePoly then
        (
            topology_state = this.ensureCleanEditablePolyTopology node
            if topology_state == #failed or topology_state == #blocked then return false

            selected_bits = polyop.getVertSelection node.baseObject
        )
        else
        (
            return false
        )

        if classOf selected_bits != BitArray or selected_bits.numberSet != 1 then
        (
            format "Redundant Vertex Cleaner | FIX SELECTED requires exactly one selected vertex.\n"
            return false
        )

        selected_ids = selected_bits as array
        source_vertex = selected_ids[1]
        fixed_ok = false

        undo "Fix Selected 2-Edge Vert Keep Edge" on
        (
            if target_type == #EditPoly then
            (
                fixed_ok = fixSelectedEditPolyVertKeepEdge node target_value source_vertex
            )
            else
            (
                fixed_ok = fixSelectedEditablePolyVertKeepEdge node source_vertex
            )
        )

        if fixed_ok then
        (
            this.resetManualRemoveState()

            if target_type == #EditPoly then
            (
                current_selection = target_value.GetSelection #Vertex node:node
                if current_selection == undefined then
                (
                    format "Redundant Vertex Cleaner | FIX SELECTED | source:% | ERROR: final Edit Poly selection read failed; selection was not cleared.\n" source_vertex
                )
                else if current_selection.numberSet > 0 then
                (
                    target_value.Select #Vertex current_selection select:false node:node
                )
                target_value.RefreshScreen()
            )
            else
            (
                polyop.setVertSelection node.baseObject #{}
            )
        )

        update node
        completeRedraw()
        format "Redundant Vertex Cleaner | FIX SELECTED | source:% | fixed:%\n" source_vertex fixed_ok
        fixed_ok
        -- return
    ),

    on create do
    (
    )
)

TwoEdgeVerts = TwoEdgeVerts_v()
