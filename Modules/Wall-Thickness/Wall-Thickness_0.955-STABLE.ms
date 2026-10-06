/*
Wall Thickness Tool 0.955
Keeps the stable strict face-normal wall shell unchanged; CLEANUP quadrifies only the current Edit Poly and smoothing reset edits existing geometry without adding a modifier.
*/


global wallThicknessRollout
global wall_thickness_ini = (getDir #plugcfg + "\\Wall-Thickness.ini")
global wall_thickness_target = undefined
global wall_thickness_default = 1.0
global wall_thickness_user_prop = "WallThickness"
global wall_thickness_source_face_count_prop = "WallThicknessSourceFaceCount"
global wall_thickness_source_vert_count_prop = "WallThicknessSourceVertCount"
global wall_thickness_cleanup_complete_prop = "WallThicknessCleanupComplete"
global wall_thickness_xformed_prop_prefix = "WallThickness_"
global wall_thickness_selection_callback_id = #WallThicknessSelectionChanged
global wall_thickness_modifier_name = "WALL THICKNESS"
global wall_thickness_finished_modifier_name = "WALL THICKNESS FINISHED"
global wall_thickness_cleanup_modifier_name = "WALL THICKNESS CLEANUP"
global wall_thickness_auto_quadrify_modifier_name = "WALL THICKNESS QUADRIFY"
global wall_thickness_inner_fix_modifier_name = "WALL THICKNESS FIX INNER CORNERS"
global wall_thickness_t_edge_fix_modifier_name = "WALL THICKNESS FIX T EDGE CORNERS"
global wall_thickness_inner_weld_modifier_name = "WALL THICKNESS FIX INNER CORNERS WELD"
global wall_thickness_chamfer_fix_modifier_name = "WALL THICKNESS FIX OUTER CORNERS"
global wall_thickness_chamfer_weld_modifier_name = "WALL THICKNESS FIX OUTER CORNERS WELD"
global wall_thickness_legacy_chamfer_fix_modifier_name = "WALL THICKNESS FIX CHAMFERS"
global wall_thickness_legacy_chamfer_weld_modifier_name = "WALL THICKNESS FIX CHAMFERS WELD"
global wall_thickness_stl_check_modifier_name = "STL CHECK"
global wall_thickness_remove_generated_modifier_name = "SELECT 02 GENERATED FACES"
global wall_thickness_deleted_generated_modifier_name = "DELETED 02 GENERATED FACES"
global wall_thickness_legacy_remove_generated_modifier_name = "SELECT GENERATED FACES"
global wall_thickness_legacy_deleted_generated_modifier_name = "DELETED GENERATED FACES"
global wall_thickness_legacy_source_weld_modifier_name = "PREP 02 - WELD SOURCE"
global wall_thickness_source_weld_modifier_name = "PREP 03 - WELD SOURCE"
global wall_thickness_degenerate_modifier_name = "SELECT 04 DEGENERATE FACES"
global wall_thickness_deleted_degenerate_modifier_name = "DELETED 04 DEGENERATE FACES"
global wall_thickness_legacy_degenerate_modifier_name = "SELECT DEGENERATE FACES"
global wall_thickness_legacy_deleted_degenerate_modifier_name = "DELETED DEGENERATE FACES"
global wall_thickness_legacy_multiple_edges_modifier_name = "PREP 04 - CHECK MULTIPLE EDGES"
global wall_thickness_multiple_edges_modifier_name = "PREP 05 - CHECK MULTIPLE EDGES"
global wall_thickness_legacy_border_check_modifier_name = "PREP 05 - CHECK DEGENERATE BORDERS"
global wall_thickness_border_check_modifier_name = "PREP 06 - CHECK DEGENERATE BORDERS"
global wall_thickness_cleanup_quadrify_modifier_name = "CLEANUP 01 - QUADRIFY"
global wall_thickness_cleanup_cap_modifier_name = "CLEANUP 02 - CAP HOLES"
global wall_thickness_cleanup_weld_modifier_name = "CLEANUP 03 - WELD"
global wall_thickness_cleanup_multiple_modifier_name = "CLEANUP 04 - MULTIPLE EDGES"
global wall_thickness_file_version = 0.955
global wall_thickness_stored_project_version = wall_thickness_file_version
global wall_thickness_project_version = wall_thickness_file_version
global wall_thickness_source_file_path = getSourceFileName()
global wall_thickness_ui_log_lines = #()
global wall_thickness_dump_logger = undefined
global wall_thickness_inner_dump_file = undefined


global wall_thickness_ratio_default = 150


/*
Starts a fresh DEV dump for one FIX INNER CORNERS run.
The reusable DUMP module is loaded from the sibling shared Modules\DUMP folder and writes inside this project repository.
*/
function startWallThicknessInnerCornerDump =
(
        wall_thickness_dump_logger = undefined
        wall_thickness_inner_dump_file = undefined
        dump_started = false
        source_path = wall_thickness_source_file_path


        if source_path == undefined or source_path == "" then
        (
                source_path = getSourceFileName()
        )


        if source_path != undefined and source_path != "" then
        (
                project_root = getFilenamePath source_path
                dump_module_path = project_root + @"..\DUMP\DUMP.ms"
                wall_thickness_inner_dump_file = project_root + @"logs\Wall-Thickness-FIX-INNER-CORNERS-DUMP.txt"


                if not (globalVars.isGlobal #DumpDevLoggerStruct) then
                (
                        if doesFileExist dump_module_path then
                        (
                                try
                                (
                                        fileIn dump_module_path
                                )
                                catch
                                (
                                        exception_text = getCurrentException()
                                        format "FIX INNER CORNERS DUMP ERROR: could not load DUMP.ms | %\n" exception_text
                                )
                        )
                        else
                        (
                                format "FIX INNER CORNERS DUMP ERROR: missing DUMP module: %\n" dump_module_path
                        )
                )


                if (globalVars.isGlobal #DumpDevLoggerStruct) then
                (
                        try
                        (
                                wall_thickness_dump_logger = DumpDevLoggerStruct()
                                dump_started = wall_thickness_dump_logger.start wall_thickness_inner_dump_file
                        )
                        catch
                        (
                                exception_text = getCurrentException()
                                format "FIX INNER CORNERS DUMP ERROR: could not start dump | %\n" exception_text
                                wall_thickness_dump_logger = undefined
                                dump_started = false
                        )
                )
        )


        dump_started
        -- return
)


/*
Mirrors one FIX INNER CORNERS diagnostic value to the Listener and active repository-local dump.
Logging failure is reported but never changes the geometry operation result.
*/
function logWallThicknessInnerCornerDump dump_value =
(
        log_succeeded = false


        if wall_thickness_dump_logger != undefined and wall_thickness_dump_logger.started then
        (
                try
                (
                        log_succeeded = wall_thickness_dump_logger.log dump_value
                )
                catch
                (
                        exception_text = getCurrentException()
                        format "FIX INNER CORNERS DUMP ERROR: %\n" exception_text
                        log_succeeded = false
                )
        )
        else
        (
                format "%\n" dump_value
        )


        log_succeeded
        -- return
)




global WallThicknessPreprocess


/*
Shared preprocessing logic adapted from the stable EPolyTools geometry routines.
All analysis and repair is performed through explicit Edit Poly stages so the user's base object is never collapsed.
*/
struct WallThicknessPreprocess_v
(
        file_version = 0.01,
        default_sliver_ratio = 0.001,
        area_epsilon = 0.00000001,
        zero_area_epsilon = 0.000000000001,
        length_epsilon = 0.00000001,
        coincident_tolerance = 0.0001,
        collinear_ratio_tolerance = 0.000001,
        border_tolerance = 0.0001,
        straight_pair_dot_limit = -0.999847695,


        /*
        Forces Edit Poly into normal component-selection mode with Show Cage disabled.
        */
        function forceSelectModeZero edit_modifier =
        (
                if edit_modifier == undefined then return false
                try (edit_modifier.selectMode = 0) catch ()
                try (edit_modifier.showCage = off) catch ()
                true
                -- return
        ),


        /*
        Binds and evaluates one Edit Poly modifier before topology is queried.
        This follows the live-topology preparation pattern used by EPolyTools.
        */
        function prepareEditPoly source_node edit_modifier selection_level:#Object =
        (
                if not isValidNode source_node then return false
                if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return false


                prepared = false
                try
                (
                        select source_node
                        max modify mode
                        edit_modifier.SetPrimaryNode source_node
                        edit_modifier.useStackSelection = false
                        forceSelectModeZero edit_modifier
                        modPanel.setCurrentObject edit_modifier node:source_node


                        case selection_level of
                        (
                                #Vertex: edit_modifier.SetEPolySelLevel #Vertex
                                #Edge: edit_modifier.SetEPolySelLevel #Edge
                                #Face: edit_modifier.SetEPolySelLevel #Face
                                default: subObjectLevel = 0
                        )


                        update source_node
                        test_mesh = snapshotAsMesh source_node
                        if test_mesh != undefined then free test_mesh
                        update source_node
                        prepared = true
                )
                catch
                (
                        prepared = false
                )


                prepared
                -- return
        ),


        /*
        Returns ordered world-space points for one live Edit Poly face.
        */
        function getModifierFaceWorldPoints source_node edit_modifier face_id =
        (
                if not isValidNode source_node then return undefined
                if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return undefined


                face_count = edit_modifier.GetNumFaces node:source_node
                if face_id < 1 or face_id > face_count then return undefined


                face_degree = edit_modifier.GetFaceDegree face_id node:source_node
                if face_degree < 3 then return undefined


                face_points = #()
                object_tm = source_node.objectTransform


                for corner_id = 1 to face_degree do
                (
                        vertex_id = edit_modifier.GetFaceVertex face_id corner_id node:source_node
                        if vertex_id < 1 then return undefined


                        vertex_point = edit_modifier.GetVertex vertex_id node:source_node
                        if vertex_point == undefined then return undefined
                        append face_points (vertex_point * object_tm)
                )


                face_points
                -- return
        ),


        /*
        Computes polygon area using the vector-area form of Newell's method.
        */
        function getPolygonArea face_points =
        (
                if face_points == undefined or face_points.count < 3 then return 0.0


                area_vector = [0,0,0]
                point_count = face_points.count
                origin_point = face_points[1]


                for point_id = 1 to point_count do
                (
                        next_id = if point_id == point_count then 1 else point_id + 1
                        point_a = face_points[point_id] - origin_point
                        point_b = face_points[next_id] - origin_point
                        area_vector += cross point_a point_b
                )


                0.5 * (length area_vector)
                -- return
        ),


        /*
        Returns the longest visible polygon-boundary segment in one face.
        */
        function getLongestBoundaryEdge face_points =
        (
                if face_points == undefined or face_points.count < 2 then return 0.0


                longest_edge = 0.0
                point_count = face_points.count
                for point_id = 1 to point_count do
                (
                        next_id = if point_id == point_count then 1 else point_id + 1
                        edge_length = distance face_points[point_id] face_points[next_id]
                        if edge_length > longest_edge then longest_edge = edge_length
                )


                longest_edge
                -- return
        ),


        /*
        Returns area, longest edge, and the scale-independent sliver ratio for one face.
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
        Finds all degenerate and long-thin sliver faces directly on the repair modifier topology.
        */
        function findCandidateFaces source_node edit_modifier sliver_ratio:0.001 =
        (
                result_faces = #{}
                if not isValidNode source_node then return result_faces
                if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return result_faces


                forceSelectModeZero edit_modifier
                edit_modifier.SetPrimaryNode source_node
                face_count = edit_modifier.GetNumFaces node:source_node


                for face_id = 1 to face_count do
                (
                        face_points = getModifierFaceWorldPoints source_node edit_modifier face_id
                        if face_points == undefined then
                        (
                                result_faces[face_id] = true
                        )
                        else
                        (
                                quality_data = getFaceQuality face_points
                                if (quality_data[1] <= area_epsilon) or (quality_data[2] <= length_epsilon) or (quality_data[3] <= sliver_ratio) then
                                (
                                        result_faces[face_id] = true
                                )
                        )
                )


                result_faces
                -- return
        ),


        /*
        Returns ordered live Edit Poly vertex IDs for one polygon face.
        */
        function getModifierFaceVertexIds source_node edit_modifier face_id =
        (
                vertex_ids = #()
                if not isValidNode source_node then return vertex_ids
                if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return vertex_ids


                face_count = edit_modifier.GetNumFaces node:source_node
                if face_id < 1 or face_id > face_count then return vertex_ids


                face_degree = edit_modifier.GetFaceDegree face_id node:source_node
                if face_degree < 3 then return vertex_ids


                for corner_id = 1 to face_degree do
                (
                        vertex_id = edit_modifier.GetFaceVertex face_id corner_id node:source_node
                        if vertex_id < 1 then return #()
                        append vertex_ids vertex_id
                )


                vertex_ids
                -- return
        ),


        /*
        Returns one live Edit Poly vertex position in world space.
        */
        function getModifierVertexWorldPoint source_node edit_modifier vertex_id =
        (
                if not isValidNode source_node then return undefined
                if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return undefined
                if vertex_id < 1 or vertex_id > (edit_modifier.GetNumVertices node:source_node) then return undefined


                vertex_point = edit_modifier.GetVertex vertex_id node:source_node
                if vertex_point == undefined then return undefined
                vertex_point * source_node.objectTransform
                -- return
        ),


        /*
        Replaces one Edit Poly component selection on the active repair stage.
        */
        function selectModifierComponents source_node edit_modifier component_level component_bits =
        (
                if not isValidNode source_node then return false
                if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return false


                forceSelectModeZero edit_modifier
                edit_modifier.SetPrimaryNode source_node


                sub_object_level = 0
                case component_level of
                (
                        #Vertex: sub_object_level = 1
                        #Edge: sub_object_level = 2
                        #Face: sub_object_level = 4
                        default: return false
                )


                edit_modifier.SetEPolySelLevel component_level
                subObjectLevel = sub_object_level
                old_selection = edit_modifier.GetSelection component_level node:source_node
                if old_selection.numberSet > 0 then edit_modifier.Select component_level old_selection select:false
                if component_bits != undefined and component_bits.numberSet > 0 then edit_modifier.Select component_level component_bits
                true
                -- return
        ),


        /*
        Finds coincident vertex groups inside one live polygon.
        */
        function getCoincidentFaceVertexGroups source_node edit_modifier face_id tolerance:0.0001 =
        (
                vertex_ids = getModifierFaceVertexIds source_node edit_modifier face_id
                groups = #()
                used_vertices = #{}


                for vertex_id in vertex_ids do
                (
                        if not used_vertices[vertex_id] then
                        (
                                base_point = getModifierVertexWorldPoint source_node edit_modifier vertex_id
                                group_bits = #{}


                                if base_point != undefined then
                                (
                                        for compare_id in vertex_ids do
                                        (
                                                if not used_vertices[compare_id] then
                                                (
                                                        compare_point = getModifierVertexWorldPoint source_node edit_modifier compare_id
                                                        if compare_point != undefined and distance base_point compare_point <= tolerance then
                                                        (
                                                                group_bits[compare_id] = true
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
                                        used_vertices[vertex_id] = true
                                )
                        )
                )


                groups
                -- return
        ),


        /*
        Counts current live vertices close to one world-space point.
        */
        function countModifierVerticesNearPoint source_node edit_modifier target_point tolerance:0.0001 =
        (
                if target_point == undefined then return 0


                vertex_count = edit_modifier.GetNumVertices node:source_node
                match_count = 0
                for vertex_id = 1 to vertex_count do
                (
                        vertex_point = getModifierVertexWorldPoint source_node edit_modifier vertex_id
                        if vertex_point != undefined and distance vertex_point target_point <= tolerance then match_count += 1
                )


                match_count
                -- return
        ),


        /*
        Returns true when any three face vertices are effectively collinear.
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
        Collapses one coincident vertex group, using Connect Vertices as the EPolyTools fallback.
        */
        function fixCoincidentVertexGroup source_node edit_modifier vertex_bits tolerance:0.0001 =
        (
                if vertex_bits == undefined or vertex_bits.numberSet < 2 then return undefined


                first_vertex = undefined
                for vertex_id in vertex_bits while first_vertex == undefined do first_vertex = vertex_id
                target_point = getModifierVertexWorldPoint source_node edit_modifier first_vertex
                if target_point == undefined then return undefined


                before_count = countModifierVerticesNearPoint source_node edit_modifier target_point tolerance:tolerance
                selectModifierComponents source_node edit_modifier #Vertex vertex_bits
                edit_modifier.ButtonOp #CollapseVertex
                update source_node


                after_direct_count = countModifierVerticesNearPoint source_node edit_modifier target_point tolerance:tolerance
                if after_direct_count < before_count then return #(#collapse, before_count, after_direct_count)


                valid_bits = #{}
                current_vertex_count = edit_modifier.GetNumVertices node:source_node
                for vertex_id in vertex_bits do
                (
                        if vertex_id <= current_vertex_count then valid_bits[vertex_id] = true
                )
                if valid_bits.numberSet < 2 then return undefined


                selectModifierComponents source_node edit_modifier #Vertex valid_bits
                edit_modifier.ButtonOp #ConnectVertices
                update source_node


                current_vertex_count = edit_modifier.GetNumVertices node:source_node
                retry_bits = #{}
                for vertex_id in valid_bits do
                (
                        if vertex_id <= current_vertex_count then retry_bits[vertex_id] = true
                )
                if retry_bits.numberSet < 2 then return undefined


                selectModifierComponents source_node edit_modifier #Vertex retry_bits
                edit_modifier.ButtonOp #CollapseVertex
                update source_node


                after_connect_count = countModifierVerticesNearPoint source_node edit_modifier target_point tolerance:tolerance
                if after_connect_count < before_count then #(#connectCollapse, before_count, after_connect_count) else undefined
                -- return
        ),


        /*
        Returns one wrapped polygon point chain between two face corners.
        */
        function getWrappedFacePointChain face_points start_id end_id =
        (
                result_points = #()
                if face_points == undefined or face_points.count < 3 then return result_points
                if start_id < 1 or start_id > face_points.count then return result_points
                if end_id < 1 or end_id > face_points.count then return result_points


                current_id = start_id
                append result_points face_points[current_id]
                safety_count = 0


                while current_id != end_id and safety_count <= face_points.count do
                (
                        current_id += 1
                        if current_id > face_points.count then current_id = 1
                        append result_points face_points[current_id]
                        safety_count += 1
                )


                result_points
                -- return
        ),


        /*
        Chooses a healthy non-adjacent polygon diagonal for collinear triangulation repair.
        */
        function findBestFaceDiagonal source_node edit_modifier face_id =
        (
                vertex_ids = getModifierFaceVertexIds source_node edit_modifier face_id
                face_points = getModifierFaceWorldPoints source_node edit_modifier face_id
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
        Retriangulates one polygon and applies the healthiest available diagonal.
        */
        function fixFaceTriangulation source_node edit_modifier face_id =
        (
                if face_id < 1 or face_id > (edit_modifier.GetNumFaces node:source_node) then return #(false, false)


                face_bits = #{face_id}
                selectModifierComponents source_node edit_modifier #Face face_bits
                edit_modifier.ButtonOp #Retriangulate
                update source_node
                retriangulated = true
                diagonal_set = false


                if face_id <= (edit_modifier.GetNumFaces node:source_node) then
                (
                        diagonal_data = findBestFaceDiagonal source_node edit_modifier face_id
                        if diagonal_data != undefined and diagonal_data[3] > zero_area_epsilon then
                        (
                                try
                                (
                                        edit_modifier.SetDiagonal diagonal_data[1] diagonal_data[2] node:source_node
                                        update source_node
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
        Repairs the current degenerate faces on one dedicated Edit Poly stage.
        The operation is the production EPolyTools repair sequence without changing the user's base object.
        */
        function fixDegenerateFaces source_node edit_modifier sliver_ratio:0.001 candidate_faces:undefined =
        (
                if not(prepareEditPoly source_node edit_modifier selection_level:#Face) then return #(false, 0, 0)


                if candidate_faces == undefined then
                (
                        candidate_faces = findCandidateFaces source_node edit_modifier sliver_ratio:sliver_ratio
                )
                else
                (
                        candidate_faces = copy candidate_faces
                        current_face_count = edit_modifier.GetNumFaces node:source_node
                        valid_faces = if current_face_count > 0 then #{1..current_face_count} else #{}
                        candidate_faces = candidate_faces * valid_faces
                )


                if candidate_faces.numberSet == 0 then
                (
                        selectModifierComponents source_node edit_modifier #Face #{}
                        return #(true, 0, 0)
                )


                face_array = candidate_faces as array
                sort face_array
                fixed_count = 0


                for array_id = face_array.count to 1 by -1 do
                (
                        face_id = face_array[array_id]
                        current_face_count = edit_modifier.GetNumFaces node:source_node


                        if face_id >= 1 and face_id <= current_face_count then
                        (
                                face_points = getModifierFaceWorldPoints source_node edit_modifier face_id
                                if face_points != undefined then
                                (
                                        face_area = getPolygonArea face_points
                                        if face_area <= zero_area_epsilon then
                                        (
                                                selectModifierComponents source_node edit_modifier #Face #{face_id}
                                                edit_modifier.ButtonOp #DeleteFace
                                                update source_node
                                                fixed_count += 1
                                        )
                                        else
                                        (
                                                coincident_pass = 0
                                                continue_fix = true


                                                while continue_fix and coincident_pass < 32 do
                                                (
                                                        current_face_count = edit_modifier.GetNumFaces node:source_node
                                                        if face_id < 1 or face_id > current_face_count then
                                                        (
                                                                continue_fix = false
                                                        )
                                                        else
                                                        (
                                                                coincident_groups = getCoincidentFaceVertexGroups source_node edit_modifier face_id tolerance:coincident_tolerance
                                                                if coincident_groups.count == 0 then
                                                                (
                                                                        continue_fix = false
                                                                )
                                                                else
                                                                (
                                                                        fix_result = fixCoincidentVertexGroup source_node edit_modifier coincident_groups[1] tolerance:coincident_tolerance
                                                                        if fix_result == undefined then
                                                                        (
                                                                                continue_fix = false
                                                                        )
                                                                        else
                                                                        (
                                                                                fixed_count += 1
                                                                                coincident_pass += 1
                                                                        )
                                                                )
                                                        )
                                                )


                                                current_face_count = edit_modifier.GetNumFaces node:source_node
                                                if face_id >= 1 and face_id <= current_face_count then
                                                (
                                                        updated_points = getModifierFaceWorldPoints source_node edit_modifier face_id
                                                        if updated_points != undefined then
                                                        (
                                                                updated_area = getPolygonArea updated_points
                                                                if updated_area <= zero_area_epsilon then
                                                                (
                                                                        selectModifierComponents source_node edit_modifier #Face #{face_id}
                                                                        edit_modifier.ButtonOp #DeleteFace
                                                                        update source_node
                                                                        fixed_count += 1
                                                                )
                                                                else if hasCollinearFaceTriple updated_points ratio_tolerance:collinear_ratio_tolerance then
                                                                (
                                                                        triangulation_result = fixFaceTriangulation source_node edit_modifier face_id
                                                                        if triangulation_result[1] then fixed_count += 1
                                                                )
                                                        )
                                                )
                                        )
                                )
                        )
                )


                remaining_faces = findCandidateFaces source_node edit_modifier sliver_ratio:sliver_ratio
                selectModifierComponents source_node edit_modifier #Face remaining_faces
                edit_modifier.showCage = off
                edit_modifier.RefreshScreen()
                update source_node
                #(remaining_faces.numberSet == 0, fixed_count, remaining_faces.numberSet)
                -- return
        ),


        /*
        Returns the two live vertex IDs of one Edit Poly edge.
        */
        function getEdgeVertIds source_node edit_modifier edge_id =
        (
                #(
                        EditPolyMod.GetEdgeVertex edit_modifier edge_id 1 node:source_node,
                        EditPolyMod.GetEdgeVertex edit_modifier edge_id 2 node:source_node
                )
                -- return
        ),


        /*
        Returns true only for a visible evaluated poly edge.
        */
        function isEdgeVisible source_node edge_id =
        (
                result_value = false
                try (result_value = polyop.getEdgeVis source_node edge_id) catch (result_value = false)
                result_value
                -- return
        ),


        /*
        Returns one live Edit Poly vertex position in object-local coordinates.
        */
        function getVertexPosition source_node edit_modifier vertex_id =
        (
                EditPolyMod.GetVertex edit_modifier vertex_id node:source_node
                -- return
        ),


        /*
        Returns true when one visible evaluated edge is an open border edge.
        */
        function isBorderEdge source_node edit_modifier edge_id =
        (
                result_value = false
                if isEdgeVisible source_node edge_id then
                (
                        try
                        (
                                edge_faces = polyop.getFacesUsingEdge source_node edge_id
                                result_value = edge_faces.numberSet == 1
                        )
                        catch
                        (
                                result_value = false
                        )
                )
                result_value
                -- return
        ),


        /*
        Collects all visible open border edges from the exact check modifier topology.
        */
        function getVisibleBorderEdges source_node edit_modifier =
        (
                border_edges = #{}
                edge_count = EditPolyMod.GetNumEdges edit_modifier node:source_node
                for edge_id = 1 to edge_count do
                (
                        if isBorderEdge source_node edit_modifier edge_id then border_edges[edge_id] = true
                )
                border_edges
                -- return
        ),


        /*
        Returns all border edges incident to one vertex.
        */
        function getBorderEdgesAtVertex source_node edit_modifier border_edges vertex_id =
        (
                result_edges = #()
                for edge_id in border_edges do
                (
                        edge_verts = getEdgeVertIds source_node edit_modifier edge_id
                        if edge_verts.count == 2 and ((edge_verts[1] == vertex_id) or (edge_verts[2] == vertex_id)) then append result_edges edge_id
                )
                result_edges
                -- return
        ),


        /*
        Returns the opposite endpoint of one edge.
        */
        function getOtherEdgeVertex source_node edit_modifier edge_id vertex_id =
        (
                other_vertex = 0
                edge_verts = getEdgeVertIds source_node edit_modifier edge_id
                if edge_verts.count == 2 then
                (
                        if edge_verts[1] == vertex_id then other_vertex = edge_verts[2]
                        else if edge_verts[2] == vertex_id then other_vertex = edge_verts[1]
                )
                other_vertex
                -- return
        ),


        /*
        Walks one unambiguous visible border chain from a seed edge.
        */
        function traceBorderLoop source_node edit_modifier border_edges seed_edge =
        (
                ordered_vertices = #()
                ordered_edges = #()
                closed_loop = false
                seed_verts = getEdgeVertIds source_node edit_modifier seed_edge


                if seed_verts.count == 2 then
                (
                        start_vertex = seed_verts[1]
                        current_vertex = seed_verts[2]
                        current_edge = seed_edge
                        append ordered_vertices start_vertex
                        append ordered_vertices current_vertex
                        append ordered_edges current_edge


                        continue_walk = true
                        safety_count = 0
                        max_steps = border_edges.numberSet + 2


                        while continue_walk and safety_count < max_steps do
                        (
                                safety_count += 1
                                incident_edges = getBorderEdgesAtVertex source_node edit_modifier border_edges current_vertex
                                next_edge = 0
                                if incident_edges.count == 2 then
                                (
                                        for candidate_edge in incident_edges while next_edge == 0 do
                                        (
                                                if candidate_edge != current_edge then next_edge = candidate_edge
                                        )
                                )


                                if next_edge == 0 then
                                (
                                        continue_walk = false
                                )
                                else
                                (
                                        next_vertex = getOtherEdgeVertex source_node edit_modifier next_edge current_vertex
                                        if next_vertex == 0 then continue_walk = false
                                        else if next_vertex == start_vertex then
                                        (
                                                append ordered_edges next_edge
                                                closed_loop = true
                                                continue_walk = false
                                        )
                                        else if findItem ordered_vertices next_vertex > 0 then
                                        (
                                                continue_walk = false
                                        )
                                        else
                                        (
                                                append ordered_edges next_edge
                                                append ordered_vertices next_vertex
                                                current_edge = next_edge
                                                current_vertex = next_vertex
                                        )
                                )
                        )
                )


                #(ordered_vertices, ordered_edges, closed_loop)
                -- return
        ),


        /*
        Calculates a Newell normal from one ordered local-space border loop.
        */
        function getBorderLoopNormal source_node edit_modifier ordered_vertices =
        (
                normal_value = [0,0,0]
                vertex_count = ordered_vertices.count
                if vertex_count >= 3 then
                (
                        for vertex_id = 1 to vertex_count do
                        (
                                next_id = if vertex_id == vertex_count then 1 else vertex_id + 1
                                point_a = getVertexPosition source_node edit_modifier ordered_vertices[vertex_id]
                                point_b = getVertexPosition source_node edit_modifier ordered_vertices[next_id]
                                normal_value.x += (point_a.y - point_b.y) * (point_a.z + point_b.z)
                                normal_value.y += (point_a.z - point_b.z) * (point_a.x + point_b.x)
                                normal_value.z += (point_a.x - point_b.x) * (point_a.y + point_b.y)
                        )
                )


                if length normal_value > 0.0000001 then normal_value = normalize normal_value
                normal_value
                -- return
        ),


        /*
        Finds reflex border corners and 360-degree backtracking peaks.
        This is the EPolyTools Straight-Edge-Fixer border-corner rule.
        */
        function findBacktrackBorderEdges source_node edit_modifier border_edges =
        (
                invalid_edges = #{}
                border_vertices = #{}


                for edge_id in border_edges do
                (
                        edge_verts = getEdgeVertIds source_node edit_modifier edge_id
                        if edge_verts.count == 2 then
                        (
                                border_vertices[edge_verts[1]] = true
                                border_vertices[edge_verts[2]] = true
                        )
                )


                for vertex_id in border_vertices do
                (
                        incident_edges = getBorderEdgesAtVertex source_node edit_modifier border_edges vertex_id
                        if incident_edges.count == 2 then
                        (
                                other_a = getOtherEdgeVertex source_node edit_modifier incident_edges[1] vertex_id
                                other_b = getOtherEdgeVertex source_node edit_modifier incident_edges[2] vertex_id


                                if other_a > 0 and other_b > 0 then
                                (
                                        vertex_position = getVertexPosition source_node edit_modifier vertex_id
                                        position_a = getVertexPosition source_node edit_modifier other_a
                                        position_b = getVertexPosition source_node edit_modifier other_b
                                        vector_a = position_a - vertex_position
                                        vector_b = position_b - vertex_position


                                        if length vector_a > 0.0000001 and length vector_b > 0.0000001 then
                                        (
                                                direction_a = normalize vector_a
                                                direction_b = normalize vector_b


                                                if dot direction_a direction_b >= 0.9999 then
                                                (
                                                        invalid_edges[incident_edges[1]] = true
                                                        invalid_edges[incident_edges[2]] = true
                                                )
                                        )
                                )
                        )
                )


                invalid_edges
                -- return
        ),


        /*
        Returns point-to-segment distance and normalized segment parameter.
        */
        function getPointSegmentData point_value segment_a segment_b =
        (
                segment_vector = segment_b - segment_a
                segment_length_squared = dot segment_vector segment_vector
                if segment_length_squared <= 0.000000000001 then return #(distance point_value segment_a, 0.0)


                segment_parameter = dot (point_value - segment_a) segment_vector / segment_length_squared
                clamped_parameter = amax 0.0 (amin 1.0 segment_parameter)
                closest_point = segment_a + (segment_vector * clamped_parameter)
                #(distance point_value closest_point, segment_parameter)
                -- return
        ),


        /*
        Finds zero-length or practically zero-length border segments.
        */
        function findZeroLengthBorderEdges source_node edit_modifier border_edges tolerance:0.0001 =
        (
                invalid_edges = #{}
                for edge_id in border_edges do
                (
                        edge_verts = getEdgeVertIds source_node edit_modifier edge_id
                        if edge_verts.count == 2 then
                        (
                                point_a = getModifierVertexWorldPoint source_node edit_modifier edge_verts[1]
                                point_b = getModifierVertexWorldPoint source_node edit_modifier edge_verts[2]
                                if point_a == undefined or point_b == undefined or distance point_a point_b <= tolerance then
                                (
                                        invalid_edges[edge_id] = true
                                )
                        )
                )
                invalid_edges
                -- return
        ),


        /*
        Finds arbitrary-orientation border overlaps and duplicate collinear segments.
        Unlike the original local-Z seam test, this works on any 3D border direction.
        */
        function findOverlappingBorderEdges source_node edit_modifier border_edges tolerance:0.0001 =
        (
                invalid_edges = #{}
                edge_array = border_edges as array


                if edge_array.count > 1 then
                (
                        for index_a = 1 to edge_array.count - 1 do
                        (
                                edge_a = edge_array[index_a]
                                verts_a = getEdgeVertIds source_node edit_modifier edge_a
                                point_a0 = getModifierVertexWorldPoint source_node edit_modifier verts_a[1]
                                point_a1 = getModifierVertexWorldPoint source_node edit_modifier verts_a[2]
                                vector_a = point_a1 - point_a0
                                length_a = length vector_a


                                if length_a > tolerance then
                                (
                                        direction_a = vector_a / length_a


                                        for index_b = index_a + 1 to edge_array.count do
                                        (
                                                edge_b = edge_array[index_b]
                                                verts_b = getEdgeVertIds source_node edit_modifier edge_b
                                                point_b0 = getModifierVertexWorldPoint source_node edit_modifier verts_b[1]
                                                point_b1 = getModifierVertexWorldPoint source_node edit_modifier verts_b[2]
                                                vector_b = point_b1 - point_b0
                                                length_b = length vector_b


                                                if length_b > tolerance then
                                                (
                                                        direction_b = vector_b / length_b
                                                        parallel_value = length (cross direction_a direction_b)


                                                        if parallel_value <= 0.0001 then
                                                        (
                                                                line_distance = length (cross (point_b0 - point_a0) direction_a)
                                                                if line_distance <= tolerance then
                                                                (
                                                                        projection_b0 = dot (point_b0 - point_a0) direction_a
                                                                        projection_b1 = dot (point_b1 - point_a0) direction_a
                                                                        min_b = amin projection_b0 projection_b1
                                                                        max_b = amax projection_b0 projection_b1
                                                                        overlap_start = amax 0.0 min_b
                                                                        overlap_end = amin length_a max_b
                                                                        if (overlap_end - overlap_start) > tolerance then
                                                                        (
                                                                                invalid_edges[edge_a] = true
                                                                                invalid_edges[edge_b] = true
                                                                        )
                                                                )
                                                        )
                                                )
                                        )
                                )
                        )
                )


                invalid_edges
                -- return
        ),


        /*
        Finds border vertices that geometrically lie in the interior of another border segment.
        The offending segment and the vertex's own border edges are returned for inspection.
        */
        function findBorderVertexOnEdgeProblems source_node edit_modifier border_edges tolerance:0.0001 =
        (
                invalid_edges = #{}
                border_vertices = #{}
                for edge_id in border_edges do
                (
                        edge_verts = getEdgeVertIds source_node edit_modifier edge_id
                        if edge_verts.count == 2 then
                        (
                                border_vertices[edge_verts[1]] = true
                                border_vertices[edge_verts[2]] = true
                        )
                )


                for vertex_id in border_vertices do
                (
                        vertex_point = getModifierVertexWorldPoint source_node edit_modifier vertex_id
                        vertex_border_edges = getBorderEdgesAtVertex source_node edit_modifier border_edges vertex_id


                        for edge_id in border_edges do
                        (
                                if findItem vertex_border_edges edge_id == 0 then
                                (
                                        edge_verts = getEdgeVertIds source_node edit_modifier edge_id
                                        point_a = getModifierVertexWorldPoint source_node edit_modifier edge_verts[1]
                                        point_b = getModifierVertexWorldPoint source_node edit_modifier edge_verts[2]
                                        segment_data = getPointSegmentData vertex_point point_a point_b
                                        edge_length = distance point_a point_b
                                        end_tolerance = if edge_length > tolerance then tolerance / edge_length else 1.0


                                        if segment_data[1] <= tolerance and segment_data[2] > end_tolerance and segment_data[2] < (1.0 - end_tolerance) then
                                        (
                                                invalid_edges[edge_id] = true
                                                for own_edge in vertex_border_edges do invalid_edges[own_edge] = true
                                        )
                                )
                        )
                )


                invalid_edges
                -- return
        ),


        /*
        Returns all three border edges when one border vertex matches the EPolyTools straight-through T-junction rule.
        */
        function getTJunctionEdges source_node edit_modifier border_edges vertex_id =
        (
                result_edges = #{}
                incident_edges = getBorderEdgesAtVertex source_node edit_modifier border_edges vertex_id
                if incident_edges.count != 3 then return result_edges


                edge_a = incident_edges[1]
                edge_b = incident_edges[2]
                edge_c = incident_edges[3]
                other_a = getOtherEdgeVertex source_node edit_modifier edge_a vertex_id
                other_b = getOtherEdgeVertex source_node edit_modifier edge_b vertex_id
                other_c = getOtherEdgeVertex source_node edit_modifier edge_c vertex_id
                if other_a < 1 or other_b < 1 or other_c < 1 then return result_edges


                vertex_position = getVertexPosition source_node edit_modifier vertex_id
                position_a = getVertexPosition source_node edit_modifier other_a
                position_b = getVertexPosition source_node edit_modifier other_b
                position_c = getVertexPosition source_node edit_modifier other_c


                vector_a = position_a - vertex_position
                vector_b = position_b - vertex_position
                vector_c = position_c - vertex_position
                if length vector_a <= 0.000001 or length vector_b <= 0.000001 or length vector_c <= 0.000001 then return result_edges


                vector_a = normalize vector_a
                vector_b = normalize vector_b
                vector_c = normalize vector_c


                if (dot vector_a vector_b <= straight_pair_dot_limit) or (dot vector_a vector_c <= straight_pair_dot_limit) or (dot vector_b vector_c <= straight_pair_dot_limit) then
                (
                        result_edges[edge_a] = true
                        result_edges[edge_b] = true
                        result_edges[edge_c] = true
                )


                result_edges
                -- return
        ),


        /*
        Finds straight-through three-edge T-junctions only on the open border.
        */
        function findTJunctionEdges source_node edit_modifier border_edges =
        (
                result_edges = #{}
                border_vertices = #{}


                for edge_id in border_edges do
                (
                        edge_verts = getEdgeVertIds source_node edit_modifier edge_id
                        if edge_verts.count == 2 then
                        (
                                border_vertices[edge_verts[1]] = true
                                border_vertices[edge_verts[2]] = true
                        )
                )


                for vertex_id in border_vertices do
                (
                        result_edges += getTJunctionEdges source_node edit_modifier border_edges vertex_id
                )


                result_edges
                -- return
        ),


        /*
        Performs the final border gate before WALL THICKNESS.
        Zero-length segments, overlaps, 360-degree backtracking peaks, border T-junctions, and border vertices lying on another border edge are all selected as invalid edges.
        */
        function checkDegenerateBorders source_node edit_modifier tolerance:0.0001 =
        (
                if not(prepareEditPoly source_node edit_modifier selection_level:#Edge) then return #(false, 0, #{}, 0, 0, 0, 0, 0)


                border_edges = getVisibleBorderEdges source_node edit_modifier
                zero_length_edges = findZeroLengthBorderEdges source_node edit_modifier border_edges tolerance:tolerance
                overlap_edges = findOverlappingBorderEdges source_node edit_modifier border_edges tolerance:tolerance
                backtrack_edges = findBacktrackBorderEdges source_node edit_modifier border_edges
                tjunction_edges = findTJunctionEdges source_node edit_modifier border_edges
                vertex_on_edge_edges = findBorderVertexOnEdgeProblems source_node edit_modifier border_edges tolerance:tolerance


                invalid_edges = copy zero_length_edges
                invalid_edges += overlap_edges
                invalid_edges += backtrack_edges
                invalid_edges += tjunction_edges
                invalid_edges += vertex_on_edge_edges


                selectModifierComponents source_node edit_modifier #Edge invalid_edges
                edit_modifier.showCage = off
                edit_modifier.RefreshScreen()
                update source_node


                #(
                        true,
                        invalid_edges.numberSet,
                        invalid_edges,
                        zero_length_edges.numberSet,
                        overlap_edges.numberSet,
                        backtrack_edges.numberSet,
                        tjunction_edges.numberSet,
                        vertex_on_edge_edges.numberSet
                )
                -- return
        ),


        on create do
        (
        )
)


WallThicknessPreprocess = WallThicknessPreprocess_v()




/*
Returns a short label for the current 3ds Max display unit.
*/
function getWallThicknessDisplayUnitsLabel =
(
        case units.DisplayType of
        (
                #Metric:
                (
                        case units.MetricType of
                        (
                                #Millimeters: "mm"
                                #Centimeters: "cm"
                                #Meters: "m"
                                #Kilometers: "km"
                                default: "units"
                        )
                )
                #US:
                (
                        case units.USType of
                        (
                                #Frac_In: "in"
                                #Dec_In: "in"
                                #Frac_Ft: "ft"
                                #Dec_Ft: "ft"
                                #Ft_Frac_In: "ft/in"
                                #Ft_Dec_In: "ft/in"
                                default: "units"
                        )
                )
                #Custom:
                (
                        if units.CustomName != "" then
                                units.CustomName
                        else
                        (
                                unit_text = units.CustomUnit as string
                                unit_text = substituteString unit_text "#" ""
                                unit_text
                        )
                )
                default: "units"
        )
)


function loadWallThicknessRatio =
(
        saved_value = getINISetting wall_thickness_ini "Settings" "ModelRatio"
        if saved_value == "" then wall_thickness_ratio_default else amax 1 (saved_value as integer)
)


function saveWallThicknessRatio ratio_value =
(
        setINISetting wall_thickness_ini "Settings" "ModelRatio" ((amax 1 ratio_value) as string)
        true
)


function loadWallThicknessDialogPos =
(
        x_text = getINISetting wall_thickness_ini "UI" "X"
        y_text = getINISetting wall_thickness_ini "UI" "Y"


        if (x_text == "") or (y_text == "") then
                undefined
        else
                [x_text as integer, y_text as integer]
)


function saveWallThicknessDialogPos =
(
        try
        (
                dialog_pos = getDialogPos wallThicknessRollout
                setINISetting wall_thickness_ini "UI" "X" (dialog_pos.x as string)
                setINISetting wall_thickness_ini "UI" "Y" (dialog_pos.y as string)
        )
        catch
        (
        )
        true
)


/*
Returns a readable metric value and unit for one system-unit distance.
The smallest practical metric unit is millimeters so values such as 0.003 m display as 3 mm.
*/
function getWallThicknessNiceMetricValue system_value =
(
        absolute_value = abs system_value
        unit_scale = 1.0
        unit_label = "mm"


        millimeter_scale = units.decodeValue "1mm"
        centimeter_scale = units.decodeValue "1cm"
        meter_scale = units.decodeValue "1m"
        kilometer_scale = units.decodeValue "1km"


        if absolute_value >= kilometer_scale then
        (
                unit_scale = kilometer_scale
                unit_label = "km"
        )
        else if absolute_value >= meter_scale then
        (
                unit_scale = meter_scale
                unit_label = "m"
        )
        else if absolute_value >= centimeter_scale then
        (
                unit_scale = centimeter_scale
                unit_label = "cm"
        )
        else
        (
                unit_scale = millimeter_scale
                unit_label = "mm"
        )


        #(system_value / unit_scale, unit_label)
        -- return
)


/*
Formats scaled thickness using a compact unit-aware value.
Metric display automatically chooses km, m, cm, or mm; other display systems keep the current 3ds Max unit format.
*/
function getWallThicknessScaledDisplay system_value =
(
        if units.DisplayType == #Metric then
        (
                metric_data = getWallThicknessNiceMetricValue system_value
                #(formattedPrint metric_data[1] format:"0.6g", metric_data[2])
        )
        else
        (
                formatted_value = units.formatValue system_value
                #(formatted_value, getWallThicknessDisplayUnitsLabel())
        )
        -- return
)


/*
Updates the scaled-thickness row from the current thickness and model ratio.
The displayed result is converted to a compact human-readable unit.
*/
function updateWallThicknessScaledLabel =
(
        if wallThicknessRollout != undefined then
        (
                ratio_value = amax 1 wallThicknessRollout.spn_ratio.value
                scaled_value = wallThicknessRollout.spn_thickness.value / ratio_value
                display_data = getWallThicknessScaledDisplay scaled_value
                wallThicknessRollout.lbl_scaled.text = display_data[1]
                wallThicknessRollout.lbl_scaled_units.text = display_data[2]
        )
        true
)




/*
Reads saved thickness from the tool INI file.
Defaults to one current world/display unit.
*/
function loadWallThicknessSetting =
(
        saved_value = getINISetting wall_thickness_ini "Settings" "Thickness"
        if saved_value == "" then (1.0) else (saved_value as float)
        -- return
)


/*
Stores current thickness in the tool INI file.
The value is restored when the UI is opened again.
*/
function saveWallThicknessSetting thickness =
(
        setINISetting wall_thickness_ini "Settings" "Thickness" (thickness as string)
        true
        -- return
)


/*
Stores every persistent rollout control value in Wall-Thickness.ini.
The INI mirrors the current UI even when values were changed programmatically.
*/
function saveWallThicknessControlValues =
(
        if wallThicknessRollout != undefined then
        (
                saveWallThicknessSetting wallThicknessRollout.spn_thickness.value
                saveWallThicknessRatio wallThicknessRollout.spn_ratio.value
        )


        true
        -- return
)


/*
Loads every persistent rollout control value from Wall-Thickness.ini.
Selection synchronization may then replace Thickness with the selected wall's own stored value.
*/
function loadWallThicknessControlValues =
(
        if wallThicknessRollout != undefined then
        (
                wallThicknessRollout.spn_thickness.value = loadWallThicknessSetting()
                wallThicknessRollout.spn_ratio.value = loadWallThicknessRatio()
        )


        true
        -- return
)


/*
Reads thickness stored directly on one wall node.
Objects without a stored value use the last thickness saved in Wall-Thickness.ini.
*/
function getObjectWallThickness source_node =
(
        thickness = loadWallThicknessSetting()


        if isValidNode source_node then
        (
                saved_value = getUserProp source_node wall_thickness_user_prop


                if saved_value != undefined then
                (
                        if (classOf saved_value == Float) or (classOf saved_value == Integer) then
                        (
                                thickness = saved_value as float
                        )
                        else
                        (
                                saved_text = saved_value as string


                                if saved_text != "" then
                                (
                                        thickness = saved_text as float
                                )
                        )
                )
        )


        thickness
        -- return
)




/*
Stores thickness directly in the selected wall node user properties.
Each wall therefore owns its own independent thickness value.
*/
function setObjectWallThickness source_node thickness =
(
        if isValidNode source_node then
        (
                setUserProp source_node wall_thickness_user_prop thickness
        )


        true
        -- return
)




/*
Updates the UI spinner from the currently selected wall object.
Selection changes also make that node the active dynamic-thickness target.
*/
function syncWallThicknessSpinnerToSelection =
(
        if wallThicknessRollout != undefined then
        (
                if selection.count == 1 then
                (
                        source_node = selection[1]
                        wall_thickness_target = source_node
                        wallThicknessRollout.spn_thickness.value = getObjectWallThickness source_node
                )
                else
                (
                        wall_thickness_target = undefined
                        wallThicknessRollout.spn_thickness.value = loadWallThicknessSetting()
                )


                saveWallThicknessControlValues()
        )


        true
        -- return
)




/*
Returns unique horizontal wall normals around a TriMesh vertex.
Normals are projected to XY so imported face noise cannot create Z displacement.
*/
function getUniqueNormals mesh_data face_ids =
(
        normal_array = #()


        for face_id in face_ids do
        (
                source_normal = getFaceNormal mesh_data face_id
                flat_normal = [source_normal.x, source_normal.y, 0]


                if (length flat_normal) > 0.000001 then
                (
                        face_normal = normalize flat_normal
                        is_unique = true


                        for existing_normal in normal_array while is_unique do
                        (
                                if (abs (dot face_normal existing_normal)) > 0.99999 then
                                (
                                        is_unique = false
                                )
                        )


                        if is_unique then
                        (
                                append normal_array face_normal
                        )
                )
        )


        normal_array
        -- return
)




/*
Solves the constant-distance intersection offset for two planes.
Both normals are expected to point toward the required inner side.
*/
function solveTwoPlaneOffset normal_a normal_b thickness =
(
        dot_ab = dot normal_a normal_b
        denominator = 1.0 + dot_ab
        if (abs denominator) < 0.000001 then
        (
                normal_a * thickness
        )
        else
        (
                ((normal_a + normal_b) / denominator) * thickness
        )
        -- return
)


/*
Solves the constant-distance intersection offset for three planes.
Returns undefined when the planes do not define a stable intersection.
*/
function solveThreePlaneOffset normal_a normal_b normal_c thickness =
(
        cross_bc = cross normal_b normal_c
        cross_ca = cross normal_c normal_a
        cross_ab = cross normal_a normal_b
        determinant = dot normal_a cross_bc
        if (abs determinant) < 0.000001 then
        (
                undefined
        )
        else
        (
                ((cross_bc + cross_ca + cross_ab) * thickness) / determinant
        )
        -- return
)


/*
Calculates horizontal inward displacement for one source vertex.
Z displacement is always zero and pathological miters are limited.
*/
function getOffsetDisplacement mesh_data vertex_id thickness =
(
        face_bits = meshop.getFacesUsingVert mesh_data #{vertex_id}
        face_ids = face_bits as array
        normal_array = getUniqueNormals mesh_data face_ids


        for normal_id = 1 to normal_array.count do
        (
                normal_array[normal_id] = -normal_array[normal_id]
        )


        normal_count = normal_array.count
        offset_vector = [0, 0, 0]


        if normal_count == 1 then
        (
                offset_vector = normal_array[1] * thickness
        )
        else if normal_count >= 2 then
        (
                offset_vector = solveTwoPlaneOffset normal_array[1] normal_array[2] thickness
        )


        offset_vector.z = 0
        max_miter_length = thickness * 20.0


        if (length offset_vector) > max_miter_length then
        (
                if normal_count > 0 then
                (
                        offset_vector = normal_array[1] * thickness
                        offset_vector.z = 0
                )
                else
                (
                        offset_vector = [0, 0, 0]
                )
        )


        offset_vector
        -- return
)




/*
Returns the two vertex indices used by one TriMesh edge.
Undefined is returned if the edge does not resolve to exactly two vertices.
*/
function getMeshEdgeVertices mesh_data edge_id =
(
        vertex_bits = meshop.getVertsUsingEdge mesh_data #{edge_id}
        vertex_ids = vertex_bits as array
        if vertex_ids.count == 2 then
        (
                [vertex_ids[1], vertex_ids[2], 0]
        )
        else
        (
                undefined
        )
        -- return
)


/*
Finds the tool-owned Edit Poly modifier on a node.
Only the modifier named WALL THICKNESS is considered.
*/
function getWallThicknessModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (classOf test_modifier == Edit_Poly) and (test_modifier.name == wall_thickness_modifier_name) then
                        (
                                found_modifier = test_modifier
                        )
                )
        )
        found_modifier
        -- return
)


/*
Finds one exact tool-owned modifier by name.
No unrelated user modifier is returned.
*/
function getWallThicknessNamedModifier source_node modifier_name =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if test_modifier.name == modifier_name then found_modifier = test_modifier
                )
        )
        found_modifier
        -- return
)


/*
Counts modifiers with one exact name without changing the stack.
*/
function countWallThicknessNamedModifiers source_node modifier_name =
(
        modifier_count = 0
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count do
                (
                        if source_node.modifiers[modifier_id].name == modifier_name then
                        (
                                modifier_count += 1
                        )
                )
        )
        modifier_count
        -- return
)




/*
Removes one exact tool-owned modifier by name.
*/
function removeWallThicknessNamedModifier source_node modifier_name =
(
        test_modifier = getWallThicknessNamedModifier source_node modifier_name
        if test_modifier != undefined then deleteModifier source_node test_modifier
        true
        -- return
)


/*
Removes every modifier with one exact tool-owned name.
This is used for SELECT/DELETED stage history where repeated RMB operations may legitimately leave more than one committed modifier.
*/
function removeAllWallThicknessNamedModifiers source_node modifier_name =
(
        removed_count = 0
        if isValidNode source_node then
        (
                test_modifier = getWallThicknessNamedModifier source_node modifier_name
                while test_modifier != undefined do
                (
                        deleteModifier source_node test_modifier
                        removed_count += 1
                        test_modifier = getWallThicknessNamedModifier source_node modifier_name
                )
        )
        removed_count
        -- return
)


/*
Removes all preprocessing history owned by Wall Thickness.
The base object and unrelated modifiers remain untouched.
*/
function removeWallThicknessPreprocessModifiers source_node =
(
        removeWallThicknessNamedModifier source_node wall_thickness_border_check_modifier_name
        removeWallThicknessNamedModifier source_node wall_thickness_legacy_border_check_modifier_name
        removeWallThicknessNamedModifier source_node wall_thickness_multiple_edges_modifier_name
        removeWallThicknessNamedModifier source_node wall_thickness_legacy_multiple_edges_modifier_name
        removeAllWallThicknessNamedModifiers source_node wall_thickness_degenerate_modifier_name
        removeAllWallThicknessNamedModifiers source_node wall_thickness_deleted_degenerate_modifier_name
        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_degenerate_modifier_name
        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_deleted_degenerate_modifier_name
        removeWallThicknessNamedModifier source_node wall_thickness_source_weld_modifier_name
        removeWallThicknessNamedModifier source_node wall_thickness_legacy_source_weld_modifier_name
        removeAllWallThicknessNamedModifiers source_node wall_thickness_remove_generated_modifier_name
        removeAllWallThicknessNamedModifiers source_node wall_thickness_deleted_generated_modifier_name
        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_remove_generated_modifier_name
        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_deleted_generated_modifier_name
        true
        -- return
)


/*
Removes all non-collapsing CLEANUP stages owned by Wall Thickness.
*/
function removeWallThicknessCleanupStageModifiers source_node =
(
        removeWallThicknessNamedModifier source_node wall_thickness_cleanup_multiple_modifier_name
        removeWallThicknessNamedModifier source_node wall_thickness_cleanup_weld_modifier_name
        removeWallThicknessNamedModifier source_node wall_thickness_cleanup_cap_modifier_name
        removeWallThicknessNamedModifier source_node wall_thickness_cleanup_quadrify_modifier_name
        true
        -- return
)


/*
Finds the zero-threshold source weld preprocessing stage.
*/
function getWallThicknessPreWeldModifier source_node =
(
        weld_modifier = getWallThicknessNamedModifier source_node wall_thickness_source_weld_modifier_name
        if weld_modifier == undefined then weld_modifier = getWallThicknessNamedModifier source_node wall_thickness_legacy_source_weld_modifier_name
        weld_modifier
        -- return
)


/*
Ensures one zero-threshold WELD SOURCE preprocessing modifier exists.
The helper remains for compatibility; normal Apply builds the full PREP history explicitly.
*/
function ensureWallThicknessPreWeldModifier source_node existing_pre_weld:undefined =
(
        pre_weld_modifier = existing_pre_weld


        if isValidNode source_node then
        (
                if pre_weld_modifier == undefined then
                (
                        pre_weld_modifier = VertexWeld()
                        pre_weld_modifier.name = wall_thickness_source_weld_modifier_name
                        pre_weld_modifier.threshold = 0.0
                        addModifier source_node pre_weld_modifier
                )
                else
                (
                        pre_weld_modifier.threshold = 0.0
                )
        )


        pre_weld_modifier
        -- return
)


/*
Finds the finalized tool-owned Edit Poly modifier on a node.
Only the modifier named WALL THICKNESS FINISHED is considered.
*/
function getFinishedWallThicknessModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (classOf test_modifier == Edit_Poly) and (test_modifier.name == wall_thickness_finished_modifier_name) then
                        (
                                found_modifier = test_modifier
                        )
                )
        )
        found_modifier
        -- return
)


/*
Finds the separate post-process cleanup modifier on a node.
The stable WALL THICKNESS core modifier is not inspected or changed.
*/
function getWallThicknessCleanupModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (classOf test_modifier == Edit_Poly) and (test_modifier.name == wall_thickness_cleanup_modifier_name) then
                        (
                                found_modifier = test_modifier
                        )
                )
        )
        found_modifier
        -- return
)


/*
Returns true after CLEANUP has completed successfully for the current WALL THICKNESS result.
No-op cleanup stages may be removed, so completion is stored separately from modifier presence.
*/
function hasCompletedWallThicknessCleanupHistory source_node =
(
        if not isValidNode source_node then
        (
                false
        )
        else if getWallThicknessModifier source_node == undefined then
        (
                false
        )
        else
        (
                cleanup_value = getUserProp source_node wall_thickness_cleanup_complete_prop
                cleanup_complete = false
                if cleanup_value != undefined then
                (
                        try (cleanup_complete = ((cleanup_value as integer) == 1)) catch (cleanup_complete = false)
                )
                cleanup_complete
        )
        -- return
)


/*
Stores or clears the successful CLEANUP state independently from visible no-op modifiers.
*/
function setWallThicknessCleanupComplete source_node cleanup_complete =
(
        if isValidNode source_node then
        (
                if cleanup_complete then
                (
                        setUserProp source_node wall_thickness_cleanup_complete_prop 1
                )
                else
                (
                        try (deleteUserProp source_node wall_thickness_cleanup_complete_prop) catch ()
                )
        )
        true
        -- return
)


/*
Finds the standalone inner-corner intersection fix modifier.
*/
function getWallThicknessInnerCornerFixModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (classOf test_modifier == Edit_Poly) and (test_modifier.name == wall_thickness_inner_fix_modifier_name) then
                        (
                                found_modifier = test_modifier
                        )
                )
        )
        found_modifier
        -- return
)


/*
Finds the standalone T-edge corner repair modifier.
It is always a separate Edit Poly layer above the already evaluated stack.
*/
function getWallThicknessTEdgeFixModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (classOf test_modifier == Edit_Poly) and (test_modifier.name == wall_thickness_t_edge_fix_modifier_name) then
                        (
                                found_modifier = test_modifier
                        )
                )
        )
        found_modifier
        -- return
)


/*
Finds the zero-threshold weld owned by FIX INNER CORNERS.
*/
function getWallThicknessInnerCornerWeldModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (test_modifier.name == wall_thickness_inner_weld_modifier_name) and (isProperty test_modifier #threshold) then
                        (
                                found_modifier = test_modifier
                        )
                )
        )
        found_modifier
        -- return
)


/*
Finds the standalone outer-corner intersection/chamfer fix modifier.
The stable WALL THICKNESS modifier is never edited by this pass.
*/
function getWallThicknessChamferFixModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (classOf test_modifier == Edit_Poly) and (test_modifier.name == wall_thickness_chamfer_fix_modifier_name) then
                        (
                                found_modifier = test_modifier
                        )
                )
        )
        found_modifier
        -- return
)


/*
Finds the zero-threshold weld owned by FIX OUTER CORNERS.
It is kept separate from the live WALL THICKNESS pre-weld.
*/
function getWallThicknessChamferWeldModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (test_modifier.name == wall_thickness_chamfer_weld_modifier_name) and (isProperty test_modifier #threshold) then
                        (
                                found_modifier = test_modifier
                        )
                )
        )
        found_modifier
        -- return
)


/*
Finds the optional STL Check modifier owned by this tool.
*/
function getWallThicknessSTLCheckModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (classOf test_modifier == STL_Check) and (test_modifier.name == wall_thickness_stl_check_modifier_name) then
                        (
                                found_modifier = test_modifier
                        )
                )
        )
        found_modifier
        -- return
)


/*
Removes only the optional Wall Thickness STL Check modifier.
*/
function removeWallThicknessSTLCheckModifier source_node =
(
        stl_modifier = getWallThicknessSTLCheckModifier source_node
        if stl_modifier != undefined then
        (
                deleteModifier source_node stl_modifier
        )
        true
        -- return
)


/*
Removes only the separate Wall Thickness cleanup modifier.
The stable thickness modifier and unrelated modifiers remain untouched.
*/
function removeWallThicknessCleanupModifier source_node =
(
        cleanup_modifier = getWallThicknessCleanupModifier source_node
        if cleanup_modifier != undefined then
        (
                deleteModifier source_node cleanup_modifier
        )
        true
        -- return
)


/*
Removes only the standalone inner-corner intersection fix modifier.
*/
function removeWallThicknessInnerCornerFixModifier source_node =
(
        inner_modifier = getWallThicknessInnerCornerFixModifier source_node
        if inner_modifier != undefined then
        (
                deleteModifier source_node inner_modifier
        )
        true
        -- return
)


/*
Removes only the FIX T EDGE CORNERS Edit Poly layer.
All lower Wall Thickness stages and unrelated modifiers remain untouched.
*/
function removeWallThicknessTEdgeFixModifier source_node =
(
        t_edge_modifier = getWallThicknessTEdgeFixModifier source_node
        if t_edge_modifier != undefined then
        (
                deleteModifier source_node t_edge_modifier
        )
        true
        -- return
)


/*
Removes only the zero-threshold weld created by FIX INNER CORNERS.
*/
function removeWallThicknessInnerCornerWeldModifier source_node =
(
        inner_weld_modifier = getWallThicknessInnerCornerWeldModifier source_node
        if inner_weld_modifier != undefined then
        (
                deleteModifier source_node inner_weld_modifier
        )
        true
        -- return
)


/*
Removes legacy FIX CHAMFERS modifiers from older Wall Thickness versions.
*/
function removeWallThicknessLegacyChamferModifiers source_node =
(
        removeWallThicknessNamedModifier source_node wall_thickness_legacy_chamfer_weld_modifier_name
        removeWallThicknessNamedModifier source_node wall_thickness_legacy_chamfer_fix_modifier_name
        true
        -- return
)


/*
Removes only the standalone outer-corner intersection/chamfer fix modifier.
The stable thickness modifier and unrelated modifiers remain untouched.
*/
function removeWallThicknessChamferFixModifier source_node =
(
        chamfer_modifier = getWallThicknessChamferFixModifier source_node
        if chamfer_modifier != undefined then
        (
                deleteModifier source_node chamfer_modifier
        )
        true
        -- return
)


/*
Removes only the zero-threshold weld created by FIX OUTER CORNERS.
Unrelated Vertex Weld modifiers are never touched.
*/
function removeWallThicknessChamferWeldModifier source_node =
(
        chamfer_weld_modifier = getWallThicknessChamferWeldModifier source_node
        if chamfer_weld_modifier != undefined then
        (
                deleteModifier source_node chamfer_weld_modifier
        )
        true
        -- return
)


/*
Removes the finalized thickness modifier from a node.
The source object and every unrelated modifier remain untouched.
*/
function removeFinishedWallThicknessModifier source_node =
(
        finished_modifier = getFinishedWallThicknessModifier source_node
        if finished_modifier != undefined then
        (
                deleteModifier source_node finished_modifier
        )
        true
        -- return
)


/*
Removes the previous generated thickness modifier from a node.
The source object and every other modifier remain untouched.
*/
function removeWallThicknessModifier source_node =
(
        thickness_modifier = getWallThicknessModifier source_node
        if thickness_modifier != undefined then
        (
                deleteModifier source_node thickness_modifier
        )
        setWallThicknessCleanupComplete source_node false
        true
        -- return
)


/*
Removes every Wall Thickness modifier owned by this tool from one node.
Both live and finished thickness modifiers are removed while unrelated modifiers and source geometry remain untouched.
*/
function resetWallThickness source_node =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                false
        )
        else
        (
                undo "Reset Wall Thickness" on
                (
                        removeWallThicknessSTLCheckModifier source_node
                        removeWallThicknessInnerCornerWeldModifier source_node
                        removeWallThicknessInnerCornerFixModifier source_node
                        removeWallThicknessTEdgeFixModifier source_node
                        removeWallThicknessChamferWeldModifier source_node
                        removeWallThicknessChamferFixModifier source_node
                        removeWallThicknessLegacyChamferModifiers source_node
                        removeWallThicknessNamedModifier source_node wall_thickness_auto_quadrify_modifier_name
                        removeWallThicknessCleanupModifier source_node
                        removeWallThicknessCleanupStageModifiers source_node
                        removeWallThicknessModifier source_node
                        removeFinishedWallThicknessModifier source_node
                        removeWallThicknessPreprocessModifiers source_node
                )


                try (deleteUserProp source_node wall_thickness_source_face_count_prop) catch ()
                try (deleteUserProp source_node wall_thickness_source_vert_count_prop) catch ()


                if wall_thickness_target == source_node then wall_thickness_target = undefined
                subObjectLevel = 0
                completeRedraw()
                true
        )
        -- return
)


/*
Assigns one material ID to a face bitarray through Edit Poly.
The operation is committed into the modifier.
*/
function setEditPolyMaterialID edit_modifier source_node face_bits material_id =
(
        if face_bits.numberSet > 0 then
        (
                edit_modifier.SetSelection #Face face_bits node:source_node
                edit_modifier.materialIDToSet = material_id
                edit_modifier.SetOperation #SetMaterial
                edit_modifier.Commit()
        )
        true
        -- return
)


/*
Applies native Edit Poly Auto Smooth to the complete result.
The threshold is explicitly set to 45 degrees.
*/
function autoSmoothEditPolyResult edit_modifier source_node =
(
        face_count = edit_modifier.GetNumFaces node:source_node
        if face_count > 0 then
        (
                all_faces = #{1..face_count}
                edit_modifier.SetSelection #Face all_faces node:source_node
                edit_modifier.autoSmoothThreshold = 45.0
                edit_modifier.SetOperation #Autosmooth
                edit_modifier.Commit()
        )
        true
        -- return
)


/*
Applies native Edit Poly Auto Smooth only to generated inner-wall and strip faces.
The original source-face smoothing groups remain unchanged.
*/
function autoSmoothWallThicknessGeneratedFaces edit_modifier source_node inner_face_ids strip_face_ids =
(
        generated_face_ids = inner_face_ids + strip_face_ids
        if generated_face_ids.numberSet > 0 then
        (
                edit_modifier.SetSelection #Face generated_face_ids node:source_node
                edit_modifier.autoSmoothThreshold = 45.0
                edit_modifier.SetOperation #Autosmooth
                edit_modifier.Commit()
        )
        true
        -- return
)


/*
Returns one normalized source-face normal for strict wall extrusion.
No vertex-normal averaging or miter direction is used.
*/
function getWallThicknessStrictFaceNormal mesh_data face_id =
(
        face_normal = getFaceNormal mesh_data face_id
        if face_normal == undefined then
        (
                undefined
        )
        else if (length face_normal) > 0.000001 then
        (
                normalize face_normal
        )
        else
        (
                undefined
        )
        -- return
)


/*
Returns or creates the generated vertex for one source vertex and one face-normal direction.
Coplanar triangles reuse the same generated vertex while sharp wall corners keep separate face-normal copies.
*/
function getOrCreateWallThicknessFaceVertex edit_modifier source_node source_mesh vertex_id face_normal thickness vertex_group_normals vertex_group_ids =
(
        normal_groups = vertex_group_normals[vertex_id]
        id_groups = vertex_group_ids[vertex_id]
        matching_group = 0


        for group_id = 1 to normal_groups.count while matching_group == 0 do
        (
                if (dot normal_groups[group_id] face_normal) > 0.99999 then
                (
                        matching_group = group_id
                )
        )


        if matching_group > 0 then
        (
                existing_vertex_id = id_groups[matching_group]
                if existing_vertex_id != undefined then existing_vertex_id else 0
        )
        else
        (
                source_position = getVert source_mesh vertex_id
                offset_position = source_position - (face_normal * thickness)
                new_vertex_id = edit_modifier.CreateVertex offset_position node:source_node


                if new_vertex_id != undefined then
                (
                        append normal_groups face_normal
                        append id_groups new_vertex_id
                        vertex_group_normals[vertex_id] = normal_groups
                        vertex_group_ids[vertex_id] = id_groups
                        new_vertex_id
                )
                else
                (
                        0
                )
        )
        -- return
)


/*
Returns the generated vertex used by one source face at one source vertex.
The face offset array is stored in source-face x/y/z order.
*/
function getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_id source_vertex_id =
(
        result_id = 0
        if source_mesh == undefined then return result_id
        if face_id < 1 or face_id > face_offset_vertex_ids.count then return result_id


        source_face = getFace source_mesh face_id
        face_vertex_ids = face_offset_vertex_ids[face_id]
        if face_vertex_ids == undefined or face_vertex_ids.count < 3 then return result_id


        if source_face.x == source_vertex_id then
        (
                if face_vertex_ids[1] != undefined then result_id = face_vertex_ids[1]
        )
        else if source_face.y == source_vertex_id then
        (
                if face_vertex_ids[2] != undefined then result_id = face_vertex_ids[2]
        )
        else if source_face.z == source_vertex_id then
        (
                if face_vertex_ids[3] != undefined then result_id = face_vertex_ids[3]
        )


        result_id
        -- return
)




/*
Creates the first preprocessing history stage after previous live generator modifiers are removed.
If a manually collapsed prior result has an exact stored source-face count, material-2/3 generated faces are removed only when that deletion restores the exact recorded source count.
*/
function addWallThicknessRemoveGeneratedStage source_node =
(
        select_modifier = getWallThicknessNamedModifier source_node wall_thickness_remove_generated_modifier_name
        if select_modifier == undefined then
        (
                select_modifier = getWallThicknessNamedModifier source_node wall_thickness_legacy_remove_generated_modifier_name
                if select_modifier != undefined then select_modifier.name = wall_thickness_remove_generated_modifier_name
        )


        if select_modifier == undefined then
        (
                select_modifier = Edit_Poly()
                select_modifier.name = wall_thickness_remove_generated_modifier_name
                select_modifier.showCage = off
                addModifier source_node select_modifier
        )


        candidate_count = 0
        ambiguous_generated_faces = false
        if WallThicknessPreprocess.prepareEditPoly source_node select_modifier selection_level:#Face then
        (
                expected_face_count = getUserProp source_node wall_thickness_source_face_count_prop
                current_face_count = select_modifier.GetNumFaces node:source_node
                generated_faces = #{}


                for face_id = 1 to current_face_count do
                (
                        material_id = select_modifier.GetFaceMaterial face_id node:source_node
                        if material_id == 2 or material_id == 3 then generated_faces[face_id] = true
                )


                candidate_count = generated_faces.numberSet
                if candidate_count > 0 then
                (
                        if expected_face_count == undefined then
                        (
                                ambiguous_generated_faces = true
                        )
                        else if (current_face_count - candidate_count) != (expected_face_count as integer) then
                        (
                                ambiguous_generated_faces = true
                        )
                )


                WallThicknessPreprocess.selectModifierComponents source_node select_modifier #Face generated_faces
        )


        select_modifier.showCage = off
        select_modifier.RefreshScreen()
        #(select_modifier, candidate_count, ambiguous_generated_faces)
        -- return
)


/*
RMB counterpart for SELECT 02 GENERATED FACES.
Deletes only the face selection stored by the dedicated SELECT modifier after revalidating material IDs and the stored source-face count, then renames the modifier to DELETED 02 GENERATED FACES.
*/
function deleteWallThicknessGeneratedSelection source_node =
(
        result_data = #(false, 0, "no SELECT 02 GENERATED FACES modifier", undefined)
        select_modifier = getWallThicknessNamedModifier source_node wall_thickness_remove_generated_modifier_name
        if select_modifier == undefined then
        (
                select_modifier = getWallThicknessNamedModifier source_node wall_thickness_legacy_remove_generated_modifier_name
                if select_modifier != undefined then select_modifier.name = wall_thickness_remove_generated_modifier_name
        )


        if select_modifier == undefined then
        (
                select_data = addWallThicknessRemoveGeneratedStage source_node
                select_modifier = select_data[1]
        )


        if select_modifier != undefined and WallThicknessPreprocess.prepareEditPoly source_node select_modifier selection_level:#Face then
        (
                selected_faces = select_modifier.GetSelection #Face node:source_node
                selected_count = selected_faces.numberSet


                if selected_count == 0 then
                (
                        result_data = #(true, 0, "no generated faces selected", select_modifier)
                )
                else
                (
                        expected_face_count = getUserProp source_node wall_thickness_source_face_count_prop
                        current_face_count = select_modifier.GetNumFaces node:source_node
                        safe_selection = expected_face_count != undefined and ((current_face_count - selected_count) == (expected_face_count as integer))


                        for face_id in selected_faces while safe_selection do
                        (
                                material_id = select_modifier.GetFaceMaterial face_id node:source_node
                                if material_id != 2 and material_id != 3 then safe_selection = false
                        )


                        if not safe_selection then
                        (
                                result_data = #(false, 0, "selected faces are not a safe exact generated-face set", select_modifier)
                        )
                        else
                        (
                                select_modifier.ButtonOp #DeleteFace
                                update source_node
                                select_modifier.name = wall_thickness_deleted_generated_modifier_name
                                select_modifier.showCage = off
                                try (deleteUserProp source_node wall_thickness_source_face_count_prop) catch ()
                                try (deleteUserProp source_node wall_thickness_source_vert_count_prop) catch ()
                                subObjectLevel = 0
                                result_data = #(true, selected_count, ("removed generated faces: " + (selected_count as string)), select_modifier)
                        )
                )
        )


        result_data
        -- return
)




/*
Creates the exact zero-threshold source weld preprocessing stage.
All coincident source vertices are welded before any topology validation or thickness generation.
*/
function addWallThicknessSourceWeldStage source_node =
(
        removeWallThicknessNamedModifier source_node wall_thickness_source_weld_modifier_name
        weld_modifier = VertexWeld()
        weld_modifier.name = wall_thickness_source_weld_modifier_name
        weld_modifier.threshold = 0.0
        addModifier source_node weld_modifier
        update source_node
        weld_modifier
        -- return
)


/*
Creates and runs the EPolyTools-derived degenerate-face repair stage.
Unresolved faces remain selected and block WALL THICKNESS.
*/
function addWallThicknessDegenerateStage source_node =
(
        select_modifier = getWallThicknessNamedModifier source_node wall_thickness_degenerate_modifier_name
        if select_modifier == undefined then
        (
                select_modifier = getWallThicknessNamedModifier source_node wall_thickness_legacy_degenerate_modifier_name
                if select_modifier != undefined then select_modifier.name = wall_thickness_degenerate_modifier_name
        )


        if select_modifier == undefined then
        (
                select_modifier = Edit_Poly()
                select_modifier.name = wall_thickness_degenerate_modifier_name
                select_modifier.showCage = off
                addModifier source_node select_modifier
        )


        candidate_faces = #{}
        check_succeeded = WallThicknessPreprocess.prepareEditPoly source_node select_modifier selection_level:#Face
        if check_succeeded then
        (
                candidate_faces = WallThicknessPreprocess.findCandidateFaces source_node select_modifier sliver_ratio:WallThicknessPreprocess.default_sliver_ratio
                WallThicknessPreprocess.selectModifierComponents source_node select_modifier #Face candidate_faces
                select_modifier.showCage = off
                select_modifier.RefreshScreen()
                update source_node
        )


        #(select_modifier, #(check_succeeded, 0, candidate_faces.numberSet), candidate_faces)
        -- return
)


/*
RMB counterpart for SELECT 04 DEGENERATE FACES.
Repairs/removes only the faces stored by the dedicated SELECT modifier, revalidates them on the live modifier topology, and renames the working modifier to DELETED 04 DEGENERATE FACES when geometry was changed.
*/
function fixWallThicknessSelectedDegenerateFaces source_node =
(
        result_data = #(false, 0, 0, "no SELECT 04 DEGENERATE FACES modifier", undefined)
        select_modifier = getWallThicknessNamedModifier source_node wall_thickness_degenerate_modifier_name
        if select_modifier == undefined then
        (
                select_modifier = getWallThicknessNamedModifier source_node wall_thickness_legacy_degenerate_modifier_name
                if select_modifier != undefined then select_modifier.name = wall_thickness_degenerate_modifier_name
        )


        if select_modifier == undefined then
        (
                select_data = addWallThicknessDegenerateStage source_node
                select_modifier = select_data[1]
        )


        if select_modifier != undefined and WallThicknessPreprocess.prepareEditPoly source_node select_modifier selection_level:#Face then
        (
                selected_faces = select_modifier.GetSelection #Face node:source_node
                if selected_faces.numberSet == 0 then
                (
                        result_data = #(true, 0, 0, "no degenerate faces selected", select_modifier)
                )
                else
                (
                        repair_data = WallThicknessPreprocess.fixDegenerateFaces source_node select_modifier sliver_ratio:WallThicknessPreprocess.default_sliver_ratio candidate_faces:selected_faces
                        fixed_count = repair_data[2]
                        remaining_count = repair_data[3]


                        if fixed_count > 0 then select_modifier.name = wall_thickness_deleted_degenerate_modifier_name
                        select_modifier.showCage = off
                        select_modifier.RefreshScreen()
                        update source_node


                        if remaining_count > 0 then subObjectLevel = 4 else subObjectLevel = 0
                        result_data = #(repair_data[1], fixed_count, remaining_count, ("fixed/removed: " + (fixed_count as string) + " | remaining: " + (remaining_count as string)), select_modifier)
                )
        )


        result_data
        -- return
)




/*
Creates the xView Multiple Edges diagnostic stage.
Detected multiple edges remain selected for inspection but do not block thickness generation.
*/
function addWallThicknessMultipleEdgesStage source_node =
(
        removeWallThicknessNamedModifier source_node wall_thickness_multiple_edges_modifier_name
        check_modifier = Edit_Poly()
        check_modifier.name = wall_thickness_multiple_edges_modifier_name
        check_modifier.showCage = off
        addModifier source_node check_modifier


        check_succeeded = WallThicknessPreprocess.prepareEditPoly source_node check_modifier selection_level:#Edge
        multiple_edge_results = #()


        if check_succeeded then
        (
                try
                (
                        MultipleEdges.Check currentTime source_node &multiple_edge_results
                )
                catch
                (
                        check_succeeded = false
                        multiple_edge_results = #()
                )
        )


        edge_bits = if multiple_edge_results.count > 0 then (multiple_edge_results as bitarray) else #{}
        if check_succeeded then WallThicknessPreprocess.selectModifierComponents source_node check_modifier #Edge edge_bits
        check_modifier.showCage = off
        check_modifier.RefreshScreen()
        update source_node
        #(check_succeeded, multiple_edge_results.count, edge_bits, check_modifier)
        -- return
)


/*
Creates the final degenerate-border gate immediately below WALL THICKNESS.
It reuses the EPolyTools straight-through T-junction/backtrack rules and adds generic 3D overlap, zero-length, and vertex-on-edge detection.
*/
function addWallThicknessBorderCheckStage source_node =
(
        removeWallThicknessNamedModifier source_node wall_thickness_border_check_modifier_name
        border_modifier = Edit_Poly()
        border_modifier.name = wall_thickness_border_check_modifier_name
        border_modifier.showCage = off
        addModifier source_node border_modifier
        border_data = WallThicknessPreprocess.checkDegenerateBorders source_node border_modifier tolerance:WallThicknessPreprocess.border_tolerance
        #(border_modifier, border_data)
        -- return
)


/*
Returns the object-specific user-property key used to remember that Reset XForm has already been baked.
The current anim handle is part of the key so a cloned object does not inherit another node's completed XForm state.
*/
function getWallThicknessXFormUserPropName source_node =
(
        if not isValidNode source_node then
        (
                undefined
        )
        else
        (
                object_handle = getHandleByAnim source_node
                if object_handle == undefined then undefined
                else wall_thickness_xformed_prop_prefix + (object_handle as string) + "_XFormed"
        )
        -- return
)


/*
Returns true only when this exact object handle has already completed the Wall Thickness Reset XForm step.
*/
function hasWallThicknessXFormApplied source_node =
(
        prop_name = getWallThicknessXFormUserPropName source_node
        if prop_name == undefined then
        (
                false
        )
        else
        (
                prop_value = getUserProp source_node prop_name
                if prop_value == undefined then false
                else
                (
                        value_text = toLower (prop_value as string)
                        (prop_value == true) or (value_text == "true") or (value_text == "1")
                )
        )
        -- return
)


/*
Runs Reset XForm only once per object and stores the completed state on that object's user properties.
This is the only production path allowed to collapse the stack, immediately after Reset XForm adds its XForm modifier.
*/
function resetWallThicknessXFormOnce source_node =
(
        if not isValidNode source_node then
        (
                #(false, false, "invalid node")
        )
        else if hasWallThicknessXFormApplied source_node then
        (
                #(true, false, "RESET XFORM already applied")
        )
        else
        (
                reset_succeeded = false
                try
                (
                        resetXForm source_node
                        collapseStack source_node
                        update source_node
                        if classOf source_node.baseObject == Editable_Poly then try (source_node.baseObject.showCage = off) catch ()


                        prop_name = getWallThicknessXFormUserPropName source_node
                        if prop_name != undefined then
                        (
                                setUserProp source_node prop_name true
                                reset_succeeded = hasWallThicknessXFormApplied source_node
                        )
                )
                catch
                (
                        reset_succeeded = false
                )


                if reset_succeeded then #(true, true, "RESET XFORM + COLLAPSE complete")
                else #(false, false, "RESET XFORM + COLLAPSE failed")
        )
        -- return
)


/*
Builds the complete non-collapsing source preprocessing history.
Multiple-edge findings are diagnostic warnings; unresolved degenerate faces and degenerate borders still block thickness.
*/
function runWallThicknessPreprocess source_node =
(
        if not isValidNode source_node then return #(false, "invalid node", undefined)
        if classOf source_node.baseObject == Editable_Poly then
        (
                try (source_node.baseObject.showCage = off) catch ()
        )


        had_live_thickness = getWallThicknessModifier source_node != undefined


        removeWallThicknessSTLCheckModifier source_node
        removeWallThicknessChamferWeldModifier source_node
        removeWallThicknessChamferFixModifier source_node
        removeWallThicknessCleanupModifier source_node
        removeWallThicknessCleanupStageModifiers source_node
        removeWallThicknessModifier source_node
        removeFinishedWallThicknessModifier source_node
        removeWallThicknessPreprocessModifiers source_node


        xform_data = resetWallThicknessXFormOnce source_node
        if not xform_data[1] then return #(false, xform_data[3], undefined)


        remove_generated_data = addWallThicknessRemoveGeneratedStage source_node
        remove_generated_modifier = remove_generated_data[1]
        if remove_generated_modifier == undefined then return #(false, "could not create SELECT 02 GENERATED FACES stage", undefined)
        if remove_generated_data[3] then
        (
                subObjectLevel = 4
                return #(false, "generated-face cleanup is ambiguous; candidate material-2/3 faces are selected", remove_generated_modifier)
        )
        if remove_generated_data[2] > 0 then
        (
                delete_generated_data = deleteWallThicknessGeneratedSelection source_node
                if not delete_generated_data[1] then return #(false, delete_generated_data[3], delete_generated_data[4])
        )


        weld_modifier = addWallThicknessSourceWeldStage source_node
        if weld_modifier == undefined then return #(false, "could not create WELD SOURCE stage", undefined)


        degenerate_stage = addWallThicknessDegenerateStage source_node
        degenerate_data = degenerate_stage[2]
        if degenerate_stage[1] == undefined or not degenerate_data[1] then return #(false, "could not create SELECT 04 DEGENERATE FACES stage", degenerate_stage[1])


        if degenerate_data[3] > 0 then
        (
                fix_degenerate_data = fixWallThicknessSelectedDegenerateFaces source_node
                if not fix_degenerate_data[1] then
                (
                        subObjectLevel = 4
                        return #(false, ("unresolved degenerate faces: " + (fix_degenerate_data[3] as string)), fix_degenerate_data[5])
                )
        )


        multiple_data = addWallThicknessMultipleEdgesStage source_node
        if not multiple_data[1] then return #(false, "Multiple Edges validation failed", multiple_data[4])
        multiple_warning_count = multiple_data[2]


        border_stage = addWallThicknessBorderCheckStage source_node
        border_data = border_stage[2]
        if not border_data[1] then return #(false, "degenerate border validation failed", border_stage[1])
        if border_data[2] > 0 then
        (
                subObjectLevel = 2
                return #(
                        false,
                        (
                                "degenerate border edges: " + (border_data[2] as string) +
                                " | zero-length:" + (border_data[4] as string) +
                                " overlaps:" + (border_data[5] as string) +
                                " backtrack:" + (border_data[6] as string) +
                                " T-junction:" + (border_data[7] as string) +
                                " vertex-on-edge:" + (border_data[8] as string)
                        ),
                        border_stage[1]
                )
        )


        subObjectLevel = 0
        preprocess_message = "source clean"
        if had_live_thickness then preprocess_message = "previous live generated faces removed"
        if remove_generated_data[2] > 0 then preprocess_message = ("removed legacy generated faces: " + (remove_generated_data[2] as string))
        if multiple_warning_count > 0 then preprocess_message += (" | multiple edges warning: " + (multiple_warning_count as string) + " (ignored)")
        #(true, preprocess_message, border_stage[1])
        -- return
)




/*
Creates wall thickness in one Edit Poly modifier.
The SOURCE WALL is the OUTER WALL and uses material ID 1; the EXTRUDED WALL is the INNER WALL and uses material ID 2; the STRIP uses material ID 3.
Generated inner faces copy the evaluated source polygon boundaries, so quads/ngons keep hidden internal triangulation instead of becoming separate visible triangle faces.
*/
function buildWallThicknessModifier source_node thickness =
(
        if not isValidNode source_node then
        (
                undefined
        )
        else
        (
                removeWallThicknessModifier source_node


                edit_modifier = Edit_Poly()
                edit_modifier.name = wall_thickness_modifier_name
                edit_modifier.showCage = off
                addModifier source_node edit_modifier


                /*
                Bind/evaluate the new empty Edit Poly before reading its topology.
                Clean modifier-free objects can otherwise report zero/stale vertex counts immediately after addModifier.
                */
                modifier_prepared = WallThicknessPreprocess.prepareEditPoly source_node edit_modifier selection_level:#Object


                if not modifier_prepared then
                (
                        deleteModifier source_node edit_modifier
                        messageBox "Unable to initialize WALL THICKNESS on the source wall." title:"Wall Thickness"
                        undefined
                )
                else
                (
                        /*
                        Snapshot only after the empty WALL THICKNESS modifier is bound and evaluated.
                        At this point the snapshot and Edit Poly query describe the exact same unchanged source state.
                        */
                        source_mesh = snapshotAsMesh source_node


                        if source_mesh == undefined then
                        (
                                deleteModifier source_node edit_modifier
                                messageBox "Unable to read source wall geometry." title:"Wall Thickness"
                                undefined
                        )
                        else
                        (
                                source_vert_count = meshop.getNumVerts source_mesh
                                open_edges = meshop.getOpenEdges source_mesh
                                modifier_source_vert_count = edit_modifier.GetNumVertices node:source_node
                                modifier_source_face_count = edit_modifier.GetNumFaces node:source_node


                                if modifier_source_vert_count != source_vert_count then
                        (
                                deleteModifier source_node edit_modifier
                                free source_mesh
                                messageBox "Source topology changed while creating thickness. WALL THICKNESS was not applied." title:"Wall Thickness"
                                undefined
                        )
                        else
                        (
                                /*
                                Capture evaluated source polygon boundaries before creating generated geometry.
                                One generated polygon is created per source polygon; Max keeps its required triangulation hidden internally.
                                */
                                source_polygon_vertex_ids = #()
                                for face_id = 1 to modifier_source_face_count do
                                (
                                        face_degree = edit_modifier.GetFaceDegree face_id node:source_node
                                        face_vertices = #()


                                        for corner_id = 1 to face_degree do
                                        (
                                                append face_vertices (edit_modifier.GetFaceVertex face_id corner_id node:source_node)
                                        )


                                        append source_polygon_vertex_ids face_vertices
                                )


                                setUserProp source_node wall_thickness_source_vert_count_prop modifier_source_vert_count
                                setUserProp source_node wall_thickness_source_face_count_prop modifier_source_face_count


                                outer_face_ids = #{1..modifier_source_face_count}
                                setEditPolyMaterialID edit_modifier source_node outer_face_ids 1
                                offset_vertex_ids = #()
                                inner_face_ids = #{}
                                strip_face_ids = #{}
                                edit_modifier.SetOperation #Create


                                /*
                                snapshotAsMesh returns world-space vertex positions/normals, while EditPolyMod.CreateVertex expects object-space coordinates.
                                Always solve the thickness offset in world space, then convert the final point back into the current node object space.
                                This keeps EXTRUDE stable on rotated/transformed objects and across repeated UPDATE runs.
                                */
                                inverse_object_tm = inverse source_node.objectTransform


                                for vertex_id = 1 to source_vert_count do
                                (
                                        source_world_position = getVert source_mesh vertex_id
                                        offset_world_vector = getOffsetDisplacement source_mesh vertex_id thickness
                                        offset_world_position = source_world_position + offset_world_vector
                                        offset_local_position = offset_world_position * inverse_object_tm
                                        new_vertex_id = edit_modifier.CreateVertex offset_local_position node:source_node
                                        append offset_vertex_ids new_vertex_id
                                )


                                for face_id = 1 to modifier_source_face_count do
                                (
                                        source_face_vertices = source_polygon_vertex_ids[face_id]
                                        generated_face_vertices = #()


                                        for corner_id = source_face_vertices.count to 1 by -1 do
                                        (
                                                source_vertex_id = source_face_vertices[corner_id]
                                                append generated_face_vertices offset_vertex_ids[source_vertex_id]
                                        )


                                        if generated_face_vertices.count >= 3 then
                                        (
                                                new_face_id = edit_modifier.CreateFace generated_face_vertices node:source_node
                                                if new_face_id != undefined then
                                                (
                                                        inner_face_ids[new_face_id] = true
                                                )
                                        )
                                )


                                for edge_id in open_edges do
                                (
                                        edge_vertices = getMeshEdgeVertices source_mesh edge_id
                                        if edge_vertices != undefined then
                                        (
                                                vertex_a = edge_vertices.x
                                                vertex_b = edge_vertices.y
                                                offset_a = offset_vertex_ids[vertex_a]
                                                offset_b = offset_vertex_ids[vertex_b]
                                                new_face_id = edit_modifier.CreateFace #(vertex_a, vertex_b, offset_b, offset_a) node:source_node
                                                if new_face_id != undefined then
                                                (
                                                        strip_face_ids[new_face_id] = true
                                                )
                                        )
                                )


                                edit_modifier.Commit()
                                setEditPolyMaterialID edit_modifier source_node inner_face_ids 2
                                setEditPolyMaterialID edit_modifier source_node strip_face_ids 3
                                autoSmoothEditPolyResult edit_modifier source_node
                                empty_faces = #{}
                                edit_modifier.SetSelection #Face empty_faces node:source_node
                                edit_modifier.RefreshScreen()
                                free source_mesh
                                completeRedraw()
                                edit_modifier
                        )
                )
                )
        )
        -- return
)


/*
Collects simple open-edge loops made only from generated thickness vertices.
Source-wall boundary vertices are ignored so CLEANUP cannot patch the original wall surface.
*/
function getWallThicknessGeneratedOpenLoops mesh_data source_vert_count =
(
        cleanup_loops = #()
        if mesh_data != undefined then
        (
                vertex_count = meshop.getNumVerts mesh_data
                open_edges = meshop.getOpenEdges mesh_data
                open_edge_ids = open_edges as array
                vertex_edges = for vertex_id = 1 to vertex_count collect #()


                for edge_id in open_edge_ids do
                (
                        edge_vertices = getMeshEdgeVertices mesh_data edge_id
                        if edge_vertices != undefined then
                        (
                                append vertex_edges[edge_vertices.x as integer] edge_id
                                append vertex_edges[edge_vertices.y as integer] edge_id
                        )
                )


                visited_edges = #{}
                max_steps = open_edge_ids.count + 1
                for start_edge in open_edge_ids do
                (
                        if not visited_edges[start_edge] then
                        (
                                start_vertices = getMeshEdgeVertices mesh_data start_edge
                                if start_vertices != undefined then
                                (
                                        start_vertex = start_vertices.x as integer
                                        current_vertex = start_vertices.y as integer
                                        loop_vertices = #(start_vertex, current_vertex)
                                        loop_edges = #(start_edge)
                                        visited_edges[start_edge] = true
                                        valid_loop = true
                                        step_count = 0


                                        while valid_loop and (current_vertex != start_vertex) and (step_count < max_steps) do
                                        (
                                                next_edge = 0
                                                for candidate_edge in vertex_edges[current_vertex] while next_edge == 0 do
                                                (
                                                        if not visited_edges[candidate_edge] then
                                                        (
                                                                next_edge = candidate_edge
                                                        )
                                                )
                                                if next_edge == 0 then
                                                (
                                                        valid_loop = false
                                                )
                                                else
                                                (
                                                        next_vertices = getMeshEdgeVertices mesh_data next_edge
                                                        if next_vertices == undefined then
                                                        (
                                                                valid_loop = false
                                                        )
                                                        else
                                                        (
                                                                if (next_vertices.x as integer) == current_vertex then
                                                                (
                                                                        next_vertex = next_vertices.y as integer
                                                                )
                                                                else
                                                                (
                                                                        next_vertex = next_vertices.x as integer
                                                                )


                                                                append loop_edges next_edge
                                                                append loop_vertices next_vertex
                                                                visited_edges[next_edge] = true
                                                                current_vertex = next_vertex
                                                        )
                                                )
                                                step_count += 1
                                        )


                                        if valid_loop and (current_vertex == start_vertex) and (loop_vertices.count > 3) then
                                        (
                                                deleteItem loop_vertices loop_vertices.count
                                                simple_loop = true
                                                generated_loop = true
                                                for vertex_id in loop_vertices do
                                                (
                                                        if vertex_edges[vertex_id].count != 2 then simple_loop = false
                                                        if vertex_id <= source_vert_count then generated_loop = false
                                                )


                                                if simple_loop and generated_loop then
                                                (
                                                        append cleanup_loops #(loop_vertices, loop_edges)
                                                )
                                        )
                                )
                        )
                )
        )
        cleanup_loops
        -- return
)


/*
Collects every simple closed open-edge loop on the current evaluated wall result.
This is used only after the explicit Cap Holes / zero-weld / duplicate-edge cleanup stage.
*/
function getWallThicknessSimpleOpenLoops mesh_data =
(
        cleanup_loops = #()
        if mesh_data != undefined then
        (
                vertex_count = meshop.getNumVerts mesh_data
                open_edges = meshop.getOpenEdges mesh_data
                open_edge_ids = open_edges as array
                vertex_edges = for vertex_id = 1 to vertex_count collect #()


                for edge_id in open_edge_ids do
                (
                        edge_vertices = getMeshEdgeVertices mesh_data edge_id
                        if edge_vertices != undefined then
                        (
                                append vertex_edges[edge_vertices.x as integer] edge_id
                                append vertex_edges[edge_vertices.y as integer] edge_id
                        )
                )


                visited_edges = #{}
                max_steps = open_edge_ids.count + 1
                for start_edge in open_edge_ids do
                (
                        if not visited_edges[start_edge] then
                        (
                                start_vertices = getMeshEdgeVertices mesh_data start_edge
                                if start_vertices != undefined then
                                (
                                        start_vertex = start_vertices.x as integer
                                        current_vertex = start_vertices.y as integer
                                        loop_vertices = #(start_vertex, current_vertex)
                                        loop_edges = #(start_edge)
                                        visited_edges[start_edge] = true
                                        valid_loop = true
                                        step_count = 0


                                        while valid_loop and (current_vertex != start_vertex) and (step_count < max_steps) do
                                        (
                                                next_edge = 0
                                                for candidate_edge in vertex_edges[current_vertex] while next_edge == 0 do
                                                (
                                                        if not visited_edges[candidate_edge] then
                                                        (
                                                                next_edge = candidate_edge
                                                        )
                                                )


                                                if next_edge == 0 then
                                                (
                                                        valid_loop = false
                                                )
                                                else
                                                (
                                                        next_vertices = getMeshEdgeVertices mesh_data next_edge
                                                        if next_vertices == undefined then
                                                        (
                                                                valid_loop = false
                                                        )
                                                        else
                                                        (
                                                                if (next_vertices.x as integer) == current_vertex then
                                                                (
                                                                        next_vertex = next_vertices.y as integer
                                                                )
                                                                else
                                                                (
                                                                        next_vertex = next_vertices.x as integer
                                                                )


                                                                append loop_edges next_edge
                                                                append loop_vertices next_vertex
                                                                visited_edges[next_edge] = true
                                                                current_vertex = next_vertex
                                                        )
                                                )
                                                step_count += 1
                                        )


                                        if valid_loop and (current_vertex == start_vertex) and (loop_vertices.count > 3) then
                                        (
                                                deleteItem loop_vertices loop_vertices.count
                                                simple_loop = true
                                                for vertex_id in loop_vertices do
                                                (
                                                        if vertex_edges[vertex_id].count != 2 then simple_loop = false
                                                )


                                                if simple_loop then
                                                (
                                                        append cleanup_loops #(loop_vertices, loop_edges)
                                                )
                                        )
                                )
                        )
                )
        )
        cleanup_loops
        -- return
)


/*
Orients one cleanup loop opposite to its existing boundary face.
The new cap then follows normal manifold winding across the shared open edge.
*/
function orientWallThicknessCleanupLoop mesh_data loop_vertices loop_edges =
(
        oriented_vertices = copy loop_vertices
        if (loop_vertices.count > 1) and (loop_edges.count > 0) then
        (
                adjacent_faces = (meshop.getFacesUsingEdge mesh_data #{loop_edges[1]}) as array
                if adjacent_faces.count > 0 then
                (
                        face_vertices = getFace mesh_data adjacent_faces[1]
                        vertex_a = loop_vertices[1]
                        vertex_b = loop_vertices[2]
                        matching_direction = ((face_vertices.x == vertex_a) and (face_vertices.y == vertex_b)) or ((face_vertices.y == vertex_a) and (face_vertices.z == vertex_b)) or ((face_vertices.z == vertex_a) and (face_vertices.x == vertex_b))


                        if matching_direction then
                        (
                                oriented_vertices = reverse oriented_vertices
                        )
                )
        )
        oriented_vertices
        -- return
)


/*
Builds the cleanup as a completely separate Edit Poly above the stable thickness result.
Only generated triangular and quadrilateral open loops are filled; larger or branched gaps are left unchanged.
*/
function buildWallThicknessCleanupModifier source_node result_mesh cleanup_loops =
(
        cleanup_modifier = undefined
        cleanup_face_ids = #{}
        triangle_count = 0
        quad_count = 0
        skipped_count = 0
        build_succeeded = true


        if cleanup_loops.count > 0 then
        (
                cleanup_modifier = Edit_Poly()
                cleanup_modifier.name = wall_thickness_cleanup_modifier_name
                cleanup_modifier.showCage = off
                addModifier source_node cleanup_modifier


                if cleanup_modifier.GetNumVertices node:source_node != meshop.getNumVerts result_mesh then
                (
                        deleteModifier source_node cleanup_modifier
                        cleanup_modifier = undefined
                        build_succeeded = false
                )
                else
                (
                        cleanup_modifier.SetOperation #Create
                        for loop_data in cleanup_loops do
                        (
                                loop_vertices = loop_data[1]
                                loop_edges = loop_data[2]
                                if (loop_vertices.count == 3) or (loop_vertices.count == 4) then
                                (
                                        oriented_vertices = orientWallThicknessCleanupLoop result_mesh loop_vertices loop_edges
                                        new_face_id = cleanup_modifier.CreateFace oriented_vertices node:source_node
                                        if new_face_id != undefined then
                                        (
                                                cleanup_face_ids[new_face_id] = true
                                                if loop_vertices.count == 3 then triangle_count += 1 else quad_count += 1
                                        )
                                        else
                                        (
                                                skipped_count += 1
                                        )
                                )
                                else
                                (
                                        skipped_count += 1
                                )
                        )


                        cleanup_modifier.Commit()
                        if cleanup_face_ids.numberSet > 0 then
                        (
                                setEditPolyMaterialID cleanup_modifier source_node cleanup_face_ids 3
                                autoSmoothWallThicknessGeneratedFaces cleanup_modifier source_node #{} cleanup_face_ids
                                empty_faces = #{}
                                cleanup_modifier.SetSelection #Face empty_faces node:source_node
                                cleanup_modifier.RefreshScreen()
                        )
                        else
                        (
                                deleteModifier source_node cleanup_modifier
                                cleanup_modifier = undefined
                        )
                )
        )


        #(build_succeeded, cleanup_modifier, cleanup_face_ids.numberSet, triangle_count, quad_count, skipped_count)
        -- return
)


/*
Returns evaluated vertex, face, and open-edge counts for no-op cleanup detection.
Undefined is returned when the evaluated mesh cannot be read safely.
*/
function getWallThicknessEvaluatedCounts source_node =
(
        if not isValidNode source_node then
        (
                undefined
        )
        else
        (
                mesh_data = snapshotAsMesh source_node
                if mesh_data == undefined then
                (
                        undefined
                )
                else
                (
                        count_data = #(
                                meshop.getNumVerts mesh_data,
                                meshop.getNumFaces mesh_data,
                                (meshop.getOpenEdges mesh_data).numberSet
                        )
                        free mesh_data
                        count_data
                )
        )
        -- return
)


/*
Returns true when two evaluated topology-count snapshots differ.
An unreadable snapshot is treated as changed so a potentially meaningful modifier is never discarded.
*/
function wallThicknessEvaluatedCountsChanged before_counts after_counts =
(
        if before_counts == undefined or after_counts == undefined then
        (
                true
        )
        else
        (
                (before_counts[1] != after_counts[1]) or
                (before_counts[2] != after_counts[2]) or
                (before_counts[3] != after_counts[3])
        )
        -- return
)


/*
Runs PolyTools Quadrify on its own dedicated Edit Poly stage.
When `generated_inner_only` is true, only material-ID 2 inner/extruded faces are selected so source/outer-wall topology is preserved exactly; material-ID 3 strip faces are already created as quads by EXTRUDE.
*/
function quadrifyWallThicknessModifier source_node modifier_name:wall_thickness_cleanup_quadrify_modifier_name generated_inner_only:false =
(
        quadrify_succeeded = false
        quadrify_changed = false


        if isValidNode source_node and getWallThicknessModifier source_node != undefined then
        (
                removeWallThicknessNamedModifier source_node modifier_name
                quadrify_modifier = Edit_Poly()
                quadrify_modifier.name = modifier_name
                quadrify_modifier.showCage = off
                addModifier source_node quadrify_modifier


                try
                (
                        select source_node
                        max modify mode
                        WallThicknessPreprocess.prepareEditPoly source_node quadrify_modifier selection_level:(if generated_inner_only then #Face else #Object)
                        before_vertices = quadrify_modifier.GetNumVertices node:source_node
                        before_edges = EditPolyMod.GetNumEdges quadrify_modifier node:source_node
                        before_faces = quadrify_modifier.GetNumFaces node:source_node
                        quadrify_face_ids = #{}


                        if generated_inner_only then
                        (
                                for face_id = 1 to before_faces do
                                (
                                        if quadrify_modifier.GetFaceMaterial face_id node:source_node == 2 then
                                        (
                                                quadrify_face_ids[face_id] = true
                                        )
                                )
                                EditPolyMod.SetEPolySelLevel quadrify_modifier #Face
                                EditPolyMod.SetSelection quadrify_modifier #Face quadrify_face_ids node:source_node
                        )


                        modPanel.setCurrentObject quadrify_modifier node:source_node
                        subObjectLevel = if generated_inner_only then 4 else 0


                        if (not generated_inner_only) or quadrify_face_ids.numberSet > 0 then
                        (
                                macros.run "PolyTools" "Quadrify"
                                update source_node
                        )


                        after_vertices = quadrify_modifier.GetNumVertices node:source_node
                        after_edges = EditPolyMod.GetNumEdges quadrify_modifier node:source_node
                        after_faces = quadrify_modifier.GetNumFaces node:source_node
                        quadrify_changed = (before_vertices != after_vertices) or (before_edges != after_edges) or (before_faces != after_faces)


                        if generated_inner_only then
                        (
                                EditPolyMod.SetSelection quadrify_modifier #Face #{} node:source_node
                                EditPolyMod.SetEPolySelLevel quadrify_modifier #Object
                                subObjectLevel = 0
                        )


                        if not quadrify_changed then
                        (
                                deleteModifier source_node quadrify_modifier
                                update source_node
                        )


                        quadrify_succeeded = true
                )
                catch
                (
                        try (subObjectLevel = 0) catch ()
                        removeWallThicknessNamedModifier source_node modifier_name
                        quadrify_succeeded = false
                        quadrify_changed = false
                )
        )


        #(quadrify_succeeded, quadrify_changed)
        -- return
)


/*
Adds separate Cap Holes, zero-threshold Vertex Weld, and Multiple Edge cleanup stages above WALL THICKNESS.
No real scene object is converted or collapsed.
*/
function preProcessWallThicknessGeometryFix source_node =
(
        process_succeeded = false
        multiple_edge_count = 0
        deleted_face_count = 0
        cap_changed = false
        weld_changed = false
        multiple_changed = false


        if isValidNode source_node then
        (
                try
                (
                        removeWallThicknessNamedModifier source_node wall_thickness_cleanup_multiple_modifier_name
                        removeWallThicknessNamedModifier source_node wall_thickness_cleanup_weld_modifier_name
                        removeWallThicknessNamedModifier source_node wall_thickness_cleanup_cap_modifier_name


                        before_cap_counts = getWallThicknessEvaluatedCounts source_node
                        cap_modifier = Cap_Holes()
                        cap_modifier.name = wall_thickness_cleanup_cap_modifier_name
                        addModifier source_node cap_modifier
                        update source_node
                        after_cap_counts = getWallThicknessEvaluatedCounts source_node
                        cap_changed = wallThicknessEvaluatedCountsChanged before_cap_counts after_cap_counts
                        if not cap_changed then
                        (
                                deleteModifier source_node cap_modifier
                                update source_node
                        )


                        before_weld_counts = getWallThicknessEvaluatedCounts source_node
                        weld_modifier = VertexWeld()
                        weld_modifier.name = wall_thickness_cleanup_weld_modifier_name
                        weld_modifier.threshold = 0.0
                        addModifier source_node weld_modifier
                        update source_node
                        after_weld_counts = getWallThicknessEvaluatedCounts source_node
                        weld_changed = wallThicknessEvaluatedCountsChanged before_weld_counts after_weld_counts
                        if not weld_changed then
                        (
                                deleteModifier source_node weld_modifier
                                update source_node
                        )


                        multiple_modifier = Edit_Poly()
                        multiple_modifier.name = wall_thickness_cleanup_multiple_modifier_name
                        multiple_modifier.showCage = off
                        addModifier source_node multiple_modifier
                        if not(WallThicknessPreprocess.prepareEditPoly source_node multiple_modifier selection_level:#Face) then throw "could not evaluate CLEANUP MULTIPLE EDGES"


                        multiple_edge_results = #()
                        MultipleEdges.Check currentTime source_node &multiple_edge_results
                        multiple_edge_count = multiple_edge_results.count


                        if multiple_edge_count > 0 then
                        (
                                edge_bits = multiple_edge_results as bitarray
                                faces_to_delete = polyop.getFacesUsingEdge source_node edge_bits
                                deleted_face_count = faces_to_delete.numberSet


                                if deleted_face_count > 0 then
                                (
                                        WallThicknessPreprocess.selectModifierComponents source_node multiple_modifier #Face faces_to_delete
                                        multiple_modifier.ButtonOp #DeleteFace
                                        update source_node
                                        multiple_changed = true
                                )
                        )


                        if multiple_changed then
                        (
                                WallThicknessPreprocess.selectModifierComponents source_node multiple_modifier #Face #{}
                                multiple_modifier.showCage = off
                                multiple_modifier.RefreshScreen()
                        )
                        else
                        (
                                deleteModifier source_node multiple_modifier
                                update source_node
                        )


                        process_succeeded = true
                )
                catch
                (
                        process_succeeded = false
                )
        )


        #(process_succeeded, multiple_edge_count, deleted_face_count, cap_changed, weld_changed, multiple_changed)
        -- return
)


/*
Adds the tool-owned STL Check modifier with one requested test visible.
The modifier never changes material IDs; it only exposes the error selection.
*/
function addWallThicknessSTLCheck source_node selection_type:3 =
(
        stl_modifier = undefined
        if isValidNode source_node then
        (
                removeWallThicknessSTLCheckModifier source_node
                try
                (
                        stl_modifier = STL_Check()
                        stl_modifier.name = wall_thickness_stl_check_modifier_name
                        addModifier source_node stl_modifier
                        stl_modifier.Selection_Type = selection_type
                        stl_modifier.Select_Faces = 1
                        stl_modifier.Change_MatID = 0
                        stl_modifier.Check_Now = 1
                        update source_node
                )
                catch
                (
                        if stl_modifier != undefined then
                        (
                                try (deleteModifier source_node stl_modifier) catch ()
                        )
                        stl_modifier = undefined
                )
        )
        stl_modifier
        -- return
)


/*
Returns the face count selected by the active STL Check result.
STL Check exposes its status through the generated component selection rather than a MAXScript error-count property.
*/
function getWallThicknessSTLErrorCount source_node =
(
        error_count = -1
        if isValidNode source_node then
        (
                try
                (
                        error_faces = getFaceSelection source_node
                        if error_faces != undefined then error_count = error_faces.numberSet
                )
                catch
                (
                        error_count = -1
                )
        )
        error_count
        -- return
)


/*
Runs Open Edge, Double Face, Spike, and Multiple Edge through one temporary STL Check modifier.
PASS removes the modifier; FAIL keeps it on the first failing test so the error remains visible.
*/
function validateWallThicknessSTL source_node show_messages:true =
(
        if not isValidNode source_node then
        (
                if show_messages then messageBox "Select exactly one wall object." title:"Wall Thickness"
                #(false, "", -1)
        )
        else
        (
                stl_modifier = addWallThicknessSTLCheck source_node selection_type:0
                if stl_modifier == undefined then
                (
                        if show_messages then messageBox "Unable to add STL CHECK." title:"Wall Thickness"
                        #(false, "STL Check unavailable", -1)
                )
                else
                (
                        test_names = #("Open Edge", "Double Face", "Spike", "Multiple Edge")
                        failed_name = ""
                        failed_count = 0
                        read_failed = false


                        for test_index = 0 to 3 while failed_name == "" and not read_failed do
                        (
                                try
                                (
                                        stl_modifier.Check_Now = 0
                                        stl_modifier.Selection_Type = test_index
                                        stl_modifier.Select_Faces = 1
                                        stl_modifier.Change_MatID = 0
                                        stl_modifier.Check_Now = 1
                                        update source_node
                                        completeRedraw()


                                        error_count = getWallThicknessSTLErrorCount source_node
                                        if error_count < 0 then
                                        (
                                                read_failed = true
                                        )
                                        else if error_count > 0 then
                                        (
                                                failed_name = test_names[test_index + 1]
                                                failed_count = error_count
                                        )
                                )
                                catch
                                (
                                        read_failed = true
                                )
                        )


                        if read_failed then
                        (
                                try
                                (
                                        select source_node
                                        max modify mode
                                        modPanel.setCurrentObject stl_modifier
                                )
                                catch
                                (
                                )
                                if show_messages then messageBox "STL CHECK could not read the generated error selection. The modifier was kept for inspection." title:"Wall Thickness"
                                #(false, "Read failure", -1)
                        )
                        else if failed_name != "" then
                        (
                                try
                                (
                                        select source_node
                                        max modify mode
                                        modPanel.setCurrentObject stl_modifier
                                )
                                catch
                                (
                                )
                                completeRedraw()
                                if show_messages then messageBox ("STL CHECK FAILED\n\n" + failed_name + ": " + (failed_count as string) + " selected error faces.\n\nThe STL Check modifier was kept on the failing test.") title:"Wall Thickness"
                                #(false, failed_name, failed_count)
                        )
                        else
                        (
                                removeWallThicknessSTLCheckModifier source_node
                                completeRedraw()
                                if show_messages then messageBox "WALL THICKNESS CHECK PASSED\n\nOpen Edge: PASS\nDouble Face: PASS\nSpike: PASS\nMultiple Edge: PASS" title:"Wall Thickness"
                                #(true, "", 0)
                        )
                )
        )
        -- return
)


/*
Runs only Double Face, Spike, and Multiple Edge before WALL THICKNESS is created.
Open Edge is intentionally skipped because source walls may have valid open borders.
PASS removes STL CHECK; FAIL keeps it on the first failing test and blocks extrusion.
*/
function validateWallThicknessPreExtrudeSTL source_node show_messages:true =
(
        if not isValidNode source_node then
        (
                if show_messages then messageBox "Select exactly one wall object." title:"Wall Thickness"
                #(false, "", -1)
        )
        else
        (
                test_types = #(1, 2, 3)
                test_names = #("Double Face", "Spike", "Multiple Edge")
                stl_modifier = addWallThicknessSTLCheck source_node selection_type:test_types[1]


                if stl_modifier == undefined then
                (
                        if show_messages then messageBox "Unable to add STL CHECK." title:"Wall Thickness"
                        #(false, "STL Check unavailable", -1)
                )
                else
                (
                        failed_name = ""
                        failed_count = 0
                        read_failed = false


                        for test_id = 1 to test_types.count while failed_name == "" and not read_failed do
                        (
                                try
                                (
                                        stl_modifier.Check_Now = 0
                                        stl_modifier.Selection_Type = test_types[test_id]
                                        stl_modifier.Select_Faces = 1
                                        stl_modifier.Change_MatID = 0
                                        stl_modifier.Check_Now = 1
                                        update source_node


                                        error_count = getWallThicknessSTLErrorCount source_node
                                        if error_count < 0 then
                                        (
                                                read_failed = true
                                        )
                                        else if error_count > 0 then
                                        (
                                                failed_name = test_names[test_id]
                                                failed_count = error_count
                                        )
                                )
                                catch
                                (
                                        read_failed = true
                                )
                        )


                        if read_failed then
                        (
                                try
                                (
                                        select source_node
                                        max modify mode
                                        modPanel.setCurrentObject stl_modifier
                                )
                                catch
                                (
                                )


                                if show_messages then messageBox "PRE-EXTRUDE STL CHECK could not read the generated error selection. STL CHECK was kept for inspection." title:"Wall Thickness"
                                #(false, "Read failure", -1)
                        )
                        else if failed_name != "" then
                        (
                                try
                                (
                                        select source_node
                                        max modify mode
                                        modPanel.setCurrentObject stl_modifier
                                )
                                catch
                                (
                                )


                                completeRedraw()
                                if show_messages then messageBox ("WALL THICKNESS was not created.\n\nSTL CHECK failed:\n" + failed_name + ": " + (failed_count as string) + " selected error faces.\n\nSTL CHECK was kept on the failing test.") title:"Wall Thickness"
                                #(false, failed_name, failed_count)
                        )
                        else
                        (
                                removeWallThicknessSTLCheckModifier source_node
                                #(true, "", 0)
                        )
                )
        )
        -- return
)


/*
Runs the separate CLEANUP pass on the evaluated modifier-stack result.
Only simple triangular and quadrilateral open loops are capped in a new WALL THICKNESS CLEANUP modifier.
*/
function postProcessWallThicknessCleanup source_node =
(
        if not isValidNode source_node then
        (
                #(false, 0, 0, 0, 0, -1, -1, 0)
        )
        else
        (
                removeWallThicknessCleanupModifier source_node
                result_mesh = snapshotAsMesh source_node
                if result_mesh == undefined then
                (
                        #(false, 0, 0, 0, 0, -1, -1, 0)
                )
                else
                (
                        open_before = (meshop.getOpenEdges result_mesh).numberSet
                        cleanup_loops = getWallThicknessSimpleOpenLoops result_mesh
                        build_data = undefined
                        build_succeeded = false
                        try
                        (
                                build_data = buildWallThicknessCleanupModifier source_node result_mesh cleanup_loops
                                build_succeeded = build_data[1]
                        )
                        catch
                        (
                                removeWallThicknessCleanupModifier source_node
                                build_data = #(false, undefined, 0, 0, 0, cleanup_loops.count)
                                build_succeeded = false
                        )


                        filled_count = build_data[3]
                        triangle_count = build_data[4]
                        quad_count = build_data[5]
                        skipped_count = build_data[6]
                        open_after = open_before


                        if build_succeeded then
                        (
                                validation_mesh = snapshotAsMesh source_node
                                if validation_mesh != undefined then
                                (
                                        open_after = (meshop.getOpenEdges validation_mesh).numberSet
                                        free validation_mesh
                                )
                        )


                        free result_mesh
                        #(build_succeeded, cleanup_loops.count, filled_count, triangle_count, quad_count, open_before, open_after, skipped_count)
                )
        )
        -- return
)


/*
Removes PRE-PROCESS stages from one numbered step upward.
Earlier completed PREP stages remain in place so each numbered button can be run independently in sequence.
*/
function removeWallThicknessPreprocessFromStep source_node step_number =
(
        if not isValidNode source_node then
        (
                false
        )
        else
        (
                if step_number <= 6 then removeWallThicknessNamedModifier source_node wall_thickness_border_check_modifier_name
                if step_number <= 5 then removeWallThicknessNamedModifier source_node wall_thickness_multiple_edges_modifier_name
                if step_number <= 4 then
                (
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_degenerate_modifier_name
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_deleted_degenerate_modifier_name
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_degenerate_modifier_name
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_deleted_degenerate_modifier_name
                )
                if step_number <= 3 then removeWallThicknessNamedModifier source_node wall_thickness_source_weld_modifier_name
                if step_number <= 2 then
                (
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_remove_generated_modifier_name
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_deleted_generated_modifier_name
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_remove_generated_modifier_name
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_deleted_generated_modifier_name
                )
                true
        )
        -- return
)


/*
Removes PRE-PROCESS stages strictly after one numbered SELECT/RMB stage.
The current SELECT or DELETED modifier is preserved so LMB can reuse it and RMB can consume its stored component selection.
*/
function removeWallThicknessPreprocessAfterStep source_node step_number =
(
        if not isValidNode source_node then
        (
                false
        )
        else
        (
                if step_number < 6 then removeWallThicknessNamedModifier source_node wall_thickness_border_check_modifier_name
                if step_number < 5 then removeWallThicknessNamedModifier source_node wall_thickness_multiple_edges_modifier_name
                if step_number < 4 then
                (
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_degenerate_modifier_name
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_deleted_degenerate_modifier_name
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_degenerate_modifier_name
                        removeAllWallThicknessNamedModifiers source_node wall_thickness_legacy_deleted_degenerate_modifier_name
                )
                if step_number < 3 then removeWallThicknessNamedModifier source_node wall_thickness_source_weld_modifier_name
                true
        )
        -- return
)




/*
Removes generated Wall Thickness/post-process history before one PRE-PROCESS step.
Existing earlier PREP stages are preserved; the selected step and all later PREP stages are rebuilt from the current evaluated source.
*/
function prepareWallThicknessPreprocessStep source_node step_number =
(
        if not isValidNode source_node then
        (
                false
        )
        else
        (
                removeWallThicknessSTLCheckModifier source_node
                removeWallThicknessInnerCornerWeldModifier source_node
                removeWallThicknessInnerCornerFixModifier source_node
                removeWallThicknessTEdgeFixModifier source_node
                removeWallThicknessChamferWeldModifier source_node
                removeWallThicknessChamferFixModifier source_node
                removeWallThicknessLegacyChamferModifiers source_node
                removeWallThicknessNamedModifier source_node wall_thickness_auto_quadrify_modifier_name
                removeWallThicknessCleanupModifier source_node
                removeWallThicknessCleanupStageModifiers source_node
                removeFinishedWallThicknessModifier source_node
                removeWallThicknessModifier source_node
                removeWallThicknessPreprocessFromStep source_node step_number
                true
        )
        -- return
)


/*
Prepares one LMB/RMB SELECT stage without deleting the current SELECT/DELETED history.
Generated Wall Thickness outputs and only later PREP stages are removed.
*/
function prepareWallThicknessPreprocessSelectStep source_node step_number =
(
        if not isValidNode source_node then
        (
                false
        )
        else
        (
                removeWallThicknessSTLCheckModifier source_node
                removeWallThicknessInnerCornerWeldModifier source_node
                removeWallThicknessInnerCornerFixModifier source_node
                removeWallThicknessTEdgeFixModifier source_node
                removeWallThicknessChamferWeldModifier source_node
                removeWallThicknessChamferFixModifier source_node
                removeWallThicknessLegacyChamferModifiers source_node
                removeWallThicknessNamedModifier source_node wall_thickness_auto_quadrify_modifier_name
                removeWallThicknessCleanupModifier source_node
                removeWallThicknessCleanupStageModifiers source_node
                removeFinishedWallThicknessModifier source_node
                removeWallThicknessModifier source_node
                removeWallThicknessPreprocessAfterStep source_node step_number
                true
        )
        -- return
)


/*
Runs exactly one numbered PRE-PROCESS stage and returns #(success, message, modifier).
Multiple-edge findings remain warnings; degenerate faces and degenerate borders remain blocking failures for their own stage.
*/
function runWallThicknessPreprocessStep source_node step_number =
(
        result_data = #(false, "invalid PRE-PROCESS step", undefined)


        if not isValidNode source_node then
        (
                result_data = #(false, "invalid node", undefined)
        )
        else if step_number < 1 or step_number > 6 then
        (
                result_data = #(false, "invalid PRE-PROCESS step", undefined)
        )
        else
        (
                if classOf source_node.baseObject == Editable_Poly then try (source_node.baseObject.showCage = off) catch ()


                if step_number == 2 or step_number == 4 then
                (
                        prepareWallThicknessPreprocessSelectStep source_node step_number
                )
                else
                (
                        prepareWallThicknessPreprocessStep source_node step_number
                )


                if step_number == 1 then
                (
                        xform_data = resetWallThicknessXFormOnce source_node
                        result_data = #(xform_data[1], xform_data[3], undefined, xform_data[2])
                )
                else if step_number == 2 then
                (
                        remove_generated_data = addWallThicknessRemoveGeneratedStage source_node
                        remove_generated_modifier = remove_generated_data[1]
                        if remove_generated_modifier == undefined then
                                result_data = #(false, "could not create SELECT 02 GENERATED FACES stage", undefined)
                        else
                        (
                                candidate_count = remove_generated_data[2]
                                if candidate_count > 0 then subObjectLevel = 4 else subObjectLevel = 0
                                step_message = "generated faces selected: " + (candidate_count as string)
                                if remove_generated_data[3] then step_message += " | exact deletion safety not proven"
                                result_data = #(true, step_message, remove_generated_modifier)
                        )
                )
                else if step_number == 3 then
                (
                        weld_modifier = addWallThicknessSourceWeldStage source_node
                        if weld_modifier == undefined then result_data = #(false, "could not create WELD SOURCE stage", undefined)
                        else
                        (
                                subObjectLevel = 0
                                result_data = #(true, "WELD SOURCE complete", weld_modifier)
                        )
                )
                else if step_number == 4 then
                (
                        degenerate_stage = addWallThicknessDegenerateStage source_node
                        degenerate_modifier = degenerate_stage[1]
                        degenerate_data = degenerate_stage[2]
                        if degenerate_modifier == undefined or degenerate_data == undefined or not degenerate_data[1] then
                                result_data = #(false, "could not create SELECT 04 DEGENERATE FACES stage", degenerate_modifier)
                        else
                        (
                                candidate_count = degenerate_data[3]
                                if candidate_count > 0 then subObjectLevel = 4 else subObjectLevel = 0
                                result_data = #(true, ("degenerate faces selected: " + (candidate_count as string)), degenerate_modifier)
                        )
                )
                else if step_number == 5 then
                (
                        multiple_data = addWallThicknessMultipleEdgesStage source_node
                        multiple_modifier = multiple_data[4]
                        if not multiple_data[1] then result_data = #(false, "Multiple Edges validation failed", multiple_modifier)
                        else
                        (
                                multiple_count = multiple_data[2]
                                if multiple_count > 0 then subObjectLevel = 2 else subObjectLevel = 0
                                step_message = if multiple_count > 0 then ("multiple edges warning: " + (multiple_count as string) + " (ignored)") else "Multiple Edges: 0"
                                result_data = #(true, step_message, multiple_modifier)
                        )
                )
                else if step_number == 6 then
                (
                        border_stage = addWallThicknessBorderCheckStage source_node
                        border_modifier = border_stage[1]
                        border_data = border_stage[2]
                        if border_modifier == undefined or border_data == undefined then
                                result_data = #(false, "could not create CHECK DEGENERATE BORDERS stage", border_modifier)
                        else if not border_data[1] then
                                result_data = #(false, "degenerate border validation failed", border_modifier)
                        else if border_data[2] > 0 then
                        (
                                subObjectLevel = 2
                                result_data = #(false, ("degenerate border edges: " + (border_data[2] as string)), border_modifier)
                        )
                        else
                        (
                                subObjectLevel = 0
                                result_data = #(true, "CHECK DEGENERATE BORDERS complete", border_modifier)
                        )
                )
        )


        result_data
        -- return
)


/*
Runs one numbered PRE-PROCESS button action with its own undo entry.
Success is reported in the Listener; failures keep the stage visible and selected for inspection.
*/
/*
Runs PREP 01 RESET XFORM on every currently selected object in one undo entry.
Each object invalidates later Wall Thickness PREP/result history before Reset XForm is applied.
*/
function preprocessWallThicknessResetXFormSelected selected_nodes =
(
        applied_count = 0
        skipped_count = 0
        failure_count = 0


        undo "Wall Thickness PREP 01 RESET XFORM" on
        (
                for source_node in selected_nodes do
                (
                        step_data = runWallThicknessPreprocessStep source_node 1
                        if step_data != undefined and step_data[1] then
                        (
                                if step_data.count >= 4 and step_data[4] then applied_count += 1
                                else skipped_count += 1
                        )
                        else
                        (
                                failure_count += 1
                        )
                )
        )


        #(failure_count == 0, applied_count, failure_count, skipped_count)
        -- return
)


function preprocessWallThicknessStep source_node step_number =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                false
        )
        else
        (
                step_data = undefined
                undo_name = "Wall Thickness PREP " + (formattedPrint step_number format:"02d")


                undo undo_name on
                (
                        step_data = runWallThicknessPreprocessStep source_node step_number
                )


                if step_data != undefined and step_data[1] then
                (
                        wall_thickness_target = source_node
                        format "Wall Thickness PREP %: PASS | %\n" (formattedPrint step_number format:"02d") step_data[2]
                        true
                )
                else
                (
                        wall_thickness_target = undefined
                        failure_text = if step_data != undefined then step_data[2] else "PRE-PROCESS step failed"
                        messageBox ("PRE-PROCESS " + (formattedPrint step_number format:"02d") + " stopped.\n\n" + failure_text + "\n\nThe stage remains visible in the modifier stack.") title:"Wall Thickness"
                        false
                )
        )
        -- return
)


/*
Runs the RMB fix/delete counterpart for numbered SELECT stages 01 and 03.
RMB consumes only the selection stored by the dedicated SELECT modifier and keeps later PREP stages invalidated.
*/
function preprocessWallThicknessRemoveStep source_node step_number =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                false
        )
        else if step_number != 2 and step_number != 4 then
        (
                false
        )
        else
        (
                result_data = undefined
                undo_name = "Wall Thickness PREP " + (formattedPrint step_number format:"02d") + " RMB"


                undo undo_name on
                (
                        prepareWallThicknessPreprocessSelectStep source_node step_number


                        if step_number == 2 then
                        (
                                result_data = deleteWallThicknessGeneratedSelection source_node
                        )
                        else
                        (
                                result_data = fixWallThicknessSelectedDegenerateFaces source_node
                        )
                )


                if result_data != undefined and result_data[1] then
                (
                        wall_thickness_target = source_node
                        true
                )
                else
                (
                        wall_thickness_target = undefined
                        false
                )
        )
        -- return
)




/*
Runs only the visible source preprocessing history without creating WALL THICKNESS.
Failures remain selected in their PREP modifier so the source can be inspected before extrusion.
*/
function preprocessWallThickness source_node =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                false
        )
        else
        (
                preprocess_data = undefined


                undo "Wall Thickness Preprocess" on
                (
                        preprocess_data = runWallThicknessPreprocess source_node
                )


                if preprocess_data != undefined and preprocess_data[1] then
                (
                        wall_thickness_target = source_node
                        format "Wall Thickness PRE-PROCESS: PASS | %\n" preprocess_data[2]
                        true
                )
                else
                (
                        wall_thickness_target = undefined
                        failure_text = if preprocess_data != undefined then preprocess_data[2] else "preprocessing failed"
                        messageBox ("PRE-PROCESS stopped.\n\n" + failure_text + "\n\nThe preprocessing history remains visible in the modifier stack.") title:"Wall Thickness"
                        false
                )
        )
        -- return
)


/*
Prepares the current source stack for the transplanted v0.08 extrusion builder without inserting any modifier before WALL THICKNESS.
Old Wall Thickness result/post-process history is removed, source counts are stored, and EXTRUDE proceeds directly to the single WALL THICKNESS modifier.
*/
function prepareWallThicknessV008Extrude source_node show_stl_messages:true =
(
        if not isValidNode source_node then
        (
                false
        )
        else
        (
                removeWallThicknessSTLCheckModifier source_node
                removeWallThicknessInnerCornerWeldModifier source_node
                removeWallThicknessInnerCornerFixModifier source_node
                removeWallThicknessTEdgeFixModifier source_node
                removeWallThicknessChamferWeldModifier source_node
                removeWallThicknessChamferFixModifier source_node
                removeWallThicknessLegacyChamferModifiers source_node
                removeWallThicknessNamedModifier source_node wall_thickness_auto_quadrify_modifier_name
                removeWallThicknessCleanupModifier source_node
                removeWallThicknessCleanupStageModifiers source_node
                removeFinishedWallThicknessModifier source_node
                removeWallThicknessModifier source_node


                source_mesh = snapshotAsMesh source_node
                if source_mesh != undefined then
                (
                        setUserProp source_node wall_thickness_source_vert_count_prop (meshop.getNumVerts source_mesh)
                        setUserProp source_node wall_thickness_source_face_count_prop (meshop.getNumFaces source_mesh)
                        free source_mesh
                )


                true
        )
        -- return
)


/*
Creates or rebuilds only the single WALL THICKNESS modifier with the complete v0.08 extrusion builder.
No automatic Quadrify or other persistent post-process modifier is added by EXTRUDE / UPDATE.
*/
function applyWallThickness source_node thickness =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                false
        )
        else if thickness <= 0 then
        (
                messageBox "Thickness must be greater than zero." title:"Wall Thickness"
                false
        )
        else
        (
                apply_succeeded = false
                thickness_modifier = undefined


                undo "Wall Thickness Extrude" on
                (
                        setObjectWallThickness source_node thickness


                        if prepareWallThicknessV008Extrude source_node show_stl_messages:true then
                        (
                                thickness_modifier = buildWallThicknessModifier source_node thickness
                                if thickness_modifier != undefined then
                                (
                                        try (thickness_modifier.showCage = off) catch ()
                                )
                        )


                        apply_succeeded = thickness_modifier != undefined
                )


                if apply_succeeded then
                (
                        wall_thickness_target = source_node
                        format "Wall Thickness EXTRUDE: complete v0.08 builder | single WALL THICKNESS modifier only.\n"
                        true
                )
                else
                (
                        wall_thickness_target = undefined
                        false
                )
        )
        -- return
)


/*
Rebuilds only the active WALL THICKNESS modifier after a spinner change.
Legacy automatic-Quadrify history is removed if present, but no additional modifier is created.
*/
function updateDynamicWallThickness thickness =
(
        if isValidNode wall_thickness_target then
        (
                live_modifier = getWallThicknessModifier wall_thickness_target
                cleanup_modifier = getWallThicknessCleanupModifier wall_thickness_target
                inner_modifier = getWallThicknessInnerCornerFixModifier wall_thickness_target
                outer_modifier = getWallThicknessChamferFixModifier wall_thickness_target


                if live_modifier != undefined and cleanup_modifier == undefined and inner_modifier == undefined and outer_modifier == undefined then
                (
                        saveWallThicknessSetting thickness
                        setObjectWallThickness wall_thickness_target thickness


                        with undo off
                        (
                                removeWallThicknessNamedModifier wall_thickness_target wall_thickness_auto_quadrify_modifier_name
                                updated_modifier = buildWallThicknessModifier wall_thickness_target thickness
                                if updated_modifier != undefined then
                                (
                                        try (updated_modifier.showCage = off) catch ()
                                )
                        )
                )
        )
        true
        -- return
)


/*
Reads the exact evaluated source wall below WALL THICKNESS.
WALL THICKNESS and every modifier above it are disabled only while the source snapshot is taken, then their enabled states are restored.
*/
function getWallThicknessSourceMesh source_node =
(
        if not isValidNode source_node then
        (
                undefined
        )
        else
        (
                preview_modifier = getWallThicknessModifier source_node
                if preview_modifier == undefined then
                (
                        snapshotAsMesh source_node
                )
                else
                (
                        preview_index = 0
                        for modifier_id = 1 to source_node.modifiers.count while preview_index == 0 do
                        (
                                if source_node.modifiers[modifier_id] == preview_modifier then preview_index = modifier_id
                        )


                        if preview_index == 0 then
                        (
                                undefined
                        )
                        else
                        (
                                saved_modifiers = #()
                                saved_enabled_states = #()
                                source_mesh = undefined


                                for modifier_id = 1 to preview_index do
                                (
                                test_modifier = source_node.modifiers[modifier_id]
                                enabled_state = true
                                try (enabled_state = test_modifier.enabled) catch (enabled_state = true)
                                append saved_modifiers test_modifier
                                append saved_enabled_states enabled_state
                                try (test_modifier.enabled = false) catch ()
                                )


                                try
                                (
                                        update source_node
                                        source_mesh = snapshotAsMesh source_node
                                )
                                catch
                                (
                                        source_mesh = undefined
                                )


                                for modifier_id = 1 to saved_modifiers.count do
                                (
                                        try (saved_modifiers[modifier_id].enabled = saved_enabled_states[modifier_id]) catch ()
                                )


                                update source_node
                                source_mesh
                        )
                )
        )
        -- return
)


/*
Reconstructs the generated vertex IDs created by the stable strict face-normal builder.
The mapping mirrors only vertex creation order; it does not modify the live WALL THICKNESS modifier.
*/
function getWallThicknessGeneratedVertexMap source_mesh =
(
        source_vert_count = meshop.getNumVerts source_mesh
        source_face_count = meshop.getNumFaces source_mesh
        vertex_group_normals = for vertex_id = 1 to source_vert_count collect #()
        vertex_group_ids = for vertex_id = 1 to source_vert_count collect #()
        face_offset_vertex_ids = for face_id = 1 to source_face_count collect #()
        face_normals = for face_id = 1 to source_face_count collect undefined
        next_vertex_id = source_vert_count


        for face_id = 1 to source_face_count do
        (
                source_face = getFace source_mesh face_id
                face_normal = getWallThicknessStrictFaceNormal source_mesh face_id
                face_normals[face_id] = face_normal


                if face_normal != undefined then
                (
                        face_vertex_ids = #()
                        for source_vertex_id in #(source_face.x as integer, source_face.y as integer, source_face.z as integer) do
                        (
                                normal_groups = vertex_group_normals[source_vertex_id]
                                id_groups = vertex_group_ids[source_vertex_id]
                                matching_group = 0


                                for group_id = 1 to normal_groups.count while matching_group == 0 do
                                (
                                        if (dot normal_groups[group_id] face_normal) > 0.99999 then
                                        (
                                                matching_group = group_id
                                        )
                                )


                                if matching_group == 0 then
                                (
                                        next_vertex_id += 1
                                        append normal_groups face_normal
                                        append id_groups next_vertex_id
                                        vertex_group_normals[source_vertex_id] = normal_groups
                                        vertex_group_ids[source_vertex_id] = id_groups
                                        append face_vertex_ids next_vertex_id
                                )
                                else
                                (
                                        append face_vertex_ids id_groups[matching_group]
                                )
                        )
                        face_offset_vertex_ids[face_id] = face_vertex_ids
                )
        )


        #(face_offset_vertex_ids, face_normals, next_vertex_id)
        -- return
)


/*
Returns the shared edge direction as it appears in one source face winding.
This makes the signed dihedral test independent of which adjacent face is returned first.
*/
function getWallThicknessDirectedEdgeVector source_mesh face_id vertex_a vertex_b =
(
        edge_direction = undefined
        source_face = getFace source_mesh face_id
        forward_edge = ((source_face.x == vertex_a) and (source_face.y == vertex_b)) or ((source_face.y == vertex_a) and (source_face.z == vertex_b)) or ((source_face.z == vertex_a) and (source_face.x == vertex_b))
        reverse_edge = ((source_face.x == vertex_b) and (source_face.y == vertex_a)) or ((source_face.y == vertex_b) and (source_face.z == vertex_a)) or ((source_face.z == vertex_b) and (source_face.x == vertex_a))


        if forward_edge then
        (
                edge_direction = (getVert source_mesh vertex_b) - (getVert source_mesh vertex_a)
        )
        else if reverse_edge then
        (
                edge_direction = (getVert source_mesh vertex_a) - (getVert source_mesh vertex_b)
        )


        if (edge_direction != undefined) and ((length edge_direction) > 0.000001) then
        (
                normalize edge_direction
        )
        else
        (
                undefined
        )
        -- return
)


/*
Adds one generated vertex target to the convex-corner move table.
Repeated targets for the same generated vertex are averaged so connected corner strips stay stable.
*/
function addWallThicknessChamferTarget target_vertex_ids target_sums target_counts vertex_id target_position =
(
        target_index = findItem target_vertex_ids vertex_id
        if target_index == 0 then
        (
                append target_vertex_ids vertex_id
                append target_sums target_position
                append target_counts 1
        )
        else
        (
                target_sums[target_index] += target_position
                target_counts[target_index] += 1
        )
        true
        -- return
)


/*
Reports whether one cleaned vertex touches outer/source, inner/extruded, and strip material classes.
The flags let FIX CHAMFERS distinguish triangular strip caps from triangulated wall quads.
*/
function getWallThicknessVertexMaterialFlags mesh_data vertex_id =
(
        has_outer = false
        has_inner = false
        has_strip = false
        face_ids = (meshop.getFacesUsingVert mesh_data #{vertex_id}) as array


        for face_id in face_ids do
        (
                material_id = meshop.getFaceMatID mesh_data face_id
                if material_id == 1 then has_outer = true
                if material_id == 2 then has_inner = true
                if material_id == 3 then has_strip = true
        )


        #(has_outer, has_inner, has_strip)
        -- return
)


/*
Returns whether one convex outside corner is safe for sharp miter repair.
The angle between source-face normals must be at most 90 degrees, which is equivalent to a source-wall inner angle of at least 90 degrees.
*/
function canFixWallThicknessChamferAngle source_normal_a source_normal_b =
(
        if source_normal_a == undefined or source_normal_b == undefined then
        (
                false
        )
        else
        (
                normal_dot = dot source_normal_a source_normal_b
                normal_dot >= -0.000001
        )
        -- return
)


/*
Finds the original sharp source edge that produced one cleaned triangular strip cap.
The two source-face normals are matched against the two strict face-normal offset directions.
*/
function getWallThicknessCleanChamferSourceEdge mesh_data source_vertex_id inward_a inward_b =
(
        result_data = undefined
        edge_ids = (meshop.getEdgesUsingVert mesh_data #{source_vertex_id}) as array
        target_normal_a = -inward_a
        target_normal_b = -inward_b


        for edge_id in edge_ids while result_data == undefined do
        (
                edge_vertices = getMeshEdgeVertices mesh_data edge_id
                if edge_vertices != undefined then
                (
                        vertex_a = edge_vertices.x as integer
                        vertex_b = edge_vertices.y as integer
                        other_vertex = if vertex_a == source_vertex_id then vertex_b else if vertex_b == source_vertex_id then vertex_a else 0


                        if other_vertex > 0 then
                        (
                                edge_bits = #{edge_id}
                                edge_bits += meshop.getEdgesReverseEdge mesh_data edge_bits
                                face_ids = (meshop.getFacesUsingEdge mesh_data edge_bits) as array
                                outer_faces = #()


                                for face_id in face_ids do
                                (
                                        if meshop.getFaceMatID mesh_data face_id == 1 then append outer_faces face_id
                                )


                                if outer_faces.count == 2 then
                                (
                                        face_a = outer_faces[1]
                                        face_b = outer_faces[2]
                                        normal_a = getWallThicknessStrictFaceNormal mesh_data face_a
                                        normal_b = getWallThicknessStrictFaceNormal mesh_data face_b


                                        if (normal_a != undefined) and (normal_b != undefined) then
                                        (
                                                match_direct = ((dot normal_a target_normal_a) > 0.995) and ((dot normal_b target_normal_b) > 0.995)
                                                match_swapped = ((dot normal_a target_normal_b) > 0.995) and ((dot normal_b target_normal_a) > 0.995)


                                                if match_swapped then
                                                (
                                                        temp_face = face_a
                                                        face_a = face_b
                                                        face_b = temp_face
                                                        temp_normal = normal_a
                                                        normal_a = normal_b
                                                        normal_b = temp_normal
                                                        match_direct = true
                                                )


                                                if match_direct then
                                                (
                                                        edge_direction = getWallThicknessDirectedEdgeVector mesh_data face_a source_vertex_id other_vertex
                                                        if edge_direction != undefined then
                                                        (
                                                                result_data = #(face_a, face_b, normal_a, normal_b, edge_direction, other_vertex)
                                                        )
                                                )
                                        )
                                )
                        )
                )
        )


        result_data
        -- return
)


/*
Returns the v0.08 miter target for one clean corner endpoint.
The endpoint is accepted only when exactly two unique one-sided horizontal wall normals meet there; any extra plane/branch rejects the corner.
*/
function getWallThicknessV008CleanCornerTarget source_mesh vertex_id source_normal_a source_normal_b thickness =
(
        if source_mesh == undefined or source_normal_a == undefined or source_normal_b == undefined then
        (
                undefined
        )
        else
        (
                face_ids = (meshop.getFacesUsingVert source_mesh #{vertex_id}) as array
                normal_array = getUniqueNormals source_mesh face_ids


                if normal_array.count != 2 then
                (
                        undefined
                )
                else
                (
                        flat_normal_a = [source_normal_a.x, source_normal_a.y, 0]
                        flat_normal_b = [source_normal_b.x, source_normal_b.y, 0]


                        if (length flat_normal_a) <= 0.000001 or (length flat_normal_b) <= 0.000001 then
                        (
                                undefined
                        )
                        else
                        (
                                flat_normal_a = normalize flat_normal_a
                                flat_normal_b = normalize flat_normal_b
                                match_direct = ((abs (dot normal_array[1] flat_normal_a)) > 0.999) and ((abs (dot normal_array[2] flat_normal_b)) > 0.999)
                                match_swapped = ((abs (dot normal_array[1] flat_normal_b)) > 0.999) and ((abs (dot normal_array[2] flat_normal_a)) > 0.999)


                                if not match_direct and not match_swapped then
                                (
                                        undefined
                                )
                                else
                                (
                                        /* This is the stable 0.08 corner construction: one shared inward miter displacement per source vertex. */
                                        offset_vector = getOffsetDisplacement source_mesh vertex_id thickness
                                        if (length offset_vector) <= 0.000001 then
                                        (
                                                undefined
                                        )
                                        else
                                        (
                                                (getVert source_mesh vertex_id) + offset_vector
                                        )
                                )
                        )
                )
        )
        -- return
)


/*
Fixes generated sharp edges from the original source topology instead of searching for material-3 cap triangles.
#inner resolves concave generated-face intersections; #outer removes convex chamfer strips and keeps the existing 90-degree safety gate.
*/
function fixWallThicknessCornerMiters source_node corner_mode =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                #(false, 0, 0)
        )
        else if getWallThicknessModifier source_node == undefined then
        (
                messageBox "Create WALL THICKNESS first." title:"Wall Thickness"
                #(false, 0, 0)
        )
        else
        (
                saved_thickness = getUserProp source_node wall_thickness_user_prop
                if saved_thickness == undefined then
                (
                        messageBox "This object has no WallThickness value. Run EXTRUDE / UPDATE first." title:"Wall Thickness"
                        #(false, 0, 0)
                )
                else
                (
                        is_inner = corner_mode == #inner
                        thickness = getObjectWallThickness source_node
                        had_stl_modifier = getWallThicknessSTLCheckModifier source_node != undefined
                        removeWallThicknessSTLCheckModifier source_node


                        if is_inner then
                        (
                                removeWallThicknessInnerCornerWeldModifier source_node
                                removeWallThicknessInnerCornerFixModifier source_node
                        )
                        else
                        (
                                removeWallThicknessChamferWeldModifier source_node
                                removeWallThicknessChamferFixModifier source_node
                                removeWallThicknessLegacyChamferModifiers source_node
                        )


                        source_mesh = getWallThicknessSourceMesh source_node
                        if source_mesh == undefined then
                        (
                                if had_stl_modifier then addWallThicknessSTLCheck source_node
                                messageBox "Unable to read the source topology below WALL THICKNESS." title:"Wall Thickness"
                                #(false, 0, 0)
                        )
                        else
                        (
                                generated_map = getWallThicknessGeneratedVertexMap source_mesh
                                face_offset_vertex_ids = generated_map[1]
                                face_normals = generated_map[2]
                                source_face_count = meshop.getNumFaces source_mesh
                                source_edge_count = source_face_count * 3
                                processed_edge_keys = #()
                                target_vertex_ids = #()
                                target_sums = #()
                                target_counts = #()
                                sharp_edge_count = 0
                                matched_edge_count = 0


                                for edge_id = 1 to source_edge_count do
                                (
                                        edge_vertices = getMeshEdgeVertices source_mesh edge_id
                                        if edge_vertices != undefined then
                                        (
                                                vertex_a = edge_vertices.x as integer
                                                vertex_b = edge_vertices.y as integer


                                                if vertex_a < vertex_b then
                                                (
                                                        edge_key = (vertex_a as string) + "_" + (vertex_b as string)
                                                )
                                                else
                                                (
                                                        edge_key = (vertex_b as string) + "_" + (vertex_a as string)
                                                )


                                                if (findItem processed_edge_keys edge_key) == 0 then
                                                (
                                                        append processed_edge_keys edge_key
                                                        edge_bits = #{edge_id}
                                                        edge_bits += meshop.getEdgesReverseEdge source_mesh edge_bits
                                                        face_ids = (meshop.getFacesUsingEdge source_mesh edge_bits) as array


                                                        if face_ids.count == 2 then
                                                        (
                                                                face_a = face_ids[1]
                                                                face_b = face_ids[2]
                                                                normal_a = face_normals[face_a]
                                                                normal_b = face_normals[face_b]


                                                                if normal_a != undefined and normal_b != undefined then
                                                                (
                                                                        normal_dot = dot normal_a normal_b
                                                                        if normal_dot < 0.99999 and normal_dot > -0.99999 then
                                                                        (
                                                                                sharp_edge_count += 1
                                                                                edge_direction = getWallThicknessDirectedEdgeVector source_mesh face_a vertex_a vertex_b


                                                                                if edge_direction != undefined then
                                                                                (
                                                                                        signed_corner = dot (cross normal_a normal_b) edge_direction
                                                                                        use_corner = false


                                                                                        /*
                                                                                        Thickness is generated toward -normal.
                                                                                        With the source-face winding, positive signed turns are INNER corners on that thickness side; negative turns are OUTER corners.
                                                                                        */
                                                                                        if is_inner then
                                                                                        (
                                                                                                use_corner = signed_corner > 0.0001
                                                                                        )
                                                                                        else if signed_corner < -0.0001 then
                                                                                        (
                                                                                                use_corner = canFixWallThicknessChamferAngle normal_a normal_b
                                                                                        )


                                                                                        if use_corner then
                                                                                        (
                                                                                                target_a = getWallThicknessV008CleanCornerTarget source_mesh vertex_a normal_a normal_b thickness
                                                                                                target_b = getWallThicknessV008CleanCornerTarget source_mesh vertex_b normal_a normal_b thickness


                                                                                                /*
                                                                                                Only a clean straight corner edge with no third normal/branch at either endpoint is rebuilt.
                                                                                                Both strict-normal copies are moved to the same v0.08 target and the existing zero-threshold weld merges them.
                                                                                                */
                                                                                                if target_a != undefined and target_b != undefined then
                                                                                                (
                                                                                                        generated_a1 = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_a vertex_a
                                                                                                        generated_a2 = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_b vertex_a
                                                                                                        generated_b1 = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_a vertex_b
                                                                                                        generated_b2 = getWallThicknessFaceVertexId source_mesh face_offset_vertex_ids face_b vertex_b


                                                                                                        if generated_a1 > 0 and generated_a2 > 0 and generated_b1 > 0 and generated_b2 > 0 then
                                                                                                        (
                                                                                                                addWallThicknessChamferTarget target_vertex_ids target_sums target_counts generated_a1 target_a
                                                                                                                addWallThicknessChamferTarget target_vertex_ids target_sums target_counts generated_a2 target_a
                                                                                                                addWallThicknessChamferTarget target_vertex_ids target_sums target_counts generated_b1 target_b
                                                                                                                addWallThicknessChamferTarget target_vertex_ids target_sums target_counts generated_b2 target_b
                                                                                                                matched_edge_count += 1
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


                                free source_mesh
                                build_succeeded = true
                                moved_vertex_count = 0


                                if target_vertex_ids.count > 0 then
                                (
                                        fix_modifier = Edit_Poly()
                                        fix_modifier.name = if is_inner then wall_thickness_inner_fix_modifier_name else wall_thickness_chamfer_fix_modifier_name
                                        fix_modifier.showCage = off
                                        addModifier source_node fix_modifier


                                        try
                                        (
                                                select source_node
                                                max modify mode
                                                fix_modifier.SetPrimaryNode source_node
                                                fix_modifier.useStackSelection = false
                                                fix_modifier.selectMode = 0
                                                fix_modifier.showCage = off
                                                EditPolyMod.SetEPolySelLevel fix_modifier #Vertex
                                                modPanel.setCurrentObject fix_modifier node:source_node
                                                subObjectLevel = 1
                                                object_tm = source_node.objectTransform
                                                live_vertex_count = EditPolyMod.GetNumVertices fix_modifier node:source_node


                                                for target_index = 1 to target_vertex_ids.count do
                                                (
                                                        vertex_id = target_vertex_ids[target_index]
                                                        if vertex_id >= 1 and vertex_id <= live_vertex_count then
                                                        (
                                                                target_local_position = target_sums[target_index] / target_counts[target_index]
                                                                current_local_position = EditPolyMod.GetVertex fix_modifier vertex_id node:source_node


                                                                if current_local_position != undefined then
                                                                (
                                                                        current_world_position = current_local_position * object_tm
                                                                        target_world_position = target_local_position * object_tm
                                                                        world_move_delta = target_world_position - current_world_position


                                                                        if (length world_move_delta) > 0.000001 then
                                                                        (
                                                                                one_vertex = #{}
                                                                                one_vertex[vertex_id] = true
                                                                                EditPolyMod.SetSelection fix_modifier #Vertex one_vertex node:source_node
                                                                                EditPolyMod.MoveSelection fix_modifier world_move_delta
                                                                                EditPolyMod.Commit fix_modifier
                                                                                moved_vertex_count += 1
                                                                        )
                                                                )
                                                        )
                                                )


                                                EditPolyMod.SetSelection fix_modifier #Vertex #{} node:source_node
                                                EditPolyMod.SetEPolySelLevel fix_modifier #Object
                                                fix_modifier.RefreshScreen()
                                                subObjectLevel = 0
                                                update source_node


                                                if moved_vertex_count > 0 then
                                                (
                                                        corner_weld_modifier = VertexWeld()
                                                        corner_weld_modifier.name = if is_inner then wall_thickness_inner_weld_modifier_name else wall_thickness_chamfer_weld_modifier_name
                                                        corner_weld_modifier.threshold = 0.0
                                                        addModifier source_node corner_weld_modifier
                                                        update source_node
                                                )
                                                else
                                                (
                                                        deleteModifier source_node fix_modifier
                                                )
                                        )
                                        catch
                                        (
                                                try (subObjectLevel = 0) catch ()
                                                if is_inner then
                                                (
                                                        removeWallThicknessInnerCornerWeldModifier source_node
                                                        removeWallThicknessInnerCornerFixModifier source_node
                                                )
                                                else
                                                (
                                                        removeWallThicknessChamferWeldModifier source_node
                                                        removeWallThicknessChamferFixModifier source_node
                                                )
                                                build_succeeded = false
                                                moved_vertex_count = 0
                                        )
                                )


                                if had_stl_modifier then addWallThicknessSTLCheck source_node
                                completeRedraw()


                                if build_succeeded then
                                (
                                        if is_inner then
                                        (
                                                format "Wall Thickness FIX INNER CORNERS: sharp source edges % | matched inner edges % | moved vertices %.
" sharp_edge_count matched_edge_count moved_vertex_count
                                        )
                                        else
                                        (
                                                format "Wall Thickness FIX OUTER CORNERS: sharp source edges % | matched safe outer edges % | moved vertices %.
" sharp_edge_count matched_edge_count moved_vertex_count
                                        )
                                )


                                #(build_succeeded, matched_edge_count, moved_vertex_count)
                        )
                )
        )
        -- return
)


/*
Fixes convex outer corners by intersecting the offset face planes and removing the generated chamfer.
*/
function fixWallThicknessOuterCorners source_node =
(
        fixWallThicknessCornerMiters source_node #outer
        -- return
)


/*
Compatibility wrapper for the previous FIX CHAMFERS function name.
*/
function fixWallThicknessOuterChamfers source_node =
(
        fixWallThicknessOuterCorners source_node
        -- return
)


/*
Returns the current inward-offset position for every source vertex.
The same displacement solver used by Live Preview is reused by the legacy finished-geometry helper.
*/
function getWallThicknessOffsetPositions source_mesh thickness =
(
        offset_positions = #()
        source_vert_count = meshop.getNumVerts source_mesh
        for vertex_id = 1 to source_vert_count do
        (
                source_position = getVert source_mesh vertex_id
                offset_vector = getOffsetDisplacement source_mesh vertex_id thickness
                append offset_positions (source_position + offset_vector)
        )
        offset_positions
        -- return
)


/*
Returns the root ID of one overlap-collapse group.
Parent arrays keep topology detection independent from scene modifiers.
*/
function getWallThicknessGroupRoot parent_array vertex_id =
(
        root_id = vertex_id
        while parent_array[root_id] != root_id do
        (
                root_id = parent_array[root_id]
        )
        root_id
        -- return
)


/*
Joins two source vertices into one local overlap-collapse group.
Only the corrected generated positions are grouped; source vertices remain untouched.
*/
function joinWallThicknessGroups parent_array vertex_a vertex_b =
(
        root_a = getWallThicknessGroupRoot parent_array vertex_a
        root_b = getWallThicknessGroupRoot parent_array vertex_b
        if root_a != root_b then
        (
                parent_array[root_b] = root_a
        )
        true
        -- return
)


/*
Calculates where one source edge collapses while thickness grows from zero to the requested value.
The same thickness fraction is applied to both endpoints, which is stable for flat orthogonal wall corners.
*/
function getWallThicknessEdgeCollapsePoint source_a offset_a source_b offset_b tolerance =
(
        source_edge = source_b - source_a
        source_length = length source_edge
        if source_length <= tolerance then
        (
                undefined
        )
        else
        (
                source_direction = source_edge / source_length
                move_a = offset_a - source_a
                move_b = offset_b - source_b
                final_projected_length = dot (offset_b - offset_a) source_direction
                projected_change = final_projected_length - source_length


                if (final_projected_length > tolerance) or (projected_change >= -tolerance) then
                (
                        undefined
                )
                else
                (
                        collapse_fraction = source_length / (source_length - final_projected_length)
                        collapse_fraction = amax 0.0 (amin 1.0 collapse_fraction)
                        point_a = source_a + (move_a * collapse_fraction)
                        point_b = source_b + (move_b * collapse_fraction)
                        (point_a + point_b) / 2.0
                )
        )
        -- return
)


/*
Normalizes every collapse-group parent to its final root ID.
The returned root array is later used to create one welded generated vertex per collapsed group.
*/
function getWallThicknessGroupRoots parent_array =
(
        root_array = #()
        for vertex_id = 1 to parent_array.count do
        (
                append root_array (getWallThicknessGroupRoot parent_array vertex_id)
        )
        root_array
        -- return
)


/*
Detects short generated edges that collapse or reverse under the requested inward thickness.
Collapsed source vertices are grouped and receive one shared generated position and one shared generated vertex ID.
*/
function getWallThicknessCorrectedOffsetPositions source_mesh thickness =
(
        if source_mesh == undefined then
        (
                undefined
        )
        else
        (
                source_vert_count = meshop.getNumVerts source_mesh
                offset_positions = getWallThicknessOffsetPositions source_mesh thickness
                parent_array = for vertex_id = 1 to source_vert_count collect vertex_id
                processed_edge_keys = #()
                collision_events = #()
                collision_tolerance = amax 0.0001 ((abs thickness) * 0.0001)
                edge_count = (meshop.getNumFaces source_mesh) * 3


                for edge_id = 1 to edge_count do
                (
                        edge_vertices = getMeshEdgeVertices source_mesh edge_id
                        if edge_vertices != undefined then
                        (
                                vertex_a = edge_vertices.x as integer
                                vertex_b = edge_vertices.y as integer
                                if vertex_a != vertex_b then
                                (
                                        if vertex_a < vertex_b then
                                        (
                                                edge_key = (vertex_a as string) + "_" + (vertex_b as string)
                                        )
                                        else
                                        (
                                                edge_key = (vertex_b as string) + "_" + (vertex_a as string)
                                        )


                                        if (findItem processed_edge_keys edge_key) == 0 then
                                        (
                                                append processed_edge_keys edge_key
                                                source_a = getVert source_mesh vertex_a
                                                source_b = getVert source_mesh vertex_b
                                                offset_a = offset_positions[vertex_a]
                                                offset_b = offset_positions[vertex_b]
                                                source_edge = source_b - source_a
                                                source_length = length source_edge


                                                if source_length > collision_tolerance then
                                                (
                                                        source_direction = source_edge / source_length
                                                        final_projected_length = dot (offset_b - offset_a) source_direction
                                                        if final_projected_length <= collision_tolerance then
                                                        (
                                                                collapse_point = getWallThicknessEdgeCollapsePoint source_a offset_a source_b offset_b collision_tolerance
                                                                if collapse_point != undefined then
                                                                (
                                                                        joinWallThicknessGroups parent_array vertex_a vertex_b
                                                                        append collision_events #(vertex_a, vertex_b, collapse_point)
                                                                )
                                                        )
                                                )
                                        )
                                )
                        )
                )


                group_sums = for vertex_id = 1 to source_vert_count collect [0, 0, 0]
                group_counts = for vertex_id = 1 to source_vert_count collect 0
                for collision_event in collision_events do
                (
                        root_id = getWallThicknessGroupRoot parent_array collision_event[1]
                        group_sums[root_id] += collision_event[3]
                        group_counts[root_id] += 1
                )


                group_roots = getWallThicknessGroupRoots parent_array
                for vertex_id = 1 to source_vert_count do
                (
                        root_id = group_roots[vertex_id]
                        if group_counts[root_id] > 0 then
                        (
                                offset_positions[vertex_id] = group_sums[root_id] / group_counts[root_id]
                        )
                )


                #(offset_positions, collision_events.count, group_roots)
        )
        -- return
)


/*
Returns the XY intersection of two generated border lines while preserving the requested Z level.
Undefined is returned for parallel or numerically unstable lines.
*/
function getWallThicknessLineIntersectionXY point_a point_b point_c point_d z_value tolerance:0.000001 =
(
        direction_a = point_b - point_a
        direction_b = point_d - point_c
        denominator = (direction_a.x * direction_b.y) - (direction_a.y * direction_b.x)


        if (abs denominator) <= tolerance then
        (
                undefined
        )
        else
        (
                delta = point_c - point_a
                line_fraction = ((delta.x * direction_b.y) - (delta.y * direction_b.x)) / denominator
                [point_a.x + (direction_a.x * line_fraction), point_a.y + (direction_a.y * line_fraction), z_value]
        )
        -- return
)




/*
Returns the two current outside connections of one connected collapse component.
Each result item is #(inside_component_vertex, outside_neighbor_vertex).
*/
function getWallThicknessCollapseBoundaryConnections component_vertices border_neighbors =
(
        boundary_connections = #()


        for source_vertex_id in component_vertices do
        (
                for neighbor_id in border_neighbors[source_vertex_id] do
                (
                        if (findItem component_vertices neighbor_id) == 0 then
                        (
                                connection_exists = false
                                for existing_connection in boundary_connections while not connection_exists do
                                (
                                        connection_exists =
                                                (existing_connection[1] == source_vertex_id and existing_connection[2] == neighbor_id)
                                )


                                if not connection_exists then
                                (
                                        append boundary_connections #(source_vertex_id, neighbor_id)
                                )
                        )
                )
        )


        boundary_connections
        -- return
)




/*
Returns the projected length that remains on one boundary edge after its component-side endpoint is moved to the repair target.
A non-positive result means that side would still be collapsed/reversed and must be absorbed into the same repair region.
*/
function getWallThicknessRepairBoundaryLength source_mesh offset_positions connection target_point tolerance =
(
        inside_vertex_id = connection[1]
        outside_vertex_id = connection[2]
        source_inside = getVert source_mesh inside_vertex_id
        source_outside = getVert source_mesh outside_vertex_id
        source_edge = source_inside - source_outside
        source_length = length source_edge


        if source_length <= tolerance then
        (
                -1e30
        )
        else
        (
                source_direction = source_edge / source_length
                dot (target_point - offset_positions[outside_vertex_id]) source_direction
        )
        -- return
)




/*
Expands one collapse component across every raw reversed edge touching a sharp source corner.
This catches the second short side of an inner corner before the boundary-intersection growth pass starts.
*/
function expandWallThicknessCollapseComponentCorners source_mesh component_vertices border_neighbors offset_positions tolerance =
(
        expanded_count = 0
        component_bits = #{}
        scan_id = 1


        for source_vertex_id in component_vertices do
        (
                if source_vertex_id != undefined and source_vertex_id > 0 then
                (
                        component_bits[source_vertex_id] = true
                )
        )


        while scan_id <= component_vertices.count do
        (
                source_vertex_id = component_vertices[scan_id]
                face_ids = (meshop.getFacesUsingVert source_mesh #{source_vertex_id}) as array
                normal_array = getUniqueNormals source_mesh face_ids


                if normal_array.count >= 2 then
                (
                        for neighbor_id in border_neighbors[source_vertex_id] do
                        (
                                if not component_bits[neighbor_id] then
                                (
                                        source_a = getVert source_mesh source_vertex_id
                                        source_b = getVert source_mesh neighbor_id
                                        source_edge = source_b - source_a
                                        source_length = length source_edge


                                        if source_length > tolerance then
                                        (
                                                source_direction = source_edge / source_length
                                                final_projected_length = dot (offset_positions[neighbor_id] - offset_positions[source_vertex_id]) source_direction


                                                if final_projected_length <= tolerance then
                                                (
                                                        append component_vertices neighbor_id
                                                        component_bits[neighbor_id] = true
                                                        expanded_count += 1
                                                )
                                        )
                                )
                        )
                )


                scan_id += 1
        )


        expanded_count
        -- return
)




/*
Returns a deterministic key for one source-vertex group.
The key is used only to prevent duplicate paired collapse regions.
*/
function getWallThicknessVertexGroupKey vertex_ids =
(
        vertex_bits = #{}
        group_key = ""


        for vertex_id in vertex_ids do
        (
                if vertex_id != undefined and vertex_id > 0 then
                (
                        vertex_bits[vertex_id] = true
                )
        )


        for vertex_id in vertex_bits do
        (
                if group_key != "" then group_key += "_"
                group_key += vertex_id as string
        )


        group_key
        -- return
)




/*
Adds matching horizontal repair regions at other Z levels when the same wall-border vertices exist there.
This guarantees that both vertical sides of one inner-corner intersection receive the same XY repair even when only one border side triggered the reversal test.
*/
function addWallThicknessPairedCollapseRegions source_mesh collapse_regions tolerance =
(
        if source_mesh == undefined or collapse_regions.count == 0 then
        (
                #(collapse_regions, 0)
        )
        else
        (
                source_vert_count = meshop.getNumVerts source_mesh
                region_keys = #()
                paired_region_count = 0


                for collapse_region in collapse_regions do
                (
                        append region_keys (getWallThicknessVertexGroupKey collapse_region[1])
                )


                original_region_count = collapse_regions.count


                for region_id = 1 to original_region_count do
                (
                        collapse_region = collapse_regions[region_id]
                        component_vertices = collapse_region[1]
                        target_point = collapse_region[2]


                        if component_vertices.count > 0 then
                        (
                                first_position = getVert source_mesh component_vertices[1]
                                candidate_z_values = #()


                                for test_vertex_id = 1 to source_vert_count do
                                (
                                        test_position = getVert source_mesh test_vertex_id
                                        same_xy =
                                                (abs (test_position.x - first_position.x) <= tolerance) and
                                                (abs (test_position.y - first_position.y) <= tolerance)


                                        if same_xy and (abs (test_position.z - first_position.z) > tolerance) then
                                        (
                                                z_exists = false
                                                for existing_z in candidate_z_values while not z_exists do
                                                (
                                                        z_exists = abs (existing_z - test_position.z) <= tolerance
                                                )


                                                if not z_exists then append candidate_z_values test_position.z
                                        )
                                )


                                for candidate_z in candidate_z_values do
                                (
                                        paired_vertex_ids = #()
                                        pair_complete = true


                                        for source_vertex_id in component_vertices while pair_complete do
                                        (
                                                source_position = getVert source_mesh source_vertex_id
                                                matched_vertex_id = 0


                                                for test_vertex_id = 1 to source_vert_count while matched_vertex_id == 0 do
                                                (
                                                        test_position = getVert source_mesh test_vertex_id
                                                        if
                                                        (
                                                                (abs (test_position.x - source_position.x) <= tolerance) and
                                                                (abs (test_position.y - source_position.y) <= tolerance) and
                                                                (abs (test_position.z - candidate_z) <= tolerance)
                                                        )
                                                        then
                                                        (
                                                                matched_vertex_id = test_vertex_id
                                                        )
                                                )


                                                if matched_vertex_id > 0 then
                                                (
                                                        append paired_vertex_ids matched_vertex_id
                                                )
                                                else
                                                (
                                                        pair_complete = false
                                                )
                                        )


                                        if pair_complete and paired_vertex_ids.count == component_vertices.count then
                                        (
                                                pair_key = getWallThicknessVertexGroupKey paired_vertex_ids
                                                if (findItem region_keys pair_key) == 0 then
                                                (
                                                        append collapse_regions #(paired_vertex_ids, [target_point.x, target_point.y, candidate_z])
                                                        append region_keys pair_key
                                                        paired_region_count += 1
                                                )
                                        )
                                )
                        )
                )


                #(collapse_regions, paired_region_count)
        )
        -- return
)




/*
Builds local collapse regions from reversed/zero-length open-border offset edges.
Each bad chain expands toward BOTH sides until the two remaining boundary segments stay forward after repair.
Matching border geometry at the opposite Z side is also paired to the same XY intersection, so both sides of an inner-corner intersection are fixed.
*/
function getWallThicknessInnerCollapseRegions source_mesh thickness =
(
        if source_mesh == undefined then
        (
                undefined
        )
        else
        (
                source_vert_count = meshop.getNumVerts source_mesh
                offset_positions = getWallThicknessOffsetPositions source_mesh thickness
                border_neighbors = for vertex_id = 1 to source_vert_count collect #()
                bad_edges = #()
                collision_tolerance = amax 0.0001 ((abs thickness) * 0.0001)
                open_edge_ids = (meshop.getOpenEdges source_mesh) as array


                for edge_id in open_edge_ids do
                (
                        edge_vertices = getMeshEdgeVertices source_mesh edge_id
                        if edge_vertices != undefined then
                        (
                                vertex_a = edge_vertices.x as integer
                                vertex_b = edge_vertices.y as integer


                                if vertex_a != vertex_b then
                                (
                                        if (findItem border_neighbors[vertex_a] vertex_b) == 0 then append border_neighbors[vertex_a] vertex_b
                                        if (findItem border_neighbors[vertex_b] vertex_a) == 0 then append border_neighbors[vertex_b] vertex_a


                                        source_a = getVert source_mesh vertex_a
                                        source_b = getVert source_mesh vertex_b
                                        source_edge = source_b - source_a
                                        source_length = length source_edge


                                        if source_length > collision_tolerance then
                                        (
                                                source_direction = source_edge / source_length
                                                offset_a = offset_positions[vertex_a]
                                                offset_b = offset_positions[vertex_b]
                                                final_projected_length = dot (offset_b - offset_a) source_direction


                                                if final_projected_length <= collision_tolerance then
                                                (
                                                        append bad_edges #(vertex_a, vertex_b)
                                                )
                                        )
                                )
                        )
                )


                visited_edges = #{}
                collapse_regions = #()
                unresolved_region_count = 0
                expanded_side_vertex_count = 0


                for bad_edge_id = 1 to bad_edges.count do
                (
                        if not visited_edges[bad_edge_id] then
                        (
                                queue = #(bad_edge_id)
                                component_vertices = #()


                                while queue.count > 0 do
                                (
                                        current_edge_id = queue[queue.count]
                                        deleteItem queue queue.count


                                        if not visited_edges[current_edge_id] then
                                        (
                                                visited_edges[current_edge_id] = true
                                                current_pair = bad_edges[current_edge_id]


                                                if (findItem component_vertices current_pair[1]) == 0 then append component_vertices current_pair[1]
                                                if (findItem component_vertices current_pair[2]) == 0 then append component_vertices current_pair[2]


                                                for test_edge_id = 1 to bad_edges.count do
                                                (
                                                        if not visited_edges[test_edge_id] then
                                                        (
                                                                test_pair = bad_edges[test_edge_id]
                                                                shares_vertex =
                                                                        (test_pair[1] == current_pair[1]) or
                                                                        (test_pair[1] == current_pair[2]) or
                                                                        (test_pair[2] == current_pair[1]) or
                                                                        (test_pair[2] == current_pair[2])


                                                                if shares_vertex then append queue test_edge_id
                                                        )
                                                )
                                        )
                                )


                                corner_expanded_count = expandWallThicknessCollapseComponentCorners source_mesh component_vertices border_neighbors offset_positions collision_tolerance
                                expanded_side_vertex_count += corner_expanded_count


                                region_finished = false
                                region_failed = false
                                growth_pass_count = 0


                                while not region_finished and not region_failed and growth_pass_count < source_vert_count do
                                (
                                        growth_pass_count += 1
                                        boundary_connections = getWallThicknessCollapseBoundaryConnections component_vertices border_neighbors


                                        if boundary_connections.count == 2 then
                                        (
                                                connection_a = boundary_connections[1]
                                                connection_b = boundary_connections[2]
                                                z_min = 1e30
                                                z_max = -1e30
                                                z_sum = 0.0


                                                for source_vertex_id in component_vertices do
                                                (
                                                        current_z = offset_positions[source_vertex_id].z
                                                        z_min = amin z_min current_z
                                                        z_max = amax z_max current_z
                                                        z_sum += current_z
                                                )


                                                if (z_max - z_min) <= collision_tolerance then
                                                (
                                                        target_z = z_sum / component_vertices.count
                                                        target_point = getWallThicknessLineIntersectionXY offset_positions[connection_a[2]] offset_positions[connection_a[1]] offset_positions[connection_b[1]] offset_positions[connection_b[2]] target_z tolerance:collision_tolerance


                                                        if target_point != undefined then
                                                        (
                                                                grow_vertices = #()


                                                                for connection in boundary_connections do
                                                                (
                                                                        remaining_length = getWallThicknessRepairBoundaryLength source_mesh offset_positions connection target_point collision_tolerance
                                                                        if remaining_length <= collision_tolerance then
                                                                        (
                                                                                outside_vertex_id = connection[2]
                                                                                if (findItem component_vertices outside_vertex_id) == 0 and (findItem grow_vertices outside_vertex_id) == 0 then
                                                                                (
                                                                                        append grow_vertices outside_vertex_id
                                                                                )
                                                                        )
                                                                )


                                                                if grow_vertices.count > 0 then
                                                                (
                                                                        for grow_vertex_id in grow_vertices do
                                                                        (
                                                                                append component_vertices grow_vertex_id
                                                                                expanded_side_vertex_count += 1
                                                                        )
                                                                )
                                                                else
                                                                (
                                                                        append collapse_regions #(component_vertices, target_point)
                                                                        region_finished = true
                                                                )
                                                        )
                                                        else
                                                        (
                                                                region_failed = true
                                                        )
                                                )
                                                else
                                                (
                                                        region_failed = true
                                                )
                                        )
                                        else
                                        (
                                                region_failed = true
                                        )
                                )


                                if not region_finished then
                                (
                                        unresolved_region_count += 1
                                )
                        )
                )


                paired_data = addWallThicknessPairedCollapseRegions source_mesh collapse_regions collision_tolerance
                collapse_regions = paired_data[1]
                paired_region_count = paired_data[2]


                #(collapse_regions, bad_edges.count, unresolved_region_count, expanded_side_vertex_count, paired_region_count)
        )
        -- return
)




/*
Returns all live Edit Poly vertex IDs at one local-space position.
The lookup is repeated after every topology change so vertex renumbering cannot stale later operations.
*/
function getWallThicknessLiveVerticesAtPosition edit_modifier source_node target_position tolerance =
(
        matched_vertex_ids = #()


        if edit_modifier != undefined and isValidNode source_node then
        (
                vertex_count = EditPolyMod.GetNumVertices edit_modifier node:source_node
                for vertex_id = 1 to vertex_count do
                (
                        current_position = EditPolyMod.GetVertex edit_modifier vertex_id node:source_node
                        if current_position != undefined and (length (current_position - target_position)) <= tolerance then
                        (
                                append matched_vertex_ids vertex_id
                        )
                )
        )


        matched_vertex_ids
        -- return
)




/*
Returns true when two live vertices share one live polygon.
*/
function wallThicknessLiveVerticesShareFace edit_modifier source_node vertex_a vertex_b =
(
        face_found = false


        if edit_modifier != undefined and isValidNode source_node and vertex_a > 0 and vertex_b > 0 and vertex_a != vertex_b then
        (
                face_count = EditPolyMod.GetNumFaces edit_modifier node:source_node
                for face_id = 1 to face_count while not face_found do
                (
                        face_degree = EditPolyMod.GetFaceDegree edit_modifier face_id node:source_node
                        has_a = false
                        has_b = false


                        for corner_id = 1 to face_degree while not (has_a and has_b) do
                        (
                                face_vertex_id = EditPolyMod.GetFaceVertex edit_modifier face_id corner_id node:source_node
                                if face_vertex_id == vertex_a then has_a = true
                                if face_vertex_id == vertex_b then has_b = true
                        )


                        face_found = has_a and has_b
                )
        )


        face_found
        -- return
)




/*
Returns one live target/residual pair found by local positions on the same polygon.
*/
function getWallThicknessLiveInnerPairAtPositions edit_modifier source_node target_position residual_position tolerance =
(
        matched_pair = undefined
        target_vertex_ids = getWallThicknessLiveVerticesAtPosition edit_modifier source_node target_position tolerance
        residual_vertex_ids = getWallThicknessLiveVerticesAtPosition edit_modifier source_node residual_position tolerance


        for target_vertex_id in target_vertex_ids while matched_pair == undefined do
        (
                for residual_vertex_id in residual_vertex_ids while matched_pair == undefined do
                (
                        if target_vertex_id != residual_vertex_id and wallThicknessLiveVerticesShareFace edit_modifier source_node target_vertex_id residual_vertex_id then
                        (
                                matched_pair = #(target_vertex_id, residual_vertex_id)
                        )
                )
        )


        matched_pair
        -- return
)




/*
Returns one short vertical quad attached to a repaired intersection edge.
The good face on the already-fixed side is rejected because its width is larger than the wall thickness.
*/
function getWallThicknessResidualInnerFaceAtTarget edit_modifier source_node target_position max_distance tolerance =
(
        best_data = undefined
        best_distance = 1e30


        if edit_modifier != undefined and isValidNode source_node then
        (
                face_count = EditPolyMod.GetNumFaces edit_modifier node:source_node


                for face_id = 1 to face_count do
                (
                        if EditPolyMod.GetFaceDegree edit_modifier face_id node:source_node == 4 then
                        (
                                target_positions = #()
                                other_positions = #()


                                for corner_id = 1 to 4 do
                                (
                                        face_vertex_id = EditPolyMod.GetFaceVertex edit_modifier face_id corner_id node:source_node
                                        face_position = EditPolyMod.GetVertex edit_modifier face_vertex_id node:source_node


                                        if face_position != undefined then
                                        (
                                                same_target_xy =
                                                        (abs (face_position.x - target_position.x) <= tolerance) and
                                                        (abs (face_position.y - target_position.y) <= tolerance)


                                                if same_target_xy then
                                                (
                                                        append target_positions face_position
                                                )
                                                else
                                                (
                                                        append other_positions face_position
                                                )
                                        )
                                )


                                if target_positions.count == 2 and other_positions.count == 2 then
                                (
                                        other_same_xy =
                                                (abs (other_positions[1].x - other_positions[2].x) <= tolerance) and
                                                (abs (other_positions[1].y - other_positions[2].y) <= tolerance)


                                        if other_same_xy then
                                        (
                                                dx = other_positions[1].x - target_position.x
                                                dy = other_positions[1].y - target_position.y
                                                face_width = sqrt ((dx * dx) + (dy * dy))
                                                z_pair_matches =
                                                        (
                                                                ((abs (target_positions[1].z - other_positions[1].z) <= tolerance) and (abs (target_positions[2].z - other_positions[2].z) <= tolerance)) or
                                                                ((abs (target_positions[1].z - other_positions[2].z) <= tolerance) and (abs (target_positions[2].z - other_positions[1].z) <= tolerance))
                                                        )


                                                if z_pair_matches and face_width > tolerance and face_width <= max_distance and face_width < best_distance then
                                                (
                                                        best_distance = face_width
                                                        best_data = #(face_id, target_positions, other_positions, face_width)
                                                )
                                        )
                                )
                        )
                )
        )


        best_data
        -- return
)




/*
Moves one residual live vertex onto its repaired intersection vertex and welds the adjacent pair.
The second weld argument is always the disposable residual vertex.
*/
function collapseWallThicknessLiveInnerPair edit_modifier source_node target_position residual_position tolerance =
(
        pair_succeeded = false
        moved_count = 0
        welded_count = 0
        live_pair = getWallThicknessLiveInnerPairAtPositions edit_modifier source_node target_position residual_position tolerance


        if live_pair != undefined then
        (
                target_vertex_id = live_pair[1]
                residual_vertex_id = live_pair[2]
                current_position = EditPolyMod.GetVertex edit_modifier residual_vertex_id node:source_node


                if current_position != undefined then
                (
                        world_delta = (target_position * source_node.objectTransform) - (current_position * source_node.objectTransform)


                        if (length world_delta) > tolerance then
                        (
                                one_vertex = #{}
                                one_vertex[residual_vertex_id] = true
                                EditPolyMod.SetSelection edit_modifier #Vertex one_vertex node:source_node
                                EditPolyMod.MoveSelection edit_modifier world_delta
                                EditPolyMod.Commit edit_modifier
                                moved_count = 1
                        )


                        if wallThicknessLiveVerticesShareFace edit_modifier source_node target_vertex_id residual_vertex_id then
                        (
                                before_vertex_count = EditPolyMod.GetNumVertices edit_modifier node:source_node
                                EditPolyMod.WeldVertices edit_modifier target_vertex_id residual_vertex_id node:source_node
                                EditPolyMod.Commit edit_modifier
                                after_vertex_count = EditPolyMod.GetNumVertices edit_modifier node:source_node


                                if after_vertex_count == (before_vertex_count - 1) then
                                (
                                        pair_succeeded = true
                                        welded_count = 1
                                )
                        )
                )
        )


        #(pair_succeeded, moved_count, welded_count)
        -- return
)




/*
Collapses the short opposite vertical quad left beside every 0.67 intersection.
This operates on live post-weld topology, so it does not depend on source-to-generated vertex IDs after the first half is fixed.
*/
function fixWallThicknessResidualInnerFaces edit_modifier source_node collapse_regions thickness tolerance =
(
        if edit_modifier == undefined or not isValidNode source_node or collapse_regions.count == 0 then
        (
                #(true, 0, 0, 0)
        )
        else
        (
                build_succeeded = true
                collapsed_face_count = 0
                moved_vertex_count = 0
                welded_vertex_count = 0
                processed_targets = #()
                max_distance = (abs thickness) + tolerance


                for collapse_region in collapse_regions while build_succeeded do
                (
                        target_position = collapse_region[2]
                        target_already_processed = false


                        for processed_target in processed_targets while not target_already_processed do
                        (
                                target_already_processed =
                                        (abs (processed_target.x - target_position.x) <= tolerance) and
                                        (abs (processed_target.y - target_position.y) <= tolerance)
                        )


                        if not target_already_processed then
                        (
                                append processed_targets target_position
                                face_data = getWallThicknessResidualInnerFaceAtTarget edit_modifier source_node target_position max_distance tolerance


                                if face_data != undefined then
                                (
                                        target_positions = face_data[2]
                                        residual_positions = face_data[3]
                                        position_pairs = #()


                                        for target_face_position in target_positions do
                                        (
                                                matched_residual_position = undefined
                                                for residual_face_position in residual_positions while matched_residual_position == undefined do
                                                (
                                                        if abs (target_face_position.z - residual_face_position.z) <= tolerance then
                                                        (
                                                                matched_residual_position = residual_face_position
                                                        )
                                                )


                                                if matched_residual_position != undefined then
                                                (
                                                        append position_pairs #(target_face_position, matched_residual_position)
                                                )
                                        )


                                        if position_pairs.count == 2 then
                                        (
                                                for position_pair in position_pairs while build_succeeded do
                                                (
                                                        pair_data = collapseWallThicknessLiveInnerPair edit_modifier source_node position_pair[1] position_pair[2] tolerance
                                                        if pair_data[1] then
                                                        (
                                                                moved_vertex_count += pair_data[2]
                                                                welded_vertex_count += pair_data[3]
                                                        )
                                                        else
                                                        (
                                                                build_succeeded = false
                                                        )
                                                )


                                                if build_succeeded then collapsed_face_count += 1
                                        )
                                        else
                                        (
                                                build_succeeded = false
                                        )
                                )
                        )
                )


                #(build_succeeded, collapsed_face_count, moved_vertex_count, welded_vertex_count)
        )
        -- return
)




/*
Sets generated inner-corner border vertices to exact 100 mm target positions.
Uses the supported Edit Poly vertex-transform API internally without changing the Modify panel or user sub-object level.
*/
function fixWallThicknessInnerCorners source_node =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                #(false, 0, 0)
        )
        else
        (
                thickness_modifier = getWallThicknessModifier source_node


                if thickness_modifier == undefined then
                (
                        messageBox "Create WALL THICKNESS first." title:"Wall Thickness"
                        #(false, 0, 0)
                )
                else
                (
                        removeWallThicknessInnerCornerWeldModifier source_node
                        removeWallThicknessInnerCornerFixModifier source_node


                        minimum_edge_length = units.decodeValue "100mm"
                        tolerance = units.decodeValue "0.01mm"
                        stack_xy_tolerance = units.decodeValue "1mm"
                        protected_source_vertices = #{}
                        moved_vertex_count = 0
                        bad_edge_count = 0
                        border_edges = #()
                        build_succeeded = true
                        candidate_targets = #()
                        planned_generated_ids = #{}
                        planned_targets = #()
                        saved_selection = selection as array
                        saved_sub_object_level = try (subObjectLevel) catch (0)
                        saved_current_object = try (modPanel.getCurrentObject()) catch (undefined)
                        live_vertex_count = 0
                        face_count = 0
                        source_vert_count = 0
                        before_mesh = undefined
                        after_mesh = undefined
                        dump_started = startWallThicknessInnerCornerDump()


                        if dump_started then
                        (
                                logWallThicknessInnerCornerDump #("FIX INNER CORNERS START", wall_thickness_file_version, source_node.name, wall_thickness_inner_dump_file)
                                logWallThicknessInnerCornerDump #("THRESHOLDS", minimum_edge_length, tolerance, stack_xy_tolerance)
                                logWallThicknessInnerCornerDump #("NODE OBJECT TRANSFORM", source_node.objectTransform)
                                logWallThicknessInnerCornerDump #("WALL THICKNESS", getObjectWallThickness source_node)
                        )
                        else
                        (
                                format "FIX INNER CORNERS DUMP ERROR: file logging is unavailable for this run.\n"
                        )


                        try
                        (
                                /*
                                Read the evaluated WALL THICKNESS result before baking it.
                                */
                                select source_node
                                update source_node


                                before_mesh = snapshotAsMesh source_node
                                if before_mesh == undefined then throw "could not snapshot WALL THICKNESS result"

                                live_vertex_count = meshop.getNumVerts before_mesh
                                initial_live_vertex_count = live_vertex_count
                                initial_triangle_count = meshop.getNumFaces before_mesh
                                face_count = thickness_modifier.GetNumFaces node:source_node

                                if live_vertex_count <= 0 then throw "WALL THICKNESS result returned zero live vertices"
                                if face_count <= 0 then throw "WALL THICKNESS modifier returned zero polygon faces"

                                original_vertex_positions = for vertex_id = 1 to live_vertex_count collect (getVert before_mesh vertex_id)

                                stored_source_vert_count = getUserProp source_node wall_thickness_source_vert_count_prop
                                stored_source_face_count = getUserProp source_node wall_thickness_source_face_count_prop
                                source_vert_count = 0
                                source_face_count = 0


                                if stored_source_vert_count != undefined then
                                (
                                        source_vert_count = stored_source_vert_count as integer
                                )


                                if stored_source_face_count != undefined then
                                (
                                        source_face_count = stored_source_face_count as integer
                                )


                                if source_vert_count > 0 and source_vert_count < live_vertex_count then
                                (
                                        source_face_ids = #{}


                                        if source_face_count > 0 and source_face_count <= face_count then
                                        (
                                                source_face_ids = #{1..source_face_count}
                                        )
                                        else
                                        (
                                                for face_id = 1 to face_count do
                                                (
                                                        face_degree = EditPolyMod.GetFaceDegree thickness_modifier face_id node:source_node
                                                        if face_degree >= 3 then
                                                        (
                                                                source_only_face = true
                                                                for corner_id = 1 to face_degree while source_only_face do
                                                                (
                                                                        face_vertex_id = EditPolyMod.GetFaceVertex thickness_modifier face_id corner_id node:source_node
                                                                        if face_vertex_id < 1 or face_vertex_id > source_vert_count then
                                                                        (
                                                                                source_only_face = false
                                                                        )
                                                                )


                                                                if source_only_face then
                                                                (
                                                                        source_face_ids[face_id] = true
                                                                )
                                                        )
                                                )
                                        )


                                        source_face_use_counts = for source_id = 1 to source_vert_count collect 0


                                        for source_face_id in source_face_ids do
                                        (
                                                source_face_degree = EditPolyMod.GetFaceDegree thickness_modifier source_face_id node:source_node


                                                for source_corner_id = 1 to source_face_degree do
                                                (
                                                        source_face_vertex_id = EditPolyMod.GetFaceVertex thickness_modifier source_face_id source_corner_id node:source_node


                                                        if source_face_vertex_id >= 1 and source_face_vertex_id <= source_vert_count then
                                                        (
                                                                source_face_use_counts[source_face_vertex_id] += 1
                                                        )
                                                )
                                        )


                                        edge_count = EditPolyMod.GetNumEdges thickness_modifier node:source_node
                                        border_neighbors = for vertex_id = 1 to source_vert_count collect #()


                                        /*
                                        WALL THICKNESS creates one generated vertex for every source vertex.
                                        Generated vertex IDs therefore map directly as source_id + source_vert_count.
                                        */
                                        for edge_id = 1 to edge_count do
                                        (
                                                source_a = EditPolyMod.GetEdgeVertex thickness_modifier edge_id 1 node:source_node
                                                source_b = EditPolyMod.GetEdgeVertex thickness_modifier edge_id 2 node:source_node


                                                if source_a >= 1 and source_a <= source_vert_count and source_b >= 1 and source_b <= source_vert_count then
                                                (
                                                        adjacent_face_a = 0
                                                        adjacent_face_b = 0
                                                        try (adjacent_face_a = EditPolyMod.GetEdgeFace thickness_modifier edge_id 1 node:source_node) catch ()
                                                        try (adjacent_face_b = EditPolyMod.GetEdgeFace thickness_modifier edge_id 2 node:source_node) catch ()


                                                        source_face_use_count = 0
                                                        if adjacent_face_a > 0 and source_face_ids[adjacent_face_a] then source_face_use_count += 1
                                                        if adjacent_face_b > 0 and source_face_ids[adjacent_face_b] then source_face_use_count += 1


                                                        if source_face_use_count == 1 then
                                                        (
                                                                generated_a = source_a + source_vert_count
                                                                generated_b = source_b + source_vert_count


                                                                if generated_a <= live_vertex_count and generated_b <= live_vertex_count then
                                                                (
                                                                        append border_edges #(source_a, source_b, generated_a, generated_b)
                                                                        if (findItem border_neighbors[source_a] source_b) == 0 then append border_neighbors[source_a] source_b
                                                                        if (findItem border_neighbors[source_b] source_a) == 0 then append border_neighbors[source_b] source_a
                                                                )
                                                        )
                                                )
                                        )


                                        logWallThicknessInnerCornerDump #("SOURCE TOPOLOGY", source_vert_count, source_face_count, live_vertex_count, face_count, border_edges.count, source_face_ids)


                                        for dump_source_id = 1 to source_vert_count do
                                        (
                                                dump_source_position = EditPolyMod.GetVertex thickness_modifier dump_source_id node:source_node
                                                dump_generated_id = dump_source_id + source_vert_count
                                                dump_generated_position = undefined
                                                if dump_generated_id <= live_vertex_count then
                                                (
                                                        dump_generated_position = EditPolyMod.GetVertex thickness_modifier dump_generated_id node:source_node
                                                )
                                                logWallThicknessInnerCornerDump #("SOURCE VERTEX", dump_source_id, dump_source_position, source_face_use_counts[dump_source_id], border_neighbors[dump_source_id], dump_generated_id, dump_generated_position)
                                        )


                                        /*
                                        Protect true wall endings automatically.
                                        Group source vertices by plan XY, then count unique horizontal border-neighbor stacks.
                                        A source XY stack with one or zero plan neighbors is a wall ending and must never move.
                                        */
                                        processed_ending_source_vertices = #{}


                                        for source_id = 1 to source_vert_count do
                                        (
                                                if not processed_ending_source_vertices[source_id] then
                                                (
                                                        source_position = EditPolyMod.GetVertex thickness_modifier source_id node:source_node
                                                        ending_stack_source_ids = #()


                                                        if source_position != undefined then
                                                        (
                                                                for compare_source_id = 1 to source_vert_count do
                                                                (
                                                                        compare_source_position = EditPolyMod.GetVertex thickness_modifier compare_source_id node:source_node


                                                                        if compare_source_position != undefined then
                                                                        (
                                                                                same_source_x = abs (compare_source_position.x - source_position.x) <= stack_xy_tolerance
                                                                                same_source_y = abs (compare_source_position.y - source_position.y) <= stack_xy_tolerance


                                                                                if same_source_x and same_source_y then
                                                                                (
                                                                                        append ending_stack_source_ids compare_source_id
                                                                                )
                                                                        )
                                                                )
                                                        )


                                                        ending_neighbor_positions = #()


                                                        for stack_source_id in ending_stack_source_ids do
                                                        (
                                                                processed_ending_source_vertices[stack_source_id] = true
                                                                stack_source_position = EditPolyMod.GetVertex thickness_modifier stack_source_id node:source_node


                                                                if stack_source_position != undefined then
                                                                (
                                                                        for neighbor_source_id in border_neighbors[stack_source_id] do
                                                                        (
                                                                                neighbor_source_position = EditPolyMod.GetVertex thickness_modifier neighbor_source_id node:source_node


                                                                                if neighbor_source_position != undefined then
                                                                                (
                                                                                        plan_delta = [neighbor_source_position.x - stack_source_position.x, neighbor_source_position.y - stack_source_position.y, 0]


                                                                                        if length plan_delta > tolerance then
                                                                                        (
                                                                                                neighbor_position_exists = false


                                                                                                for known_neighbor_position in ending_neighbor_positions while not neighbor_position_exists do
                                                                                                (
                                                                                                        same_neighbor_x = abs (known_neighbor_position.x - neighbor_source_position.x) <= stack_xy_tolerance
                                                                                                        same_neighbor_y = abs (known_neighbor_position.y - neighbor_source_position.y) <= stack_xy_tolerance


                                                                                                        if same_neighbor_x and same_neighbor_y then
                                                                                                        (
                                                                                                                neighbor_position_exists = true
                                                                                                        )
                                                                                                )


                                                                                                if not neighbor_position_exists then
                                                                                                (
                                                                                                        append ending_neighbor_positions neighbor_source_position
                                                                                                )
                                                                                        )
                                                                                )
                                                                        )
                                                                )
                                                        )


                                                        if ending_stack_source_ids.count > 0 and ending_neighbor_positions.count <= 1 then
                                                        (
                                                                for stack_source_id in ending_stack_source_ids do
                                                                (
                                                                        protected_source_vertices[stack_source_id] = true
                                                                )
                                                        )
                                                )
                                        )


                                        logWallThicknessInnerCornerDump #("PROTECTED SOURCE VERTICES", protected_source_vertices)


                                        /*
                                        A sharp wall-plan corner has two non-vertical source-border neighbors.
                                        End-cap vertices with one horizontal plus one vertical border edge are ignored.
                                        */
                                        sharp_source_vertices = #{}
                                        for vertex_id = 1 to source_vert_count do
                                        (
                                                center_position = EditPolyMod.GetVertex thickness_modifier vertex_id node:source_node
                                                horizontal_neighbors = #()


                                                if center_position != undefined then
                                                (
                                                        for neighbor_id in border_neighbors[vertex_id] do
                                                        (
                                                                neighbor_position = EditPolyMod.GetVertex thickness_modifier neighbor_id node:source_node
                                                                if neighbor_position != undefined then
                                                                (
                                                                        plan_delta = [neighbor_position.x - center_position.x, neighbor_position.y - center_position.y, 0]
                                                                        if length plan_delta > tolerance then
                                                                        (
                                                                                append horizontal_neighbors neighbor_id
                                                                        )
                                                                )
                                                        )
                                                )


                                                if horizontal_neighbors.count == 2 then
                                                (
                                                        neighbor_a_position = EditPolyMod.GetVertex thickness_modifier horizontal_neighbors[1] node:source_node
                                                        neighbor_b_position = EditPolyMod.GetVertex thickness_modifier horizontal_neighbors[2] node:source_node


                                                        direction_a = [neighbor_a_position.x - center_position.x, neighbor_a_position.y - center_position.y, 0]
                                                        direction_b = [neighbor_b_position.x - center_position.x, neighbor_b_position.y - center_position.y, 0]


                                                        if length direction_a > tolerance and length direction_b > tolerance then
                                                        (
                                                                direction_a = normalize direction_a
                                                                direction_b = normalize direction_b
                                                                if (dot direction_a direction_b) > -0.9999 then
                                                                (
                                                                        sharp_source_vertices[vertex_id] = true
                                                                )
                                                        )
                                                )
                                        )


                                        logWallThicknessInnerCornerDump #("SHARP SOURCE VERTICES", sharp_source_vertices)
                                        bad_edges = #()


                                        /*
                                        A repair is valid only when exactly one endpoint belongs to a sharp source-wall corner.
                                        That endpoint is the fixed generated intersection. The opposite generated endpoint is the only vertex allowed to move.
                                        */
                                        for edge_data in border_edges do
                                        (
                                                source_a = edge_data[1]
                                                source_b = edge_data[2]
                                                generated_a = edge_data[3]
                                                generated_b = edge_data[4]
                                                sharp_a = sharp_source_vertices[source_a]
                                                sharp_b = sharp_source_vertices[source_b]


                                                if sharp_a != sharp_b then
                                                (
                                                        if sharp_a then
                                                        (
                                                                anchor_source_id = source_a
                                                                remote_source_id = source_b
                                                                anchor_generated_id = generated_a
                                                                remote_generated_id = generated_b
                                                        )
                                                        else
                                                        (
                                                                anchor_source_id = source_b
                                                                remote_source_id = source_a
                                                                anchor_generated_id = generated_b
                                                                remote_generated_id = generated_a
                                                        )


                                                        anchor_source_position = EditPolyMod.GetVertex thickness_modifier anchor_source_id node:source_node
                                                        remote_source_position = EditPolyMod.GetVertex thickness_modifier remote_source_id node:source_node
                                                        anchor_generated_position = EditPolyMod.GetVertex thickness_modifier anchor_generated_id node:source_node
                                                        remote_generated_position = EditPolyMod.GetVertex thickness_modifier remote_generated_id node:source_node


                                                        if anchor_source_position != undefined and remote_source_position != undefined and anchor_generated_position != undefined and remote_generated_position != undefined then
                                                        (
                                                                source_direction = [remote_source_position.x - anchor_source_position.x, remote_source_position.y - anchor_source_position.y, 0]
                                                                source_length = length source_direction


                                                                if source_length > tolerance then
                                                                (
                                                                        source_direction = source_direction / source_length
                                                                        generated_delta = [remote_generated_position.x - anchor_generated_position.x, remote_generated_position.y - anchor_generated_position.y, 0]
                                                                        generated_projection = dot generated_delta source_direction
                                                                        projected_delta = source_direction * generated_projection
                                                                        cross_track_distance = length (generated_delta - projected_delta)
                                                                        reversed_edge = generated_projection <= tolerance
                                                                        short_edge = generated_projection < (minimum_edge_length - tolerance)
                                                                        crossed_edge = cross_track_distance > tolerance and generated_projection < minimum_edge_length
                                                                        logWallThicknessInnerCornerDump #("BAD EDGE TEST", anchor_source_id, remote_source_id, anchor_generated_id, remote_generated_id, source_length, generated_projection, cross_track_distance, reversed_edge, crossed_edge, short_edge, protected_source_vertices[remote_source_id], ((reversed_edge or crossed_edge or short_edge) and not protected_source_vertices[remote_source_id]))


                                                                        if (reversed_edge or crossed_edge or short_edge) and not protected_source_vertices[remote_source_id] then
                                                                        (
                                                                                append bad_edges #(anchor_source_id, remote_source_id, anchor_generated_id, remote_generated_id)
                                                                        )
                                                                )
                                                        )
                                                )
                                        )


                                        bad_edge_count = bad_edges.count
                                        logWallThicknessInnerCornerDump #("BAD EDGES", bad_edge_count, bad_edges)


                                        object_tm = source_node.objectTransform


                                        /*
                                        Build exact-position candidates first.
                                        T-junction stacks can be reachable from more than one fixed corner,
                                        so candidate resolution happens per source-XY stack instead of first-match wins.
                                        */
                                        for bad_edge_data in bad_edges do
                                        (
                                                anchor_source_id = bad_edge_data[1]
                                                remote_source_id = bad_edge_data[2]
                                                anchor_generated_id = bad_edge_data[3]
                                                remote_generated_id = bad_edge_data[4]

                                                anchor_source_position = EditPolyMod.GetVertex thickness_modifier anchor_source_id node:source_node
                                                remote_source_position = EditPolyMod.GetVertex thickness_modifier remote_source_id node:source_node
                                                fixed_corner_position = EditPolyMod.GetVertex thickness_modifier anchor_generated_id node:source_node
                                                remote_generated_position = EditPolyMod.GetVertex thickness_modifier remote_generated_id node:source_node


                                                if anchor_source_position != undefined and remote_source_position != undefined and fixed_corner_position != undefined and remote_generated_position != undefined then
                                                (
                                                        allow_candidate = true
                                                        remote_stack_source_ids = #()


                                                        for stack_source_id = 1 to source_vert_count do
                                                        (
                                                                stack_source_position = EditPolyMod.GetVertex thickness_modifier stack_source_id node:source_node


                                                                if stack_source_position != undefined then
                                                                (
                                                                        same_source_x = abs (stack_source_position.x - remote_source_position.x) <= stack_xy_tolerance
                                                                        same_source_y = abs (stack_source_position.y - remote_source_position.y) <= stack_xy_tolerance


                                                                        if same_source_x and same_source_y then
                                                                        (
                                                                                append remote_stack_source_ids stack_source_id
                                                                        )
                                                                )
                                                        )


                                                        logWallThicknessInnerCornerDump #("CANDIDATE REMOTE STACK", anchor_source_id, remote_source_id, remote_stack_source_ids)


                                                        /*
                                                        Preserve the lower half of a two-vertex vertical opening stack.
                                                        Its upper member may continue the wall while the lower member terminates at the junction.
                                                        */
                                                        if remote_stack_source_ids.count == 2 then
                                                        (
                                                                stack_source_a = remote_stack_source_ids[1]
                                                                stack_source_b = remote_stack_source_ids[2]
                                                                stack_position_a = EditPolyMod.GetVertex thickness_modifier stack_source_a node:source_node
                                                                stack_position_b = EditPolyMod.GetVertex thickness_modifier stack_source_b node:source_node
                                                                vertical_stack_edge = (findItem border_neighbors[stack_source_a] stack_source_b) > 0


                                                                if vertical_stack_edge and stack_position_a != undefined and stack_position_b != undefined then
                                                                (
                                                                        lower_stack_source_id = if stack_position_a.z < stack_position_b.z then stack_source_a else stack_source_b


                                                                        if remote_source_id == lower_stack_source_id then
                                                                        (
                                                                                allow_candidate = false
                                                                                logWallThicknessInnerCornerDump #("CANDIDATE REJECT LOWER TWO STACK", anchor_source_id, remote_source_id, remote_stack_source_ids, lower_stack_source_id)
                                                                        )
                                                                )
                                                        )


                                                        if allow_candidate then
                                                        (
                                                                source_direction = [remote_source_position.x - anchor_source_position.x, remote_source_position.y - anchor_source_position.y, 0]
                                                                source_length = length source_direction


                                                                if source_length > tolerance then
                                                                (
                                                                        source_direction = source_direction / source_length
                                                                        target_xy_position = fixed_corner_position + (source_direction * minimum_edge_length)
                                                                        target_local_position = [target_xy_position.x, target_xy_position.y, remote_generated_position.z]
                                                                        candidate_move_distance = distance remote_generated_position target_local_position


                                                                        append candidate_targets #(
                                                                                anchor_source_id,
                                                                                remote_source_id,
                                                                                anchor_generated_id,
                                                                                remote_generated_id,
                                                                                target_xy_position,
                                                                                candidate_move_distance,
                                                                                fixed_corner_position
                                                                        )
                                                                        logWallThicknessInnerCornerDump #("CANDIDATE TARGET", anchor_source_id, remote_source_id, anchor_generated_id, remote_generated_id, target_xy_position, candidate_move_distance, fixed_corner_position)
                                                                )
                                                        )
                                                )
                                        )


                                        logWallThicknessInnerCornerDump #("CANDIDATE TARGETS", candidate_targets)


                                        /*
                                        Resolve every remote source-XY stack once.
                                        When several corners propose targets for the same stack, keep the target
                                        that requires the smallest move from the current generated position.
                                        */
                                        resolved_source_vertices = #{}


                                        for candidate_id = 1 to candidate_targets.count do
                                        (
                                                candidate_data = candidate_targets[candidate_id]
                                                candidate_remote_source_id = candidate_data[2]


                                                if not resolved_source_vertices[candidate_remote_source_id] then
                                                (
                                                        candidate_remote_source_position = EditPolyMod.GetVertex thickness_modifier candidate_remote_source_id node:source_node
                                                        best_candidate_data = undefined
                                                        best_candidate_move_distance = 1.0e30
                                                        matching_source_ids = #()


                                                        if candidate_remote_source_position != undefined then
                                                        (
                                                                for stack_source_id = 1 to source_vert_count do
                                                                (
                                                                        stack_source_position = EditPolyMod.GetVertex thickness_modifier stack_source_id node:source_node


                                                                        if stack_source_position != undefined then
                                                                        (
                                                                                same_source_x = abs (stack_source_position.x - candidate_remote_source_position.x) <= stack_xy_tolerance
                                                                                same_source_y = abs (stack_source_position.y - candidate_remote_source_position.y) <= stack_xy_tolerance


                                                                                if same_source_x and same_source_y then
                                                                                (
                                                                                        append matching_source_ids stack_source_id
                                                                                        resolved_source_vertices[stack_source_id] = true
                                                                                )
                                                                        )
                                                                )


                                                                for compare_candidate_data in candidate_targets do
                                                                (
                                                                        compare_remote_source_id = compare_candidate_data[2]
                                                                        compare_remote_source_position = EditPolyMod.GetVertex thickness_modifier compare_remote_source_id node:source_node


                                                                        if compare_remote_source_position != undefined then
                                                                        (
                                                                                same_candidate_x = abs (compare_remote_source_position.x - candidate_remote_source_position.x) <= stack_xy_tolerance
                                                                                same_candidate_y = abs (compare_remote_source_position.y - candidate_remote_source_position.y) <= stack_xy_tolerance


                                                                                if same_candidate_x and same_candidate_y and compare_candidate_data[6] < best_candidate_move_distance then
                                                                                (
                                                                                        best_candidate_move_distance = compare_candidate_data[6]
                                                                                        best_candidate_data = compare_candidate_data
                                                                                )
                                                                        )
                                                                )


                                                                if best_candidate_data != undefined then
                                                                (
                                                                        anchor_source_id = best_candidate_data[1]
                                                                        remote_source_id = best_candidate_data[2]
                                                                        anchor_generated_id = best_candidate_data[3]
                                                                        target_xy_position = best_candidate_data[5]
                                                                        fixed_corner_position = best_candidate_data[7]


                                                                        for stack_source_id in matching_source_ids do
                                                                        (
                                                                                stack_generated_id = stack_source_id + source_vert_count


                                                                                if stack_generated_id <= live_vertex_count and not planned_generated_ids[stack_generated_id] then
                                                                                (
                                                                                        stack_generated_position = EditPolyMod.GetVertex thickness_modifier stack_generated_id node:source_node


                                                                                        if stack_generated_position != undefined then
                                                                                        (
                                                                                                target_local_position = [target_xy_position.x, target_xy_position.y, stack_generated_position.z]


                                                                                                if distance stack_generated_position target_local_position > tolerance then
                                                                                                (
                                                                                                        planned_generated_ids[stack_generated_id] = true
                                                                                                        append planned_targets #(stack_generated_id, target_local_position, stack_generated_position, anchor_generated_id, fixed_corner_position)
                                                                                                        format "FIX INNER CORNERS PLAN STACK V%: % -> % | anchor source V% | remote source stack V%\n" stack_generated_id stack_generated_position target_local_position anchor_source_id remote_source_id
                                                                                                        logWallThicknessInnerCornerDump #("PLAN STACK", stack_generated_id, stack_generated_position, target_local_position, anchor_source_id, remote_source_id, anchor_generated_id, fixed_corner_position)
                                                                                                )
                                                                                        )
                                                                                )
                                                                        )
                                                                )
                                                        )
                                                )
                                        )


                                        logWallThicknessInnerCornerDump #("PLANNED TARGETS AFTER CANDIDATE RESOLUTION", planned_targets)


                                        /*
                                        Only near-vertical source edges may use the vertical-stack compatibility alignment.
                                        Real horizontal near-loop corner repairs must keep their exact 100 mm planned targets;
                                        otherwise this alignment would overwrite the actual FIX INNER CORNERS repair.
                                        */
                                        vertical_stack_alignment_sources = #{}


                                        for candidate_data in candidate_targets do
                                        (
                                                candidate_anchor_source_id = candidate_data[1]
                                                candidate_remote_source_id = candidate_data[2]
                                                candidate_anchor_source_position = EditPolyMod.GetVertex thickness_modifier candidate_anchor_source_id node:source_node
                                                candidate_remote_source_position = EditPolyMod.GetVertex thickness_modifier candidate_remote_source_id node:source_node


                                                if candidate_anchor_source_position != undefined and candidate_remote_source_position != undefined then
                                                (
                                                        candidate_source_plan_delta = [candidate_remote_source_position.x - candidate_anchor_source_position.x, candidate_remote_source_position.y - candidate_anchor_source_position.y, 0]


                                                        if length candidate_source_plan_delta <= stack_xy_tolerance then
                                                        (
                                                                vertical_stack_alignment_sources[candidate_anchor_source_id] = true
                                                                vertical_stack_alignment_sources[candidate_remote_source_id] = true
                                                        )
                                                )
                                        )


                                        processed_vertical_stack_sources = #{}


                                        for source_id = 1 to source_vert_count do
                                        (
                                                if not processed_vertical_stack_sources[source_id] then
                                                (
                                                        source_position = EditPolyMod.GetVertex thickness_modifier source_id node:source_node
                                                        vertical_stack_source_ids = #()


                                                        if source_position != undefined then
                                                        (
                                                                for compare_source_id = 1 to source_vert_count do
                                                                (
                                                                        compare_source_position = EditPolyMod.GetVertex thickness_modifier compare_source_id node:source_node


                                                                        if compare_source_position != undefined then
                                                                        (
                                                                                same_source_x = abs (compare_source_position.x - source_position.x) <= stack_xy_tolerance
                                                                                same_source_y = abs (compare_source_position.y - source_position.y) <= stack_xy_tolerance


                                                                                if same_source_x and same_source_y then
                                                                                (
                                                                                        append vertical_stack_source_ids compare_source_id
                                                                                        processed_vertical_stack_sources[compare_source_id] = true
                                                                                )
                                                                        )
                                                                )
                                                        )


                                                        align_vertical_stack = false
                                                        for stack_source_id in vertical_stack_source_ids while not align_vertical_stack do
                                                        (
                                                                if vertical_stack_alignment_sources[stack_source_id] then
                                                                (
                                                                        align_vertical_stack = true
                                                                )
                                                        )


                                                        logWallThicknessInnerCornerDump #("VERTICAL STACK GROUP", source_id, vertical_stack_source_ids, align_vertical_stack)


                                                        /*
                                                        Exact 3+ member vertical T stacks must not depend on tiny XY drift to enter candidate resolution.
                                                        Continuing source members establish the generated corner XY; only terminal one-face members are aligned to it, preserving Z.
                                                        */
                                                        if vertical_stack_source_ids.count >= 3 then
                                                        (
                                                                exact_vertical_stack = true
                                                                stack_reference_source_position = EditPolyMod.GetVertex thickness_modifier vertical_stack_source_ids[1] node:source_node
                                                                continuing_stack_source_ids = #()
                                                                terminal_stack_source_ids = #()


                                                                if stack_reference_source_position == undefined then
                                                                (
                                                                        exact_vertical_stack = false
                                                                )
                                                                else
                                                                (
                                                                        for stack_source_id in vertical_stack_source_ids do
                                                                        (
                                                                                stack_member_source_position = EditPolyMod.GetVertex thickness_modifier stack_source_id node:source_node


                                                                                if stack_member_source_position == undefined then
                                                                                (
                                                                                        exact_vertical_stack = false
                                                                                )
                                                                                else
                                                                                (
                                                                                        stack_source_plan_delta = [stack_member_source_position.x - stack_reference_source_position.x, stack_member_source_position.y - stack_reference_source_position.y, 0]
                                                                                        if length stack_source_plan_delta > tolerance then exact_vertical_stack = false


                                                                                        if source_face_use_counts[stack_source_id] >= 2 then
                                                                                        (
                                                                                                append continuing_stack_source_ids stack_source_id
                                                                                        )
                                                                                        else if source_face_use_counts[stack_source_id] == 1 then
                                                                                        (
                                                                                                append terminal_stack_source_ids stack_source_id
                                                                                        )
                                                                                )
                                                                        )
                                                                )


                                                                topology_stack_repair = exact_vertical_stack and continuing_stack_source_ids.count >= 2 and terminal_stack_source_ids.count > 0
                                                                topology_stack_anchor_source_id = 0
                                                                topology_stack_anchor_source_position = undefined
                                                                topology_stack_anchor_generated_id = 0
                                                                topology_stack_anchor_generated_position = undefined
                                                                topology_stack_anchor_agreement = true


                                                                if topology_stack_repair then
                                                                (
                                                                        topology_stack_anchor_source_id = continuing_stack_source_ids[1]
                                                                        topology_stack_anchor_source_position = EditPolyMod.GetVertex thickness_modifier topology_stack_anchor_source_id node:source_node


                                                                        for continuing_source_id in continuing_stack_source_ids do
                                                                        (
                                                                                continuing_source_position = EditPolyMod.GetVertex thickness_modifier continuing_source_id node:source_node


                                                                                if continuing_source_position != undefined and topology_stack_anchor_source_position != undefined and continuing_source_position.z > topology_stack_anchor_source_position.z then
                                                                                (
                                                                                        topology_stack_anchor_source_id = continuing_source_id
                                                                                        topology_stack_anchor_source_position = continuing_source_position
                                                                                )
                                                                        )


                                                                        topology_stack_anchor_generated_id = topology_stack_anchor_source_id + source_vert_count
                                                                        if topology_stack_anchor_generated_id <= live_vertex_count then
                                                                        (
                                                                                topology_stack_anchor_generated_position = EditPolyMod.GetVertex thickness_modifier topology_stack_anchor_generated_id node:source_node
                                                                        )
                                                                        else
                                                                        (
                                                                                topology_stack_repair = false
                                                                        )


                                                                        if topology_stack_anchor_generated_position == undefined then
                                                                        (
                                                                                topology_stack_repair = false
                                                                        )
                                                                )


                                                                if topology_stack_repair then
                                                                (
                                                                        for continuing_source_id in continuing_stack_source_ids while topology_stack_anchor_agreement do
                                                                        (
                                                                                continuing_generated_id = continuing_source_id + source_vert_count
                                                                                continuing_generated_position = undefined
                                                                                if continuing_generated_id <= live_vertex_count then
                                                                                (
                                                                                        continuing_generated_position = EditPolyMod.GetVertex thickness_modifier continuing_generated_id node:source_node
                                                                                )


                                                                                if continuing_generated_position == undefined then
                                                                                (
                                                                                        topology_stack_anchor_agreement = false
                                                                                )
                                                                                else
                                                                                (
                                                                                        continuing_generated_plan_delta = [continuing_generated_position.x - topology_stack_anchor_generated_position.x, continuing_generated_position.y - topology_stack_anchor_generated_position.y, 0]
                                                                                        if length continuing_generated_plan_delta > stack_xy_tolerance then topology_stack_anchor_agreement = false
                                                                                )
                                                                        )


                                                                        if not topology_stack_anchor_agreement then topology_stack_repair = false
                                                                )


                                                                logWallThicknessInnerCornerDump #("EXACT T STACK TEST", vertical_stack_source_ids, exact_vertical_stack, continuing_stack_source_ids, terminal_stack_source_ids, topology_stack_anchor_source_id, topology_stack_anchor_generated_id, topology_stack_anchor_agreement, topology_stack_repair)


                                                                if topology_stack_repair then
                                                                (
                                                                        topology_stack_anchor_final_position = topology_stack_anchor_generated_position


                                                                        for target_data in planned_targets do
                                                                        (
                                                                                if target_data[1] == topology_stack_anchor_generated_id then
                                                                                (
                                                                                        topology_stack_anchor_final_position = target_data[2]
                                                                                )
                                                                        )


                                                                        for terminal_source_id in terminal_stack_source_ids do
                                                                        (
                                                                                terminal_generated_id = terminal_source_id + source_vert_count


                                                                                if terminal_generated_id <= live_vertex_count and not planned_generated_ids[terminal_generated_id] then
                                                                                (
                                                                                        terminal_generated_position = EditPolyMod.GetVertex thickness_modifier terminal_generated_id node:source_node


                                                                                        if terminal_generated_position != undefined then
                                                                                        (
                                                                                                terminal_target_position = [topology_stack_anchor_final_position.x, topology_stack_anchor_final_position.y, terminal_generated_position.z]


                                                                                                if distance terminal_generated_position terminal_target_position > tolerance then
                                                                                                (
                                                                                                        planned_generated_ids[terminal_generated_id] = true
                                                                                                        append planned_targets #(terminal_generated_id, terminal_target_position, terminal_generated_position, topology_stack_anchor_generated_id, topology_stack_anchor_final_position)
                                                                                                        format "FIX INNER CORNERS ALIGN EXACT T STACK V%: % -> % | fixed continuing V%\n" terminal_generated_id terminal_generated_position terminal_target_position topology_stack_anchor_generated_id
                                                                                                        logWallThicknessInnerCornerDump #("ALIGN EXACT T STACK", terminal_source_id, terminal_generated_id, terminal_generated_position, terminal_target_position, topology_stack_anchor_source_id, topology_stack_anchor_generated_id)
                                                                                                )
                                                                                        )
                                                                                )
                                                                        )
                                                                )
                                                        )


                                                        /*
                                                        A two-member vertical T stack can have one generated member already at the correct corner miter while the other remains on the raw face offset.
                                                        When the upper source member belongs to multiple source faces and the lower member belongs to only one, propagate the upper generated XY to the lower member and preserve both Z values.
                                                        */
                                                        if vertical_stack_source_ids.count == 2 then
                                                        (
                                                                stack_source_a = vertical_stack_source_ids[1]
                                                                stack_source_b = vertical_stack_source_ids[2]
                                                                stack_position_a = EditPolyMod.GetVertex thickness_modifier stack_source_a node:source_node
                                                                stack_position_b = EditPolyMod.GetVertex thickness_modifier stack_source_b node:source_node
                                                                vertical_stack_edge = (findItem border_neighbors[stack_source_a] stack_source_b) > 0
                                                                logWallThicknessInnerCornerDump #("T STACK PAIR", stack_source_a, stack_source_b, stack_position_a, stack_position_b, vertical_stack_edge, border_neighbors[stack_source_a], border_neighbors[stack_source_b])


                                                                if vertical_stack_edge and stack_position_a != undefined and stack_position_b != undefined then
                                                                (
                                                                        stack_anchor_source_id = if stack_position_a.z > stack_position_b.z then stack_source_a else stack_source_b
                                                                        stack_other_source_id = if stack_anchor_source_id == stack_source_a then stack_source_b else stack_source_a
                                                                        anchor_source_face_count = source_face_use_counts[stack_anchor_source_id]
                                                                        other_source_face_count = source_face_use_counts[stack_other_source_id]
                                                                        logWallThicknessInnerCornerDump #("T STACK FACE COUNTS", stack_anchor_source_id, anchor_source_face_count, stack_other_source_id, other_source_face_count)


                                                                        if anchor_source_face_count >= 2 and other_source_face_count == 1 then
                                                                        (
                                                                                stack_anchor_generated_id = stack_anchor_source_id + source_vert_count
                                                                                stack_other_generated_id = stack_other_source_id + source_vert_count


                                                                                if stack_anchor_generated_id <= live_vertex_count and stack_other_generated_id <= live_vertex_count then
                                                                                (
                                                                                        stack_anchor_generated_position = EditPolyMod.GetVertex thickness_modifier stack_anchor_generated_id node:source_node
                                                                                        stack_other_generated_position = EditPolyMod.GetVertex thickness_modifier stack_other_generated_id node:source_node
                                                                                        logWallThicknessInnerCornerDump #("T STACK GENERATED", stack_anchor_generated_id, stack_anchor_generated_position, stack_other_generated_id, stack_other_generated_position, planned_generated_ids[stack_other_generated_id])


                                                                                        if stack_anchor_generated_position != undefined and stack_other_generated_position != undefined and not planned_generated_ids[stack_other_generated_id] then
                                                                                        (
                                                                                                stack_anchor_final_position = stack_anchor_generated_position


                                                                                                for target_data in planned_targets do
                                                                                                (
                                                                                                        if target_data[1] == stack_anchor_generated_id then
                                                                                                        (
                                                                                                                stack_anchor_final_position = target_data[2]
                                                                                                        )
                                                                                                )


                                                                                                stack_target_position = [stack_anchor_final_position.x, stack_anchor_final_position.y, stack_other_generated_position.z]
                                                                                                logWallThicknessInnerCornerDump #("T STACK TARGET", stack_anchor_source_id, stack_other_source_id, stack_anchor_generated_id, stack_other_generated_id, stack_anchor_final_position, stack_target_position, (distance stack_other_generated_position stack_target_position))


                                                                                                if distance stack_other_generated_position stack_target_position > tolerance then
                                                                                                (
                                                                                                        planned_generated_ids[stack_other_generated_id] = true
                                                                                                        append planned_targets #(stack_other_generated_id, stack_target_position, stack_other_generated_position, stack_anchor_generated_id, stack_anchor_final_position)
                                                                                                        format "FIX INNER CORNERS ALIGN T STACK V%: % -> % | fixed upper V%\n" stack_other_generated_id stack_other_generated_position stack_target_position stack_anchor_generated_id
                                                                                                        logWallThicknessInnerCornerDump #("ALIGN T STACK", stack_other_generated_id, stack_other_generated_position, stack_target_position, stack_anchor_generated_id)
                                                                                                )
                                                                                                else
                                                                                                (
                                                                                                        logWallThicknessInnerCornerDump #("T STACK NO MOVE", stack_other_generated_id, stack_other_generated_position, stack_target_position, tolerance)
                                                                                                )
                                                                                        )
                                                                                )
                                                                        )
                                                                        else
                                                                        (
                                                                                logWallThicknessInnerCornerDump #("T STACK REJECT FACE COUNTS", stack_anchor_source_id, anchor_source_face_count, stack_other_source_id, other_source_face_count)
                                                                        )
                                                                )
                                                                else
                                                                (
                                                                        logWallThicknessInnerCornerDump #("T STACK REJECT EDGE OR POSITION", stack_source_a, stack_source_b, vertical_stack_edge, stack_position_a, stack_position_b)
                                                                )
                                                        )


                                                        if vertical_stack_source_ids.count >= 3 and align_vertical_stack then
                                                        (
                                                                stack_anchor_source_id = vertical_stack_source_ids[1]
                                                                stack_anchor_source_position = EditPolyMod.GetVertex thickness_modifier stack_anchor_source_id node:source_node


                                                                for stack_source_id in vertical_stack_source_ids do
                                                                (
                                                                        stack_source_position = EditPolyMod.GetVertex thickness_modifier stack_source_id node:source_node


                                                                        if stack_source_position != undefined and stack_anchor_source_position != undefined and stack_source_position.z > stack_anchor_source_position.z then
                                                                        (
                                                                                stack_anchor_source_id = stack_source_id
                                                                                stack_anchor_source_position = stack_source_position
                                                                        )
                                                                )


                                                                stack_anchor_generated_id = stack_anchor_source_id + source_vert_count


                                                                if stack_anchor_generated_id <= live_vertex_count then
                                                                (
                                                                        stack_anchor_generated_position = EditPolyMod.GetVertex thickness_modifier stack_anchor_generated_id node:source_node


                                                                        if stack_anchor_generated_position != undefined then
                                                                        (
                                                                                if planned_generated_ids[stack_anchor_generated_id] then
                                                                                (
                                                                                        for target_id = planned_targets.count to 1 by -1 do
                                                                                        (
                                                                                                if planned_targets[target_id][1] == stack_anchor_generated_id then
                                                                                                (
                                                                                                        deleteItem planned_targets target_id
                                                                                                )
                                                                                        )
                                                                                        planned_generated_ids[stack_anchor_generated_id] = false
                                                                                )


                                                                                for stack_source_id in vertical_stack_source_ids do
                                                                                (
                                                                                        stack_generated_id = stack_source_id + source_vert_count


                                                                                        if stack_generated_id <= live_vertex_count and stack_generated_id != stack_anchor_generated_id then
                                                                                        (
                                                                                                stack_generated_position = EditPolyMod.GetVertex thickness_modifier stack_generated_id node:source_node


                                                                                                if stack_generated_position != undefined then
                                                                                                (
                                                                                                        stack_target_position = [stack_anchor_generated_position.x, stack_anchor_generated_position.y, stack_generated_position.z]


                                                                                                        if distance stack_generated_position stack_target_position > tolerance then
                                                                                                        (
                                                                                                                target_overridden = false


                                                                                                                for target_id = 1 to planned_targets.count while not target_overridden do
                                                                                                                (
                                                                                                                        if planned_targets[target_id][1] == stack_generated_id then
                                                                                                                        (
                                                                                                                                planned_targets[target_id][2] = stack_target_position
                                                                                                                                planned_targets[target_id][4] = stack_anchor_generated_id
                                                                                                                                planned_targets[target_id][5] = stack_anchor_generated_position
                                                                                                                                target_overridden = true
                                                                                                                        )
                                                                                                                )


                                                                                                                if not target_overridden then
                                                                                                                (
                                                                                                                        planned_generated_ids[stack_generated_id] = true
                                                                                                                        append planned_targets #(stack_generated_id, stack_target_position, stack_generated_position, stack_anchor_generated_id, stack_anchor_generated_position)
                                                                                                                )


                                                                                                                format "FIX INNER CORNERS ALIGN STACK V%: % -> % | fixed top V%\n" stack_generated_id stack_generated_position stack_target_position stack_anchor_generated_id
                                                                                                                logWallThicknessInnerCornerDump #("ALIGN STACK", stack_generated_id, stack_generated_position, stack_target_position, stack_anchor_generated_id)
                                                                                                        )
                                                                                                )
                                                                                        )
                                                                                )
                                                                        )
                                                                )
                                                        )
                                                )
                                        )


                                        logWallThicknessInnerCornerDump #("PLANNED TARGETS FINAL", planned_targets)


                                        if planned_targets.count > 0 then
                                        (
                                                /*
                                                Direct absolute assignment:
                                                bake evaluated WALL THICKNESS result to Editable Poly,
                                                then set only planned generated vertices.
                                                */
                                                logWallThicknessInnerCornerDump #("BAKE START", planned_targets.count, classOf source_node.baseObject)
                                                convertToPoly source_node
                                                update source_node
                                                logWallThicknessInnerCornerDump #("BAKE COMPLETE", classOf source_node.baseObject)


                                                if classOf source_node.baseObject != Editable_Poly then
                                                (
                                                        build_succeeded = false
                                                        throw "could not bake WALL THICKNESS result to Editable Poly"
                                                )


                                                for target_data in planned_targets while build_succeeded do
                                                (
                                                        remote_generated_id = target_data[1]
                                                        target_local_position = target_data[2]
                                                        one_vertex = #{}
                                                        one_vertex[remote_generated_id] = true


                                                        polyop.setVert source_node one_vertex target_local_position
                                                        update source_node


                                                        actual_local_position = polyop.getVert source_node remote_generated_id
                                                        if distance actual_local_position target_local_position <= tolerance then
                                                        (
                                                                format "FIX INNER CORNERS SET V%: %\n" remote_generated_id actual_local_position
                                                                logWallThicknessInnerCornerDump #("SET", remote_generated_id, target_local_position, actual_local_position, true)
                                                        )
                                                        else
                                                        (
                                                                build_succeeded = false
                                                                format "FIX INNER CORNERS SET FAILED V%: target % | actual %\n" remote_generated_id target_local_position actual_local_position
                                                                logWallThicknessInnerCornerDump #("SET", remote_generated_id, target_local_position, actual_local_position, false)
                                                        )
                                                )
                                        )


                                        /*
                                        Do not normalize unrelated generated stacks.
                                        Only vertices explicitly planned from bad local corner edges are allowed to move.
                                        */


                                        after_mesh = snapshotAsMesh source_node

                                        if after_mesh == undefined then
                                        (
                                                build_succeeded = false
                                                format "FIX INNER CORNERS VERIFY FAILED: could not snapshot result.\n"
                                                logWallThicknessInnerCornerDump #("VERIFY SNAPSHOT FAILED")
                                        )
                                        else
                                        (
                                                final_vertex_count = meshop.getNumVerts after_mesh
                                                final_triangle_count = meshop.getNumFaces after_mesh


                                                if final_vertex_count != initial_live_vertex_count or final_triangle_count != initial_triangle_count then
                                                (
                                                        build_succeeded = false
                                                        format "FIX INNER CORNERS TOPOLOGY CHANGED: verts % -> % | triangles % -> %\n" initial_live_vertex_count final_vertex_count initial_triangle_count final_triangle_count
                                                        logWallThicknessInnerCornerDump #("TOPOLOGY CHANGED", initial_live_vertex_count, final_vertex_count, initial_triangle_count, final_triangle_count)
                                                )


                                                if build_succeeded then
                                                (
                                                        for target_data in planned_targets while build_succeeded do
                                                        (
                                                                remote_generated_id = target_data[1]
                                                                target_local_position = target_data[2]
                                                                original_local_position = target_data[3]
                                                                anchor_generated_id = target_data[4]
                                                                fixed_corner_position = target_data[5]
                                                                actual_local_position = getVert after_mesh remote_generated_id
                                                                actual_fixed_corner_position = getVert after_mesh anchor_generated_id
                                                                expected_fixed_corner_position = fixed_corner_position


                                                                for anchor_target_data in planned_targets do
                                                                (
                                                                        if anchor_target_data[1] == anchor_generated_id then
                                                                        (
                                                                                expected_fixed_corner_position = anchor_target_data[2]
                                                                        )
                                                                )


                                                                target_matches = distance actual_local_position target_local_position <= tolerance
                                                                position_changed = distance actual_local_position original_local_position > tolerance
                                                                corner_matches_plan = distance actual_fixed_corner_position expected_fixed_corner_position <= tolerance


                                                                if target_matches and position_changed and corner_matches_plan then
                                                                (
                                                                        moved_vertex_count += 1
                                                                        format "FIX INNER CORNERS SET V%: %\n" remote_generated_id actual_local_position
                                                                        logWallThicknessInnerCornerDump #("VERIFY TARGET", remote_generated_id, target_local_position, actual_local_position, original_local_position, anchor_generated_id, expected_fixed_corner_position, actual_fixed_corner_position, target_matches, position_changed, corner_matches_plan)
                                                                )
                                                                else
                                                                (
                                                                        build_succeeded = false
                                                                        format "FIX INNER CORNERS SET FAILED V%: target % | actual % | changed:% | corner matches plan:%\n" remote_generated_id target_local_position actual_local_position position_changed corner_matches_plan
                                                                        logWallThicknessInnerCornerDump #("VERIFY TARGET FAILED", remote_generated_id, target_local_position, actual_local_position, original_local_position, anchor_generated_id, expected_fixed_corner_position, actual_fixed_corner_position, target_matches, position_changed, corner_matches_plan)
                                                                )
                                                        )
                                                )


                                                if build_succeeded then
                                                (
                                                        for vertex_id = 1 to final_vertex_count while build_succeeded do
                                                        (
                                                                if not planned_generated_ids[vertex_id] then
                                                                (
                                                                        actual_position = getVert after_mesh vertex_id

                                                                        if distance actual_position original_vertex_positions[vertex_id] > tolerance then
                                                                        (
                                                                                build_succeeded = false
                                                                                format "FIX INNER CORNERS UNEXPECTED VERTEX CHANGE V%: % -> %\n" vertex_id original_vertex_positions[vertex_id] actual_position
                                                                                logWallThicknessInnerCornerDump #("UNEXPECTED VERTEX CHANGE", vertex_id, original_vertex_positions[vertex_id], actual_position)
                                                                        )
                                                                )
                                                        )
                                                )
                                        )


                                        if bad_edge_count > 0 and planned_targets.count == 0 then
                                        (
                                                build_succeeded = false
                                                logWallThicknessInnerCornerDump #("FAILED NO PLANNED TARGETS", bad_edge_count, candidate_targets)
                                        )
                                )
                                else
                                (
                                        build_succeeded = false
                                )


                                update source_node
                                if before_mesh != undefined then free before_mesh
                                if after_mesh != undefined then free after_mesh
                        )
                        catch
                        (
                                build_succeeded = false
                                try (if before_mesh != undefined then free before_mesh) catch ()
                                try (if after_mesh != undefined then free after_mesh) catch ()
                                exception_text = getCurrentException()
                                format "Wall Thickness FIX INNER CORNERS ERROR: %\n" exception_text
                                logWallThicknessInnerCornerDump #("ERROR", exception_text)
                        )


                        try
                        (
                                if saved_selection.count > 0 then select saved_selection else clearSelection()
                                try
                                (
                                        if saved_current_object != undefined then modPanel.setCurrentObject saved_current_object
                                )
                                catch ()
                                subObjectLevel = saved_sub_object_level
                        )
                        catch ()


                        completeRedraw()
                        format "Wall Thickness FIX INNER CORNERS %: source verts % | live verts % | mapped source border edges % | bad edges % | positions actually set % .\n" wall_thickness_file_version source_vert_count live_vertex_count border_edges.count bad_edge_count moved_vertex_count
                        logWallThicknessInnerCornerDump #("FIX INNER CORNERS SUMMARY", wall_thickness_file_version, build_succeeded, source_vert_count, live_vertex_count, border_edges.count, bad_edge_count, moved_vertex_count)
                        if dump_started then format "FIX INNER CORNERS DUMP FILE: %\n" wall_thickness_inner_dump_file
                        #(build_succeeded, bad_edge_count, moved_vertex_count)
                )
        )
        -- return
)




/*
Returns one ordered local-space polygon normal from the exact live Edit Poly topology.
No world axis is used.
*/
function getWallThicknessTEdgeFaceNormal edit_modifier source_node face_id =
(
        face_normal = [0,0,0]
        if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return face_normal
        if not isValidNode source_node then return face_normal

        face_count = EditPolyMod.GetNumFaces edit_modifier node:source_node
        if face_id < 1 or face_id > face_count then return face_normal

        face_degree = EditPolyMod.GetFaceDegree edit_modifier face_id node:source_node
        if face_degree < 3 then return face_normal

        origin_vertex_id = EditPolyMod.GetFaceVertex edit_modifier face_id 1 node:source_node
        origin_position = EditPolyMod.GetVertex edit_modifier origin_vertex_id node:source_node
        if origin_position == undefined then return face_normal

        for corner_id = 2 to (face_degree - 1) do
        (
                vertex_b_id = EditPolyMod.GetFaceVertex edit_modifier face_id corner_id node:source_node
                vertex_c_id = EditPolyMod.GetFaceVertex edit_modifier face_id (corner_id + 1) node:source_node
                position_b = EditPolyMod.GetVertex edit_modifier vertex_b_id node:source_node
                position_c = EditPolyMod.GetVertex edit_modifier vertex_c_id node:source_node

                if position_b != undefined and position_c != undefined then
                (
                        face_normal += cross (position_b - origin_position) (position_c - origin_position)
                )
        )

        if (length face_normal) > 0.000001 then face_normal = normalize face_normal
        face_normal
        -- return
)


/*
Returns local polygon area for material-majority decisions after the T-edge weld.
*/
function getWallThicknessTEdgeFaceArea edit_modifier source_node face_id =
(
        face_area = 0.0
        if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return face_area
        if not isValidNode source_node then return face_area

        face_degree = EditPolyMod.GetFaceDegree edit_modifier face_id node:source_node
        if face_degree < 3 then return face_area

        origin_vertex_id = EditPolyMod.GetFaceVertex edit_modifier face_id 1 node:source_node
        origin_position = EditPolyMod.GetVertex edit_modifier origin_vertex_id node:source_node
        if origin_position == undefined then return face_area

        area_vector = [0,0,0]
        for corner_id = 2 to (face_degree - 1) do
        (
                vertex_b_id = EditPolyMod.GetFaceVertex edit_modifier face_id corner_id node:source_node
                vertex_c_id = EditPolyMod.GetFaceVertex edit_modifier face_id (corner_id + 1) node:source_node
                position_b = EditPolyMod.GetVertex edit_modifier vertex_b_id node:source_node
                position_c = EditPolyMod.GetVertex edit_modifier vertex_c_id node:source_node

                if position_b != undefined and position_c != undefined then
                (
                        area_vector += cross (position_b - origin_position) (position_c - origin_position)
                )
        )

        0.5 * (length area_vector)
        -- return
)


/*
Finds one unordered vertex-pair record in an array built from polygon boundaries.
*/
function findWallThicknessTEdgeRecord edge_records vertex_a vertex_b =
(
        result_index = 0
        low_id = if vertex_a < vertex_b then vertex_a else vertex_b
        high_id = if vertex_a > vertex_b then vertex_a else vertex_b

        for record_id = 1 to edge_records.count while result_index == 0 do
        (
                edge_record = edge_records[record_id]
                if edge_record[1] == low_id and edge_record[2] == high_id then result_index = record_id
        )

        result_index
        -- return
)


/*
Builds unordered polygon-boundary edge records #(lowVertex, highVertex, faceIds).
Hidden TriMesh diagonals never enter this table.
*/
function buildWallThicknessTEdgeRecords edit_modifier source_node face_ids =
(
        edge_records = #()

        for face_id in face_ids do
        (
                face_degree = EditPolyMod.GetFaceDegree edit_modifier face_id node:source_node
                if face_degree >= 3 then
                (
                        face_vertices = #()
                        for corner_id = 1 to face_degree do
                        (
                                append face_vertices (EditPolyMod.GetFaceVertex edit_modifier face_id corner_id node:source_node)
                        )

                        for corner_id = 1 to face_degree do
                        (
                                next_corner_id = if corner_id == face_degree then 1 else corner_id + 1
                                vertex_a = face_vertices[corner_id]
                                vertex_b = face_vertices[next_corner_id]
                                low_id = if vertex_a < vertex_b then vertex_a else vertex_b
                                high_id = if vertex_a > vertex_b then vertex_a else vertex_b
                                record_index = findWallThicknessTEdgeRecord edge_records low_id high_id

                                if record_index == 0 then
                                (
                                        append edge_records #(low_id, high_id, #(face_id))
                                )
                                else
                                (
                                        edge_record = edge_records[record_index]
                                        record_faces = edge_record[3]
                                        if (findItem record_faces face_id) == 0 then append record_faces face_id
                                        edge_record[3] = record_faces
                                        edge_records[record_index] = edge_record
                                )
                        )
                )
        )

        edge_records
        -- return
)


/*
Returns the opposite vertex of one unordered edge record.
*/
function getWallThicknessTEdgeRecordOtherVertex edge_record vertex_id =
(
        other_vertex_id = 0
        if edge_record[1] == vertex_id then other_vertex_id = edge_record[2]
        else if edge_record[2] == vertex_id then other_vertex_id = edge_record[1]
        other_vertex_id
        -- return
)


/*
Returns unique local source-surface region IDs touching one source edge.
*/
function getWallThicknessTEdgeRecordRegions edge_record face_region_ids =
(
        region_ids = #()
        for face_id in edge_record[3] do
        (
                if face_id >= 1 and face_id <= face_region_ids.count then
                (
                        region_id = face_region_ids[face_id]
                        if region_id > 0 and (findItem region_ids region_id) == 0 then append region_ids region_id
                )
        )
        region_ids
        -- return
)


/*
Groups the preserved source polygons into connected locally coplanar wall-surface regions.
Only relative neighboring face normals are compared.
*/
function getWallThicknessTEdgeSourceRegions edit_modifier source_node source_face_count source_edge_records coplanar_dot_limit =
(
        face_region_ids = for face_id = 1 to source_face_count collect 0
        face_normals = for face_id = 1 to source_face_count collect (getWallThicknessTEdgeFaceNormal edit_modifier source_node face_id)
        next_region_id = 0

        for seed_face_id = 1 to source_face_count do
        (
                if face_region_ids[seed_face_id] == 0 then
                (
                        next_region_id += 1
                        face_region_ids[seed_face_id] = next_region_id
                        face_queue = #(seed_face_id)

                        while face_queue.count > 0 do
                        (
                                current_face_id = face_queue[1]
                                deleteItem face_queue 1
                                current_normal = face_normals[current_face_id]

                                for edge_record in source_edge_records do
                                (
                                        if (findItem edge_record[3] current_face_id) > 0 then
                                        (
                                                for neighbor_face_id in edge_record[3] do
                                                (
                                                        if neighbor_face_id != current_face_id and face_region_ids[neighbor_face_id] == 0 then
                                                        (
                                                                neighbor_normal = face_normals[neighbor_face_id]
                                                                if (length current_normal) > 0.000001 and (length neighbor_normal) > 0.000001 then
                                                                (
                                                                        if (abs (dot current_normal neighbor_normal)) >= coplanar_dot_limit then
                                                                        (
                                                                                face_region_ids[neighbor_face_id] = next_region_id
                                                                                append face_queue neighbor_face_id
                                                                        )
                                                                )
                                                        )
                                                )
                                        )
                                )
                        )
                )
        )

        face_region_ids
        -- return
)


/*
Detects local partial-height T-edge source anchors from polygon topology.
Each result is #(anchorSource, branchNeighbor, cornerNeighbor, continuationNeighbor, continuingRegion, terminatingRegion, continuingPlanNeighbor, anchorFraction).
*/
function detectWallThicknessTEdgeCases edit_modifier source_node source_vert_count source_face_count wall_thickness =
(
        detected_cases = #()
        if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return detected_cases
        if source_vert_count < 1 or source_face_count < 1 then return detected_cases

        live_vertex_count = EditPolyMod.GetNumVertices edit_modifier node:source_node
        live_face_count = EditPolyMod.GetNumFaces edit_modifier node:source_node
        if source_vert_count >= live_vertex_count or source_face_count > live_face_count then return detected_cases

        source_faces_valid = true
        for face_id = 1 to source_face_count while source_faces_valid do
        (
                face_degree = EditPolyMod.GetFaceDegree edit_modifier face_id node:source_node
                if face_degree < 3 then
                (
                        source_faces_valid = false
                )
                else
                (
                        for corner_id = 1 to face_degree while source_faces_valid do
                        (
                                vertex_id = EditPolyMod.GetFaceVertex edit_modifier face_id corner_id node:source_node
                                if vertex_id < 1 or vertex_id > source_vert_count then source_faces_valid = false
                        )
                )
        )
        if not source_faces_valid then return detected_cases

        source_face_ids = #{1..source_face_count}
        source_edge_records = buildWallThicknessTEdgeRecords edit_modifier source_node source_face_ids
        surface_tolerance_degrees = 1.0
        coplanar_dot_limit = cos surface_tolerance_degrees
        face_region_ids = getWallThicknessTEdgeSourceRegions edit_modifier source_node source_face_count source_edge_records coplanar_dot_limit
        spine_tolerance_degrees = 5.0
        opposite_dot_limit = -(cos spine_tolerance_degrees)
        branch_parallel_limit = cos spine_tolerance_degrees
        length_tolerance = units.decodeValue "0.01mm"
        fraction_tolerance = 0.000001
        object_tm = source_node.objectTransform

        for anchor_source_id = 1 to source_vert_count do
        (
                incident_record_ids = #()
                for record_id = 1 to source_edge_records.count do
                (
                        edge_record = source_edge_records[record_id]
                        if edge_record[1] == anchor_source_id or edge_record[2] == anchor_source_id then append incident_record_ids record_id
                )

                detected_case = undefined
                if incident_record_ids.count >= 4 then
                (
                        anchor_local_position = EditPolyMod.GetVertex edit_modifier anchor_source_id node:source_node

                        if anchor_local_position != undefined then
                        (
                                for first_index = 1 to (incident_record_ids.count - 1) while detected_case == undefined do
                                (
                                        first_record = source_edge_records[incident_record_ids[first_index]]
                                        first_neighbor_id = getWallThicknessTEdgeRecordOtherVertex first_record anchor_source_id
                                        first_neighbor_position = EditPolyMod.GetVertex edit_modifier first_neighbor_id node:source_node

                                        if first_neighbor_position != undefined then
                                        (
                                                first_direction = first_neighbor_position - anchor_local_position
                                                if (length first_direction) > length_tolerance then first_direction = normalize first_direction

                                                for second_index = (first_index + 1) to incident_record_ids.count while detected_case == undefined do
                                                (
                                                        second_record = source_edge_records[incident_record_ids[second_index]]
                                                        second_neighbor_id = getWallThicknessTEdgeRecordOtherVertex second_record anchor_source_id
                                                        second_neighbor_position = EditPolyMod.GetVertex edit_modifier second_neighbor_id node:source_node

                                                        if second_neighbor_position != undefined then
                                                        (
                                                                second_direction = second_neighbor_position - anchor_local_position
                                                                if (length second_direction) > length_tolerance then second_direction = normalize second_direction

                                                                if (length first_direction) > 0.5 and (length second_direction) > 0.5 and (dot first_direction second_direction) <= opposite_dot_limit then
                                                                (
                                                                        for orientation_id = 1 to 2 while detected_case == undefined do
                                                                        (
                                                                                corner_record = if orientation_id == 1 then first_record else second_record
                                                                                continuation_record = if orientation_id == 1 then second_record else first_record
                                                                                corner_neighbor_id = if orientation_id == 1 then first_neighbor_id else second_neighbor_id
                                                                                continuation_neighbor_id = if orientation_id == 1 then second_neighbor_id else first_neighbor_id
                                                                                corner_direction = if orientation_id == 1 then first_direction else second_direction
                                                                                corner_regions = getWallThicknessTEdgeRecordRegions corner_record face_region_ids
                                                                                continuation_regions = getWallThicknessTEdgeRecordRegions continuation_record face_region_ids

                                                                                if corner_regions.count == 2 and continuation_regions.count == 1 then
                                                                                (
                                                                                        continuing_region_id = continuation_regions[1]
                                                                                        if (findItem corner_regions continuing_region_id) > 0 then
                                                                                        (
                                                                                                terminating_region_id = if corner_regions[1] == continuing_region_id then corner_regions[2] else corner_regions[1]

                                                                                                for branch_record_id in incident_record_ids while detected_case == undefined do
                                                                                                (
                                                                                                        if branch_record_id != incident_record_ids[first_index] and branch_record_id != incident_record_ids[second_index] then
                                                                                                        (
                                                                                                                branch_record = source_edge_records[branch_record_id]
                                                                                                                branch_regions = getWallThicknessTEdgeRecordRegions branch_record face_region_ids

                                                                                                                if branch_record[3].count == 1 and branch_regions.count == 1 and branch_regions[1] == terminating_region_id then
                                                                                                                (
                                                                                                                        branch_neighbor_id = getWallThicknessTEdgeRecordOtherVertex branch_record anchor_source_id
                                                                                                                        branch_neighbor_position = EditPolyMod.GetVertex edit_modifier branch_neighbor_id node:source_node

                                                                                                                        if branch_neighbor_position != undefined then
                                                                                                                        (
                                                                                                                                branch_direction = branch_neighbor_position - anchor_local_position
                                                                                                                                branch_local_length = length branch_direction

                                                                                                                                if branch_local_length > length_tolerance then
                                                                                                                                (
                                                                                                                                        branch_direction = normalize branch_direction

                                                                                                                                        if (abs (dot branch_direction corner_direction)) < branch_parallel_limit then
                                                                                                                                        (
                                                                                                                                                branch_world_length = distance (anchor_local_position * object_tm) (branch_neighbor_position * object_tm)

                                                                                                                                                if branch_world_length > (wall_thickness + length_tolerance) then
                                                                                                                                                (
                                                                                                                                                        continuing_plan_neighbor_id = 0
                                                                                                                                                        anchor_generated_id = anchor_source_id + source_vert_count

                                                                                                                                                        for plan_record_id in incident_record_ids while continuing_plan_neighbor_id == 0 do
                                                                                                                                                        (
                                                                                                                                                                if plan_record_id != branch_record_id and plan_record_id != incident_record_ids[first_index] and plan_record_id != incident_record_ids[second_index] then
                                                                                                                                                                (
                                                                                                                                                                        plan_record = source_edge_records[plan_record_id]
                                                                                                                                                                        plan_regions = getWallThicknessTEdgeRecordRegions plan_record face_region_ids

                                                                                                                                                                        if plan_regions.count == 1 and plan_regions[1] == continuing_region_id then
                                                                                                                                                                        (
                                                                                                                                                                                plan_neighbor_id = getWallThicknessTEdgeRecordOtherVertex plan_record anchor_source_id
                                                                                                                                                                                plan_neighbor_position = EditPolyMod.GetVertex edit_modifier plan_neighbor_id node:source_node

                                                                                                                                                                                if plan_neighbor_position != undefined then
                                                                                                                                                                                (
                                                                                                                                                                                        plan_delta = [plan_neighbor_position.x - anchor_local_position.x, plan_neighbor_position.y - anchor_local_position.y, 0]

                                                                                                                                                                                        if length plan_delta > length_tolerance then
                                                                                                                                                                                        (
                                                                                                                                                                                                generated_plan_neighbor_id = plan_neighbor_id + source_vert_count

                                                                                                                                                                                                if anchor_generated_id <= live_vertex_count and generated_plan_neighbor_id <= live_vertex_count then
                                                                                                                                                                                                (
                                                                                                                                                                                                        generated_anchor_position = EditPolyMod.GetVertex edit_modifier anchor_generated_id node:source_node
                                                                                                                                                                                                        generated_plan_position = EditPolyMod.GetVertex edit_modifier generated_plan_neighbor_id node:source_node

                                                                                                                                                                                                        if generated_anchor_position != undefined and generated_plan_position != undefined then
                                                                                                                                                                                                        (
                                                                                                                                                                                                                branch_plan = [branch_neighbor_position.x - anchor_local_position.x, branch_neighbor_position.y - anchor_local_position.y, 0]
                                                                                                                                                                                                                generated_plan = [generated_plan_position.x - generated_anchor_position.x, generated_plan_position.y - generated_anchor_position.y, 0]
                                                                                                                                                                                                                denominator = (branch_plan.x * generated_plan.y) - (branch_plan.y * generated_plan.x)

                                                                                                                                                                                                                if abs denominator > 0.000000001 then
                                                                                                                                                                                                                (
                                                                                                                                                                                                                        between_lines = [generated_anchor_position.x - anchor_local_position.x, generated_anchor_position.y - anchor_local_position.y, 0]
                                                                                                                                                                                                                        anchor_fraction = ((between_lines.x * generated_plan.y) - (between_lines.y * generated_plan.x)) / denominator

                                                                                                                                                                                                                        if anchor_fraction > fraction_tolerance and anchor_fraction < (1.0 - fraction_tolerance) then
                                                                                                                                                                                                                        (
                                                                                                                                                                                                                                continuing_plan_neighbor_id = plan_neighbor_id
                                                                                                                                                                                                                                detected_case = #(anchor_source_id, branch_neighbor_id, corner_neighbor_id, continuation_neighbor_id, continuing_region_id, terminating_region_id, continuing_plan_neighbor_id, anchor_fraction)
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
                                                        )
                                                )
                                        )
                                )
                        )
                )

                if detected_case != undefined then append detected_cases detected_case
        )

        detected_cases
        -- return
)


/*
Resolves the current live Edit Poly edge connecting two known vertex IDs.
Edge IDs are never persisted across topology changes.
*/
function findWallThicknessTEdgeLiveEdge edit_modifier source_node vertex_a vertex_b =
(
        found_edge_id = 0
        edge_count = EditPolyMod.GetNumEdges edit_modifier node:source_node

        for edge_id = 1 to edge_count while found_edge_id == 0 do
        (
                edge_vertex_a = EditPolyMod.GetEdgeVertex edit_modifier edge_id 1 node:source_node
                edge_vertex_b = EditPolyMod.GetEdgeVertex edit_modifier edge_id 2 node:source_node
                if ((edge_vertex_a == vertex_a) and (edge_vertex_b == vertex_b)) or ((edge_vertex_a == vertex_b) and (edge_vertex_b == vertex_a)) then
                (
                        found_edge_id = edge_id
                )
        )

        found_edge_id
        -- return
)

/*
Divides one current Edit Poly edge at a fraction measured from a named endpoint.
The edge is resolved immediately before the call so topology edits cannot stale its ID.
*/
function divideWallThicknessTEdgeFromVertexFraction edit_modifier source_node start_vertex_id end_vertex_id fraction_from_start =
(
        new_vertex_id = 0
        if fraction_from_start <= 0.0 or fraction_from_start >= 1.0 then return new_vertex_id

        edge_id = findWallThicknessTEdgeLiveEdge edit_modifier source_node start_vertex_id end_vertex_id
        if edge_id < 1 then return new_vertex_id

        edge_vertex_a = EditPolyMod.GetEdgeVertex edit_modifier edge_id 1 node:source_node
        divide_fraction = if edge_vertex_a == start_vertex_id then fraction_from_start else (1.0 - fraction_from_start)

        divided_vertex_id = EditPolyMod.DivideEdge edit_modifier edge_id divide_fraction node:source_node
        if divided_vertex_id != undefined and divided_vertex_id > 0 then
        (
                EditPolyMod.Commit edit_modifier
                update source_node
                new_vertex_id = divided_vertex_id as integer
        )

        new_vertex_id
        -- return
)


/*
Connects exactly two live Edit Poly vertices and verifies the new visible polygon edge exists.
*/
function connectWallThicknessTEdgeVertices edit_modifier source_node vertex_a vertex_b =
(
        if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return false
        if not isValidNode source_node then return false
        if vertex_a < 1 or vertex_b < 1 or vertex_a == vertex_b then return false

        if findWallThicknessTEdgeLiveEdge edit_modifier source_node vertex_a vertex_b > 0 then return true

        vertex_bits = #{}
        vertex_bits[vertex_a] = true
        vertex_bits[vertex_b] = true

        if not WallThicknessPreprocess.selectModifierComponents source_node edit_modifier #Vertex vertex_bits then return false

        edit_modifier.ButtonOp #ConnectVertices
        update source_node

        findWallThicknessTEdgeLiveEdge edit_modifier source_node vertex_a vertex_b > 0
        -- return
)


/*
Moves the complete newly cut vertical edge in local X/Y onto the fixed anchor.
Both cut vertices keep their original Z positions.
*/
function moveWallThicknessTEdgeVerticalCutToAnchor edit_modifier source_node top_vertex_id bottom_vertex_id fixed_anchor_position tolerance =
(
        if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return false
        if not isValidNode source_node then return false

        top_position = EditPolyMod.GetVertex edit_modifier top_vertex_id node:source_node
        bottom_position = EditPolyMod.GetVertex edit_modifier bottom_vertex_id node:source_node
        if top_position == undefined or bottom_position == undefined then return false

        if abs (top_position.x - bottom_position.x) > tolerance or abs (top_position.y - bottom_position.y) > tolerance then return false

        original_top_z = top_position.z
        original_bottom_z = bottom_position.z
        move_amount = [fixed_anchor_position.x - top_position.x, fixed_anchor_position.y - top_position.y, 0]

        vertex_bits = #{}
        vertex_bits[top_vertex_id] = true
        vertex_bits[bottom_vertex_id] = true

        if not WallThicknessPreprocess.selectModifierComponents source_node edit_modifier #Vertex vertex_bits then return false

        edit_modifier.SetOperation #TransformVertex
        parent_tm = matrix3 1
        axis_tm = matrix3 1
        edit_modifier.MoveSelection move_amount parent:parent_tm axis:axis_tm localOrigin:false
        edit_modifier.Commit()
        update source_node

        moved_top_position = EditPolyMod.GetVertex edit_modifier top_vertex_id node:source_node
        moved_bottom_position = EditPolyMod.GetVertex edit_modifier bottom_vertex_id node:source_node
        if moved_top_position == undefined or moved_bottom_position == undefined then return false

        top_matches =
                abs (moved_top_position.x - fixed_anchor_position.x) <= tolerance and
                abs (moved_top_position.y - fixed_anchor_position.y) <= tolerance and
                abs (moved_top_position.z - original_top_z) <= tolerance

        bottom_matches =
                abs (moved_bottom_position.x - fixed_anchor_position.x) <= tolerance and
                abs (moved_bottom_position.y - fixed_anchor_position.y) <= tolerance and
                abs (moved_bottom_position.z - original_bottom_z) <= tolerance

        top_matches and bottom_matches
        -- return
)


/*
Returns true when one live Edit Poly polygon contains a named vertex.
*/
function wallThicknessTEdgeFaceUsesVertex edit_modifier source_node face_id vertex_id =
(
        uses_vertex = false
        face_count = EditPolyMod.GetNumFaces edit_modifier node:source_node
        if face_id < 1 or face_id > face_count then return uses_vertex

        face_degree = EditPolyMod.GetFaceDegree edit_modifier face_id node:source_node
        for corner_id = 1 to face_degree while not uses_vertex do
        (
                if EditPolyMod.GetFaceVertex edit_modifier face_id corner_id node:source_node == vertex_id then uses_vertex = true
        )

        uses_vertex
        -- return
)


/*
Copies the material ID onto only the new generated-side half of the repaired vertical strip.
The unchanged generated wall polygon across the original generated vertical edge is the reference.
*/
function fixWallThicknessTEdgeGeneratedStripMaterial edit_modifier source_node generated_top_vertex_id generated_bottom_vertex_id fixed_anchor_vertex_id =
(
        changed_face_count = 0
        generated_edge_id = findWallThicknessTEdgeLiveEdge edit_modifier source_node generated_top_vertex_id generated_bottom_vertex_id
        if generated_edge_id < 1 then return changed_face_count

        face_a = 0
        face_b = 0
        try (face_a = EditPolyMod.GetEdgeFace edit_modifier generated_edge_id 1 node:source_node) catch ()
        try (face_b = EditPolyMod.GetEdgeFace edit_modifier generated_edge_id 2 node:source_node) catch ()

        if face_a > 0 and face_b > 0 then
        (
                face_a_uses_anchor = wallThicknessTEdgeFaceUsesVertex edit_modifier source_node face_a fixed_anchor_vertex_id
                face_b_uses_anchor = wallThicknessTEdgeFaceUsesVertex edit_modifier source_node face_b fixed_anchor_vertex_id

                if face_a_uses_anchor != face_b_uses_anchor then
                (
                        target_face_id = if face_a_uses_anchor then face_a else face_b
                        reference_face_id = if face_a_uses_anchor then face_b else face_a
                        reference_material_id = EditPolyMod.GetFaceMaterial edit_modifier reference_face_id node:source_node
                        target_material_id = EditPolyMod.GetFaceMaterial edit_modifier target_face_id node:source_node

                        if reference_material_id > 0 and target_material_id != reference_material_id then
                        (
                                face_bits = #{}
                                face_bits[target_face_id] = true

                                if WallThicknessPreprocess.selectModifierComponents source_node edit_modifier #Face face_bits then
                                (
                                        edit_modifier.materialIDToSet = reference_material_id
                                        edit_modifier.SetOperation #SetMaterial
                                        edit_modifier.Commit()
                                        update source_node

                                        if EditPolyMod.GetFaceMaterial edit_modifier target_face_id node:source_node == reference_material_id then
                                        (
                                                changed_face_count = 1
                                        )
                                )
                        )
                )
        )

        changed_face_count
        -- return
)



/*
Resolves the generated cross-edge paired with one preserved source anchor.
The normal source->generated builder mapping is preferred, then a unique generated live neighbor is accepted.
*/
function findWallThicknessTEdgeCrossData edit_modifier source_node anchor_source_id source_vert_count original_live_vertex_count =
(
        result_data = undefined
        expected_generated_id = anchor_source_id + source_vert_count

        if expected_generated_id > source_vert_count and expected_generated_id <= original_live_vertex_count then
        (
                expected_edge_id = findWallThicknessTEdgeLiveEdge edit_modifier source_node anchor_source_id expected_generated_id
                if expected_edge_id > 0 then result_data = #(expected_edge_id, expected_generated_id)
        )

        if result_data == undefined then
        (
                generated_candidates = #()
                edge_count = EditPolyMod.GetNumEdges edit_modifier node:source_node

                for edge_id = 1 to edge_count do
                (
                        edge_vertex_a = EditPolyMod.GetEdgeVertex edit_modifier edge_id 1 node:source_node
                        edge_vertex_b = EditPolyMod.GetEdgeVertex edit_modifier edge_id 2 node:source_node
                        other_vertex_id = 0

                        if edge_vertex_a == anchor_source_id then other_vertex_id = edge_vertex_b
                        else if edge_vertex_b == anchor_source_id then other_vertex_id = edge_vertex_a

                        if other_vertex_id > source_vert_count and other_vertex_id <= original_live_vertex_count then
                        (
                                append generated_candidates #(edge_id, other_vertex_id)
                        )
                )

                if generated_candidates.count == 1 then result_data = generated_candidates[1]
        )

        result_data
        -- return
)


/*
Finds the closest live vertex to one local target position within tolerance.
*/
function findWallThicknessTEdgeVertexAtPosition edit_modifier source_node target_position tolerance =
(
        found_vertex_id = 0
        best_distance = tolerance
        vertex_count = EditPolyMod.GetNumVertices edit_modifier node:source_node

        for vertex_id = 1 to vertex_count do
        (
                test_position = EditPolyMod.GetVertex edit_modifier vertex_id node:source_node
                if test_position != undefined then
                (
                        test_distance = distance test_position target_position
                        if test_distance <= best_distance then
                        (
                                best_distance = test_distance
                                found_vertex_id = vertex_id
                        )
                )
        )

        found_vertex_id
        -- return
)


/*
Returns all polygon faces incident to one live Edit Poly vertex.
*/
function getWallThicknessTEdgeFacesAtVertex edit_modifier source_node vertex_id =
(
        face_bits = #{}
        face_count = EditPolyMod.GetNumFaces edit_modifier node:source_node

        for face_id = 1 to face_count do
        (
                face_degree = EditPolyMod.GetFaceDegree edit_modifier face_id node:source_node
                for corner_id = 1 to face_degree while not face_bits[face_id] do
                (
                        if EditPolyMod.GetFaceVertex edit_modifier face_id corner_id node:source_node == vertex_id then face_bits[face_id] = true
                )
        )

        face_bits
        -- return
)


/*
Normalizes material IDs only in coplanar connected face regions touching one repaired T-edge anchor.
The established material is selected by total polygon area, never by a hardcoded material number.
*/
function normalizeWallThicknessTEdgeMaterials edit_modifier source_node anchor_vertex_id normal_tolerance_degrees:1.0 =
(
        changed_face_count = 0
        seed_faces = getWallThicknessTEdgeFacesAtVertex edit_modifier source_node anchor_vertex_id
        if seed_faces.numberSet == 0 then return changed_face_count

        face_count = EditPolyMod.GetNumFaces edit_modifier node:source_node
        all_face_ids = #{1..face_count}
        edge_records = buildWallThicknessTEdgeRecords edit_modifier source_node all_face_ids
        face_normals = for face_id = 1 to face_count collect (getWallThicknessTEdgeFaceNormal edit_modifier source_node face_id)
        processed_faces = #{}
        normal_dot_limit = cos normal_tolerance_degrees

        for seed_face_id in seed_faces do
        (
                if not processed_faces[seed_face_id] then
                (
                        region_faces = #{}
                        face_queue = #(seed_face_id)
                        processed_faces[seed_face_id] = true

                        while face_queue.count > 0 do
                        (
                                current_face_id = face_queue[1]
                                deleteItem face_queue 1
                                region_faces[current_face_id] = true
                                current_normal = face_normals[current_face_id]

                                for edge_record in edge_records do
                                (
                                        if (findItem edge_record[3] current_face_id) > 0 then
                                        (
                                                for neighbor_face_id in edge_record[3] do
                                                (
                                                        if neighbor_face_id != current_face_id and not processed_faces[neighbor_face_id] then
                                                        (
                                                                neighbor_normal = face_normals[neighbor_face_id]
                                                                if (length current_normal) > 0.000001 and (length neighbor_normal) > 0.000001 and (dot current_normal neighbor_normal) >= normal_dot_limit then
                                                                (
                                                                        processed_faces[neighbor_face_id] = true
                                                                        append face_queue neighbor_face_id
                                                                )
                                                        )
                                                )
                                        )
                                )
                        )

                        if region_faces.numberSet > 1 then
                        (
                                material_ids = #()
                                material_areas = #()

                                for face_id in region_faces do
                                (
                                        material_id = EditPolyMod.GetFaceMaterial edit_modifier face_id node:source_node
                                        face_area = getWallThicknessTEdgeFaceArea edit_modifier source_node face_id
                                        material_index = findItem material_ids material_id

                                        if material_index == 0 then
                                        (
                                                append material_ids material_id
                                                append material_areas face_area
                                        )
                                        else
                                        (
                                                material_areas[material_index] += face_area
                                        )
                                )

                                target_material_id = 0
                                best_material_area = -1.0
                                for material_index = 1 to material_ids.count do
                                (
                                        if material_areas[material_index] > best_material_area then
                                        (
                                                best_material_area = material_areas[material_index]
                                                target_material_id = material_ids[material_index]
                                        )
                                )

                                if target_material_id > 0 then
                                (
                                        change_faces = #{}
                                        for face_id in region_faces do
                                        (
                                                if EditPolyMod.GetFaceMaterial edit_modifier face_id node:source_node != target_material_id then change_faces[face_id] = true
                                        )

                                        if change_faces.numberSet > 0 then
                                        (
                                                setEditPolyMaterialID edit_modifier source_node change_faces target_material_id
                                                changed_face_count += change_faces.numberSet
                                        )
                                )
                        )
                )
        )

        changed_face_count
        -- return
)


/*
Returns one ordered local-space polygon normal from the baked Editable Poly.
This is the direct-base equivalent of the working FIX INNER CORNERS path.
*/
function getWallThicknessTEdgeBaseFaceNormal source_node face_id =
(
        face_normal = [0,0,0]
        if not isValidNode source_node then return face_normal
        if classOf source_node.baseObject != Editable_Poly then return face_normal

        face_count = source_node.GetNumFaces()
        if face_id < 1 or face_id > face_count then return face_normal

        face_degree = source_node.GetFaceDegree face_id
        if face_degree < 3 then return face_normal

        origin_vertex_id = source_node.GetFaceVertex face_id 1
        origin_position = source_node.GetVertex origin_vertex_id

        for corner_id = 2 to (face_degree - 1) do
        (
                vertex_b_id = source_node.GetFaceVertex face_id corner_id
                vertex_c_id = source_node.GetFaceVertex face_id (corner_id + 1)
                position_b = source_node.GetVertex vertex_b_id
                position_c = source_node.GetVertex vertex_c_id
                face_normal += cross (position_b - origin_position) (position_c - origin_position)
        )

        if (length face_normal) > 0.000001 then face_normal = normalize face_normal
        face_normal
        -- return
)

function buildWallThicknessTEdgeBaseRecords source_node face_ids =
(
        edge_records = #()

        for face_id in face_ids do
        (
                face_degree = source_node.GetFaceDegree face_id
                if face_degree >= 3 then
                (
                        face_vertices = #()
                        for corner_id = 1 to face_degree do
                        (
                                append face_vertices (source_node.GetFaceVertex face_id corner_id)
                        )

                        for corner_id = 1 to face_degree do
                        (
                                next_corner_id = if corner_id == face_degree then 1 else corner_id + 1
                                vertex_a = face_vertices[corner_id]
                                vertex_b = face_vertices[next_corner_id]
                                low_id = if vertex_a < vertex_b then vertex_a else vertex_b
                                high_id = if vertex_a > vertex_b then vertex_a else vertex_b
                                record_index = findWallThicknessTEdgeRecord edge_records low_id high_id

                                if record_index == 0 then
                                (
                                        append edge_records #(low_id, high_id, #(face_id))
                                )
                                else
                                (
                                        edge_record = edge_records[record_index]
                                        record_faces = edge_record[3]
                                        if (findItem record_faces face_id) == 0 then append record_faces face_id
                                        edge_record[3] = record_faces
                                        edge_records[record_index] = edge_record
                                )
                        )
                )
        )

        edge_records
        -- return
)

function getWallThicknessTEdgeBaseSourceRegions source_node source_face_count source_edge_records coplanar_dot_limit =
(
        face_region_ids = for face_id = 1 to source_face_count collect 0
        face_normals = for face_id = 1 to source_face_count collect (getWallThicknessTEdgeBaseFaceNormal source_node face_id)
        next_region_id = 0

        for seed_face_id = 1 to source_face_count do
        (
                if face_region_ids[seed_face_id] == 0 then
                (
                        next_region_id += 1
                        face_region_ids[seed_face_id] = next_region_id
                        face_queue = #(seed_face_id)

                        while face_queue.count > 0 do
                        (
                                current_face_id = face_queue[1]
                                deleteItem face_queue 1
                                current_normal = face_normals[current_face_id]

                                for edge_record in source_edge_records do
                                (
                                        if (findItem edge_record[3] current_face_id) > 0 then
                                        (
                                                for neighbor_face_id in edge_record[3] do
                                                (
                                                        if neighbor_face_id != current_face_id and face_region_ids[neighbor_face_id] == 0 then
                                                        (
                                                                neighbor_normal = face_normals[neighbor_face_id]
                                                                if (length current_normal) > 0.000001 and (length neighbor_normal) > 0.000001 then
                                                                (
                                                                        if (abs (dot current_normal neighbor_normal)) >= coplanar_dot_limit then
                                                                        (
                                                                                face_region_ids[neighbor_face_id] = next_region_id
                                                                                append face_queue neighbor_face_id
                                                                        )
                                                                )
                                                        )
                                                )
                                        )
                                )
                        )
                )
        )

        face_region_ids
        -- return
)

function detectWallThicknessTEdgeBaseCases source_node source_vert_count source_face_count wall_thickness =
(
        detected_cases = #()
        if not isValidNode source_node then return detected_cases
        if classOf source_node.baseObject != Editable_Poly then return detected_cases
        if source_vert_count < 1 or source_face_count < 1 then return detected_cases

        live_vertex_count = source_node.GetNumVertices()
        live_face_count = source_node.GetNumFaces()
        if source_vert_count >= live_vertex_count or source_face_count > live_face_count then return detected_cases

        source_faces_valid = true
        for face_id = 1 to source_face_count while source_faces_valid do
        (
                face_degree = source_node.GetFaceDegree face_id
                if face_degree < 3 then
                (
                        source_faces_valid = false
                )
                else
                (
                        for corner_id = 1 to face_degree while source_faces_valid do
                        (
                                vertex_id = source_node.GetFaceVertex face_id corner_id
                                if vertex_id < 1 or vertex_id > source_vert_count then source_faces_valid = false
                        )
                )
        )
        if not source_faces_valid then return detected_cases

        source_face_ids = #{1..source_face_count}
        source_edge_records = buildWallThicknessTEdgeBaseRecords source_node source_face_ids
        surface_tolerance_degrees = 1.0
        coplanar_dot_limit = cos surface_tolerance_degrees
        face_region_ids = getWallThicknessTEdgeBaseSourceRegions source_node source_face_count source_edge_records coplanar_dot_limit
        spine_tolerance_degrees = 5.0
        opposite_dot_limit = -(cos spine_tolerance_degrees)
        branch_parallel_limit = cos spine_tolerance_degrees
        length_tolerance = units.decodeValue "0.01mm"
        fraction_tolerance = 0.000001
        object_tm = source_node.objectTransform

        for anchor_source_id = 1 to source_vert_count do
        (
                incident_record_ids = #()
                for record_id = 1 to source_edge_records.count do
                (
                        edge_record = source_edge_records[record_id]
                        if edge_record[1] == anchor_source_id or edge_record[2] == anchor_source_id then append incident_record_ids record_id
                )

                detected_case = undefined
                if incident_record_ids.count >= 4 then
                (
                        anchor_local_position = source_node.GetVertex anchor_source_id

                        if anchor_local_position != undefined then
                        (
                                for first_index = 1 to (incident_record_ids.count - 1) while detected_case == undefined do
                                (
                                        first_record = source_edge_records[incident_record_ids[first_index]]
                                        first_neighbor_id = getWallThicknessTEdgeRecordOtherVertex first_record anchor_source_id
                                        first_neighbor_position = source_node.GetVertex first_neighbor_id

                                        if first_neighbor_position != undefined then
                                        (
                                                first_direction = first_neighbor_position - anchor_local_position
                                                if (length first_direction) > length_tolerance then first_direction = normalize first_direction

                                                for second_index = (first_index + 1) to incident_record_ids.count while detected_case == undefined do
                                                (
                                                        second_record = source_edge_records[incident_record_ids[second_index]]
                                                        second_neighbor_id = getWallThicknessTEdgeRecordOtherVertex second_record anchor_source_id
                                                        second_neighbor_position = source_node.GetVertex second_neighbor_id

                                                        if second_neighbor_position != undefined then
                                                        (
                                                                second_direction = second_neighbor_position - anchor_local_position
                                                                if (length second_direction) > length_tolerance then second_direction = normalize second_direction

                                                                if (length first_direction) > 0.5 and (length second_direction) > 0.5 and (dot first_direction second_direction) <= opposite_dot_limit then
                                                                (
                                                                        for orientation_id = 1 to 2 while detected_case == undefined do
                                                                        (
                                                                                corner_record = if orientation_id == 1 then first_record else second_record
                                                                                continuation_record = if orientation_id == 1 then second_record else first_record
                                                                                corner_neighbor_id = if orientation_id == 1 then first_neighbor_id else second_neighbor_id
                                                                                continuation_neighbor_id = if orientation_id == 1 then second_neighbor_id else first_neighbor_id
                                                                                corner_direction = if orientation_id == 1 then first_direction else second_direction
                                                                                corner_regions = getWallThicknessTEdgeRecordRegions corner_record face_region_ids
                                                                                continuation_regions = getWallThicknessTEdgeRecordRegions continuation_record face_region_ids

                                                                                if corner_regions.count == 2 and continuation_regions.count == 1 then
                                                                                (
                                                                                        continuing_region_id = continuation_regions[1]
                                                                                        if (findItem corner_regions continuing_region_id) > 0 then
                                                                                        (
                                                                                                terminating_region_id = if corner_regions[1] == continuing_region_id then corner_regions[2] else corner_regions[1]

                                                                                                for branch_record_id in incident_record_ids while detected_case == undefined do
                                                                                                (
                                                                                                        if branch_record_id != incident_record_ids[first_index] and branch_record_id != incident_record_ids[second_index] then
                                                                                                        (
                                                                                                                branch_record = source_edge_records[branch_record_id]
                                                                                                                branch_regions = getWallThicknessTEdgeRecordRegions branch_record face_region_ids

                                                                                                                if branch_record[3].count == 1 and branch_regions.count == 1 and branch_regions[1] == terminating_region_id then
                                                                                                                (
                                                                                                                        branch_neighbor_id = getWallThicknessTEdgeRecordOtherVertex branch_record anchor_source_id
                                                                                                                        branch_neighbor_position = source_node.GetVertex branch_neighbor_id

                                                                                                                        if branch_neighbor_position != undefined then
                                                                                                                        (
                                                                                                                                branch_direction = branch_neighbor_position - anchor_local_position
                                                                                                                                branch_local_length = length branch_direction

                                                                                                                                if branch_local_length > length_tolerance then
                                                                                                                                (
                                                                                                                                        branch_direction = normalize branch_direction

                                                                                                                                        if (abs (dot branch_direction corner_direction)) < branch_parallel_limit then
                                                                                                                                        (
                                                                                                                                                branch_world_length = distance (anchor_local_position * object_tm) (branch_neighbor_position * object_tm)

                                                                                                                                                if branch_world_length > (wall_thickness + length_tolerance) then
                                                                                                                                                (
                                                                                                                                                        continuing_plan_neighbor_id = 0
                                                                                                                                                        anchor_generated_id = anchor_source_id + source_vert_count

                                                                                                                                                        for plan_record_id in incident_record_ids while continuing_plan_neighbor_id == 0 do
                                                                                                                                                        (
                                                                                                                                                                if plan_record_id != branch_record_id and plan_record_id != incident_record_ids[first_index] and plan_record_id != incident_record_ids[second_index] then
                                                                                                                                                                (
                                                                                                                                                                        plan_record = source_edge_records[plan_record_id]
                                                                                                                                                                        plan_regions = getWallThicknessTEdgeRecordRegions plan_record face_region_ids

                                                                                                                                                                        if plan_regions.count == 1 and plan_regions[1] == continuing_region_id then
                                                                                                                                                                        (
                                                                                                                                                                                plan_neighbor_id = getWallThicknessTEdgeRecordOtherVertex plan_record anchor_source_id
                                                                                                                                                                                plan_neighbor_position = source_node.GetVertex plan_neighbor_id

                                                                                                                                                                                if plan_neighbor_position != undefined then
                                                                                                                                                                                (
                                                                                                                                                                                        plan_delta = [plan_neighbor_position.x - anchor_local_position.x, plan_neighbor_position.y - anchor_local_position.y, 0]

                                                                                                                                                                                        if length plan_delta > length_tolerance then
                                                                                                                                                                                        (
                                                                                                                                                                                                generated_plan_neighbor_id = plan_neighbor_id + source_vert_count

                                                                                                                                                                                                if anchor_generated_id <= live_vertex_count and generated_plan_neighbor_id <= live_vertex_count then
                                                                                                                                                                                                (
                                                                                                                                                                                                        generated_anchor_position = source_node.GetVertex anchor_generated_id
                                                                                                                                                                                                        generated_plan_position = source_node.GetVertex generated_plan_neighbor_id

                                                                                                                                                                                                        if generated_anchor_position != undefined and generated_plan_position != undefined then
                                                                                                                                                                                                        (
                                                                                                                                                                                                                branch_plan = [branch_neighbor_position.x - anchor_local_position.x, branch_neighbor_position.y - anchor_local_position.y, 0]
                                                                                                                                                                                                                generated_plan = [generated_plan_position.x - generated_anchor_position.x, generated_plan_position.y - generated_anchor_position.y, 0]
                                                                                                                                                                                                                denominator = (branch_plan.x * generated_plan.y) - (branch_plan.y * generated_plan.x)

                                                                                                                                                                                                                if abs denominator > 0.000000001 then
                                                                                                                                                                                                                (
                                                                                                                                                                                                                        between_lines = [generated_anchor_position.x - anchor_local_position.x, generated_anchor_position.y - anchor_local_position.y, 0]
                                                                                                                                                                                                                        anchor_fraction = ((between_lines.x * generated_plan.y) - (between_lines.y * generated_plan.x)) / denominator

                                                                                                                                                                                                                        if anchor_fraction > fraction_tolerance and anchor_fraction < (1.0 - fraction_tolerance) then
                                                                                                                                                                                                                        (
                                                                                                                                                                                                                                continuing_plan_neighbor_id = plan_neighbor_id
                                                                                                                                                                                                                                detected_case = #(anchor_source_id, branch_neighbor_id, corner_neighbor_id, continuation_neighbor_id, continuing_region_id, terminating_region_id, continuing_plan_neighbor_id, anchor_fraction)
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
                                                        )
                                                )
                                        )
                                )
                        )
                )

                if detected_case != undefined then append detected_cases detected_case
        )

        detected_cases
        -- return
)

/*
Resolves one current Editable Poly edge from its endpoint vertex IDs.
The edge ID is resolved again after every topology edit.
*/
function findWallThicknessTEdgeBaseEdge source_node vertex_a vertex_b =
(
        found_edge_id = 0
        if not isValidNode source_node then return found_edge_id
        if classOf source_node.baseObject != Editable_Poly then return found_edge_id

        edge_count = source_node.GetNumEdges()

        for edge_id = 1 to edge_count while found_edge_id == 0 do
        (
                edge_vertex_a = source_node.GetEdgeVertex edge_id 1
                edge_vertex_b = source_node.GetEdgeVertex edge_id 2

                if ((edge_vertex_a == vertex_a) and (edge_vertex_b == vertex_b)) or ((edge_vertex_a == vertex_b) and (edge_vertex_b == vertex_a)) then
                (
                        found_edge_id = edge_id
                )
        )

        found_edge_id
        -- return
)


/*
Divides one edge directly on the baked Editable Poly.
*/
function divideWallThicknessTEdgeBaseFromVertexFraction source_node start_vertex_id end_vertex_id fraction_from_start =
(
        new_vertex_id = 0
        if not isValidNode source_node then return new_vertex_id
        if classOf source_node.baseObject != Editable_Poly then return new_vertex_id
        if fraction_from_start <= 0.0 or fraction_from_start >= 1.0 then return new_vertex_id

        edge_id = findWallThicknessTEdgeBaseEdge source_node start_vertex_id end_vertex_id
        if edge_id < 1 then return new_vertex_id

        edge_vertex_a = source_node.GetEdgeVertex edge_id 1
        divide_fraction = if edge_vertex_a == start_vertex_id then fraction_from_start else (1.0 - fraction_from_start)
        divided_vertex_id = polyop.divideEdge source_node.baseObject edge_id divide_fraction

        if divided_vertex_id != undefined and divided_vertex_id > 0 then
        (
                update source_node
                new_vertex_id = divided_vertex_id as integer
        )

        new_vertex_id
        -- return
)


/*
Creates one polygon edge directly on the baked Editable Poly.
*/
function connectWallThicknessTEdgeBaseVertices source_node vertex_a vertex_b =
(
        if not isValidNode source_node then return false
        if classOf source_node.baseObject != Editable_Poly then return false
        if vertex_a < 1 or vertex_b < 1 or vertex_a == vertex_b then return false

        if findWallThicknessTEdgeBaseEdge source_node vertex_a vertex_b > 0 then return true

        new_edge_id = polyop.createEdge source_node.baseObject vertex_a vertex_b
        update source_node

        new_edge_id != undefined and findWallThicknessTEdgeBaseEdge source_node vertex_a vertex_b > 0
        -- return
)


/*
Moves the new vertical cut exactly like FIX INNER CORNERS moves its vertices:
direct absolute polyop.setVert assignments on the baked Editable Poly.
Only X/Y changes; each vertex keeps its original Z.
*/
function moveWallThicknessTEdgeBaseVerticalCutToAnchor source_node top_vertex_id bottom_vertex_id fixed_anchor_position tolerance =
(
        if not isValidNode source_node then return false
        if classOf source_node.baseObject != Editable_Poly then return false

        poly_object = source_node.baseObject
        top_position = source_node.GetVertex top_vertex_id
        bottom_position = source_node.GetVertex bottom_vertex_id
        if top_position == undefined or bottom_position == undefined then return false

        /*
        The two cut vertices come from different strip cross-edges and may inherit tiny
        independent XY drift. They do not need to be pre-aligned: both are written
        independently to the exact fixed-anchor XY while preserving their own Z.
        */
        top_target = [fixed_anchor_position.x, fixed_anchor_position.y, top_position.z]
        bottom_target = [fixed_anchor_position.x, fixed_anchor_position.y, bottom_position.z]

        top_bits = #{}
        top_bits[top_vertex_id] = true
        bottom_bits = #{}
        bottom_bits[bottom_vertex_id] = true

        polyop.setVert poly_object top_bits top_target
        polyop.setVert poly_object bottom_bits bottom_target
        update source_node

        actual_top = source_node.GetVertex top_vertex_id
        actual_bottom = source_node.GetVertex bottom_vertex_id

        (distance actual_top top_target <= tolerance) and (distance actual_bottom bottom_target <= tolerance)
        -- return
)


/*
Returns every current Editable Poly vertex at one local position.
*/
function getWallThicknessTEdgeBaseVerticesAtPosition source_node target_position tolerance =
(
        vertex_ids = #()
        if not isValidNode source_node then return vertex_ids
        if classOf source_node.baseObject != Editable_Poly then return vertex_ids

        vertex_count = source_node.GetNumVertices()

        for vertex_id = 1 to vertex_count do
        (
                if not polyop.isVertDead source_node.baseObject vertex_id then
                (
                        vertex_position = source_node.GetVertex vertex_id
                        if distance vertex_position target_position <= tolerance then append vertex_ids vertex_id
                )
        )

        vertex_ids
        -- return
)


/*
Returns true when one current Editable Poly polygon contains the vertex.
*/
function wallThicknessTEdgeBaseFaceUsesVertex source_node face_id vertex_id =
(
        uses_vertex = false
        if not isValidNode source_node then return uses_vertex
        if classOf source_node.baseObject != Editable_Poly then return uses_vertex

        face_count = source_node.GetNumFaces()
        if face_id < 1 or face_id > face_count then return uses_vertex
        if polyop.isFaceDead source_node.baseObject face_id then return uses_vertex

        face_vertices = polyop.getFaceVerts source_node.baseObject face_id
        (findItem face_vertices vertex_id) > 0
        -- return
)


/*
Copies Material ID only to the repaired generated-side strip polygon.
*/
function fixWallThicknessTEdgeBaseGeneratedStripMaterial source_node generated_top_vertex_id generated_bottom_vertex_id fixed_anchor_vertex_id =
(
        changed_face_count = 0
        if not isValidNode source_node then return changed_face_count
        if classOf source_node.baseObject != Editable_Poly then return changed_face_count

        poly_object = source_node.baseObject
        generated_edge_id = findWallThicknessTEdgeBaseEdge source_node generated_top_vertex_id generated_bottom_vertex_id
        if generated_edge_id < 1 then return changed_face_count

        edge_faces = polyop.getEdgeFaces poly_object generated_edge_id

        if edge_faces != undefined and edge_faces.count == 2 then
        (
                face_a = edge_faces[1]
                face_b = edge_faces[2]
                face_a_uses_anchor = wallThicknessTEdgeBaseFaceUsesVertex source_node face_a fixed_anchor_vertex_id
                face_b_uses_anchor = wallThicknessTEdgeBaseFaceUsesVertex source_node face_b fixed_anchor_vertex_id

                if face_a_uses_anchor != face_b_uses_anchor then
                (
                        target_face_id = if face_a_uses_anchor then face_a else face_b
                        reference_face_id = if face_a_uses_anchor then face_b else face_a
                        reference_material_id = polyop.getFaceMatID poly_object reference_face_id
                        target_material_id = polyop.getFaceMatID poly_object target_face_id

                        if reference_material_id > 0 and target_material_id != reference_material_id then
                        (
                                target_faces = #{}
                                target_faces[target_face_id] = true
                                polyop.setFaceMatID poly_object target_faces reference_material_id
                                update source_node

                                if polyop.getFaceMatID poly_object target_face_id == reference_material_id then changed_face_count = 1
                        )
                )
        )

        changed_face_count
        -- return
)

/*
Repairs partial-height T-edge corners after EXTRUDE -> FIX INNER CORNERS.

IMPORTANT:
This intentionally uses the same write strategy as the working FIX INNER CORNERS:
evaluate the current result, bake it to Editable Poly, then edit that exact Editable Poly directly.
The topology is different, but the write path is the same.
*/
function fixWallThicknessTEdgeCorners source_node =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                #(false, 0, 0, 0)
        )
        else
        (
                stored_source_vert_count = getUserProp source_node wall_thickness_source_vert_count_prop
                stored_source_face_count = getUserProp source_node wall_thickness_source_face_count_prop
                stored_thickness = getUserProp source_node wall_thickness_user_prop

                if stored_source_vert_count == undefined or stored_source_face_count == undefined or stored_thickness == undefined then
                (
                        messageBox "Create WALL THICKNESS first." title:"Wall Thickness"
                        #(false, 0, 0, 0)
                )
                else
                (
                        source_vert_count = stored_source_vert_count as integer
                        source_face_count = stored_source_face_count as integer
                        wall_thickness = stored_thickness as float
                        tolerance = units.decodeValue "0.01mm"
                        repaired_case_count = 0
                        welded_vertex_count = 0
                        material_face_count = 0
                        build_succeeded = true
                        saved_selection = selection as array
                        saved_sub_object_level = try (subObjectLevel) catch (0)
                        saved_current_object = try (modPanel.getCurrentObject()) catch (undefined)

                        undo "Wall Thickness - Fix T Edge Corners" on
                        (
                                try
                                (
                                        /*
                                        Required order:
                                        EXTRUDE -> FIX INNER CORNERS -> FIX T EDGE CORNERS.
                                        Remove only the obsolete 0.942/0.943 T-edge modifier if it exists.
                                        */
                                        removeWallThicknessTEdgeFixModifier source_node
                                        update source_node

                                        thickness_modifier = getWallThicknessModifier source_node

                                        if thickness_modifier != undefined then
                                        (
                                                inner_result = fixWallThicknessInnerCorners source_node
                                                if inner_result == undefined then throw "FIX INNER CORNERS did not return a result"
                                                if inner_result[1] != true then throw "FIX INNER CORNERS must succeed before FIX T EDGE CORNERS"
                                                update source_node
                                        )

                                        /*
                                        Same direct-write path as FIX INNER CORNERS:
                                        bake the exact evaluated result before topology editing.
                                        */
                                        if classOf source_node.baseObject != Editable_Poly or source_node.modifiers.count > 0 then
                                        (
                                                convertToPoly source_node
                                                update source_node
                                        )

                                        if classOf source_node.baseObject != Editable_Poly then throw "could not bake evaluated FIX INNER CORNERS result to Editable Poly"

                                        try (source_node.showCage = off) catch ()
                                        try (source_node.baseObject.showCage = off) catch ()

                                        poly_object = source_node.baseObject
                                        input_live_vertex_count = source_node.GetNumVertices()
                                        input_polygon_face_count = source_node.GetNumFaces()
                                        input_poly_edge_count = source_node.GetNumEdges()

                                        if source_vert_count < 1 or source_vert_count >= input_live_vertex_count then throw "invalid stored source vertex count"
                                        if source_face_count < 1 or source_face_count > input_polygon_face_count then throw "invalid stored source face count"

                                        detected_cases = detectWallThicknessTEdgeBaseCases source_node source_vert_count source_face_count wall_thickness
                                        format "FIX T EDGE CORNERS BASE DETECT: % case(s)\n" detected_cases.count

                                        for case_data in detected_cases while build_succeeded do
                                        (
                                                anchor_source_id = case_data[1]
                                                branch_neighbor_id = case_data[2]
                                                continuation_source_id = case_data[4]
                                                continuing_plan_source_id = case_data[7]
                                                anchor_fraction_from_source = case_data[8]

                                                generated_anchor_id = anchor_source_id + source_vert_count
                                                generated_continuation_id = continuation_source_id + source_vert_count
                                                generated_plan_id = continuing_plan_source_id + source_vert_count

                                                case_start_vertex_count = source_node.GetNumVertices()
                                                case_start_face_count = source_node.GetNumFaces()
                                                case_start_edge_count = source_node.GetNumEdges()

                                                if findWallThicknessTEdgeBaseEdge source_node anchor_source_id branch_neighbor_id < 1 then throw "could not resolve T branch edge on Editable Poly"
                                                if findWallThicknessTEdgeBaseEdge source_node anchor_source_id generated_anchor_id < 1 then throw "could not resolve upper strip cross-edge on Editable Poly"
                                                if findWallThicknessTEdgeBaseEdge source_node continuation_source_id generated_continuation_id < 1 then throw "could not resolve lower strip cross-edge on Editable Poly"
                                                if findWallThicknessTEdgeBaseEdge source_node generated_anchor_id generated_continuation_id < 1 then throw "could not resolve generated vertical strip edge on Editable Poly"
                                                if findWallThicknessTEdgeBaseEdge source_node generated_anchor_id generated_plan_id < 1 then throw "could not resolve generated continuing wall edge on Editable Poly"

                                                source_anchor_position = source_node.GetVertex anchor_source_id
                                                branch_neighbor_position = source_node.GetVertex branch_neighbor_id
                                                expected_anchor_position = source_anchor_position + ((branch_neighbor_position - source_anchor_position) * anchor_fraction_from_source)

                                                fixed_anchor_vertex_id = divideWallThicknessTEdgeBaseFromVertexFraction source_node anchor_source_id branch_neighbor_id anchor_fraction_from_source
                                                if fixed_anchor_vertex_id < 1 then throw "failed to create fixed T-edge anchor vertex"

                                                fixed_anchor_position = source_node.GetVertex fixed_anchor_vertex_id
                                                if distance fixed_anchor_position expected_anchor_position > tolerance then throw "fixed T-edge anchor did not reach the continuing-wall intersection"

                                                top_cut_vertex_id = divideWallThicknessTEdgeBaseFromVertexFraction source_node anchor_source_id generated_anchor_id 0.5
                                                if top_cut_vertex_id < 1 then throw "failed to create upper strip cut vertex"

                                                bottom_cut_vertex_id = divideWallThicknessTEdgeBaseFromVertexFraction source_node continuation_source_id generated_continuation_id 0.5
                                                if bottom_cut_vertex_id < 1 then throw "failed to create lower strip cut vertex"

                                                if not connectWallThicknessTEdgeBaseVertices source_node fixed_anchor_vertex_id top_cut_vertex_id then throw "failed to connect anchor to upper strip cut"
                                                if not connectWallThicknessTEdgeBaseVertices source_node top_cut_vertex_id bottom_cut_vertex_id then throw "failed to create vertical strip edge"

                                                topology_vertex_count = source_node.GetNumVertices()
                                                topology_face_count = source_node.GetNumFaces()
                                                topology_edge_count = source_node.GetNumEdges()

                                                if topology_vertex_count != (case_start_vertex_count + 3) then throw "new T-edge topology did not add exactly three vertices"
                                                if topology_face_count != (case_start_face_count + 2) then throw "new T-edge topology did not add exactly two polygons"
                                                if topology_edge_count != (case_start_edge_count + 5) then throw "new T-edge topology did not add exactly five edges"

                                                top_cut_position = source_node.GetVertex top_cut_vertex_id
                                                bottom_cut_position = source_node.GetVertex bottom_cut_vertex_id
                                                expected_bottom_after_move = [fixed_anchor_position.x, fixed_anchor_position.y, bottom_cut_position.z]

                                                if not moveWallThicknessTEdgeBaseVerticalCutToAnchor source_node top_cut_vertex_id bottom_cut_vertex_id fixed_anchor_position tolerance then
                                                (
                                                        throw "vertical strip edge did not move onto the fixed anchor in X/Y"
                                                )

                                                moved_top_position = source_node.GetVertex top_cut_vertex_id
                                                moved_bottom_position = source_node.GetVertex bottom_cut_vertex_id

                                                if distance moved_top_position fixed_anchor_position > tolerance then throw "upper strip cut did not coincide with fixed anchor"
                                                if distance moved_bottom_position expected_bottom_after_move > tolerance then throw "lower strip cut did not preserve Z"

                                                /*
                                                The anchor and upper cut are now exactly coincident and connected.
                                                Collapse only that zero-length edge. Since both endpoints have the same
                                                position, the fixed anchor position cannot move.
                                                */
                                                collapse_edge_id = findWallThicknessTEdgeBaseEdge source_node fixed_anchor_vertex_id top_cut_vertex_id
                                                if collapse_edge_id < 1 then throw "could not resolve zero-length anchor edge before weld"

                                                before_weld_vertex_count = source_node.GetNumVertices()
                                                before_weld_face_count = source_node.GetNumFaces()
                                                before_weld_edge_count = source_node.GetNumEdges()

                                                collapse_edges = #{}
                                                collapse_edges[collapse_edge_id] = true
                                                polyop.collapseEdges poly_object collapse_edges
                                                polyop.CollapseDeadStructs poly_object
                                                update source_node

                                                after_weld_vertex_count = source_node.GetNumVertices()
                                                after_weld_face_count = source_node.GetNumFaces()
                                                after_weld_edge_count = source_node.GetNumEdges()

                                                if after_weld_vertex_count != (before_weld_vertex_count - 1) then throw "anchor weld did not remove exactly one coincident vertex"
                                                if after_weld_face_count != (before_weld_face_count - 1) then throw "anchor weld did not remove the degenerate polygon"
                                                if after_weld_edge_count != (before_weld_edge_count - 2) then throw "anchor weld did not remove the two redundant edges"

                                                if after_weld_vertex_count != (case_start_vertex_count + 2) then throw "unexpected repaired T-edge vertex count"
                                                if after_weld_face_count != (case_start_face_count + 1) then throw "unexpected repaired T-edge polygon count"
                                                if after_weld_edge_count != (case_start_edge_count + 3) then throw "unexpected repaired T-edge edge count"

                                                surviving_anchor_ids = getWallThicknessTEdgeBaseVerticesAtPosition source_node fixed_anchor_position tolerance
                                                if surviving_anchor_ids.count != 1 then throw "fixed anchor was not uniquely preserved after weld"
                                                surviving_anchor_id = surviving_anchor_ids[1]

                                                surviving_bottom_ids = getWallThicknessTEdgeBaseVerticesAtPosition source_node expected_bottom_after_move tolerance
                                                if surviving_bottom_ids.count != 1 then throw "lower vertical-cut vertex was not preserved after weld"

                                                material_face_count += fixWallThicknessTEdgeBaseGeneratedStripMaterial source_node generated_anchor_id generated_continuation_id surviving_anchor_id

                                                repaired_case_count += 1
                                                welded_vertex_count += 1

                                                format "FIX T EDGE CORNERS BASE: source V% | anchor V% at % | vertical edge moved direct in XY | coincident edge collapsed | lower vertex %\n" anchor_source_id surviving_anchor_id fixed_anchor_position surviving_bottom_ids[1]
                                        )

                                        final_vertex_count = source_node.GetNumVertices()
                                        final_face_count = source_node.GetNumFaces()
                                        final_edge_count = source_node.GetNumEdges()

                                        if final_vertex_count != (input_live_vertex_count + (repaired_case_count * 2)) then throw "unexpected final T-edge vertex count"
                                        if final_face_count != (input_polygon_face_count + repaired_case_count) then throw "unexpected final T-edge polygon count"
                                        if final_edge_count != (input_poly_edge_count + (repaired_case_count * 3)) then throw "unexpected final T-edge edge count"
                                )
                                catch
                                (
                                        build_succeeded = false
                                        try (format "Wall Thickness FIX T EDGE CORNERS ERROR: %\n" (getCurrentException())) catch ()
                                )
                        )

                        try
                        (
                                if saved_selection.count > 0 then select saved_selection else clearSelection()
                                try
                                (
                                        if saved_current_object != undefined then modPanel.setCurrentObject saved_current_object
                                )
                                catch ()
                                subObjectLevel = saved_sub_object_level
                        )
                        catch ()

                        completeRedraw()
                        format "Wall Thickness FIX T EDGE CORNERS %: detected/repaired % | welded % | material polygons corrected % | direct Editable Poly:%\n" wall_thickness_file_version repaired_case_count welded_vertex_count material_face_count (classOf source_node.baseObject == Editable_Poly)
                        #(build_succeeded, repaired_case_count, welded_vertex_count, material_face_count)
                )
        )
        -- return
)


/*
Tests direct T-edge cut movement when the two cut vertices start with different XY.
Both vertices must land on exact anchor XY while each original Z remains unchanged.
*/
function testWallThicknessTEdgeSkewedVerticalCut =
(
        tolerance = units.decodeValue "0.01mm"
        skew_amount = units.decodeValue "0.02mm"
        top_start_position = [0, 0, units.decodeValue "100mm"]
        bottom_start_position = [skew_amount, 0, 0]
        fixed_anchor_position = [units.decodeValue "250mm", units.decodeValue "125mm", 0]


        undo "Create T Edge Skew Test" on
        (
                test_node = box length:(units.decodeValue "1m") width:(units.decodeValue "1m") height:(units.decodeValue "1m")
                test_node.name = "TEST T EDGE SKEWED CUT"
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
                try (test_node.baseObject.showCage = off) catch ()


                top_vertex_id = 1
                bottom_vertex_id = 2
                top_bits = #{}
                top_bits[top_vertex_id] = true
                bottom_bits = #{}
                bottom_bits[bottom_vertex_id] = true


                polyop.setVert test_node.baseObject top_bits top_start_position
                polyop.setVert test_node.baseObject bottom_bits bottom_start_position
                update test_node
        )


        original_top_position = test_node.GetVertex top_vertex_id
        original_bottom_position = test_node.GetVertex bottom_vertex_id


        undo "Move T Edge Skew Test Cut" on
        (
                move_succeeded = moveWallThicknessTEdgeBaseVerticalCutToAnchor test_node top_vertex_id bottom_vertex_id fixed_anchor_position tolerance
        )


        moved_top_position = test_node.GetVertex top_vertex_id
        moved_bottom_position = test_node.GetVertex bottom_vertex_id


        top_matches =
                abs (moved_top_position.x - fixed_anchor_position.x) <= tolerance and
                abs (moved_top_position.y - fixed_anchor_position.y) <= tolerance and
                moved_top_position.z == original_top_position.z


        bottom_matches =
                abs (moved_bottom_position.x - fixed_anchor_position.x) <= tolerance and
                abs (moved_bottom_position.y - fixed_anchor_position.y) <= tolerance and
                moved_bottom_position.z == original_bottom_position.z


        test_passed = move_succeeded and top_matches and bottom_matches
        format "Wall Thickness T EDGE SKEWED CUT TEST: % | top:% -> % | bottom:% -> % | anchor:%\n" (if test_passed then "PASS" else "FAIL") original_top_position moved_top_position original_bottom_position moved_bottom_position fixed_anchor_position
        format "Undo order: Move T Edge Skew Test Cut, Create T Edge Skew Test.\n"
        test_passed
        -- return
)


/*
Runs a focused regression check on the currently selected extruded wall.
The expected final topology per repaired T-edge is +2 vertices, +1 polygon, and +3 polygon edges.
*/
/*
Runs a focused regression check on the currently selected extruded wall.
FIX T EDGE CORNERS now writes directly to the baked Editable Poly, exactly like FIX INNER CORNERS.
Expected net topology per repaired T-edge: +2 vertices, +1 polygon, +3 polygon edges.
*/
function testWallThicknessTEdgeCornersSelected =
(
        if selection.count != 1 then
        (
                format "Wall Thickness FIX T EDGE CORNERS TEST: FAIL - select exactly one wall object.\n"
                false
        )
        else
        (
                test_node = selection[1]
                removeWallThicknessTEdgeFixModifier test_node
                update test_node

                before_modifier = Edit_Poly()
                before_modifier.name = "__FIX T EDGE TEST INPUT__"
                before_modifier.showCage = off
                addModifier test_node before_modifier
                before_modifier.SetPrimaryNode test_node
                before_vertex_count = EditPolyMod.GetNumVertices before_modifier node:test_node
                before_face_count = EditPolyMod.GetNumFaces before_modifier node:test_node
                before_edge_count = EditPolyMod.GetNumEdges before_modifier node:test_node
                deleteModifier test_node before_modifier
                update test_node

                result_data = fixWallThicknessTEdgeCorners test_node

                after_vertex_count = 0
                after_face_count = 0
                after_edge_count = 0

                if classOf test_node.baseObject == Editable_Poly then
                (
                        after_vertex_count = test_node.GetNumVertices()
                        after_face_count = test_node.GetNumFaces()
                        after_edge_count = test_node.GetNumEdges()
                )

                expected_vertex_count = before_vertex_count + (result_data[2] * 2)
                expected_face_count = before_face_count + result_data[2]
                expected_edge_count = before_edge_count + (result_data[2] * 3)

                test_passed =
                        result_data[1] and
                        after_vertex_count == expected_vertex_count and
                        after_face_count == expected_face_count and
                        after_edge_count == expected_edge_count

                format "Wall Thickness FIX T EDGE CORNERS TEST: % | cases:% | verts:% -> % expected:% | polygons:% -> % expected:% | edges:% -> % expected:%\n" (if test_passed then "PASS" else "FAIL") result_data[2] before_vertex_count after_vertex_count expected_vertex_count before_face_count after_face_count expected_face_count before_edge_count after_edge_count expected_edge_count
                test_passed
        )
        -- return
)


/*
Removes repeated vertex IDs from one generated polygon while preserving winding order.
This turns a collapsed border quad into a valid triangle instead of leaving a hole.
*/
function getWallThicknessUniqueFaceVertices vertex_ids =
(
        unique_ids = #()
        for vertex_id in vertex_ids do
        (
                if (unique_ids.count == 0) or (unique_ids[unique_ids.count] != vertex_id) then
                (
                        append unique_ids vertex_id
                )
        )
        if (unique_ids.count > 1) and (unique_ids[1] == unique_ids[unique_ids.count]) then
        (
                deleteItem unique_ids unique_ids.count
        )
        unique_ids
        -- return
)


/*
Builds the finalized Edit Poly using one generated vertex per collapse group.
Degenerate inner triangles are skipped and collapsed border quads become triangles so the shell can remain closed.
*/
function buildFinishedWallThicknessModifier source_node source_mesh corrected_positions collapse_roots thickness =
(
        preview_modifier = getWallThicknessModifier source_node
        if preview_modifier == undefined then
        (
                #(false, -1, 0, 0)
        )
        else
        (
                preview_was_enabled = preview_modifier.enabled
                final_modifier = undefined
                build_succeeded = false
                open_edge_count = -1
                skipped_inner_faces = 0
                triangular_border_faces = 0
                try
                (
                        preview_modifier.enabled = false
                        final_modifier = Edit_Poly()
                        final_modifier.name = "__WALL THICKNESS FINISH__"
                        final_modifier.showCage = off
                        addModifier source_node final_modifier


                        source_vert_count = meshop.getNumVerts source_mesh
                        source_tri_face_count = meshop.getNumFaces source_mesh
                        modifier_source_vert_count = final_modifier.GetNumVertices node:source_node
                        modifier_source_face_count = final_modifier.GetNumFaces node:source_node
                        if (modifier_source_vert_count == source_vert_count) and (corrected_positions.count == source_vert_count) and (collapse_roots.count == source_vert_count) then
                        (
                                if modifier_source_face_count > 0 then
                                (
                                        setEditPolyMaterialID final_modifier source_node #{1..modifier_source_face_count} 1
                                )


                                offset_vertex_ids = for vertex_id = 1 to source_vert_count collect 0
                                root_vertex_ids = for vertex_id = 1 to source_vert_count collect 0
                                inner_face_ids = #{}
                                strip_face_ids = #{}
                                final_modifier.SetOperation #Create


                                for vertex_id = 1 to source_vert_count do
                                (
                                        root_id = collapse_roots[vertex_id]
                                        if root_vertex_ids[root_id] == 0 then
                                        (
                                                root_vertex_ids[root_id] = final_modifier.CreateVertex corrected_positions[root_id] node:source_node
                                        )
                                        offset_vertex_ids[vertex_id] = root_vertex_ids[root_id]
                                )


                                for face_id = 1 to source_tri_face_count do
                                (
                                        source_face = getFace source_mesh face_id
                                        vertex_a = offset_vertex_ids[source_face.z]
                                        vertex_b = offset_vertex_ids[source_face.y]
                                        vertex_c = offset_vertex_ids[source_face.x]
                                        if (vertex_a != vertex_b) and (vertex_b != vertex_c) and (vertex_c != vertex_a) then
                                        (
                                                new_face_id = final_modifier.CreateFace #(vertex_a, vertex_b, vertex_c) node:source_node
                                                if new_face_id != undefined then
                                                (
                                                        inner_face_ids[new_face_id] = true
                                                )
                                        )
                                        else
                                        (
                                                skipped_inner_faces += 1
                                        )
                                )


                                source_open_edges = meshop.getOpenEdges source_mesh
                                for edge_id in source_open_edges do
                                (
                                        edge_vertices = getMeshEdgeVertices source_mesh edge_id
                                        if edge_vertices != undefined then
                                        (
                                                vertex_a = edge_vertices.x as integer
                                                vertex_b = edge_vertices.y as integer
                                                offset_a = offset_vertex_ids[vertex_a]
                                                offset_b = offset_vertex_ids[vertex_b]
                                                border_vertices = getWallThicknessUniqueFaceVertices #(vertex_a, vertex_b, offset_b, offset_a)
                                                if border_vertices.count >= 3 then
                                                (
                                                        new_face_id = final_modifier.CreateFace border_vertices node:source_node
                                                        if new_face_id != undefined then
                                                        (
                                                                strip_face_ids[new_face_id] = true
                                                                if border_vertices.count == 3 then
                                                                (
                                                                        triangular_border_faces += 1
                                                                )
                                                        )
                                                )
                                        )
                                )


                                final_modifier.Commit()
                                setEditPolyMaterialID final_modifier source_node inner_face_ids 2
                                setEditPolyMaterialID final_modifier source_node strip_face_ids 3
                                autoSmoothWallThicknessGeneratedFaces final_modifier source_node inner_face_ids strip_face_ids
                                empty_faces = #{}
                                final_modifier.SetSelection #Face empty_faces node:source_node
                                final_modifier.RefreshScreen()


                                validation_mesh = snapshotAsMesh source_node
                                if validation_mesh != undefined then
                                (
                                        open_edge_count = (meshop.getOpenEdges validation_mesh).numberSet
                                        free validation_mesh
                                )


                                deleteModifier source_node preview_modifier
                                final_modifier.name = wall_thickness_finished_modifier_name
                                final_modifier.showCage = off
                                build_succeeded = true
                        )


                        if not build_succeeded then
                        (
                                if final_modifier != undefined then
                                (
                                        deleteModifier source_node final_modifier
                                )
                                preview_modifier.enabled = preview_was_enabled
                        )
                )
                catch
                (
                        if final_modifier != undefined then
                        (
                                try
                                (
                                        deleteModifier source_node final_modifier
                                )
                                catch
                                (
                                )
                        )
                        if isValidNode source_node then
                        (
                                try
                                (
                                        preview_modifier.enabled = preview_was_enabled
                                )
                                catch
                                (
                                )
                        )
                        build_succeeded = false
                        open_edge_count = -1
                )
                #(build_succeeded, open_edge_count, skipped_inner_faces, triangular_border_faces)
        )
        -- return
)


/*
Returns the exact Wall Thickness script file that launched the current tool.
A sibling Wall-Thickness.ms is only a fallback because it may be an older stale copy.
*/
function getLatestWallThicknessScriptPath =
(
        source_path = wall_thickness_source_file_path
        resolved_path = undefined
        source_folder = ""


        if source_path != undefined and source_path != "" then
        (
                source_folder = getFilenamePath source_path
                if doesFileExist source_path then resolved_path = source_path
        )


        if resolved_path == undefined then
        (
                runtime_source_path = getSourceFileName()


                if runtime_source_path != undefined and runtime_source_path != "" then
                (
                        if source_folder == "" then source_folder = getFilenamePath runtime_source_path
                        if doesFileExist runtime_source_path then resolved_path = runtime_source_path
                )
        )


        if resolved_path == undefined and source_folder != "" then
        (
                canonical_path = source_folder + "Wall-Thickness.ms"
                if doesFileExist canonical_path then resolved_path = canonical_path
        )


        resolved_path
        -- return
)


/*
Reloads the exact script file that launched the current Wall Thickness tool.
The fixed-name sibling is used only when the original source file no longer exists.
*/
function loadLatestWallThicknessVersion =
(
        latest_script_path = getLatestWallThicknessScriptPath()


        if latest_script_path == undefined or not doesFileExist latest_script_path then
        (
                messageBox "Cannot find the Wall Thickness source script." title:"Wall Thickness"
                false
        )
        else
        (
                fileIn latest_script_path
                true
        )
        -- return
)


/*
Returns the Edit Poly currently active in the Modify panel for one node.
The modifier must belong to that node; no modifier is created.
*/
function getWallThicknessCurrentEditPolyModifier source_node =
(
        current_modifier = undefined
        modifier_index = undefined


        if isValidNode source_node then
        (
                try
                (
                        max modify mode
                        current_modifier = modPanel.getCurrentObject()
                )
                catch
                (
                        current_modifier = undefined
                )


                if current_modifier != undefined and classOf current_modifier == Edit_Poly then
                (
                        try
                        (
                                modifier_index = modPanel.getModifierIndex source_node current_modifier
                        )
                        catch
                        (
                                modifier_index = undefined
                        )
                )
        )


        if modifier_index == undefined then undefined else current_modifier
        -- return
)


/*
Returns the highest existing Edit Poly modifier on one node.
This is only a no-new-modifier fallback for whole-object smoothing reset.
*/
function getWallThicknessTopEditPolyModifier source_node =
(
        edit_modifier = undefined


        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while edit_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if classOf test_modifier == Edit_Poly then edit_modifier = test_modifier
                )
        )


        edit_modifier
        -- return
)


/*
Clears smoothing groups on every face represented by one existing Edit Poly.
The Set Smooth operation is committed into that same modifier; no modifier is added.
*/
function clearWallSmoothingGroupsOnEditPoly source_node edit_modifier =
(
        cleared = false


        if isValidNode source_node and edit_modifier != undefined and classOf edit_modifier == Edit_Poly then
        (
                try
                (
                        prepared = WallThicknessPreprocess.prepareEditPoly source_node edit_modifier selection_level:#Face


                        if prepared then
                        (
                                face_count = edit_modifier.GetNumFaces node:source_node
                                if face_count > 0 then
                                (
                                        all_faces = #{1..face_count}
                                        edit_modifier.SetSelection #Face all_faces node:source_node
                                        edit_modifier.smoothingGroupsToSet = 0
                                        edit_modifier.smoothingGroupsToClear = -1
                                        edit_modifier.SetOperation #SetSmooth
                                        edit_modifier.Commit()
                                        edit_modifier.SetSelection #Face #{} node:source_node
                                        subObjectLevel = 0
                                )


                                update source_node
                                cleared = true
                        )
                )
                catch
                (
                        cleared = false
                )
        )


        cleared
        -- return
)


/*
Clears smoothing groups directly on an Editable Poly base object.
This is the no-modifier fallback when the object has no Edit Poly modifier.
*/
function clearWallSmoothingGroupsOnEditablePoly source_node =
(
        cleared = false


        if isValidNode source_node and classOf source_node.baseObject == Editable_Poly then
        (
                try
                (
                        face_count = polyop.getNumFaces source_node.baseObject
                        if face_count > 0 then
                        (
                                polyop.setFaceSmoothGroup source_node.baseObject #{1..face_count} 0
                        )


                        update source_node
                        cleared = true
                )
                catch
                (
                        cleared = false
                )
        )


        cleared
        -- return
)


/*
Runs PolyTools Quadrify only on the Edit Poly currently active in the Modify panel.
No cleanup modifier is created, removed, renamed, or rebuilt.
*/
function quadrifyCurrentWallThicknessModifier source_node =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                false
        )
        else
        (
                current_modifier = getWallThicknessCurrentEditPolyModifier source_node


                if current_modifier == undefined then
                (
                        messageBox "Make an Edit Poly modifier current before using CLEANUP." title:"Wall Thickness"
                        false
                )
                else
                (
                        quadrify_succeeded = false


                        undo "Wall Thickness - Quadrify Current Modifier" on
                        (
                                try
                                (
                                        select source_node
                                        max modify mode
                                        prepared = WallThicknessPreprocess.prepareEditPoly source_node current_modifier selection_level:#Object


                                        if prepared then
                                        (
                                                modPanel.setCurrentObject current_modifier node:source_node
                                                subObjectLevel = 0
                                                macros.run "PolyTools" "Quadrify"
                                                update source_node
                                                quadrify_succeeded = true
                                        )
                                )
                                catch
                                (
                                        quadrify_succeeded = false
                                )
                        )


                        completeRedraw()


                        if not quadrify_succeeded then
                        (
                                messageBox "Quadrify failed on the current Edit Poly modifier." title:"Wall Thickness"
                        )


                        quadrify_succeeded
                )
        )
        -- return
)


/*
Runs CLEANUP as a non-collapsing history above WALL THICKNESS.
Only stages that actually change evaluated geometry remain in the modifier stack.
*/
function cleanupWallThickness source_node =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                false
        )
        else
        (
                preview_modifier = getWallThicknessModifier source_node
                if preview_modifier == undefined then
                (
                        messageBox "Create a live thickness preview before using CLEANUP." title:"Wall Thickness"
                        false
                )
                else
                (
                        cleanup_data = undefined
                        preprocess_data = undefined
                        quadrify_data = #(false, false)
                        cleanup_succeeded = false


                        undo "Cleanup Wall Thickness" on
                        (
                                setWallThicknessCleanupComplete source_node false
                                removeWallThicknessSTLCheckModifier source_node
                                removeWallThicknessInnerCornerWeldModifier source_node
                                removeWallThicknessInnerCornerFixModifier source_node
                                removeWallThicknessTEdgeFixModifier source_node
                                removeWallThicknessChamferWeldModifier source_node
                                removeWallThicknessChamferFixModifier source_node
                                removeWallThicknessLegacyChamferModifiers source_node
                                removeWallThicknessCleanupModifier source_node
                                removeWallThicknessCleanupStageModifiers source_node


                                quadrify_data = quadrifyWallThicknessModifier source_node
                                if quadrify_data[1] then
                                (
                                        preprocess_data = preProcessWallThicknessGeometryFix source_node
                                        if preprocess_data[1] then
                                        (
                                                cleanup_data = postProcessWallThicknessCleanup source_node
                                                if cleanup_data[1] then
                                                (
                                                        cleanup_succeeded = true
                                                        setWallThicknessCleanupComplete source_node true
                                                )
                                        )
                                )
                        )


                        if cleanup_succeeded then
                        (
                                cleanup_changed = quadrify_data[2] or preprocess_data[4] or preprocess_data[5] or preprocess_data[6] or (cleanup_data[3] > 0)
                                format "Wall Thickness CLEANUP: changed:% | quadrify:% | cap:% | weld:% | multiple:% | deleted faces:% | loop fills:% | open edges:% -> %.\n" cleanup_changed quadrify_data[2] preprocess_data[4] preprocess_data[5] preprocess_data[6] preprocess_data[3] cleanup_data[3] cleanup_data[6] cleanup_data[7]
                                subObjectLevel = 0
                                completeRedraw()
                                true
                        )
                        else
                        (
                                setWallThicknessCleanupComplete source_node false
                                messageBox "CLEANUP failed. Only cleanup stages that changed geometry are kept; RESET removes the remaining Wall Thickness history." title:"Wall Thickness"
                                false
                        )
                )
        )
        -- return
)


/*
Clears smoothing groups across every face without adding a modifier.
The current Edit Poly is preferred, then the highest existing Edit Poly, then the Editable Poly base.
*/
function clearWallSmoothingGroups =
(
        if selection.count == 0 then
        (
                messageBox "Select at least one wall object." title:"Wall Thickness"
                false
        )
        else
        (
                clear_succeeded = true


                undo "Clear Smoothing Groups" on
                (
                        for source_node in selection do
                        (
                                source_cleared = false
                                edit_modifier = getWallThicknessCurrentEditPolyModifier source_node


                                if edit_modifier == undefined then
                                (
                                        edit_modifier = getWallThicknessTopEditPolyModifier source_node
                                )


                                if edit_modifier != undefined then
                                (
                                        source_cleared = clearWallSmoothingGroupsOnEditPoly source_node edit_modifier
                                )
                                else
                                (
                                        source_cleared = clearWallSmoothingGroupsOnEditablePoly source_node
                                )


                                if not source_cleared then clear_succeeded = false
                        )
                )


                completeRedraw()


                if not clear_succeeded then
                (
                        messageBox "Smoothing groups could not be cleared on one or more selected objects." title:"Wall Thickness"
                )


                clear_succeeded
        )
        -- return
)


/*
Quadrifies the angle-test wall in a dedicated Edit Poly modifier.
The modifier is left visible so the quad result can be inspected directly.
*/
function quadrifyWallThicknessTestObject test_node =
(
        if not isValidNode test_node then
        (
                false
        )
        else
        (
                quadrify_succeeded = false
                quadrify_modifier = Edit_Poly()
                quadrify_modifier.name = "TEST QUADRIFY"
                quadrify_modifier.showCage = off
                addModifier test_node quadrify_modifier


                try
                (
                        select test_node
                        max modify mode
                        WallThicknessPreprocess.prepareEditPoly test_node quadrify_modifier selection_level:#Object
                        modPanel.setCurrentObject quadrify_modifier node:test_node
                        subObjectLevel = 0
                        macros.run "PolyTools" "Quadrify"
                        update test_node
                        quadrify_succeeded = clearWallSmoothingGroupsOnEditPoly test_node quadrify_modifier
                )
                catch
                (
                        try (deleteModifier test_node quadrify_modifier) catch ()
                        quadrify_succeeded = false
                )


                quadrify_succeeded
        )
        -- return
)


/*
Creates the current uploaded complex source/outer-wall reference used for Wall Thickness testing.
RMB on CREATE ANGLE TEST WALLS calls this function; topology, coordinates, material ID 1, smoothing 0, and WallThickness 0.35 come from the uploaded diagnostic.
*/
function createWallThicknessUploadedTest =
(
        test_vertices = #(
                [-3.75159,-10.3163,3.78754],
                [-3.64014,-10.2408,3.78754],
                [2.60706,-6.00934,3.78754],
                [4.76929,7.36407,-2.78748],
                [4.76929,7.36414,-2.93628],
                [5.14587,7.61926,-2.93634],
                [5.14587,7.61926,-2.78748],
                [1.94604,5.45178,-2.78748],
                [1.94604,5.45178,-2.93622],
                [2.07837,5.54163,-2.93622],
                [2.07837,5.54163,-2.78748],
                [4.76929,7.36407,-1.13684],
                [5.146,7.61926,-1.1369],
                [1.08069,4.86572,0.587158],
                [1.08069,4.86572,0.437561],
                [1.58582,5.20782,0.437561],
                [-2.92261,2.1543,0.587524],
                [-2.92249,2.1543,0.437561],
                [-1.22925,3.30115,0.437561],
                [1.08069,4.86572,2.23749],
                [-2.92249,2.1543,2.23755],
                [-1.22925,3.30109,2.23755],
                [-1.22925,3.30115,3.78754],
                [-2.92249,2.1543,3.78754],
                [1.94604,5.45172,-1.13684],
                [2.07837,5.54156,-1.13684],
                [1.08069,4.86578,3.78754],
                [1.58569,5.20795,3.78754],
                [1.94592,5.4519,3.78754],
                [2.07837,5.54163,3.78754],
                [2.19421,5.62006,3.78754],
                [-2.51855,1.55817,2.23755],
                [-2.51855,1.55817,0.587402],
                [2.36316,-5.64917,0.586853],
                [2.36316,-5.64917,0.437561],
                [1.76587,-4.7674,0.437561],
                [-2.51855,1.55817,0.437561],
                [2.60706,-6.00934,2.23669],
                [2.60706,-6.00934,0.586792],
                [1.76587,-4.7674,3.78754],
                [2.36316,-5.64917,3.78754],
                [-2.51855,1.55811,3.78754],
                [2.03296,5.32349,-1.13684],
                [2.03284,5.32349,-2.78748],
                [5.6051,0.0494385,-3.78748],
                [4.6405,1.47345,-3.78748],
                [4.6405,1.47351,-2.93597],
                [5.6051,0.0494385,-2.93585],
                [2.03284,5.32349,-2.93616],
                [4.6405,1.47351,-2.78748],
                [5.60522,0.0494385,-1.13727],
                [5.6051,0.0494385,-2.78748],
                [7.47534,-2.71185,-1.13757],
                [7.47534,-2.71185,-2.78748],
                [7.23157,-2.35162,-2.78748],
                [7.04639,-2.07837,-2.78748],
                [7.23145,-2.35168,0.586914],
                [7.45276,-2.72717,0.437561],
                [7.23132,-2.35168,0.437561],
                [1.95044,5.98016,0.587402],
                [1.95044,5.98016,0.437561],
                [0.556763,8.03766,0.437561],
                [1.95032,5.9801,2.23755],
                [0.556641,8.03766,2.23773],
                [0.556763,8.0376,3.78754],
                [1.95044,5.9801,3.78754],
                [-7.47546,6.52246,0.437561],
                [-7.47546,6.52246,-0.412476],
                [-7.47546,6.52246,3.78754],
                [-7.47546,6.52246,2.23816],
                [-1.87439,10.3163,0.437561],
                [-1.87439,10.3163,3.78754],
                [-1.87439,10.3163,-0.412476],
                [2.07849,5.54156,0.437561],
                [1.94604,5.45166,0.437561],
                [4.76917,7.36414,0.437561],
                [2.19421,5.62,0.437561],
                [2.19421,5.62,-1.13684],
                [5.14587,7.61926,0.437561],
                [7.04626,-2.07849,0.437561],
                [5.60498,0.0493774,0.437561],
                [4.6405,1.47345,0.437561],
                [2.03284,5.32349,0.437561],
                [4.76929,7.36407,-3.78748],
                [5.14587,7.61926,-3.78748],
                [1.94592,5.45178,-3.78748],
                [2.07837,5.54156,-3.78748],
                [2.03284,5.32349,-3.78748],
                [1.08069,4.86572,-0.412476],
                [1.58582,5.20782,-0.412476],
                [-2.92249,2.1543,-0.412476],
                [-1.22925,3.30109,-0.412476],
                [2.36316,-5.64917,-0.412476],
                [1.76587,-4.7674,-0.412476],
                [-2.51855,1.55817,-0.412476],
                [1.95044,5.98016,-0.412476],
                [0.556763,8.03766,-0.412476],
                [-3.75146,-10.3163,0.58728],
                [-3.64014,-10.2408,-2.78748],
                [2.60706,-6.0094,-2.78748],
                [2.99609,-5.74579,0.586792],
                [2.79321,-5.88318,0.586792],
                [2.79321,-5.88318,-2.78748],
                [2.99609,-5.74573,-2.78748],
                [4.81763,-4.51196,-2.78748],
                [5.02466,-4.37177,-2.78748],
                [5.02466,-4.37177,0.587036],
                [-3.75159,-10.3163,-2.78748],
                [1.58582,5.20782,0.587158],
                [-1.22925,3.30115,0.587402],
                [0.556763,8.03766,0.587463],
                [-7.47546,6.52246,0.587646],
                [2.07849,5.54156,0.587158],
                [1.94604,5.45172,0.587158],
                [4.76917,7.36414,0.587097],
                [2.19421,5.62,0.587158],
                [5.14587,7.61926,0.58728],
                [2.03284,5.32349,0.587158],
                [-3.64014,-10.2407,0.587219],
                [1.76587,-4.7674,0.586914],
                [-1.87439,10.3163,0.587585],
                [7.04639,-2.07849,0.586975],
                [5.60498,0.0493774,0.587036],
                [4.64062,1.47345,0.587158],
                [4.81763,-4.51196,0.587036],
                [7.45276,-2.72717,0.586914],
                [1.58569,5.20789,2.23749],
                [1.94592,5.4519,2.23749],
                [2.07837,5.54163,2.23743],
                [2.19421,5.62006,2.23743],
                [2.36316,-5.64917,2.23682],
                [1.76587,-4.7674,2.23682],
                [-1.87439,10.3163,2.23804],
                [-3.75146,-10.3163,2.23615],
                [-3.64014,-10.2408,2.23615],
                [4.6405,1.47345,-1.13721],
                [7.23145,-2.35168,-1.13751],
                [7.04639,-2.07837,-1.13745],
                [4.81763,-4.51196,-1.13837],
                [-3.64014,-10.2408,-1.13806],
                [2.60706,-6.0094,-1.13831],
                [2.79321,-5.88318,-1.13831],
                [2.99609,-5.74573,-1.13831],
                [-3.75146,-10.3163,-1.13806],
                [5.02466,-4.37177,-1.13837],
                [-3.64014,-10.2407,0.437561],
                [2.60706,-6.00934,0.437561],
                [2.79321,-5.88312,0.437561],
                [2.99622,-5.74573,0.437561],
                [5.02466,-4.37177,0.437561],
                [4.81763,-4.51196,0.437561],
                [-3.75146,-10.3163,0.437603],
                [-0.51654,-8.12509,3.78754],
                [-0.516541,-8.12509,-2.78748],
                [-0.516541,-8.12503,0.587006],
                [-0.51654,-8.12509,2.23642],
                [-0.516541,-8.12509,-1.13818],
                [-0.516541,-8.125,0.437561],
                [-2.07834,-9.18294,-2.78748],
                [-2.07834,-9.18288,0.587112],
                [-2.07834,-9.18294,-1.13812],
                [-2.07834,-9.18283,0.437561],
                [-2.07834,-9.18297,3.78754],
                [-2.07834,-9.18297,2.23628]
        )


        test_faces = #(
                [5,6,7],
                [7,4,5],
                [9,10,11],
                [11,8,9],
                [4,7,13],
                [13,12,4],
                [17,110,22],
                [22,21,17],
                [23,24,21],
                [21,22,23],
                [26,25,8],
                [8,11,26],
                [20,27,23],
                [23,22,20],
                [127,28,27],
                [27,20,127],
                [114,128,127],
                [127,109,114],
                [128,29,28],
                [28,127,128],
                [113,129,128],
                [128,114,113],
                [129,30,29],
                [29,128,129],
                [116,130,129],
                [129,113,116],
                [130,31,30],
                [30,129,130],
                [33,17,21],
                [21,32,33],
                [132,40,41],
                [41,131,132],
                [120,132,131],
                [131,34,120],
                [32,42,40],
                [40,132,32],
                [21,24,42],
                [42,32,21],
                [43,44,8],
                [8,25,43],
                [46,47,48],
                [48,45,46],
                [49,9,8],
                [8,44,49],
                [136,51,52],
                [52,50,136],
                [56,138,137],
                [137,55,56],
                [31,130,63],
                [63,66,31],
                [73,68,67],
                [67,71,73],
                [74,75,25],
                [25,26,74],
                [76,77,78],
                [78,12,76],
                [77,74,26],
                [26,78,77],
                [79,76,12],
                [12,13,79],
                [80,59,137],
                [137,138,80],
                [81,80,138],
                [138,51,81],
                [82,81,51],
                [51,136,82],
                [83,82,136],
                [136,43,83],
                [75,83,43],
                [43,25,75],
                [84,85,6],
                [6,5,84],
                [86,87,10],
                [10,9,86],
                [50,52,48],
                [48,47,50],
                [88,86,9],
                [9,49,88],
                [89,90,16],
                [16,15,89],
                [91,92,19],
                [19,18,91],
                [93,94,36],
                [36,35,93],
                [95,91,18],
                [18,37,95],
                [53,137,59],
                [59,58,53],
                [96,97,62],
                [62,61,96],
                [113,114,75],
                [75,74,113],
                [115,116,77],
                [77,76,115],
                [116,113,74],
                [74,77,116],
                [117,115,76],
                [76,79,117],
                [122,57,59],
                [59,80,122],
                [123,122,80],
                [80,81,123],
                [124,123,81],
                [81,82,124],
                [118,124,82],
                [82,83,118],
                [114,118,83],
                [83,75,114],
                [2,1,134],
                [134,135,2],
                [139,143,104],
                [104,105,139],
                [145,139,105],
                [105,106,145],
                [142,141,100],
                [100,103,142],
                [15,16,109],
                [109,14,15],
                [18,19,110],
                [110,17,18],
                [37,18,17],
                [17,33,37],
                [61,62,111],
                [111,60,61],
                [71,67,112],
                [112,121,71],
                [38,156,155],
                [155,39,38],
                [35,36,120],
                [120,34,35],
                [64,63,60],
                [60,111,64],
                [70,133,121],
                [121,112,70],
                [146,162,160],
                [160,119,146],
                [148,149,101],
                [101,102,148],
                [152,146,119],
                [119,98,152],
                [58,59,57],
                [57,126,58],
                [14,109,127],
                [127,20,14],
                [39,34,131],
                [131,38,39],
                [116,60,63],
                [63,130,116],
                [65,66,63],
                [63,64,65],
                [69,72,133],
                [133,70,69],
                [98,119,135],
                [135,134,98],
                [3,153,156],
                [156,38,3],
                [54,55,137],
                [137,53,54],
                [151,149,143],
                [143,139,151],
                [150,151,139],
                [139,145,150],
                [53,58,150],
                [150,145,53],
                [148,147,141],
                [141,142,148],
                [99,159,161],
                [161,140,99],
                [103,104,143],
                [143,142,103],
                [108,99,140],
                [140,144,108],
                [140,161,162],
                [162,146,140],
                [142,143,149],
                [149,148,142],
                [125,101,149],
                [149,151,125],
                [107,125,151],
                [151,150,107],
                [58,126,107],
                [107,150,58],
                [102,39,147],
                [147,148,102],
                [106,54,53],
                [53,145,106],
                [38,131,41],
                [41,3,38],
                [144,140,146],
                [146,152,144],
                [164,160,155],
                [155,156,164],
                [147,39,155],
                [155,158,147],
                [163,164,156],
                [156,153,163],
                [100,141,157],
                [157,154,100],
                [141,147,158],
                [158,157,141],
                [158,155,160],
                [160,162,158],
                [154,157,161],
                [161,159,154],
                [157,158,162],
                [162,161,157],
                [135,119,160],
                [160,164,135],
                [2,135,164],
                [164,163,2]
        )


        test_node = mesh vertices:test_vertices faces:test_faces
        test_node.name = uniqueName "WallThickness_ComplexSource_TEST_"
        convertToPoly test_node
        try (test_node.baseObject.showCage = off) catch ()


        all_faces = #{1..210}
        polyop.setFaceMatID test_node all_faces 1
        polyop.setFaceSmoothGroup test_node all_faces 0
        polyop.setFaceSmoothGroup test_node #{187,188} 1


        setUserProp test_node wall_thickness_user_prop 0.2
        setUserProp test_node wall_thickness_source_vert_count_prop 164
        setUserProp test_node wall_thickness_source_face_count_prop 210


        update test_node
        select test_node


        /*
        The uploaded reference has one enabled STRAIGHT EDGE FIXER Edit Poly with faces 70 and 95 selected.
        The evaluated diagnostic geometry is already reconstructed in the base object; this modifier preserves the reference stack/selection context without changing geometry.
        */
        reference_modifier = Edit_Poly()
        reference_modifier.name = "STRAIGHT EDGE FIXER"
        reference_modifier.showCage = off
        addModifier test_node reference_modifier
        if WallThicknessPreprocess.prepareEditPoly test_node reference_modifier selection_level:#Face then
        (
                EditPolyMod.SetSelection reference_modifier #Face #{70,95} node:test_node
                reference_modifier.RefreshScreen()
        )


        quadrify_succeeded = quadrifyWallThicknessTestObject test_node


        centerPivot test_node
        test_node.pos = [0,0,0]
        update test_node


        max modify mode
        subObjectLevel = 0
        completeRedraw()


        format "Wall Thickness COMPLEX SOURCE TEST: base verts:% | base faces:% | Straight Edge Fixer selection:2 | quadrify:% | pivot/position:[0,0,0] | WallThickness:0.2.\n" (polyop.getNumVerts test_node.baseObject) (polyop.getNumFaces test_node.baseObject) quadrify_succeeded
        test_node
        -- return
)


/*
Tests exact reconstruction of the uploaded Object010 diagnostic mesh.
The created object remains in the scene for direct inspection and undo.
*/
function testWallThicknessUploadedTestObject =
(
        test_node = undefined
        undo "Create Complex Wall Thickness Source Test" on
        (
                test_node = createWallThicknessUploadedTest()
        )


        test_passed = isValidNode test_node
        base_verts_ok = false
        base_faces_ok = false
        reference_modifier_ok = false
        reference_selection_ok = false
        quadrify_ok = false
        position_ok = false
        bounds_center_ok = false
        thickness_ok = false
        source_counts_ok = false


        if test_passed then
        (
                base_verts_ok = (polyop.getNumVerts test_node.baseObject == 164)
                base_faces_ok = (polyop.getNumFaces test_node.baseObject == 210)


                reference_modifier = getWallThicknessNamedModifier test_node "STRAIGHT EDGE FIXER"
                reference_modifier_ok = reference_modifier != undefined
                if reference_modifier_ok then
                (
                        reference_selection = reference_modifier.GetSelection #Face node:test_node
                        reference_selection_ok = (reference_selection == #{70,95})
                )


                quadrify_modifier = getWallThicknessNamedModifier test_node "TEST QUADRIFY"
                quadrify_ok = quadrify_modifier != undefined
                position_ok = (distance test_node.pos [0,0,0]) < 0.000001


                bounds_center = (test_node.min + test_node.max) * 0.5
                bounds_center_ok = (length bounds_center) < 0.01


                stored_thickness = getUserProp test_node wall_thickness_user_prop
                thickness_ok = stored_thickness != undefined and (abs ((stored_thickness as float) - 0.2) < 0.000001)


                stored_source_verts = getUserProp test_node wall_thickness_source_vert_count_prop
                stored_source_faces = getUserProp test_node wall_thickness_source_face_count_prop
                source_counts_ok = (stored_source_verts as integer) == 164 and (stored_source_faces as integer) == 210


                test_passed = base_verts_ok and base_faces_ok and reference_modifier_ok and reference_selection_ok and quadrify_ok and position_ok and bounds_center_ok and thickness_ok and source_counts_ok
        )


        format "Wall Thickness COMPLEX SOURCE OBJECT TEST: % | base verts:% | base faces:% | reference modifier:% | faces 70,95:% | quadrify:% | pos0:% | bounds centered:% | thickness/source props:%.\n" (if test_passed then "PASS" else "FAIL") base_verts_ok base_faces_ok reference_modifier_ok reference_selection_ok quadrify_ok position_ok bounds_center_ok (thickness_ok and source_counts_ok)
        format "Undo order: Create Complex Wall Thickness Source Test.\n"
        test_passed
        -- return
)


/*
Creates connected one-sided exterior test walls with varied plan angles directly as a quadrified Editable Poly.
Each wall segment is created as one native quad; no TEST QUADRIFY or other modifier is added.
*/
function createWallThicknessTest =
(
        wall_height = units.decodeValue "4m"
        plan_scale = wall_height / 100.0
        corner_edge_distance = units.decodeValue "0.40m"
        corner_points = #(
                [0, 0, 0],
                [120, 0, 0],
                [120, 90, 0],
                [200, 90, 0],
                [200, 170, 0],
                [155, 225, 0],
                [75, 190, 0],
                [5, 245, 0],
                [-70, 245, 0],
                [-70, 150, 0],
                [-145, 150, 0]
        )


        for point_id = 1 to corner_points.count do
        (
                corner_points[point_id] *= plan_scale
        )


        plan_points = #(corner_points[1])
        for corner_id = 2 to (corner_points.count - 1) do
        (
                previous_point = corner_points[corner_id - 1]
                corner_point = corner_points[corner_id]
                next_point = corner_points[corner_id + 1]
                incoming_vector = previous_point - corner_point
                outgoing_vector = next_point - corner_point
                incoming_length = length incoming_vector
                outgoing_length = length outgoing_vector


                if incoming_length > 0.000001 and outgoing_length > 0.000001 then
                (
                        incoming_distance = amin corner_edge_distance (incoming_length * 0.25)
                        outgoing_distance = amin corner_edge_distance (outgoing_length * 0.25)
                        incoming_point = corner_point + ((normalize incoming_vector) * incoming_distance)
                        outgoing_point = corner_point + ((normalize outgoing_vector) * outgoing_distance)


                        append plan_points incoming_point
                        append plan_points corner_point
                        append plan_points outgoing_point
                )
                else
                (
                        append plan_points corner_point
                )
        )
        append plan_points corner_points[corner_points.count]


        test_node = editable_mesh name:"WallThickness_Angles_TEST"
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        try (test_poly.showCage = off) catch ()


        for plan_point in plan_points do
        (
                polyop.createVert test_poly [plan_point.x, plan_point.y, 0]
                polyop.createVert test_poly [plan_point.x, plan_point.y, wall_height]
        )


        for segment_id = 1 to (plan_points.count - 1) do
        (
                bottom_a = ((segment_id - 1) * 2) + 1
                top_a = bottom_a + 1
                bottom_b = bottom_a + 2
                top_b = bottom_a + 3


                /* One native quad per wall panel keeps the same winding as the former triangle pair. */
                polyop.createPolygon test_poly #(bottom_a, bottom_b, top_b, top_a)
        )


        face_count = polyop.getNumFaces test_poly
        if face_count > 0 then
        (
                all_faces = #{1..face_count}
                polyop.setFaceMatID test_poly all_faces 1
                polyop.setFaceSmoothGroup test_poly all_faces 0
        )


        update test_node
        select test_node
        format "Wall Thickness ANGLE TEST: height 4m | corner support edges:0.40m | vertical edges:% | native quad panels:% | no TEST QUADRIFY modifier.\n" plan_points.count face_count


        test_node
        -- return
)


/*
Tests that the basic angle-test object is generated directly as a quadrified Editable Poly with no TEST QUADRIFY modifier.
The object remains in the scene so the added vertical edges around every interior corner can be inspected directly.
*/
function testWallThicknessAngleTestObject =
(
        test_node = createWallThicknessTest()
        height_ok = false
        no_test_modifier_ok = false
        corner_support_topology_ok = false
        face_degree_ok = true
        smoothing_groups_ok = true


        if isValidNode test_node then
        (
                test_height = test_node.max.z - test_node.min.z
                expected_height = units.decodeValue "4m"
                height_ok = abs (test_height - expected_height) <= (amax 0.001 (expected_height * 0.000001))
                no_test_modifier_ok = getWallThicknessNamedModifier test_node "TEST QUADRIFY" == undefined


                test_poly = test_node.baseObject
                vertex_count = polyop.getNumVerts test_poly
                face_count = polyop.getNumFaces test_poly
                corner_support_topology_ok = vertex_count == 58 and face_count == 28


                for face_id = 1 to face_count while face_degree_ok do
                (
                        face_vertices = polyop.getFaceVerts test_poly face_id
                        face_degree_ok = face_vertices.count == 4
                )


                test_mesh = snapshotAsMesh test_node
                if test_mesh == undefined then
                (
                        smoothing_groups_ok = false
                )
                else
                (
                        mesh_face_count = getNumFaces test_mesh
                        for face_id = 1 to mesh_face_count while smoothing_groups_ok do
                        (
                                smoothing_groups_ok = getFaceSmoothGroup test_mesh face_id == 0
                        )
                        free test_mesh
                )
        )


        test_passed = height_ok and no_test_modifier_ok and corner_support_topology_ok and face_degree_ok and smoothing_groups_ok
        format "Wall Thickness ANGLE TEST OBJECT TEST: % | height 4m:% | 58v/28q:% | no TEST QUADRIFY:% | all native quads:% | smoothing 0:%\n" (if test_passed then "PASS" else "FAIL") height_ok corner_support_topology_ok no_test_modifier_ok face_degree_ok smoothing_groups_ok
        test_passed
        -- return
)


/*
Creates a narrow orthogonal wall path with a run shorter than the requested thickness.
The test validates strict face-normal extrusion and corner stitching without averaged vertex motion.
*/
function createWallThicknessOverlapTest =
(
        test_node = undefined
        undo "Create Wall Thickness Overlap Test" on
        (
                wall_height = 100.0
                plan_points = #(
                        [0, 0, 0],
                        [120, 0, 0],
                        [120, 24, 0],
                        [35, 24, 0],
                        [35, 120, 0]
                )
                test_vertices = #()
                for plan_point in plan_points do
                (
                        append test_vertices [plan_point.x, plan_point.y, 0]
                        append test_vertices [plan_point.x, plan_point.y, wall_height]
                )
                test_faces = #()
                for segment_id = 1 to (plan_points.count - 1) do
                (
                        bottom_a = ((segment_id - 1) * 2) + 1
                        top_a = bottom_a + 1
                        bottom_b = bottom_a + 2
                        top_b = bottom_a + 3
                        append test_faces [bottom_a, bottom_b, top_b]
                        append test_faces [bottom_a, top_b, top_a]
                )
                test_node = mesh vertices:test_vertices faces:test_faces
                test_node.name = "WallThickness_Overlap_TEST"
                convertToPoly test_node
                update test_node
                select test_node
        )
        applyWallThickness test_node 40.0
        test_node
        -- return
)


/*
Runs the strict face-normal shell through the complete non-collapsing CLEANUP history and reports whether open edges remain.
The test object stays in the scene so every preprocessing and cleanup modifier can be inspected directly.
*/
function testWallThicknessFinishOverlap =
(
        test_node = createWallThicknessOverlapTest()
        cleanup_succeeded = cleanupWallThickness test_node
        open_edge_count = -1
        if cleanup_succeeded then
        (
                result_mesh = snapshotAsMesh test_node
                if result_mesh != undefined then
                (
                        open_edge_count = (meshop.getOpenEdges result_mesh).numberSet
                        free result_mesh
                )
        )
        test_passed = cleanup_succeeded and (open_edge_count == 0)
        format "Wall Thickness STRICT NORMAL TEST: % | open edges: %\n" (if test_passed then "PASS" else "FAIL") open_edge_count
        format "Undo order: Cleanup Wall Thickness -> Wall Thickness Preprocess + Thickness -> Create Wall Thickness Overlap Test.\n"
        test_passed
        -- return
)


/*
Runs a practical validation on the selected generated wall.
Checks the Edit Poly modifier and required material IDs 1, 2 and 3.
*/
function testWallThicknessResult =
(
        if selection.count != 1 then
        (
                format "Wall Thickness TEST: FAIL - select one generated wall.\n"
                false
        )
        else
        (
                source_node = selection[1]
                edit_modifier = getWallThicknessModifier source_node
                if edit_modifier == undefined then
                (
                        format "Wall Thickness TEST: FAIL - WALL THICKNESS Edit Poly modifier not found.\n"
                        false
                )
                else
                (
                        face_count = edit_modifier.GetNumFaces node:source_node
                        id_1_count = 0
                        id_2_count = 0
                        id_3_count = 0
                        for face_id = 1 to face_count do
                        (
                                material_id = edit_modifier.GetFaceMaterial face_id node:source_node
                                case material_id of
                                (
                                        1: id_1_count += 1
                                        2: id_2_count += 1
                                        3: id_3_count += 1
                                )
                        )
                        test_passed = (id_1_count > 0) and (id_2_count > 0) and (id_3_count > 0)
                        format "Wall Thickness TEST:\n"
                        format "  Edit Poly: %\n" (classOf edit_modifier == Edit_Poly)
                        format "  Material ID 1 outer/source wall faces: %\n" id_1_count
                        format "  Material ID 2 inner/extruded wall faces: %\n" id_2_count
                        format "  Material ID 3 strip faces: %\n" id_3_count
                        format "  RESULT: %\n" (if test_passed then "PASS" else "FAIL")
                        test_passed
                )
        )
        -- return
)


/*
Tests metric scaled-thickness formatting with the requested 0.003 meter example.
The expected compact result is exactly 3 mm.
*/
function testWallThicknessScaledUnits =
(
        test_value = units.decodeValue "0.003m"
        metric_data = getWallThicknessNiceMetricValue test_value
        test_passed = ((abs (metric_data[1] - 3.0)) < 0.0001) and (metric_data[2] == "mm")
        format "Wall Thickness SCALED UNIT TEST: % | value:% %\n" (if test_passed then "PASS" else "FAIL") metric_data[1] metric_data[2]
        test_passed
        -- return
)


/*
Tests RESET by creating a live thickness modifier and removing it again.
The generated test wall stays in the scene so the modifier stack can be inspected after the test.
*/
function testWallThicknessReset =
(
        test_node = createWallThicknessOverlapTest()
        live_before = getWallThicknessModifier test_node
        reset_succeeded = resetWallThickness test_node
        live_after = getWallThicknessModifier test_node
        finished_after = getFinishedWallThicknessModifier test_node
        test_passed = (live_before != undefined) and reset_succeeded and (live_after == undefined) and (finished_after == undefined)
        format "Wall Thickness RESET TEST: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)


/*
Tests the isolated cleanup builder on one four-edge generated-style hole.
The test leaves the Editable Poly pyramid and cleanup modifier in the scene for inspection.
*/
function testWallThicknessPostProcessCleanup =
(
        test_node = undefined
        undo "Create Wall Thickness Cleanup Test" on
        (
                test_node = mesh name:"WallThickness_Cleanup_Test" vertices:#([0,0,0], [100,0,0], [100,100,0], [0,100,0], [50,50,100]) faces:#([1,2,5], [2,3,5], [3,4,5], [4,1,5])
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
        )


        test_mesh = snapshotAsMesh test_node
        cleanup_loops = getWallThicknessSimpleOpenLoops test_mesh
        build_data = undefined
        undo "Wall Thickness Cleanup Test" on
        (
                build_data = buildWallThicknessCleanupModifier test_node test_mesh cleanup_loops
        )
        free test_mesh


        validation_mesh = snapshotAsMesh test_node
        open_edge_count = if validation_mesh != undefined then (meshop.getOpenEdges validation_mesh).numberSet else -1
        if validation_mesh != undefined then free validation_mesh
        test_passed = (cleanup_loops.count == 1) and build_data[1] and (build_data[5] == 1) and (open_edge_count == 0)
        format "Wall Thickness POSTPROCESS CLEANUP TEST: % | loops: % | quads: % | open edges: %\n" (if test_passed then "PASS" else "FAIL") cleanup_loops.count build_data[5] open_edge_count
        format "Undo order: Wall Thickness Cleanup Test -> Create Wall Thickness Cleanup Test.\n"
        select test_node
        test_passed
        -- return
)


/*
Tests that CLEANUP remains a visible modifier history and never collapses the source object.
The object stays in the final cleaned state for direct stack inspection.
*/
function testWallThicknessCleanupHistory =
(
        test_node = createWallThicknessOverlapTest()
        base_class_before = classOf test_node.baseObject
        cleanup_succeeded = cleanupWallThickness test_node


        quadrify_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_quadrify_modifier_name
        cap_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_cap_modifier_name
        weld_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_weld_modifier_name
        multiple_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_multiple_modifier_name
        cleanup_modifier = getWallThicknessCleanupModifier test_node
        thickness_modifier = getWallThicknessModifier test_node


        test_passed = cleanup_succeeded
        test_passed = test_passed and (base_class_before == classOf test_node.baseObject)
        test_passed = test_passed and (thickness_modifier != undefined)
        test_passed = test_passed and hasCompletedWallThicknessCleanupHistory test_node


        format "Wall Thickness CLEANUP HISTORY TEST: % | base:% | modifiers:% | quadrify:% cap:% weld:% multiple:% loop-fill:%\n" (if test_passed then "PASS" else "FAIL") (classOf test_node.baseObject) test_node.modifiers.count (quadrify_modifier != undefined) (cap_modifier != undefined) (weld_modifier != undefined) (multiple_modifier != undefined) (cleanup_modifier != undefined)
        test_passed
        -- return
)


/*
Tests the five split PRE-PROCESS actions in numbered order.
Every stage must remain visible after step 05 and WELD SOURCE must keep threshold 0.0.
*/
/*
Tests one-time PREP 01 RESET XFORM state on multiple selected objects.
The first run applies and bakes XForm; the second run must skip both objects and preserve a modifier added after the first bake.
*/
function testWallThicknessResetXFormSelected =
(
        test_a = box name:(uniqueName "WallThickness_ResetXForm_A_") width:100 length:100 height:100
        test_b = box name:(uniqueName "WallThickness_ResetXForm_B_") width:100 length:100 height:100
        test_a.scale = [2,1,1]
        test_b.scale = [1,3,1]
        select #(test_a, test_b)


        first_result = preprocessWallThicknessResetXFormSelected (selection as array)
        first_state_ok = first_result[1] and (first_result[2] == 2) and (first_result[3] == 0) and (first_result[4] == 0)
        first_state_ok = first_state_ok and ((distance test_a.scale [1,1,1]) < 0.0001) and ((distance test_b.scale [1,1,1]) < 0.0001)
        first_state_ok = first_state_ok and hasWallThicknessXFormApplied test_a and hasWallThicknessXFormApplied test_b


        user_modifier = Edit_Poly()
        user_modifier.name = "USER MODIFIER AFTER XFORM"
        user_modifier.showCage = off
        addModifier test_a user_modifier
        update test_a


        second_result = preprocessWallThicknessResetXFormSelected (selection as array)
        second_state_ok = second_result[1] and (second_result[2] == 0) and (second_result[3] == 0) and (second_result[4] == 2)
        second_state_ok = second_state_ok and (getWallThicknessNamedModifier test_a "USER MODIFIER AFTER XFORM" != undefined)


        test_passed = first_state_ok and second_state_ok
        format "Wall Thickness RESET XFORM ONCE TEST: % | first applied:% | second skipped:% | post-XForm user modifier preserved:%\n" (if test_passed then "PASS" else "FAIL") first_result[2] second_result[4] (getWallThicknessNamedModifier test_a "USER MODIFIER AFTER XFORM" != undefined)
        test_passed
        -- return
)


function testWallThicknessPreWeld =
(
        test_node = plane name:"WallThickness_Preprocess_Test" length:100 width:100 lengthsegs:1 widthsegs:1
        convertToPoly test_node
        try (test_node.baseObject.showCage = off) catch ()
        select test_node


        step_results = #()
        for step_number = 1 to 6 do
        (
                append step_results (preprocessWallThicknessStep test_node step_number)
        )


        remove_generated_modifier = getWallThicknessNamedModifier test_node wall_thickness_remove_generated_modifier_name
        pre_weld_modifier = getWallThicknessPreWeldModifier test_node
        degenerate_modifier = getWallThicknessNamedModifier test_node wall_thickness_degenerate_modifier_name
        multiple_modifier = getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name
        border_modifier = getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name


        test_passed = true
        for step_result in step_results while test_passed do
        (
                test_passed = step_result
        )


        test_passed = test_passed and (remove_generated_modifier != undefined)
        test_passed = test_passed and (pre_weld_modifier != undefined)
        test_passed = test_passed and (degenerate_modifier != undefined)
        test_passed = test_passed and (multiple_modifier != undefined)
        test_passed = test_passed and (border_modifier != undefined)


        if test_passed then
        (
                test_passed = (abs pre_weld_modifier.threshold) < 0.000001
        )


        format "Wall Thickness SPLIT PREPROCESS TEST: % | stages:% | source weld threshold:%
" (if test_passed then "PASS" else "FAIL") 6 (if pre_weld_modifier != undefined then pre_weld_modifier.threshold else undefined)
        format "Undo order: PREP 06 -> PREP 05 -> PREP 04 -> PREP 03 -> PREP 02 -> PREP 01.
"
        test_passed
        -- return
)


/*
Tests that EXTRUDE keeps the exact PRE-PROCESS modifier instances already visible in the stack.
No PREP stage may be deleted or rebuilt between PRE-PROCESS SOURCE and EXTRUDE.
*/
/*
Tests the EXTRUDE / UPDATE single-modifier contract on a deliberately triangulated source wall.
After extrusion the node must contain exactly one modifier named WALL THICKNESS, with no automatic Quadrify modifier, and the source triangles must remain triangles.
*/
function testWallThicknessSingleModifierExtrude =
(
        test_vertices = #(
                [0,0,0],
                [100,0,0],
                [100,0,100],
                [0,0,100]
        )
        test_faces = #(
                [1,2,3],
                [1,3,4]
        )
        test_node = mesh vertices:test_vertices faces:test_faces
        test_node.name = uniqueName "WallThickness_SingleModifier_TEST_"
        convertToPoly test_node
        try (test_node.baseObject.showCage = off) catch ()
        select test_node


        extrude_succeeded = applyWallThickness test_node 10.0
        thickness_modifier = getWallThicknessModifier test_node
        auto_quadrify_modifier = getWallThicknessNamedModifier test_node wall_thickness_auto_quadrify_modifier_name
        single_modifier_ok = test_node.modifiers.count == 1 and thickness_modifier != undefined and auto_quadrify_modifier == undefined
        source_triangles_ok = false


        if thickness_modifier != undefined then
        (
                source_triangles_ok = true
                for face_id = 1 to 2 while source_triangles_ok do
                (
                        if thickness_modifier.GetFaceDegree face_id node:test_node != 3 then
                        (
                                source_triangles_ok = false
                        )
                )
        )


        test_passed = extrude_succeeded and single_modifier_ok and source_triangles_ok
        format "Wall Thickness SINGLE MODIFIER EXTRUDE TEST: % | one WALL THICKNESS modifier:% | source triangles preserved:%\n" (if test_passed then "PASS" else "FAIL") single_modifier_ok source_triangles_ok
        test_passed
        -- return
)


/*
Tests EXTRUDE on the clean modifier-free native angle-test source.
The path must initialize WALL THICKNESS correctly, keep one shared offset vertex per source vertex, and produce 28 material-ID 2 quad polygons with hidden triangulation.
*/
function testWallThicknessV008Extrude =
(
        test_node = createWallThicknessTest()
        test_thickness = units.decodeValue "0.20m"
        source_mesh = snapshotAsMesh test_node
        source_vert_count = if source_mesh != undefined then meshop.getNumVerts source_mesh else 0
        if source_mesh != undefined then free source_mesh
        source_polygon_face_count = polyop.getNumFaces test_node.baseObject


        extrude_succeeded = applyWallThickness test_node test_thickness
        thickness_modifier = getWallThicknessModifier test_node
        generated_vert_count = 0
        outer_material_ok = true
        inner_quad_count = 0
        inner_hidden_triangulation_ok = true


        if thickness_modifier != undefined then
        (
                generated_vert_count = (EditPolyMod.GetNumVertices thickness_modifier node:test_node) - source_vert_count
                total_face_count = thickness_modifier.GetNumFaces node:test_node


                for face_id = 1 to source_polygon_face_count while outer_material_ok do
                (
                        outer_material_ok = thickness_modifier.GetFaceMaterial face_id node:test_node == 1
                )


                for face_id = 1 to total_face_count do
                (
                        if thickness_modifier.GetFaceMaterial face_id node:test_node == 2 then
                        (
                                inner_quad_count += 1
                                if thickness_modifier.GetFaceDegree face_id node:test_node != 4 then
                                (
                                        inner_hidden_triangulation_ok = false
                                )
                        )
                )
        )


        test_passed =
                extrude_succeeded and
                (thickness_modifier != undefined) and
                (generated_vert_count == source_vert_count) and
                outer_material_ok and
                (inner_quad_count == source_polygon_face_count) and
                inner_hidden_triangulation_ok


        format "Wall Thickness v0.08 EXTRUDE TEST: % | source/outer verts:% | generated offset verts:% | outer mat ID 1:% | generated inner quads:% | hidden triangulation:%\n" (if test_passed then "PASS" else "FAIL") source_vert_count generated_vert_count outer_material_ok inner_quad_count inner_hidden_triangulation_ok
        test_passed
        -- return
)


function testWallThicknessExtrudePreservesPreprocess =
(
        test_node = plane name:(uniqueName "WallThickness_PreservePreprocess_TEST_") length:100 width:100 lengthsegs:1 widthsegs:1
        convertToPoly test_node
        select test_node


        preprocess_succeeded = preprocessWallThickness test_node
        remove_generated_before = getWallThicknessNamedModifier test_node wall_thickness_remove_generated_modifier_name
        weld_before = getWallThicknessNamedModifier test_node wall_thickness_source_weld_modifier_name
        degenerate_before = getWallThicknessNamedModifier test_node wall_thickness_degenerate_modifier_name
        multiple_before = getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name
        border_before = getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name


        extrude_succeeded = applyWallThickness test_node 10.0
        test_passed = preprocess_succeeded and extrude_succeeded
        test_passed = test_passed and (remove_generated_before == getWallThicknessNamedModifier test_node wall_thickness_remove_generated_modifier_name)
        test_passed = test_passed and (weld_before == getWallThicknessNamedModifier test_node wall_thickness_source_weld_modifier_name)
        test_passed = test_passed and (degenerate_before == getWallThicknessNamedModifier test_node wall_thickness_degenerate_modifier_name)
        test_passed = test_passed and (multiple_before == getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name)
        test_passed = test_passed and (border_before == getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name)


        format "Wall Thickness EXTRUDE PRESERVES PREPROCESS TEST: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)


/*
Tests that EXTRUDE runs directly on a clean mesh without creating PRE-PROCESS modifiers.
Only WALL THICKNESS may be added by this action.
*/
function testWallThicknessExtrudeWithoutPreprocess =
(
        test_node = plane name:(uniqueName "WallThickness_DirectExtrude_TEST_") length:100 width:100 lengthsegs:1 widthsegs:1
        convertToPoly test_node
        select test_node


        extrude_succeeded = applyWallThickness test_node 10.0
        prep_count = 0
        if getWallThicknessNamedModifier test_node wall_thickness_remove_generated_modifier_name != undefined then prep_count += 1
        if getWallThicknessNamedModifier test_node wall_thickness_source_weld_modifier_name != undefined then prep_count += 1
        if getWallThicknessNamedModifier test_node wall_thickness_degenerate_modifier_name != undefined then prep_count += 1
        if getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name != undefined then prep_count += 1
        if getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name != undefined then prep_count += 1


        test_passed = extrude_succeeded and prep_count == 0 and getWallThicknessModifier test_node != undefined
        format "Wall Thickness DIRECT EXTRUDE TEST: % | PREP modifiers created: %\n" (if test_passed then "PASS" else "FAIL") prep_count
        test_passed
        -- return
)


/*
Tests that PREP 04 keeps multiple edges selected as a warning without failing preprocessing.
Three closed tetrahedral shells share one source edge so the object has a non-manifold multiple edge but no open border.
*/
function testWallThicknessMultipleEdgeWarning =
(
        test_node = undefined
        undo "Create Wall Thickness Multiple Edge Warning Test" on
        (
                test_vertices = #(
                        [0,0,0], [100,0,0],
                        [25,30,30], [25,-30,30],
                        [50,30,-30], [50,-30,-30],
                        [75,30,30], [75,-30,30]
                )
                test_faces = #(
                        [1,2,3], [1,4,2], [1,3,4], [2,4,3],
                        [1,2,5], [1,6,2], [1,5,6], [2,6,5],
                        [1,2,7], [1,8,2], [1,7,8], [2,8,7]
                )
                test_node = mesh name:"WallThickness_MultipleEdgeWarning_TEST" vertices:test_vertices faces:test_faces
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
                select test_node
        )


        preprocess_data = undefined
        undo "Wall Thickness Multiple Edge Warning Preprocess" on
        (
                preprocess_data = runWallThicknessPreprocess test_node
        )


        multiple_modifier = getWallThicknessNamedModifier test_node wall_thickness_multiple_edges_modifier_name
        selected_edges = if multiple_modifier != undefined then multiple_modifier.GetSelection #Edge node:test_node else #{}


        test_passed = preprocess_data != undefined and preprocess_data[1] and (multiple_modifier != undefined) and (selected_edges.numberSet > 0)
        format "Wall Thickness MULTIPLE EDGE WARNING TEST: % | selected warnings: % | message: %\n" (if test_passed then "PASS" else "FAIL") selected_edges.numberSet (if preprocess_data != undefined then preprocess_data[2] else undefined)
        format "Undo order: Wall Thickness Multiple Edge Warning Preprocess -> Create Wall Thickness Multiple Edge Warning Test.\n"
        test_passed
        -- return
)


/*
Tests that the final degenerate-border gate still blocks a disconnected border vertex lying on another border edge.
Multiple-edge warnings are permissive, but PREP 05 remains a hard source-topology gate.
*/
function testWallThicknessDegenerateBorderGate =
(
        test_node = undefined
        undo "Create Wall Thickness Degenerate Border Test" on
        (
                test_node = mesh name:"WallThickness_DegenerateBorder_TEST" vertices:#([0,0,0], [100,0,0], [0,100,0], [50,0,0], [50,-50,0], [75,-50,0]) faces:#([1,2,3], [4,5,6])
                convertToPoly test_node
                try (test_node.showCage = off) catch ()
                select test_node
        )


        apply_succeeded = applyWallThickness test_node 10.0
        border_modifier = getWallThicknessNamedModifier test_node wall_thickness_border_check_modifier_name
        thickness_modifier = getWallThicknessModifier test_node
        selected_edges = if border_modifier != undefined then border_modifier.GetSelection #Edge node:test_node else #{}


        test_passed = (not apply_succeeded) and (border_modifier != undefined) and (thickness_modifier == undefined) and (selected_edges.numberSet > 0)
        format "Wall Thickness DEGENERATE BORDER GATE TEST: % | selected border errors: %\n" (if test_passed then "PASS" else "FAIL") selected_edges.numberSet
        format "Undo order: Wall Thickness Preprocess + Thickness -> Create Wall Thickness Degenerate Border Test.\n"
        test_passed
        -- return
)


/*
Tests that EXTRUDE / UPDATE does not create a temporary STL CHECK before WALL THICKNESS.
A clean open source must receive WALL THICKNESS directly with no STL CHECK modifier.
*/
function testWallThicknessPreExtrudeSTL =
(
        test_node = plane name:(uniqueName "WALL_THICKNESS_NO_PRE_STL_") width:20 length:20 widthsegs:1 lengthsegs:1
        convertTo test_node Editable_Poly
        try (test_node.baseObject.showCage = off) catch ()
        select test_node


        extrude_succeeded = applyWallThickness test_node 2.0
        thickness_modifier = getWallThicknessModifier test_node
        stl_modifier = getWallThicknessSTLCheckModifier test_node
        test_passed = extrude_succeeded and (thickness_modifier != undefined) and (stl_modifier == undefined) and (test_node.modifiers.count == 1)


        format "Wall Thickness NO PRE-EXTRUDE STL TEST: % | WALL THICKNESS only:%\n" (if test_passed then "PASS" else "FAIL") test_passed
        test_passed
        -- return
)


/*
Tests the FINAL STL CHECK pass/fail contract on one closed box and one open plane.
PASS must remove the temporary modifier; FAIL must keep it on Open Edge.
*/
function testWallThicknessSTLValidation =
(
        closed_node = box name:(uniqueName "WALL_THICKNESS_STL_PASS_") width:20 length:20 height:20
        convertTo closed_node Editable_Poly
        closed_node.showCage = off
        closed_result = validateWallThicknessSTL closed_node show_messages:false
        closed_ok = closed_result[1] and (getWallThicknessSTLCheckModifier closed_node == undefined)


        open_node = plane name:(uniqueName "WALL_THICKNESS_STL_FAIL_") width:20 length:20 widthsegs:1 lengthsegs:1
        convertTo open_node Editable_Poly
        open_node.showCage = off
        open_result = validateWallThicknessSTL open_node show_messages:false
        open_modifier = getWallThicknessSTLCheckModifier open_node
        open_ok = (not open_result[1]) and (open_result[2] == "Open Edge") and (open_modifier != undefined)
        if open_modifier != undefined then open_ok = open_ok and (open_modifier.Selection_Type == 0)


        test_passed = closed_ok and open_ok
        format "Wall Thickness FINAL STL CHECK TEST: % | closed:% | open:%\n" (if test_passed then "PASS" else "FAIL") closed_ok open_ok
        test_passed
        -- return
)


/*
Tests successful CLEANUP state when redundant cleanup modifiers are pruned.
No-op cleanup stages are allowed to be absent while FIX CHAMFERS still sees CLEANUP as complete.
*/
function testWallThicknessCleanupCompletionGate =
(
        test_node = plane name:(uniqueName "WallThickness_CleanupGate_TEST_") length:100 width:100 lengthsegs:1 widthsegs:1
        convertToPoly test_node
        try (test_node.baseObject.showCage = off) catch ()
        select test_node


        extrude_succeeded = applyWallThickness test_node 5.0
        cleanup_succeeded = if extrude_succeeded then cleanupWallThickness test_node else false
        cleanup_complete = hasCompletedWallThicknessCleanupHistory test_node
        multiple_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_multiple_modifier_name
        weld_modifier = getWallThicknessNamedModifier test_node wall_thickness_cleanup_weld_modifier_name


        test_passed = extrude_succeeded and cleanup_succeeded and cleanup_complete
        test_passed = test_passed and (multiple_modifier == undefined)
        test_passed = test_passed and (weld_modifier == undefined)
        format "Wall Thickness CLEANUP NO-OP PRUNE TEST: % | weld kept:% | multiple kept:%\n" (if test_passed then "PASS" else "FAIL") (weld_modifier != undefined) (multiple_modifier != undefined)
        test_passed
        -- return
)


/*
Tests signed source-corner classification used by the separate inner and outer buttons.
*/
function testWallThicknessCornerModes =
(
        edge_direction = [0,0,1]
        inner_signed = dot (cross [1,0,0] [0,1,0]) edge_direction
        outer_signed = dot (cross [0,1,0] [1,0,0]) edge_direction
        test_passed = (inner_signed > 0.0001) and (outer_signed < -0.0001)
        format "Wall Thickness CORNER MODE TEST: % | inner:% | outer:%\\n" (if test_passed then "PASS" else "FAIL") inner_signed outer_signed
        test_passed
        -- return
)


/*
Creates the exact vertical T-stack regression geometry where stacked source vertices have zero XY drift.
The lower terminal member must receive the same generated XY as the continuing stack while preserving its Z.
*/
function createWallThicknessExactVerticalStackTest =
(
        test_node = editable_mesh name:"WallThickness_ExactVerticalStack_TEST"
        convertTo test_node Editable_Poly
        test_poly = test_node.baseObject
        try (test_poly.showCage = off) catch ()


        wall_run = units.decodeValue "3.135m"
        wall_width = units.decodeValue "0.88m"
        wall_top = units.decodeValue "2.65m"
        lower_drop = units.decodeValue "1.395m"
        far_lower_drop = units.decodeValue "1.445m"


        polyop.createVert test_poly [0, 0, 0]
        polyop.createVert test_poly [-wall_width, 0, 0]
        polyop.createVert test_poly [-wall_width, 0, wall_top]
        polyop.createVert test_poly [0, 0, wall_top]
        polyop.createVert test_poly [0, 0, -lower_drop]
        polyop.createVert test_poly [0, wall_run, 0]
        polyop.createVert test_poly [0, wall_run, wall_top]
        polyop.createVert test_poly [0, wall_run, -far_lower_drop]


        polyop.createPolygon test_poly #(2, 1, 4, 3)
        polyop.createPolygon test_poly #(5, 8, 6, 1)
        polyop.createPolygon test_poly #(6, 7, 4, 1)


        face_count = polyop.getNumFaces test_poly
        if face_count > 0 then
        (
                polyop.setFaceMatID test_poly #{1..face_count} 1
                polyop.setFaceSmoothGroup test_poly #{1..face_count} 0
        )


        update test_node
        select test_node
        test_node
        -- return
)


/*
Tests that an exact 3-member vertical T stack is repaired without relying on accidental XY drift.
Only the generated terminal member may move; source topology and source positions must remain unchanged.
*/
function testWallThicknessExactVerticalStackInnerCorner =
(
        test_node = createWallThicknessExactVerticalStackTest()
        test_thickness = units.decodeValue "0.45m"
        test_tolerance = units.decodeValue "0.01mm"
        test_passed = false
        source_unchanged = true
        topology_unchanged = false
        target_matches = false
        target_changed = false
        target_z_preserved = false
        fix_data = #(false, 0, 0)


        if isValidNode test_node then
        (
                extrude_succeeded = applyWallThickness test_node test_thickness


                if extrude_succeeded then
                (
                        thickness_modifier = getWallThicknessModifier test_node
                        source_vert_count_value = getUserProp test_node wall_thickness_source_vert_count_prop
                        source_vert_count = if source_vert_count_value != undefined then source_vert_count_value as integer else 0


                        if thickness_modifier != undefined and source_vert_count == 8 then
                        (
                                target_generated_id = source_vert_count + 5
                                anchor_generated_id = source_vert_count + 4
                                before_vertex_count = thickness_modifier.GetNumVertices node:test_node
                                before_face_count = thickness_modifier.GetNumFaces node:test_node
                                before_source_positions = for source_id = 1 to source_vert_count collect (EditPolyMod.GetVertex thickness_modifier source_id node:test_node)
                                before_target_position = EditPolyMod.GetVertex thickness_modifier target_generated_id node:test_node
                                before_anchor_position = EditPolyMod.GetVertex thickness_modifier anchor_generated_id node:test_node


                                if before_target_position != undefined and before_anchor_position != undefined then
                                (
                                        expected_target_position = [before_anchor_position.x, before_anchor_position.y, before_target_position.z]
                                        fix_data = fixWallThicknessInnerCorners test_node
                                        after_vertex_count = polyop.getNumVerts test_node
                                        after_face_count = polyop.getNumFaces test_node
                                        after_target_position = polyop.getVert test_node target_generated_id


                                        topology_unchanged = before_vertex_count == after_vertex_count and before_face_count == after_face_count
                                        target_matches = distance after_target_position expected_target_position <= test_tolerance
                                        target_changed = distance after_target_position before_target_position > test_tolerance
                                        target_z_preserved = after_target_position.z == before_target_position.z


                                        for source_id = 1 to source_vert_count while source_unchanged do
                                        (
                                                after_source_position = polyop.getVert test_node source_id
                                                if distance after_source_position before_source_positions[source_id] > test_tolerance then source_unchanged = false
                                        )
                                )
                        )
                )
        )


        test_passed = fix_data[1] and fix_data[3] > 0 and topology_unchanged and source_unchanged and target_matches and target_changed and target_z_preserved
        format "Wall Thickness EXACT VERTICAL STACK TEST: % | moved:% | topology unchanged:% | source unchanged:% | target:% | changed:% | Z preserved:%\n" (if test_passed then "PASS" else "FAIL") fix_data[3] topology_unchanged source_unchanged target_matches target_changed target_z_preserved
        format "Undo order: FIX INNER CORNERS, EXTRUDE / UPDATE, Create Exact Vertical Stack Test.\n"
        test_passed
        -- return
)


/*
Tests FIX INNER CORNERS as a transform-only repair.
Vertex/face counts and every source vertex must remain unchanged while at least one bad generated neighbor moves.
*/
function testWallThicknessInnerCornerChainExpansion =
(
        test_node = createWallThicknessTest()
        test_thickness = units.decodeValue "0.60m"
        test_passed = false
        source_unchanged = true
        changed_vertex_count = 0
        before_vertex_count = 0
        after_vertex_count = 0
        before_face_count = 0
        after_face_count = 0
        fix_data = #(false, 0, 0)


        if isValidNode test_node then
        (
                extrude_succeeded = applyWallThickness test_node test_thickness


                if extrude_succeeded then
                (
                        before_mesh = snapshotAsMesh test_node
                        source_vert_count_value = getUserProp test_node wall_thickness_source_vert_count_prop
                        source_vert_count = if source_vert_count_value != undefined then source_vert_count_value as integer else 0
                        before_positions = #()


                        if before_mesh != undefined then
                        (
                                before_vertex_count = meshop.getNumVerts before_mesh
                                before_face_count = meshop.getNumFaces before_mesh
                                before_positions = for vertex_id = 1 to before_vertex_count collect (getVert before_mesh vertex_id)
                                free before_mesh
                        )


                        fix_data = fixWallThicknessInnerCorners test_node
                        after_mesh = snapshotAsMesh test_node


                        if after_mesh != undefined then
                        (
                                after_vertex_count = meshop.getNumVerts after_mesh
                                after_face_count = meshop.getNumFaces after_mesh


                                if after_vertex_count == before_positions.count then
                                (
                                        for vertex_id = 1 to after_vertex_count do
                                        (
                                                after_position = getVert after_mesh vertex_id
                                                if distance after_position before_positions[vertex_id] > units.decodeValue "0.01mm" then
                                                (
                                                        changed_vertex_count += 1
                                                        if vertex_id <= source_vert_count then source_unchanged = false
                                                )
                                        )
                                )
                                else
                                (
                                        source_unchanged = false
                                )


                                free after_mesh
                        )
                )
        )


        test_passed =
                fix_data[1] and
                fix_data[2] > 0 and
                fix_data[3] > 0 and
                before_vertex_count == after_vertex_count and
                before_face_count == after_face_count and
                source_unchanged and
                changed_vertex_count == fix_data[3]


        format "Wall Thickness INNER CORNER DIRECT-MAP TEST: % | bad edges:% | moved:% | changed:% | verts:%/% | faces:%/% | source unchanged:%\n" (if test_passed then "PASS" else "FAIL") fix_data[2] fix_data[3] changed_vertex_count before_vertex_count after_vertex_count before_face_count after_face_count source_unchanged
        format "Undo order: FIX INNER CORNERS, EXTRUDE / UPDATE, Create Wall Thickness Angle Test.\n"
        test_passed
        -- return
)




/*
Tests inner-wall collapse repair separately from the existing outer-corner miter repair.
The inner case deliberately uses thickness larger than several source segments so generated inner-wall edges must collapse instead of reversing.
*/
function testWallThicknessFixChamfers =
(
        inner_thickness = units.decodeValue "3.0m"
        outer_thickness = units.decodeValue "0.20m"


        inner_node = createWallThicknessTest()
        inner_extrude_succeeded = applyWallThickness inner_node inner_thickness
        inner_data = if inner_extrude_succeeded then fixWallThicknessInnerCorners inner_node else #(false, 0, 0)
        inner_second_data = if inner_extrude_succeeded then fixWallThicknessInnerCorners inner_node else #(false, 0, 0)


        outer_node = createWallThicknessTest()
        outer_node.pos.x += units.decodeValue "14m"
        outer_extrude_succeeded = applyWallThickness outer_node outer_thickness
        outer_data = if outer_extrude_succeeded then fixWallThicknessOuterCorners outer_node else #(false, 0, 0)


        angle_90_ok = canFixWallThicknessChamferAngle [1,0,0] [0,1,0]
        angle_wide_ok = canFixWallThicknessChamferAngle [1,0,0] [0.5,0.8660254,0]
        angle_sharp_rejected = not (canFixWallThicknessChamferAngle [1,0,0] [-0.5,0.8660254,0])
        angle_gate_ok = angle_90_ok and angle_wide_ok and angle_sharp_rejected


        inner_single_modifier_ok = (countWallThicknessNamedModifiers inner_node wall_thickness_inner_fix_modifier_name) == 1
        inner_ok = inner_data[1] and (inner_data[2] > 0) and (inner_data[3] > 0) and inner_second_data[1] and inner_single_modifier_ok and (getWallThicknessInnerCornerFixModifier inner_node != undefined) and (getWallThicknessInnerCornerWeldModifier inner_node == undefined)
        outer_ok = outer_data[1] and (outer_data[2] > 0) and (outer_data[3] > 0) and (getWallThicknessChamferFixModifier outer_node != undefined)
        test_passed = inner_extrude_succeeded and outer_extrude_succeeded and inner_ok and outer_ok and angle_gate_ok


        format "Wall Thickness INNER COLLAPSE / OUTER CORNER FIX TEST: % | inner bad edges:% moved:% single modifier:% | outer edges:% moved:% | outer angle gate:%\n" (if test_passed then "PASS" else "FAIL") inner_data[2] inner_data[3] inner_single_modifier_ok outer_data[2] outer_data[3] angle_gate_ok
        test_passed
        -- return
)


/*
Tests that CLEANUP Quadrify uses the current Edit Poly without creating another modifier.
The test object remains in the scene for visual inspection.
*/
function testWallThicknessCurrentModifierCleanupPolicy =
(
        test_node = createWallThicknessTest()
        test_modifier = Edit_Poly()
        test_modifier.name = "TEST CURRENT EDIT POLY"
        test_modifier.showCage = off
        addModifier test_node test_modifier
        test_passed = false


        if isValidNode test_node then
        (
                before_modifier_count = test_node.modifiers.count
                select test_node
                max modify mode
                WallThicknessPreprocess.prepareEditPoly test_node test_modifier selection_level:#Object
                modPanel.setCurrentObject test_modifier node:test_node
                cleanup_succeeded = quadrifyCurrentWallThicknessModifier test_node
                after_modifier_count = test_node.modifiers.count
                current_modifier = modPanel.getCurrentObject()


                test_passed = cleanup_succeeded and before_modifier_count == after_modifier_count and current_modifier == test_modifier
        )


        format "Wall Thickness CURRENT MODIFIER CLEANUP TEST: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)


/*
Tests the no-new-modifier smoothing exception on a dedicated generic Edit Poly stage.
The basic angle-test creator itself remains modifier-free.
*/
function testWallThicknessSmoothingResetPolicy =
(
        test_node = createWallThicknessTest()
        test_modifier = Edit_Poly()
        test_modifier.name = "TEST SMOOTHING EDIT POLY"
        test_modifier.showCage = off
        addModifier test_node test_modifier
        test_passed = false


        if isValidNode test_node then
        (
                before_modifier_count = test_node.modifiers.count
                WallThicknessPreprocess.prepareEditPoly test_node test_modifier selection_level:#Object
                reset_succeeded = clearWallSmoothingGroupsOnEditPoly test_node test_modifier
                after_modifier_count = test_node.modifiers.count
                smoothing_groups_ok = true
                test_mesh = snapshotAsMesh test_node


                if test_mesh == undefined then
                (
                        smoothing_groups_ok = false
                )
                else
                (
                        mesh_face_count = getNumFaces test_mesh
                        for face_id = 1 to mesh_face_count while smoothing_groups_ok do
                        (
                                smoothing_groups_ok = getFaceSmoothGroup test_mesh face_id == 0
                        )
                        free test_mesh
                )


                test_passed = reset_succeeded and before_modifier_count == after_modifier_count and smoothing_groups_ok
        )


        format "Wall Thickness SMOOTHING RESET TEST: %\n" (if test_passed then "PASS" else "FAIL")
        test_passed
        -- return
)


/*
Tests that RESTART TOOL keeps the exact currently loaded source path when that file still exists.
This test resolves the path only and does not reload the script.
*/
function testWallThicknessLatestReloadPath =
(
        latest_script_path = getLatestWallThicknessScriptPath()
        expected_path = wall_thickness_source_file_path
        test_passed = latest_script_path != undefined and doesFileExist latest_script_path


        if test_passed and expected_path != undefined and expected_path != "" and doesFileExist expected_path then
        (
                test_passed = (toLower latest_script_path) == (toLower expected_path)
        )


        format "Wall Thickness RESTART TOOL PATH TEST: % | %\n" (if test_passed then "PASS" else "FAIL") latest_script_path
        test_passed
        -- return
)


try
(
        destroyDialog wallThicknessRollout
)
catch
(
)


/*
Formats one function result for the compact UI log.
*/
/*
Tests the LMB SELECT / RMB remove-fix split for PREP 01 and PREP 03.
The two test objects remain in the scene so SELECT/DELETED modifier history can be inspected with undo.
*/
function testWallThicknessSelectRemoveWorkflow =
(
        generated_node = mesh name:(uniqueName "WallThickness_SelectRemove_Generated_") vertices:#([0,0,0],[100,0,0],[100,100,0],[0,100,0]) faces:#([1,2,3],[1,3,4])
        convertToPoly generated_node
        try (generated_node.baseObject.showCage = off) catch ()
        polyop.setFaceMatID generated_node #{1} 1
        polyop.setFaceMatID generated_node #{2} 2
        setUserProp generated_node wall_thickness_source_face_count_prop 1
        select generated_node


        generated_select_ok = preprocessWallThicknessStep generated_node 2
        generated_select_modifier = getWallThicknessNamedModifier generated_node wall_thickness_remove_generated_modifier_name
        generated_selected_count = if generated_select_modifier != undefined then (generated_select_modifier.GetSelection #Face node:generated_node).numberSet else 0
        generated_delete_ok = preprocessWallThicknessRemoveStep generated_node 2
        generated_deleted_modifier = getWallThicknessNamedModifier generated_node wall_thickness_deleted_generated_modifier_name
        generated_result_ok = generated_select_ok and generated_delete_ok and (generated_selected_count == 1) and (generated_deleted_modifier != undefined)


        degenerate_node = mesh name:(uniqueName "WallThickness_SelectRemove_Degenerate_") vertices:#([0,0,0],[100,0,0],[200,0,0],[0,100,0]) faces:#([1,2,3],[1,4,2])
        convertToPoly degenerate_node
        try (degenerate_node.baseObject.showCage = off) catch ()
        select degenerate_node


        degenerate_select_ok = preprocessWallThicknessStep degenerate_node 4
        degenerate_select_modifier = getWallThicknessNamedModifier degenerate_node wall_thickness_degenerate_modifier_name
        degenerate_selected_count = if degenerate_select_modifier != undefined then (degenerate_select_modifier.GetSelection #Face node:degenerate_node).numberSet else 0
        degenerate_fix_ok = preprocessWallThicknessRemoveStep degenerate_node 4
        degenerate_deleted_modifier = getWallThicknessNamedModifier degenerate_node wall_thickness_deleted_degenerate_modifier_name
        degenerate_result_ok = degenerate_select_ok and degenerate_fix_ok and (degenerate_selected_count > 0) and (degenerate_deleted_modifier != undefined)


        test_passed = generated_result_ok and degenerate_result_ok
        format "Wall Thickness SELECT/RMB TEST: % | generated selected:% | degenerate selected:%\n" (if test_passed then "PASS" else "FAIL") generated_selected_count degenerate_selected_count
        format "Undo order includes PREP 03 RMB/LMB and PREP 01 RMB/LMB for visual inspection.\n"
        test_passed
        -- return
)


function getWallThicknessUILogResultText result_value =
(
        result_text = "undefined"
        if result_value != undefined then
        (
                try
                (
                        result_text = result_value as string
                )
                catch
                (
                        result_text = "<result>"
                )
        )
        result_text
        -- return
)


/*
Shows only the latest action result in the top UI log.
The UI message is concise, upper-case, and may contain multiple lines for one action.
*/
function setWallThicknessUILog action_name result_value:undefined detail:"" =
(
        message_text = ""


        if detail != "" then
        (
                message_text = detail
        )
        else if result_value == true then
        (
                message_text = action_name + " COMPLETE"
        )
        else if result_value == false then
        (
                message_text = action_name + " FAILED"
        )
        else if result_value != undefined then
        (
                message_text = getWallThicknessUILogResultText result_value
        )
        else
        (
                message_text = action_name
        )


        message_text = toUpper message_text
        try (wallThicknessRollout.edt_log.text = message_text) catch ()
        format "Wall Thickness % | %\n" action_name message_text
        true
        -- return
)


rollout wallThicknessRollout "WALL THICKNESS" width:270
(
        button btn_reload_latest "RESTART TOOL" width:230 height:28 align:#center tooltip:"Reload the exact script file that launched this tool."


        group "LOG"
        (
                editText edt_log "" text:"READY" readOnly:true width:230 height:58 align:#center
        )


        button btn_reset "REMOVE MODIFIERS" width:230 height:28 align:#center tooltip:"Remove all Wall Thickness PREP, THICKNESS, CLEANUP, chamfer and STL Check modifiers.\n\nThe base object remains unchanged."


        group "PRE-PROCESS"
        (
                button btn_preprocess_01 "01  RESET XFORM" width:230 height:28 align:#center tooltip:"LMB: Reset XForm once per selected object, then collapse only to bake that XForm result.\n\nCompleted state is stored per object handle in User Properties, so later clicks skip already-XFormed objects."
                button btn_preprocess_02 "02  GENERATED FACES" width:230 height:28 align:#center tooltip:"LMB: Select generated material-2/3 faces in SELECT 02 GENERATED FACES.\n\nRMB: Delete only that stored selection after exact source-face-count revalidation, then rename the modifier DELETED 02 GENERATED FACES."
                button btn_preprocess_03 "03  WELD SOURCE" width:230 height:28 align:#center tooltip:"LMB: Add the zero-threshold source Vertex Weld stage."
                button btn_preprocess_04 "04  DEGENERATE FACES" width:230 height:28 align:#center tooltip:"LMB: Select degenerate/sliver faces in SELECT 04 DEGENERATE FACES.\n\nRMB: Fix or remove only that stored selection, then rename the changed modifier DELETED 04 DEGENERATE FACES."
                button btn_preprocess_05 "05  CHECK MULTIPLE EDGES" width:230 height:28 align:#center tooltip:"LMB: Run the xView Multiple Edges check. Findings remain selected as warnings and do not block extrusion."
                button btn_preprocess_06 "06  CHECK DEGENERATE BORDERS" width:230 height:28 align:#center tooltip:"LMB: Validate zero-length, overlapping, backtracking, T-junction, and vertex-on-edge border defects."
        )


        group "EXTRUDE"
        (
                label lbl_thickness_caption "Thickness:" width:92 align:#left across:3
                spinner spn_thickness "" range:[0.001, 1000000.0, 1.0] type:#worldUnits width:92 fieldwidth:72 align:#left
                label lbl_units "" width:42 align:#left


                label lbl_ratio_caption "Model ratio: 1 :" width:92 align:#left across:3
                spinner spn_ratio "" range:[1, 1000000, 150] type:#integer width:92 fieldwidth:72 align:#left
                label lbl_ratio_units "" width:42 align:#left


                label lbl_scaled_caption "Scaled thickness:" width:92 align:#left across:3
                label lbl_scaled "" width:92 align:#left
                label lbl_scaled_units "" width:42 align:#left


                button btn_create "EXTRUDE / UPDATE" width:230 height:32 align:#center tooltip:"LMB: Create or rebuild only the single WALL THICKNESS modifier.\n\nNo STL Check, Quadrify, or other modifier is inserted by EXTRUDE / UPDATE."
        )


        group "POST-PROCESS"
        (
                button btn_fix_inner "FIX INNER CORNERS" width:230 height:28 align:#center tooltip:"LMB: Add one Edit Poly and place bad generated inner-corner vertices at exact 100 mm targets without changing your Modify-panel sub-object mode."
                button btn_fix_t_edge "FIX T EDGE CORNERS" width:230 height:28 align:#center tooltip:"LMB: Ensure FIX INNER CORNERS runs first, then add the T-junction topology, move the new vertical cut in X/Y onto the fixed anchor, weld the coincident upper vertex into the anchor, remove the degenerate polygon through that weld, and copy the generated-side strip material from its adjacent generated wall face."
                button btn_fix_outer "FIX OUTER CORNERS" width:230 height:28 align:#center tooltip:"Resolve convex outer corners by intersecting the offset face planes and removing the generated chamfer.\n\nSource-wall inner angles sharper than 90 degrees are left unchanged to avoid spikes."
                button btn_cleanup "CLEANUP" width:230 height:32 align:#center tooltip:"Run PolyTools Quadrify on the currently active Edit Poly modifier only.\n\nNo modifier is created."
        )


        group "FINISH"
        (
                button btn_stl_check "FINAL STL CHECK" width:230 height:32 align:#center tooltip:"Run Open Edge, Double Face, Spike and Multiple Edge tests.\n\nPASS: remove the temporary STL Check and show success.\n\nFAIL: keep the modifier on the first failing test."
        )


        group "SMOOTHING"
        (
                button btn_clear_smoothing "CLEAR SMOOTHING GROUPS" width:230 height:28 align:#center
        )


        group "TESTS"
        (
                button btn_test "CREATE ANGLE TEST WALLS" width:230 height:28 align:#center tooltip:"LMB: Create the 4 m angle-test wall directly as a native quad Editable Poly with vertical support edges around every interior plan corner. No TEST QUADRIFY modifier is added.\n\nRMB: Create the current uploaded complex-source reference, preserve its STRAIGHT EDGE FIXER selection context, Quadrify it, center its pivot, and place the pivot at world [0,0,0]."
        )


        on wallThicknessRollout open do
        (
                wallThicknessRollout.title = "WALL THICKNESS " + (wall_thickness_file_version as string)
                lbl_units.text = getWallThicknessDisplayUnitsLabel()
                loadWallThicknessControlValues()
                syncWallThicknessSpinnerToSelection()
                updateWallThicknessScaledLabel()
                setWallThicknessUILog "READY" detail:("WALL THICKNESS " + (wall_thickness_file_version as string))
        )


        on spn_thickness changed value do
        (
                saveWallThicknessControlValues()
                updateWallThicknessScaledLabel()


                if selection.count == 1 then
                (
                        wall_thickness_target = selection[1]
                        if getFinishedWallThicknessModifier wall_thickness_target == undefined then
                        (
                                updateDynamicWallThickness value
                        )
                )
        )


        on spn_ratio changed value do
        (
                saveWallThicknessControlValues()
                updateWallThicknessScaledLabel()
        )


        on wallThicknessRollout close do
        (
                saveWallThicknessControlValues()
                saveWallThicknessDialogPos()
        )


        on btn_reset pressed do
        (
                if selection.count == 1 then
                (
                        result_value = resetWallThickness selection[1]
                        setWallThicknessUILog "REMOVE MODIFIERS" detail:(if result_value then "MODIFIERS REMOVED" else "REMOVE MODIFIERS FAILED")
                )
                else
                (
                        setWallThicknessUILog "REMOVE MODIFIERS" detail:"SELECT EXACTLY ONE WALL OBJECT"
                        messageBox "Select exactly one wall object." title:"Wall Thickness"
                )
        )


        on btn_preprocess_01 pressed do
        (
                if selection.count > 0 then
                (
                        result_value = preprocessWallThicknessResetXFormSelected (selection as array)
                        status_text = (result_value[2] as string) + " OBJECTS XFORMED"
                        if result_value.count >= 4 and result_value[4] > 0 then status_text += "\r\n" + (result_value[4] as string) + " ALREADY XFORMED"
                        if result_value[3] > 0 then status_text += "\r\n" + (result_value[3] as string) + " OBJECTS FAILED"
                        setWallThicknessUILog "01 RESET XFORM" detail:status_text
                )
                else
                (
                        setWallThicknessUILog "01 RESET XFORM" detail:"SELECT ONE OR MORE OBJECTS"
                )
        )


        on btn_preprocess_02 pressed do
        (
                if selection.count == 1 then
                (
                        result_value = preprocessWallThicknessStep selection[1] 2
                        select_modifier = getWallThicknessNamedModifier selection[1] wall_thickness_remove_generated_modifier_name
                        selected_count = if select_modifier != undefined then (select_modifier.GetSelection #Face node:selection[1]).numberSet else 0
                        setWallThicknessUILog "02 LMB" detail:((selected_count as string) + " GENERATED FACES FOUND")
                )
                else messageBox "Select exactly one wall object." title:"Wall Thickness"
        )


        on btn_preprocess_02 rightClick do
        (
                if selection.count == 1 then
                (
                        select_modifier = getWallThicknessNamedModifier selection[1] wall_thickness_remove_generated_modifier_name
                        selected_count = if select_modifier != undefined then (select_modifier.GetSelection #Face node:selection[1]).numberSet else 0
                        result_value = preprocessWallThicknessRemoveStep selection[1] 2
                        if result_value then
                        (
                                setWallThicknessUILog "02 RMB" detail:((selected_count as string) + " GENERATED FACES REMOVED")
                        )
                        else
                        (
                                setWallThicknessUILog "02 RMB" detail:"GENERATED FACE REMOVE FAILED"
                        )
                )
                else messageBox "Select exactly one wall object." title:"Wall Thickness"
        )


        on btn_preprocess_03 pressed do
        (
                if selection.count == 1 then
                (
                        result_value = preprocessWallThicknessStep selection[1] 3
                        setWallThicknessUILog "03 WELD SOURCE" result_value:result_value
                )
                else messageBox "Select exactly one wall object." title:"Wall Thickness"
        )


        on btn_preprocess_04 pressed do
        (
                if selection.count == 1 then
                (
                        result_value = preprocessWallThicknessStep selection[1] 4
                        select_modifier = getWallThicknessNamedModifier selection[1] wall_thickness_degenerate_modifier_name
                        selected_count = if select_modifier != undefined then (select_modifier.GetSelection #Face node:selection[1]).numberSet else 0
                        setWallThicknessUILog "04 LMB" detail:((selected_count as string) + " DEGENERATE FACES FOUND")
                )
                else messageBox "Select exactly one wall object." title:"Wall Thickness"
        )


        on btn_preprocess_04 rightClick do
        (
                if selection.count == 1 then
                (
                        select_modifier = getWallThicknessNamedModifier selection[1] wall_thickness_degenerate_modifier_name
                        selected_count = if select_modifier != undefined then (select_modifier.GetSelection #Face node:selection[1]).numberSet else 0
                        result_value = preprocessWallThicknessRemoveStep selection[1] 4
                        if result_value then
                        (
                                setWallThicknessUILog "04 RMB" detail:((selected_count as string) + " DEGENERATE FACES PROCESSED")
                        )
                        else
                        (
                                setWallThicknessUILog "04 RMB" detail:"DEGENERATE FACE FIX FAILED"
                        )
                )
                else messageBox "Select exactly one wall object." title:"Wall Thickness"
        )


        on btn_preprocess_05 pressed do
        (
                if selection.count == 1 then
                (
                        result_value = preprocessWallThicknessStep selection[1] 5
                        setWallThicknessUILog "05 MULTIPLE EDGES" result_value:result_value
                )
                else messageBox "Select exactly one wall object." title:"Wall Thickness"
        )


        on btn_preprocess_06 pressed do
        (
                if selection.count == 1 then
                (
                        result_value = preprocessWallThicknessStep selection[1] 6
                        setWallThicknessUILog "06 DEGENERATE BORDERS" result_value:result_value
                )
                else messageBox "Select exactly one wall object." title:"Wall Thickness"
        )


        on btn_create pressed do
        (
                if selection.count == 1 then
                (
                        result_value = applyWallThickness selection[1] spn_thickness.value
                        setWallThicknessUILog "EXTRUDE / UPDATE" result_value:result_value
                )
                else
                (
                        setWallThicknessUILog "EXTRUDE / UPDATE" detail:"select exactly one wall object"
                        messageBox "Select exactly one wall object." title:"Wall Thickness"
                )
        )


        on btn_cleanup pressed do
        (
                if selection.count == 1 then
                (
                        result_value = quadrifyCurrentWallThicknessModifier selection[1]
                        setWallThicknessUILog "CLEANUP" result_value:result_value
                )
                else
                (
                        setWallThicknessUILog "CLEANUP" detail:"select exactly one wall object"
                        messageBox "Select exactly one wall object." title:"Wall Thickness"
                )
        )


        on btn_fix_inner pressed do
        (
                if selection.count == 1 then
                (
                        result_value = fixWallThicknessInnerCorners selection[1]
                        setWallThicknessUILog "FIX INNER CORNERS" result_value:result_value
                )
                else
                (
                        setWallThicknessUILog "FIX INNER CORNERS" detail:"select exactly one wall object"
                        messageBox "Select exactly one wall object." title:"Wall Thickness"
                )
        )


        on btn_fix_t_edge pressed do
        (
                if selection.count == 1 then
                (
                        result_value = fixWallThicknessTEdgeCorners selection[1]
                        if result_value[1] then
                        (
                                setWallThicknessUILog "FIX T EDGE CORNERS" detail:((result_value[2] as string) + " T EDGE CORNERS FIXED | " + (result_value[4] as string) + " MATERIAL POLYGONS UPDATED")
                        )
                        else
                        (
                                setWallThicknessUILog "FIX T EDGE CORNERS" detail:"FIX T EDGE CORNERS FAILED"
                        )
                )
                else
                (
                        setWallThicknessUILog "FIX T EDGE CORNERS" detail:"select exactly one wall object"
                        messageBox "Select exactly one wall object." title:"Wall Thickness"
                )
        )


        on btn_fix_outer pressed do
        (
                if selection.count == 1 then
                (
                        result_value = fixWallThicknessOuterCorners selection[1]
                        setWallThicknessUILog "FIX OUTER CORNERS" result_value:result_value
                )
                else
                (
                        setWallThicknessUILog "FIX OUTER CORNERS" detail:"select exactly one wall object"
                        messageBox "Select exactly one wall object." title:"Wall Thickness"
                )
        )


        on btn_stl_check pressed do
        (
                if selection.count == 1 then
                (
                        result_value = validateWallThicknessSTL selection[1] show_messages:true
                        setWallThicknessUILog "FINAL STL CHECK" result_value:result_value
                )
                else
                (
                        setWallThicknessUILog "FINAL STL CHECK" detail:"select exactly one wall object"
                        messageBox "Select exactly one wall object." title:"Wall Thickness"
                )
        )


        on btn_clear_smoothing pressed do
        (
                result_value = clearWallSmoothingGroups()
                setWallThicknessUILog "CLEAR SMOOTHING GROUPS" result_value:result_value
        )


        on btn_test pressed do
        (
                result_value = createWallThicknessTest()
                setWallThicknessUILog "TEST LMB" result_value:result_value
        )


        on btn_test rightClick do
        (
                result_value = createWallThicknessUploadedTest()
                setWallThicknessUILog "TEST RMB" result_value:result_value
        )


        on btn_reload_latest pressed do
        (
                result_value = loadLatestWallThicknessVersion()
                setWallThicknessUILog "RESTART TOOL" result_value:result_value
        )
)


callbacks.removeScripts id:wall_thickness_selection_callback_id
callbacks.addScript #selectionSetChanged "syncWallThicknessSpinnerToSelection()" id:wall_thickness_selection_callback_id


saved_dialog_pos = loadWallThicknessDialogPos()
if saved_dialog_pos == undefined then
(
        createDialog wallThicknessRollout
)
else
(
        createDialog wallThicknessRollout pos:saved_dialog_pos
)