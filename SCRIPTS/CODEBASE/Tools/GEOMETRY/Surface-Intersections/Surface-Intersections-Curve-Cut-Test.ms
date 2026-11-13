/*
Surface-Intersections-Curve-Cut-Test 0.15 | Project 0.91
Data-only checks for real finite polygon cuts, smaller-side deletion, and
invisible triangulation edges. Default data checks create/delete no scene nodes. Optional scene checks are explicit.
*/

global si_project_version
global si_curve_cut_test_file_version = "0.15"
global si_curve_cut_test_project_version = "0.91"
if si_project_version == undefined then
(
    si_project_version = si_curve_cut_test_project_version
)
else if (si_project_version as float) < (si_curve_cut_test_project_version as float) then
(
    si_project_version = si_curve_cut_test_project_version
)

global SurfaceIntersections_v
global SurfaceIntersections
global siCurveCutTestArea
global siCurveCutTestRun
global siCurveCutSceneTestRun
global siDemandUpdateTestRun
global siEndpointSlicePlanTestRun
global siEndpointSliceSceneTestRun
global siPrecisionBoundaryTestRun
global siCollapsedRegionEdgesTestRun
global siEmptyWorkingCellTestRun
global siExtendedCutTestRun
global siExtendedCutNativeTestRun
global siConvexContainmentTestRun
global siCumulativeContainmentTestRun

/*
Checks one measured polygon-area result and reports the actual value.
*/
function siCurveCutTestArea tool_instance test_name patch_values expected_area precision_value =
(
    local actual_area = tool_instance.getWorkingPatchSetArea patch_values
    local passed = (abs (actual_area - expected_area)) <= precision_value
    format "SI CURVE CUT TEST | % | actual:% expected:% passed:%\n" test_name actual_area expected_area passed
    passed
    -- return
)

/*
Runs scene-safe polygon-cut regression tests on orthogonal source quads.
*/
function siCurveCutTestRun =
(
    local failures = 0
    if SurfaceIntersections_v == undefined then
    (
        format "SI CURVE CUT TEST FAILED | Load Surface-Intersections-FN.ms first.\n"
        false
    )
    else
    (
        local tool_instance = SurfaceIntersections_v()
        local position_precision = tool_instance.getPositionPrecision 0.01
        local surface_a = #([-5,-5,0], [5,-5,0], [5,5,0], [-5,5,0])
        local surface_b = #([2,-5,-2], [2,5,-2], [2,5,8], [2,-5,8])
        tool_instance.delete_trimmed = false
        tool_instance.hidden_edge_segments = #(#([-5,-5,0],[5,5,0]))
        local both_a = tool_instance.cutPatchSetByActualCurves #(surface_a) #(surface_b) #auto position_precision
        if not (siCurveCutTestArea tool_instance "OFF / A unchanged area" both_a 100.0 position_precision) then failures += 1
        if both_a.count != 2 then
        (
            format "SI CURVE CUT TEST FAILED | Expected 2 cut polygons on A, actual:%\n" both_a.count
            failures += 1
        )
        local both_b = tool_instance.cutPatchSetByActualCurves #(surface_b) #(surface_a) #auto position_precision
        if not (siCurveCutTestArea tool_instance "OFF / B unchanged area" both_b 100.0 position_precision) then failures += 1
        if both_b.count != 2 then
        (
            format "SI CURVE CUT TEST FAILED | Expected 2 cut polygons on B, actual:%\n" both_b.count
            failures += 1
        )
        tool_instance.delete_trimmed = true
        local larger_a = tool_instance.cutPatchSetByActualCurves #(surface_a) #(surface_b) #auto position_precision
        if not (siCurveCutTestArea tool_instance "ON / A keeps 70%" larger_a 70.0 position_precision) then failures += 1
        local larger_b = tool_instance.cutPatchSetByActualCurves #(surface_b) #(surface_a) #auto position_precision
        if not (siCurveCutTestArea tool_instance "ON / B keeps 80%" larger_b 80.0 position_precision) then failures += 1

        /* Finite curve has an endpoint on source A's HIDDEN diagonal.
           It must be cut as geometry, not rejected for touching that diagonal. */
        tool_instance.delete_trimmed = false
        local short_b = #([2,-2,-2], [2,2,-2], [2,2,8], [2,-2,8])
        local partial_a = tool_instance.cutPatchSetByActualCurves #(surface_a) #(short_b) #auto position_precision
        if partial_a.count != 2 then
        (
            format "SI CURVE CUT TEST FAILED | Hidden diagonal blocked real finite split; actual patches:% expected:2\n" partial_a.count
            failures += 1
        )
        if not (siCurveCutTestArea tool_instance "Partial cut keeps both regions" partial_a 100.0 position_precision) then failures += 1
        if tool_instance.trim_boundary_segments.count == 0 then
        (
            format "SI CURVE CUT TEST FAILED | Expected actual finite cut edge records.\n"
            failures += 1
        )

        /* Bent finite seam traverses one face through two cutter facets. */
        local bent_cutter = #(#([-5,2,-2],[0,0,-2],[0,0,8],[-5,2,8]), #([0,0,-2],[5,2,-2],[5,2,8],[0,0,8]))
        tool_instance.delete_trimmed = true
        local bent_a = tool_instance.cutPatchSetByActualCurves #(surface_a) bent_cutter #auto position_precision
        if not (siCurveCutTestArea tool_instance "Bent seam / A keeps 60%" bent_a 60.0 position_precision) then failures += 1
        local bent_b = tool_instance.cutPatchSetByActualCurves bent_cutter #(surface_a) #auto position_precision
        if not (siCurveCutTestArea tool_instance "Bent seam / B keeps 80%" bent_b (16.0 * sqrt 29.0) position_precision) then failures += 1
        tool_instance.delete_trimmed = false
        local bent_both = tool_instance.cutPatchSetByActualCurves #(surface_a) bent_cutter #auto position_precision
        if not (siCurveCutTestArea tool_instance "Bent seam / OFF conserves area" bent_both 100.0 position_precision) then failures += 1
        local far_quad = #([-25,-5,0],[-15,-5,0],[-15,5,0],[-25,5,0])
        tool_instance.delete_trimmed = true
        local disconnected = tool_instance.cutPatchSetByActualCurves #(surface_a, far_quad) bent_cutter #auto position_precision
        if not (siCurveCutTestArea tool_instance "Uncut disconnected component survives" disconnected 160.0 position_precision) then failures += 1

        /* An invisible evaluated diagonal must not introduce a cut knot. */
        local polygon_tool = SurfaceIntersections_v()
        polygon_tool.visible_edge_segments = #(#([-5,-5,0],[-5,5,0]), #([5,-5,0],[5,5,0]))
        local hidden_diagonal_cuts = #(#([-5,0,0],[0,0.1,0]), #([0,0.1,0],[5,0,0]))
        local visible_cuts = polygon_tool.simplifyVisibleCutSegments hidden_diagonal_cuts position_precision
        if visible_cuts.count != 1 then
        (
            format "SI VISIBLE CUT TEST FAILED | segments:% expected:1 without hidden diagonal knot\n" visible_cuts.count
            failures += 1
        )
        append polygon_tool.visible_edge_segments #([0,-5,0],[0,5,0])
        visible_cuts = polygon_tool.simplifyVisibleCutSegments hidden_diagonal_cuts position_precision
        if visible_cuts.count != 2 then
        (
            format "SI VISIBLE CUT TEST FAILED | segments:% expected:2 at real visible edge\n" visible_cuts.count
            failures += 1
        )

        if tool_instance.cut_error_count != 0 then
        (
            format "SI CURVE CUT TEST FAILED | Unexpected unresolved cut errors:%\n" tool_instance.cut_error_count
            failures += 1
        )
        format "SI CURVE CUT TEST END | failures:%\n" failures
        (failures == 0)
    )
    -- return
)

/*
Inspects the generated two-surface fixture without modifying or deleting nodes.
Returns false for artificial vertices, disconnected output, or missing cut edges.
*/
function siCurveCutSceneTestRun =
(
    local failures = 0
    local tool_instance = SurfaceIntersections
    local position_precision = tool_instance.getPositionPrecision tool_instance.position_precision_mm
    if not (isValidNode tool_instance.trimmed_result_node) or tool_instance.source_nodes.count != 2 then
    (
        format "SI SCENE CUT TEST FAILED | Generate the two-source result first.\n"
        false
    )
    else
    (
        local poly_base = tool_instance.trimmed_result_node.baseObject
        if polyop.getHasDeadStructs poly_base != 0 then
        (
            format "SI SCENE CUT TEST FAILED | Output contains dead topology.\n"
            failures += 1
        )
        else
        (
            local face_count = polyop.getNumFaces poly_base
            local face_remaining = #{1..face_count}
            local element_count = 0
            while face_remaining.numberSet > 0 do
            (
                local face_id = (face_remaining as array)[1]
                face_remaining -= polyop.getElementsUsingFace poly_base #{face_id}
                element_count += 1
            )
            if element_count != 2 then failures += 1
            for face_id = 1 to face_count where (polyop.getFaceDeg poly_base face_id) < 3 do failures += 1
            local result_edges = for edge_id = 1 to (polyop.getNumEdges poly_base) where (polyop.getEdgeVis poly_base edge_id) collect
            (
                local edge_ids = polyop.getEdgeVerts poly_base edge_id
                #(polyop.getVert poly_base edge_ids[1], polyop.getVert poly_base edge_ids[2])
            )
            local original_sets = for source_node in tool_instance.source_nodes collect
                (tool_instance.buildVisibleSourcePatches (tool_instance.buildTriangleCache source_node) position_precision)[1]
            local actual_cuts = tool_instance.collectVisiblePatchSegments original_sets[1] original_sets[2] position_precision
            actual_cuts = tool_instance.simplifyVisibleCutSegments actual_cuts position_precision
            if actual_cuts.count == 0 then failures += 1
            local missing_count = 0
            for actual_segment in actual_cuts do
            (
                local direction = normalize (actual_segment[2] - actual_segment[1])
                local matching_edges = for result_edge in result_edges where
                    (length (cross direction (result_edge[1] - actual_segment[1]))) <= position_precision and
                    (length (cross direction (result_edge[2] - actual_segment[1]))) <= position_precision collect result_edge
                if not (tool_instance.finiteSegmentsCoverChord matching_edges actual_segment position_precision) then missing_count += 1
            )
            failures += missing_count
            local original_points = #()
            for reference_segment in tool_instance.visible_edge_segments do
            (
                for point_value in reference_segment do tool_instance.appendUniquePoint original_points point_value position_precision
            )
            local cut_points = #()
            for actual_segment in actual_cuts do
            (
                for point_value in actual_segment do tool_instance.appendUniquePoint cut_points point_value position_precision
            )
            local artificial_count = 0
            for vertex_id = 1 to (polyop.getNumVerts poly_base) do
            (
                local vertex_position = polyop.getVert poly_base vertex_id
                local is_original = false
                for point_value in original_points while not is_original do is_original = tool_instance.isSamePoint vertex_position point_value position_precision
                local is_real_cut = false
                if not is_original then
                (
                    for point_value in cut_points while not is_real_cut do is_real_cut = tool_instance.isSamePoint vertex_position point_value position_precision
                    local is_visible_edge_hit = false
                    for reference_segment in tool_instance.visible_edge_segments while not is_visible_edge_hit do
                    (
                        is_visible_edge_hit = tool_instance.segmentWithinReference vertex_position vertex_position reference_segment position_precision
                    )
                    is_real_cut = is_real_cut and is_visible_edge_hit
                )
                if not is_original and not is_real_cut then
                (
                    artificial_count += 1
                    format "SI SCENE VERTEX FAILED | vertex:% raw:% precision:% expected:original or real visible-edge intersection\n" vertex_id vertex_position position_precision
                )
            )
            failures += artificial_count
            format "SI SCENE VERTEX TEST | vertices:% artificial:% expected artificial:0\n" (polyop.getNumVerts poly_base) artificial_count
            for source_index = 1 to 2 do
            (
                local original_area = tool_instance.getWorkingPatchSetArea original_sets[source_index]
                local retained_area = tool_instance.getWorkingPatchSetArea tool_instance.working_patch_sets[source_index]
                if retained_area >= original_area or retained_area < original_area * 0.5 then failures += 1
                format "SI SCENE CUT TEST | source:% original area:% retained area:%\n" tool_instance.source_nodes[source_index].name original_area retained_area
            )
            format "SI SCENE CUT TEST | faces:% elements:% expected elements:2 cut segments:% missing:%\n" face_count element_count actual_cuts.count missing_count
        )
        format "SI SCENE CUT TEST END | failures:%\n" failures
        failures == 0
    )
    -- return
)

/*
Checks on-demand mode without creating nodes or modifying the active setup.
Legacy live/freeze settings and stale callbacks must never schedule a rebuild.
*/
function siDemandUpdateTestRun =
(
    local test_instance = SurfaceIntersections_v()
    local failures = 0
    test_instance.attachMonitoring()
    if test_instance.node_callback != undefined or test_instance.live_timer != undefined or test_instance.transform_handler != undefined then
    (
        format "SI DEMAND TEST FAILED | Monitoring resources were registered; expected:none.\n"
        failures += 1
    )
    for legacy_mode in #(#live, #freeze, #manual) do
    (
        if not (test_instance.setMode legacy_mode) or test_instance.update_mode != #manual then
        (
            format "SI DEMAND TEST FAILED | legacy:% actual:% expected:manual\n" legacy_mode test_instance.update_mode
            failures += 1
        )
    )
    test_instance.update_mode = #live
    test_instance.is_dirty = false
    test_instance.markDirty()
    if test_instance.is_dirty or test_instance.live_timer != undefined then
    (
        format "SI DEMAND TEST FAILED | Callback dirty:% timer:% expected:false/undefined\n" test_instance.is_dirty test_instance.live_timer
        failures += 1
    )
    test_instance.detachMonitoring()
    format "SI DEMAND TEST END | failures:%\n" failures
    failures == 0
    -- return
)

/*
Tests endpoint planning using finite borders and opaque source identity tokens.
Creates no nodes and does not modify the active scene or tool binding.
*/
function siEndpointSlicePlanTestRun =
(
    local ti = SurfaceIntersections_v()
    local p = ti.getPositionPrecision 0.01
    local failures = 0
    ti.slice_source_values = #("narrow", "wide")
    ti.slice_boundary_sets = #(#(#([-5,-1,0],[5,-1,0]), #([5,-1,0],[5,1,0]), #([5,1,0],[-5,1,0]), #([-5,1,0],[-5,-1,0])), #(#([-10,-2,0],[10,-2,0]), #([10,-2,0],[10,2,0]), #([10,2,0],[-10,2,0]), #([-10,2,0],[-10,-2,0])))
    ti.slice_pair_cuts = #(#(1,2,#(#([0,0,0],[5,0,0]))))
    local plans = ti.buildEndpointSlicePlans p
    if plans.count != 1 then failures += 1
    else
    (
        if plans[1][2] != "wide" or plans[1][4] != 1 or plans[1][5] != [1,0,0] then failures += 1
        if not (ti.isSamePoint plans[1][3] [5,0,0] p) then failures += 1
    )
    ti.slice_pair_cuts = #(#(1,2,#(#([-5,0,0],[0,0,0]))))
    plans = ti.buildEndpointSlicePlans p
    if plans.count != 1 then failures += 1
    else if plans[1][5] != [-1,0,0] then failures += 1
    ti.slice_boundary_sets[2] = ti.slice_boundary_sets[1]
    ti.slice_pair_cuts = #(#(1,2,#(#([-5,0,0],[5,0,0]))))
    if (ti.buildEndpointSlicePlans p).count != 0 then failures += 1
    format "SI SLICE PLAN TEST END | failures:%\n" failures
    failures == 0
    -- return
)

/*
Checks an active generated Slice fixture and explicitly regenerates it once.
Run only on a test setup; verifies instancing, world pivot, type and reuse.
*/
function siEndpointSliceSceneTestRun =
(
    local ti = SurfaceIntersections
    local owned_mods = ti.getOwnedEndpointSlices()
    local failures = 0
    if owned_mods.count != 1 then
    (
        format "SI SLICE SCENE TEST FAILED | owned:% expected:1 for this fixture\n" owned_mods.count
        false
    )
    else
    (
        local sm = owned_mods[1]
        local linked_nodes = ti.getEndpointSliceNodes sm
        local p = ti.getPositionPrecision ti.position_precision_mm
        if sm.Slice_Type != 2 then failures += 1
        for target_node in linked_nodes do
        (
            if not isValidNode target_node then failures += 1
            else
            (
                if (findItem (for stack_mod in target_node.modifiers collect stack_mod) sm) == 0 then failures += 1
                local world_plane = sm.slice_plane.transform * (inverse (getModContextTM target_node sm)) * target_node.objectTransform
                if not (ti.isSamePoint world_plane.translation sm.SI_EndpointSlice.pivot_position p) then failures += 1
                local unit_distance = units.decodeValue "1mm"
                for axis_index = 1 to 3 do
                (
                    local expected_axis = [0,0,0]
                    expected_axis[axis_index] = unit_distance
                    if not (ti.isSamePoint (world_plane.translation + world_plane[axis_index] * unit_distance) (sm.SI_EndpointSlice.pivot_position + expected_axis) p) then failures += 1
                )
            )
        )
        local mod_handle = getHandleByAnim sm
        local result_handle = getHandleByAnim ti.trimmed_result_node
        if not (ti.refresh()) then failures += 1
        owned_mods = ti.getOwnedEndpointSlices()
        if owned_mods.count != 1 then failures += 1
        else if (getHandleByAnim owned_mods[1]) != mod_handle then failures += 1
        if (getHandleByAnim ti.trimmed_result_node) != result_handle then failures += 1
        if ti.update_mode != #manual or ti.live_timer != undefined or ti.node_callback != undefined then failures += 1
        format "SI SLICE SCENE TEST END | failures:%\n" failures
        failures == 0
    )
    -- return
)

/*
Reproduces boundary construction at every supported precision on given sources.
Only temporary result nodes created by this test are deleted; inputs are retained.
*/
function siPrecisionBoundaryTestRun source_values precision_values:#(1.0, 0.1, 0.01) delete_values:#(true, false) =
(
    local active_tool = SurfaceIntersections
    local test_tool = SurfaceIntersections_v()
    test_tool.source_nodes = source_values
    test_tool.result_node = active_tool.result_node
    local failures = 0
    for delete_state in delete_values do
    (
        test_tool.delete_trimmed = delete_state
        for precision_mm in precision_values do
        (
            local p = test_tool.getPositionPrecision precision_mm
            local segments = test_tool.collectAllSegments source_values p
            local pending = undefined
            local scenario_failures = 0
            if segments == undefined then scenario_failures += 1
            else
            (
                for segment_value in segments do
                (
                    for point_value in segment_value where (test_tool.getEndpointDegree segments point_value p) > 2 do scenario_failures += 1
                )
                pending = test_tool.buildTrimmedPoly test_tool.working_patch_sets p
                if not isValidNode pending then scenario_failures += 1
                else
                (
                    local allowed_points = #()
                    for reference_segment in (test_tool.visible_edge_segments + test_tool.trim_boundary_segments) do
                    (
                        for point_value in reference_segment do test_tool.appendUniquePoint allowed_points point_value p
                    )
                    for vertex_id = 1 to (polyop.getNumVerts pending.baseObject) do
                    (
                        local query_point = polyop.getVert pending.baseObject vertex_id
                        local authoritative = false
                        for allowed_point in allowed_points while not authoritative do authoritative = test_tool.isSamePoint query_point allowed_point p
                        if not authoritative then scenario_failures += 1
                    )
                )
            )
            if isValidNode pending then delete pending
            failures += scenario_failures
            format "SI PRECISION BOUNDARY TEST | mm:% DeleteTrimmed:% failures:%\n" precision_mm delete_state scenario_failures
        )
    )
    format "SI PRECISION BOUNDARY TEST END | failures:%\n" failures
    failures == 0
    -- return
)

/*
Reproduces duplicate support edges that previously formed a two-point loop.
Checks that real opposite edges across different regions are retained.
*/
function siCollapsedRegionEdgesTestRun =
(
    local ti = SurfaceIntersections_v()
    local failures = 0
    local edges = #(#(1,2,1), #(2,3,1), #(3,4,1), #(4,1,1), #(2,5,1), #(5,2,1), #(2,5,1), #(6,6,1))
    local used_edges = #{}
    used_edges.count = edges.count
    used_edges = ti.cancelCollapsedRegionEdges edges #(1) used_edges
    if used_edges != #{5,6,7,8} then
    (
        format "SI COLLAPSED EDGE TEST FAILED | removed:% expected:#{5,6,7,8}\n" used_edges
        failures += 1
    )
    edges = #(#(1,2,1), #(2,1,2))
    used_edges = #{}
    used_edges.count = edges.count
    used_edges = ti.cancelCollapsedRegionEdges edges #(1,2) used_edges
    if used_edges.numberSet != 0 then
    (
        format "SI COLLAPSED EDGE TEST FAILED | Genuine inter-region seam was removed:%\n" used_edges
        failures += 1
    )
    format "SI COLLAPSED EDGE TEST END | failures:%\n" failures
    failures == 0
    -- return
)

/*
Reproduces the empty-cell fixture without replacing existing result geometry.
Requires the affected source pair; checks that region input remains polygonal.
*/
function siEmptyWorkingCellTestRun source_values position_precision_mm:0.01 =
(
    local ti = SurfaceIntersections_v()
    ti.source_nodes = source_values
    ti.result_node = SurfaceIntersections.result_node
    local p = ti.getPositionPrecision position_precision_mm
    local segments = ti.collectAllSegments source_values p
    local failures = 0
    local pending = undefined
    if segments == undefined then failures += 1
    else
    (
        if ti.collapsed_cell_count == 0 then
        (
            format "SI EMPTY CELL TEST FAILED | Fixture did not exercise knot-cleanup collapse.\n"
            failures += 1
        )
        for patch_set in ti.working_patch_sets do
        (
            for patch_points in patch_set where patch_points.count < 3 do
            (
                format "SI EMPTY CELL TEST FAILED | Invalid region corners:% expected:3 or more\n" patch_points.count
                failures += 1
            )
        )
        pending = ti.buildTrimmedPoly ti.working_patch_sets p
        if not isValidNode pending then failures += 1
    )
    if isValidNode pending then delete pending
    format "SI EMPTY CELL TEST END | omitted:% failures:%\n" ti.collapsed_cell_count failures
    failures == 0
    -- return
)

/*
Checks endpoint extensions on unequal widths without creating scene nodes.
Both reciprocal cuts, area conservation, closed cuts and facet traversal are checked.
*/
function siExtendedCutTestRun =
(
    local ti = SurfaceIntersections_v()
    local p = ti.getPositionPrecision 0.01
    local failures = 0
    local surface_a = #([-5,-5,0],[5,-5,0],[5,5,0],[-5,5,0])
    for width_limits in #(#(-4.75,4.8), #(-5.0,4.8), #(-2.0,2.0)) do
    (
        local surface_b = #([2,width_limits[1],-2],[2,width_limits[2],-2],[2,width_limits[2],8],[2,width_limits[1],8])
        ti.delete_trimmed = true
        local result_a = ti.cutPatchSetByActualCurves #(surface_a) #(surface_b) #auto p
        if not (siCurveCutTestArea ti "Unequal widths / larger A" result_a 70.0 p) then failures += 1
        local result_b = ti.cutPatchSetByActualCurves #(surface_b) #(surface_a) #auto p
        if not (siCurveCutTestArea ti "Unequal widths / larger B" result_b ((width_limits[2] - width_limits[1]) * 8.0) p) then failures += 1
        ti.delete_trimmed = false
        result_a = ti.cutPatchSetByActualCurves #(surface_a) #(surface_b) #auto p
        if not (siCurveCutTestArea ti "Extended OFF conserves A" result_a 100.0 p) then failures += 1
    )
    local lower_facet = #([-5,-5,0],[5,-5,0],[5,3,0],[-5,3,0])
    local upper_facet = #([-5,3,0],[5,3,0],[5,5,1],[-5,5,1])
    local short_b = #([2,-2,-2],[2,2,-2],[2,2,8],[2,-2,8])
    ti.delete_trimmed = true
    local folded = ti.cutPatchSetByActualCurves #(lower_facet,upper_facet) #(short_b) #auto p
    if not (siCurveCutTestArea ti "Continuation across adjacent facet" folded (0.7 * (80.0 + 10.0 * sqrt 5.0)) p) then failures += 1
    local far_quad = #([-25,-5,0],[-15,-5,0],[-15,5,0],[-25,5,0])
    local disconnected = ti.cutPatchSetByActualCurves #(surface_a,far_quad) #(short_b) #auto p
    if not (siCurveCutTestArea ti "Extension preserves disconnected island" disconnected 170.0 p) then failures += 1
    local no_cut = ti.cutPatchSetByActualCurves #(surface_a) #(#([20,-2,-2],[20,2,-2],[20,2,8],[20,-2,8])) #auto p
    if not (siCurveCutTestArea ti "No intersection has no extension" no_cut 100.0 p) then failures += 1
    local closed_cut = #(#([-2,-2,0],[2,-2,0]),#([2,-2,0],[2,2,0]),#([2,2,0],[-2,2,0]),#([-2,2,0],[-2,-2,0]))
    ti.extended_cut_segments = #()
    if (ti.extendCutSegmentsToBorder #(surface_a) closed_cut p).count != 4 or ti.extended_cut_segments.count != 0 then failures += 1
    local sliver = #([10,-10,-10],[10,10,10],[10.000001,10,10.000001])
    local restored = ti.buildVisibleSourcePatches #(#(sliver,[0,0,0],[0,0,0],#(true,true,true),#(1,2,3))) p
    if restored[1].count != 0 then failures += 1
    local touching_island = #([2,5,0],[4,10,0],[0,10,0])
    local point_touch = ti.cutPatchSetByActualCurves #(surface_a,touching_island) #(short_b) #auto p
    if not (siCurveCutTestArea ti "Stop at border before point-touch island" point_touch 80.0 p) then failures += 1
    local fan_points = #([0,0,0],[100,0,0],[100,100,0],[0,100,0],[50,0.001,0])
    local fan_cache = for corner_index = 1 to 4 collect
    (
        local next_index = if corner_index == 4 then 1 else corner_index + 1
        #(#(fan_points[corner_index],fan_points[next_index],fan_points[5]),[0,0,0],[100,100,0],#(true,false,false),#(corner_index,next_index,5))
    )
    local restored_fan = ti.buildVisibleSourcePatches fan_cache p
    if not (siCurveCutTestArea ti "Merge hidden skinny triangles before cleaning" restored_fan[1] 10000.0 p) then failures += 1
    if ti.endpoint_slice_enabled then failures += 1
    format "SI EXTENDED CUT TEST END | failures:%\n" failures
    failures == 0
    -- return
)

/*
Builds temporary native unequal-width surfaces and checks generated polygon topology.
Deletes only exact temporary nodes and restores the original scene selection.
*/
function siExtendedCutNativeTestRun =
(
    local ti = SurfaceIntersections_v()
    local p = ti.getPositionPrecision 0.01
    local temp_nodes = #()
    local prior_selection = selection as array
    local failures = 0
    local surface_a = #([-5,-5,0],[5,-5,0],[5,5,0],[-5,5,0])
    local surface_b = #([2,-4.75,-2],[2,4.8,-2],[2,4.8,8],[2,-4.75,8])
    try
    (
        for pp in #(surface_a,surface_b) do
        (
            for edge_index = 1 to pp.count do
            (
                local next_index = if edge_index == pp.count then 1 else edge_index + 1
                append ti.result_edge_segments #(pp[edge_index],pp[next_index])
            )
            ti.visible_edge_segments = copy ti.result_edge_segments #noMap
            local source_node = ti.buildTrimmedPoly #(#(pp)) p
            if not isValidNode source_node then throw "SI EXTENDED NATIVE TEST FAILED | Cannot create input polygon."
            append temp_nodes source_node
        )
        local sources = copy temp_nodes #noMap
        for delete_state in #(true,false) do
        (
            ti.delete_trimmed = delete_state
            local cut_segments = ti.collectAllSegments sources p
            if cut_segments == undefined then throw "SI EXTENDED NATIVE TEST FAILED | Cannot compute cut."
            local expected_area = if delete_state then 70.0 else 100.0
            if not (siCurveCutTestArea ti "Native unequal width / A" ti.working_patch_sets[1] expected_area p) then failures += 1
            for border_point in #([2,-5,0],[2,5,0]) do
            (
                local found = false
                for cut_segment in cut_segments while not found do found = ti.segmentWithinReference border_point border_point cut_segment p
                if not found then
                (
                    format "SI EXTENDED NATIVE TEST FAILED | Missing curve border point:%\n" border_point
                    failures += 1
                )
            )
            local pending = ti.buildTrimmedPoly ti.working_patch_sets p
            if not isValidNode pending then throw "SI EXTENDED NATIVE TEST FAILED | Native polygon build failed."
            append temp_nodes pending
            if (polyop.getNumFaces pending.baseObject) < 2 then failures += 1
            if pending.modifiers.count != 0 then failures += 1
            for border_point in #([2,-5,0],[2,5,0]) do
            (
                local found = false
                for vertex_id = 1 to (polyop.getNumVerts pending.baseObject) while not found do found = ti.isSamePoint (polyop.getVert pending.baseObject vertex_id) border_point p
                if not found then failures += 1
            )
        )
        local test_controller = SplineShape name:"SI_Extension_Test_Controller"
        append temp_nodes test_controller
        ti.result_node = test_controller
        ti.trimmed_result_node = temp_nodes[3]
        local owner_key = ((dotNetClass "System.Guid").NewGuid()).ToString "N"
        setUserProp test_controller "SI_SliceOwnerKey" owner_key
        local owned_slice = SliceModifier()
        custAttributes.add owned_slice si_endpoint_slice_ca
        owned_slice.SI_EndpointSlice.owner_key = owner_key
        addModifier sources[1] owned_slice
        addModifier ti.trimmed_result_node owned_slice
        local manual_slice = SliceModifier()
        addModifier sources[2] manual_slice
        if not (ti.updateEndpointSlices p) or owned_slice.enabled or not manual_slice.enabled then
        (
            format "SI EXTENDED NATIVE TEST FAILED | owned enabled:% manual enabled:% expected:false/true\n" owned_slice.enabled manual_slice.enabled
            failures += 1
        )
    )
    catch
    (
        local exception_text = getCurrentException()
        format "SI EXTENDED NATIVE TEST FAILED | %\n" exception_text
        failures += 1
    )
    for temp_node in temp_nodes where isValidNode temp_node do delete temp_node
    select (for prior_node in prior_selection where isValidNode prior_node collect prior_node)
    format "SI EXTENDED NATIVE TEST END | failures:%\n" failures
    failures == 0
    -- return
)

/*
Rejects outside and off-plane points on rotated polygons with collinear corners.
The old triangle-fan containment accepts the first outside point in this fixture.
*/
function siConvexContainmentTestRun =
(
    local ti = SurfaceIntersections_v()
    local p = ti.getPositionPrecision 0.01
    local transform_value = (eulerAngles 1.1 2.7 0.9) as matrix3
    transform_value.translation = [1584.33,-352.591,2385.36]
    local patch_points = for point_value in #([0,0,0],[1000,0,0],[1000,2000,0],[0,2000,0],[0,1800,0]) collect (point_value * transform_value)
    local failures = 0
    for local_point in #([500,-20,0],[-20,100,0],[1020,1000,0],[500,2020,0],[500,1000,10]) do
    (
        local world_point = local_point * transform_value
        if ti.pointInConvexPatch world_point patch_points p then
        (
            format "SI CONTAINMENT TEST FAILED | outside:% world:% expected:false\n" local_point world_point
            failures += 1
        )
    )
    for local_point in #([500,1000,0],[500,0,0],[0,1800,0],[0,0,0]) do
    (
        if not (ti.pointInConvexPatch (local_point * transform_value) patch_points p) then
        (
            format "SI CONTAINMENT TEST FAILED | inside/border:% expected:true\n" local_point
            failures += 1
        )
    )
    local reversed_points = for point_index = patch_points.count to 1 by -1 collect patch_points[point_index]
    if not (ti.pointInConvexPatch ([500,1000,0] * transform_value) reversed_points p) then failures += 1
    if ti.pointInConvexPatch ([500,-20,0] * transform_value) reversed_points p then failures += 1
    format "SI CONTAINMENT TEST END | failures:%\n" failures
    failures == 0
    -- return
)

/*
Checks the four rotated source outlines recorded in the extension error log.
Coordinates are the log's rounded samples, not a substitute for its original Max scene.
*/
function siCumulativeContainmentTestRun =
(
    local ti = SurfaceIntersections_v()
    local p = ti.getPositionPrecision 0.01
    local original_sets = #(
        #(#([2122.82,674.147,3628.69],[2342.05,674.147,2385.36],[2342.05,3681.75,2385.36],[2122.82,3681.75,3628.69])),
        #(#([1584.33,-352.592,3650.41],[1584.33,-352.592,2385.36],[2371.53,1415.48,2385.36],[2371.53,1415.48,3650.41])),
        #(#([2342.05,205.984,2385.36],[1617.05,205.984,1129.63],[1617.05,3681.75,1129.63],[2342.05,3681.75,2385.36])),
        #(#([1584.33,-352.591,2385.36],[1344.05,-245.612,1147.96],[2131.25,1522.45,1147.96],[2371.53,1415.48,2385.36]))
    )
    local failures = 0
    for delete_state in #(true,false) do
    (
        ti.delete_trimmed = delete_state
        ti.cut_error_count = 0
        local result_sets = ti.buildCumulativePatches original_sets #(#auto,#auto,#auto,#auto) [0,0,0] p
        if result_sets.count != 4 or ti.cut_error_count != 0 then failures += 1
        for source_index = 1 to result_sets.count do
        (
            local original_area = ti.getWorkingPatchSetArea original_sets[source_index]
            local actual_area = ti.getWorkingPatchSetArea result_sets[source_index]
            local perimeter = 0.0
            for pp in original_sets[source_index] do
            (
                for edge_index = 1 to pp.count do
                (
                    local next_index = if edge_index == pp.count then 1 else edge_index + 1
                    perimeter += length (pp[next_index] - pp[edge_index])
                )
            )
            /* Same position-derived area allowance used by the polygon cutter. */
            local area_precision = p * perimeter * 4.0
            local area_ok = actual_area > 0.0 and actual_area <= original_area + area_precision
            if not delete_state then area_ok = area_ok and (abs (actual_area - original_area)) <= area_precision
            if not area_ok then
            (
                format "SI CUMULATIVE CONTAINMENT FAILED | source:% delete:% original:% actual:% allowance:%\n" source_index delete_state original_area actual_area area_precision
                failures += 1
            )
        )
    )
    format "SI CUMULATIVE CONTAINMENT TEST END | failures:%\n" failures
    failures == 0
    -- return
)

global siSourcePolygonGenerateTestRun

/*
Checks fresh result creation from explicit source surfaces without replacing them.
Leaves the test-owned result available for inspection; run only on demand.
*/
function siSourcePolygonGenerateTestRun source_values position_precision_mm:0.01 =
(
    global si_polygon_generation_test_engine = SurfaceIntersections_v()
    si_polygon_generation_test_engine.only_final_result = true
    local generated = si_polygon_generation_test_engine.startLive source_values position_precision_mm:position_precision_mm
    local passed = isValidNode generated and isValidNode si_polygon_generation_test_engine.trimmed_result_node
    if passed then passed = (polyop.getNumFaces si_polygon_generation_test_engine.trimmed_result_node) > 0
    format "SI SOURCE POLYGON TEST | sources:% precision mm:% result:% passed:% report:%\n" source_values.count position_precision_mm si_polygon_generation_test_engine.trimmed_result_node passed si_polygon_generation_test_engine.last_polygon_report
    passed
    -- return
)

global siTerminalStubExtensionTestRun

/*
Checks that a sub-precision terminal stub cannot reverse a cut extension.
Uses only polygon data and preserves the selected position-precision contract.
*/
function siTerminalStubExtensionTestRun =
(
    local engine_value = SurfaceIntersections_v()
    local position_precision = engine_value.getPositionPrecision 0.01
    local target_patches = #(#([0,-1,0],[10,-1,0],[10,1,0],[0,1,0]))
    local endpoint = [4.9949,0,0]
    local cut_segments = #(#([1,0,0],[4.9951,0,0]),#([4.9951,0,0],endpoint))
    engine_value.extendCutSegmentsToBorder target_patches cut_segments position_precision
    local end_point = engine_value.extended_cut_segments[engine_value.extended_cut_segments.count][2]
    local passed = engine_value.isSamePoint end_point [10,0,0] position_precision
    format "SI TERMINAL STUB TEST | actual:% expected:% precision:% passed:%\n" end_point [10,0,0] position_precision passed
    passed
    -- return
)

global siWarpedSourcePatchTestRun

/*
Preserves warped source triangles instead of flattening them at identity precision.
An exactly planar hidden diagonal may still dissolve before cutting.
*/
function siWarpedSourcePatchTestRun =
(
    local engine_value = SurfaceIntersections_v()
    local position_precision = engine_value.getPositionPrecision 0.1
    local failures = 0
    for corner_height in #(0.0,0.05) do
    (
        local point_a = [0,0,0]
        local point_b = [10,0,0]
        local point_c = [10,10,corner_height]
        local point_d = [0,10,0]
        local triangle_values = #(
            #(#(point_a,point_b,point_c),[0,0,0],[10,10,corner_height],#(true,true,false),#(1,2,3)),
            #(#(point_a,point_c,point_d),[0,0,0],[10,10,corner_height],#(false,true,true),#(1,3,4)))
        local reconstructed = engine_value.buildVisibleSourcePatches triangle_values position_precision
        local expected_count = if corner_height == 0.0 then 1 else 2
        if reconstructed[1].count != expected_count then
        (
            failures += 1
            format "SI WARPED SOURCE FAILED | height:% patches:% expected:% precision:%\n" corner_height reconstructed[1].count expected_count position_precision
        )
    )
    format "SI WARPED SOURCE TEST | failures:%\n" failures
    failures == 0
    -- return
)

global siCollapsedCutSplitTestRun

/*
Accepts a valid cut when one side collapses under the explicit position precision.
The surviving cut cell must replace the original unsplit patch without a fatal error.
*/
function siCollapsedCutSplitTestRun =
(
    local engine_value = SurfaceIntersections_v()
    local unit_scale = units.decodeValue "1mm"
    local position_precision = engine_value.getPositionPrecision 0.1
    local target_patches = #(#(
        [1472.786376953,-3.455856323,3001.630859375] * unit_scale,
        [1469.473754883,-15.287353516,2949.341796875] * unit_scale,
        [1472.884033203,-3.107181549,3001.993896484] * unit_scale))
    local plane_origin = [1470.694335938,-10.927753448,2968.560302734] * unit_scale
    local plane_normal = [-0.195891902,-0.699650586,0.687106550]
    local tangent = normalize (cross plane_normal [0,0,1])
    local across = normalize (cross plane_normal tangent)
    local span_value = 100.0 * unit_scale
    local cutter_patches = #(#(
        plane_origin-tangent*span_value-across*span_value,
        plane_origin+tangent*span_value-across*span_value,
        plane_origin+tangent*span_value+across*span_value,
        plane_origin-tangent*span_value+across*span_value))
    local retained = engine_value.cutPatchSetByActualCurves target_patches cutter_patches #auto position_precision
    local original_area = engine_value.getWorkingPatchSetArea target_patches
    local retained_area = engine_value.getWorkingPatchSetArea retained
    local passed = engine_value.cut_error_count == 0 and retained_area > 0.0 and retained_area < original_area
    format "SI COLLAPSED SPLIT TEST | errors:% expected:0 original area:% retained area:% passed:%\n" engine_value.cut_error_count original_area retained_area passed
    passed
    -- return
)

global siContinuationStubTestRun

/*
Ignores a sub-precision section stub instead of reporting a false branch.
Replays the CABIN/BUMPER continuation from the reported rover scene in millimeters.
*/
function siContinuationStubTestRun =
(
    local engine_value = SurfaceIntersections_v()
    local unit_scale = units.decodeValue "1mm"
    local position_precision = engine_value.getPositionPrecision 0.1
    local target_patches = #(
#([143.993606567,-312.829162598,2562.041992188] * unit_scale,[0.000000000,-314.700744629,2561.540527344] * unit_scale,[0.000000000,73.527526855,1112.651733398] * unit_scale),
#([0.000000000,73.527526855,1112.651733398] * unit_scale,[143.993606567,75.399108887,1113.153198242] * unit_scale,[143.993606567,-312.829162598,2562.041992188] * unit_scale),
#([283.939392090,-310.811950684,2562.582519531] * unit_scale,[143.993606567,-312.829162598,2562.041992188] * unit_scale,[143.993606567,75.399108887,1113.153198242] * unit_scale),
#([143.993606567,75.399108887,1113.153198242] * unit_scale,[283.939392090,77.416381836,1113.693725586] * unit_scale,[283.939392090,-310.811950684,2562.582519531] * unit_scale),
#([415.789581299,-308.503356934,2563.201171875] * unit_scale,[283.939392090,-310.811950684,2562.582519531] * unit_scale,[283.939392090,77.416381836,1113.693725586] * unit_scale),
#([283.939392090,77.416381836,1113.693725586] * unit_scale,[415.789581299,79.724914551,1114.312377930] * unit_scale,[415.789581299,-308.503356934,2563.201171875] * unit_scale),
#([535.496459961,-305.758117676,2563.936767578] * unit_scale,[415.789581299,-308.503356934,2563.201171875] * unit_scale,[415.789581299,79.724914551,1114.312377930] * unit_scale),
#([415.789581299,79.724914551,1114.312377930] * unit_scale,[535.496459961,82.470214844,1115.047973633] * unit_scale,[535.496459961,-305.758117676,2563.936767578] * unit_scale),
#([639.012207031,-302.430236816,2564.828369141] * unit_scale,[535.496459961,-305.758117676,2563.936767578] * unit_scale,[535.496459961,82.470214844,1115.047973633] * unit_scale),
#([535.496459961,82.470214844,1115.047973633] * unit_scale,[639.012207031,85.798034668,1115.939575195] * unit_scale,[639.012207031,-302.430236816,2564.828369141] * unit_scale),
#([722.289001465,-298.374328613,2565.915039062] * unit_scale,[639.012207031,-302.430236816,2564.828369141] * unit_scale,[639.012207031,85.798034668,1115.939575195] * unit_scale),
#([639.012207031,85.798034668,1115.939575195] * unit_scale,[722.289001465,89.854003906,1117.026367188] * unit_scale,[722.289001465,-298.374328613,2565.915039062] * unit_scale),
#([781.279113770,-293.444641113,2567.236083984] * unit_scale,[722.289001465,-298.374328613,2565.915039062] * unit_scale,[722.289001465,89.854003906,1117.026367188] * unit_scale),
#([722.289001465,89.854003906,1117.026367188] * unit_scale,[781.279113770,94.783630371,1118.347290039] * unit_scale,[781.279113770,-293.444641113,2567.236083984] * unit_scale),
#([1144.123901367,-244.626647949,2580.316894531] * unit_scale,[781.279113770,-293.444641113,2567.236083984] * unit_scale,[781.279113770,94.783630371,1118.347290039] * unit_scale),
#([781.279113770,94.783630371,1118.347290039] * unit_scale,[1144.123901367,143.601623535,1131.428100586] * unit_scale,[1144.123901367,-244.626647949,2580.316894531] * unit_scale),
#([1469.473876953,-178.999450684,2597.901611328] * unit_scale,[1144.123901367,-244.626647949,2580.316894531] * unit_scale,[1144.123901367,143.601623535,1131.428100586] * unit_scale),
#([1144.123901367,143.601623535,1131.428100586] * unit_scale,[1469.473876953,209.228820801,1149.012817383] * unit_scale,[1469.473876953,-178.999450684,2597.901611328] * unit_scale),
#([1750.648925781,-98.498718262,2619.471679688] * unit_scale,[1469.473876953,-178.999450684,2597.901611328] * unit_scale,[1469.473876953,209.228820801,1149.012817383] * unit_scale),
#([1469.473876953,209.228820801,1149.012817383] * unit_scale,[1750.648925781,289.729614258,1170.582885742] * unit_scale,[1750.648925781,-98.498718262,2619.471679688] * unit_scale),
#([1980.969360352,-5.060485840,2644.508300781] * unit_scale,[1750.648925781,-98.498718262,2619.471679688] * unit_scale,[1750.648925781,289.729614258,1170.582885742] * unit_scale),
#([1750.648925781,289.729614258,1170.582885742] * unit_scale,[1980.969360352,383.167816162,1195.619506836] * unit_scale,[1980.969360352,-5.060485840,2644.508300781] * unit_scale),
#([2153.754882812,99.379699707,2672.493164062] * unit_scale,[1980.969360352,-5.060485840,2644.508300781] * unit_scale,[1980.969360352,383.167816162,1195.619506836] * unit_scale),
#([1980.969360352,383.167816162,1195.619506836] * unit_scale,[2153.754882812,487.607971191,1223.604248047] * unit_scale,[2153.754882812,99.379699707,2672.493164062] * unit_scale)
)
    local endpoint = [722.289001465,-284.396697998,2513.749755859] * unit_scale
    local neighbor = [737.908874512,-283.026000977,2513.855712891] * unit_scale
    local passed = false
    try
    (
        local extension = engine_value.traceCutEndpoint target_patches endpoint neighbor position_precision
        passed = extension.count > 0
        for segment_value in extension while passed do passed = (length(segment_value[2]-segment_value[1])) > position_precision
        format "SI CONTINUATION STUB TEST | segments:% precision:% passed:%\n" extension.count position_precision passed
    )
    catch
    (
        format "SI CONTINUATION STUB TEST FAILED | %\n" (getCurrentException())
    )
    passed
    -- return
)

/* Data checks always run; scene checks are an explicit second action. */
siCurveCutTestRun()
siDemandUpdateTestRun()


siEndpointSlicePlanTestRun()

siCollapsedRegionEdgesTestRun()

siExtendedCutTestRun()

siConvexContainmentTestRun()

siCumulativeContainmentTestRun()



siTerminalStubExtensionTestRun()

siWarpedSourcePatchTestRun()

siCollapsedCutSplitTestRun()

siContinuationStubTestRun()
