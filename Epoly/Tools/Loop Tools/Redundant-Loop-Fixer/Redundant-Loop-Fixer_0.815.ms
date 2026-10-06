/*
    Redundant-Loop-Fixer 0.815
    Standalone simple detector for redundant isolated internal dividers and straight internal edge chains.
*/

global RedundantLoopFixer
global RedundantLoopFixer0815
global RedundantLoopFixer_UI
global RedundantLoopFixer_Dialog_Position
global RedundantLoopDetector_Test_UI
global EPolyToolsIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global epoly_tools_project_version

/*
Destroys a previous standalone dialog before this rollout is redefined.
The last standalone position is preserved across reloads.
*/
try
(
    if RedundantLoopFixer_UI != undefined then
    (
        if RedundantLoopFixer_UI.inDialog then
        (
            try(RedundantLoopFixer_Dialog_Position = getDialogPos RedundantLoopFixer_UI)catch(getCurrentException())
            try(destroyDialog RedundantLoopFixer_UI)catch(getCurrentException())
        )
    )

    if RedundantLoopDetector_Test_UI != undefined then
    (
        if RedundantLoopDetector_Test_UI.inDialog then
        (
            try(RedundantLoopFixer_Dialog_Position = getDialogPos RedundantLoopDetector_Test_UI)catch(getCurrentException())
            try(destroyDialog RedundantLoopDetector_Test_UI)catch(getCurrentException())
        )
    )
)
catch(getCurrentException())


struct RedundantLoopFixer0815_v
(
    file_version = 0.815,
    project_version = 1.118,
    face_angle_threshold = 0.1,
    near_face_angle_threshold = 1.0,
    straight_angle_threshold = 5.0,
    coincidence_tolerance = 0.001,
    crease_epsilon = 0.000001,
    latest_redundant_edges = #{},
    latest_redundant_node = undefined,
    latest_redundant_modifier = undefined,

    /*
    Forces Editable Poly and Edit Poly selection mode to normal component selection.
    Every selection read/write path in this tool uses selectMode 0.
    */
    function forceSelectModeZero editable_poly =
    (
        if editable_poly == undefined then return false

        select_mode_error = undefined

        try
        (
            editable_poly.selectMode = 0
        )
        catch
        (
            select_mode_error = getCurrentException()
        )

        if select_mode_error != undefined then
        (
            format "Redundant-Loop-Fixer SELECT MODE ERROR | %\n" select_mode_error
            false
        )
        else
        (
            true
        )
        -- return
    ),

    /*
    Returns the opposite vertex of an incident edge.
    Invalid topology returns undefined.
    */
    function getOtherVertex vertex_index edge_index edge_vertices =
    (
        if edge_index < 1 or edge_index > edge_vertices.count then return undefined

        edge_pair = edge_vertices[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return undefined

        if edge_pair[1] == vertex_index then
        (
            edge_pair[2]
        )
        else if edge_pair[2] == vertex_index then
        (
            edge_pair[1]
        )
        else
        (
            undefined
        )
        -- return
    ),

    /*
    Returns the geometric length of one analyzed topology edge.
    Invalid topology returns zero.
    */
    function getEdgeLength edge_index edge_vertices vertex_points =
    (
        if edge_index < 1 or edge_index > edge_vertices.count then return 0.0

        edge_pair = edge_vertices[edge_index]
        if edge_pair == undefined or edge_pair.count != 2 then return 0.0

        point_a = vertex_points[edge_pair[1]]
        point_b = vertex_points[edge_pair[2]]
        if point_a == undefined or point_b == undefined then return 0.0

        distance point_a point_b
        -- return
    ),

    /*
    Returns a normalized direction from one vertex along one incident edge.
    Zero-length edges return undefined.
    */
    function getEdgeDirection vertex_index edge_index edge_vertices vertex_points =
    (
        other_vertex = getOtherVertex vertex_index edge_index edge_vertices
        if other_vertex == undefined then return undefined

        direction_value = vertex_points[other_vertex] - vertex_points[vertex_index]
        if length direction_value <= 0.0000001 then return undefined

        normalize direction_value
        -- return
    ),

    /*
    Recursively pairs every edge with one opposite straight continuation.
    Backtracking avoids order-dependent rejection at crossings.
    */
    function canPairEdges vertex_index edge_array edge_vertices vertex_points straight_limit =
    (
        if edge_array.count == 0 then return true
        if (mod edge_array.count 2) != 0 then return false

        first_edge = edge_array[1]
        first_direction = getEdgeDirection vertex_index first_edge edge_vertices vertex_points
        if first_direction == undefined then return false

        for pair_index = 2 to edge_array.count do
        (
            pair_edge = edge_array[pair_index]
            pair_direction = getEdgeDirection vertex_index pair_edge edge_vertices vertex_points

            if pair_direction != undefined then
            (
                if (dot first_direction pair_direction) <= -straight_limit then
                (
                    remaining_edges = #()

                    for index = 2 to edge_array.count do
                    (
                        if index != pair_index then append remaining_edges edge_array[index]
                    )

                    if canPairEdges vertex_index remaining_edges edge_vertices vertex_points straight_limit then return true
                )
            )
        )

        false
        -- return
    ),

    /*
    Tests whether all supplied incident edges form straight-through opposite pairs.
    Empty input is accepted; odd or unmatched sets are rejected.
    */
    function areEdgesStraightPairs vertex_index edge_set edge_vertices vertex_points angle_threshold:5.0 =
    (
        if edge_set.numberSet == 0 then return true
        if (mod edge_set.numberSet 2) != 0 then return false

        canPairEdges vertex_index (edge_set as array) edge_vertices vertex_points (cos angle_threshold)
        -- return
    ),

    /*
    Returns the best straight-through score for a complete pairing of incident edges.
    A score of 1.0 is perfectly opposite; -2.0 means the edge set cannot be paired completely.
    */
    function getBestStraightPairScore vertex_index edge_array edge_vertices vertex_points =
    (
        if edge_array == undefined then return -2.0
        if edge_array.count == 0 then return 1.0
        if (mod edge_array.count 2) != 0 then return -2.0

        first_edge = edge_array[1]
        first_direction = this.getEdgeDirection vertex_index first_edge edge_vertices vertex_points
        if first_direction == undefined then return -2.0

        best_score = -2.0

        for pair_index = 2 to edge_array.count do
        (
            pair_edge = edge_array[pair_index]
            pair_direction = this.getEdgeDirection vertex_index pair_edge edge_vertices vertex_points

            if pair_direction != undefined then
            (
                pair_score = -(dot first_direction pair_direction)
                remaining_edges = #()

                for edge_array_index = 2 to edge_array.count do
                (
                    if edge_array_index != pair_index then append remaining_edges edge_array[edge_array_index]
                )

                remaining_score = this.getBestStraightPairScore vertex_index remaining_edges edge_vertices vertex_points

                if remaining_score > -2.0 then
                (
                    combined_score = if pair_score < remaining_score then pair_score else remaining_score
                    if combined_score > best_score then best_score = combined_score
                )
            )
        )

        best_score
        -- return
    ),

    /*
    Returns the straight-through score of the ring edges crossing one possible loop path at a vertex.
    The loop edges themselves are intentionally ignored, so the loop may turn around geometric corners.
    */
    function getRingStraightnessScore vertex_index loop_edges vertex_edges edge_vertices vertex_points =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return -2.0
        if loop_edges == undefined then return -2.0

        ring_edges = vertex_edges[vertex_index] - loop_edges
        this.getBestStraightPairScore vertex_index (ring_edges as array) edge_vertices vertex_points
        -- return
    ),

    /*
    Reads native Editable Poly topology without changing geometry.
    Vertex positions and face normals are captured in world space while native edge IDs are preserved.
    */
    function buildPolyTopology node poly_value =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if poly_value == undefined or classOf poly_value != Editable_Poly then return undefined

        vertex_count = polyop.getNumVerts poly_value
        edge_count = polyop.getNumEdges poly_value
        face_count = polyop.getNumFaces poly_value

        if vertex_count < 2 or edge_count < 1 or face_count < 1 then return undefined

        vertex_points = #()
        vertex_edges = #()
        vertex_faces = #()

        for vertex_index = 1 to vertex_count do
        (
            vertex_point = undefined

            in coordsys world
            (
                vertex_point = polyop.getVert poly_value vertex_index node:node
            )

            append vertex_points vertex_point
            append vertex_edges #{}
            append vertex_faces #{}
        )

        edge_vertices = #()
        edge_faces = #()
        border_edges = #{}
        border_vertices = #{}

        for edge_index = 1 to edge_count do
        (
            edge_pair = polyop.getEdgeVerts poly_value edge_index
            edge_face_array = polyop.getEdgeFaces poly_value edge_index

            edge_valid = edge_pair != undefined and edge_pair.count == 2
            if edge_valid then edge_valid = edge_pair[1] >= 1 and edge_pair[1] <= vertex_count and edge_pair[2] >= 1 and edge_pair[2] <= vertex_count

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

        for face_index = 1 to face_count do
        (
            face_vertices = polyop.getFaceVerts poly_value face_index
            face_normal = undefined

            if face_vertices != undefined and face_vertices.count >= 3 then
            (
                for vertex_index in face_vertices do
                (
                    if vertex_index >= 1 and vertex_index <= vertex_count then vertex_faces[vertex_index][face_index] = true
                )

                in coordsys world
                (
                    face_normal = polyop.getFaceNormal poly_value face_index node:node
                )

                if face_normal != undefined then
                (
                    if length face_normal > 0.0000001 then
                    (
                        face_normal = normalize face_normal
                        face_valid[face_index] = true
                    )
                    else
                    (
                        face_normal = undefined
                    )
                )
            )

            append face_normals face_normal
        )

        #(
            vertex_count,
            edge_count,
            face_count,
            vertex_points,
            vertex_edges,
            vertex_faces,
            edge_vertices,
            edge_faces,
            border_edges,
            border_vertices,
            face_normals,
            face_valid
        )
        -- return
    ),

    /*
    Returns explicit edge creases from Editable Poly edge-data channel 2.
    Unsupported crease data means that no explicit crease is present.
    */
    function getCreaseEdges poly_value edge_count =
    (
        crease_edges = #{}

        if polyop.getEDataChannelSupport poly_value 2 then
        (
            for edge_index = 1 to edge_count do
            (
                crease_value = polyop.getEDataValue poly_value 2 edge_index
                if crease_value != undefined and abs crease_value > crease_epsilon then crease_edges[edge_index] = true
            )
        )

        crease_edges
        -- return
    ),

    /*
    Acquires the evaluated top-of-stack geometry for read-only analysis.
    A modifier-free Editable Poly is read directly; any other stack is evaluated on a disposable collapsed copy.
    */
    function acquireAnalysisSource node =
    (
        if node == undefined or not(isValidNode node) then return undefined

        if classOf node.baseObject == Editable_Poly and node.modifiers.count == 0 then
        (
            node.baseObject.showCage = off
            if not(forceSelectModeZero node.baseObject) then return undefined
            #(node, node.baseObject, false)
        )
        else
        (
            temp_node = undefined
            result_data = undefined

            try
            (
                with undo off
                (
                    temp_node = copy node
                    temp_node.name = uniqueName "__REDUNDANT_LOOP_ANALYSIS__"
                    convertToPoly temp_node

                    if classOf temp_node.baseObject != Editable_Poly then throw "evaluated copy is not Editable Poly"
                    temp_node.baseObject.showCage = off
                    if not(forceSelectModeZero temp_node.baseObject) then throw "could not set evaluated Editable Poly selectMode to 0"
                    result_data = #(temp_node, temp_node.baseObject, true)
                )
            )
            catch
            (
                analysis_error = getCurrentException()

                if temp_node != undefined then
                (
                    try(delete temp_node)catch(getCurrentException())
                )

                format "Redundant-Loop-Fixer ANALYSIS ACQUIRE ERROR | node:% | %\n" node.name analysis_error
                result_data = undefined
            )

            result_data
        )
        -- return
    ),

    /*
    Releases only disposable analysis geometry.
    The user's original object is never deleted or collapsed.
    */
    function releaseAnalysisSource analysis_source =
    (
        if analysis_source == undefined then return false

        release_ok = true

        if analysis_source[3] then
        (
            analysis_node = analysis_source[1]

            if analysis_node != undefined and isValidNode analysis_node then
            (
                release_error = undefined

                with undo off
                (
                    try
                    (
                        delete analysis_node
                    )
                    catch
                    (
                        release_error = getCurrentException()
                    )
                )

                if release_error != undefined then
                (
                    format "Redundant-Loop-Fixer ANALYSIS RELEASE ERROR | %\n" release_error
                    release_ok = false
                )
            )
        )

        release_ok
        -- return
    ),

    /*
    Tests whether one border vertex is a clean straight-through border point.
    A border corner, border branch, missing continuation, or more than two border edges is rejected.
    */
    function isStraightBorderVertex vertex_index border_edges vertex_edges edge_vertices vertex_points angle_threshold:5.0 =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return false

        raw_border_edges = vertex_edges[vertex_index] * border_edges
        if raw_border_edges.numberSet != 2 then return false

        areEdgesStraightPairs vertex_index raw_border_edges edge_vertices vertex_points angle_threshold:angle_threshold
        -- return
    ),

    /*
    Tests whether one vertex is a true border corner or otherwise invalid border terminal.
    Any border incidence that is not exactly one straight-through pair is treated as a border corner condition.
    */
    function isBorderCornerVertex vertex_index border_edges vertex_edges edge_vertices vertex_points angle_threshold:5.0 =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return true

        raw_border_edges = vertex_edges[vertex_index] * border_edges
        if raw_border_edges.numberSet == 0 then return false

        not(isStraightBorderVertex vertex_index border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold)
        -- return
    ),

    /*
    Collects border corner and border branch vertices before any internal loop tracing.
    Straight-through border vertices are excluded from this seed set.
    */
    function getBorderCornerVertices topology_data angle_threshold:1.0 =
    (
        border_corner_vertices = #{}
        if topology_data == undefined then return border_corner_vertices

        border_edges = topology_data[9]
        vertex_edges = topology_data[5]
        edge_vertices = topology_data[7]
        vertex_points = topology_data[4]

        for vertex_index = 1 to vertex_edges.count do
        (
            if isBorderCornerVertex vertex_index border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold then
            (
                border_corner_vertices[vertex_index] = true
            )
        )

        border_corner_vertices
        -- return
    ),

    /*
    Traces one candidate loop outward from one border corner seed edge.
    The corner itself is the loop start; later continuation follows the straightest ring-edge pairing while the loop itself may turn freely around corners.
    */
    function traceLoopFromBorderCorner corner_vertex seed_edge topology_data candidate_edges border_corner_vertices max_turn_threshold:45.0 =
    (
        empty_record = #(#{}, corner_vertex, corner_vertex)
        if topology_data == undefined then return empty_record
        if corner_vertex < 1 or corner_vertex > topology_data[5].count then return empty_record
        if seed_edge < 1 or seed_edge > topology_data[7].count then return empty_record
        if not candidate_edges[seed_edge] then return empty_record

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        edge_vertices = topology_data[7]
        seed_pair = edge_vertices[seed_edge]

        if seed_pair == undefined or seed_pair.count != 2 then return empty_record

        next_vertex = getOtherVertex corner_vertex seed_edge edge_vertices
        if next_vertex == undefined then return empty_record

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

                next_edge = this.getBestLoopContinuation current_edge current_vertex available_edges vertex_edges edge_vertices vertex_points ring_limit

                if next_edge == undefined then
                (
                    walking = false
                )
                else
                (
                    chain_edges[next_edge] = true
                    next_vertex = getOtherVertex current_vertex next_edge edge_vertices

                    if next_vertex == undefined then
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
    Builds all border-corner loops before generic loop partitioning.
    Every candidate edge leaving every border corner/branch is traced independently by ring-edge continuity, so a loop may go around geometric corners without merging unrelated branches.
    */
    function buildBorderCornerLoopRecords topology_data candidate_edges max_turn_threshold:45.0 =
    (
        border_corner_records = #()
        if topology_data == undefined then return border_corner_records

        vertex_edges = topology_data[5]
        border_corner_vertices = getBorderCornerVertices topology_data angle_threshold:1.0
        record_keys = #()

        for corner_vertex in border_corner_vertices do
        (
            incident_candidates = vertex_edges[corner_vertex] * candidate_edges

            for seed_edge in incident_candidates do
            (
                loop_record = traceLoopFromBorderCorner corner_vertex seed_edge topology_data candidate_edges border_corner_vertices max_turn_threshold:max_turn_threshold

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
    Tests one welded/triangulated open-border terminal.
    The border pair must remain straight through the terminal; one extra internal support edge is allowed only when it and the chain edge close through one border bridge edge.
    */
    function isValidTriangulatedOpenBorderTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:5.0 =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return false
        if chain_incident_edges.numberSet != 1 then return false
        if not(isStraightBorderVertex vertex_index border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold) then return false

        raw_edges = vertex_edges[vertex_index]
        raw_chain_edges = raw_edges * chain_incident_edges
        raw_border_edges = raw_edges * border_edges

        if raw_chain_edges.numberSet != 1 then return false
        if raw_border_edges.numberSet != 2 then return false
        if raw_edges.numberSet != 4 then return false

        extra_edges = raw_edges - raw_chain_edges - raw_border_edges
        if extra_edges.numberSet != 1 then return false

        chain_edge = (raw_chain_edges as array)[1]
        extra_edge = (extra_edges as array)[1]
        chain_other_vertex = getOtherVertex vertex_index chain_edge edge_vertices
        extra_other_vertex = getOtherVertex vertex_index extra_edge edge_vertices

        if chain_other_vertex == undefined or extra_other_vertex == undefined then return false
        if chain_other_vertex < 1 or chain_other_vertex > vertex_edges.count then return false
        if extra_other_vertex < 1 or extra_other_vertex > vertex_edges.count then return false

        bridge_edges = vertex_edges[chain_other_vertex] * vertex_edges[extra_other_vertex] * border_edges
        bridge_edges.numberSet == 1
        -- return
    ),

    /*
    Tests one open-border terminal.
    Every border terminal requires a straight-through border pair; a welded border triangle may add one internal support edge but can never bypass the straight-border rule.
    */
    function isValidOpenBorderTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:5.0 =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return false
        if chain_incident_edges.numberSet != 1 then return false

        raw_edges = vertex_edges[vertex_index]
        raw_chain_edges = raw_edges * chain_incident_edges
        raw_border_edges = raw_edges * border_edges

        if raw_chain_edges.numberSet != 1 then return false
        if raw_border_edges.numberSet != 2 then return false
        if not(isStraightBorderVertex vertex_index border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold) then return false

        if raw_edges.numberSet == 3 then
        (
            isStraightBorderVertex vertex_index border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold
        )
        else
        (
            isValidTriangulatedOpenBorderTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold
        )
        -- return
    ),

    /*
    Tests one internal straight T-junction or crossing terminal.
    Exactly one chain edge is allowed and every remaining edge must be consumed by straight-through opposite pairs.
    */
    function isValidInternalTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:5.0 =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return false
        if chain_incident_edges.numberSet != 1 then return false

        raw_edges = vertex_edges[vertex_index]
        if (raw_edges * border_edges).numberSet > 0 then return false

        raw_chain_edges = raw_edges * chain_incident_edges
        if raw_chain_edges.numberSet != 1 then return false

        remaining_edges = raw_edges - raw_chain_edges
        if remaining_edges.numberSet < 2 then return false

        areEdgesStraightPairs vertex_index remaining_edges edge_vertices vertex_points angle_threshold:angle_threshold
        -- return
    ),

    /*
    Tests one legal chain terminal.
    Any border incidence forces the strict open-border rule, so a border corner can never fall through to an internal terminal rule.
    */
    function isValidTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:5.0 =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return false
        if chain_incident_edges.numberSet != 1 then return false

        raw_border_edges = vertex_edges[vertex_index] * border_edges

        if raw_border_edges.numberSet > 0 then
        (
            isValidOpenBorderTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold
        )
        else
        (
            isValidInternalTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold
        )
        -- return
    ),

    /*
    Tests one internal loop vertex using only the ring/transverse edges crossing the loop.
    The incoming/outgoing loop edges may form any corner; only the remaining ring edges must pair straight within ANGLE.
    */
    function isValidInternalVertex vertex_index incoming_edge outgoing_edge border_edges vertex_edges edge_vertices vertex_points angle_threshold:5.0 =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return false

        raw_edges = vertex_edges[vertex_index]
        if (raw_edges * border_edges).numberSet > 0 then return false

        chain_pair = #{}
        chain_pair[incoming_edge] = true
        chain_pair[outgoing_edge] = true

        raw_chain_edges = raw_edges * chain_pair
        if raw_chain_edges.numberSet != 2 then return false

        transverse_edges = raw_edges - raw_chain_edges

        if transverse_edges.numberSet > 0 then
        (
            if not(areEdgesStraightPairs vertex_index transverse_edges edge_vertices vertex_points angle_threshold:angle_threshold) then return false
        )

        true
        -- return
    ),

    /*
    Classifies every live face incident to one chain vertex against the chain reference plane orientation.
    Faces beyond the flat threshold but within the near-flat threshold are accepted and returned in a BitArray.
    */
    function getVertexPlanarity vertex_index vertex_faces face_normals face_valid reference_normal flat_threshold:0.1 near_threshold:1.0 =
    (
        near_faces = #{}

        if vertex_index < 1 or vertex_index > vertex_faces.count then return #(false, near_faces)
        if reference_normal == undefined then return #(false, near_faces)

        flat_limit = cos flat_threshold
        near_limit = cos near_threshold
        incident_face_count = 0

        for face_index in vertex_faces[vertex_index] do
        (
            if face_index < 1 or face_index > face_normals.count then return #(false, near_faces)
            if face_index > face_valid.count or not face_valid[face_index] then return #(false, near_faces)

            face_normal = face_normals[face_index]
            if face_normal == undefined then return #(false, near_faces)

            incident_face_count += 1
            face_dot = abs(dot reference_normal face_normal)

            if face_dot < near_limit then return #(false, near_faces)
            if face_dot < flat_limit then near_faces[face_index] = true
        )

        #(incident_face_count > 0, near_faces)
        -- return
    ),

    /*
    Verifies one chain vertex while allowing near-flat incident faces up to the supplied tolerance.
    */
    function isVertexPlanar vertex_index vertex_faces face_normals face_valid reference_normal angle_threshold:0.1 near_threshold:1.0 =
    (
        planarity = getVertexPlanarity vertex_index vertex_faces face_normals face_valid reference_normal flat_threshold:angle_threshold near_threshold:near_threshold
        planarity[1]
        -- return
    ),

    /*
    Builds the simple internal edge candidate set used by loop traversal.
    Candidates are non-border, non-crease, non-zero-length edges with two adjacent faces; face coplanarity is not part of loop selection.
    */
    function buildCandidateEdges topology_data crease_edges =
    (
        edge_count = topology_data[2]
        face_count = topology_data[3]
        vertex_points = topology_data[4]
        edge_vertices = topology_data[7]
        edge_faces = topology_data[8]
        border_edges = topology_data[9]

        candidate_edges = #{}

        for edge_index = 1 to edge_count do
        (
            edge_pair = edge_vertices[edge_index]
            face_pair = edge_faces[edge_index]

            if edge_pair != undefined and edge_pair.count == 2 and face_pair != undefined and face_pair.count == 2 then
            (
                if not border_edges[edge_index] and not crease_edges[edge_index] then
                (
                    if getEdgeLength edge_index edge_vertices vertex_points > 0.0000001 then
                    (
                        face_a = face_pair[1]
                        face_b = face_pair[2]

                        if face_a > 0 and face_b > 0 and face_a <= face_count and face_b <= face_count then
                        (
                            candidate_edges[edge_index] = true
                        )
                    )
                )
            )
        )

        candidate_edges
        -- return
    ),

    /*
    Returns true when a vertex is on the mesh border.
    Any accepted loop component containing such a vertex is rejected as a whole.
    */
    function vertexTouchesBorder vertex_index vertex_edges border_edges =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return true
        ((vertex_edges[vertex_index] * border_edges).numberSet > 0)
        -- return
    ),

    /*
    Finds the connected candidate edge that leaves the straightest ring-edge pairing at one loop vertex.
    The angle between the incoming and outgoing loop edges is ignored, so a valid loop may turn around a corner.
    */
    function getBestLoopContinuation edge_index vertex_index candidate_edges vertex_edges edge_vertices vertex_points straight_limit =
    (
        if vertex_index < 1 or vertex_index > vertex_edges.count then return undefined

        incident_candidates = copy (vertex_edges[vertex_index] * candidate_edges)
        incident_candidates[edge_index] = false

        best_edge = undefined
        best_ring_score = -3.0

        for neighbor_edge in incident_candidates do
        (
            loop_pair = #{}
            loop_pair[edge_index] = true
            loop_pair[neighbor_edge] = true
            ring_score = this.getRingStraightnessScore vertex_index loop_pair vertex_edges edge_vertices vertex_points

            if ring_score > best_ring_score then
            (
                best_ring_score = ring_score
                best_edge = neighbor_edge
            )
        )

        if best_edge != undefined and best_ring_score >= straight_limit then best_edge else undefined
        -- return
    ),

    /*
    Tests one single-edge redundant divider with the same local-coplanarity and terminal rules used by longer chains.
    This helper is diagnostic only; normal detection traverses single-edge and multi-edge chains through one common path.
    */
    function isValidIsolatedDivider edge_index candidate_edges topology_data face_threshold:0.1 near_face_threshold:1.0 straight_threshold:5.0 =
    (
        if edge_index < 1 or edge_index > topology_data[2] then return false
        if not candidate_edges[edge_index] then return false

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        vertex_faces = topology_data[6]
        edge_vertices = topology_data[7]
        edge_faces = topology_data[8]
        border_edges = topology_data[9]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        edge_pair = edge_vertices[edge_index]
        face_pair = edge_faces[edge_index]

        if edge_pair == undefined or edge_pair.count != 2 then return false
        if face_pair == undefined or face_pair.count != 2 then return false

        face_a = face_pair[1]
        face_b = face_pair[2]

        if face_a < 1 or face_b < 1 then return false
        if face_a > face_normals.count or face_b > face_normals.count then return false
        if not face_valid[face_a] or not face_valid[face_b] then return false

        reference_normal = face_normals[face_a]
        if reference_normal == undefined then return false

        single_edge = #{}
        single_edge[edge_index] = true

        for vertex_index in edge_pair do
        (
            other_candidates = (vertex_edges[vertex_index] * candidate_edges) - single_edge
            if other_candidates.numberSet > 0 then return false

            if not(isValidTerminal vertex_index single_edge border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold) then return false
        )

        true
        -- return
    ),

    /*
    Validates a completed chain by local divider coplanarity plus straight terminal/internal topology.
    Surface normal drift along the chain is allowed; only each divider edge's own adjacent faces must remain locally coplanar.
    */
    function validateChain chain_edges chain_vertices start_vertex end_vertex candidate_edges topology_data face_threshold:0.1 near_face_threshold:1.0 straight_threshold:5.0 =
    (
        if chain_edges.numberSet == 0 then return #(false, "empty chain")
        if chain_vertices.count < 2 then return #(false, "chain has fewer than two vertices")
        if start_vertex == end_vertex then return #(false, "chain returns to its start")
        if (chain_edges - candidate_edges).numberSet > 0 then return #(false, "chain contains a non-candidate edge")

        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        edge_vertices = topology_data[7]
        edge_faces = topology_data[8]
        border_edges = topology_data[9]
        face_normals = topology_data[11]
        face_valid = topology_data[12]
        near_faces = #{}
        flat_limit = cos face_threshold
        near_limit = cos near_face_threshold

        for vertex_index in chain_vertices do
        (
            chain_incident_edges = vertex_edges[vertex_index] * chain_edges
            is_endpoint = vertex_index == start_vertex or vertex_index == end_vertex

            if is_endpoint then
            (
                if not(isValidTerminal vertex_index chain_incident_edges border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold) then
                (
                    return #(false, "invalid terminal topology at vertex " + (vertex_index as string))
                )
            )
            else
            (
                if chain_incident_edges.numberSet != 2 then return #(false, "internal vertex does not have exactly two chain edges at vertex " + (vertex_index as string))

                chain_pair = chain_incident_edges as array

                if not(isValidInternalVertex vertex_index chain_pair[1] chain_pair[2] border_edges vertex_edges edge_vertices vertex_points angle_threshold:straight_threshold) then
                (
                    return #(false, "invalid internal branch topology at vertex " + (vertex_index as string))
                )
            )
        )

        for edge_index in chain_edges do
        (
            face_pair = edge_faces[edge_index]

            if face_pair != undefined and face_pair.count == 2 then
            (
                face_a = face_pair[1]
                face_b = face_pair[2]

                if face_a >= 1 and face_a <= face_normals.count and face_b >= 1 and face_b <= face_normals.count then
                (
                    if face_a <= face_valid.count and face_b <= face_valid.count and face_valid[face_a] and face_valid[face_b] then
                    (
                        face_dot = abs(dot face_normals[face_a] face_normals[face_b])

                        if face_dot < near_limit then return #(false, "chain contains a non-coplanar divider edge " + (edge_index as string), near_faces)

                        if face_dot < flat_limit then
                        (
                            near_faces[face_a] = true
                            near_faces[face_b] = true
                        )
                    )
                )
            )
        )

        #(true, "", near_faces)
        -- return
    ),

    /*
    Creates a stable key for duplicate suppression when the same chain is traversed from both terminals.
    BitArray iteration keeps edge IDs sorted automatically.
    */
    function makeChainKey chain_edges =
    (
        key_text = ""
        for edge_index in chain_edges do key_text += (edge_index as string) + ","
        key_text
        -- return
    ),

    /*
    Builds complete candidate loop/chain records before border-corner and ANGLE filtering.
    Every candidate edge belongs to at most one record, and branch continuation chooses the path that leaves the straightest ring-edge pairing; turns along the loop are ignored.
    */
    function buildLoopRecordsFromTopology topology_data candidate_edges =
    (
        loop_records = #()
        remaining_edges = copy candidate_edges
        vertex_points = topology_data[4]
        vertex_edges = topology_data[5]
        edge_vertices = topology_data[7]

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
                            next_edge = getBestLoopContinuation current_edge current_vertex remaining_edges vertex_edges edge_vertices vertex_points -2.0

                            if next_edge == undefined then
                            (
                                walking = false
                            )
                            else
                            (
                                chain_edges[next_edge] = true
                                remaining_edges[next_edge] = false
                                next_vertex = getOtherVertex current_vertex next_edge edge_vertices

                                if next_vertex == undefined then
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
    Returns true when one internal candidate edge separates two different wall planes.
    Opposite face normals are treated as the same plane; the supplied face-angle threshold is explicit.
    */
    function edgeSeparatesWallPlanes edge_index topology_data wall_angle_threshold =
    (
        if topology_data == undefined then return false

        edge_faces = topology_data[8]
        face_normals = topology_data[11]
        face_valid = topology_data[12]

        if edge_faces == undefined or face_normals == undefined or face_valid == undefined then return false
        if edge_index < 1 or edge_index > edge_faces.count then return false

        face_pair = edge_faces[edge_index]
        if face_pair == undefined or face_pair.count != 2 then return false

        face_a = face_pair[1]
        face_b = face_pair[2]

        if face_a < 1 or face_b < 1 or face_a > face_normals.count or face_b > face_normals.count then return false
        if face_a > face_valid.count or face_b > face_valid.count then return false
        if not face_valid[face_a] or not face_valid[face_b] then return false

        normal_a = face_normals[face_a]
        normal_b = face_normals[face_b]
        if normal_a == undefined or normal_b == undefined then return false

        face_dot = abs(dot normal_a normal_b)
        face_dot < (cos wall_angle_threshold)
        -- return
    ),

    /*
    Builds debug-only wall-corner loop records from candidate edges whose adjacent face normals belong to different wall planes.
    The existing loop tracer groups those wall-corner edges; production redundant-loop filtering is not changed.
    */
    function buildWallCornerLoopRecords topology_data candidate_edges wall_angle_threshold =
    (
        wall_corner_edges = #{}
        if topology_data == undefined or candidate_edges == undefined then return #()

        for edge_index in candidate_edges do
        (
            if this.edgeSeparatesWallPlanes edge_index topology_data wall_angle_threshold then
            (
                wall_corner_edges[edge_index] = true
            )
        )

        if wall_corner_edges.numberSet == 0 then return #()
        this.buildLoopRecordsFromTopology topology_data wall_corner_edges
        -- return
    ),

    /*
    Returns true when any vertex used by one complete loop/chain is a border corner or border branch.
    Straight-through border vertices remain valid even when they occur inside the traced chain.
    */
    function loopRecordTouchesBorderCorner loop_record topology_data =
    (
        if loop_record == undefined or loop_record.count < 1 then return false
        if topology_data == undefined then return false

        chain_edges = loop_record[1]
        border_edges = topology_data[9]
        vertex_edges = topology_data[5]
        edge_vertices = topology_data[7]
        vertex_points = topology_data[4]
        tested_vertices = #{}

        for edge_index in chain_edges do
        (
            if edge_index >= 1 and edge_index <= edge_vertices.count then
            (
                edge_pair = edge_vertices[edge_index]

                if edge_pair != undefined and edge_pair.count == 2 then
                (
                    for vertex_index in edge_pair do
                    (
                        if not tested_vertices[vertex_index] then
                        (
                            tested_vertices[vertex_index] = true

                            if isBorderCornerVertex vertex_index border_edges vertex_edges edge_vertices vertex_points angle_threshold:1.0 then return true
                        )
                    )
                )
            )
        )

        false
        -- return
    ),

    /*
    Returns true when the ring edges crossing every vertex of one complete loop stay within ANGLE.
    The loop edges may turn by any amount; ANGLE applies only to the non-loop ring edges left at each loop vertex.
    */
    function loopRecordWithinAngle loop_record topology_data angle_threshold =
    (
        if loop_record == undefined or loop_record.count < 1 then return false
        if topology_data == undefined then return false

        chain_edges = loop_record[1]
        vertex_edges = topology_data[5]
        edge_vertices = topology_data[7]
        vertex_points = topology_data[4]
        ring_limit = cos angle_threshold

        for vertex_index = 1 to vertex_edges.count do
        (
            chain_incident_edges = vertex_edges[vertex_index] * chain_edges

            if chain_incident_edges.numberSet > 0 then
            (
                if chain_incident_edges.numberSet > 2 then return false

                ring_score = this.getRingStraightnessScore vertex_index chain_incident_edges vertex_edges edge_vertices vertex_points
                if ring_score < ring_limit then return false
            )
        )

        true
        -- return
    ),

    /*
    Detects internal edge loops using topology, border exclusion, crease exclusion, and ANGLE on ring edges crossing each loop vertex.
    Turns along the loop are ignored; face coplanarity and old chain-direction angle gates do not participate.
    */
    function detectRedundantLoops node face_threshold:0.1 near_face_threshold:1.0 straight_threshold:5.0 debug_output:false =
    (
        accepted_records = #()
        redundant_edges = #{}
        analysis_source = acquireAnalysisSource node

        if analysis_source == undefined then return #(false, accepted_records, redundant_edges, "could not acquire evaluated Editable Poly topology", undefined)

        analysis_node = analysis_source[1]
        analysis_poly = analysis_source[2]
        topology_data = buildPolyTopology analysis_node analysis_poly

        if topology_data == undefined then
        (
            releaseAnalysisSource analysis_source
            return #(false, accepted_records, redundant_edges, "could not read evaluated Editable Poly topology", undefined)
        )

        crease_edges = getCreaseEdges analysis_poly topology_data[2]
        candidate_edges = buildCandidateEdges topology_data crease_edges
        border_corner_records = buildBorderCornerLoopRecords topology_data candidate_edges max_turn_threshold:45.0
        border_corner_edges = #{}

        for border_corner_record in border_corner_records do
        (
            border_corner_edges += border_corner_record[1]

            if debug_output then
            (
                format "REJECT BORDER CORNER LOOP | node:% | startVertex:% | edges:%\n" node.name border_corner_record[2] border_corner_record[1]
            )
        )

        clean_candidate_edges = candidate_edges - border_corner_edges
        loop_records = buildLoopRecordsFromTopology topology_data clean_candidate_edges

        for loop_record in loop_records do
        (
            reject_angle = not(loopRecordWithinAngle loop_record topology_data straight_threshold)

            if not reject_angle then
            (
                append accepted_records loop_record
                redundant_edges += loop_record[1]

                if debug_output then
                (
                    format "REDUNDANT LOOP | node:% | edges:%\n" node.name loop_record[1]
                )
            )
            else if debug_output then
            (
                format "REJECT RING-ANGLED LOOP | node:% | angle:% | edges:%\n" node.name straight_threshold loop_record[1]
            )
        )

        releaseAnalysisSource analysis_source
        #(true, accepted_records, redundant_edges, "", topology_data)
        -- return
    ),

    /*
    Builds generic candidate-loop records plus independent border-corner and wall-corner debug records.
    Returns #(success, records, topology_data, error_text, border_corner_records, wall_corner_records).
    */
    function buildDebugLoopRecords node =
    (
        loop_records = #()
        border_corner_records = #()
        wall_corner_records = #()
        analysis_source = acquireAnalysisSource node

        if analysis_source == undefined then return #(false, loop_records, undefined, "could not acquire evaluated Editable Poly topology", border_corner_records, wall_corner_records)

        analysis_node = analysis_source[1]
        analysis_poly = analysis_source[2]
        topology_data = buildPolyTopology analysis_node analysis_poly

        if topology_data == undefined then
        (
            releaseAnalysisSource analysis_source
            return #(false, loop_records, undefined, "could not read evaluated Editable Poly topology", border_corner_records, wall_corner_records)
        )

        crease_edges = getCreaseEdges analysis_poly topology_data[2]
        candidate_edges = buildCandidateEdges topology_data crease_edges
        loop_records = buildLoopRecordsFromTopology topology_data candidate_edges
        border_corner_records = buildBorderCornerLoopRecords topology_data candidate_edges max_turn_threshold:45.0
        wall_corner_records = buildWallCornerLoopRecords topology_data candidate_edges near_face_angle_threshold

        releaseAnalysisSource analysis_source
        #(true, loop_records, topology_data, "", border_corner_records, wall_corner_records)
        -- return
    ),

    /*
    Returns true when any vertex in a debug chain touches a border corner or border branch.
    Straight-through border vertices remain valid.
    */
    function debugChainTouchesBorderCorner loop_record topology_data =
    (
        loopRecordTouchesBorderCorner loop_record topology_data
        -- return
    ),

    /*
    Returns true when every two-edge turn inside one debug chain stays within ANGLE.
    Endpoints are not tested because they have only one chain edge.
    */
    function debugChainWithinAngle loop_record topology_data angle_threshold =
    (
        loopRecordWithinAngle loop_record topology_data angle_threshold
        -- return
    ),

    /*
    Writes one complete debug Edge BitArray into the dedicated SELECT REDUNDANT LOOPS modifier.
    */
    function writeDebugEdgeSelection node edge_bits =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, "invalid node")

        selection_modifier = undefined
        created_now = false
        previous_edge_selection = undefined
        operation_error = undefined
        rollback_error = undefined

        try
        (
            modifier_data = this.acquireSelectionModifier node
            selection_modifier = modifier_data[1]
            created_now = modifier_data[2]

            if selection_modifier == undefined then throw "could not acquire SELECT REDUNDANT LOOPS"
            if not(this.activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT LOOPS"

            if not created_now then previous_edge_selection = copy (selection_modifier.GetSelection #Edge node:node)

            current_edge_selection = copy (selection_modifier.GetSelection #Edge node:node)

            if current_edge_selection.numberSet > 0 then
            (
                selection_modifier.Select #Edge current_edge_selection select:false node:node
            )

            if edge_bits.numberSet > 0 then
            (
                selection_modifier.Select #Edge edge_bits select:true node:node
            )

            update node
            stored_selection = copy (selection_modifier.GetSelection #Edge node:node)
            if stored_selection != edge_bits then throw "debug edge selection storage mismatch"

            selection_modifier.showCage = false
            selection_modifier.RefreshScreen()
            completeRedraw()
        )
        catch
        (
            operation_error = getCurrentException()

            if selection_modifier != undefined then
            (
                if created_now then
                (
                    try
                    (
                        deleteModifier node selection_modifier
                        selection_modifier = undefined
                    )
                    catch
                    (
                        rollback_error = getCurrentException()
                    )
                )
                else if previous_edge_selection != undefined then
                (
                    try
                    (
                        if not(this.activateSelectionModifier node selection_modifier) then
                        (
                            rollback_error = "could not reactivate debug selector during rollback"
                        )
                        else
                        (
                            current_edges = copy (selection_modifier.GetSelection #Edge node:node)
                            if current_edges.numberSet > 0 then selection_modifier.Select #Edge current_edges select:false node:node
                            if previous_edge_selection.numberSet > 0 then selection_modifier.Select #Edge previous_edge_selection select:true node:node
                            restored_edges = copy (selection_modifier.GetSelection #Edge node:node)

                            if restored_edges != previous_edge_selection then
                            (
                                rollback_error = "debug rollback selection verification failed"
                            )
                        )
                    )
                    catch
                    (
                        rollback_error = getCurrentException()
                    )
                )
            )
        )

        if rollback_error != undefined then
        (
            format "Redundant-Loop-Fixer DEBUG ROLLBACK ERROR | node:% | %\n" node.name rollback_error
            operation_error = (operation_error as string) + " | rollback failed: " + (rollback_error as string)
        )

        if operation_error == undefined then #(true, edge_bits.numberSet, "") else #(false, 0, operation_error as string)
        -- return
    ),

    /*
    DEBUG 1: selects every internal candidate chain before border-corner or ANGLE filtering.
    */
    function debugSelectAllLoops =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one geometry object." title:"Redundant-Loop-Fixer"
            return false
        )

        node = selection[1]
        debug_data = buildDebugLoopRecords node

        if not debug_data[1] then
        (
            messageBox debug_data[4] title:"Redundant-Loop-Fixer"
            return false
        )

        debug_edges = #{}
        for loop_record in debug_data[2] do debug_edges += loop_record[1]

        write_result = writeDebugEdgeSelection node debug_edges

        if write_result[1] then
        (
            format "DEBUG 1 ALL LOOPS | node:% | loops:% | edges:%\n" node.name debug_data[2].count write_result[2]
            true
        )
        else
        (
            messageBox write_result[3] title:"Redundant-Loop-Fixer"
            false
        )
        -- return
    ),

    /*
    DEBUG 2: finds border corners first and selects every candidate loop traced outward from them.
    Each candidate branch leaving one corner is independent, so horizontal and vertical launches are both selected.
    */
    function debugSelectBorderCornerLoops =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one geometry object." title:"Redundant-Loop-Fixer"
            return false
        )

        node = selection[1]
        debug_data = buildDebugLoopRecords node

        if not debug_data[1] then
        (
            messageBox debug_data[4] title:"Redundant-Loop-Fixer"
            return false
        )

        border_corner_edges = #{}
        border_corner_loops = debug_data[5].count

        for loop_record in debug_data[5] do
        (
            border_corner_edges += loop_record[1]
        )

        write_result = writeDebugEdgeSelection node border_corner_edges

        if write_result[1] then
        (
            format "DEBUG 2 BORDER CORNER LOOPS | node:% | loops:% | edges:%\n" node.name border_corner_loops write_result[2]
            true
        )
        else
        (
            messageBox write_result[3] title:"Redundant-Loop-Fixer"
            false
        )
        -- return
    ),

    /*
    DEBUG 4: selects internal candidate loops that lie on wall corners where adjacent face normals belong to different planes.
    This diagnostic uses the existing near-face angle threshold and does not change production filtering.
    */
    function debugSelectWallCornerLoops =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one geometry object." title:"Redundant-Loop-Fixer"
            return false
        )

        node = selection[1]
        debug_data = buildDebugLoopRecords node

        if not debug_data[1] then
        (
            messageBox debug_data[4] title:"Redundant-Loop-Fixer"
            return false
        )

        wall_corner_edges = #{}
        wall_corner_loops = debug_data[6].count

        for loop_record in debug_data[6] do
        (
            wall_corner_edges += loop_record[1]
        )

        write_result = writeDebugEdgeSelection node wall_corner_edges

        if write_result[1] then
        (
            format "DEBUG 4 WALL CORNER LOOPS | node:% | faceAngle:% | loops:% | edges:%\n" node.name near_face_angle_threshold wall_corner_loops write_result[2]
            true
        )
        else
        (
            messageBox write_result[3] title:"Redundant-Loop-Fixer"
            false
        )
        -- return
    ),

    /*
    DEBUG 3: removes complete chains containing a turn greater than the current ANGLE spinner value.
    */
    function debugDeselectAngledLoops angle_threshold =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one geometry object." title:"Redundant-Loop-Fixer"
            return false
        )

        node = selection[1]
        debug_data = buildDebugLoopRecords node

        if not debug_data[1] then
        (
            messageBox debug_data[4] title:"Redundant-Loop-Fixer"
            return false
        )

        selected_edges = this.getCurrentSelectedEdges node

        if selected_edges == undefined then
        (
            messageBox "Could not read the current edge selection." title:"Redundant-Loop-Fixer"
            return false
        )

        removed_edges = #{}
        removed_loops = 0

        for loop_record in debug_data[2] do
        (
            if not(debugChainWithinAngle loop_record debug_data[3] angle_threshold) then
            (
                affected_edges = selected_edges * loop_record[1]

                if affected_edges.numberSet > 0 then
                (
                    selected_edges -= loop_record[1]
                    removed_edges += affected_edges
                    removed_loops += 1
                )
            )
        )

        write_result = writeDebugEdgeSelection node selected_edges

        if write_result[1] then
        (
            format "DEBUG 3 ANGLE | node:% | angle:% | removedLoops:% | removedEdges:% | remaining:%\n" node.name angle_threshold removed_loops removed_edges.numberSet write_result[2]
            true
        )
        else
        (
            messageBox write_result[3] title:"Redundant-Loop-Fixer"
            false
        )
        -- return
    ),

    /*
    Returns the currently selected edge IDs from the active Editable Poly or Edit Poly object.
    The selection source is never inferred from a debug spinner.
    */
    function getCurrentSelectedEdges node =
    (
        if node == undefined or not(isValidNode node) then return undefined

        current_object = undefined
        current_object_error = undefined

        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            current_object_error = getCurrentException()
        )

        if current_object_error != undefined then
        (
            format "Redundant-Loop-Fixer CURRENT OBJECT READ ERROR | node:% | %\n" node.name current_object_error
        )

        if current_object != undefined and classOf current_object == Edit_Poly then
        (
            current_on_node = false

            for modifier_index = 1 to node.modifiers.count while not current_on_node do
            (
                if node.modifiers[modifier_index] == current_object then current_on_node = true
            )

            if current_on_node then
            (
                if not(forceSelectModeZero current_object) then return undefined

                selection_error = undefined
                selected_edges = undefined

                try
                (
                    selected_edges = current_object.GetSelection #Edge node:node
                )
                catch
                (
                    selection_error = getCurrentException()
                )

                if selection_error != undefined then
                (
                    format "Redundant-Loop-Fixer EDGE SELECTION READ ERROR | node:% | active Edit Poly | %\n" node.name selection_error
                    return undefined
                )

                return selected_edges
            )
        )

        if node.modifiers.count > 0 then
        (
            top_modifier = node.modifiers[1]

            if classOf top_modifier == Edit_Poly then
            (
                if not(forceSelectModeZero top_modifier) then return undefined

                selection_error = undefined
                selected_edges = undefined

                try
                (
                    selected_edges = top_modifier.GetSelection #Edge node:node
                )
                catch
                (
                    selection_error = getCurrentException()
                )

                if selection_error != undefined then
                (
                    format "Redundant-Loop-Fixer EDGE SELECTION READ ERROR | node:% | top Edit Poly | %\n" node.name selection_error
                    return undefined
                )

                return selected_edges
            )
        )

        if classOf node.baseObject == Editable_Poly then
        (
            if not(forceSelectModeZero node.baseObject) then return undefined

            selection_error = undefined
            selected_edges = undefined

            try
            (
                selected_edges = polyop.getEdgeSelection node.baseObject
            )
            catch
            (
                selection_error = getCurrentException()
            )

            if selection_error != undefined then
            (
                format "Redundant-Loop-Fixer EDGE SELECTION READ ERROR | node:% | Editable Poly | %\n" node.name selection_error
                return undefined
            )

            return selected_edges
        )

        undefined
        -- return
    ),

    /*
    Returns the deviation from straight for exactly two currently selected edges.
    Connected edges are measured from their shared vertex; disconnected edges use their undirected direction difference.
    */
    function getSelectedEdgeStraightAngle node =
    (
        if node == undefined or not(isValidNode node) then return #(false, undefined, "Select one valid object.")

        selected_edges = undefined
        source_edit_poly = undefined
        use_base_poly = false
        selection_source_resolved = false
        current_object = undefined
        selection_error = undefined

        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            selection_error = getCurrentException()
        )

        if selection_error != undefined then
        (
            format "Redundant-Loop-Fixer GET ANGLE CURRENT OBJECT ERROR | node:% | %\n" node.name selection_error
            current_object = undefined
        )

        if current_object != undefined and classOf current_object == Edit_Poly then
        (
            current_on_node = false

            for stack_index = 1 to node.modifiers.count while not current_on_node do
            (
                if node.modifiers[stack_index] == current_object then current_on_node = true
            )

            if current_on_node then
            (
                selection_source_resolved = true
                if not(forceSelectModeZero current_object) then return #(false, undefined, "Could not set the active Edit Poly selection mode.")
                selection_error = undefined

                try
                (
                    selected_edges = current_object.GetSelection #Edge node:node
                )
                catch
                (
                    selection_error = getCurrentException()
                )

                if selection_error != undefined then return #(false, undefined, selection_error as string)
                source_edit_poly = current_object
            )
        )

        if not selection_source_resolved and node.modifiers.count > 0 then
        (
            top_edit_poly = node.modifiers[1]

            if classOf top_edit_poly == Edit_Poly then
            (
                selection_source_resolved = true
                if not(forceSelectModeZero top_edit_poly) then return #(false, undefined, "Could not set the top Edit Poly selection mode.")
                selection_error = undefined

                try
                (
                    selected_edges = top_edit_poly.GetSelection #Edge node:node
                )
                catch
                (
                    selection_error = getCurrentException()
                )

                if selection_error != undefined then return #(false, undefined, selection_error as string)
                source_edit_poly = top_edit_poly
            )
        )

        if not selection_source_resolved and classOf node.baseObject == Editable_Poly then
        (
            selection_source_resolved = true
            if not(forceSelectModeZero node.baseObject) then return #(false, undefined, "Could not set the Editable Poly selection mode.")
            selection_error = undefined

            try
            (
                selected_edges = polyop.getEdgeSelection node.baseObject
            )
            catch
            (
                selection_error = getCurrentException()
            )

            if selection_error != undefined then return #(false, undefined, selection_error as string)
            use_base_poly = true
        )

        if not selection_source_resolved or selected_edges == undefined then return #(false, undefined, "Could not resolve the selected edge source.")
        if selected_edges.numberSet != 2 then return #(false, undefined, "Select exactly 2 edges.")

        edge_vertices = undefined
        vertex_points = undefined

        if source_edit_poly != undefined then
        (
            edit_topology = buildEditPolyEdgeTopology node source_edit_poly
            if edit_topology == undefined then return #(false, undefined, "Could not read the selected Edit Poly edge topology.")

            vertex_points = edit_topology[3]
            edge_vertices = edit_topology[4]
        )
        else if use_base_poly then
        (
            base_topology = buildPolyTopology node node.baseObject
            if base_topology == undefined then return #(false, undefined, "Could not read the Editable Poly edge topology.")

            vertex_points = base_topology[4]
            edge_vertices = base_topology[7]
        )
        else
        (
            return #(false, undefined, "Could not resolve the selected edge source.")
        )

        selected_array = selected_edges as array
        edge_a = selected_array[1]
        edge_b = selected_array[2]

        if edge_a < 1 or edge_a > edge_vertices.count or edge_b < 1 or edge_b > edge_vertices.count then
        (
            return #(false, undefined, "Selected edge IDs are outside the current topology.")
        )

        pair_a = edge_vertices[edge_a]
        pair_b = edge_vertices[edge_b]
        if pair_a == undefined or pair_a.count != 2 or pair_b == undefined or pair_b.count != 2 then
        (
            return #(false, undefined, "Selected edge endpoints could not be resolved.")
        )

        shared_vertex = 0
        shared_count = 0

        for vertex_index in pair_a do
        (
            if vertex_index == pair_b[1] or vertex_index == pair_b[2] then
            (
                shared_vertex = vertex_index
                shared_count += 1
            )
        )

        if shared_count == 1 then
        (
            direction_a = getEdgeDirection shared_vertex edge_a edge_vertices vertex_points
            direction_b = getEdgeDirection shared_vertex edge_b edge_vertices vertex_points
            if direction_a == undefined or direction_b == undefined then return #(false, undefined, "One selected edge has zero length.")

            dot_value = dot direction_a direction_b
            if dot_value < -1.0 then dot_value = -1.0
            if dot_value > 1.0 then dot_value = 1.0

            #(true, acos(-dot_value), "")
        )
        else
        (
            direction_a = vertex_points[pair_a[2]] - vertex_points[pair_a[1]]
            direction_b = vertex_points[pair_b[2]] - vertex_points[pair_b[1]]
            if length direction_a <= 0.0000001 or length direction_b <= 0.0000001 then return #(false, undefined, "One selected edge has zero length.")

            direction_a = normalize direction_a
            direction_b = normalize direction_b
            dot_value = abs(dot direction_a direction_b)
            if dot_value > 1.0 then dot_value = 1.0

            #(true, acos dot_value, "")
        )
        -- return
    ),

    /*
    Prints detailed classification for one analyzed edge ID without changing the object.
    The UI calls this for every currently selected edge on the active object.
    */
    function debugEdge node edge_index face_threshold:0.1 straight_threshold:5.0 =
    (
        analysis_source = acquireAnalysisSource node
        if analysis_source == undefined then return false

        analysis_node = analysis_source[1]
        analysis_poly = analysis_source[2]
        topology_data = buildPolyTopology analysis_node analysis_poly

        if topology_data == undefined then
        (
            releaseAnalysisSource analysis_source
            return false
        )

        crease_edges = getCreaseEdges analysis_poly topology_data[2]
        candidate_edges = buildCandidateEdges topology_data crease_edges

        if edge_index < 1 or edge_index > topology_data[2] then
        (
            format "DEBUG EDGE % | invalid edge ID, edgeCount:%\n" edge_index topology_data[2]
            releaseAnalysisSource analysis_source
            return false
        )

        edge_pair = topology_data[7][edge_index]
        face_pair = topology_data[8][edge_index]
        border_edges = topology_data[9]
        vertex_edges = topology_data[5]
        vertex_points = topology_data[4]

        isolated_ok = isValidIsolatedDivider edge_index candidate_edges topology_data face_threshold:face_threshold near_face_threshold:straight_threshold straight_threshold:straight_threshold
        format "DEBUG EDGE % | verts:% | faces:% | candidate:% | isolatedDivider:% | border:% | crease:%\n" edge_index edge_pair face_pair candidate_edges[edge_index] isolated_ok border_edges[edge_index] crease_edges[edge_index]

        if edge_pair != undefined then
        (
            chain_set = #{}
            chain_set[edge_index] = true

            for vertex_index in edge_pair do
            (
                raw_edges = vertex_edges[vertex_index]
                raw_border = raw_edges * border_edges
                border_corner = isBorderCornerVertex vertex_index border_edges vertex_edges topology_data[7] vertex_points angle_threshold:straight_threshold
                terminal_ok = isValidTerminal vertex_index chain_set border_edges vertex_edges topology_data[7] vertex_points angle_threshold:straight_threshold

                format "  V% | rawEdges:% | rawBorder:% | borderCorner:% | terminal:%\n" vertex_index raw_edges raw_border border_corner terminal_ok
            )
        )

        releaseAnalysisSource analysis_source
        true
        -- return
    ),

    /*
    Debugs every currently selected edge on one object.
    No explicit edge ID input is required.
    */
    function debugSelectedEdges node face_threshold:0.1 straight_threshold:5.0 =
    (
        selected_edges = this.getCurrentSelectedEdges node

        if selected_edges == undefined then
        (
            messageBox "Could not read the current edge selection." title:"Redundant-Loop-Fixer"
            return false
        )

        if selected_edges.numberSet == 0 then
        (
            messageBox "Select one or more edges first." title:"Redundant-Loop-Fixer"
            return false
        )

        debug_ok = true

        for edge_index in selected_edges do
        (
            if not(debugEdge node edge_index face_threshold:face_threshold straight_threshold:straight_threshold) then debug_ok = false
        )

        debug_ok
        -- return
    ),

    /*
    Returns the existing exact top selection modifier or creates one.
    Unrelated Edit Poly modifiers are never used for selection storage.
    */
    function acquireSelectionModifier node =
    (
        if node == undefined or not(isValidNode node) then return #(undefined, false)

        for modifier_index = 1 to node.modifiers.count do
        (
            stack_mod = node.modifiers[modifier_index]

            if classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT REDUNDANT LOOPS" then
            (
                stack_mod.showCage = false
                return #(stack_mod, false)
            )
        )

        selection_modifier = Edit_Poly name:"SELECT REDUNDANT LOOPS"
        selection_modifier.showCage = false
        addModifier node selection_modifier
        #(selection_modifier, true)
        -- return
    ),

    /*
    Activates the dedicated selection modifier in Edge mode with Show Cage disabled.
    Geometry detection has already finished before this function runs.
    The modifier is entered once and is not refreshed until the caller applies the complete selection.
    */
    function activateSelectionModifier node selection_modifier =
    (
        if node == undefined or not(isValidNode node) then return false
        if selection_modifier == undefined or classOf selection_modifier != Edit_Poly then return false

        activated = true

        try
        (
            select node
            max modify mode

            if classOf node.baseObject == Editable_Poly then forceSelectModeZero node.baseObject

            forceSelectModeZero selection_modifier
            selection_modifier.SetPrimaryNode node
            selection_modifier.useStackSelection = false
            selection_modifier.showCage = false
            selection_modifier.selectMode = 0

            modPanel.setCurrentObject selection_modifier node:node

            selection_modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2

            if selection_modifier.GetEPolySelLevel() != #Edge then throw "Edit Poly did not enter Edge selection level"
            if selection_modifier.GetMeshSelLevel() != #Edge then throw "Edit Poly mesh selection level is not Edge"
        )
        catch
        (
            activation_error = getCurrentException()
            format "Redundant-Loop-Fixer SELECTOR ACTIVATION ERROR | node:% | %\n" node.name activation_error
            activated = false
        )

        activated
        -- return
    ),

    /*
    Clears the actual current Edit Poly edge selection through the modifier selection API.
    No fabricated edge range or geometry edge count is used, so stale selection IDs cannot survive from another edge-index domain.
    */
    function clearCurrentEditPolyEdges node selection_modifier =
    (
        if node == undefined or not(isValidNode node) then return false
        if selection_modifier == undefined or classOf selection_modifier != Edit_Poly then return false

        cleared = true

        try
        (
            select node
            max modify mode

            forceSelectModeZero selection_modifier
            selection_modifier.SetPrimaryNode node
            selection_modifier.useStackSelection = false
            selection_modifier.showCage = false
            selection_modifier.selectMode = 0

            modPanel.setCurrentObject selection_modifier node:node

            selection_modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2
            selection_modifier.SetEPolySelLevel #Edge

            if selection_modifier.GetEPolySelLevel() != #Edge then throw "could not enter Edge level while clearing edge selection"
            if selection_modifier.GetMeshSelLevel() != #Edge then throw "Edit Poly mesh selection level is not Edge while clearing edge selection"

            current_edges = copy (selection_modifier.GetSelection #Edge node:node)

            if current_edges.numberSet > 0 then
            (
                selection_modifier.Select #Edge current_edges select:false node:node
            )

            update node
            selection_modifier.RefreshScreen()

            remaining_edges = selection_modifier.GetSelection #Edge node:node
            if remaining_edges.numberSet > 0 then throw ("could not clear Edit Poly edge selection. remaining:" + (remaining_edges as string))
        )
        catch
        (
            clear_error = getCurrentException()
            format "Redundant-Loop-Fixer EDGE CLEAR ERROR | node:% | %\n" node.name clear_error
            cleared = false
        )

        cleared
        -- return
    ),

    /*
    Clears stale Vertex and Face selections stored in the dedicated Edit Poly modifier.
    Each selection is cleared only while that exact sub-object level is active, then Edge mode is restored.
    */
    function clearNonEdgeSelections node selection_modifier =
    (
        if node == undefined or not(isValidNode node) then return false
        if selection_modifier == undefined or classOf selection_modifier != Edit_Poly then return false

        cleared = true

        try
        (
            select node
            max modify mode

            forceSelectModeZero selection_modifier
            selection_modifier.SetPrimaryNode node
            selection_modifier.useStackSelection = false
            selection_modifier.showCage = false
            selection_modifier.selectMode = 0
            modPanel.setCurrentObject selection_modifier node:node

            vertex_selection = selection_modifier.GetSelection #Vertex node:node

            if vertex_selection.numberSet > 0 then
            (
                selection_modifier.SetEPolySelLevel #Vertex
                subObjectLevel = 1
                selection_modifier.SetEPolySelLevel #Vertex

                if selection_modifier.GetEPolySelLevel() != #Vertex then throw "could not enter Vertex level while clearing stale selection"

                selection_modifier.Select #Vertex vertex_selection select:false node:node
            )

            face_selection = selection_modifier.GetSelection #Face node:node

            if face_selection.numberSet > 0 then
            (
                selection_modifier.SetEPolySelLevel #Face
                subObjectLevel = 4
                selection_modifier.SetEPolySelLevel #Face

                if selection_modifier.GetEPolySelLevel() != #Face then throw "could not enter Face level while clearing stale selection"

                selection_modifier.Select #Face face_selection select:false node:node
            )

            selection_modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2
            selection_modifier.SetEPolySelLevel #Edge

            if selection_modifier.GetEPolySelLevel() != #Edge then throw "could not restore Edge selection level"
            if selection_modifier.GetMeshSelLevel() != #Edge then throw "could not restore Edge mesh selection level"

            selection_modifier.RefreshScreen()
        )
        catch
        (
            clear_error = getCurrentException()
            format "Redundant-Loop-Fixer NON-EDGE CLEAR ERROR | node:% | %\n" node.name clear_error
            cleared = false
        )

        cleared
        -- return
    ),

    /*
    Reads the active Edit Poly edge topology using the exact edge IDs consumed by EditPolyMod.Select.
    Vertex positions are converted to world space and incident edge sets are built for endpoint-based resolution.
    */
    function buildEditPolyEdgeTopology node editable_poly =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if editable_poly == undefined or classOf editable_poly != Edit_Poly then return undefined
        if not(forceSelectModeZero editable_poly) then return undefined

        vertex_count = 0
        edge_count = 0
        topology_error = undefined

        try
        (
            vertex_count = EditPolyMod.GetNumVertices editable_poly node:node
            edge_count = EditPolyMod.GetNumEdges editable_poly node:node
        )
        catch
        (
            topology_error = getCurrentException()
        )

        if topology_error != undefined then
        (
            format "Redundant-Loop-Fixer EDIT POLY COUNT ERROR | node:% | %\n" node.name topology_error
            return undefined
        )

        if vertex_count < 2 or edge_count < 1 then return undefined

        vertex_points = #()
        edge_vertices = #()
        vertex_edges = #()
        object_transform = node.objectTransform

        for vertex_index = 1 to vertex_count do
        (
            object_point = undefined
            topology_error = undefined

            try
            (
                object_point = EditPolyMod.GetVertex editable_poly vertex_index node:node
            )
            catch
            (
                topology_error = getCurrentException()
            )

            if topology_error != undefined then
            (
                format "Redundant-Loop-Fixer EDIT POLY VERTEX READ ERROR | node:% | vertex:% | %\n" node.name vertex_index topology_error
                return undefined
            )

            if object_point == undefined then return undefined

            append vertex_points (object_point * object_transform)
            append vertex_edges #{}
        )

        for edge_index = 1 to edge_count do
        (
            vertex_a = 0
            vertex_b = 0
            topology_error = undefined

            try
            (
                vertex_a = EditPolyMod.GetEdgeVertex editable_poly edge_index 1 node:node
                vertex_b = EditPolyMod.GetEdgeVertex editable_poly edge_index 2 node:node
            )
            catch
            (
                topology_error = getCurrentException()
            )

            if topology_error != undefined then
            (
                format "Redundant-Loop-Fixer EDIT POLY EDGE READ ERROR | node:% | edge:% | %\n" node.name edge_index topology_error
                return undefined
            )

            if vertex_a < 1 or vertex_a > vertex_count or vertex_b < 1 or vertex_b > vertex_count then return undefined

            append edge_vertices #(vertex_a, vertex_b)
            vertex_edges[vertex_a][edge_index] = true
            vertex_edges[vertex_b][edge_index] = true
        )

        #(vertex_count, edge_count, vertex_points, edge_vertices, vertex_edges)
        -- return
    ),

    /*
    Resolves one analyzed endpoint onto the current Edit Poly vertex topology.
    Same-ID correspondence is preferred only when the vertex position confirms it; otherwise a unique positional match is required.
    */
    function resolveEditPolyVertex source_vertex source_point target_points tolerance:0.0001 =
    (
        if source_point == undefined then return #(false, 0, "undefined source endpoint")

        if source_vertex >= 1 and source_vertex <= target_points.count then
        (
            if distance source_point target_points[source_vertex] <= tolerance then
            (
                return #(true, source_vertex, #sameVertexID)
            )
        )

        matching_vertices = #()

        for target_vertex = 1 to target_points.count do
        (
            if distance source_point target_points[target_vertex] <= tolerance then
            (
                append matching_vertices target_vertex
            )
        )

        if matching_vertices.count != 1 then
        (
            #(false, 0, ("endpoint vertex mapping is ambiguous | matches:" + (matching_vertices.count as string)))
        )
        else
        (
            #(true, matching_vertices[1], #position)
        )
        -- return
    ),

    /*
    Resolves detected edges onto the active Edit Poly through endpoint vertices and their shared current edge.
    Raw source edge IDs are never used as target selection IDs.
    */
    function resolveEdgesByEndpoints source_edges source_topology target_topology debug_output:false node_name:"" =
    (
        if source_topology == undefined or target_topology == undefined then return #(false, #{}, "missing source or target topology")

        source_points = source_topology[4]
        source_edge_vertices = source_topology[7]

        target_vertex_count = target_topology[1]
        target_edge_count = target_topology[2]
        target_points = target_topology[3]
        target_edge_vertices = target_topology[4]
        target_vertex_edges = target_topology[5]

        resolved_edges = #{}
        resolved_edges.count = target_edge_count

        for source_edge in source_edges do
        (
            if source_edge < 1 or source_edge > source_edge_vertices.count then
            (
                return #(false, #{}, ("invalid detected edge ID " + (source_edge as string)))
            )

            source_pair = source_edge_vertices[source_edge]

            if source_pair == undefined or source_pair.count != 2 then
            (
                return #(false, #{}, ("detected edge has invalid endpoints " + (source_edge as string)))
            )

            source_vertex_a = source_pair[1]
            source_vertex_b = source_pair[2]

            if source_vertex_a < 1 or source_vertex_a > source_points.count or source_vertex_b < 1 or source_vertex_b > source_points.count then
            (
                return #(false, #{}, ("detected edge endpoint is outside source vertex range " + (source_edge as string)))
            )

            source_point_a = source_points[source_vertex_a]
            source_point_b = source_points[source_vertex_b]

            target_a_result = resolveEditPolyVertex source_vertex_a source_point_a target_points tolerance:0.0001
            if not target_a_result[1] then
            (
                return #(false, #{}, ("endpoint A mapping failed for detected edge " + (source_edge as string) + " | " + target_a_result[3]))
            )

            target_b_result = resolveEditPolyVertex source_vertex_b source_point_b target_points tolerance:0.0001
            if not target_b_result[1] then
            (
                return #(false, #{}, ("endpoint B mapping failed for detected edge " + (source_edge as string) + " | " + target_b_result[3]))
            )

            target_vertex_a = target_a_result[2]
            target_vertex_b = target_b_result[2]

            if target_vertex_a == target_vertex_b then
            (
                return #(false, #{}, ("both endpoints resolved to the same target vertex for detected edge " + (source_edge as string)))
            )

            if target_vertex_a < 1 or target_vertex_a > target_vertex_count or target_vertex_b < 1 or target_vertex_b > target_vertex_count then
            (
                return #(false, #{}, ("resolved vertex is outside target topology for detected edge " + (source_edge as string)))
            )

            shared_edges = target_vertex_edges[target_vertex_a] * target_vertex_edges[target_vertex_b]

            if shared_edges.numberSet != 1 then
            (
                return #(false, #{}, ("current Edit Poly edge mapping failed for detected edge " + (source_edge as string) + " | sharedEdges:" + (shared_edges as string)))
            )

            matched_edge_array = shared_edges as array
            matched_edge = matched_edge_array[1]
            target_pair = target_edge_vertices[matched_edge]

            pair_valid = false

            if target_pair != undefined and target_pair.count == 2 then
            (
                pair_valid = (target_pair[1] == target_vertex_a and target_pair[2] == target_vertex_b) or (target_pair[1] == target_vertex_b and target_pair[2] == target_vertex_a)
            )

            if not pair_valid then
            (
                return #(false, #{}, ("resolved Edit Poly edge endpoint verification failed for detected edge " + (source_edge as string)))
            )

            if resolved_edges[matched_edge] then
            (
                return #(false, #{}, ("multiple detected edges resolved to target edge " + (matched_edge as string)))
            )

            resolved_edges[matched_edge] = true

            if debug_output then
            (
                format "EDGE MAP | node:% | sourceEdge:% | sourceVerts:% | targetVerts:%-% | targetEdge:% | mode:%/%\\n" node_name source_edge source_pair target_vertex_a target_vertex_b matched_edge target_a_result[3] target_b_result[3]
            )
        )

        #(true, resolved_edges, "")
        -- return
    ),

    /*
    Detects one object and stores the detected edge IDs directly on the dedicated Edit Poly modifier.
    The complete Edge BitArray is cleared/applied in whole-set Select calls while Edge sub-object mode is explicitly active.
    */
    function selectRedundantLoopsOnNode node face_threshold:0.1 straight_threshold:5.0 debug_output:false defer_redraw:false =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, 0, "invalid node", undefined)

        detection = detectRedundantLoops node face_threshold:face_threshold near_face_threshold:straight_threshold straight_threshold:straight_threshold debug_output:debug_output
        if not detection[1] then return #(false, 0, 0, detection[4], undefined)

        loop_count = detection[2].count
        redundant_edges = detection[3]
        selected_edge_count = redundant_edges.numberSet
        selection_modifier = undefined
        created_now = false
        previous_edge_selection = undefined
        operation_error = undefined
        selection_bits = #{}

        try
        (
            if selected_edge_count > 0 then
            (
                modifier_data = this.acquireSelectionModifier node
                selection_modifier = modifier_data[1]
                created_now = modifier_data[2]

                if selection_modifier == undefined then throw "could not acquire SELECT REDUNDANT LOOPS"
                if not(this.activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT LOOPS"

                if not created_now then
                (
                    previous_edge_selection = copy (selection_modifier.GetSelection #Edge node:node)
                )

                selection_bits = copy redundant_edges

                current_edge_selection = copy (selection_modifier.GetSelection #Edge node:node)

                if current_edge_selection.numberSet > 0 then
                (
                    selection_modifier.Select #Edge current_edge_selection select:false node:node
                )

                if selection_bits.numberSet > 0 then
                (
                    selection_modifier.Select #Edge selection_bits select:true node:node
                )

                update node

                if not defer_redraw then
                (
                    selection_modifier.RefreshScreen()
                    completeRedraw()
                )

                stored_selection = copy (selection_modifier.GetSelection #Edge node:node)

                if stored_selection != selection_bits then
                (
                    throw ("edge selection storage mismatch. requested:" + (selection_bits as string) + " actual:" + (stored_selection as string))
                )

                selection_modifier.showCage = false
            )
            else
            (
                if debug_output then
                (
                    existing_selector = false

                    for modifier_index = 1 to node.modifiers.count while not existing_selector do
                    (
                        stack_mod = node.modifiers[modifier_index]
                        existing_selector = classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT REDUNDANT LOOPS"
                    )

                    format "REDUNDANT LOOP ZERO RESULT | node:% | existingSelectorPreserved:%\n" node.name existing_selector
                )

                update node
            )
        )
        catch
        (
            operation_error = getCurrentException()
            rollback_error = undefined

            if selection_modifier != undefined then
            (
                if created_now then
                (
                    try
                    (
                        deleteModifier node selection_modifier
                        selection_modifier = undefined
                    )
                    catch
                    (
                        rollback_error = getCurrentException()
                    )
                )
                else if previous_edge_selection != undefined then
                (
                    try
                    (
                        if not(activateSelectionModifier node selection_modifier) then
                        (
                            rollback_error = "could not reactivate selector during rollback"
                        )
                        else
                        (
                            current_edges = copy (selection_modifier.GetSelection #Edge node:node)

                            if current_edges.numberSet > 0 then
                            (
                                selection_modifier.Select #Edge current_edges select:false node:node
                            )

                            if previous_edge_selection.numberSet > 0 then
                            (
                                selection_modifier.Select #Edge previous_edge_selection select:true node:node
                            )

                            restored_edges = copy (selection_modifier.GetSelection #Edge node:node)

                            if restored_edges != previous_edge_selection then
                            (
                                rollback_error = "rollback edge selection verification failed"
                            )
                            else
                            (
                                selection_modifier.SetEPolySelLevel #Edge
                                subObjectLevel = 2
                                selection_modifier.showCage = false
                                selection_modifier.RefreshScreen()
                            )
                        )
                    )
                    catch
                    (
                        rollback_error = getCurrentException()
                    )
                )
            )

            if rollback_error != undefined then
            (
                format "Redundant-Loop-Fixer ROLLBACK ERROR | node:% | %\n" node.name rollback_error
                operation_error = (operation_error as string) + " | rollback failed: " + (rollback_error as string)
            )

            update node
        )

        if operation_error == undefined then
        (
            latest_redundant_node = node
            latest_redundant_edges = if selection_modifier != undefined then copy selection_bits else copy redundant_edges
            latest_redundant_modifier = selection_modifier
            #(true, loop_count, selected_edge_count, "", selection_modifier)
        )
        else
        (
            #(false, 0, 0, operation_error as string, undefined)
        )
        -- return
    ),

    /*
    Processes every selected object independently and finishes with only matching objects selected.
    Each matching object receives its own SELECT REDUNDANT LOOPS modifier and Edge selection.
    */
    function selectRedundantLoops face_threshold:0.1 straight_threshold:5.0 debug_output:false =
    (
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            messageBox "Select at least one geometry object." title:"Redundant-Loop-Fixer"
            return #(false, 0, 0)
        )

        total_loops = 0
        total_edges = 0
        failed_count = 0
        matching_nodes = #()

        with redraw off
        (
            for node in selected_nodes do
            (
                result_data = selectRedundantLoopsOnNode node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:debug_output defer_redraw:true

                if result_data[1] then
                (
                    total_loops += result_data[2]
                    total_edges += result_data[3]

                    if debug_output then
                    (
                        format "Redundant-Loop-Fixer | node:% | chains:% | selectedEdges:%\n" node.name result_data[2] result_data[3]
                    )

                    if result_data[3] > 0 then
                    (
                        append matching_nodes node

                    )
                )
                else
                (
                    failed_count += 1

                    if debug_output then
                    (
                        format "Redundant-Loop-Fixer FAILED | node:% | %\n" node.name result_data[4]
                    )
                )
            )
        )

        if matching_nodes.count > 0 then
        (
            if matching_nodes.count == 1 then
            (
                current_nodes = selection as array

                if current_nodes.count != 1 or current_nodes[1] != matching_nodes[1] then
                (
                    select matching_nodes
                )
            )
            else
            (
                select matching_nodes
            )
        )
        else
        (
            select selected_nodes
        )

        completeRedraw()

        if debug_output then
        (
            format "Redundant-Loop-Fixer COMPLETE | objects:% | chains:% | edges:% | failures:%\n" selected_nodes.count total_loops total_edges failed_count
        )

        #(failed_count == 0, total_loops, total_edges)
        -- return
    ),

    /*
    Removes the redundant-loop edges stored in SELECT REDUNDANT LOOPS and removes their vertices.
    If RMB is used before LMB, the same non-destructive detection runs first to create the dedicated selector.
    */
    function removeSelectedRedundantLoops face_threshold:0.1 straight_threshold:5.0 =
    (
        selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            messageBox "Select at least one geometry object." title:"Redundant-Loop-Fixer"
            return false
        )

        removed_nodes = #()
        failed_count = 0

        for node in selected_nodes do
        (
            selection_modifier = undefined

            for modifier_index = 1 to node.modifiers.count while selection_modifier == undefined do
            (
                stack_mod = node.modifiers[modifier_index]

                if classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT REDUNDANT LOOPS" then
                (
                    selection_modifier = stack_mod
                )
            )

            if selection_modifier == undefined then
            (
                detection_result = selectRedundantLoopsOnNode node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:false

                if detection_result[1] and detection_result[3] > 0 then
                (
                    selection_modifier = detection_result[5]
                )
                else if not detection_result[1] then
                (
                    failed_count += 1
                    format "Redundant-Loop-Fixer RMB DETECTION FAILED | node:% | %\n" node.name detection_result[4]
                )
            )

            if selection_modifier != undefined then
            (
                operation_error = undefined

                try
                (
                    if not(this.activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT LOOPS"

                    selected_loop_edges = copy (selection_modifier.GetSelection #Edge node:node)
                    if selected_loop_edges.numberSet == 0 then throw "SELECT REDUNDANT LOOPS contains no selected edges"

                    current_detection = detectRedundantLoops node face_threshold:face_threshold near_face_threshold:straight_threshold straight_threshold:straight_threshold debug_output:false
                    if not current_detection[1] then throw current_detection[4]

                    current_topology = this.buildEditPolyEdgeTopology node selection_modifier
                    if current_topology == undefined then throw "could not read current SELECT REDUNDANT LOOPS topology"

                    revalidation_result = this.resolveEdgesByEndpoints current_detection[3] current_detection[5] current_topology debug_output:false node_name:node.name
                    if not revalidation_result[1] then throw revalidation_result[3]

                    current_redundant_edges = revalidation_result[2]
                    stale_edges = selected_loop_edges - current_redundant_edges

                    if stale_edges.numberSet > 0 then
                    (
                        throw ("stored redundant-loop selection is stale. invalid edges:" + (stale_edges as string))
                    )

                    before_vertex_count = EditPolyMod.GetNumVertices selection_modifier node:node
                    before_edge_count = EditPolyMod.GetNumEdges selection_modifier node:node

                    undo "Remove Redundant Loops" on
                    (
                        if not(forceSelectModeZero selection_modifier) then throw "could not set SELECT REDUNDANT LOOPS selectMode to 0"
                        selection_modifier.SetEPolySelLevel #Edge
                        subObjectLevel = 2
                        modPanel.setCurrentObject selection_modifier node:node

                        selection_modifier.ButtonOp #RemoveEdgeRemoveVertices
                        update node
                    )

                    after_vertex_count = EditPolyMod.GetNumVertices selection_modifier node:node
                    after_edge_count = EditPolyMod.GetNumEdges selection_modifier node:node

                    if after_vertex_count >= before_vertex_count and after_edge_count >= before_edge_count then
                    (
                        throw ("remove operation did not reduce topology. verts:" + (before_vertex_count as string) + "->" + (after_vertex_count as string) + " edges:" + (before_edge_count as string) + "->" + (after_edge_count as string))
                    )

                    selection_modifier.showCage = false
                    selection_modifier.name = "DELETED REDUNDANT LOOPS"
                    selection_modifier.RefreshScreen()
                    append removed_nodes node
                )
                catch
                (
                    operation_error = getCurrentException()
                )

                if operation_error != undefined then
                (
                    failed_count += 1
                    format "Redundant-Loop-Fixer RMB FAILED | node:% | %\n" node.name operation_error
                )
            )
        )

        if removed_nodes.count > 0 then
        (
            select removed_nodes
        )
        else
        (
            select selected_nodes
        )

        completeRedraw()
        failed_count == 0
        -- return
    ),

    /*
    Selects the most recently detected redundant edge IDs directly on their source object.
    Edit Poly uses the actual modifier instance; base Editable Poly uses its native SetSelection API.
    */
    function selectLatestRedundantEdges =
    (
        node = latest_redundant_node
        edge_bits = copy latest_redundant_edges

        if node == undefined or not(isValidNode node) then
        (
            messageBox "No valid latest redundant-edge object." title:"Redundant-Loop-Fixer"
            return false
        )

        if edge_bits.numberSet == 0 then
        (
            messageBox "No latest redundant edges are stored." title:"Redundant-Loop-Fixer"
            return false
        )

        select node
        max modify mode

        selection_modifier = undefined
        modifier_index = 0

        if latest_redundant_modifier != undefined then
        (
            for current_index = 1 to node.modifiers.count while selection_modifier == undefined do
            (
                if node.modifiers[current_index] == latest_redundant_modifier and classOf latest_redundant_modifier == Edit_Poly then
                (
                    selection_modifier = latest_redundant_modifier
                    modifier_index = current_index
                )
            )
        )

        if selection_modifier == undefined then
        (
            for current_index = 1 to node.modifiers.count while selection_modifier == undefined do
            (
                current_modifier = node.modifiers[current_index]

                if classOf current_modifier == Edit_Poly and current_modifier.name == "SELECT REDUNDANT LOOPS" then
                (
                    selection_modifier = current_modifier
                    modifier_index = current_index
                )
            )
        )

        if selection_modifier == undefined and node.modifiers.count > 0 then
        (
            modifier_data = this.acquireSelectionModifier node
            selection_modifier = modifier_data[1]

            for current_index = 1 to node.modifiers.count while modifier_index == 0 do
            (
                if node.modifiers[current_index] == selection_modifier then modifier_index = current_index
            )
        )

        if selection_modifier != undefined then
        (
            if not(forceSelectModeZero selection_modifier) then return false
            selection_modifier.SetPrimaryNode node
            selection_modifier.useStackSelection = false
            selection_modifier.showCage = false
            selection_modifier.selectMode = 0

            modPanel.setCurrentObject selection_modifier node:node
            selection_modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2

            current_edge_selection = copy (selection_modifier.GetSelection #Edge node:node)

            if current_edge_selection.numberSet > 0 then
            (
                selection_modifier.Select #Edge current_edge_selection select:false node:node
            )

            if edge_bits.numberSet > 0 then
            (
                selection_modifier.Select #Edge edge_bits select:true node:node
            )

            selection_modifier.SetEPolySelLevel #Edge
            subObjectLevel = 2
            selection_modifier.RefreshScreen()
            update node
            completeRedraw()

            stored_selection = copy (selection_modifier.GetSelection #Edge node:node)
            if stored_selection != edge_bits then
            (
                format "SELECT LATEST REDUNDANT EDGES FAILED | node:% | requested:% | stored:%\n" node.name edge_bits stored_selection
                return false
            )

            latest_redundant_modifier = selection_modifier

            format "SELECT LATEST REDUNDANT EDGES | node:% | modifierIndex:% | modifier:% | edges:%\n" node.name modifier_index selection_modifier.name edge_bits
            true
        )
        else if node.modifiers.count == 0 and classOf node.baseObject == Editable_Poly then
        (
            if not(forceSelectModeZero node.baseObject) then return false
            modPanel.setCurrentObject node.baseObject node:node
            subObjectLevel = 2

            node.EditablePoly.SetSelection #Edge #{}
            node.EditablePoly.SetSelection #Edge edge_bits

            subObjectLevel = 2
            update node
            completeRedraw()

            stored_selection = polyop.getEdgeSelection node.baseObject
            if stored_selection != edge_bits then
            (
                format "SELECT LATEST REDUNDANT EDGES FAILED | node:% | base:Editable_Poly | requested:% | stored:%\n" node.name edge_bits stored_selection
                return false
            )

            format "SELECT LATEST REDUNDANT EDGES | node:% | base:Editable_Poly | edges:%\n" node.name edge_bits
            true
        )
        else
        (
            messageBox "No valid SELECT REDUNDANT LOOPS Edit Poly or Editable Poly base found." title:"Redundant-Loop-Fixer"
            false
        )
        -- return
    ),

    /*
    Finds one Editable Poly edge by its two vertex IDs.
    This helper is used by the standalone regression tests only.
    */
    function findPolyEdgeByVertices poly_value vertex_a vertex_b =
    (
        edge_count = polyop.getNumEdges poly_value

        for edge_index = 1 to edge_count do
        (
            edge_pair = polyop.getEdgeVerts poly_value edge_index

            if edge_pair != undefined then
            (
                same_pair = (edge_pair[1] == vertex_a and edge_pair[2] == vertex_b) or (edge_pair[1] == vertex_b and edge_pair[2] == vertex_a)
                if same_pair then return edge_index
            )
        )

        0
        -- return
    ),

    /*
    Creates a planar wall split by one redundant border-to-border divider.
    The optional crease marks that divider as protected and therefore non-redundant.
    */
    function createDividerTestObject creased:false x_offset:0.0 =
    (
        test_node = editable_mesh name:(uniqueName "REDUNDANT_LOOP_TEST_")
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        test_poly.showCage = off
        if not(forceSelectModeZero test_poly) then throw "could not set divider test Editable Poly selectMode to 0"

        vertex_1 = polyop.createVert test_poly [x_offset + 0.0, 0.0, 0.0]
        vertex_2 = polyop.createVert test_poly [x_offset + 10.0, 0.0, 0.0]
        vertex_3 = polyop.createVert test_poly [x_offset + 0.0, 5.0, 0.0]
        vertex_4 = polyop.createVert test_poly [x_offset + 10.0, 5.0, 0.0]
        vertex_5 = polyop.createVert test_poly [x_offset + 0.0, 10.0, 0.0]
        vertex_6 = polyop.createVert test_poly [x_offset + 10.0, 10.0, 0.0]

        polyop.createPolygon test_poly #(vertex_1, vertex_2, vertex_4, vertex_3)
        polyop.createPolygon test_poly #(vertex_3, vertex_4, vertex_6, vertex_5)
        update test_node

        divider_edge = findPolyEdgeByVertices test_poly vertex_3 vertex_4
        if divider_edge == 0 then throw "could not create divider test edge"

        if creased then
        (
            if not(polyop.getEDataChannelSupport test_poly 2) then polyop.setEDataChannelSupport test_poly 2 true
            polyop.setEDataValue test_poly 2 #{divider_edge} 1.0
        )

        #(test_node, divider_edge)
        -- return
    ),

    /*
    Creates a valid border-to-straight-T redundant divider.
    This mirrors the intended topology of the supplied edge 31 case: one straight border endpoint and one internal straight receiving loop.
    */
    function createTJunctionTestObject x_offset:30.0 =
    (
        test_node = editable_mesh name:(uniqueName "REDUNDANT_T_TEST_")
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        test_poly.showCage = off
        if not(forceSelectModeZero test_poly) then throw "could not set T-junction test Editable Poly selectMode to 0"

        vertex_1 = polyop.createVert test_poly [x_offset + 0.0, 0.0, 0.0]
        vertex_2 = polyop.createVert test_poly [x_offset + 5.0, 0.0, 0.0]
        vertex_3 = polyop.createVert test_poly [x_offset + 10.0, 0.0, 0.0]
        vertex_4 = polyop.createVert test_poly [x_offset + 0.0, 5.0, 0.0]
        vertex_5 = polyop.createVert test_poly [x_offset + 5.0, 5.0, 0.0]
        vertex_6 = polyop.createVert test_poly [x_offset + 0.0, 10.0, 0.0]
        vertex_7 = polyop.createVert test_poly [x_offset + 5.0, 10.0, 0.0]
        vertex_8 = polyop.createVert test_poly [x_offset + 10.0, 10.0, 0.0]

        polyop.createPolygon test_poly #(vertex_1, vertex_2, vertex_5, vertex_4)
        polyop.createPolygon test_poly #(vertex_4, vertex_5, vertex_7, vertex_6)
        polyop.createPolygon test_poly #(vertex_2, vertex_3, vertex_8, vertex_7, vertex_5)
        update test_node

        divider_edge = findPolyEdgeByVertices test_poly vertex_4 vertex_5
        if divider_edge == 0 then throw "could not create T-junction divider test edge"

        #(test_node, divider_edge)
        -- return
    ),

    /*
    Creates one isolated planar divider whose endpoint is also a polygon border corner.
    The detector must reject this edge because a redundant feature may not start or end at a border corner.
    */
    function createBorderCornerTestObject x_offset:60.0 =
    (
        test_node = editable_mesh name:(uniqueName "REDUNDANT_CORNER_TEST_")
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        test_poly.showCage = off
        if not(forceSelectModeZero test_poly) then throw "could not set border-corner test Editable Poly selectMode to 0"

        vertex_1 = polyop.createVert test_poly [x_offset + 0.0, 0.0, 0.0]
        vertex_2 = polyop.createVert test_poly [x_offset + 10.0, 0.0, 0.0]
        vertex_3 = polyop.createVert test_poly [x_offset + 0.0, 5.0, 0.0]
        vertex_4 = polyop.createVert test_poly [x_offset + 10.0, 10.0, 0.0]
        vertex_5 = polyop.createVert test_poly [x_offset + 0.0, 10.0, 0.0]

        polyop.createPolygon test_poly #(vertex_1, vertex_2, vertex_4, vertex_3)
        polyop.createPolygon test_poly #(vertex_3, vertex_4, vertex_5)
        update test_node

        divider_edge = findPolyEdgeByVertices test_poly vertex_3 vertex_4
        if divider_edge == 0 then throw "could not create border-corner divider test edge"

        #(test_node, divider_edge)
        -- return
    ),

    /*
    Tests the design.md border-corner and ANGLE rules without scene geometry.
    Loop turns may go around corners; only the transverse ring-edge pairs are evaluated against ANGLE.
    */
    function testTopologyRules =
    (
        straight_border_points = #([0,0,0], [0,-1,0], [0,1,0])
        straight_border_edges = #(#(1,2), #(1,3))
        straight_border_vertex_edges = #(#{1,2}, #{1}, #{2})
        straight_border_ok = not(isBorderCornerVertex 1 #{1,2} straight_border_vertex_edges straight_border_edges straight_border_points angle_threshold:1.0)

        corner_border_points = #([0,0,0], [0,-1,0], [1,0,0])
        corner_border_edges = #(#(1,2), #(1,3))
        corner_border_vertex_edges = #(#{1,2}, #{1}, #{2})
        border_corner_rejected = isBorderCornerVertex 1 #{1,2} corner_border_vertex_edges corner_border_edges corner_border_points angle_threshold:1.0

        branch_border_points = #([0,0,0], [0,-1,0], [0,1,0], [1,0,0])
        branch_border_edges = #(#(1,2), #(1,3), #(1,4))
        branch_border_vertex_edges = #(#{1,2,3}, #{1}, #{2}, #{3})
        border_branch_rejected = isBorderCornerVertex 1 #{1,2,3} branch_border_vertex_edges branch_border_edges branch_border_points angle_threshold:1.0

        internal_corner_points = #([-1,0,0], [0,0,0], [1,0,0], [0,1,0], [1,1,0])
        internal_corner_edges = #(#(1,2), #(2,3), #(2,4), #(2,5))
        internal_corner_vertex_edges = #(#{1}, #{1,2,3,4}, #{2}, #{3}, #{4})
        internal_corner_topology = #(undefined, undefined, undefined, internal_corner_points, internal_corner_vertex_edges, undefined, internal_corner_edges, undefined, #{3,4})
        internal_corner_record = #(#{1,2}, 1, 3)
        internal_border_corner_rejected = loopRecordTouchesBorderCorner internal_corner_record internal_corner_topology

        corner_launch_points = #([0,0,0], [-1,0,0], [0,-1,0], [1,0,0], [2,0,0], [0,1,0], [0,2,0])
        corner_launch_edges = #(#(1,2), #(1,3), #(1,4), #(4,5), #(1,6), #(6,7))
        corner_launch_vertex_edges = #(#{1,2,3,5}, #{1}, #{2}, #{3,4}, #{4}, #{5,6}, #{6})
        corner_launch_topology = #(undefined, 6, undefined, corner_launch_points, corner_launch_vertex_edges, undefined, corner_launch_edges, undefined, #{1,2})
        corner_launch_candidates = #{3,4,5,6}
        corner_launch_records = buildBorderCornerLoopRecords corner_launch_topology corner_launch_candidates max_turn_threshold:45.0
        corner_launch_selected = #{}
        for corner_launch_record in corner_launch_records do corner_launch_selected += corner_launch_record[1]
        corner_launch_ok = corner_launch_records.count == 2 and corner_launch_selected.numberSet == 4 and corner_launch_selected[3] and corner_launch_selected[4] and corner_launch_selected[5] and corner_launch_selected[6]

        loop_corner_points = #([-1,0,0], [0,0,0], [0,1,0], [0,0,-1], [0,0,1])
        loop_corner_edges = #(#(1,2), #(2,3), #(2,4), #(2,5))
        loop_corner_vertex_edges = #(#{1}, #{1,2,3,4}, #{2}, #{3}, #{4})
        loop_corner_topology = #(undefined, 4, undefined, loop_corner_points, loop_corner_vertex_edges, undefined, loop_corner_edges, undefined, #{})
        loop_corner_record = #(#{1,2}, 1, 3)
        loop_corner_accepted_at_5 = loopRecordWithinAngle loop_corner_record loop_corner_topology 5.0

        corner_trace_points = #([0,0,0], [1,0,0], [1,1,0], [-1,0,0], [0,-1,0], [1,0,-1], [1,0,1])
        corner_trace_edges = #(#(1,4), #(1,5), #(1,2), #(2,3), #(2,6), #(2,7))
        corner_trace_vertex_edges = #(#{1,2,3}, #{3,4,5,6}, #{4}, #{1}, #{2}, #{5}, #{6})
        corner_trace_topology = #(undefined, 6, undefined, corner_trace_points, corner_trace_vertex_edges, undefined, corner_trace_edges, undefined, #{1,2})
        corner_trace_records = buildBorderCornerLoopRecords corner_trace_topology #{3,4} max_turn_threshold:45.0
        corner_trace_edges_selected = #{}
        for corner_trace_record in corner_trace_records do corner_trace_edges_selected += corner_trace_record[1]
        corner_trace_around_90_ok = corner_trace_edges_selected[3] and corner_trace_edges_selected[4]

        ring_bend_radians = 30.0 * pi / 180.0
        ring_bend_points = #([-1,0,0], [0,0,0], [1,0,0], [0,1,0], [sin ring_bend_radians,-(cos ring_bend_radians),0])
        ring_bend_edges = #(#(1,2), #(2,3), #(2,4), #(2,5))
        ring_bend_vertex_edges = #(#{1}, #{1,2,3,4}, #{2}, #{3}, #{4})
        ring_bend_topology = #(undefined, 4, undefined, ring_bend_points, ring_bend_vertex_edges, undefined, ring_bend_edges, undefined, #{})
        ring_bend_record = #(#{1,2}, 1, 3)
        ring_bend_rejected_at_20 = not(loopRecordWithinAngle ring_bend_record ring_bend_topology 20.0)
        ring_bend_accepted_at_45 = loopRecordWithinAngle ring_bend_record ring_bend_topology 45.0

        ring_right_angle_points = #([-1,0,0], [0,0,0], [1,0,0], [0,1,0], [1,0,0])
        ring_right_angle_edges = #(#(1,2), #(2,3), #(2,4), #(2,5))
        ring_right_angle_vertex_edges = #(#{1}, #{1,2,3,4}, #{2}, #{3}, #{4})
        ring_right_angle_topology = #(undefined, 4, undefined, ring_right_angle_points, ring_right_angle_vertex_edges, undefined, ring_right_angle_edges, undefined, #{})
        ring_right_angle_record = #(#{1,2}, 1, 3)
        ring_right_angle_rejected_at_45 = not(loopRecordWithinAngle ring_right_angle_record ring_right_angle_topology 45.0)

        wall_corner_points = #([0,0,0], [0,0,1], [2,0,0], [2,0,1])
        wall_corner_vertex_edges = #(#{1}, #{1}, #{2}, #{2})
        wall_corner_edge_vertices = #(#(1,2), #(3,4))
        wall_corner_edge_faces = #(#(1,2), #(3,4))
        wall_corner_face_normals = #([0,1,0], [1,0,0], [0,1,0], [0,1,0])
        wall_corner_topology = #(undefined, 2, 4, wall_corner_points, wall_corner_vertex_edges, undefined, wall_corner_edge_vertices, wall_corner_edge_faces, #{}, #{}, wall_corner_face_normals, #{1..4})
        wall_corner_records = buildWallCornerLoopRecords wall_corner_topology #{1,2} near_face_angle_threshold
        wall_corner_selected = #{}
        for wall_corner_record in wall_corner_records do wall_corner_selected += wall_corner_record[1]
        wall_corner_normal_split_detected = wall_corner_records.count == 1 and wall_corner_selected == #{1}

        #(straight_border_ok, border_corner_rejected, border_branch_rejected, internal_border_corner_rejected, corner_launch_ok, loop_corner_accepted_at_5, corner_trace_around_90_ok, ring_bend_rejected_at_20, ring_bend_accepted_at_45, ring_right_angle_rejected_at_45, wall_corner_normal_split_detected)
        -- return
    ),

    /*
    Tests audit-critical selection contracts without changing production detector rules.
    Verifies failed selectMode writes report failure and a buried dedicated selector is reused instead of duplicated.
    */
    function testAuditSafetyContracts =
    (
        select_mode_failure_ok = false
        selector_reuse_ok = false
        invalid_target = box name:(uniqueName "RLF_AUDIT_INVALID_")
        selector_test = undefined

        select_mode_failure_ok = not(forceSelectModeZero invalid_target)

        try
        (
            selector_test = plane name:(uniqueName "RLF_AUDIT_SELECTOR_") width:20.0 length:20.0 widthsegs:2 lengthsegs:2
            convertToPoly selector_test
            selector_test.baseObject.showCage = off

            buried_selector = Edit_Poly name:"SELECT REDUNDANT LOOPS"
            buried_selector.showCage = off
            addModifier selector_test buried_selector

            top_test_mod = Edit_Poly name:"AUDIT TOP MODIFIER"
            top_test_mod.showCage = off
            addModifier selector_test top_test_mod

            before_count = 0
            for stack_mod in selector_test.modifiers do
            (
                if classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT REDUNDANT LOOPS" then before_count += 1
            )

            selector_result = acquireSelectionModifier selector_test

            after_count = 0
            for stack_mod in selector_test.modifiers do
            (
                if classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT REDUNDANT LOOPS" then after_count += 1
            )

            selector_reuse_ok = before_count == 1 and after_count == 1 and selector_result[1] == buried_selector and not selector_result[2]
        )
        catch
        (
            audit_test_error = getCurrentException()
            format "AUDIT SAFETY TEST ERROR | %\n" audit_test_error
            selector_reuse_ok = false
        )

        if invalid_target != undefined then try(delete invalid_target)catch(getCurrentException())
        if selector_test != undefined then try(delete selector_test)catch(getCurrentException())

        #(select_mode_failure_ok, selector_reuse_ok)
        -- return
    ),

    /*
    Runs regression tests for the design.md selection contract.
    The tests verify border handling, corner-following loop traces, ring-edge-only ANGLE filtering, crease rejection, and branch continuation without old loop-direction angle gates.
    */
    function runTests =
    (
        test_passed = true
        topology_result = testTopologyRules()

        format "TEST straight border vertex accepted: %\n" topology_result[1]
        format "TEST border corner vertex rejected: %\n" topology_result[2]
        format "TEST border branch vertex rejected: %\n" topology_result[3]
        format "TEST internal chain border corner rejected: %\n" topology_result[4]
        format "TEST border corner launches horizontal + vertical loops independently: %\n" topology_result[5]
        format "TEST 90 degree turn along loop accepted at ANGLE 5 when ring is straight: %\n" topology_result[6]
        format "TEST border-corner trace follows 90 degree loop turn by ring continuity: %\n" topology_result[7]
        format "TEST 30 degree ring bend rejected at ANGLE 20: %\n" topology_result[8]
        format "TEST 30 degree ring bend accepted at ANGLE 45: %\n" topology_result[9]
        format "TEST 90 degree ring bend rejected at ANGLE 45: %\n" topology_result[10]
        format "TEST wall-corner loop detected from different adjacent face normals: %\n" topology_result[11]

        for result_value in topology_result do
        (
            if not result_value then test_passed = false
        )

        audit_safety_result = testAuditSafetyContracts()
        format "TEST failed selectMode write reports failure: %\n" audit_safety_result[1]
        format "TEST buried SELECT REDUNDANT LOOPS modifier is reused: %\n" audit_safety_result[2]

        for result_value in audit_safety_result do
        (
            if not result_value then test_passed = false
        )

        plain_test = undefined
        crease_test = undefined
        t_test = undefined
        corner_test = undefined

        try
        (
            plain_data = createDividerTestObject creased:false x_offset:0.0
            plain_test = plain_data[1]
            plain_edge = plain_data[2]
            plain_result = selectRedundantLoopsOnNode plain_test face_threshold:0.1 straight_threshold:5.0 debug_output:true
            plain_selection = #{}

            if plain_result[1] and plain_result[5] != undefined then plain_selection = EditPolyMod.GetSelection plain_result[5] #Edge node:plain_test

            plain_ok = plain_result[1] and plain_selection.numberSet == 1 and plain_selection[plain_edge]
            format "TEST planar divider selected: % | expectedEdge:% | stored:% | error:%\n" plain_ok plain_edge plain_selection plain_result[4]
            if not plain_ok then test_passed = false

            crease_data = createDividerTestObject creased:true x_offset:20.0
            crease_test = crease_data[1]
            crease_edge = crease_data[2]
            crease_result = selectRedundantLoopsOnNode crease_test face_threshold:0.1 straight_threshold:5.0 debug_output:true
            crease_ok = crease_result[1] and crease_result[3] == 0
            format "TEST creased divider rejected: % | creaseEdge:% | selectedCount:% | error:%\n" crease_ok crease_edge crease_result[3] crease_result[4]
            if not crease_ok then test_passed = false

            t_data = createTJunctionTestObject x_offset:40.0
            t_test = t_data[1]
            t_edge = t_data[2]
            t_result = selectRedundantLoopsOnNode t_test face_threshold:0.1 straight_threshold:5.0 debug_output:true
            t_selection = #{}

            if t_result[1] and t_result[5] != undefined then t_selection = EditPolyMod.GetSelection t_result[5] #Edge node:t_test

            t_ok = t_result[1] and t_selection[t_edge]
            format "TEST branch topology does not block divider: % | expectedEdge:% | stored:% | error:%\n" t_ok t_edge t_selection t_result[4]
            if not t_ok then test_passed = false

            corner_data = createBorderCornerTestObject x_offset:70.0
            corner_test = corner_data[1]
            corner_edge = corner_data[2]

            corner_modifier_data = acquireSelectionModifier corner_test
            corner_modifier_before = corner_modifier_data[1]
            activateSelectionModifier corner_test corner_modifier_before
            clearCurrentEditPolyEdges corner_test corner_modifier_before
            corner_sentinel = #{}
            corner_sentinel[corner_edge] = true
            corner_modifier_before.Select #Edge corner_sentinel node:corner_test
            update corner_test

            corner_result = selectRedundantLoopsOnNode corner_test face_threshold:0.1 straight_threshold:5.0 debug_output:true
            corner_selection = EditPolyMod.GetSelection corner_modifier_before #Edge node:corner_test
            corner_modifier_preserved = corner_test.modifiers.count > 0 and corner_test.modifiers[1] == corner_modifier_before
            corner_ok = corner_result[1] and corner_result[3] == 0 and corner_modifier_preserved and corner_selection == corner_sentinel
            format "TEST zero-result preserves selector: % | edge:% | stored:% | modifierPreserved:% | error:%\n" corner_ok corner_edge corner_selection corner_modifier_preserved corner_result[4]
            if not corner_ok then test_passed = false
        )
        catch
        (
            format "TEST ERROR: %\n" (getCurrentException())
            test_passed = false
        )

        if plain_test != undefined then try(delete plain_test)catch(getCurrentException())
        if crease_test != undefined then try(delete crease_test)catch(getCurrentException())
        if t_test != undefined then try(delete t_test)catch(getCurrentException())
        if corner_test != undefined then try(delete corner_test)catch(getCurrentException())

        format "Redundant-Loop-Fixer TESTS PASSED: %\n" test_passed
        test_passed
        -- return
    ),

    /*
    Creates one visible planar divider test object for manual viewport inspection.
    Detection is not run automatically.
    */
    function createManualTestObject =
    (
        test_data = createDividerTestObject creased:false x_offset:0.0
        select test_data[1]
        completeRedraw()
        test_data[1]
        -- return
    ),

    /*
    Returns the tool title using the highest currently loaded EPolyTools project version.
    The stored tool project version is the fallback when no higher shared version has been loaded.
    */
    function getDisplayTitle =
    (
        display_version = project_version

        if epoly_tools_project_version != undefined and epoly_tools_project_version > display_version then
        (
            display_version = epoly_tools_project_version
        )

        "Redundant-Loop-Fixer | v" + (display_version as string)
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
        file_prefix = "Redundant-Loop-Fixer_"
        candidate_files = getFiles (source_directory + file_prefix + "*.ms")
        latest_path = source_path
        latest_version = -1.0

        for candidate_path in candidate_files do
        (
            candidate_name = getFilenameFile candidate_path

            if matchPattern candidate_name pattern:(file_prefix + "*") then
            (
                version_text = substring candidate_name (file_prefix.count + 1) (candidate_name.count - file_prefix.count)
                version_value = version_text as float
                if version_value == undefined then version_value = -1.0

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
    Returns the persistent INI path used for standalone dialog state.
    */
    function getSettingsPath =
    (
        source_path = getSourceFileName()
        source_directory = getFilenamePath source_path
        source_directory + "Redundant-Loop-Fixer.ini"
        -- return
    ),

    /*
    Saves the standalone dialog position in memory and in the tool INI file.
    */
    function saveDialogPosition dialog_pos =
    (
        if dialog_pos == undefined then return false

        dialog_x = try(dialog_pos.x as integer)catch((getCurrentException(); undefined))
        dialog_y = try(dialog_pos.y as integer)catch((getCurrentException(); undefined))
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
    A position captured from the previous live dialog takes priority over the INI file.
    */
    function loadDialogPosition =
    (
        if RedundantLoopFixer_Dialog_Position != undefined then return RedundantLoopFixer_Dialog_Position

        settings_path = this.getSettingsPath()
        dialog_x_text = try(getINISetting settings_path "Dialog" "X")catch((getCurrentException(); ""))
        dialog_y_text = try(getINISetting settings_path "Dialog" "Y")catch((getCurrentException(); ""))
        if dialog_x_text == "" or dialog_y_text == "" then return undefined

        dialog_x = try(dialog_x_text as integer)catch((getCurrentException(); undefined))
        dialog_y = try(dialog_y_text as integer)catch((getCurrentException(); undefined))
        if dialog_x == undefined or dialog_y == undefined then return undefined
        if dialog_x < -32000 or dialog_x > 32000 or dialog_y < -32000 or dialog_y > 32000 then return undefined

        RedundantLoopFixer_Dialog_Position = [dialog_x, dialog_y]
        RedundantLoopFixer_Dialog_Position
        -- return
    ),

    /*
    Saves the user-facing straight-edge tolerance in degrees.
    */
    function saveStraightAngleThreshold angle_value =
    (
        straight_value = try(angle_value as float)catch((getCurrentException(); undefined))
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
    Loads the saved straight-edge tolerance, falling back to the 5 degree default.
    */
    function loadStraightAngleThreshold =
    (
        settings_path = this.getSettingsPath()
        straight_text = try(getINISetting settings_path "Settings" "StraightAngleThreshold")catch((getCurrentException(); ""))
        straight_value = try(straight_text as float)catch((getCurrentException(); undefined))

        if straight_text == "" or straight_value == undefined then straight_value = 5.0
        if straight_value < 0.0 then straight_value = 0.0
        if straight_value > 45.0 then straight_value = 45.0
        this.straight_angle_threshold = straight_value
        straight_value
        -- return
    ),

    /*
    Saves the current standalone dialog position when this rollout owns a dialog window.
    */
    function saveCurrentDialogPosition =
    (
        if RedundantLoopFixer_UI == undefined then return false

        dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch((getCurrentException(); false))
        if not dialog_is_standalone then return false

        dialog_pos = try(getDialogPos RedundantLoopFixer_UI)catch((getCurrentException(); undefined))
        if dialog_pos == undefined then return false

        this.saveDialogPosition dialog_pos
        -- return
    ),

    /*
    Reloads the highest numeric versioned script found in this tool's source directory.
    This is the action exposed by the RESTART button.
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
        dialog_pos = this.loadDialogPosition()

        if dialog_pos != undefined then
        (
            createDialog RedundantLoopFixer_UI pos:dialog_pos
            this.saveDialogPosition dialog_pos
        )
        else
        (
            createDialog RedundantLoopFixer_UI
        )

        true
        -- return
    ),

    /*
    Closes the standalone tool dialog without changing an embedded manager rollout.
    The current standalone position is saved before destruction.
    */
    function hideUI =
    (
        hide_ok = true

        if RedundantLoopFixer_UI != undefined then
        (
            dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch((getCurrentException(); false))

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

    on create do
    (
    )
)

RedundantLoopFixer0815 = RedundantLoopFixer0815_v()
RedundantLoopFixer = RedundantLoopFixer0815

if epoly_tools_project_version == undefined or epoly_tools_project_version < RedundantLoopFixer.project_version then
(
    epoly_tools_project_version = RedundantLoopFixer.project_version
)

rollout RedundantLoopFixer_UI "Redundant-Loop-Fixer | v1.118" width:286 height:248
(
    spinner spn_straight_angle "ANGLE:" pos:[12,17] width:112 range:[0.0,45.0,5.0] type:#float scale:0.1 fieldwidth:46 tooltip:"Maximum deviation from straight for ring edges crossing the detected loop. Turns along the loop are ignored."
    label lbl_straight_units "deg" pos:[126,19] width:28 height:16
    button btn_select_remove "SELECT \\ REMOVE" pos:[158,10] width:116 height:30 tooltip:"LMB: Detect and select redundant loops.\n\nRMB: Remove the selected redundant-loop edges and their vertices."
    button btn_get_angle "GET ANGLE" pos:[12,48] width:127 height:24 tooltip:"LMB: Read exactly two selected ring edges and set ANGLE to their deviation from straight."
    button btn_select_force "SELECT FORCE" pos:[147,48] width:127 height:24 tooltip:"LMB: Detect and select redundant loops with a fixed 45 degree ring-edge threshold."
    button btn_debug_all "1  SELECT ALL LOOPS" pos:[12,80] width:262 height:24 tooltip:"DEBUG 1: Select all internal candidate loops before border-corner and ANGLE filtering."
    button btn_debug_border "2  SELECT BORDER CORNER LOOPS" pos:[12,108] width:262 height:24 tooltip:"DEBUG 2: Find border corners first, then trace every outgoing loop by ring-edge continuity. The loop itself may turn around corners."
    button btn_debug_angle "3  DESELECT ANGLED LOOPS" pos:[12,136] width:262 height:24 tooltip:"DEBUG 3: Deselect complete loops whose ring edges deviate from straight by more than ANGLE. Turns along the loop are ignored."
    button btn_debug_wall_corner "4  SELECT WALL CORNER LOOP" pos:[12,164] width:262 height:24 tooltip:"DEBUG 4: Select internal candidate loops on wall corners where the two adjacent face normals belong to different planes. Uses the existing 1 degree near-face threshold; ANGLE is ignored."
    button btn_restart "RESTART" pos:[12,212] width:262 height:24 tooltip:"LMB: Load the highest numeric Redundant-Loop-Fixer version from this script directory."

    on RedundantLoopFixer_UI open do
    (
        spn_straight_angle.value = RedundantLoopFixer.loadStraightAngleThreshold()
    )

    on RedundantLoopFixer_UI moved dialog_pos do
    (
        dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch((getCurrentException(); false))
        if dialog_is_standalone then RedundantLoopFixer.saveDialogPosition dialog_pos
    )

    on spn_straight_angle changed angle_value do
    (
        RedundantLoopFixer.saveStraightAngleThreshold angle_value
    )

    on btn_debug_all pressed do
    (
        RedundantLoopFixer.debugSelectAllLoops()
    )

    on btn_debug_border pressed do
    (
        RedundantLoopFixer.debugSelectBorderCornerLoops()
    )

    on btn_debug_angle pressed do
    (
        RedundantLoopFixer.debugDeselectAngledLoops spn_straight_angle.value
    )

    on btn_debug_wall_corner pressed do
    (
        RedundantLoopFixer.debugSelectWallCornerLoops()
    )

    on btn_restart pressed do
    (
        RedundantLoopFixer.restartLatest()
    )

    on btn_get_angle pressed do
    (
        if selection.count != 1 then
        (
            messageBox "Select one object with exactly 2 edges selected." title:"Redundant-Loop-Fixer"
        )
        else
        (
            angle_result = RedundantLoopFixer.getSelectedEdgeStraightAngle selection[1]

            if angle_result[1] then
            (
                measured_angle = angle_result[2]

                if measured_angle > 45.0 then
                (
                    messageBox ("Selected-edge angle is " + (measured_angle as string) + " degrees, above the 45 degree ANGLE limit.") title:"Redundant-Loop-Fixer"
                )
                else
                (
                    spn_straight_angle.value = measured_angle
                    RedundantLoopFixer.saveStraightAngleThreshold measured_angle
                )
            )
            else
            (
                messageBox angle_result[3] title:"Redundant-Loop-Fixer"
            )
        )
    )

    on btn_select_force pressed do
    (
        RedundantLoopFixer.selectRedundantLoops face_threshold:0.1 straight_threshold:45.0 debug_output:false
    )

    on btn_select_remove pressed do
    (
        RedundantLoopFixer.selectRedundantLoops face_threshold:0.1 straight_threshold:spn_straight_angle.value debug_output:false
    )

    on btn_select_remove rightclick do
    (
        RedundantLoopFixer.removeSelectedRedundantLoops face_threshold:0.1 straight_threshold:spn_straight_angle.value
    )
)

if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "redundant-loop-fixer" (RedundantLoopFixer.getDisplayTitle()) RedundantLoopFixer RedundantLoopFixer_UI RedundantLoopFixer.file_version RedundantLoopFixer.project_version (getSourceFileName()) capabilities:#(#detect, #selection, #remove, #edge, #editable_poly, #edit_poly, #ui)

    if EPolyToolsIntegration.shouldAutoOpenUI() then RedundantLoopFixer.showUI()
)
else
(
    RedundantLoopFixer.showUI()
)
