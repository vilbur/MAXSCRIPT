/*
Geometry Diagnostics backend.
Owns Geometry Diagnostics test helpers and delegates reusable color painting to VertexColorPainter.
*/

global geometry_diagnostics_fn_version = "0.17"
global geometry_diagnostics_fn_project_version = "0.19"
global geometry_diagnostics_project_version
global geometry_diagnostics_test_node
global VertexColorPainter
global geometry_diagnostics_edge_selection_owners


if geometry_diagnostics_edge_selection_owners == undefined or classOf geometry_diagnostics_edge_selection_owners != Array then
(
    geometry_diagnostics_edge_selection_owners = #()
)


global GeometryDiagnosticsOrthoEdgeResult

struct GeometryDiagnosticsOrthoEdgeResult_v
(
    source_node = undefined,
    target_stack_index = -1,
    target_stack_mod = undefined,
    position_precision_text = "",
    position_precision_value = 0.0,
    ortho_tolerance_text = "",
    ortho_tolerance_value = 0.0,
    visible_edges = #{},
    horizontal_edges = #{},
    vertical_edges = #{},
    orthogonal_edges = #{},
    valid_skewed_edges = #{},
    invalid_edges = #{},
    suspicious_edges = #{},
    edge_deviation_distances = #(),
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
    selection_edit_poly_mod = undefined,
    position_precision_text = "",
    position_precision_value = 0.0,
    direction_type = #vertical,
    selection_mode = #exact,
    edge_ids = #{},

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
Resolves one explicit orthogonal-tolerance label to current scene/system units.
The supported values are separate from postion preccision and default to 1.00mm in the UI.
*/
function resolveGeometryDiagnosticsOrthoTolerance ortho_tolerance_text =
(
    case ortho_tolerance_text of
    (
        "1.00mm": (units.decodeValue "1.00mm")
        "2.00mm": (units.decodeValue "2.00mm")
        "5.00mm": (units.decodeValue "5.00mm")
        "10.00mm": (units.decodeValue "10.00mm")
        default:
        (
            format "Geometry Diagnostics ORTHO TOLERANCE ERROR | supplied:% | expected:#(\"1.00mm\", \"2.00mm\", \"5.00mm\", \"10.00mm\")\n" ortho_tolerance_text
            undefined
        )
    )
    -- return
)


/*
Maps one off-axis distance to the three-level orthogonal diagnostic palette.
Within postion preccision is white; valid skew/sloping blends green to blue; invalid drift blends yellow to red and reaches red at 2x ortho tolerance.
*/
function getGeometryDiagnosticsOrthoSeverityColor deviation_distance position_precision ortho_tolerance =
(
    if deviation_distance == undefined or (classOf deviation_distance != Float and classOf deviation_distance != Integer) then
    (
        format "Geometry Diagnostics ORTHO COLOR ERROR | distance:% | class:%\n" deviation_distance (classOf deviation_distance)
        return undefined
    )

    if position_precision == undefined or position_precision <= 0.0 then
    (
        format "Geometry Diagnostics ORTHO COLOR ERROR | position_precision:% | required:>0\n" position_precision
        return undefined
    )

    if ortho_tolerance == undefined or ortho_tolerance < position_precision then
    (
        format "Geometry Diagnostics ORTHO COLOR ERROR | ortho_tolerance:% | position_precision:% | required:tolerance>=precision\n" \
            ortho_tolerance position_precision
        return undefined
    )

    local distance_value = amax 0.0 (deviation_distance as float)

    if distance_value <= position_precision then
    (
        return color 255 255 255
    )

    if distance_value <= ortho_tolerance then
    (
        local valid_span = ortho_tolerance - position_precision
        local blend_value = if valid_span > 0.0 then ((distance_value - position_precision) / valid_span) else 1.0
        blend_value = amin 1.0 (amax 0.0 blend_value)
        return color 0.0 (255.0 * (1.0 - blend_value)) (255.0 * blend_value)
    )

    local red_distance = ortho_tolerance * 2.0
    local invalid_span = red_distance - ortho_tolerance
    local blend_value = if invalid_span > 0.0 then ((distance_value - ortho_tolerance) / invalid_span) else 1.0
    blend_value = amin 1.0 (amax 0.0 blend_value)

    color 255.0 (255.0 * (1.0 - blend_value)) 0.0
    -- return
)


/*
Appends or raises one face-corner distance-severity record.
When multiple visible edges share a face-corner, the largest off-axis distance wins deterministically.
*/
function appendGeometryDiagnosticsCornerSeverity corner_severity_data geo_vertex_id face_id deviation_distance =
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
            if deviation_distance > row_data[3] then
            (
                row_data[3] = deviation_distance
            )

            return true
        )
    )

    append corner_severity_data #(geo_vertex_id, face_id, deviation_distance)
    true
    -- return
)


/*
Builds variable-color paint rows for every visible orthogonal diagnostic edge.
Each face-corner receives the highest incident off-axis distance before the white / green-blue / yellow-red color is resolved.
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

    if ortho_result.edge_deviation_distances == undefined or classOf ortho_result.edge_deviation_distances != Array then
    (
        format "Geometry Diagnostics ORTHO PAINT DATA ERROR | edge_deviation_distances:% | class:%\n" \
            ortho_result.edge_deviation_distances (classOf ortho_result.edge_deviation_distances)
        return undefined
    )

    local corner_severity_data = #()

    for edge_id in ortho_result.visible_edges do
    (
        if edge_id < 1 or edge_id > VertexColorPainter.edge_count or edge_id > ortho_result.edge_deviation_distances.count then
        (
            format "Geometry Diagnostics ORTHO PAINT DATA ERROR | edge:% | painter_range:1..% | distance_count:%\n" \
                edge_id VertexColorPainter.edge_count ortho_result.edge_deviation_distances.count
            return undefined
        )

        local deviation_distance = ortho_result.edge_deviation_distances[edge_id]
        local current_edge_vertices = VertexColorPainter.edge_vertices[edge_id]
        local current_edge_faces = VertexColorPainter.edge_faces[edge_id]

        if deviation_distance == undefined or current_edge_vertices == undefined or current_edge_vertices.count != 2 or current_edge_faces == undefined or current_edge_faces.count == 0 then
        (
            format "Geometry Diagnostics ORTHO PAINT DATA ERROR | edge:% | distance:% | endpoints:% | faces:%\n" \
                edge_id deviation_distance current_edge_vertices current_edge_faces
            return undefined
        )

        for face_id in current_edge_faces do
        (
            if not appendGeometryDiagnosticsCornerSeverity corner_severity_data current_edge_vertices[1] face_id deviation_distance then return undefined
            if not appendGeometryDiagnosticsCornerSeverity corner_severity_data current_edge_vertices[2] face_id deviation_distance then return undefined
        )
    )

    local paint_data = #()

    for corner_data in corner_severity_data do
    (
        local corner_color = getGeometryDiagnosticsOrthoSeverityColor \
            corner_data[3] \
            ortho_result.position_precision_value \
            ortho_result.ortho_tolerance_value

        if corner_color == undefined then return undefined

        append paint_data #(corner_data[1], corner_data[2], corner_color)
    )

    paint_data
    -- return
)

/*
Returns the dominant world axis and off-axis drift distance for one edge.
Z uses XY drift; X uses YZ drift; Y uses XZ drift. Zero-length edges return an empty Array.
*/
function getGeometryDiagnosticsPrincipalAxisData point_a point_b =
(
    if point_a == undefined or point_b == undefined or classOf point_a != Point3 or classOf point_b != Point3 then
    (
        format "Geometry Diagnostics PRINCIPAL AXIS ERROR | point_a:% | point_b:% | classes:[%,%]\n" \
            point_a point_b (classOf point_a) (classOf point_b)
        return #()
    )

    local edge_vector = point_b - point_a
    local edge_length = length edge_vector

    if edge_length <= 0.0 then return #()

    local abs_x = abs edge_vector.x
    local abs_y = abs edge_vector.y
    local abs_z = abs edge_vector.z
    local axis_type = #z
    local off_axis_distance = 0.0

    if abs_z >= abs_x and abs_z >= abs_y then
    (
        axis_type = #z
        off_axis_distance = length [edge_vector.x, edge_vector.y, 0.0]
    )
    else if abs_x >= abs_y then
    (
        axis_type = #x
        off_axis_distance = length [0.0, edge_vector.y, edge_vector.z]
    )
    else
    (
        axis_type = #y
        off_axis_distance = length [edge_vector.x, 0.0, edge_vector.z]
    )

    #(axis_type, off_axis_distance)
    -- return
)


/*
Tests one edge against the requested direction using position precision as the off-axis distance cutoff.
LMB exact mode accepts drift at or below the cutoff; RMB skewed mode accepts drift above the cutoff.
*/
function geometryDiagnosticsDirectionMatches point_a point_b direction_type selection_mode position_difference =
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

    if position_difference == undefined or position_difference <= 0.0 then
    (
        format "Geometry Diagnostics DIRECTION MATCH ERROR | position_difference:% | required:>0\n" position_difference
        return false
    )

    local axis_data = getGeometryDiagnosticsPrincipalAxisData point_a point_b

    if axis_data.count != 2 then return false

    local axis_type = axis_data[1]
    local off_axis_distance = axis_data[2]
    local direction_matches = if direction_type == #vertical then (axis_type == #z) else (axis_type == #x or axis_type == #y)

    if not direction_matches then return false

    if selection_mode == #exact then
    (
        off_axis_distance <= position_difference
    )
    else
    (
        off_axis_distance > position_difference
    )
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
Analyzes visible edges on the exact selected paint topology with three distance-based orthogonal levels.
Valid ortho uses postion preccision; valid skewed/sloped edges are above precision through ortho tolerance; invalid edges are above ortho tolerance.
*/
function analyzeGeometryDiagnosticsOrthoEdges source_node position_precision_text ortho_tolerance_text =
(
    if not isValidNode source_node then
    (
        format "Geometry Diagnostics ORTHO ERROR | invalid node:%\n" source_node
        return undefined
    )

    local position_precision = resolveGeometryDiagnosticsPositionPrecision position_precision_text
    local ortho_tolerance = resolveGeometryDiagnosticsOrthoTolerance ortho_tolerance_text

    if position_precision == undefined or position_precision <= 0.0 then
    (
        format "Geometry Diagnostics ORTHO ERROR | precision_text:% | resolved_precision:%\n" position_precision_text position_precision
        return undefined
    )

    if ortho_tolerance == undefined or ortho_tolerance < position_precision then
    (
        format "Geometry Diagnostics ORTHO ERROR | tolerance_text:% | resolved_tolerance:% | position_precision:% | required:tolerance>=precision\n" \
            ortho_tolerance_text ortho_tolerance position_precision
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
        local valid_skewed_edges = #{}
        local invalid_edges = #{}
        local edge_deviation_distances = #()

        horizontal_edges.count = edge_count
        vertical_edges.count = edge_count
        orthogonal_edges.count = edge_count
        valid_skewed_edges.count = edge_count
        invalid_edges.count = edge_count
        edge_deviation_distances.count = edge_count

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

            local axis_data = getGeometryDiagnosticsPrincipalAxisData raw_position_a raw_position_b

            if axis_data.count == 2 then
            (
                local axis_type = axis_data[1]
                local off_axis_distance = axis_data[2]
                edge_deviation_distances[edge_id] = off_axis_distance

                if off_axis_distance <= position_precision then
                (
                    if axis_type == #z then
                    (
                        vertical_edges[edge_id] = true
                    )
                    else
                    (
                        horizontal_edges[edge_id] = true
                    )

                    orthogonal_edges[edge_id] = true
                )
                else if off_axis_distance <= ortho_tolerance then
                (
                    valid_skewed_edges[edge_id] = true
                )
                else
                (
                    invalid_edges[edge_id] = true
                )
            )
            else
            (
                edge_deviation_distances[edge_id] = ortho_tolerance * 2.0
                invalid_edges[edge_id] = true
            )
        )

        local suspicious_edges = copy invalid_edges
        local vertex_data = buildGeometryDiagnosticsEdgeVertexData invalid_edges

        if vertex_data == undefined then
        (
            throw "Geometry Diagnostics invalid-edge vertex-data conversion failed."
        )

        result_value = GeometryDiagnosticsOrthoEdgeResult_v()
        result_value.source_node = source_node
        result_value.target_stack_index = current_target_index
        result_value.target_stack_mod = VertexColorPainter.target_stack_mod
        result_value.position_precision_text = position_precision_text
        result_value.position_precision_value = position_precision
        result_value.ortho_tolerance_text = ortho_tolerance_text
        result_value.ortho_tolerance_value = ortho_tolerance
        result_value.visible_edges = copy visible_edges
        result_value.horizontal_edges = copy horizontal_edges
        result_value.vertical_edges = copy vertical_edges
        result_value.orthogonal_edges = copy orthogonal_edges
        result_value.valid_skewed_edges = copy valid_skewed_edges
        result_value.invalid_edges = copy invalid_edges
        result_value.suspicious_edges = suspicious_edges
        result_value.edge_deviation_distances = edge_deviation_distances
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
        format "Geometry Diagnostics ORTHO ERROR | node:% | target_index:% | precision:% | tolerance:% | exception:%\n" \
            source_node.name current_target_index position_precision_text ortho_tolerance_text exception_text
        return undefined
    )

    if result_value == undefined then
    (
        format "Geometry Diagnostics ORTHO ERROR | analysis produced no result | node:% | target_index:% | precision:% | tolerance:%\n" \
            source_node.name current_target_index position_precision_text ortho_tolerance_text
        return undefined
    )

    GeometryDiagnosticsOrthoEdgeResult = result_value

    format "\n=== Geometry Diagnostics : Ortho Edges ===\n"
    format "NODE: %\n" source_node.name
    format "TARGET STACK INDEX: %\n" result_value.target_stack_index
    format "POSITION PRECISION: % -> % scene units\n" result_value.position_precision_text result_value.position_precision_value
    format "ORTHO TOLERANCE: % -> % scene units\n" result_value.ortho_tolerance_text result_value.ortho_tolerance_value
    format "VISIBLE EDGES: % | %\n" result_value.visible_edges.numberSet result_value.visible_edges
    format "VALID ORTHO EDGES: % | %\n" result_value.orthogonal_edges.numberSet result_value.orthogonal_edges
    format "VALID SKEWED/SLOPED EDGES: % | %\n" result_value.valid_skewed_edges.numberSet result_value.valid_skewed_edges
    format "INVALID SKEWED/SLOPED EDGES: % | %\n" result_value.invalid_edges.numberSet result_value.invalid_edges
    format "ORTHO SEVERITY COLORS: white valid ortho | green->blue valid skew/sloped | yellow->red invalid\n"
    format "INVALID FACE-CORNER VERTEX DATA: % rows\n" result_value.vertex_data.count
    format "===========================================\n"

    result_value
    -- return
)


/*
Returns true only when one exact modifier instance still belongs to the supplied node.
Display names are never used as an ownership signal.
*/
function geometryDiagnosticsModifierBelongsToNode source_node stack_mod =
(
    if not isValidNode source_node or stack_mod == undefined then return false

    for current_stack_mod in source_node.modifiers do
    (
        if current_stack_mod == stack_mod then return true
    )

    false
    -- return
)


/*
Returns the exact session-owned Geometry Diagnostics edge-selection Edit Poly for one node.
Stale owner rows are discarded; same-name foreign modifiers are never adopted.
*/
function getGeometryDiagnosticsOwnedEdgeSelectionModifier source_node =
(
    if not isValidNode source_node then return undefined

    local owned_edit_poly_mod = undefined
    local live_owner_rows = #()

    for owner_row in geometry_diagnostics_edge_selection_owners do
    (
        if classOf owner_row == Array and owner_row.count >= 2 then
        (
            local owner_node = owner_row[1]
            local owner_edit_poly_mod = owner_row[2]

            if isValidNode owner_node and owner_edit_poly_mod != undefined and \
                geometryDiagnosticsModifierBelongsToNode owner_node owner_edit_poly_mod then
            (
                append live_owner_rows owner_row

                if owner_node == source_node and owned_edit_poly_mod == undefined then
                (
                    owned_edit_poly_mod = owner_edit_poly_mod
                )
            )
        )
    )

    geometry_diagnostics_edge_selection_owners = live_owner_rows

    owned_edit_poly_mod
    -- return
)


/*
Removes one exact Geometry Diagnostics direction-selection ownership row.
The modifier itself is not deleted by this helper.
*/
function removeGeometryDiagnosticsEdgeSelectionOwner source_node selection_edit_poly_mod =
(
    local live_owner_rows = #()

    for owner_row in geometry_diagnostics_edge_selection_owners do
    (
        if classOf owner_row == Array and owner_row.count >= 2 then
        (
            if not (owner_row[1] == source_node and owner_row[2] == selection_edit_poly_mod) then
            (
                append live_owner_rows owner_row
            )
        )
    )

    geometry_diagnostics_edge_selection_owners = live_owner_rows

    true
    -- return
)


/*
Switches the Command Panel to Create mode before Edit Poly topology reads.
This follows the working Wall-Fixer direction-selection path.
*/
function ensureGeometryDiagnosticsCreatePanelMode =
(
    local current_panel_mode = undefined

    try
    (
        current_panel_mode = getCommandPanelTaskMode()

        if current_panel_mode != #create then
        (
            setCommandPanelTaskMode mode:#create
            current_panel_mode = getCommandPanelTaskMode()
        )
    )
    catch
    (
        local exception_text = getCurrentException()
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:ensureCreatePanelMode | exception:%\n" exception_text
        return false
    )

    current_panel_mode == #create
    -- return
)


/*
Binds one owned Edit Poly to the supplied node as its primary node.
Returns true only when the primary-node read-back matches.
*/
function ensureGeometryDiagnosticsEditPolyPrimaryNode source_node selection_edit_poly_mod =
(
    if not isValidNode source_node or selection_edit_poly_mod == undefined then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:ensurePrimaryNode | node:% | edit_poly:%\n" \
            source_node selection_edit_poly_mod
        return false
    )

    local primary_node = undefined

    try
    (
        primary_node = EditPolyMod.GetPrimaryNode selection_edit_poly_mod

        if primary_node != source_node then
        (
            EditPolyMod.SetPrimaryNode selection_edit_poly_mod source_node
            primary_node = EditPolyMod.GetPrimaryNode selection_edit_poly_mod
        )
    )
    catch
    (
        local exception_text = getCurrentException()
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:ensurePrimaryNode | node:% | edit_poly:% | exception:%\n" \
            source_node.name selection_edit_poly_mod exception_text
        return false
    )

    if primary_node != source_node then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:ensurePrimaryNode | expected:% | actual:% | edit_poly:%\n" \
            source_node primary_node selection_edit_poly_mod
        return false
    )

    true
    -- return
)


/*
Creates or returns the exact session-owned Edit Poly used by the direction buttons.
The return value mirrors Wall-Fixer: #(edit_poly, created_new).
*/
function ensureGeometryDiagnosticsEdgeSelectionModifier source_node =
(
    if not isValidNode source_node then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | invalid node:%\n" source_node
        return #(undefined, false)
    )

    local selection_edit_poly_mod = getGeometryDiagnosticsOwnedEdgeSelectionModifier source_node
    local created_new_edit_poly = false

    if selection_edit_poly_mod == undefined then
    (
        try
        (
            selection_edit_poly_mod = Edit_Poly()
            selection_edit_poly_mod.name = "GEOMETRY DIAGNOSTICS"
            selection_edit_poly_mod.showCage = off
            addModifier source_node selection_edit_poly_mod
            created_new_edit_poly = true
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:createEditPoly | node:% | exception:%\n" \
                source_node.name exception_text
            return #(undefined, false)
        )

        if not geometryDiagnosticsModifierBelongsToNode source_node selection_edit_poly_mod then
        (
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:createEditPoly | node:% | edit_poly:% | required:exact modifier must belong to node\n" \
                source_node.name selection_edit_poly_mod
            return #(undefined, false)
        )

        append geometry_diagnostics_edge_selection_owners #(source_node, selection_edit_poly_mod)
    )

    if classOf source_node.baseObject == Editable_Poly then
    (
        source_node.baseObject.showCage = off
    )

    selection_edit_poly_mod.showCage = off

    #(selection_edit_poly_mod, created_new_edit_poly)
    -- return
)


/*
Prepares the owned Edit Poly exactly through Wall-Fixer's live-topology sequence.
A zero-edge first read forces evaluated topology; failure is reported instead of converted to an empty valid result.
*/
function prepareGeometryDiagnosticsEdgeSelectionModifier source_node selection_edit_poly_mod =
(
    if not isValidNode source_node or selection_edit_poly_mod == undefined then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:prepare | node:% | edit_poly:%\n" \
            source_node selection_edit_poly_mod
        return false
    )

    local live_edge_count = 0
    local evaluated_mesh = undefined
    local original_selection = selection as array
    local operation_failed = false
    local exception_text = ""

    try
    (
        if not ensureGeometryDiagnosticsCreatePanelMode() then
        (
            throw "Could not switch Geometry Diagnostics direction selection to Create mode."
        )

        if not ensureGeometryDiagnosticsEditPolyPrimaryNode source_node selection_edit_poly_mod then
        (
            throw "Could not bind Geometry Diagnostics direction Edit Poly to its node."
        )

        selection_edit_poly_mod.useStackSelection = false
        selection_edit_poly_mod.showCage = off

        if (EditPolyMod.GetEPolySelLevel selection_edit_poly_mod) != #Edge then
        (
            EditPolyMod.SetEPolySelLevel selection_edit_poly_mod #Edge
        )

        update source_node
        live_edge_count = EditPolyMod.GetNumEdges selection_edit_poly_mod node:source_node

        if live_edge_count <= 0 then
        (
            evaluated_mesh = snapshotAsMesh source_node

            if evaluated_mesh != undefined then
            (
                free evaluated_mesh
                evaluated_mesh = undefined
            )

            update source_node
            live_edge_count = EditPolyMod.GetNumEdges selection_edit_poly_mod node:source_node
        )

        if live_edge_count <= 0 then
        (
            select source_node
            setCommandPanelTaskMode mode:#modify
            modPanel.setCurrentObject selection_edit_poly_mod
            update source_node

            evaluated_mesh = snapshotAsMesh source_node

            if evaluated_mesh != undefined then
            (
                free evaluated_mesh
                evaluated_mesh = undefined
            )

            live_edge_count = EditPolyMod.GetNumEdges selection_edit_poly_mod node:source_node

            if not ensureGeometryDiagnosticsCreatePanelMode() then
            (
                throw "Could not restore Create mode after Geometry Diagnostics live-topology evaluation."
            )

            if original_selection.count > 0 then
            (
                select original_selection
            )
            else
            (
                clearSelection()
            )
        )
    )
    catch
    (
        exception_text = getCurrentException()
        operation_failed = true
    )

    if evaluated_mesh != undefined then
    (
        free evaluated_mesh
    )

    if operation_failed then
    (
        ensureGeometryDiagnosticsCreatePanelMode()

        if original_selection.count > 0 then
        (
            select original_selection
        )
        else
        (
            clearSelection()
        )

        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:prepare | node:% | edit_poly:% | edge_count:% | exception:%\n" \
            source_node.name selection_edit_poly_mod live_edge_count exception_text
        return false
    )

    if live_edge_count <= 0 then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:prepare | node:% | edit_poly:% | edge_count:% | required:>0\n" \
            source_node.name selection_edit_poly_mod live_edge_count
        return false
    )

    true
    -- return
)


/*
Builds the direction-selection geometry adapter through the same recovery path as Wall-Fixer.
If a valid base has edges but the first owned Edit Poly exposes zero live edges, that exact owned instance is rebuilt once.
*/
function getGeometryDiagnosticsDirectionAdapter source_node =
(
    if not isValidNode source_node then return #()

    local selection_mod_result = ensureGeometryDiagnosticsEdgeSelectionModifier source_node
    local selection_edit_poly_mod = selection_mod_result[1]
    local created_new_edit_poly = selection_mod_result[2]

    if selection_edit_poly_mod == undefined then return #()

    local selection_mod_ready = prepareGeometryDiagnosticsEdgeSelectionModifier source_node selection_edit_poly_mod
    local should_rebuild = false

    if not selection_mod_ready and classOf source_node.baseObject == Editable_Poly then
    (
        local base_edge_count = polyop.getNumEdges source_node.baseObject
        should_rebuild = base_edge_count > 0
    )

    if should_rebuild then
    (
        if not geometryDiagnosticsModifierBelongsToNode source_node selection_edit_poly_mod then
        (
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:rebuild | node:% | edit_poly:% | required:exact owned modifier still belongs to node\n" \
                source_node.name selection_edit_poly_mod
            return #()
        )

        if not ensureGeometryDiagnosticsCreatePanelMode() then
        (
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:rebuild | node:% | could not switch to Create mode\n" source_node.name
            return #()
        )

        try
        (
            deleteModifier source_node selection_edit_poly_mod
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:rebuildDelete | node:% | edit_poly:% | exception:%\n" \
                source_node.name selection_edit_poly_mod exception_text
            return #()
        )

        removeGeometryDiagnosticsEdgeSelectionOwner source_node selection_edit_poly_mod
        update source_node

        selection_mod_result = ensureGeometryDiagnosticsEdgeSelectionModifier source_node
        selection_edit_poly_mod = selection_mod_result[1]
        created_new_edit_poly = true

        if selection_edit_poly_mod == undefined then return #()

        selection_mod_ready = prepareGeometryDiagnosticsEdgeSelectionModifier source_node selection_edit_poly_mod
    )

    if not selection_mod_ready then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:getAdapter | node:% | edit_poly:% | live topology unavailable after Wall-Fixer recovery path\n" \
            source_node.name selection_edit_poly_mod
        return #()
    )

    #(#edit_poly, selection_edit_poly_mod, created_new_edit_poly)
    -- return
)


/*
Returns the edge count for one direction-selection adapter.
Edit Poly retries through the same preparation path as Wall-Fixer when the initial live count is zero.
*/
function getGeometryDiagnosticsDirectionEdgeCount source_node adapter =
(
    local edge_count = 0

    if classOf adapter != Array or adapter.count < 2 then return edge_count

    if adapter[1] == #editable_poly then
    (
        edge_count = polyop.getNumEdges adapter[2]
    )
    else if adapter[1] == #edit_poly and adapter[2] != undefined then
    (
        local first_read_failed = false
        local first_exception_text = ""

        try
        (
            edge_count = EditPolyMod.GetNumEdges adapter[2] node:source_node
        )
        catch
        (
            first_exception_text = getCurrentException()
            first_read_failed = true
            format "Geometry Diagnostics EDGE COUNT ERROR | stage:initial | node:% | edit_poly:% | exception:%\n" \
                source_node.name adapter[2] first_exception_text
        )

        if first_read_failed or edge_count <= 0 then
        (
            if prepareGeometryDiagnosticsEdgeSelectionModifier source_node adapter[2] then
            (
                try
                (
                    edge_count = EditPolyMod.GetNumEdges adapter[2] node:source_node
                )
                catch
                (
                    local exception_text = getCurrentException()
                    format "Geometry Diagnostics EDGE COUNT ERROR | stage:prepared | node:% | edit_poly:% | exception:%\n" \
                        source_node.name adapter[2] exception_text
                    return 0
                )
            )
            else
            (
                return 0
            )
        )
    )

    if classOf edge_count != Integer then
    (
        format "Geometry Diagnostics EDGE COUNT ERROR | node:% | value:% | class:% | expected:Integer\n" \
            source_node edge_count (classOf edge_count)
        return 0
    )

    edge_count
    -- return
)


/*
Returns the two vertex IDs for one edge through the Wall-Fixer adapter API.
*/
function getGeometryDiagnosticsDirectionEdgeVertIds source_node adapter edge_id =
(
    local edge_verts = #()

    if classOf adapter != Array or adapter.count < 2 then return edge_verts

    if adapter[1] == #editable_poly then
    (
        edge_verts = polyop.getEdgeVerts adapter[2] edge_id
    )
    else if adapter[1] == #edit_poly then
    (
        local vert_a = EditPolyMod.GetEdgeVertex adapter[2] edge_id 1 node:source_node
        local vert_b = EditPolyMod.GetEdgeVertex adapter[2] edge_id 2 node:source_node
        edge_verts = #(vert_a, vert_b)
    )

    edge_verts
    -- return
)


/*
Returns one adapter vertex position in object space.
*/
function getGeometryDiagnosticsDirectionVertexPosition source_node adapter vertex_id =
(
    if classOf adapter != Array or adapter.count < 2 then return undefined

    if adapter[1] == #editable_poly then
    (
        polyop.getVert adapter[2] vertex_id
    )
    else if adapter[1] == #edit_poly then
    (
        EditPolyMod.GetVertex adapter[2] vertex_id node:source_node
    )
    else
    (
        undefined
    )
    -- return
)


/*
Returns one adapter vertex position in world space.
This is the same endpoint-position source used by Wall-Fixer before its angle calculation.
*/
function getGeometryDiagnosticsDirectionVertexWorldPosition source_node adapter vertex_id =
(
    local local_position = getGeometryDiagnosticsDirectionVertexPosition source_node adapter vertex_id

    if local_position == undefined then return undefined

    local_position * source_node.objectTransform
    -- return
)


/*
Activates the direction adapter in Modify mode at Edge sub-object level.
This mirrors Wall-Fixer's activateEdgeSelectionDisplay behavior.
*/
function activateGeometryDiagnosticsEdgeSelectionDisplay source_node adapter =
(
    if not isValidNode source_node or classOf adapter != Array or adapter.count < 2 then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:activateDisplay | node:% | adapter:%\n" \
            source_node adapter
        return false
    )

    local geometry_source = adapter[2]
    local display_activated = false
    local current_object = undefined

    try
    (
        select source_node
        max modify mode

        if adapter[1] == #edit_poly then
        (
            if not ensureGeometryDiagnosticsEditPolyPrimaryNode source_node geometry_source then
            (
                throw "Could not bind Geometry Diagnostics Edit Poly before display activation."
            )

            geometry_source.useStackSelection = false
            geometry_source.showCage = off
            modPanel.setCurrentObject geometry_source
            EditPolyMod.SetEPolySelLevel geometry_source #Edge
        )
        else if adapter[1] == #editable_poly then
        (
            geometry_source.showCage = off
            modPanel.setCurrentObject geometry_source
        )

        subObjectLevel = 2
        current_object = modPanel.getCurrentObject()
        display_activated = (current_object == geometry_source) and (subObjectLevel == 2)

        if adapter[1] == #edit_poly then
        (
            display_activated = display_activated and \
                ((EditPolyMod.GetEPolySelLevel geometry_source) == #Edge) and \
                (geometry_source.useStackSelection == false)
        )
    )
    catch
    (
        local exception_text = getCurrentException()
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:activateDisplay | node:% | source:% | exception:%\n" \
            source_node.name geometry_source exception_text
        return false
    )

    display_activated
    -- return
)


/*
Prints the decisive state when a direction-selection write or verification fails.
*/
function printGeometryDiagnosticsDirectionSelectionDebug source_node adapter requested_selection set_selection_readback actual_selection display_activated =
(
    local current_object = undefined
    local geometry_source = if classOf adapter == Array and adapter.count >= 2 then adapter[2] else undefined
    local use_stack_selection = undefined

    try
    (
        current_object = modPanel.getCurrentObject()
    )
    catch
    (
        local exception_text = getCurrentException()
        format "Geometry Diagnostics EDGE SELECTION DEBUG ERROR | node:% | exception:%\n" source_node exception_text
    )

    if classOf adapter == Array and adapter.count >= 2 and adapter[1] == #edit_poly and geometry_source != undefined then
    (
        use_stack_selection = geometry_source.useStackSelection
    )

    format "Geometry Diagnostics EDGE SELECTION DEBUG | node:% | adapter:% | source:%\n" \
        source_node.name (if classOf adapter == Array and adapter.count > 0 then adapter[1] else undefined) geometry_source
    format "Geometry Diagnostics EDGE SELECTION DEBUG | requested:%\n" requested_selection
    format "Geometry Diagnostics EDGE SELECTION DEBUG | immediate_readback:%\n" set_selection_readback
    format "Geometry Diagnostics EDGE SELECTION DEBUG | final_readback:%\n" actual_selection
    format "Geometry Diagnostics EDGE SELECTION DEBUG | current_object:% | subObjectLevel:% | useStackSelection:% | display_activated:%\n" \
        current_object subObjectLevel use_stack_selection display_activated

    true
    -- return
)


/*
Writes one requested edge BitArray using Wall-Fixer's checker-selection sequence.
Returns #(success, immediate_readback, final_readback, display_activated); native read failures remain undefined.
*/
function setGeometryDiagnosticsCheckerEdgeSelection source_node adapter edge_selection =
(
    if not isValidNode source_node or classOf adapter != Array or adapter.count < 2 or classOf edge_selection != BitArray then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:setSelectionInput | node:% | adapter:% | requested:%\n" \
            source_node adapter edge_selection
        return #(false, undefined, undefined, false)
    )

    local geometry_source = adapter[2]
    local requested_selection = copy edge_selection
    local set_selection_readback = undefined
    local actual_selection = undefined
    local display_activated = false

    if adapter[1] == #edit_poly and geometry_source != undefined then
    (
        display_activated = activateGeometryDiagnosticsEdgeSelectionDisplay source_node adapter

        if not display_activated then
        (
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:activateBeforeWrite | node:% | source:%\n" \
                source_node.name geometry_source
            return #(false, set_selection_readback, actual_selection, false)
        )

        if not ensureGeometryDiagnosticsEditPolyPrimaryNode source_node geometry_source then
        (
            return #(false, set_selection_readback, actual_selection, false)
        )

        geometry_source.useStackSelection = false
        geometry_source.showCage = off

        if (EditPolyMod.GetEPolySelLevel geometry_source) != #Edge then
        (
            EditPolyMod.SetEPolySelLevel geometry_source #Edge
        )

        try
        (
            EditPolyMod.SetSelection geometry_source #Edge requested_selection node:source_node
            set_selection_readback = EditPolyMod.GetSelection geometry_source #Edge node:source_node
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:SetSelection | node:% | source:% | requested:% | exception:%\n" \
                source_node.name geometry_source requested_selection exception_text
            return #(false, undefined, undefined, display_activated)
        )

        if classOf set_selection_readback != BitArray then
        (
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:SetSelectionReadback | node:% | value:% | class:% | expected:BitArray\n" \
                source_node.name set_selection_readback (classOf set_selection_readback)
            return #(false, set_selection_readback, undefined, display_activated)
        )

        if set_selection_readback != requested_selection then
        (
            local empty_selection = #{}

            try
            (
                EditPolyMod.SetSelection geometry_source #Edge empty_selection node:source_node
                EditPolyMod.Select geometry_source #Edge requested_selection invert:false select:true node:source_node
                set_selection_readback = EditPolyMod.GetSelection geometry_source #Edge node:source_node
            )
            catch
            (
                local exception_text = getCurrentException()
                format "Geometry Diagnostics EDGE SELECTION ERROR | stage:SelectFallback | node:% | source:% | requested:% | exception:%\n" \
                    source_node.name geometry_source requested_selection exception_text
                return #(false, undefined, undefined, display_activated)
            )

            if classOf set_selection_readback != BitArray then
            (
                format "Geometry Diagnostics EDGE SELECTION ERROR | stage:SelectFallbackReadback | node:% | value:% | class:% | expected:BitArray\n" \
                    source_node.name set_selection_readback (classOf set_selection_readback)
                return #(false, set_selection_readback, undefined, display_activated)
            )
        )

        update source_node
        display_activated = activateGeometryDiagnosticsEdgeSelectionDisplay source_node adapter
        completeRedraw()

        try
        (
            actual_selection = EditPolyMod.GetSelection geometry_source #Edge node:source_node
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:FinalReadback | node:% | source:% | requested:% | exception:%\n" \
                source_node.name geometry_source requested_selection exception_text
            return #(false, set_selection_readback, undefined, display_activated)
        )
    )
    else if adapter[1] == #editable_poly and geometry_source != undefined then
    (
        display_activated = activateGeometryDiagnosticsEdgeSelectionDisplay source_node adapter

        try
        (
            polyop.setEdgeSelection geometry_source requested_selection
            set_selection_readback = polyop.getEdgeSelection geometry_source
            completeRedraw()
            actual_selection = polyop.getEdgeSelection geometry_source
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Geometry Diagnostics EDGE SELECTION ERROR | stage:EditablePolySelection | node:% | requested:% | exception:%\n" \
                source_node.name requested_selection exception_text
            return #(false, undefined, undefined, display_activated)
        )
    )

    if classOf actual_selection != BitArray then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:FinalReadbackType | node:% | value:% | class:% | expected:BitArray\n" \
            source_node.name actual_selection (classOf actual_selection)
        return #(false, set_selection_readback, actual_selection, display_activated)
    )

    local selection_applied = \
        (classOf set_selection_readback == BitArray) and \
        (set_selection_readback == requested_selection) and \
        (actual_selection == requested_selection) and \
        display_activated

    if not selection_applied then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:verifySelection | node:% | requested:% | immediate:% | final:% | display:%\n" \
            source_node.name requested_selection set_selection_readback actual_selection display_activated
        printGeometryDiagnosticsDirectionSelectionDebug \
            source_node adapter requested_selection set_selection_readback actual_selection display_activated
    )

    #(selection_applied, set_selection_readback, actual_selection, display_activated)
    -- return
)


/*
Reads the current edge selection through the same adapter API as Wall-Fixer.
*/
function getGeometryDiagnosticsDirectionEdgeSelection source_node adapter =
(
    if classOf adapter != Array or adapter.count < 2 then return undefined

    local geometry_source = adapter[2]
    local edge_selection = undefined

    try
    (
        if adapter[1] == #editable_poly and geometry_source != undefined then
        (
            edge_selection = polyop.getEdgeSelection geometry_source
        )
        else if adapter[1] == #edit_poly and geometry_source != undefined then
        (
            edge_selection = EditPolyMod.GetSelection geometry_source #Edge node:source_node
        )
    )
    catch
    (
        local exception_text = getCurrentException()
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:getSelection | node:% | source:% | exception:%\n" \
            source_node geometry_source exception_text
        return undefined
    )

    if classOf edge_selection != BitArray then
    (
        format "Geometry Diagnostics EDGE SELECTION ERROR | stage:getSelectionType | node:% | value:% | class:% | expected:BitArray\n" \
            source_node edge_selection (classOf edge_selection)
        return undefined
    )

    copy edge_selection
    -- return
)


/*
Runs one direction-button action through Wall-Fixer's adapter, scan, write, activate, and read-back sequence.
Only the classifier differs: endpoint positions use postion preccision instead of calculating an angle.
*/
function checkGeometryDiagnosticsDirectionEdges source_node direction_type selection_mode position_precision_text =
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

    if not isValidNode source_node then
    (
        format "Geometry Diagnostics DIRECTION ERROR | invalid node:%\n" source_node
        return undefined
    )

    local position_difference = resolveGeometryDiagnosticsPositionPrecision position_precision_text

    if position_difference == undefined or position_difference <= 0.0 then
    (
        format "Geometry Diagnostics DIRECTION ERROR | precision_text:% | position_difference:%\n" \
            position_precision_text position_difference
        return undefined
    )

    if not ensureGeometryDiagnosticsCreatePanelMode() then return undefined

    local adapter = getGeometryDiagnosticsDirectionAdapter source_node

    if adapter.count < 2 then
    (
        format "Geometry Diagnostics DIRECTION ERROR | node:% | direction:% | mode:% | adapter unavailable\n" \
            source_node.name direction_type selection_mode
        return undefined
    )

    local edge_count = getGeometryDiagnosticsDirectionEdgeCount source_node adapter
    local matched_edges = #{}
    matched_edges.count = edge_count

    if edge_count <= 0 then
    (
        format "Geometry Diagnostics DIRECTION ERROR | node:% | direction:% | mode:% | live_edge_count:% | required:>0\n" \
            source_node.name direction_type selection_mode edge_count
        return undefined
    )

    for edge_id = 1 to edge_count do
    (
        local edge_verts = getGeometryDiagnosticsDirectionEdgeVertIds source_node adapter edge_id

        if edge_verts.count != 2 then
        (
            format "Geometry Diagnostics DIRECTION EDGE READ ERROR | node:% | edge:% | edge_verts:% | expected:2 vertex IDs\n" \
                source_node.name edge_id edge_verts
            return undefined
        )

        local point_a = getGeometryDiagnosticsDirectionVertexWorldPosition source_node adapter edge_verts[1]
        local point_b = getGeometryDiagnosticsDirectionVertexWorldPosition source_node adapter edge_verts[2]

        if point_a == undefined or point_b == undefined then
        (
            format "Geometry Diagnostics DIRECTION EDGE READ ERROR | node:% | edge:% | verts:% | point_a:% | point_b:%\n" \
                source_node.name edge_id edge_verts point_a point_b
            return undefined
        )

        if geometryDiagnosticsDirectionMatches point_a point_b direction_type selection_mode position_difference then
        (
            matched_edges[edge_id] = true
        )
    )

    local selection_result = setGeometryDiagnosticsCheckerEdgeSelection source_node adapter matched_edges

    if selection_result[1] != true then
    (
        format "Geometry Diagnostics CHECK DIRECTION ERROR | node:% | direction:% | mode:% | precision:% | requested:% | immediate:% | final:% | display:%\n" \
            source_node.name direction_type selection_mode position_precision_text matched_edges \
            selection_result[2] selection_result[3] selection_result[4]
        return undefined
    )

    local actual_selection = getGeometryDiagnosticsDirectionEdgeSelection source_node adapter

    if actual_selection == undefined or actual_selection != matched_edges then
    (
        format "Geometry Diagnostics CHECK DIRECTION ERROR | stage:postReadback | node:% | requested:% | actual:%\n" \
            source_node.name matched_edges actual_selection
        return undefined
    )

    local result_value = GeometryDiagnosticsDirectionalEdgeResult_v()
    result_value.source_node = source_node
    result_value.selection_edit_poly_mod = adapter[2]
    result_value.position_precision_text = position_precision_text
    result_value.position_precision_value = position_difference
    result_value.direction_type = direction_type
    result_value.selection_mode = selection_mode
    result_value.edge_ids = copy matched_edges

    GeometryDiagnosticsDirectionalEdgeResult = result_value

    format "\n=== Geometry Diagnostics : Direction Edge Selection ===\n"
    format "NODE: %\n" source_node.name
    format "DIRECTION: % | MODE: %\n" direction_type selection_mode
    format "POSITION DIFFERENCE: % -> % scene units\n" position_precision_text position_difference
    format "MATCHED EDGES: % | %\n" result_value.edge_ids.numberSet result_value.edge_ids
    format "FINAL SELECTION: % | %\n" actual_selection.numberSet actual_selection
    format "=======================================================\n"

    result_value
    -- return
)


/*
Replaces current Geometry Diagnostics paint with the three-level distance-based orthogonal severity overlay.
Valid ortho is white, valid skew/sloping is green-to-blue, and invalid skew/sloping is yellow-to-red through face-corner vertex data.
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
Runs the horizontal/vertical edge diagnostic and paints all visible edges by three-level off-axis distance severity.
Postion preccision defines white valid ortho; ortho tolerance defines the end of the green-to-blue valid skew/sloped band.
*/
function checkGeometryDiagnosticsOrthoEdges source_node position_precision_text ortho_tolerance_text =
(
    local ortho_result = analyzeGeometryDiagnosticsOrthoEdges source_node position_precision_text ortho_tolerance_text

    if ortho_result == undefined then return undefined

    if not paintGeometryDiagnosticsOrthoResult source_node ortho_result then
    (
        format "Geometry Diagnostics CHECK ORTHO EDGES ERROR | node:% | precision:% | tolerance:%\n" \
            source_node.name position_precision_text ortho_tolerance_text
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
