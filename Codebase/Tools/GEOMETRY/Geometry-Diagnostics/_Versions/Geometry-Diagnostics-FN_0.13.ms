/*
Geometry Diagnostics backend.
Owns Geometry Diagnostics test helpers and delegates reusable color painting to VertexColorPainter.
*/

global geometry_diagnostics_fn_version = "0.13"
global geometry_diagnostics_fn_project_version = "0.15"
global geometry_diagnostics_project_version
global geometry_diagnostics_test_node
global VertexColorPainter


global GeometryDiagnosticsOrthoEdgeResult

struct GeometryDiagnosticsOrthoEdgeResult_v
(
    source_node = undefined,
    target_stack_index = -1,
    target_stack_mod = undefined,
    position_precision_text = "",
    position_precision_value = 0.0,
    visible_edges = #{},
    horizontal_edges = #{},
    vertical_edges = #{},
    orthogonal_edges = #{},
    suspicious_edges = #{},
    edge_deviation_angles = #(),
    vertex_data = #(),

    on create do
    (
    )
)

GeometryDiagnosticsOrthoEdgeResult = GeometryDiagnosticsOrthoEdgeResult_v()


global GeometryDiagnosticsDirectionalEdgeResult

struct GeometryDiagnosticsDirectionalEdgeResult_v
(
    source_node = undefined,
    target_stack_index = -1,
    target_stack_mod = undefined,
    position_precision_text = "",
    position_precision_value = 0.0,
    direction_type = #vertical,
    selection_mode = #exact,
    angle_threshold = 0.0,
    visible_edges = #{},
    edge_ids = #{},
    vertex_data = #(),

    on create do
    (
    )
)

GeometryDiagnosticsDirectionalEdgeResult = GeometryDiagnosticsDirectionalEdgeResult_v()

if geometry_diagnostics_project_version == undefined then
(
    geometry_diagnostics_project_version = geometry_diagnostics_fn_project_version
)
else if (geometry_diagnostics_project_version as float) < (geometry_diagnostics_fn_project_version as float) then
(
    geometry_diagnostics_project_version = geometry_diagnostics_fn_project_version
)

if geometry_diagnostics_test_node == undefined then
(
    geometry_diagnostics_test_node = undefined
)


/*
Compares two integer arrays by value.
Returns true only when count and every indexed value match.
*/
function geometryDiagnosticsIntegerArraysMatch values_a values_b =
(
    if values_a == undefined or values_b == undefined then return false
    if values_a.count != values_b.count then return false

    for value_index = 1 to values_a.count do
    (
        if values_a[value_index] != values_b[value_index] then return false
    )

    true
    -- return
)


/*
Returns true when the supplied scene node has an Editable Poly base object.
This helper is used only by Geometry Diagnostics test and UI code.
*/
function isGeometryDiagnosticsEditablePolyNode source_node =
(
    if not isValidNode source_node then return false

    classOf source_node.baseObject == Editable_Poly
    -- return
)


/*
Resolves one canonical millimeter position-precision label to current scene/system units.
Returns undefined for unsupported labels instead of inventing a fallback precision.
*/
function resolveGeometryDiagnosticsPositionPrecision position_precision_text =
(
    case position_precision_text of
    (
        "1mm": (units.decodeValue "1mm")
        "0.1mm": (units.decodeValue "0.1mm")
        "0.01mm": (units.decodeValue "0.01mm")
        default:
        (
            format "Geometry Diagnostics POSITION PRECISION ERROR | supplied:% | expected:#(\"1mm\", \"0.1mm\", \"0.01mm\")\n" position_precision_text
            undefined
        )
    )
    -- return
)


/*
Quantizes one scalar to the nearest explicit position-precision step.
Uses verified floor arithmetic because MAXScript does not provide the assumed round() global.
*/
function quantizeGeometryDiagnosticsScalar scalar_value scalar_precision =
(
    if scalar_precision == undefined or scalar_precision <= 0.0 then
    (
        format "Geometry Diagnostics SCALAR QUANTIZE ERROR | value:% | precision:% | required:>0\n" scalar_value scalar_precision
        return undefined
    )

    local scaled_value = scalar_value / scalar_precision
    local rounded_steps = if scaled_value >= 0.0 then floor (scaled_value + 0.5) else -(floor ((-scaled_value) + 0.5))

    rounded_steps * scalar_precision
    -- return
)


/*
Rounds one temporary Point3 copy to the explicit position precision used for geometry classification.
The rounded value is comparison-only and is never written back to scene geometry.
*/
function roundGeometryDiagnosticsPosition position_value position_precision =
(
    if position_value == undefined or classOf position_value != Point3 then
    (
        format "Geometry Diagnostics POSITION ROUND ERROR | position:% | class:%\n" position_value (classOf position_value)
        return undefined
    )

    if position_precision == undefined or position_precision <= 0.0 then
    (
        format "Geometry Diagnostics POSITION ROUND ERROR | precision:% | required:>0\n" position_precision
        return undefined
    )

    local rounded_x = quantizeGeometryDiagnosticsScalar position_value.x position_precision
    local rounded_y = quantizeGeometryDiagnosticsScalar position_value.y position_precision
    local rounded_z = quantizeGeometryDiagnosticsScalar position_value.z position_precision

    if rounded_x == undefined or rounded_y == undefined or rounded_z == undefined then
    (
        format "Geometry Diagnostics POSITION ROUND ERROR | position:% | precision:% | rounded:[%,%,%]\n" \
            position_value position_precision rounded_x rounded_y rounded_z
        return undefined
    )

    [rounded_x, rounded_y, rounded_z]
    -- return
)


/*
Returns horizontal and vertical angular deviation for one raw world-space edge.
The result is #(horizontal_deviation, vertical_deviation) in degrees; zero-length edges return an empty Array.
*/
function getGeometryDiagnosticsEdgeAxisDeviation point_a point_b =
(
    if point_a == undefined or point_b == undefined or classOf point_a != Point3 or classOf point_b != Point3 then
    (
        format "Geometry Diagnostics DIRECTION ANGLE ERROR | point_a:% | point_b:% | classes:[%,%]\n" \
            point_a point_b (classOf point_a) (classOf point_b)
        return #()
    )

    local edge_vector = point_b - point_a
    local edge_length = length edge_vector

    if edge_length <= 0.0 then return #()

    local z_ratio = (abs edge_vector.z) / edge_length
    z_ratio = amin 1.0 (amax 0.0 z_ratio)

    local vertical_deviation = acos z_ratio
    local horizontal_deviation = abs (90.0 - vertical_deviation)

    #(horizontal_deviation, vertical_deviation)
    -- return
)


/*
Maps one orthogonal-deviation angle to the diagnostic severity ramp.
0 degrees is green, 15 degrees is blue, and 45 degrees is red, with linear interpolation between anchors.
*/
function getGeometryDiagnosticsOrthoSeverityColor deviation_angle =
(
    if deviation_angle == undefined then
    (
        format "Geometry Diagnostics ORTHO COLOR ERROR | angle is undefined.\n"
        return undefined
    )

    if classOf deviation_angle != Float and classOf deviation_angle != Integer then
    (
        format "Geometry Diagnostics ORTHO COLOR ERROR | angle:% | class:% | expected:Float or Integer\n" deviation_angle (classOf deviation_angle)
        return undefined
    )

    local clamped_angle = amin 45.0 (amax 0.0 (deviation_angle as float))
    local blue_anchor_angle = 15.0

    if clamped_angle <= blue_anchor_angle then
    (
        local blend_value = clamped_angle / blue_anchor_angle
        return color 0.0 (255.0 * (1.0 - blend_value)) (255.0 * blend_value)
    )

    local blend_value = (clamped_angle - blue_anchor_angle) / (45.0 - blue_anchor_angle)
    color (255.0 * blend_value) 0.0 (255.0 * (1.0 - blend_value))
    -- return
)


/*
Appends or raises one face-corner severity record.
When multiple visible edges share a face-corner, the largest orthogonal deviation wins deterministically.
*/
function appendGeometryDiagnosticsCornerSeverity corner_severity_data geo_vertex_id face_id deviation_angle =
(
    if corner_severity_data == undefined or classOf corner_severity_data != Array then
    (
        format "Geometry Diagnostics ORTHO CORNER ERROR | data:% | class:%\n" corner_severity_data (classOf corner_severity_data)
        return false
    )

    for row_index = 1 to corner_severity_data.count do
    (
        local row_data = corner_severity_data[row_index]

        if row_data.count == 3 and row_data[1] == geo_vertex_id and row_data[2] == face_id then
        (
            if deviation_angle > row_data[3] then
            (
                row_data[3] = deviation_angle
            )

            return true
        )
    )

    append corner_severity_data #(geo_vertex_id, face_id, deviation_angle)
    true
    -- return
)


/*
Builds variable-color paint rows for every visible orthogonal diagnostic edge.
Each face-corner receives the highest incident edge deviation before the green-blue-red color is resolved.
*/
function buildGeometryDiagnosticsOrthoSeverityPaintData ortho_result =
(
    if ortho_result == undefined then
    (
        format "Geometry Diagnostics ORTHO PAINT DATA ERROR | result is undefined.\n"
        return undefined
    )

    if VertexColorPainter == undefined or not VertexColorPainter.cache_valid then
    (
        format "Geometry Diagnostics ORTHO PAINT DATA ERROR | painter cache is unavailable.\n"
        return undefined
    )

    if ortho_result.edge_deviation_angles == undefined or classOf ortho_result.edge_deviation_angles != Array then
    (
        format "Geometry Diagnostics ORTHO PAINT DATA ERROR | edge_deviation_angles:% | class:%\n" \
            ortho_result.edge_deviation_angles (classOf ortho_result.edge_deviation_angles)
        return undefined
    )

    local corner_severity_data = #()

    for edge_id in ortho_result.visible_edges do
    (
        if edge_id < 1 or edge_id > VertexColorPainter.edge_count or edge_id > ortho_result.edge_deviation_angles.count then
        (
            format "Geometry Diagnostics ORTHO PAINT DATA ERROR | edge:% | painter_range:1..% | angle_count:%\n" \
                edge_id VertexColorPainter.edge_count ortho_result.edge_deviation_angles.count
            return undefined
        )

        local deviation_angle = ortho_result.edge_deviation_angles[edge_id]
        local current_edge_vertices = VertexColorPainter.edge_vertices[edge_id]
        local current_edge_faces = VertexColorPainter.edge_faces[edge_id]

        if deviation_angle == undefined or current_edge_vertices == undefined or current_edge_vertices.count != 2 or current_edge_faces == undefined or current_edge_faces.count == 0 then
        (
            format "Geometry Diagnostics ORTHO PAINT DATA ERROR | edge:% | angle:% | endpoints:% | faces:%\n" \
                edge_id deviation_angle current_edge_vertices current_edge_faces
            return undefined
        )

        for face_id in current_edge_faces do
        (
            if not appendGeometryDiagnosticsCornerSeverity corner_severity_data current_edge_vertices[1] face_id deviation_angle then return undefined
            if not appendGeometryDiagnosticsCornerSeverity corner_severity_data current_edge_vertices[2] face_id deviation_angle then return undefined
        )
    )

    local paint_data = #()

    for corner_data in corner_severity_data do
    (
        local corner_color = getGeometryDiagnosticsOrthoSeverityColor corner_data[3]

        if corner_color == undefined then return undefined

        append paint_data #(corner_data[1], corner_data[2], corner_color)
    )

    paint_data
    -- return
)


/*
Tests one rounded edge against the requested exact world-axis direction.
Exact horizontal means equal rounded Z; exact vertical means equal rounded X and Y.
*/
function isGeometryDiagnosticsExactDirection rounded_point_a rounded_point_b direction_type =
(
    if rounded_point_a == undefined or rounded_point_b == undefined or classOf rounded_point_a != Point3 or classOf rounded_point_b != Point3 then
    (
        format "Geometry Diagnostics EXACT DIRECTION ERROR | point_a:% | point_b:% | direction:%\n" \
            rounded_point_a rounded_point_b direction_type
        return false
    )

    if rounded_point_a == rounded_point_b then return false

    case direction_type of
    (
        #horizontal: (rounded_point_a.z == rounded_point_b.z)
        #vertical: (rounded_point_a.x == rounded_point_b.x and rounded_point_a.y == rounded_point_b.y)
        default:
        (
            format "Geometry Diagnostics EXACT DIRECTION ERROR | unsupported direction:% | expected:#horizontal or #vertical\n" direction_type
            false
        )
    )
    -- return
)


/*
Tests one edge for the Wall-Fixer-style exact or near-direction diagnostic mode.
Near-direction mode excludes exact rounded matches and accepts raw angular deviation above 0 degrees through Angle.
*/
function geometryDiagnosticsDirectionMatches raw_point_a raw_point_b rounded_point_a rounded_point_b direction_type selection_mode angle_threshold =
(
    if direction_type != #horizontal and direction_type != #vertical then
    (
        format "Geometry Diagnostics DIRECTION MATCH ERROR | unsupported direction:%\n" direction_type
        return false
    )

    if selection_mode != #exact and selection_mode != #skewed then
    (
        format "Geometry Diagnostics DIRECTION MATCH ERROR | unsupported mode:% | expected:#exact or #skewed\n" selection_mode
        return false
    )

    local exact_match = isGeometryDiagnosticsExactDirection rounded_point_a rounded_point_b direction_type

    if selection_mode == #exact then return exact_match

    if angle_threshold == undefined or angle_threshold <= 0.0 or angle_threshold > 45.0 then
    (
        format "Geometry Diagnostics DIRECTION MATCH ERROR | angle:% | required:>0 and <=45\n" angle_threshold
        return false
    )

    if exact_match then return false

    local deviations = getGeometryDiagnosticsEdgeAxisDeviation raw_point_a raw_point_b

    if deviations.count != 2 then return false

    local angle_from_target = if direction_type == #horizontal then deviations[1] else deviations[2]

    (angle_from_target > 0.0) and (angle_from_target <= angle_threshold)
    -- return
)


/*
Returns visible and currently selectable edge IDs from one validated Editable Poly topology.
The original edge selection is restored before the function returns.
*/
function getGeometryDiagnosticsVisibleSelectableEdges poly_value =
(
    if poly_value == undefined or classOf poly_value != Editable_Poly then
    (
        format "Geometry Diagnostics VISIBLE EDGE ERROR | poly:% | class:%\n" poly_value (classOf poly_value)
        return undefined
    )

    local edge_count = polyop.getNumEdges poly_value
    local visible_edges = #{}
    visible_edges.count = edge_count

    for edge_id = 1 to edge_count do
    (
        if polyop.getEdgeVis poly_value edge_id then
        (
            visible_edges[edge_id] = true
        )
    )

    local previous_edge_selection = polyop.getEdgeSelection poly_value

    if previous_edge_selection == undefined then
    (
        format "Geometry Diagnostics VISIBLE EDGE ERROR | could not read previous edge selection | edge_count:%\n" edge_count
        return undefined
    )

    polyop.setEdgeSelection poly_value #all
    local selectable_edges = polyop.getEdgeSelection poly_value
    polyop.setEdgeSelection poly_value previous_edge_selection

    if selectable_edges == undefined then
    (
        format "Geometry Diagnostics VISIBLE EDGE ERROR | could not resolve selectable edges | edge_count:%\n" edge_count
        return undefined
    )

    visible_edges * selectable_edges
    -- return
)


/*
Compares two two-vertex edge endpoint arrays without depending on endpoint order.
Returns false when either edge does not contain exactly two vertex IDs.
*/
function geometryDiagnosticsEdgePairsMatch edge_vertices_a edge_vertices_b =
(
    if edge_vertices_a == undefined or edge_vertices_b == undefined then return false
    if edge_vertices_a.count != 2 or edge_vertices_b.count != 2 then return false

    (edge_vertices_a[1] == edge_vertices_b[1] and edge_vertices_a[2] == edge_vertices_b[2]) or \
    (edge_vertices_a[1] == edge_vertices_b[2] and edge_vertices_a[2] == edge_vertices_b[1])
    -- return
)


/*
Appends one unique geometry-vertex plus polygon-face corner identity to diagnostic vertex data.
Returns true when the corner already exists or is appended successfully.
*/
function appendGeometryDiagnosticsVertexCornerUnique vertex_data geo_vertex_id face_id =
(
    if vertex_data == undefined or classOf vertex_data != Array then
    (
        format "Geometry Diagnostics VERTEX DATA ERROR | vertex_data:% | class:%\n" vertex_data (classOf vertex_data)
        return false
    )

    for corner_data in vertex_data do
    (
        if corner_data.count == 2 and corner_data[1] == geo_vertex_id and corner_data[2] == face_id then
        (
            return true
        )
    )

    append vertex_data #(geo_vertex_id, face_id)
    true
    -- return
)


/*
Converts cached edge IDs to unique face-corner vertex identities for VertexColorPainter.
Each returned row is #(geo_vertex_id, face_id) and can color an edge independently per face.
*/
function buildGeometryDiagnosticsEdgeVertexData edge_ids =
(
    if VertexColorPainter == undefined then
    (
        format "Geometry Diagnostics EDGE VERTEX DATA ERROR | VertexColorPainter is not loaded.\n"
        return undefined
    )

    if edge_ids == undefined or classOf edge_ids != BitArray then
    (
        format "Geometry Diagnostics EDGE VERTEX DATA ERROR | edge_ids:% | class:%\n" edge_ids (classOf edge_ids)
        return undefined
    )

    if not VertexColorPainter.cache_valid then
    (
        format "Geometry Diagnostics EDGE VERTEX DATA ERROR | painter cache is not valid.\n"
        return undefined
    )

    local vertex_data = #()

    for edge_id in edge_ids do
    (
        if edge_id < 1 or edge_id > VertexColorPainter.edge_count then
        (
            format "Geometry Diagnostics EDGE VERTEX DATA ERROR | edge:% | valid_range:1..%\n" edge_id VertexColorPainter.edge_count
            return undefined
        )

        local current_edge_vertices = VertexColorPainter.edge_vertices[edge_id]
        local current_edge_faces = VertexColorPainter.edge_faces[edge_id]

        if current_edge_vertices == undefined or current_edge_vertices.count != 2 then
        (
            format "Geometry Diagnostics EDGE VERTEX DATA ERROR | edge:% | endpoints:% | expected:2 endpoints\n" edge_id current_edge_vertices
            return undefined
        )

        if current_edge_faces == undefined or current_edge_faces.count == 0 then
        (
            format "Geometry Diagnostics EDGE VERTEX DATA ERROR | edge:% | adjacent_faces:% | expected:at least one face\n" edge_id current_edge_faces
            return undefined
        )

        for face_id in current_edge_faces do
        (
            if face_id < 1 or face_id > VertexColorPainter.face_count then
            (
                format "Geometry Diagnostics EDGE VERTEX DATA ERROR | edge:% | face:% | valid_face_range:1..%\n" edge_id face_id VertexColorPainter.face_count
                return undefined
            )

            if not appendGeometryDiagnosticsVertexCornerUnique vertex_data current_edge_vertices[1] face_id then return undefined
            if not appendGeometryDiagnosticsVertexCornerUnique vertex_data current_edge_vertices[2] face_id then return undefined
        )
    )

    vertex_data
    -- return
)


/*
Converts diagnostic #(geo_vertex_id, face_id) rows to VertexColorPainter paint rows.
The supplied color is attached without changing the stored diagnostic identities.
*/
function geometryDiagnosticsVertexDataToPaintData vertex_data color_value =
(
    if vertex_data == undefined or classOf vertex_data != Array then
    (
        format "Geometry Diagnostics PAINT DATA ERROR | vertex_data:% | class:%\n" vertex_data (classOf vertex_data)
        return undefined
    )

    if color_value == undefined or classOf color_value != Color then
    (
        format "Geometry Diagnostics PAINT DATA ERROR | color:% | class:%\n" color_value (classOf color_value)
        return undefined
    )

    local paint_data = #()

    for corner_data in vertex_data do
    (
        if corner_data == undefined or classOf corner_data != Array or corner_data.count != 2 then
        (
            format "Geometry Diagnostics PAINT DATA ERROR | corner_data:% | expected:#(geo_vertex_id, face_id)\n" corner_data
            return undefined
        )

        append paint_data #(corner_data[1], corner_data[2], color_value)
    )

    paint_data
    -- return
)


/*
Converts a MAXScript Color to channel-map Point3 values through the shared painter contract.
Returns undefined when VertexColorPainter is unavailable or the color is invalid.
*/
function geometryDiagnosticsColorToMapPoint color_value =
(
    if VertexColorPainter == undefined then return undefined

    VertexColorPainter.colorToMapPoint color_value
    -- return
)


/*
Converts a MAXScript Color to VertexPaint Point4 values through the shared painter contract.
Returns undefined when VertexColorPainter is unavailable or the color is invalid.
*/
function geometryDiagnosticsColorToPaintPoint4 color_value =
(
    if VertexColorPainter == undefined then return undefined

    VertexColorPainter.colorToPaintPoint4 color_value
    -- return
)


/*
Returns 1 while the shared painter holds an active direct-base restore backup for this node.
This compatibility helper exists only for the existing Geometry Diagnostics regression test.
*/
function getGeometryDiagnosticsBackupIndex source_node =
(
    if VertexColorPainter == undefined then return 0

    if VertexColorPainter.source_node == source_node and VertexColorPainter.base_backup_valid then
    (
        return 1
    )

    0
    -- return
)


/*
Resolves the exact Modify-panel stack level selected for Geometry Diagnostics painting.
Editable Poly/base selection returns 0; an owned PaintLayerMod resolves back to its exact supported target.
*/
function getGeometryDiagnosticsSelectedPaintStackIndex source_node =
(
    if VertexColorPainter == undefined then return undefined
    if not isValidNode source_node then return undefined

    max modify mode

    local current_stack_object = modPanel.getCurrentObject()

    if current_stack_object == undefined then return 0
    if current_stack_object == source_node then return 0
    if current_stack_object == source_node.baseObject then return 0

    if VertexColorPainter.source_node == source_node then
    (
        local owned_paint_layer = VertexColorPainter.getPaintLayerMod()

        if owned_paint_layer != undefined and current_stack_object == owned_paint_layer then
        (
            local current_target_index = VertexColorPainter.getCurrentTargetStackIndex()

            if current_target_index > 0 then return current_target_index
        )
    )

    local selected_modifier_index = modPanel.getModifierIndex source_node current_stack_object

    if selected_modifier_index == undefined then
    (
        format "Geometry Diagnostics: the selected Modify-panel object is not part of the target node stack.\n"
        return undefined
    )

    if not VertexColorPainter.isSupportedStackTarget current_stack_object then
    (
        format "Geometry Diagnostics: selected modifier class % is not supported by VertexColorPainter.\n" (classOf current_stack_object)
        return undefined
    )

    selected_modifier_index
    -- return
)


/*
Binds VertexColorPainter to the exact stack level selected in the Modify panel.
Editable Poly/base selection paints channel 0 directly; a supported selected modifier paints through PaintLayerMod above that modifier.
*/
function ensureGeometryDiagnosticsPainterTarget source_node =
(
    if VertexColorPainter == undefined then
    (
        format "Geometry Diagnostics: VertexColorPainter operation is not loaded.\n"
        return false
    )

    if not isValidNode source_node then return false

    local target_stack_index = getGeometryDiagnosticsSelectedPaintStackIndex source_node

    if target_stack_index == undefined then return false

    if VertexColorPainter.source_node == source_node and VertexColorPainter.stack_index == target_stack_index then
    (
        if VertexColorPainter.cache_valid and not VertexColorPainter.topology_dirty and VertexColorPainter.isTargetValid() then
        (
            return true
        )
    )

    VertexColorPainter.setTarget source_node target_stack_index
    -- return
)


/*
Resolves geometry vertices to cached direct channel-0 map vertices through VertexColorPainter.
Returns undefined when the requested node cannot be bound to the direct base backend.
*/
function getGeometryDiagnosticsMapVerticesForGeometryVertices source_node vertex_ids =
(
    if VertexColorPainter == undefined then return undefined
    if not isGeometryDiagnosticsEditablePolyNode source_node then return undefined

    if VertexColorPainter.source_node != source_node or VertexColorPainter.stack_index != 0 then
    (
        if not VertexColorPainter.setTarget source_node 0 then return undefined
    )

    if not VertexColorPainter.cache_valid then return undefined

    local requested_vertex_ids = #()
    local resolved_map_vert_ids = #()
    local target_class = classOf vertex_ids

    if target_class == Integer then
    (
        append requested_vertex_ids vertex_ids
    )
    else if target_class == BitArray then
    (
        for vertex_id in vertex_ids do
        (
            append requested_vertex_ids vertex_id
        )
    )
    else if target_class == Array then
    (
        for vertex_id in vertex_ids do
        (
            append requested_vertex_ids vertex_id
        )
    )
    else
    (
        return undefined
    )

    if requested_vertex_ids.count == 0 then return #()

    if VertexColorPainter.geo_to_map_vertices.count != VertexColorPainter.vertex_count then
    (
        local poly_value = source_node.baseObject

        if not polyop.getMapSupport poly_value 0 then return #()
        if not VertexColorPainter.buildBaseMapCache() then return undefined
    )

    for vertex_id in requested_vertex_ids do
    (
        if classOf vertex_id != Integer then return undefined
        if vertex_id < 1 or vertex_id > VertexColorPainter.vertex_count then return undefined

        for map_vert_id in VertexColorPainter.geo_to_map_vertices[vertex_id] do
        (
            if findItem resolved_map_vert_ids map_vert_id == 0 then
            (
                append resolved_map_vert_ids map_vert_id
            )
        )
    )

    resolved_map_vert_ids
    -- return
)


/*
Returns the Geometry Diagnostics owned VertexPaint layer on one node.
This compatibility helper does not change the current painter target.
*/
function getGeometryDiagnosticsPaintLayerMod source_node =
(
    if VertexColorPainter == undefined then return undefined
    if not isValidNode source_node then return undefined
    if VertexColorPainter.source_node != source_node then return undefined

    VertexColorPainter.getPaintLayerMod()
    -- return
)


/*
Returns the evaluated geometry vertex count of one node.
A temporary mesh is used only for Geometry Diagnostics regression assertions.
*/
function getGeometryDiagnosticsEvaluatedVertexCount source_node =
(
    if not isValidNode source_node then return 0

    local evaluated_mesh = snapshotAsMesh source_node

    if evaluated_mesh == undefined then return 0

    local evaluated_vertex_count = getNumVerts evaluated_mesh
    delete evaluated_mesh

    evaluated_vertex_count
    -- return
)


/*
Acquires one VertexPaintState from a verified PaintLayerMod.
Returns undefined when the node or paint layer cannot provide a state.
*/
function acquireGeometryDiagnosticsPaintState source_node paint_layer_mod =
(
    if not isValidNode source_node then return undefined
    if paint_layer_mod == undefined then return undefined
    if classOf paint_layer_mod != PaintLayerMod then return undefined

    completeRedraw()

    paint_layer_mod.AcquirePaintState source_node
    -- return
)


/*
Paints one or more geometry vertices through the shared VertexColorPainter operation.
The active cached target is reused so repeated calls do not rebuild topology.
*/
function paintGeometryDiagnosticsVertices source_node vertex_ids color_value =
(
    if not ensureGeometryDiagnosticsPainterTarget source_node then return false

    VertexColorPainter.paintVertices vertex_ids color_value
    -- return
)


/*
Paints every corner of one polygon face through the shared VertexColorPainter operation.
The face ID belongs to the painter's cached Editable Poly topology domain.
*/
function paintGeometryDiagnosticsFaceCorners source_node face_id color_value =
(
    if not ensureGeometryDiagnosticsPainterTarget source_node then return false

    VertexColorPainter.paintFace face_id color_value
    -- return
)


/*
Paints one cached edge only on one specified polygon face.
Only the two face-corner vertex entries belonging to that edge on that face are changed.
*/
function paintGeometryDiagnosticsEdgeOnFace source_node edge_id face_id color_value =
(
    if not ensureGeometryDiagnosticsPainterTarget source_node then
    (
        format "Geometry Diagnostics EDGE-ON-FACE ERROR | could not bind painter target | node:%\n" source_node
        return false
    )

    if classOf edge_id != Integer or edge_id < 1 or edge_id > VertexColorPainter.edge_count then
    (
        format "Geometry Diagnostics EDGE-ON-FACE ERROR | edge:% | valid_range:1..%\n" edge_id VertexColorPainter.edge_count
        return false
    )

    if classOf face_id != Integer or face_id < 1 or face_id > VertexColorPainter.face_count then
    (
        format "Geometry Diagnostics EDGE-ON-FACE ERROR | face:% | valid_range:1..%\n" face_id VertexColorPainter.face_count
        return false
    )

    local current_edge_vertices = VertexColorPainter.edge_vertices[edge_id]
    local current_edge_faces = VertexColorPainter.edge_faces[edge_id]

    if current_edge_vertices == undefined or current_edge_vertices.count != 2 then
    (
        format "Geometry Diagnostics EDGE-ON-FACE ERROR | edge:% | endpoints:% | expected:2 endpoints\n" edge_id current_edge_vertices
        return false
    )

    if current_edge_faces == undefined or findItem current_edge_faces face_id == 0 then
    (
        format "Geometry Diagnostics EDGE-ON-FACE ERROR | edge:% | requested_face:% | adjacent_faces:%\n" edge_id face_id current_edge_faces
        return false
    )

    local vertex_data = #(
        #(current_edge_vertices[1], face_id),
        #(current_edge_vertices[2], face_id)
    )
    local paint_data = geometryDiagnosticsVertexDataToPaintData vertex_data color_value

    if paint_data == undefined then return false

    VertexColorPainter.paintCorners paint_data
    -- return
)


/*
Analyzes visible edges on the exact selected paint topology as horizontal, vertical, or suspicious.
The world-axis definitions mirror the proven Straight-Edge-Fixer checks; Geometry Diagnostics applies explicit position rounding instead of tolerance.
Horizontal means equal rounded world Z; vertical means equal rounded world X and Y; zero-length rounded edges are suspicious.
*/
function analyzeGeometryDiagnosticsOrthoEdges source_node position_precision_text =
(
    if not isValidNode source_node then
    (
        format "Geometry Diagnostics ORTHO ERROR | invalid node:%\n" source_node
        return undefined
    )

    local position_precision = resolveGeometryDiagnosticsPositionPrecision position_precision_text

    if position_precision == undefined or position_precision <= 0.0 then
    (
        format "Geometry Diagnostics ORTHO ERROR | precision_text:% | resolved_precision:%\n" position_precision_text position_precision
        return undefined
    )

    if not ensureGeometryDiagnosticsPainterTarget source_node then
    (
        format "Geometry Diagnostics ORTHO ERROR | could not bind selected topology | node:%\n" source_node.name
        return undefined
    )

    local current_target_index = VertexColorPainter.getCurrentTargetStackIndex()

    if current_target_index < 0 then
    (
        format "Geometry Diagnostics ORTHO ERROR | target_index:% | node:%\n" current_target_index source_node.name
        return undefined
    )

    local analysis_node = undefined
    local analysis_poly = undefined
    local temp_node = undefined
    local operation_failed = false
    local exception_text = ""
    local result_value = undefined

    try
    (
        with redraw off
        with undo off
        (
            temp_node = copy source_node
            temp_node.name = uniqueName "GeometryDiagnostics_OrthoAnalysis"

            if current_target_index == 0 then
            (
                for mod_index = temp_node.modifiers.count to 1 by -1 do
                (
                    deleteModifier temp_node mod_index
                )
            )
            else if current_target_index > 1 then
            (
                for mod_index = (current_target_index - 1) to 1 by -1 do
                (
                    deleteModifier temp_node mod_index
                )
            )

            if current_target_index > 0 then
            (
                convertTo temp_node Editable_Poly
            )

            if classOf temp_node.baseObject != Editable_Poly then
            (
                format "Geometry Diagnostics ORTHO ANALYSIS ERROR | temp base class:% | expected:Editable_Poly | target_index:%\n" \
                    (classOf temp_node.baseObject) current_target_index
                throw "Geometry Diagnostics ortho analysis requires Editable Poly topology."
            )

            temp_node.baseObject.showCage = off
            analysis_node = temp_node
            analysis_poly = temp_node.baseObject

            if polyop.getHasDeadStructs analysis_poly != 0 then
            (
                polyop.collapseDeadStructs analysis_poly
            )
        )

        local vertex_count = polyop.getNumVerts analysis_poly
        local edge_count = polyop.getNumEdges analysis_poly
        local face_count = polyop.getNumFaces analysis_poly

        if vertex_count != VertexColorPainter.vertex_count or edge_count != VertexColorPainter.edge_count or face_count != VertexColorPainter.face_count then
        (
            format "Geometry Diagnostics ORTHO TOPOLOGY MISMATCH | target_counts:[%,%,%] | analysis_counts:[%,%,%] | target_index:%\n" \
                VertexColorPainter.vertex_count VertexColorPainter.edge_count VertexColorPainter.face_count \
                vertex_count edge_count face_count current_target_index
            throw "Geometry Diagnostics ortho topology count mismatch."
        )

        for face_id = 1 to face_count do
        (
            local analysis_face_vertices = polyop.getFaceVerts analysis_poly face_id
            local cached_face_vertices = VertexColorPainter.face_vertices[face_id]

            if not geometryDiagnosticsIntegerArraysMatch analysis_face_vertices cached_face_vertices then
            (
                format "Geometry Diagnostics ORTHO FACE MISMATCH | face:% | cached:% | analysis:% | target_index:%\n" \
                    face_id cached_face_vertices analysis_face_vertices current_target_index
                throw "Geometry Diagnostics ortho face identity mismatch."
            )
        )

        for edge_id = 1 to edge_count do
        (
            local analysis_edge_vertices = polyop.getEdgeVerts analysis_poly edge_id
            local cached_edge_vertices = VertexColorPainter.edge_vertices[edge_id]

            if not geometryDiagnosticsEdgePairsMatch analysis_edge_vertices cached_edge_vertices then
            (
                format "Geometry Diagnostics ORTHO EDGE MISMATCH | edge:% | cached:% | analysis:% | target_index:%\n" \
                    edge_id cached_edge_vertices analysis_edge_vertices current_target_index
                throw "Geometry Diagnostics ortho edge identity mismatch."
            )
        )

        local visible_edges = getGeometryDiagnosticsVisibleSelectableEdges analysis_poly

        if visible_edges == undefined then
        (
            throw "Geometry Diagnostics visible-edge resolution failed."
        )

        local horizontal_edges = #{}
        local vertical_edges = #{}
        local orthogonal_edges = #{}
        local edge_deviation_angles = #()

        horizontal_edges.count = edge_count
        vertical_edges.count = edge_count
        orthogonal_edges.count = edge_count
        edge_deviation_angles.count = edge_count

        for edge_id in visible_edges do
        (
            local edge_vertices = polyop.getEdgeVerts analysis_poly edge_id

            if edge_vertices == undefined or edge_vertices.count != 2 then
            (
                format "Geometry Diagnostics ORTHO EDGE READ ERROR | edge:% | endpoints:%\n" edge_id edge_vertices
                throw "Geometry Diagnostics ortho edge endpoint read failed."
            )

            local raw_position_a = undefined
            local raw_position_b = undefined

            in coordsys world
            (
                raw_position_a = polyop.getVert analysis_poly edge_vertices[1] node:analysis_node
                raw_position_b = polyop.getVert analysis_poly edge_vertices[2] node:analysis_node
            )

            local rounded_position_a = roundGeometryDiagnosticsPosition raw_position_a position_precision
            local rounded_position_b = roundGeometryDiagnosticsPosition raw_position_b position_precision

            if rounded_position_a == undefined or rounded_position_b == undefined then
            (
                format "Geometry Diagnostics ORTHO POSITION ERROR | edge:% | raw_a:% | raw_b:% | rounded_a:% | rounded_b:% | precision:%\n" \
                    edge_id raw_position_a raw_position_b rounded_position_a rounded_position_b position_precision_text
                throw "Geometry Diagnostics ortho position rounding failed."
            )

            local deviations = getGeometryDiagnosticsEdgeAxisDeviation raw_position_a raw_position_b
            local nearest_deviation = if deviations.count == 2 then amin deviations[1] deviations[2] else 45.0
            nearest_deviation = amin 45.0 (amax 0.0 nearest_deviation)

            if rounded_position_a != rounded_position_b then
            (
                if rounded_position_a.z == rounded_position_b.z then
                (
                    horizontal_edges[edge_id] = true
                    orthogonal_edges[edge_id] = true
                    edge_deviation_angles[edge_id] = 0.0
                )
                else if rounded_position_a.x == rounded_position_b.x and rounded_position_a.y == rounded_position_b.y then
                (
                    vertical_edges[edge_id] = true
                    orthogonal_edges[edge_id] = true
                    edge_deviation_angles[edge_id] = 0.0
                )
                else
                (
                    edge_deviation_angles[edge_id] = nearest_deviation
                )
            )
            else
            (
                edge_deviation_angles[edge_id] = 45.0
            )
        )

        local suspicious_edges = copy visible_edges
        suspicious_edges -= orthogonal_edges

        local vertex_data = buildGeometryDiagnosticsEdgeVertexData suspicious_edges

        if vertex_data == undefined then
        (
            throw "Geometry Diagnostics suspicious-edge vertex-data conversion failed."
        )

        result_value = GeometryDiagnosticsOrthoEdgeResult_v()
        result_value.source_node = source_node
        result_value.target_stack_index = current_target_index
        result_value.target_stack_mod = VertexColorPainter.target_stack_mod
        result_value.position_precision_text = position_precision_text
        result_value.position_precision_value = position_precision
        result_value.visible_edges = copy visible_edges
        result_value.horizontal_edges = copy horizontal_edges
        result_value.vertical_edges = copy vertical_edges
        result_value.orthogonal_edges = copy orthogonal_edges
        result_value.suspicious_edges = copy suspicious_edges
        result_value.edge_deviation_angles = edge_deviation_angles
        result_value.vertex_data = vertex_data
    )
    catch
    (
        exception_text = getCurrentException()
        operation_failed = true
    )

    if isValidNode temp_node then
    (
        delete temp_node
    )

    if operation_failed then
    (
        format "Geometry Diagnostics ORTHO ERROR | node:% | target_index:% | precision:% | exception:%\n" \
            source_node.name current_target_index position_precision_text exception_text
        return undefined
    )

    if result_value == undefined then
    (
        format "Geometry Diagnostics ORTHO ERROR | analysis produced no result | node:% | target_index:% | precision:%\n" \
            source_node.name current_target_index position_precision_text
        return undefined
    )

    GeometryDiagnosticsOrthoEdgeResult = result_value

    format "\n=== Geometry Diagnostics : Ortho Edges ===\n"
    format "NODE: %\n" source_node.name
    format "TARGET STACK INDEX: %\n" result_value.target_stack_index
    format "POSITION PRECISION: % -> % scene units\n" result_value.position_precision_text result_value.position_precision_value
    format "VISIBLE EDGES: % | %\n" result_value.visible_edges.numberSet result_value.visible_edges
    format "HORIZONTAL EDGES: % | %\n" result_value.horizontal_edges.numberSet result_value.horizontal_edges
    format "VERTICAL EDGES: % | %\n" result_value.vertical_edges.numberSet result_value.vertical_edges
    format "ORTHOGONAL EDGES: % | %\n" result_value.orthogonal_edges.numberSet result_value.orthogonal_edges
    format "SUSPICIOUS EDGES: % | %\n" result_value.suspicious_edges.numberSet result_value.suspicious_edges
    format "ORTHO SEVERITY COLORS: 0deg green -> 15deg blue -> 45deg red\n"
    format "SUSPICIOUS FACE-CORNER VERTEX DATA: % rows\n" result_value.vertex_data.count
    format "===========================================\n"

    result_value
    -- return
)


/*
Analyzes one Wall-Fixer-style direction button mode on the exact selected topology.
LMB mode returns exact rounded horizontal/vertical edges; RMB mode returns non-exact edges within the supplied Angle.
*/
function analyzeGeometryDiagnosticsDirectionEdges source_node direction_type selection_mode position_precision_text angle_threshold =
(
    if direction_type != #horizontal and direction_type != #vertical then
    (
        format "Geometry Diagnostics DIRECTION ERROR | unsupported direction:%\n" direction_type
        return undefined
    )

    if selection_mode != #exact and selection_mode != #skewed then
    (
        format "Geometry Diagnostics DIRECTION ERROR | unsupported mode:%\n" selection_mode
        return undefined
    )

    if angle_threshold == undefined or angle_threshold <= 0.0 or angle_threshold > 45.0 then
    (
        format "Geometry Diagnostics DIRECTION ERROR | angle:% | required:>0 and <=45\n" angle_threshold
        return undefined
    )

    local ortho_result = analyzeGeometryDiagnosticsOrthoEdges source_node position_precision_text

    if ortho_result == undefined then return undefined

    local matched_edges = #{}
    matched_edges.count = ortho_result.visible_edges.count

    if selection_mode == #exact then
    (
        matched_edges = if direction_type == #horizontal then copy ortho_result.horizontal_edges else copy ortho_result.vertical_edges
    )
    else
    (
        local current_target_index = ortho_result.target_stack_index
        local analysis_node = undefined
        local analysis_poly = undefined
        local temp_node = undefined
        local operation_failed = false
        local exception_text = ""

        try
        (
            with redraw off
            with undo off
            (
                temp_node = copy source_node
                temp_node.name = uniqueName "GeometryDiagnostics_DirectionAnalysis"

                if current_target_index == 0 then
                (
                    for mod_index = temp_node.modifiers.count to 1 by -1 do
                    (
                        deleteModifier temp_node mod_index
                    )
                )
                else if current_target_index > 1 then
                (
                    for mod_index = (current_target_index - 1) to 1 by -1 do
                    (
                        deleteModifier temp_node mod_index
                    )
                )

                if current_target_index > 0 then
                (
                    convertTo temp_node Editable_Poly
                )

                if classOf temp_node.baseObject != Editable_Poly then
                (
                    format "Geometry Diagnostics DIRECTION ANALYSIS ERROR | temp base class:% | expected:Editable_Poly | target_index:%\n" \
                        (classOf temp_node.baseObject) current_target_index
                    throw "Geometry Diagnostics direction analysis requires Editable Poly topology."
                )

                temp_node.baseObject.showCage = off
                analysis_node = temp_node
                analysis_poly = temp_node.baseObject

                if polyop.getHasDeadStructs analysis_poly != 0 then
                (
                    polyop.collapseDeadStructs analysis_poly
                )
            )

            local vertex_count = polyop.getNumVerts analysis_poly
            local edge_count = polyop.getNumEdges analysis_poly
            local face_count = polyop.getNumFaces analysis_poly

            if vertex_count != VertexColorPainter.vertex_count or edge_count != VertexColorPainter.edge_count or face_count != VertexColorPainter.face_count then
            (
                format "Geometry Diagnostics DIRECTION TOPOLOGY MISMATCH | target_counts:[%,%,%] | analysis_counts:[%,%,%] | target_index:%\n" \
                    VertexColorPainter.vertex_count VertexColorPainter.edge_count VertexColorPainter.face_count \
                    vertex_count edge_count face_count current_target_index
                throw "Geometry Diagnostics direction topology count mismatch."
            )

            matched_edges.count = edge_count

            for edge_id in ortho_result.visible_edges do
            (
                local analysis_edge_vertices = polyop.getEdgeVerts analysis_poly edge_id
                local cached_edge_vertices = VertexColorPainter.edge_vertices[edge_id]

                if not geometryDiagnosticsEdgePairsMatch analysis_edge_vertices cached_edge_vertices then
                (
                    format "Geometry Diagnostics DIRECTION EDGE MISMATCH | edge:% | cached:% | analysis:% | target_index:%\n" \
                        edge_id cached_edge_vertices analysis_edge_vertices current_target_index
                    throw "Geometry Diagnostics direction edge identity mismatch."
                )

                local raw_point_a = undefined
                local raw_point_b = undefined

                in coordsys world
                (
                    raw_point_a = polyop.getVert analysis_poly analysis_edge_vertices[1] node:analysis_node
                    raw_point_b = polyop.getVert analysis_poly analysis_edge_vertices[2] node:analysis_node
                )

                local rounded_point_a = roundGeometryDiagnosticsPosition raw_point_a ortho_result.position_precision_value
                local rounded_point_b = roundGeometryDiagnosticsPosition raw_point_b ortho_result.position_precision_value

                if rounded_point_a == undefined or rounded_point_b == undefined then
                (
                    format "Geometry Diagnostics DIRECTION POSITION ERROR | edge:% | raw_a:% | raw_b:% | rounded_a:% | rounded_b:% | precision:%\n" \
                        edge_id raw_point_a raw_point_b rounded_point_a rounded_point_b position_precision_text
                    throw "Geometry Diagnostics direction position rounding failed."
                )

                if geometryDiagnosticsDirectionMatches \
                    raw_point_a raw_point_b rounded_point_a rounded_point_b \
                    direction_type selection_mode angle_threshold then
                (
                    matched_edges[edge_id] = true
                )
            )
        )
        catch
        (
            exception_text = getCurrentException()
            operation_failed = true
        )

        if isValidNode temp_node then
        (
            delete temp_node
        )

        if operation_failed then
        (
            format "Geometry Diagnostics DIRECTION ERROR | node:% | target_index:% | direction:% | mode:% | angle:% | precision:% | exception:%\n" \
                source_node.name current_target_index direction_type selection_mode angle_threshold position_precision_text exception_text
            return undefined
        )
    )

    local vertex_data = buildGeometryDiagnosticsEdgeVertexData matched_edges

    if vertex_data == undefined then
    (
        format "Geometry Diagnostics DIRECTION ERROR | could not convert edge ids to vertex data | direction:% | mode:% | edges:%\n" \
            direction_type selection_mode matched_edges
        return undefined
    )

    local result_value = GeometryDiagnosticsDirectionalEdgeResult_v()
    result_value.source_node = source_node
    result_value.target_stack_index = ortho_result.target_stack_index
    result_value.target_stack_mod = ortho_result.target_stack_mod
    result_value.position_precision_text = position_precision_text
    result_value.position_precision_value = ortho_result.position_precision_value
    result_value.direction_type = direction_type
    result_value.selection_mode = selection_mode
    result_value.angle_threshold = angle_threshold
    result_value.visible_edges = copy ortho_result.visible_edges
    result_value.edge_ids = copy matched_edges
    result_value.vertex_data = vertex_data

    GeometryDiagnosticsDirectionalEdgeResult = result_value

    format "\n=== Geometry Diagnostics : Direction Edges ===\n"
    format "NODE: %\n" source_node.name
    format "DIRECTION: % | MODE: % | ANGLE: %\n" direction_type selection_mode angle_threshold
    format "POSITION PRECISION: % -> % scene units\n" position_precision_text result_value.position_precision_value
    format "MATCHED EDGES: % | %\n" result_value.edge_ids.numberSet result_value.edge_ids
    format "FACE-CORNER VERTEX DATA: % rows\n" result_value.vertex_data.count
    format "================================================\n"

    result_value
    -- return
)


/*
Replaces current Geometry Diagnostics paint with one directional-edge diagnostic overlay.
The requested edge set is painted orange through exact face-corner vertex data.
*/
function paintGeometryDiagnosticsDirectionalResult source_node direction_result color_value =
(
    if direction_result == undefined then
    (
        format "Geometry Diagnostics DIRECTION PAINT ERROR | result is undefined.\n"
        return false
    )

    if not isValidNode source_node or direction_result.source_node != source_node then
    (
        format "Geometry Diagnostics DIRECTION PAINT ERROR | source_node:% | result_node:%\n" source_node direction_result.source_node
        return false
    )

    if VertexColorPainter == undefined or VertexColorPainter.source_node != source_node then
    (
        format "Geometry Diagnostics DIRECTION PAINT ERROR | painter is not bound to result node:%\n" source_node.name
        return false
    )

    if direction_result.target_stack_index == 0 then
    (
        if VertexColorPainter.stack_index != 0 then
        (
            format "Geometry Diagnostics DIRECTION PAINT ERROR | expected base target index:0 | actual:%\n" VertexColorPainter.stack_index
            return false
        )
    )
    else if VertexColorPainter.target_stack_mod != direction_result.target_stack_mod then
    (
        format "Geometry Diagnostics DIRECTION PAINT ERROR | expected target:% | actual:%\n" \
            direction_result.target_stack_mod VertexColorPainter.target_stack_mod
        return false
    )

    local paint_data = geometryDiagnosticsVertexDataToPaintData direction_result.vertex_data color_value

    if paint_data == undefined then return false

    if not VertexColorPainter.clearPaint() then
    (
        format "Geometry Diagnostics DIRECTION PAINT ERROR | could not clear previous owned paint | node:%\n" source_node.name
        return false
    )

    if paint_data.count == 0 then
    (
        completeRedraw()
        return true
    )

    if not VertexColorPainter.beginPaint() then
    (
        format "Geometry Diagnostics DIRECTION PAINT ERROR | beginPaint failed | node:% | edges:%\n" \
            source_node.name direction_result.edge_ids
        return false
    )

    local paint_result = true

    undo "Geometry Diagnostics - Direction Edges" on
    (
        paint_result = VertexColorPainter.paintCorners paint_data
    )

    local end_result = VertexColorPainter.endPaint()

    if not paint_result or not end_result then
    (
        format "Geometry Diagnostics DIRECTION PAINT ERROR | paint_result:% | end_result:% | edges:%\n" \
            paint_result end_result direction_result.edge_ids
        return false
    )

    true
    -- return
)


/*
Runs one Wall-Fixer-style direction button action and paints the matched edges orange.
LMB callers use #exact; RMB callers use #skewed with the current Angle threshold.
*/
function checkGeometryDiagnosticsDirectionEdges source_node direction_type selection_mode position_precision_text angle_threshold =
(
    local direction_result = analyzeGeometryDiagnosticsDirectionEdges \
        source_node direction_type selection_mode position_precision_text angle_threshold

    if direction_result == undefined then return undefined

    if not paintGeometryDiagnosticsDirectionalResult source_node direction_result (color 255 128 0) then
    (
        format "Geometry Diagnostics CHECK DIRECTION ERROR | node:% | direction:% | mode:% | precision:% | angle:%\n" \
            source_node.name direction_type selection_mode position_precision_text angle_threshold
        return undefined
    )

    direction_result
    -- return
)


/*
Replaces current Geometry Diagnostics paint with the orthogonal-deviation severity overlay.
Every visible edge contributes green at 0 degrees, blue at 15 degrees, and red at 45 degrees through face-corner vertex data.
*/
function paintGeometryDiagnosticsOrthoResult source_node ortho_result =
(
    if ortho_result == undefined then
    (
        format "Geometry Diagnostics ORTHO PAINT ERROR | result is undefined.\n"
        return false
    )

    if not isValidNode source_node or ortho_result.source_node != source_node then
    (
        format "Geometry Diagnostics ORTHO PAINT ERROR | source_node:% | result_node:%\n" source_node ortho_result.source_node
        return false
    )

    if VertexColorPainter == undefined or VertexColorPainter.source_node != source_node then
    (
        format "Geometry Diagnostics ORTHO PAINT ERROR | painter is not bound to result node:%\n" source_node.name
        return false
    )

    if ortho_result.target_stack_index == 0 then
    (
        if VertexColorPainter.stack_index != 0 then
        (
            format "Geometry Diagnostics ORTHO PAINT ERROR | expected base target index:0 | actual:%\n" VertexColorPainter.stack_index
            return false
        )
    )
    else if VertexColorPainter.target_stack_mod != ortho_result.target_stack_mod then
    (
        format "Geometry Diagnostics ORTHO PAINT ERROR | expected target:% | actual:%\n" ortho_result.target_stack_mod VertexColorPainter.target_stack_mod
        return false
    )

    local paint_data = buildGeometryDiagnosticsOrthoSeverityPaintData ortho_result

    if paint_data == undefined then return false

    if not VertexColorPainter.clearPaint() then
    (
        format "Geometry Diagnostics ORTHO PAINT ERROR | could not clear previous owned paint | node:%\n" source_node.name
        return false
    )

    if paint_data.count == 0 then
    (
        completeRedraw()
        return true
    )

    if not VertexColorPainter.beginPaint() then
    (
        format "Geometry Diagnostics ORTHO PAINT ERROR | beginPaint failed | node:% | visible_edges:%\n" \
            source_node.name ortho_result.visible_edges
        return false
    )

    local paint_result = true

    undo "Geometry Diagnostics - Check Ortho Edges" on
    (
        paint_result = VertexColorPainter.paintCorners paint_data
    )

    local end_result = VertexColorPainter.endPaint()

    if not paint_result or not end_result then
    (
        format "Geometry Diagnostics ORTHO PAINT ERROR | paint_result:% | end_result:% | visible_edges:%\n" \
            paint_result end_result ortho_result.visible_edges
        return false
    )

    true
    -- return
)


/*
Runs the horizontal/vertical edge diagnostic and paints all visible edges by orthogonal angular severity.
Exact orthogonal edges are green; deviation increases through blue at 15 degrees to red at 45 degrees.
*/
function checkGeometryDiagnosticsOrthoEdges source_node position_precision_text =
(
    local ortho_result = analyzeGeometryDiagnosticsOrthoEdges source_node position_precision_text

    if ortho_result == undefined then return undefined

    if not paintGeometryDiagnosticsOrthoResult source_node ortho_result then
    (
        format "Geometry Diagnostics CHECK ORTHO EDGES ERROR | node:% | precision:%\n" source_node.name position_precision_text
        return undefined
    )

    ortho_result
    -- return
)


/*
Clears Geometry Diagnostics paint from the currently bound shared painter target.
Only paint owned by VertexColorPainter is restored or removed.
*/
function restoreGeometryDiagnosticsColors source_node =
(
    if VertexColorPainter == undefined then return false
    if VertexColorPainter.source_node != source_node then return false

    VertexColorPainter.clearPaint()
    -- return
)


/*
Creates fully face-split channel-0 topology on a generated test object.
This helper is destructive by design and must not be used on arbitrary user geometry.
*/
function buildGeometryDiagnosticsTestColorMap source_node =
(
    if not isGeometryDiagnosticsEditablePolyNode source_node then return false
    if source_node.modifiers.count != 0 then return false

    local poly_value = source_node.baseObject

    if polyop.getHasDeadStructs poly_value != 0 then
    (
        polyop.collapseDeadStructs poly_value
    )

    local face_count = polyop.getNumFaces poly_value
    local total_corner_count = 0
    local next_map_vert_id = 1
    local white_point = [1.0, 1.0, 1.0]

    if polyop.getMapSupport poly_value 0 then
    (
        polyop.setMapSupport poly_value 0 false
    )

    polyop.setMapSupport poly_value 0 true

    for face_id = 1 to face_count do
    (
        total_corner_count += polyop.getFaceDeg poly_value face_id
    )

    polyop.setNumMapVerts poly_value 0 total_corner_count keep:false

    for face_id = 1 to face_count do
    (
        local face_degree = polyop.getFaceDeg poly_value face_id
        local map_face_ids = #()

        for corner_id = 1 to face_degree do
        (
            append map_face_ids next_map_vert_id
            polyop.setMapVert poly_value 0 next_map_vert_id white_point
            next_map_vert_id += 1
        )

        polyop.setMapFace poly_value 0 face_id map_face_ids
    )

    source_node.showVertexColors = true
    source_node.vertexColorType = #color
    source_node.vertexColorsShaded = true

    true
    -- return
)


/*
Adds the Geometry Diagnostics Tessellate test target through the Modify panel.
The setup mirrors the user-proven UI method and intentionally leaves Tessellate selected.
*/
function addGeometryDiagnosticsTestTessellation source_node =
(
    if not isGeometryDiagnosticsEditablePolyNode source_node then return undefined
    if source_node.modifiers.count != 0 then return undefined

    select source_node
    max modify mode

    undo "Geometry Diagnostics - Add Tessellate Target" on
    (
        modPanel.addModToSelection (tessellate ()) ui:on
        $.modifiers[#Tessellate].faceType = 1
        $.modifiers[#Tessellate].type = 0
        $.modifiers[#Tessellate].tension = 0
        $.modifiers[#Tessellate].iterations = 0
    )

    local tessellate_mod = source_node.modifiers[#Tessellate]

    if tessellate_mod == undefined then return undefined

    completeRedraw()

    tessellate_mod
    -- return
)


/*
Creates the Geometry Diagnostics test box and adds the canonical Tessellate modifier.
The base remains an 8-vertex / 6-polygon Editable Poly with 24 split color-map vertices.
*/
function createGeometryDiagnosticsTestBox =
(
    local created_node = undefined
    local tessellate_mod = undefined

    undo "Geometry Diagnostics - Create Test Box" on
    (
        created_node = box \
            name:(uniqueName "GeometryDiagnostics_TestBox") \
            length:100.0 \
            width:100.0 \
            height:100.0 \
            lengthsegs:1 \
            widthsegs:1 \
            heightsegs:1

        convertTo created_node Editable_Poly
        created_node.baseObject.showCage = off

        if not buildGeometryDiagnosticsTestColorMap created_node then
        (
            delete created_node
            created_node = undefined
        )
    )

    if created_node != undefined then
    (
        tessellate_mod = addGeometryDiagnosticsTestTessellation created_node

        if tessellate_mod == undefined then
        (
            format "Geometry Diagnostics: test box Tessellate creation failed for node %.\n" created_node.name
            delete created_node
            created_node = undefined
            geometry_diagnostics_test_node = undefined
        )
        else
        (
            geometry_diagnostics_test_node = created_node
            select created_node
        )
    )

    created_node
    -- return
)


/*
Applies a repeating six-color face palette through the currently selected VertexColorPainter target.
Editable Poly selection writes direct channel 0; a supported selected modifier writes through the painter-owned PaintLayerMod.
*/
function paintGeometryDiagnosticsTestBox source_node =
(
    if VertexColorPainter == undefined then return false
    if not isGeometryDiagnosticsEditablePolyNode source_node then return false
    if not ensureGeometryDiagnosticsPainterTarget source_node then return false
    if VertexColorPainter.face_count < 1 then return false

    local face_colors = #(
        (color 255 0 0),
        (color 0 255 0),
        (color 0 0 255),
        (color 255 255 0),
        (color 0 255 255),
        (color 255 0 255)
    )

    if not VertexColorPainter.beginPaint() then return false

    local paint_result = true
    local color_index = 1

    undo "Geometry Diagnostics - Paint Face Colors" on
    (
        for face_id = 1 to VertexColorPainter.face_count while paint_result do
        (
            paint_result = VertexColorPainter.paintFace face_id face_colors[color_index]

            color_index += 1

            if color_index > face_colors.count then
            (
                color_index = 1
            )
        )
    )

    local end_result = VertexColorPainter.endPaint()

    paint_result and end_result
    -- return
)



/*
Returns one selected Editable Poly node first, then the currently tracked test node as fallback.
This keeps user-facing paint actions aligned with the active Modify-panel stack selection.
*/
function getGeometryDiagnosticsTargetNode =
(
    if selection.count == 1 then
    (
        if isGeometryDiagnosticsEditablePolyNode selection[1] then
        (
            return selection[1]
        )
    )

    if isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_node then
    (
        return geometry_diagnostics_test_node
    )

    undefined
    -- return
)


/*
Prints current base geometry and channel-0 mapping data to the Listener.
The dump uses Editable Poly polygon IDs and never exposes TriMesh triangle IDs.
*/
function dumpGeometryDiagnosticsChannelZero source_node =
(
    if not isGeometryDiagnosticsEditablePolyNode source_node then return false

    local poly_value = source_node.baseObject
    poly_value.showCage = off

    if polyop.getHasDeadStructs poly_value != 0 then
    (
        format "Geometry Diagnostics: dump aborted because Editable Poly contains dead topology.\n"
        return false
    )

    local vertex_count = polyop.getNumVerts poly_value
    local face_count = polyop.getNumFaces poly_value
    local has_map_support = polyop.getMapSupport poly_value 0

    format "\n=== Geometry Diagnostics : Channel 0 ===\n"
    format "NODE: %\n" source_node.name
    format "GEOMETRY VERTICES: %\n" vertex_count
    format "POLYGON FACES: %\n" face_count
    format "CHANNEL 0 SUPPORTED: %\n" has_map_support

    if not has_map_support then
    (
        format "CHANNEL 0: no map data\n"
        format "========================================\n"
        return true
    )

    local map_vert_count = polyop.getNumMapVerts poly_value 0
    local map_face_count = polyop.getNumMapFaces poly_value 0

    format "MAP VERTICES: %\n" map_vert_count
    format "MAP FACES: %\n" map_face_count

    for face_id = 1 to face_count do
    (
        local geometry_face_ids = polyop.getFaceVerts poly_value face_id
        local map_face_ids = polyop.getMapFace poly_value 0 face_id

        format "FACE % | GEO % | MAP %\n" face_id geometry_face_ids map_face_ids

        for map_vert_id in map_face_ids do
        (
            format "    MAP VERT % = %\n" map_vert_id (polyop.getMapVert poly_value 0 map_vert_id)
        )
    )

    format "========================================\n"

    true
    -- return
)
