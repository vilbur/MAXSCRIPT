/*
    Degenerate Face Selector 0.06
    Selects and repairs near-zero-area and long thin sliver faces using real Editable Poly topology.
*/

global DegenerateFaceSelector
global DegenerateFaceSelector_UI

struct DegenerateFaceSelector_v
(
    file_version = 0.06,
    default_sliver_ratio = 0.001,
    area_epsilon = 0.00000001,
    zero_area_epsilon = 0.000000000001,
    length_epsilon = 0.00000001,
    coincident_tolerance = 0.0001,
    collinear_ratio_tolerance = 0.000001,

    /*
    Forces Editable Poly or Edit Poly into normal component selection mode.
    Every selection operation in this tool uses selectMode 0.
    */
    function forceSelectModeZero editable_poly =
    (
        if editable_poly == undefined then return false

        try(editable_poly.selectMode = 0)catch()
        true
        -- return
    ),

    /*
    Returns the currently active Edit Poly modifier for one node when possible.
    The Modify-panel object is preferred; otherwise the top Edit Poly is used.
    */
    function getActiveEditPoly node =
    (
        if node == undefined or not(isValidNode node) then return undefined

        current_object = undefined
        try(current_object = modPanel.getCurrentObject())catch()

        if current_object != undefined and classOf current_object == Edit_Poly then
        (
            current_on_node = false

            for modifier_index = 1 to node.modifiers.count while not current_on_node do
            (
                if node.modifiers[modifier_index] == current_object then current_on_node = true
            )

            if current_on_node then return current_object
        )

        if node.modifiers.count > 0 then
        (
            top_modifier = node.modifiers[1]
            if classOf top_modifier == Edit_Poly then return top_modifier
        )

        undefined
        -- return
    ),

    /*
    Acquires evaluated top-of-stack geometry for read-only polygon analysis.
    A modifier-free Editable Poly is read directly; otherwise a disposable collapsed copy is used.
    */
    function acquireAnalysisSource node =
    (
        if node == undefined or not(isValidNode node) then return undefined

        if classOf node.baseObject == Editable_Poly and node.modifiers.count == 0 then
        (
            forceSelectModeZero node.baseObject
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
                    temp_node.name = uniqueName "__DEGENERATE_FACE_SCAN__"
                    convertToPoly temp_node

                    if classOf temp_node.baseObject != Editable_Poly then throw "evaluated copy is not Editable Poly"
                    forceSelectModeZero temp_node.baseObject
                    result_data = #(temp_node, temp_node.baseObject, true)
                )
            )
            catch
            (
                if temp_node != undefined then try(delete temp_node)catch()
                result_data = undefined
            )

            result_data
        )
        -- return
    ),

    /*
    Releases only a disposable analysis copy.
    The user's real object and modifier stack are never collapsed by the detector.
    */
    function releaseAnalysisSource analysis_source =
    (
        if analysis_source == undefined then return false

        if analysis_source[3] then
        (
            analysis_node = analysis_source[1]

            if analysis_node != undefined and isValidNode analysis_node then
            (
                with undo off
                (
                    try(delete analysis_node)catch()
                )
            )
        )

        true
        -- return
    ),

    /*
    Returns ordered world-space points for one Editable Poly face.
    Undefined is returned for invalid or incomplete face topology.
    */
    function getFaceWorldPoints node poly_value face_index =
    (
        face_vertices = polyop.getFaceVerts poly_value face_index
        if face_vertices == undefined or face_vertices.count < 3 then return undefined

        face_points = #()

        for vertex_index in face_vertices do
        (
            vertex_point = undefined

            in coordsys world
            (
                vertex_point = polyop.getVert poly_value vertex_index node:node
            )

            if vertex_point == undefined then return undefined
            append face_points vertex_point
        )

        face_points
        -- return
    ),

    /*
    Returns ordered world-space points for one face directly from the exact Edit Poly modifier topology.
    Detection and final selection therefore share the same face IDs with no cross-topology index transfer.
    */
    function getModifierFaceWorldPoints node modifier face_index =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if modifier == undefined or classOf modifier != Edit_Poly then return undefined

        forceSelectModeZero modifier
        modifier.SetPrimaryNode node

        face_count = modifier.GetNumFaces node:node
        if face_index < 1 or face_index > face_count then return undefined

        face_degree = modifier.GetFaceDegree face_index node:node
        if face_degree < 3 then return undefined

        face_points = #()
        object_tm = node.objectTransform

        for corner_index = 1 to face_degree do
        (
            vertex_index = modifier.GetFaceVertex face_index corner_index node:node
            if vertex_index < 1 then return undefined

            vertex_point = modifier.GetVertex vertex_index node:node
            if vertex_point == undefined then return undefined

            append face_points (vertex_point * object_tm)
        )

        face_points
        -- return
    ),

    /*
    Computes planar polygon area from ordered points using the vector-area form of Newell's method.
    The magnitude approaches zero for collapsed and long thin sliver faces.
    */
    function getPolygonArea face_points =
    (
        if face_points == undefined or face_points.count < 3 then return 0.0

        area_vector = [0,0,0]
        point_count = face_points.count
        origin_point = face_points[1]

        for point_index = 1 to point_count do
        (
            next_index = if point_index == point_count then 1 else point_index + 1
            point_a = face_points[point_index] - origin_point
            point_b = face_points[next_index] - origin_point
            area_vector += cross point_a point_b
        )

        0.5 * (length area_vector)
        -- return
    ),

    /*
    Returns the longest polygon boundary edge length in world space.
    Hidden triangulation diagonals are never included because only ordered face boundary vertices are used.
    */
    function getLongestBoundaryEdge face_points =
    (
        if face_points == undefined or face_points.count < 2 then return 0.0

        longest_edge = 0.0
        point_count = face_points.count

        for point_index = 1 to point_count do
        (
            next_index = if point_index == point_count then 1 else point_index + 1
            edge_length = distance face_points[point_index] face_points[next_index]
            if edge_length > longest_edge then longest_edge = edge_length
        )

        longest_edge
        -- return
    ),

    /*
    Returns #(area, longestEdge, quality) for one polygon.
    quality is area divided by longestEdge squared and is therefore scale independent.
    */
    function getFaceQuality face_points =
    (
        face_area = getPolygonArea face_points
        longest_edge = getLongestBoundaryEdge face_points
        quality_value = 0.0

        if longest_edge > length_epsilon then
        (
            quality_value = face_area / (longest_edge * longest_edge)
        )

        #(face_area, longest_edge, quality_value)
        -- return
    ),

    /*
    Tests one face for true near-zero area or an extremely small scale-independent sliver ratio.
    Uniformly small but well-shaped faces are not selected merely because their raw area is small.
    */
    function isDegenerateFace node poly_value face_index sliver_ratio:0.001 =
    (
        face_points = getFaceWorldPoints node poly_value face_index
        if face_points == undefined then return true

        quality_data = getFaceQuality face_points
        face_area = quality_data[1]
        longest_edge = quality_data[2]
        quality_value = quality_data[3]

        if face_area <= area_epsilon then return true
        if longest_edge <= length_epsilon then return true

        quality_value <= sliver_ratio
        -- return
    ),

    /*
    Finds every degenerate/sliver polygon directly on the exact Edit Poly modifier topology.
    Returned IDs are immediately safe for SetSelection on that same modifier.
    */
    function findCandidateFaces node selection_modifier sliver_ratio:0.001 debug_output:false =
    (
        result_faces = #{}
        if node == undefined or not(isValidNode node) then return result_faces
        if selection_modifier == undefined or classOf selection_modifier != Edit_Poly then return result_faces

        forceSelectModeZero selection_modifier
        selection_modifier.SetPrimaryNode node
        face_count = selection_modifier.GetNumFaces node:node

        for face_index = 1 to face_count do
        (
            face_points = getModifierFaceWorldPoints node selection_modifier face_index

            if face_points != undefined then
            (
                quality_data = getFaceQuality face_points
                is_candidate = quality_data[1] <= area_epsilon or quality_data[2] <= length_epsilon or quality_data[3] <= sliver_ratio

                if is_candidate then
                (
                    result_faces[face_index] = true

                    if debug_output then
                    (
                        format "DEGENERATE FACE | node:% | face:% | area:% | longest:% | ratio:%\n" node.name face_index quality_data[1] quality_data[2] quality_data[3]
                    )
                )
            )
            else
            (
                result_faces[face_index] = true

                if debug_output then
                (
                    format "DEGENERATE FACE | node:% | face:% | reason:invalid live Edit Poly face points\n" node.name face_index
                )
            )
        )

        result_faces
        -- return
    ),

    /*
    Returns or creates the dedicated top Edit Poly modifier used to display face selection.
    Unrelated Edit Poly modifiers are never reused.
    */
    function getSelectionModifier node =
    (
        if node.modifiers.count > 0 then
        (
            top_modifier = node.modifiers[1]

            if classOf top_modifier == Edit_Poly and top_modifier.name == "DEGENERATE FACES" then
            (
                forceSelectModeZero top_modifier
                return top_modifier
            )
        )

        selection_modifier = Edit_Poly name:"DEGENERATE FACES"
        addModifier node selection_modifier
        forceSelectModeZero selection_modifier
        selection_modifier.showCage = false
        selection_modifier.useStackSelection = false
        selection_modifier.SetPrimaryNode node
        selection_modifier.SetEPolySelLevel #Face
        selection_modifier
        -- return
    ),

    /*
    Activates the dedicated modifier at Polygon/Face sub-object level.
    selectMode remains 0 and Show Cage is disabled.
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
            forceSelectModeZero selection_modifier
            if classOf node.baseObject == Editable_Poly then forceSelectModeZero node.baseObject
            selection_modifier.SetPrimaryNode node
            selection_modifier.useStackSelection = false
            selection_modifier.showCage = false
            modPanel.setCurrentObject selection_modifier node:node
            selection_modifier.SetEPolySelLevel #Face
            subObjectLevel = 4
            update node
        )
        catch
        (
            activated = false
        )

        activated
        -- return
    ),

    /*
    Selects degenerate/sliver faces on the first selected object.
    The dedicated modifier remains active at Polygon level with the detected faces visibly selected.
    */
    function selectCandidates sliver_ratio:0.001 debug_output:true =
    (
        if selection.count == 0 then
        (
            messageBox "Select one geometry object." title:"Degenerate Face Selector"
            return false
        )

        node = selection[1]

        if node.modifiers.count > 0 then
        (
            top_modifier = node.modifiers[1]

            if classOf top_modifier == Edit_Poly and top_modifier.name == "DEGENERATE FACES" then
            (
                subObjectLevel = 0
                deleteModifier node top_modifier
                update node
            )
        )

        selection_modifier = Edit_Poly name:"DEGENERATE FACES"
        addModifier node selection_modifier
        selection_modifier.selectMode = 0
        selection_modifier.showCage = false
        selection_modifier.useStackSelection = false
        selection_modifier.SetPrimaryNode node

        candidate_faces = findCandidateFaces node selection_modifier sliver_ratio:sliver_ratio debug_output:debug_output

        if candidate_faces.numberSet == 0 then
        (
            deleteModifier node selection_modifier
            update node
            format "Degenerate Face Selector | node:% | selectedFaces:0 | ratio<=%\n" node.name sliver_ratio
            return true
        )

        select node
        max modify mode
        modPanel.setCurrentObject selection_modifier node:node
        selection_modifier.SetPrimaryNode node
        selection_modifier.selectMode = 0
        selection_modifier.showCage = false
        selection_modifier.useStackSelection = false
        selection_modifier.SetEPolySelLevel #Face
        subObjectLevel = 4

        /* Exact direct Edit Poly selection command. */
        selection_modifier.Select #Face candidate_faces

        update node
        selection_modifier.RefreshScreen()
        redrawViews()

        format "Degenerate Face Selector | node:% | selectedFaces:% | faces:% | ratio<=%\n" node.name candidate_faces.numberSet candidate_faces sliver_ratio
        true
        -- return
    ),

    /*
    Returns ordered live Edit Poly vertex IDs for one polygon face.
    IDs belong to the same modifier topology that receives all repair operations.
    */
    function getModifierFaceVertexIds node modifier face_index =
    (
        if node == undefined or not(isValidNode node) then return #()
        if modifier == undefined or classOf modifier != Edit_Poly then return #()

        face_count = modifier.GetNumFaces node:node
        if face_index < 1 or face_index > face_count then return #()

        face_degree = modifier.GetFaceDegree face_index node:node
        if face_degree < 3 then return #()

        vertex_ids = #()

        for corner_index = 1 to face_degree do
        (
            vertex_index = modifier.GetFaceVertex face_index corner_index node:node
            if vertex_index < 1 then return #()
            append vertex_ids vertex_index
        )

        vertex_ids
        -- return
    ),

    /*
    Returns one live Edit Poly vertex position in world space.
    Undefined is returned for an invalid current vertex ID.
    */
    function getModifierVertexWorldPoint node modifier vertex_index =
    (
        if node == undefined or not(isValidNode node) then return undefined
        if modifier == undefined or classOf modifier != Edit_Poly then return undefined
        if vertex_index < 1 or vertex_index > (modifier.GetNumVertices node:node) then return undefined

        vertex_point = modifier.GetVertex vertex_index node:node
        if vertex_point == undefined then return undefined

        vertex_point * node.objectTransform
        -- return
    ),

    /*
    Selects one component BitArray on the already active dedicated Edit Poly modifier.
    The Modify panel is not reopened here; only the sub-object level and local selection are changed.
    */
    function selectModifierComponents node modifier component_level component_bits =
    (
        if node == undefined or not(isValidNode node) then return false
        if modifier == undefined or classOf modifier != Edit_Poly then return false

        forceSelectModeZero modifier
        modifier.SetPrimaryNode node

        sub_object_level = 0
        case component_level of
        (
            #Vertex: sub_object_level = 1
            #Edge: sub_object_level = 2
            #Face: sub_object_level = 4
            default: return false
        )

        modifier.SetEPolySelLevel component_level
        subObjectLevel = sub_object_level

        old_selection = modifier.GetSelection component_level
        if old_selection.numberSet > 0 then modifier.Select component_level old_selection select:false

        if component_bits != undefined and component_bits.numberSet > 0 then modifier.Select component_level component_bits

        true
        -- return
    ),

    /*
    Finds groups of two or more vertices on one face that occupy the same world-space position.
    Each returned item is a BitArray containing the coincident live vertex IDs.
    */
    function getCoincidentFaceVertexGroups node modifier face_index tolerance:0.0001 =
    (
        vertex_ids = getModifierFaceVertexIds node modifier face_index
        groups = #()
        used_vertices = #{}

        for vertex_index in vertex_ids do
        (
            if not used_vertices[vertex_index] then
            (
                base_point = getModifierVertexWorldPoint node modifier vertex_index
                group_bits = #{}

                if base_point != undefined then
                (
                    for compare_index in vertex_ids do
                    (
                        if not used_vertices[compare_index] then
                        (
                            compare_point = getModifierVertexWorldPoint node modifier compare_index

                            if compare_point != undefined and distance base_point compare_point <= tolerance then
                            (
                                group_bits[compare_index] = true
                            )
                        )
                    )
                )

                if group_bits.numberSet >= 2 then
                (
                    append groups group_bits
                    used_vertices = used_vertices + group_bits
                )
                else
                (
                    used_vertices[vertex_index] = true
                )
            )
        )

        groups
        -- return
    ),

    /*
    Counts all current live vertices near one world-space position.
    This verifies whether a collapse operation actually reduced coincident topology.
    */
    function countModifierVerticesNearPoint node modifier target_point tolerance:0.0001 =
    (
        if target_point == undefined then return 0

        vertex_count = modifier.GetNumVertices node:node
        match_count = 0

        for vertex_index = 1 to vertex_count do
        (
            vertex_point = getModifierVertexWorldPoint node modifier vertex_index
            if vertex_point != undefined and distance vertex_point target_point <= tolerance then match_count += 1
        )

        match_count
        -- return
    ),

    /*
    Returns true when any three polygon vertices are effectively collinear.
    The cross-product magnitude is normalized by squared segment scale for unit-independent testing.
    */
    function hasCollinearFaceTriple face_points ratio_tolerance:0.000001 =
    (
        if face_points == undefined or face_points.count < 3 then return false

        point_count = face_points.count

        for index_a = 1 to point_count - 2 do
        (
            for index_b = index_a + 1 to point_count - 1 do
            (
                for index_c = index_b + 1 to point_count do
                (
                    point_a = face_points[index_a]
                    point_b = face_points[index_b]
                    point_c = face_points[index_c]
                    vector_ab = point_b - point_a
                    vector_ac = point_c - point_a
                    length_ab = length vector_ab
                    length_ac = length vector_ac
                    scale_value = if length_ab > length_ac then length_ab else length_ac

                    if scale_value > length_epsilon then
                    (
                        collinear_ratio = (length (cross vector_ab vector_ac)) / (scale_value * scale_value)
                        if collinear_ratio <= ratio_tolerance then return true
                    )
                )
            )
        )

        false
        -- return
    ),

    /*
    Attempts to collapse one coincident vertex group.
    If direct Collapse Vertex makes no change, Connect Vertices is tried first and Collapse Vertex is attempted again.
    */
    function fixCoincidentVertexGroup node modifier vertex_bits tolerance:0.0001 =
    (
        if vertex_bits == undefined or vertex_bits.numberSet < 2 then return undefined

        first_vertex = undefined
        for vertex_index in vertex_bits while first_vertex == undefined do first_vertex = vertex_index
        target_point = getModifierVertexWorldPoint node modifier first_vertex
        if target_point == undefined then return undefined

        before_count = countModifierVerticesNearPoint node modifier target_point tolerance:tolerance

        selectModifierComponents node modifier #Vertex vertex_bits
        modifier.ButtonOp #CollapseVertex
        update node

        after_direct_count = countModifierVerticesNearPoint node modifier target_point tolerance:tolerance
        if after_direct_count < before_count then return #(#collapse, before_count, after_direct_count)

        valid_bits = #{}
        current_vertex_count = modifier.GetNumVertices node:node
        for vertex_index in vertex_bits do
        (
            if vertex_index <= current_vertex_count then valid_bits[vertex_index] = true
        )

        if valid_bits.numberSet < 2 then return undefined

        selectModifierComponents node modifier #Vertex valid_bits
        modifier.ButtonOp #ConnectVertices
        update node

        current_vertex_count = modifier.GetNumVertices node:node
        retry_bits = #{}
        for vertex_index in valid_bits do
        (
            if vertex_index <= current_vertex_count then retry_bits[vertex_index] = true
        )

        if retry_bits.numberSet < 2 then return undefined

        selectModifierComponents node modifier #Vertex retry_bits
        modifier.ButtonOp #CollapseVertex
        update node

        after_connect_count = countModifierVerticesNearPoint node modifier target_point tolerance:tolerance
        if after_connect_count < before_count then return #(#connectCollapse, before_count, after_connect_count)

        undefined
        -- return
    ),

    /*
    Returns one ordered polygon point chain between two face corners, wrapping around the polygon boundary when required.
    The returned chain includes both end corners.
    */
    function getWrappedFacePointChain face_points start_index end_index =
    (
        result_points = #()
        if face_points == undefined or face_points.count < 3 then return result_points
        if start_index < 1 or start_index > face_points.count then return result_points
        if end_index < 1 or end_index > face_points.count then return result_points

        current_index = start_index
        append result_points face_points[current_index]
        safety_count = 0

        while current_index != end_index and safety_count <= face_points.count do
        (
            current_index += 1
            if current_index > face_points.count then current_index = 1
            append result_points face_points[current_index]
            safety_count += 1
        )

        result_points
        -- return
    ),

    /*
    Finds a non-adjacent vertex pair whose diagonal maximizes the smaller area of the two polygon halves.
    This avoids choosing a diagonal that itself creates an obviously degenerate side.
    */
    function findBestFaceDiagonal node modifier face_index =
    (
        vertex_ids = getModifierFaceVertexIds node modifier face_index
        face_points = getModifierFaceWorldPoints node modifier face_index

        if vertex_ids.count < 4 or face_points == undefined or face_points.count != vertex_ids.count then return undefined

        best_pair = undefined
        best_score = -1.0
        point_count = face_points.count

        for index_a = 1 to point_count - 1 do
        (
            for index_b = index_a + 1 to point_count do
            (
                adjacent_pair = index_b == (index_a + 1) or (index_a == 1 and index_b == point_count)

                if not adjacent_pair then
                (
                    chain_a = getWrappedFacePointChain face_points index_a index_b
                    chain_b = getWrappedFacePointChain face_points index_b index_a

                    if chain_a.count >= 3 and chain_b.count >= 3 then
                    (
                        area_a = getPolygonArea chain_a
                        area_b = getPolygonArea chain_b
                        split_score = if area_a < area_b then area_a else area_b

                        if split_score > best_score then
                        (
                            best_score = split_score
                            best_pair = #(vertex_ids[index_a], vertex_ids[index_b], split_score)
                        )
                    )
                )
            )
        )

        best_pair
        -- return
    ),

    /*
    Tries to change one polygon's internal triangulation without viewport picking.
    Retriangulate is followed by SetDiagonal using the healthiest available non-adjacent vertex pair.
    */
    function fixFaceTriangulation node modifier face_index =
    (
        if face_index < 1 or face_index > (modifier.GetNumFaces node:node) then return #(false, false)

        face_bits = #{}
        face_bits[face_index] = true
        selectModifierComponents node modifier #Face face_bits
        modifier.ButtonOp #Retriangulate
        update node
        retriangulated = true
        diagonal_set = false

        if face_index <= (modifier.GetNumFaces node:node) then
        (
            diagonal_data = findBestFaceDiagonal node modifier face_index

            if diagonal_data != undefined and diagonal_data[3] > zero_area_epsilon then
            (
                try
                (
                    modifier.SetDiagonal diagonal_data[1] diagonal_data[2] node:node
                    update node
                    diagonal_set = true
                )
                catch
                (
                    diagonal_set = false
                )
            )
        )

        #(retriangulated, diagonal_set)
        -- return
    ),

    /*
    Fixes currently selected degenerate faces conservatively.
    Whole polygons are deleted only when their complete polygon area is effectively zero.
    Non-zero-area faces first try coincident-vertex collapse, then Connect+Collapse, then Retriangulate for collinear polygon vertices.
    */
    function fixSelectedCandidates sliver_ratio:0.001 =
    (
        if selection.count == 0 then
        (
            messageBox "Select a processed object first." title:"Degenerate Face Selector"
            return false
        )

        node = selection[1]
        selection_modifier = getActiveEditPoly node

        if selection_modifier == undefined or selection_modifier.name != "DEGENERATE FACES" then
        (
            messageBox "Activate the DEGENERATE FACES Edit Poly first." title:"Degenerate Face Selector"
            return false
        )

        forceSelectModeZero selection_modifier
        selected_faces = selection_modifier.GetSelection #Face

        if selected_faces.numberSet == 0 then
        (
            messageBox "No faces are selected." title:"Degenerate Face Selector"
            return false
        )

        current_candidates = findCandidateFaces node selection_modifier sliver_ratio:sliver_ratio debug_output:false
        valid_faces = selected_faces * current_candidates

        if valid_faces.numberSet == 0 then
        (
            messageBox "Selected faces no longer satisfy the degenerate-face threshold." title:"Degenerate Face Selector"
            return false
        )

        if not(activateSelectionModifier node selection_modifier) then return false

        face_array = valid_faces as array
        sort face_array

        deleted_zero_area = 0
        collapsed_groups = 0
        connected_collapsed_groups = 0
        retriangulated_faces = 0
        diagonal_fixed_faces = 0
        unresolved_faces = 0
        operation_error = undefined

        try
        (
            undo "Fix Degenerate Faces" on
            (
                for array_index = face_array.count to 1 by -1 do
                (
                    face_index = face_array[array_index]
                    current_face_count = selection_modifier.GetNumFaces node:node

                    if face_index >= 1 and face_index <= current_face_count then
                    (
                        face_points = getModifierFaceWorldPoints node selection_modifier face_index

                        if face_points != undefined then
                        (
                            face_area = getPolygonArea face_points

                            if face_area <= zero_area_epsilon then
                            (
                                face_bits = #{}
                                face_bits[face_index] = true
                                selectModifierComponents node selection_modifier #Face face_bits
                                selection_modifier.ButtonOp #DeleteFace
                                update node
                                deleted_zero_area += 1
                                format "FIX ZERO AREA | node:% | face:% | area:% | action:DeleteFace\n" node.name face_index face_area
                            )
                            else
                            (
                                coincident_pass = 0
                                continue_coincident_fix = true

                                while continue_coincident_fix and coincident_pass < 32 do
                                (
                                    current_face_count = selection_modifier.GetNumFaces node:node

                                    if face_index < 1 or face_index > current_face_count then
                                    (
                                        continue_coincident_fix = false
                                    )
                                    else
                                    (
                                        coincident_groups = getCoincidentFaceVertexGroups node selection_modifier face_index tolerance:coincident_tolerance

                                        if coincident_groups.count == 0 then
                                        (
                                            continue_coincident_fix = false
                                        )
                                        else
                                        (
                                            vertex_group = coincident_groups[1]
                                            fix_result = fixCoincidentVertexGroup node selection_modifier vertex_group tolerance:coincident_tolerance

                                            if fix_result == undefined then
                                            (
                                                continue_coincident_fix = false
                                            )
                                            else
                                            (
                                                if fix_result[1] == #collapse then
                                                (
                                                    collapsed_groups += 1
                                                    format "FIX COINCIDENT VERTS | node:% | face:% | method:CollapseVertex | count:%->%\n" node.name face_index fix_result[2] fix_result[3]
                                                )

                                                if fix_result[1] == #connectCollapse then
                                                (
                                                    connected_collapsed_groups += 1
                                                    format "FIX COINCIDENT VERTS | node:% | face:% | method:ConnectVertices+CollapseVertex | count:%->%\n" node.name face_index fix_result[2] fix_result[3]
                                                )

                                                coincident_pass += 1
                                            )
                                        )
                                    )
                                )

                                current_face_count = selection_modifier.GetNumFaces node:node

                                if face_index >= 1 and face_index <= current_face_count then
                                (
                                    updated_points = getModifierFaceWorldPoints node selection_modifier face_index

                                    if updated_points != undefined then
                                    (
                                        updated_area = getPolygonArea updated_points

                                        if updated_area <= zero_area_epsilon then
                                        (
                                            face_bits = #{}
                                            face_bits[face_index] = true
                                            selectModifierComponents node selection_modifier #Face face_bits
                                            selection_modifier.ButtonOp #DeleteFace
                                            update node
                                            deleted_zero_area += 1
                                            format "FIX ZERO AREA AFTER VERT REPAIR | node:% | face:% | area:% | action:DeleteFace\n" node.name face_index updated_area
                                        )
                                        else if hasCollinearFaceTriple updated_points ratio_tolerance:collinear_ratio_tolerance then
                                        (
                                            triangulation_result = fixFaceTriangulation node selection_modifier face_index

                                            if triangulation_result[1] then
                                            (
                                                retriangulated_faces += 1
                                                format "FIX COLLINEAR TRIANGULATION | node:% | face:% | action:Retriangulate\n" node.name face_index
                                            )

                                            if triangulation_result[2] then
                                            (
                                                diagonal_fixed_faces += 1
                                                format "FIX COLLINEAR TRIANGULATION | node:% | face:% | action:SetDiagonal\n" node.name face_index
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                )

                remaining_faces = findCandidateFaces node selection_modifier sliver_ratio:sliver_ratio debug_output:false
                unresolved_faces = remaining_faces.numberSet
                selectModifierComponents node selection_modifier #Face remaining_faces
                selection_modifier.showCage = false
                selection_modifier.RefreshScreen()
                update node
            )
        )
        catch
        (
            operation_error = getCurrentException()
        )

        if operation_error != undefined then
        (
            format "Degenerate Face Selector FIX FAILED | node:% | %\n" node.name operation_error
            messageBox ("Fix failed:\n" + (operation_error as string)) title:"Degenerate Face Selector"
            return false
        )

        completeRedraw()
        format "Degenerate Face Selector FIX | node:% | zeroAreaDeleted:% | collapsed:% | connectCollapsed:% | retriangulated:% | diagonalsSet:% | unresolved:%\n" node.name deleted_zero_area collapsed_groups connected_collapsed_groups retriangulated_faces diagonal_fixed_faces unresolved_faces
        true
        -- return
    ),

    /*
    Creates one normal triangle and one very thin sliver triangle for manual testing.
    With the default ratio only the second face should be selected.
    */
    function createTestObject =
    (
        test_node = editable_mesh name:(uniqueName "DEGENERATE_FACE_TEST_")
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        forceSelectModeZero test_poly

        vertex_1 = polyop.createVert test_poly [0,0,0]
        vertex_2 = polyop.createVert test_poly [10,0,0]
        vertex_3 = polyop.createVert test_poly [0,10,0]

        vertex_4 = polyop.createVert test_poly [20,0,0]
        vertex_5 = polyop.createVert test_poly [30,0,0]
        vertex_6 = polyop.createVert test_poly [30,0.001,0]

        polyop.createPolygon test_poly #(vertex_1, vertex_2, vertex_3)
        polyop.createPolygon test_poly #(vertex_4, vertex_5, vertex_6)

        update test_node
        select test_node
        completeRedraw()
        test_node
        -- return
    ),

    /*
    Creates three repair cases: a zero-area triangle, a sliver with coincident vertices, and a thin n-gon with three collinear vertices.
    The fixer can exercise Delete Face, Collapse/Connect Vertices, and Retriangulate on one object.
    */
    function createFixTestObject =
    (
        test_node = editable_mesh name:(uniqueName "DEGENERATE_FIX_TEST_")
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        forceSelectModeZero test_poly

        zero_1 = polyop.createVert test_poly [0,0,0]
        zero_2 = polyop.createVert test_poly [5,0,0]
        zero_3 = polyop.createVert test_poly [10,0,0]
        polyop.createPolygon test_poly #(zero_1, zero_2, zero_3)

        duplicate_1 = polyop.createVert test_poly [20,0,0]
        duplicate_2 = polyop.createVert test_poly [30,0,0]
        duplicate_3 = polyop.createVert test_poly [30,0,0]
        duplicate_4 = polyop.createVert test_poly [20,0.001,0]
        polyop.createPolygon test_poly #(duplicate_1, duplicate_2, duplicate_3, duplicate_4)

        collinear_1 = polyop.createVert test_poly [40,0,0]
        collinear_2 = polyop.createVert test_poly [45,0,0]
        collinear_3 = polyop.createVert test_poly [50,0,0]
        collinear_4 = polyop.createVert test_poly [50,0.001,0]
        collinear_5 = polyop.createVert test_poly [40,0.001,0]
        polyop.createPolygon test_poly #(collinear_1, collinear_2, collinear_3, collinear_4, collinear_5)

        update test_node
        select test_node
        completeRedraw()
        test_node
        -- return
    ),

    /*
    Runs the repair pipeline on synthetic zero-area, coincident-vertex, and collinear-triangulation cases.
    It verifies that the operation completes and reduces both face and vertex counts.
    */
    function testFixOperations sliver_ratio:0.001 =
    (
        test_node = undefined
        test_passed = false

        try
        (
            test_node = createFixTestObject()
            start_faces = polyop.getNumFaces test_node.baseObject
            start_vertices = polyop.getNumVerts test_node.baseObject

            selectCandidates sliver_ratio:sliver_ratio debug_output:true
            fix_ok = fixSelectedCandidates sliver_ratio:sliver_ratio

            modifier = getActiveEditPoly test_node
            end_faces = if modifier != undefined then modifier.GetNumFaces node:test_node else start_faces
            end_vertices = if modifier != undefined then modifier.GetNumVertices node:test_node else start_vertices

            test_passed = fix_ok and end_faces < start_faces and end_vertices < start_vertices
            format "TEST degenerate face FIX: % | faces:%->% | verts:%->%\n" test_passed start_faces end_faces start_vertices end_vertices
        )
        catch
        (
            format "TEST FIX ERROR: %\n" (getCurrentException())
            test_passed = false
        )

        if test_node != undefined then try(delete test_node)catch()

        test_passed
        -- return
    ),

    /*
    Runs the standalone face-quality regression test.
    A normal triangle must remain unselected while the long near-zero-area sliver is selected.
    */
    function runTests sliver_ratio:0.001 =
    (
        test_node = undefined
        test_passed = true

        try
        (
            test_node = createTestObject()
            test_modifier = getSelectionModifier test_node
            result_faces = findCandidateFaces test_node test_modifier sliver_ratio:sliver_ratio debug_output:true
            expected_faces = #{2}
            detection_ok = result_faces == expected_faces

            format "TEST degenerate/sliver face detection: % | result:% | expected:%\n" detection_ok result_faces expected_faces
            if not detection_ok then test_passed = false

            select test_node
            selectCandidates sliver_ratio:sliver_ratio debug_output:false

            stored_faces = #{}
            storage_ok = false

            if test_node.modifiers.count > 0 then
            (
                test_modifier = test_node.modifiers[1]

                if classOf test_modifier == Edit_Poly and test_modifier.name == "DEGENERATE FACES" then
                (
                    stored_faces = test_modifier.GetSelection #Face
                    storage_ok = stored_faces[2] and stored_faces.numberSet == 1
                )
            )

            format "TEST stored face selection: % | stored:%\n" storage_ok stored_faces
            if not storage_ok then test_passed = false
        )
        catch
        (
            format "TEST ERROR: %\n" (getCurrentException())
            test_passed = false
        )

        if test_node != undefined then try(delete test_node)catch()

        fix_test_passed = testFixOperations sliver_ratio:sliver_ratio
        if not fix_test_passed then test_passed = false

        format "DEGENERATE FACE SELECTOR TESTS PASSED: %\n" test_passed
        test_passed
        -- return
    ),

    on create do
    (
    )
)

DegenerateFaceSelector = DegenerateFaceSelector_v()

try(destroyDialog DegenerateFaceSelector_UI)catch()

rollout DegenerateFaceSelector_UI "Degenerate Face Selector 0.06" width:300 height:140
(
    spinner spn_ratio "Sliver Ratio:" pos:[12,10] width:190 height:18 range:[0.000001,0.1,0.001] type:#float scale:0.0001 fieldwidth:76 tooltip:"Select live Edit Poly faces whose area divided by longest boundary edge squared is at or below this value."
    label lbl_ratio "area / longest²" pos:[206,12] width:82 height:18 align:#left
    button btn_main "SELECT \\ FIX" pos:[12,36] width:276 height:30 tooltip:"LMB: Select near-zero-area and long thin sliver faces.\n\nRMB: Fix selected faces. Zero-area polygons may be deleted; otherwise coincident vertices are collapsed and collinear triangulation is retriangulated."
    button btn_test "CREATE TEST" pos:[12,72] width:134 height:28 tooltip:"Create one normal triangle and one long near-zero-area sliver triangle."
    button btn_tests "RUN TESTS" pos:[154,72] width:134 height:28 tooltip:"Run the standalone degenerate-face regression test."
    label lbl_info "Scale-independent sliver detection" pos:[12,108] width:276 height:18 align:#center

    on btn_main pressed do
    (
        DegenerateFaceSelector.selectCandidates sliver_ratio:spn_ratio.value debug_output:true
    )

    on btn_main rightclick do
    (
        DegenerateFaceSelector.fixSelectedCandidates sliver_ratio:spn_ratio.value
    )

    on btn_test pressed do
    (
        DegenerateFaceSelector.createTestObject()
    )

    on btn_tests pressed do
    (
        DegenerateFaceSelector.runTests sliver_ratio:spn_ratio.value
    )
)

createDialog DegenerateFaceSelector_UI
