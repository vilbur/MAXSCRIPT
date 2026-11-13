/*
Surface-Intersections-FN 0.46
On-demand, non-destructive intersection curves from multiple selected open surfaces.
Source geometry is evaluated in world space; planar priority cutters are supported.
Output changes only through explicit Generate / Update; live monitoring is disabled.
*/


global DumpDevLoggerStruct
global SurfaceIntersections_v
global SurfaceIntersections
global si_live_source_nodes = #()
global si_project_version



/*
Stores persistent setup/source identity keys on an owned shared Slice instance.
Unrelated user-created Slice modifiers are never adopted by name or class.
*/
global si_endpoint_slice_ca = attributes SI_EndpointSlice attribID:#(0x4e591b21,0x228a0f36)
(
    parameters main
    (
        owner_key type:#string default:""
        source_key type:#string default:""
        result_key type:#string default:""
        pivot_position type:#point3 default:[0,0,0]
        axis_index type:#integer default:1
        endpoint_key type:#string default:""
    )
)

/*
Queues a source transform change without editing geometry inside the change handler.
This is a global callback to avoid depending on function-local state.
*/
function siLiveTransformChanged changed_node =
(
    if SurfaceIntersections != undefined then
    (
        SurfaceIntersections.markDirty()
    )
    true
    -- return
)


/*
Handles source geometry, topology and deletion events from NodeEventCallback.
Only registered source AnimHandles are relevant.
*/
function siLiveNodeChanged event_name node_handles =
(
    if SurfaceIntersections != undefined then
    (
        for node_handle in node_handles do
        (
            if (findItem SurfaceIntersections.source_handles node_handle) > 0 then
            (
                SurfaceIntersections.markDirty()
            )
        )
    )
    true
    -- return
)


/*
Stops an obsolete queued timer tick without rebuilding any output.
Kept for compatibility with already-registered callbacks during an upgrade.
*/
function siLiveTimerTick timer_sender timer_event =
(
    if SurfaceIntersections != undefined then
    (
        if SurfaceIntersections.live_timer != undefined then SurfaceIntersections.live_timer.Stop()
    )
    true
    -- return
)


struct SurfaceIntersections_v
(
    file_version = "0.45",
    fn_file_version = "0.46",
    project_version = "0.99",
    endpoint_slice_enabled = false,
    extended_cut_segments = #(),
    source_clip_modes = #(),
    priority_clipping = true,
    delete_trimmed = true,
    only_final_result = true,
    hidden_edge_segments = #(),
    visible_edge_segments = #(),
    result_edge_segments = #(),
    trim_boundary_segments = #(),
    raw_trim_boundary_segments = #(),
    cut_error_count = 0,
    slice_source_values = #(),
    slice_boundary_sets = #(),
    slice_pair_cuts = #(),
    last_slice_report = "",
    last_polygon_report = "",
    collapsed_cell_count = 0,
    intersection_mode = #poly,
    source_nodes = #(),
    source_handles = #(),
    result_node = undefined,
    trimmed_result_node = undefined,
    output_curves = true,
    output_surfaces = true,
    source_element_sets = #(),
    working_patch_sets = #(),
    process_patch_sets = #(),
    process_result_nodes = #(),
    inspection_process = 0,
    pair_segments_data = #(),
    pair_curve_nodes = #(),
    pair_source_indices = #(),
    legacy_stage_nodes = #(),
    inspection_pair = 0,
    position_precision_mm = 0.01,
    update_mode = #manual,
    is_dirty = false,
    is_rebuilding = false,
    node_callback = undefined,
    transform_handler = undefined,
    live_timer = undefined,


    /*
    Debugging mode: inspect existing Slice modifiers without adding any new ones.
    No generated surface receives a Slice modifier while topology is investigated.
    */
    function ensureResultSliceModifier target_node =
    (
        local slice_mod = undefined
        if isValidNode target_node then
        (
            for stack_mod in target_node.modifiers while slice_mod == undefined do
            (
                if classOf stack_mod == SliceModifier then slice_mod = stack_mod
            )
        )
        slice_mod
        -- return
    ),


    /*
    Names the linked curve and surface after the applied source-node names.
    For more than two sources, all names appear in their current priority order.
    Node identity, custom attributes, modifiers and source nodes are preserved.
    */
    function nameLinkedResults =
    (
        local named_ok = false
        if source_nodes.count >= 2 and isValidNode result_node and isValidNode trimmed_result_node then
        (
            local source_label = ""
            local valid_sources = true
            for source_node in source_nodes while valid_sources do
            (
                if isValidNode source_node then
                (
                    if source_label != "" then source_label += "+"
                    source_label += source_node.name
                )
                else valid_sources = false
            )

            if valid_sources and source_label != "" then
            (
                try
                (
                    result_node.name = source_label + "-curve"
                    trimmed_result_node.name = source_label
                    named_ok = true
                )
                catch
                (
                    format "SI RESULT NAME FAILED | %\n" (getCurrentException())
                )
            )
            else format "SI RESULT NAME SKIPPED | An applied source is invalid.\n"
        )
        named_ok
        -- return
    ),


    /*
    Places the Slice gizmo origin on the end of the FIRST OPEN spline of the
    final result. The knot is read in world space; the modifier context and
    object's transform convert it to the Slice Plane's local position.
    Rotation and the Editable Poly object's pivot are never changed.
    */
    function placeSliceGizmoAtCurveEnd =
    (
        local aligned = false
        if isValidNode result_node and isValidNode trimmed_result_node then
        (
            local world_endpoint = undefined
            for spline_index = 1 to (numSplines result_node) while world_endpoint == undefined do
            (
                local knot_count = numKnots result_node spline_index
                if knot_count >= 2 and not (isClosed result_node spline_index) then
                (
                    in coordsys world
                    (
                        world_endpoint = getKnotPoint result_node spline_index knot_count
                    )
                )
            )

            if world_endpoint != undefined then
            (
                local slice_mod = ensureResultSliceModifier trimmed_result_node
                if slice_mod != undefined then
                (
                    try
                    (
                        local context_tm = getModContextTM trimmed_result_node slice_mod
                        local world_to_object_tm = inverse trimmed_result_node.objectTransform
                        local local_endpoint = world_endpoint * context_tm * world_to_object_tm
                        slice_mod.slice_plane.position = local_endpoint
                        update trimmed_result_node
                        aligned = true
                    )
                    catch
                    (
                        format "SI SLICE PIVOT FAILED | %\n" (getCurrentException())
                    )
                )
                else format "SI SLICE PIVOT FAILED | Result has no valid Slice modifier.\n"
            )
            else format "SI SLICE PIVOT SKIPPED | Intersection has no open spline endpoint.\n"
        )
        aligned
        -- return
    ),


    /*
    Targets the generated trimmed-mesh Slice modifier first, creating it if
    needed. Before any result exists, retains active-modifier/stack fallback.
    */
    function getSliceGizmoModifier source_node:undefined =
    (
        local target_mod = undefined

        if isValidNode trimmed_result_node then
        (
            target_mod = ensureResultSliceModifier trimmed_result_node
        )
        else
        (
            local panel_mod = modPanel.getCurrentObject()

            if panel_mod != undefined and (classOf panel_mod == SliceModifier) then
            (
                target_mod = panel_mod
            )
            else if isValidNode source_node then
            (
                for stack_mod in source_node.modifiers while target_mod == undefined do
                (
                    if classOf stack_mod == SliceModifier then target_mod = stack_mod
                )
            )
        )

        target_mod
        -- return
    ),


    /*
    Applies a delta in degrees around the Slice gizmo's own X/Y/Z axis.
    MAXScript's row-vector transform convention puts the local increment first.
    */
    function rotateSliceGizmoLocal target_mod axis_index delta_angle =
    (
        local applied = false
        local axis_vector = undefined

        case axis_index of
        (
            1: (axis_vector = [1,0,0])
            2: (axis_vector = [0,1,0])
            3: (axis_vector = [0,0,1])
        )

        if target_mod != undefined and (classOf target_mod == SliceModifier) and axis_vector != undefined and delta_angle != 0.0 then
        (
            local prior_rotation = target_mod.slice_plane.rotation
            local delta_rotation = quat delta_angle axis_vector
            target_mod.slice_plane.rotation = normalize (delta_rotation * prior_rotation)
            applied = true
        )

        applied
        -- return
    ),


    /*
    Converts the supported millimeter precision option into current system units.
    Returns undefined for an unsupported precision choice.
    */
    function getPositionPrecision position_precision_mm =
    (
        case position_precision_mm of
        (
            1.0: (units.decodeValue "1mm")
            0.1: (units.decodeValue "0.1mm")
            0.01: (units.decodeValue "0.01mm")
            default: undefined
        )
        -- return
    ),


    /*
    Rounds a temporary position for endpoint identity without changing geometry.
    */
    function quantizePosition position_value position_precision =
    (
        local scaled_x = position_value.x / position_precision
        local scaled_y = position_value.y / position_precision
        local scaled_z = position_value.z / position_precision


        local rounded_x = if scaled_x >= 0.0 then (floor (scaled_x + 0.5)) else (ceil (scaled_x - 0.5))
        local rounded_y = if scaled_y >= 0.0 then (floor (scaled_y + 0.5)) else (ceil (scaled_y - 0.5))
        local rounded_z = if scaled_z >= 0.0 then (floor (scaled_z + 0.5)) else (ceil (scaled_z - 0.5))


        [(rounded_x * position_precision), (rounded_y * position_precision), (rounded_z * position_precision)]
        -- return
    ),


    /*
    Checks whether positions represent the same endpoint at the chosen precision.
    */
    function isSamePoint point_a point_b position_precision =
    (
        (quantizePosition point_a position_precision) == (quantizePosition point_b position_precision)
        -- return
    ),


    /*
    Tests whether a point is within a non-degenerate triangle using barycentric coordinates.
    Boundary slack is derived from the explicitly selected position precision.
    */
    function pointInTriangle point_value point_a point_b point_c position_precision =
    (
        local edge_u = point_b - point_a
        local edge_v = point_c - point_a
        local edge_w = point_c - point_b
        local to_point = point_value - point_a
        local dot_uu = dot edge_u edge_u
        local dot_uv = dot edge_u edge_v
        local dot_vv = dot edge_v edge_v
        local dot_pu = dot to_point edge_u
        local dot_pv = dot to_point edge_v
        local determinant = dot_uu * dot_vv - dot_uv * dot_uv
        local inside = false


        if determinant != 0.0 then
        (
            local longest_edge = amax (length edge_u) (amax (length edge_v) (length edge_w))
            local altitude = (length (cross edge_u edge_v)) / longest_edge
            local bary_precision = position_precision / altitude
            local bary_u = (dot_vv * dot_pu - dot_uv * dot_pv) / determinant
            local bary_v = (dot_uu * dot_pv - dot_uv * dot_pu) / determinant


            inside = ((bary_u >= -bary_precision) and (bary_v >= -bary_precision) and ((bary_u + bary_v) <= (1.0 + bary_precision)))
        )


        inside
        -- return
    ),


    /*
    Intersects an edge with a triangle using the explicit position precision.
    Nearly coplanar edges are handled by appendEdgeInTrianglePlane.
    Original source geometry is never snapped.
    */
    function getEdgeTriangleHit edge_start edge_end tri_a tri_b tri_c position_precision =
    (
        local plane_normal = cross (tri_b - tri_a) (tri_c - tri_a)
        local normal_length = length plane_normal
        local hit_point = undefined


        if normal_length > 0.0 then
        (
            local distance_start = dot plane_normal (edge_start - tri_a)
            local distance_end = dot plane_normal (edge_end - tri_a)
            local plane_distance_precision = normal_length * position_precision
            local crossing = ((distance_start <= plane_distance_precision and distance_end >= -plane_distance_precision) or \
                              (distance_start >= -plane_distance_precision and distance_end <= plane_distance_precision))


            if crossing and (distance_start != distance_end) then
            (
                local edge_direction = edge_end - edge_start
                local edge_length = length edge_direction
                if edge_length > 0.0 then
                (
                    local param_precision = position_precision / edge_length
                    local fraction = distance_start / (distance_start - distance_end)
                    if fraction >= -param_precision and fraction <= (1.0 + param_precision) then
                    (
                        -- Avoid extending beyond the finite source edge.
                        local clipped_fraction = amax 0.0 (amin 1.0 fraction)
                        local candidate = edge_start + edge_direction * clipped_fraction
                        if pointInTriangle candidate tri_a tri_b tri_c position_precision then
                        (
                            hit_point = candidate
                        )
                    )
                )
            )
        )


        hit_point
        -- return
    ),


    /*
    Adds an intersection point only when it is not already represented in the set.
    */
    function appendUniquePoint point_values new_point position_precision =
    (
        exists = false


        for old_point in point_values while not exists do
        (
            if isSamePoint old_point new_point position_precision then
            (
                exists = true
            )
        )


        if not exists then
        (
            append point_values new_point
        )


        (not exists)
        -- return
    ),


    /*
    Clips a finite coplanar edge to a nondegenerate target triangle.
    Adds endpoints of overlap; boundary allowance comes from position_precision.
    */
    function appendEdgeInTrianglePlane edge_start edge_end tri_a tri_b tri_c hit_points position_precision =
    (
        local plane_normal = cross (tri_b - tri_a) (tri_c - tri_a)
        local start_distance = dot plane_normal (edge_start - tri_a)
        local end_distance = dot plane_normal (edge_end - tri_a)
        local overlap_found = false


        local normal_length = length plane_normal
        local plane_distance_precision = normal_length * position_precision
        if (normal_length > 0.0) and (abs start_distance <= plane_distance_precision) and (abs end_distance <= plane_distance_precision) then
        (
            local basis_u = tri_b - tri_a
            local basis_v = tri_c - tri_a
            local edge_start_offset = edge_start - tri_a
            local edge_end_offset = edge_end - tri_a
            local dot_uu = dot basis_u basis_u
            local dot_uv = dot basis_u basis_v
            local dot_vv = dot basis_v basis_v
            local determinant = dot_uu * dot_vv - dot_uv * dot_uv


            if determinant != 0.0 then
            (
                local u_start = (dot_vv * (dot edge_start_offset basis_u) - dot_uv * (dot edge_start_offset basis_v)) / determinant
                local v_start = (dot_uu * (dot edge_start_offset basis_v) - dot_uv * (dot edge_start_offset basis_u)) / determinant
                local u_end = (dot_vv * (dot edge_end_offset basis_u) - dot_uv * (dot edge_end_offset basis_v)) / determinant
                local v_end = (dot_uu * (dot edge_end_offset basis_v) - dot_uv * (dot edge_end_offset basis_u)) / determinant


                local weights_start = #(u_start, v_start, 1.0 - u_start - v_start)
                local weights_end = #(u_end, v_end, 1.0 - u_end - v_end)
                local longest_edge = amax (length basis_u) (amax (length basis_v) (length (tri_c - tri_b)))
                local altitude = normal_length / longest_edge
                local bary_precision = position_precision / altitude
                local interval_start = 0.0
                local interval_end = 1.0
                local overlap_valid = true


                for weight_index = 1 to 3 while overlap_valid do
                (
                    local weight_start = weights_start[weight_index]
                    local weight_change = weights_end[weight_index] - weight_start
                    if weight_change > 0.0 then
                    (
                        interval_start = amax interval_start ((-bary_precision - weight_start) / weight_change)
                    )
                    else if weight_change < 0.0 then
                    (
                        interval_end = amin interval_end ((-bary_precision - weight_start) / weight_change)
                    )
                    else if weight_start < -bary_precision then
                    (
                        overlap_valid = false
                    )
                    if interval_start > interval_end then
                    (
                        overlap_valid = false
                    )
                )


                if overlap_valid then
                (
                    local edge_direction = edge_end - edge_start
                    local clipped_start = edge_start + edge_direction * interval_start
                    local clipped_end = edge_start + edge_direction * interval_end
                    appendUniquePoint hit_points clipped_start position_precision
                    appendUniquePoint hit_points clipped_end position_precision
                    overlap_found = true
                )
            )
        )
        overlap_found
        -- return
    ),


    /*
    Finds the finite intersection segment of two noncoplanar mesh triangles.
    Returns two world-space points or undefined; never snaps the source geometry.
    */
    function intersectTriangles triangle_a triangle_b position_precision =
    (
        local hits = #()
        local normal_a = cross (triangle_a[2] - triangle_a[1]) (triangle_a[3] - triangle_a[1])
        local normal_b = cross (triangle_b[2] - triangle_b[1]) (triangle_b[3] - triangle_b[1])
        local planes_intersect = (length normal_a > 0.0) and (length normal_b > 0.0) and (length (cross normal_a normal_b) > 0.0)


        if planes_intersect then
        (
            for edge_index = 1 to 3 do
            (
                local next_index = if edge_index == 3 then 1 else edge_index + 1
                local hit_point = getEdgeTriangleHit triangle_a[edge_index] triangle_a[next_index] triangle_b[1] triangle_b[2] triangle_b[3] position_precision


                if hit_point != undefined then
                (
                    appendUniquePoint hits hit_point position_precision
                )
                appendEdgeInTrianglePlane triangle_a[edge_index] triangle_a[next_index] triangle_b[1] triangle_b[2] triangle_b[3] hits position_precision


                hit_point = getEdgeTriangleHit triangle_b[edge_index] triangle_b[next_index] triangle_a[1] triangle_a[2] triangle_a[3] position_precision


                if hit_point != undefined then
                (
                    appendUniquePoint hits hit_point position_precision
                )
                appendEdgeInTrianglePlane triangle_b[edge_index] triangle_b[next_index] triangle_a[1] triangle_a[2] triangle_a[3] hits position_precision
            )
        )


        best_segment = undefined
        largest_distance_squared = 0.0


        if hits.count >= 2 then
        (
            for point_index = 1 to (hits.count - 1) do
            (
                for next_index = (point_index + 1) to hits.count do
                (
                    separation = hits[point_index] - hits[next_index]
                    distance_squared = dot separation separation


                    if distance_squared > largest_distance_squared then
                    (
                        largest_distance_squared = distance_squared
                        best_segment = #(hits[point_index], hits[next_index])
                    )
                )
            )
        )


        best_segment
        -- return
    ),


    /*
    Returns a cached triangle with its bounding-box minimum and maximum points.
    */
    function getCachedTriangle mesh_value face_index =
    (
        vertex_ids = getFace mesh_value face_index
        point_a = getVert mesh_value vertex_ids.x
        point_b = getVert mesh_value vertex_ids.y
        point_c = getVert mesh_value vertex_ids.z


        box_min = [
            (amin point_a.x (amin point_b.x point_c.x)),
            (amin point_a.y (amin point_b.y point_c.y)),
            (amin point_a.z (amin point_b.z point_c.z))]


        box_max = [
            (amax point_a.x (amax point_b.x point_c.x)),
            (amax point_a.y (amax point_b.y point_c.y)),
            (amax point_a.z (amax point_b.z point_c.z))]


        local edge_visibility = #((getEdgeVis mesh_value face_index 1), (getEdgeVis mesh_value face_index 2), (getEdgeVis mesh_value face_index 3))
        #(#(point_a, point_b, point_c), box_min, box_max, edge_visibility, #(vertex_ids.x, vertex_ids.y, vertex_ids.z))
        -- return
    ),


    /*
    Returns true if two triangle world-space bounding boxes overlap.
    */
    function triangleBoxesOverlap cached_a cached_b position_precision =
    (
        box_a_min = cached_a[2]
        box_a_max = cached_a[3]
        box_b_min = cached_b[2]
        box_b_max = cached_b[3]


        ((box_a_min.x <= box_b_max.x + position_precision) and (box_b_min.x <= box_a_max.x + position_precision) and \
         (box_a_min.y <= box_b_max.y + position_precision) and (box_b_min.y <= box_a_max.y + position_precision) and \
         (box_a_min.z <= box_b_max.z + position_precision) and (box_b_min.z <= box_a_max.z + position_precision))
        -- return
    ),


    /*
    Avoids duplicate intersection segments caused by shared triangle boundaries.
    */
    function appendUniqueSegment segment_values new_segment position_precision =
    (
        is_duplicate = false
        was_added = false


        if not (isSamePoint new_segment[1] new_segment[2] position_precision) then
        (
            for old_segment in segment_values while not is_duplicate do
            (
                same_direction = ((isSamePoint old_segment[1] new_segment[1] position_precision) and (isSamePoint old_segment[2] new_segment[2] position_precision))
                opposite_direction = ((isSamePoint old_segment[1] new_segment[2] position_precision) and (isSamePoint old_segment[2] new_segment[1] position_precision))


                if same_direction or opposite_direction then
                (
                    is_duplicate = true
                )
            )


            if not is_duplicate then
            (
                append segment_values new_segment
                was_added = true
            )
        )


        was_added
        -- return
    ),


    /*
    Finds this setup's exact Slice instances through their persistent owner refs.
    Includes source-only instances if a generated surface was manually deleted.
    */
    function getOwnedEndpointSlices =
    (
        local owned_mods = #()
        local owner_key = if isValidNode result_node then getUserProp result_node "SI_SliceOwnerKey" else undefined
        if owner_key != undefined and owner_key != "" then
        (
            for stack_mod in (getClassInstances SliceModifier target:rootNode) do
            (
                if isProperty stack_mod #SI_EndpointSlice then
                (
                    if stack_mod.SI_EndpointSlice.owner_key == owner_key then appendIfUnique owned_mods stack_mod
                )
            )
        )
        owned_mods
        -- return
    ),

    /*
    Resolves persisted modifier identity keys against this setup's actual nodes.
    String identities avoid host-node reference cycles inside a modifier.
    */
    function getEndpointSliceNodes slice_mod =
    (
        local linked_source = undefined
        local linked_result = undefined
        local ownership = slice_mod.SI_EndpointSlice
        for candidate_node in (refs.dependentNodes slice_mod) where isValidNode candidate_node do
        (
            if (getUserProp candidate_node "SI_SliceSourceKey") == ownership.source_key then linked_source = candidate_node
            if (getUserProp candidate_node "SI_SliceSurfaceKey") == ownership.result_key then linked_result = candidate_node
        )
        #(linked_source, linked_result)
        -- return
    ),

    /*
    Removes only explicitly owned instances from their recorded source and output.
    Exact stack references are resolved again before each removal.
    */
    function removeEndpointSlice slice_mod =
    (
        local removed_ok = isProperty slice_mod #SI_EndpointSlice
        if removed_ok then
        (
            local ownership = slice_mod.SI_EndpointSlice
            removed_ok = isValidNode result_node and ownership.owner_key == (getUserProp result_node "SI_SliceOwnerKey")
            if removed_ok then
            (
                local linked_nodes = getEndpointSliceNodes slice_mod
                for target_node in linked_nodes where isValidNode target_node do
                (
                    local stack_index = findItem (for stack_mod in target_node.modifiers collect stack_mod) slice_mod
                    if stack_index > 0 then deleteModifier target_node stack_index
                    if (findItem (for stack_mod in target_node.modifiers collect stack_mod) slice_mod) > 0 then removed_ok = false
                )
            )
        )
        if not removed_ok then format "SI SLICE REMOVE FAILED | Exact ownership or removal verification failed.\n"
        removed_ok
        -- return
    ),

    /*
    Returns the finite outer border edges of evaluated triangles by shared IDs.
    Invisible shared triangulation edges are never considered a source border.
    */
    function buildSourceBorderSegments triangle_set =
    (
        local edge_records = #()
        for cached_triangle in triangle_set do
        (
            for edge_index = 1 to 3 do
            (
                local next_index = if edge_index == 3 then 1 else edge_index + 1
                local first_id = amin cached_triangle[5][edge_index] cached_triangle[5][next_index]
                local second_id = amax cached_triangle[5][edge_index] cached_triangle[5][next_index]
                local record_index = 0
                for candidate_index = 1 to edge_records.count while record_index == 0 do
                (
                    if edge_records[candidate_index][1] == first_id and edge_records[candidate_index][2] == second_id then record_index = candidate_index
                )
                if record_index > 0 then edge_records[record_index][3] += 1
                else append edge_records #(first_id, second_id, 1, cached_triangle[1][edge_index], cached_triangle[1][next_index])
            )
        )
        for edge_record in edge_records where edge_record[3] == 1 collect #(edge_record[4], edge_record[5])
        -- return
    ),

    /*
    Reads the current evaluated mesh as world-space triangles without editing the source node.
    */
    function buildTriangleCache source_node =
    (
        temporary_mesh = snapshotAsMesh source_node
        triangles = #()
        triangles.count = (getNumFaces temporary_mesh)


        for face_index = 1 to triangles.count do
        (
            triangles[face_index] = getCachedTriangle temporary_mesh face_index
        )


        delete temporary_mesh
        triangles
        -- return
    ),


    /*
    Extracts all finite triangle-to-triangle intersections for one pair of surfaces.
    */
    function collectPairSegments triangles_a triangles_b position_precision =
    (
        segments = #()


        for cached_a in triangles_a do
        (
            for cached_b in triangles_b do
            (
                if triangleBoxesOverlap cached_a cached_b position_precision then
                (
                    new_segment = intersectTriangles cached_a[1] cached_b[1] position_precision


                    if new_segment != undefined then
                    (
                        appendUniqueSegment segments new_segment position_precision
                    )
                )
            )
        )


        segments
        -- return
    ),


    /*
    Counts incident segments at an endpoint to identify branches and boundaries.
    */
    function getEndpointDegree segment_values query_point position_precision =
    (
        degree_count = 0


        for segment_value in segment_values do
        (
            if isSamePoint segment_value[1] query_point position_precision then degree_count += 1
            if isSamePoint segment_value[2] query_point position_precision then degree_count += 1
        )


        degree_count
        -- return
    ),


    /*
    Finds the next unused segment attached to a given endpoint.
    Returns #(segment index, next point), or undefined if no match exists.
    */
    function findUnusedNeighbor segment_values used_flags query_point position_precision =
    (
        neighbor_result = undefined


        for segment_index = 1 to segment_values.count while neighbor_result == undefined do
        (
            if not used_flags[segment_index] then
            (
                next_point = undefined


                if isSamePoint segment_values[segment_index][1] query_point position_precision then
                (
                    next_point = segment_values[segment_index][2]
                )
                else if isSamePoint segment_values[segment_index][2] query_point position_precision then
                (
                    next_point = segment_values[segment_index][1]
                )


                if next_point != undefined then
                (
                    neighbor_result = #(segment_index, next_point)
                )
            )
        )


        neighbor_result
        -- return
    ),


    /*
    A knot is eligible for removal only when it lies inside an actual hidden
    edge from snapshotAsMesh. An ordinary visible edge is never simplified here.
    */
    function isOnHiddenEdge point_value position_precision =
    (
        local found = false
        for edge_points in hidden_edge_segments while not found do
        (
            local edge_vector = edge_points[2] - edge_points[1]
            local squared_length = dot edge_vector edge_vector
            if squared_length > 0.0 then
            (
                local fraction = (dot (point_value - edge_points[1]) edge_vector) / squared_length
                local border_fraction = position_precision / (sqrt squared_length)
                if fraction > border_fraction and fraction < (1.0 - border_fraction) then
                (
                    local closest_point = edge_points[1] + edge_vector * fraction
                    found = (length (point_value - closest_point)) <= position_precision
                )
            )
        )
        /* Visible edges from any source protect coincident intersection knots. */
        for edge_points in visible_edge_segments while found do
        (
            local edge_vector = edge_points[2] - edge_points[1]
            local squared_length = dot edge_vector edge_vector
            if squared_length > 0.0 then
            (
                local fraction = (dot (point_value - edge_points[1]) edge_vector) / squared_length
                local closest_point = edge_points[1] + edge_vector * (amax 0.0 (amin 1.0 fraction))
                if (length (point_value - closest_point)) <= position_precision then found = false
            )
        )
        found
        -- return
    ),


    /*
    Preserve corners and branch vertices. Remove only straight-through knots
    caused by hidden diagonals of the source's evaluated triangles.
    */
    function simplifyHiddenKnots chain_points segment_values position_precision =
    (
        local simplified = for knot_point in chain_points collect knot_point
        local is_closed = simplified.count > 2 and (isSamePoint simplified[1] simplified[simplified.count] position_precision)
        if true then /* Polygon topology is the only supported mode. */
        (
            if is_closed then deleteItem simplified simplified.count
            local point_index = if is_closed then 1 else 2
            while simplified.count > (if is_closed then 3 else 2) and point_index <= (if is_closed then simplified.count else simplified.count - 1) do
            (
                local before_index = if point_index == 1 then simplified.count else point_index - 1
                local after_index = if point_index == simplified.count then 1 else point_index + 1
                local point_before = simplified[before_index]
                local point_middle = simplified[point_index]
                local point_after = simplified[after_index]
                local full_vector = point_after - point_before
                local squared_length = dot full_vector full_vector
                local removable = false
                if squared_length > 0.0 and (getEndpointDegree segment_values point_middle position_precision) == 2 then
                (
                    if isOnHiddenEdge point_middle position_precision then
                    (
                        local fraction = (dot (point_middle - point_before) full_vector) / squared_length
                        local projected_point = point_before + full_vector * fraction
                        removable = fraction > 0.0 and fraction < 1.0 and \
                                    (length (point_middle - projected_point)) <= position_precision
                    )
                )
                if removable then
                (
                    deleteItem simplified point_index
                )
                else
                (
                    point_index += 1
                )
            )
            if is_closed then append simplified simplified[1]
        )
        simplified
        -- return
    ),


    /*
    Joins contiguous segments into line chains without joining unrelated junction branches.
    */
    function buildCurveChains segment_values position_precision =
    (
        used_flags = for segment_index = 1 to segment_values.count collect false
        chains = #()


        for first_index = 1 to segment_values.count do
        (
            if not used_flags[first_index] then
            (
                used_flags[first_index] = true
                chain_points = #(segment_values[first_index][1], segment_values[first_index][2])


                walking = true
                while walking do
                (
                    last_point = chain_points[chain_points.count]
                    walking = (getEndpointDegree segment_values last_point position_precision) == 2


                    if walking then
                    (
                        next_link = findUnusedNeighbor segment_values used_flags last_point position_precision


                        if next_link != undefined then
                        (
                            used_flags[next_link[1]] = true
                            append chain_points next_link[2]


                            if isSamePoint chain_points[1] next_link[2] position_precision then
                            (
                                walking = false
                            )
                        )
                        else
                        (
                            walking = false
                        )
                    )
                )


                if not (isSamePoint chain_points[1] chain_points[chain_points.count] position_precision) then
                (
                    walking = true
                    while walking do
                    (
                        first_point = chain_points[1]
                        walking = (getEndpointDegree segment_values first_point position_precision) == 2


                        if walking then
                        (
                            next_link = findUnusedNeighbor segment_values used_flags first_point position_precision


                            if next_link != undefined then
                            (
                                used_flags[next_link[1]] = true
                                insertItem next_link[2] chain_points 1
                            )
                            else
                            (
                                walking = false
                            )
                        )
                    )
                )


                append chains chain_points
            )
        )


        chains
        -- return
    ),


    /*
    Find a nonparallel, finite 3D crossing of a loose terminal edge and another
    curve segment. Return the cut position only when their separation is within
    the explicitly selected position precision; do not extend either segment.
    */
    function getTerminalSegmentCrossing loose_point inner_point other_start other_end position_precision =
    (
        local terminal_vector = inner_point - loose_point
        local other_vector = other_end - other_start
        local displacement = loose_point - other_start
        local terminal_length_squared = dot terminal_vector terminal_vector
        local other_length_squared = dot other_vector other_vector
        local crossing_point = undefined


        if terminal_length_squared > 0.0 and other_length_squared > 0.0 then
        (
            local mixed_dot = dot terminal_vector other_vector
            local determinant = terminal_length_squared * other_length_squared - mixed_dot * mixed_dot
            if determinant > 0.0 then
            (
                local terminal_dot = dot terminal_vector displacement
                local other_dot = dot other_vector displacement
                local terminal_fraction = (mixed_dot * other_dot - other_length_squared * terminal_dot) / determinant
                local other_fraction = (terminal_length_squared * other_dot - mixed_dot * terminal_dot) / determinant
                local terminal_margin = position_precision / (sqrt terminal_length_squared)
                local other_margin = position_precision / (sqrt other_length_squared)
                if terminal_fraction > terminal_margin and terminal_fraction < (1.0 - terminal_margin) and \
                   other_fraction >= -other_margin and other_fraction <= (1.0 + other_margin) then
                (
                    local terminal_crossing = loose_point + terminal_vector * terminal_fraction
                    local other_crossing = other_start + other_vector * other_fraction
                    if (length (terminal_crossing - other_crossing)) <= position_precision then
                    (
                        crossing_point = terminal_crossing
                    )
                )
            )
        )
        crossing_point
        -- return
    ),


    /*
    Trim only genuinely free endpoints of open spline chains. The endpoint's
    existing terminal segment must cross a different chain. Keep the nearest
    crossing encountered walking inward from that endpoint, preserving all
    internal knots and all other segments; do not modify source geometry.
    */
    function trimFreeCurveEndpoints chain_values segment_values position_precision =
    (
        local original_chains = for chain_points in chain_values collect (for knot_point in chain_points collect knot_point)
        local processed_chains = for chain_points in original_chains collect (for knot_point in chain_points collect knot_point)
        local shared_corners = #()


        for chain_index = 1 to original_chains.count do
        (
            local current_chain = original_chains[chain_index]
            local knot_count = current_chain.count
            if knot_count >= 2 and not (isSamePoint current_chain[1] current_chain[knot_count] position_precision) then
            (
                for end_index = 1 to 2 do
                (
                    local terminal_index = if end_index == 1 then 1 else knot_count
                    local inner_index = if end_index == 1 then 2 else knot_count - 1
                    local loose_point = current_chain[terminal_index]
                    local inner_point = current_chain[inner_index]
                    if (getEndpointDegree segment_values loose_point position_precision) == 1 then
                    (
                        local best_crossing = undefined
                        local best_distance_squared = undefined
                        for other_chain_index = 1 to original_chains.count do
                        (
                            if other_chain_index != chain_index then
                            (
                                local other_chain = original_chains[other_chain_index]
                                for segment_index = 1 to (other_chain.count - 1) do
                                (
                                    local candidate = getTerminalSegmentCrossing loose_point inner_point \
                                        other_chain[segment_index] other_chain[segment_index + 1] position_precision
                                    if candidate != undefined then
                                    (
                                        local delta = candidate - loose_point
                                        local candidate_distance_squared = dot delta delta
                                        if best_distance_squared == undefined or candidate_distance_squared < best_distance_squared then
                                        (
                                            best_crossing = candidate
                                            best_distance_squared = candidate_distance_squared
                                        )
                                    )
                                )
                            )
                        )
                        if best_crossing != undefined then
                        (
                            local canonical_crossing = best_crossing
                            local found_shared_corner = false
                            for existing_corner in shared_corners while not found_shared_corner do
                            (
                                if isSamePoint existing_corner best_crossing position_precision then
                                (
                                    canonical_crossing = existing_corner
                                    found_shared_corner = true
                                )
                            )
                            if not found_shared_corner then
                            (
                                append shared_corners best_crossing
                            )
                            processed_chains[chain_index][terminal_index] = canonical_crossing
                        )
                    )
                )
            )
        )
        processed_chains
        -- return
    ),


    /*
    Creates or updates a splineShape in place, preserving its node and modifier stack.
    An empty result is retained for live links when keep_empty is true.
    */
    function makeSplineResult segment_values position_precision result_shape:undefined keep_empty:false =
    (
        /* Deleted MAXNodes are still non-undefined. Never query splines on a
           stale node retained by a prior live link or pair-curve array. */
        if result_shape != undefined and not (isValidNode result_shape) then
        (
            format "SI CURVE RECOVER | Deleted cached spline result; creating a replacement.\n"
            result_shape = undefined
        )
        if result_shape != undefined or segment_values.count > 0 or keep_empty then
        (
            if result_shape == undefined then
            (
                result_shape = splineShape name:"Surface_Intersections"
            )
            else
            (
                for spline_index = (numSplines result_shape) to 1 by -1 do
                (
                    deleteSpline result_shape spline_index
                )
            )


            if segment_values.count > 0 then
            (
                local chains = buildCurveChains segment_values position_precision
                chains = trimFreeCurveEndpoints chains segment_values position_precision


                for chain_points in chains do
                (
                    chain_points = simplifyHiddenKnots chain_points segment_values position_precision
                    addNewSpline result_shape
                    local spline_index = numSplines result_shape
                    local is_closed = ((chain_points.count > 2) and (isSamePoint chain_points[1] chain_points[chain_points.count] position_precision))
                    local final_count = if is_closed then chain_points.count - 1 else chain_points.count


                    for knot_index = 1 to final_count do
                    (
                        in coordsys world
                        (
                            addKnot result_shape spline_index #corner #line chain_points[knot_index]
                        )
                    )


                    if is_closed then
                    (
                        close result_shape spline_index
                    )
                )
            )


            updateShape result_shape
            result_shape.wirecolor = color 50 185 245
        )


        result_shape
        -- return
    ),


    /*
    Return a finite planar cutter's origin and unit normal, or undefined.
    Non-planar cutter meshes are skipped rather than being treated as planes.
    */
    function getPlanarCutter triangle_set position_precision =
    (
        local cutter_plane = undefined
        if triangle_set.count > 0 then
        (
            local vertices = triangle_set[1][1]
            local raw_normal = cross (vertices[2] - vertices[1]) (vertices[3] - vertices[1])
            local normal_length = length raw_normal
            if normal_length > 0.0 then
            (
                local normal_value = raw_normal / normal_length
                local origin_value = vertices[1]
                local planar = true
                for cached_triangle in triangle_set while planar do
                (
                    for triangle_point in cached_triangle[1] while planar do
                    (
                        planar = (abs (dot normal_value (triangle_point - origin_value))) <= position_precision
                    )
                )
                if planar then cutter_plane = #(origin_value, normal_value)
            )
        )
        cutter_plane
        -- return
    ),


    /*
    A cutter is finite. Projection outside all its actual faces cannot trim.
    */
    function isPointOnCutter point_value triangle_set position_precision =
    (
        local inside = false
        for cached_triangle in triangle_set while not inside do
        (
            inside = pointInTriangle point_value cached_triangle[1][1] cached_triangle[1][2] cached_triangle[1][3] position_precision
        )
        inside
        -- return
    ),


    /*
    Average source positions to choose a reasonable AUTO half-space.
    The UI can override AUTO for every ordered source independently.
    */
    function getSourcesCenter triangle_sets =
    (
        local sum_position = [0.0,0.0,0.0]
        local total_points = 0
        for triangle_set in triangle_sets do
        (
            for cached_triangle in triangle_set do
            (
                for point_value in cached_triangle[1] do
                (
                    sum_position += point_value
                    total_points += 1
                )
            )
        )
        if total_points > 0 then (sum_position / total_points) else undefined
        -- return
    ),


    /*
    Clip a finite intersection segment only when the cutter footprint covers
    the crossing (or projection of a wholly discarded segment).
    Kept half-space: #auto, #positive, #negative; #off bypasses this cutter.
    */
    function clipSegmentByCutter segment_value cutter_plane triangle_set clip_mode reference_center position_precision =
    (
        local clipped_segment = segment_value
        if clip_mode != #off and cutter_plane != undefined then
        (
            local origin_value = cutter_plane[1]
            local normal_value = cutter_plane[2]
            local keep_sign = 1.0
            case clip_mode of
            (
                #negative: (keep_sign = -1.0)
                #positive: (keep_sign = 1.0)
                default:
                (
                    if reference_center != undefined then
                    (
                        if (dot normal_value (reference_center - origin_value)) < 0.0 then keep_sign = -1.0
                    )
                )
            )
            local distance_a = keep_sign * (dot normal_value (segment_value[1] - origin_value))
            local distance_b = keep_sign * (dot normal_value (segment_value[2] - origin_value))
            local keep_a = distance_a >= -position_precision
            local keep_b = distance_b >= -position_precision
            if not (keep_a and keep_b) then
            (
                local candidate = undefined
                local crosses_plane = ((distance_a <= 0.0 and distance_b >= 0.0) or \
                                       (distance_a >= 0.0 and distance_b <= 0.0))
                if crosses_plane and distance_a != distance_b then
                (
                    local fraction = distance_a / (distance_a - distance_b)
                    if fraction >= 0.0 and fraction <= 1.0 then
                    (
                        candidate = segment_value[1] + (segment_value[2] - segment_value[1]) * fraction
                    )
                )
                if candidate != undefined then
                (
                    if isPointOnCutter candidate triangle_set position_precision then
                    (
                        if keep_a then clipped_segment = #(segment_value[1], candidate)
                        else if keep_b then clipped_segment = #(candidate, segment_value[2])
                        else clipped_segment = undefined
                    )
                )
                else if not keep_a and not keep_b then
                (
                    local mid_point = (segment_value[1] + segment_value[2]) * 0.5
                    local projected = mid_point - normal_value * (dot normal_value (mid_point - origin_value))
                    if isPointOnCutter projected triangle_set position_precision then
                    (
                        clipped_segment = undefined
                    )
                )
            )
        )
        clipped_segment
        -- return
    ),


    /*
    A working patch is a convex world-space polygon. Split it without changing
    any source node; both fragments reuse exact interpolated coordinates.
    A pair of polygon arrays is always returned: #(positive, negative).
    */
    function splitWorkingPatch patch_points plane_origin plane_normal position_precision crossing_points:#() exact_sides:false =
    (
        local side_precision = if exact_sides then 0.0 else position_precision
        local positive_points = #()
        local negative_points = #()
        if patch_points.count >= 3 then
        (
            for edge_index = 1 to patch_points.count do
            (
                local next_index = if edge_index == patch_points.count then 1 else edge_index + 1
                local point_start = patch_points[edge_index]
                local point_end = patch_points[next_index]
                local signed_start = dot (point_start - plane_origin) plane_normal
                local signed_end = dot (point_end - plane_origin) plane_normal
                if signed_start >= -side_precision then append positive_points point_start
                if signed_start <= side_precision then append negative_points point_start
                if (signed_start > side_precision and signed_end < -side_precision) or \
                   (signed_start < -side_precision and signed_end > side_precision) then
                (
                    local crossing_fraction = signed_start / (signed_start - signed_end)
                    local crossing_point = point_start + (point_end - point_start) * crossing_fraction
                    /* Use the actual curve junction instead of recomputing an
                       ill-conditioned intersection of nearly parallel lines. */
                    local edge_vector = point_end - point_start
                    local edge_squared = dot edge_vector edge_vector
                    local matched_crossing = false
                    for actual_point in crossing_points while not matched_crossing do
                    (
                        local fraction = (dot (actual_point - point_start) edge_vector) / edge_squared
                        local projection = point_start + edge_vector * fraction
                        if fraction >= 0.0 and fraction <= 1.0 and \
                           (length (actual_point - projection)) <= position_precision and \
                           (abs (dot (actual_point - plane_origin) plane_normal)) <= position_precision then
                        (
                            crossing_point = actual_point
                            matched_crossing = true
                        )
                    )
                    append positive_points crossing_point
                    append negative_points crossing_point
                )
            )
        )
        #(positive_points, negative_points)
        -- return
    ),

    /* Removes consecutive duplicate vertices and zero-area polygon fragments. */
    function cleanWorkingPatch patch_points position_precision =
    (
        local cleaned_points = #()
        for point_value in patch_points do
        (
            if cleaned_points.count == 0 or not (isSamePoint cleaned_points[cleaned_points.count] point_value position_precision) then
            (
                append cleaned_points point_value
            )
        )
        if cleaned_points.count >= 2 and (isSamePoint cleaned_points[1] cleaned_points[cleaned_points.count] position_precision) then
        (
            deleteItem cleaned_points cleaned_points.count
        )
        if cleaned_points.count >= 3 then
        (
            local area_vector = [0.0,0.0,0.0]
            local longest_edge = 0.0
            for point_index = 2 to (cleaned_points.count - 1) do
            (
                area_vector += cross (cleaned_points[point_index] - cleaned_points[1]) (cleaned_points[point_index + 1] - cleaned_points[1])
            )
            for point_index = 1 to cleaned_points.count do
            (
                local next_index = if point_index == cleaned_points.count then 1 else point_index + 1
                longest_edge = amax longest_edge (length (cleaned_points[next_index] - cleaned_points[point_index]))
            )
            if (length area_vector) <= (position_precision * longest_edge) then cleaned_points = #()
        )
        else cleaned_points = #()
        cleaned_points
        -- return
    ),

    /*
    A finite cutter applies ONLY inside its planar footprint. Its edge halfspaces
    partition a target patch into outside pieces and one inside piece. Trim that
    inside piece by the cutter plane, preserving the requested side.
    This also handles cutter polygons that were themselves trimmed earlier.
    */
    function trimPatchWithCutter target_points cutter_points kept_mode reference_center position_precision =
    (
        local surviving = #()
        if kept_mode == #off or cutter_points.count < 3 then
        (
            append surviving target_points
        )
        else
        (
            local cutter_origin = cutter_points[1]
            local normal_vector = [0.0,0.0,0.0]
            for normal_index = 2 to (cutter_points.count - 1) do
            (
                normal_vector += cross (cutter_points[normal_index] - cutter_origin) (cutter_points[normal_index + 1] - cutter_origin)
            )
            if (length normal_vector) == 0.0 then
            (
                append surviving target_points
            )
            else
            (
                local cutter_normal = normalize normal_vector
                local kept_sign = 1.0
                case kept_mode of
                (
                    #negative: (kept_sign = -1.0)
                    #positive: (kept_sign = 1.0)
                    default:
                    (
                        if reference_center != undefined and (dot cutter_normal (reference_center - cutter_origin)) < 0.0 then
                        (
                            kept_sign = -1.0
                        )
                    )
                )
                local all_kept = true
                local coplanar = true
                for target_point in target_points do
                (
                    local signed_distance = dot (target_point - cutter_origin) cutter_normal
                    if signed_distance * kept_sign < -position_precision then all_kept = false
                    if (abs signed_distance) > position_precision then coplanar = false
                )
                if all_kept or coplanar then
                (
                    append surviving target_points
                )
                else
                (
                    local inside_points = target_points
                    for cutter_index = 1 to cutter_points.count while inside_points.count >= 3 do
                    (
                        local next_index = if cutter_index == cutter_points.count then 1 else cutter_index + 1
                        local edge_start = cutter_points[cutter_index]
                        local edge_vector = cutter_points[next_index] - edge_start
                        local inward_vector = cross cutter_normal edge_vector
                        if (length inward_vector) > 0.0 then
                        (
                            inward_vector = normalize inward_vector
                            local pieces = splitWorkingPatch inside_points edge_start inward_vector position_precision
                            local outside_points = cleanWorkingPatch pieces[2] position_precision
                            if outside_points.count >= 3 then append surviving outside_points
                            inside_points = cleanWorkingPatch pieces[1] position_precision
                        )
                    )
                    if inside_points.count >= 3 then
                    (
                        local plane_pieces = splitWorkingPatch inside_points cutter_origin cutter_normal position_precision
                        local kept_points = if kept_sign > 0.0 then plane_pieces[1] else plane_pieces[2]
                        kept_points = cleanWorkingPatch kept_points position_precision
                        if kept_points.count >= 3 then append surviving kept_points
                    )
                )
            )
        )
        surviving
        -- return
    ),

    /* Triangle-compatible cached descriptor used by existing curve intersection. */
    function getWorkingTriangle point_a point_b point_c =
    (
        local minimum_point = [
            (amin point_a.x (amin point_b.x point_c.x)),
            (amin point_a.y (amin point_b.y point_c.y)),
            (amin point_a.z (amin point_b.z point_c.z))]
        local maximum_point = [
            (amax point_a.x (amax point_b.x point_c.x)),
            (amax point_a.y (amax point_b.y point_c.y)),
            (amax point_a.z (amax point_b.z point_c.z))]
        #(#(point_a, point_b, point_c), minimum_point, maximum_point, #(true,true,true))
        -- return
    ),

    /* Triangulates surviving convex patches in memory, not into the scene. */
    function getWorkingTriangles patch_values =
    (
        local triangles = #()
        for patch_points in patch_values do
        (
            if patch_points.count >= 3 then
            (
                for point_index = 2 to (patch_points.count - 1) do
                (
                    append triangles (getWorkingTriangle patch_points[1] patch_points[point_index] patch_points[point_index + 1])
                )
            )
        )
        triangles
        -- return
    ),

    /*
    Returns the geometric normal of a convex working polygon, or undefined
    if its boundary has no meaningful area.
    */
    function getPatchNormal patch_points =
    (
        local unit_normal = undefined
        if patch_points.count >= 3 then
        (
            local vector_sum = [0.0,0.0,0.0]
            for vertex_index = 2 to (patch_points.count - 1) do
            (
                vector_sum += cross (patch_points[vertex_index] - patch_points[1]) (patch_points[vertex_index + 1] - patch_points[1])
            )
            if (length vector_sum) > 0.0 then unit_normal = normalize vector_sum
        )
        unit_normal
        -- return
    ),

    /*
    Tests convex polygon plane and oriented boundary halfspaces directly.
    Collinear corners cannot create unstable zero-area containment triangles.
    */
    function pointInConvexPatch point_value patch_points position_precision =
    (
        local inside_patch = false
        if patch_points.count >= 3 then
        (
            local patch_normal = getPatchNormal patch_points
            if patch_normal != undefined then
            (
                inside_patch = (abs (dot (point_value - patch_points[1]) patch_normal)) <= position_precision
                for edge_index = 1 to patch_points.count while inside_patch do
                (
                    local next_index = if edge_index == patch_points.count then 1 else edge_index + 1
                    local edge_vector = patch_points[next_index] - patch_points[edge_index]
                    local edge_length = length edge_vector
                    if edge_length > 0.0 then
                    (
                        local oriented_area = dot (cross edge_vector (point_value - patch_points[edge_index])) patch_normal
                        if oriented_area < (-position_precision * edge_length) then inside_patch = false
                    )
                )
            )
        )
        inside_patch
        -- return
    ),

    /* Returns a world-space axis-aligned bounding box of a finite polygon. */
    function getPatchBounds patch_points =
    (
        local min_point = copy patch_points[1]
        local max_point = copy patch_points[1]
        for point_value in patch_points do
        (
            min_point.x = amin min_point.x point_value.x
            min_point.y = amin min_point.y point_value.y
            min_point.z = amin min_point.z point_value.z
            max_point.x = amax max_point.x point_value.x
            max_point.y = amax max_point.y point_value.y
            max_point.z = amax max_point.z point_value.z
        )
        #(min_point, max_point)
        -- return
    ),

    /*
    Joins two coplanar triangles across their SHARED INVISIBLE edge to
    reconstruct a convex source quad. Keeps each remaining edge's visibility.
    Unpaired triangles are retained with their exact per-edge flags.
    */
    function buildVisibleSourcePatches triangle_set position_precision =
    (
        /* Dissolve ALL coplanar, mutually invisible shared diagonals before any
           cutting. Vertex IDs, not coincident positions, establish adjacency.
           Concave unions are not merged: they remain explicit source boundaries. */
        local patch_points = for cached_triangle in triangle_set collect (copy cached_triangle[1] #noMap)
        local patch_flags = for cached_triangle in triangle_set collect (copy cached_triangle[4] #noMap)
        local patch_ids = for cached_triangle in triangle_set collect (copy cached_triangle[5] #noMap)
        local merging = true
        while merging do
        (
            merging = false
            local first_index = 1
            while first_index < patch_points.count and not merging do
            (
                local first_points = patch_points[first_index]
                local first_normal = getPatchNormal first_points
                local second_index = first_index + 1
                while second_index <= patch_points.count and not merging do
                (
                    local second_points = patch_points[second_index]
                    local second_normal = getPatchNormal second_points
                    if first_normal != undefined and second_normal != undefined and (dot first_normal second_normal) > 0.0 then
                    (
                        local edge_index = 1
                        while edge_index <= first_points.count and not merging do
                        (
                            if not patch_flags[first_index][edge_index] then
                            (
                                local next_index = if edge_index == first_points.count then 1 else edge_index + 1
                                local second_edge = 1
                                while second_edge <= second_points.count and not merging do
                                (
                                    local other_next = if second_edge == second_points.count then 1 else second_edge + 1
                                    if not patch_flags[second_index][second_edge] and \
                                       patch_ids[first_index][edge_index] == patch_ids[second_index][other_next] and \
                                       patch_ids[first_index][next_index] == patch_ids[second_index][second_edge] then
                                    (
                                        local merged_points = #()
                                        local merged_flags = #()
                                        local merged_ids = #()
                                        local walk_index = next_index
                                        for walk_count = 1 to first_points.count do
                                        (
                                            append merged_points first_points[walk_index]
                                            append merged_ids patch_ids[first_index][walk_index]
                                            append merged_flags (if walk_index == edge_index then patch_flags[second_index][other_next] else patch_flags[first_index][walk_index])
                                            walk_index = if walk_index == first_points.count then 1 else walk_index + 1
                                        )
                                        walk_index = if other_next == second_points.count then 1 else other_next + 1
                                        for walk_count = 1 to (second_points.count - 2) do
                                        (
                                            append merged_points second_points[walk_index]
                                            append merged_ids patch_ids[second_index][walk_index]
                                            append merged_flags patch_flags[second_index][walk_index]
                                            walk_index = if walk_index == second_points.count then 1 else walk_index + 1
                                        )
                                        local valid_union = true
                                        local unique_ids = #()
                                        for vertex_id in merged_ids do appendIfUnique unique_ids vertex_id
                                        if unique_ids.count != merged_ids.count then valid_union = false
                                        for corner_index = 1 to merged_points.count while valid_union do
                                        (
                                            local next_corner = if corner_index == merged_points.count then 1 else corner_index + 1
                                            local after_corner = if next_corner == merged_points.count then 1 else next_corner + 1
                                            /* Identity precision must not flatten the evaluated source surface. */
                                            if (abs (dot first_normal (merged_points[corner_index] - merged_points[1]))) > 0.0 then valid_union = false
                                            if (dot (cross (merged_points[next_corner] - merged_points[corner_index]) (merged_points[after_corner] - merged_points[next_corner])) first_normal) < (-position_precision * position_precision) then valid_union = false
                                        )
                                        if valid_union then
                                        (
                                            patch_points[first_index] = merged_points
                                            patch_flags[first_index] = merged_flags
                                            patch_ids[first_index] = merged_ids
                                            deleteItem patch_points second_index
                                            deleteItem patch_flags second_index
                                            deleteItem patch_ids second_index
                                            merging = true
                                        )
                                    )
                                    second_edge += 1
                                )
                            )
                            edge_index += 1
                        )
                    )
                    second_index += 1
                )
                first_index += 1
            )
        )
        local valid_indices = #()
        for patch_index = 1 to patch_points.count do
        (
            local distinct_points = #()
            for point_value in patch_points[patch_index] do appendUniquePoint distinct_points point_value position_precision
            if distinct_points.count >= 3 and (getPatchNormal patch_points[patch_index]) != undefined then append valid_indices patch_index
        )
        if valid_indices.count != patch_points.count then format "SI SOURCE DEGENERATE | omitted reconstructed patches:% precision:%\n" (patch_points.count - valid_indices.count) position_precision
        #((for patch_index in valid_indices collect patch_points[patch_index]), (for patch_index in valid_indices collect patch_flags[patch_index]))
        -- return
    ),

    /*
    Finds crossings using ONLY visible polygon edges. Mathematical polygon
    interiors remain available for containment. No hidden triangulation edge
    is emitted as an intersection boundary or endpoint.
    */
    function intersectVisiblePatches patch_a patch_b position_precision visibility_a:undefined visibility_b:undefined =
    (
        local crossing_segment = undefined
        local normal_a = getPatchNormal patch_a
        local normal_b = getPatchNormal patch_b
        if normal_a != undefined and normal_b != undefined and (length (cross normal_a normal_b)) > 0.0 then
        (
            local patch_sets = #(patch_a, patch_b)
            local other_normals = #(normal_b, normal_a)
            local edge_flags = #(visibility_a, visibility_b)
            local hits = #()
            for source_index = 1 to 2 do
            (
                local source_patch = patch_sets[source_index]
                local target_patch = patch_sets[3 - source_index]
                local target_normal = other_normals[source_index]
                local target_origin = target_patch[1]
                local flags = edge_flags[source_index]
                for edge_index = 1 to source_patch.count do
                (
                    if flags == undefined or flags[edge_index] then
                    (
                        local next_index = if edge_index == source_patch.count then 1 else edge_index + 1
                        local point_start = source_patch[edge_index]
                        local point_end = source_patch[next_index]
                        local dist_start = dot target_normal (point_start - target_origin)
                        local dist_end = dot target_normal (point_end - target_origin)
                        if abs dist_start <= position_precision and (pointInConvexPatch point_start target_patch position_precision) then
                        (
                            appendUniquePoint hits point_start position_precision
                        )
                        if abs dist_end <= position_precision and (pointInConvexPatch point_end target_patch position_precision) then
                        (
                            appendUniquePoint hits point_end position_precision
                        )
                        if (dist_start > position_precision and dist_end < -position_precision) or \
                            (dist_start < -position_precision and dist_end > position_precision) then
                        (
                            local fraction = dist_start / (dist_start - dist_end)
                            local crossing = point_start + (point_end - point_start) * fraction
                            if pointInConvexPatch crossing target_patch position_precision then appendUniquePoint hits crossing position_precision
                        )
                    )
                )
            )
            local farthest_squared = 0.0
            if hits.count >= 2 then for point_index = 1 to (hits.count - 1) do
            (
                for next_index = (point_index + 1) to hits.count do
                (
                    local difference = hits[point_index] - hits[next_index]
                    local distance_squared = dot difference difference
                    if distance_squared > farthest_squared then
                    (
                        farthest_squared = distance_squared
                        crossing_segment = #(hits[point_index], hits[next_index])
                    )
                )
            )
        )
        crossing_segment
        -- return
    ),

    /* Finite polygon-to-polygon intersections; never consults hidden triangulation diagonals. */
    function collectVisiblePatchSegments patches_a patches_b position_precision vis_a:undefined vis_b:undefined =
    (
        local segments = #()
        for first_index = 1 to patches_a.count do
        (
            local first_patch = patches_a[first_index]
            local first_bounds = getPatchBounds first_patch
            local first_flags = if vis_a != undefined then vis_a[first_index] else undefined
            for second_index = 1 to patches_b.count do
            (
                local second_patch = patches_b[second_index]
                local second_flags = if vis_b != undefined then vis_b[second_index] else undefined
                local second_bounds = getPatchBounds second_patch
                local overlaps = (first_bounds[1].x <= second_bounds[2].x + position_precision) and \
                    (second_bounds[1].x <= first_bounds[2].x + position_precision) and \
                    (first_bounds[1].y <= second_bounds[2].y + position_precision) and \
                    (second_bounds[1].y <= first_bounds[2].y + position_precision) and \
                    (first_bounds[1].z <= second_bounds[2].z + position_precision) and \
                    (second_bounds[1].z <= first_bounds[2].z + position_precision)
                if overlaps then
                (
                    local crossing_segment = intersectVisiblePatches first_patch second_patch position_precision visibility_a:first_flags visibility_b:second_flags
                    if crossing_segment != undefined then appendUniqueSegment segments crossing_segment position_precision
                )
            )
        )
        segments
        -- return
    ),

    /* World-space area of a single convex working patch. No source is modified. */
    function getWorkingPatchArea patch_points =
    (
        local area_vector = [0.0,0.0,0.0]
        if patch_points.count >= 3 then
        (
            for corner_index = 2 to (patch_points.count - 1) do
            (
                area_vector += cross (patch_points[corner_index] - patch_points[1]) (patch_points[corner_index + 1] - patch_points[1])
            )
        )
        (length area_vector) * 0.5
        -- return
    ),

    /* Compare COMPLETE surface-patch areas, not a triangle's local area. */
    function getWorkingPatchSetArea patch_values =
    (
        local total_area = 0.0
        for patch_points in patch_values do total_area += getWorkingPatchArea patch_points
        total_area
        -- return
    ),

    /*
    If all cutter polygons are coplanar and consistently wound, use their
    common infinite supporting plane to divide the target's entire surface.
    An actual finite intersection is still required before any cut is made.
    */
    function getPlanarWorkingCutter cutter_patches position_precision =
    (
        local cutter_plane = undefined
        local shared_origin = undefined
        local shared_normal = undefined
        local is_planar = cutter_patches.count > 0
        for cutter_points in cutter_patches while is_planar do
        (
            local face_normal = getPatchNormal cutter_points
            if face_normal == undefined then
            (
                is_planar = false
            )
            else
            (
                if shared_normal == undefined then
                (
                    shared_origin = cutter_points[1]
                    shared_normal = face_normal
                )
                else if (dot face_normal shared_normal) <= 0.0 then is_planar = false
                for point_value in cutter_points while is_planar do
                (
                    if (abs (dot shared_normal (point_value - shared_origin))) > position_precision then is_planar = false
                )
            )
        )
        if is_planar and shared_normal != undefined then cutter_plane = #(shared_origin, shared_normal)
        cutter_plane
        -- return
    ),

    /* Cut a whole patch set on one side of a supporting plane. */
    function clipPatchSetByPlane target_patches cutter_plane kept_mode position_precision =
    (
        local retained_patches = #()
        for patch_points in target_patches do
        (
            local split_values = splitWorkingPatch patch_points cutter_plane[1] cutter_plane[2] position_precision
            local kept_points = if kept_mode == #negative then split_values[2] else split_values[1]
            kept_points = cleanWorkingPatch kept_points position_precision
            if kept_points.count >= 3 then append retained_patches kept_points
        )
        retained_patches
        -- return
    ),

    /*
    Make newly created planar cut edges visible in each result mesh. Source
    triangulation edges remain hidden unless they were originally visible.
    Record ONLY if a target polygon actually straddles the cutter plane.
    */
    function recordPlanarTrimEdges target_patches retained_patches cutter_plane position_precision =
    (
        local crossed_plane = false
        for source_patch in target_patches while not crossed_plane do
        (
            local has_positive = false
            local has_negative = false
            for point_value in source_patch do
            (
                local distance_value = dot (point_value - cutter_plane[1]) cutter_plane[2]
                if distance_value > position_precision then has_positive = true
                if distance_value < -position_precision then has_negative = true
            )
            crossed_plane = has_positive and has_negative
        )
        if crossed_plane then
        (
            for retained_patch in retained_patches do
            (
                for edge_index = 1 to retained_patch.count do
                (
                    local next_index = if edge_index == retained_patch.count then 1 else edge_index + 1
                    local edge_start = retained_patch[edge_index]
                    local edge_end = retained_patch[next_index]
                    if (abs (dot (edge_start - cutter_plane[1]) cutter_plane[2])) <= position_precision and \
                       (abs (dot (edge_end - cutter_plane[1]) cutter_plane[2])) <= position_precision then
                    (
                        appendUniqueSegment trim_boundary_segments #(edge_start, edge_end) position_precision
                    )
                )
            )
        )
        crossed_plane
        -- return
    ),

    /* Original finite-footprint clipping for nonplanar cutter patch sets. */
    function clipPatchSetByFiniteCutters target_patches cutter_patches kept_mode reference_center position_precision =
    (
        local remaining_patches = for patch_points in target_patches collect (copy patch_points #noMap)
        for cutter_points in cutter_patches while remaining_patches.count > 0 do
        (
            local next_patches = #()
            for target_points in remaining_patches do
            (
                join next_patches (trimPatchWithCutter target_points cutter_points kept_mode reference_center position_precision)
            )
            remaining_patches = next_patches
        )
        remaining_patches
        -- return
    ),

    /* Whether a point belongs to the finite edge of one polygon (world space). */
    function pointOnPatchBoundary query_point patch_points position_precision =
    (
        local found = false
        for edge_index = 1 to patch_points.count while not found do
        (
            local next_index = if edge_index == patch_points.count then 1 else edge_index + 1
            local edge_start = patch_points[edge_index]
            local edge_vector = patch_points[next_index] - edge_start
            local squared_length = dot edge_vector edge_vector
            if squared_length > 0.0 then
            (
                local parameter = (dot (query_point - edge_start) edge_vector) / squared_length
                local projection = edge_start + edge_vector * (amax 0.0 (amin 1.0 parameter))
                found = parameter >= 0.0 and parameter <= 1.0 and (length (query_point - projection)) <= position_precision
            )
        )
        found
        -- return
    ),

    /* Insert ACTUAL finite curve endpoints on a split seam. Do not use
       triangulation diagonals or introduce a vertex at their crossings. */
    function insertActualCutKnots piece_points finite_segments cutting_plane position_precision =
    (
        local enriched = #()
        for edge_index = 1 to piece_points.count do
        (
            local next_index = if edge_index == piece_points.count then 1 else edge_index + 1
            local edge_start = piece_points[edge_index]
            local edge_end = piece_points[next_index]
            append enriched edge_start
            if (abs (dot (edge_start - cutting_plane[1]) cutting_plane[2])) <= position_precision and \
               (abs (dot (edge_end - cutting_plane[1]) cutting_plane[2])) <= position_precision then
            (
                local edge_vector = edge_end - edge_start
                local squared_length = dot edge_vector edge_vector
                if squared_length > 0.0 then
                (
                    local knot_entries = #()
                    for finite_segment in finite_segments do
                    (
                        for actual_point in finite_segment do
                        (
                            local fraction = (dot (actual_point - edge_start) edge_vector) / squared_length
                            local projection = edge_start + edge_vector * fraction
                            if fraction > 0.0 and fraction < 1.0 and (length (projection - actual_point)) <= position_precision and \
                               not (isSamePoint actual_point edge_start position_precision) and not (isSamePoint actual_point edge_end position_precision) then
                            (
                                local duplicate_knot = false
                                for knot_data in knot_entries where (abs (knot_data[1] - fraction)) <= (position_precision / (sqrt squared_length)) do duplicate_knot = true
                                if not duplicate_knot then append knot_entries #(fraction, actual_point)
                            )
                        )
                    )
                    if knot_entries.count > 1 then
                    (
                        for i = 1 to (knot_entries.count - 1) do
                        (
                            for j = (i + 1) to knot_entries.count do
                            (
                                if knot_entries[j][1] < knot_entries[i][1] then
                                (
                                    local swap_entry = knot_entries[i]
                                    knot_entries[i] = knot_entries[j]
                                    knot_entries[j] = swap_entry
                                )
                            )
                        )
                    )
                    for knot_data in knot_entries do append enriched knot_data[2]
                )
            )
        )
        cleanWorkingPatch enriched position_precision
        -- return
    ),

    /* A finite intersection partitions a face only if it covers the entire
       chord between the face's two visible boundary intersections. */
    function finiteSegmentsCoverChord finite_segments chord_points position_precision =
    (
        local covered = false
        if chord_points.count == 2 then
        (
            local chord_vector = chord_points[2] - chord_points[1]
            local length_squared = dot chord_vector chord_vector
            if length_squared > 0.0 then
            (
                local margin = position_precision / (sqrt length_squared)
                local coverage = 0.0
                local expanding = true
                while expanding and coverage < (1.0 - margin) do
                (
                    expanding = false
                    for finite_segment in finite_segments do
                    (
                        local first_fraction = (dot (finite_segment[1] - chord_points[1]) chord_vector) / length_squared
                        local second_fraction = (dot (finite_segment[2] - chord_points[1]) chord_vector) / length_squared
                        local start_fraction = amax 0.0 (amin first_fraction second_fraction)
                        local end_fraction = amin 1.0 (amax first_fraction second_fraction)
                        if start_fraction <= (coverage + margin) and end_fraction > (coverage + margin) then
                        (
                            coverage = end_fraction
                            expanding = true
                        )
                    )
                )
                covered = coverage >= (1.0 - margin)
            )
        )
        covered
        -- return
    ),

    /* Determine the two boundary endpoints of the FULL chord of a finite
       curve's line through a convex polygon. No hidden source edge is read. */
    function getPatchChord patch_points cutting_plane position_precision =
    (
        local chord_points = #()
        local positive_seen = false
        local negative_seen = false
        for edge_index = 1 to patch_points.count do
        (
            local next_index = if edge_index == patch_points.count then 1 else edge_index + 1
            local edge_start = patch_points[edge_index]
            local edge_end = patch_points[next_index]
            local distance_start = dot (edge_start - cutting_plane[1]) cutting_plane[2]
            local distance_end = dot (edge_end - cutting_plane[1]) cutting_plane[2]
            if distance_start > position_precision then positive_seen = true
            if distance_start < -position_precision then negative_seen = true
            if (abs distance_start) <= position_precision then appendUniquePoint chord_points edge_start position_precision
            if (distance_start > position_precision and distance_end < -position_precision) or \
               (distance_start < -position_precision and distance_end > position_precision) then
            (
                local fraction = distance_start / (distance_start - distance_end)
                appendUniquePoint chord_points (edge_start + (edge_end - edge_start) * fraction) position_precision
            )
        )
        if not positive_seen or not negative_seen then chord_points = #()
        if chord_points.count > 2 then
        (
            local best_pair = #()
            local best_distance = 0.0
            for first_index = 1 to (chord_points.count - 1) do
            (
                for second_index = (first_index + 1) to chord_points.count do
                (
                    local separation = chord_points[second_index] - chord_points[first_index]
                    local squared_distance = dot separation separation
                    if squared_distance > best_distance then
                    (
                        best_distance = squared_distance
                        best_pair = #(chord_points[first_index], chord_points[second_index])
                    )
                )
            )
            chord_points = best_pair
        )
        chord_points
        -- return
    ),

    /*
    Finds a shared boundary interval that is not blocked by an actual finite cut.
    Supporting-line extensions remain traversable, including partial edge overlap.
    */
    function patchesShareUncutEdge patch_a patch_b cut_segments position_precision =
    (
        local connected = false
        local bounds_a = getPatchBounds patch_a
        local bounds_b = getPatchBounds patch_b
        local overlaps = bounds_a[1].x <= bounds_b[2].x + position_precision and bounds_b[1].x <= bounds_a[2].x + position_precision and \
            bounds_a[1].y <= bounds_b[2].y + position_precision and bounds_b[1].y <= bounds_a[2].y + position_precision and \
            bounds_a[1].z <= bounds_b[2].z + position_precision and bounds_b[1].z <= bounds_a[2].z + position_precision
        if overlaps then
        (
            for edge_a = 1 to patch_a.count while not connected do
            (
                local next_a = if edge_a == patch_a.count then 1 else edge_a + 1
                local edge_start = patch_a[edge_a]
                local edge_vector = patch_a[next_a] - edge_start
                local edge_length = length edge_vector
                if edge_length > position_precision then
                (
                    local direction = edge_vector / edge_length
                    for edge_b = 1 to patch_b.count while not connected do
                    (
                        local next_b = if edge_b == patch_b.count then 1 else edge_b + 1
                        local other_start = patch_b[edge_b] - edge_start
                        local other_end = patch_b[next_b] - edge_start
                        if (length (cross direction other_start)) <= position_precision and (length (cross direction other_end)) <= position_precision then
                        (
                            local first_distance = dot other_start direction
                            local second_distance = dot other_end direction
                            local interval_start = amax 0.0 (amin first_distance second_distance)
                            local interval_end = amin edge_length (amax first_distance second_distance)
                            if interval_end - interval_start > position_precision then
                            (
                                local barriers = #()
                                for cut_segment in cut_segments do
                                (
                                    if (length (cross direction (cut_segment[1] - edge_start))) <= position_precision and \
                                       (length (cross direction (cut_segment[2] - edge_start))) <= position_precision then append barriers cut_segment
                                )
                                local shared_chord = #(edge_start + direction * interval_start, edge_start + direction * interval_end)
                                connected = not (finiteSegmentsCoverChord barriers shared_chord position_precision)
                            )
                        )
                    )
                )
            )
        )
        connected
        -- return
    ),

    /*
    Labels connected surface regions across uncut boundary intervals.
    A finite curve is a barrier; its invisible supporting extension is not.
    */
    function labelCutRegions patch_values cut_segments position_precision =
    (
        for patch_index = 1 to patch_values.count do
        (
            if patch_values[patch_index].count < 3 then
            (
                format "SI REGION INPUT FAILED | patch:% corners:% expected:3 or more\n" patch_index patch_values[patch_index].count
                throw ("SI REGION INPUT FAILED | patch:" + (patch_index as string) + " corners:" + (patch_values[patch_index].count as string))
            )
        )
        local region_labels = for patch_index = 1 to patch_values.count collect patch_index
        for first_index = 1 to (patch_values.count - 1) do
        (
            for second_index = (first_index + 1) to patch_values.count do
            (
                local first_root = first_index
                local second_root = second_index
                while region_labels[first_root] != first_root do first_root = region_labels[first_root]
                while region_labels[second_root] != second_root do second_root = region_labels[second_root]
                if first_root != second_root and (patchesShareUncutEdge patch_values[first_index] patch_values[second_index] cut_segments position_precision) then
                (
                    region_labels[second_root] = first_root
                )
            )
        )
        for patch_index = 1 to region_labels.count do
        (
            local region_root = patch_index
            while region_labels[region_root] != region_root do region_root = region_labels[region_root]
            region_labels[patch_index] = region_root
        )
        region_labels
        -- return
    ),

    /*
    True if the complete requested result edge is a subsegment of a REAL visible
    original source edge or a genuine computed source-intersection segment.
    This is geometric edge identity, not source triangle-index identity.
    */
    function segmentWithinReference edge_start edge_end reference_segment position_precision =
    (
        local line_start = reference_segment[1]
        local line_vector = reference_segment[2] - line_start
        local line_length_squared = dot line_vector line_vector
        local contained = false
        if line_length_squared > 0.0 then
        (
            local line_length = sqrt line_length_squared
            local allowed_fraction = position_precision / line_length
            local valid_start = true
            local valid_end = true
            for test_point_index = 1 to 2 do
            (
                local test_point = if test_point_index == 1 then edge_start else edge_end
                local fraction = (dot (test_point - line_start) line_vector) / line_length_squared
                local projection = line_start + line_vector * fraction
                local lies_on_line = (length (test_point - projection)) <= position_precision
                local lies_on_segment = fraction >= -allowed_fraction and fraction <= (1.0 + allowed_fraction)
                if test_point_index == 1 then valid_start = lies_on_line and lies_on_segment
                else valid_end = lies_on_line and lies_on_segment
            )
            contained = valid_start and valid_end
        )
        contained
        -- return
    ),

    /*
    Follows the terminal edge's section plane through its connected surface component.
    Returns finite face segments ending at a border; ambiguous continuations fail.
    */
    function traceCutEndpoint target_patches endpoint neighbor position_precision =
    (
        local direction = endpoint - neighbor
        local terminal_normal = undefined
        local terminal_patch_index = 0
        for patch_index = 1 to target_patches.count while terminal_normal == undefined do
        (
            local patch_points = target_patches[patch_index]
            local patch_normal = getPatchNormal patch_points
            if patch_normal != undefined and (abs (dot (endpoint - patch_points[1]) patch_normal)) <= position_precision and (abs (dot (neighbor - patch_points[1]) patch_normal)) <= position_precision then
            (
                if (pointInConvexPatch endpoint patch_points position_precision) and (pointInConvexPatch neighbor patch_points position_precision) then
                (
                    terminal_normal = patch_normal
                    terminal_patch_index = patch_index
                )
            )
        )
        local extension = #()
        if terminal_normal == undefined then
        (
            format "SI EXTENSION FAILED | No incident polygon | endpoint:% neighbor:% precision:%\n" endpoint neighbor position_precision
            throw "SI EXTENSION FAILED | Cannot resolve terminal polygon."
        )
        local plane_normal = cross terminal_normal direction
        if (length plane_normal) == 0.0 then
        (
            format "SI EXTENSION FAILED | Zero terminal direction | endpoint:% neighbor:%\n" endpoint neighbor
            throw "SI EXTENSION FAILED | Invalid terminal direction."
        )
        local cutting_plane = #(endpoint, normalize plane_normal)
        local section_segments = #()
        local component_labels = labelCutRegions target_patches #() position_precision
        for patch_index = 1 to target_patches.count where component_labels[patch_index] == component_labels[terminal_patch_index] do
        (
            local patch_points = target_patches[patch_index]
            local chord_points = getPatchChord patch_points cutting_plane position_precision
            if chord_points.count == 2 then appendUniqueSegment section_segments chord_points position_precision
            else
            (
                /* A continuation may coincide with an existing polygon edge. */
                for edge_index = 1 to patch_points.count do
                (
                    local next_index = if edge_index == patch_points.count then 1 else edge_index + 1
                    local edge_start = patch_points[edge_index]
                    local edge_end = patch_points[next_index]
                    if (abs (dot (edge_start - endpoint) cutting_plane[2])) <= position_precision and (abs (dot (edge_end - endpoint) cutting_plane[2])) <= position_precision then
                    (
                        appendUniqueSegment section_segments #(edge_start, edge_end) position_precision
                    )
                )
            )
        )
        local cursor_point = endpoint
        local visited_points = #(endpoint)
        local used_sections = #{}
        used_sections.count = section_segments.count
        local walking = true
        while walking do
        (
            local candidates = #()
            local candidate_sections = #()
            for section_index = 1 to section_segments.count where not used_sections[section_index] do
            (
                local section_segment = section_segments[section_index]
                if segmentWithinReference cursor_point cursor_point section_segment position_precision then
                (
                    for section_point in section_segment do
                    (
                        /* A rounding-cell boundary can distinguish a tiny stub.
                           Follow only spans usable at the selected cut precision. */
                        local is_candidate = not (isSamePoint cursor_point section_point position_precision) and (length (section_point - cursor_point)) > position_precision
                        if extension.count == 0 then is_candidate = is_candidate and (dot (section_point - cursor_point) direction) > 0.0
                        if is_candidate then
                        (
                            if (appendUniquePoint candidates section_point position_precision) then append candidate_sections section_index
                        )
                    )
                )
            )
            if candidates.count == 0 then
            (
                local on_boundary = false
                for patch_points in target_patches while not on_boundary do on_boundary = pointOnPatchBoundary cursor_point patch_points position_precision
                if not on_boundary then
                (
                    format "SI EXTENSION FAILED | Stopped inside polygon | point:% start:%\n" cursor_point endpoint
                    throw "SI EXTENSION FAILED | Continuation did not reach a border."
                )
                walking = false
            )
            else if candidates.count != 1 then
            (
                format "SI EXTENSION FAILED | Ambiguous section | point:% candidates:%\n" cursor_point candidates
                throw "SI EXTENSION FAILED | Branching continuation."
            )
            else
            (
                local next_point = candidates[1]
                local repeated = false
                for visited_point in visited_points while not repeated do repeated = isSamePoint visited_point next_point position_precision
                if repeated then
                (
                    format "SI EXTENSION FAILED | Closed continuation | point:% start:%\n" next_point endpoint
                    throw "SI EXTENSION FAILED | No border along continuation."
                )
                used_sections[candidate_sections[1]] = true
                append extension #(cursor_point, next_point)
                append visited_points next_point
                cursor_point = next_point
            )
        )
        extension
        -- return
    ),

    /*
    Completes each degree-one cut endpoint on this target surface independently.
    Closed curves, junctions and disconnected surface islands are not extended.
    */
    function extendCutSegmentsToBorder target_patches actual_segments position_precision =
    (
        /* Match the cutter's existing minimum usable segment length before
           resolving degrees and directions; tiny stubs cannot steer extensions. */
        local usable_segments = for segment_value in actual_segments where (length (segment_value[2] - segment_value[1])) > position_precision collect segment_value
        local completed_segments = copy usable_segments #noMap
        for actual_segment in usable_segments do
        (
            for endpoint_index = 1 to 2 do
            (
                local endpoint = actual_segment[endpoint_index]
                local neighbor = actual_segment[3 - endpoint_index]
                if (getEndpointDegree usable_segments endpoint position_precision) == 1 then
                (
                    local extension = traceCutEndpoint target_patches endpoint neighbor position_precision
                    for extension_segment in extension do
                    (
                        appendUniqueSegment completed_segments extension_segment position_precision
                        appendUniqueSegment extended_cut_segments extension_segment position_precision
                    )
                    if extension.count > 0 then format "SI CUT EXTENDED | from:% to:% face segments:%\n" endpoint extension[extension.count][2] extension.count
                )
            )
        )
        completed_segments
        -- return
    ),

    /*
    Cuts polygons along the real intersection plus connected border extensions.
    The completed finite barrier permits larger-region retention at unequal widths.
    */
    function cutPatchSetByActualCurves target_patches cutter_patches kept_mode position_precision =
    (
        local cut_cells = #()
        local cell_origins = #()
        local actual_cuts = #()
        local cut_count = 0
        local split_count = 0
        local finite_cuts = collectVisiblePatchSegments target_patches cutter_patches position_precision
        local completed_cuts = extendCutSegmentsToBorder target_patches finite_cuts position_precision
        /* Two usable spans can meet at the same rounded endpoint while
           crossing a tiny corner of an otherwise uncut construction patch. */
        local short_bridges = #()
        if delete_trimmed and kept_mode != #off then
        (
            for first_index = 1 to (completed_cuts.count - 1) do
            (
                for second_index = first_index + 1 to completed_cuts.count do
                (
                    for first_point in completed_cuts[first_index] do
                    (
                        for second_point in completed_cuts[second_index] do
                        (
                            if (isSamePoint first_point second_point position_precision) then
                            (
                                local span_length = length (second_point - first_point)
                                if span_length > 0.0 and span_length <= position_precision then append short_bridges #(first_point,second_point)
                            )
                        )
                    )
                )
            )
        )
        for patch_index = 1 to target_patches.count do
        (
            local target_patch = target_patches[patch_index]
            local patch_normal = getPatchNormal target_patch
            local patch_segments = #()
            if patch_normal != undefined then
            (
                patch_segments = for cut_segment in completed_cuts where (abs (dot (cut_segment[1] - target_patch[1]) patch_normal)) <= position_precision and (abs (dot (cut_segment[2] - target_patch[1]) patch_normal)) <= position_precision and (pointInConvexPatch cut_segment[1] target_patch position_precision) and (pointInConvexPatch cut_segment[2] target_patch position_precision) collect cut_segment
            )
            local actual_points = #()
            for actual_segment in patch_segments do for actual_point in actual_segment do appendUniquePoint actual_points actual_point position_precision
            local cut_planes = #()
            local pieces = #(target_patch)
            if patch_segments.count == 0 and patch_normal != undefined then
            (
                local bridge_applied = false
                for bridge_segment in short_bridges while not bridge_applied do
                (
                    local bridge_start = bridge_segment[1]
                    local bridge_end = bridge_segment[2]
                    if (pointInConvexPatch bridge_start target_patch position_precision) and (pointInConvexPatch bridge_end target_patch position_precision) and \
                       (pointOnPatchBoundary bridge_start target_patch position_precision) and (pointOnPatchBoundary bridge_end target_patch position_precision) then
                    (
                        local bridge_normal = cross patch_normal (bridge_end - bridge_start)
                        if (length bridge_normal) > 0.0 then
                        (
                            /* Resolve the real crossing before normal precision
                               cleanup so the collapsed corner cannot join both regions. */
                            local raw_sides = splitWorkingPatch target_patch bridge_start (normalize bridge_normal) position_precision exact_sides:true
                            if raw_sides[1].count >= 3 and raw_sides[2].count >= 3 then
                            (
                                local first_side = cleanWorkingPatch raw_sides[1] position_precision
                                local second_side = cleanWorkingPatch raw_sides[2] position_precision
                                if (first_side.count >= 3) != (second_side.count >= 3) then
                                (
                                    pieces = #(if first_side.count >= 3 then first_side else second_side)
                                    collapsed_cell_count += 1
                                    bridge_applied = true
                                    format "SI SHORT BRIDGE | patch:% from:% to:% precision:%\n" patch_index bridge_start bridge_end position_precision
                                )
                            )
                        )
                    )
                )
            )
            for actual_segment in patch_segments do
            (
                local line_vector = actual_segment[2] - actual_segment[1]
                if patch_normal != undefined and (length line_vector) > position_precision then
                (
                    local cutting_normal = normalize (cross patch_normal line_vector)
                    local cutting_plane = #(actual_segment[1], cutting_normal)
                    append cut_planes cutting_plane
                    appendUniqueSegment actual_cuts actual_segment position_precision
                    appendUniqueSegment trim_boundary_segments actual_segment position_precision
                    local next_pieces = #()
                    for piece_points in pieces do
                    (
                        local chord_points = getPatchChord piece_points cutting_plane position_precision
                        if chord_points.count == 2 then
                        (
                            local split_faces = splitWorkingPatch piece_points cutting_plane[1] cutting_plane[2] position_precision crossing_points:actual_points
                            local positive_patch = cleanWorkingPatch split_faces[1] position_precision
                            local negative_patch = cleanWorkingPatch split_faces[2] position_precision
                            if positive_patch.count >= 3 and negative_patch.count >= 3 then
                            (
                                append next_pieces positive_patch
                                append next_pieces negative_patch
                                split_count += 1
                            )
                            else if positive_patch.count >= 3 or negative_patch.count >= 3 then
                            (
                                /* The normal cleanup contract permits one side to
                                   collapse at the selected position precision. */
                                append next_pieces (if positive_patch.count >= 3 then positive_patch else negative_patch)
                                collapsed_cell_count += 1
                                format "SI CUT COLLAPSED SIDE | patch:% positive corners:% negative corners:% precision:%\n" patch_index positive_patch.count negative_patch.count position_precision
                            )
                            else
                            (
                                cut_error_count += 1
                                format "SI CUT INVALID | patch:% positive corners:% negative corners:%\n" patch_index positive_patch.count negative_patch.count
                                append next_pieces piece_points
                            )
                        )
                        else append next_pieces piece_points
                    )
                    pieces = next_pieces
                    cut_count += 1
                )
            )
            for piece_points in pieces do
            (
                local enriched = piece_points
                for cutting_plane in cut_planes while enriched.count >= 3 do enriched = insertActualCutKnots enriched patch_segments cutting_plane position_precision
                if enriched.count >= 3 then
                (
                    append cut_cells enriched
                    append cell_origins patch_index
                )
                else if enriched.count == 0 then
                (
                    collapsed_cell_count += 1
                    format "SI CUT EMPTY CELL | source patch:% original corners:% cleaned corners:0 precision:% | omitted from region graph\n" patch_index piece_points.count position_precision
                )
                else
                (
                    format "SI CUT INVALID CELL | source patch:% corners:% expected:0 or 3 or more\n" patch_index enriched.count
                    throw "SI CUT INVALID CELL | Knot insertion returned an invalid polygon."
                )
            )
        )

        local original_area = getWorkingPatchSetArea target_patches
        local cell_area = getWorkingPatchSetArea cut_cells
        local boundary_length = 0.0
        for target_patch in target_patches do
        (
            for edge_index = 1 to target_patch.count do
            (
                local next_index = if edge_index == target_patch.count then 1 else edge_index + 1
                boundary_length += length (target_patch[next_index] - target_patch[edge_index])
            )
        )
        local area_precision = position_precision * boundary_length * 4.0
        if (abs (cell_area - original_area)) > area_precision then
        (
            cut_error_count += 1
            format "SI CUT AREA FAILED | original:% cells:% difference:% precision allowance:%\n" original_area cell_area (cell_area - original_area) area_precision
        )
        local retained = cut_cells
        if delete_trimmed and kept_mode != #off and actual_cuts.count > 0 and cut_cells.count > 0 then
        (
            local original_labels = labelCutRegions target_patches #() position_precision
            local cut_labels = labelCutRegions cut_cells actual_cuts position_precision
            local region_areas = for cell_index = 1 to cut_cells.count collect 0.0
            local chosen_regions = for patch_index = 1 to target_patches.count collect 0
            local cutter_plane = getPlanarWorkingCutter cutter_patches position_precision
            for cell_index = 1 to cut_cells.count do region_areas[cut_labels[cell_index]] += getWorkingPatchArea cut_cells[cell_index]
            for cell_index = 1 to cut_cells.count do
            (
                local original_region = original_labels[cell_origins[cell_index]]
                local cut_region = cut_labels[cell_index]
                local chosen_region = chosen_regions[original_region]
                if chosen_region == 0 then chosen_regions[original_region] = cut_region
                else if region_areas[cut_region] > region_areas[chosen_region] then chosen_regions[original_region] = cut_region
            )
            retained = #()
            for cell_index = 1 to cut_cells.count do
            (
                local keep_cell = cut_labels[cell_index] == chosen_regions[original_labels[cell_origins[cell_index]]]
                if cutter_plane != undefined and (kept_mode == #positive or kept_mode == #negative) then
                (
                    local cell_center = [0.0,0.0,0.0]
                    for point_value in cut_cells[cell_index] do cell_center += point_value
                    cell_center /= cut_cells[cell_index].count
                    local signed_distance = dot (cell_center - cutter_plane[1]) cutter_plane[2]
                    keep_cell = if kept_mode == #negative then signed_distance <= 0.0 else signed_distance >= 0.0
                )
                if keep_cell then append retained cut_cells[cell_index]
            )
            format "SI REGION AREAS | % | retained area:% original area:%\n" (for cell_index = 1 to region_areas.count where region_areas[cell_index] > 0.0 collect region_areas[cell_index]) (getWorkingPatchSetArea retained) (getWorkingPatchSetArea target_patches)
        )
        format "SI CUT SUMMARY | finite segments:% polygon splits:% cells:% retained:% errors:%\n" cut_count split_count cut_cells.count retained.count cut_error_count
        retained
        -- return
    ),

    /* Compatibility entry point retained for external callers. */
    function clipPatchSetByCutters target_patches cutter_patches kept_mode reference_center position_precision =
    (
        cutPatchSetByActualCurves target_patches cutter_patches kept_mode position_precision
        -- return
    ),

    /*
    Each new source trims every prior surviving patch. Its own patches are
    trimmed by the same PRE-STAGE cumulative result, so neither reciprocal
    pass can accidentally change the other's cutter geometry.
    */
    function buildCumulativePatches original_sets clip_modes reference_center position_precision =
    (
        local surviving_sets = #()
        process_patch_sets = #()
        if original_sets.count > 0 then
        (
            append surviving_sets (for patch_points in original_sets[1] collect patch_points)
            for source_index = 2 to original_sets.count do
            (
                local prior_sets = surviving_sets
                local current_patches = original_sets[source_index]
                local current_mode = if clip_modes.count == original_sets.count then clip_modes[source_index] else #auto
                local updated_sets = #()

                /* Incoming surface trims the complete surviving previous result. */
                for prior_index = 1 to prior_sets.count do
                (
                    append updated_sets (clipPatchSetByCutters prior_sets[prior_index] current_patches current_mode reference_center position_precision)
                )

                /* Incoming surface is trimmed by the previous result, not the just-updated fragments. */
                local incoming_patches = for patch_points in current_patches collect patch_points
                for prior_index = 1 to prior_sets.count while incoming_patches.count > 0 do
                (
                    local prior_mode = if clip_modes.count == original_sets.count then clip_modes[prior_index] else #auto
                    incoming_patches = clipPatchSetByCutters incoming_patches prior_sets[prior_index] prior_mode reference_center position_precision
                )

                append updated_sets incoming_patches
                surviving_sets = updated_sets
                append process_patch_sets (for patch_set in surviving_sets collect (for patch_points in patch_set collect (copy patch_points #noMap)))
                format "SI CUMULATIVE TRIM | stage:% | retained patch counts:%\n" source_index (for patch_set in surviving_sets collect patch_set.count)
            )
        )
        surviving_sets
        -- return
    ),


    /*
    Removes evaluated hidden-diagonal knots from the published polygon cut.
    Real visible-edge crossings define each straight segment through a polygon.
    */
    function simplifyVisibleCutSegments segment_values position_precision =
    (
        local simplified_segments = #()
        local chains = buildCurveChains segment_values position_precision
        for chain_points in chains do
        (
            local visible_points = #()
            for point_value in chain_points do
            (
                local visible_hit = false
                for visible_segment in visible_edge_segments while not visible_hit do
                (
                    visible_hit = segmentWithinReference point_value point_value visible_segment position_precision
                )
                if visible_hit then append visible_points point_value
                else if (getEndpointDegree segment_values point_value position_precision) != 2 then
                (
                    append visible_points point_value
                    format "SI CUT LIMITATION | Non-visible-edge endpoint or branch:%\n" point_value
                )
            )
            for point_index = 1 to (visible_points.count - 1) do
            (
                appendUniqueSegment simplified_segments #(visible_points[point_index], visible_points[point_index + 1]) position_precision
            )
        )
        simplified_segments
        -- return
    ),

    /*
    Builds all intersection curves and per-source surviving patches from the
    final cumulative geometry; returns undefined if sources are invalid.
    */
    function buildSequentialResults source_values position_precision =
    (
        local results = undefined
        local valid_inputs = source_values.count >= 2
        for source_node in source_values while valid_inputs do
        (
            if not (isValidNode source_node and (superClassOf source_node == GeometryClass)) then valid_inputs = false
        )
        if not valid_inputs then
        (
            format "SURFACE INTERSECTIONS FAILED | Need two or more valid geometry sources.\n"
        )
        else
        (
            trim_boundary_segments = #()
            cut_error_count = 0
            collapsed_cell_count = 0
            extended_cut_segments = #()
            local original_caches = for source_node in source_values collect (buildTriangleCache source_node)
            source_element_sets = for triangle_cache in original_caches collect (this.buildSourceElementSets triangle_cache)
            slice_source_values = copy source_values #noMap
            slice_boundary_sets = for triangle_cache in original_caches collect (buildSourceBorderSegments triangle_cache)
            slice_pair_cuts = #()
            local original_sets = #()
            local original_visibility = #()
            local surviving_sets = #()
            local all_segments = #()
            pair_segments_data = #()
            local local_hidden_edges = #()
            local local_visible_edges = #()
            local reference_center = getSourcesCenter original_caches
            for triangle_cache in original_caches do
            (
                local restored_source = buildVisibleSourcePatches triangle_cache position_precision
                append original_sets restored_source[1]
                append original_visibility restored_source[2]
                for cached_triangle in triangle_cache do
                (
                    for edge_index = 1 to 3 do
                    (
                        local next_index = if edge_index == 3 then 1 else edge_index + 1
                        local original_edge = #(cached_triangle[1][edge_index], cached_triangle[1][next_index])
                        if cached_triangle[4][edge_index] then append local_visible_edges original_edge
                        else append local_hidden_edges original_edge
                    )
                )
            )
            hidden_edge_segments = local_hidden_edges
            visible_edge_segments = local_visible_edges
            surviving_sets = buildCumulativePatches original_sets source_clip_modes reference_center position_precision
            for first_index = 1 to (source_values.count - 1) do
            (
                for second_index = (first_index + 1) to source_values.count do
                (
                    local pair_segments = collectVisiblePatchSegments surviving_sets[first_index] surviving_sets[second_index] position_precision
                    for pair_segment in pair_segments do appendUniqueSegment all_segments pair_segment position_precision
                )
            )
            /* Pair inspection uses ORIGINAL evaluated source surfaces, not cumulative stages. */
            for first_index = 1 to (source_values.count - 1) do
            (
                for second_index = (first_index + 1) to source_values.count do
                (
                    local endpoint_segments = collectVisiblePatchSegments original_sets[first_index] original_sets[second_index] position_precision
                    endpoint_segments = simplifyVisibleCutSegments endpoint_segments position_precision
                    append slice_pair_cuts #(first_index, second_index, endpoint_segments)
                    local raw_segments = collectVisiblePatchSegments original_sets[first_index] original_sets[second_index] position_precision vis_a:original_visibility[first_index] vis_b:original_visibility[second_index]
                    raw_segments = simplifyVisibleCutSegments raw_segments position_precision
                    append pair_segments_data #(first_index, second_index, raw_segments)
                )
            )
            hidden_edge_segments = local_hidden_edges
            visible_edge_segments = local_visible_edges
            raw_trim_boundary_segments = trim_boundary_segments
            trim_boundary_segments = simplifyVisibleCutSegments raw_trim_boundary_segments position_precision
            /* Two-source curves come from the original finite polygons.
               Re-intersecting temporary clip cells can manufacture branches. */
            if source_values.count == 2 and slice_pair_cuts.count == 1 then all_segments = copy slice_pair_cuts[1][3] #noMap
            for extension_segment in extended_cut_segments do appendUniqueSegment all_segments extension_segment position_precision
            all_segments = simplifyVisibleCutSegments all_segments position_precision
            result_edge_segments = for visible_segment in local_visible_edges collect visible_segment
            for crossing_segment in all_segments do appendUniqueSegment result_edge_segments crossing_segment position_precision
            for trim_segment in trim_boundary_segments do appendUniqueSegment result_edge_segments trim_segment position_precision
            results = #(all_segments, surviving_sets)
        )
        results
        -- return
    ),

    /*
    Plans world-axis Slice planes for open endpoints interior to one source only.
    The dominant terminal direction selects the most perpendicular world plane.
    */
    function buildEndpointSlicePlans position_precision =
    (
        local plans = #()
        for pair_data in slice_pair_cuts do
        (
            local chains = buildCurveChains pair_data[3] position_precision
            for chain_index = 1 to chains.count do
            (
                local chain_points = chains[chain_index]
                if chain_points.count >= 2 and not (isSamePoint chain_points[1] chain_points[chain_points.count] position_precision) then
                (
                    for end_index = 1 to 2 do
                    (
                        local endpoint = if end_index == 1 then chain_points[1] else chain_points[chain_points.count]
                        local neighbor = if end_index == 1 then chain_points[2] else chain_points[chain_points.count - 1]
                        local on_borders = #()
                        for source_index in #(pair_data[1], pair_data[2]) do
                        (
                            local on_border = false
                            for border_segment in slice_boundary_sets[source_index] while not on_border do
                            (
                                on_border = segmentWithinReference endpoint endpoint border_segment position_precision
                            )
                            append on_borders on_border
                        )
                        if on_borders[1] != on_borders[2] then
                        (
                            local wider_index = if on_borders[1] then pair_data[2] else pair_data[1]
                            local direction = endpoint - neighbor
                            local axis_index = 1
                            if abs direction.y > abs direction[axis_index] then axis_index = 2
                            if abs direction.z > abs direction[axis_index] then axis_index = 3
                            local plane_normal = [0,0,0]
                            plane_normal[axis_index] = if direction[axis_index] < 0.0 then -1.0 else 1.0
                            local endpoint_key = (pair_data[1] as string) + ":" + (pair_data[2] as string) + ":" + (chain_index as string) + ":" + (end_index as string)
                            append plans #(endpoint_key, slice_source_values[wider_index], endpoint, axis_index, plane_normal)
                        )
                        else if not on_borders[1] then format "SI SLICE SKIPPED | Endpoint interior to both surfaces; wider source is ambiguous:%\n" endpoint
                    )
                )
            )
        )
        plans
        -- return
    ),

    /*
    Retains the previous shared Slice implementation for explicit legacy use.
    Normal Generate / Update does not enter this method while its gate is false.
    */
    function applyEndpointSlices position_precision =
    (
        local slice_ok = isValidNode result_node and isValidNode trimmed_result_node
        last_slice_report = "valid:" + (slice_ok as string)
        if slice_ok then
        (
            local owner_key = getUserProp result_node "SI_SliceOwnerKey"
            if owner_key == undefined then
            (
                owner_key = ((dotNetClass "System.Guid").NewGuid()).ToString "N"
                setUserProp result_node "SI_SliceOwnerKey" owner_key
            )
            local result_key = getUserProp trimmed_result_node "SI_SliceSurfaceKey"
            if result_key == undefined then
            (
                result_key = ((dotNetClass "System.Guid").NewGuid()).ToString "N"
                setUserProp trimmed_result_node "SI_SliceSurfaceKey" result_key
            )
            local previous_mods = getOwnedEndpointSlices()
            local retained_mods = #()
            local plans = buildEndpointSlicePlans position_precision
            last_slice_report += " plans:" + (plans.count as string) + " previous:" + (previous_mods.count as string)
            for plan in plans while slice_ok do
            (
                local source_node = plan[2]
                local source_key = getUserProp source_node "SI_SliceSourceKey"
                if source_key == undefined then
                (
                    source_key = ((dotNetClass "System.Guid").NewGuid()).ToString "N"
                    setUserProp source_node "SI_SliceSourceKey" source_key
                )
                local slice_mod = undefined
                for previous_mod in previous_mods while slice_mod == undefined do
                (
                    local ownership = previous_mod.SI_EndpointSlice
                    if ownership.endpoint_key == plan[1] and ownership.source_key == source_key and ownership.result_key == result_key then slice_mod = previous_mod
                )
                if slice_mod == undefined then
                (
                    last_slice_report += " creating"
                    slice_mod = SliceModifier()
                    custAttributes.add slice_mod si_endpoint_slice_ca
                    slice_mod.SI_EndpointSlice.owner_key = owner_key
                    slice_mod.SI_EndpointSlice.source_key = source_key
                    slice_mod.SI_EndpointSlice.result_key = result_key
                    slice_mod.SI_EndpointSlice.endpoint_key = plan[1]
                    slice_mod.enabled = false
                    addModifier source_node slice_mod
                    addModifier trimmed_result_node slice_mod
                    if source_node.modifiers[1] != slice_mod or trimmed_result_node.modifiers[1] != slice_mod then
                    (
                        slice_ok = false
                        last_slice_report += " bad instance"
                        format "SI SLICE ADD FAILED | Exact shared instance was not added at the top of both stacks.\n"
                    )
                )
                if slice_ok then
                (
                    /* Reattach the same owned instance if one host was edited. */
                    for target_node in #(source_node, trimmed_result_node) do
                    (
                        if (findItem (for stack_mod in target_node.modifiers collect stack_mod) slice_mod) == 0 then addModifier target_node slice_mod
                    )
                    slice_mod.name = "Endpoint Slice " + (#("X", "Y", "Z")[plan[4]])
                    slice_mod.Slice_Type = 2
                    slice_mod.Faces___Polygons_Toggle = 1
                    slice_mod.SliceFormat = 0
                    slice_mod.PlanarX = plan[4] == 1
                    slice_mod.PlanarY = plan[4] == 2
                    slice_mod.PlanarZ = plan[4] == 3
                    slice_mod.PlanarFlipX = plan[5].x < 0.0
                    slice_mod.PlanarFlipY = plan[5].y < 0.0
                    slice_mod.PlanarFlipZ = plan[5].z < 0.0
                    slice_mod.slice_plane.transform = matrix3 1
                    local world_plane = transMatrix plan[3]
                    for target_node in #(source_node, trimmed_result_node) do
                    (
                        setModContextTM target_node slice_mod (target_node.objectTransform * (inverse world_plane))
                        local actual_world = slice_mod.slice_plane.transform * (inverse (getModContextTM target_node slice_mod)) * target_node.objectTransform
                        if not (isSamePoint actual_world.translation plan[3] position_precision) then
                        (
                            slice_ok = false
                            last_slice_report += " pivot mismatch"
                            format "SI SLICE PIVOT FAILED | node:% actual:% expected:% precision:%\n" target_node.name actual_world.translation plan[3] position_precision
                        )
                    )
                    slice_mod.SI_EndpointSlice.pivot_position = plan[3]
                    slice_mod.SI_EndpointSlice.axis_index = plan[4]
                    slice_mod.enabled = true
                    append retained_mods slice_mod
                    update trimmed_result_node
                )
            )
            if slice_ok then
            (
                for previous_mod in previous_mods where (findItem retained_mods previous_mod) == 0 do
                (
                    if not (removeEndpointSlice previous_mod) then slice_ok = false
                )
            )
        )
        else format "SI SLICE FAILED | Missing controller or final surface.\n"
        if not slice_ok then format "SI SLICE UPDATE FAILED | %\n" last_slice_report
        slice_ok
        -- return
    ),

    /*
    Disables this setup's owned endpoint Slices unless legacy behavior is enabled.
    The retained implementation never runs during normal polygon-cut generation.
    */
    function updateEndpointSlices position_precision =
    (
        local slice_ok = true
        if endpoint_slice_enabled then slice_ok = applyEndpointSlices position_precision
        else
        (
            for slice_mod in (getOwnedEndpointSlices()) do
            (
                slice_mod.enabled = false
                if slice_mod.enabled then
                (
                    format "SI SLICE DISABLE FAILED | owned modifier:% expected enabled:false\n" slice_mod
                    slice_ok = false
                )
            )
            last_slice_report = "Automatic endpoint Slice disabled; polygon cuts extend to border."
        )
        slice_ok
        -- return
    ),

    /* Reuses established curve API while retaining working patches for both results. */
    function collectAllSegments source_values position_precision =
    (
        local owned_mods = getOwnedEndpointSlices()
        local prior_enabled = for slice_mod in owned_mods collect slice_mod.enabled
        local computed = undefined
        try
        (
            for slice_mod in owned_mods do slice_mod.enabled = false
            computed = buildSequentialResults source_values position_precision
        )
        catch
        (
            local exception_text = getCurrentException()
            for mod_index = 1 to owned_mods.count do owned_mods[mod_index].enabled = prior_enabled[mod_index]
            format "SI SLICE SOURCE EVALUATION FAILED | %\n" exception_text
            throw()
        )
        for mod_index = 1 to owned_mods.count do owned_mods[mod_index].enabled = prior_enabled[mod_index]
        if cut_error_count > 0 then
        (
            format "SI TOPOLOGY FAILED | % nonseparating or invalid cut(s); refusing to publish unchanged source copies.\n" cut_error_count
            computed = undefined
        )
        if computed != undefined then
        (
            working_patch_sets = computed[2]
            computed[1]
        )
        else undefined
        -- return
    ),

    /*
    A final Editable Poly must never expose the evaluated mesh's invisible
    triangulation or construction-only cell seams.
    All REAL visible source edges and actual intersection cuts stay visible.
    The temporary poly has world-space coordinates at this stage.
    */
    function restoreResultEdgeVisibility target_poly position_precision =
    (
        local restored = false
        if isValidNode target_poly and classOf target_poly.baseObject == Editable_Poly then
        (
            local poly_base = target_poly.baseObject
            local hidden_indices = #{}
            local visible_indices = #{}
            local visible_count = 0
            local hidden_count = 0
            local edge_count = polyop.getNumEdges poly_base
            for edge_index = 1 to edge_count do
            (
                local edge_ids = polyop.getEdgeVerts poly_base edge_index
                if edge_ids.count == 2 then
                (
                    local point_start = polyop.getVert poly_base edge_ids[1]
                    local point_end = polyop.getVert poly_base edge_ids[2]
                    local meaningful_edge = false
                    for reference_segment in result_edge_segments while not meaningful_edge do
                    (
                        meaningful_edge = segmentWithinReference point_start point_end reference_segment position_precision
                    )
                    if meaningful_edge then
                    (
                        visible_indices[edge_index] = true
                        visible_count += 1
                    )
                    else
                    (
                        hidden_indices[edge_index] = true
                        hidden_count += 1
                    )
                )
                else
                (
                    hidden_indices[edge_index] = true
                    hidden_count += 1
                    format "SI EDGE VIS FAILED | Invalid Editable Poly edge:%\n" edge_index
                )
            )
            try
            (
                if visible_indices.numberSet > 0 then polyop.setEdgeVis poly_base visible_indices true
                if hidden_indices.numberSet > 0 then polyop.setEdgeVis poly_base hidden_indices false
                update target_poly
                local mismatch_count = 0
                for edge_index in hidden_indices do
                (
                    if polyop.getEdgeVis poly_base edge_index then mismatch_count += 1
                )
                for edge_index in visible_indices do
                (
                    if not (polyop.getEdgeVis poly_base edge_index) then mismatch_count += 1
                )
                restored = mismatch_count == 0
                if restored then
                (
                    format "SI EDGE VIS | visible:% hidden-internal:% total:%\n" visible_count hidden_count edge_count
                )
                else
                (
                    format "SI EDGE VIS FAILED | hidden expected:% | still visible:%\n" hidden_count mismatch_count
                )
            )
            catch
            (
                format "SI EDGE VIS ERROR | %\n" (getCurrentException())
            )
        )
        restored
        -- return
    ),

    /* Reuses vertex IDs only within each source; keep distinct surface elements. */
    function findWorkingVertex vertex_values vertex_sources query_point source_index position_precision =
    (
        local vertex_index = 0
        for existing_index = 1 to vertex_values.count while vertex_index == 0 do
        (
            if vertex_sources[existing_index] == source_index and (isSamePoint vertex_values[existing_index] query_point position_precision) then vertex_index = existing_index
        )
        vertex_index
        -- return
    ),

    /* Builds the pending complete TriMesh without touching any scene node. */
    function buildTrimmedMesh patch_sets position_precision =
    (
        local mesh_vertices = #()
        local mesh_sources = #()
        local mesh_faces = #()
        for source_index = 1 to patch_sets.count do
        (
            for patch_points in patch_sets[source_index] do
            (
                local ids = #()
                for patch_point in patch_points do
                (
                    local vertex_index = findWorkingVertex mesh_vertices mesh_sources patch_point source_index position_precision
                    if vertex_index == 0 then
                    (
                        append mesh_vertices patch_point
                        append mesh_sources source_index
                        vertex_index = mesh_vertices.count
                    )
                    append ids vertex_index
                )
                if ids.count >= 3 then
                (
                    for point_index = 2 to (ids.count - 1) do
                    (
                        if ids[1] != ids[point_index] and ids[1] != ids[point_index + 1] and ids[point_index] != ids[point_index + 1] then
                        (
                            append mesh_faces [ids[1], ids[point_index], ids[point_index + 1]]
                        )
                    )
                )
            )
        )
        local pending_mesh = TriMesh()
        setNumVerts pending_mesh mesh_vertices.count
        setNumFaces pending_mesh mesh_faces.count
        for vertex_index = 1 to mesh_vertices.count do setVert pending_mesh vertex_index mesh_vertices[vertex_index]
        for face_index = 1 to mesh_faces.count do setFace pending_mesh face_index mesh_faces[face_index]
        update pending_mesh
        pending_mesh
        -- return
    ),

    /*
    Cancels collapsed construction boundaries inside the same published region.
    Opposite edges belonging to different real regions remain separate cut seams.
    */
    function cancelCollapsedRegionEdges directed_edges region_labels used_edges =
    (
        for edge_index = 1 to directed_edges.count where not used_edges[edge_index] do
        (
            local current_edge = directed_edges[edge_index]
            if current_edge[1] == current_edge[2] then used_edges[edge_index] = true
            else
            (
                local duplicate_index = 1
                while duplicate_index < edge_index and not used_edges[edge_index] do
                (
                    local prior_edge = directed_edges[duplicate_index]
                    if not used_edges[duplicate_index] and prior_edge[1] == current_edge[1] and prior_edge[2] == current_edge[2] and \
                       region_labels[prior_edge[3]] == region_labels[current_edge[3]] then used_edges[edge_index] = true
                    duplicate_index += 1
                )
            )
        )
        for edge_index = 1 to (directed_edges.count - 1) where not used_edges[edge_index] do
        (
            local current_edge = directed_edges[edge_index]
            local opposite_index = edge_index + 1
            while opposite_index <= directed_edges.count and not used_edges[edge_index] do
            (
                local opposite_edge = directed_edges[opposite_index]
                if not used_edges[opposite_index] and current_edge[1] == opposite_edge[2] and current_edge[2] == opposite_edge[1] and \
                   region_labels[current_edge[3]] == region_labels[opposite_edge[3]] then
                (
                    used_edges[edge_index] = true
                    used_edges[opposite_index] = true
                )
                opposite_index += 1
            )
        )
        used_edges
        -- return
    ),

    /*
    Rebuilds source polygon regions from cut-cell boundaries without support seams.
    Keeps only original visible-edge vertices and true finite-intersection points.
    */
    function buildVisibleRegionPolygons patch_values position_precision =
    (
        last_polygon_report = ""
        local source_corners = #()
        for patch_points in patch_values do
        (
            for point_value in patch_points do appendUniquePoint source_corners point_value position_precision
        )
        local corner_segments = for point_value in source_corners collect #(point_value, point_value)
        local actual_cut_points = #()
        for reference_segment in trim_boundary_segments do for point_value in reference_segment do appendUniquePoint actual_cut_points point_value position_precision
        local vertex_points = #()
        local vertex_sources = #()
        local cell_ids = #()
        local directed_edges = #()
        local paired_edges = #()
        local boundary_flags = #()
        local region_labels = for patch_index = 1 to patch_values.count collect patch_index
        local build_ok = true
        for patch_index = 1 to patch_values.count do
        (
            local patch_points = patch_values[patch_index]
            local conforming_patch = patch_points
            local patch_normal = getPatchNormal patch_points
            for edge_index = 1 to patch_points.count do
            (
                local next_index = if edge_index == patch_points.count then 1 else edge_index + 1
                local edge_plane = #(patch_points[edge_index], normalize (cross patch_normal (patch_points[next_index] - patch_points[edge_index])))
                conforming_patch = insertActualCutKnots conforming_patch corner_segments edge_plane position_precision
            )
            local face_ids = #()
            for point_value in conforming_patch do
            (
                /* A support-line hit on an original edge belongs to that edge's
                   actual cut vertex, never to a second construction corner. */
                local authoritative_point = undefined
                for reference_segment in visible_edge_segments while authoritative_point == undefined do
                (
                    for original_point in reference_segment while authoritative_point == undefined do
                    (
                        if isSamePoint point_value original_point position_precision then authoritative_point = original_point
                    )
                )
                for cut_point in actual_cut_points while authoritative_point == undefined do
                (
                    if isSamePoint point_value cut_point position_precision then authoritative_point = cut_point
                )
                if authoritative_point == undefined then
                (
                    local nearest_cut = undefined
                    local nearest_distance = undefined
                    for reference_segment in visible_edge_segments do
                    (
                        if segmentWithinReference point_value point_value reference_segment position_precision then
                        (
                            for cut_point in actual_cut_points do
                            (
                                if segmentWithinReference cut_point cut_point reference_segment position_precision then
                                (
                                    local candidate_distance = length (cut_point - point_value)
                                    if nearest_distance == undefined or candidate_distance < nearest_distance then
                                    (
                                        nearest_cut = cut_point
                                        nearest_distance = candidate_distance
                                    )
                                )
                            )
                        )
                    )
                    authoritative_point = nearest_cut
                )
                if authoritative_point != undefined then point_value = authoritative_point
                local vertex_index = findWorkingVertex vertex_points vertex_sources point_value 1 position_precision
                if vertex_index == 0 then
                (
                    append vertex_points point_value
                    append vertex_sources 1
                    vertex_index = vertex_points.count
                )
                if face_ids.count == 0 or face_ids[face_ids.count] != vertex_index then append face_ids vertex_index
            )
            if face_ids.count > 1 and face_ids[1] == face_ids[face_ids.count] then deleteItem face_ids face_ids.count
            append cell_ids face_ids
            for edge_index = 1 to face_ids.count do
            (
                local next_index = if edge_index == face_ids.count then 1 else edge_index + 1
                append directed_edges #(face_ids[edge_index], face_ids[next_index], patch_index)
                append paired_edges 0
                local meaningful_edge = false
                for reference_segment in result_edge_segments while not meaningful_edge do
                (
                    meaningful_edge = segmentWithinReference vertex_points[face_ids[edge_index]] vertex_points[face_ids[next_index]] reference_segment position_precision
                )
                for reference_segment in raw_trim_boundary_segments while not meaningful_edge do
                (
                    meaningful_edge = segmentWithinReference vertex_points[face_ids[edge_index]] vertex_points[face_ids[next_index]] reference_segment position_precision
                )
                append boundary_flags meaningful_edge
            )
        )
        for first_index = 1 to (directed_edges.count - 1) do
        (
            if paired_edges[first_index] == 0 then
            (
                local first_edge = directed_edges[first_index]
                local second_index = first_index + 1
                while second_index <= directed_edges.count and paired_edges[first_index] == 0 do
                (
                    local second_edge = directed_edges[second_index]
                    if first_edge[1] == second_edge[2] and first_edge[2] == second_edge[1] then
                    (
                        paired_edges[first_index] = second_index
                        paired_edges[second_index] = first_index
                        /* A hidden source diagonal is not a polygon boundary,
                           even when evaluation warps its two triangles. */
                        if not boundary_flags[first_index] and not boundary_flags[second_index] then
                        (
                            local first_root = first_edge[3]
                            local second_root = second_edge[3]
                            while region_labels[first_root] != first_root do first_root = region_labels[first_root]
                            while region_labels[second_root] != second_root do second_root = region_labels[second_root]
                            region_labels[second_root] = first_root
                        )
                    )
                    second_index += 1
                )
            )
        )
        for patch_index = 1 to region_labels.count do
        (
            local region_root = patch_index
            while region_labels[region_root] != region_root do region_root = region_labels[region_root]
            region_labels[patch_index] = region_root
        )
        local used_edges = #{}
        used_edges.count = directed_edges.count
        for edge_index = 1 to directed_edges.count do
        (
            local paired_index = paired_edges[edge_index]
            if paired_index > 0 and \
               region_labels[directed_edges[edge_index][3]] == region_labels[directed_edges[paired_index][3]] then used_edges[edge_index] = true
        )
        used_edges = cancelCollapsedRegionEdges directed_edges region_labels used_edges
        local allowed_points = #()
        for reference_segment in visible_edge_segments do
        (
            for point_value in reference_segment do appendUniquePoint allowed_points point_value position_precision
        )
        local hidden_cut_points = #()
        for reference_segment in trim_boundary_segments do
        (
            for point_value in reference_segment do
            (
                local visible_hit = false
                for visible_segment in visible_edge_segments while not visible_hit do
                (
                    visible_hit = segmentWithinReference point_value point_value visible_segment position_precision
                )
                if visible_hit then appendUniquePoint allowed_points point_value position_precision
                else appendUniquePoint hidden_cut_points point_value position_precision
            )
        )
        local polygons = #()
        for edge_index = 1 to directed_edges.count while build_ok do
        (
            if not used_edges[edge_index] then
            (
                local region_id = region_labels[directed_edges[edge_index][3]]
                local polygon_points = #()
                local current_edge = edge_index
                local first_vertex = directed_edges[edge_index][1]
                local closed_loop = false
                while current_edge > 0 and not closed_loop and build_ok do
                (
                    used_edges[current_edge] = true
                    append polygon_points vertex_points[directed_edges[current_edge][1]]
                    local next_vertex = directed_edges[current_edge][2]
                    closed_loop = next_vertex == first_vertex
                    if not closed_loop then
                    (
                        local candidates = #()
                        for candidate_index = 1 to directed_edges.count where not used_edges[candidate_index] do
                        (
                            local candidate_edge = directed_edges[candidate_index]
                            if candidate_edge[1] == next_vertex and region_labels[candidate_edge[3]] == region_id then append candidates candidate_index
                        )
                        if candidates.count == 1 then current_edge = candidates[1]
                        else
                        (
                            build_ok = false
                            last_polygon_report = "vertex:" + (vertex_points[next_vertex] as string) + " candidates:"
                            for candidate_index in candidates do
                            (
                                local candidate_edge = directed_edges[candidate_index]
                                last_polygon_report += (vertex_points[candidate_edge[2]] as string) + ";"
                            )
                            format "SI POLYGON BOUNDARY FAILED | region:% vertex:% outgoing:% expected:1 | %\n" region_id next_vertex candidates.count last_polygon_report
                        )
                    )
                )
                if build_ok then
                (
                    local simplified_points = #()
                    for point_index = 1 to polygon_points.count do
                    (
                        local point_value = polygon_points[point_index]
                        local is_authoritative = false
                        for allowed_point in allowed_points while not is_authoritative do is_authoritative = isSamePoint point_value allowed_point position_precision
                        local prior_index = if point_index == 1 then polygon_points.count else point_index - 1
                        local next_index = if point_index == polygon_points.count then 1 else point_index + 1
                        local collinear_point = segmentWithinReference point_value point_value #(polygon_points[prior_index], polygon_points[next_index]) position_precision
                        local hidden_cut_point = isOnHiddenEdge point_value position_precision
                        for hidden_point in hidden_cut_points while not hidden_cut_point do hidden_cut_point = isSamePoint point_value hidden_point position_precision
                        if is_authoritative then append simplified_points point_value
                        else if not collinear_point and not hidden_cut_point then
                        (
                            build_ok = false
                            last_polygon_report = "unsupported corner:" + (point_value as string) + " region:" + (region_id as string)
                            format "SI POLYGON VERTEX FAILED | Unsupported construction corner:% region:%\n" point_value region_id
                        )
                    )
                    if simplified_points.count >= 3 then append polygons simplified_points
                    else
                    (
                        /* A construction sliver can straddle a quantization cell
                           while remaining one line at the selected position precision. */
                        local span_segment = undefined
                        local span_length = 0.0
                        for first_index = 1 to (polygon_points.count - 1) do
                        (
                            for second_index = first_index + 1 to polygon_points.count do
                            (
                                local candidate_length = length (polygon_points[second_index] - polygon_points[first_index])
                                if candidate_length > span_length then
                                (
                                    span_length = candidate_length
                                    span_segment = #(polygon_points[first_index],polygon_points[second_index])
                                )
                            )
                        )
                        local collapsed_boundary = span_segment != undefined
                        for point_value in polygon_points while collapsed_boundary do
                        (
                            collapsed_boundary = segmentWithinReference point_value point_value span_segment position_precision
                        )
                        if collapsed_boundary then
                        (
                            collapsed_cell_count += 1
                            format "SI POLYGON COLLAPSED | region:% corners:% raw area:% position precision:%\n" region_id simplified_points.count (getWorkingPatchArea polygon_points) position_precision
                        )
                        else
                        (
                            build_ok = false
                            last_polygon_report = "degenerate region:" + (region_id as string) + " corners:" + (simplified_points.count as string) + " raw area:" + ((getWorkingPatchArea polygon_points) as string) + " raw:" + (polygon_points as string)
                            format "SI POLYGON FAILED | region:% corners:% expected:3 or more | %\n" region_id simplified_points.count last_polygon_report
                        )
                    )
                )
            )
        )
        if build_ok then polygons else undefined
        -- return
    ),

    /*
    Keeps evaluated triangle components distinct by their original shared vertex IDs.
    Coincident coordinates never connect independent sheets inside a mid-result.
    */
    function buildSourceElementSets triangle_set =
    (
        local labels = for triangle_index = 1 to triangle_set.count collect triangle_index
        for first_index = 1 to (triangle_set.count - 1) do
        (
            for second_index = first_index + 1 to triangle_set.count do
            (
                local shared_count = 0
                for vertex_id in triangle_set[first_index][5] do
                (
                    if (findItem triangle_set[second_index][5] vertex_id) > 0 then shared_count += 1
                )
                if shared_count >= 2 then
                (
                    local first_root = first_index
                    local second_root = second_index
                    while labels[first_root] != first_root do first_root = labels[first_root]
                    while labels[second_root] != second_root do second_root = labels[second_root]
                    labels[second_root] = first_root
                )
            )
        )
        local root_ids = #()
        local element_sets = #()
        for triangle_index = 1 to triangle_set.count do
        (
            local root_id = triangle_index
            while labels[root_id] != root_id do root_id = labels[root_id]
            local element_index = findItem root_ids root_id
            if element_index == 0 then
            (
                append root_ids root_id
                append element_sets #()
                element_index = element_sets.count
            )
            append element_sets[element_index] triangle_set[triangle_index]
        )
        element_sets
        -- return
    ),

    /*
    Assigns surviving convex cells to their evaluated source sheet before polygon assembly.
    Uses the cell center and closest supporting plane; does not alter coordinates.
    */
    function partitionSourceElements patch_values element_sets position_precision =
    (
        local partitioned = #()
        if element_sets.count <= 1 then partitioned = #(patch_values)
        else
        (
            partitioned = for element_set in element_sets collect #()
            for patch_points in patch_values do
            (
                local center_point = [0,0,0]
                for point_value in patch_points do center_point += point_value
                center_point /= patch_points.count
                local patch_normal = getPatchNormal patch_points
                local chosen_element = 0
                local nearest_plane = undefined
                local closest_normal = undefined
                for element_index = 1 to element_sets.count do
                (
                    for cached_triangle in element_sets[element_index] do
                    (
                        local triangle_points = cached_triangle[1]
                        local triangle_normal = getPatchNormal triangle_points
                        if patch_normal != undefined and triangle_normal != undefined and (dot patch_normal triangle_normal) > 0.0 then
                        (
                            local plane_distance = abs (dot triangle_normal (center_point - triangle_points[1]))
                            if plane_distance <= position_precision and (pointInConvexPatch center_point triangle_points position_precision) then
                            (
                                local normal_alignment = dot patch_normal triangle_normal
                                if nearest_plane == undefined or plane_distance < nearest_plane or (plane_distance == nearest_plane and normal_alignment > closest_normal) then
                                (
                                    nearest_plane = plane_distance
                                    closest_normal = normal_alignment
                                    chosen_element = element_index
                                )
                            )
                        )
                    )
                )
                if chosen_element == 0 then
                (
                    last_polygon_report = "No evaluated source element for retained cell at " + (center_point as string)
                    throw ("SI POLY ELEMENT FAILED | " + last_polygon_report)
                )
                append partitioned[chosen_element] patch_points
            )
        )
        partitioned
        -- return
    ),

    /*
    Builds real Editable Poly polygon topology from surviving working patches.
    Vertices shared by patches from the same source are reused, while separate
    source surfaces remain independently editable polygon elements.
    Returns a temporary Editable Poly node or undefined on any build failure.
    */
    function buildTrimmedPoly patch_sets position_precision =
    (
        local vertex_points = #()
        local vertex_sources = #()
        local polygon_ids = #()
        local build_ok = true
        local surface_index = 0

        for source_index = 1 to patch_sets.count while build_ok do
        (
            local element_sets = if source_index <= source_element_sets.count then source_element_sets[source_index] else #()
            local element_patches = partitionSourceElements patch_sets[source_index] element_sets position_precision
            for element_patch_set in element_patches while build_ok do
            (
                surface_index += 1
                local source_polygons = buildVisibleRegionPolygons element_patch_set position_precision
                if source_polygons == undefined then build_ok = false
                else
                (
                    for polygon_points in source_polygons while build_ok do
                    (
                        local face_ids = #()
                        for point_value in polygon_points do
                        (
                            local vertex_index = findWorkingVertex vertex_points vertex_sources point_value surface_index position_precision
                            if vertex_index == 0 then
                            (
                                append vertex_points point_value
                                append vertex_sources surface_index
                                vertex_index = vertex_points.count
                            )
                            append face_ids vertex_index
                        )
                        local unique_ids = #()
                        for vertex_index in face_ids do appendIfUnique unique_ids vertex_index
                        if unique_ids.count != face_ids.count or face_ids.count < 3 then
                        (
                            format "SI POLY FAILED | Invalid polygon from source:% | vertices:% unique:%\n" source_index face_ids.count unique_ids.count
                            build_ok = false
                        )
                        else append polygon_ids face_ids
                    )
                )
            )

        )

        local pending_poly = undefined
        if build_ok then
        (
            try
            (
                pending_poly = Editable_Mesh name:"SI_Pending_Poly_Result"
                convertToPoly pending_poly
                build_ok = isValidNode pending_poly and classOf pending_poly.baseObject == Editable_Poly

                if build_ok then
                (
                    for point_value in vertex_points while build_ok do
                    (
                        local created_index = polyop.createVert pending_poly.baseObject point_value
                        if created_index == undefined then
                        (
                            build_ok = false
                            format "SI POLY FAILED | Could not create vertex.\n"
                        )
                    )
                )

                if build_ok then
                (
                    for face_ids in polygon_ids while build_ok do
                    (
                        local face_index = polyop.createPolygon pending_poly.baseObject face_ids
                        if face_index == undefined then
                        (
                            build_ok = false
                            format "SI POLY FAILED | Could not create polygon with % vertices.\n" face_ids.count
                        )
                    )
                )

                if build_ok then
                (
                    /* Native construction is complete. No cached component IDs
                       survive into the following topology inspection stage. */
                    if polyop.getHasDeadStructs pending_poly.baseObject != 0 then
                    (
                        polyop.collapseDeadStructs pending_poly.baseObject
                    )
                    build_ok = (polyop.getNumFaces pending_poly.baseObject) == polygon_ids.count
                    if not build_ok then
                    (
                        format "SI POLY FAILED | Polygon count mismatch: expected %.\n" polygon_ids.count
                    )
                )

                if build_ok then
                (
                    for face_index = 1 to (polyop.getNumFaces pending_poly.baseObject) while build_ok do
                    (
                        local face_degree = polyop.getFaceDeg pending_poly.baseObject face_index
                        if face_degree < 3 then
                        (
                            format "SI POLYGON FAILED | face:% | actual degree:% | expected:3 or more\n" face_index face_degree
                            build_ok = false
                        )
                    )
                    if build_ok then build_ok = restoreResultEdgeVisibility pending_poly position_precision
                    if not build_ok then format "SI POLY FAILED | Could not restore source-visible edge topology.\n"
                )
            )
            catch
            (
                format "SI POLY ERROR | %\n" (getCurrentException())
                build_ok = false
            )
        )

        if not build_ok then
        (
            if isValidNode pending_poly then delete pending_poly
            pending_poly = undefined
        )

        pending_poly
        -- return
    ),


    /*
    Creates/reuses one result-only child layer below the current input source layer.
    Layer names include the generated controller handle to isolate independent setups.
    Never parents scene nodes or changes the original source layer hierarchy.
    */
    function getResultChildLayer source_node =
    (
        local child_layer = undefined
        if isValidNode source_node and isValidNode result_node then
        (
            try
            (
                local source_layer = source_node.layer
                if source_layer != undefined then
                (
                    local owner_handle = (getHandleByAnim result_node) as string
                    local layer_name = "SI_RESULTS_" + owner_handle + "_" + source_layer.name
                    child_layer = LayerManager.getLayerFromName layer_name
                    if child_layer == undefined then
                    (
                        child_layer = LayerManager.newLayerFromName layer_name
                        if child_layer != undefined then
                        (
                            if not (child_layer.setParent source_layer) then
                            (
                                format "SI LAYER FAILED | Cannot parent % under source layer %.\n" layer_name source_layer.name
                                child_layer = undefined
                            )
                        )
                    )
                    else if (child_layer.getParent()) != source_layer then
                    (
                        format "SI LAYER FAILED | Existing layer % belongs to a different parent.\n" layer_name
                        child_layer = undefined
                    )
                )
            )
            catch
            (
                format "SI LAYER FAILED | %\n" (getCurrentException())
                child_layer = undefined
            )
        )
        child_layer
        -- return
    ),


    /*
    Assigns a generated node to a setup-owned layer under its original source layer.
    Verifies the assignment; invalid nodes and missing layers are never dereferenced.
    */
    function placeResultNodeInLayer target_node source_index =
    (
        local placed = false
        if isValidNode target_node and source_index >= 1 and source_index <= source_nodes.count then
        (
            local source_node = source_nodes[source_index]
            if isValidNode source_node then
            (
                local target_layer = getResultChildLayer source_node
                if target_layer != undefined then
                (
                    try
                    (
                        target_layer.addNode target_node
                        placed = (target_node.layer == target_layer)
                    )
                    catch
                    (
                        format "SI LAYER FAILED | Output assignment: %\n" (getCurrentException())
                    )
                )
            )
        )
        if not placed then format "SI LAYER FAILED | Cannot layer generated output for source index: %.\n" source_index
        placed
        -- return
    ),


    /*
    Removes only this controller's empty SI_RESULTS layers left by prior outputs.
    Populated, active, unrelated and parent layers with children are preserved.
    */
    function cleanupEmptyResultLayers owner_handle:"" =
    (
        local deleted_count = 0
        local handle_text = owner_handle
        if handle_text == "" and isValidNode result_node then handle_text = (getHandleByAnim result_node) as string
        if handle_text != "" then
        (
            local owned_prefix = "SI_RESULTS_" + handle_text + "_"
            for layer_index = (LayerManager.count - 1) to 1 by -1 do
            (
                local result_layer = LayerManager.getLayer layer_index
                if result_layer != undefined and result_layer.name.count >= owned_prefix.count then
                (
                    if (substring result_layer.name 1 owned_prefix.count) == owned_prefix then
                    (
                        if result_layer.getNumNodes() == 0 and result_layer.getNumChildren() == 0 then
                        (
                            /* An empty active output layer must first yield current status to default layer. */
                            if result_layer == LayerManager.current then
                            (
                                local default_layer = LayerManager.getLayer 0
                                if default_layer != undefined then default_layer.current = true
                            )
                            if result_layer != LayerManager.current and result_layer.canDelete() then
                            (
                                if LayerManager.deleteLayerByName result_layer.name then deleted_count += 1
                            )
                        )
                    )
                )
            )
        )
        deleted_count
        -- return
    ),

    /*
    Places controller, cumulative results and pair curves into result-only child layers.
    Final results belong under the last contributing source layer; earlier stages
    and pair curves belong under the source layer introduced by their operation.
    */
    function placeGeneratedResultsInLayers =
    (
        local placed_all = true
        if source_nodes.count >= 2 and isValidNode result_node then
        (
            if not (placeResultNodeInLayer result_node 1) then placed_all = false
            if only_final_result then
            (
                if isValidNode trimmed_result_node then
                (
                    if not (placeResultNodeInLayer trimmed_result_node source_nodes.count) then placed_all = false
                )
            )
            else
            (
                for result_index = 1 to process_result_nodes.count do
                (
                    local generated_node = process_result_nodes[result_index]
                    if isValidNode generated_node then
                    (
                        local source_index = amin source_nodes.count (result_index + 1)
                        if not (placeResultNodeInLayer generated_node source_index) then placed_all = false
                    )
                )
                for pair_index = 1 to pair_curve_nodes.count do
                (
                    local curve_node = pair_curve_nodes[pair_index]
                    if isValidNode curve_node and pair_index <= pair_source_indices.count then
                    (
                        local source_indices = pair_source_indices[pair_index]
                        if source_indices != undefined and source_indices.count == 2 then
                        (
                            if not (placeResultNodeInLayer curve_node source_indices[2]) then placed_all = false
                        )
                    )
                )
            )
        )
        else placed_all = false
        cleanupEmptyResultLayers()
        placed_all
        -- return
    ),


    /*
    Commits an Editable Poly result without replacing the existing scene node.
    The writable baseObject link keeps its modifier stack, including Slice.
    Temporary construction is fully completed before the old base is replaced.
    */
    function makeTrimmedResult pending_poly result_mesh:undefined result_name:"Surface_Intersections_Trimmed" add_slice:false =
    (
        local completed_result = undefined

        if isValidNode pending_poly and classOf pending_poly.baseObject == Editable_Poly then
        (
            if isValidNode result_mesh then
            (
                try
                (
                    local inverse_transform = inverse result_mesh.objectTransform
                    for vertex_index = 1 to (polyop.getNumVerts pending_poly.baseObject) do
                    (
                        local point_value = polyop.getVert pending_poly.baseObject vertex_index
                        polyop.setVert pending_poly.baseObject vertex_index (point_value * inverse_transform)
                    )
                    result_mesh.baseObject = pending_poly.baseObject
                    update result_mesh
                    completed_result = result_mesh
                )
                catch
                (
                    format "SI POLY COMMIT FAILED | %\n" (getCurrentException())
                )

                if isValidNode pending_poly then delete pending_poly
            )
            else
            (
                pending_poly.name = result_name
                completed_result = pending_poly
            )

            if isValidNode completed_result then
            (
                completed_result.wirecolor = color 230 155 65
                if add_slice then ensureResultSliceModifier completed_result
                format "SI POLY RESULT | polygons:% | vertices:%\n" (polyop.getNumFaces completed_result.baseObject) (polyop.getNumVerts completed_result.baseObject)
            )
        )
        else
        (
            format "SI POLY COMMIT FAILED | Missing valid Editable Poly geometry.\n"
        )

        completed_result
        -- return
    ),

    /*
    Names a processed surface from exactly the original inputs consumed so far.
    Each successive result uses the preceding cumulative geometry as its input.
    */
    function getProcessResultName step_index ordered_sources =
    (
        local joined_name = ""
        local last_source_index = amin ordered_sources.count (step_index + 1)
        for source_index = 1 to last_source_index do
        (
            if joined_name != "" then joined_name += "+"
            if isValidNode ordered_sources[source_index] then joined_name += ordered_sources[source_index].name
            else joined_name += "MissingSource"
        )
        joined_name
        -- return
    ),

    /*
    Remove only outputs of this result's confirmed owner. Keep original inputs and
    unrelated / unowned scene nodes untouched. A failed deletion is a real failure.
    */
    function deleteOwnedOptionalNodes candidate_nodes owner_handle owner_key protected_node:undefined =
    (
        local cleared = true
        local visited = #()
        for candidate_node in candidate_nodes do
        (
            if isValidNode candidate_node and (findItem visited candidate_node) == 0 then
            (
                append visited candidate_node
                local candidate_label = candidate_node.name
                local stored_owner = getUserProp candidate_node owner_key
                local safe_to_delete = (stored_owner != undefined and (stored_owner as string) == owner_handle and \
                    candidate_node != protected_node and candidate_node != result_node and \
                    (findItem source_nodes candidate_node) == 0)
                if safe_to_delete then
                (
                    try
                    (
                        delete candidate_node
                    )
                    catch
                    (
                        format "SI FINAL ONLY DELETE FAILED | node:% | error:%\n" candidate_label (getCurrentException())
                    )
                    if isValidNode candidate_node then
                    (
                        cleared = false
                        format "SI FINAL ONLY DELETE FAILED | Owned output still exists after delete.\n"
                    )
                )
                else
                (
                    cleared = false
                    format "SI FINAL ONLY DELETE SKIPPED | Output ownership/source verification failed.\n"
                )
            )
        )
        cleared
        -- return
    ),

    /*
    Working patch sets still process every source cumulatively. When final-only
    is enabled, publish just the latest step and recycle the existing final node.
    No intermediate scene meshes need to be created or snapshot back into Max.
    */
    function updateProcessResults position_precision ordered_sources =
    (
        local step_count = process_patch_sets.count
        local process_ok = (step_count >= 1 and isValidNode result_node)
        if not process_ok then format "SI PROCESS FAILED | Need a valid curve controller and cumulative patch steps.\n"
        if process_ok and only_final_result then
        (
            local owner_handle = (getHandleByAnim result_node) as string
            local pending_node = buildTrimmedPoly process_patch_sets[step_count] position_precision
            if not isValidNode pending_node then
            (
                format "SI FINAL ONLY FAILED | Cannot build last polygon step:%\n" step_count
                process_ok = false
            )
            else
            (
                local previous_final = if isValidNode trimmed_result_node then trimmed_result_node else undefined
                if previous_final == undefined and process_result_nodes.count > 0 then
                (
                    local previous_last = process_result_nodes[process_result_nodes.count]
                    if isValidNode previous_last then previous_final = previous_last
                )
                local desired_name = getProcessResultName step_count ordered_sources
                local final_node = makeTrimmedResult pending_node result_mesh:previous_final result_name:desired_name add_slice:false
                if isValidNode final_node then
                (
                    final_node.name = desired_name
                    setUserProp final_node "SI_ProcessOwner" owner_handle
                    setUserProp final_node "SI_ProcessIndex" "1"
                    setUserProp final_node "SI_ProcessKind" "surface"
                    setUserProp final_node "SI_OutputMode" "final_only"
                    setUserProp final_node "SI_StageOwner" owner_handle
                    setUserProp final_node "SI_StageKind" "final_surface"
                    local old_intermediates = for old_node in process_result_nodes where (isValidNode old_node and old_node != final_node) collect old_node
                    process_ok = deleteOwnedOptionalNodes old_intermediates owner_handle "SI_ProcessOwner" protected_node:final_node
                    if process_ok then
                    (
                        process_result_nodes = #(final_node)
                        trimmed_result_node = final_node
                        inspection_process = 0
                        format "SI FINAL ONLY | Published final poly:% | cumulative steps:%\n" final_node.name step_count
                    )
                )
                else
                (
                    format "SI FINAL ONLY FAILED | Could not commit final surface.\n"
                    process_ok = false
                )
            )
        )
        else if process_ok then
        (
            local pending_nodes = #()
            local committed_nodes = #()
            for step_index = 1 to step_count while process_ok do
            (
                local pending_node = buildTrimmedPoly process_patch_sets[step_index] position_precision
                if isValidNode pending_node then append pending_nodes pending_node
                else
                (
                    format "SI PROCESS FAILED | Cannot build Editable Poly at step:%\n" step_index
                    process_ok = false
                )
            )
            if process_ok then
            (
                local prior_nodes = copy process_result_nodes #noMap
                local next_nodes = #()
                local owner_handle = (getHandleByAnim result_node) as string
                local prior_final_only = (prior_nodes.count == 1 and isValidNode prior_nodes[1] and \
                    (getUserProp prior_nodes[1] "SI_OutputMode") == "final_only")
                for step_index = 1 to step_count while process_ok do
                (
                    local previous_node = if prior_final_only then (if step_index == step_count then prior_nodes[1] else undefined) \
                        else (if step_index <= prior_nodes.count then prior_nodes[step_index] else undefined)
                    if not isValidNode previous_node and step_index == step_count then
                    (
                        if isValidNode trimmed_result_node and (findItem prior_nodes trimmed_result_node) == 0 then previous_node = trimmed_result_node
                    )
                    local desired_name = getProcessResultName step_index ordered_sources
                    local step_node = makeTrimmedResult pending_nodes[step_index] result_mesh:previous_node result_name:desired_name add_slice:false
                    if isValidNode step_node then
                    (
                        step_node.name = desired_name
                        setUserProp step_node "SI_ProcessOwner" owner_handle
                        setUserProp step_node "SI_ProcessIndex" (step_index as string)
                        setUserProp step_node "SI_ProcessKind" "surface"
                        setUserProp step_node "SI_OutputMode" "process_stack"
                        setUserProp step_node "SI_StageOwner" owner_handle
                        setUserProp step_node "SI_StageKind" (if step_index == step_count then "final_surface" else "process_surface")
                        append next_nodes step_node
                        append committed_nodes step_node
                    )
                    else
                    (
                        process_ok = false
                        format "SI PROCESS FAILED | Could not commit step:%\n" step_index
                    )
                )
                if process_ok then
                (
                    if prior_nodes.count > step_count and not prior_final_only then
                    (
                        for old_index = (step_count + 1) to prior_nodes.count do
                        (
                            local stale_node = prior_nodes[old_index]
                            if isValidNode stale_node and (findItem ordered_sources stale_node) == 0 then
                            (
                                hide stale_node
                                setUserProp stale_node "SI_ProcessKind" "retired"
                                appendIfUnique legacy_stage_nodes stale_node
                            )
                        )
                    )
                    process_result_nodes = next_nodes
                    trimmed_result_node = process_result_nodes[step_count]
                    inspection_process = 0
                    format "SI PROCESS | % cumulative result surfaces | latest:%\n" process_result_nodes.count trimmed_result_node.name
                )
            )
            if not process_ok then
            (
                for pending_node in pending_nodes do
                (
                    if isValidNode pending_node and (findItem committed_nodes pending_node) == 0 then delete pending_node
                )
            )
        )
        process_ok
        -- return
    ),

    /*
    Preserves the final Editable Poly surface and shows either final curves
    or one raw intersection curve between a selected pair of source surfaces.
    */
    function applyOutputVisibility =
    (
        if isValidNode result_node then
        (
            if (not only_final_result) and inspection_pair == 0 and output_curves then unhide result_node else hide result_node
        )
        local visible_process = if inspection_process > 0 then inspection_process else process_result_nodes.count
        if process_result_nodes.count == 0 then
        (
            if isValidNode trimmed_result_node then
            (
                if output_surfaces then unhide trimmed_result_node else hide trimmed_result_node
            )
        )
        else
        (
            for process_index = 1 to process_result_nodes.count do
            (
                local surface_node = process_result_nodes[process_index]
                if isValidNode surface_node then
                (
                    if output_surfaces and process_index == visible_process then unhide surface_node
                    else hide surface_node
                )
            )
        )
        for pair_index = 1 to pair_curve_nodes.count do
        (
            local curve_node = pair_curve_nodes[pair_index]
            if isValidNode curve_node then
            (
                if (not only_final_result) and pair_index == inspection_pair and output_curves then unhide curve_node else hide curve_node
            )
        )
        true
        -- return
    ),


    /*
    Select and display one saved processing result without modifying source rows.
    Index zero is the latest result, regardless of the number of source nodes.
    */
    function setInspectionProcess step_index =
    (
        local selected_index = if step_index == 0 then process_result_nodes.count else step_index
        local process_ok = selected_index >= 1 and selected_index <= process_result_nodes.count
        if process_ok then
        (
            local target_node = process_result_nodes[selected_index]
            process_ok = isValidNode target_node
            if process_ok then
            (
                inspection_process = selected_index
                applyOutputVisibility()
                select target_node
            )
        )
        if not process_ok then format "SI PROCESS INSPECT FAILED | Invalid result step: %\n" step_index
        process_ok
        -- return
    ),

    /*
    Selects the displayed source-pair intersection without changing geometry.
    Index zero means the combined final intersection curves.
    */
    function setInspectionPair pair_index =
    (
        local pair_ok = (pair_index >= 0 and pair_index <= pair_curve_nodes.count)
        if pair_ok then
        (
            inspection_pair = pair_index
            applyOutputVisibility()
        )
        else format "SI PAIR FAILED | Invalid inspection pair: %\n" pair_index
        pair_ok
        -- return
    ),


    /*
    Restores ONLY pairwise curves linked by result handle. Legacy v0.31 step
    objects are recorded for explicit Reset, never generated or silently deleted.
    */
    function restorePairNodes =
    (
        pair_curve_nodes = #()
        pair_source_indices = #()
        legacy_stage_nodes = #()
        process_result_nodes = #()
        inspection_pair = 0
        inspection_process = 0
        if isValidNode result_node then
        (
            local owner_handle = (getHandleByAnim result_node) as string
            for scene_node in ($* as array) where isValidNode scene_node do
            (
                local saved_owner = getUserProp scene_node "SI_StageOwner"
                local pair_owner = getUserProp scene_node "SI_PairOwner"
                local process_owner = getUserProp scene_node "SI_ProcessOwner"
                if process_owner != undefined and (process_owner as string) == owner_handle then
                (
                    local process_kind = getUserProp scene_node "SI_ProcessKind"
                    if process_kind == "surface" then
                    (
                        local process_value = getUserProp scene_node "SI_ProcessIndex"
                        local process_index = if process_value != undefined then (process_value as integer) else undefined
                        if process_index != undefined and process_index > 0 then
                        (
                            if process_result_nodes.count < process_index then process_result_nodes.count = process_index
                            process_result_nodes[process_index] = scene_node
                        )
                    )
                    else if process_kind == "retired" then appendIfUnique legacy_stage_nodes scene_node
                )
                if pair_owner != undefined and (pair_owner as string) == owner_handle then
                (
                    local pair_index_value = getUserProp scene_node "SI_PairIndex"
                    local source_a_value = getUserProp scene_node "SI_PairA"
                    local source_b_value = getUserProp scene_node "SI_PairB"
                    if pair_index_value != undefined and source_a_value != undefined and source_b_value != undefined then
                    (
                        local pair_index = pair_index_value as integer
                        local a_index = source_a_value as integer
                        local b_index = source_b_value as integer
                        if pair_index != undefined and pair_index > 0 and a_index != undefined and b_index != undefined then
                        (
                            if pair_curve_nodes.count < pair_index then pair_curve_nodes.count = pair_index
                            if pair_source_indices.count < pair_index then pair_source_indices.count = pair_index
                            pair_curve_nodes[pair_index] = scene_node
                            pair_source_indices[pair_index] = #(a_index,b_index)
                        )
                    )
                )
                else if saved_owner != undefined and (saved_owner as string) == owner_handle then
                (
                    local stage_kind = getUserProp scene_node "SI_StageKind"
                    if stage_kind == "final_surface" then trimmed_result_node = scene_node
                    else if stage_kind == "surface" or stage_kind == "curves" then append legacy_stage_nodes scene_node
                )
            )
        )
        if process_result_nodes.count > 0 and isValidNode process_result_nodes[process_result_nodes.count] then
        (
            trimmed_result_node = process_result_nodes[process_result_nodes.count]
        )
        /* Old v0.31 snapshots stay in the scene for safe manual cleanup, but
           are hidden so only the final surface and pair curves are inspected. */
        for old_node in legacy_stage_nodes do
        (
            if isValidNode old_node and (findItem source_nodes old_node) == 0 then hide old_node
        )
        applyOutputVisibility()
        pair_curve_nodes.count
        -- return
    ),


    /*
    Builds ONLY pairwise intersection spline nodes; no intermediate surfaces.
    Pair nodes are stable across updates and recoverable from result-owned tags.
    */
    function updatePairResults position_precision =
    (
        local pair_ok = isValidNode result_node
        local owner_handle = if pair_ok then (getHandleByAnim result_node) as string else ""
        if pair_ok and only_final_result then
        (
            pair_ok = deleteOwnedOptionalNodes pair_curve_nodes owner_handle "SI_PairOwner" protected_node:trimmed_result_node
            if pair_ok then
            (
                pair_curve_nodes = #()
                pair_source_indices = #()
                inspection_pair = 0
                applyOutputVisibility()
            )
        )
        if pair_ok and isValidNode trimmed_result_node then
        (
            setUserProp trimmed_result_node "SI_StageOwner" owner_handle
            setUserProp trimmed_result_node "SI_StageKind" "final_surface"
        )
        if not only_final_result then for pair_index = 1 to pair_segments_data.count while pair_ok do
        (
            local pair_data = pair_segments_data[pair_index]
            local source_a = pair_data[1]
            local source_b = pair_data[2]
            local previous_curve = if pair_index <= pair_curve_nodes.count then pair_curve_nodes[pair_index] else undefined
            if not isValidNode previous_curve then previous_curve = undefined
            local output_curve = makeSplineResult pair_data[3] position_precision result_shape:previous_curve keep_empty:true
            if not isValidNode output_curve then
            (
                pair_ok = false
                format "SI PAIR FAILED | Could not generate pair curve:%\n" pair_index
            )
            else
            (
                if previous_curve == undefined then
                (
                    output_curve.name = "Surface_Intersections_Pair_" + (formattedPrint source_a format:".2d") + "_" + (formattedPrint source_b format:".2d")
                )
                output_curve.wirecolor = color 245 205 70
                if pair_curve_nodes.count < pair_index then pair_curve_nodes.count = pair_index
                if pair_source_indices.count < pair_index then pair_source_indices.count = pair_index
                pair_curve_nodes[pair_index] = output_curve
                pair_source_indices[pair_index] = #(source_a,source_b)
                setUserProp output_curve "SI_PairOwner" owner_handle
                setUserProp output_curve "SI_PairIndex" (pair_index as string)
                setUserProp output_curve "SI_PairA" (source_a as string)
                setUserProp output_curve "SI_PairB" (source_b as string)
            )
        )
        if pair_ok and not only_final_result then
        (
            /* An input count change may remove pairs; delete only tracked, owned outputs. */
            if pair_curve_nodes.count > pair_segments_data.count then for pair_index = pair_curve_nodes.count to (pair_segments_data.count + 1) by -1 do
            (
                local stale_curve = pair_curve_nodes[pair_index]
                if isValidNode stale_curve then
                (
                    local stale_owner = getUserProp stale_curve "SI_PairOwner"
                    if (findItem source_nodes stale_curve) == 0 and stale_owner != undefined and (stale_owner as string) == owner_handle then
                    (
                        try
                        (
                            delete stale_curve
                        )
                        catch
                        (
                            format "SI PAIR FAILED | Removing old pair: %\n" (getCurrentException())
                        )
                        if isValidNode stale_curve then
                        (
                            pair_ok = false
                            format "SI PAIR FAILED | Could not delete stale pair node.\n"
                        )
                    )
                    else
                    (
                        format "SI PAIR FAILED | Old pair output is not tool-owned.\n"
                        pair_ok = false
                    )
                )
                if pair_ok then
                (
                    deleteItem pair_curve_nodes pair_index
                    deleteItem pair_source_indices pair_index
                )
            )
        )
        if pair_ok and inspection_pair > pair_curve_nodes.count then inspection_pair = 0
        if pair_ok then applyOutputVisibility()
        pair_ok
        -- return
    ),


    /*
    Creates a static spline from evaluated surfaces without registering callbacks.
    Kept as a public API for backward compatibility with 0.01.
    */
    function createFromSelection source_values position_precision_mm:0.01 =
    (
        local result_shape = undefined
        local position_precision = getPositionPrecision position_precision_mm


        if position_precision == undefined then
        (
            format "SURFACE INTERSECTIONS FAILED | Unsupported precision: % mm\n" position_precision_mm
        )
        else
        (
            local segments = collectAllSegments source_values position_precision


            if segments != undefined then
            (
                result_shape = makeSplineResult segments position_precision


                if result_shape == undefined then
                (
                    format "SURFACE INTERSECTIONS | No finite noncoplanar intersections.\n"
                )
            )
        )
        result_shape
        -- return
    ),


    /*
    Releases only monitoring resources, never deleting or changing the result node.
    */
    function detachMonitoring =
    (
        if live_timer != undefined then
        (
            live_timer.Stop()
            live_timer.Dispose()
            live_timer = undefined
        )


        if transform_handler != undefined then
        (
            deleteChangeHandler transform_handler
            transform_handler = undefined
        )


        if node_callback != undefined then
        (
            node_callback = undefined
            gc light:true
        )
        true
        -- return
    ),


    /*
    Compatibility method: automatic monitoring is disabled for on-demand output.
    Removes any previous watchers without registering callbacks or timers.
    */
    function attachMonitoring =
    (
        detachMonitoring()
        update_mode = #manual
        true
        -- return
    ),

    /*
    Ignores source notifications; only an explicit Generate / Update rebuilds.
    Kept for callbacks left over from earlier loaded versions.
    */
    function markDirty =
    (
        false
        -- return
    ),

    /*
    Explicitly rebuilds existing curves in place for Generate / Update.
    Returns true only if the new evaluated result has been written successfully.
    */
    function refresh =
    (
        local refresh_ok = false


        if update_mode == #freeze then
        (
            format "SURFACE INTERSECTIONS | Frozen: refresh skipped.\n"
        )
        else if is_rebuilding then
        (
            format "SURFACE INTERSECTIONS | Refresh already running.\n"
        )
        else if not (isValidNode result_node) then
        (
            format "SURFACE INTERSECTIONS FAILED | Bound curve node was deleted.\n"
        )
        else
        (
            is_rebuilding = true
            local position_precision = getPositionPrecision position_precision_mm


            if position_precision == undefined then
            (
                format "SURFACE INTERSECTIONS FAILED | Invalid precision: % mm\n" position_precision_mm
            )
            else
            (
                try
                (
                    local segments = collectAllSegments source_nodes position_precision
                    if segments != undefined then
                    (
                        refresh_ok = updateProcessResults position_precision source_nodes
                        if refresh_ok then
                        (
                            makeSplineResult segments position_precision result_shape:result_node keep_empty:true
                            refresh_ok = updateEndpointSlices position_precision
                            if refresh_ok then refresh_ok = updatePairResults position_precision
                            if refresh_ok then
                            (
                                nameLinkedResults()
                                if not (placeGeneratedResultsInLayers()) then
                                (
                                    format "SI LAYER WARNING | Geometry was updated, but some generated nodes were not layered.\n"
                                )
                                /* Endpoint Slices are updated explicitly with this generated result. */
                                applyOutputVisibility()
                                is_dirty = false
                                format "SURFACE INTERSECTIONS REFRESH | curves:% | segments:% | polygons:% | process steps:%\n" (numSplines result_node) segments.count (polyop.getNumFaces trimmed_result_node.baseObject) process_result_nodes.count
                            )
                            else format "SURFACE INTERSECTIONS REFRESH FAILED | Source-pair curves incomplete.\n"
                        )
                    )
                )
                catch
                (
                    local exception_text = getCurrentException()
                    format "SURFACE INTERSECTIONS REFRESH FAILED | %\n" exception_text
                )
            )
            is_rebuilding = false
        )
        refresh_ok
        -- return
    ),


    /*
    Accepts legacy saved modes but always uses on-demand manual updates.
    Clears existing watchers and pending dirty state without regenerating.
    */
    function setMode new_mode =
    (
        local mode_ok = (findItem #(#live, #manual, #freeze) new_mode) > 0
        if mode_ok then
        (
            detachMonitoring()
            update_mode = #manual
            is_dirty = false
        )
        else format "SURFACE INTERSECTIONS FAILED | Unknown mode: %\n" new_mode
        mode_ok
        -- return
    ),

    /*
    Generates once from supplied nodes; the legacy method name remains compatible.
    */
    function startLive source_values position_precision_mm:0.01 clip_modes:#() =
    (
        local new_result = undefined
        local position_precision = getPositionPrecision position_precision_mm


        if position_precision == undefined then
        (
            format "SURFACE INTERSECTIONS FAILED | Invalid precision: % mm\n" position_precision_mm
        )
        else
        (
            source_clip_modes = if clip_modes.count == source_values.count then (for item in clip_modes collect item) else (for source_node in source_values collect #auto)
            local segments = collectAllSegments source_values position_precision


            if segments != undefined then
            (
                detachMonitoring()
                source_nodes = for source_node in source_values collect source_node
                source_handles = for source_node in source_nodes collect (getHandleByAnim source_node)
                this.position_precision_mm = position_precision_mm
                update_mode = #manual
                is_dirty = false
                result_node = makeSplineResult segments position_precision result_shape:result_node keep_empty:true
                if isValidNode result_node and (updateProcessResults position_precision source_nodes) then
                (
                    if (updateEndpointSlices position_precision) and (updatePairResults position_precision) then
                    (
                        nameLinkedResults()
                        if not (placeGeneratedResultsInLayers()) then
                        (
                            format "SI LAYER WARNING | Geometry was generated, but some generated nodes were not layered.\n"
                        )
                        /* Endpoint Slices are updated explicitly with this generated result. */
                        applyOutputVisibility()
                        new_result = result_node
                    )
                    local mode_ok = if isValidNode new_result then (setMode #manual) else false
                    if mode_ok then
                    (
                        format "SURFACE INTERSECTIONS | Linked sources: % | curves: % | result: %\n" source_nodes.count (numSplines new_result) new_result.name
                    )
                    else format "SURFACE INTERSECTIONS | Could not finish the on-demand update state.\n"
                )
            )
        )
        new_result
        -- return
    ),


    /*
    Apply a new source priority order and per-source kept sides without replacing
    the existing output spline node or its modifier stack.
    */
    function setSourceOrder ordered_nodes clip_modes:#() position_precision_mm:0.01 =
    (
        local order_ok = false
        if ordered_nodes.count < 2 then
        (
            format "SI PRIORITY FAILED | Need at least two sources, actual:%\n" ordered_nodes.count
        )
        else if not isValidNode result_node then
        (
            format "SI PRIORITY FAILED | No active result; call startLive first.\n"
        )
        else
        (
            local original_mode = update_mode
            local previous_nodes = source_nodes
            local previous_handles = source_handles
            local previous_clip_modes = source_clip_modes
            local previous_precision = this.position_precision_mm
            detachMonitoring()
            update_mode = #manual
            source_nodes = for source_node in ordered_nodes collect source_node
            source_handles = for source_node in source_nodes collect (getHandleByAnim source_node)
            source_clip_modes = if clip_modes.count == ordered_nodes.count then (for mode_value in clip_modes collect mode_value) else (for source_node in ordered_nodes collect #auto)
            this.position_precision_mm = position_precision_mm
            order_ok = refresh()
            if order_ok then
            (
                if original_mode == #live then (setMode #live)
                else if original_mode == #freeze then (setMode #freeze)
            )
            else
            (
                source_nodes = previous_nodes
                source_handles = previous_handles
                source_clip_modes = previous_clip_modes
                this.position_precision_mm = previous_precision
                if original_mode == #live then (setMode #live)
                else if original_mode == #freeze then (setMode #freeze)
                format "SI PRIORITY FAILED | Previous source order restored.\n"
            )
        )
        order_ok
        -- return
    ),


    /*
    Stops live monitoring and keeps the latest result as an ordinary editable spline.
    */
    function stop =
    (
        detachMonitoring()
        update_mode = #manual
        is_dirty = false
        source_nodes = #()
        source_handles = #()
        source_clip_modes = #()
        hidden_edge_segments = #()
        visible_edge_segments = #()
        result_edge_segments = #()
        trim_boundary_segments = #()
        raw_trim_boundary_segments = #()
        slice_source_values = #()
        slice_boundary_sets = #()
        slice_pair_cuts = #()
        extended_cut_segments = #()
        si_live_source_nodes = #()
        result_node = undefined
        trimmed_result_node = undefined
        working_patch_sets = #()
        process_patch_sets = #()
        process_result_nodes = #()
        inspection_process = 0
        pair_segments_data = #()
        pair_curve_nodes = #()
        pair_source_indices = #()
        legacy_stage_nodes = #()
        inspection_pair = 0
        true
        -- return
    ),


    /*
    Deletes only this session's linked spline and trimmed-surface outputs.
    Live monitoring is detached before deletion. Input sources are protected.
    A failed deletion keeps remaining result references available for retry.
    */
    function deleteGeneratedResults =
    (
        local curve_output = result_node
        local surface_output = trimmed_result_node
        local deleted_count = 0
        local failed_count = 0

        detachMonitoring()
        update_mode = #manual
        is_dirty = false

        for slice_mod in (getOwnedEndpointSlices()) do
        (
            if not (removeEndpointSlice slice_mod) then failed_count += 1
        )
        /* Reset is explicit/confirmed in the UI: delete only THIS setup's tagged outputs. */
        local owner_handle = if isValidNode curve_output then (getHandleByAnim curve_output) as string else ""
        local owned_outputs = #()
        for candidate_node in (pair_curve_nodes + legacy_stage_nodes + process_result_nodes) do appendIfUnique owned_outputs candidate_node
        for generated_node in owned_outputs do
        (
            if isValidNode generated_node then
            (
                local pair_owner = getUserProp generated_node "SI_PairOwner"
                local stage_owner = getUserProp generated_node "SI_StageOwner"
                local process_owner = getUserProp generated_node "SI_ProcessOwner"
                local is_owned = owner_handle != "" and ((pair_owner != undefined and (pair_owner as string) == owner_handle) or (stage_owner != undefined and (stage_owner as string) == owner_handle) or (process_owner != undefined and (process_owner as string) == owner_handle))
                if (findItem source_nodes generated_node) > 0 or not is_owned then
                (
                    format "SI RESET FAILED | Skipped unowned or source node: %\n" generated_node.name
                    failed_count += 1
                )
                else
                (
                    try (delete generated_node) catch (format "SI RESET ERROR | Pair or legacy stage: %\n" (getCurrentException()))
                    if isValidNode generated_node then failed_count += 1 else deleted_count += 1
                )
            )
        )

        if isValidNode surface_output and (findItem owned_outputs surface_output) == 0 then
        (
            if (findItem source_nodes surface_output) > 0 then
            (
                format "SI RESET FAILED | Surface result is also an input source: %\n" surface_output.name
                failed_count += 1
            )
            else
            (
                try
                (
                    delete surface_output
                )
                catch
                (
                    format "SI RESET ERROR | Deleting surface result: %\n" (getCurrentException())
                )
                if isValidNode surface_output then failed_count += 1
                else deleted_count += 1
            )
        )

        if isValidNode curve_output then
        (
            if (findItem source_nodes curve_output) > 0 then
            (
                format "SI RESET FAILED | Curve result is also an input source: %\n" curve_output.name
                failed_count += 1
            )
            else
            (
                try
                (
                    delete curve_output
                )
                catch
                (
                    format "SI RESET ERROR | Deleting curve result: %\n" (getCurrentException())
                )
                if isValidNode curve_output then failed_count += 1
                else deleted_count += 1
            )
        )

        if failed_count == 0 then
        (
            stop()
            cleanupEmptyResultLayers owner_handle:owner_handle
            format "SI RESET | Deleted % generated result object(s); input sources preserved.\n" deleted_count
        )
        else
        (
            if not isValidNode trimmed_result_node then trimmed_result_node = undefined
            if not isValidNode result_node then result_node = undefined
            pair_curve_nodes = for curve_node in pair_curve_nodes where isValidNode curve_node collect curve_node
            process_result_nodes = for surface_node in process_result_nodes where isValidNode surface_node collect surface_node
            legacy_stage_nodes = for old_node in legacy_stage_nodes where isValidNode old_node collect old_node
            format "SI RESET FAILED | % generated result object(s) remain.\n" failed_count
        )

        (failed_count == 0)
        -- return
    ),


    /*
    Generates once from the current scene selection.
    */
    function run position_precision_mm:0.01 =
    (
        startLive (selection as array) position_precision_mm:position_precision_mm
        -- return
    ),


    /* Writes a fresh scene snapshot through the canonical DUMP logger.
    Source order, linked sources and current result are recorded without rebuilding geometry.
    */
    function writeDebug source_values clip_modes output_path logger_path ui_precision_mm:0.01 =
    (
        local debug_ok = false
        local temporary_mesh = undefined
        local report_stream = stringStream ""
        local debug_logger = undefined
        try
        (
            if not doesFileExist logger_path then
            (
                format "SI DEBUG FAILED | Missing canonical logger:%\n" logger_path
            )
            else
            (
                fileIn logger_path
                debug_logger = DumpDevLoggerStruct()
                if not (debug_logger.start output_path) then
                (
                    format "SI DEBUG FAILED | Cannot create log:%\n" output_path
                )
                else
                (
                    format "SI DEBUG | BEGIN | project:% backend:% time:% scene:% frame:%\n" si_project_version fn_file_version localTime (maxFilePath + maxFileName) currentTime to:report_stream
                    format "SETTINGS | intersection:% update:% dirty:% cumulative:true delete_trimmed:% UI_precision_mm:% linked_precision_mm:% system_type:% system_scale:%\n" intersection_mode update_mode is_dirty delete_trimmed ui_precision_mm position_precision_mm units.SystemType units.SystemScale to:report_stream
                    format "COORDINATES | WORLD | system units | XYZ components use 9 significant digits\n" to:report_stream
                    format "UI_SOURCES | count:% | current ordered list, possibly not yet applied\n" source_values.count to:report_stream
                    for row_index = 1 to source_values.count do
                    (
                        local source_node = source_values[row_index]
                        local kept_side = if row_index <= clip_modes.count then clip_modes[row_index] else #undefined
                        if isValidNode source_node then
                        (
                            format "UI_SOURCE | row:% handle:% name:% side:%\n" row_index (getHandleByAnim source_node) source_node.name kept_side to:report_stream
                        )
                        else
                        (
                            format "UI_SOURCE | row:% MISSING side:%\n" row_index kept_side to:report_stream
                        )
                    )
                    format "LINKED_SOURCES | count:% | currently linked to result\n" source_nodes.count to:report_stream
                    for row_index = 1 to source_nodes.count do
                    (
                        local source_node = source_nodes[row_index]
                        local kept_side = if row_index <= source_clip_modes.count then source_clip_modes[row_index] else #undefined
                        if isValidNode source_node then
                        (
                            format "LINKED_SOURCE | row:% handle:% name:% side:%\n" row_index (getHandleByAnim source_node) source_node.name kept_side to:report_stream
                        )
                        else
                        (
                            format "LINKED_SOURCE | row:% MISSING side:%\n" row_index kept_side to:report_stream
                        )
                    )
                    local debug_nodes = for source_node in source_values where isValidNode source_node collect source_node
                    for source_node in source_nodes where isValidNode source_node do appendIfUnique debug_nodes source_node
                    for source_node in debug_nodes do
                    (
                        local world_point = in coordsys world source_node.pos
                        format "OBJECT | handle:% name:% class:% position:[%,%,%]\n" (getHandleByAnim source_node) source_node.name (classOf source_node) (formattedPrint world_point.x format:".9g") (formattedPrint world_point.y format:".9g") (formattedPrint world_point.z format:".9g") to:report_stream
                        temporary_mesh = snapshotAsMesh source_node
                        format "EVALUATED_MESH | vertices:% triangles:%\n" (getNumVerts temporary_mesh) (getNumFaces temporary_mesh) to:report_stream
                        for vertex_index = 1 to (getNumVerts temporary_mesh) do
                        (
                            world_point = getVert temporary_mesh vertex_index
                            format "VERTEX | id:% world:[%,%,%]\n" vertex_index (formattedPrint world_point.x format:".9g") (formattedPrint world_point.y format:".9g") (formattedPrint world_point.z format:".9g") to:report_stream
                        )
                        for face_index = 1 to (getNumFaces temporary_mesh) do
                        (
                            format "TRIANGLE | id:% vertices:% visible_edges:[%,%,%]\n" face_index (getFace temporary_mesh face_index) (getEdgeVis temporary_mesh face_index 1) (getEdgeVis temporary_mesh face_index 2) (getEdgeVis temporary_mesh face_index 3) to:report_stream
                        )
                        delete temporary_mesh
                        temporary_mesh = undefined
                    )
                    if isValidNode result_node then
                    (
                        format "RESULT | handle:% name:% splines:%\n" (getHandleByAnim result_node) result_node.name (numSplines result_node) to:report_stream
                        for spline_index = 1 to (numSplines result_node) do
                        (
                            format "CURVE | spline:% knots:% closed:%\n" spline_index (numKnots result_node spline_index) (isClosed result_node spline_index) to:report_stream
                            for knot_index = 1 to (numKnots result_node spline_index) do
                            (
                                local world_point = in coordsys world (getKnotPoint result_node spline_index knot_index)
                                format "KNOT | spline:% knot:% world:[%,%,%]\n" spline_index knot_index (formattedPrint world_point.x format:".9g") (formattedPrint world_point.y format:".9g") (formattedPrint world_point.z format:".9g") to:report_stream
                            )
                        )
                    )
                    else
                    (
                        format "RESULT | MISSING | no valid linked intersection result\n" to:report_stream
                    )
                    format "SI DEBUG | END | capture complete\n" to:report_stream
                    debug_ok = debug_logger.log (report_stream as string)
                    if not debug_ok then format "SI DEBUG FAILED | Cannot write log:%\n" output_path
                )
            )
        )
        catch
        (
            local exception_text = getCurrentException()
            format "SI DEBUG FAILED | %\n" exception_text
            format "SI DEBUG | FAILED | incomplete capture | %\n" exception_text to:report_stream
            if temporary_mesh != undefined then delete temporary_mesh
            if debug_logger != undefined then debug_logger.log (report_stream as string)
            debug_ok = false
        )
        close report_stream
        debug_ok
        -- return
    ),


    on create do
    (
        if si_project_version == undefined then
        (
            si_project_version = project_version
        )
        else if (si_project_version as float) < (project_version as float) then
        (
            si_project_version = project_version
        )
    )
)


/*
Persistent trim forest: scene references live on a separate hidden catalog.
Catalog references cannot form a modifier/host or controller/self dependency.
*/
global si_hierarchy_definition = attributes SI_HierarchyCatalog attribID:#(0x398da421,0x297de165) version:1
(
    parameters graph
    (
        schema_version type:#integer default:1
        item_kinds type:#stringTab tabSize:0 tabSizeVariable:true
        scene_nodes type:#nodeTab tabSize:0 tabSizeVariable:true
        controllers type:#nodeTab tabSize:0 tabSizeVariable:true
        children_values type:#stringTab tabSize:0 tabSizeVariable:true
        side_values type:#stringTab tabSize:0 tabSizeVariable:true
        precision_values type:#floatTab tabSize:0 tabSizeVariable:true
        delete_values type:#intTab tabSize:0 tabSizeVariable:true
        root_values type:#intTab tabSize:0 tabSizeVariable:true
        latest_id type:#integer default:0
    )
)

/*
Marks only Symmetry instances generated by this hierarchy.
Never adopts or deletes manually created Symmetry modifiers.
*/
global si_root_symmetry_ca = attributes SI_RootSymmetry attribID:#(0x39a65419,0x28f1774a) version:1
(
    parameters owner
    (
        catalog_key type:#string default:""
        item_id type:#integer default:0
        axis_index type:#integer default:-1
    )
)

/*
A source, original 3ds Max scene group, or generated intersection operation; IDs stay stable within a catalog.
*/
struct SIHierarchyItem_v
(
    item_id = 0,
    kind = #source,
    scene_node = undefined,
    controller_node = undefined,
    child_ids = #(),
    keep_mode = #auto,
    precision_mm = 0.01,
    delete_trimmed = true,
    symmetry_enabled = false,
    symmetry_mask = 1,
    engine = undefined,
    pending = true,
    on create do ()
)

/*
Owns an ordered forest of explicit trim groups using the existing geometry engine.
Scene groups retain their native group head and expose original geometry children.
Generated result groups evaluate scene-group children in order without snapshotting a helper.
*/
struct SIHierarchy_v
(
    items = #(),
    root_ids = #(),
    catalog_node = undefined,
    latest_id = 0,
    last_error = "",
    is_generating = false,

    /*
    Collects reachable IDs and detects shared descendants and cycles.
    */
    function collectIds item_id visited_ids =
    (
        local valid = item_id >= 1 and item_id <= items.count
        if valid then valid = (findItem visited_ids item_id) == 0
        if valid then
        (
            append visited_ids item_id
            for child_id in items[item_id].child_ids while valid do valid = this.collectIds child_id visited_ids
        )
        valid
        -- return
    ),

    /*
    Rejects missing IDs, cycles, multiple parents and undersized operations.
    */
    function isValidForest =
    (
        local visited_ids = #()
        local valid = true
        for item_id in root_ids while valid do valid = collectIds item_id visited_ids
        for item_id in visited_ids while valid do
        (
            local item_value = items[item_id]
            valid = item_value.item_id == item_id
            if item_value.kind == #group then
            (
                valid = valid and (item_value.child_ids.count >= 2 or (item_value.child_ids.count == 1 and item_value.child_ids[1] >= 1 and item_value.child_ids[1] <= items.count and items[item_value.child_ids[1]].kind == #scene_group))
            )
            else if item_value.kind == #scene_group then
            (
                valid = valid and item_value.child_ids.count > 0 and isValidNode item_value.scene_node and isGroupHead item_value.scene_node
            )
            else valid = valid and item_value.kind == #source and item_value.child_ids.count == 0
        )
        if not valid then last_error = "Invalid trim hierarchy: missing input, shared descendant or cycle."
        valid
        -- return
    ),

    /*
    Finds the active parent of a visible item without following inactive history.
    */
    function getParentId item_id =
    (
        local reachable = #()
        for root_id in root_ids do collectIds root_id reachable
        local parent_id = 0
        for candidate_id in reachable while parent_id == 0 do
        (
            if (findItem items[candidate_id].child_ids item_id) > 0 then parent_id = candidate_id
        )
        parent_id
        -- return
    ),

    /*
    Resolves the outermost native 3ds Max group head for a source or group member.
    A result-object parent does not count as a native scene group.
    */
    function getSceneGroupHead source_node =
    (
        local candidate = source_node
        local group_head = undefined
        while isValidNode candidate do
        (
            if isGroupHead candidate then group_head = candidate
            candidate = candidate.parent
        )
        group_head
        -- return
    ),

    /*
    Imports an original native group and its hierarchy using real scene children.
    Geometry members remain sources; group-head helpers are never mesh inputs.
    Existing nested source memberships are not duplicated in the trim forest.
    */
    function ensureSceneGroup group_head =
    (
        local group_id = 0
        if isValidNode group_head and isGroupHead group_head then
        (
            for item_value in items while group_id == 0 do
            (
                if item_value.kind == #scene_group and item_value.scene_node == group_head then group_id = item_value.item_id
            )
            if group_id == 0 then
            (
                group_id = items.count + 1
                append items (SIHierarchyItem_v item_id:group_id kind:#scene_group scene_node:group_head controller_node:group_head.parent)
                for child_node in group_head.children do
                (
                    local member_id = 0
                    if isGroupHead child_node then member_id = this.ensureSceneGroup child_node
                    else if (superClassOf child_node == GeometryClass) and ((getUserProp child_node "SI_ProcessOwner") == undefined) then
                    (
                        for item_value in items while member_id == 0 do
                        (
                            if item_value.kind == #source and item_value.scene_node == child_node then member_id = item_value.item_id
                        )
                        if member_id == 0 then
                        (
                            member_id = items.count + 1
                            append items (SIHierarchyItem_v item_id:member_id kind:#source scene_node:child_node)
                        )
                    )
                    if member_id > 0 then
                    (
                        local other_parent_id = getParentId member_id
                        if other_parent_id == 0 then
                        (
                            local loose_index = findItem root_ids member_id
                            if loose_index > 0 then deleteItem root_ids loose_index
                            appendIfUnique items[group_id].child_ids member_id
                        )
                        else if other_parent_id != group_id then
                        (
                            format "SI GROUP IMPORT SKIPPED | % already belongs to hierarchy item %\n" child_node.name other_parent_id
                        )
                    )
                )
                if items[group_id].child_ids.count == 0 then
                (
                    format "SI GROUP IMPORT FAILED | Native group % contains no usable original geometry.\n" group_head.name
                    group_id = 0
                )
            )
        )
        group_id
        -- return
    ),

    /*
    Reconciles member rows with native group children when an explicit rebuild occurs.
    Only original geometry and nested native group heads may be imported.
    */
    function syncSceneGroupMembers =
    (
        local reachable_ids = #()
        for root_id in root_ids do collectIds root_id reachable_ids
        local changed = false
        for group_id in reachable_ids do
        (
            if items[group_id].kind == #scene_group then
            (
                local source_group = items[group_id]
                local group_head = source_group.scene_node
                if isValidNode group_head and isGroupHead group_head then
                (
                    local next_children = #()
                    for child_node in group_head.children do
                    (
                        local member_id = 0
                        if isGroupHead child_node then member_id = this.ensureSceneGroup child_node
                        else if superClassOf child_node == GeometryClass and (getUserProp child_node "SI_ProcessOwner") == undefined then
                        (
                            for item_value in items while member_id == 0 do
                            (
                                if item_value.kind == #source and item_value.scene_node == child_node then member_id = item_value.item_id
                            )
                            if member_id == 0 then
                            (
                                member_id = items.count + 1
                                append items (SIHierarchyItem_v item_id:member_id kind:#source scene_node:child_node)
                            )
                        )
                        if member_id > 0 then
                        (
                            local current_parent = getParentId member_id
                            if current_parent == 0 or current_parent == group_id then
                            (
                                appendIfUnique next_children member_id
                                local loose_index = findItem root_ids member_id
                                if loose_index > 0 then deleteItem root_ids loose_index
                            )
                            else format "SI SCENE GROUP SYNC SKIPPED | Member % already belongs to hierarchy item %\n" child_node.name current_parent
                        )
                    )
                    local membership_changed = next_children.count != source_group.child_ids.count
                    if not membership_changed then
                    (
                        for member_index = 1 to next_children.count while not membership_changed do
                        (
                            membership_changed = next_children[member_index] != source_group.child_ids[member_index]
                        )
                    )
                    if membership_changed then
                    (
                        source_group.child_ids = next_children
                        changed = true
                    )
                )
                else
                (
                    last_error = "Native group head was deleted or is no longer a group."
                )
            )
        )
        if changed then
        (
            for item_value in items where item_value.kind == #group do item_value.pending = true
            format "SI SCENE GROUP SYNC | Changed native member membership.\n"
        )
        changed
        -- return
    ),

    /*
    Counts original geometry leaves inside one native scene-group item.
    */
    function countSceneGroupSurfaces item_id =
    (
        local surface_count = 0
        if item_id >= 1 and item_id <= items.count then
        (
            local item_value = items[item_id]
            if item_value.kind == #source then surface_count = 1
            else if item_value.kind == #scene_group then
            (
                for child_id in item_value.child_ids do surface_count += this.countSceneGroupSurfaces child_id
            )
        )
        surface_count
        -- return
    ),

    /*
    Adds original geometry once; a selected native group is one hierarchy branch.
    */
    function addSources source_values =
    (
        local added_count = 0
        for selected_node in source_values where isValidNode selected_node do
        (
            local group_head = this.getSceneGroupHead selected_node
            local source_id = 0
            if isValidNode group_head then source_id = this.ensureSceneGroup group_head
            else if (superClassOf selected_node == GeometryClass) and ((getUserProp selected_node "SI_ProcessOwner") == undefined) then
            (
                for item_value in items while source_id == 0 do
                (
                    if item_value.kind == #source and item_value.scene_node == selected_node then source_id = item_value.item_id
                )
                if source_id == 0 then
                (
                    source_id = items.count + 1
                    append items (SIHierarchyItem_v item_id:source_id kind:#source scene_node:selected_node)
                )
            )
            if source_id > 0 and (findItem root_ids source_id) == 0 and (getParentId source_id) == 0 then
            (
                append root_ids source_id
                added_count += 1
            )
        )
        added_count
        -- return
    ),

    /*
    Appends original geometry to a reachable result group without rebuilding it.
    Existing loose source rows are moved into the group; nested sources are never duplicated.
    */
    function addSelectionToGroup group_id source_values =
    (
        local added_count = 0
        local reachable_ids = #()
        for root_id in root_ids do collectIds root_id reachable_ids
        local valid_group = (findItem reachable_ids group_id) > 0
        if valid_group then valid_group = items[group_id].kind == #group and not is_generating
        if valid_group then
        (
            for selected_node in source_values where isValidNode selected_node do
            (
                local source_node = this.getSceneGroupHead selected_node
                if not (isValidNode source_node) then source_node = selected_node
                local valid_source = (isGroupHead source_node or superClassOf source_node == GeometryClass) and ((getUserProp source_node "SI_ProcessOwner") == undefined)
                if valid_source then
                (
                    for item_id in reachable_ids while valid_source do
                    (
                        local item_value = items[item_id]
                        if item_value.kind == #group then
                        (
                            if item_value.scene_node == source_node or item_value.controller_node == source_node then valid_source = false
                        )
                    )
                )
                if valid_source then
                (
                    /* This may create a new loose scene-group tree before moving it. */
                    this.addSources #(source_node)
                    local source_id = 0
                    for item_value in items while source_id == 0 do
                    (
                        if (item_value.kind == #source or item_value.kind == #scene_group) and item_value.scene_node == source_node then source_id = item_value.item_id
                    )
                    if source_id > 0 then
                    (
                        local root_index = findItem root_ids source_id
                        if root_index > 0 then
                        (
                            deleteItem root_ids root_index
                            appendIfUnique items[group_id].child_ids source_id
                            added_count += 1
                        )
                    )
                )
            )
            if added_count > 0 then
            (
                local dirty_id = group_id
                while dirty_id > 0 do
                (
                    items[dirty_id].pending = true
                    dirty_id = getParentId dirty_id
                )
                last_error = ""
            )
            else last_error = "No new original source or native group in the scene selection."
        )
        else last_error = "Target must be a visible result group and generation must be idle."
        added_count
        -- return
    ),

    /*
    Wraps selected roots in their visible order; ancestors and descendants cannot mix.
    Returns zero on invalid input without changing the forest.
    */
    function groupRoots selected_ids =
    (
        local unique_ids = #()
        local valid = selected_ids.count >= 2
        if selected_ids.count == 1 then valid = items[selected_ids[1]].kind == #scene_group and (this.countSceneGroupSurfaces selected_ids[1]) >= 2
        for item_id in selected_ids do
        (
            if (findItem root_ids item_id) == 0 or (findItem unique_ids item_id) > 0 then valid = false
            append unique_ids item_id
        )
        local group_id = 0
        if valid then
        (
            local ordered_ids = for item_id in root_ids where (findItem selected_ids item_id) > 0 collect item_id
            local next_roots = #()
            group_id = items.count + 1
            local inserted = false
            for item_id in root_ids do
            (
                if (findItem ordered_ids item_id) > 0 then
                (
                    if not inserted then
                    (
                        append next_roots group_id
                        inserted = true
                    )
                )
                else append next_roots item_id
            )
            append items (SIHierarchyItem_v item_id:group_id kind:#group child_ids:ordered_ids)
            root_ids = next_roots
        )
        else last_error = "Check two top-level inputs, or one native scene group containing two or more surfaces."
        group_id
        -- return
    ),

    /*
    Checks whether an intersection-result wrapper can be removed without invalidating the forest.
    Returns #(parent_id, replacement_siblings) without retaining any hierarchy mutations.
    */
    function planResultRemoval item_id =
    (
        local planned = #()
        local reachable_ids = #()
        for root_id in root_ids do collectIds root_id reachable_ids
        if not is_generating and item_id >= 1 and item_id <= items.count and (findItem reachable_ids item_id) > 0 and items[item_id].kind == #group then
        (
            local parent_id = getParentId item_id
            local sibling_ids = if parent_id == 0 then copy root_ids #noMap else copy items[parent_id].child_ids #noMap
            local target_index = findItem sibling_ids item_id
            if target_index > 0 then
            (
                local replacement_ids = copy sibling_ids #noMap
                deleteItem replacement_ids target_index
                for child_index = items[item_id].child_ids.count to 1 by -1 do
                (
                    insertItem items[item_id].child_ids[child_index] replacement_ids target_index
                )
                if parent_id == 0 then root_ids = replacement_ids else items[parent_id].child_ids = replacement_ids
                local is_valid = isValidForest()
                if parent_id == 0 then root_ids = sibling_ids else items[parent_id].child_ids = sibling_ids
                if is_valid then planned = #(parent_id,replacement_ids)
            )
        )
        if planned.count != 2 then last_error = "Cannot remove this result without invalidating the source hierarchy."
        planned
        -- return
    ),

    /*
    Removes one generated intersection result and dissolves its wrapper into the parent level.
    Original geometry and other child results survive, including native group links and transforms.
    */
    function removeResultItem item_id only_final:true =
    (
        local removed = false
        local plan = this.planResultRemoval item_id
        if plan.count == 2 and isValidNode items[item_id].scene_node and not (isValidNode items[item_id].controller_node) then
        (
            last_error = "Cannot safely delete the result surface: its owned controller is missing."
            plan = #()
        )
        if plan.count == 2 then
        (
            local item_value = items[item_id]
            local saved_child_count = item_value.child_ids.count
            local old_result_node = item_value.scene_node
            local saved_links = #()
            local detach_ok = true
            for child_id in item_value.child_ids while detach_ok do
            (
                local child_item = items[child_id]
                if child_item.kind == #scene_group and isValidNode child_item.scene_node and isValidNode old_result_node and child_item.scene_node.parent == old_result_node then
                (
                    local group_head = child_item.scene_node
                    local original_parent = if isValidNode child_item.controller_node and child_item.controller_node != old_result_node then child_item.controller_node else undefined
                    local saved_transform = group_head.transform
                    append saved_links #(group_head,old_result_node,saved_transform)
                    try
                    (
                        group_head.parent = original_parent
                        group_head.transform = saved_transform
                        detach_ok = group_head.parent == original_parent
                    )
                    catch
                    (
                        detach_ok = false
                        last_error = getCurrentException()
                    )
                )
            )
            if detach_ok then
            (
                local engine_value = getEngine item_id
                local delete_ok = if isValidNode item_value.scene_node or isValidNode item_value.controller_node then engine_value.deleteGeneratedResults() else true
                if delete_ok then
                (
                    local parent_id = plan[1]
                    if parent_id == 0 then root_ids = plan[2] else items[parent_id].child_ids = plan[2]
                    item_value.child_ids = #()
                    item_value.scene_node = undefined
                    item_value.controller_node = undefined
                    item_value.engine = undefined
                    item_value.pending = true
                    while parent_id > 0 do
                    (
                        items[parent_id].pending = true
                        parent_id = getParentId parent_id
                    )
                    local active_ids = #()
                    for root_id in root_ids do collectIds root_id active_ids
                    if (findItem active_ids latest_id) == 0 then
                    (
                        latest_id = 0
                        for active_id in active_ids where items[active_id].kind == #group and isValidNode items[active_id].scene_node do latest_id = active_id
                    )
                    local has_active_result = false
                    for active_id in active_ids while not has_active_result do
                    (
                        has_active_result = items[active_id].kind == #group and isValidNode items[active_id].controller_node
                    )
                    if has_active_result then saveCatalog()
                    else
                    (
                        if isValidNode catalog_node then delete catalog_node
                        catalog_node = undefined
                    )
                    this.applyVisibility only_final
                    if not (this.syncRootSymmetry()) then format "SI REMOVE RESULT | Symmetry reconciliation incomplete.\n"
                    last_error = ""
                    removed = true
                    format "SI REMOVE RESULT | Removed group:%; preserved % child inputs.\n" item_id saved_child_count
                )
                else last_error = "Failed deleting the selected result. Source hierarchy was retained; retry or inspect Listener."
            )
            else last_error = "Unable to detach a native group head before deleting its result."
            if not removed then
            (
                /* Restore links wherever their former generated parent still exists. */
                for link_data in saved_links do
                (
                    if isValidNode link_data[1] and isValidNode link_data[2] then
                    (
                        try
                        (
                            link_data[1].parent = link_data[2]
                            link_data[1].transform = link_data[3]
                        )
                        catch (format "SI REMOVE RESULT | Cannot restore group head: %\n" (getCurrentException()))
                    )
                )
            )
        )
        removed
        -- return
    ),

    /*
    Changes sibling order only; geometry waits for explicit Generate / Update.
    */
    function moveItem item_id movement to_boundary:false =
    (
        local parent_id = getParentId item_id
        local sibling_ids = if parent_id == 0 then copy root_ids #noMap else copy items[parent_id].child_ids #noMap
        local old_index = findItem sibling_ids item_id
        local moved = false
        if old_index > 0 then
        (
            local new_index = if to_boundary then (if movement < 0 then 1 else sibling_ids.count) else old_index + movement
            if new_index >= 1 and new_index <= sibling_ids.count and new_index != old_index then
            (
                deleteItem sibling_ids old_index
                insertItem item_id sibling_ids new_index
                if parent_id == 0 then root_ids = sibling_ids else items[parent_id].child_ids = sibling_ids
                for item_value in items where item_value.kind == #group do item_value.pending = true
                moved = true
            )
        )
        moved
        -- return
    ),

    /*
    Removes a root row or dissolves its group, preserving all scene objects.
    */
    function removeRoot item_id =
    (
        local root_index = findItem root_ids item_id
        local removed = root_index > 0
        if removed then
        (
            deleteItem root_ids root_index
            if items[item_id].kind == #group then
            (
                for child_index = items[item_id].child_ids.count to 1 by -1 do insertItem items[item_id].child_ids[child_index] root_ids root_index
            )
        )
        else last_error = "Remove top-level rows only; dissolve the parent group first."
        removed
        -- return
    ),

    /*
    Restores exact generated node references into one independent backend instance.
    */
    function getEngine item_id =
    (
        local item_value = items[item_id]
        if item_value.engine == undefined then
        (
            item_value.engine = SurfaceIntersections_v()
            if isValidNode item_value.controller_node then
            (
                item_value.engine.result_node = item_value.controller_node
                item_value.engine.restorePairNodes()
                if isValidNode item_value.scene_node then item_value.engine.trimmed_result_node = item_value.scene_node
            )
        )
        item_value.engine
        -- return
    ),

    /*
    Returns the current hierarchy key; an invalid catalog has no modifier ownership.
    */
    function getSymmetryCatalogKey =
    (
        if isValidNode catalog_node then (getUserProp catalog_node "SI_HierarchyKey") else undefined
        -- return
    ),

    /*
    Identifies an owned native Symmetry modifier for this exact group and axis.
    Other artist modifiers are never adopted by class or display name.
    */
    function isOwnedSymmetry stack_mod item_id axis_index:-1 =
    (
        local owned = false
        local owner_key = getSymmetryCatalogKey()
        if owner_key != undefined and classOf stack_mod == Symmetry then
        (
            local tag_value = custAttributes.get stack_mod si_root_symmetry_ca
            if tag_value != undefined then
            (
                owned = tag_value.catalog_key == (owner_key as string) and tag_value.item_id == item_id
                if axis_index >= 0 then owned = owned and tag_value.axis_index == axis_index
            )
        )
        owned
        -- return
    ),

    /*
    Disables all owned Symmetry modifiers before mesh evaluation.
    Child modifiers are removed on success, not on failure, preserving their gizmos.
    */
    function prepareSymmetryForGeneration =
    (
        for item_value in items where item_value.kind == #group and isValidNode item_value.scene_node do
        (
            local is_root = (findItem root_ids item_value.item_id) > 0
            for mod_index = item_value.scene_node.modifiers.count to 1 by -1 do
            (
                local stack_mod = item_value.scene_node.modifiers[mod_index]
                if isOwnedSymmetry stack_mod item_value.item_id then
                (
                    /* Defer physical child removal until successful generation.
                       Disabled modifiers do not affect snapshots; failure preserves gizmos. */
                    stack_mod.enabled = false
                )
            )
        )
        true
        -- return
    ),

    /*
    Restores existing owned modifiers after a failed generation, preserving gizmos.
    No modifier instance is removed until a successful dependency evaluation.
    */
    function restoreSymmetryAfterFailure =
    (
        for item_value in items where item_value.kind == #group and isValidNode item_value.scene_node do
        (
            for stack_mod in item_value.scene_node.modifiers do
            (
                if isOwnedSymmetry stack_mod item_value.item_id then stack_mod.enabled = true
            )
        )
        true
        -- return
    ),

    /*
    Reconciles X/Y/Z-owned modifier stacks only on current top-level result groups.
    Uses a separate native Symmetry instance per axis, preserving existing gizmos.
    */
    function syncRootSymmetry =
    (
        local owner_key = getSymmetryCatalogKey()
        local applied = true
        for item_value in items where applied and item_value.kind == #group and isValidNode item_value.scene_node do
        (
            local root_item = (findItem root_ids item_value.item_id) > 0
            local mask_value = if root_item and item_value.symmetry_enabled then item_value.symmetry_mask else 0
            local kept_axes = #()
            for mod_index = item_value.scene_node.modifiers.count to 1 by -1 do
            (
                local stack_mod = item_value.scene_node.modifiers[mod_index]
                if isOwnedSymmetry stack_mod item_value.item_id then
                (
                    local tag_value = custAttributes.get stack_mod si_root_symmetry_ca
                    local axis_index = tag_value.axis_index
                    local axis_bit = case axis_index of
                    (
                        0: 1
                        1: 2
                        2: 4
                        default: 0
                    )
                    if axis_bit == 0 or (bit.and mask_value axis_bit) == 0 or (findItem kept_axes axis_index) > 0 then
                    (
                        deleteModifier item_value.scene_node mod_index
                    )
                    else
                    (
                        append kept_axes axis_index
                        stack_mod.enabled = true
                    )
                )
            )
            if mask_value > 0 then
            (
                if owner_key == undefined then throw "SI SYMMETRY FAILED | Hierarchy catalog key is missing."
                for axis_index = 0 to 2 do
                (
                    local axis_bit = case axis_index of
                    (
                        0: 1
                        1: 2
                        2: 4
                    )
                    if (bit.and mask_value axis_bit) != 0 and (findItem kept_axes axis_index) == 0 then
                    (
                        local sym_mod = Symmetry()
                        sym_mod.axis = axis_index
                        custAttributes.add sym_mod si_root_symmetry_ca
                        sym_mod.SI_RootSymmetry.catalog_key = owner_key as string
                        sym_mod.SI_RootSymmetry.item_id = item_value.item_id
                        sym_mod.SI_RootSymmetry.axis_index = axis_index
                        sym_mod.name = "SI Symmetry " + #("X","Y","Z")[axis_index+1]
                        addModifier item_value.scene_node sym_mod
                        applied = applied and (findItem (for check_mod in item_value.scene_node.modifiers collect check_mod) sym_mod) > 0
                    )
                )
            )
        )
        applied
        -- return
    ),

    /*
    Rejects artist-owned Symmetry on child group results before reading evaluated geometry.
    Tool-owned child modifiers are disabled by prepareSymmetryForGeneration.
    */
    function validateChildSymmetry item_id =
    (
        local valid = true
        if items[item_id].kind == #group and isValidNode items[item_id].scene_node then
        (
            for stack_mod in items[item_id].scene_node.modifiers where classOf stack_mod == Symmetry do
            (
                if stack_mod.enabled and not (isOwnedSymmetry stack_mod item_id) then valid = false
            )
        )
        if not valid then throw ("SI SYMMETRY FAILED | Disable artist Symmetry on child group " + (item_id as string) + " before intersection.")
        valid
        -- return
    ),

    /*
    Expands native group helper branches to ordered original geometry inputs.
    No snapshot is ever requested from a helper or dummy.
    */
    function appendSceneGroupInputs item_id input_nodes input_modes =
    (
        local item_value = items[item_id]
        if item_value.kind == #source then
        (
            if not (isValidNode item_value.scene_node) then throw ("SI SCENE GROUP | Missing member " + (item_id as string))
            if superClassOf item_value.scene_node != GeometryClass then throw ("SI SCENE GROUP | Non-geometry member " + (item_id as string))
            append input_nodes item_value.scene_node
            append input_modes item_value.keep_mode
        )
        else if item_value.kind == #scene_group then
        (
            if not (isValidNode item_value.scene_node and isGroupHead item_value.scene_node) then throw ("SI SCENE GROUP | Missing native group head " + (item_id as string))
            for child_id in item_value.child_ids do this.appendSceneGroupInputs child_id input_nodes input_modes
        )
        else throw ("SI SCENE GROUP | Invalid nested hierarchy item " + (item_id as string))
        true
        -- return
    ),

    /*
    Links direct native group branches under their generated result, preserving group world transforms.
    Records the prior parent in the catalog so Reset can restore original scene placement.
    */
    function linkSceneGroups item_id result_node =
    (
        for child_id in items[item_id].child_ids do
        (
            local source_item = items[child_id]
            if source_item.kind == #scene_group and isValidNode source_item.scene_node then
            (
                local group_head = source_item.scene_node
                if not (isGroupHead group_head) then throw ("SI SCENE GROUP | Lost native group status: " + group_head.name)
                if group_head.parent != result_node then
                (
                    local world_transform = group_head.transform
                    group_head.parent = result_node
                    group_head.transform = world_transform
                    if group_head.parent != result_node then throw ("SI SCENE GROUP | Cannot parent group head under result: " + group_head.name)
                )
            )
        )
        true
        -- return
    ),

    /*
    Restores native scene group parent links before generated output nodes are deleted.
    */
    function restoreSceneGroupLinks =
    (
        local restored = true
        for item_value in items where item_value.kind == #scene_group and isValidNode item_value.scene_node do
        (
            local group_head = item_value.scene_node
            local original_parent = item_value.controller_node
            local actual_parent = group_head.parent
            local owned_result = false
            for result_item in items while not owned_result do
            (
                if result_item.kind == #group and result_item.scene_node == actual_parent then owned_result = true
            )
            if owned_result then
            (
                local world_transform = group_head.transform
                group_head.parent = if isValidNode original_parent then original_parent else undefined
                group_head.transform = world_transform
                restored = restored and group_head.parent == (if isValidNode original_parent then original_parent else undefined)
            )
        )
        if not restored then last_error = "Could not restore all native group links. Generated result deletion was cancelled."
        restored
        -- return
    ),

    /*
    Evaluates dependencies in postorder using real member meshes from native groups.
    Generated-result children retain their separate evaluated result identities.
    */
    function generateItem item_id path_ids =
    (
        if (findItem path_ids item_id) > 0 then throw "SI HIERARCHY FAILED | Cyclic trim dependency."
        local item_value = items[item_id]
        if item_value.kind == #source then
        (
            if not (isValidNode item_value.scene_node) then throw ("SI HIERARCHY FAILED | Missing source item " + (item_id as string))
            item_value.scene_node
        )
        else if item_value.kind == #scene_group then
        (
            /* Scene group is a container, not an independently evaluated geometry node. */
            item_value.scene_node
        )
        else
        (
            local child_nodes = #()
            local child_modes = #()
            local next_path = copy path_ids #noMap
            append next_path item_id
            for child_id in item_value.child_ids do
            (
                if items[child_id].kind == #scene_group then this.appendSceneGroupInputs child_id child_nodes child_modes
                else
                (
                    local child_node = this.generateItem child_id next_path
                    validateChildSymmetry child_id
                    append child_nodes child_node
                    append child_modes items[child_id].keep_mode
                )
            )
            if child_nodes.count < 2 then throw ("SI HIERARCHY FAILED | Group " + (item_id as string) + " requires at least two source surfaces.")
            local engine_value = getEngine item_id
            engine_value.only_final_result = true
            engine_value.delete_trimmed = item_value.delete_trimmed
            engine_value.endpoint_slice_enabled = false
            local generated = undefined
            local source_membership_changed = engine_value.source_nodes.count != child_nodes.count
            if not source_membership_changed then
            (
                for source_index = 1 to child_nodes.count while not source_membership_changed do
                (
                    if engine_value.source_nodes[source_index] != child_nodes[source_index] then source_membership_changed = true
                )
            )
            if (not isValidNode engine_value.result_node) or source_membership_changed or item_value.pending then
            (
                /* Regenerate ALL cumulative steps from the hierarchy's current children. */
                format "SI REBUILD | group:% sources:% membership_changed:% pending:%\n" item_id child_nodes.count source_membership_changed item_value.pending
                generated = engine_value.startLive child_nodes position_precision_mm:item_value.precision_mm clip_modes:child_modes
            )
            else if engine_value.setSourceOrder child_nodes clip_modes:child_modes position_precision_mm:item_value.precision_mm then generated = engine_value.result_node
            if not (isValidNode generated and isValidNode engine_value.trimmed_result_node) then throw ("SI HIERARCHY FAILED | Cannot generate group " + (item_id as string))
            local expected_stages = child_nodes.count - 1
            if engine_value.process_patch_sets.count != expected_stages then
            (
                throw ("SI HIERARCHY FAILED | Incomplete rebuilt group " + (item_id as string) + ": expected " + (expected_stages as string) + " cumulative stages, got " + (engine_value.process_patch_sets.count as string))
            )
            local applied_sources_match = engine_value.source_nodes.count == child_nodes.count
            if applied_sources_match then
            (
                for source_index = 1 to child_nodes.count while applied_sources_match do
                (
                    applied_sources_match = engine_value.source_nodes[source_index] == child_nodes[source_index]
                )
            )
            if not applied_sources_match then throw ("SI HIERARCHY FAILED | Group " + (item_id as string) + " did not apply its updated source membership.")
            item_value.controller_node = generated
            item_value.scene_node = engine_value.trimmed_result_node
            this.linkSceneGroups item_id item_value.scene_node
            item_value.pending = false
            item_value.scene_node
        )
        -- return
    ),

    /*
    Persists real node references and ordered group membership on one hidden catalog.
    String input IDs are parsed numerically, never executed as MaxScript.
    */
    function saveCatalog =
    (
        local has_groups = false
        for item_value in items while not has_groups do has_groups = item_value.kind == #group and isValidNode item_value.controller_node
        if has_groups then
        (
            if not (isValidNode catalog_node) then
            (
                catalog_node = SplineShape name:"SI Trim Hierarchy"
                custAttributes.add catalog_node si_hierarchy_definition baseObject:false
                setUserProp catalog_node "SI_HierarchyCatalog" "1"
                setUserProp catalog_node "SI_HierarchyKey" (((dotNetClass "System.Guid").NewGuid()).ToString "N")
                hide catalog_node
                catalog_node.renderable = false
            )
            local graph_data = custAttributes.get catalog_node si_hierarchy_definition baseObject:false
            graph_data.item_kinds = for item_value in items collect (item_value.kind as string)
            graph_data.scene_nodes = for item_value in items collect (if isValidNode item_value.scene_node then item_value.scene_node else undefined)
            graph_data.controllers = for item_value in items collect (if isValidNode item_value.controller_node then item_value.controller_node else undefined)
            graph_data.children_values = for item_value in items collect
            (
                local encoded = ""
                for child_id in item_value.child_ids do encoded += (child_id as string) + ","
                encoded
            )
            graph_data.side_values = for item_value in items collect (item_value.keep_mode as string)
            graph_data.precision_values = for item_value in items collect item_value.precision_mm
            graph_data.delete_values = for item_value in items collect (if item_value.delete_trimmed then 1 else 0)
            graph_data.root_values = root_ids
            graph_data.latest_id = latest_id
            local catalog_key = getUserProp catalog_node "SI_HierarchyKey"
            for item_value in items where item_value.kind == #group do
            (
                for linked_node in #(item_value.scene_node,item_value.controller_node) where isValidNode linked_node do setUserProp linked_node "SI_HierarchyKey" catalog_key
                if isValidNode item_value.scene_node then
                (
                    setUserProp item_value.scene_node "SI_RootSymmetryEnabled" (if item_value.symmetry_enabled then "1" else "0")
                    setUserProp item_value.scene_node "SI_RootSymmetryMask" (item_value.symmetry_mask as string)
                )
            )
        )
        has_groups
        -- return
    ),

    /*
    Loads a saved catalog without generating, selecting or deleting scene objects.
    Invalid graphs fail before replacing this manager's current state.
    */
    function loadCatalog target_node =
    (
        local graph_data = if isValidNode target_node then custAttributes.get target_node si_hierarchy_definition baseObject:false else undefined
        local loaded = graph_data != undefined and graph_data.schema_version == 1
        local decoded_items = #()
        if loaded then
        (
            local item_count = graph_data.item_kinds.count
            loaded = graph_data.scene_nodes.count == item_count and graph_data.controllers.count == item_count and graph_data.children_values.count == item_count and graph_data.side_values.count == item_count and graph_data.precision_values.count == item_count and graph_data.delete_values.count == item_count
            if loaded then
            (
                for item_id = 1 to item_count while loaded do
                (
                    local item_kind = case graph_data.item_kinds[item_id] of
                    (
                        "group": #group
                        "scene_group": #scene_group
                        default: #source
                    )
                    local children_ids = #()
                    for encoded_id in (filterString graph_data.children_values[item_id] ",") do
                    (
                        local child_id = encoded_id as integer
                        /* Added group inputs can receive IDs newer than their parent. */
                        if child_id == undefined or child_id < 1 or child_id > item_count or child_id == item_id then loaded = false
                        else append children_ids child_id
                    )
                    local keep_mode = #auto
                    for candidate in #(#auto,#positive,#negative,#off) where (candidate as string) == graph_data.side_values[item_id] do keep_mode = candidate
                    local restored_node = graph_data.scene_nodes[item_id]
                    local restored_enabled = if isValidNode restored_node then getUserProp restored_node "SI_RootSymmetryEnabled" else undefined
                    local restored_mask = if isValidNode restored_node then getUserProp restored_node "SI_RootSymmetryMask" else undefined
                    local mask_value = if restored_mask == undefined then 1 else (restored_mask as integer)
                    if mask_value == undefined or mask_value < 0 or mask_value > 7 then mask_value = 1
                    append decoded_items (SIHierarchyItem_v item_id:item_id kind:item_kind scene_node:restored_node controller_node:graph_data.controllers[item_id] child_ids:children_ids keep_mode:keep_mode precision_mm:graph_data.precision_values[item_id] delete_trimmed:(graph_data.delete_values[item_id] == 1) symmetry_enabled:(restored_enabled == 1 or restored_enabled == "1" or restored_enabled == true) symmetry_mask:mask_value)
                )
            )
        )
        if loaded then
        (
            local prior_items = items
            local prior_roots = root_ids
            items = decoded_items
            root_ids = graph_data.root_values as array
            loaded = isValidForest()
            if loaded then
            (
                catalog_node = target_node
                latest_id = if graph_data.latest_id >= 1 and graph_data.latest_id <= items.count then graph_data.latest_id else 0
            )
            else
            (
                items = prior_items
                root_ids = prior_roots
            )
        )
        if not loaded then last_error = "Cannot load trim hierarchy: invalid catalog."
        loaded
        -- return
    ),

    /*
    Shows each current root result and optionally its retained dependency results.
    Original source visibility is never changed.
    */
    function applyVisibility only_final =
    (
        local reachable = #()
        for root_id in root_ids do collectIds root_id reachable
        for item_value in items where item_value.kind == #group and isValidNode item_value.scene_node do
        (
            local visible_result = (findItem reachable item_value.item_id) > 0 and (not only_final or (findItem root_ids item_value.item_id) > 0)
            if visible_result then unhide item_value.scene_node else hide item_value.scene_node
            if isValidNode item_value.controller_node then hide item_value.controller_node
        )
        true
        -- return
    ),

    /*
    Generates one group on demand and preserves an explicit failure report.
    */
    function generateGroup item_id precision_mm:0.01 delete_trimmed:true only_final:true =
    (
        local generated = undefined
        if not is_generating then this.syncSceneGroupMembers()
        if not is_generating and (isValidForest()) and item_id >= 1 and item_id <= items.count and items[item_id].kind == #group then
        (
            is_generating = true
            items[item_id].precision_mm = precision_mm
            items[item_id].delete_trimmed = delete_trimmed
            try
            (
                prepareSymmetryForGeneration()
                generated = generateItem item_id #()
                latest_id = item_id
                local parent_id = getParentId item_id
                while parent_id > 0 do
                (
                    items[parent_id].pending = true
                    parent_id = getParentId parent_id
                )
                saveCatalog()
                if not (syncRootSymmetry()) then throw "SI SYMMETRY FAILED | Could not apply all requested root modifiers."
                applyVisibility only_final
                last_error = ""
            )
            catch
            (
                local generation_error = getCurrentException()
                try
                (
                    restoreSymmetryAfterFailure()
                )
                catch
                (
                    format "SI SYMMETRY RESTORE FAILED | %\n" (getCurrentException())
                )
                last_error = generation_error
                generated = undefined
                format "SI HIERARCHY FAILED | %\n" last_error
            )
            is_generating = false
        )
        else last_error = "Select one result to update, or check two top-level inputs."
        generated
        -- return
    ),

    /*
    Deletes this forest's exact generated outputs only; source nodes are retained.
    */
    function resetResults =
    (
        local reset_ok = this.restoreSceneGroupLinks()
        local layer_handles = #()
        for item_value in items where item_value.kind == #group and isValidNode item_value.controller_node do
        (
            appendIfUnique layer_handles ((getHandleByAnim item_value.controller_node) as string)
        )
        for item_id = items.count to 1 by -1 while reset_ok do
        (
            local item_value = items[item_id]
            if item_value.kind == #group then
            (
                local engine_value = getEngine item_id
                if isValidNode engine_value.result_node then reset_ok = engine_value.deleteGeneratedResults()
                else if isValidNode item_value.scene_node then
                (
                    local expected_key = if isValidNode catalog_node then getUserProp catalog_node "SI_HierarchyKey" else undefined
                    local actual_key = getUserProp item_value.scene_node "SI_HierarchyKey"
                    local is_source = false
                    for source_item in items while not is_source do is_source = source_item.kind == #source and source_item.scene_node == item_value.scene_node
                    if expected_key != undefined and actual_key == expected_key and not is_source then
                    (
                        delete item_value.scene_node
                        reset_ok = not (isValidNode item_value.scene_node)
                    )
                    else
                    (
                        reset_ok = false
                        format "SI HIERARCHY RESET FAILED | group:% missing controller; output key:% expected:% source:%\n" item_id actual_key expected_key is_source
                    )
                )
            )
        )
        if reset_ok then
        (
            /* Nested generated layers can empty after their parent was already processed. */
            if layer_handles.count > 0 then
            (
                local cleanup_engine = SurfaceIntersections_v()
                local removed_layers = 1
                while removed_layers > 0 do
                (
                    removed_layers = 0
                    for handle_text in layer_handles do removed_layers += cleanup_engine.cleanupEmptyResultLayers owner_handle:handle_text
                )
            )
            if isValidNode catalog_node then delete catalog_node
            catalog_node = undefined
            local source_values = #()
            for root_id in root_ids do
            (
                local root_item = items[root_id]
                if root_item.kind == #scene_group and isValidNode root_item.scene_node then appendIfUnique source_values root_item.scene_node
                else if root_item.kind == #source and isValidNode root_item.scene_node then appendIfUnique source_values root_item.scene_node
            )
            /* Also restore original sources nested inside discarded result wrappers. */
            for item_value in items where item_value.kind == #scene_group and isValidNode item_value.scene_node do appendIfUnique source_values item_value.scene_node
            for item_value in items where item_value.kind == #source and isValidNode item_value.scene_node do appendIfUnique source_values item_value.scene_node
            items = #()
            root_ids = #()
            latest_id = 0
            addSources source_values
        )
        reset_ok
        -- return
    ),

    on create do ()
)

global siHierarchy
global si_hierarchy_restore_catalog = if siHierarchy != undefined then siHierarchy.catalog_node else undefined
siHierarchy = SIHierarchy_v()
if isValidNode si_hierarchy_restore_catalog then siHierarchy.loadCatalog si_hierarchy_restore_catalog


/* Backend is independently loadable and intentionally does not open the UI. */
if SurfaceIntersections != undefined then
(
    SurfaceIntersections.stop()
)
SurfaceIntersections = SurfaceIntersections_v()





