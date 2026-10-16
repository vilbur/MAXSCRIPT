/*
    Loop-Cleaner 1.218
    Clean rewrite development build.
*/

global RedundantLoopFixer
global RedundantLoopFixer1168
global RedundantLoopFixer_UI
global RedundantLoopFixer_Dialog_Position
global RedundantLoopFixer_Title
global RedundantLoopFixer_Source_File
global RedundantLoopFixer_Script_Reload_Path
global RedundantLoopFixer_Tool_Title_Button_Path
global EPolyToolsIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global epoly_tools_project_version
global RedundantLoopFixer_Previous_Pending_Node
global RedundantLoopFixer_Previous_Pending_Edit_Poly_Mod
global RedundantLoopFixer_Previous_Pending_Move_Records

RedundantLoopFixer_Previous_Pending_Node = undefined
RedundantLoopFixer_Previous_Pending_Edit_Poly_Mod = undefined
RedundantLoopFixer_Previous_Pending_Move_Records = #()

if RedundantLoopFixer != undefined then
(
    try
    (
        if RedundantLoopFixer.pending_broken_t_node != undefined and \
           RedundantLoopFixer.pending_broken_t_edit_poly_mod != undefined and \
           classOf RedundantLoopFixer.pending_broken_t_move_records == Array and \
           RedundantLoopFixer.pending_broken_t_move_records.count > 0 then
        (
            RedundantLoopFixer_Previous_Pending_Node = RedundantLoopFixer.pending_broken_t_node
            RedundantLoopFixer_Previous_Pending_Edit_Poly_Mod = RedundantLoopFixer.pending_broken_t_edit_poly_mod
            RedundantLoopFixer_Previous_Pending_Move_Records = RedundantLoopFixer.pending_broken_t_move_records
        )
    )
    catch
    (
        format "Loop-Cleaner BROKEN T PENDING STATE PRESERVE ERROR | %\n" (getCurrentException())
    )
)

RedundantLoopFixer_Source_File = getSourceFileName()

if RedundantLoopFixer_Source_File == undefined or RedundantLoopFixer_Source_File == "" then
(
    throw "Loop-Cleaner must be executed from a saved .ms file."
)

RedundantLoopFixer_Script_Reload_Path = (getFilenamePath RedundantLoopFixer_Source_File) + "..\\..\\..\\..\\..\\UI\\Default\\ScriptReload.ms"
RedundantLoopFixer_Tool_Title_Button_Path = (getFilenamePath RedundantLoopFixer_Source_File) + "..\\..\\..\\..\\..\\UI\\Default\\ToolTitleButton.ms"

if not doesFileExist RedundantLoopFixer_Script_Reload_Path then
(
    throw ("Missing shared UI dependency: " + RedundantLoopFixer_Script_Reload_Path)
)

if not doesFileExist RedundantLoopFixer_Tool_Title_Button_Path then
(
    throw ("Missing shared UI dependency: " + RedundantLoopFixer_Tool_Title_Button_Path)
)

fileIn RedundantLoopFixer_Script_Reload_Path
fileIn RedundantLoopFixer_Tool_Title_Button_Path

/*
Closes a previous standalone dialog before the rollout is redefined.
Preserves the last known standalone position when possible.
*/
try
(
    if RedundantLoopFixer_UI != undefined then
    (
        if RedundantLoopFixer_UI.inDialog then
        (
            try
            (
                RedundantLoopFixer_Dialog_Position = getDialogPos RedundantLoopFixer_UI
            )
            catch
            (
                format "Loop-Cleaner UI POSITION ERROR | %\n" (getCurrentException())
            )

            try
            (
                cui.UnRegisterDialogBar RedundantLoopFixer_UI
            )
            catch
            (
                format "Loop-Cleaner UI UNREGISTER ERROR | %\n" (getCurrentException())
            )

            try
            (
                destroyDialog RedundantLoopFixer_UI
            )
            catch
            (
                format "Loop-Cleaner UI CLOSE ERROR | %\n" (getCurrentException())
            )
        )
    )
)
catch
(
    format "Loop-Cleaner UI RESET ERROR | %\n" (getCurrentException())
)

struct RedundantLoopFixer1168_v
(
    file_version = 1.218,
    project_version = 1.218,
    quiet_mode = true,
    straight_angle_threshold = 5.0,
    geometry_corner_angle_threshold = 1.0,
    position_precision_text = "0.01mm",
    pending_broken_t_node = undefined,
    pending_broken_t_edit_poly_mod = undefined,
    pending_broken_t_move_records = #(),

    /*
    Resolves the currently active polygon editing domain on one node.
    Returns #(source_kind, source_value, selector_before_index).
    The selector position follows the same current-stack placement contract as the stable tool.
    */
    function getCurrentPolyTarget node =
    (
        if node == undefined or not isValidNode node then return #(#unsupported, undefined, 0)

        current_object = modPanel.getCurrentObject()

        if current_object != undefined and classOf current_object == Edit_Poly then
        (
            current_index = 0

            for stack_index = 1 to node.modifiers.count while current_index == 0 do
            (
                if node.modifiers[stack_index] == current_object then current_index = stack_index
            )

            if current_index > 0 then
            (
                selector_before_index = if current_index > 1 then current_index - 1 else 0
                return #(#edit_poly, current_object, selector_before_index)
            )
        )

        if current_object != undefined and classOf current_object == Editable_Poly then
        (
            if node.baseObject == current_object then
            (
                selector_before_index = if node.modifiers.count > 0 then node.modifiers.count else 0
                return #(#editable_poly, node.baseObject, selector_before_index)
            )
        )

        if node.modifiers.count == 0 and classOf node.baseObject == Editable_Poly then
        (
            return #(#editable_poly, node.baseObject, 0)
        )

        #(#unsupported, undefined, 0)
        -- return
    ),

    /*
    Ensures one base Editable Poly has compact live topology before any index-sensitive reads.
    If dead vertex/edge/face slots exist, collapseDeadStructs removes them before IDs are read.
    Returns true when the supplied Editable Poly is ready for fresh topology queries.
    */
    function ensureCleanEditablePolyTopology poly_value =
    (
        if poly_value == undefined or classOf poly_value != Editable_Poly then return false

        dead_flags = polyop.getHasDeadStructs poly_value

        if dead_flags != 0 then
        (
            polyop.collapseDeadStructs poly_value
            format "Loop-Cleaner DEAD TOPOLOGY CLEANED | flags:%\n" dead_flags
        )

        true
        -- return
    ),

    /*
    Returns the edge IDs that the current Editable Poly can actually store as an edge selection.
    This excludes component IDs rejected by the current Editable Poly state, such as edges hidden
    by current sub-object visibility. The previous edge selection is restored before returning.
    */
    function getSelectableEditablePolyEdges poly_value =
    (
        if poly_value == undefined or classOf poly_value != Editable_Poly then return undefined

        previous_edges = polyop.getEdgeSelection poly_value

        polyop.setEdgeSelection poly_value #all
        selectable_edges = polyop.getEdgeSelection poly_value

        polyop.setEdgeSelection poly_value previous_edges

        selectable_edges
        -- return
    ),

    /*
    Collects visible, currently selectable edges from one Editable Poly topology.
    Edge visibility alone is not enough: an edge can have getEdgeVis == true while its current
    sub-object visibility state still prevents that edge from being selected/displayed.
    */
    function getVisibleEditablePolyEdges poly_value =
    (
        if poly_value == undefined or classOf poly_value != Editable_Poly then return undefined

        edge_count = polyop.getNumEdges poly_value
        edge_vis_edges = #{}
        edge_vis_edges.count = edge_count

        for edge_index = 1 to edge_count do
        (
            if polyop.getEdgeVis poly_value edge_index then edge_vis_edges[edge_index] = true
        )

        selectable_edges = this.getSelectableEditablePolyEdges poly_value
        if selectable_edges == undefined then return undefined

        blocked_visible_edges = edge_vis_edges - selectable_edges

        if blocked_visible_edges.numberSet > 0 and not this.quiet_mode then
        (
            hidden_vertices = polyop.getHiddenVerts poly_value
            hidden_faces = polyop.getHiddenFaces poly_value
            blocked_by_hidden_vertex = #{}
            blocked_by_hidden_face = #{}
            blocked_other = #{}

            blocked_by_hidden_vertex.count = edge_count
            blocked_by_hidden_face.count = edge_count
            blocked_other.count = edge_count

            for edge_index in blocked_visible_edges do
            (
                edge_vertices = polyop.getEdgeVerts poly_value edge_index
                edge_faces = polyop.getFacesUsingEdge poly_value #{edge_index}
                has_hidden_vertex = false
                has_hidden_face = false

                if edge_vertices != undefined and edge_vertices.count == 2 then
                (
                    has_hidden_vertex = hidden_vertices[edge_vertices[1]] or hidden_vertices[edge_vertices[2]]
                )

                if edge_faces != undefined then
                (
                    has_hidden_face = (edge_faces * hidden_faces).numberSet > 0
                )

                if has_hidden_vertex then blocked_by_hidden_vertex[edge_index] = true
                if has_hidden_face then blocked_by_hidden_face[edge_index] = true

                if not has_hidden_vertex and not has_hidden_face then
                (
                    blocked_other[edge_index] = true
                )
            )

            format "Loop-Cleaner VISIBLE EDGE FILTER | edgeVisButNotSelectable:% | hiddenVertex:% | hiddenFace:% | other:%\n" blocked_visible_edges blocked_by_hidden_vertex blocked_by_hidden_face blocked_other
        )

        edge_vis_edges * selectable_edges
        -- return
    ),

    /*
    Reads visible-edge flags from the Editable Poly base only when the current Edit Poly has the exact same vertex and edge ID topology.
    This is a safe temporary bridge for the first clean-rewrite stage; topology-changing Edit Poly states are rejected.
    */
    function getVisibleEditPolyEdgesFromBase node edit_poly_mod =
    (
        if node == undefined or not isValidNode node then return undefined
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return undefined
        if classOf node.baseObject != Editable_Poly then return undefined

        base_poly = node.baseObject
        dead_flags = polyop.getHasDeadStructs base_poly

        if dead_flags != 0 then
        (
            format "Loop-Cleaner EDIT POLY BASE HAS DEAD TOPOLOGY | flags:% | base cleanup skipped to protect modifier indexing\n" dead_flags
            return undefined
        )

        base_vertex_count = polyop.getNumVerts base_poly
        base_edge_count = polyop.getNumEdges base_poly
        edit_vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        edit_edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node

        if base_vertex_count != edit_vertex_count then return undefined
        if base_edge_count != edit_edge_count then return undefined

        for edge_index = 1 to base_edge_count do
        (
            base_pair = polyop.getEdgeVerts base_poly edge_index
            edit_vertex_a = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 1 node:node
            edit_vertex_b = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 2 node:node

            if base_pair == undefined or base_pair.count != 2 then return undefined

            same_direction = base_pair[1] == edit_vertex_a and base_pair[2] == edit_vertex_b
            opposite_direction = base_pair[1] == edit_vertex_b and base_pair[2] == edit_vertex_a

            if not same_direction and not opposite_direction then return undefined
        )

        this.getVisibleEditablePolyEdges base_poly
        -- return
    ),

    /*
    Returns explicit edge creases from Editable Poly edge-data channel 2.
    Unsupported crease data means no explicit crease is present.
    */
    function getCreaseEdges poly_value edge_count =
    (
        crease_edges = #{}
        crease_edges.count = edge_count

        if polyop.getEDataChannelSupport poly_value 2 then
        (
            for edge_index = 1 to edge_count do
            (
                crease_value = polyop.getEDataValue poly_value 2 edge_index
                if crease_value != undefined and crease_value != 0.0 then crease_edges[edge_index] = true
            )
        )

        crease_edges
        -- return
    ),

    /*
    Builds one polygon-topology snapshot from the exact base Editable Poly used for detection.
    Vertex positions and face normals are captured in world space; native polygon edge IDs are preserved.
    Returns:
    #(vertexCount, edgeCount, faceCount, vertexPoints, vertexEdges, edgeVertices,
      edgeFaces, borderEdges, borderVertices, faceNormals, faceValid, visibleEdges, creaseEdges)
    */
    function buildEditablePolyTopology node poly_value visible_edges =
    (
        if node == undefined or not isValidNode node then return undefined
        if poly_value == undefined or classOf poly_value != Editable_Poly then return undefined
        if visible_edges == undefined then return undefined

        vertex_count = polyop.getNumVerts poly_value
        edge_count = polyop.getNumEdges poly_value
        face_count = polyop.getNumFaces poly_value

        if vertex_count < 2 or edge_count < 1 or face_count < 1 then return undefined

        vertex_points = #()
        vertex_edges = #()

        for vertex_index = 1 to vertex_count do
        (
            vertex_point = undefined

            in coordsys world
            (
                vertex_point = polyop.getVert poly_value vertex_index node:node
            )

            append vertex_points vertex_point
            append vertex_edges #{}
        )

        edge_vertices = #()
        edge_faces = #()
        border_edges = #{}
        border_vertices = #{}
        border_edges.count = edge_count
        border_vertices.count = vertex_count

        for edge_index = 1 to edge_count do
        (
            edge_pair = polyop.getEdgeVerts poly_value edge_index
            edge_face_array = polyop.getEdgeFaces poly_value edge_index

            edge_valid = edge_pair != undefined and edge_pair.count == 2

            if edge_valid then
            (
                edge_valid = edge_pair[1] >= 1 and edge_pair[1] <= vertex_count and edge_pair[2] >= 1 and edge_pair[2] <= vertex_count
            )

            if edge_valid then
            (
                append edge_vertices #(edge_pair[1], edge_pair[2])
                vertex_edges[edge_pair[1]][edge_index] = true
                vertex_edges[edge_pair[2]][edge_index] = true

                face_a = 0
                face_b = 0

                if edge_face_array != undefined then
                (
                    if edge_face_array.count >= 1 then face_a = edge_face_array[1]
                    if edge_face_array.count >= 2 then face_b = edge_face_array[2]
                )

                append edge_faces #(face_a, face_b)

                if face_a > 0 and face_b == 0 then
                (
                    border_edges[edge_index] = true
                    border_vertices[edge_pair[1]] = true
                    border_vertices[edge_pair[2]] = true
                )
            )
            else
            (
                append edge_vertices undefined
                append edge_faces undefined
            )
        )

        face_normals = #()
        face_valid = #{}
        face_valid.count = face_count

        for face_index = 1 to face_count do
        (
            face_vertices = polyop.getFaceVerts poly_value face_index
            face_normal = undefined

            if face_vertices != undefined and face_vertices.count >= 3 then
            (
                in coordsys world
                (
                    face_normal = polyop.getFaceNormal poly_value face_index node:node
                )

                if face_normal != undefined and length face_normal > 0.0 then
                (
                    face_normal = normalize face_normal
                    face_valid[face_index] = true
                )
                else
                (
                    face_normal = undefined
                )
            )

            append face_normals face_normal
        )

        crease_edges = this.getCreaseEdges poly_value edge_count

        #(
            vertex_count,
            edge_count,
            face_count,
            vertex_points,
            vertex_edges,
            edge_vertices,
            edge_faces,
            border_edges,
            border_vertices,
            face_normals,
            face_valid,
            copy visible_edges,
            crease_edges
        )
        -- return
    ),

    /*
    Returns the exact world-space length of one topology edge.
    No epsilon or hidden tolerance is used.
    */
    function getTopologyEdgeLength edge_index topology_data =
    (
        if topology_data == undefined then return 0.0

        edge_vertices = topology_data[6]
        vertex_points = topology_data[4]

        if edge_index < 1 or edge_index > edge_vertices.count then return 0.0

        edge_pair = edge_vertices[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return 0.0

        point_a = vertex_points[edge_pair[1]]
        point_b = vertex_points[edge_pair[2]]
        distance point_a point_b
        -- return
    ),

    /*
    Returns true when one internal edge separates two different polygon planes.
    Opposite face normals are treated as the same plane.
    */
    function edgeSeparatesGeometryPlanes edge_index topology_data angle_threshold =
    (
        if topology_data == undefined then return false

        edge_faces = topology_data[7]
        face_normals = topology_data[10]
        face_valid = topology_data[11]

        if edge_index < 1 or edge_index > edge_faces.count then return false

        face_pair = edge_faces[edge_index]
        if face_pair == undefined or face_pair.count != 2 then return false

        face_a = face_pair[1]
        face_b = face_pair[2]

        if face_a < 1 or face_b < 1 or face_a > face_normals.count or face_b > face_normals.count then return false
        if not face_valid[face_a] or not face_valid[face_b] then return false

        normal_a = face_normals[face_a]
        normal_b = face_normals[face_b]

        if normal_a == undefined or normal_b == undefined then return false

        face_dot = abs(dot normal_a normal_b)
        face_dot < (cos angle_threshold)
        -- return
    ),

    /*
    Applies the structural negative filters to the visible/selectable edge domain.
    Returns #(candidateEdges, borderProtected, geometryCornerProtected, creaseProtected, invalidProtected).
    */
    function buildRedundantCandidates topology_data geometry_corner_angle =
    (
        if topology_data == undefined then return undefined

        edge_count = topology_data[2]
        face_count = topology_data[3]
        edge_vertices = topology_data[6]
        edge_faces = topology_data[7]
        border_edges = topology_data[8]
        visible_edges = topology_data[12]
        crease_edges = topology_data[13]

        candidate_edges = copy visible_edges
        border_protected = visible_edges * border_edges
        crease_protected = visible_edges * crease_edges
        geometry_corner_protected = #{}
        invalid_protected = #{}

        geometry_corner_protected.count = edge_count
        invalid_protected.count = edge_count

        candidate_edges -= border_protected
        candidate_edges -= crease_protected

        candidate_snapshot = copy candidate_edges

        for edge_index in candidate_snapshot do
        (
            edge_pair = edge_vertices[edge_index]
            face_pair = edge_faces[edge_index]
            edge_ok = edge_pair != undefined and edge_pair.count == 2 and face_pair != undefined and face_pair.count == 2

            if edge_ok then
            (
                edge_ok = face_pair[1] > 0 and face_pair[2] > 0 and face_pair[1] <= face_count and face_pair[2] <= face_count
            )

            if edge_ok then
            (
                edge_ok = this.getTopologyEdgeLength edge_index topology_data > 0.0
            )

            if not edge_ok then
            (
                candidate_edges[edge_index] = false
                invalid_protected[edge_index] = true
            )
            else if this.edgeSeparatesGeometryPlanes edge_index topology_data geometry_corner_angle then
            (
                candidate_edges[edge_index] = false
                geometry_corner_protected[edge_index] = true
            )
        )

        #(candidate_edges, border_protected, geometry_corner_protected, crease_protected, invalid_protected)
        -- return
    ),

    /*
    Returns the opposite endpoint of one edge at one vertex, or 0 when the edge is invalid there.
    */
    function getOtherEdgeVertex edge_index vertex_index topology_data =
    (
        if topology_data == undefined then return 0

        edge_vertices = topology_data[6]
        if edge_index < 1 or edge_index > edge_vertices.count then return 0

        edge_pair = edge_vertices[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return 0

        if edge_pair[1] == vertex_index then return edge_pair[2]
        if edge_pair[2] == vertex_index then return edge_pair[1]

        0
        -- return
    ),

    /*
    Returns the best complete straight-pair score for one set of incident ring edges.
    1.0 is perfectly straight; -2.0 means no complete straight pairing exists.
    */
    function getBestStraightPairScore vertex_index edge_bits topology_data =
    (
        if edge_bits == undefined then return -2.0
        if topology_data == undefined then return -2.0

        edge_count = edge_bits.numberSet
        if edge_count == 0 then return 1.0
        if (mod edge_count 2) != 0 then return -2.0

        edge_array = edge_bits as array
        first_edge = edge_array[1]
        first_direction = undefined

        other_vertex = this.getOtherEdgeVertex first_edge vertex_index topology_data
        vertex_points = topology_data[4]

        if other_vertex < 1 or other_vertex > vertex_points.count then return -2.0
        if vertex_index < 1 or vertex_index > vertex_points.count then return -2.0

        first_vector = vertex_points[other_vertex] - vertex_points[vertex_index]
        if length first_vector == 0.0 then return -2.0

        first_direction = normalize first_vector
        best_score = -2.0

        for pair_index = 2 to edge_array.count do
        (
            pair_edge = edge_array[pair_index]
            pair_other = this.getOtherEdgeVertex pair_edge vertex_index topology_data

            if pair_other >= 1 and pair_other <= vertex_points.count then
            (
                pair_vector = vertex_points[pair_other] - vertex_points[vertex_index]

                if length pair_vector > 0.0 then
                (
                    pair_direction = normalize pair_vector
                    pair_score = -(dot first_direction pair_direction)
                    remaining_edges = copy edge_bits
                    remaining_edges[first_edge] = false
                    remaining_edges[pair_edge] = false
                    remaining_score = this.getBestStraightPairScore vertex_index remaining_edges topology_data

                    if remaining_score > -2.0 then
                    (
                        combined_score = if pair_score < remaining_score then pair_score else remaining_score
                        if combined_score > best_score then best_score = combined_score
                    )
                )
            )
        )

        best_score
        -- return
    ),

    /*
    Returns the straight-through score of the visible ring edges left after choosing two chain edges.
    The chain pair itself may turn by any amount.
    */
    function getRingStraightnessScore vertex_index chain_pair topology_data =
    (
        if topology_data == undefined or chain_pair == undefined then return -2.0

        vertex_edges = topology_data[5]
        visible_edges = topology_data[12]

        if vertex_index < 1 or vertex_index > vertex_edges.count then return -2.0

        ring_edges = vertex_edges[vertex_index] * visible_edges
        ring_edges -= chain_pair

        this.getBestStraightPairScore vertex_index ring_edges topology_data
        -- return
    ),

    /*
    Tests whether one border vertex is a clean straight-through border point.
    This restores the 0.819 border-corner classifier on the clean topology snapshot.
    */
    function isStraightBorderVertex vertex_index topology_data angle_threshold:5.0 =
    (
        if topology_data == undefined then return false

        vertex_edges = topology_data[5]
        border_edges = topology_data[8]

        if vertex_index < 1 or vertex_index > vertex_edges.count then return false

        raw_border_edges = vertex_edges[vertex_index] * border_edges
        if raw_border_edges.numberSet != 2 then return false

        straight_score = this.getBestStraightPairScore vertex_index raw_border_edges topology_data
        straight_score >= (cos angle_threshold)
        -- return
    ),

    /*
    Tests whether one vertex is a border corner or border branch.
    Any border incidence that is not one straight-through pair is classified as a corner condition.
    */
    function isBorderCornerVertex vertex_index topology_data angle_threshold:5.0 =
    (
        if topology_data == undefined then return true

        vertex_edges = topology_data[5]
        border_edges = topology_data[8]

        if vertex_index < 1 or vertex_index > vertex_edges.count then return true

        raw_border_edges = vertex_edges[vertex_index] * border_edges
        if raw_border_edges.numberSet == 0 then return false

        not(this.isStraightBorderVertex vertex_index topology_data angle_threshold:angle_threshold)
        -- return
    ),

    /*
    Collects border corner and border branch vertices before loop tracing.
    Straight-through border vertices are excluded.
    */
    function getBorderCornerVertices topology_data angle_threshold:1.0 =
    (
        border_corner_vertices = #{}
        if topology_data == undefined then return border_corner_vertices

        vertex_edges = topology_data[5]

        for vertex_index = 1 to vertex_edges.count do
        (
            if this.isBorderCornerVertex vertex_index topology_data angle_threshold:angle_threshold then
            (
                border_corner_vertices[vertex_index] = true
            )
        )

        border_corner_vertices
        -- return
    ),

    /*
    Returns the best continuation used by the restored 0.819 debug loop tracer.
    The loop may turn; the remaining incident ring edges determine the continuation score.
    */
    function getBestLoopContinuation edge_index vertex_index candidate_edges topology_data straight_limit =
    (
        if topology_data == undefined or candidate_edges == undefined then return 0

        vertex_edges = topology_data[5]
        if vertex_index < 1 or vertex_index > vertex_edges.count then return 0

        incident_candidates = copy (vertex_edges[vertex_index] * candidate_edges)
        incident_candidates[edge_index] = false

        best_edge = 0
        best_ring_score = -3.0

        for neighbor_edge in incident_candidates do
        (
            loop_pair = #{}
            loop_pair[edge_index] = true
            loop_pair[neighbor_edge] = true

            ring_edges = vertex_edges[vertex_index] - loop_pair
            ring_score = this.getBestStraightPairScore vertex_index ring_edges topology_data

            if ring_score > best_ring_score then
            (
                best_ring_score = ring_score
                best_edge = neighbor_edge
            )
        )

        if best_edge > 0 and best_ring_score >= straight_limit then best_edge else 0
        -- return
    ),

    /*
    Traces one candidate loop outward from one border-corner seed edge.
    Tracing stops at another border corner or when no valid 0.819-style continuation remains.
    */
    function traceLoopFromBorderCorner corner_vertex seed_edge topology_data candidate_edges border_corner_vertices max_turn_threshold:45.0 =
    (
        empty_record = #(#{}, corner_vertex, corner_vertex)
        if topology_data == undefined then return empty_record
        if candidate_edges == undefined or border_corner_vertices == undefined then return empty_record

        vertex_edges = topology_data[5]
        edge_vertices = topology_data[6]

        if corner_vertex < 1 or corner_vertex > vertex_edges.count then return empty_record
        if seed_edge < 1 or seed_edge > edge_vertices.count then return empty_record
        if not candidate_edges[seed_edge] then return empty_record

        seed_pair = edge_vertices[seed_edge]
        if seed_pair == undefined or seed_pair.count != 2 then return empty_record

        next_vertex = this.getOtherEdgeVertex seed_edge corner_vertex topology_data
        if next_vertex < 1 then return empty_record

        chain_edges = #{}
        chain_edges[seed_edge] = true
        current_edge = seed_edge
        current_vertex = next_vertex
        walking = true
        ring_limit = cos max_turn_threshold

        while walking do
        (
            if current_vertex != corner_vertex and border_corner_vertices[current_vertex] then
            (
                walking = false
            )
            else
            (
                available_edges = copy candidate_edges
                available_edges -= chain_edges

                next_edge = this.getBestLoopContinuation current_edge current_vertex available_edges topology_data ring_limit

                if next_edge < 1 then
                (
                    walking = false
                )
                else
                (
                    chain_edges[next_edge] = true
                    next_vertex = this.getOtherEdgeVertex next_edge current_vertex topology_data

                    if next_vertex < 1 then
                    (
                        walking = false
                    )
                    else
                    (
                        current_edge = next_edge
                        current_vertex = next_vertex
                    )
                )
            )
        )

        #(chain_edges, corner_vertex, current_vertex)
        -- return
    ),

    /*
    Builds all border-corner loop records using the restored 0.819 tracing rule.
    Duplicate edge sets are removed with the same deterministic chain key used by the old implementation.
    */
    function buildBorderCornerLoopRecords topology_data candidate_edges max_turn_threshold:45.0 =
    (
        border_corner_records = #()
        if topology_data == undefined or candidate_edges == undefined then return border_corner_records

        vertex_edges = topology_data[5]
        border_corner_vertices = this.getBorderCornerVertices topology_data angle_threshold:1.0
        record_keys = #()

        for corner_vertex in border_corner_vertices do
        (
            incident_candidates = vertex_edges[corner_vertex] * candidate_edges

            for seed_edge in incident_candidates do
            (
                loop_record = this.traceLoopFromBorderCorner corner_vertex seed_edge topology_data candidate_edges border_corner_vertices max_turn_threshold:max_turn_threshold

                if loop_record[1].numberSet > 0 then
                (
                    chain_key = this.makeChainKey loop_record[1]

                    if findItem record_keys chain_key == 0 then
                    (
                        append record_keys chain_key
                        append border_corner_records loop_record
                    )
                )
            )
        )

        border_corner_records
        -- return
    ),

    /*
    Builds complete loop records with the restored 0.819 debug tracer.
    A candidate edge is assigned to at most one record.
    */
    function buildDebugLoopRecordsFromTopology topology_data candidate_edges =
    (
        loop_records = #()
        if topology_data == undefined or candidate_edges == undefined then return loop_records

        remaining_edges = copy candidate_edges
        edge_vertices = topology_data[6]

        for seed_edge in candidate_edges do
        (
            if remaining_edges[seed_edge] then
            (
                seed_pair = edge_vertices[seed_edge]

                if seed_pair != undefined and seed_pair.count == 2 then
                (
                    chain_edges = #{}
                    chain_edges[seed_edge] = true
                    remaining_edges[seed_edge] = false
                    endpoint_a = seed_pair[1]
                    endpoint_b = seed_pair[2]

                    for direction_index = 1 to 2 do
                    (
                        current_edge = seed_edge
                        current_vertex = seed_pair[direction_index]
                        walking = true

                        while walking do
                        (
                            next_edge = this.getBestLoopContinuation current_edge current_vertex remaining_edges topology_data -2.0

                            if next_edge < 1 then
                            (
                                walking = false
                            )
                            else
                            (
                                chain_edges[next_edge] = true
                                remaining_edges[next_edge] = false
                                next_vertex = this.getOtherEdgeVertex next_edge current_vertex topology_data

                                if next_vertex < 1 then
                                (
                                    walking = false
                                )
                                else
                                (
                                    current_edge = next_edge
                                    current_vertex = next_vertex
                                )
                            )
                        )

                        if direction_index == 1 then endpoint_a = current_vertex else endpoint_b = current_vertex
                    )

                    append loop_records #(chain_edges, endpoint_a, endpoint_b)
                )
                else
                (
                    remaining_edges[seed_edge] = false
                )
            )
        )

        loop_records
        -- return
    ),

    /*
    Builds wall-corner loop records from candidate edges whose adjacent face normals lie on different planes.
    This is the restored 0.819 wall-corner classifier reused by debug and production masking.
    */
    function buildWallCornerLoopRecords topology_data candidate_edges wall_angle_threshold =
    (
        wall_corner_edges = #{}
        if topology_data == undefined or candidate_edges == undefined then return #()

        for edge_index in candidate_edges do
        (
            if this.edgeSeparatesGeometryPlanes edge_index topology_data wall_angle_threshold then
            (
                wall_corner_edges[edge_index] = true
            )
        )

        if wall_corner_edges.numberSet == 0 then return #()
        this.buildDebugLoopRecordsFromTopology topology_data wall_corner_edges
        -- return
    ),

    /*
    Returns a deterministic comma-separated key for one Edge BitArray.
    */
    function makeChainKey chain_edges =
    (
        key_text = ""
        for edge_index in chain_edges do key_text += (edge_index as string) + ","
        key_text
        -- return
    ),

    /*
    Chooses one continuation edge by the best complete ring straightness.
    ANGLE applies only to the remaining ring topology; the redundant chain itself may turn.
    Equal scores remain deterministic through native ascending edge-ID iteration.
    */
    function getBestChainContinuation edge_index vertex_index available_candidates topology_data angle_threshold =
    (
        if topology_data == undefined or available_candidates == undefined then return 0

        vertex_edges = topology_data[5]
        if vertex_index < 1 or vertex_index > vertex_edges.count then return 0

        incident_candidates = vertex_edges[vertex_index] * available_candidates
        incident_candidates[edge_index] = false

        if incident_candidates.numberSet == 0 then return 0

        straight_limit = cos angle_threshold
        best_edge = 0
        best_score = -2.0

        for neighbor_edge in incident_candidates do
        (
            chain_pair = #{}
            chain_pair[edge_index] = true
            chain_pair[neighbor_edge] = true

            ring_score = this.getRingStraightnessScore vertex_index chain_pair topology_data

            if ring_score >= straight_limit and ring_score > best_score then
            (
                best_score = ring_score
                best_edge = neighbor_edge
            )
        )

        best_edge
        -- return
    ),

    /*
    Traces one complete candidate chain in both directions from one seed.
    Already-assigned edges from earlier records are unavailable, and edges already consumed by this
    chain are never reused. A closed loop naturally ends with identical endpoint IDs.
    Returns #(chainEdges, endpointA, endpointB).
    */
    function traceCandidateChain seed_edge remaining_edges topology_data angle_threshold =
    (
        empty_record = #(#{}, 0, 0)

        if topology_data == undefined or remaining_edges == undefined then return empty_record
        if seed_edge < 1 or seed_edge > topology_data[2] then return empty_record
        if not remaining_edges[seed_edge] then return empty_record

        edge_vertices = topology_data[6]
        seed_pair = edge_vertices[seed_edge]

        if seed_pair == undefined or seed_pair.count != 2 then return empty_record

        chain_edges = #{}
        chain_edges[seed_edge] = true
        endpoint_a = seed_pair[1]
        endpoint_b = seed_pair[2]

        for direction_index = 1 to 2 do
        (
            current_edge = seed_edge
            current_vertex = seed_pair[direction_index]
            walking = true

            while walking do
            (
                available_edges = copy remaining_edges
                available_edges -= chain_edges

                next_edge = this.getBestChainContinuation current_edge current_vertex available_edges topology_data angle_threshold

                if next_edge == 0 then
                (
                    walking = false
                )
                else
                (
                    chain_edges[next_edge] = true
                    next_vertex = this.getOtherEdgeVertex next_edge current_vertex topology_data

                    if next_vertex < 1 then
                    (
                        walking = false
                    )
                    else
                    (
                        current_edge = next_edge
                        current_vertex = next_vertex
                    )
                )
            )

            if direction_index == 1 then endpoint_a = current_vertex else endpoint_b = current_vertex
        )

        #(chain_edges, endpoint_a, endpoint_b)
        -- return
    ),

    /*
    Partitions every candidate edge into one traced chain/loop record.
    Each candidate belongs to exactly one record.
    */
    function buildCandidateChainRecords candidate_edges topology_data angle_threshold =
    (
        chain_records = #()

        if candidate_edges == undefined or candidate_edges.numberSet == 0 then return chain_records
        if topology_data == undefined then return chain_records

        remaining_edges = copy candidate_edges

        for seed_edge in candidate_edges do
        (
            if remaining_edges[seed_edge] then
            (
                chain_record = this.traceCandidateChain seed_edge remaining_edges topology_data angle_threshold

                if chain_record[1].numberSet > 0 then
                (
                    append chain_records chain_record
                    remaining_edges -= chain_record[1]
                )
                else
                (
                    remaining_edges[seed_edge] = false
                )
            )
        )

        chain_records
        -- return
    ),

    /*
    Validates one already-traced whole chain/loop.
    Closed loops require valid ring pairing at every used vertex.
    Open chains are rejected at mesh-border terminals. Internal terminals are accepted only when
    removing the one chain edge leaves at least one complete straight-through ring pair within ANGLE.
    */
    function validateCandidateChain chain_record topology_data angle_threshold =
    (
        if chain_record == undefined or chain_record.count < 3 then return #(false, "invalid record")
        if topology_data == undefined then return #(false, "missing topology")

        chain_edges = chain_record[1]
        endpoint_a = chain_record[2]
        endpoint_b = chain_record[3]

        if chain_edges == undefined or chain_edges.numberSet == 0 then return #(false, "empty chain")

        vertex_edges = topology_data[5]
        edge_vertices = topology_data[6]
        border_vertices = topology_data[9]
        visible_edges = topology_data[12]
        used_vertices = #{}
        used_vertices.count = topology_data[1]
        closed_loop = endpoint_a > 0 and endpoint_a == endpoint_b

        for edge_index in chain_edges do
        (
            edge_pair = edge_vertices[edge_index]
            if edge_pair == undefined or edge_pair.count != 2 then return #(false, "invalid edge")

            used_vertices[edge_pair[1]] = true
            used_vertices[edge_pair[2]] = true
        )

        straight_limit = cos angle_threshold

        for vertex_index in used_vertices do
        (
            chain_incident_edges = vertex_edges[vertex_index] * chain_edges
            chain_degree = chain_incident_edges.numberSet
            is_endpoint = not closed_loop and (vertex_index == endpoint_a or vertex_index == endpoint_b)

            if is_endpoint then
            (
                if chain_degree != 1 then return #(false, "endpoint degree")

                if border_vertices[vertex_index] then
                (
                    return #(false, "border terminal")
                )

                remaining_ring_edges = vertex_edges[vertex_index] * visible_edges
                remaining_ring_edges -= chain_incident_edges

                if remaining_ring_edges.numberSet < 2 then
                (
                    return #(false, "unsupported internal terminal")
                )

                terminal_score = this.getBestStraightPairScore vertex_index remaining_ring_edges topology_data

                if terminal_score < straight_limit then
                (
                    return #(false, "invalid internal terminal")
                )
            )
            else
            (
                if chain_degree != 2 then return #(false, "internal degree")

                ring_score = this.getRingStraightnessScore vertex_index chain_incident_edges topology_data

                if ring_score < straight_limit then
                (
                    return #(false, "ring angle")
                )
            )
        )

        #(true, "")
        -- return
    ),

    /*
    Builds the production redundant-edge result from the three established masks.
    Final result:
    visible/selectable edges - border edges - border-corner loop edges - wall-corner loop edges.
    No chain, terminal, degree, or ANGLE validation is applied after these masks are built.
    */
    function detectRedundantEditablePoly node poly_value visible_edges =
    (
        if node == undefined or not isValidNode node then return undefined
        if poly_value == undefined or classOf poly_value != Editable_Poly then return undefined
        if visible_edges == undefined then return undefined

        topology_data = this.buildEditablePolyTopology node poly_value visible_edges
        if topology_data == undefined then return undefined

        border_edges = topology_data[8]
        internal_edges = copy visible_edges
        internal_edges -= border_edges

        border_corner_records = this.buildBorderCornerLoopRecords topology_data internal_edges max_turn_threshold:45.0
        wall_corner_records = this.buildWallCornerLoopRecords topology_data internal_edges this.geometry_corner_angle_threshold
        border_corner_edges = #{}
        wall_corner_edges = #{}

        for loop_record in border_corner_records do
        (
            border_corner_edges += loop_record[1]
        )

        for loop_record in wall_corner_records do
        (
            wall_corner_edges += loop_record[1]
        )

        border_corner_edges -= wall_corner_edges

        redundant_edges = copy internal_edges
        redundant_edges -= border_corner_edges
        redundant_edges -= wall_corner_edges

        #(
            redundant_edges,
            topology_data,
            visible_edges * border_edges,
            border_corner_edges,
            wall_corner_edges,
            internal_edges
        )
        -- return
    ),

    /*
    Returns the dedicated selector only; unrelated Edit Poly modifiers are never reused.
    */
    function findSelectionModifier node =
    (
        if node == undefined or not isValidNode node then return undefined

        for stack_index = 1 to node.modifiers.count do
        (
            stack_mod = node.modifiers[stack_index]

            if classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT REDUNDANT LOOPS" then
            (
                stack_mod.showCage = off
                return stack_mod
            )
        )

        undefined
        -- return
    ),

    /*
    Reuses the dedicated selector or creates it at the requested topology position.
    Creation occurs only after a non-empty redundant result exists.
    */
    function acquireSelectionModifier node before_index:0 =
    (
        if node == undefined or not isValidNode node then return #(undefined, false)

        selection_mod = this.findSelectionModifier node
        if selection_mod != undefined then return #(selection_mod, false)

        selection_mod = Edit_Poly name:"SELECT REDUNDANT LOOPS"
        selection_mod.showCage = off

        if before_index >= 1 and before_index <= node.modifiers.count then
        (
            addModifier node selection_mod before:before_index
        )
        else
        (
            addModifier node selection_mod
        )

        #(selection_mod, true)
        -- return
    ),

    /*
    Activates the dedicated selection modifier in Edge mode.
    */
    function activateSelectionModifier node selection_mod =
    (
        if node == undefined or not isValidNode node then return false
        if selection_mod == undefined or classOf selection_mod != Edit_Poly then return false

        select node
        max modify mode

        selection_mod.SetPrimaryNode node
        selection_mod.useStackSelection = false
        selection_mod.selectMode = 0
        selection_mod.showCage = off

        modPanel.setCurrentObject selection_mod node:node
        selection_mod.SetEPolySelLevel #Edge
        subObjectLevel = 2

        true
        -- return
    ),

    /*
    Stores the final detector BitArray in SELECT REDUNDANT LOOPS.
    A zero result never creates a new selector; an existing selector is cleared.
    Returns #(success, selector, created).
    */
    function writeRedundantSelection node redundant_edges before_index:0 =
    (
        if node == undefined or not isValidNode node then return #(false, undefined, false)
        if redundant_edges == undefined then return #(false, undefined, false)

        selection_mod = this.findSelectionModifier node
        created = false

        if redundant_edges.numberSet == 0 then
        (
            if selection_mod == undefined then return #(true, undefined, false)

            if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, false)

            old_edges = selection_mod.GetSelection #Edge

            if old_edges.numberSet > 0 then
            (
                selection_mod.Select #Edge old_edges select:false
            )

            selection_mod.RefreshScreen()
            completeRedraw()

            stored_edges = selection_mod.GetSelection #Edge
            return #(stored_edges.numberSet == 0, selection_mod, false)
        )

        selection_data = this.acquireSelectionModifier node before_index:before_index
        selection_mod = selection_data[1]
        created = selection_data[2]

        if selection_mod == undefined then return #(false, undefined, created)
        if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, created)

        old_edges = selection_mod.GetSelection #Edge

        if old_edges.numberSet > 0 then
        (
            selection_mod.Select #Edge old_edges select:false
        )

        selection_mod.Select #Edge redundant_edges select:true
        selection_mod.RefreshScreen()
        completeRedraw()

        stored_edges = selection_mod.GetSelection #Edge
        missing_edges = redundant_edges - stored_edges
        extra_edges = stored_edges - redundant_edges
        selection_matches = missing_edges.numberSet == 0 and extra_edges.numberSet == 0

        if not selection_matches then
        (
            format "Loop-Cleaner SELECTOR VERIFY FAILED | requested:% | stored:% | missing:% | extra:%\n" redundant_edges stored_edges missing_edges extra_edges
        )

        #(selection_matches, selection_mod, created)
        -- return
    ),

    /*
    Returns the dedicated border selector only; unrelated Edit Poly modifiers are never reused.
    All border-selection modes share one SELECT BORDERS modifier.
    */
    function findBorderSelectionModifier node =
    (
        if node == undefined or not isValidNode node then return undefined

        for stack_index = 1 to node.modifiers.count do
        (
            stack_mod = node.modifiers[stack_index]

            if classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT BORDERS" then
            (
                stack_mod.showCage = off
                return stack_mod
            )
        )

        undefined
        -- return
    ),

    /*
    Reuses SELECT BORDERS or creates it at the requested topology position.
    Creation occurs only after a non-empty border selection exists.
    */
    function acquireBorderSelectionModifier node before_index:0 =
    (
        if node == undefined or not isValidNode node then return #(undefined, false)

        selection_mod = this.findBorderSelectionModifier node
        if selection_mod != undefined then return #(selection_mod, false)

        selection_mod = Edit_Poly name:"SELECT BORDERS"
        selection_mod.showCage = off

        if before_index >= 1 and before_index <= node.modifiers.count then
        (
            addModifier node selection_mod before:before_index
        )
        else
        (
            addModifier node selection_mod
        )

        #(selection_mod, true)
        -- return
    ),

    /*
    Stores one border Edge BitArray in SELECT BORDERS.
    A zero result never creates a new selector; an existing SELECT BORDERS selection is cleared.
    Returns #(success, selector, created).
    */
    function writeBorderSelection node border_edges before_index:0 =
    (
        if node == undefined or not isValidNode node then return #(false, undefined, false)
        if border_edges == undefined then return #(false, undefined, false)

        selection_mod = this.findBorderSelectionModifier node
        created = false

        if border_edges.numberSet == 0 then
        (
            if selection_mod == undefined then return #(true, undefined, false)

            if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, false)

            old_edges = selection_mod.GetSelection #Edge

            if old_edges.numberSet > 0 then
            (
                selection_mod.Select #Edge old_edges select:false
            )

            selection_mod.RefreshScreen()
            completeRedraw()

            stored_edges = selection_mod.GetSelection #Edge
            return #(stored_edges.numberSet == 0, selection_mod, false)
        )

        selection_data = this.acquireBorderSelectionModifier node before_index:before_index
        selection_mod = selection_data[1]
        created = selection_data[2]

        if selection_mod == undefined then return #(false, undefined, created)
        if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, created)

        old_edges = selection_mod.GetSelection #Edge

        if old_edges.numberSet > 0 then
        (
            selection_mod.Select #Edge old_edges select:false
        )

        selection_mod.Select #Edge border_edges select:true
        selection_mod.RefreshScreen()
        completeRedraw()

        stored_edges = selection_mod.GetSelection #Edge
        missing_edges = border_edges - stored_edges
        extra_edges = stored_edges - border_edges
        selection_matches = missing_edges.numberSet == 0 and extra_edges.numberSet == 0

        if not selection_matches then
        (
            format "Loop-Cleaner BORDER SELECTOR VERIFY FAILED | requested:% | stored:% | missing:% | extra:%\n" border_edges stored_edges missing_edges extra_edges
        )

        #(selection_matches, selection_mod, created)
        -- return
    ),

    /*
    Resolves the current polygon topology for border selection without running redundant-loop filters.
    Returns #(success, topology_data, selector_before_index, error_text).
    */
    function getBorderSelectionAnalysis node =
    (
        if node == undefined or not isValidNode node then return #(false, undefined, 0, "Select one valid geometry object.")

        target_data = this.getCurrentPolyTarget node
        target_kind = target_data[1]
        target_value = target_data[2]
        selector_before_index = target_data[3]
        analysis_poly = undefined
        visible_edges = undefined

        if target_kind == #editable_poly then
        (
            if not this.ensureCleanEditablePolyTopology target_value then
            (
                return #(false, undefined, selector_before_index, "Could not validate Editable Poly topology before reading component IDs.")
            )

            analysis_poly = target_value
            visible_edges = this.getVisibleEditablePolyEdges analysis_poly
        )
        else if target_kind == #edit_poly then
        (
            visible_edges = this.getVisibleEditPolyEdgesFromBase node target_value

            if visible_edges != undefined then
            (
                analysis_poly = node.baseObject
            )
        )
        else
        (
            return #(false, undefined, selector_before_index, "Make an Editable Poly base or an Edit Poly modifier current in the Modify panel.")
        )

        if analysis_poly == undefined or visible_edges == undefined then
        (
            return #(false, undefined, selector_before_index, "The current topology cannot be analyzed safely for border selection.")
        )

        topology_data = this.buildEditablePolyTopology node analysis_poly visible_edges
        if topology_data == undefined then return #(false, undefined, selector_before_index, "Could not read the current polygon topology.")

        #(true, topology_data, selector_before_index, "")
        -- return
    ),

    /*
    Builds connected components from the complete true-border Edge BitArray.
    Components are connected through shared border vertices; no angle or geometric tolerance is used.
    */
    function buildBorderComponents topology_data =
    (
        border_components = #()
        if topology_data == undefined then return border_components

        vertex_edges = topology_data[5]
        edge_vertices = topology_data[6]
        remaining_edges = copy topology_data[8]

        while remaining_edges.numberSet > 0 do
        (
            seed_edge = 0

            for edge_index in remaining_edges while seed_edge == 0 do
            (
                seed_edge = edge_index
            )

            if seed_edge == 0 then
            (
                format "Loop-Cleaner BORDER COMPONENT FAILED | remainingEdgeCount:% | expected:>0 seed edge\n" remaining_edges.numberSet
                return border_components
            )

            component_edges = #{}
            edge_stack = #(seed_edge)
            remaining_edges[seed_edge] = false

            while edge_stack.count > 0 do
            (
                stack_index = edge_stack.count
                current_edge = edge_stack[stack_index]
                deleteItem edge_stack stack_index
                component_edges[current_edge] = true

                edge_pair = edge_vertices[current_edge]

                if edge_pair != undefined and edge_pair.count == 2 then
                (
                    for endpoint_index = 1 to 2 do
                    (
                        vertex_index = edge_pair[endpoint_index]

                        if vertex_index >= 1 and vertex_index <= vertex_edges.count then
                        (
                            neighbor_edges = vertex_edges[vertex_index] * remaining_edges

                            for neighbor_edge in neighbor_edges do
                            (
                                remaining_edges[neighbor_edge] = false
                                append edge_stack neighbor_edge
                            )
                        )
                    )
                )
            )

            append border_components component_edges
        )

        border_components
        -- return
    ),

    /*
    Builds one connected-surface-shell ID for every polygon face.
    Faces belong to the same shell when they are connected through a two-face topology edge.
    */
    function buildFaceShellIds topology_data =
    (
        if topology_data == undefined then return undefined

        face_count = topology_data[3]
        edge_faces = topology_data[7]
        face_neighbors = #()
        face_shell_ids = #()

        for face_index = 1 to face_count do
        (
            append face_neighbors #{}
            append face_shell_ids 0
        )

        for edge_index = 1 to edge_faces.count do
        (
            face_pair = edge_faces[edge_index]

            if face_pair != undefined and face_pair.count == 2 then
            (
                face_a = face_pair[1]
                face_b = face_pair[2]

                if face_a >= 1 and face_a <= face_count and face_b >= 1 and face_b <= face_count then
                (
                    face_neighbors[face_a][face_b] = true
                    face_neighbors[face_b][face_a] = true
                )
            )
        )

        shell_id = 0

        for face_index = 1 to face_count do
        (
            if face_shell_ids[face_index] == 0 then
            (
                shell_id += 1
                face_stack = #(face_index)
                face_shell_ids[face_index] = shell_id

                while face_stack.count > 0 do
                (
                    stack_index = face_stack.count
                    current_face = face_stack[stack_index]
                    deleteItem face_stack stack_index

                    for neighbor_face in face_neighbors[current_face] do
                    (
                        if face_shell_ids[neighbor_face] == 0 then
                        (
                            face_shell_ids[neighbor_face] = shell_id
                            append face_stack neighbor_face
                        )
                    )
                )
            )
        )

        face_shell_ids
        -- return
    ),

    /*
    Returns the exact world-space perimeter of one border component.
    No rounding, epsilon, or hidden tolerance is applied.
    */
    function getBorderComponentPerimeter component_edges topology_data =
    (
        if component_edges == undefined or topology_data == undefined then return 0.0

        perimeter_value = 0.0

        for edge_index in component_edges do
        (
            perimeter_value += this.getTopologyEdgeLength edge_index topology_data
        )

        perimeter_value
        -- return
    ),

    /*
    Collects every vertex incident to one topology Edge BitArray.
    Returns a BitArray in native vertex-ID order without changing topology or geometry.
    */
    function getTopologyVerticesFromEdges topology_data edge_bits =
    (
        if topology_data == undefined then
        (
            format "Loop-Cleaner TOPOLOGY VERTEX SET FAILED | topology:undefined\n"
            return undefined
        )

        if classOf edge_bits != BitArray then
        (
            format "Loop-Cleaner TOPOLOGY VERTEX SET FAILED | edgeBitsType:% | expected:BitArray\n" (classOf edge_bits)
            return undefined
        )

        edge_vertices = topology_data[6]
        vertex_bits = #{}
        vertex_bits.count = topology_data[1]

        for edge_index in edge_bits do
        (
            if edge_index < 1 or edge_index > edge_vertices.count then
            (
                format "Loop-Cleaner TOPOLOGY VERTEX SET FAILED | edge:% | edgeCount:% | expectedRange:1..%\n" edge_index edge_vertices.count edge_vertices.count
                return undefined
            )

            edge_pair = edge_vertices[edge_index]

            if edge_pair == undefined or edge_pair.count != 2 then
            (
                format "Loop-Cleaner TOPOLOGY VERTEX SET FAILED | edge:% | pair:% | expectedPairCount:2\n" edge_index edge_pair
                return undefined
            )

            if edge_pair[1] < 1 or edge_pair[1] > vertex_bits.count or edge_pair[2] < 1 or edge_pair[2] > vertex_bits.count then
            (
                format "Loop-Cleaner TOPOLOGY VERTEX SET FAILED | edge:% | vertexA:% | vertexB:% | vertexCount:%\n" edge_index edge_pair[1] edge_pair[2] vertex_bits.count
                return undefined
            )

            vertex_bits[edge_pair[1]] = true
            vertex_bits[edge_pair[2]] = true
        )

        vertex_bits
        -- return
    ),

    /*
    Classifies true border components using an already-built connected-component Array.
    This keeps classifyBorderEdges() caller output unchanged while allowing Broken-T analysis to reuse the same components.
    */
    function classifyBorderEdgesFromComponents topology_data border_components =
    (
        if topology_data == undefined then
        (
            format "Loop-Cleaner BORDER CLASSIFY FAILED | topology:undefined\n"
            return undefined
        )

        if classOf border_components != Array then
        (
            format "Loop-Cleaner BORDER CLASSIFY FAILED | componentType:% | expected:Array\n" (classOf border_components)
            return undefined
        )

        all_border_edges = copy topology_data[8]
        outer_border_edges = #{}
        inner_border_edges = #{}
        face_shell_ids = this.buildFaceShellIds topology_data

        if face_shell_ids == undefined then
        (
            format "Loop-Cleaner BORDER CLASSIFY FAILED | faceShellIds:undefined | faceCount:%\n" topology_data[3]
            return undefined
        )

        edge_faces = topology_data[7]
        component_shell_ids = #()
        shell_ids = #()
        shell_outer_component_indexes = #()
        shell_outer_perimeters = #()

        for component_index = 1 to border_components.count do
        (
            component_edges = border_components[component_index]
            component_shell_id = 0
            component_perimeter = this.getBorderComponentPerimeter component_edges topology_data
            seed_edge = 0

            for component_edge_id in component_edges while seed_edge == 0 do
            (
                seed_edge = component_edge_id
            )

            if seed_edge > 0 then
            (
                face_pair = edge_faces[seed_edge]

                if face_pair != undefined and face_pair.count == 2 then
                (
                    adjacent_face = if face_pair[1] > 0 then face_pair[1] else face_pair[2]

                    if adjacent_face >= 1 and adjacent_face <= face_shell_ids.count then
                    (
                        component_shell_id = face_shell_ids[adjacent_face]
                    )
                )
            )

            append component_shell_ids component_shell_id

            shell_slot = findItem shell_ids component_shell_id

            if shell_slot == 0 then
            (
                append shell_ids component_shell_id
                append shell_outer_component_indexes component_index
                append shell_outer_perimeters component_perimeter
            )
            else if component_perimeter > shell_outer_perimeters[shell_slot] then
            (
                shell_outer_component_indexes[shell_slot] = component_index
                shell_outer_perimeters[shell_slot] = component_perimeter
            )
        )

        for component_index = 1 to border_components.count do
        (
            component_shell_id = component_shell_ids[component_index]
            shell_slot = findItem shell_ids component_shell_id

            if shell_slot > 0 and shell_outer_component_indexes[shell_slot] == component_index then
            (
                outer_border_edges += border_components[component_index]
            )
            else
            (
                inner_border_edges += border_components[component_index]
            )
        )

        #(all_border_edges, outer_border_edges, inner_border_edges, border_components.count, shell_ids.count)
        -- return
    ),

    /*
    Classifies true border components as all, outer, and inner.
    For each connected surface shell, the border component with the greatest exact world-space perimeter
    is the outer border; all other border components on that shell are inner-hole borders.
    Returns #(allBorders, outerBorders, innerBorders, componentCount, shellCount).
    */
    function classifyBorderEdges topology_data =
    (
        if topology_data == undefined then return undefined

        border_components = this.buildBorderComponents topology_data
        this.classifyBorderEdgesFromComponents topology_data border_components
        -- return
    ),

    /*
    Selects all, outer, or inner-hole border edges and stores the result in SELECT BORDERS.
    Only currently visible/selectable edges are written; border classification itself uses the complete border topology.
    */
    function selectBorders border_mode =
    (
        if selection.count != 1 then
        (
            if show_dialogs then messageBox "Select exactly one Editable Poly or active Edit Poly object." title:"Loop-Cleaner"
            return false
        )

        node = selection[1]
        analysis_data = this.getBorderSelectionAnalysis node

        if not analysis_data[1] then
        (
            messageBox analysis_data[4] title:"Loop-Cleaner"
            return false
        )

        topology_data = analysis_data[2]
        selector_before_index = analysis_data[3]
        classification = this.classifyBorderEdges topology_data

        if classification == undefined then
        (
            messageBox "Could not classify the current border topology." title:"Loop-Cleaner"
            return false
        )

        selected_edges = #{}
        border_label = ""

        case border_mode of
        (
            #all:
            (
                selected_edges = copy classification[1]
                border_label = "ALL"
            )
            #outer:
            (
                selected_edges = copy classification[2]
                border_label = "OUTER"
            )
            #inner:
            (
                selected_edges = copy classification[3]
                border_label = "INNER"
            )
            default:
            (
                messageBox "Unsupported border selection mode." title:"Loop-Cleaner"
                return false
            )
        )

        selected_edges = selected_edges * topology_data[12]
        write_result = this.writeBorderSelection node selected_edges before_index:selector_before_index

        if not write_result[1] then
        (
            messageBox "Could not store the border selection in SELECT BORDERS. See Listener for verification details." title:"Loop-Cleaner"
            return false
        )

        format "Loop-Cleaner BORDER SELECT | node:% | mode:% | components:% | shells:% | selected:% | edges:%\n" node.name border_label classification[4] classification[5] selected_edges.numberSet selected_edges

        true
        -- return
    ),

    /*
    Selects every current true mesh border edge that is visible/selectable.
    */
    function selectAllBorders =
    (
        this.selectBorders #all
        -- return
    ),

    /*
    Selects the outer border of each connected surface shell.
    Outer means the shell's greatest-perimeter border component.
    */
    function selectOuterBorders =
    (
        this.selectBorders #outer
        -- return
    ),

    /*
    Selects every inner-hole border on each connected surface shell.
    Inner means every border component except that shell's greatest-perimeter outer border.
    */
    function selectInnerBorders =
    (
        this.selectBorders #inner
        -- return
    ),


    /*
    Returns the dedicated T-junction selector only; unrelated Edit Poly modifiers are never reused.
    All T-junction selection modes share one SELECT T JUNCTIONS modifier.
    */
    function findTJunctionSelectionModifier node =
    (
        if node == undefined or not isValidNode node then return undefined

        for stack_index = 1 to node.modifiers.count do
        (
            stack_mod = node.modifiers[stack_index]

            if classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT T JUNCTIONS" then
            (
                stack_mod.showCage = off
                return stack_mod
            )
        )

        undefined
        -- return
    ),

    /*
    Reuses SELECT T JUNCTIONS or creates it at the requested topology position.
    Creation occurs only after a non-empty T-junction loop selection exists.
    */
    function acquireTJunctionSelectionModifier node before_index:0 =
    (
        if node == undefined or not isValidNode node then return #(undefined, false)

        selection_mod = this.findTJunctionSelectionModifier node
        if selection_mod != undefined then return #(selection_mod, false)

        selection_mod = Edit_Poly name:"SELECT T JUNCTIONS"
        selection_mod.showCage = off

        if before_index >= 1 and before_index <= node.modifiers.count then
        (
            addModifier node selection_mod before:before_index
        )
        else
        (
            addModifier node selection_mod
        )

        #(selection_mod, true)
        -- return
    ),

    /*
    Stores one T-junction loop Edge BitArray in SELECT T JUNCTIONS.
    A zero result never creates a new selector; an existing selector is cleared and verified.
    */
    function writeTJunctionSelection node junction_edges before_index:0 =
    (
        if node == undefined or not isValidNode node then return #(false, undefined, false)
        if junction_edges == undefined then return #(false, undefined, false)

        selection_mod = this.findTJunctionSelectionModifier node
        created = false

        if junction_edges.numberSet == 0 then
        (
            if selection_mod == undefined then return #(true, undefined, false)

            if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, false)

            old_edges = selection_mod.GetSelection #Edge

            if old_edges.numberSet > 0 then
            (
                selection_mod.Select #Edge old_edges select:false
            )

            selection_mod.RefreshScreen()
            completeRedraw()

            stored_edges = selection_mod.GetSelection #Edge
            return #(stored_edges.numberSet == 0, selection_mod, false)
        )

        selection_data = this.acquireTJunctionSelectionModifier node before_index:before_index
        selection_mod = selection_data[1]
        created = selection_data[2]

        if selection_mod == undefined then return #(false, undefined, created)
        if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, created)

        old_edges = selection_mod.GetSelection #Edge

        if old_edges.numberSet > 0 then
        (
            selection_mod.Select #Edge old_edges select:false
        )

        selection_mod.Select #Edge junction_edges select:true
        selection_mod.RefreshScreen()
        completeRedraw()

        stored_edges = selection_mod.GetSelection #Edge
        missing_edges = junction_edges - stored_edges
        extra_edges = stored_edges - junction_edges
        selection_matches = missing_edges.numberSet == 0 and extra_edges.numberSet == 0

        if not selection_matches then
        (
            format "Loop-Cleaner T JUNCTION SELECTOR VERIFY FAILED | requested:% | stored:% | missing:% | extra:%\n" junction_edges stored_edges missing_edges extra_edges
        )

        #(selection_matches, selection_mod, created)
        -- return
    ),

    /*
    Returns the stem edge of one exact topological T junction.
    A T vertex has exactly three incident topology edges, exactly one perfectly collinear opposite pair,
    and one remaining non-border stem edge. No angular tolerance is used.
    */
    function getTJunctionStemEdge vertex_index topology_data =
    (
        if topology_data == undefined then return 0

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        border_edges = topology_data[8]

        if vertex_index < 1 or vertex_index > vertex_edges.count then return 0

        raw_edges = vertex_edges[vertex_index]
        if raw_edges.numberSet != 3 then return 0

        edge_array = raw_edges as array
        straight_pair_count = 0
        through_edges = #{}

        for first_index = 1 to 2 do
        (
            for second_index = first_index + 1 to 3 do
            (
                first_edge = edge_array[first_index]
                second_edge = edge_array[second_index]
                first_other = this.getOtherEdgeVertex first_edge vertex_index topology_data
                second_other = this.getOtherEdgeVertex second_edge vertex_index topology_data

                if first_other >= 1 and first_other <= vertex_points.count and second_other >= 1 and second_other <= vertex_points.count then
                (
                    first_vector = vertex_points[first_other] - vertex_points[vertex_index]
                    second_vector = vertex_points[second_other] - vertex_points[vertex_index]

                    if length first_vector > 0.0 and length second_vector > 0.0 then
                    (
                        cross_value = cross first_vector second_vector
                        dot_value = dot first_vector second_vector

                        if length cross_value == 0.0 and dot_value < 0.0 then
                        (
                            straight_pair_count += 1
                            through_edges = #{}
                            through_edges[first_edge] = true
                            through_edges[second_edge] = true
                        )
                    )
                )
            )
        )

        if straight_pair_count != 1 then return 0

        stem_edges = raw_edges - through_edges
        if stem_edges.numberSet != 1 then return 0

        stem_array = stem_edges as array
        stem_edge = stem_array[1]
        if border_edges[stem_edge] then return 0

        stem_edge
        -- return
    ),

    /*
    Collects exact T-junction seed records as #(vertexIndex, stemEdge, isBorderJunction).
    Border classification uses complete topology; visibility is applied later to the traced loop selection.
    */
    function buildTJunctionSeedRecords topology_data =
    (
        seed_records = #()
        if topology_data == undefined then return seed_records

        vertex_edges = topology_data[5]
        border_edges = topology_data[8]

        for vertex_index = 1 to vertex_edges.count do
        (
            stem_edge = this.getTJunctionStemEdge vertex_index topology_data

            if stem_edge > 0 then
            (
                is_border_junction = (vertex_edges[vertex_index] * border_edges).numberSet > 0
                append seed_records #(vertex_index, stem_edge, is_border_junction)
            )
        )

        seed_records
        -- return
    ),

    /*
    Builds the visible/selectable internal edge domain used to trace T-junction loops.
    Only valid non-border two-face edges with non-zero exact length participate.
    */
    function buildTJunctionCandidateEdges topology_data =
    (
        candidate_edges = #{}
        if topology_data == undefined then return candidate_edges

        face_count = topology_data[3]
        edge_vertices = topology_data[6]
        edge_faces = topology_data[7]
        border_edges = topology_data[8]
        visible_edges = topology_data[12]

        candidate_edges = copy visible_edges
        candidate_edges -= border_edges
        candidate_snapshot = copy candidate_edges

        for edge_index in candidate_snapshot do
        (
            edge_pair = edge_vertices[edge_index]
            face_pair = edge_faces[edge_index]
            edge_valid = edge_pair != undefined and edge_pair.count == 2 and face_pair != undefined and face_pair.count == 2

            if edge_valid then
            (
                edge_valid = face_pair[1] > 0 and face_pair[2] > 0 and face_pair[1] <= face_count and face_pair[2] <= face_count
            )

            if edge_valid then
            (
                edge_valid = this.getTopologyEdgeLength edge_index topology_data > 0.0
            )

            if not edge_valid then candidate_edges[edge_index] = false
        )

        candidate_edges
        -- return
    ),

    /*
    Returns the unique topology-opposite continuation edge at one non-T vertex.
    A valid continuation shares no polygon face with the incoming edge. Ambiguous or missing continuations stop the trace.
    */
    function getUniqueTopologicalLoopContinuation current_edge vertex_index available_edges topology_data =
    (
        if topology_data == undefined or available_edges == undefined then return 0

        vertex_edges = topology_data[5]
        edge_faces = topology_data[7]

        if vertex_index < 1 or vertex_index > vertex_edges.count then return 0
        if current_edge < 1 or current_edge > edge_faces.count then return 0

        current_face_pair = edge_faces[current_edge]
        if current_face_pair == undefined or current_face_pair.count != 2 then return 0

        incident_candidates = vertex_edges[vertex_index] * available_edges
        incident_candidates[current_edge] = false

        opposite_candidates = #{}
        opposite_candidates.count = topology_data[2]

        for neighbor_edge in incident_candidates do
        (
            neighbor_face_pair = edge_faces[neighbor_edge]
            shares_face = false

            if neighbor_face_pair != undefined and neighbor_face_pair.count == 2 then
            (
                for current_face_index = 1 to current_face_pair.count while not shares_face do
                (
                    current_face = current_face_pair[current_face_index]

                    if current_face > 0 then
                    (
                        for neighbor_face_index = 1 to neighbor_face_pair.count while not shares_face do
                        (
                            neighbor_face = neighbor_face_pair[neighbor_face_index]

                            if neighbor_face > 0 and neighbor_face == current_face then
                            (
                                shares_face = true
                            )
                        )
                    )
                )

                if not shares_face then
                (
                    opposite_candidates[neighbor_edge] = true
                )
            )
        )

        if opposite_candidates.numberSet != 1 then return 0

        opposite_array = opposite_candidates as array
        opposite_array[1]
        -- return
    ),

    /*
    Traces one whole visible internal loop/chained path outward from a T-junction stem.
    Arriving through another T junction's stem terminates the trace; arriving on its straight-through pair
    continues across the other through edge. At ordinary vertices, continuation is topology-only and requires
    exactly one incident candidate edge that shares no polygon face with the incoming edge.
    Returns #(chainEdges, startTVertex, terminalTVertexOrZero, terminalVertex).
    */
    function traceTJunctionLoop start_vertex seed_edge topology_data candidate_edges t_vertices =
    (
        empty_record = #(#{}, start_vertex, 0, start_vertex)

        if topology_data == undefined or candidate_edges == undefined or t_vertices == undefined then return empty_record
        if start_vertex < 1 or start_vertex > topology_data[1] then return empty_record
        if seed_edge < 1 or seed_edge > topology_data[2] then return empty_record
        if not candidate_edges[seed_edge] then return empty_record

        next_vertex = this.getOtherEdgeVertex seed_edge start_vertex topology_data
        if next_vertex < 1 then return empty_record

        vertex_edges = topology_data[5]
        chain_edges = #{}
        chain_edges[seed_edge] = true
        current_edge = seed_edge
        current_vertex = next_vertex
        terminal_t_vertex = 0
        walking = true

        while walking do
        (
            next_edge = 0
            current_t_stem = 0

            if current_vertex >= 1 and current_vertex <= t_vertices.count and t_vertices[current_vertex] then
            (
                current_t_stem = this.getTJunctionStemEdge current_vertex topology_data
            )

            if current_t_stem > 0 and current_edge == current_t_stem then
            (
                terminal_t_vertex = current_vertex
                walking = false
            )
            else
            (
                if current_t_stem > 0 then
                (
                    through_candidates = copy (vertex_edges[current_vertex] * candidate_edges)
                    through_candidates[current_edge] = false
                    through_candidates[current_t_stem] = false
                    through_candidates -= chain_edges

                    if through_candidates.numberSet == 1 then
                    (
                        through_array = through_candidates as array
                        next_edge = through_array[1]
                    )
                )
                else
                (
                    available_edges = copy candidate_edges
                    available_edges -= chain_edges
                    next_edge = this.getUniqueTopologicalLoopContinuation current_edge current_vertex available_edges topology_data
                )

                if next_edge < 1 then
                (
                    walking = false
                )
                else
                (
                    chain_edges[next_edge] = true
                    next_vertex = this.getOtherEdgeVertex next_edge current_vertex topology_data

                    if next_vertex < 1 then
                    (
                        walking = false
                    )
                    else
                    (
                        current_edge = next_edge
                        current_vertex = next_vertex
                    )
                )
            )
        )

        #(chain_edges, start_vertex, terminal_t_vertex, current_vertex)
        -- return
    ),

    /*
    Returns exact T-junction vertices that terminate on any detected broken inner-border component.
    Direct topology incidence qualifies immediately. A disconnected T at the end of the broken run also
    qualifies when its T vertex is within the explicit broken-T position tolerance of that component edge
    or endpoint and one T through edge remains on the same border line within the same tolerance.
    */
    function getBrokenInnerBorderTJunctionVertices topology_data =
    (
        if topology_data == undefined then return undefined

        position_tolerance = this.getBrokenTJunctionPositionPrecision()
        broken_data = this.getBrokenTJunctionBorderSelection topology_data position_tolerance

        if broken_data == undefined then return undefined

        broken_edges = broken_data[1]
        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        edge_vertices = topology_data[6]
        broken_t_vertices = #{}
        broken_t_vertices.count = topology_data[1]

        if broken_edges.numberSet == 0 then return broken_t_vertices

        for vertex_index = 1 to vertex_edges.count do
        (
            stem_edge = this.getTJunctionStemEdge vertex_index topology_data

            if stem_edge > 0 then
            (
                touches_broken_component = (vertex_edges[vertex_index] * broken_edges).numberSet > 0

                if not touches_broken_component then
                (
                    vertex_point = vertex_points[vertex_index]
                    through_edges = copy vertex_edges[vertex_index]
                    through_edges[stem_edge] = false

                    for broken_edge_id in broken_edges while not touches_broken_component do
                    (
                        broken_pair = edge_vertices[broken_edge_id]

                        if broken_pair != undefined and broken_pair.count == 2 then
                        (
                            point_a = vertex_points[broken_pair[1]]
                            point_b = vertex_points[broken_pair[2]]
                            broken_length = distance point_a point_b

                            if broken_length > 0.0 then
                            (
                                projection_data = this.getPointSegmentProjectionData vertex_point point_a point_b
                                projection_fraction = projection_data[2]
                                segment_distance = projection_data[1]

                                if projection_fraction < 0.0 then
                                (
                                    segment_distance = distance vertex_point point_a
                                )
                                else if projection_fraction > 1.0 then
                                (
                                    segment_distance = distance vertex_point point_b
                                )

                                if segment_distance <= position_tolerance then
                                (
                                    aligned_through_edge = false

                                    for through_edge_id in through_edges while not aligned_through_edge do
                                    (
                                        through_other_vertex = this.getOtherEdgeVertex through_edge_id vertex_index topology_data

                                        if through_other_vertex >= 1 and through_other_vertex <= vertex_points.count then
                                        (
                                            through_other_point = vertex_points[through_other_vertex]
                                            through_line_data = this.getPointSegmentProjectionData through_other_point point_a point_b

                                            if through_line_data[1] <= position_tolerance then
                                            (
                                                aligned_through_edge = true
                                            )
                                        )
                                    )

                                    if aligned_through_edge then
                                    (
                                        touches_broken_component = true
                                    )
                                )
                            )
                        )
                    )
                )

                if touches_broken_component then
                (
                    broken_t_vertices[vertex_index] = true
                )
            )
        )

        broken_t_vertices
        -- return
    ),

    /*
    Classifies traced T-junction loops as all, border, or mesh.
    T BORDER is built directly from exact T-stem edges whose T vertices terminate on a detected broken
    inner-border component, including spatial endpoint termination on the last broken-border edge.
    T MESH keeps complete traced loops that contain no T BORDER stem edge.
    Returns #(allEdges, borderEdges, meshEdges, allCount, borderCount, meshCount).
    */
    function classifyTJunctionLoops topology_data =
    (
        if topology_data == undefined then return undefined

        seed_records = this.buildTJunctionSeedRecords topology_data
        candidate_edges = this.buildTJunctionCandidateEdges topology_data
        broken_t_vertices = this.getBrokenInnerBorderTJunctionVertices topology_data

        if broken_t_vertices == undefined then return undefined

        all_t_vertices = #{}
        seed_edges = #{}
        border_junction_edges = #{}

        all_t_vertices.count = topology_data[1]
        seed_edges.count = topology_data[2]
        border_junction_edges.count = topology_data[2]

        for seed_record in seed_records do
        (
            vertex_index = seed_record[1]
            stem_edge = seed_record[2]

            all_t_vertices[vertex_index] = true

            if stem_edge >= 1 and stem_edge <= candidate_edges.count and candidate_edges[stem_edge] then
            (
                seed_edges[stem_edge] = true

                if vertex_index >= 1 and vertex_index <= broken_t_vertices.count and broken_t_vertices[vertex_index] then
                (
                    border_junction_edges[stem_edge] = true
                )
            )
        )

        remaining_seed_edges = copy seed_edges
        all_junction_edges = #{}
        mesh_junction_edges = #{}
        all_count = 0
        border_count = 0
        mesh_count = 0

        for seed_record in seed_records do
        (
            start_vertex = seed_record[1]
            seed_edge = seed_record[2]

            if seed_edge >= 1 and seed_edge <= remaining_seed_edges.count and remaining_seed_edges[seed_edge] then
            (
                loop_record = this.traceTJunctionLoop start_vertex seed_edge topology_data candidate_edges all_t_vertices
                loop_edges = loop_record[1]

                if loop_edges.numberSet > 0 then
                (
                    remaining_seed_edges -= loop_edges
                    all_junction_edges += loop_edges
                    all_count += 1

                    if (loop_edges * border_junction_edges).numberSet > 0 then
                    (
                        border_count += 1
                    )
                    else
                    (
                        mesh_junction_edges += loop_edges
                        mesh_count += 1
                    )
                )
                else
                (
                    remaining_seed_edges[seed_edge] = false
                )
            )
        )

        #(all_junction_edges, border_junction_edges, mesh_junction_edges, all_count, border_count, mesh_count)
        -- return
    ),


    /*
    Selects all, border, or mesh T-junction loops and stores the result in SELECT T JUNCTIONS.
    */
    function selectTJunctions junction_mode =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one Editable Poly or active Edit Poly object." title:"Loop-Cleaner"
            return false
        )

        node = selection[1]
        analysis_data = this.getBorderSelectionAnalysis node

        if not analysis_data[1] then
        (
            messageBox analysis_data[4] title:"Loop-Cleaner"
            return false
        )

        topology_data = analysis_data[2]
        selector_before_index = analysis_data[3]
        classification = this.classifyTJunctionLoops topology_data

        if classification == undefined then
        (
            messageBox "Could not classify the current T-junction topology." title:"Loop-Cleaner"
            return false
        )

        selected_edges = #{}
        junction_label = ""

        case junction_mode of
        (
            #all:
            (
                selected_edges = copy classification[1]
                junction_label = "ALL"
            )
            #border:
            (
                selected_edges = copy classification[2]
                junction_label = "BORDER"
            )
            #mesh:
            (
                selected_edges = copy classification[3]
                junction_label = "MESH"
            )
            default:
            (
                messageBox "Unsupported T-junction selection mode." title:"Loop-Cleaner"
                return false
            )
        )

        selected_edges = selected_edges * topology_data[12]
        write_result = this.writeTJunctionSelection node selected_edges before_index:selector_before_index

        if not write_result[1] then
        (
            messageBox "Could not store the T-junction selection in SELECT T JUNCTIONS. See Listener for verification details." title:"Loop-Cleaner"
            return false
        )

        format "Loop-Cleaner T JUNCTION SELECT | node:% | mode:% | all:% | border:% | mesh:% | selected:% | edges:%\n" node.name junction_label classification[4] classification[5] classification[6] selected_edges.numberSet selected_edges

        true
        -- return
    ),

    /*
    Selects every traced exact T-junction loop.
    */
    function selectAllTJunctions =
    (
        this.selectTJunctions #all
        -- return
    ),

    /*
    Selects traced T-junction loops containing at least one T vertex on true mesh border topology.
    */
    function selectBorderTJunctions =
    (
        this.selectTJunctions #border
        -- return
    ),

    /*
    Selects traced T-junction loops whose T vertices are all internal to the mesh.
    */
    function selectMeshTJunctions =
    (
        this.selectTJunctions #mesh
        -- return
    ),


    /*
    Returns the dedicated broken-T selector only.
    This selector is separate from redundant-loop, border, and normal T-junction selectors.
    */
    function findBrokenTJunctionSelectionModifier node =
    (
        if node == undefined or not isValidNode node then return undefined

        for stack_index = 1 to node.modifiers.count do
        (
            stack_mod = node.modifiers[stack_index]

            if classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT BROKEN T JUNCTIONS" then
            (
                stack_mod.showCage = off
                return stack_mod
            )
        )

        undefined
        -- return
    ),

    /*
    Reuses SELECT BROKEN T JUNCTIONS or creates it at the requested topology position.
    Creation occurs only after a non-empty degenerate inner-border result exists.
    */
    function acquireBrokenTJunctionSelectionModifier node before_index:0 =
    (
        if node == undefined or not isValidNode node then return #(undefined, false)

        selection_mod = this.findBrokenTJunctionSelectionModifier node
        if selection_mod != undefined then return #(selection_mod, false)

        selection_mod = Edit_Poly name:"SELECT BROKEN T JUNCTIONS"
        selection_mod.showCage = off

        if before_index >= 1 and before_index <= node.modifiers.count then
        (
            addModifier node selection_mod before:before_index
        )
        else
        (
            addModifier node selection_mod
        )

        #(selection_mod, true)
        -- return
    ),

    /*
    Stores one degenerate-border Edge BitArray in SELECT BROKEN T JUNCTIONS.
    A zero result never creates a new selector; an existing selector is cleared.
    Returns #(success, selector, created).
    */
    function writeBrokenTJunctionSelection node broken_edges before_index:0 refresh_viewport:true =
    (
        if node == undefined or not isValidNode node then return #(false, undefined, false)
        if broken_edges == undefined then return #(false, undefined, false)

        selection_mod = this.findBrokenTJunctionSelectionModifier node
        created = false

        if broken_edges.numberSet == 0 then
        (
            if selection_mod == undefined then return #(true, undefined, false)

            local same_empty_selector_context = \
                selection.count == 1 and \
                selection[1] == node and \
                modPanel.getCurrentObject() == selection_mod

            if same_empty_selector_context then
            (
                if selection_mod.useStackSelection != false then selection_mod.useStackSelection = false
                if selection_mod.selectMode != 0 then selection_mod.selectMode = 0
                if selection_mod.showCage != off then selection_mod.showCage = off
                if selection_mod.GetEPolySelLevel() != #Edge then selection_mod.SetEPolySelLevel #Edge
                if subObjectLevel != 2 then subObjectLevel = 2
            )
            else
            (
                if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, false)
            )

            old_edges = selection_mod.GetSelection #Edge node:node

            if old_edges.numberSet > 0 then
            (
                selection_mod.Select #Edge old_edges select:false node:node
            )

            if refresh_viewport then
            (
                selection_mod.RefreshScreen()
                completeRedraw()
            )

            stored_edges = selection_mod.GetSelection #Edge node:node
            return #(stored_edges.numberSet == 0, selection_mod, false)
        )

        selection_data = this.acquireBrokenTJunctionSelectionModifier node before_index:before_index
        selection_mod = selection_data[1]
        created = selection_data[2]

        if selection_mod == undefined then return #(false, undefined, created)

        local same_filled_selector_context = \
            selection.count == 1 and \
            selection[1] == node and \
            modPanel.getCurrentObject() == selection_mod

        if same_filled_selector_context then
        (
            if selection_mod.useStackSelection != false then selection_mod.useStackSelection = false
            if selection_mod.selectMode != 0 then selection_mod.selectMode = 0
            if selection_mod.showCage != off then selection_mod.showCage = off
            if selection_mod.GetEPolySelLevel() != #Edge then selection_mod.SetEPolySelLevel #Edge
            if subObjectLevel != 2 then subObjectLevel = 2
        )
        else
        (
            if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, created)
        )

        old_edges = selection_mod.GetSelection #Edge node:node

        if old_edges.numberSet > 0 then
        (
            selection_mod.Select #Edge old_edges select:false node:node
        )

        selection_mod.Select #Edge broken_edges node:node

        if refresh_viewport then
        (
            selection_mod.RefreshScreen()
            completeRedraw()
        )

        stored_edges = selection_mod.GetSelection #Edge node:node
        missing_edges = broken_edges - stored_edges
        extra_edges = stored_edges - broken_edges
        selection_matches = missing_edges.numberSet == 0 and extra_edges.numberSet == 0

        if not selection_matches then
        (
            format "Loop-Cleaner BROKEN T SELECTOR VERIFY FAILED | requested:% | stored:% | missing:% | extra:%\n" broken_edges stored_edges missing_edges extra_edges
        )

        #(selection_matches, selection_mod, created)
        -- return
    ),

    /*
    Returns the canonical position-precision labels used by the UI and backend.
    The default contract is 0.01mm.
    */
    function getPositionPrecisionItems =
    (
        #("1mm", "0.1mm", "0.01mm")
        -- return
    ),

    /*
    Converts one approved millimeter position-precision label to current system units.
    Returns undefined for any value outside the explicit precision contract.
    */
    function getPositionPrecisionValue position_precision_text =
    (
        precision_items = this.getPositionPrecisionItems()
        if findItem precision_items position_precision_text == 0 then return undefined

        units.decodeValue position_precision_text
        -- return
    ),

    /*
    Returns the currently configured Broken-T position precision in current system units.
    The UI stores the precision as an explicit millimeter label instead of a free numeric tolerance.
    */
    function getBrokenTJunctionPositionPrecision =
    (
        this.getPositionPrecisionValue this.position_precision_text
        -- return
    ),

    /*
    Quantizes one scalar to the nearest explicit precision step without relying on an undefined round() global.
    Negative values use the same nearest-step rule as positive values.
    */
    function quantizeScalarToPrecision scalar_value scalar_precision =
    (
        if scalar_precision == undefined or scalar_precision <= 0.0 then return undefined

        scaled_value = scalar_value / scalar_precision
        rounded_steps = if scaled_value >= 0.0 then floor (scaled_value + 0.5) else -(floor ((-scaled_value) + 0.5))

        rounded_steps * scalar_precision
        -- return
    ),

    /*
    Quantizes a temporary Point3 copy to the explicit position precision for identity comparisons.
    The rounded value is never written back to scene geometry.
    */
    function roundPositionToPrecision position_value position_precision =
    (
        if classOf position_value != Point3 then return undefined
        if position_precision == undefined or position_precision <= 0.0 then return undefined

        rounded_x = this.quantizeScalarToPrecision position_value.x position_precision
        rounded_y = this.quantizeScalarToPrecision position_value.y position_precision
        rounded_z = this.quantizeScalarToPrecision position_value.z position_precision

        if rounded_x == undefined or rounded_y == undefined or rounded_z == undefined then return undefined

        [rounded_x, rounded_y, rounded_z]
        -- return
    ),

    /*
    Compares two Point3 values through temporary precision-quantized copies.
    Raw geometry positions remain untouched.
    */
    function positionsMatchAtPrecision position_a position_b position_precision =
    (
        rounded_a = this.roundPositionToPrecision position_a position_precision
        rounded_b = this.roundPositionToPrecision position_b position_precision

        if rounded_a == undefined or rounded_b == undefined then return false

        rounded_a == rounded_b
        -- return
    ),

    /*
    Returns one Point3 coordinate by 1-based axis index.
    Used only for conservative Broken-T sweep broad-phase ordering.
    */
    function getPointAxisValue point_value axis_index =
    (
        if classOf point_value != Point3 then return undefined

        case axis_index of
        (
            1: point_value.x
            2: point_value.y
            3: point_value.z
            default: undefined
        )
        -- return
    ),

    /*
    Compares Broken-T sweep events by coordinate, then START -> VERTEX -> END, then component ID.
    Inclusive event ordering keeps edges active at exact tolerance-expanded interval boundaries.
    */
    function compareBrokenTSweepEvents event_a event_b =
    (
        if event_a[1] < event_b[1] then -1
        else if event_a[1] > event_b[1] then 1
        else if event_a[2] < event_b[2] then -1
        else if event_a[2] > event_b[2] then 1
        else if event_a[3] < event_b[3] then -1
        else if event_a[3] > event_b[3] then 1
        else 0
        -- return
    ),

    /*
    Builds a live polygon-topology snapshot directly from one Edit Poly modifier.
    The result uses the same array layout as buildEditablePolyTopology so border classifiers can be reused.
    Native face-boundary edge lookup uses per-vertex neighbor tables, avoiding global linear string-key searches.
    */
    function buildEditPolyBorderTopology node edit_poly_mod =
    (
        if node == undefined or not isValidNode node then return undefined
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return undefined

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node
        face_count = EditPolyMod.GetNumFaces edit_poly_mod node:node

        if vertex_count < 2 or edge_count < 1 or face_count < 1 then return undefined

        vertex_points = #()
        vertex_edges = #()
        vertex_neighbor_vertices = #()
        vertex_neighbor_edges = #()

        for vertex_index = 1 to vertex_count do
        (
            local_point = EditPolyMod.GetVertex edit_poly_mod vertex_index node:node
            if local_point == undefined then return undefined

            append vertex_points (local_point * node.objectTransform)
            vertex_bits = #{}
            vertex_bits.count = edge_count
            append vertex_edges vertex_bits
            append vertex_neighbor_vertices #()
            append vertex_neighbor_edges #()
        )

        edge_vertices = #()
        edge_face_lists = #()

        for edge_index = 1 to edge_count do
        (
            vertex_a = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 1 node:node
            vertex_b = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 2 node:node

            if vertex_a < 1 or vertex_a > vertex_count or vertex_b < 1 or vertex_b > vertex_count or vertex_a == vertex_b then return undefined

            existing_neighbor_index = findItem vertex_neighbor_vertices[vertex_a] vertex_b
            if existing_neighbor_index > 0 then return undefined

            append edge_vertices #(vertex_a, vertex_b)
            append edge_face_lists #()

            append vertex_neighbor_vertices[vertex_a] vertex_b
            append vertex_neighbor_edges[vertex_a] edge_index
            append vertex_neighbor_vertices[vertex_b] vertex_a
            append vertex_neighbor_edges[vertex_b] edge_index

            vertex_edges[vertex_a][edge_index] = true
            vertex_edges[vertex_b][edge_index] = true
        )

        for face_index = 1 to face_count do
        (
            face_degree = EditPolyMod.GetFaceDegree edit_poly_mod face_index node:node
            if face_degree == undefined or face_degree < 3 then return undefined

            face_vertices = #()

            for corner_index = 1 to face_degree do
            (
                face_vertex = EditPolyMod.GetFaceVertex edit_poly_mod face_index corner_index node:node
                if face_vertex < 1 or face_vertex > vertex_count then return undefined
                append face_vertices face_vertex
            )

            for corner_index = 1 to face_degree do
            (
                next_corner_index = if corner_index < face_degree then corner_index + 1 else 1
                face_vertex_a = face_vertices[corner_index]
                face_vertex_b = face_vertices[next_corner_index]
                neighbor_index = findItem vertex_neighbor_vertices[face_vertex_a] face_vertex_b

                if neighbor_index < 1 or neighbor_index > vertex_neighbor_edges[face_vertex_a].count then return undefined

                native_edge_index = vertex_neighbor_edges[face_vertex_a][neighbor_index]
                if native_edge_index < 1 or native_edge_index > edge_count then return undefined

                if findItem edge_face_lists[native_edge_index] face_index == 0 then
                (
                    append edge_face_lists[native_edge_index] face_index
                )
            )
        )

        edge_faces = #()
        border_edges = #{}
        border_vertices = #{}
        border_edges.count = edge_count
        border_vertices.count = vertex_count

        for edge_index = 1 to edge_count do
        (
            adjacent_faces = edge_face_lists[edge_index]

            if adjacent_faces.count < 1 or adjacent_faces.count > 2 then return undefined

            face_a = adjacent_faces[1]
            face_b = if adjacent_faces.count == 2 then adjacent_faces[2] else 0
            append edge_faces #(face_a, face_b)

            if face_b == 0 then
            (
                border_edges[edge_index] = true
                edge_pair = edge_vertices[edge_index]
                border_vertices[edge_pair[1]] = true
                border_vertices[edge_pair[2]] = true
            )
        )

        face_normals = #()
        face_valid = #{}
        face_valid.count = face_count

        for face_index = 1 to face_count do
        (
            append face_normals undefined
        )

        all_edges = #{}
        all_edges.count = edge_count

        for edge_index = 1 to edge_count do
        (
            all_edges[edge_index] = true
        )

        crease_edges = #{}
        crease_edges.count = edge_count

        #(
            vertex_count,
            edge_count,
            face_count,
            vertex_points,
            vertex_edges,
            edge_vertices,
            edge_faces,
            border_edges,
            border_vertices,
            face_normals,
            face_valid,
            all_edges,
            crease_edges
        )
        -- return
    ),

    /*
    Returns #(distanceToSegmentLine, segmentParameter, projectedPoint).
    The caller decides the allowed positional tolerance and endpoint exclusion.
    */
    function getPointSegmentProjectionData point_value segment_a segment_b =
    (
        segment_vector = segment_b - segment_a
        segment_length_squared = dot segment_vector segment_vector

        if segment_length_squared == 0.0 then
        (
            return #(distance point_value segment_a, 0.0, segment_a)
        )

        segment_parameter = dot (point_value - segment_a) segment_vector / segment_length_squared
        projected_point = segment_a + (segment_vector * segment_parameter)

        #(distance point_value projected_point, segment_parameter, projected_point)
        -- return
    ),

    /*
    Finds inner-border vertex-on-edge T seams on overlapping parallel border runs.
    A sweep-line broad phase keeps only target edges whose tolerance-expanded axis interval contains the source vertex,
    then conservative XYZ bounds filter candidates before the unchanged exact projection/parallel-source tests.
    Returns records: #(sourceVertex, targetEdge, targetFraction, distanceToTarget, sourceInnerEdges).
    */
    function findBrokenTJunctionCases topology_data position_tolerance inner_border_edges:undefined =
    (
        if topology_data == undefined then return undefined
        if position_tolerance < 0.0 then return undefined

        if inner_border_edges == undefined then
        (
            local classification = this.classifyBorderEdges topology_data
            if classification == undefined then return undefined

            inner_border_edges = classification[3]
        )

        if classOf inner_border_edges != BitArray then return undefined
        if inner_border_edges.numberSet == 0 then return #()

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        edge_vertices = topology_data[6]
        inner_vertices = #{}
        inner_vertices.count = topology_data[1]

        for edge_index in inner_border_edges do
        (
            edge_pair = edge_vertices[edge_index]

            if edge_pair == undefined or edge_pair.count != 2 then return undefined

            inner_vertices[edge_pair[1]] = true
            inner_vertices[edge_pair[2]] = true
        )

        if inner_vertices.numberSet == 0 then return #()

        first_inner_vertex = 0
        for vertex_index in inner_vertices while first_inner_vertex == 0 do
        (
            first_inner_vertex = vertex_index
        )

        if first_inner_vertex < 1 or first_inner_vertex > vertex_points.count then return undefined

        first_point = vertex_points[first_inner_vertex]
        min_x = first_point.x
        max_x = first_point.x
        min_y = first_point.y
        max_y = first_point.y
        min_z = first_point.z
        max_z = first_point.z

        for vertex_index in inner_vertices do
        (
            vertex_point = vertex_points[vertex_index]

            if vertex_point.x < min_x then min_x = vertex_point.x
            if vertex_point.x > max_x then max_x = vertex_point.x
            if vertex_point.y < min_y then min_y = vertex_point.y
            if vertex_point.y > max_y then max_y = vertex_point.y
            if vertex_point.z < min_z then min_z = vertex_point.z
            if vertex_point.z > max_z then max_z = vertex_point.z
        )

        extent_x = max_x - min_x
        extent_y = max_y - min_y
        extent_z = max_z - min_z
        sweep_axis = 1
        sweep_extent = extent_x

        if extent_y > sweep_extent then
        (
            sweep_axis = 2
            sweep_extent = extent_y
        )

        if extent_z > sweep_extent then
        (
            sweep_axis = 3
        )

        inner_edge_data = #()
        inner_edge_data.count = topology_data[2]
        sweep_events = #()

        for target_edge_id in inner_border_edges do
        (
            target_pair = edge_vertices[target_edge_id]
            if target_pair == undefined or target_pair.count != 2 then return undefined

            point_a = vertex_points[target_pair[1]]
            point_b = vertex_points[target_pair[2]]
            target_length = distance point_a point_b

            edge_min_x = if point_a.x < point_b.x then point_a.x else point_b.x
            edge_max_x = if point_a.x > point_b.x then point_a.x else point_b.x
            edge_min_y = if point_a.y < point_b.y then point_a.y else point_b.y
            edge_max_y = if point_a.y > point_b.y then point_a.y else point_b.y
            edge_min_z = if point_a.z < point_b.z then point_a.z else point_b.z
            edge_max_z = if point_a.z > point_b.z then point_a.z else point_b.z

            inner_edge_data[target_edge_id] = #(
                edge_min_x,
                edge_max_x,
                edge_min_y,
                edge_max_y,
                edge_min_z,
                edge_max_z,
                target_length
            )

            point_a_axis = this.getPointAxisValue point_a sweep_axis
            point_b_axis = this.getPointAxisValue point_b sweep_axis
            if point_a_axis == undefined or point_b_axis == undefined then return undefined

            edge_axis_min = if point_a_axis < point_b_axis then point_a_axis else point_b_axis
            edge_axis_max = if point_a_axis > point_b_axis then point_a_axis else point_b_axis

            append sweep_events #(edge_axis_min - position_tolerance, 1, target_edge_id)
            append sweep_events #(edge_axis_max + position_tolerance, 3, target_edge_id)
        )

        for source_vertex_id in inner_vertices do
        (
            source_axis = this.getPointAxisValue vertex_points[source_vertex_id] sweep_axis
            if source_axis == undefined then return undefined

            append sweep_events #(source_axis, 2, source_vertex_id)
        )

        sweep_compare_function = this.compareBrokenTSweepEvents
        qsort sweep_events sweep_compare_function

        active_target_edges = #{}
        active_target_edges.count = topology_data[2]
        case_record_by_vertex = #()
        case_record_by_vertex.count = topology_data[1]

        for sweep_event in sweep_events do
        (
            event_type = sweep_event[2]
            event_id = sweep_event[3]

            if event_type == 1 then
            (
                active_target_edges[event_id] = true
            )
            else if event_type == 3 then
            (
                active_target_edges[event_id] = false
            )
            else
            (
                source_vertex_id = event_id
                source_point = vertex_points[source_vertex_id]
                source_inner_edges = vertex_edges[source_vertex_id] * inner_border_edges

                if source_inner_edges.numberSet > 0 then
                (
                    best_target_edge = 0
                    best_target_fraction = 0.0
                    best_target_distance = undefined
                    best_target_length = undefined

                    for target_edge_id in active_target_edges do
                    (
                        if not source_inner_edges[target_edge_id] then
                        (
                            target_data = inner_edge_data[target_edge_id]

                            if target_data != undefined and target_data.count == 7 then
                            (
                                inside_x_bounds = source_point.x >= (target_data[1] - position_tolerance) and source_point.x <= (target_data[2] + position_tolerance)
                                inside_y_bounds = source_point.y >= (target_data[3] - position_tolerance) and source_point.y <= (target_data[4] + position_tolerance)
                                inside_z_bounds = source_point.z >= (target_data[5] - position_tolerance) and source_point.z <= (target_data[6] + position_tolerance)
                                inside_bounds = inside_x_bounds and inside_y_bounds and inside_z_bounds

                                if inside_bounds then
                                (
                                    target_length = target_data[7]

                                    if target_length > 0.0 then
                                    (
                                        target_pair = edge_vertices[target_edge_id]
                                        point_a = vertex_points[target_pair[1]]
                                        point_b = vertex_points[target_pair[2]]
                                        projection_data = this.getPointSegmentProjectionData source_point point_a point_b
                                        projection_distance = projection_data[1]
                                        projection_fraction = projection_data[2]
                                        endpoint_fraction = position_tolerance / target_length

                                        if projection_distance <= position_tolerance and projection_fraction > endpoint_fraction and projection_fraction < (1.0 - endpoint_fraction) then
                                        (
                                            has_parallel_source_edge = false

                                            for source_edge_id in source_inner_edges while not has_parallel_source_edge do
                                            (
                                                source_other_vertex = this.getOtherEdgeVertex source_edge_id source_vertex_id topology_data

                                                if source_other_vertex >= 1 and source_other_vertex <= vertex_points.count then
                                                (
                                                    source_other_point = vertex_points[source_other_vertex]
                                                    source_line_data = this.getPointSegmentProjectionData source_other_point point_a point_b

                                                    if source_line_data[1] <= position_tolerance then
                                                    (
                                                        has_parallel_source_edge = true
                                                    )
                                                )
                                            )

                                            if has_parallel_source_edge then
                                            (
                                                choose_target = false

                                                if best_target_edge == 0 then
                                                (
                                                    choose_target = true
                                                )
                                                else if projection_distance < best_target_distance then
                                                (
                                                    choose_target = true
                                                )
                                                else if projection_distance == best_target_distance and target_length < best_target_length then
                                                (
                                                    choose_target = true
                                                )

                                                if choose_target then
                                                (
                                                    best_target_edge = target_edge_id
                                                    best_target_fraction = projection_fraction
                                                    best_target_distance = projection_distance
                                                    best_target_length = target_length
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )

                    if best_target_edge > 0 then
                    (
                        case_record_by_vertex[source_vertex_id] = #(source_vertex_id, best_target_edge, best_target_fraction, best_target_distance, copy source_inner_edges)
                    )
                )
            )
        )

        case_records = #()

        for source_vertex_id in inner_vertices do
        (
            if case_record_by_vertex[source_vertex_id] != undefined then
            (
                append case_records case_record_by_vertex[source_vertex_id]
            )
        )

        case_records
        -- return
    ),

    /*
    Builds complete Broken-T border analysis once for one unchanged topology snapshot.
    Valid closed inner borders with no vertex-on-edge T seam are not selected.
    Returns #(selectedDegenerateBorderEdges, caseRecords, componentCount, innerBorderEdges, innerBorderVertices).
    */
    function getBrokenTJunctionBorderAnalysis topology_data position_tolerance =
    (
        if topology_data == undefined then return undefined

        border_components = this.buildBorderComponents topology_data
        classification = this.classifyBorderEdgesFromComponents topology_data border_components
        if classification == undefined then return undefined

        inner_border_edges = classification[3]
        inner_border_vertices = this.getTopologyVerticesFromEdges topology_data inner_border_edges
        if inner_border_vertices == undefined then return undefined

        case_records = this.findBrokenTJunctionCases topology_data position_tolerance inner_border_edges:inner_border_edges
        if case_records == undefined then return undefined

        problem_edges = #{}
        problem_edges.count = topology_data[2]

        for case_record in case_records do
        (
            target_edge_id = case_record[2]
            source_inner_edges = case_record[5]

            problem_edges[target_edge_id] = true
            problem_edges += source_inner_edges
        )

        selected_edges = #{}
        selected_edges.count = topology_data[2]
        broken_component_count = 0

        for component_edges in border_components do
        (
            inner_component_edges = component_edges * inner_border_edges

            if inner_component_edges.numberSet > 0 and (inner_component_edges * problem_edges).numberSet > 0 then
            (
                selected_edges += inner_component_edges
                broken_component_count += 1
            )
        )

        #(selected_edges, case_records, broken_component_count, inner_border_edges, inner_border_vertices)
        -- return
    ),

    /*
    Expands local broken-T case edges to their complete degenerate inner-border components.
    Preserves the established three-field result contract while the internal analysis helper also carries reusable inner-border sets.
    Returns #(selectedDegenerateBorderEdges, caseRecords, componentCount).
    */
    function getBrokenTJunctionBorderSelection topology_data position_tolerance =
    (
        analysis_result = this.getBrokenTJunctionBorderAnalysis topology_data position_tolerance
        if analysis_result == undefined then return undefined

        #(analysis_result[1], analysis_result[2], analysis_result[3])
        -- return
    ),

    /*
    Detects and stores the Broken-T border selection once, retaining the same pre-topology-change analysis for the first Divide cycle.
    Returns #(success, node, selector, topologyData, caseRecords, positionTolerance, componentCount, selectedEdges, errorText, innerBorderEdges, innerBorderVertices).
    */
    function prepareBrokenTJunctionSelectionData show_dialogs:true =
    (
        local empty_cases = #()
        local empty_edges = #{}
        local empty_inner_edges = #{}
        local empty_inner_vertices = #{}
        local error_text = ""

        if selection.count != 1 then
        (
            error_text = "Select exactly one Editable Poly or active Edit Poly object."
            if show_dialogs then messageBox error_text title:"Loop-Cleaner"
            return #(false, undefined, undefined, undefined, empty_cases, undefined, 0, empty_edges, error_text, empty_inner_edges, empty_inner_vertices)
        )

        node = selection[1]
        analysis_data = this.getBorderSelectionAnalysis node

        if not analysis_data[1] then
        (
            error_text = analysis_data[4]
            if show_dialogs then messageBox error_text title:"Loop-Cleaner"
            return #(false, node, undefined, undefined, empty_cases, undefined, 0, empty_edges, error_text, empty_inner_edges, empty_inner_vertices)
        )

        topology_data = analysis_data[2]
        selector_before_index = analysis_data[3]
        position_tolerance = this.getBrokenTJunctionPositionPrecision()

        if position_tolerance == undefined or position_tolerance <= 0.0 then
        (
            error_text = "Invalid Broken-T position precision."
            format "Loop-Cleaner BROKEN T SELECT FAILED | node:% | positionPrecision:% | error:%\n" node.name this.position_precision_text error_text
            if show_dialogs then messageBox error_text title:"Loop-Cleaner"
            return #(false, node, undefined, topology_data, empty_cases, position_tolerance, 0, empty_edges, error_text, empty_inner_edges, empty_inner_vertices)
        )

        broken_data = this.getBrokenTJunctionBorderAnalysis topology_data position_tolerance

        if broken_data == undefined then
        (
            error_text = "Could not classify broken inner-border T junctions."
            if show_dialogs then messageBox error_text title:"Loop-Cleaner"
            return #(false, node, undefined, topology_data, empty_cases, position_tolerance, 0, empty_edges, error_text, empty_inner_edges, empty_inner_vertices)
        )

        broken_edges = broken_data[1] * topology_data[12]
        case_records = broken_data[2]
        broken_component_count = broken_data[3]
        inner_border_edges = broken_data[4]
        inner_border_vertices = broken_data[5]
        write_result = this.writeBrokenTJunctionSelection node broken_edges before_index:selector_before_index refresh_viewport:show_dialogs

        if not write_result[1] then
        (
            error_text = "Could not store the broken-T border selection in SELECT BROKEN T JUNCTIONS."
            if show_dialogs then messageBox (error_text + " See Listener for verification details.") title:"Loop-Cleaner"
            return #(false, node, write_result[2], topology_data, case_records, position_tolerance, broken_component_count, broken_edges, error_text, inner_border_edges, inner_border_vertices)
        )

        format "Loop-Cleaner BROKEN T SELECT | node:% | positionPrecision:% | cases:% | components:% | selected:% | edges:%\n" node.name this.position_precision_text case_records.count broken_component_count broken_edges.numberSet broken_edges

        #(true, node, write_result[2], topology_data, case_records, position_tolerance, broken_component_count, broken_edges, "", inner_border_edges, inner_border_vertices)
        -- return
    ),

    /*
    Selects every degenerate inner-border component containing a border vertex-on-edge T seam.
    The positional contract uses the single configured Broken-T position tolerance.
    */
    function selectBrokenTJunctionBorders show_dialogs:true =
    (
        local selection_data = this.prepareBrokenTJunctionSelectionData show_dialogs:show_dialogs
        selection_data[1]
        -- return
    ),

    /*
    Moves one Edit Poly vertex exactly onto another existing vertex.
    Node-scoped Edit Poly GetVertex values are already world-space, matching MoveSelection's world-space delta path.
    */
    function moveBrokenTVertexOntoVertex node edit_poly_mod moving_vertex_id target_vertex_id position_tolerance =
    (
        if node == undefined or not isValidNode node then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node

        if moving_vertex_id < 1 or moving_vertex_id > vertex_count then return false
        if target_vertex_id < 1 or target_vertex_id > vertex_count then return false
        if moving_vertex_id == target_vertex_id then return false

        moving_world = EditPolyMod.GetVertex edit_poly_mod moving_vertex_id node:node
        target_world = EditPolyMod.GetVertex edit_poly_mod target_vertex_id node:node

        if moving_world == undefined or target_world == undefined then return false

        select node
        max modify mode

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off

        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        old_vertices = edit_poly_mod.GetSelection #Vertex node:node
        if old_vertices == undefined then return false

        if old_vertices.numberSet > 0 then
        (
            edit_poly_mod.Select #Vertex old_vertices select:false node:node
        )

        moving_bits = #{}
        moving_bits[moving_vertex_id] = true
        edit_poly_mod.Select #Vertex moving_bits select:true node:node

        stored_vertices = edit_poly_mod.GetSelection #Vertex node:node
        if stored_vertices == undefined or stored_vertices != moving_bits then return false

        move_delta_world = target_world - moving_world

        if move_delta_world != [0,0,0] then
        (
            edit_poly_mod.MoveSelection move_delta_world
            edit_poly_mod.Commit()
            edit_poly_mod.RefreshScreen()
            update node
        )

        moved_world = EditPolyMod.GetVertex edit_poly_mod moving_vertex_id node:node
        target_after_move_world = EditPolyMod.GetVertex edit_poly_mod target_vertex_id node:node

        if moved_world == undefined or target_after_move_world == undefined then return false

        distance moved_world target_after_move_world <= position_tolerance
        -- return
    ),

    /*
    Replaces the Broken-T Edit Poly vertex selection with exactly the supplied BitArray.
    Returns true only when the modifier reports the exact requested selection afterwards.
    */
    function setExactBrokenTVertexSelection node edit_poly_mod vertex_bits =
    (
        if node == undefined or not isValidNode node then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if classOf vertex_bits != BitArray then return false

        current_vertices = edit_poly_mod.GetSelection #Vertex node:node

        if current_vertices == undefined then
        (
            format "Loop-Cleaner BROKEN T MOVE SELECTION READ FAILED | node:%\n" node.name
            return false
        )

        if current_vertices.numberSet > 0 then
        (
            edit_poly_mod.Select #Vertex current_vertices select:false node:node
        )

        if vertex_bits.numberSet > 0 then
        (
            edit_poly_mod.Select #Vertex vertex_bits select:true node:node
        )

        stored_vertices = edit_poly_mod.GetSelection #Vertex node:node

        if stored_vertices == undefined or stored_vertices != vertex_bits then
        (
            format "Loop-Cleaner BROKEN T MOVE SELECTION VERIFY FAILED | node:% | expected:% | actual:%\n" node.name vertex_bits stored_vertices
            return false
        )

        true
        -- return
    ),

    /*
    Moves appended Broken-T vertices one by one through exact Edit Poly vertex isolation.
    Each record stores #(sourceVertexID, insertedVertexID); source and inserted positions are read live immediately before MoveSelection.
    The user's previous Edit Poly selection state is restored after the stage.
    */
    function moveBrokenTVertexRecords node edit_poly_mod move_records position_precision =
    (
        if node == undefined or not isValidNode node then
        (
            format "Loop-Cleaner BROKEN T MOVE PRECONDITION FAILED | node:%\n" node
            return false
        )
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then
        (
            format "Loop-Cleaner BROKEN T MOVE PRECONDITION FAILED | editPoly:%\n" edit_poly_mod
            return false
        )
        if classOf move_records != Array or move_records.count == 0 then
        (
            format "Loop-Cleaner BROKEN T MOVE PRECONDITION FAILED | moveRecords:% | type:%\n" move_records (classOf move_records)
            return false
        )
        if position_precision == undefined or position_precision <= 0.0 then
        (
            format "Loop-Cleaner BROKEN T MOVE PRECONDITION FAILED | positionPrecision:%\n" position_precision
            return false
        )
        if edit_poly_mod.currentOperation != 0 then
        (
            format "Loop-Cleaner BROKEN T MOVE PRECONDITION FAILED | node:% | currentOperation:% | required:0\n" node.name edit_poly_mod.currentOperation
            return false
        )

        modifier_is_live = false

        for stack_mod in node.modifiers while not modifier_is_live do
        (
            if stack_mod == edit_poly_mod then modifier_is_live = true
        )

        if not modifier_is_live then
        (
            format "Loop-Cleaner BROKEN T MOVE PRECONDITION FAILED | node:% | editPolyNoLongerInStack:%\n" node.name edit_poly_mod
            return false
        )

        vertex_count = edit_poly_mod.GetNumVertices node:node

        for move_record in move_records do
        (
            if classOf move_record != Array or move_record.count != 2 then
            (
                format "Loop-Cleaner BROKEN T MOVE RECORD FAILED | record:%\n" move_record
                return false
            )

            source_vertex_id = move_record[1]
            inserted_vertex_id = move_record[2]

            if classOf source_vertex_id != Integer or classOf inserted_vertex_id != Integer then
            (
                format "Loop-Cleaner BROKEN T MOVE RECORD TYPE FAILED | sourceVertex:% | insertedVertex:%\n" source_vertex_id inserted_vertex_id
                return false
            )

            if source_vertex_id < 1 or source_vertex_id > vertex_count or inserted_vertex_id < 1 or inserted_vertex_id > vertex_count or source_vertex_id == inserted_vertex_id then
            (
                format "Loop-Cleaner BROKEN T MOVE ID FAILED | sourceVertex:% | insertedVertex:% | liveVertexCount:%\n" source_vertex_id inserted_vertex_id vertex_count
                return false
            )
        )

        original_primary_node = edit_poly_mod.GetPrimaryNode()
        original_level = edit_poly_mod.GetEPolySelLevel()
        original_use_stack_selection = edit_poly_mod.useStackSelection
        original_select_mode = edit_poly_mod.selectMode
        original_vertex_selection = edit_poly_mod.GetSelection #Vertex node:node

        if original_vertex_selection == undefined then
        (
            format "Loop-Cleaner BROKEN T MOVE ORIGINAL SELECTION READ FAILED | node:%\n" node.name
            return false
        )

        original_vertex_selection = copy original_vertex_selection
        move_ok = true
        operation_exception = undefined

        try
        (
            select node
            max modify mode

            edit_poly_mod.SetPrimaryNode node
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            edit_poly_mod.showCage = off
            modPanel.setCurrentObject edit_poly_mod node:node
            edit_poly_mod.SetEPolySelLevel #Vertex
            subObjectLevel = 1

            if not this.setExactBrokenTVertexSelection node edit_poly_mod #{} then
            (
                throw "Could not clear the Edit Poly vertex selection before Broken-T movement."
            )

            for move_record in move_records while move_ok do
            (
                source_vertex_id = move_record[1]
                inserted_vertex_id = move_record[2]
                source_position = edit_poly_mod.GetVertex source_vertex_id node:node
                inserted_position = edit_poly_mod.GetVertex inserted_vertex_id node:node

                if source_position == undefined or inserted_position == undefined then
                (
                    format "Loop-Cleaner BROKEN T MOVE POSITION READ FAILED | sourceVertex:% | insertedVertex:% | sourcePosition:% | insertedPosition:%\n" source_vertex_id inserted_vertex_id source_position inserted_position
                    move_ok = false
                )
                else
                (
                    vertex_bits = #{}
                    vertex_bits[inserted_vertex_id] = true

                    if not this.setExactBrokenTVertexSelection node edit_poly_mod vertex_bits then
                    (
                        move_ok = false
                    )
                    else
                    (
                        move_delta = source_position - inserted_position
                        if not this.quiet_mode then
                        (
                            format "Loop-Cleaner BROKEN T MOVE | sourceVertex:% | insertedVertex:% | sourcePosition:% | insertedPosition:% | delta:%\n" source_vertex_id inserted_vertex_id source_position inserted_position move_delta
                        )

                        if move_delta != [0,0,0] then
                        (
                            edit_poly_mod.MoveSelection move_delta
                            edit_poly_mod.Commit()
                            update node
                            edit_poly_mod.RefreshScreen()
                            completeRedraw()

                            moved_position = edit_poly_mod.GetVertex inserted_vertex_id node:node

                            if moved_position == undefined then
                            (
                                format "Loop-Cleaner BROKEN T MOVE VERIFY READ FAILED | sourceVertex:% | insertedVertex:% | expected:% | actual:% | positionPrecision:%\n" source_vertex_id inserted_vertex_id source_position moved_position this.position_precision_text
                                move_ok = false
                            )
                            else
                            (
                                rounded_expected = this.roundPositionToPrecision source_position position_precision
                                rounded_actual = this.roundPositionToPrecision moved_position position_precision

                                if rounded_expected == undefined or rounded_actual == undefined then
                                (
                                    format "Loop-Cleaner BROKEN T MOVE VERIFY ROUND FAILED | sourceVertex:% | insertedVertex:% | expected:% | actual:% | positionPrecision:%\n" source_vertex_id inserted_vertex_id source_position moved_position this.position_precision_text
                                    move_ok = false
                                )
                                else if rounded_actual != rounded_expected then
                                (
                                    format "Loop-Cleaner BROKEN T MOVE VERIFY FAILED | sourceVertex:% | insertedVertex:% | before:% | expectedRaw:% | actualRaw:% | expectedRounded:% | actualRounded:% | remainingDelta:% | positionPrecision:%\n" source_vertex_id inserted_vertex_id inserted_position source_position moved_position rounded_expected rounded_actual (source_position - moved_position) this.position_precision_text
                                    move_ok = false
                                )
                                else
                                (
                                    if not this.quiet_mode then
                                    (
                                        format "Loop-Cleaner BROKEN T MOVE VERIFIED | sourceVertex:% | insertedVertex:% | before:% | after:% | positionPrecision:%\n" source_vertex_id inserted_vertex_id inserted_position moved_position this.position_precision_text
                                    )
                                )
                            )
                        )
                        else
                        (
                            if not this.quiet_mode then
                            (
                                format "Loop-Cleaner BROKEN T MOVE ALREADY ALIGNED | sourceVertex:% | insertedVertex:% | position:%\n" source_vertex_id inserted_vertex_id source_position
                            )
                        )
                    )
                )
            )
        )
        catch
        (
            operation_exception = getCurrentException()
            format "Loop-Cleaner BROKEN T MOVE NATIVE ERROR | node:% | error:%\n" node.name operation_exception
            move_ok = false
        )

        restore_ok = true

        try
        (
            if not this.setExactBrokenTVertexSelection node edit_poly_mod original_vertex_selection then
            (
                restore_ok = false
            )

            edit_poly_mod.useStackSelection = original_use_stack_selection
            edit_poly_mod.selectMode = original_select_mode

            if original_level != undefined then
            (
                edit_poly_mod.SetEPolySelLevel original_level
            )

            if original_primary_node != undefined and isValidNode original_primary_node then
            (
                edit_poly_mod.SetPrimaryNode original_primary_node
            )
        )
        catch
        (
            format "Loop-Cleaner BROKEN T MOVE RESTORE ERROR | node:% | error:%\n" node.name (getCurrentException())
            restore_ok = false
        )

        edit_poly_mod.showCage = off
        edit_poly_mod.RefreshScreen()
        completeRedraw()
        update node

        if not restore_ok then
        (
            format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:restore Edit Poly state\n" node.name
            return false
        )

        move_ok
        -- return
    ),

    /*
    Finds one existing opposite-side inner-border vertex at the broken-T source position.
    The candidate must be a non-neighbor inner-border vertex within the explicit position tolerance
    and must lie on the detected target-edge segment line. Ambiguous coincident candidates fail.
    Optional preclassified inner-border edge/vertex sets avoid repeating unchanged border analysis.
    Returns #(#found, targetVertexID, errorText), #(#missing, 0, ""), or #(#error, 0, errorText).
    */
    function findExistingBrokenTTargetVertex topology_data source_vertex_id target_edge_id position_tolerance inner_border_edges:undefined inner_border_vertices:undefined =
    (
        if topology_data == undefined then return #(#error, 0, "Missing broken-T topology.")
        if position_tolerance < 0.0 then return #(#error, 0, "Invalid broken-T position tolerance.")

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        edge_vertices = topology_data[6]

        if source_vertex_id < 1 or source_vertex_id > vertex_points.count then return #(#error, 0, "Invalid broken-T source vertex.")
        if target_edge_id < 1 or target_edge_id > edge_vertices.count then return #(#error, 0, "Invalid broken-T target edge.")

        target_pair = edge_vertices[target_edge_id]
        if target_pair == undefined or target_pair.count != 2 then return #(#error, 0, "Broken-T target edge has invalid endpoints.")

        if inner_border_edges == undefined then
        (
            classification = this.classifyBorderEdges topology_data
            if classification == undefined then return #(#error, 0, "Could not classify inner borders while resolving an existing weld vertex.")

            inner_border_edges = classification[3]
        )

        if classOf inner_border_edges != BitArray then return #(#error, 0, "Invalid inner-border edge set while resolving an existing weld vertex.")

        if inner_border_vertices == undefined then
        (
            inner_border_vertices = this.getTopologyVerticesFromEdges topology_data inner_border_edges
        )

        if classOf inner_border_vertices != BitArray then return #(#error, 0, "Could not resolve inner-border vertices while resolving an existing weld vertex.")

        source_point = vertex_points[source_vertex_id]
        target_point_a = vertex_points[target_pair[1]]
        target_point_b = vertex_points[target_pair[2]]
        source_neighbor_vertices = #{}
        source_neighbor_vertices.count = vertex_points.count

        for source_edge_id in vertex_edges[source_vertex_id] do
        (
            neighbor_vertex_id = this.getOtherEdgeVertex source_edge_id source_vertex_id topology_data

            if neighbor_vertex_id >= 1 and neighbor_vertex_id <= source_neighbor_vertices.count then
            (
                source_neighbor_vertices[neighbor_vertex_id] = true
            )
        )

        best_vertex_id = 0
        best_distance = undefined
        ambiguous_best = false

        for candidate_vertex_id in inner_border_vertices do
        (
            if candidate_vertex_id != source_vertex_id and not source_neighbor_vertices[candidate_vertex_id] then
            (
                candidate_point = vertex_points[candidate_vertex_id]
                source_distance = distance source_point candidate_point

                if source_distance <= position_tolerance then
                (
                    target_line_data = this.getPointSegmentProjectionData candidate_point target_point_a target_point_b
                    target_line_distance = target_line_data[1]
                    target_line_fraction = target_line_data[2]

                    if target_line_distance <= position_tolerance and target_line_fraction >= 0.0 and target_line_fraction <= 1.0 then
                    (
                        choose_candidate = false

                        if best_vertex_id == 0 then
                        (
                            choose_candidate = true
                        )
                        else if source_distance < best_distance then
                        (
                            choose_candidate = true
                        )

                        if choose_candidate then
                        (
                            best_vertex_id = candidate_vertex_id
                            best_distance = source_distance
                            ambiguous_best = false
                        )
                        else if source_distance == best_distance then
                        (
                            ambiguous_best = true
                        )
                    )
                )
            )
        )

        if best_vertex_id == 0 then
        (
            return #(#missing, 0, "")
        )

        if ambiguous_best then
        (
            return #(#error, 0, "More than one equally close existing opposite inner-border vertex was found; the weld target is ambiguous.")
        )

        #(#found, best_vertex_id, "")
        -- return
    ),

    /*
    Builds topology-independent insertion records for all currently missing Broken-T targets.
    Component IDs are converted to world-space source/neighbor/target geometry before any split.
    One preclassified inner-border edge/vertex set is reused across all case resolvers when supplied.
    Returns #(success, insertPlan, errorText).
    */
    function buildBrokenTInsertPlan topology_data case_records position_tolerance inner_border_edges:undefined inner_border_vertices:undefined =
    (
        if topology_data == undefined then return #(false, #(), "Missing broken-T topology.")
        if case_records == undefined then return #(false, #(), "Missing broken-T case records.")
        if position_tolerance < 0.0 then return #(false, #(), "Invalid broken-T position tolerance.")
        if case_records.count == 0 then return #(true, #(), "")

        vertex_points = topology_data[4]
        edge_vertices = topology_data[6]
        insert_plan = #()
        if inner_border_edges == undefined then
        (
            classification = this.classifyBorderEdges topology_data

            if classification == undefined then return #(false, #(), "Could not classify inner borders while building the Broken-T insert plan.")

            inner_border_edges = classification[3]
        )

        if classOf inner_border_edges != BitArray then return #(false, #(), "Invalid inner-border edge set while building the Broken-T insert plan.")

        if inner_border_vertices == undefined then
        (
            inner_border_vertices = this.getTopologyVerticesFromEdges topology_data inner_border_edges
        )

        if classOf inner_border_vertices != BitArray then return #(false, #(), "Could not resolve inner-border vertices while building the Broken-T insert plan.")

        for case_record in case_records do
        (
            source_vertex_id = case_record[1]
            target_edge_id = case_record[2]
            source_inner_edges = case_record[5]

            existing_target_result = this.findExistingBrokenTTargetVertex \
                topology_data \
                source_vertex_id \
                target_edge_id \
                position_tolerance \
                inner_border_edges:inner_border_edges \
                inner_border_vertices:inner_border_vertices

            existing_target_status = existing_target_result[1]

            if existing_target_status == #error then
            (
                return #(false, #(), existing_target_result[3])
            )
            else if existing_target_status == #missing then
            (
                if source_vertex_id < 1 or source_vertex_id > vertex_points.count then return #(false, #(), "Invalid Broken-T source vertex while building the insert plan.")
                if target_edge_id < 1 or target_edge_id > edge_vertices.count then return #(false, #(), "Invalid Broken-T target edge while building the insert plan.")

                target_pair = edge_vertices[target_edge_id]
                if target_pair == undefined or target_pair.count != 2 then return #(false, #(), "Broken-T target edge has invalid endpoints while building the insert plan.")

                source_neighbor_points = #()

                for source_edge_id in source_inner_edges do
                (
                    neighbor_vertex_id = this.getOtherEdgeVertex source_edge_id source_vertex_id topology_data

                    if neighbor_vertex_id >= 1 and neighbor_vertex_id <= vertex_points.count then
                    (
                        neighbor_point = vertex_points[neighbor_vertex_id]

                        if findItem source_neighbor_points neighbor_point == 0 then
                        (
                            append source_neighbor_points neighbor_point
                        )
                    )
                )

                if source_neighbor_points.count == 0 then return #(false, #(), "Broken-T source has no reusable inner-border neighbor signature.")

                append insert_plan #(
                    vertex_points[source_vertex_id],
                    source_neighbor_points,
                    vertex_points[target_pair[1]],
                    vertex_points[target_pair[2]],
                    source_vertex_id,
                    target_edge_id,
                    target_pair[1],
                    target_pair[2]
                )
            )
        )

        #(true, insert_plan, "")
        -- return
    ),

    /*
    Re-resolves one preserved Broken-T source vertex after topology changes.
    The source must keep its exact world position and connect to every stored source-neighbor position.
    Returns #(#found, vertexID, errorText) or #(#error, 0, errorText).
    */
    function findBrokenTSourceVertexByGeometry topology_data source_point source_neighbor_points =
    (
        if topology_data == undefined then return #(#error, 0, "Missing topology while resolving the Broken-T source vertex.")
        if source_neighbor_points == undefined or source_neighbor_points.count == 0 then return #(#error, 0, "Missing Broken-T source-neighbor geometry.")

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        matching_vertices = #()

        for candidate_vertex_id = 1 to vertex_points.count do
        (
            if vertex_points[candidate_vertex_id] == source_point then
            (
                matches_all_neighbors = true

                for neighbor_point in source_neighbor_points while matches_all_neighbors do
                (
                    neighbor_found = false

                    for candidate_edge_id in vertex_edges[candidate_vertex_id] while not neighbor_found do
                    (
                        other_vertex_id = this.getOtherEdgeVertex candidate_edge_id candidate_vertex_id topology_data

                        if other_vertex_id >= 1 and other_vertex_id <= vertex_points.count then
                        (
                            if vertex_points[other_vertex_id] == neighbor_point then
                            (
                                neighbor_found = true
                            )
                        )
                    )

                    if not neighbor_found then
                    (
                        matches_all_neighbors = false
                    )
                )

                if matches_all_neighbors then
                (
                    append matching_vertices candidate_vertex_id
                )
            )
        )

        if matching_vertices.count == 1 then return #(#found, matching_vertices[1], "")
        if matching_vertices.count == 0 then return #(#error, 0, "Could not re-resolve the preserved Broken-T source vertex from its geometry.")

        #(#error, 0, "More than one Broken-T source vertex matches the stored geometry signature.")
        -- return
    ),

    /*
    Finds the current child edge of an original Broken-T target segment that still contains a source point.
    This is the Stage-06 rule: after every split, discard the old edge ID and resolve the next segment geometrically.
    Returns #(#found, edgeID, divideFraction, endpointA, endpointB, projectedPoint, errorText),
    #(#missing, 0, 0.0, undefined, undefined, undefined, ""), or #(#error, ...).
    */
    function findBrokenTChildEdgeForPoint topology_data source_point original_target_a original_target_b position_tolerance =
    (
        empty_result = #(#missing, 0, 0.0, undefined, undefined, undefined, "")

        if topology_data == undefined then return #(#error, 0, 0.0, undefined, undefined, undefined, "Missing topology while resolving a Broken-T child edge.")
        if position_tolerance < 0.0 then return #(#error, 0, 0.0, undefined, undefined, undefined, "Invalid Broken-T position tolerance.")
        if original_target_a == original_target_b then return #(#error, 0, 0.0, undefined, undefined, undefined, "Broken-T original target edge has zero length.")

        classification = this.classifyBorderEdges topology_data
        if classification == undefined then return #(#error, 0, 0.0, undefined, undefined, undefined, "Could not classify inner borders while resolving a Broken-T child edge.")

        inner_border_edges = classification[3]
        vertex_points = topology_data[4]
        edge_vertices = topology_data[6]
        best_edge_id = 0
        best_fraction = 0.0
        best_distance = undefined
        best_length = undefined
        best_point_a = undefined
        best_point_b = undefined
        best_projected_point = undefined
        ambiguous_best = false

        for candidate_edge_id in inner_border_edges do
        (
            candidate_pair = edge_vertices[candidate_edge_id]

            if candidate_pair != undefined and candidate_pair.count == 2 then
            (
                candidate_point_a = vertex_points[candidate_pair[1]]
                candidate_point_b = vertex_points[candidate_pair[2]]
                candidate_length = distance candidate_point_a candidate_point_b

                if candidate_length > 0.0 then
                (
                    endpoint_a_on_original = this.getPointSegmentProjectionData candidate_point_a original_target_a original_target_b
                    endpoint_b_on_original = this.getPointSegmentProjectionData candidate_point_b original_target_a original_target_b

                    if endpoint_a_on_original[1] <= position_tolerance and endpoint_b_on_original[1] <= position_tolerance and endpoint_a_on_original[2] >= 0.0 and endpoint_a_on_original[2] <= 1.0 and endpoint_b_on_original[2] >= 0.0 and endpoint_b_on_original[2] <= 1.0 then
                    (
                        source_projection = this.getPointSegmentProjectionData source_point candidate_point_a candidate_point_b
                        endpoint_fraction = position_tolerance / candidate_length

                        if source_projection[1] <= position_tolerance and source_projection[2] > endpoint_fraction and source_projection[2] < (1.0 - endpoint_fraction) then
                        (
                            choose_candidate = false

                            if best_edge_id == 0 then
                            (
                                choose_candidate = true
                            )
                            else if source_projection[1] < best_distance then
                            (
                                choose_candidate = true
                            )
                            else if source_projection[1] == best_distance and candidate_length < best_length then
                            (
                                choose_candidate = true
                            )

                            if choose_candidate then
                            (
                                best_edge_id = candidate_edge_id
                                best_fraction = source_projection[2]
                                best_distance = source_projection[1]
                                best_length = candidate_length
                                best_point_a = candidate_point_a
                                best_point_b = candidate_point_b
                                best_projected_point = source_projection[3]
                                ambiguous_best = false
                            )
                            else if source_projection[1] == best_distance and candidate_length == best_length then
                            (
                                ambiguous_best = true
                            )
                        )
                    )
                )
            )
        )

        if best_edge_id == 0 then return empty_result
        if ambiguous_best then return #(#error, 0, 0.0, undefined, undefined, undefined, "More than one current child edge can receive the same Broken-T source point.")

        #(#found, best_edge_id, best_fraction, best_point_a, best_point_b, best_projected_point, "")
        -- return
    ),

    /*
    Resolves the vertex created by one DivideEdge using the pre-divide child-edge endpoint positions.
    The created vertex must connect to both old child-edge endpoints, so a coincident T source cannot be mistaken for it.
    Returns #(#found, vertexID, errorText) or #(#error, 0, errorText).
    */
    function findInsertedBrokenTVertexByGeometry topology_data source_vertex_id projected_point target_endpoint_a target_endpoint_b position_tolerance =
    (
        if topology_data == undefined then return #(#error, 0, "Missing topology while resolving the inserted Broken-T vertex.")
        if position_tolerance < 0.0 then return #(#error, 0, "Invalid Broken-T position tolerance.")

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        matching_vertices = #()

        for candidate_vertex_id = 1 to vertex_points.count do
        (
            if candidate_vertex_id != source_vertex_id and distance vertex_points[candidate_vertex_id] projected_point <= position_tolerance then
            (
                has_endpoint_a = false
                has_endpoint_b = false

                for candidate_edge_id in vertex_edges[candidate_vertex_id] do
                (
                    other_vertex_id = this.getOtherEdgeVertex candidate_edge_id candidate_vertex_id topology_data

                    if other_vertex_id >= 1 and other_vertex_id <= vertex_points.count then
                    (
                        other_point = vertex_points[other_vertex_id]

                        if other_point == target_endpoint_a then has_endpoint_a = true
                        if other_point == target_endpoint_b then has_endpoint_b = true
                    )
                )

                if has_endpoint_a and has_endpoint_b then
                (
                    append matching_vertices candidate_vertex_id
                )
            )
        )

        if matching_vertices.count == 1 then return #(#found, matching_vertices[1], "")
        if matching_vertices.count == 0 then return #(#error, 0, "Could not resolve the vertex created by DivideEdge from the child-edge endpoint geometry.")

        #(#error, 0, "More than one vertex matches the inserted Broken-T geometry signature.")
        -- return
    ),

    /*
    Re-resolves one current Edit Poly edge by its endpoint positions at the explicit precision.
    Returns the unique matching live edge ID, or zero when the edge cannot be resolved unambiguously.
    */
    function findEditPolyEdgeByEndpointPositions edit_poly_mod obj endpoint_a endpoint_b position_precision =
    (
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return 0
        if obj == undefined or not isValidNode obj then return 0
        if position_precision == undefined or position_precision <= 0.0 then return 0

        current_edge_count = edit_poly_mod.GetNumEdges node:obj
        found_edge_id = 0
        match_count = 0

        for edge_id = 1 to current_edge_count do
        (
            vertex_a = edit_poly_mod.GetEdgeVertex edge_id 1 node:obj
            vertex_b = edit_poly_mod.GetEdgeVertex edge_id 2 node:obj
            position_a = edit_poly_mod.GetVertex vertex_a node:obj
            position_b = edit_poly_mod.GetVertex vertex_b node:obj
            forward_match = (this.positionsMatchAtPrecision position_a endpoint_a position_precision) and (this.positionsMatchAtPrecision position_b endpoint_b position_precision)
            reverse_match = (this.positionsMatchAtPrecision position_a endpoint_b position_precision) and (this.positionsMatchAtPrecision position_b endpoint_a position_precision)

            if forward_match or reverse_match then
            (
                found_edge_id = edge_id
                match_count += 1
            )
        )

        if match_count == 1 then found_edge_id else 0
        -- return
    ),

    /*
    Resolves one live Edit Poly edge from an exact vertex pair.
    Uses native vertex-edge adjacency first, then falls back to the legacy full edge scan only when the local adjacency path finds no match.
    */
    function findEditPolyEdgeByVertexPair edit_poly_mod obj vertex_a vertex_b =
    (
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return 0
        if obj == undefined or not isValidNode obj then return 0
        if vertex_a < 1 or vertex_b < 1 or vertex_a == vertex_b then return 0

        local current_vertex_count = edit_poly_mod.GetNumVertices node:obj

        if vertex_a > current_vertex_count or vertex_b > current_vertex_count then return 0

        local current_edge_count = edit_poly_mod.GetNumEdges node:obj
        local adjacent_edge_count = edit_poly_mod.GetVertexEdgeCount vertex_a node:obj
        local found_edge_id = 0
        local match_count = 0

        if classOf adjacent_edge_count == Integer and adjacent_edge_count > 0 then
        (
            for adjacent_index = 1 to adjacent_edge_count do
            (
                local adjacent_edge_id = edit_poly_mod.GetVertexEdge vertex_a adjacent_index node:obj

                if adjacent_edge_id >= 1 and adjacent_edge_id <= current_edge_count then
                (
                    local edge_vertex_a = edit_poly_mod.GetEdgeVertex adjacent_edge_id 1 node:obj
                    local edge_vertex_b = edit_poly_mod.GetEdgeVertex adjacent_edge_id 2 node:obj
                    local forward_match = edge_vertex_a == vertex_a and edge_vertex_b == vertex_b
                    local reverse_match = edge_vertex_a == vertex_b and edge_vertex_b == vertex_a

                    if forward_match or reverse_match then
                    (
                        found_edge_id = adjacent_edge_id
                        match_count += 1
                    )
                )
            )
        )

        if match_count == 1 then return found_edge_id
        if match_count > 1 then return 0

        found_edge_id = 0
        match_count = 0

        for edge_id = 1 to current_edge_count do
        (
            local edge_vertex_a = edit_poly_mod.GetEdgeVertex edge_id 1 node:obj
            local edge_vertex_b = edit_poly_mod.GetEdgeVertex edge_id 2 node:obj
            local forward_match = edge_vertex_a == vertex_a and edge_vertex_b == vertex_b
            local reverse_match = edge_vertex_a == vertex_b and edge_vertex_b == vertex_a

            if forward_match or reverse_match then
            (
                found_edge_id = edge_id
                match_count += 1
            )
        )

        if match_count == 1 then found_edge_id else 0
        -- return
    ),

    /*
    Adds the requested number of vertices using the repeated DivideEdge + Commit sequence.
    The first edge comes from the preserved topology ID; every later child segment is resolved exactly from inserted/far endpoint vertex IDs.
    */
    function addMultipleVerticesToEdge edit_poly_mod obj endpoint_a endpoint_b vertices_to_add position_precision initial_edge_id:0 initial_vertex_a:0 initial_vertex_b:0 =
    (
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #(false, #(), "Invalid Edit Poly target.")
        if obj == undefined or not isValidNode obj then return #(false, #(), "Invalid target node.")
        if vertices_to_add < 1 then return #(false, #(), "The requested insert count must be at least one.")
        if position_precision == undefined or position_precision <= 0.0 then return #(false, #(), "Invalid position precision.")

        current_edge_count = edit_poly_mod.GetNumEdges node:obj
        current_edge_id = initial_edge_id

        if current_edge_id < 1 or current_edge_id > current_edge_count then
        (
            current_edge_id = this.findEditPolyEdgeByEndpointPositions edit_poly_mod obj endpoint_a endpoint_b position_precision
        )

        if current_edge_id == 0 then
        (
            format "Loop-Cleaner BROKEN T TARGET EDGE RESOLVE FAILED | initialEdge:% | endpointA:% | endpointB:% | positionPrecision:%\n" initial_edge_id endpoint_a endpoint_b position_precision
            return #(false, #(), "Could not resolve the current target edge.")
        )

        live_vertex_a = edit_poly_mod.GetEdgeVertex current_edge_id 1 node:obj
        live_vertex_b = edit_poly_mod.GetEdgeVertex current_edge_id 2 node:obj
        live_position_a = edit_poly_mod.GetVertex live_vertex_a node:obj
        live_position_b = edit_poly_mod.GetVertex live_vertex_b node:obj
        has_exact_endpoint_ids = initial_vertex_a >= 1 and initial_vertex_b >= 1

        if has_exact_endpoint_ids and live_vertex_a == initial_vertex_a and live_vertex_b == initial_vertex_b then
        (
            current_vertex_a = live_vertex_a
            current_vertex_b = live_vertex_b
            current_position_a = live_position_a
            current_position_b = live_position_b
        )
        else if has_exact_endpoint_ids and live_vertex_a == initial_vertex_b and live_vertex_b == initial_vertex_a then
        (
            current_vertex_a = live_vertex_b
            current_vertex_b = live_vertex_a
            current_position_a = live_position_b
            current_position_b = live_position_a
        )
        else if not has_exact_endpoint_ids and (this.positionsMatchAtPrecision live_position_a endpoint_a position_precision) and (this.positionsMatchAtPrecision live_position_b endpoint_b position_precision) then
        (
            current_vertex_a = live_vertex_a
            current_vertex_b = live_vertex_b
            current_position_a = live_position_a
            current_position_b = live_position_b
        )
        else if not has_exact_endpoint_ids and (this.positionsMatchAtPrecision live_position_a endpoint_b position_precision) and (this.positionsMatchAtPrecision live_position_b endpoint_a position_precision) then
        (
            current_vertex_a = live_vertex_b
            current_vertex_b = live_vertex_a
            current_position_a = live_position_b
            current_position_b = live_position_a
        )
        else
        (
            format "Loop-Cleaner BROKEN T TARGET EDGE ID FAILED | edge:% | liveVertexA:% | liveVertexB:% | expectedVertexA:% | expectedVertexB:% | livePosA:% | livePosB:%\n" current_edge_id live_vertex_a live_vertex_b initial_vertex_a initial_vertex_b live_position_a live_position_b
            return #(false, #(), "The stored Broken-T target edge no longer has its preserved endpoint vertex IDs.")
        )

        inserted_vertex_ids = #()
        insert_ok = true
        insert_error = ""

        for insert_index = 1 to vertices_to_add while insert_ok do
        (
            remaining_insert_count = vertices_to_add - insert_index + 1
            insert_fraction = 1.0 / (remaining_insert_count + 1)
            vertex_count_before = edit_poly_mod.GetNumVertices node:obj

            edit_poly_mod.DivideEdge current_edge_id insert_fraction node:obj
            edit_poly_mod.Commit()

            vertex_count_after = edit_poly_mod.GetNumVertices node:obj

            if vertex_count_after != (vertex_count_before + 1) then
            (
                format "Loop-Cleaner BROKEN T DIVIDE COUNT FAILED | edge:% | insertIndex:% | beforeVertices:% | afterVertices:% | expectedAfter:%\n" current_edge_id insert_index vertex_count_before vertex_count_after (vertex_count_before + 1)
                insert_error = "DivideEdge did not add exactly one vertex."
                insert_ok = false
            )
            else
            (
                inserted_vertex_id = vertex_count_after
                append inserted_vertex_ids inserted_vertex_id

                if insert_index < vertices_to_add then
                (
                    current_edge_id = this.findEditPolyEdgeByVertexPair edit_poly_mod obj inserted_vertex_id current_vertex_b

                    if current_edge_id == 0 then
                    (
                        format "Loop-Cleaner BROKEN T CHILD EDGE RESOLVE FAILED | insertedVertex:% | farVertex:% | insertIndex:% | insertsTotal:%\n" inserted_vertex_id current_vertex_b insert_index vertices_to_add
                        insert_error = "Could not resolve the remaining child edge after DivideEdge."
                        insert_ok = false
                    )
                    else
                    (
                        current_vertex_a = inserted_vertex_id
                        current_position_a = edit_poly_mod.GetVertex current_vertex_a node:obj
                        current_position_b = edit_poly_mod.GetVertex current_vertex_b node:obj

                        if current_position_a == undefined or current_position_b == undefined then
                        (
                            format "Loop-Cleaner BROKEN T CHILD POSITION READ FAILED | edge:% | insertedVertex:% | farVertex:% | positionA:% | positionB:%\n" current_edge_id current_vertex_a current_vertex_b current_position_a current_position_b
                            insert_error = "Could not read the remaining child-edge endpoint positions."
                            insert_ok = false
                        )
                    )
                )
            )
        )

        #(insert_ok, inserted_vertex_ids, insert_error)
        -- return
    ),

    /*
    Repairs missing Broken-T targets by grouping sources that share one original target edge.
    Every group performs exactly N committed DivideEdge splits, sorts sources and inserted vertices from the same edge endpoint, moves pairs one by one, then welds descending inserted IDs.
    Returns #(success, insertedCount, fixedCount, committedTopology, errorText).
    */
    function repairMissingBrokenTTargets node edit_poly_mod topology_data case_records position_tolerance =
    (
        if node == undefined or not isValidNode node then return #(false, 0, 0, undefined, "Invalid target node.")
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #(false, 0, 0, undefined, "Invalid Edit Poly target.")
        if topology_data == undefined then return #(false, 0, 0, undefined, "Missing pre-repair topology.")
        if case_records == undefined then return #(false, 0, 0, undefined, "Missing Broken-T case records.")
        if position_tolerance < 0.0 then return #(false, 0, 0, undefined, "Invalid Broken-T position tolerance.")

        plan_result = this.buildBrokenTInsertPlan topology_data case_records position_tolerance
        if not plan_result[1] then return #(false, 0, 0, undefined, plan_result[3])

        insert_plan = plan_result[2]
        if insert_plan.count == 0 then return #(true, 0, 0, topology_data, "")

        target_groups = #()

        for plan_record in insert_plan do
        (
            original_target_a = plan_record[3]
            original_target_b = plan_record[4]
            original_target_edge_id = plan_record[6]
            original_target_vertex_a = plan_record[7]
            original_target_vertex_b = plan_record[8]
            group_index = 0

            for target_group_index = 1 to target_groups.count while group_index == 0 do
            (
                target_group = target_groups[target_group_index]

                if target_group[1] == original_target_edge_id then
                (
                    group_index = target_group_index
                )
            )

            if group_index == 0 then
            (
                append target_groups #(original_target_edge_id, original_target_a, original_target_b, original_target_vertex_a, original_target_vertex_b, #(plan_record))
            )
            else
            (
                append (target_groups[group_index][6]) plan_record
            )
        )

        inserted_count = 0
        fixed_count = 0
        current_topology = topology_data
        repair_error = undefined

        select node
        max modify mode
        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off
        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Edge
        subObjectLevel = 2

        for target_group in target_groups while repair_error == undefined do
        (
            original_target_edge_id = target_group[1]
            original_target_a = target_group[2]
            original_target_b = target_group[3]
            original_target_vertex_a = target_group[4]
            original_target_vertex_b = target_group[5]
            group_plans = target_group[6]
            target_edge_id = this.findEditPolyEdgeByVertexPair edit_poly_mod node original_target_vertex_a original_target_vertex_b

            if target_edge_id == 0 then
            (
                format "Loop-Cleaner BROKEN T REPAIR EDGE RESOLVE FAILED | originalEdge:% | vertexA:% | vertexB:% | endpointA:% | endpointB:%\n" original_target_edge_id original_target_vertex_a original_target_vertex_b original_target_a original_target_b
                repair_error = "Could not resolve the planned Broken-T target edge from its preserved endpoint vertex IDs."
            )
            else
            (
                vertices_to_add = group_plans.count
                ordered_sources = #()

                for group_plan in group_plans while repair_error == undefined do
                (
                    source_projection = this.getPointSegmentProjectionData group_plan[1] original_target_a original_target_b
                    append ordered_sources #(source_projection[2], group_plan)
                )

                if ordered_sources.count > 1 then
                (
                    for sort_index = 2 to ordered_sources.count do
                    (
                        sorted_item = ordered_sources[sort_index]
                        compare_index = sort_index - 1

                        while compare_index >= 1 and ordered_sources[compare_index][1] > sorted_item[1] do
                        (
                            ordered_sources[compare_index + 1] = ordered_sources[compare_index]
                            compare_index -= 1
                        )

                        ordered_sources[compare_index + 1] = sorted_item
                    )
                )

                before_vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
                before_edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node
                before_face_count = EditPolyMod.GetNumFaces edit_poly_mod node:node
                insert_exception = undefined
                insert_result = undefined

                try
                (
                    insert_result = this.addMultipleVerticesToEdge edit_poly_mod node original_target_a original_target_b vertices_to_add position_tolerance initial_edge_id:target_edge_id initial_vertex_a:original_target_vertex_a initial_vertex_b:original_target_vertex_b
                )
                catch
                (
                    insert_exception = getCurrentException() as string
                )

                if insert_exception != undefined then
                (
                    repair_error = insert_exception
                )
                else if insert_result == undefined or not insert_result[1] then
                (
                    repair_error = if insert_result == undefined then "addMultipleVerticesToEdge returned no result." else insert_result[3]
                )
                else
                (
                    inserted_vertex_ids = insert_result[2]
                    after_vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
                    after_edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node
                    after_face_count = EditPolyMod.GetNumFaces edit_poly_mod node:node

                    if after_vertex_count != (before_vertex_count + vertices_to_add) then
                    (
                        repair_error = ("Multi-insert added an unexpected vertex count. Before:" + (before_vertex_count as string) + " After:" + (after_vertex_count as string) + " ExpectedAdd:" + (vertices_to_add as string))
                    )
                    else if after_edge_count != (before_edge_count + vertices_to_add) then
                    (
                        repair_error = ("Multi-insert added an unexpected edge count. Before:" + (before_edge_count as string) + " After:" + (after_edge_count as string) + " ExpectedAdd:" + (vertices_to_add as string))
                    )
                    else if after_face_count != before_face_count then
                    (
                        repair_error = ("Multi-insert changed the face count unexpectedly. Before:" + (before_face_count as string) + " After:" + (after_face_count as string))
                    )
                    else
                    (
                        inserted_count += vertices_to_add
                        edit_poly_mod.RefreshScreen()
                        completeRedraw()
                        update node

                        /*
                        Post-DivideEdge GetVertex reads must run in Vertex context.
                        Runtime proved Edge-level reads can return [0,0,0] for live appended/source IDs,
                        which produces a false move delta even though Select #Vertex addresses the correct live vertex.
                        */
                        edit_poly_mod.SetEPolySelLevel #Vertex
                        subObjectLevel = 1

                        inserted_vertex_records = #()

                        format "Loop-Cleaner BROKEN T POST INSERT VERTEX CONTEXT | node:% | epolyLevel:% | vertexSelection:% | insertedVertices:%\n" node.name (edit_poly_mod.GetEPolySelLevel()) (edit_poly_mod.GetSelection #Vertex node:node) inserted_vertex_ids

                        for inserted_vertex_id in inserted_vertex_ids do
                        (
                            inserted_position = edit_poly_mod.GetVertex inserted_vertex_id node:node

                            if inserted_position == undefined then
                            (
                                repair_error = "Could not read one newly inserted Broken-T vertex."
                            )
                            else
                            (
                                inserted_projection = this.getPointSegmentProjectionData inserted_position original_target_a original_target_b
                                append inserted_vertex_records #(inserted_projection[2], inserted_vertex_id)
                            )
                        )

                        if repair_error == undefined and inserted_vertex_records.count != ordered_sources.count then
                        (
                            repair_error = "The appended Broken-T vertex count does not match the stored source count."
                        )

                        if repair_error == undefined and inserted_vertex_records.count > 1 then
                        (
                            for sort_index = 2 to inserted_vertex_records.count do
                            (
                                sorted_item = inserted_vertex_records[sort_index]
                                compare_index = sort_index - 1

                                while compare_index >= 1 and inserted_vertex_records[compare_index][1] > sorted_item[1] do
                                (
                                    inserted_vertex_records[compare_index + 1] = inserted_vertex_records[compare_index]
                                    compare_index -= 1
                                )

                                inserted_vertex_records[compare_index + 1] = sorted_item
                            )
                        )

                        move_records = #()
                        weld_pairs = #()

                        for source_order_index = 1 to ordered_sources.count while repair_error == undefined do
                        (
                            source_plan = ordered_sources[source_order_index][2]
                            source_vertex_id = source_plan[5]
                            inserted_vertex_id = inserted_vertex_records[source_order_index][2]

                            append move_records #(source_vertex_id, inserted_vertex_id)
                            append weld_pairs #(inserted_vertex_id, source_vertex_id)
                        )

                        if repair_error == undefined then
                        (
                            if not this.moveBrokenTVertexRecords node edit_poly_mod move_records position_tolerance then
                            (
                                repair_error = "Could not move one appended Broken-T vertex onto its paired source vertex."
                            )
                        )

                        if repair_error == undefined and weld_pairs.count > 1 then
                        (
                            for sort_index = 2 to weld_pairs.count do
                            (
                                sorted_item = weld_pairs[sort_index]
                                compare_index = sort_index - 1

                                while compare_index >= 1 and weld_pairs[compare_index][1] < sorted_item[1] do
                                (
                                    weld_pairs[compare_index + 1] = weld_pairs[compare_index]
                                    compare_index -= 1
                                )

                                weld_pairs[compare_index + 1] = sorted_item
                            )
                        )

                        for weld_pair in weld_pairs while repair_error == undefined do
                        (
                            inserted_vertex_id = weld_pair[1]
                            source_vertex_id = weld_pair[2]

                            if not this.weldBrokenTVertexIntoTarget node edit_poly_mod source_vertex_id inserted_vertex_id then
                            (
                                repair_error = "WeldVertices did not remove exactly one inserted Broken-T vertex."
                            )
                            else
                            (
                                fixed_count += 1
                            )
                        )

                        if repair_error == undefined then
                        (
                            current_topology = this.buildEditPolyBorderTopology node edit_poly_mod

                            if current_topology == undefined then
                            (
                                repair_error = "Could not rebuild topology after welding the inserted Broken-T vertices."
                            )
                        )
                    )
                )
            )
        )

        if repair_error != undefined then return #(false, inserted_count, fixed_count, undefined, repair_error)

        #(true, inserted_count, fixed_count, current_topology, "")
        -- return
    ),

    /*
    Clears the transient Broken-T divide-to-move handoff stored between the two stage buttons.
    The handoff contains only live node/modifier references and source/inserted vertex ID pairs.
    */
    function clearPendingBrokenTMoveState =
    (
        this.pending_broken_t_node = undefined
        this.pending_broken_t_edit_poly_mod = undefined
        this.pending_broken_t_move_records = #()

        true
        -- return
    ),

    /*
    Synchronizes the required Broken-T Edge/Vertex context by changing only state that is actually different.
    When the same node, Edit Poly, and sub-object level are already active, this function performs no Command Panel writes.
    */
    function syncBrokenTEditPolyLevel node edit_poly_mod target_level apply_common_state:true =
    (
        if node == undefined or not isValidNode node then
        (
            format "Loop-Cleaner BROKEN T CONTEXT SYNC FAILED | stage:node | value:%\n" node
            return false
        )

        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then
        (
            format "Loop-Cleaner BROKEN T CONTEXT SYNC FAILED | node:% | stage:Edit Poly | value:%\n" node.name edit_poly_mod
            return false
        )

        if modPanel.getCurrentObject() != edit_poly_mod then
        (
            format "Loop-Cleaner BROKEN T CONTEXT SYNC FAILED | node:% | stage:current modifier | expected:% | actual:%\n" \
                node.name edit_poly_mod (modPanel.getCurrentObject())
            return false
        )

        local target_subobject_level = 0

        if target_level == #Vertex then
        (
            target_subobject_level = 1
        )
        else if target_level == #Edge then
        (
            target_subobject_level = 2
        )
        else
        (
            format "Loop-Cleaner BROKEN T CONTEXT SYNC FAILED | node:% | stage:target level | value:% | required:#Vertex or #Edge\n" node.name target_level
            return false
        )

        if apply_common_state then
        (
            if edit_poly_mod.useStackSelection != false then edit_poly_mod.useStackSelection = false
            if edit_poly_mod.selectMode != 0 then edit_poly_mod.selectMode = 0
            if edit_poly_mod.showCage != off then edit_poly_mod.showCage = off
        )

        if edit_poly_mod.GetEPolySelLevel() != target_level then
        (
            edit_poly_mod.SetEPolySelLevel target_level
        )

        if subObjectLevel != target_subobject_level then
        (
            subObjectLevel = target_subobject_level
        )

        true
        -- return
    ),

    /*
    Forces a fresh binding of the exact working Broken-T Edit Poly when a post-Commit live-topology probe proves the current binding is stale.
    This is the recovery path for the historical zero-count Edit Poly state; normal same-state batches avoid it.
    */
    function rebindBrokenTEditPolyContext node edit_poly_mod target_level =
    (
        if node == undefined or not isValidNode node then
        (
            format "Loop-Cleaner BROKEN T REBIND FAILED | stage:node | value:%\n" node
            return false
        )

        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then
        (
            format "Loop-Cleaner BROKEN T REBIND FAILED | node:% | stage:Edit Poly | value:%\n" node.name edit_poly_mod
            return false
        )

        local modifier_is_live = false

        for stack_mod in node.modifiers while not modifier_is_live do
        (
            if stack_mod == edit_poly_mod then modifier_is_live = true
        )

        if not modifier_is_live then
        (
            format "Loop-Cleaner BROKEN T REBIND FAILED | node:% | stage:modifier stack | editPoly:%\n" node.name edit_poly_mod
            return false
        )

        select node
        max modify mode

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off
        modPanel.setCurrentObject edit_poly_mod node:node

        this.syncBrokenTEditPolyLevel node edit_poly_mod target_level apply_common_state:false
        -- return
    ),

    /*
    Activates the exact working Broken-T Edit Poly only when the requested node/modifier is not already current.
    When it is already current, only genuinely different modifier/sub-object state is changed.
    */
    function prepareBrokenTEditPolyContext node edit_poly_mod target_level =
    (
        if node == undefined or not isValidNode node then
        (
            format "Loop-Cleaner BROKEN T CONTEXT FAILED | stage:node | value:%\n" node
            return false
        )

        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then
        (
            format "Loop-Cleaner BROKEN T CONTEXT FAILED | node:% | stage:Edit Poly | value:%\n" node.name edit_poly_mod
            return false
        )

        local modifier_is_live = false

        for stack_mod in node.modifiers while not modifier_is_live do
        (
            if stack_mod == edit_poly_mod then modifier_is_live = true
        )

        if not modifier_is_live then
        (
            format "Loop-Cleaner BROKEN T CONTEXT FAILED | node:% | stage:modifier stack | editPoly:%\n" node.name edit_poly_mod
            return false
        )

        local same_selected_node = selection.count == 1 and selection[1] == node
        local same_current_modifier = modPanel.getCurrentObject() == edit_poly_mod

        if not same_selected_node or not same_current_modifier then
        (
            if not same_selected_node then select node
            max modify mode

            edit_poly_mod.SetPrimaryNode node
            if edit_poly_mod.useStackSelection != false then edit_poly_mod.useStackSelection = false
            if edit_poly_mod.selectMode != 0 then edit_poly_mod.selectMode = 0
            if edit_poly_mod.showCage != off then edit_poly_mod.showCage = off

            if modPanel.getCurrentObject() != edit_poly_mod then
            (
                modPanel.setCurrentObject edit_poly_mod node:node
            )
        )

        this.syncBrokenTEditPolyLevel node edit_poly_mod target_level
        -- return
    ),

    /*
    Keeps the current Broken-T Vertex context when committed topology is already readable.
    A full same-modifier rebind is used only as a fallback when the live count proves the current binding is stale.
    Returns #(success, liveVertexCount, usedFallbackRebind).
    */
    function ensureBrokenTLiveVertexContext node edit_poly_mod minimum_vertex_id:1 expected_vertex_count:undefined =
    (
        if minimum_vertex_id < 1 then minimum_vertex_id = 1

        if not(this.prepareBrokenTEditPolyContext node edit_poly_mod #Vertex) then
        (
            return #(false, 0, false)
        )

        local live_vertex_count = edit_poly_mod.GetNumVertices node:node
        local live_count_ok = classOf live_vertex_count == Integer and live_vertex_count >= minimum_vertex_id

        if expected_vertex_count != undefined then
        (
            live_count_ok = live_count_ok and live_vertex_count == expected_vertex_count
        )

        if live_count_ok then
        (
            return #(true, live_vertex_count, false)
        )

        edit_poly_mod.RefreshScreen()
        update node

        live_vertex_count = edit_poly_mod.GetNumVertices node:node
        live_count_ok = classOf live_vertex_count == Integer and live_vertex_count >= minimum_vertex_id

        if expected_vertex_count != undefined then
        (
            live_count_ok = live_count_ok and live_vertex_count == expected_vertex_count
        )

        if live_count_ok then
        (
            return #(true, live_vertex_count, false)
        )

        if not(this.rebindBrokenTEditPolyContext node edit_poly_mod #Vertex) then
        (
            return #(false, live_vertex_count, true)
        )

        live_vertex_count = edit_poly_mod.GetNumVertices node:node
        live_count_ok = classOf live_vertex_count == Integer and live_vertex_count >= minimum_vertex_id

        if expected_vertex_count != undefined then
        (
            live_count_ok = live_count_ok and live_vertex_count == expected_vertex_count
        )

        if not live_count_ok then
        (
            format "Loop-Cleaner BROKEN T LIVE CONTEXT FAILED | node:% | minimumVertexID:% | expectedVertexCount:% | actualVertexCount:%\n" \
                node.name minimum_vertex_id expected_vertex_count live_vertex_count
            return #(false, live_vertex_count, true)
        )

        #(true, live_vertex_count, true)
        -- return
    ),

    /*
    Runs only the missing-target DivideEdge stage and returns source/inserted pairs for a later move pass.
    Preclassified inner-border sets may be reused only before the first split of this unchanged topology snapshot.
    No vertex is moved or welded here; each target-edge group performs exactly N committed splits and preserves pair order from one original edge direction.
    */
    function prepareBrokenTDivideStage node edit_poly_mod topology_data case_records position_tolerance inner_border_edges:undefined inner_border_vertices:undefined =
    (
        if node == undefined or not isValidNode node then return #(false, 0, #(), "Invalid target node.")
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return #(false, 0, #(), "Invalid Edit Poly target.")
        if topology_data == undefined then return #(false, 0, #(), "Missing pre-divide topology.")
        if case_records == undefined then return #(false, 0, #(), "Missing Broken-T case records.")
        if position_tolerance == undefined or position_tolerance <= 0.0 then return #(false, 0, #(), "Invalid Broken-T position precision.")

        plan_result = this.buildBrokenTInsertPlan \
            topology_data \
            case_records \
            position_tolerance \
            inner_border_edges:inner_border_edges \
            inner_border_vertices:inner_border_vertices
        if not plan_result[1] then return #(false, 0, #(), plan_result[3])

        insert_plan = plan_result[2]
        if insert_plan.count == 0 then return #(true, 0, #(), "")

        target_groups = #()

        for plan_record in insert_plan do
        (
            original_target_a = plan_record[3]
            original_target_b = plan_record[4]
            original_target_edge_id = plan_record[6]
            original_target_vertex_a = plan_record[7]
            original_target_vertex_b = plan_record[8]
            group_index = 0

            for target_group_index = 1 to target_groups.count while group_index == 0 do
            (
                target_group = target_groups[target_group_index]

                if target_group[1] == original_target_edge_id then
                (
                    group_index = target_group_index
                )
            )

            if group_index == 0 then
            (
                append target_groups #(original_target_edge_id, original_target_a, original_target_b, original_target_vertex_a, original_target_vertex_b, #(plan_record))
            )
            else
            (
                append (target_groups[group_index][6]) plan_record
            )
        )

        inserted_count = 0
        move_records = #()
        completed_group_records = #()
        divide_error = undefined

        if not(this.syncBrokenTEditPolyLevel node edit_poly_mod #Edge) then
        (
            return #(false, 0, #(), "Could not synchronize the Broken-T Edit Poly Edge context.")
        )

        for target_group in target_groups while divide_error == undefined do
        (
            original_target_edge_id = target_group[1]
            original_target_a = target_group[2]
            original_target_b = target_group[3]
            original_target_vertex_a = target_group[4]
            original_target_vertex_b = target_group[5]
            group_plans = target_group[6]
            ordered_sources = #()

            target_edge_id = original_target_edge_id
            current_edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node

            if target_edge_id < 1 or target_edge_id > current_edge_count then
            (
                format "Loop-Cleaner BROKEN T STORED EDGE ID FAILED | edge:% | liveEdgeCount:% | vertexA:% | vertexB:%\n" target_edge_id current_edge_count original_target_vertex_a original_target_vertex_b
                divide_error = "The stored Broken-T target edge ID is no longer valid."
            )
            else
            (
                for group_plan in group_plans do
                (
                    source_projection = this.getPointSegmentProjectionData group_plan[1] original_target_a original_target_b
                    append ordered_sources #(source_projection[2], group_plan)
                )

                if ordered_sources.count > 1 then
                (
                    for sort_index = 2 to ordered_sources.count do
                    (
                        sorted_item = ordered_sources[sort_index]
                        compare_index = sort_index - 1

                        while compare_index >= 1 and ordered_sources[compare_index][1] > sorted_item[1] do
                        (
                            ordered_sources[compare_index + 1] = ordered_sources[compare_index]
                            compare_index -= 1
                        )

                        ordered_sources[compare_index + 1] = sorted_item
                    )
                )

                vertices_to_add = ordered_sources.count
                before_vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
                before_edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node
                before_face_count = EditPolyMod.GetNumFaces edit_poly_mod node:node
                insert_result = undefined
                insert_exception = undefined

                try
                (
                    insert_result = this.addMultipleVerticesToEdge edit_poly_mod node original_target_a original_target_b vertices_to_add position_tolerance initial_edge_id:target_edge_id initial_vertex_a:original_target_vertex_a initial_vertex_b:original_target_vertex_b
                )
                catch
                (
                    insert_exception = getCurrentException() as string
                )

                if insert_exception != undefined then
                (
                    divide_error = insert_exception
                )
                else if insert_result == undefined or not insert_result[1] then
                (
                    divide_error = if insert_result == undefined then "addMultipleVerticesToEdge returned no result." else insert_result[3]
                )
                else
                (
                    inserted_vertex_ids = insert_result[2]
                    after_vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
                    after_edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node
                    after_face_count = EditPolyMod.GetNumFaces edit_poly_mod node:node

                    if after_vertex_count != (before_vertex_count + vertices_to_add) then
                    (
                        divide_error = "Multi-insert added an unexpected vertex count. Before:" + (before_vertex_count as string) + " After:" + (after_vertex_count as string) + " ExpectedAdd:" + (vertices_to_add as string)
                    )
                    else if after_edge_count != (before_edge_count + vertices_to_add) then
                    (
                        divide_error = "Multi-insert added an unexpected edge count. Before:" + (before_edge_count as string) + " After:" + (after_edge_count as string) + " ExpectedAdd:" + (vertices_to_add as string)
                    )
                    else if after_face_count != before_face_count then
                    (
                        divide_error = "Multi-insert changed the face count unexpectedly. Before:" + (before_face_count as string) + " After:" + (after_face_count as string)
                    )
                    else
                    (
                        inserted_count += vertices_to_add
                        append completed_group_records #(original_target_a, original_target_b, ordered_sources, inserted_vertex_ids)
                    )
                )
            )
        )

        if completed_group_records.count > 0 then
        (
            edit_poly_mod.RefreshScreen()
            update node

            if not(this.syncBrokenTEditPolyLevel node edit_poly_mod #Vertex apply_common_state:false) then
            (
                if divide_error == undefined then
                (
                    divide_error = "Could not synchronize the Broken-T Edit Poly Vertex context after the Divide stage."
                )
                else
                (
                    divide_error = divide_error + " | Could not synchronize the Broken-T Edit Poly Vertex context for the completed-group handoff."
                )
            )
            else
            (
                local pair_error = undefined

                for completed_group_record in completed_group_records while pair_error == undefined do
                (
                    original_target_a = completed_group_record[1]
                    original_target_b = completed_group_record[2]
                    ordered_sources = completed_group_record[3]
                    inserted_vertex_ids = completed_group_record[4]
                    inserted_vertex_records = #()

                    for inserted_vertex_id in inserted_vertex_ids while pair_error == undefined do
                    (
                        inserted_position = edit_poly_mod.GetVertex inserted_vertex_id node:node

                        if inserted_position == undefined then
                        (
                            pair_error = "Could not read one newly inserted Broken-T vertex."
                        )
                        else
                        (
                            inserted_projection = this.getPointSegmentProjectionData inserted_position original_target_a original_target_b
                            append inserted_vertex_records #(inserted_projection[2], inserted_vertex_id)
                        )
                    )

                    if pair_error == undefined and inserted_vertex_records.count != ordered_sources.count then
                    (
                        pair_error = "The appended Broken-T vertex count does not match the stored source count."
                    )

                    if pair_error == undefined and inserted_vertex_records.count > 1 then
                    (
                        for sort_index = 2 to inserted_vertex_records.count do
                        (
                            sorted_item = inserted_vertex_records[sort_index]
                            compare_index = sort_index - 1

                            while compare_index >= 1 and inserted_vertex_records[compare_index][1] > sorted_item[1] do
                            (
                                inserted_vertex_records[compare_index + 1] = inserted_vertex_records[compare_index]
                                compare_index -= 1
                            )

                            inserted_vertex_records[compare_index + 1] = sorted_item
                        )
                    )

                    if pair_error == undefined then
                    (
                        for source_order_index = 1 to ordered_sources.count do
                        (
                            source_plan = ordered_sources[source_order_index][2]
                            source_vertex_id = source_plan[5]
                            inserted_vertex_id = inserted_vertex_records[source_order_index][2]
                            append move_records #(source_vertex_id, inserted_vertex_id)
                        )
                    )
                )

                if pair_error != undefined then
                (
                    if divide_error == undefined then
                    (
                        divide_error = pair_error
                    )
                    else
                    (
                        divide_error = divide_error + " | Completed-group handoff failed: " + pair_error
                    )
                )
            )
        )

        if divide_error != undefined then
        (
            format "Loop-Cleaner BROKEN T DIVIDE FAILED | node:% | insertedVertices:% | pairs:% | error:%\n" node.name inserted_count move_records.count divide_error
            return #(false, inserted_count, move_records, divide_error)
        )

        #(true, inserted_count, move_records, "")
        -- return
    ),

    /*
    Runs only the Broken-T missing-target DivideEdge stage and stores ordered source/inserted pairs for MOVE VERTICES.
    The operation intentionally stops before any MoveSelection or weld call.
    */
    function divideBrokenTJunctionEdges show_dialogs:true reuse_current_modifier:false precomputed_topology_data:undefined precomputed_case_records:undefined precomputed_position_tolerance:undefined precomputed_inner_border_edges:undefined precomputed_inner_border_vertices:undefined =
    (
        this.clearPendingBrokenTMoveState()

        if selection.count != 1 then
        (
            if show_dialogs then messageBox "Select exactly one geometry object." title:"Loop-Cleaner"
            return false
        )

        node = selection[1]
        selection_mod = this.findBrokenTJunctionSelectionModifier node

        if selection_mod == undefined then
        (
            local selection_data = this.prepareBrokenTJunctionSelectionData show_dialogs:show_dialogs
            if not selection_data[1] then return false

            selection_mod = selection_data[3]

            if precomputed_topology_data == undefined and precomputed_case_records == undefined and precomputed_position_tolerance == undefined then
            (
                precomputed_topology_data = selection_data[4]
                precomputed_case_records = selection_data[5]
                precomputed_position_tolerance = selection_data[6]
                precomputed_inner_border_edges = selection_data[10]
                precomputed_inner_border_vertices = selection_data[11]
            )
        )

        if selection_mod == undefined then
        (
            if show_dialogs then messageBox "No SELECT BROKEN T JUNCTIONS modifier is available." title:"Loop-Cleaner"
            return false
        )

        local context_ok = if reuse_current_modifier then
        (
            this.syncBrokenTEditPolyLevel node selection_mod #Edge
        )
        else
        (
            this.prepareBrokenTEditPolyContext node selection_mod #Edge
        )

        if not context_ok then
        (
            if show_dialogs then messageBox "Could not activate SELECT BROKEN T JUNCTIONS." title:"Loop-Cleaner"
            return false
        )

        local use_precomputed_analysis = \
            classOf precomputed_topology_data == Array and \
            classOf precomputed_case_records == Array and \
            precomputed_position_tolerance != undefined and \
            precomputed_position_tolerance > 0.0

        position_tolerance = if use_precomputed_analysis then precomputed_position_tolerance else this.getBrokenTJunctionPositionPrecision()

        if position_tolerance == undefined or position_tolerance <= 0.0 then
        (
            format "Loop-Cleaner BROKEN T DIVIDE FAILED | node:% | positionPrecision:% | error:invalid position precision\n" node.name this.position_precision_text
            return false
        )

        topology_data = undefined
        case_records = undefined
        inner_border_edges = undefined
        inner_border_vertices = undefined

        if use_precomputed_analysis then
        (
            local live_vertex_count = selection_mod.GetNumVertices node:node
            local live_edge_count = selection_mod.GetNumEdges node:node
            local live_face_count = selection_mod.GetNumFaces node:node
            local expected_vertex_count = if precomputed_topology_data.count >= 3 then precomputed_topology_data[1] else 0
            local expected_edge_count = if precomputed_topology_data.count >= 3 then precomputed_topology_data[2] else 0
            local expected_face_count = if precomputed_topology_data.count >= 3 then precomputed_topology_data[3] else 0

            if live_vertex_count == expected_vertex_count and live_edge_count == expected_edge_count and live_face_count == expected_face_count then
            (
                topology_data = precomputed_topology_data
                case_records = precomputed_case_records

                if classOf precomputed_inner_border_edges == BitArray and classOf precomputed_inner_border_vertices == BitArray then
                (
                    inner_border_edges = precomputed_inner_border_edges
                    inner_border_vertices = precomputed_inner_border_vertices
                )

                format "Loop-Cleaner BROKEN T DIVIDE REUSE ANALYSIS | node:% | cases:% | verts:% | edges:% | faces:%\n" \
                    node.name case_records.count live_vertex_count live_edge_count live_face_count
            )
            else
            (
                format "Loop-Cleaner BROKEN T DIVIDE REUSE SKIPPED | node:% | expectedVerts:% | liveVerts:% | expectedEdges:% | liveEdges:% | expectedFaces:% | liveFaces:%\n" \
                    node.name expected_vertex_count live_vertex_count expected_edge_count live_edge_count expected_face_count live_face_count
            )
        )

        if topology_data == undefined then
        (
            topology_data = this.buildEditPolyBorderTopology node selection_mod

            if topology_data == undefined then
            (
                format "Loop-Cleaner BROKEN T DIVIDE FAILED | node:% | stage:read topology | error:undefined topology\n" node.name
                return false
            )

            classification = this.classifyBorderEdges topology_data

            if classification == undefined then
            (
                format "Loop-Cleaner BROKEN T DIVIDE FAILED | node:% | stage:classify inner borders | error:undefined classification\n" node.name
                return false
            )

            inner_border_edges = classification[3]
            inner_border_vertices = this.getTopologyVerticesFromEdges topology_data inner_border_edges

            if inner_border_vertices == undefined then
            (
                format "Loop-Cleaner BROKEN T DIVIDE FAILED | node:% | stage:collect inner-border vertices | error:undefined vertex set\n" node.name
                return false
            )

            case_records = this.findBrokenTJunctionCases topology_data position_tolerance inner_border_edges:inner_border_edges

            if case_records == undefined then
            (
                format "Loop-Cleaner BROKEN T DIVIDE FAILED | node:% | stage:find cases | error:undefined case list\n" node.name
                return false
            )
        )

        if case_records.count == 0 then
        (
            format "Loop-Cleaner BROKEN T DIVIDE | node:% | cases:0 | insertedVertices:0 | pairs:0\n" node.name
            return true
        )

        divide_result = undefined

        undo "Broken T Divide Edge" on
        (
            divide_result = this.prepareBrokenTDivideStage \
                node \
                selection_mod \
                topology_data \
                case_records \
                position_tolerance \
                inner_border_edges:inner_border_edges \
                inner_border_vertices:inner_border_vertices
        )

        if divide_result == undefined or not divide_result[1] then
        (
            divide_error = if divide_result == undefined then "prepareBrokenTDivideStage returned no result." else divide_result[4]
            inserted_count = if divide_result == undefined then 0 else divide_result[2]
            pair_count = if divide_result == undefined then 0 else divide_result[3].count

            if divide_result != undefined and divide_result[3] != undefined and divide_result[3].count > 0 then
            (
                this.pending_broken_t_node = node
                this.pending_broken_t_edit_poly_mod = selection_mod
                this.pending_broken_t_move_records = divide_result[3]
                format "Loop-Cleaner BROKEN T PARTIAL MOVE PAIRS STORED | node:% | pairs:%\n" node.name this.pending_broken_t_move_records.count
            )

            format "Loop-Cleaner BROKEN T DIVIDE FAILED | node:% | insertedVertices:% | pairs:% | error:%\n" node.name inserted_count pair_count divide_error

            if show_dialogs then
            (
                if pair_count > 0 then
                (
                    messageBox ("Broken-T Divide Edge stopped after partial success.\n\n" + divide_error + "\n\nThe successful source/inserted pairs were kept. You can run MOVE VERTICES now.") title:"Loop-Cleaner"
                )
                else
                (
                    messageBox ("Broken-T Divide Edge stopped.\n\n" + divide_error + "\n\nNo move pairs were created.") title:"Loop-Cleaner"
                )
            )

            return false
        )

        this.pending_broken_t_node = node
        this.pending_broken_t_edit_poly_mod = selection_mod
        this.pending_broken_t_move_records = divide_result[3]

        selection_mod.showCage = off
        selection_mod.RefreshScreen()
        completeRedraw()

        format "Loop-Cleaner BROKEN T DIVIDE COMPLETE | node:% | positionPrecision:% | cases:% | insertedVertices:% | movePairs:%\n" node.name this.position_precision_text case_records.count divide_result[2] divide_result[3].count

        true
        -- return
    ),

    /*
    Creates one Plane, adds one Edit Poly modifier, selects vertex 1, and moves vertex 1 onto vertex 2.
    Leaves the test Plane selected with the Edit Poly active so the moved vertex is immediately visible.
    Returns true only when vertex 1 reaches vertex 2 at the supplied position precision.
    */
    function testEditPolyVertexMove position_precision =
    (
        if position_precision == undefined or position_precision <= 0.0 then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:position precision | value:%\n" position_precision
            return false
        )

        local plane_size = units.decodeValue "1000mm"

        if plane_size == undefined or plane_size <= 0.0 then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:plane size | value:%\n" plane_size
            return false
        )

        local test_node = plane \
            name:"LoopCleaner_Move_Test" \
            length:plane_size \
            width:plane_size \
            lengthsegs:1 \
            widthsegs:1

        if test_node == undefined or not isValidNode test_node then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:create plane | node:%\n" test_node
            return false
        )

        local test_edit_poly_mod = Edit_Poly name:"MOVE TEST"
        test_edit_poly_mod.showCage = off
        addModifier test_node test_edit_poly_mod

        select test_node
        max modify mode

        test_edit_poly_mod.SetPrimaryNode test_node
        test_edit_poly_mod.useStackSelection = false
        test_edit_poly_mod.selectMode = 0
        test_edit_poly_mod.showCage = off
        modPanel.setCurrentObject test_edit_poly_mod node:test_node
        test_edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        local vertex_count = test_edit_poly_mod.GetNumVertices node:test_node

        if vertex_count < 2 then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:vertex count | node:% | actual:% | required:>=2\n" test_node.name vertex_count
            return false
        )

        local original_selection = test_edit_poly_mod.GetSelection #Vertex node:test_node

        if original_selection == undefined then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:selection read | node:%\n" test_node.name
            return false
        )

        if original_selection.numberSet > 0 then
        (
            test_edit_poly_mod.Select #Vertex original_selection select:false node:test_node
        )

        local vertex_bits = #{1}
        test_edit_poly_mod.Select #Vertex vertex_bits node:test_node

        local stored_selection = test_edit_poly_mod.GetSelection #Vertex node:test_node

        if stored_selection == undefined or stored_selection != vertex_bits then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:selection verify | node:% | expected:% | actual:%\n" test_node.name vertex_bits stored_selection
            return false
        )

        local before_position = test_edit_poly_mod.GetVertex 1 node:test_node
        local target_position = test_edit_poly_mod.GetVertex 2 node:test_node

        if before_position == undefined or target_position == undefined then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:position read | node:% | vertex1:% | vertex2:%\n" \
                test_node.name before_position target_position
            return false
        )

        local move_delta = target_position - before_position

        format "Loop-Cleaner EDIT POLY MOVE TEST | node:% | sourceVertex:1 | targetVertex:2 | before:% | target:% | delta:%\n" \
            test_node.name before_position target_position move_delta

        test_edit_poly_mod.MoveSelection move_delta
        test_edit_poly_mod.Commit()
        test_edit_poly_mod.RefreshScreen()
        completeRedraw()

        local after_position = test_edit_poly_mod.GetVertex 1 node:test_node
        local target_after_position = test_edit_poly_mod.GetVertex 2 node:test_node

        if after_position == undefined or target_after_position == undefined then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:after position | node:% | vertex1:% | vertex2:%\n" \
                test_node.name after_position target_after_position
            return false
        )

        local rounded_expected = this.roundPositionToPrecision target_position position_precision
        local rounded_actual = this.roundPositionToPrecision after_position position_precision
        local rounded_target_after = this.roundPositionToPrecision target_after_position position_precision

        if rounded_expected == undefined or rounded_actual == undefined or rounded_target_after == undefined then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:position rounding | node:% | expectedRaw:% | actualRaw:% | targetAfterRaw:% | positionPrecision:%\n" \
                test_node.name target_position after_position target_after_position position_precision
            return false
        )

        if rounded_actual != rounded_expected then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:move verify | node:% | sourceVertex:1 | targetVertex:2 | before:% | expectedRaw:% | actualRaw:% | expectedRounded:% | actualRounded:% | actualDelta:% | positionPrecision:%\n" \
                test_node.name before_position target_position after_position rounded_expected rounded_actual (after_position - before_position) position_precision
            return false
        )

        if rounded_target_after != rounded_expected then
        (
            format "Loop-Cleaner EDIT POLY MOVE TEST FAILED | stage:target changed | node:% | targetVertex:2 | before:% | after:% | beforeRounded:% | afterRounded:% | positionPrecision:%\n" \
                test_node.name target_position target_after_position rounded_expected rounded_target_after position_precision
            return false
        )

        format "Loop-Cleaner EDIT POLY MOVE TEST COMPLETE | node:% | sourceVertex:1 | targetVertex:2 | before:% | target:% | after:% | delta:%\n" \
            test_node.name before_position target_position after_position (after_position - before_position)

        true
        -- return
    ),

    /*
    Moves one currently selected vertex on the first selected object's active Edit Poly by exactly 1000 mm on Z.
    The moving vertex is the first ID in the modifier's current Vertex selection; no unselected vertex is chosen.
    Leaves only the moved vertex selected so the result is immediately visible.
    */
    function testMoveOneSelectedEditPolyVertex position_precision =
    (
        if position_precision == undefined or position_precision <= 0.0 then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:position precision | value:%\n" position_precision
            return false
        )

        if selection.count < 1 or not isValidNode selection[1] then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:node | selectionCount:%\n" selection.count
            messageBox "Select at least one object." title:"Loop-Cleaner"
            return false
        )

        local node = selection[1]
        local target_data = this.getCurrentPolyTarget node

        if target_data[1] != #edit_poly or target_data[2] == undefined or classOf target_data[2] != Edit_Poly then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:active edit poly | node:% | targetKind:% | target:%\n"                 node.name target_data[1] target_data[2]
            messageBox "Make the Edit Poly containing the selected vertices current in the Modify panel." title:"Loop-Cleaner"
            return false
        )

        local edit_poly_mod = target_data[2]

        if edit_poly_mod.currentOperation != 0 then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:current operation | node:% | editPoly:% | currentOperation:%\n"                 node.name edit_poly_mod edit_poly_mod.currentOperation
            return false
        )

        local selected_vertices = edit_poly_mod.GetSelection #Vertex node:node

        if selected_vertices == undefined then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:selection read | node:% | editPoly:%\n" node.name edit_poly_mod
            return false
        )

        if selected_vertices.numberSet < 1 then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:no selected vertices | node:% | selection:%\n" node.name selected_vertices
            messageBox "Select at least one vertex in the current Edit Poly." title:"Loop-Cleaner"
            return false
        )

        local moving_vertex_id = 0

        for vertex_id in selected_vertices while moving_vertex_id == 0 do
        (
            moving_vertex_id = vertex_id
        )

        local vertex_count = edit_poly_mod.GetNumVertices node:node

        if moving_vertex_id < 1 or moving_vertex_id > vertex_count then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:selected vertex range | node:% | vertex:% | liveVertexCount:% | selection:%\n"                 node.name moving_vertex_id vertex_count selected_vertices
            return false
        )

        local before_position = edit_poly_mod.GetVertex moving_vertex_id node:node

        if before_position == undefined then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:position read | node:% | vertex:%\n" node.name moving_vertex_id
            return false
        )

        local move_distance = units.decodeValue "1000mm"

        if move_distance == undefined or move_distance <= 0.0 then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:move distance | value:%\n" move_distance
            return false
        )

        local move_delta = [0.0, 0.0, move_distance]
        local expected_position = before_position + move_delta
        local moving_bits = #{}
        moving_bits[moving_vertex_id] = true

        select node
        max modify mode

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off
        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        if selected_vertices.numberSet > 0 then
        (
            edit_poly_mod.Select #Vertex selected_vertices select:false node:node
        )

        edit_poly_mod.Select #Vertex moving_bits node:node

        local isolated_selection = edit_poly_mod.GetSelection #Vertex node:node

        if isolated_selection == undefined or isolated_selection != moving_bits then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:selection isolate | node:% | vertex:% | expected:% | actual:%\n"                 node.name moving_vertex_id moving_bits isolated_selection
            return false
        )

        format "Loop-Cleaner SELECTED VERTEX MOVE TEST | node:% | vertex:% | before:% | delta:% | expected:%\n"             node.name moving_vertex_id before_position move_delta expected_position

        edit_poly_mod.MoveSelection move_delta
        edit_poly_mod.Commit()
        edit_poly_mod.RefreshScreen()
        completeRedraw()

        local after_position = edit_poly_mod.GetVertex moving_vertex_id node:node

        if after_position == undefined then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:after position | node:% | vertex:%\n" node.name moving_vertex_id
            return false
        )

        local rounded_expected = this.roundPositionToPrecision expected_position position_precision
        local rounded_actual = this.roundPositionToPrecision after_position position_precision

        if rounded_expected == undefined or rounded_actual == undefined then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:position rounding | node:% | vertex:% | expectedRaw:% | actualRaw:% | positionPrecision:%\n"                 node.name moving_vertex_id expected_position after_position position_precision
            return false
        )

        if rounded_actual != rounded_expected then
        (
            format "Loop-Cleaner SELECTED VERTEX MOVE TEST FAILED | stage:move verify | node:% | vertex:% | before:% | expectedRaw:% | actualRaw:% | expectedRounded:% | actualRounded:% | actualDelta:% | positionPrecision:%\n"                 node.name moving_vertex_id before_position expected_position after_position rounded_expected rounded_actual (after_position - before_position) position_precision
            return false
        )

        format "Loop-Cleaner SELECTED VERTEX MOVE TEST COMPLETE | node:% | vertex:% | before:% | after:% | delta:%\n"             node.name moving_vertex_id before_position after_position (after_position - before_position)

        true
        -- return
    ),

    /*
    Welds exactly two vertices selected in the current Edit Poly.
    The lower vertex ID is the preserved target and the higher vertex ID is the disposable source.
    Success requires one committed WeldVertices call to reduce the live vertex count by exactly one.
    */
    function testWeldSelectedEditPolyVertices =
    (
        if selection.count < 1 or not isValidNode selection[1] then
        (
            format "Loop-Cleaner SELECTED VERTEX WELD TEST FAILED | stage:node | selectionCount:%\n" selection.count
            messageBox "Select at least one object." title:"Loop-Cleaner"
            return false
        )

        local node = selection[1]
        local target_data = this.getCurrentPolyTarget node

        if target_data[1] != #edit_poly or target_data[2] == undefined or classOf target_data[2] != Edit_Poly then
        (
            format "Loop-Cleaner SELECTED VERTEX WELD TEST FAILED | stage:active edit poly | node:% | targetKind:% | target:%\n" \
                node.name target_data[1] target_data[2]
            messageBox "Make the Edit Poly containing the selected vertices current in the Modify panel." title:"Loop-Cleaner"
            return false
        )

        local edit_poly_mod = target_data[2]

        if edit_poly_mod.currentOperation != 0 then
        (
            format "Loop-Cleaner SELECTED VERTEX WELD TEST FAILED | stage:current operation | node:% | editPoly:% | currentOperation:%\n" \
                node.name edit_poly_mod edit_poly_mod.currentOperation
            return false
        )

        select node
        max modify mode

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off
        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        local selected_vertices = edit_poly_mod.GetSelection #Vertex node:node

        if selected_vertices == undefined then
        (
            format "Loop-Cleaner SELECTED VERTEX WELD TEST FAILED | stage:selection read | node:% | editPoly:%\n" node.name edit_poly_mod
            return false
        )

        if selected_vertices.numberSet != 2 then
        (
            format "Loop-Cleaner SELECTED VERTEX WELD TEST FAILED | stage:selected vertex count | node:% | actual:% | required:2 | selection:%\n" \
                node.name selected_vertices.numberSet selected_vertices
            messageBox "Select exactly two vertices in the current Edit Poly." title:"Loop-Cleaner"
            return false
        )

        local selected_ids = #()

        for vertex_id in selected_vertices do
        (
            append selected_ids vertex_id
        )

        local target_vertex_id = selected_ids[1]
        local source_vertex_id = selected_ids[2]

        if target_vertex_id > source_vertex_id then
        (
            local swap_id = target_vertex_id
            target_vertex_id = source_vertex_id
            source_vertex_id = swap_id
        )

        local before_vertex_count = edit_poly_mod.GetNumVertices node:node

        if before_vertex_count < 2 then
        (
            format "Loop-Cleaner SELECTED VERTEX WELD TEST FAILED | stage:vertex count | node:% | actual:% | required:>=2\n" \
                node.name before_vertex_count
            return false
        )

        if target_vertex_id < 1 or target_vertex_id > before_vertex_count or source_vertex_id < 1 or source_vertex_id > before_vertex_count then
        (
            format "Loop-Cleaner SELECTED VERTEX WELD TEST FAILED | stage:selected vertex range | node:% | targetVertex:% | sourceVertex:% | liveVertexCount:% | selection:%\n" \
                node.name target_vertex_id source_vertex_id before_vertex_count selected_vertices
            return false
        )

        local target_position = edit_poly_mod.GetVertex target_vertex_id node:node
        local source_position = edit_poly_mod.GetVertex source_vertex_id node:node

        if target_position == undefined or source_position == undefined then
        (
            format "Loop-Cleaner SELECTED VERTEX WELD TEST FAILED | stage:position read | node:% | targetVertex:% | sourceVertex:% | targetPosition:% | sourcePosition:%\n" \
                node.name target_vertex_id source_vertex_id target_position source_position
            return false
        )

        format "Loop-Cleaner SELECTED VERTEX WELD TEST | node:% | targetVertex:% | sourceVertex:% | targetPosition:% | sourcePosition:% | vertsBefore:%\n" \
            node.name target_vertex_id source_vertex_id target_position source_position before_vertex_count

        EditPolyMod.WeldVertices edit_poly_mod target_vertex_id source_vertex_id node:node
        EditPolyMod.Commit edit_poly_mod
        edit_poly_mod.showCage = off
        edit_poly_mod.RefreshScreen()
        completeRedraw()

        select node
        max modify mode
        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off
        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        local after_vertex_count = edit_poly_mod.GetNumVertices node:node
        local expected_vertex_count = before_vertex_count - 1

        if after_vertex_count != expected_vertex_count then
        (
            format "Loop-Cleaner SELECTED VERTEX WELD TEST FAILED | stage:weld verify | node:% | targetVertex:% | sourceVertex:% | targetPosition:% | sourcePosition:% | vertsBefore:% | expectedAfter:% | actualAfter:%\n" \
                node.name target_vertex_id source_vertex_id target_position source_position before_vertex_count expected_vertex_count after_vertex_count
            return false
        )

        format "Loop-Cleaner SELECTED VERTEX WELD TEST COMPLETE | node:% | targetVertex:% | sourceVertex:% | vertsBefore:% | vertsAfter:%\n" \
            node.name target_vertex_id source_vertex_id before_vertex_count after_vertex_count

        true
        -- return
    ),

    /*
    Moves every pending inserted Broken-T vertex onto its paired preserved source vertex.
    By default the pending handoff is cleared only after every move verifies successfully.
    The combined Broken-T fix can preserve the same verified handoff for the following weld stage.
    */
    function moveBrokenTJunctionVertices clear_pending:true show_dialogs:true reuse_current_modifier:false =
    (
        local node = undefined
        local edit_poly_mod = undefined
        local move_records = this.pending_broken_t_move_records

        if classOf move_records != Array or move_records.count == 0 then
        (
            format "Loop-Cleaner BROKEN T MOVE FAILED | stage:pending pairs | value:% | type:%\n" move_records (classOf move_records)
            if show_dialogs then messageBox "Run DIVIDE EDGE first; no pending Broken-T move pairs are stored." title:"Loop-Cleaner"
            return false
        )

        if this.pending_broken_t_node != undefined and isValidNode this.pending_broken_t_node then
        (
            node = this.pending_broken_t_node
        )
        else if selection.count == 1 and isValidNode selection[1] then
        (
            node = selection[1]
        )
        else
        (
            format "Loop-Cleaner BROKEN T MOVE FAILED | stage:node | pendingNode:% | selectionCount:%\n" this.pending_broken_t_node selection.count
            if show_dialogs then messageBox "Select one object, or run BROKEN T SELECT / DIVIDE EDGE first." title:"Loop-Cleaner"
            return false
        )

        if this.pending_broken_t_edit_poly_mod != undefined and classOf this.pending_broken_t_edit_poly_mod == Edit_Poly then
        (
            for stack_mod in node.modifiers while edit_poly_mod == undefined do
            (
                if stack_mod == this.pending_broken_t_edit_poly_mod then edit_poly_mod = stack_mod
            )
        )

        if edit_poly_mod == undefined then
        (
            edit_poly_mod = this.findBrokenTJunctionSelectionModifier node
        )

        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then
        (
            format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:Edit Poly | value:%\n" node.name edit_poly_mod
            if show_dialogs then messageBox "No Broken-T Edit Poly modifier is available on the object." title:"Loop-Cleaner"
            return false
        )

        if edit_poly_mod.currentOperation != 0 then
        (
            format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:current operation | actual:% | required:0\n" node.name edit_poly_mod.currentOperation
            return false
        )

        local position_precision = this.getBrokenTJunctionPositionPrecision()

        if position_precision == undefined or position_precision <= 0.0 then
        (
            format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:position precision | value:%\n" node.name position_precision
            return false
        )

        local required_max_vertex_id = 1

        for move_record in move_records do
        (
            if classOf move_record != Array or move_record.count != 2 then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:record shape | record:%\n" node.name move_record
                return false
            )

            local source_vertex_id = move_record[1]
            local inserted_vertex_id = move_record[2]

            if classOf source_vertex_id != Integer or classOf inserted_vertex_id != Integer then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:record IDs | sourceVertex:% | insertedVertex:%\n" node.name source_vertex_id inserted_vertex_id
                return false
            )

            if source_vertex_id < 1 or inserted_vertex_id < 1 or source_vertex_id == inserted_vertex_id then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:record ID range | sourceVertex:% | insertedVertex:% | required:positive distinct IDs\n" \
                    node.name source_vertex_id inserted_vertex_id
                return false
            )

            if source_vertex_id > required_max_vertex_id then required_max_vertex_id = source_vertex_id
            if inserted_vertex_id > required_max_vertex_id then required_max_vertex_id = inserted_vertex_id
        )

        local vertex_count = 0

        if reuse_current_modifier then
        (
            local live_context = this.ensureBrokenTLiveVertexContext node edit_poly_mod minimum_vertex_id:required_max_vertex_id

            if not live_context[1] then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:post-Divide live context | requiredMaxVertexID:% | liveVertexCount:%\n" \
                    node.name required_max_vertex_id live_context[2]
                return false
            )

            vertex_count = live_context[2]
        )
        else
        (
            if not(this.prepareBrokenTEditPolyContext node edit_poly_mod #Vertex) then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:Edit Poly context\n" node.name
                return false
            )

            vertex_count = edit_poly_mod.GetNumVertices node:node

            if vertex_count < required_max_vertex_id then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:vertex count | actual:% | requiredMaxVertexID:%\n" \
                    node.name vertex_count required_max_vertex_id
                return false
            )
        )

        local moved_count = 0
        local aligned_count = 0

        for move_record in move_records do
        (
            local source_vertex_id = move_record[1]
            local inserted_vertex_id = move_record[2]
            local source_position = edit_poly_mod.GetVertex source_vertex_id node:node
            local inserted_position = edit_poly_mod.GetVertex inserted_vertex_id node:node

            if source_position == undefined or inserted_position == undefined then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:position read | sourceVertex:% | insertedVertex:% | sourcePosition:% | insertedPosition:%\n" \
                    node.name source_vertex_id inserted_vertex_id source_position inserted_position
                return false
            )

            local current_selection = edit_poly_mod.GetSelection #Vertex node:node

            if current_selection == undefined then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:selection read | sourceVertex:% | insertedVertex:%\n" node.name source_vertex_id inserted_vertex_id
                return false
            )

            if current_selection.numberSet > 0 then
            (
                edit_poly_mod.Select #Vertex current_selection select:false node:node
            )

            local moving_bits = #{}
            moving_bits[inserted_vertex_id] = true
            edit_poly_mod.Select #Vertex moving_bits node:node

            local isolated_selection = edit_poly_mod.GetSelection #Vertex node:node

            if isolated_selection == undefined or isolated_selection != moving_bits then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:selection isolate | sourceVertex:% | insertedVertex:% | expected:% | actual:%\n" \
                    node.name source_vertex_id inserted_vertex_id moving_bits isolated_selection
                return false
            )

            local move_delta = source_position - inserted_position

            if not this.quiet_mode then
            (
                format "Loop-Cleaner BROKEN T MOVE | node:% | sourceVertex:% | insertedVertex:% | sourcePosition:% | insertedPosition:% | delta:%\n" \
                    node.name source_vertex_id inserted_vertex_id source_position inserted_position move_delta
            )

            if move_delta != [0,0,0] then
            (
                edit_poly_mod.MoveSelection move_delta
                edit_poly_mod.Commit()
                moved_count += 1
            )
            else
            (
                aligned_count += 1
            )

            local moved_position = edit_poly_mod.GetVertex inserted_vertex_id node:node
            local source_after_position = edit_poly_mod.GetVertex source_vertex_id node:node

            if moved_position == undefined or source_after_position == undefined then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:after position read | sourceVertex:% | insertedVertex:% | expected:% | insertedActual:% | sourceActual:%\n" \
                    node.name source_vertex_id inserted_vertex_id source_position moved_position source_after_position
                return false
            )

            local rounded_expected = this.roundPositionToPrecision source_position position_precision
            local rounded_actual = this.roundPositionToPrecision moved_position position_precision
            local rounded_source_after = this.roundPositionToPrecision source_after_position position_precision

            if rounded_expected == undefined or rounded_actual == undefined or rounded_source_after == undefined then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:position rounding | sourceVertex:% | insertedVertex:% | expectedRaw:% | insertedActualRaw:% | sourceAfterRaw:% | positionPrecision:%\n" \
                    node.name source_vertex_id inserted_vertex_id source_position moved_position source_after_position this.position_precision_text
                return false
            )

            if rounded_actual != rounded_expected then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:move verify | sourceVertex:% | insertedVertex:% | before:% | expectedRaw:% | actualRaw:% | expectedRounded:% | actualRounded:% | remainingDelta:% | positionPrecision:%\n" \
                    node.name source_vertex_id inserted_vertex_id inserted_position source_position moved_position rounded_expected rounded_actual (source_position - moved_position) this.position_precision_text
                return false
            )

            if rounded_source_after != rounded_expected then
            (
                format "Loop-Cleaner BROKEN T MOVE FAILED | node:% | stage:source changed | sourceVertex:% | insertedVertex:% | sourceBefore:% | sourceAfter:% | sourceBeforeRounded:% | sourceAfterRounded:% | positionPrecision:%\n" \
                    node.name source_vertex_id inserted_vertex_id source_position source_after_position rounded_expected rounded_source_after this.position_precision_text
                return false
            )

            if not this.quiet_mode then
            (
                format "Loop-Cleaner BROKEN T MOVE VERIFIED | node:% | sourceVertex:% | insertedVertex:% | before:% | after:% | source:% | delta:%\n" \
                    node.name source_vertex_id inserted_vertex_id inserted_position moved_position source_after_position (moved_position - inserted_position)
            )
        )

        edit_poly_mod.showCage = off

        if show_dialogs then
        (
            edit_poly_mod.RefreshScreen()
            completeRedraw()
        )

        local pair_count = move_records.count

        if clear_pending then
        (
            this.clearPendingBrokenTMoveState()
        )

        format "Loop-Cleaner BROKEN T MOVE COMPLETE | node:% | pairs:% | movedVertices:% | alreadyAligned:% | pendingPreserved:% | welds:0\n" \
            node.name pair_count moved_count aligned_count (not clear_pending)

        true
        -- return
    ),

    /*
    Welds all pending Broken-T source/inserted pairs with the runtime-proven selected-vertex weld sequence.
    Original source vertices are preserved. Inserted disposable IDs are processed in descending order so remaining stored IDs stay stable.
    No base Editable Poly cleanup is performed inside this Edit Poly compound topology operation.
    */
    function weldBrokenTJunctionVertices show_dialogs:true reuse_current_modifier:false =
    (
        local node = undefined
        local edit_poly_mod = undefined
        local move_records = this.pending_broken_t_move_records

        if classOf move_records != Array or move_records.count == 0 then
        (
            format "Loop-Cleaner BROKEN T WELD FAILED | stage:pending pairs | value:% | type:%\n" move_records (classOf move_records)
            if show_dialogs then messageBox "Run DIVIDE EDGE and MOVE VERTICES first; no pending Broken-T weld pairs are stored." title:"Loop-Cleaner"
            return false
        )

        if this.pending_broken_t_node != undefined and isValidNode this.pending_broken_t_node then
        (
            node = this.pending_broken_t_node
        )
        else if selection.count == 1 and isValidNode selection[1] then
        (
            node = selection[1]
        )
        else
        (
            format "Loop-Cleaner BROKEN T WELD FAILED | stage:node | pendingNode:% | selectionCount:%\n" this.pending_broken_t_node selection.count
            return false
        )

        if this.pending_broken_t_edit_poly_mod != undefined and classOf this.pending_broken_t_edit_poly_mod == Edit_Poly then
        (
            for stack_mod in node.modifiers while edit_poly_mod == undefined do
            (
                if stack_mod == this.pending_broken_t_edit_poly_mod then edit_poly_mod = stack_mod
            )
        )

        if edit_poly_mod == undefined then
        (
            edit_poly_mod = this.findBrokenTJunctionSelectionModifier node
        )

        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then
        (
            format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:Edit Poly | value:%\n" node.name edit_poly_mod
            return false
        )

        if edit_poly_mod.currentOperation != 0 then
        (
            format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:current operation | actual:% | required:0\n" node.name edit_poly_mod.currentOperation
            return false
        )

        local position_precision = this.getBrokenTJunctionPositionPrecision()

        if position_precision == undefined or position_precision <= 0.0 then
        (
            format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:position precision | value:%\n" node.name position_precision
            return false
        )

        local context_ok = if reuse_current_modifier then
        (
            this.syncBrokenTEditPolyLevel node edit_poly_mod #Vertex
        )
        else
        (
            this.prepareBrokenTEditPolyContext node edit_poly_mod #Vertex
        )

        if not context_ok then
        (
            format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:Edit Poly context\n" node.name
            return false
        )

        local initial_vertex_count = edit_poly_mod.GetNumVertices node:node

        if initial_vertex_count < 2 then
        (
            format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:vertex count | actual:% | required:>=2\n" node.name initial_vertex_count
            return false
        )

        local weld_records = #()
        local seen_target_ids = #()
        local seen_source_ids = #()
        local highest_target_id = 0
        local lowest_source_id = initial_vertex_count + 1

        for move_record in move_records do
        (
            if classOf move_record != Array or move_record.count != 2 then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:record shape | record:%\n" node.name move_record
                return false
            )

            local target_vertex_id = move_record[1]
            local source_vertex_id = move_record[2]

            if classOf target_vertex_id != Integer or classOf source_vertex_id != Integer then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:record IDs | targetVertex:% | sourceVertex:%\n" node.name target_vertex_id source_vertex_id
                return false
            )

            if target_vertex_id < 1 or target_vertex_id > initial_vertex_count or source_vertex_id < 1 or source_vertex_id > initial_vertex_count or target_vertex_id == source_vertex_id then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:vertex range | targetVertex:% | sourceVertex:% | liveVertexCount:%\n" \
                    node.name target_vertex_id source_vertex_id initial_vertex_count
                return false
            )

            if target_vertex_id > source_vertex_id then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:preserved ID order | targetVertex:% | disposableVertex:% | requirement:target must be lower ID\n" \
                    node.name target_vertex_id source_vertex_id
                return false
            )

            if findItem seen_target_ids target_vertex_id > 0 or                findItem seen_source_ids source_vertex_id > 0 or                findItem seen_target_ids source_vertex_id > 0 or                findItem seen_source_ids target_vertex_id > 0 then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:duplicate pair vertex | targetVertex:% | disposableVertex:% | targets:% | disposables:%\n" \
                    node.name target_vertex_id source_vertex_id seen_target_ids seen_source_ids
                return false
            )

            append seen_target_ids target_vertex_id
            append seen_source_ids source_vertex_id

            if target_vertex_id > highest_target_id then highest_target_id = target_vertex_id
            if source_vertex_id < lowest_source_id then lowest_source_id = source_vertex_id

            local target_position = edit_poly_mod.GetVertex target_vertex_id node:node
            local source_position = edit_poly_mod.GetVertex source_vertex_id node:node

            if target_position == undefined or source_position == undefined then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:position read | targetVertex:% | disposableVertex:% | targetPosition:% | disposablePosition:%\n" \
                    node.name target_vertex_id source_vertex_id target_position source_position
                return false
            )

            local rounded_target = this.roundPositionToPrecision target_position position_precision
            local rounded_source = this.roundPositionToPrecision source_position position_precision

            if rounded_target == undefined or rounded_source == undefined then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:position rounding | targetVertex:% | disposableVertex:% | targetRaw:% | disposableRaw:% | positionPrecision:%\n" \
                    node.name target_vertex_id source_vertex_id target_position source_position this.position_precision_text
                return false
            )

            if rounded_target != rounded_source then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:vertices not aligned | targetVertex:% | disposableVertex:% | targetRaw:% | disposableRaw:% | targetRounded:% | disposableRounded:% | positionPrecision:%\n" \
                    node.name target_vertex_id source_vertex_id target_position source_position rounded_target rounded_source this.position_precision_text
                return false
            )

            append weld_records #(target_vertex_id, source_vertex_id)
        )

        if highest_target_id >= lowest_source_id then
        (
            format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:ID domains | highestPreserved:% | lowestDisposable:% | requirement:all preserved IDs must be below all disposable IDs\n" \
                node.name highest_target_id lowest_source_id
            return false
        )

        if weld_records.count > 1 then
        (
            for sort_index = 2 to weld_records.count do
            (
                local sorted_record = weld_records[sort_index]
                local compare_index = sort_index - 1

                while compare_index >= 1 and weld_records[compare_index][2] < sorted_record[2] do
                (
                    weld_records[compare_index + 1] = weld_records[compare_index]
                    compare_index -= 1
                )

                weld_records[compare_index + 1] = sorted_record
            )
        )

        local welded_count = 0

        for weld_record in weld_records do
        (
            local target_vertex_id = weld_record[1]
            local source_vertex_id = weld_record[2]

            local before_vertex_count = edit_poly_mod.GetNumVertices node:node

            if target_vertex_id < 1 or target_vertex_id > before_vertex_count or source_vertex_id < 1 or source_vertex_id > before_vertex_count then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:live vertex range | targetVertex:% | disposableVertex:% | vertsBefore:% | weldedSoFar:%\n" \
                    node.name target_vertex_id source_vertex_id before_vertex_count welded_count

                if welded_count > 0 then this.clearPendingBrokenTMoveState()
                return false
            )

            local target_position = edit_poly_mod.GetVertex target_vertex_id node:node
            local source_position = edit_poly_mod.GetVertex source_vertex_id node:node

            if target_position == undefined or source_position == undefined then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:live position read | targetVertex:% | disposableVertex:% | targetPosition:% | disposablePosition:% | weldedSoFar:%\n" \
                    node.name target_vertex_id source_vertex_id target_position source_position welded_count

                if welded_count > 0 then this.clearPendingBrokenTMoveState()
                return false
            )

            if not this.quiet_mode then
            (
                format "Loop-Cleaner BROKEN T WELD | node:% | targetVertex:% | disposableVertex:% | targetPosition:% | disposablePosition:% | vertsBefore:%\n" \
                    node.name target_vertex_id source_vertex_id target_position source_position before_vertex_count
            )

            EditPolyMod.WeldVertices edit_poly_mod target_vertex_id source_vertex_id node:node
            EditPolyMod.Commit edit_poly_mod
            if edit_poly_mod.showCage != off then edit_poly_mod.showCage = off

            local expected_vertex_count = before_vertex_count - 1
            local live_context = this.ensureBrokenTLiveVertexContext \
                node \
                edit_poly_mod \
                expected_vertex_count:expected_vertex_count

            if not live_context[1] then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:post-weld live context | targetVertex:% | disposableVertex:% | expectedVertexCount:% | actualVertexCount:% | weldedSoFar:%\n" \
                    node.name target_vertex_id source_vertex_id expected_vertex_count live_context[2] welded_count
                this.clearPendingBrokenTMoveState()
                return false
            )

            local after_vertex_count = live_context[2]

            if after_vertex_count != expected_vertex_count then
            (
                format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:weld verify | targetVertex:% | disposableVertex:% | vertsBefore:% | expectedAfter:% | actualAfter:% | weldedSoFar:%\n" \
                    node.name target_vertex_id source_vertex_id before_vertex_count expected_vertex_count after_vertex_count welded_count

                if welded_count > 0 or after_vertex_count != before_vertex_count then this.clearPendingBrokenTMoveState()
                return false
            )

            welded_count += 1

            if not this.quiet_mode then
            (
                format "Loop-Cleaner BROKEN T WELD VERIFIED | node:% | targetVertex:% | disposableVertex:% | vertsBefore:% | vertsAfter:%\n" \
                    node.name target_vertex_id source_vertex_id before_vertex_count after_vertex_count
            )
        )

        local final_vertex_count = edit_poly_mod.GetNumVertices node:node
        local expected_final_count = initial_vertex_count - weld_records.count

        if final_vertex_count != expected_final_count then
        (
            format "Loop-Cleaner BROKEN T WELD FAILED | node:% | stage:final count | vertsBefore:% | weldPairs:% | expectedAfter:% | actualAfter:%\n" \
                node.name initial_vertex_count weld_records.count expected_final_count final_vertex_count
            this.clearPendingBrokenTMoveState()
            return false
        )

        this.clearPendingBrokenTMoveState()

        if show_dialogs then
        (
            edit_poly_mod.RefreshScreen()
            completeRedraw()
        )

        format "Loop-Cleaner BROKEN T WELD COMPLETE | node:% | weldPairs:% | vertsBefore:% | vertsAfter:%\n" \
            node.name welded_count initial_vertex_count final_vertex_count

        true
        -- return
    ),

    /*
    Leaves exactly the successfully repaired preserved T-junction vertices selected on the working Broken-T Edit Poly.
    The caller supplies stable preserved vertex IDs collected only after complete successful weld cycles.
    */
    function selectRepairedBrokenTVertices node edit_poly_mod repaired_vertex_ids =
    (
        if node == undefined or not isValidNode node then
        (
            format "Loop-Cleaner BROKEN T REPAIRED VERTEX SELECT FAILED | stage:node | value:%\n" node
            return false
        )

        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then
        (
            format "Loop-Cleaner BROKEN T REPAIRED VERTEX SELECT FAILED | node:% | stage:Edit Poly | value:%\n" node.name edit_poly_mod
            return false
        )

        if classOf repaired_vertex_ids != Array then
        (
            format "Loop-Cleaner BROKEN T REPAIRED VERTEX SELECT FAILED | node:% | stage:vertex ID list | value:% | type:%\n" \
                node.name repaired_vertex_ids (classOf repaired_vertex_ids)
            return false
        )

        local live_context = this.ensureBrokenTLiveVertexContext node edit_poly_mod

        if not live_context[1] then
        (
            format "Loop-Cleaner BROKEN T REPAIRED VERTEX SELECT FAILED | node:% | stage:Vertex context | liveVertexCount:%\n" \
                node.name live_context[2]
            return false
        )

        local live_vertex_count = live_context[2]
        local repaired_vertex_bits = #{}
        repaired_vertex_bits.count = live_vertex_count

        for repaired_vertex_id in repaired_vertex_ids do
        (
            if classOf repaired_vertex_id != Integer or repaired_vertex_id < 1 or repaired_vertex_id > live_vertex_count then
            (
                format "Loop-Cleaner BROKEN T REPAIRED VERTEX SELECT FAILED | node:% | stage:vertex range | vertex:% | liveVertexCount:%\n" \
                    node.name repaired_vertex_id live_vertex_count
                return false
            )

            repaired_vertex_bits[repaired_vertex_id] = true
        )

        if not(this.setExactBrokenTVertexSelection node edit_poly_mod repaired_vertex_bits) then
        (
            format "Loop-Cleaner BROKEN T REPAIRED VERTEX SELECT FAILED | node:% | stage:write selection | requested:%\n" \
                node.name repaired_vertex_bits
            return false
        )

        format "Loop-Cleaner BROKEN T REPAIRED VERTEX SELECT | node:% | vertices:% | selection:%\n" \
            node.name repaired_vertex_bits.numberSet repaired_vertex_bits

        true
        -- return
    ),

    /*
    Runs the user-verified Broken-T repair stages in one action: DivideEdge, MoveSelection, then WeldVertices.
    The same node/modifier/level is kept unchanged whenever live topology is already readable; full same-modifier rebind is a stale-context fallback after topology commits.
    Successfully repaired preserved T-junction vertex IDs are accumulated per completed weld cycle and selected once after the full batch succeeds.
    */
    function fixBrokenTJunctionStable initial_topology_data:undefined initial_case_records:undefined initial_position_tolerance:undefined initial_inner_border_edges:undefined initial_inner_border_vertices:undefined =
    (
        format "Loop-Cleaner BROKEN T FIX START\n"

        local completed_cycles = 0
        local total_pairs = 0
        local modifier_locked = false
        local batch_node = undefined
        local batch_edit_poly_mod = undefined
        local first_cycle = true
        local repaired_vertex_ids = #()

        while true do
        (
            local divide_ok = if first_cycle then
            (
                this.divideBrokenTJunctionEdges \
                    show_dialogs:false \
                    reuse_current_modifier:modifier_locked \
                    precomputed_topology_data:initial_topology_data \
                    precomputed_case_records:initial_case_records \
                    precomputed_position_tolerance:initial_position_tolerance \
                    precomputed_inner_border_edges:initial_inner_border_edges \
                    precomputed_inner_border_vertices:initial_inner_border_vertices
            )
            else
            (
                this.divideBrokenTJunctionEdges show_dialogs:false reuse_current_modifier:modifier_locked
            )

            first_cycle = false
            local pending_records = this.pending_broken_t_move_records
            local pair_count = if classOf pending_records == Array then pending_records.count else 0

            if pair_count == 0 then
            (
                if divide_ok then
                (
                    if total_pairs > 0 then
                    (
                        if batch_node == undefined or not isValidNode batch_node or batch_edit_poly_mod == undefined or classOf batch_edit_poly_mod != Edit_Poly then
                        (
                            format "Loop-Cleaner BROKEN T FIX FAILED | stage:final repaired vertex selection context | node:% | editPoly:% | repairedVertices:%\n" \
                                batch_node batch_edit_poly_mod repaired_vertex_ids
                            return false
                        )

                        if not(this.selectRepairedBrokenTVertices batch_node batch_edit_poly_mod repaired_vertex_ids) then
                        (
                            format "Loop-Cleaner BROKEN T FIX FAILED | stage:final repaired vertex selection | repairedVertices:%\n" repaired_vertex_ids
                            return false
                        )

                        if batch_edit_poly_mod.showCage != off then batch_edit_poly_mod.showCage = off
                        batch_edit_poly_mod.RefreshScreen()
                        completeRedraw()
                    )

                    format "Loop-Cleaner BROKEN T FIX COMPLETE | cycles:% | pairs:% | selectedRepairedVertices:%\n" \
                        completed_cycles total_pairs repaired_vertex_ids.count
                    return true
                )

                format "Loop-Cleaner BROKEN T FIX FAILED | stage:DIVIDE EDGE | cycles:% | pairs:% | pending:% | type:%\n" \
                    completed_cycles total_pairs pending_records (classOf pending_records)
                return false
            )

            if this.pending_broken_t_node != undefined and isValidNode this.pending_broken_t_node then
            (
                batch_node = this.pending_broken_t_node
            )

            if this.pending_broken_t_edit_poly_mod != undefined and classOf this.pending_broken_t_edit_poly_mod == Edit_Poly then
            (
                batch_edit_poly_mod = this.pending_broken_t_edit_poly_mod
            )

            if not divide_ok then
            (
                format "Loop-Cleaner BROKEN T FIX PARTIAL DIVIDE CONTINUE | cycle:% | pairs:%\n" (completed_cycles + 1) pair_count
            )

            modifier_locked = true

            if not(this.moveBrokenTJunctionVertices clear_pending:false show_dialogs:false reuse_current_modifier:true) then
            (
                format "Loop-Cleaner BROKEN T FIX FAILED | stage:MOVE VERTICES | cycle:% | pairs:%\n" (completed_cycles + 1) pair_count
                return false
            )

            if not(this.weldBrokenTJunctionVertices show_dialogs:false reuse_current_modifier:true) then
            (
                format "Loop-Cleaner BROKEN T FIX FAILED | stage:WELD VERTICES | cycle:% | pairs:%\n" (completed_cycles + 1) pair_count
                return false
            )

            for pending_record in pending_records do
            (
                local repaired_vertex_id = pending_record[1]

                if findItem repaired_vertex_ids repaired_vertex_id == 0 then
                (
                    append repaired_vertex_ids repaired_vertex_id
                )
            )

            completed_cycles += 1
            total_pairs += pair_count

            format "Loop-Cleaner BROKEN T FIX CYCLE COMPLETE | cycle:% | pairs:% | totalPairs:%\n" completed_cycles pair_count total_pairs
        )

        false
        -- return
    ),

    /*
    Runs a non-modal Broken-T selection followed immediately by the stable batch repair.
    Returns true when the select stage succeeds and either no Broken-T holes remain or the complete repair succeeds.
    */
    function fixTBorderHoles =
    (
        if selection.count != 1 then
        (
            format "Loop-Cleaner FIX T BORDER HOLES FAILED | stage:selection | selectionCount:% | required:1\n" selection.count
            return false
        )

        local target_node = selection[1]

        format "Loop-Cleaner FIX T BORDER HOLES START | node:%\n" target_node.name

        local selection_data = this.prepareBrokenTJunctionSelectionData show_dialogs:false

        if not selection_data[1] then
        (
            format "Loop-Cleaner FIX T BORDER HOLES FAILED | node:% | stage:BROKEN T SELECT | error:%\n" target_node.name selection_data[9]
            return false
        )

        local selection_mod = selection_data[3]

        if selection_mod == undefined then
        (
            format "Loop-Cleaner FIX T BORDER HOLES COMPLETE | node:% | result:no Broken-T holes\n" target_node.name
            return true
        )

        if not(this.fixBrokenTJunctionStable \
            initial_topology_data:selection_data[4] \
            initial_case_records:selection_data[5] \
            initial_position_tolerance:selection_data[6] \
            initial_inner_border_edges:selection_data[10] \
            initial_inner_border_vertices:selection_data[11]) then
        (
            format "Loop-Cleaner FIX T BORDER HOLES FAILED | node:% | stage:BATCH BROKEN T FIX\n" target_node.name
            return false
        )

        format "Loop-Cleaner FIX T BORDER HOLES COMPLETE | node:%\n" target_node.name

        true
        -- return
    ),

    /*
    Welds one disposable Edit Poly vertex into one preserved target vertex.
    Success requires the live vertex count to decrease by exactly one after Commit().
    */
    function weldBrokenTVertexIntoTarget node edit_poly_mod target_vertex_id source_vertex_id =
    (
        if node == undefined or not isValidNode node then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node

        if target_vertex_id < 1 or target_vertex_id > vertex_count then return false
        if source_vertex_id < 1 or source_vertex_id > vertex_count then return false
        if target_vertex_id == source_vertex_id then return false

        before_weld_vertex_count = vertex_count

        edit_poly_mod.WeldVertices target_vertex_id source_vertex_id node:node
        edit_poly_mod.Commit()
        update node

        after_weld_vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        after_weld_vertex_count == (before_weld_vertex_count - 1)
        -- return
    ),

    /*
    Fixes every currently detected broken inner-border T seam inside SELECT BROKEN T JUNCTIONS.
    Missing targets are grouped by their original target edge. Each edge receives exactly the required DivideEdge count, then appended vertices are paired in edge order, moved one by one, and welded in descending inserted-ID order.
    */
    function fixBrokenTJunctionBorders =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one geometry object." title:"Loop-Cleaner"
            return false
        )

        node = selection[1]
        selection_mod = this.findBrokenTJunctionSelectionModifier node

        if selection_mod == undefined then
        (
            if not this.selectBrokenTJunctionBorders() then return false
            selection_mod = this.findBrokenTJunctionSelectionModifier node
        )

        if selection_mod == undefined then
        (
            messageBox "No broken inner-border T junctions were detected." title:"Loop-Cleaner"
            return false
        )

        if not this.activateSelectionModifier node selection_mod then
        (
            messageBox "Could not activate SELECT BROKEN T JUNCTIONS." title:"Loop-Cleaner"
            return false
        )

        stored_edges = copy (selection_mod.GetSelection #Edge node:node)

        if stored_edges.numberSet == 0 then
        (
            messageBox "SELECT BROKEN T JUNCTIONS contains no selected degenerate border edges." title:"Loop-Cleaner"
            return false
        )

        position_tolerance = this.getBrokenTJunctionPositionPrecision()
        initial_topology = this.buildEditPolyBorderTopology node selection_mod

        if initial_topology == undefined then
        (
            messageBox "Could not read live Edit Poly topology for the broken-T fix." title:"Loop-Cleaner"
            return false
        )

        initial_cases = this.findBrokenTJunctionCases initial_topology position_tolerance

        if initial_cases == undefined then
        (
            messageBox "Could not validate current broken-T topology before the fix." title:"Loop-Cleaner"
            return false
        )

        if initial_cases.count == 0 then
        (
            messageBox "No current broken inner-border T junctions remain." title:"Loop-Cleaner"
            return false
        )

        initial_case_count = initial_cases.count
        fixed_operation_count = 0
        inserted_vertex_count = 0
        fix_succeeded = true
        operation_error = ""
        operation_stage = "start"

        undo "Fix Broken T Junctions" on
        (
            try
            (
                keep_fixing = true

                while keep_fixing do
                (
                    operation_stage = "read live topology"
                    topology_data = this.buildEditPolyBorderTopology node selection_mod

                    if topology_data == undefined then
                    (
                        fix_succeeded = false
                        operation_error = "Could not rebuild live Edit Poly border topology."
                        keep_fixing = false
                    )
                    else
                    (
                        case_records = this.findBrokenTJunctionCases topology_data position_tolerance

                        if case_records == undefined then
                        (
                            fix_succeeded = false
                            operation_error = "Could not revalidate broken-T cases."
                            keep_fixing = false
                        )
                        else if case_records.count == 0 then
                        (
                            keep_fixing = false
                        )
                        else
                        (
                            case_count_before = case_records.count
                            missing_target_count = 0
                            first_found_case = undefined
                            first_found_target_vertex_id = 0
                            resolver_failed = false

                            for case_record in case_records while not resolver_failed do
                            (
                                source_vertex_id = case_record[1]
                                target_edge_id = case_record[2]
                                existing_target_result = this.findExistingBrokenTTargetVertex topology_data source_vertex_id target_edge_id position_tolerance
                                existing_target_status = existing_target_result[1]

                                if existing_target_status == #error then
                                (
                                    fix_succeeded = false
                                    operation_error = existing_target_result[3]
                                    operation_stage = "find existing opposite vertex"
                                    resolver_failed = true
                                    keep_fixing = false
                                )
                                else if existing_target_status == #missing then
                                (
                                    missing_target_count += 1
                                )
                                else if existing_target_status == #found and first_found_case == undefined then
                                (
                                    first_found_case = case_record
                                    first_found_target_vertex_id = existing_target_result[2]
                                )
                            )

                            if fix_succeeded and missing_target_count > 0 then
                            (
                                operation_stage = "insert and weld missing opposite vertices"
                                repair_result = this.repairMissingBrokenTTargets node selection_mod topology_data case_records position_tolerance

                                if not repair_result[1] then
                                (
                                    fix_succeeded = false
                                    operation_error = repair_result[5]
                                    keep_fixing = false
                                )
                                else if repair_result[3] < 1 then
                                (
                                    fix_succeeded = false
                                    operation_error = "Broken-T cases still require opposite vertices, but no planned insert/weld operation completed."
                                    keep_fixing = false
                                )
                                else
                                (
                                    inserted_vertex_count += repair_result[2]
                                    fixed_operation_count += repair_result[3]
                                    operation_stage = "verify multi-insert repair"
                                    repaired_topology = repair_result[4]
                                    repaired_cases = this.findBrokenTJunctionCases repaired_topology position_tolerance

                                    if repaired_cases == undefined then
                                    (
                                        fix_succeeded = false
                                        operation_error = "Could not verify broken-T cases after the planned insert/weld sequence."
                                        keep_fixing = false
                                    )
                                    else if repaired_cases.count >= case_count_before then
                                    (
                                        fix_succeeded = false
                                        operation_error = "The planned insert/weld sequence did not reduce the broken-T case count."
                                        keep_fixing = false
                                    )
                                )
                            )
                            else if fix_succeeded then
                            (
                                if first_found_case == undefined or first_found_target_vertex_id < 1 then
                                (
                                    fix_succeeded = false
                                    operation_error = "No repairable broken-T case could be resolved."
                                    operation_stage = "resolve weld case"
                                    keep_fixing = false
                                )
                                else
                                (
                                    source_vertex_id = first_found_case[1]
                                    target_vertex_id = first_found_target_vertex_id
                                    operation_stage = "align T source to existing opposite vertex"
                                    before_align_vertex_count = EditPolyMod.GetNumVertices selection_mod node:node

                                    if not this.moveBrokenTVertexOntoVertex node selection_mod source_vertex_id target_vertex_id position_tolerance then
                                    (
                                        fix_succeeded = false
                                        operation_error = "The T source vertex could not be aligned onto the existing opposite vertex."
                                        keep_fixing = false
                                    )
                                    else if EditPolyMod.GetNumVertices selection_mod node:node != before_align_vertex_count then
                                    (
                                        fix_succeeded = false
                                        operation_error = "Aligning the existing Broken-T vertices changed the live vertex count unexpectedly."
                                        keep_fixing = false
                                    )
                                    else
                                    (
                                        operation_stage = "weld T source to existing opposite vertex"

                                        if not this.weldBrokenTVertexIntoTarget node selection_mod target_vertex_id source_vertex_id then
                                        (
                                            fix_succeeded = false
                                            operation_error = "WeldVertices did not remove exactly one vertex."
                                            keep_fixing = false
                                        )
                                        else
                                        (
                                            operation_stage = "verify repaired topology"
                                            post_topology = this.buildEditPolyBorderTopology node selection_mod

                                            if post_topology == undefined then
                                            (
                                                fix_succeeded = false
                                                operation_error = "Could not read topology after the weld."
                                                keep_fixing = false
                                            )
                                            else
                                            (
                                                post_cases = this.findBrokenTJunctionCases post_topology position_tolerance

                                                if post_cases == undefined then
                                                (
                                                    fix_succeeded = false
                                                    operation_error = "Could not verify broken-T cases after the weld."
                                                    keep_fixing = false
                                                )
                                                else if post_cases.count >= case_count_before then
                                                (
                                                    fix_succeeded = false
                                                    operation_error = "The weld did not reduce the broken-T case count."
                                                    keep_fixing = false
                                                )
                                                else
                                                (
                                                    fixed_operation_count += 1
                                                )
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
            catch
            (
                operation_error = getCurrentException()
                fix_succeeded = false
            )
        )

        if not fix_succeeded then
        (
            format "Loop-Cleaner BROKEN T FIX FAILED | node:% | stage:% | insertedVertices:% | repairedOperations:% | error:%\n" node.name operation_stage inserted_vertex_count fixed_operation_count operation_error
            messageBox ("Broken-T fix stopped at: " + operation_stage + "\n\n" + operation_error + "\n\nPartial changes, if any, remain in the Edit Poly and can be undone.") title:"Loop-Cleaner"
            return false
        )

        final_topology = this.buildEditPolyBorderTopology node selection_mod
        final_cases = if final_topology != undefined then this.findBrokenTJunctionCases final_topology position_tolerance else undefined

        if final_cases == undefined or final_cases.count != 0 then
        (
            remaining_count = if final_cases == undefined then -1 else final_cases.count
            format "Loop-Cleaner BROKEN T FIX VERIFY FAILED | node:% | initial:% | insertedVertices:% | repairedOperations:% | remaining:%\n" node.name initial_case_count inserted_vertex_count fixed_operation_count remaining_count
            messageBox "Broken-T fix did not verify a clean result. Undo is available." title:"Loop-Cleaner"
            return false
        )

        selection_mod.showCage = off
        selection_mod.name = "FIXED BROKEN T JUNCTIONS"
        selection_mod.RefreshScreen()
        completeRedraw()

        format "Loop-Cleaner BROKEN T FIX COMPLETE | node:% | positionPrecision:% | initialCases:% | insertedVertices:% | repairOperations:% | remaining:0\n" node.name this.position_precision_text initial_case_count inserted_vertex_count fixed_operation_count

        true
        -- return
    ),

    /*
    Resolves the current clean Editable Poly analysis snapshot for restored debug selectors.
    Returns #(success, topology_data, candidate_edges, selector_before_index, error_text).
    */
    function getDebugLoopAnalysis node =
    (
        if node == undefined or not isValidNode node then return #(false, undefined, undefined, 0, "Select one valid geometry object.")

        target_data = this.getCurrentPolyTarget node
        target_kind = target_data[1]
        target_value = target_data[2]
        selector_before_index = target_data[3]
        analysis_poly = undefined
        visible_edges = undefined

        if target_kind == #editable_poly then
        (
            if not this.ensureCleanEditablePolyTopology target_value then
            (
                return #(false, undefined, undefined, selector_before_index, "Could not validate Editable Poly topology before reading component IDs.")
            )

            analysis_poly = target_value
            visible_edges = this.getVisibleEditablePolyEdges analysis_poly
        )
        else if target_kind == #edit_poly then
        (
            visible_edges = this.getVisibleEditPolyEdgesFromBase node target_value

            if visible_edges != undefined then
            (
                analysis_poly = node.baseObject
            )
        )
        else
        (
            return #(false, undefined, undefined, selector_before_index, "Make an Editable Poly base or an Edit Poly modifier current in the Modify panel.")
        )

        if analysis_poly == undefined or visible_edges == undefined then
        (
            return #(false, undefined, undefined, selector_before_index, "The current topology cannot be analyzed safely in this clean build.")
        )

        topology_data = this.buildEditablePolyTopology node analysis_poly visible_edges
        if topology_data == undefined then return #(false, undefined, undefined, selector_before_index, "Could not read the current polygon topology.")

        filter_data = this.buildRedundantCandidates topology_data this.geometry_corner_angle_threshold
        if filter_data == undefined then return #(false, undefined, undefined, selector_before_index, "Could not build the debug candidate edge domain.")

        candidate_edges = copy filter_data[1]
        candidate_edges += filter_data[3]

        #(true, topology_data, candidate_edges, selector_before_index, "")
        -- return
    ),

    /*
    Selects border-corner loop edges using the restored 0.819 diagnostic behavior.
    Wall-corner edges are excluded from the displayed border-corner result exactly as in the old debug button.
    */
    function debugSelectBorderCornerLoops =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one Editable Poly or active Edit Poly object." title:"Loop-Cleaner"
            return false
        )

        node = selection[1]
        debug_data = this.getDebugLoopAnalysis node

        if not debug_data[1] then
        (
            messageBox debug_data[5] title:"Loop-Cleaner"
            return false
        )

        topology_data = debug_data[2]
        candidate_edges = debug_data[3]
        selector_before_index = debug_data[4]
        border_corner_records = this.buildBorderCornerLoopRecords topology_data candidate_edges max_turn_threshold:45.0
        wall_corner_records = this.buildWallCornerLoopRecords topology_data candidate_edges this.geometry_corner_angle_threshold
        border_corner_edges = #{}
        wall_corner_edges = #{}

        for loop_record in border_corner_records do
        (
            border_corner_edges += loop_record[1]
        )

        for loop_record in wall_corner_records do
        (
            wall_corner_edges += loop_record[1]
        )

        border_corner_edges -= wall_corner_edges
        write_result = this.writeRedundantSelection node border_corner_edges before_index:selector_before_index

        if not write_result[1] then
        (
            messageBox "Could not store the border-corner debug selection." title:"Loop-Cleaner"
            return false
        )

        format "DEBUG 2 BORDER CORNER LOOPS | node:% | loops:% | excludedWallEdges:% | edges:%\n" node.name border_corner_records.count wall_corner_edges.numberSet border_corner_edges
        true
        -- return
    ),

    /*
    Selects wall-corner loop edges using the restored 0.819 adjacent-face-plane diagnostic.
    */
    function debugSelectWallCornerLoops =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one Editable Poly or active Edit Poly object." title:"Loop-Cleaner"
            return false
        )

        node = selection[1]
        debug_data = this.getDebugLoopAnalysis node

        if not debug_data[1] then
        (
            messageBox debug_data[5] title:"Loop-Cleaner"
            return false
        )

        topology_data = debug_data[2]
        candidate_edges = debug_data[3]
        selector_before_index = debug_data[4]
        wall_corner_records = this.buildWallCornerLoopRecords topology_data candidate_edges this.geometry_corner_angle_threshold
        wall_corner_edges = #{}

        for loop_record in wall_corner_records do
        (
            wall_corner_edges += loop_record[1]
        )

        write_result = this.writeRedundantSelection node wall_corner_edges before_index:selector_before_index

        if not write_result[1] then
        (
            messageBox "Could not store the wall-corner debug selection." title:"Loop-Cleaner"
            return false
        )

        format "DEBUG 3 WALL CORNER LOOPS | node:% | faceAngle:% | loops:% | edges:%\n" node.name this.geometry_corner_angle_threshold wall_corner_records.count wall_corner_edges
        true
        -- return
    ),

    /*
    Runs the canonical detector from the SELECT | REMOVE LMB action.
    The exact final result is stored in SELECT REDUNDANT LOOPS.
    */
    function runSelectRemove =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one Editable Poly or active Edit Poly object." title:"Loop-Cleaner"
            return false
        )

        node = selection[1]
        target_data = this.getCurrentPolyTarget node
        target_kind = target_data[1]
        target_value = target_data[2]
        selector_before_index = target_data[3]
        analysis_poly = undefined
        visible_edges = undefined

        if target_kind == #editable_poly then
        (
            if not this.ensureCleanEditablePolyTopology target_value then
            (
                messageBox "Could not validate Editable Poly topology before reading component IDs." title:"Loop-Cleaner"
                return false
            )

            analysis_poly = target_value
            visible_edges = this.getVisibleEditablePolyEdges analysis_poly
        )
        else if target_kind == #edit_poly then
        (
            visible_edges = this.getVisibleEditPolyEdgesFromBase node target_value

            if visible_edges != undefined then
            (
                analysis_poly = node.baseObject
            )
        )
        else
        (
            messageBox "Make an Editable Poly base or an Edit Poly modifier current in the Modify panel." title:"Loop-Cleaner"
            return false
        )

        if analysis_poly == undefined or visible_edges == undefined then
        (
            messageBox "The current topology cannot be analyzed safely in this clean build. Activate the matching Editable Poly base or an Edit Poly whose topology still matches that base." title:"Loop-Cleaner"
            return false
        )

        detection = this.detectRedundantEditablePoly node analysis_poly visible_edges

        if detection == undefined then
        (
            messageBox "Redundant-loop detection failed while reading the current polygon topology." title:"Loop-Cleaner"
            return false
        )

        redundant_edges = detection[1]
        topology_data = detection[2]
        border_edges = detection[3]
        border_corner_edges = detection[4]
        wall_corner_edges = detection[5]
        internal_edges = detection[6]

        write_result = this.writeRedundantSelection node redundant_edges before_index:selector_before_index

        if not write_result[1] then
        (
            messageBox "Could not store the detected edges in SELECT REDUNDANT LOOPS. See Listener for verification details." title:"Loop-Cleaner"
            return false
        )

        format "Loop-Cleaner SELECT COMPLETE | node:% | visible:% | border:% | internal:% | borderCorner:% | wallCorner:% | redundant:% | edges:%\n" node.name visible_edges.numberSet border_edges.numberSet internal_edges.numberSet border_corner_edges.numberSet wall_corner_edges.numberSet redundant_edges.numberSet redundant_edges

        true
        -- return
    ),

    /*
    RMB removes exactly the Edge BitArray currently stored in SELECT REDUNDANT LOOPS.
    If the selector does not exist yet, the same canonical detector runs first.
    */
    function removeSelectedRedundantLoops =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one geometry object." title:"Loop-Cleaner"
            return false
        )

        node = selection[1]
        selection_mod = this.findSelectionModifier node

        if selection_mod == undefined then
        (
            if not this.runSelectRemove() then return false
            selection_mod = this.findSelectionModifier node
        )

        if selection_mod == undefined then
        (
            messageBox "No redundant loops were detected." title:"Loop-Cleaner"
            return false
        )

        if not this.activateSelectionModifier node selection_mod then
        (
            messageBox "Could not activate SELECT REDUNDANT LOOPS." title:"Loop-Cleaner"
            return false
        )

        selected_edges = copy (selection_mod.GetSelection #Edge)

        if selected_edges.numberSet == 0 then
        (
            messageBox "SELECT REDUNDANT LOOPS contains no selected edges." title:"Loop-Cleaner"
            return false
        )

        before_vertex_count = EditPolyMod.GetNumVertices selection_mod node:node
        before_edge_count = EditPolyMod.GetNumEdges selection_mod node:node

        undo "Remove Redundant Loops" on
        (
            selection_mod.selectMode = 0
            selection_mod.SetEPolySelLevel #Edge
            subObjectLevel = 2
            modPanel.setCurrentObject selection_mod node:node

            selection_mod.SetOperation #RemoveEdgeRemoveVertices
            selection_mod.Commit()
            update node
        )

        after_vertex_count = EditPolyMod.GetNumVertices selection_mod node:node
        after_edge_count = EditPolyMod.GetNumEdges selection_mod node:node

        if after_vertex_count >= before_vertex_count and after_edge_count >= before_edge_count then
        (
            format "Loop-Cleaner REMOVE VERIFY FAILED | node:% | verts:%->% | edges:%->%\n" node.name before_vertex_count after_vertex_count before_edge_count after_edge_count
            messageBox "Remove operation did not reduce topology. Undo is available." title:"Loop-Cleaner"
            return false
        )

        selection_mod.showCage = off
        selection_mod.name = "DELETED REDUNDANT LOOPS"
        selection_mod.RefreshScreen()
        completeRedraw()

        format "Loop-Cleaner REMOVE COMPLETE | node:% | removedSelection:% | verts:%->% | edges:%->%\n" node.name selected_edges.numberSet before_vertex_count after_vertex_count before_edge_count after_edge_count

        true
        -- return
    ),

    /*
    Returns the persistent INI file used by this clean rewrite.
    The filename stays compatible with the existing tool settings.
    */
    function getSettingsPath =
    (
        source_path = getSourceFileName()
        source_directory = getFilenamePath source_path
        source_directory + "Loop-Cleaner.ini"
        -- return
    ),

    /*
    Saves the standalone dialog position.
    Invalid coordinates are rejected instead of being written.
    */
    function saveDialogPosition dialog_pos =
    (
        if dialog_pos == undefined then return false

        dialog_x = try(dialog_pos.x as integer)catch(undefined)
        dialog_y = try(dialog_pos.y as integer)catch(undefined)

        if dialog_x == undefined or dialog_y == undefined then return false
        if dialog_x < -32000 or dialog_x > 32000 or dialog_y < -32000 or dialog_y > 32000 then return false

        RedundantLoopFixer_Dialog_Position = [dialog_x, dialog_y]
        settings_path = this.getSettingsPath()
        settings_error = undefined

        try
        (
            setINISetting settings_path "Dialog" "X" (dialog_x as string)
            setINISetting settings_path "Dialog" "Y" (dialog_y as string)
        )
        catch
        (
            settings_error = getCurrentException()
        )

        if settings_error != undefined then
        (
            format "Loop-Cleaner SETTINGS WRITE ERROR | dialog position | %\n" settings_error
            false
        )
        else
        (
            true
        )
        -- return
    ),

    /*
    Loads the remembered standalone dialog position.
    In-memory position takes priority over the INI file.
    */
    function loadDialogPosition =
    (
        if RedundantLoopFixer_Dialog_Position != undefined then return RedundantLoopFixer_Dialog_Position

        settings_path = this.getSettingsPath()
        dialog_x_text = try(getINISetting settings_path "Dialog" "X")catch("")
        dialog_y_text = try(getINISetting settings_path "Dialog" "Y")catch("")

        if dialog_x_text == "" or dialog_y_text == "" then return undefined

        dialog_x = try(dialog_x_text as integer)catch(undefined)
        dialog_y = try(dialog_y_text as integer)catch(undefined)

        if dialog_x == undefined or dialog_y == undefined then return undefined
        if dialog_x < -32000 or dialog_x > 32000 or dialog_y < -32000 or dialog_y > 32000 then return undefined

        RedundantLoopFixer_Dialog_Position = [dialog_x, dialog_y]
        RedundantLoopFixer_Dialog_Position
        -- return
    ),

    /*
    Saves QUIET mode for routine detector and Broken-T success diagnostics.
    Fatal diagnostics and stage/final summaries remain visible.
    */
    function saveQuietMode quiet_value =
    (
        this.quiet_mode = quiet_value == true
        settings_path = this.getSettingsPath()
        settings_error = undefined

        try
        (
            setINISetting settings_path "Settings" "Quiet" (if this.quiet_mode then "true" else "false")
        )
        catch
        (
            settings_error = getCurrentException()
        )

        if settings_error != undefined then
        (
            format "Loop-Cleaner SETTINGS WRITE ERROR | QUIET | %\n" settings_error
            false
        )
        else
        (
            true
        )
        -- return
    ),

    /*
    Loads QUIET mode from the shared tool INI.
    Missing settings default to enabled.
    */
    function loadQuietMode =
    (
        settings_path = this.getSettingsPath()
        quiet_text = try(getINISetting settings_path "Settings" "Quiet")catch("")
        quiet_value = quiet_text != "false"

        this.quiet_mode = quiet_value
        quiet_value
        -- return
    ),

    /*
    Saves one canonical Broken-T position-precision label to the tool INI.
    Only 1mm, 0.1mm, and 0.01mm are accepted.
    */
    function savePositionPrecision position_precision_text =
    (
        precision_items = this.getPositionPrecisionItems()
        if findItem precision_items position_precision_text == 0 then return false

        this.position_precision_text = position_precision_text
        settings_path = this.getSettingsPath()
        settings_error = undefined

        try
        (
            setINISetting settings_path "Settings" "PositionPrecision" position_precision_text
        )
        catch
        (
            settings_error = getCurrentException()
        )

        if settings_error != undefined then
        (
            format "Loop-Cleaner SETTINGS WRITE ERROR | POSITION PRECISION | %\n" settings_error
            false
        )
        else
        (
            true
        )
        -- return
    ),

    /*
    Loads the persisted position-precision label used by Broken-T position operations.
    Missing or invalid values fall back to the canonical 0.01mm default.
    */
    function loadPositionPrecision =
    (
        settings_path = this.getSettingsPath()
        precision_text = try(getINISetting settings_path "Settings" "PositionPrecision")catch("")
        precision_items = this.getPositionPrecisionItems()

        if findItem precision_items precision_text == 0 then
        (
            precision_text = "0.01mm"
        )

        this.position_precision_text = precision_text
        precision_text
        -- return
    ),

    /*
    Saves the ANGLE UI value for later detector work.
    This shell does not use ANGLE for detection yet.
    */
    function saveStraightAngleThreshold angle_value =
    (
        straight_value = try(angle_value as float)catch(undefined)
        if straight_value == undefined then return false
        if straight_value < 0.0 then straight_value = 0.0
        if straight_value > 45.0 then straight_value = 45.0

        this.straight_angle_threshold = straight_value
        settings_path = this.getSettingsPath()
        settings_error = undefined

        try
        (
            setINISetting settings_path "Settings" "StraightAngleThreshold" (straight_value as string)
        )
        catch
        (
            settings_error = getCurrentException()
        )

        if settings_error != undefined then
        (
            format "Loop-Cleaner SETTINGS WRITE ERROR | ANGLE | %\n" settings_error
            false
        )
        else
        (
            true
        )
        -- return
    ),

    /*
    Loads the ANGLE UI value from the shared tool INI.
    Missing or invalid values fall back to 5 degrees.
    */
    function loadStraightAngleThreshold =
    (
        settings_path = this.getSettingsPath()
        straight_text = try(getINISetting settings_path "Settings" "StraightAngleThreshold")catch("")
        straight_value = try(straight_text as float)catch(undefined)

        if straight_text == "" or straight_value == undefined then straight_value = 5.0
        if straight_value < 0.0 then straight_value = 0.0
        if straight_value > 45.0 then straight_value = 45.0

        this.straight_angle_threshold = straight_value
        straight_value
        -- return
    ),

    /*
    Saves the current standalone dialog position if a dialog exists.
    Returns false when the rollout is not currently standalone.
    */
    function saveCurrentDialogPosition =
    (
        if RedundantLoopFixer_UI == undefined then return false

        dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch(false)
        if not dialog_is_standalone then return false

        dialog_pos = try(getDialogPos RedundantLoopFixer_UI)catch(undefined)
        if dialog_pos == undefined then return false

        this.saveDialogPosition dialog_pos
        -- return
    ),

    /*
    Closes the standalone dialog without touching embedded manager UI.
    Any failure is reported instead of being swallowed.
    */
    function hideUI =
    (
        hide_ok = true

        if RedundantLoopFixer_UI != undefined then
        (
            dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch(false)

            if dialog_is_standalone then
            (
                this.saveCurrentDialogPosition()
                hide_error = undefined

                try
                (
                    cui.UnRegisterDialogBar RedundantLoopFixer_UI
                )
                catch
                (
                    unregister_error = getCurrentException()
                    format "Loop-Cleaner UNREGISTER UI ERROR | %\n" unregister_error
                )

                try
                (
                    destroyDialog RedundantLoopFixer_UI
                )
                catch
                (
                    hide_error = getCurrentException()
                )

                if hide_error != undefined then
                (
                    format "Loop-Cleaner HIDE UI ERROR | %\n" hide_error
                    hide_ok = false
                )
            )
        )

        hide_ok
        -- return
    ),

    /*
    Opens the standalone clean-rewrite UI.
    The previous saved position is restored when available.
    */
    function showUI =
    (
        this.hideUI()
        dialog_pos = this.loadDialogPosition()

        if dialog_pos != undefined then
        (
            createDialog RedundantLoopFixer_UI pos:dialog_pos
        )
        else
        (
            createDialog RedundantLoopFixer_UI
        )

        cui.RegisterDialogBar RedundantLoopFixer_UI style:#(#cui_dock_vert, #cui_floatable, #cui_handles)
        windows.processPostedMessages()
        true
        -- return
    ),

    /*
    Returns the visible tool title from the current global project version.
    The native dialog title keeps the running project version visible.
    */
    function getDisplayTitle =
    (
        "Loop-Cleaner | v" + (epoly_tools_project_version as string)
        -- return
    ),

    on create do
    (
    )
)

RedundantLoopFixer1168 = RedundantLoopFixer1168_v()
RedundantLoopFixer = RedundantLoopFixer1168

if RedundantLoopFixer_Previous_Pending_Node != undefined and \
   isValidNode RedundantLoopFixer_Previous_Pending_Node and \
   RedundantLoopFixer_Previous_Pending_Edit_Poly_Mod != undefined and \
   classOf RedundantLoopFixer_Previous_Pending_Edit_Poly_Mod == Edit_Poly and \
   classOf RedundantLoopFixer_Previous_Pending_Move_Records == Array and \
   RedundantLoopFixer_Previous_Pending_Move_Records.count > 0 then
(
    pending_mod_is_live = false

    for stack_mod in RedundantLoopFixer_Previous_Pending_Node.modifiers while not pending_mod_is_live do
    (
        if stack_mod == RedundantLoopFixer_Previous_Pending_Edit_Poly_Mod then pending_mod_is_live = true
    )

    if pending_mod_is_live then
    (
        RedundantLoopFixer.pending_broken_t_node = RedundantLoopFixer_Previous_Pending_Node
        RedundantLoopFixer.pending_broken_t_edit_poly_mod = RedundantLoopFixer_Previous_Pending_Edit_Poly_Mod
        RedundantLoopFixer.pending_broken_t_move_records = RedundantLoopFixer_Previous_Pending_Move_Records
        format "Loop-Cleaner BROKEN T PENDING MOVE PAIRS RESTORED | node:% | pairs:%\n" RedundantLoopFixer.pending_broken_t_node.name RedundantLoopFixer.pending_broken_t_move_records.count
    )
)

RedundantLoopFixer_Previous_Pending_Node = undefined
RedundantLoopFixer_Previous_Pending_Edit_Poly_Mod = undefined
RedundantLoopFixer_Previous_Pending_Move_Records = #()

if epoly_tools_project_version == undefined or epoly_tools_project_version < RedundantLoopFixer.project_version then
(
    epoly_tools_project_version = RedundantLoopFixer.project_version
)

RedundantLoopFixer_Title = "Loop-Cleaner | v" + (epoly_tools_project_version as string)

rollout RedundantLoopFixer_UI RedundantLoopFixer_Title width:288 height:444
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:264 height:32
    button btn_select_remove "USELESS LOOPS SELECT \\ REMOVE" pos:[24,56] width:240 height:32 tooltip:"LMB: Select visible internal edges after subtracting border-corner and wall-corner loop masks.\n\nRMB: Remove the exact stored redundant-edge selection and its redundant vertices."
    button btn_border_all "BORDER ALL" pos:[24,100] width:72 height:32 tooltip:"LMB: Select every visible/selectable true mesh border edge."
    button btn_border_outer "OUTER" pos:[108,100] width:72 height:32 tooltip:"LMB: Select the greatest-perimeter border component on each connected surface shell."
    button btn_border_inner "INNER" pos:[192,100] width:72 height:32 tooltip:"LMB: Select all remaining border components, representing inner holes on each connected surface shell."
    button btn_t_junction_all "T JUNCTIONS" pos:[24,144] width:72 height:32 tooltip:"LMB: Select all visible internal loops traced from exact T-junction stems."
    button btn_t_junction_border "T BORDER" pos:[108,144] width:72 height:32 tooltip:"LMB: Select only the T-stem edges at broken inner-border seams. Parallel continuation edges along the traced loop are not selected."
    button btn_t_junction_mesh "T MESH" pos:[192,144] width:72 height:32 tooltip:"LMB: Select complete traced T-junction loops that have no broken inner-border seam endpoint."
    button btn_t_border_holes "T BORDER HOLES SELECT \\ FIX" pos:[24,188] width:240 height:32 tooltip:"LMB: Select complete broken inner-border components using the position precision below.\n\nRMB: Run Broken-T selection, then the complete Divide, Move, and Weld repair with no modal stage dialogs."
    button btn_debug_border "2  SELECT BORDER CORNER LOOPS" pos:[24,232] width:240 height:32 tooltip:"LMB: Select border-corner loop edges in SELECT REDUNDANT LOOPS."
    button btn_debug_wall_corner "3  SELECT WALL CORNER LOOP" pos:[24,276] width:240 height:32 tooltip:"LMB: Select wall-corner loop edges in SELECT REDUNDANT LOOPS."
    button btn_debug_angle "4  SELECT ANGLED LOOPS" pos:[24,320] width:240 height:32 enabled:false tooltip:"Unused in the clean rewrite."
    checkbox chk_quiet "QUIET" pos:[24,364] width:48 height:24 checked:true tooltip:"Suppress routine detector and Broken-T per-pair success diagnostics. Failures and stage/final summaries remain visible."
    label lbl_position_precision "postion preccision" pos:[78,364] width:108 height:16
    dropdownlist ddl_position_precision "" pos:[192,360] width:72 height:24 items:#("1mm", "0.1mm", "0.01mm") selection:3 tooltip:"Position precision used for Broken-T position matching and edge re-resolution. Default: 0.01mm."
    spinner spn_straight_angle "ANGLE:" pos:[24,400] width:108 range:[0.0,45.0,5.0] type:#float scale:0.1 fieldwidth:60 enabled:false tooltip:"Not used by SELECT in this build."
    label lbl_straight_units "deg" pos:[144,404] width:24 height:16
    button btn_get_angle "GET ANGLE" pos:[180,396] width:84 height:32 enabled:false tooltip:"Unused in the clean rewrite."

    on RedundantLoopFixer_UI open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Loop-Cleaner"
        ToolTitleButton.resizeToolTitleButton btn_tool_title (RedundantLoopFixer_UI.width - 24)
        btn_tool_title.height = 32
        chk_quiet.checked = RedundantLoopFixer.loadQuietMode()
        position_precision_text = RedundantLoopFixer.loadPositionPrecision()
        precision_index = findItem ddl_position_precision.items position_precision_text
        ddl_position_precision.selection = if precision_index > 0 then precision_index else 3
        spn_straight_angle.value = RedundantLoopFixer.loadStraightAngleThreshold()
    )

    on RedundantLoopFixer_UI moved dialog_pos do
    (
        dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch(false)
        if dialog_is_standalone then RedundantLoopFixer.saveDialogPosition dialog_pos
    )

    on RedundantLoopFixer_UI resized dialog_size do
    (
        ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
        btn_tool_title.height = 32
    )

    on btn_tool_title Click sender event_args do
    (
        restartTool RedundantLoopFixer_Source_File "Loop-Cleaner"
    )

    on chk_quiet changed quiet_value do
    (
        RedundantLoopFixer.saveQuietMode quiet_value
    )

    on ddl_position_precision selected precision_index do
    (
        if precision_index >= 1 and precision_index <= ddl_position_precision.items.count then
        (
            RedundantLoopFixer.savePositionPrecision ddl_position_precision.items[precision_index]
        )
    )

    on spn_straight_angle changed angle_value do
    (
        RedundantLoopFixer.saveStraightAngleThreshold angle_value
    )

    on btn_select_remove pressed do
    (
        RedundantLoopFixer.runSelectRemove()
    )

    on btn_select_remove rightClick do
    (
        RedundantLoopFixer.removeSelectedRedundantLoops()
    )

    on btn_border_all pressed do
    (
        RedundantLoopFixer.selectAllBorders()
    )

    on btn_border_outer pressed do
    (
        RedundantLoopFixer.selectOuterBorders()
    )

    on btn_border_inner pressed do
    (
        RedundantLoopFixer.selectInnerBorders()
    )

    on btn_t_junction_all pressed do
    (
        RedundantLoopFixer.selectAllTJunctions()
    )

    on btn_t_junction_border pressed do
    (
        RedundantLoopFixer.selectBorderTJunctions()
    )

    on btn_t_junction_mesh pressed do
    (
        RedundantLoopFixer.selectMeshTJunctions()
    )

    on btn_t_border_holes pressed do
    (
        RedundantLoopFixer.selectBrokenTJunctionBorders()
    )

    on btn_t_border_holes rightClick do
    (
        RedundantLoopFixer.fixTBorderHoles()
    )


    on btn_debug_border pressed do
    (
        RedundantLoopFixer.debugSelectBorderCornerLoops()
    )

    on btn_debug_wall_corner pressed do
    (
        RedundantLoopFixer.debugSelectWallCornerLoops()
    )
)

if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "redundant-loop-fixer-clean" (RedundantLoopFixer.getDisplayTitle()) RedundantLoopFixer RedundantLoopFixer_UI RedundantLoopFixer.file_version RedundantLoopFixer.project_version (getSourceFileName()) capabilities:#(#ui, #selection, #edge, #editable_poly, #edit_poly)

    if EPolyToolsIntegration.shouldAutoOpenUI() then RedundantLoopFixer.showUI()
)
else
(
    RedundantLoopFixer.showUI()
)
