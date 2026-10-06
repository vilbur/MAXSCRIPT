/*
    Loop-Cleaner 1.156
    Clean rewrite development build.
*/

global RedundantLoopFixer
global RedundantLoopFixer1156
global RedundantLoopFixer_UI
global RedundantLoopFixer_Dialog_Position
global RedundantLoopFixer_Title
global RedundantLoopFixer_Source_File
global RedundantLoopFixer_Script_Reload_Path
global RedundantLoopFixer_Tool_Title_Button_Path
global EPolyToolsIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global epoly_tools_project_version

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

struct RedundantLoopFixer1156_v
(
    file_version = 1.156,
    project_version = 1.156,
    quiet_mode = true,
    straight_angle_threshold = 5.0,
    geometry_corner_angle_threshold = 1.0,
    broken_t_position_tolerance_mm = 0.1,

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
            seed_array = remaining_edges as array
            seed_edge = seed_array[1]
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
    Classifies true border components as all, outer, and inner.
    For each connected surface shell, the border component with the greatest exact world-space perimeter
    is the outer border; all other border components on that shell are inner-hole borders.
    Returns #(allBorders, outerBorders, innerBorders, componentCount, shellCount).
    */
    function classifyBorderEdges topology_data =
    (
        if topology_data == undefined then return undefined

        all_border_edges = copy topology_data[8]
        outer_border_edges = #{}
        inner_border_edges = #{}
        border_components = this.buildBorderComponents topology_data
        face_shell_ids = this.buildFaceShellIds topology_data

        if face_shell_ids == undefined then return undefined

        edge_faces = topology_data[7]
        component_shell_ids = #()
        shell_ids = #()
        shell_outer_component_indexes = #()
        shell_outer_perimeters = #()

        for component_index = 1 to border_components.count do
        (
            component_edges = border_components[component_index]
            component_array = component_edges as array
            component_shell_id = 0
            component_perimeter = this.getBorderComponentPerimeter component_edges topology_data

            if component_array.count > 0 then
            (
                seed_edge = component_array[1]
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
    Selects all, outer, or inner-hole border edges and stores the result in SELECT BORDERS.
    Only currently visible/selectable edges are written; border classification itself uses the complete border topology.
    */
    function selectBorders border_mode =
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
    Returns #(chainEdges, startTVertex, terminalTVertexOrZero).
    */
    function traceTJunctionLoop start_vertex seed_edge topology_data candidate_edges t_vertices =
    (
        empty_record = #(#{}, start_vertex, 0)

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

        #(chain_edges, start_vertex, terminal_t_vertex)
        -- return
    ),

    /*
    Classifies traced T-junction loops as all, border, or mesh.
    T BORDER means at least one exact T-junction vertex on the traced loop lies on true mesh border topology.
    T MESH means every exact T-junction vertex on that traced loop is internal.
    Returns #(allEdges, borderEdges, meshEdges, allCount, borderCount, meshCount).
    */
    function classifyTJunctionLoops topology_data =
    (
        if topology_data == undefined then return undefined

        seed_records = this.buildTJunctionSeedRecords topology_data
        candidate_edges = this.buildTJunctionCandidateEdges topology_data
        all_t_vertices = #{}
        border_t_vertices = #{}
        seed_edges = #{}

        all_t_vertices.count = topology_data[1]
        border_t_vertices.count = topology_data[1]
        seed_edges.count = topology_data[2]

        for seed_record in seed_records do
        (
            vertex_index = seed_record[1]
            stem_edge = seed_record[2]
            is_border_junction = seed_record[3]

            all_t_vertices[vertex_index] = true
            if is_border_junction then border_t_vertices[vertex_index] = true

            if stem_edge >= 1 and stem_edge <= candidate_edges.count and candidate_edges[stem_edge] then
            (
                seed_edges[stem_edge] = true
            )
        )

        remaining_seed_edges = copy seed_edges
        all_junction_edges = #{}
        border_junction_edges = #{}
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
                    terminal_t_vertex = loop_record[3]
                    has_border_t = seed_record[3]

                    if terminal_t_vertex >= 1 and terminal_t_vertex <= border_t_vertices.count then
                    (
                        if border_t_vertices[terminal_t_vertex] then has_border_t = true
                    )

                    all_junction_edges += loop_edges
                    all_count += 1

                    if has_border_t then
                    (
                        border_junction_edges += loop_edges
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
    function writeBrokenTJunctionSelection node broken_edges before_index:0 =
    (
        if node == undefined or not isValidNode node then return #(false, undefined, false)
        if broken_edges == undefined then return #(false, undefined, false)

        selection_mod = this.findBrokenTJunctionSelectionModifier node
        created = false

        if broken_edges.numberSet == 0 then
        (
            if selection_mod == undefined then return #(true, undefined, false)
            if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, false)

            old_edges = selection_mod.GetSelection #Edge node:node

            if old_edges.numberSet > 0 then
            (
                selection_mod.Select #Edge old_edges select:false node:node
            )

            selection_mod.RefreshScreen()
            completeRedraw()

            stored_edges = selection_mod.GetSelection #Edge node:node
            return #(stored_edges.numberSet == 0, selection_mod, false)
        )

        selection_data = this.acquireBrokenTJunctionSelectionModifier node before_index:before_index
        selection_mod = selection_data[1]
        created = selection_data[2]

        if selection_mod == undefined then return #(false, undefined, created)
        if not this.activateSelectionModifier node selection_mod then return #(false, selection_mod, created)

        old_edges = selection_mod.GetSelection #Edge node:node

        if old_edges.numberSet > 0 then
        (
            selection_mod.Select #Edge old_edges select:false node:node
        )

        selection_mod.Select #Edge broken_edges node:node
        selection_mod.RefreshScreen()
        completeRedraw()

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
    Returns the explicit broken-T positional tolerance in current system units.
    The feature contract is fixed at 0.1 mm; no scene-unit-dependent hidden epsilon is used.
    */
    function getBrokenTJunctionPositionTolerance =
    (
        this.broken_t_position_tolerance_mm * (units.decodeValue "1mm")
        -- return
    ),

    /*
    Returns a deterministic unordered vertex-pair key for one topology edge.
    */
    function makeVertexPairKey vertex_a vertex_b =
    (
        if vertex_a < vertex_b then
        (
            (vertex_a as string) + ":" + (vertex_b as string)
        )
        else
        (
            (vertex_b as string) + ":" + (vertex_a as string)
        )
        -- return
    ),

    /*
    Builds a live polygon-topology snapshot directly from one Edit Poly modifier.
    The result uses the same array layout as buildEditablePolyTopology so border classifiers can be reused.
    Native edge IDs are resolved from face boundary vertex pairs; ambiguous duplicate endpoint edges abort.
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

        for vertex_index = 1 to vertex_count do
        (
            local_point = EditPolyMod.GetVertex edit_poly_mod vertex_index node:node
            if local_point == undefined then return undefined

            append vertex_points (local_point * node.objectTransform)
            vertex_bits = #{}
            vertex_bits.count = edge_count
            append vertex_edges vertex_bits
        )

        edge_vertices = #()
        edge_keys = #()
        edge_face_lists = #()

        for edge_index = 1 to edge_count do
        (
            vertex_a = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 1 node:node
            vertex_b = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 2 node:node

            if vertex_a < 1 or vertex_a > vertex_count or vertex_b < 1 or vertex_b > vertex_count or vertex_a == vertex_b then return undefined

            edge_key = this.makeVertexPairKey vertex_a vertex_b
            if findItem edge_keys edge_key > 0 then return undefined

            append edge_vertices #(vertex_a, vertex_b)
            append edge_keys edge_key
            append edge_face_lists #()

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
                face_edge_key = this.makeVertexPairKey face_vertices[corner_index] face_vertices[next_corner_index]
                native_edge_index = findItem edge_keys face_edge_key

                if native_edge_index < 1 then return undefined

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
    A case exists when an inner-border vertex lies within the explicit 0.1 mm tolerance of the strict interior
    of another non-incident inner-border edge and at least one source border edge lies on the same target line
    within that same tolerance. Returns records:
    #(sourceVertex, targetEdge, targetFraction, distanceToTarget, sourceInnerEdges).
    */
    function findBrokenTJunctionCases topology_data position_tolerance =
    (
        if topology_data == undefined then return undefined
        if position_tolerance < 0.0 then return undefined

        classification = this.classifyBorderEdges topology_data
        if classification == undefined then return undefined

        inner_border_edges = classification[3]
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

        case_records = #()

        for source_vertex_id in inner_vertices do
        (
            source_point = vertex_points[source_vertex_id]
            source_inner_edges = vertex_edges[source_vertex_id] * inner_border_edges

            if source_inner_edges.numberSet > 0 then
            (
                best_target_edge = 0
                best_target_fraction = 0.0
                best_target_distance = undefined
                best_target_length = undefined

                for target_edge_id in inner_border_edges do
                (
                    if not source_inner_edges[target_edge_id] then
                    (
                        target_pair = edge_vertices[target_edge_id]

                        if target_pair != undefined and target_pair.count == 2 then
                        (
                            point_a = vertex_points[target_pair[1]]
                            point_b = vertex_points[target_pair[2]]
                            target_length = distance point_a point_b

                            if target_length > 0.0 then
                            (
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

                if best_target_edge > 0 then
                (
                    append case_records #(source_vertex_id, best_target_edge, best_target_fraction, best_target_distance, copy source_inner_edges)
                )
            )
        )

        case_records
        -- return
    ),

    /*
    Expands local broken-T case edges to their complete degenerate inner-border components.
    Valid closed inner borders with no vertex-on-edge T seam are not selected.
    Returns #(selectedDegenerateBorderEdges, caseRecords, componentCount).
    */
    function getBrokenTJunctionBorderSelection topology_data position_tolerance =
    (
        if topology_data == undefined then return undefined

        case_records = this.findBrokenTJunctionCases topology_data position_tolerance
        if case_records == undefined then return undefined

        classification = this.classifyBorderEdges topology_data
        if classification == undefined then return undefined

        inner_border_edges = classification[3]
        border_components = this.buildBorderComponents topology_data
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

        #(selected_edges, case_records, broken_component_count)
        -- return
    ),

    /*
    Selects every degenerate inner-border component containing a border vertex-on-edge T seam.
    The positional contract is the explicit fixed 0.1 mm tolerance.
    */
    function selectBrokenTJunctionBorders =
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
        position_tolerance = this.getBrokenTJunctionPositionTolerance()
        broken_data = this.getBrokenTJunctionBorderSelection topology_data position_tolerance

        if broken_data == undefined then
        (
            messageBox "Could not classify broken inner-border T junctions." title:"Loop-Cleaner"
            return false
        )

        broken_edges = broken_data[1] * topology_data[12]
        case_records = broken_data[2]
        broken_component_count = broken_data[3]
        write_result = this.writeBrokenTJunctionSelection node broken_edges before_index:selector_before_index

        if not write_result[1] then
        (
            messageBox "Could not store the broken-T border selection in SELECT BROKEN T JUNCTIONS. See Listener for verification details." title:"Loop-Cleaner"
            return false
        )

        format "Loop-Cleaner BROKEN T SELECT | node:% | toleranceMM:% | cases:% | components:% | selected:% | edges:%\n" node.name this.broken_t_position_tolerance_mm case_records.count broken_component_count broken_edges.numberSet broken_edges

        true
        -- return
    ),

    /*
    Moves one newly divided Edit Poly vertex exactly onto one existing source vertex.
    The move is verified in world space against the explicit broken-T position tolerance.
    */
    function moveBrokenTVertexOntoSource node edit_poly_mod moving_vertex_id source_vertex_id position_tolerance =
    (
        if node == undefined or not isValidNode node then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false

        vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node

        if moving_vertex_id < 1 or moving_vertex_id > vertex_count then return false
        if source_vertex_id < 1 or source_vertex_id > vertex_count then return false
        if moving_vertex_id == source_vertex_id then return false

        moving_position = EditPolyMod.GetVertex edit_poly_mod moving_vertex_id node:node
        source_position = EditPolyMod.GetVertex edit_poly_mod source_vertex_id node:node

        if moving_position == undefined or source_position == undefined then return false

        move_delta = source_position - moving_position

        if move_delta != [0,0,0] then
        (
            select node
            max modify mode

            edit_poly_mod.SetPrimaryNode node
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0

            modPanel.setCurrentObject edit_poly_mod node:node
            edit_poly_mod.SetEPolySelLevel #Vertex
            subObjectLevel = 1

            old_vertices = edit_poly_mod.GetSelection #Vertex node:node

            if old_vertices.numberSet > 0 then
            (
                edit_poly_mod.Select #Vertex old_vertices select:false node:node
            )

            moving_bits = #{}
            moving_bits[moving_vertex_id] = true
            edit_poly_mod.Select #Vertex moving_bits node:node

            stored_vertices = edit_poly_mod.GetSelection #Vertex node:node
            if stored_vertices != moving_bits then return false

            edit_poly_mod.MoveSelection move_delta
            edit_poly_mod.Commit()
            update node
        )

        moved_position = EditPolyMod.GetVertex edit_poly_mod moving_vertex_id node:node
        source_after_move = EditPolyMod.GetVertex edit_poly_mod source_vertex_id node:node

        if moved_position == undefined or source_after_move == undefined then return false

        moved_world = moved_position * node.objectTransform
        source_world = source_after_move * node.objectTransform

        distance moved_world source_world <= position_tolerance
        -- return
    ),

    /*
    Fixes every currently detected broken inner-border T seam inside SELECT BROKEN T JUNCTIONS.
    Each pass re-reads live Edit Poly topology, divides the target border edge at the projected source position,
    moves the new vertex exactly onto the existing source vertex, welds them, and requires the case count to decrease.
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

        position_tolerance = this.getBrokenTJunctionPositionTolerance()
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
                            case_record = case_records[1]
                            source_vertex_id = case_record[1]
                            target_edge_id = case_record[2]
                            divide_fraction = case_record[3]

                            operation_stage = "divide opposite border edge"
                            before_divide_vertex_count = EditPolyMod.GetNumVertices selection_mod node:node
                            divided_vertex_id = EditPolyMod.DivideEdge selection_mod target_edge_id divide_fraction node:node

                            if divided_vertex_id == undefined or divided_vertex_id < 1 then
                            (
                                fix_succeeded = false
                                operation_error = "DivideEdge did not create the required opposite-edge vertex."
                                keep_fixing = false
                            )
                            else
                            (
                                EditPolyMod.Commit selection_mod
                                update node

                                after_divide_vertex_count = EditPolyMod.GetNumVertices selection_mod node:node

                                if after_divide_vertex_count != (before_divide_vertex_count + 1) then
                                (
                                    fix_succeeded = false
                                    operation_error = "DivideEdge did not add exactly one live vertex."
                                    keep_fixing = false
                                )
                                else
                                (
                                    operation_stage = "align divided vertex"
                                    if not this.moveBrokenTVertexOntoSource node selection_mod divided_vertex_id source_vertex_id position_tolerance then
                                    (
                                        fix_succeeded = false
                                        operation_error = "The divided vertex could not be aligned onto the T-junction source vertex."
                                        keep_fixing = false
                                    )
                                    else
                                    (
                                        operation_stage = "weld divided vertex to source"
                                        before_weld_vertex_count = EditPolyMod.GetNumVertices selection_mod node:node
                                        selection_mod.WeldVertices source_vertex_id divided_vertex_id node:node
                                        selection_mod.Commit()
                                        update node
                                        after_weld_vertex_count = EditPolyMod.GetNumVertices selection_mod node:node

                                        if after_weld_vertex_count != (before_weld_vertex_count - 1) then
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
            format "Loop-Cleaner BROKEN T FIX FAILED | node:% | stage:% | repairedOperations:% | error:%\n" node.name operation_stage fixed_operation_count operation_error
            messageBox ("Broken-T fix stopped at: " + operation_stage + "\n\n" + operation_error + "\n\nPartial changes, if any, remain in the Edit Poly and can be undone.") title:"Loop-Cleaner"
            return false
        )

        final_topology = this.buildEditPolyBorderTopology node selection_mod
        final_cases = if final_topology != undefined then this.findBrokenTJunctionCases final_topology position_tolerance else undefined

        if final_cases == undefined or final_cases.count != 0 then
        (
            remaining_count = if final_cases == undefined then -1 else final_cases.count
            format "Loop-Cleaner BROKEN T FIX VERIFY FAILED | node:% | initial:% | repairedOperations:% | remaining:%\n" node.name initial_case_count fixed_operation_count remaining_count
            messageBox "Broken-T fix did not verify a clean result. Undo is available." title:"Loop-Cleaner"
            return false
        )

        selection_mod.showCage = off
        selection_mod.name = "FIXED BROKEN T JUNCTIONS"
        selection_mod.RefreshScreen()
        completeRedraw()

        format "Loop-Cleaner BROKEN T FIX COMPLETE | node:% | toleranceMM:% | initialCases:% | repairOperations:% | remaining:0\n" node.name this.broken_t_position_tolerance_mm initial_case_count fixed_operation_count

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
    Saves QUIET mode for future detector functions.
    The clean rewrite keeps the current UI state behavior.
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

RedundantLoopFixer1156 = RedundantLoopFixer1156_v()
RedundantLoopFixer = RedundantLoopFixer1156

if epoly_tools_project_version == undefined or epoly_tools_project_version < RedundantLoopFixer.project_version then
(
    epoly_tools_project_version = RedundantLoopFixer.project_version
)

RedundantLoopFixer_Title = "Loop-Cleaner | v" + (epoly_tools_project_version as string)

rollout RedundantLoopFixer_UI RedundantLoopFixer_Title width:336 height:488
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:312 height:32
    button btn_select_remove "USELESS LOOPS SELECT \\ REMOVE" pos:[24,56] width:288 height:32 tooltip:"LMB: Select visible internal edges after subtracting border-corner and wall-corner loop masks.\n\nRMB: Remove the exact stored redundant-edge selection and its redundant vertices."
    button btn_border_all "BORDER ALL" pos:[24,100] width:88 height:32 tooltip:"LMB: Select every visible/selectable true mesh border edge."
    button btn_border_outer "OUTER" pos:[124,100] width:88 height:32 tooltip:"LMB: Select the greatest-perimeter border component on each connected surface shell."
    button btn_border_inner "INNER" pos:[224,100] width:88 height:32 tooltip:"LMB: Select all remaining border components, representing inner holes on each connected surface shell."
    button btn_t_junction_all "T JUNCTIONS" pos:[24,144] width:88 height:32 tooltip:"LMB: Select all visible internal loops traced from exact T-junction stems."
    button btn_t_junction_border "T BORDER" pos:[124,144] width:88 height:32 tooltip:"LMB: Select T-junction loops containing a T vertex on true mesh border topology."
    button btn_t_junction_mesh "T MESH" pos:[224,144] width:88 height:32 tooltip:"LMB: Select T-junction loops whose T vertices are all internal to the mesh."
    button btn_broken_t_fix "BROKEN T JUCTIONS SELECT \\ FIX" pos:[24,188] width:288 height:32 tooltip:"LMB: Select complete inner-border components containing a border vertex lying within 0.1 mm of another non-incident inner-border edge.\n\nRMB: Split the opposite border edge at the projected position, move the new vertex onto the T vertex, weld them, and verify the broken-T case count decreases."
    button btn_debug_all "1  SELECT ALL LOOPS" pos:[24,232] width:288 height:32 enabled:false tooltip:"Unused in the clean rewrite."
    button btn_debug_border "2  SELECT BORDER CORNER LOOPS" pos:[24,276] width:288 height:32 tooltip:"LMB: Select border-corner loop edges in SELECT REDUNDANT LOOPS."
    button btn_debug_wall_corner "3  SELECT WALL CORNER LOOP" pos:[24,320] width:288 height:32 tooltip:"LMB: Select wall-corner loop edges in SELECT REDUNDANT LOOPS."
    button btn_debug_angle "4  SELECT ANGLED LOOPS" pos:[24,364] width:288 height:32 enabled:false tooltip:"Unused in the clean rewrite."
    checkbox chk_quiet "QUIET" pos:[24,408] width:96 height:24 checked:true tooltip:"Reserved for the clean detector diagnostics."
    spinner spn_straight_angle "ANGLE:" pos:[24,444] width:144 range:[0.0,45.0,5.0] type:#float scale:0.1 fieldwidth:60 enabled:false tooltip:"Not used by SELECT in this build."
    label lbl_straight_units "deg" pos:[174,448] width:30 height:16
    button btn_get_angle "GET ANGLE" pos:[216,440] width:96 height:32 enabled:false tooltip:"Unused in the clean rewrite."

    on RedundantLoopFixer_UI open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Loop-Cleaner"
        ToolTitleButton.resizeToolTitleButton btn_tool_title (RedundantLoopFixer_UI.width - 24)
        btn_tool_title.height = 32
        chk_quiet.checked = RedundantLoopFixer.loadQuietMode()
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

    on btn_broken_t_fix pressed do
    (
        RedundantLoopFixer.selectBrokenTJunctionBorders()
    )

    on btn_broken_t_fix rightClick do
    (
        RedundantLoopFixer.fixBrokenTJunctionBorders()
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
