/*
Wall Thickness Tool 0.996
Keeps the stable strict face-normal wall shell unchanged; CLEANUP quadrifies only the current Edit Poly and smoothing reset edits existing geometry without adding a modifier.
*/
global wallThicknessRollout
global wall_thickness_ini = (getDir #plugcfg + "\\Wall-Thickness.ini")
global wall_thickness_target = undefined
global wall_thickness_default = 1.0
global wall_thickness_user_prop = "WallThickness"
global wall_thickness_source_face_count_prop = "WallThicknessSourceFaceCount"
global wall_thickness_source_vert_count_prop = "WallThicknessSourceVertCount"
global wall_thickness_inner_fix_enabled_prop = "WallThicknessFixInnerCorners"
global wall_thickness_change_material_ids_prop = "WallThicknessChangeMaterialIds"
global wall_thickness_cleanup_complete_prop = "WallThicknessCleanupComplete"
global wall_thickness_xformed_prop_prefix = "WallThickness_"
global wall_thickness_selection_callback_id = #WallThicknessSelectionChanged
global wall_thickness_modifier_name = "WALL THICKNESS"
global wall_thickness_finished_modifier_name = "WALL THICKNESS FINISHED"
global wall_thickness_cleanup_modifier_name = "WALL THICKNESS CLEANUP"
global wall_thickness_auto_quadrify_modifier_name = "WALL THICKNESS QUADRIFY"
global wall_thickness_inner_fix_modifier_name = "WALL THICKNESS FIX INNER CORNERS"
global wall_thickness_t_edge_fix_modifier_name = "WALL THICKNESS FIX T EDGE CORNERS"
global wall_thickness_t_edge_input_modifier_name = "WALL THICKNESS FIX T EDGE INPUT"
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
global wall_thickness_file_version = 0.996
global wall_thickness_stored_project_version = wall_thickness_file_version
global wall_thickness_project_version = wall_thickness_file_version
global wall_thickness_ui_title = "WALL THICKNESS " + (wall_thickness_project_version as string)
global wall_thickness_source_file_path = getSourceFileName()
global wall_thickness_inner_corners_module_path = undefined
global wall_thickness_ui_log_lines = #()
global wall_thickness_dump_logger = undefined
global wall_thickness_inner_dump_file = undefined
global buildWallThicknessTEdgeFixModifier
global wall_thickness_ratio_default = 150
/*
Persistent deformation-only modifier used by FIX INNER CORNERS.
It changes only the stored target vertex positions and never changes topology.
*/
plugin simpleMod WallThicknessInnerCornerFixMod
name:"Wall Thickness Inner Corner Fix"
classID:#(0x4f61a962, 0x27bc1102)
version:1
(
        parameters main
        (
                target_vertex_ids type:#intTab tabSizeVariable:true animatable:false
                target_positions type:#point3Tab tabSizeVariable:true animatable:false
        )
        on map point_index point_position do
        (
                local mapped_position = point_position
                local target_count = 0
                if point_index > 0 then
                (
                        target_count = target_vertex_ids.count
                        if target_positions.count < target_count then target_count = target_positions.count
                        for target_index = 1 to target_count while mapped_position == point_position do
                        (
                                if target_vertex_ids[target_index] == point_index then
                                (
                                        mapped_position = target_positions[target_index]
                                )
                        )
                )
                mapped_position
        )
)
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
Reads whether EXTRUDE / UPDATE should apply the Wall Thickness Material ID convention.
The option defaults to disabled so source Material IDs are preserved.
*/
function loadWallThicknessChangeMaterialIds =
(
        saved_value = getINISetting wall_thickness_ini "Settings" "ChangeMaterialIDs"
        saved_value == "1"
        -- return
)
/*
Stores whether EXTRUDE / UPDATE should change Material IDs to outer 1, inner 2, strip 3.
*/
function saveWallThicknessChangeMaterialIds enabled_value =
(
        setINISetting wall_thickness_ini "Settings" "ChangeMaterialIDs" (if enabled_value then "1" else "0")
        true
        -- return
)
/*
Reads whether routine per-action Listener output is suppressed.
QUIET defaults to disabled.
*/
function loadWallThicknessQuietMode =
(
        saved_value = getINISetting wall_thickness_ini "Settings" "QuietMode"
        saved_value == "1"
        -- return
)
/*
Stores the QUIET UI state.
*/
function saveWallThicknessQuietMode enabled_value =
(
        setINISetting wall_thickness_ini "Settings" "QuietMode" (if enabled_value then "1" else "0")
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
                saveWallThicknessChangeMaterialIds wallThicknessRollout.chk_change_material_ids.checked
                saveWallThicknessQuietMode wallThicknessRollout.chk_quiet.checked
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
                wallThicknessRollout.chk_change_material_ids.checked = loadWallThicknessChangeMaterialIds()
                wallThicknessRollout.chk_quiet.checked = loadWallThicknessQuietMode()
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
Reads whether FIX INNER CORNERS is part of the rebuildable WALL THICKNESS state for this wall.
The state is stored on the node so future thickness updates can rebuild the same fixed result from the source.
*/
function getObjectWallThicknessInnerFixEnabled source_node =
(
        fix_enabled = false
        if isValidNode source_node then
        (
                saved_value = getUserProp source_node wall_thickness_inner_fix_enabled_prop
                if saved_value != undefined then
                (
                        if (classOf saved_value == Integer) or (classOf saved_value == Float) then
                        (
                                fix_enabled = (saved_value as integer) != 0
                        )
                        else
                        (
                                saved_text = saved_value as string
                                fix_enabled = (saved_text == "1") or (saved_text == "true") or (saved_text == "True")
                        )
                )
        )
        fix_enabled
        -- return
)
/*
Stores whether FIX INNER CORNERS must be reapplied whenever WALL THICKNESS is rebuilt.
*/
function setObjectWallThicknessInnerFixEnabled source_node enabled_value =
(
        if isValidNode source_node then
        (
                setUserProp source_node wall_thickness_inner_fix_enabled_prop (if enabled_value then 1 else 0)
        )
        true
        -- return
)
/*
Reads the Material ID mode stored with one wall so non-destructive corner rebuilds preserve the active EXTRUDE option.
*/
function getObjectWallThicknessChangeMaterialIds source_node =
(
        change_ids = false
        if isValidNode source_node then
        (
                saved_value = getUserProp source_node wall_thickness_change_material_ids_prop
                if saved_value != undefined then
                (
                        if (classOf saved_value == Integer) or (classOf saved_value == Float) then
                        (
                                change_ids = (saved_value as integer) != 0
                        )
                        else
                        (
                                saved_text = saved_value as string
                                change_ids = (saved_text == "1") or (saved_text == "true") or (saved_text == "True")
                        )
                )
        )
        change_ids
        -- return
)
/*
Stores the EXTRUDE Material ID mode on one wall.
*/
function setObjectWallThicknessChangeMaterialIds source_node enabled_value =
(
        if isValidNode source_node then
        (
                setUserProp source_node wall_thickness_change_material_ids_prop (if enabled_value then 1 else 0)
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
                        if test_modifier.name == wall_thickness_inner_fix_modifier_name then
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
Returns every tool-owned FIX T EDGE CORNERS Edit Poly layer in current stack order.
Current builds create one canonical layer; prefixed case layers are recognized only so older experimental stacks can be cleaned safely.
*/
function getWallThicknessTEdgeFixModifiers source_node =
(
        found_modifiers = #()
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        test_name = test_modifier.name as string
                        if (classOf test_modifier == Edit_Poly) and (findString test_name wall_thickness_t_edge_fix_modifier_name == 1) then
                        (
                                append found_modifiers test_modifier
                        )
                )
        )
        found_modifiers
        -- return
)
/*
Finds the legacy Turn To Poly helper from the failed pre-0.976 T-edge experiments.
Current T-edge execution does not create or depend on this modifier; it is recognized only for cleanup.
*/
function getWallThicknessTEdgeInputModifier source_node =
(
        found_modifier = undefined
        if isValidNode source_node then
        (
                for modifier_id = 1 to source_node.modifiers.count while found_modifier == undefined do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        if (classOf test_modifier == Turn_to_Poly) and (test_modifier.name == wall_thickness_t_edge_input_modifier_name) then
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
Removes the current FIX T EDGE CORNERS Edit Poly plus any legacy prefixed case layers and input converter.
Lower Wall Thickness stages and unrelated modifiers remain untouched.
*/
function removeWallThicknessTEdgeFixModifier source_node =
(
        if isValidNode source_node then
        (
                for modifier_id = source_node.modifiers.count to 1 by -1 do
                (
                        test_modifier = source_node.modifiers[modifier_id]
                        test_name = test_modifier.name as string
                        is_t_edge_case =
                                (classOf test_modifier == Edit_Poly) and
                                (findString test_name wall_thickness_t_edge_fix_modifier_name == 1)
                        if is_t_edge_case then
                        (
                                deleteModifier source_node modifier_id
                        )
                )
                t_edge_input_modifier = getWallThicknessTEdgeInputModifier source_node
                if t_edge_input_modifier != undefined then
                (
                        deleteModifier source_node t_edge_input_modifier
                )
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
                try (deleteUserProp source_node wall_thickness_inner_fix_enabled_prop) catch ()
                try (deleteUserProp source_node wall_thickness_change_material_ids_prop) catch ()
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
Adds one generated face to a material-preservation group.
Faces sharing the same source Material ID are committed together after geometry creation.
*/
function addWallThicknessMaterialFace material_ids material_face_bits material_id face_id =
(
        material_index = findItem material_ids material_id
        if material_index == 0 then
        (
                append material_ids material_id
                new_face_bits = #{}
                new_face_bits[face_id] = true
                append material_face_bits new_face_bits
        )
        else
        (
                material_face_bits[material_index][face_id] = true
        )
        true
        -- return
)
/*
Applies inherited source Material IDs to newly generated faces only.
Existing source faces are never reassigned by EXTRUDE / UPDATE.
*/
function applyWallThicknessInheritedMaterialIds edit_modifier source_node material_ids material_face_bits =
(
        if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return false
        if not isValidNode source_node then return false
        if material_ids.count != material_face_bits.count then return false
        for material_index = 1 to material_ids.count do
        (
                setEditPolyMaterialID edit_modifier source_node material_face_bits[material_index] material_ids[material_index]
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
Performs the explicit PREP 01 hard transform reset every time it is requested.
The full current stack is baked by Reset XForm + collapse, then Reset Pivot restores the node pivot to its creation position/orientation.
*/
function resetWallThicknessXFormHard source_node =
(
        if not isValidNode source_node then
        (
                #(false, false, "invalid node")
        )
        else
        (
                reset_succeeded = false
                failure_text = ""
                try
                (
                        resetXForm source_node
                        collapseStack source_node
                        resetPivot source_node
                        update source_node
                        if classOf source_node.baseObject == Editable_Poly then
                        (
                                source_node.baseObject.showCage = off
                        )
                        prop_name = getWallThicknessXFormUserPropName source_node
                        if prop_name != undefined then
                        (
                                setUserProp source_node prop_name true
                        )
                        reset_succeeded = true
                        format "Wall Thickness HARD RESET XFORM: % | RESET XFORM + COLLAPSE + RESET PIVOT complete\n" source_node.name
                )
                catch
                (
                        exception_text = getCurrentException()
                        failure_text = exception_text as string
                        reset_succeeded = false
                        format "Wall Thickness HARD RESET XFORM ERROR [%]: %\n" source_node.name failure_text
                )
                if reset_succeeded then
                (
                        #(true, true, "HARD RESET XFORM + COLLAPSE + RESET PIVOT complete")
                )
                else
                (
                        #(false, false, ("HARD RESET XFORM failed: " + failure_text))
                )
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
        xform_data = resetWallThicknessXFormHard source_node
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
When change_material_ids is false, source faces keep their Material IDs and generated inner/strip faces inherit the corresponding source Material ID.
When change_material_ids is true, source/outer faces become 1, generated inner faces become 2, and border strips become 3.
Generated inner faces copy the evaluated source polygon boundaries, so quads/ngons keep hidden internal triangulation instead of becoming separate visible triangle faces.
*/
function buildWallThicknessModifier source_node thickness change_material_ids:false =
(
        if not isValidNode source_node then
        (
                undefined
        )
        else
        (
                removeWallThicknessInnerCornerFixModifier source_node
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
                        Rebind the empty WALL THICKNESS Edit Poly and capture its polygon topology before
                        any additional evaluated-stack snapshot. snapshotAsMesh can invalidate a live
                        Edit Poly topology read even though the evaluated geometry itself is unchanged.
                        */
                        edit_modifier.SetPrimaryNode source_node
                        edit_modifier.useStackSelection = false
                        edit_modifier.selectMode = 0
                        modPanel.setCurrentObject edit_modifier node:source_node
                        modifier_source_vert_count = edit_modifier.GetNumVertices node:source_node
                        modifier_source_face_count = edit_modifier.GetNumFaces node:source_node
                        /*
                        Capture source polygon boundaries from the same live Edit Poly topology that will
                        receive the generated geometry. TriMesh face IDs are never used as polygon IDs.
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
                        source_polygon_material_ids = #()
                        for face_id = 1 to modifier_source_face_count do
                        (
                                append source_polygon_material_ids (edit_modifier.GetFaceMaterial face_id node:source_node)
                        )
                        /*
                        The TriMesh snapshot is used only for world-space vertex/normal calculations and
                        open-border discovery. Vertex count must still match the live Edit Poly input.
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
                                if modifier_source_vert_count != source_vert_count then
                                (
                                        format "Wall Thickness EXTRUDE SOURCE TOPOLOGY MISMATCH: Edit Poly verts % | snapshot verts % | Edit Poly polygons %\n" modifier_source_vert_count source_vert_count modifier_source_face_count
                                        deleteModifier source_node edit_modifier
                                        free source_mesh
                                        messageBox "Source topology changed while creating thickness. WALL THICKNESS was not applied." title:"Wall Thickness"
                                        undefined
                                )
                                else
                                (
                                setUserProp source_node wall_thickness_source_vert_count_prop modifier_source_vert_count
                                setUserProp source_node wall_thickness_source_face_count_prop modifier_source_face_count
                                /*
                                snapshotAsMesh has finished its read-only work. Restore the same Edit Poly
                                as the active live writer before any CreateVertex/CreateFace operation.
                                */
                                edit_modifier.SetPrimaryNode source_node
                                edit_modifier.useStackSelection = false
                                edit_modifier.selectMode = 0
                                modPanel.setCurrentObject edit_modifier node:source_node
                                outer_face_ids = #{1..modifier_source_face_count}
                                offset_vertex_ids = #()
                                inner_face_ids = #{}
                                strip_face_ids = #{}
                                inherited_material_ids = #()
                                inherited_material_face_bits = #()
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
                                                        addWallThicknessMaterialFace inherited_material_ids inherited_material_face_bits source_polygon_material_ids[face_id] new_face_id
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
                                                source_edge_faces = (meshop.getFacesUsingEdge source_mesh #{edge_id}) as array
                                                if source_edge_faces.count == 1 then
                                                (
                                                        strip_material_id = meshop.getFaceMatID source_mesh source_edge_faces[1]
                                                        new_face_id = edit_modifier.CreateFace #(vertex_a, vertex_b, offset_b, offset_a) node:source_node
                                                        if new_face_id != undefined then
                                                        (
                                                                strip_face_ids[new_face_id] = true
                                                                addWallThicknessMaterialFace inherited_material_ids inherited_material_face_bits strip_material_id new_face_id
                                                        )
                                                )
                                        )
                                )
                                edit_modifier.Commit()
                                material_assignment_succeeded = true
                                if change_material_ids then
                                (
                                        material_assignment_succeeded = setEditPolyMaterialID edit_modifier source_node outer_face_ids 1
                                        if material_assignment_succeeded then material_assignment_succeeded = setEditPolyMaterialID edit_modifier source_node inner_face_ids 2
                                        if material_assignment_succeeded then material_assignment_succeeded = setEditPolyMaterialID edit_modifier source_node strip_face_ids 3
                                )
                                else
                                (
                                        material_assignment_succeeded = applyWallThicknessInheritedMaterialIds edit_modifier source_node inherited_material_ids inherited_material_face_bits
                                )
                                if not material_assignment_succeeded then
                                (
                                        deleteModifier source_node edit_modifier
                                        free source_mesh
                                        messageBox "Unable to assign Wall Thickness Material IDs." title:"Wall Thickness"
                                        return undefined
                                )
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
                        xform_data = resetWallThicknessXFormHard source_node
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
Runs PREP 01 HARD RESET XFORM on every currently selected object in one undo entry.
Every click invalidates later Wall Thickness PREP/result history, bakes the current stack, and resets the pivot.
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
                /*
                Wall Thickness relies on contiguous source vertex IDs because generated vertices map as
                source_id + source_vert_count. Editable Poly can retain dead SO elements after prior edits;
                Edit Poly counts those dead vertex slots while snapshotAsMesh omits them. Compact dead
                structures only when the source is the bare Editable Poly base object, before WALL THICKNESS
                is added, so both topology representations start from the same contiguous live vertex IDs.
                */
                if (classOf source_node.baseObject == Editable_Poly) and (source_node.modifiers.count == 0) then
                (
                        dead_struct_flags = polyop.GetHasDeadStructs source_node.baseObject
                        if dead_struct_flags != 0 then
                        (
                                dead_vertex_slots_before = polyop.getNumVerts source_node.baseObject
                                polyop.CollapseDeadStructs source_node.baseObject
                                update source_node
                                remaining_dead_struct_flags = polyop.GetHasDeadStructs source_node.baseObject
                                compact_vertex_count = polyop.getNumVerts source_node.baseObject
                                format "Wall Thickness EXTRUDE SOURCE COMPACT: dead flags % | vertex slots % -> % | remaining dead flags %\n" dead_struct_flags dead_vertex_slots_before compact_vertex_count remaining_dead_struct_flags
                                if remaining_dead_struct_flags != 0 then
                                (
                                        messageBox "Unable to compact dead Editable Poly elements before creating thickness. WALL THICKNESS was not applied." title:"Wall Thickness"
                                        return false
                                )
                        )
                )
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
Creates or rebuilds WALL THICKNESS with the complete v0.08 extrusion builder.
When auto_fix_inner is true, EXTRUDE / UPDATE always runs the stable FIX INNER CORNERS planner and creates the deformation-only fix modifier only when correction targets exist.
FIX T EDGE CORNERS is a manual non-destructive modifier pass. Thickness rebuilds remove its topology layer and it is reapplied manually when needed.
When auto_fix_inner is false, EXTRUDE ONLY creates the raw WALL THICKNESS modifier and removes every automatic post-fix layer.
*/
function applyWallThickness source_node thickness change_material_ids:false auto_fix_inner:false =
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
                auto_fix_succeeded = true
                auto_fix_bad_edge_count = 0
                auto_fix_moved_vertex_count = 0
                thickness_modifier = undefined
                undo "Wall Thickness Extrude" on
                (
                        removeWallThicknessTEdgeFixModifier source_node
                        setObjectWallThickness source_node thickness
                        setObjectWallThicknessChangeMaterialIds source_node change_material_ids
                        setObjectWallThicknessInnerFixEnabled source_node false
                        if prepareWallThicknessV008Extrude source_node show_stl_messages:true then
                        (
                                if auto_fix_inner then
                                (
                                        rebuild_data = rebuildWallThicknessWithInnerCorners source_node thickness change_material_ids:change_material_ids
                                        auto_fix_succeeded = rebuild_data[1]
                                        auto_fix_bad_edge_count = rebuild_data[2]
                                        auto_fix_moved_vertex_count = rebuild_data[3]
                                        thickness_modifier = rebuild_data[4]
                                        if auto_fix_succeeded then
                                        (
                                                setObjectWallThicknessInnerFixEnabled source_node true
                                        )
                                )
                                else
                                (
                                        thickness_modifier = buildWallThicknessModifier source_node thickness change_material_ids:change_material_ids
                                )
                                if thickness_modifier != undefined then
                                (
                                        try (thickness_modifier.showCage = off) catch ()
                                )
                        )
                        apply_succeeded = thickness_modifier != undefined and auto_fix_succeeded
                )
                if thickness_modifier != undefined then wall_thickness_target = source_node else wall_thickness_target = undefined
                if apply_succeeded then
                (
                        material_mode_text = if change_material_ids then "OUTER 1 | INNER 2 | STRIP 3" else "source Material IDs preserved"
                        if auto_fix_inner then
                        (
                                if auto_fix_moved_vertex_count > 0 then
                                (
                                        format "Wall Thickness EXTRUDE / UPDATE: complete v0.08 builder | % | automatic FIX INNER CORNERS | bad edges % | corrected vertices %.\n" material_mode_text auto_fix_bad_edge_count auto_fix_moved_vertex_count
                                )
                                else
                                (
                                        format "Wall Thickness EXTRUDE / UPDATE: complete v0.08 builder | % | automatic FIX INNER CORNERS check | no correction required.\n" material_mode_text
                                )
                        )
                        else
                        (
                                format "Wall Thickness EXTRUDE ONLY: complete v0.08 builder | % | raw extrusion | single WALL THICKNESS modifier only.\n" material_mode_text
                        )
                        true
                )
                else
                (
                        if auto_fix_inner and thickness_modifier != undefined then
                        (
                                setObjectWallThicknessInnerFixEnabled source_node false
                                messageBox "WALL THICKNESS was created, but automatic FIX INNER CORNERS failed. The raw extrusion remains available for manual inspection." title:"Wall Thickness"
                        )
                        false
                )
        )
        -- return
)
/*
Rebuilds the tool-owned wall-thickness state after a spinner change.
When FIX INNER CORNERS is enabled, WALL THICKNESS and its deformation-only fix modifier are recreated from the untouched source.
Any experimental FIX T EDGE CORNERS helper layers are removed before rebuilding the lower thickness/inner-corner stack. T-edge is reapplied manually when needed.
*/
function updateDynamicWallThickness thickness change_material_ids:false =
(
        update_succeeded = true
        if isValidNode wall_thickness_target then
        (
                live_modifier = getWallThicknessModifier wall_thickness_target
                cleanup_modifier = getWallThicknessCleanupModifier wall_thickness_target
                outer_modifier = getWallThicknessChamferFixModifier wall_thickness_target
                if live_modifier != undefined and cleanup_modifier == undefined and outer_modifier == undefined then
                (
                        saveWallThicknessSetting thickness
                        setObjectWallThickness wall_thickness_target thickness
                        setObjectWallThicknessChangeMaterialIds wall_thickness_target change_material_ids
                        inner_fix_enabled = getObjectWallThicknessInnerFixEnabled wall_thickness_target
                        with undo off
                        (
                                removeWallThicknessTEdgeFixModifier wall_thickness_target
                                removeWallThicknessNamedModifier wall_thickness_target wall_thickness_auto_quadrify_modifier_name
                                updated_modifier = undefined
                                if inner_fix_enabled then
                                (
                                        rebuild_data = rebuildWallThicknessWithInnerCorners wall_thickness_target thickness change_material_ids:change_material_ids
                                        if rebuild_data[1] then updated_modifier = rebuild_data[4]
                                )
                                else
                                (
                                        updated_modifier = buildWallThicknessModifier wall_thickness_target thickness change_material_ids:change_material_ids
                                )
                                if updated_modifier != undefined then
                                (
                                        try (updated_modifier.showCage = off) catch ()
                                )
                                else
                                (
                                        update_succeeded = false
                                )
                        )
                )
        )
        update_succeeded
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
Loads the extracted FIX INNER CORNERS planning module from the current repository.
The public planWallThicknessInnerCorners() function name and behavior remain unchanged.
*/
wall_thickness_inner_corners_module_path = (getFilenamePath wall_thickness_source_file_path) + "Wall-Thickness-Inner-Corners.ms"
if doesFileExist wall_thickness_inner_corners_module_path then
(
        fileIn wall_thickness_inner_corners_module_path
)
else
(
        throw ("Missing Wall Thickness inner-corners module: " + wall_thickness_inner_corners_module_path)
)
/*
Creates the persistent deformation-only FIX INNER CORNERS modifier from stable planned world-space target positions, converted to modifier-local space before storage.
The incoming WALL THICKNESS topology is not changed.
*/
function createWallThicknessInnerCornerFixModifier source_node planned_targets =
(
        if not isValidNode source_node then
        (
                undefined
        )
        else if planned_targets == undefined or planned_targets.count == 0 then
        (
                undefined
        )
        else
        (
                removeWallThicknessInnerCornerFixModifier source_node
                fix_modifier = WallThicknessInnerCornerFixMod()
                fix_modifier.name = wall_thickness_inner_fix_modifier_name
                fix_modifier.target_vertex_ids.count = planned_targets.count
                fix_modifier.target_positions.count = planned_targets.count
                inverse_object_tm = inverse source_node.objectTransform
                targets_valid = true
                for target_index = 1 to planned_targets.count while targets_valid do
                (
                        target_data = planned_targets[target_index]
                        if target_data == undefined or target_data.count < 2 then
                        (
                                targets_valid = false
                        )
                        else
                        (
                                target_vertex_id = target_data[1] as integer
                                target_world_position = target_data[2]
                                target_local_position = target_world_position * inverse_object_tm
                                if target_vertex_id < 1 then
                                (
                                        targets_valid = false
                                )
                                else
                                (
                                        fix_modifier.target_vertex_ids[target_index] = target_vertex_id
                                        fix_modifier.target_positions[target_index] = target_local_position
                                )
                        )
                )
                if not targets_valid then
                (
                        undefined
                )
                else
                (
                        addModifier source_node fix_modifier
                        update source_node
                        fix_modifier
                )
        )
        -- return
)
/*
Rebuilds WALL THICKNESS from the untouched source, plans FIX INNER CORNERS against that raw result, then adds one deformation-only fix modifier above it.
Thickness updates remove/recreate both tool-owned modifiers from the original source, so no movement accumulates.
*/
function rebuildWallThicknessWithInnerCorners source_node thickness change_material_ids:false =
(
        if not isValidNode source_node then
        (
                #(false, 0, 0, undefined)
        )
        else if thickness <= 0 then
        (
                #(false, 0, 0, undefined)
        )
        else
        (
                removeWallThicknessInnerCornerFixModifier source_node
                raw_modifier = buildWallThicknessModifier source_node thickness change_material_ids:change_material_ids
                if raw_modifier == undefined then
                (
                        #(false, 0, 0, undefined)
                )
                else
                (
                        planned_targets = #()
                        plan_data = planWallThicknessInnerCorners source_node planned_targets
                        if plan_data == undefined or plan_data[1] != true then
                        (
                                #(false, 0, 0, raw_modifier)
                        )
                        else if planned_targets.count == 0 then
                        (
                                removeWallThicknessInnerCornerFixModifier source_node
                                #(true, plan_data[2], 0, raw_modifier)
                        )
                        else
                        (
                                tolerance = units.decodeValue "0.01mm"
                                raw_mesh = snapshotAsMesh source_node
                                raw_vertex_count = if raw_mesh != undefined then meshop.getNumVerts raw_mesh else 0
                                raw_face_count = if raw_mesh != undefined then meshop.getNumFaces raw_mesh else 0
                                source_vert_count_value = getUserProp source_node wall_thickness_source_vert_count_prop
                                source_vert_count = if source_vert_count_value != undefined then source_vert_count_value as integer else 0
                                raw_source_positions = #()
                                if raw_mesh != undefined and source_vert_count > 0 and source_vert_count <= raw_vertex_count then
                                (
                                        raw_source_positions = for source_id = 1 to source_vert_count collect (getVert raw_mesh source_id)
                                )
                                fix_modifier = createWallThicknessInnerCornerFixModifier source_node planned_targets
                                build_succeeded = fix_modifier != undefined
                                moved_vertex_count = 0
                                fixed_mesh = if build_succeeded then snapshotAsMesh source_node else undefined
                                if build_succeeded and fixed_mesh == undefined then
                                (
                                        logWallThicknessInnerCornerDump #("NON-DESTRUCTIVE FIX FAIL SNAPSHOT")
                                        build_succeeded = false
                                )
                                if build_succeeded then
                                (
                                        fixed_vertex_count = meshop.getNumVerts fixed_mesh
                                        fixed_face_count = meshop.getNumFaces fixed_mesh
                                        if fixed_vertex_count != raw_vertex_count or fixed_face_count != raw_face_count then
                                        (
                                                logWallThicknessInnerCornerDump #("NON-DESTRUCTIVE FIX FAIL TOPOLOGY", raw_vertex_count, fixed_vertex_count, raw_face_count, fixed_face_count)
                                                build_succeeded = false
                                        )
                                )
                                if build_succeeded and (source_vert_count < 1 or raw_source_positions.count != source_vert_count) then
                                (
                                        logWallThicknessInnerCornerDump #("NON-DESTRUCTIVE FIX FAIL SOURCE SNAPSHOT", source_vert_count, raw_source_positions.count)
                                        build_succeeded = false
                                )
                                if build_succeeded then
                                (
                                        for source_id = 1 to source_vert_count while build_succeeded do
                                        (
                                                fixed_source_position = getVert fixed_mesh source_id
                                                if distance fixed_source_position raw_source_positions[source_id] > tolerance then
                                                (
                                                        logWallThicknessInnerCornerDump #("NON-DESTRUCTIVE FIX FAIL SOURCE MOVE", source_id, raw_source_positions[source_id], fixed_source_position)
                                                        build_succeeded = false
                                                )
                                        )
                                )
                                if build_succeeded then
                                (
                                        for target_data in planned_targets while build_succeeded do
                                        (
                                                target_generated_id = target_data[1] as integer
                                                target_world_position = target_data[2]
                                                original_world_position = target_data[3]
                                                if target_generated_id < 1 or target_generated_id > raw_vertex_count then
                                                (
                                                        logWallThicknessInnerCornerDump #("NON-DESTRUCTIVE FIX FAIL TARGET ID", target_generated_id, raw_vertex_count)
                                                        build_succeeded = false
                                                )
                                                else
                                                (
                                                        actual_world_position = getVert fixed_mesh target_generated_id
                                                        if distance actual_world_position target_world_position <= tolerance and distance actual_world_position original_world_position > tolerance then
                                                        (
                                                                moved_vertex_count += 1
                                                                if not loadWallThicknessQuietMode() then
                                (
                                        logWallThicknessInnerCornerDump #("NON-DESTRUCTIVE FIX TARGET", target_generated_id, original_world_position, target_world_position, actual_world_position)
                                )
                                                        )
                                                        else
                                                        (
                                                                logWallThicknessInnerCornerDump #("NON-DESTRUCTIVE FIX FAIL TARGET", target_generated_id, original_world_position, target_world_position, actual_world_position)
                                                                build_succeeded = false
                                                        )
                                                )
                                        )
                                )
                                if raw_mesh != undefined then free raw_mesh
                                if fixed_mesh != undefined then free fixed_mesh
                                if build_succeeded then
                                (
                                        format "Wall Thickness FIX INNER CORNERS NON-DESTRUCTIVE: bad edges % | corrected vertices % | WALL THICKNESS + FIX INNER CORNERS modifiers.\n" plan_data[2] moved_vertex_count
                                        #(true, plan_data[2], moved_vertex_count, raw_modifier)
                                )
                                else
                                (
                                        removeWallThicknessInnerCornerFixModifier source_node
                                        #(false, plan_data[2], moved_vertex_count, raw_modifier)
                                )
                        )
                )
        )
        -- return
)
/*
Rebuilds WALL THICKNESS and recreates the deformation-only FIX INNER CORNERS modifier above it.
No stack collapse occurs; future thickness updates remember and reapply both tool-owned modifiers from the original source.
*/
function fixWallThicknessInnerCorners source_node change_material_ids:undefined =
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
                thickness = getObjectWallThickness source_node
                use_material_ids = if change_material_ids == undefined then getObjectWallThicknessChangeMaterialIds source_node else change_material_ids
                rebuild_data = #(false, 0, 0, undefined)
                undo "Wall Thickness - Fix Inner Corners" on
                (
                        removeWallThicknessTEdgeFixModifier source_node
                        rebuild_data = rebuildWallThicknessWithInnerCorners source_node thickness change_material_ids:use_material_ids
                        if rebuild_data[1] then
                        (
                                setObjectWallThicknessInnerFixEnabled source_node true
                                setObjectWallThicknessChangeMaterialIds source_node use_material_ids
                                wall_thickness_target = source_node
                        )
                )
                #(rebuild_data[1], rebuild_data[2], rebuild_data[3])
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
Moves both newly cut strip vertices independently onto the fixed-anchor X/Y inside the T-edge Edit Poly modifier.
The two cuts may start with different X/Y drift; each keeps its own original Z.
*/
function moveWallThicknessTEdgeVerticalCutToAnchor edit_modifier source_node top_vertex_id bottom_vertex_id fixed_anchor_position tolerance =
(
        if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return false
        if not isValidNode source_node then return false
        top_position = EditPolyMod.GetVertex edit_modifier top_vertex_id node:source_node
        bottom_position = EditPolyMod.GetVertex edit_modifier bottom_vertex_id node:source_node
        if top_position == undefined or bottom_position == undefined then return false
        top_target = [fixed_anchor_position.x, fixed_anchor_position.y, top_position.z]
        bottom_target = [fixed_anchor_position.x, fixed_anchor_position.y, bottom_position.z]
        object_tm = source_node.objectTransform
        top_world_delta = (top_target * object_tm) - (top_position * object_tm)
        bottom_world_delta = (bottom_target * object_tm) - (bottom_position * object_tm)
        top_bits = #{}
        top_bits[top_vertex_id] = true
        if not WallThicknessPreprocess.selectModifierComponents source_node edit_modifier #Vertex top_bits then return false
        EditPolyMod.MoveSelection edit_modifier top_world_delta
        EditPolyMod.Commit edit_modifier
        update source_node
        moved_top_position = EditPolyMod.GetVertex edit_modifier top_vertex_id node:source_node
        if moved_top_position == undefined or distance moved_top_position top_target > tolerance then return false
        bottom_bits = #{}
        bottom_bits[bottom_vertex_id] = true
        if not WallThicknessPreprocess.selectModifierComponents source_node edit_modifier #Vertex bottom_bits then return false
        EditPolyMod.MoveSelection edit_modifier bottom_world_delta
        EditPolyMod.Commit edit_modifier
        update source_node
        moved_top_position = EditPolyMod.GetVertex edit_modifier top_vertex_id node:source_node
        moved_bottom_position = EditPolyMod.GetVertex edit_modifier bottom_vertex_id node:source_node
        if moved_top_position == undefined or moved_bottom_position == undefined then return false
        top_matches = distance moved_top_position top_target <= tolerance
        bottom_matches = distance moved_bottom_position bottom_target <= tolerance
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
Copies the Material ID onto the one new T-edge polygon from an adjacent wall face
whose polygon normal is the closest same-direction match to the new face normal.
No specific strip edge is used as a material source.
*/
function fixWallThicknessTEdgeNewWallFaceMaterial edit_modifier source_node generated_top_vertex_id generated_bottom_vertex_id fixed_anchor_vertex_id fixed_bottom_vertex_id =
(
        changed_face_count = 0
        selected_faces = edit_modifier.GetSelection #Face node:source_node
        if selected_faces == undefined or selected_faces.numberSet != 1 then return changed_face_count
        selected_face_ids = selected_faces as array
        target_face_id = selected_face_ids[1]
        target_face_degree = EditPolyMod.GetFaceDegree edit_modifier target_face_id node:source_node
        if target_face_degree != 4 then return changed_face_count
        if not wallThicknessTEdgeFaceUsesVertex edit_modifier source_node target_face_id generated_top_vertex_id then return changed_face_count
        if not wallThicknessTEdgeFaceUsesVertex edit_modifier source_node target_face_id generated_bottom_vertex_id then return changed_face_count
        if not wallThicknessTEdgeFaceUsesVertex edit_modifier source_node target_face_id fixed_anchor_vertex_id then return changed_face_count
        if not wallThicknessTEdgeFaceUsesVertex edit_modifier source_node target_face_id fixed_bottom_vertex_id then return changed_face_count
        target_face_normal = getWallThicknessTEdgeFaceNormal edit_modifier source_node target_face_id
        if target_face_normal == [0,0,0] then return changed_face_count
        face_count = EditPolyMod.GetNumFaces edit_modifier node:source_node
        if face_count < 1 then return changed_face_count
        all_face_ids = #{1..face_count}
        edge_records = buildWallThicknessTEdgeRecords edit_modifier source_node all_face_ids
        reference_face_id = 0
        best_normal_dot = -2.0
        for edge_record in edge_records do
        (
                if (findItem edge_record[3] target_face_id) > 0 then
                (
                        for neighbor_face_id in edge_record[3] do
                        (
                                if neighbor_face_id != target_face_id then
                                (
                                        neighbor_face_normal = getWallThicknessTEdgeFaceNormal edit_modifier source_node neighbor_face_id
                                        if neighbor_face_normal != [0,0,0] then
                                        (
                                                normal_dot = dot target_face_normal neighbor_face_normal
                                                if normal_dot > best_normal_dot then
                                                (
                                                        best_normal_dot = normal_dot
                                                        reference_face_id = neighbor_face_id
                                                )
                                        )
                                )
                        )
                )
        )
        if reference_face_id < 1 or best_normal_dot <= 0.0 then return changed_face_count
        reference_material_id = EditPolyMod.GetFaceMaterial edit_modifier reference_face_id node:source_node
        target_material_id = EditPolyMod.GetFaceMaterial edit_modifier target_face_id node:source_node
        if reference_material_id < 1 then return changed_face_count
        if target_material_id != reference_material_id then
        (
                edit_modifier.SetSelection #Face selected_faces node:source_node
                edit_modifier.materialIDToSet = reference_material_id
                edit_modifier.SetOperation #SetMaterial
                edit_modifier.Commit()
                edit_modifier.RefreshScreen()
                completeRedraw()
                if EditPolyMod.GetFaceMaterial edit_modifier target_face_id node:source_node == reference_material_id then
                (
                        changed_face_count = 1
                        format "FIX T EDGE CORNERS MATERIAL: selected new face F% | same-normal neighbor F% | normal dot % | Material ID % -> %\n" target_face_id reference_face_id best_normal_dot target_material_id reference_material_id
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
Moves the new T-edge vertical cut directly on the baked Editable Poly.
This topology-changing pass remains destructive even though FIX INNER CORNERS is now non-destructive.
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
Captures the untouched Editable Poly base topology and positions for before/after verification.
The signature deliberately ignores the modifier stack and reads only source_node.baseObject.
*/
function getWallThicknessBaseTopologySignature source_node =
(
        if not isValidNode source_node then return undefined
        if classOf source_node.baseObject != Editable_Poly then return undefined
        poly_object = source_node.baseObject
        vertex_count = polyop.getNumVerts poly_object
        edge_count = polyop.getNumEdges poly_object
        face_count = polyop.getNumFaces poly_object
        vertex_positions = #()
        edge_vertices = #()
        face_vertices = #()
        for vertex_id = 1 to vertex_count do
        (
                append vertex_positions (polyop.getVert poly_object vertex_id)
        )
        for edge_id = 1 to edge_count do
        (
                append edge_vertices (polyop.getEdgeVerts poly_object edge_id)
        )
        for face_id = 1 to face_count do
        (
                append face_vertices (polyop.getFaceVerts poly_object face_id)
        )
        #(vertex_count, edge_count, face_count, vertex_positions, edge_vertices, face_vertices)
        -- return
)
/*
Compares two Editable Poly base signatures exactly.
Any base topology or position change fails the non-destructive T-edge contract.
*/
function wallThicknessBaseTopologySignaturesMatch signature_a signature_b =
(
        if signature_a == undefined or signature_b == undefined then return false
        if signature_a.count != 6 or signature_b.count != 6 then return false
        if signature_a[1] != signature_b[1] or signature_a[2] != signature_b[2] or signature_a[3] != signature_b[3] then return false
        matches = true
        for vertex_id = 1 to signature_a[4].count while matches do
        (
                if signature_a[4][vertex_id] != signature_b[4][vertex_id] then matches = false
        )
        for edge_id = 1 to signature_a[5].count while matches do
        (
                edge_a = signature_a[5][edge_id]
                edge_b = signature_b[5][edge_id]
                if edge_a.count != edge_b.count then
                (
                        matches = false
                )
                else
                (
                        for edge_vertex_index = 1 to edge_a.count while matches do
                        (
                                if edge_a[edge_vertex_index] != edge_b[edge_vertex_index] then matches = false
                        )
                )
        )
        for face_id = 1 to signature_a[6].count while matches do
        (
                face_a = signature_a[6][face_id]
                face_b = signature_b[6][face_id]
                if face_a.count != face_b.count then
                (
                        matches = false
                )
                else
                (
                        for face_vertex_index = 1 to face_a.count while matches do
                        (
                                if face_a[face_vertex_index] != face_b[face_vertex_index] then matches = false
                        )
                )
        )
        matches
        -- return
)
/*
Plans T-edge repairs from a temporary baked copy of the fully evaluated FIX INNER CORNERS result.
The temporary copy is the 0.969 geometry oracle; the source node and its Editable Poly base remain untouched.
*/
function planWallThicknessTEdgeModifierRepairs source_node =
(
        if not isValidNode source_node then return #(false, #(), 0, 0, 0)
        stored_source_vert_count = getUserProp source_node wall_thickness_source_vert_count_prop
        stored_source_face_count = getUserProp source_node wall_thickness_source_face_count_prop
        stored_thickness = getUserProp source_node wall_thickness_user_prop
        if stored_source_vert_count == undefined or stored_source_face_count == undefined or stored_thickness == undefined then return #(false, #(), 0, 0, 0)
        source_vert_count = stored_source_vert_count as integer
        source_face_count = stored_source_face_count as integer
        wall_thickness = stored_thickness as float
        tolerance = units.decodeValue "0.01mm"
        planned_cases = #()
        planner_node = undefined
        input_vertex_count = 0
        input_face_count = 0
        input_edge_count = 0
        plan_succeeded = false
        planner_exception_text = undefined
        try
        (
                with redraw off
                with undo off
                (
                        planner_node = copy source_node
                        planner_node.name = source_node.name + " T EDGE PLAN"
                        collapseStack planner_node
                        update planner_node
                )
                if planner_node == undefined or not isValidNode planner_node then throw "could not create temporary baked T-edge planner copy"
                if classOf planner_node.baseObject != Editable_Poly then throw "temporary T-edge planner did not bake to Editable Poly"
                try (planner_node.showCage = off) catch ()
                try (planner_node.baseObject.showCage = off) catch ()
                input_vertex_count = planner_node.GetNumVertices()
                input_face_count = planner_node.GetNumFaces()
                input_edge_count = planner_node.GetNumEdges()
                detected_cases = detectWallThicknessTEdgeBaseCases planner_node source_vert_count source_face_count wall_thickness
                format "FIX T EDGE CORNERS BASE DETECT: % case(s)\n" detected_cases.count
                for case_data in detected_cases do
                (
                        anchor_source_id = case_data[1]
                        branch_neighbor_id = case_data[2]
                        continuation_source_id = case_data[4]
                        continuing_plan_source_id = case_data[7]
                        anchor_fraction_from_source = case_data[8]
                        generated_anchor_id = anchor_source_id + source_vert_count
                        generated_continuation_id = continuation_source_id + source_vert_count
                        generated_plan_id = continuing_plan_source_id + source_vert_count
                        branch_edge_id = findWallThicknessTEdgeBaseEdge planner_node anchor_source_id branch_neighbor_id
                        upper_cross_edge_id = findWallThicknessTEdgeBaseEdge planner_node anchor_source_id generated_anchor_id
                        lower_cross_edge_id = findWallThicknessTEdgeBaseEdge planner_node continuation_source_id generated_continuation_id
                        generated_vertical_edge_id = findWallThicknessTEdgeBaseEdge planner_node generated_anchor_id generated_continuation_id
                        generated_plan_edge_id = findWallThicknessTEdgeBaseEdge planner_node generated_anchor_id generated_plan_id
                        if branch_edge_id < 1 then throw "planner could not resolve T branch edge"
                        if upper_cross_edge_id < 1 then throw "planner could not resolve upper strip cross-edge"
                        if lower_cross_edge_id < 1 then throw "planner could not resolve lower strip cross-edge"
                        if generated_vertical_edge_id < 1 then throw "planner could not resolve generated vertical strip edge"
                        if generated_plan_edge_id < 1 then throw "planner could not resolve generated continuing wall edge"
                        source_anchor_position = planner_node.GetVertex anchor_source_id
                        branch_neighbor_position = planner_node.GetVertex branch_neighbor_id
                        generated_anchor_position = planner_node.GetVertex generated_anchor_id
                        continuation_position = planner_node.GetVertex continuation_source_id
                        generated_continuation_position = planner_node.GetVertex generated_continuation_id
                        if source_anchor_position == undefined or branch_neighbor_position == undefined then throw "planner could not read T branch positions"
                        if generated_anchor_position == undefined or continuation_position == undefined or generated_continuation_position == undefined then throw "planner could not read generated strip positions"
                        fixed_anchor_position = source_anchor_position + ((branch_neighbor_position - source_anchor_position) * anchor_fraction_from_source)
                        top_cut_position = source_anchor_position + ((generated_anchor_position - source_anchor_position) * 0.5)
                        bottom_cut_position = continuation_position + ((generated_continuation_position - continuation_position) * 0.5)
                        expected_top_position = [fixed_anchor_position.x, fixed_anchor_position.y, top_cut_position.z]
                        expected_bottom_position = [fixed_anchor_position.x, fixed_anchor_position.y, bottom_cut_position.z]
                        if distance expected_top_position fixed_anchor_position > tolerance then throw "planner upper cut Z does not match fixed anchor Z"
                        append planned_cases #(
                                anchor_source_id,
                                branch_neighbor_id,
                                continuation_source_id,
                                continuing_plan_source_id,
                                anchor_fraction_from_source,
                                fixed_anchor_position,
                                expected_bottom_position
                        )
                        format "FIX T EDGE CORNERS PLAN: source V% | branch V% | upper %-% | lower %-% | generated %-% | continuing %-% | anchor fraction % | target % | lower target %\n" anchor_source_id branch_neighbor_id anchor_source_id generated_anchor_id continuation_source_id generated_continuation_id generated_anchor_id generated_continuation_id generated_anchor_id generated_plan_id anchor_fraction_from_source fixed_anchor_position expected_bottom_position
                )
                plan_succeeded = true
        )
        catch
        (
                planner_exception_text = getCurrentException()
                plan_succeeded = false
                format "FIX T EDGE CORNERS PLAN ERROR: %\n" planner_exception_text
        )
        if planner_node != undefined and isValidNode planner_node then
        (
                try
                (
                        with undo off (delete planner_node)
                )
                catch
                (
                        planner_cleanup_exception_text = getCurrentException()
                        format "FIX T EDGE CORNERS PLAN CLEANUP ERROR: %\n" planner_cleanup_exception_text
                        plan_succeeded = false
                )
        )
        #(plan_succeeded, planned_cases, input_vertex_count, input_face_count, input_edge_count)
        -- return
)
/*
Creates a temporary baked Editable Poly probe for read-only regression comparison.
The probe is never used as a topology-ID authority by live FIX T EDGE CORNERS execution and is deleted after each comparison stage.
*/
function createWallThicknessTEdgePolyProbe source_node stage_name =
(
        probe_node = undefined
        probe_succeeded = false
        if not isValidNode source_node then return undefined
        try
        (
                with redraw off
                with undo off
                (
                        probe_node = copy source_node
                        probe_node.name = source_node.name + " T EDGE PROBE " + stage_name
                        collapseStack probe_node
                        update probe_node
                )
                if probe_node == undefined or not isValidNode probe_node then throw "could not create T-edge topology probe"
                if classOf probe_node.baseObject != Editable_Poly then throw "T-edge topology probe did not bake to Editable Poly"
                try (probe_node.showCage = off) catch ()
                try (probe_node.baseObject.showCage = off) catch ()
                probe_succeeded = true
        )
        catch
        (
                probe_exception_text = getCurrentException()
                format "FIX T EDGE CORNERS PROBE ERROR [%]: %\n" stage_name probe_exception_text
                probe_succeeded = false
        )
        if not probe_succeeded and probe_node != undefined and isValidNode probe_node then
        (
                try
                (
                        with undo off (delete probe_node)
                )
                catch
                (
                        probe_cleanup_exception_text = getCurrentException()
                        format "FIX T EDGE CORNERS PROBE CLEANUP ERROR [%]: %\n" stage_name probe_cleanup_exception_text
                )
                probe_node = undefined
        )
        probe_node
        -- return
)
/*
Deletes one temporary T-edge topology probe.
Probe cleanup failure is reported because leaked scene nodes would invalidate the development workflow.
*/
function deleteWallThicknessTEdgePolyProbe probe_node stage_name =
(
        cleanup_succeeded = true
        if probe_node != undefined and isValidNode probe_node then
        (
                try
                (
                        with undo off (delete probe_node)
                )
                catch
                (
                        cleanup_exception_text = getCurrentException()
                        cleanup_succeeded = false
                        format "FIX T EDGE CORNERS PROBE CLEANUP ERROR [%]: %\n" stage_name cleanup_exception_text
                )
        )
        cleanup_succeeded
        -- return
)
/*
Returns the compact polygon topology counts from one baked T-edge probe.
The returned order is vertices, faces, edges.
*/
function getWallThicknessTEdgeProbeCounts probe_node =
(
        if probe_node == undefined or not isValidNode probe_node then return #(0, 0, 0)
        if classOf probe_node.baseObject != Editable_Poly then return #(0, 0, 0)
        #(probe_node.GetNumVertices(), probe_node.GetNumFaces(), probe_node.GetNumEdges())
        -- return
)
/*
Connects the three live endpoint-resolved T-edge edges in one native Edit Poly operation.
The selection and ConnectEdges workflow mirrors EPoly-Stack-Test_1.10 and never interprets an operation status as a vertex ID.
*/
function executeWallThicknessTEdgeConnectEdges edit_modifier source_node connect_edges =
(
        if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return false
        if not isValidNode source_node then return false
        if connect_edges == undefined or classOf connect_edges != BitArray then return false
        if connect_edges.numberSet != 3 then return false
        edit_modifier.showCage = off
        edit_modifier.useStackSelection = false
        edit_modifier.selectMode = 0
        select source_node
        max modify mode
        edit_modifier.SetPrimaryNode source_node
        modPanel.setCurrentObject edit_modifier node:source_node
        edit_modifier.SetEPolySelLevel #Edge
        subObjectLevel = 2
        old_selection = edit_modifier.GetSelection #Edge node:source_node
        if old_selection.numberSet > 0 then
        (
                edit_modifier.Select #Edge old_selection select:false node:source_node
        )
        edit_modifier.Select #Edge connect_edges node:source_node
        stored_selection = edit_modifier.GetSelection #Edge node:source_node
        if stored_selection != connect_edges then return false
        edit_modifier.connectEdgeSegments = 1
        edit_modifier.connectEdgePinch = 0
        edit_modifier.connectEdgeSlide = 0
        edit_modifier.SetOperation #ConnectEdges
        edit_modifier.Commit()
        edit_modifier.RefreshScreen()
        completeRedraw()
        true
        -- return
)
/*
Compares material IDs of two collapsed Editable Poly probes face by face.
Topology correspondence must already be verified before this material comparison is used.
*/
function wallThicknessTEdgeProbeMaterialsMatch probe_a probe_b =
(
        if probe_a == undefined or probe_b == undefined then return false
        if not isValidNode probe_a or not isValidNode probe_b then return false
        if classOf probe_a.baseObject != Editable_Poly or classOf probe_b.baseObject != Editable_Poly then return false
        face_count_a = polyop.getNumFaces probe_a.baseObject
        face_count_b = polyop.getNumFaces probe_b.baseObject
        if face_count_a != face_count_b then return false
        matches = true
        for face_id = 1 to face_count_a while matches do
        (
                if polyop.getFaceMatID probe_a.baseObject face_id != polyop.getFaceMatID probe_b.baseObject face_id then matches = false
        )
        matches
        -- return
)
/*
Moves one newly connected T-edge vertical edge onto the branch anchor in XY.
Both edge vertices are selected and moved together in one Edit Poly MoveSelection call,
so their Z values and the vertical edge length are preserved exactly.
*/
function moveWallThicknessTEdgeLiveCutEdgeToAnchor edit_modifier source_node top_vertex_id bottom_vertex_id anchor_vertex_id tolerance =
(
        if edit_modifier == undefined or classOf edit_modifier != Edit_Poly then return false
        if not isValidNode source_node then return false
        if top_vertex_id < 1 or bottom_vertex_id < 1 or anchor_vertex_id < 1 then return false
        vertex_count = edit_modifier.GetNumVertices node:source_node
        if top_vertex_id > vertex_count or bottom_vertex_id > vertex_count or anchor_vertex_id > vertex_count then return false
        top_position = edit_modifier.GetVertex top_vertex_id node:source_node
        bottom_position = edit_modifier.GetVertex bottom_vertex_id node:source_node
        anchor_position = edit_modifier.GetVertex anchor_vertex_id node:source_node
        if top_position == undefined or bottom_position == undefined or anchor_position == undefined then return false
        original_bottom_z = bottom_position.z
        move_delta = [anchor_position.x - top_position.x, anchor_position.y - top_position.y, 0.0]
        select source_node
        max modify mode
        edit_modifier.SetPrimaryNode source_node
        edit_modifier.useStackSelection = false
        edit_modifier.selectMode = 0
        modPanel.setCurrentObject edit_modifier node:source_node
        edit_modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1
        old_vertices = edit_modifier.GetSelection #Vertex node:source_node
        if old_vertices.numberSet > 0 then
        (
                edit_modifier.Select #Vertex old_vertices select:false node:source_node
        )
        vertex_bits = #{}
        vertex_bits[top_vertex_id] = true
        vertex_bits[bottom_vertex_id] = true
        edit_modifier.Select #Vertex vertex_bits node:source_node
        stored_vertices = edit_modifier.GetSelection #Vertex node:source_node
        if stored_vertices != vertex_bits then return false
        edit_modifier.MoveSelection move_delta
        edit_modifier.Commit()
        edit_modifier.RefreshScreen()
        completeRedraw()
        moved_top_position = edit_modifier.GetVertex top_vertex_id node:source_node
        moved_bottom_position = edit_modifier.GetVertex bottom_vertex_id node:source_node
        anchor_after_move = edit_modifier.GetVertex anchor_vertex_id node:source_node
        if moved_top_position == undefined or moved_bottom_position == undefined or anchor_after_move == undefined then return false
        if distance moved_top_position anchor_after_move > tolerance then return false
        if abs (moved_bottom_position.x - anchor_after_move.x) > tolerance then return false
        if abs (moved_bottom_position.y - anchor_after_move.y) > tolerance then return false
        if moved_bottom_position.z != original_bottom_z then return false
        true
        -- return
)
/*
Returns only newly appended live vertices at one position.
The incoming topology count is used to exclude pre-existing coincident vertices.
*/
function getWallThicknessTEdgeNewVerticesAtPosition edit_modifier source_node target_position tolerance first_new_vertex_id =
(
        matched_vertex_ids = #()
        if edit_modifier != undefined and classOf edit_modifier == Edit_Poly and isValidNode source_node then
        (
                vertex_count = EditPolyMod.GetNumVertices edit_modifier node:source_node
                if first_new_vertex_id <= vertex_count then
                (
                        for vertex_id = first_new_vertex_id to vertex_count do
                        (
                                current_position = EditPolyMod.GetVertex edit_modifier vertex_id node:source_node
                                if current_position != undefined and distance current_position target_position <= tolerance then
                                (
                                        append matched_vertex_ids vertex_id
                                )
                        )
                )
        )
        matched_vertex_ids
        -- return
)
/*
Builds all planned T-edge repairs inside one normal Edit Poly above FIX INNER CORNERS.
The existing inner-corner deformation stays in place; the T-edge Edit Poly reads and edits that evaluated topology directly.
*/
function buildWallThicknessTEdgeFixModifier source_node planned_cases =
(
        if not isValidNode source_node then return #(false, 0, 0, 0, undefined, false)
        if planned_cases == undefined then return #(false, 0, 0, 0, undefined, false)
        source_vert_count_value = getUserProp source_node wall_thickness_source_vert_count_prop
        source_face_count_value = getUserProp source_node wall_thickness_source_face_count_prop
        if source_vert_count_value == undefined or source_face_count_value == undefined then return #(false, 0, 0, 0, undefined, false)
        source_vert_count = source_vert_count_value as integer
        source_face_count = source_face_count_value as integer
        tolerance = units.decodeValue "0.01mm"
        repaired_case_count = 0
        welded_vertex_count = 0
        material_face_count = 0
        build_succeeded = false
        inner_restored = false
        fix_modifier = undefined
        inner_fix_modifier = undefined
        thickness_modifier = getWallThicknessModifier source_node
        exception_text = undefined
        operation_stage = "initialize direct stacked Edit Poly"
        saved_selection = selection as array
        saved_sub_object_level = try (subObjectLevel) catch (0)
        saved_current_object = try (modPanel.getCurrentObject()) catch (undefined)
        if thickness_modifier == undefined or classOf thickness_modifier != Edit_Poly then return #(false, 0, 0, 0, undefined, false)
        removeWallThicknessTEdgeFixModifier source_node
        update source_node
        inner_fix_modifier = getWallThicknessInnerCornerFixModifier source_node
        try
        (
                /*
                Keep FIX INNER CORNERS live. The new T-edge Edit Poly is inserted above it,
                so its topology reads see the already-corrected evaluated wall positions.
                */
                inner_restored = inner_fix_modifier == undefined or getWallThicknessInnerCornerFixModifier source_node == inner_fix_modifier
                if not inner_restored then throw "FIX INNER CORNERS changed before T-edge authoring"
                if planned_cases.count == 0 then
                (
                        build_succeeded = true
                )
                else
                (
                        operation_stage = "create and bind WALL THICKNESS FIX T EDGE CORNERS"
                        fix_modifier = Edit_Poly()
                        fix_modifier.name = wall_thickness_t_edge_fix_modifier_name
                        fix_modifier.showCage = off
                        fix_modifier.useStackSelection = false
                        fix_modifier.selectMode = 0
                        addModifier source_node fix_modifier
                        if source_node.modifiers.count < 1 or source_node.modifiers[1] != fix_modifier then
                        (
                                throw "FIX T EDGE CORNERS was not added at the top of the modifier stack"
                        )
                        select source_node
                        max modify mode
                        fix_modifier.SetPrimaryNode source_node
                        modPanel.setCurrentObject fix_modifier node:source_node
                        fix_modifier.SetEPolySelLevel #Edge
                        subObjectLevel = 2
                        for case_index = 1 to planned_cases.count do
                        (
                                planned_case = planned_cases[case_index]
                                anchor_source_id = planned_case[1]
                                branch_neighbor_id = planned_case[2]
                                continuation_source_id = planned_case[3]
                                continuing_plan_source_id = planned_case[4]
                                planned_anchor_position = planned_case[6]
                                planned_bottom_position = planned_case[7]
                                generated_anchor_id = anchor_source_id + source_vert_count
                                generated_continuation_id = continuation_source_id + source_vert_count
                                generated_plan_id = continuing_plan_source_id + source_vert_count
                                operation_stage = "read live T-edge topology for case " + (case_index as string)
                                case_start_vertex_count = fix_modifier.GetNumVertices node:source_node
                                case_start_face_count = fix_modifier.GetNumFaces node:source_node
                                case_start_edge_count = fix_modifier.GetNumEdges node:source_node
                                format "FIX T EDGE CORNERS STACK CASE START: case % | verts % | polygons % | edges %\n" case_index case_start_vertex_count case_start_face_count case_start_edge_count
                                if source_vert_count < 1 or source_vert_count >= case_start_vertex_count then throw "invalid source vertex count in direct stacked T-edge modifier"
                                if source_face_count < 1 or source_face_count > case_start_face_count then throw "invalid source face count in direct stacked T-edge modifier"
                                operation_stage = "resolve live T-edge edge IDs for case " + (case_index as string)
                                branch_edge_id = findWallThicknessTEdgeLiveEdge fix_modifier source_node anchor_source_id branch_neighbor_id
                                upper_edge_id = findWallThicknessTEdgeLiveEdge fix_modifier source_node anchor_source_id generated_anchor_id
                                lower_edge_id = findWallThicknessTEdgeLiveEdge fix_modifier source_node continuation_source_id generated_continuation_id
                                generated_vertical_edge_id = findWallThicknessTEdgeLiveEdge fix_modifier source_node generated_anchor_id generated_continuation_id
                                generated_plan_edge_id = findWallThicknessTEdgeLiveEdge fix_modifier source_node generated_anchor_id generated_plan_id
                                format "FIX T EDGE CORNERS STACK MAP: branch E% | upper E% | lower E% | generated vertical E% | generated continuing E%\n" branch_edge_id upper_edge_id lower_edge_id generated_vertical_edge_id generated_plan_edge_id
                                if branch_edge_id < 1 then throw "direct stacked modifier could not map T branch edge"
                                if upper_edge_id < 1 then throw "direct stacked modifier could not map upper strip edge"
                                if lower_edge_id < 1 then throw "direct stacked modifier could not map lower strip edge"
                                if generated_vertical_edge_id < 1 then throw "direct stacked modifier could not map generated vertical edge"
                                if generated_plan_edge_id < 1 then throw "direct stacked modifier could not map generated continuing edge"
                                upper_source_position = fix_modifier.GetVertex anchor_source_id node:source_node
                                upper_generated_position = fix_modifier.GetVertex generated_anchor_id node:source_node
                                lower_source_position = fix_modifier.GetVertex continuation_source_id node:source_node
                                lower_generated_position = fix_modifier.GetVertex generated_continuation_id node:source_node
                                branch_neighbor_position = fix_modifier.GetVertex branch_neighbor_id node:source_node
                                if upper_source_position == undefined or upper_generated_position == undefined then throw "direct stacked modifier could not read upper strip positions"
                                if lower_source_position == undefined or lower_generated_position == undefined then throw "direct stacked modifier could not read lower strip positions"
                                if branch_neighbor_position == undefined then throw "direct stacked modifier could not read branch neighbor position"
                                expected_anchor_connect_position = upper_source_position + ((branch_neighbor_position - upper_source_position) * 0.5)
                                expected_upper_cut_position = upper_source_position + ((upper_generated_position - upper_source_position) * 0.5)
                                expected_lower_cut_position = lower_source_position + ((lower_generated_position - lower_source_position) * 0.5)
                                connect_edges = #{}
                                connect_edges[branch_edge_id] = true
                                connect_edges[upper_edge_id] = true
                                connect_edges[lower_edge_id] = true
                                operation_stage = "ConnectEdges for case " + (case_index as string)
                                if not executeWallThicknessTEdgeConnectEdges fix_modifier source_node connect_edges then throw "direct stacked Connect Edges failed"
                                connect_vertex_count = fix_modifier.GetNumVertices node:source_node
                                connect_face_count = fix_modifier.GetNumFaces node:source_node
                                connect_edge_count = fix_modifier.GetNumEdges node:source_node
                                format "FIX T EDGE CORNERS STACK AFTER CONNECT: verts % | polygons % | edges %\n" connect_vertex_count connect_face_count connect_edge_count
                                if connect_vertex_count != (case_start_vertex_count + 3) then throw "direct stacked Connect Edges did not add exactly three vertices"
                                if connect_face_count != (case_start_face_count + 2) then throw "direct stacked Connect Edges did not add exactly two polygons"
                                if connect_edge_count != (case_start_edge_count + 5) then throw "direct stacked Connect Edges did not add exactly five edges"
                                operation_stage = "resolve three new ConnectEdges vertices for case " + (case_index as string)
                                first_new_vertex_id = case_start_vertex_count + 1
                                fixed_anchor_ids = getWallThicknessTEdgeNewVerticesAtPosition fix_modifier source_node expected_anchor_connect_position tolerance first_new_vertex_id
                                top_cut_ids = getWallThicknessTEdgeNewVerticesAtPosition fix_modifier source_node expected_upper_cut_position tolerance first_new_vertex_id
                                bottom_cut_ids = getWallThicknessTEdgeNewVerticesAtPosition fix_modifier source_node expected_lower_cut_position tolerance first_new_vertex_id
                                if fixed_anchor_ids.count != 1 then throw "direct stacked Connect Edges did not resolve one new branch anchor"
                                if top_cut_ids.count != 1 then throw "direct stacked Connect Edges did not resolve one new upper cut vertex"
                                if bottom_cut_ids.count != 1 then throw "direct stacked Connect Edges did not resolve one new lower cut vertex"
                                fixed_anchor_vertex_id = fixed_anchor_ids[1]
                                top_cut_vertex_id = top_cut_ids[1]
                                bottom_cut_vertex_id = bottom_cut_ids[1]
                                if findWallThicknessTEdgeLiveEdge fix_modifier source_node fixed_anchor_vertex_id top_cut_vertex_id < 1 then throw "direct stacked Connect Edges did not create anchor-to-upper edge"
                                if findWallThicknessTEdgeLiveEdge fix_modifier source_node top_cut_vertex_id bottom_cut_vertex_id < 1 then throw "direct stacked Connect Edges did not create upper-to-lower edge"
                                format "FIX T EDGE CORNERS STACK NEW VERTS: anchor V% | upper V% | lower V%\n" fixed_anchor_vertex_id top_cut_vertex_id bottom_cut_vertex_id
                                fixed_anchor_position = fix_modifier.GetVertex fixed_anchor_vertex_id node:source_node
                                top_before_move = fix_modifier.GetVertex top_cut_vertex_id node:source_node
                                bottom_before_move = fix_modifier.GetVertex bottom_cut_vertex_id node:source_node
                                if fixed_anchor_position == undefined or top_before_move == undefined or bottom_before_move == undefined then throw "direct stacked modifier could not read new T-edge vertices"
                                operation_stage = "move new T-edge cut edge onto branch anchor for case " + (case_index as string)
                                if not moveWallThicknessTEdgeLiveCutEdgeToAnchor fix_modifier source_node top_cut_vertex_id bottom_cut_vertex_id fixed_anchor_vertex_id tolerance then throw "direct stacked cut-edge move failed"
                                anchor_after_move = fix_modifier.GetVertex fixed_anchor_vertex_id node:source_node
                                top_after_move = fix_modifier.GetVertex top_cut_vertex_id node:source_node
                                moved_bottom_position = fix_modifier.GetVertex bottom_cut_vertex_id node:source_node
                                bottom_target_position = [fixed_anchor_position.x, fixed_anchor_position.y, bottom_before_move.z]
                                format "FIX T EDGE CORNERS STACK PRE-WELD: anchor % | upper moved % | lower moved %\n" anchor_after_move top_after_move moved_bottom_position
                                if anchor_after_move == undefined or distance anchor_after_move fixed_anchor_position > tolerance then throw "direct stacked cut-edge move changed branch anchor"
                                if top_after_move == undefined or distance top_after_move anchor_after_move > tolerance then throw "direct stacked upper cut did not coincide with branch anchor"
                                if moved_bottom_position == undefined or distance moved_bottom_position bottom_target_position > tolerance then throw "direct stacked lower cut did not align below branch anchor"
                                operation_stage = "weld coincident upper cut into branch anchor for case " + (case_index as string)
                                before_weld_vertex_count = fix_modifier.GetNumVertices node:source_node
                                before_weld_face_count = fix_modifier.GetNumFaces node:source_node
                                before_weld_edge_count = fix_modifier.GetNumEdges node:source_node
                                fix_modifier.WeldVertices fixed_anchor_vertex_id top_cut_vertex_id node:source_node
                                fix_modifier.Commit()
                                fix_modifier.RefreshScreen()
                                completeRedraw()
                                after_weld_vertex_count = fix_modifier.GetNumVertices node:source_node
                                after_weld_face_count = fix_modifier.GetNumFaces node:source_node
                                after_weld_edge_count = fix_modifier.GetNumEdges node:source_node
                                format "FIX T EDGE CORNERS STACK WELD: upper V% -> anchor V% | verts % -> % | polygons % -> % | edges % -> %\n" top_cut_vertex_id fixed_anchor_vertex_id before_weld_vertex_count after_weld_vertex_count before_weld_face_count after_weld_face_count before_weld_edge_count after_weld_edge_count
                                if after_weld_vertex_count != (before_weld_vertex_count - 1) then throw "direct stacked weld did not remove exactly one vertex"
                                if after_weld_face_count != (before_weld_face_count - 1) then throw "direct stacked weld did not remove exactly one polygon"
                                if after_weld_edge_count != (before_weld_edge_count - 2) then throw "direct stacked weld did not remove exactly two edges"
                                if after_weld_vertex_count != (case_start_vertex_count + 2) then throw "unexpected direct stacked repaired vertex count"
                                if after_weld_face_count != (case_start_face_count + 1) then throw "unexpected direct stacked repaired polygon count"
                                if after_weld_edge_count != (case_start_edge_count + 3) then throw "unexpected direct stacked repaired edge count"
                                surviving_anchor_ids = getWallThicknessLiveVerticesAtPosition fix_modifier source_node fixed_anchor_position tolerance
                                if surviving_anchor_ids.count != 1 then throw "direct stacked fixed anchor was not uniquely preserved"
                                surviving_anchor_id = surviving_anchor_ids[1]
                                surviving_bottom_ids = getWallThicknessLiveVerticesAtPosition fix_modifier source_node bottom_target_position tolerance
                                if surviving_bottom_ids.count != 1 then throw "direct stacked lower cut vertex was not uniquely preserved"
                                operation_stage = "generated-side Material ID correction for case " + (case_index as string)
                                changed_material_faces = fixWallThicknessTEdgeNewWallFaceMaterial fix_modifier source_node generated_anchor_id generated_continuation_id surviving_anchor_id surviving_bottom_ids[1]
                                material_face_count += changed_material_faces
                                repaired_case_count += 1
                                welded_vertex_count += 1
                                format "FIX T EDGE CORNERS STACK CASE COMPLETE: case % | material polygons updated %\n" case_index changed_material_faces
                        )
                        if repaired_case_count != planned_cases.count then throw "not every direct stacked T-edge case completed"
                        build_succeeded = true
                )
        )
        catch
        (
                exception_text = getCurrentException()
                build_succeeded = false
                format "Wall Thickness FIX T EDGE CORNERS STACK ERROR [%]: %\n" operation_stage exception_text
        )
        operation_stage = "verify FIX INNER CORNERS remained unchanged"
        inner_restored = inner_fix_modifier == undefined or getWallThicknessInnerCornerFixModifier source_node == inner_fix_modifier
        if not inner_restored then
        (
                build_succeeded = false
                format "FIX T EDGE CORNERS INNER PRESERVE ERROR: FIX INNER CORNERS instance changed during T-edge authoring.\n"
        )
        if not build_succeeded and fix_modifier != undefined then
        (
                format "FIX T EDGE CORNERS DEBUG: failed Edit Poly left visible in stack for inspection: %\n" fix_modifier.name
        )
        try
        (
                if saved_selection.count > 0 then select saved_selection else clearSelection()
                if saved_current_object != undefined then modPanel.setCurrentObject saved_current_object
                subObjectLevel = saved_sub_object_level
        )
        catch
        (
                restore_exception_text = getCurrentException()
                format "Wall Thickness FIX T EDGE CORNERS UI RESTORE ERROR: %\n" restore_exception_text
        )
        #(build_succeeded and inner_restored, repaired_case_count, welded_vertex_count, material_face_count, fix_modifier, inner_restored)
        -- return
)
/*
Repairs partial-height T-edge corners in one removable non-destructive Edit Poly without changing the Editable Poly base.
Planning is evaluated from the stable inner-fixed result; topology is authored directly in one stacked Edit Poly above FIX INNER CORNERS using the proven EPoly-Stack-Test node-scoped workflow.
*/
function fixWallThicknessTEdgeCorners source_node =
(
        if not isValidNode source_node then
        (
                messageBox "Select exactly one wall object." title:"Wall Thickness"
                #(false, 0, 0, 0)
        )
        else if getWallThicknessModifier source_node == undefined then
        (
                messageBox "Create WALL THICKNESS first." title:"Wall Thickness"
                #(false, 0, 0, 0)
        )
        else
        (
                use_material_ids = getObjectWallThicknessChangeMaterialIds source_node
                repaired_case_count = 0
                welded_vertex_count = 0
                material_face_count = 0
                build_succeeded = false
                restore_succeeded = true
                operation_exception_text = undefined
                base_signature_before = getWallThicknessBaseTopologySignature source_node
                base_signature_after = undefined
                inner_result = #(false, 0, 0)
                plan_data = #(false, #(), 0, 0, 0)
                build_data = #(false, 0, 0, 0, undefined, false)
                undo "Wall Thickness - Fix T Edge Corners" on
                (
                        try
                        (
                                removeWallThicknessTEdgeFixModifier source_node
                                inner_result = fixWallThicknessInnerCorners source_node change_material_ids:use_material_ids
                                if inner_result == undefined or inner_result[1] != true then throw "stable FIX INNER CORNERS must succeed before T-edge planning"
                                update source_node
                                plan_data = planWallThicknessTEdgeModifierRepairs source_node
                                if plan_data[1] != true then throw "baked 0.969 T-edge planning failed"
                                build_data = buildWallThicknessTEdgeFixModifier source_node plan_data[2]
                                build_succeeded = build_data[1]
                                repaired_case_count = build_data[2]
                                welded_vertex_count = build_data[3]
                                material_face_count = build_data[4]
                                if not build_succeeded then throw "persistent FIX T EDGE CORNERS modifier execution failed"
                                if repaired_case_count != plan_data[2].count then throw "not every planned T-edge case was repaired"
                                base_signature_after = getWallThicknessBaseTopologySignature source_node
                                if not wallThicknessBaseTopologySignaturesMatch base_signature_before base_signature_after then throw "Editable Poly base topology/positions changed during T-edge repair"
                                setObjectWallThicknessInnerFixEnabled source_node true
                                setObjectWallThicknessChangeMaterialIds source_node use_material_ids
                                wall_thickness_target = source_node
                                format "FIX T EDGE CORNERS BASE SIGNATURE: unchanged:true | verts % | edges % | polygons %\n" base_signature_after[1] base_signature_after[2] base_signature_after[3]
                        )
                        catch
                        (
                                operation_exception_text = getCurrentException()
                                build_succeeded = false
                        )
                        if not build_succeeded then
                        (
                                if getWallThicknessInnerCornerFixModifier source_node == undefined then
                                (
                                        format "FIX T EDGE CORNERS RECOVERY: FIX INNER CORNERS is missing; rebuilding stable lower state.\n"
                                        restore_data = rebuildWallThicknessWithInnerCorners source_node (getObjectWallThickness source_node) change_material_ids:use_material_ids
                                        restore_succeeded = restore_data[1]
                                )
                                else
                                (
                                        restore_succeeded = true
                                        if getWallThicknessTEdgeFixModifier source_node != undefined then
                                        (
                                                format "FIX T EDGE CORNERS RECOVERY: failed T-edge Edit Poly preserved for inspection; WALL THICKNESS + FIX INNER CORNERS remain in stack.\n"
                                        )
                                )
                                if restore_succeeded then setObjectWallThicknessInnerFixEnabled source_node true
                        )
                )
                completeRedraw()
                if build_succeeded then
                (
                        format "Wall Thickness FIX T EDGE CORNERS %: detected/repaired % | welded % | material polygons corrected % | removable Edit Poly:true | base unchanged:true\n" wall_thickness_file_version repaired_case_count welded_vertex_count material_face_count
                )
                else
                (
                        if operation_exception_text != undefined then format "Wall Thickness FIX T EDGE CORNERS MODIFIER ERROR: %\n" operation_exception_text
                        format "Wall Thickness FIX T EDGE CORNERS %: modifier build failed | stable lower state restored:%\n" wall_thickness_file_version restore_succeeded
                )
                #(build_succeeded, repaired_case_count, welded_vertex_count, material_face_count)
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
Returns true when one filename token is a plain numeric version.
Only digits and one optional decimal point are accepted.
*/
function isWallThicknessVersionText version_text =
(
        is_valid = version_text != ""
        digit_count = 0
        decimal_count = 0
        character_value = ""
        if is_valid then
        (
                for character_index = 1 to version_text.count while is_valid do
                (
                        character_value = substring version_text character_index 1
                        if character_value == "." then
                        (
                                decimal_count += 1
                                if decimal_count > 1 then is_valid = false
                        )
                        else if (findString "0123456789" character_value) != undefined then
                        (
                                digit_count += 1
                        )
                        else
                        (
                                is_valid = false
                        )
                )
                if digit_count == 0 then is_valid = false
        )
        is_valid
        -- return
)
/*
Returns #(valid, version, isLatest, isPlain) for one Wall-Thickness_<version>*.ms path.
Release tags such as -LATEST, -MVP, or -STABLE do not change the numeric version.
*/
function getWallThicknessScriptVersionData script_path =
(
        result_data = #(false, 0.0, false, false)
        if script_path != undefined and script_path != "" then
        (
                script_stem = getFilenameFile script_path
                version_prefix = "Wall-Thickness_"
                if script_stem.count > version_prefix.count and (findString script_stem version_prefix) == 1 then
                (
                        suffix_text = substring script_stem (version_prefix.count + 1) (script_stem.count - version_prefix.count)
                        suffix_parts = filterString suffix_text "-"
                        if suffix_parts.count >= 1 then
                        (
                                version_text = suffix_parts[1]
                                if isWallThicknessVersionText version_text then
                                (
                                        is_latest = false
                                        if suffix_parts.count >= 2 then
                                        (
                                                for part_index = 2 to suffix_parts.count while not is_latest do
                                                (
                                                        if toUpper suffix_parts[part_index] == "LATEST" then is_latest = true
                                                )
                                        )
                                        result_data = #(true, version_text as float, is_latest, suffix_parts.count == 1)
                                )
                        )
                )
        )
        result_data
        -- return
)
/*
Finds the highest versioned Wall Thickness script in the current script directory.
When several files share the highest version, -LATEST is preferred, then the plain versioned file; the current script is only a fallback when no versioned candidate exists.
*/
function getLatestWallThicknessScriptPath =
(
        source_path = wall_thickness_source_file_path
        source_folder = ""
        resolved_path = undefined
        newest_version = -1.0
        newest_rank = -1
        if source_path == undefined or source_path == "" then source_path = getSourceFileName()
        if source_path != undefined and source_path != "" then source_folder = getFilenamePath source_path
        if source_folder != "" then
        (
                candidate_files = getFiles (source_folder + "Wall-Thickness_*.ms")
                for candidate_file in candidate_files do
                (
                        version_data = getWallThicknessScriptVersionData candidate_file
                        if version_data[1] then
                        (
                                candidate_rank = if version_data[3] then 2 else if version_data[4] then 1 else 0
                                if version_data[2] > newest_version or (version_data[2] == newest_version and candidate_rank > newest_rank) then
                                (
                                        newest_version = version_data[2]
                                        newest_rank = candidate_rank
                                        resolved_path = candidate_file
                                )
                        )
                )
        )
        if resolved_path == undefined and source_path != undefined and source_path != "" and doesFileExist source_path then
        (
                resolved_path = source_path
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
Reloads the newest versioned Wall Thickness script found beside the running file.
When no versioned candidate exists, the current source file is reloaded instead.
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
                format "Wall Thickness RESTART TOOL: loading %\n" latest_script_path
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
        quiet_enabled = false
        if wallThicknessRollout != undefined then
        (
                quiet_enabled = wallThicknessRollout.chk_quiet.checked
        )
        if not quiet_enabled then
        (
                format "Wall Thickness % | %\n" action_name message_text
        )
        true
        -- return
)
rollout wallThicknessRollout wall_thickness_ui_title width:270
(
        button btn_reload_latest "RESTART TOOL" width:230 height:28 align:#center tooltip:"Reload the highest versioned Wall-Thickness script found in this script folder.\n\nWhen versions tie, prefer the -LATEST file."
        checkbutton chk_quiet "QUIET" checked:false width:230 height:24 align:#center tooltip:"LMB: Suppress the routine Listener line written after each UI action.\n\nErrors and diagnostic output remain visible."
        group "LOG"
        (
                editText edt_log "" text:"READY" readOnly:true width:230 height:58 align:#center
        )
        button btn_reset "REMOVE MODIFIERS" width:230 height:28 align:#center tooltip:"Remove all Wall Thickness PREP, THICKNESS, CLEANUP, chamfer and STL Check modifiers.\n\nThe base object remains unchanged."
        group "PRE-PROCESS"
        (
                button btn_preprocess_01 "01  RESET XFORM" width:230 height:28 align:#center tooltip:"LMB: HARD reset every selected object: Reset XForm, collapse the full current stack to bake it, then Reset Pivot.\n\nRuns on every click. Use before WALL THICKNESS when object transform or pivot state is suspect."
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
                checkbox chk_change_material_ids "CHANGE MATERIAL IDS" checked:false width:230 align:#left tooltip:"When enabled, EXTRUDE / UPDATE sets source/outer faces to Material ID 1, generated inner faces to Material ID 2, and border strip faces to Material ID 3.\n\nWhen disabled, EXTRUDE / UPDATE preserves source Material IDs and inherits them onto generated faces."
                button btn_create "EXTRUDE / UPDATE" width:230 height:32 align:#center tooltip:"LMB: Create or rebuild WALL THICKNESS, automatically run FIX INNER CORNERS, and create the fix modifier only when correction is required.\n\nCHANGE MATERIAL IDS OFF: preserve/inherit source Material IDs.\n\nCHANGE MATERIAL IDS ON: assign OUTER 1, INNER 2, STRIP 3."
        )
        group "MANUAL-PROCESS"
        (
                button btn_extrude_only "EXTRUDE ONLY" width:230 height:28 align:#center tooltip:"LMB: Rebuild only the raw WALL THICKNESS extrusion.\n\nNo automatic FIX INNER CORNERS pass is run; later spinner rebuilds remain raw-only until FIX INNER CORNERS is run manually."
                button btn_fix_inner "FIX INNER CORNERS" width:230 height:28 align:#center tooltip:"LMB: Keep WALL THICKNESS intact and add a deformation-only FIX INNER CORNERS modifier above it.\n\nThe fix changes vertex positions only, never topology. Future thickness updates rebuild both modifiers from the untouched source."
                button btn_fix_t_edge "FIX T EDGE CORNERS" width:230 height:28 align:#center tooltip:"LMB: Plan from the stable FIX INNER CORNERS result, then repair T-edge topology in one removable Edit Poly directly above WALL THICKNESS. FIX INNER CORNERS is restored above it afterward."
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
        on wallThicknessRollout open do
        (
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
                                updateDynamicWallThickness value change_material_ids:chk_change_material_ids.checked
                        )
                )
        )
        on spn_ratio changed value do
        (
                saveWallThicknessControlValues()
                updateWallThicknessScaledLabel()
        )
        on chk_change_material_ids changed state do
        (
                saveWallThicknessControlValues()
                setWallThicknessUILog "CHANGE MATERIAL IDS" detail:(if state then "ON | EXTRUDE / UPDATE -> OUTER 1, INNER 2, STRIP 3" else "OFF | EXTRUDE / UPDATE PRESERVES MATERIAL IDS")
        )
        on chk_quiet changed state do
        (
                saveWallThicknessControlValues()
                setWallThicknessUILog "QUIET" detail:(if state then "ON | ACTION LISTENER OUTPUT SUPPRESSED" else "OFF | ACTION LISTENER OUTPUT ENABLED")
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
                        status_text = (result_value[2] as string) + " OBJECTS HARD RESET"
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
                        result_value = applyWallThickness selection[1] spn_thickness.value change_material_ids:chk_change_material_ids.checked auto_fix_inner:true
                        setWallThicknessUILog "EXTRUDE / UPDATE" result_value:result_value
                )
                else
                (
                        setWallThicknessUILog "EXTRUDE / UPDATE" detail:"select exactly one wall object"
                        messageBox "Select exactly one wall object." title:"Wall Thickness"
                )
        )
        on btn_extrude_only pressed do
        (
                if selection.count == 1 then
                (
                        result_value = applyWallThickness selection[1] spn_thickness.value change_material_ids:chk_change_material_ids.checked auto_fix_inner:false
                        setWallThicknessUILog "EXTRUDE ONLY" result_value:result_value
                )
                else
                (
                        setWallThicknessUILog "EXTRUDE ONLY" detail:"select exactly one wall object"
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
                        result_value = fixWallThicknessInnerCorners selection[1] change_material_ids:chk_change_material_ids.checked
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
cui.RegisterDialogBar wallThicknessRollout style:#(#cui_dock_left, #cui_dock_right, #cui_floatable, #cui_handles)
windows.processPostedMessages()
