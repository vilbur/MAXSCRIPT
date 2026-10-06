/*
    Two Visible Edge Verts 0.48
    Finds vertices with exactly two incident topology edges and selects them directly on the active Editable Poly or Edit Poly topology.
*/

global TwoVisibleEdgeVerts
global TwoVisibleEdgeVerts_UI
global EPolyToolsIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global EPOLY_TOOLS_MANAGER_PATH
global EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE
global EPOLY_TOOLS_MANAGER_LOAD_ERROR
global EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY
global EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY
global EPOLY_TOOLS_MANAGER_CANDIDATE_PATH
global EPOLY_TOOLS_MANAGER_SEARCH_DEPTH
global EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR
global epoly_tools_project_version

if EPolyToolsIntegration == undefined then
(
    EPOLY_TOOLS_MANAGER_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = getFilenamePath (getSourceFileName())
    EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DEPTH = 0

    while EPOLY_TOOLS_MANAGER_PATH == undefined and EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY != "" and EPOLY_TOOLS_MANAGER_SEARCH_DEPTH < 16 do
    (
        EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY + "EPolyManager.ms"

        if not(doesFileExist EPOLY_TOOLS_MANAGER_CANDIDATE_PATH) then
        (
            EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY + "PolyToosManager.ms"
        )

        if doesFileExist EPOLY_TOOLS_MANAGER_CANDIDATE_PATH then
        (
            EPOLY_TOOLS_MANAGER_PATH = EPOLY_TOOLS_MANAGER_CANDIDATE_PATH
        )
        else
        (
            EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY

            if EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count > 0 and EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR[EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count] == "\\" then
            (
                EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = substring EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR 1 (EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count - 1)
            )

            EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = getFilenamePath EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR

            if EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY == EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY then
            (
                EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = ""
            )
            else
            (
                EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY
            )
        )

        EPOLY_TOOLS_MANAGER_SEARCH_DEPTH += 1
    )

    EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_MANAGER_LOAD_ERROR = undefined
    EPOLY_TOOLS_RUNTIME_MODE = #library

    if EPOLY_TOOLS_MANAGER_PATH != undefined then
    (
        try
        (
            fileIn EPOLY_TOOLS_MANAGER_PATH quiet:true -- resolved parent EPolyManager.ms or legacy PolyToosManager.ms
        )
        catch
        (
            EPOLY_TOOLS_MANAGER_LOAD_ERROR = getCurrentException()
        )
    )
    else
    (
        EPOLY_TOOLS_MANAGER_LOAD_ERROR = "EPolyManager.ms or legacy PolyToosManager.ms was not found in any parent EPoly directory."
    )

    EPOLY_TOOLS_RUNTIME_MODE = EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE
    EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE = undefined
    EPOLY_TOOLS_MANAGER_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DEPTH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = undefined

    if EPOLY_TOOLS_MANAGER_LOAD_ERROR != undefined then
    (
        throw EPOLY_TOOLS_MANAGER_LOAD_ERROR
    )
)

struct TwoVisibleEdgeVerts_v
(
    file_version = 0.48,
    project_version = 0.48,
    ignore_border_corners = true,
    right_angle_dot_tolerance = 0.017452406,
    straight_pair_dot_limit = -0.999847695,

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
    Removes the supplied selected two-edge vertices from one Editable Poly base object using the stable single-vertex weld removal.
    Selected vertex positions are snapshotted once; each target is re-resolved and selected alone immediately before its weld.
    */
    function weldTwoEdgeEditablePolyVerts node vertex_bits =
    (
        if node == undefined or not(isValidNode node) then return 0
        if classOf node.baseObject != Editable_Poly then return 0
        if vertex_bits == undefined or vertex_bits.numberSet < 1 then return 0

        poly_value = node.baseObject
        forceSelectModeZero poly_value
        target_positions = #()
        target_vertices = vertex_bits as array
        welded_count = 0

        /*
        Capture target positions from highest original vertex ID to lowest.
        Vertex IDs are not reused after topology changes.
        */
        for target_index = target_vertices.count to 1 by -1 do
        (
            vertex_index = target_vertices[target_index]
            append target_positions (polyop.getVert poly_value vertex_index)
        )

        undo "Remove 2-Edge Verts" on
        (
            for target_position in target_positions do
            (
                current_vertex = findEditablePolyVertexByPosition poly_value target_position tolerance:0.0001

                if current_vertex > 0 then
                (
                    valid_bits = findTwoEdgeVertsOnEditablePoly node

                    if valid_bits[current_vertex] then
                    (
                        /*
                        Select exactly one current vertex resolved from the stored position,
                        then run the stable single-vertex weld removal.
                        */
                        polyop.setVertSelection poly_value #{current_vertex}
                        neighbor_vertices = getEditablePolyVisibleNeighborVerts poly_value current_vertex

                        if neighbor_vertices.count > 0 then
                        (
                            target_vertex = neighbor_vertices[1]
                            target_vertex_position = polyop.getVert poly_value target_vertex
                            before_count = polyop.getNumVerts poly_value

                            weld_ok = try
                            (
                                poly_value.weldVerts current_vertex target_vertex target_vertex_position
                                true
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
    Removes the supplied selected two-edge vertices from one existing Edit Poly modifier using the stable single-vertex weld removal.
    Selected vertex positions are snapshotted once; each target is re-resolved and selected alone immediately before its weld.
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

        target_positions = #()
        target_vertices = vertex_bits as array
        welded_count = 0

        /*
        Capture target positions from highest original vertex ID to lowest.
        Vertex IDs are not reused after topology changes.
        */
        for target_index = target_vertices.count to 1 by -1 do
        (
            vertex_index = target_vertices[target_index]
            append target_positions (EditPolyMod.GetVertex modifier vertex_index node:node)
        )

        undo "Remove 2-Edge Verts" on
        (
            for target_position in target_positions do
            (
                current_vertex = findEditPolyVertexByPosition node modifier target_position tolerance:0.0001

                if current_vertex > 0 then
                (
                    valid_bits = findTwoEdgeVertsOnEditPoly node modifier

                    if valid_bits[current_vertex] then
                    (
                        current_selection = modifier.GetSelection #Vertex node:node
                        if current_selection == undefined then current_selection = #{}

                        if current_selection.numberSet > 0 then
                        (
                            modifier.Select #Vertex current_selection select:false node:node
                        )

                        /*
                        Select exactly one current vertex resolved from the stored position,
                        then run the stable single-vertex weld removal.
                        */
                        modifier.Select #Vertex #{current_vertex} select:true node:node
                        target_vertex = getEditPolyVisibleNeighborByPosition node modifier current_vertex

                        if target_vertex > 0 then
                        (
                            target_vertex_position = EditPolyMod.GetVertex modifier target_vertex node:node
                            before_count = EditPolyMod.GetNumVertices modifier node:node

                            weld_ok = try
                            (
                                modifier.SetOperation #Transform
                                modifier.SetVert #{current_vertex} target_vertex_position node:node
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
                        )
                    )
                )
            )
        )

        current_selection = modifier.GetSelection #Vertex node:node
        if current_selection == undefined then current_selection = #{}

        if current_selection.numberSet > 0 then
        (
            modifier.Select #Vertex current_selection select:false node:node
        )

        modifier.RefreshScreen()
        update node
        completeRedraw()

        welded_count
        -- return
    ),

    /*
    Removes only the currently selected vertices that are still valid two-edge targets on each selected Epoly object.
    RMB snapshots their positions, re-resolves each current vertex by position, selects only that vertex, then runs the stable single-vertex weld removal.
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
    Finds the highest numeric versioned script for this tool in the current source directory.
    The current source file is used as fallback when no matching versioned file is found.
    */
    function getLatestScriptPath =
    (
        source_path = getSourceFileName()
        source_directory = getFilenamePath source_path
        file_prefix = "Two-Visible-Edge-Verts_"
        candidate_files = getFiles (source_directory + file_prefix + "*.ms")
        latest_path = source_path
        latest_version = -1.0

        for candidate_path in candidate_files do
        (
            candidate_name = getFilenameFile candidate_path

            if matchPattern candidate_name pattern:(file_prefix + "*") then
            (
                version_text = substring candidate_name (file_prefix.count + 1) (candidate_name.count - file_prefix.count)
                version_value = try(version_text as float)catch(-1.0)

                if version_value > latest_version then
                (
                    latest_version = version_value
                    latest_path = candidate_path
                )
            )
        )

        latest_path
        -- return
    ),

    /*
    Reloads the highest numeric versioned script found in this tool's source directory.
    This is the same action exposed by the RESTART button.
    */
    function restartLatest =
    (
        latest_path = getLatestScriptPath()
        if latest_path == undefined or latest_path == "" or not(doesFileExist latest_path) then return false

        fileIn latest_path quiet:true
        true
        -- return
    ),

    /*
    Opens the standalone tool dialog.
    Embedded and library loads can call this explicitly when UI is desired.
    */
    function showUI =
    (
        this.hideUI()
        createDialog TwoVisibleEdgeVerts_UI style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
        true
        -- return
    ),

    /*
    Closes the standalone tool dialog without changing the public API instance.
    */
    function hideUI =
    (
        try(destroyDialog TwoVisibleEdgeVerts_UI)catch()
        true
        -- return
    ),

    on create do
    (
    )
)

TwoVisibleEdgeVerts = TwoVisibleEdgeVerts_v()

rollout TwoVisibleEdgeVerts_UI "Two Edge Verts | v0.48" width:286 height:216
(
    button btn_restart "RESTART" pos:[12,10] width:262 height:24 tooltip:"LMB: Load the highest numeric Two-Visible-Edge-Verts version from this script directory."
    label lbl_info "Select topology cleanup vertices" pos:[12,40] width:262 height:18 align:#left
    button btn_select "SELECT 2-EDGE VERTS" pos:[12,62] width:262 height:30 tooltip:"LMB: Find vertices with exactly two incident topology edges on every selected Editable Poly or Edit Poly object.\n\nRMB: Store selected valid 2-edge vertex positions. Re-resolve and select one current vertex by position before each stable single-vertex weld."
    button btn_t_junction "SELECT T-JUNCTION VERTS" pos:[12,98] width:262 height:30 tooltip:"LMB: Find vertices with exactly three incident topology edges where two edges continue straight through the vertex."
    checkbox chk_ignore_border_corners "Ignore border corners" pos:[12,134] width:262 height:18 checked:true tooltip:"Ignore degree-two border vertices whose two border edges form a 90 degree corner."
    button btn_debug_clear "DEBUG: CLEAR EDIT POLY SELECTIONS" pos:[12,160] width:262 height:30 tooltip:"LMB: Clear Vertex, Edge, and Face selections from every Edit Poly modifier on all selected objects."

    on btn_restart pressed do
    (
        TwoVisibleEdgeVerts.restartLatest()
    )

    on btn_select pressed do
    (
        TwoVisibleEdgeVerts.ignore_border_corners = chk_ignore_border_corners.checked
        TwoVisibleEdgeVerts.selectTwoEdgeVerts()
    )

    on btn_select rightclick do
    (
        TwoVisibleEdgeVerts.ignore_border_corners = chk_ignore_border_corners.checked
        TwoVisibleEdgeVerts.removeTwoEdgeVerts()
    )

    on btn_t_junction pressed do
    (
        TwoVisibleEdgeVerts.selectTJunctionVerts()
    )

    on btn_debug_clear pressed do
    (
        TwoVisibleEdgeVerts.clearAllEditPolySelections()
    )
)


if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "two-visible-edge-verts" "Two Edge Verts" TwoVisibleEdgeVerts TwoVisibleEdgeVerts_UI TwoVisibleEdgeVerts.file_version TwoVisibleEdgeVerts.project_version (getSourceFileName()) capabilities:#(#detect, #selection, #remove, #vertex, #editable_poly, #edit_poly, #ui)

    if EPolyToolsIntegration.shouldAutoOpenUI() then TwoVisibleEdgeVerts.showUI()
)
else
(
    TwoVisibleEdgeVerts.showUI()
)
