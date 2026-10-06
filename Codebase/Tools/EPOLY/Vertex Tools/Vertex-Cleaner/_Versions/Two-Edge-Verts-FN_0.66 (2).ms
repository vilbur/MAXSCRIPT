/*
    Two Edge Verts Backend 0.66
    Reusable geometry backend for two-edge detection, selection, candidate storage, and visible-edge-only vertex fixes.

    Public input/output API:
    getTwoEdgeVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    getTJunctionVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    getBorderCornerVerts node edit_poly_mod:<Edit_Poly> -> BitArray
    selectTJunctionVerts() -> Boolean
    selectBorderCornerVerts() -> Boolean
    getVisibleNeighborVertexIds node source_vertex edit_poly_mod:<Edit_Poly> -> Array
    getClosestVisibleNeighborVertexId node source_vertex edit_poly_mod:<Edit_Poly> -> Integer
    storeCandidateIds node vertex_bits edit_poly_mod:<Edit_Poly> -> Array
    getStoredCandidateIds() -> Array
    getNextStoredCandidateId() -> Integer
    selectCandidateById node vertex_id edit_poly_mod:<Edit_Poly> -> Boolean
    fixCandidateById node source_vertex edit_poly_mod:<Edit_Poly> -> Boolean
*/

global TwoEdgeVerts
global epoly_tools_project_version

if epoly_tools_project_version == undefined or epoly_tools_project_version < 0.821 then
(
    epoly_tools_project_version = 0.821
)

struct TwoEdgeVerts_v
(
    file_version = 0.66,
    project_version = 0.821,
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
    Finds Editable Poly border corners independently from the true two-edge and T-junction classifications.
    Border corners have two border edges, are not T-junctions, and are not straight-through.
    */
    function findBorderCornerVertsOnEditablePoly node =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

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
    function findTwoEdgeVertsOnEditablePoly node =
    (
        if node == undefined or not(isValidNode node) then return #{}
        if classOf node.baseObject != Editable_Poly then return #{}

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
                if not(isEditablePolyTJunction node vertex_index) and not(isEditablePolyBorderCorner node vertex_index) then
                (
                    candidate_bits[vertex_index] = true
                )
            )
        )

        candidate_bits
        -- return
    ),

    /*
    Detects exact live Edit Poly vertex IDs by counting only live incident edges whose endpoint pair is visible in the evaluated mesh.
    The evaluated TriMesh is used only as an edge-visibility oracle; no TriMesh vertex or edge ID is copied into Edit Poly topology.
    */
    function findTwoEdgeVertsOnEditPoly node edit_poly_mod =
    (
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
        if vertex_count < 1 or edge_count < 1 then return #{}

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

        if snapshot_mesh == undefined then return #{}

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
                if not(isEditPolyTJunction node edit_poly_mod vertex_index) and not(isEditPolyBorderCorner node edit_poly_mod vertex_index) then
                (
                    candidate_bits[vertex_index] = true
                )
            )
        )

        delete snapshot_mesh

        format "Two Edge Verts DETECT | node:% | target:#EditPoly | candidates:% | count:%\n" node.name candidate_bits candidate_bits.numberSet
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

        old_vertices = edit_poly_mod.GetSelection #Vertex
        if old_vertices == undefined then old_vertices = #{}

        if old_vertices.numberSet > 0 then
        (
            edit_poly_mod.Select #Vertex old_vertices select:false
        )

        edit_poly_mod.Select #Vertex vertex_bits select:true
        stored_selection = edit_poly_mod.GetSelection #Vertex
        if stored_selection == undefined then stored_selection = #{}

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
        if current_selection == undefined then current_selection = #{}
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
    Removes one Editable Poly source vertex using the current stored source ID.
    The weld target is the closest vertex connected by an actually visible incident edge.
    */
    function removeOneManualEditablePolyVert node source_vertex =
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
        weld_ok = false

        try
        (
            weld_result = poly_value.weldVerts target_vertex source_vertex target_position
            weld_ok = weld_result == true
        )
        catch
        (
            exception_text = getCurrentException()
            format "REMOVE VERT | Editable Poly | source:% | target:% | ERROR:%\n" source_vertex target_vertex exception_text
            weld_ok = false
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
    function removeOneManualEditPolyVert node edit_poly_mod source_vertex =
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

        current_selection = edit_poly_mod.GetSelection #Vertex node:node
        if current_selection == undefined then current_selection = #{}
        if current_selection.numberSet > 0 then edit_poly_mod.Select #Vertex current_selection select:false node:node

        single_vertex = #{}
        single_vertex[source_vertex] = true
        edit_poly_mod.Select #Vertex single_vertex select:true node:node
        selected_bits = edit_poly_mod.GetSelection #Vertex node:node
        if selected_bits != single_vertex then return false

        target_vertex = getClosestEditPolyVisibleNeighborVert node edit_poly_mod source_vertex
        if target_vertex < 1 then return false

        source_position = EditPolyMod.GetVertex edit_poly_mod source_vertex node:node
        target_position = EditPolyMod.GetVertex edit_poly_mod target_vertex node:node
        move_amount = target_position - source_position
        before_count = vertex_count

        weld_ok = false

        try
        (
            edit_poly_mod.MoveSelection move_amount
            edit_poly_mod.Commit()
            /*
            Edit Poly uses the same endpoint ownership: first survives and second is killed.
            Native Edit Poly weld return values are not used as success flags; topology is verified below.
            */
            edit_poly_mod.WeldVertices target_vertex source_vertex node:node
            edit_poly_mod.Commit()
            weld_ok = true
        )
        catch
        (
            exception_text = getCurrentException()
            format "REMOVE VERT | Edit Poly | source:% | target:% | ERROR:%\n" source_vertex target_vertex exception_text
            weld_ok = false
        )

        edit_poly_mod.RefreshScreen()
        update node
        after_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
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
            queue_updated = this.removeStoredCandidateId source_vertex
            remaining_ids = for stored_vertex_id in this.manual_remove_vertex_ids collect stored_vertex_id

            if not(queue_updated) then
            (
                format "REMOVE VERT RMB | fixed:% | ERROR: processed ID was not removed from stored data:%\n" source_vertex remaining_ids
                this.resetManualRemoveState()
            )
            else
            (
                this.manual_remove_candidate_id = 0

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

                if remaining_ids.count > 0 then
                (
                    format "REMOVE VERT RMB | fixed:% | remaining:% | use LMB for next candidate.\n" source_vertex remaining_ids
                )
                else
                (
                    format "REMOVE VERT RMB | fixed:% | stored data complete.\n" source_vertex
                    this.resetManualRemoveState()
                )
            )
        )

        update node
        completeRedraw()
        removed_ok
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
    Finds border-corner vertices independently on every selected object and selects them on the same topology.
    This selector never returns T-junctions or true two-edge candidates.
    */
    function selectBorderCornerVerts =
    (
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

        for node in selected_nodes do
        (
            target = getSelectionTarget node multi_object:multi_object

            if target == undefined then
            (
                format "Border Corner Verts | node:% | target:#Unsupported | selected:#{} | count:0 | ok:false\n" node.name
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
                    candidate_bits = findBorderCornerVertsOnEditPoly node target_value

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
                    candidate_bits = findBorderCornerVertsOnEditablePoly node
                    selection_ok = selectEditablePolyVerts node candidate_bits enter_subobject:(not multi_object and candidate_bits.numberSet > 0)

                    if candidate_bits.numberSet > 0 then
                    (
                        if findItem found_nodes node == 0 then append found_nodes node
                    )
                )

                format "Border Corner Verts | node:% | target:% | selected:% | count:% | ok:%\n" node.name target_type candidate_bits candidate_bits.numberSet selection_ok
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
    Finds degree-two vertices on exactly one selected supported object and visibly selects them.
    Single-object SEARCH keeps the stored manual candidate IDs bound to one live topology.
    */
    function selectTwoEdgeVerts =
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
            candidate_bits = findTwoEdgeVertsOnEditPoly node target_value
            selection_ok = selectEditPolyVerts node target_value candidate_bits
        )
        else if target_type == #EditablePoly then
        (
            candidate_bits = findTwoEdgeVertsOnEditablePoly node
            selection_ok = selectEditablePolyVerts node candidate_bits enter_subobject:(candidate_bits.numberSet > 0)
        )

        format "Two Edge Verts | node:% | target:% | selected:% | count:% | ok:%\n" node.name target_type candidate_bits candidate_bits.numberSet selection_ok
        selection_ok
        -- return
    ),

    /*
    Returns valid two-visible-edge vertex IDs for one explicit EPoly node.
    INPUT: node and optional Edit Poly modifier. OUTPUT: BitArray of vertex IDs on that same live topology.
    */
    function getTwoEdgeVerts node edit_poly_mod:undefined =
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
            #EditablePoly: getEditablePolyVisibleNeighborVerts node.baseObject source_vertex
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
            #EditablePoly: getClosestEditablePolyVisibleNeighborVert node.baseObject source_vertex
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

    on create do
    (
    )
)

TwoEdgeVerts = TwoEdgeVerts_v()
