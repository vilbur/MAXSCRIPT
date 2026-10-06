/*
Wall Thickness Inner Corners Module 0.001
Project version 0.996.
Contains the extracted planWallThicknessInnerCorners() analysis routine.
*/
global wall_thickness_inner_corners_file_version = 0.001
global wall_thickness_inner_corners_stored_project_version = 0.996
/*
Plans generated inner-corner border vertex targets from the evaluated WALL THICKNESS result.
This is analysis-only: it snapshots and reads the modifier, but never collapses the stack and never writes geometry.
*/
function planWallThicknessInnerCorners source_node planned_targets_out =
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
                                                if not loadWallThicknessQuietMode() then
                                                (
                                                        logWallThicknessInnerCornerDump #("SOURCE VERTEX", dump_source_id, dump_source_position, source_face_use_counts[dump_source_id], border_neighbors[dump_source_id], dump_generated_id, dump_generated_position)
                                                )
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
                                                        A 3+/2/1 source-face vertical corner stack can inherit only one face offset on the shared generated corner.
                                                        Rebuild that corner XY from the intersection of the two neighboring generated border lines.
                                                        This is topology-driven and rotation-invariant: it does not choose a stack anchor from local Z order.
                                                        */
                                                        special_stack_intersection_repair = false
                                                        special_stack_intersection_target = undefined
                                                        special_stack_corner_source_id = 0
                                                        if vertical_stack_source_ids.count >= 3 then
                                                        (
                                                                has_three_face_member = false
                                                                has_one_face_member = false
                                                                for stack_source_id in vertical_stack_source_ids do
                                                                (
                                                                        if source_face_use_counts[stack_source_id] >= 3 then has_three_face_member = true
                                                                        if source_face_use_counts[stack_source_id] == 1 then has_one_face_member = true
                                                                )
                                                                if has_three_face_member and has_one_face_member then
                                                                (
                                                                        for stack_source_id in vertical_stack_source_ids while not special_stack_intersection_repair do
                                                                        (
                                                                                if source_face_use_counts[stack_source_id] == 2 and sharp_source_vertices[stack_source_id] then
                                                                                (
                                                                                        stack_corner_source_position = EditPolyMod.GetVertex thickness_modifier stack_source_id node:source_node
                                                                                        stack_corner_horizontal_neighbors = #()
                                                                                        if stack_corner_source_position != undefined then
                                                                                        (
                                                                                                for neighbor_source_id in border_neighbors[stack_source_id] do
                                                                                                (
                                                                                                        neighbor_source_position = EditPolyMod.GetVertex thickness_modifier neighbor_source_id node:source_node
                                                                                                        if neighbor_source_position != undefined then
                                                                                                        (
                                                                                                                neighbor_plan_delta = [neighbor_source_position.x - stack_corner_source_position.x, neighbor_source_position.y - stack_corner_source_position.y, 0]
                                                                                                                if length neighbor_plan_delta > tolerance then append stack_corner_horizontal_neighbors neighbor_source_id
                                                                                                        )
                                                                                                )
                                                                                        )
                                                                                        if stack_corner_horizontal_neighbors.count == 2 then
                                                                                        (
                                                                                                neighbor_source_a = stack_corner_horizontal_neighbors[1]
                                                                                                neighbor_source_b = stack_corner_horizontal_neighbors[2]
                                                                                                neighbor_generated_a = neighbor_source_a + source_vert_count
                                                                                                neighbor_generated_b = neighbor_source_b + source_vert_count
                                                                                                stack_corner_generated_id = stack_source_id + source_vert_count
                                                                                                if neighbor_generated_a <= live_vertex_count and neighbor_generated_b <= live_vertex_count and stack_corner_generated_id <= live_vertex_count then
                                                                                                (
                                                                                                        neighbor_source_position_a = EditPolyMod.GetVertex thickness_modifier neighbor_source_a node:source_node
                                                                                                        neighbor_source_position_b = EditPolyMod.GetVertex thickness_modifier neighbor_source_b node:source_node
                                                                                                        neighbor_generated_position_a = EditPolyMod.GetVertex thickness_modifier neighbor_generated_a node:source_node
                                                                                                        neighbor_generated_position_b = EditPolyMod.GetVertex thickness_modifier neighbor_generated_b node:source_node
                                                                                                        stack_corner_generated_position = EditPolyMod.GetVertex thickness_modifier stack_corner_generated_id node:source_node
                                                                                                        if neighbor_source_position_a != undefined and neighbor_source_position_b != undefined and neighbor_generated_position_a != undefined and neighbor_generated_position_b != undefined and stack_corner_generated_position != undefined then
                                                                                                        (
                                                                                                                neighbor_direction_a = [neighbor_source_position_a.x - stack_corner_source_position.x, neighbor_source_position_a.y - stack_corner_source_position.y, 0]
                                                                                                                neighbor_direction_b = [neighbor_source_position_b.x - stack_corner_source_position.x, neighbor_source_position_b.y - stack_corner_source_position.y, 0]
                                                                                                                if length neighbor_direction_a > tolerance and length neighbor_direction_b > tolerance then
                                                                                                                (
                                                                                                                        line_end_a = neighbor_generated_position_a + neighbor_direction_a
                                                                                                                        line_end_b = neighbor_generated_position_b + neighbor_direction_b
                                                                                                                        special_stack_intersection_target = getWallThicknessLineIntersectionXY neighbor_generated_position_a line_end_a neighbor_generated_position_b line_end_b stack_corner_generated_position.z tolerance:tolerance
                                                                                                                        if special_stack_intersection_target != undefined then
                                                                                                                        (
                                                                                                                                special_stack_intersection_repair = true
                                                                                                                                special_stack_corner_source_id = stack_source_id
                                                                                                                        )
                                                                                                                )
                                                                                                        )
                                                                                                )
                                                                                        )
                                                                                )
                                                                        )
                                                                )
                                                        )
                                                        if special_stack_intersection_repair then
                                                        (
                                                                for stack_source_id in vertical_stack_source_ids do
                                                                (
                                                                        stack_generated_id = stack_source_id + source_vert_count
                                                                        if stack_generated_id <= live_vertex_count then
                                                                        (
                                                                                stack_generated_position = EditPolyMod.GetVertex thickness_modifier stack_generated_id node:source_node
                                                                                if stack_generated_position != undefined then
                                                                                (
                                                                                        stack_intersection_target = [special_stack_intersection_target.x, special_stack_intersection_target.y, stack_generated_position.z]
                                                                                        if distance stack_generated_position stack_intersection_target > tolerance then
                                                                                        (
                                                                                                target_updated = false
                                                                                                for target_id = 1 to planned_targets.count while not target_updated do
                                                                                                (
                                                                                                        if planned_targets[target_id][1] == stack_generated_id then
                                                                                                        (
                                                                                                                planned_targets[target_id][2] = stack_intersection_target
                                                                                                                planned_targets[target_id][4] = special_stack_corner_source_id + source_vert_count
                                                                                                                planned_targets[target_id][5] = special_stack_intersection_target
                                                                                                                target_updated = true
                                                                                                        )
                                                                                                )
                                                                                                if not target_updated then
                                                                                                (
                                                                                                        planned_generated_ids[stack_generated_id] = true
                                                                                                        append planned_targets #(stack_generated_id, stack_intersection_target, stack_generated_position, special_stack_corner_source_id + source_vert_count, special_stack_intersection_target)
                                                                                                )
                                                                                                planned_generated_ids[stack_generated_id] = true
                                                                                                format "FIX INNER CORNERS ALIGN ROTATION-INVARIANT STACK V%: % -> % | corner source V%\n" stack_generated_id stack_generated_position stack_intersection_target special_stack_corner_source_id
                                                                                                logWallThicknessInnerCornerDump #("ALIGN ROTATION-INVARIANT STACK", stack_source_id, stack_generated_id, stack_generated_position, stack_intersection_target, special_stack_corner_source_id, special_stack_intersection_target)
                                                                                        )
                                                                                )
                                                                        )
                                                                )
                                                        )
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
                                                                                        stack_other_source_position = EditPolyMod.GetVertex thickness_modifier stack_other_source_id node:source_node
                                                                                        logWallThicknessInnerCornerDump #("T STACK GENERATED", stack_anchor_generated_id, stack_anchor_generated_position, stack_other_generated_id, stack_other_generated_position, planned_generated_ids[stack_other_generated_id])
                                                                                        if stack_anchor_generated_position != undefined and stack_other_generated_position != undefined and stack_other_source_position != undefined then
                                                                                        (
                                                                                                parallel_strip_repair = false
                                                                                                parallel_reference_edge = undefined
                                                                                                /*
                                                                                                A three-face upper border corner is different from the stable two-face T stack.
                                                                                                When a clean vertical border strip proves that the one-face lower endpoint carries the established extrusion offset, keep that lower generated XY fixed and move only the upper generated corner onto it.
                                                                                                */
                                                                                                if anchor_source_face_count >= 3 and not planned_generated_ids[stack_anchor_generated_id] then
                                                                                                (
                                                                                                        source_stack_plan_delta = [stack_position_a.x - stack_position_b.x, stack_position_a.y - stack_position_b.y, 0]
                                                                                                        if length source_stack_plan_delta <= tolerance then
                                                                                                        (
                                                                                                                simple_offset_xy = [stack_other_generated_position.x - stack_other_source_position.x, stack_other_generated_position.y - stack_other_source_position.y, 0]
                                                                                                                for reference_edge_data in border_edges while not parallel_strip_repair do
                                                                                                                (
                                                                                                                        reference_source_a = reference_edge_data[1]
                                                                                                                        reference_source_b = reference_edge_data[2]
                                                                                                                        reference_generated_a = reference_edge_data[3]
                                                                                                                        reference_generated_b = reference_edge_data[4]
                                                                                                                        if not ((reference_source_a == stack_source_a and reference_source_b == stack_source_b) or (reference_source_a == stack_source_b and reference_source_b == stack_source_a)) then
                                                                                                                        (
                                                                                                                                reference_source_position_a = EditPolyMod.GetVertex thickness_modifier reference_source_a node:source_node
                                                                                                                                reference_source_position_b = EditPolyMod.GetVertex thickness_modifier reference_source_b node:source_node
                                                                                                                                reference_generated_position_a = EditPolyMod.GetVertex thickness_modifier reference_generated_a node:source_node
                                                                                                                                reference_generated_position_b = EditPolyMod.GetVertex thickness_modifier reference_generated_b node:source_node
                                                                                                                                if reference_source_position_a != undefined and reference_source_position_b != undefined and reference_generated_position_a != undefined and reference_generated_position_b != undefined then
                                                                                                                                (
                                                                                                                                        reference_source_plan_delta = [reference_source_position_b.x - reference_source_position_a.x, reference_source_position_b.y - reference_source_position_a.y, 0]
                                                                                                                                        reference_generated_plan_delta = [reference_generated_position_b.x - reference_generated_position_a.x, reference_generated_position_b.y - reference_generated_position_a.y, 0]
                                                                                                                                        if length reference_source_plan_delta <= stack_xy_tolerance and length reference_generated_plan_delta <= stack_xy_tolerance then
                                                                                                                                        (
                                                                                                                                                reference_offset_a = [reference_generated_position_a.x - reference_source_position_a.x, reference_generated_position_a.y - reference_source_position_a.y, 0]
                                                                                                                                                reference_offset_b = [reference_generated_position_b.x - reference_source_position_b.x, reference_generated_position_b.y - reference_source_position_b.y, 0]
                                                                                                                                                if distance reference_offset_a simple_offset_xy <= stack_xy_tolerance and distance reference_offset_b simple_offset_xy <= stack_xy_tolerance then
                                                                                                                                                (
                                                                                                                                                        parallel_strip_repair = true
                                                                                                                                                        parallel_reference_edge = #(reference_source_a, reference_source_b, reference_generated_a, reference_generated_b)
                                                                                                                                                )
                                                                                                                                        )
                                                                                                                                )
                                                                                                                        )
                                                                                                                )
                                                                                                        )
                                                                                                )
                                                                                                logWallThicknessInnerCornerDump #("PARALLEL STRIP TEST", stack_anchor_source_id, anchor_source_face_count, stack_other_source_id, other_source_face_count, parallel_strip_repair, parallel_reference_edge)
                                                                                                if parallel_strip_repair then
                                                                                                (
                                                                                                        parallel_target_position = [stack_other_generated_position.x, stack_other_generated_position.y, stack_anchor_generated_position.z]
                                                                                                        if distance stack_anchor_generated_position parallel_target_position > tolerance then
                                                                                                        (
                                                                                                                planned_generated_ids[stack_anchor_generated_id] = true
                                                                                                                append planned_targets #(stack_anchor_generated_id, parallel_target_position, stack_anchor_generated_position, stack_other_generated_id, stack_other_generated_position)
                                                                                                                format "FIX INNER CORNERS ALIGN PARALLEL STRIP V%: % -> % | fixed simple V% | reference %\n" stack_anchor_generated_id stack_anchor_generated_position parallel_target_position stack_other_generated_id parallel_reference_edge
                                                                                                                logWallThicknessInnerCornerDump #("ALIGN PARALLEL STRIP", stack_anchor_source_id, stack_anchor_generated_id, stack_anchor_generated_position, parallel_target_position, stack_other_source_id, stack_other_generated_id, parallel_reference_edge)
                                                                                                        )
                                                                                                )
                                                                                                else if not planned_generated_ids[stack_other_generated_id] then
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
                                                        if vertical_stack_source_ids.count >= 3 and align_vertical_stack and not special_stack_intersection_repair then
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
                                        if planned_targets_out != undefined then
                                        (
                                                for target_data in planned_targets do
                                                (
                                                        append planned_targets_out target_data
                                                )
                                        )
                                        moved_vertex_count = planned_targets.count
                                        if moved_vertex_count > 0 then
                                        (
                                                logWallThicknessInnerCornerDump #("PLAN ONLY", moved_vertex_count, "no geometry written")
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
                        format "Wall Thickness FIX INNER CORNERS %: source verts % | live verts % | mapped source border edges % | bad edges % | positions planned % .\n" wall_thickness_file_version source_vert_count live_vertex_count border_edges.count bad_edge_count moved_vertex_count
                        logWallThicknessInnerCornerDump #("FIX INNER CORNERS SUMMARY", wall_thickness_file_version, build_succeeded, source_vert_count, live_vertex_count, border_edges.count, bad_edge_count, moved_vertex_count)
                        if dump_started then format "FIX INNER CORNERS DUMP FILE: %\n" wall_thickness_inner_dump_file
                        #(build_succeeded, bad_edge_count, moved_vertex_count)
                )
        )
        -- return
)
