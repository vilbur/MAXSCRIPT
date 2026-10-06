/*
    Redundant-Loop-Fixer 0.834
    Standalone simple detector for redundant isolated internal dividers and straight internal edge chains.
*/

global RedundantLoopFixer
global RedundantLoopFixer0834
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


struct RedundantLoopFixer0834_v
(
    file_version = 0.834,
    project_version = 1.138,
    quiet_mode = true,
    face_angle_threshold = 0.1,
    near_face_angle_threshold = 1.0,
    straight_angle_threshold = 5.0,
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
        if length direction_value == 0.0 then return undefined

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
                    if length face_normal > 0.0 then
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
    Computes a normalized polygon normal from ordered world-space polygon points without triangulating the polygon.
    */
    function getPolygonNormalFromPoints face_points =
    (
        if face_points == undefined or face_points.count < 3 then return undefined

        origin_point = face_points[1]
        normal_value = [0,0,0]

        for point_index = 2 to (face_points.count - 1) do
        (
            vector_a = face_points[point_index] - origin_point
            vector_b = face_points[point_index + 1] - origin_point
            normal_value += cross vector_a vector_b
        )

        if length normal_value == 0.0 then return undefined
        normalize normal_value
        -- return
    ),

    /*
    Reads the committed topology of one live Edit Poly directly through EditPolyMod geometry queries.
    Polygon degrees and ordered polygon vertices are preserved; no mesh snapshot or triangulation is created.
    */
    function buildEditPolyTopologyData node edit_poly_mod =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return undefined

        vertex_count = 0
        edge_count = 0
        face_count = 0
        topology_error = undefined

        try
        (
            vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
            edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node
            face_count = EditPolyMod.GetNumFaces edit_poly_mod node:node
        )
        catch
        (
            topology_error = getCurrentException()
        )

        if topology_error != undefined then
        (
            format "Redundant-Loop-Fixer EDIT POLY TOPOLOGY COUNT ERROR | node:% | %\n" node.name topology_error
            return undefined
        )

        if vertex_count < 2 or edge_count < 1 or face_count < 1 then return undefined

        vertex_points = #()
        vertex_edges = #()
        vertex_faces = #()
        edge_vertices = #()
        edge_faces = #()
        border_edges = #{}
        border_vertices = #{}
        face_normals = #()
        face_valid = #{}
        object_transform = node.objectTransform

        for vertex_index = 1 to vertex_count do
        (
            vertex_point = undefined
            topology_error = undefined

            try
            (
                vertex_point = EditPolyMod.GetVertex edit_poly_mod vertex_index node:node
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

            if vertex_point == undefined then return undefined
            append vertex_points (vertex_point * object_transform)
            append vertex_edges #{}
            append vertex_faces #{}
        )

        for edge_index = 1 to edge_count do
        (
            vertex_a = 0
            vertex_b = 0
            face_a = 0
            face_b = 0
            topology_error = undefined

            try
            (
                vertex_a = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 1 node:node
                vertex_b = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 2 node:node
                face_a = EditPolyMod.GetEdgeFace edit_poly_mod edge_index 1 node:node
                face_b = EditPolyMod.GetEdgeFace edit_poly_mod edge_index 2 node:node
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
            append edge_faces #(face_a, face_b)
            vertex_edges[vertex_a][edge_index] = true
            vertex_edges[vertex_b][edge_index] = true

            if face_a > 0 and face_b == 0 then
            (
                border_edges[edge_index] = true
                border_vertices[vertex_a] = true
                border_vertices[vertex_b] = true
            )
        )

        for face_index = 1 to face_count do
        (
            face_degree = 0
            topology_error = undefined

            try
            (
                face_degree = EditPolyMod.GetFaceDegree edit_poly_mod face_index node:node
            )
            catch
            (
                topology_error = getCurrentException()
            )

            if topology_error != undefined then
            (
                format "Redundant-Loop-Fixer EDIT POLY FACE READ ERROR | node:% | face:% | %\n" node.name face_index topology_error
                return undefined
            )

            face_points = #()
            face_ok = face_degree >= 3

            if face_ok then
            (
                for corner_index = 1 to face_degree while face_ok do
                (
                    vertex_index = 0
                    topology_error = undefined

                    try
                    (
                        vertex_index = EditPolyMod.GetFaceVertex edit_poly_mod face_index corner_index node:node
                    )
                    catch
                    (
                        topology_error = getCurrentException()
                    )

                    if topology_error != undefined then
                    (
                        format "Redundant-Loop-Fixer EDIT POLY FACE VERTEX ERROR | node:% | face:% | corner:% | %\n" node.name face_index corner_index topology_error
                        return undefined
                    )

                    if vertex_index < 1 or vertex_index > vertex_count then
                    (
                        face_ok = false
                    )
                    else
                    (
                        vertex_faces[vertex_index][face_index] = true
                        append face_points vertex_points[vertex_index]
                    )
                )
            )

            face_normal = if face_ok then this.getPolygonNormalFromPoints face_points else undefined

            if face_normal != undefined then face_valid[face_index] = true
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
                if crease_value != undefined and crease_value != 0.0 then crease_edges[edge_index] = true
            )
        )

        crease_edges
        -- return
    ),

    /*
    Maps explicit base Editable Poly crease edges onto a live Edit Poly topology by endpoint vertex IDs when those IDs still resolve uniquely.
    */
    function getMappedBaseCreaseEdges node topology_data =
    (
        mapped_creases = #{}
        if node == undefined or not(isValidNode node) then return mapped_creases
        if topology_data == undefined then return mapped_creases
        if classOf node.baseObject != Editable_Poly then return mapped_creases

        base_topology = this.buildPolyTopology node node.baseObject
        if base_topology == undefined then return mapped_creases

        base_creases = this.getCreaseEdges node.baseObject base_topology[2]
        target_vertex_edges = topology_data[5]

        for base_edge in base_creases do
        (
            base_pair = base_topology[7][base_edge]

            if base_pair != undefined and base_pair.count == 2 then
            (
                vertex_a = base_pair[1]
                vertex_b = base_pair[2]

                if vertex_a >= 1 and vertex_a <= target_vertex_edges.count and vertex_b >= 1 and vertex_b <= target_vertex_edges.count then
                (
                    shared_edges = target_vertex_edges[vertex_a] * target_vertex_edges[vertex_b]
                    if shared_edges.numberSet == 1 then mapped_creases[(shared_edges as array)[1]] = true
                )
            )
        )

        mapped_creases
        -- return
    ),

    /*
    Resolves the user's current polygon-analysis source without changing stack state.
    A live current Edit Poly or Editable Poly is preferred; unsupported current stack states request disposable evaluated-copy analysis.
    Returns #(source_kind, source_value, selector_before_index).
    */
    function getCurrentAnalysisTarget node =
    (
        if node == undefined or not(isValidNode node) then return #(#snapshot, undefined, 0)

        current_object = try(modPanel.getCurrentObject())catch((getCurrentException(); undefined))

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

        if current_object != undefined and classOf current_object == Editable_Poly and node.baseObject == current_object then
        (
            selector_before_index = if node.modifiers.count > 0 then node.modifiers.count else 0
            return #(#editable_poly, node.baseObject, selector_before_index)
        )

        if node.modifiers.count == 0 and classOf node.baseObject == Editable_Poly then
        (
            return #(#editable_poly, node.baseObject, 0)
        )

        #(#snapshot, undefined, 0)
        -- return
    ),

    /*
    Acquires the true evaluated top-of-stack geometry on a disposable Editable Poly copy for read-only analysis.
    Native loop expansion may change analysis selection state, so the user's source object is never used directly.
    */
    function acquireAnalysisSource node =
    (
        if node == undefined or not(isValidNode node) then return undefined

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
        -- return
    ),

    /*
    Acquires production topology from the current live Editable Poly/Edit Poly when possible.
    Unsupported current stack states fall back to a disposable evaluated Editable Poly copy; the live node is never collapsed or converted.
    Returns #(success, topology_data, crease_edges, disposable_source, selector_before_index, source_kind, error_text).
    */
    function acquireProductionAnalysis node =
    (
        if node == undefined or not(isValidNode node) then return #(false, undefined, #{}, undefined, 0, #invalid, "invalid node")

        target_data = this.getCurrentAnalysisTarget node
        source_kind = target_data[1]
        source_value = target_data[2]
        selector_before_index = target_data[3]
        topology_data = undefined
        crease_edges = #{}

        if source_kind == #edit_poly then
        (
            topology_data = this.buildEditPolyTopologyData node source_value

            if topology_data != undefined then
            (
                crease_edges = this.getMappedBaseCreaseEdges node topology_data
                return #(true, topology_data, crease_edges, undefined, selector_before_index, source_kind, "")
            )
        )
        else if source_kind == #editable_poly then
        (
            topology_data = this.buildPolyTopology node source_value

            if topology_data != undefined then
            (
                crease_edges = this.getCreaseEdges source_value topology_data[2]
                return #(true, topology_data, crease_edges, undefined, selector_before_index, source_kind, "")
            )
        )

        disposable_source = this.acquireAnalysisSource node
        if disposable_source == undefined then return #(false, undefined, #{}, undefined, 0, #snapshot, "could not acquire disposable evaluated Editable Poly topology")

        topology_data = this.buildPolyTopology disposable_source[1] disposable_source[2]

        if topology_data == undefined then
        (
            this.releaseAnalysisSource disposable_source
            return #(false, undefined, #{}, undefined, 0, #snapshot, "could not read disposable evaluated Editable Poly topology")
        )

        crease_edges = this.getCreaseEdges disposable_source[2] topology_data[2]
        #(true, topology_data, crease_edges, disposable_source, 0, #snapshot, "")
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
                    if getEdgeLength edge_index edge_vertices vertex_points > 0.0 then
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
    Builds the actual 3ds Max Editable Poly edge loop for every internal candidate seed on the disposable analysis node.
    EditablePoly interface methods are called on the node interface; singleton native loops remain valid records.
    */
    function buildNativeEdgeLoopRecords analysis_node candidate_edges debug_output:false =
    (
        loop_records = #()
        if analysis_node == undefined or not(isValidNode analysis_node) then return #(false, loop_records, "invalid analysis node")
        if classOf analysis_node.baseObject != Editable_Poly then return #(false, loop_records, "analysis node is not Editable Poly")
        if candidate_edges == undefined then return #(false, loop_records, "candidate edge set is undefined")
        if candidate_edges.numberSet == 0 then return #(true, loop_records, "")

        analysis_poly = analysis_node.baseObject
        remaining_edges = copy candidate_edges
        record_keys = #()
        operation_error = undefined
        restore_error = undefined
        previous_nodes = selection as array

        try
        (
            with redraw off
            (
                select analysis_node
                max modify mode
                modPanel.setCurrentObject analysis_poly node:analysis_node
                subObjectLevel = 2
            )

            for seed_edge in candidate_edges do
            (
                if remaining_edges[seed_edge] then
                (
                    polyop.setEdgeSelection analysis_poly #{seed_edge}
                    analysis_node.EditablePoly.SelectEdgeLoop()
                    loop_edges = copy (polyop.getEdgeSelection analysis_poly)

                    if loop_edges[seed_edge] then
                    (
                        non_candidate_edges = loop_edges - candidate_edges

                        if non_candidate_edges.numberSet == 0 then
                        (
                            loop_key = this.makeChainKey loop_edges

                            if findItem record_keys loop_key == 0 then
                            (
                                append record_keys loop_key
                                append loop_records #(loop_edges, 0, 0)

                                if debug_output and not this.quiet_mode then
                                (
                                    format "NATIVE EDGE LOOP | seed:% | edges:%\n" seed_edge loop_edges
                                )
                            )
                        )
                        else if debug_output and not this.quiet_mode then
                        (
                            format "REJECT NATIVE LOOP PROTECTED EDGE | seed:% | loop:% | protected:%\n" seed_edge loop_edges non_candidate_edges
                        )

                        remaining_edges -= loop_edges
                    )
                    else
                    (
                        remaining_edges[seed_edge] = false

                        if debug_output and not this.quiet_mode then
                        (
                            format "NATIVE EDGE LOOP SKIP | seed:% | result:%\n" seed_edge loop_edges
                        )
                    )
                )
            )

            polyop.setEdgeSelection analysis_poly #{}
        )
        catch
        (
            operation_error = getCurrentException()
        )

        try
        (
            if previous_nodes.count > 0 then
            (
                select previous_nodes
            )
            else
            (
                clearSelection()
            )
        )
        catch
        (
            restore_error = getCurrentException()
        )

        if restore_error != undefined then
        (
            return #(false, loop_records, "could not restore scene selection after native loop analysis | " + (restore_error as string))
        )

        if operation_error != undefined then
        (
            return #(false, loop_records, "native EditablePoly SelectEdgeLoop failed | " + (operation_error as string))
        )

        #(true, loop_records, "")
        -- return
    ),

    /*
    Returns true when any edge in one complete traced loop/chain is a wall-corner edge.
    Wall-corner classification is independent of the user ANGLE filter.
    */
    function loopRecordTouchesWallCorner loop_record topology_data wall_angle_threshold =
    (
        if loop_record == undefined or loop_record.count < 1 then return false
        if topology_data == undefined then return false

        for edge_index in loop_record[1] do
        (
            if this.edgeSeparatesWallPlanes edge_index topology_data wall_angle_threshold then return true
        )

        false
        -- return
    ),

    /*
    Returns true when one complete generic loop shares at least one edge with a classifier edge set.
    Filtering uses this only to reject the whole generic loop record, never to subtract edge fragments.
    */
    function loopRecordIntersectsEdges loop_record classifier_edges =
    (
        if loop_record == undefined or loop_record.count < 1 then return false
        if classifier_edges == undefined or classifier_edges.numberSet == 0 then return false

        ((loop_record[1] * classifier_edges).numberSet > 0)
        -- return
    ),

    /*
    Returns true when one candidate edge has a valid redundant-loop continuation or terminal at one endpoint.
    A continuation removes two loop edges at the vertex; a terminal removes only this edge and must leave valid straight-through topology.
    */
    function edgeHasRedundantSupportAtVertex edge_index vertex_index active_edges topology_data angle_threshold =
    (
        if topology_data == undefined then return false
        if active_edges == undefined then return false

        vertex_edges = topology_data[5]
        edge_vertices = topology_data[7]
        border_edges = topology_data[9]
        vertex_points = topology_data[4]

        if vertex_index < 1 or vertex_index > vertex_edges.count then return false
        if edge_index < 1 or edge_index > edge_vertices.count then return false

        single_edge = #{}
        single_edge[edge_index] = true

        if this.isValidTerminal vertex_index single_edge border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold then
        (
            return true
        )

        continuation_edges = vertex_edges[vertex_index] * active_edges
        continuation_edges[edge_index] = false

        for continuation_edge in continuation_edges do
        (
            if this.isValidInternalVertex vertex_index edge_index continuation_edge border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold then
            (
                return true
            )
        )

        false
        -- return
    ),

    /*
    Removes unsupported candidate edges until every surviving edge is supported at both endpoints.
    This fixed-point pass keeps complete loops, open redundant chains, broken loop fragments, and valid single-edge dividers under one rule.
    */
    function pruneRedundantEdgeCandidates candidate_edges topology_data angle_threshold =
    (
        if candidate_edges == undefined then return #{}
        if topology_data == undefined then return #{}

        edge_vertices = topology_data[7]
        active_edges = copy candidate_edges
        changed = true

        while changed do
        (
            changed = false
            remove_edges = #{}

            for edge_index in active_edges do
            (
                edge_pair = edge_vertices[edge_index]

                if edge_pair == undefined or edge_pair.count != 2 then
                (
                    remove_edges[edge_index] = true
                )
                else
                (
                    endpoint_a_ok = this.edgeHasRedundantSupportAtVertex edge_index edge_pair[1] active_edges topology_data angle_threshold
                    endpoint_b_ok = this.edgeHasRedundantSupportAtVertex edge_index edge_pair[2] active_edges topology_data angle_threshold

                    if not endpoint_a_ok or not endpoint_b_ok then
                    (
                        remove_edges[edge_index] = true
                    )
                )
            )

            if remove_edges.numberSet > 0 then
            (
                active_edges -= remove_edges
                changed = true
            )
        )

        active_edges
        -- return
    ),

    /*
    Groups surviving redundant edges by valid continuation relationships for reporting and loop counts.
    Terminal-only contact does not merge unrelated redundant chains.
    */
    function buildRedundantEdgeComponents redundant_edges topology_data angle_threshold =
    (
        component_records = #()
        if redundant_edges == undefined or redundant_edges.numberSet == 0 then return component_records
        if topology_data == undefined then return component_records

        vertex_edges = topology_data[5]
        edge_vertices = topology_data[7]
        border_edges = topology_data[9]
        vertex_points = topology_data[4]
        remaining_edges = copy redundant_edges

        for seed_edge in redundant_edges do
        (
            if remaining_edges[seed_edge] then
            (
                component_edges = #{}
                pending_edges = #(seed_edge)
                remaining_edges[seed_edge] = false

                while pending_edges.count > 0 do
                (
                    current_edge = pending_edges[pending_edges.count]
                    deleteItem pending_edges pending_edges.count
                    component_edges[current_edge] = true
                    edge_pair = edge_vertices[current_edge]

                    if edge_pair != undefined and edge_pair.count == 2 then
                    (
                        for vertex_index in edge_pair do
                        (
                            neighbor_edges = vertex_edges[vertex_index] * remaining_edges

                            for neighbor_edge in neighbor_edges do
                            (
                                if this.isValidInternalVertex vertex_index current_edge neighbor_edge border_edges vertex_edges edge_vertices vertex_points angle_threshold:angle_threshold then
                                (
                                    remaining_edges[neighbor_edge] = false
                                    append pending_edges neighbor_edge
                                )
                            )
                        )
                    )
                )

                append component_records #(component_edges, 0, 0)
            )
        )

        component_records
        -- return
    ),

    /*
    Detects redundant edge-loop networks from local removable topology only.
    Production does not depend on native SelectEdgeLoop: unsupported structural edges are pruned until only removable loops, chains, fragments, and singleton dividers remain.
    */
    function detectRedundantLoops node face_threshold:0.1 near_face_threshold:1.0 straight_threshold:5.0 debug_output:false =
    (
        accepted_records = #()
        redundant_edges = #{}
        analysis_data = this.acquireProductionAnalysis node

        if not analysis_data[1] then return #(false, accepted_records, redundant_edges, analysis_data[7], undefined, 0, analysis_data[6])

        topology_data = analysis_data[2]
        crease_edges = analysis_data[3]
        disposable_source = analysis_data[4]
        selector_before_index = analysis_data[5]
        source_kind = analysis_data[6]
        candidate_edges = buildCandidateEdges topology_data crease_edges
        removable_candidates = copy candidate_edges
        wall_corner_edges = #{}

        for edge_index in candidate_edges do
        (
            if this.edgeSeparatesWallPlanes edge_index topology_data near_face_threshold then
            (
                wall_corner_edges[edge_index] = true
                removable_candidates[edge_index] = false
            )
        )

        redundant_edges = this.pruneRedundantEdgeCandidates removable_candidates topology_data straight_threshold
        accepted_records = this.buildRedundantEdgeComponents redundant_edges topology_data straight_threshold

        if debug_output and not this.quiet_mode then
        (
            pruned_edges = removable_candidates - redundant_edges
            format "REDUNDANT NETWORK | node:% | source:% | candidates:% | wallProtected:% | pruned:% | selected:% | components:%\n" node.name source_kind candidate_edges wall_corner_edges pruned_edges redundant_edges accepted_records.count
        )

        if disposable_source != undefined then this.releaseAnalysisSource disposable_source
        #(true, accepted_records, redundant_edges, "", topology_data, selector_before_index, source_kind)
        -- return
    ),

    /*
    Builds native Editable Poly loop records plus independent border-corner and wall-corner debug records.
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
        loop_build_result = this.buildNativeEdgeLoopRecords analysis_node candidate_edges

        if not loop_build_result[1] then
        (
            releaseAnalysisSource analysis_source
            return #(false, loop_records, topology_data, loop_build_result[3], border_corner_records, wall_corner_records)
        )

        loop_records = loop_build_result[2]

        for loop_record in loop_records do
        (
            if this.loopRecordTouchesBorderCorner loop_record topology_data then append border_corner_records loop_record
            if this.loopRecordTouchesWallCorner loop_record topology_data near_face_angle_threshold then append wall_corner_records loop_record
        )

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
    Maps analysis-space debug edges into the live SELECT REDUNDANT LOOPS topology before writing selection.
    Debug selection never writes raw analysis edge IDs directly into a live Edit Poly modifier.
    */
    function writeDebugEdgeSelection node edge_bits source_topology =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, "invalid node")
        if edge_bits == undefined then return #(false, 0, "debug edge set is undefined")
        if source_topology == undefined then return #(false, 0, "debug source topology is undefined")

        selection_modifier = undefined
        created_now = false
        previous_edge_selection = undefined
        operation_error = undefined
        rollback_error = undefined
        mapped_edge_bits = #{}

        if edge_bits.numberSet == 0 and this.findSelectionModifier node == undefined then return #(true, 0, "")

        try
        (
            modifier_data = this.acquireSelectionModifier node
            selection_modifier = modifier_data[1]
            created_now = modifier_data[2]

            if selection_modifier == undefined then throw "could not acquire SELECT REDUNDANT LOOPS"
            if not(this.activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT LOOPS"

            if not created_now then previous_edge_selection = copy (selection_modifier.GetSelection #Edge node:node)

            current_topology = this.buildEditPolyEdgeTopology node selection_modifier
            if current_topology == undefined then throw "could not read current SELECT REDUNDANT LOOPS topology"

            edge_map_result = this.resolveEdgesByVertexIds edge_bits source_topology current_topology node_name:node.name
            if not edge_map_result[1] then throw edge_map_result[3]

            mapped_edge_bits = edge_map_result[2]
            current_edge_selection = copy (selection_modifier.GetSelection #Edge node:node)

            if current_edge_selection.numberSet > 0 then
            (
                selection_modifier.Select #Edge current_edge_selection select:false node:node
            )

            if mapped_edge_bits.numberSet > 0 then
            (
                selection_modifier.Select #Edge mapped_edge_bits select:true node:node
            )

            update node
            stored_selection = copy (selection_modifier.GetSelection #Edge node:node)
            if stored_selection != mapped_edge_bits then throw "debug edge selection storage mismatch"

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

        if operation_error == undefined then #(true, mapped_edge_bits.numberSet, "") else #(false, 0, operation_error as string)
        -- return
    ),

    /*
    DEBUG 1: selects every complete native Editable Poly loop before production filtering.
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

        write_result = writeDebugEdgeSelection node debug_edges debug_data[3]

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
    DEBUG 2: selects every complete native loop that touches a border corner or border branch.
    Wall-corner classification is independent, so loops that satisfy both classifiers remain visible here.
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

        write_result = writeDebugEdgeSelection node border_corner_edges debug_data[3]

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
    DEBUG 3: selects internal candidate loops that lie on wall corners where adjacent face normals belong to different planes.
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

        write_result = writeDebugEdgeSelection node wall_corner_edges debug_data[3]

        if write_result[1] then
        (
            format "DEBUG 3 WALL CORNER LOOPS | node:% | faceAngle:% | loops:% | edges:%\n" node.name near_face_angle_threshold wall_corner_loops write_result[2]
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
    DEBUG 4: selects complete candidate loops whose ring-edge pairs exceed the current ANGLE spinner value.
    This diagnostic is independent of the current edge selection.
    */
    function debugSelectAngledLoops angle_threshold =
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

        angled_edges = #{}
        angled_loops = 0

        for loop_record in debug_data[2] do
        (
            if not(debugChainWithinAngle loop_record debug_data[3] angle_threshold) then
            (
                angled_edges += loop_record[1]
                angled_loops += 1
            )
        )

        write_result = writeDebugEdgeSelection node angled_edges debug_data[3]

        if write_result[1] then
        (
            format "DEBUG 4 ANGLED LOOPS | node:% | angle:% | loops:% | edges:%\n" node.name angle_threshold angled_loops write_result[2]
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
            if length direction_a == 0.0 or length direction_b == 0.0 then return #(false, undefined, "One selected edge has zero length.")

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
    function findSelectionModifier node =
    (
        if node == undefined or not(isValidNode node) then return undefined

        for stack_index = 1 to node.modifiers.count do
        (
            stack_mod = node.modifiers[stack_index]

            if classOf stack_mod == Edit_Poly and stack_mod.name == "SELECT REDUNDANT LOOPS" then
            (
                stack_mod.showCage = false
                return stack_mod
            )
        )

        undefined
        -- return
    ),

    /*
    Returns the existing exact selection modifier or creates one at the requested topology position.
    Creation is called only after non-empty redundant edges have already been detected.
    */
    function acquireSelectionModifier node before_index:0 =
    (
        if node == undefined or not(isValidNode node) then return #(undefined, false)

        selection_modifier = this.findSelectionModifier node
        if selection_modifier != undefined then return #(selection_modifier, false)

        selection_modifier = Edit_Poly name:"SELECT REDUNDANT LOOPS"
        selection_modifier.showCage = false

        if before_index >= 1 and before_index <= node.modifiers.count then
        (
            addModifier node selection_modifier before:before_index
        )
        else
        (
            addModifier node selection_modifier
        )

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
    Resolves source edge IDs onto the active Edit Poly by complete vertex-ID topology identity.
    Every source edge endpoint pair must exist exactly once in the target topology, so edge renumbering is allowed but vertex renumbering or topology changes fail safely.
    */
    function resolveEdgesByVertexIds source_edges source_topology target_topology debug_output:false node_name:"" =
    (
        if source_edges == undefined then return #(false, #{}, "missing source edges")
        if source_topology == undefined or target_topology == undefined then return #(false, #{}, "missing source or target topology")

        source_vertex_count = source_topology[1]
        source_edge_count = source_topology[2]
        source_edge_vertices = source_topology[7]

        target_vertex_count = target_topology[1]
        target_edge_count = target_topology[2]
        target_edge_vertices = target_topology[4]
        target_vertex_edges = target_topology[5]

        if source_vertex_count != target_vertex_count then
        (
            return #(false, #{}, ("vertex topology differs between analysis and Edit Poly. source:" + (source_vertex_count as string) + " target:" + (target_vertex_count as string)))
        )

        if source_edge_count != target_edge_count then
        (
            return #(false, #{}, ("edge topology differs between analysis and Edit Poly. source:" + (source_edge_count as string) + " target:" + (target_edge_count as string)))
        )

        source_to_target = #()
        mapped_target_edges = #{}
        mapped_target_edges.count = target_edge_count

        for source_edge = 1 to source_edge_count do
        (
            source_pair = source_edge_vertices[source_edge]

            if source_pair == undefined or source_pair.count != 2 then
            (
                return #(false, #{}, ("analysis edge has invalid endpoints " + (source_edge as string)))
            )

            source_vertex_a = source_pair[1]
            source_vertex_b = source_pair[2]

            if source_vertex_a < 1 or source_vertex_a > target_vertex_count or source_vertex_b < 1 or source_vertex_b > target_vertex_count then
            (
                return #(false, #{}, ("analysis edge endpoint is outside Edit Poly vertex range " + (source_edge as string)))
            )

            shared_edges = target_vertex_edges[source_vertex_a] * target_vertex_edges[source_vertex_b]

            if shared_edges.numberSet != 1 then
            (
                return #(false, #{}, ("vertex-ID edge mapping failed for analysis edge " + (source_edge as string) + " | verts:" + (source_pair as string) + " | sharedEdges:" + (shared_edges as string)))
            )

            matched_edge = (shared_edges as array)[1]
            target_pair = target_edge_vertices[matched_edge]

            if target_pair == undefined or target_pair.count != 2 then
            (
                return #(false, #{}, ("mapped Edit Poly edge has invalid endpoints " + (matched_edge as string)))
            )

            pair_matches = (target_pair[1] == source_vertex_a and target_pair[2] == source_vertex_b) or (target_pair[1] == source_vertex_b and target_pair[2] == source_vertex_a)

            if not pair_matches then
            (
                return #(false, #{}, ("mapped Edit Poly edge endpoint verification failed for analysis edge " + (source_edge as string)))
            )

            if mapped_target_edges[matched_edge] then
            (
                return #(false, #{}, ("multiple analysis edges map to Edit Poly edge " + (matched_edge as string)))
            )

            mapped_target_edges[matched_edge] = true
            append source_to_target matched_edge
        )

        if mapped_target_edges.numberSet != target_edge_count then
        (
            return #(false, #{}, ("analysis/Edit Poly edge topology is not bijective. mapped:" + (mapped_target_edges.numberSet as string) + " target:" + (target_edge_count as string)))
        )

        resolved_edges = #{}
        resolved_edges.count = target_edge_count

        for source_edge in source_edges do
        (
            if source_edge < 1 or source_edge > source_to_target.count then
            (
                return #(false, #{}, ("invalid detected edge ID " + (source_edge as string)))
            )

            matched_edge = source_to_target[source_edge]
            resolved_edges[matched_edge] = true

            if debug_output and not this.quiet_mode then
            (
                format "EDGE ID MAP | node:% | analysisEdge:% | verts:% | editPolyEdge:%\n" node_name source_edge source_edge_vertices[source_edge] matched_edge
            )
        )

        #(true, resolved_edges, "")
        -- return
    ),

    /*
    Detects one object, resolves analysis edge numbering onto the dedicated Edit Poly through complete vertex-ID topology identity, and stores the mapped edge IDs.
    The complete mapped Edge BitArray is cleared/applied in whole-set Select calls while Edge sub-object mode is explicitly active.
    */
    function selectRedundantLoopsOnNode node face_threshold:0.1 straight_threshold:5.0 debug_output:false select_debug_output:false defer_redraw:false =
    (
        if node == undefined or not(isValidNode node) then return #(false, 0, 0, "invalid node", undefined)

        detection = detectRedundantLoops node face_threshold:face_threshold near_face_threshold:near_face_angle_threshold straight_threshold:straight_threshold debug_output:debug_output
        if not detection[1] then return #(false, 0, 0, detection[4], undefined)

        loop_count = detection[2].count
        redundant_edges = detection[3]
        selected_edge_count = redundant_edges.numberSet
        selector_before_index = if detection.count >= 6 then detection[6] else 0
        selection_modifier = undefined
        created_now = false
        previous_edge_selection = undefined
        operation_error = undefined
        selection_bits = #{}

        try
        (
            if selected_edge_count > 0 then
            (
                modifier_data = this.acquireSelectionModifier node before_index:selector_before_index
                selection_modifier = modifier_data[1]
                created_now = modifier_data[2]

                if selection_modifier == undefined then throw "could not acquire SELECT REDUNDANT LOOPS"
                if not(this.activateSelectionModifier node selection_modifier) then throw "could not activate SELECT REDUNDANT LOOPS"

                if not created_now then
                (
                    previous_edge_selection = copy (selection_modifier.GetSelection #Edge node:node)
                )

                current_topology = this.buildEditPolyEdgeTopology node selection_modifier
                if current_topology == undefined then throw "could not read current SELECT REDUNDANT LOOPS topology"

                edge_map_result = this.resolveEdgesByVertexIds redundant_edges detection[5] current_topology debug_output:select_debug_output node_name:node.name
                if not edge_map_result[1] then throw edge_map_result[3]

                selection_bits = edge_map_result[2]
                selected_edge_count = selection_bits.numberSet

                if select_debug_output and not this.quiet_mode then
                (
                    format "DEBUG SELECT EDGE DOMAIN | node:% | analysisEdges:% | editPolyEdges:% | detected:% | mapped:%\n" node.name detection[5][2] current_topology[2] redundant_edges selection_bits
                )

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
                selection_modifier = this.findSelectionModifier node

                if selection_modifier != undefined then
                (
                    if not(this.activateSelectionModifier node selection_modifier) then throw "could not activate existing SELECT REDUNDANT LOOPS for zero-result clear"

                    previous_edge_selection = copy (selection_modifier.GetSelection #Edge node:node)

                    if previous_edge_selection.numberSet > 0 then
                    (
                        selection_modifier.Select #Edge previous_edge_selection select:false node:node
                    )

                    update node
                    stored_selection = copy (selection_modifier.GetSelection #Edge node:node)

                    if stored_selection.numberSet != 0 then
                    (
                        throw ("zero-result selector clear failed. remaining:" + (stored_selection as string))
                    )

                    selection_modifier.showCage = false

                    if not defer_redraw then
                    (
                        selection_modifier.RefreshScreen()
                        completeRedraw()
                    )
                )
                else
                (
                    update node
                )

                if (debug_output or select_debug_output) and not this.quiet_mode then
                (
                    format "REDUNDANT LOOP ZERO RESULT | node:% | selectorCleared:%\n" node.name (selection_modifier != undefined)
                )
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

            if select_debug_output and not this.quiet_mode then
            (
                final_selected_edges = if selection_modifier != undefined then copy selection_bits else #{}
                format "DEBUG SELECT LOOPS RESULT | node:% | ANGLE:% deg | loops:% | selectedEdges:% | count:%\n" node.name straight_threshold loop_count final_selected_edges final_selected_edges.numberSet
            )

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
    A SELECT REDUNDANT LOOPS modifier is created only for objects with at least one detected redundant edge.
    */
    function selectRedundantLoops face_threshold:0.1 straight_threshold:5.0 debug_output:false select_debug_output:false =
    (
        selected_nodes = selection as array

        if select_debug_output and not this.quiet_mode then
        (
            format "DEBUG SELECT LOOPS SETUP | ANGLE:% deg | faceThreshold:% | objects:%\n" straight_threshold face_threshold selected_nodes.count
        )

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
                result_data = selectRedundantLoopsOnNode node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:debug_output select_debug_output:select_debug_output defer_redraw:true

                if result_data[1] then
                (
                    total_loops += result_data[2]
                    total_edges += result_data[3]

                    if debug_output and not this.quiet_mode then
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

                    format "Redundant-Loop-Fixer SELECT FAILED | node:% | %\n" node.name result_data[4]
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

        if this.quiet_mode then
        (
            format "Redundant-Loop-Fixer SELECT | objects:% | loops:% | edges:% | failures:%\n" selected_nodes.count total_loops total_edges failed_count
        )
        else if debug_output or select_debug_output then
        (
            format "DEBUG SELECT LOOPS COMPLETE | objects:% | loops:% | edges:% | failures:%\n" selected_nodes.count total_loops total_edges failed_count
        )

        #(failed_count == 0, total_loops, total_edges)
        -- return
    ),

    /*
    Removes the exact redundant-loop edge BitArray already stored in SELECT REDUNDANT LOOPS and removes their vertices.
    RMB does not re-detect or position-remap those selected edges before the destructive Edit Poly operation.
    Edit Poly Remove Edge And Vertices uses SetOperation plus Commit instead of the ButtonOp UI-button path.
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
            selection_modifier = this.findSelectionModifier node

            if selection_modifier == undefined then
            (
                detection_result = selectRedundantLoopsOnNode node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:false

                if detection_result[1] and detection_result[3] > 0 then
                (
                    selection_modifier = detection_result[5]
                )
                else if detection_result[1] then
                (
                    failed_count += 1
                    format "Redundant-Loop-Fixer RMB NOTHING TO REMOVE | node:%\n" node.name
                )
                else
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

                    before_vertex_count = EditPolyMod.GetNumVertices selection_modifier node:node
                    before_edge_count = EditPolyMod.GetNumEdges selection_modifier node:node

                    invalid_selected_edges = #{}
                    for edge_index in selected_loop_edges do
                    (
                        if edge_index < 1 or edge_index > before_edge_count then
                        (
                            invalid_selected_edges[edge_index] = true
                        )
                    )

                    if invalid_selected_edges.numberSet > 0 then
                    (
                        throw ("SELECT REDUNDANT LOOPS contains edge IDs outside the active Edit Poly topology: " + (invalid_selected_edges as string))
                    )

                    if not this.quiet_mode then
                    (
                        format "DEBUG RMB REMOVE INPUT | node:% | selectedEdges:% | count:% | verts:% | edges:%\n" node.name selected_loop_edges selected_loop_edges.numberSet before_vertex_count before_edge_count
                    )

                    undo "Remove Redundant Loops" on
                    (
                        if not(forceSelectModeZero selection_modifier) then throw "could not set SELECT REDUNDANT LOOPS selectMode to 0"
                        selection_modifier.SetEPolySelLevel #Edge
                        subObjectLevel = 2
                        modPanel.setCurrentObject selection_modifier node:node

                        selection_modifier.SetOperation #RemoveEdgeRemoveVertices
                        selection_modifier.Commit()
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

        if this.quiet_mode then
        (
            format "Redundant-Loop-Fixer REMOVE | objects:% | removed:% | failures:%\n" selected_nodes.count removed_nodes.count failed_count
        )

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

            polyop.setEdgeSelection node.baseObject #{}
            polyop.setEdgeSelection node.baseObject edge_bits

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
    Creates a quad grid with enough internal topology for native Editable Poly loop regression tests.
    The grid is intentionally simple for native EditablePoly loop regression tests.
    */
    function createNativeLoopGridTestObject x_offset:130.0 =
    (
        test_node = plane name:(uniqueName "RLF_NATIVE_LOOP_TEST_") width:30.0 length:30.0 widthsegs:3 lengthsegs:3
        test_node.pos = [x_offset, 0.0, 0.0]
        convertTo test_node Editable_Poly
        test_node.baseObject.showCage = off
        if not(forceSelectModeZero test_node.baseObject) then throw "could not set native-loop grid Editable Poly selectMode to 0"
        test_node
        -- return
    ),

    /*
    Verifies native EditablePoly SelectEdgeLoop expands a real multi-edge loop on a disposable quad-grid analysis copy.
    The source object's edge selection must remain untouched by analysis.
    */
    function testNativeEditablePolyMultiEdgeLoop =
    (
        test_node = undefined
        analysis_source = undefined
        test_ok = false
        error_text = ""

        try
        (
            test_node = createNativeLoopGridTestObject x_offset:125.0
            source_selection = #{1}
            polyop.setEdgeSelection test_node.baseObject source_selection

            analysis_source = acquireAnalysisSource test_node
            if analysis_source == undefined then throw "could not acquire native loop analysis source"

            analysis_node = analysis_source[1]
            analysis_poly = analysis_source[2]
            topology_data = buildPolyTopology analysis_node analysis_poly
            if topology_data == undefined then throw "could not read native loop analysis topology"

            crease_edges = getCreaseEdges analysis_poly topology_data[2]
            candidate_edges = buildCandidateEdges topology_data crease_edges
            loop_result = buildNativeEdgeLoopRecords analysis_node candidate_edges debug_output:true
            if not loop_result[1] then throw loop_result[3]

            multi_edge_loop_found = false

            for loop_record in loop_result[2] while not multi_edge_loop_found do
            (
                if loop_record[1].numberSet > 1 then multi_edge_loop_found = true
            )

            source_selection_unchanged = polyop.getEdgeSelection test_node.baseObject == source_selection
            test_ok = multi_edge_loop_found and source_selection_unchanged

            if not test_ok then
            (
                error_text = "native loop did not expand or analysis changed source edge selection"
            )
        )
        catch
        (
            error_text = getCurrentException() as string
            test_ok = false
        )

        if analysis_source != undefined then releaseAnalysisSource analysis_source

        #(test_ok, test_node, error_text)
        -- return
    ),

    /*
    Verifies native loop discovery uses the EditablePoly interface on a disposable analysis node and accepts a valid singleton divider.
    This guards both the API receiver and the single-edge redundant-loop contract.
    */
    function testNativeEditablePolyLoopPath =
    (
        test_node = undefined
        test_ok = false
        error_text = ""

        try
        (
            test_data = createDividerTestObject creased:false x_offset:130.0
            test_node = test_data[1]
            divider_edge = test_data[2]
            detection_result = detectRedundantLoops test_node face_threshold:0.1 near_face_threshold:near_face_angle_threshold straight_threshold:5.0 debug_output:true

            test_ok = detection_result[1] and detection_result[2].count == 1 and detection_result[3] == #{divider_edge}

            if not test_ok then
            (
                error_text = "native EditablePoly loop detection did not preserve the valid singleton divider"
            )
        )
        catch
        (
            error_text = getCurrentException() as string
            test_ok = false
        )

        #(test_ok, test_node, error_text)
        -- return
    ),

    /*
    Verifies that debug selection maps analysis edge IDs into live Edit Poly edge IDs before writing selection.
    A deliberately reordered source edge table must select the corresponding live edge rather than the raw source ID.
    */
    function testDebugSelectionMapping =
    (
        test_node = undefined
        test_ok = false
        error_text = ""

        try
        (
            test_data = createDividerTestObject creased:false x_offset:170.0
            test_node = test_data[1]
            modifier_data = acquireSelectionModifier test_node
            selection_modifier = modifier_data[1]

            if selection_modifier == undefined then throw "could not acquire debug mapping selector"
            if not(activateSelectionModifier test_node selection_modifier) then throw "could not activate debug mapping selector"

            target_topology = buildEditPolyEdgeTopology test_node selection_modifier
            if target_topology == undefined then throw "could not read debug mapping target topology"
            if target_topology[2] < 2 then throw "debug mapping test requires at least two edges"

            reordered_edges = copy target_topology[4]
            first_pair = reordered_edges[1]
            reordered_edges[1] = reordered_edges[2]
            reordered_edges[2] = first_pair

            source_topology = #(target_topology[1], target_topology[2], undefined, undefined, undefined, undefined, reordered_edges)
            source_edges = #{1}
            expected_edges = #{2}
            write_result = writeDebugEdgeSelection test_node source_edges source_topology
            stored_edges = copy (selection_modifier.GetSelection #Edge node:test_node)

            test_ok = write_result[1] and stored_edges == expected_edges
            if not test_ok then error_text = "debug selection did not remap reordered source edge IDs"
        )
        catch
        (
            error_text = getCurrentException() as string
            test_ok = false
        )

        #(test_ok, test_node, error_text)
        -- return
    ),

    /*
    Verifies analysis keeps the true evaluated top-of-stack topology when SELECT REDUNDANT LOOPS is buried.
    A topology-changing Edit Poly above the selector must remain visible to the disposable analysis copy.
    */
    function testEvaluatedAnalysisUsesTopOfStack =
    (
        test_node = undefined
        analysis_source = undefined
        test_ok = false
        error_text = ""

        try
        (
            test_data = createDividerTestObject creased:false x_offset:205.0
            test_node = test_data[1]
            divider_edge = test_data[2]

            selector_data = acquireSelectionModifier test_node
            buried_selector = selector_data[1]
            if buried_selector == undefined then throw "could not create buried selector test modifier"

            top_edit_poly = Edit_Poly name:"RLF TOP TOPOLOGY CHANGE"
            top_edit_poly.showCage = false
            addModifier test_node top_edit_poly

            select test_node
            max modify mode
            if not(forceSelectModeZero top_edit_poly) then throw "could not set top Edit Poly selectMode to 0"
            top_edit_poly.SetPrimaryNode test_node
            top_edit_poly.useStackSelection = false
            top_edit_poly.showCage = false
            modPanel.setCurrentObject top_edit_poly node:test_node
            top_edit_poly.SetEPolySelLevel #Edge
            subObjectLevel = 2
            top_edit_poly.Select #Edge #{divider_edge} select:true node:test_node
            top_edit_poly.SetOperation #RemoveEdgeRemoveVertices
            top_edit_poly.Commit()
            update test_node

            buried_edge_count = EditPolyMod.GetNumEdges buried_selector node:test_node
            top_edge_count = EditPolyMod.GetNumEdges top_edit_poly node:test_node
            if top_edge_count >= buried_edge_count then throw "top Edit Poly did not reduce topology for evaluated-stack test"

            analysis_source = acquireAnalysisSource test_node
            if analysis_source == undefined then throw "could not acquire evaluated top-of-stack analysis source"

            analysis_edge_count = polyop.getNumEdges analysis_source[2]
            test_ok = analysis_edge_count == top_edge_count and analysis_edge_count != buried_edge_count

            if not test_ok then
            (
                error_text = "analysis topology does not match evaluated top-of-stack topology"
            )
        )
        catch
        (
            error_text = getCurrentException() as string
            test_ok = false
        )

        if analysis_source != undefined then releaseAnalysisSource analysis_source

        #(test_ok, test_node, error_text)
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

        remap_source_topology = #(4, 3, undefined, undefined, undefined, undefined, #(#(1,2), #(2,3), #(3,4)))
        remap_target_topology = #(4, 3, undefined, #(#(3,4), #(1,2), #(2,3)), #(#{2}, #{2,3}, #{1,3}, #{1}))
        remap_result = resolveEdgesByVertexIds #{1,3} remap_source_topology remap_target_topology
        edge_id_remap_ok = remap_result[1] and remap_result[2] == #{1,2}

        all_first_records = #(#(#{1,2}, 1, 2), #(#{3,4}, 3, 4), #(#{5,6}, 5, 6))
        all_first_border_edges = #{3}
        all_first_wall_edges = #{5}
        all_first_survivors = #{}

        for all_first_record in all_first_records do
        (
            if not(this.loopRecordIntersectsEdges all_first_record all_first_border_edges) and not(this.loopRecordIntersectsEdges all_first_record all_first_wall_edges) then
            (
                all_first_survivors += all_first_record[1]
            )
        )

        all_first_filter_ok = all_first_survivors == #{1,2}

        #(straight_border_ok, border_corner_rejected, border_branch_rejected, internal_border_corner_rejected, corner_launch_ok, loop_corner_accepted_at_5, corner_trace_around_90_ok, ring_bend_rejected_at_20, ring_bend_accepted_at_45, ring_right_angle_rejected_at_45, wall_corner_normal_split_detected, edge_id_remap_ok, all_first_filter_ok)
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
    Runs regression tests for the design.md selection and removal contract.
    Native-loop integrity, debug edge-ID remapping, classifier rules, and RMB success/failure semantics are covered explicitly.
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
        format "TEST analysis edge IDs remap by vertex topology after edge renumbering: %\n" topology_result[12]
        format "TEST all loops are built first, then whole border/wall loops are filtered: %\n" topology_result[13]

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

        native_multi_result = testNativeEditablePolyMultiEdgeLoop()
        native_multi_test = native_multi_result[2]
        format "TEST native EditablePoly SelectEdgeLoop expands a multi-edge loop on disposable copy: % | error:%\n" native_multi_result[1] native_multi_result[3]
        if not native_multi_result[1] then test_passed = false

        native_loop_path_result = testNativeEditablePolyLoopPath()
        native_loop_path_test = native_loop_path_result[2]
        format "TEST native EditablePoly loop detection accepts the valid singleton divider: % | error:%\n" native_loop_path_result[1] native_loop_path_result[3]
        if not native_loop_path_result[1] then test_passed = false

        debug_mapping_result = testDebugSelectionMapping()
        debug_mapping_test = debug_mapping_result[2]
        format "TEST debug selection remaps analysis edge IDs before live Edit Poly write: % | error:%\n" debug_mapping_result[1] debug_mapping_result[3]
        if not debug_mapping_result[1] then test_passed = false

        evaluated_stack_result = testEvaluatedAnalysisUsesTopOfStack()
        evaluated_stack_test = evaluated_stack_result[2]
        format "TEST buried selector analysis still uses true evaluated top-of-stack topology: % | error:%\n" evaluated_stack_result[1] evaluated_stack_result[3]
        if not evaluated_stack_result[1] then test_passed = false

        plain_test = undefined
        crease_test = undefined
        t_test = undefined
        corner_test = undefined
        remove_test = undefined
        no_op_test = undefined

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
            corner_ok = corner_result[1] and corner_result[3] == 0 and corner_modifier_preserved and corner_selection.numberSet == 0
            format "TEST zero-result clears stale selector edges: % | edge:% | stored:% | modifierPreserved:% | error:%\n" corner_ok corner_edge corner_selection corner_modifier_preserved corner_result[4]
            if not corner_ok then test_passed = false

            remove_data = createDividerTestObject creased:false x_offset:100.0
            remove_test = remove_data[1]
            remove_select_result = selectRedundantLoopsOnNode remove_test face_threshold:0.1 straight_threshold:5.0 debug_output:true
            remove_selector = remove_select_result[5]
            remove_before_vertices = if remove_selector != undefined then EditPolyMod.GetNumVertices remove_selector node:remove_test else 0
            remove_before_edges = if remove_selector != undefined then EditPolyMod.GetNumEdges remove_selector node:remove_test else 0

            select remove_test
            remove_result = removeSelectedRedundantLoops face_threshold:0.1 straight_threshold:5.0
            remove_after_vertices = if remove_selector != undefined then EditPolyMod.GetNumVertices remove_selector node:remove_test else remove_before_vertices
            remove_after_edges = if remove_selector != undefined then EditPolyMod.GetNumEdges remove_selector node:remove_test else remove_before_edges
            remove_ok = remove_select_result[1] and remove_selector != undefined and remove_result and remove_after_vertices < remove_before_vertices and remove_after_edges < remove_before_edges
            format "TEST RMB remove commits topology: % | verts:%->% | edges:%->%\n" remove_ok remove_before_vertices remove_after_vertices remove_before_edges remove_after_edges
            if not remove_ok then test_passed = false

            no_op_data = createBorderCornerTestObject x_offset:210.0
            no_op_test = no_op_data[1]
            select no_op_test
            no_op_result = removeSelectedRedundantLoops face_threshold:0.1 straight_threshold:5.0
            no_op_ok = not no_op_result
            format "TEST RMB no-op reports failure instead of success: %\n" no_op_ok
            if not no_op_ok then test_passed = false
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
        if remove_test != undefined then try(delete remove_test)catch(getCurrentException())
        if no_op_test != undefined then try(delete no_op_test)catch(getCurrentException())
        if native_multi_test != undefined then try(delete native_multi_test)catch(getCurrentException())
        if native_loop_path_test != undefined then try(delete native_loop_path_test)catch(getCurrentException())
        if debug_mapping_test != undefined then try(delete debug_mapping_test)catch(getCurrentException())
        if evaluated_stack_test != undefined then try(delete evaluated_stack_test)catch(getCurrentException())

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
    Returns the tool title from this file's own version.
    The visible title must always match file_version and the numeric versioned filename.
    */
    function getDisplayTitle =
    (
        "Redundant-Loop-Fixer | v" + (file_version as string)
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
    Saves QUIET mode. QUIET suppresses verbose process diagnostics while preserving errors and final operation summaries.
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
    Loads QUIET mode, defaulting to enabled when no setting exists.
    */
    function loadQuietMode =
    (
        settings_path = this.getSettingsPath()
        quiet_text = try(getINISetting settings_path "Settings" "Quiet")catch((getCurrentException(); ""))
        quiet_value = quiet_text != "false"
        this.quiet_mode = quiet_value
        quiet_value
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

RedundantLoopFixer0834 = RedundantLoopFixer0834_v()
RedundantLoopFixer = RedundantLoopFixer0834

if epoly_tools_project_version == undefined or epoly_tools_project_version < RedundantLoopFixer.project_version then
(
    epoly_tools_project_version = RedundantLoopFixer.project_version
)

rollout RedundantLoopFixer_UI "Redundant-Loop-Fixer | v0.834" width:286 height:272
(
    button btn_select_remove "SELECT | REMOVE" pos:[12,8] width:262 height:40 tooltip:"LMB: Detect and select redundant loops.\n\nRMB: Remove the selected redundant-loop edges and their vertices."
    button btn_debug_all "1  SELECT ALL LOOPS" pos:[12,60] width:262 height:24 tooltip:"DEBUG 1: Select all native Editable Poly loops seeded by internal removable edges before filtering."
    button btn_debug_border "2  SELECT BORDER CORNER LOOPS" pos:[12,88] width:262 height:24 tooltip:"DEBUG 2: Select complete native loops that touch a border corner or border branch."
    button btn_debug_wall_corner "3  SELECT WALL CORNER LOOP" pos:[12,116] width:262 height:24 tooltip:"DEBUG 3: Select internal candidate loops on wall corners where the two adjacent face normals belong to different planes. Uses the existing 1 degree near-face threshold; ANGLE is ignored."
    button btn_debug_angle "4  SELECT ANGLED LOOPS" pos:[12,144] width:262 height:24 tooltip:"DEBUG 4: Select complete loops whose ring edges deviate from straight by more than ANGLE. Turns along the loop are ignored."
    checkbox chk_quiet "QUIET" pos:[12,178] width:72 height:20 checked:true tooltip:"Suppress detailed Listener diagnostics. Errors and final operation summaries are still printed."
    spinner spn_straight_angle "ANGLE:" pos:[12,210] width:112 range:[0.0,45.0,5.0] type:#float scale:0.1 fieldwidth:46 tooltip:"Maximum deviation from straight for ring edges crossing the detected loop. Turns along the loop are ignored."
    label lbl_straight_units "deg" pos:[126,212] width:28 height:16
    button btn_get_angle "GET ANGLE" pos:[147,204] width:127 height:24 tooltip:"LMB: Read exactly two selected ring edges and set ANGLE to their deviation from straight."
    button btn_restart "RESTART" pos:[12,240] width:262 height:24 tooltip:"LMB: Load the highest numeric Redundant-Loop-Fixer version from this script directory."

    on RedundantLoopFixer_UI open do
    (
        chk_quiet.checked = RedundantLoopFixer.loadQuietMode()
        spn_straight_angle.value = RedundantLoopFixer.loadStraightAngleThreshold()
    )

    on RedundantLoopFixer_UI moved dialog_pos do
    (
        dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch((getCurrentException(); false))
        if dialog_is_standalone then RedundantLoopFixer.saveDialogPosition dialog_pos
    )

    on chk_quiet changed quiet_value do
    (
        RedundantLoopFixer.saveQuietMode quiet_value
    )

    on spn_straight_angle changed angle_value do
    (
        saved_ok = RedundantLoopFixer.saveStraightAngleThreshold angle_value
        if not RedundantLoopFixer.quiet_mode then format "DEBUG ANGLE SET | value:% deg | saved:%\n" angle_value saved_ok
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
        RedundantLoopFixer.debugSelectAngledLoops spn_straight_angle.value
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
            selected_edges = RedundantLoopFixer.getCurrentSelectedEdges selection[1]
            selected_edge_count = if selected_edges != undefined then selected_edges.numberSet else 0
            if not RedundantLoopFixer.quiet_mode then
            (
                format "DEBUG GET ANGLE INPUT | node:% | selectedEdges:% | count:%\n" selection[1].name selected_edges selected_edge_count
            )

            angle_result = RedundantLoopFixer.getSelectedEdgeStraightAngle selection[1]

            if angle_result[1] then
            (
                measured_angle = angle_result[2]
                if not RedundantLoopFixer.quiet_mode then
                (
                    format "DEBUG GET ANGLE RESULT | node:% | selectedEdges:% | measured:% deg\n" selection[1].name selected_edges measured_angle
                )

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

    on btn_select_remove pressed do
    (
        RedundantLoopFixer.selectRedundantLoops face_threshold:0.1 straight_threshold:spn_straight_angle.value debug_output:false select_debug_output:(not RedundantLoopFixer.quiet_mode)
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
