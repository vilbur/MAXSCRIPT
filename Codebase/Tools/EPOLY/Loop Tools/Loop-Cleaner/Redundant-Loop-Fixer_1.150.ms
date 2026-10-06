/*
    Redundant-Loop-Fixer 1.150
    Clean rewrite development build.
*/

global RedundantLoopFixer
global RedundantLoopFixer1150
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
    throw "Redundant-Loop-Fixer must be executed from a saved .ms file."
)

RedundantLoopFixer_Script_Reload_Path = (getFilenamePath RedundantLoopFixer_Source_File) + "..\\..\\..\\..\\UI\\Default\\ScriptReload.ms"
RedundantLoopFixer_Tool_Title_Button_Path = (getFilenamePath RedundantLoopFixer_Source_File) + "..\\..\\..\\..\\UI\\Default\\ToolTitleButton.ms"

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
                format "Redundant-Loop-Fixer UI POSITION ERROR | %\n" (getCurrentException())
            )

            try
            (
                destroyDialog RedundantLoopFixer_UI
            )
            catch
            (
                format "Redundant-Loop-Fixer UI CLOSE ERROR | %\n" (getCurrentException())
            )
        )
    )
)
catch
(
    format "Redundant-Loop-Fixer UI RESET ERROR | %\n" (getCurrentException())
)

struct RedundantLoopFixer1150_v
(
    file_version = 1.150,
    project_version = 1.150,
    quiet_mode = true,
    straight_angle_threshold = 5.0,
    geometry_corner_angle_threshold = 1.0,

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
            format "Redundant-Loop-Fixer DEAD TOPOLOGY CLEANED | flags:%\n" dead_flags
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

            format "Redundant-Loop-Fixer VISIBLE EDGE FILTER | edgeVisButNotSelectable:% | hiddenVertex:% | hiddenFace:% | other:%\n" blocked_visible_edges blocked_by_hidden_vertex blocked_by_hidden_face blocked_other
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
            format "Redundant-Loop-Fixer EDIT POLY BASE HAS DEAD TOPOLOGY | flags:% | base cleanup skipped to protect modifier indexing\n" dead_flags
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
            format "Redundant-Loop-Fixer SELECTOR VERIFY FAILED | requested:% | stored:% | missing:% | extra:%\n" redundant_edges stored_edges missing_edges extra_edges
        )

        #(selection_matches, selection_mod, created)
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
            messageBox "Select exactly one Editable Poly or active Edit Poly object." title:"Redundant-Loop-Fixer"
            return false
        )

        node = selection[1]
        debug_data = this.getDebugLoopAnalysis node

        if not debug_data[1] then
        (
            messageBox debug_data[5] title:"Redundant-Loop-Fixer"
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
            messageBox "Could not store the border-corner debug selection." title:"Redundant-Loop-Fixer"
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
            messageBox "Select exactly one Editable Poly or active Edit Poly object." title:"Redundant-Loop-Fixer"
            return false
        )

        node = selection[1]
        debug_data = this.getDebugLoopAnalysis node

        if not debug_data[1] then
        (
            messageBox debug_data[5] title:"Redundant-Loop-Fixer"
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
            messageBox "Could not store the wall-corner debug selection." title:"Redundant-Loop-Fixer"
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
            messageBox "Select exactly one Editable Poly or active Edit Poly object." title:"Redundant-Loop-Fixer"
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
                messageBox "Could not validate Editable Poly topology before reading component IDs." title:"Redundant-Loop-Fixer"
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
            messageBox "Make an Editable Poly base or an Edit Poly modifier current in the Modify panel." title:"Redundant-Loop-Fixer"
            return false
        )

        if analysis_poly == undefined or visible_edges == undefined then
        (
            messageBox "The current topology cannot be analyzed safely in this clean build. Activate the matching Editable Poly base or an Edit Poly whose topology still matches that base." title:"Redundant-Loop-Fixer"
            return false
        )

        detection = this.detectRedundantEditablePoly node analysis_poly visible_edges

        if detection == undefined then
        (
            messageBox "Redundant-loop detection failed while reading the current polygon topology." title:"Redundant-Loop-Fixer"
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
            messageBox "Could not store the detected edges in SELECT REDUNDANT LOOPS. See Listener for verification details." title:"Redundant-Loop-Fixer"
            return false
        )

        format "Redundant-Loop-Fixer SELECT COMPLETE | node:% | visible:% | border:% | internal:% | borderCorner:% | wallCorner:% | redundant:% | edges:%\n" node.name visible_edges.numberSet border_edges.numberSet internal_edges.numberSet border_corner_edges.numberSet wall_corner_edges.numberSet redundant_edges.numberSet redundant_edges

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
            messageBox "Select exactly one geometry object." title:"Redundant-Loop-Fixer"
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
            messageBox "No redundant loops were detected." title:"Redundant-Loop-Fixer"
            return false
        )

        if not this.activateSelectionModifier node selection_mod then
        (
            messageBox "Could not activate SELECT REDUNDANT LOOPS." title:"Redundant-Loop-Fixer"
            return false
        )

        selected_edges = copy (selection_mod.GetSelection #Edge)

        if selected_edges.numberSet == 0 then
        (
            messageBox "SELECT REDUNDANT LOOPS contains no selected edges." title:"Redundant-Loop-Fixer"
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
            format "Redundant-Loop-Fixer REMOVE VERIFY FAILED | node:% | verts:%->% | edges:%->%\n" node.name before_vertex_count after_vertex_count before_edge_count after_edge_count
            messageBox "Remove operation did not reduce topology. Undo is available." title:"Redundant-Loop-Fixer"
            return false
        )

        selection_mod.showCage = off
        selection_mod.name = "DELETED REDUNDANT LOOPS"
        selection_mod.RefreshScreen()
        completeRedraw()

        format "Redundant-Loop-Fixer REMOVE COMPLETE | node:% | removedSelection:% | verts:%->% | edges:%->%\n" node.name selected_edges.numberSet before_vertex_count after_vertex_count before_edge_count after_edge_count

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
        source_directory + "Redundant-Loop-Fixer.ini"
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
            format "Redundant-Loop-Fixer SETTINGS WRITE ERROR | dialog position | %\n" settings_error
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
            format "Redundant-Loop-Fixer SETTINGS WRITE ERROR | QUIET | %\n" settings_error
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
            format "Redundant-Loop-Fixer SETTINGS WRITE ERROR | ANGLE | %\n" settings_error
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
                    format "Redundant-Loop-Fixer HIDE UI ERROR | %\n" hide_error
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
        "Redundant-Loop-Fixer | v" + (epoly_tools_project_version as string)
        -- return
    ),

    on create do
    (
    )
)

RedundantLoopFixer1150 = RedundantLoopFixer1150_v()
RedundantLoopFixer = RedundantLoopFixer1150

if epoly_tools_project_version == undefined or epoly_tools_project_version < RedundantLoopFixer.project_version then
(
    epoly_tools_project_version = RedundantLoopFixer.project_version
)

RedundantLoopFixer_Title = "Redundant-Loop-Fixer | v" + (epoly_tools_project_version as string)

rollout RedundantLoopFixer_UI RedundantLoopFixer_Title width:336 height:356
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:312 height:32
    button btn_select_remove "USELESS LOOPS SELECT \\ REMOVE" pos:[24,56] width:288 height:32 tooltip:"LMB: Select visible internal edges after subtracting border-corner and wall-corner loop masks.\n\nRMB: Remove the exact stored redundant-edge selection and its redundant vertices."
    button btn_debug_all "1  SELECT ALL LOOPS" pos:[24,100] width:288 height:32 enabled:false tooltip:"Unused in the clean rewrite."
    button btn_debug_border "2  SELECT BORDER CORNER LOOPS" pos:[24,144] width:288 height:32 tooltip:"LMB: Select border-corner loop edges in SELECT REDUNDANT LOOPS."
    button btn_debug_wall_corner "3  SELECT WALL CORNER LOOP" pos:[24,188] width:288 height:32 tooltip:"LMB: Select wall-corner loop edges in SELECT REDUNDANT LOOPS."
    button btn_debug_angle "4  SELECT ANGLED LOOPS" pos:[24,232] width:288 height:32 enabled:false tooltip:"Unused in the clean rewrite."
    checkbox chk_quiet "QUIET" pos:[24,276] width:96 height:24 checked:true tooltip:"Reserved for the clean detector diagnostics."
    spinner spn_straight_angle "ANGLE:" pos:[24,312] width:144 range:[0.0,45.0,5.0] type:#float scale:0.1 fieldwidth:60 enabled:false tooltip:"Not used by SELECT in this build."
    label lbl_straight_units "deg" pos:[174,316] width:30 height:16
    button btn_get_angle "GET ANGLE" pos:[216,308] width:96 height:32 enabled:false tooltip:"Unused in the clean rewrite."

    on RedundantLoopFixer_UI open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Redundant-Loop-Fixer"
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
        restartTool RedundantLoopFixer_Source_File "Redundant-Loop-Fixer"
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
