/*
Geometry Diagnostics backend.
Owns Geometry Diagnostics test helpers and delegates reusable color painting to VertexColorPainter.
*/

global geometry_diagnostics_fn_version = "0.21"
global geometry_diagnostics_fn_project_version = "0.23"
global geometry_diagnostics_project_version
global geometry_diagnostics_test_node
global VertexColorPainter
global geometry_diagnostics_edge_selection_owners
global geometry_diagnostics_planar_selection_owners


if geometry_diagnostics_edge_selection_owners == undefined or classOf geometry_diagnostics_edge_selection_owners != Array then
(
    geometry_diagnostics_edge_selection_owners = #()
)

if geometry_diagnostics_planar_selection_owners == undefined or classOf geometry_diagnostics_planar_selection_owners != Array then
(
    geometry_diagnostics_planar_selection_owners = #()
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
Canonicalizes one face normal so opposite parallel faces share one stable wall orientation.
This is the Wall-Fixer planarity helper moved into Geometry Diagnostics without changing its geometric rule.
*/
function geometryDiagnosticsCanonicalPlanarNormal face_normal =
(
    local result_normal = face_normal
    local normal_length = length result_normal

    if normal_length > 0.0000001 then
    (
        result_normal = result_normal / normal_length
        local abs_x = abs result_normal.x
        local abs_y = abs result_normal.y
        local abs_z = abs result_normal.z

        if abs_x >= abs_y and abs_x >= abs_z then
        (
            if result_normal.x < 0.0 then result_normal = -result_normal
        )
        else if abs_y >= abs_x and abs_y >= abs_z then
        (
            if result_normal.y < 0.0 then result_normal = -result_normal
        )
        else
        (
            if result_normal.z < 0.0 then result_normal = -result_normal
        )
    )

    result_normal
    -- return
)


/*
Builds one canonical plane candidate from three non-collinear world-space points.
The implementation is copied from the working Wall-Fixer planar-wall checker.
*/
function geometryDiagnosticsGetPlanarPlaneCandidate point_a point_b point_c =
(
    local candidate_data = #()
    local cross_value = cross (point_b - point_a) (point_c - point_a)
    local cross_length = length cross_value

    if cross_length > 0.0000001 then
    (
        local plane_normal = geometryDiagnosticsCanonicalPlanarNormal (cross_value / cross_length)
        local plane_offset = dot point_a plane_normal
        candidate_data = #(plane_normal, plane_offset)
    )

    candidate_data
    -- return
)


/*
Scores one candidate plane by vertex support, face-normal agreement, and total vertex deviation.
This preserves the Wall-Fixer candidate ranking contract.
*/
function geometryDiagnosticsScorePlanarPlaneCandidate world_points face_normal_records plane_normal plane_offset planar_tolerance =
(
    local inlier_vertices = #{}
    local inlier_count = 0
    local total_deviation = 0.0
    local angular_cost = 0.0

    for vertex_index = 1 to world_points.count do
    (
        local vertex_deviation = abs ((dot world_points[vertex_index] plane_normal) - plane_offset)
        total_deviation += vertex_deviation

        if vertex_deviation <= planar_tolerance then
        (
            inlier_vertices[vertex_index] = true
            inlier_count += 1
        )
    )

    for face_record in face_normal_records do
    (
        angular_cost += (1.0 - (dot plane_normal face_record[1])) * face_record[2]
    )

    #(inlier_count, angular_cost, total_deviation, inlier_vertices)
    -- return
)


/*
Classifies one evaluated wall cluster as near-vertical, near-horizontal, or unrestricted.
Wall-Fixer uses this only as a deterministic tie-break aid while finding the dominant plane.
*/
function geometryDiagnosticsGetPlanarOrientationMode face_normal_records normal_angle_tolerance =
(
    local safe_angle = normal_angle_tolerance
    if safe_angle < 0.1 then safe_angle = 0.1
    if safe_angle > 20.0 then safe_angle = 20.0

    local vertical_limit = sin safe_angle
    local horizontal_limit = cos safe_angle
    local vertical_count = 0
    local horizontal_count = 0

    for face_record in face_normal_records do
    (
        local face_normal = face_record[1]
        local absolute_z = abs face_normal.z

        if absolute_z <= vertical_limit then vertical_count += 1
        if absolute_z >= horizontal_limit then horizontal_count += 1
    )

    local orientation_mode = #free

    if face_normal_records.count > 0 then
    (
        if (vertical_count * 2) >= face_normal_records.count then
        (
            orientation_mode = #vertical
        )
        else if (horizontal_count * 2) >= face_normal_records.count then
        (
            orientation_mode = #horizontal
        )
    )

    orientation_mode
    -- return
)


/*
Returns the Wall-Fixer orientation penalty for one candidate wall plane.
Vertical clusters prefer normal Z=0; horizontal clusters prefer absolute normal Z=1.
*/
function geometryDiagnosticsGetPlanarOrientationCost plane_normal orientation_mode =
(
    local orientation_cost = 0.0

    case orientation_mode of
    (
        #vertical:
        (
            orientation_cost = abs plane_normal.z
        )
        #horizontal:
        (
            orientation_cost = 1.0 - (abs plane_normal.z)
        )
        default:
        (
            orientation_cost = 0.0
        )
    )

    orientation_cost
    -- return
)


/*
Compares two robust Wall-Fixer plane candidates without depending on loop order.
Vertex support wins first, then orientation, total deviation, source priority, and angular cost.
*/
function geometryDiagnosticsIsPlanarCandidateBetter candidate_score candidate_orientation_cost candidate_priority best_inlier_count best_orientation_cost best_candidate_priority best_angular_cost best_total_deviation =
(
    local candidate_better = false
    local comparison_epsilon = 0.000001

    if candidate_score[1] > best_inlier_count then
    (
        candidate_better = true
    )
    else if candidate_score[1] == best_inlier_count then
    (
        if candidate_orientation_cost < (best_orientation_cost - comparison_epsilon) then
        (
            candidate_better = true
        )
        else if abs (candidate_orientation_cost - best_orientation_cost) <= comparison_epsilon then
        (
            if candidate_score[3] < (best_total_deviation - comparison_epsilon) then
            (
                candidate_better = true
            )
            else if abs (candidate_score[3] - best_total_deviation) <= comparison_epsilon then
            (
                if candidate_priority < best_candidate_priority then
                (
                    candidate_better = true
                )
                else if candidate_priority == best_candidate_priority and candidate_score[2] < (best_angular_cost - comparison_epsilon) then
                (
                    candidate_better = true
                )
            )
        )
    )

    candidate_better
    -- return
)


/*
Returns one evaluated TriMesh face BitArray for every Wall-Fixer wall-plane cluster.
Adjacent triangles remain together below 45 degrees and sharp corners split connected multi-wall objects.
*/
function geometryDiagnosticsGetPlanarMeshWallFaceGroups analysis_mesh wall_corner_angle:45.0 =
(
    local wall_groups = #()

    if analysis_mesh != undefined and analysis_mesh.numfaces > 0 then
    (
        local safe_corner_angle = wall_corner_angle
        if safe_corner_angle < 0.1 then safe_corner_angle = 0.1
        if safe_corner_angle > 179.9 then safe_corner_angle = 179.9

        local remaining_faces = #{}
        for face_index = 1 to analysis_mesh.numfaces do
        (
            remaining_faces[face_index] = true
        )

        while remaining_faces.numberSet > 0 do
        (
            local seed_face = (remaining_faces as array)[1]
            local wall_faces = #{}

            try
            (
                wall_faces = meshop.getPolysUsingFace \
                    analysis_mesh \
                    #{seed_face} \
                    ignoreVisEdges:true \
                    threshhold:safe_corner_angle
            )
            catch
            (
                local exception_text = getCurrentException()
                format "Geometry Diagnostics PLANAR NOTICE | stage:wallGroups | seed_face:% | angle:% | exception:% | fallback:seed-only\n" \
                    seed_face safe_corner_angle exception_text
                wall_faces = #{seed_face}
            )

            if wall_faces.numberSet == 0 then wall_faces = #{seed_face}

            append wall_groups wall_faces
            remaining_faces = remaining_faces - wall_faces
        )
    )

    wall_groups
    -- return
)


/*
Analyzes one Wall-Fixer sharp-corner-delimited wall cluster against its dominant plane.
Returned outlier IDs remain evaluated-mesh vertex IDs so cluster results can be merged safely.
*/
function geometryDiagnosticsAnalyzePlanarMeshElement source_node analysis_mesh element_faces planar_tolerance:1.0 normal_angle_tolerance:5.0 =
(
    local result_data = #(false, [0,0,1], 0.0, #{}, 0.0, 0, "Unable to analyze wall cluster.")

    if source_node == undefined or not isValidNode source_node or analysis_mesh == undefined or element_faces.numberSet == 0 then
    (
        return #(false, [0,0,1], 0.0, #{}, 0.0, 0, "Invalid wall cluster.")
    )

    local safe_tolerance = amax 0.000001 planar_tolerance
    local element_vertex_bits = meshop.getVertsUsingFace analysis_mesh element_faces
    local element_vertex_ids = element_vertex_bits as array
    local world_points = #()
    local face_normal_records = #()
    local face_candidates = #()

    if element_vertex_ids.count < 3 then
    (
        return #(false, [0,0,1], 0.0, #{}, 0.0, element_vertex_ids.count, "Wall cluster has fewer than three vertices.")
    )

    for vertex_index in element_vertex_ids do
    (
        append world_points ((getVert analysis_mesh vertex_index) * source_node.objectTransform)
    )

    for face_index in element_faces do
    (
        local face_vertices = getFace analysis_mesh face_index
        local vertex_a = (getVert analysis_mesh (face_vertices.x as integer)) * source_node.objectTransform
        local vertex_b = (getVert analysis_mesh (face_vertices.y as integer)) * source_node.objectTransform
        local vertex_c = (getVert analysis_mesh (face_vertices.z as integer)) * source_node.objectTransform
        local cross_value = cross (vertex_b - vertex_a) (vertex_c - vertex_a)
        local cross_length = length cross_value

        if cross_length > 0.0000001 then
        (
            local face_normal = geometryDiagnosticsCanonicalPlanarNormal (cross_value / cross_length)
            append face_normal_records #(face_normal, cross_length)
            append face_candidates #(face_normal, dot vertex_a face_normal)
        )
    )

    if face_candidates.count == 0 then
    (
        return #(false, [0,0,1], 0.0, #{}, 0.0, element_vertex_ids.count, "No non-degenerate wall faces were found.")
    )

    local orientation_mode = geometryDiagnosticsGetPlanarOrientationMode face_normal_records normal_angle_tolerance
    local best_normal = undefined
    local best_offset = 0.0
    local best_inlier_count = -1
    local best_orientation_cost = 1.0e30
    local best_candidate_priority = 999
    local best_angular_cost = 1.0e30
    local best_total_deviation = 1.0e30

    for candidate_data in face_candidates do
    (
        local candidate_score = geometryDiagnosticsScorePlanarPlaneCandidate world_points face_normal_records candidate_data[1] candidate_data[2] safe_tolerance
        local candidate_orientation_cost = geometryDiagnosticsGetPlanarOrientationCost candidate_data[1] orientation_mode
        local candidate_priority = 0
        local candidate_better = geometryDiagnosticsIsPlanarCandidateBetter \
            candidate_score \
            candidate_orientation_cost \
            candidate_priority \
            best_inlier_count \
            best_orientation_cost \
            best_candidate_priority \
            best_angular_cost \
            best_total_deviation

        if candidate_better then
        (
            best_normal = candidate_data[1]
            best_offset = candidate_data[2]
            best_inlier_count = candidate_score[1]
            best_orientation_cost = candidate_orientation_cost
            best_candidate_priority = candidate_priority
            best_angular_cost = candidate_score[2]
            best_total_deviation = candidate_score[3]
        )
    )

    local sample_indices = #()
    local sample_limit = if world_points.count <= 32 then world_points.count else 12

    if sample_limit == world_points.count then
    (
        for vertex_index = 1 to world_points.count do append sample_indices vertex_index
    )
    else
    (
        for sample_index = 0 to (sample_limit - 1) do
        (
            local vertex_index = 1 + (((sample_index as float) * (world_points.count - 1) / (sample_limit - 1)) as integer)
            if findItem sample_indices vertex_index == 0 then append sample_indices vertex_index
        )
    )

    if sample_indices.count >= 3 then
    (
        for sample_a = 1 to (sample_indices.count - 2) do
        (
            for sample_b = (sample_a + 1) to (sample_indices.count - 1) do
            (
                for sample_c = (sample_b + 1) to sample_indices.count do
                (
                    local candidate_data = geometryDiagnosticsGetPlanarPlaneCandidate \
                        world_points[sample_indices[sample_a]] \
                        world_points[sample_indices[sample_b]] \
                        world_points[sample_indices[sample_c]]

                    if candidate_data.count == 2 then
                    (
                        local candidate_score = geometryDiagnosticsScorePlanarPlaneCandidate world_points face_normal_records candidate_data[1] candidate_data[2] safe_tolerance
                        local candidate_orientation_cost = geometryDiagnosticsGetPlanarOrientationCost candidate_data[1] orientation_mode
                        local candidate_priority = 1
                        local candidate_better = geometryDiagnosticsIsPlanarCandidateBetter \
                            candidate_score \
                            candidate_orientation_cost \
                            candidate_priority \
                            best_inlier_count \
                            best_orientation_cost \
                            best_candidate_priority \
                            best_angular_cost \
                            best_total_deviation

                        if candidate_better then
                        (
                            best_normal = candidate_data[1]
                            best_offset = candidate_data[2]
                            best_inlier_count = candidate_score[1]
                            best_orientation_cost = candidate_orientation_cost
                            best_candidate_priority = candidate_priority
                            best_angular_cost = candidate_score[2]
                            best_total_deviation = candidate_score[3]
                        )
                    )
                )
            )
        )
    )

    if best_normal == undefined or best_inlier_count < 3 or (best_inlier_count * 2) <= world_points.count then
    (
        return #(false, [0,0,1], 0.0, #{}, 0.0, element_vertex_ids.count, "No majority wall plane was found. Run Step 2 first.")
    )

    local target_offset = best_offset
    local strict_planar_tolerance = amin safe_tolerance 0.001
    strict_planar_tolerance = amax strict_planar_tolerance 0.000001
    local outlier_vertices = #{}
    local max_deviation = 0.0

    for local_vertex_index = 1 to world_points.count do
    (
        local vertex_deviation = abs ((dot world_points[local_vertex_index] best_normal) - target_offset)
        if vertex_deviation > max_deviation then max_deviation = vertex_deviation

        if vertex_deviation > strict_planar_tolerance then
        (
            outlier_vertices[element_vertex_ids[local_vertex_index]] = true
        )
    )

    result_data = #(true, best_normal, target_offset, outlier_vertices, max_deviation, element_vertex_ids.count, "")
    result_data
    -- return
)


/*
Analyzes every Wall-Fixer wall cluster independently and merges its true non-planar vertex IDs.
The result also carries the wall-cluster plane records required by RMB repair.
*/
function analyzeGeometryDiagnosticsPlanarWall source_node planar_tolerance:1.0 normal_angle_tolerance:5.0 wall_corner_angle:45.0 =
(
    local result_data = #(false, [0,0,1], 0.0, #{}, 0.0, 0, "Unable to analyze wall.", #())
    local analysis_mesh = undefined
    local operation_failed = false
    local exception_text = ""

    if source_node == undefined or not isValidNode source_node or superClassOf source_node != GeometryClass then
    (
        return #(false, [0,0,1], 0.0, #{}, 0.0, 0, "Invalid geometry object.", #())
    )

    try
    (
        analysis_mesh = snapshotAsMesh source_node

        if analysis_mesh == undefined or analysis_mesh.numfaces <= 0 or analysis_mesh.numverts < 3 then
        (
            result_data = #(false, [0,0,1], 0.0, #{}, 0.0, 0, "Wall has no usable evaluated mesh.", #())
        )
        else
        (
            local wall_groups = geometryDiagnosticsGetPlanarMeshWallFaceGroups analysis_mesh wall_corner_angle:wall_corner_angle

            if wall_groups.count == 0 then
            (
                result_data = #(false, [0,0,1], 0.0, #{}, 0.0, analysis_mesh.numverts, "No wall face clusters were found.", #())
            )
            else
            (
                local aggregate_outliers = #{}
                local aggregate_max_deviation = 0.0
                local first_normal = [0,0,1]
                local first_offset = 0.0
                local analysis_failed = false
                local failure_message = ""
                local wall_cluster_records = #()

                for wall_index = 1 to wall_groups.count do
                (
                    if not analysis_failed then
                    (
                        local wall_result = geometryDiagnosticsAnalyzePlanarMeshElement \
                            source_node \
                            analysis_mesh \
                            wall_groups[wall_index] \
                            planar_tolerance:planar_tolerance \
                            normal_angle_tolerance:normal_angle_tolerance

                        if not wall_result[1] then
                        (
                            analysis_failed = true
                            failure_message = "Wall cluster " + (wall_index as string) + ": " + wall_result[7]
                        )
                        else
                        (
                            local wall_vertices = meshop.getVertsUsingFace analysis_mesh wall_groups[wall_index]
                            append wall_cluster_records #((copy wall_groups[wall_index]), (copy wall_vertices), wall_result[2], wall_result[3], (copy wall_result[4]), wall_result[5])

                            if wall_index == 1 then
                            (
                                first_normal = wall_result[2]
                                first_offset = wall_result[3]
                            )

                            for vertex_index in wall_result[4] do aggregate_outliers[vertex_index] = true
                            if wall_result[5] > aggregate_max_deviation then aggregate_max_deviation = wall_result[5]
                        )
                    )
                )

                if analysis_failed then
                (
                    result_data = #(false, first_normal, first_offset, aggregate_outliers, aggregate_max_deviation, analysis_mesh.numverts, failure_message, wall_cluster_records)
                )
                else
                (
                    result_data = #(true, first_normal, first_offset, aggregate_outliers, aggregate_max_deviation, analysis_mesh.numverts, "", wall_cluster_records)
                )
            )
        )
    )
    catch
    (
        exception_text = getCurrentException()
        operation_failed = true
    )

    if analysis_mesh != undefined then
    (
        try
        (
            free analysis_mesh
        )
        catch
        (
            local free_exception_text = getCurrentException()
            format "Geometry Diagnostics PLANAR CLEANUP ERROR | node:% | exception:%\n" source_node.name free_exception_text
        )
    )

    if operation_failed then
    (
        format "Geometry Diagnostics PLANAR ERROR | stage:analyze | node:% | tolerance:% | normal_angle:% | corner_angle:% | exception:%\n" \
            source_node.name planar_tolerance normal_angle_tolerance wall_corner_angle exception_text
        return #(false, [0,0,1], 0.0, #{}, 0.0, 0, (exception_text as string), #())
    )

    result_data
    -- return
)


/*
Returns the exact Geometry Diagnostics planar-selection marker owned for one node.
Stale rows are discarded and same-name foreign modifiers are never adopted.
*/
function getGeometryDiagnosticsOwnedPlanarSelectionMarker source_node =
(
    if not isValidNode source_node then return undefined

    local owned_marker = undefined
    local live_owner_rows = #()

    for owner_row in geometry_diagnostics_planar_selection_owners do
    (
        if classOf owner_row == Array and owner_row.count >= 2 then
        (
            local owner_node = owner_row[1]
            local owner_marker = owner_row[2]

            if isValidNode owner_node and owner_marker != undefined and geometryDiagnosticsModifierBelongsToNode owner_node owner_marker then
            (
                append live_owner_rows owner_row
                if owner_node == source_node and owned_marker == undefined then owned_marker = owner_marker
            )
        )
    )

    geometry_diagnostics_planar_selection_owners = live_owner_rows
    owned_marker
    -- return
)


/*
Forgets one exact Geometry Diagnostics planar-selection marker ownership row.
The modifier is not deleted by this helper.
*/
function removeGeometryDiagnosticsPlanarSelectionOwner source_node selection_edit_poly_mod =
(
    local live_owner_rows = #()

    for owner_row in geometry_diagnostics_planar_selection_owners do
    (
        if classOf owner_row == Array and owner_row.count >= 2 then
        (
            if not (owner_row[1] == source_node and owner_row[2] == selection_edit_poly_mod) then append live_owner_rows owner_row
        )
    )

    geometry_diagnostics_planar_selection_owners = live_owner_rows
    true
    -- return
)


/*
Removes only the exact Geometry Diagnostics temporary NON PLANAR VERTS marker created by a prior LMB check.
A same-name user modifier is never treated as owned.
*/
function removeGeometryDiagnosticsPlanarSelectionMarker source_node =
(
    if not isValidNode source_node then return false

    local selection_edit_poly_mod = getGeometryDiagnosticsOwnedPlanarSelectionMarker source_node
    if selection_edit_poly_mod == undefined then return false

    if not geometryDiagnosticsModifierBelongsToNode source_node selection_edit_poly_mod then
    (
        removeGeometryDiagnosticsPlanarSelectionOwner source_node selection_edit_poly_mod
        return false
    )

    try
    (
        deleteModifier source_node selection_edit_poly_mod
        update source_node
    )
    catch
    (
        local exception_text = getCurrentException()
        format "Geometry Diagnostics PLANAR MARKER ERROR | stage:remove | node:% | edit_poly:% | exception:%\n" \
            source_node.name selection_edit_poly_mod exception_text
        return false
    )

    removeGeometryDiagnosticsPlanarSelectionOwner source_node selection_edit_poly_mod
    true
    -- return
)


/*
Clears the previous Wall-Fixer-style planar vertex selection before one new LMB check.
An existing top Edit Poly is reused; only the exact Geometry Diagnostics temporary marker is removed.
*/
function clearGeometryDiagnosticsPlanarCheckSelection source_node =
(
    if not isValidNode source_node then return false

    if classOf source_node.baseObject == Editable_Poly then source_node.baseObject.showCage = off
    removeGeometryDiagnosticsPlanarSelectionMarker source_node

    local top_edit_poly = undefined
    if source_node.modifiers.count > 0 and classOf source_node.modifiers[1] == Edit_Poly then top_edit_poly = source_node.modifiers[1]

    if top_edit_poly != undefined then
    (
        try
        (
            select source_node
            max modify mode
            modPanel.setCurrentObject top_edit_poly
            top_edit_poly.SetPrimaryNode source_node
            top_edit_poly.useStackSelection = false
            top_edit_poly.showCage = off
            top_edit_poly.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            top_edit_poly.SetSelection #Vertex #{} node:source_node
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Geometry Diagnostics PLANAR SELECTION ERROR | stage:clearTopEditPoly | node:% | edit_poly:% | exception:%\n" \
                source_node.name top_edit_poly exception_text
            return false
        )
    )
    else if source_node.modifiers.count == 0 and classOf source_node.baseObject == Editable_Poly then
    (
        polyop.setVertSelection source_node.baseObject #{}
        update source_node
    )

    true
    -- return
)


/*
Selects Wall-Fixer planar outlier vertices without changing topology.
A current top Edit Poly is reused; otherwise a session-owned NON PLANAR VERTS Edit Poly is created only when needed.
*/
function selectGeometryDiagnosticsPlanarOutlierVerts source_node outlier_vertices expected_vertex_count =
(
    if not isValidNode source_node or classOf outlier_vertices != BitArray or outlier_vertices.numberSet == 0 then return false
    if classOf source_node.baseObject == Editable_Poly then source_node.baseObject.showCage = off

    local top_edit_poly = undefined
    if source_node.modifiers.count > 0 and classOf source_node.modifiers[1] == Edit_Poly then top_edit_poly = source_node.modifiers[1]

    if top_edit_poly != undefined then
    (
        try
        (
            select source_node
            max modify mode
            modPanel.setCurrentObject top_edit_poly
            top_edit_poly.SetPrimaryNode source_node
            top_edit_poly.useStackSelection = false
            top_edit_poly.showCage = off
            top_edit_poly.SetEPolySelLevel #Vertex
            subObjectLevel = 1
            top_edit_poly.ButtonOp #UnhideAllVertex
            update source_node
            top_edit_poly.SetSelection #Vertex (copy outlier_vertices) node:source_node

            local actual_selection = top_edit_poly.GetSelection #Vertex node:source_node
            if actual_selection != outlier_vertices then
            (
                format "Geometry Diagnostics PLANAR SELECTION ERROR | stage:topEditPolyReadback | node:% | requested:% | actual:%\n" \
                    source_node.name outlier_vertices actual_selection
                return false
            )
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Geometry Diagnostics PLANAR SELECTION ERROR | stage:topEditPoly | node:% | edit_poly:% | exception:%\n" \
                source_node.name top_edit_poly exception_text
            return false
        )

        return true
    )

    if source_node.modifiers.count == 0 and classOf source_node.baseObject == Editable_Poly then
    (
        local actual_vertex_count = polyop.getNumVerts source_node.baseObject
        if actual_vertex_count != expected_vertex_count then
        (
            format "Geometry Diagnostics PLANAR SELECTION ERROR | stage:baseTopology | node:% | expected_vertex_count:% | actual_vertex_count:%\n" \
                source_node.name expected_vertex_count actual_vertex_count
            return false
        )

        polyop.unHideAllVerts source_node.baseObject
        polyop.setVertSelection source_node.baseObject outlier_vertices
        update source_node

        local actual_selection = polyop.getVertSelection source_node.baseObject
        if actual_selection != outlier_vertices then
        (
            format "Geometry Diagnostics PLANAR SELECTION ERROR | stage:baseReadback | node:% | requested:% | actual:%\n" \
                source_node.name outlier_vertices actual_selection
            return false
        )

        select source_node
        max modify mode
        modPanel.setCurrentObject source_node.baseObject node:source_node ui:true
        subObjectLevel = 1
        return true
    )

    local selection_edit_poly_mod = undefined

    try
    (
        selection_edit_poly_mod = Edit_Poly name:"NON PLANAR VERTS"
        selection_edit_poly_mod.showCage = off
        addModifier source_node selection_edit_poly_mod
        append geometry_diagnostics_planar_selection_owners #(source_node, selection_edit_poly_mod)
        update source_node

        select source_node
        max modify mode
        modPanel.setCurrentObject selection_edit_poly_mod
        selection_edit_poly_mod.SetPrimaryNode source_node
        selection_edit_poly_mod.useStackSelection = false
        selection_edit_poly_mod.SetEPolySelLevel #Vertex
        subObjectLevel = 1
        selection_edit_poly_mod.ButtonOp #UnhideAllVertex
        update source_node
        selection_edit_poly_mod.SetSelection #Vertex (copy outlier_vertices) node:source_node

        local actual_selection = selection_edit_poly_mod.GetSelection #Vertex node:source_node
        if actual_selection != outlier_vertices then
        (
            format "Geometry Diagnostics PLANAR SELECTION ERROR | stage:markerReadback | node:% | requested:% | actual:% | edit_poly:%\n" \
                source_node.name outlier_vertices actual_selection selection_edit_poly_mod
            throw "NON PLANAR VERTS selection read-back mismatch."
        )
    )
    catch
    (
        local exception_text = getCurrentException()
        format "Geometry Diagnostics PLANAR SELECTION ERROR | stage:createMarker | node:% | edit_poly:% | exception:%\n" \
            source_node.name selection_edit_poly_mod exception_text

        if selection_edit_poly_mod != undefined and geometryDiagnosticsModifierBelongsToNode source_node selection_edit_poly_mod then
        (
            try
            (
                deleteModifier source_node selection_edit_poly_mod
                update source_node
            )
            catch
            (
                local cleanup_exception_text = getCurrentException()
                format "Geometry Diagnostics PLANAR SELECTION CLEANUP ERROR | node:% | edit_poly:% | exception:%\n" \
                    source_node.name selection_edit_poly_mod cleanup_exception_text
            )
        )

        removeGeometryDiagnosticsPlanarSelectionOwner source_node selection_edit_poly_mod
        return false
    )

    true
    -- return
)


/*
Returns the unique Wall-Fixer wall-cluster planes touching one evaluated vertex.
Parallel duplicate planes are collapsed before the repair target is solved.
*/
function geometryDiagnosticsGetPlanarVertexWallClusterPlanes wall_cluster_records vertex_index =
(
    local vertex_planes = #()
    local parallel_dot_limit = 0.99999

    for cluster_record in wall_cluster_records do
    (
        if cluster_record.count >= 4 and cluster_record[2][vertex_index] then
        (
            local plane_normal = cluster_record[3]
            local plane_offset = cluster_record[4]
            local duplicate_plane = false

            for existing_plane in vertex_planes while not duplicate_plane do
            (
                if abs (dot existing_plane[1] plane_normal) >= parallel_dot_limit then duplicate_plane = true
            )

            if not duplicate_plane then append vertex_planes #(plane_normal, plane_offset)
        )
    )

    vertex_planes
    -- return
)


/*
Returns the nearest practical Wall-Fixer point satisfying the wall planes that share one vertex.
One plane projects, two solve the strongest intersection line, and three or more solve the strongest independent triplet.
*/
function geometryDiagnosticsGetPlanarVertexWallClusterTarget vertex_world vertex_planes =
(
    local target_world = undefined
    local plane_count = vertex_planes.count
    local epsilon_value = 0.0000001

    if plane_count == 1 then
    (
        local plane_normal = vertex_planes[1][1]
        local plane_offset = vertex_planes[1][2]
        local signed_deviation = (dot vertex_world plane_normal) - plane_offset
        target_world = vertex_world - (plane_normal * signed_deviation)
    )
    else if plane_count >= 2 then
    (
        local best_pair_a = 0
        local best_pair_b = 0
        local best_pair_cross = 0.0

        for plane_a_index = 1 to (plane_count - 1) do
        (
            for plane_b_index = (plane_a_index + 1) to plane_count do
            (
                local pair_cross = length (cross vertex_planes[plane_a_index][1] vertex_planes[plane_b_index][1])
                if pair_cross > best_pair_cross then
                (
                    best_pair_cross = pair_cross
                    best_pair_a = plane_a_index
                    best_pair_b = plane_b_index
                )
            )
        )

        if plane_count >= 3 then
        (
            local best_det = 0.0
            local best_triplet = undefined

            for plane_a_index = 1 to (plane_count - 2) do
            (
                for plane_b_index = (plane_a_index + 1) to (plane_count - 1) do
                (
                    for plane_c_index = (plane_b_index + 1) to plane_count do
                    (
                        local normal_a = vertex_planes[plane_a_index][1]
                        local normal_b = vertex_planes[plane_b_index][1]
                        local normal_c = vertex_planes[plane_c_index][1]
                        local det_value = dot normal_a (cross normal_b normal_c)
                        local absolute_det = abs det_value

                        if absolute_det > best_det then
                        (
                            best_det = absolute_det
                            best_triplet = #(plane_a_index, plane_b_index, plane_c_index, det_value)
                        )
                    )
                )
            )

            if best_triplet != undefined and best_det > epsilon_value then
            (
                local plane_a = vertex_planes[best_triplet[1]]
                local plane_b = vertex_planes[best_triplet[2]]
                local plane_c = vertex_planes[best_triplet[3]]
                local det_value = best_triplet[4]

                target_world = \
                    (((cross plane_b[1] plane_c[1]) * plane_a[2]) + \
                    ((cross plane_c[1] plane_a[1]) * plane_b[2]) + \
                    ((cross plane_a[1] plane_b[1]) * plane_c[2])) / det_value
            )
        )

        if target_world == undefined and best_pair_a > 0 and best_pair_cross > epsilon_value then
        (
            local plane_a = vertex_planes[best_pair_a]
            local plane_b = vertex_planes[best_pair_b]
            local normal_dot = dot plane_a[1] plane_b[1]
            local denominator = 1.0 - (normal_dot * normal_dot)

            if abs denominator > epsilon_value then
            (
                local deviation_a = (dot vertex_world plane_a[1]) - plane_a[2]
                local deviation_b = (dot vertex_world plane_b[1]) - plane_b[2]
                local lambda_a = (deviation_a - (normal_dot * deviation_b)) / denominator
                local lambda_b = (deviation_b - (normal_dot * deviation_a)) / denominator
                target_world = vertex_world - (plane_a[1] * lambda_a) - (plane_b[1] * lambda_b)
            )
        )

        if target_world == undefined then
        (
            local plane_normal = vertex_planes[1][1]
            local plane_offset = vertex_planes[1][2]
            local signed_deviation = (dot vertex_world plane_normal) - plane_offset
            target_world = vertex_world - (plane_normal * signed_deviation)
        )

        for cleanup_pass = 1 to 3 do
        (
            for plane_record in vertex_planes do
            (
                local signed_deviation = (dot target_world plane_record[1]) - plane_record[2]
                target_world = target_world - (plane_record[1] * signed_deviation)
            )
        )
    )

    target_world
    -- return
)


/*
Builds the Wall-Fixer fallback plane from the other vertices of one Editable Poly polygon face.
Detected outliers are excluded first; when too few clean vertices remain only the current repair vertex is excluded.
*/
function geometryDiagnosticsGetPlanarFaceRepairPlane source_node face_index vertex_index outlier_vertices =
(
    local plane_data = #()
    if not isValidNode source_node or classOf source_node.baseObject != Editable_Poly then return plane_data

    source_node.baseObject.showCage = off
    local source_poly = source_node.baseObject
    local face_vertices = polyop.getFaceVerts source_poly face_index
    local candidate_vertices = #()

    for face_vertex_index in face_vertices do
    (
        if face_vertex_index != vertex_index and not outlier_vertices[face_vertex_index] then
        (
            if findItem candidate_vertices face_vertex_index == 0 then append candidate_vertices face_vertex_index
        )
    )

    if candidate_vertices.count < 3 then
    (
        candidate_vertices = #()
        for face_vertex_index in face_vertices do
        (
            if face_vertex_index != vertex_index and findItem candidate_vertices face_vertex_index == 0 then append candidate_vertices face_vertex_index
        )
    )

    if candidate_vertices.count >= 3 then
    (
        local best_cross_length = 0.0
        local best_cross_value = undefined
        local best_point = undefined

        for point_a_index = 1 to (candidate_vertices.count - 2) do
        (
            local point_a = (polyop.getVert source_poly candidate_vertices[point_a_index]) * source_node.objectTransform

            for point_b_index = (point_a_index + 1) to (candidate_vertices.count - 1) do
            (
                local point_b = (polyop.getVert source_poly candidate_vertices[point_b_index]) * source_node.objectTransform

                for point_c_index = (point_b_index + 1) to candidate_vertices.count do
                (
                    local point_c = (polyop.getVert source_poly candidate_vertices[point_c_index]) * source_node.objectTransform
                    local cross_value = cross (point_b - point_a) (point_c - point_a)
                    local cross_length = length cross_value

                    if cross_length > best_cross_length then
                    (
                        best_cross_length = cross_length
                        best_cross_value = cross_value
                        best_point = point_a
                    )
                )
            )
        )

        if best_cross_value != undefined and best_cross_length > 0.0000001 then
        (
            local target_normal = geometryDiagnosticsCanonicalPlanarNormal (best_cross_value / best_cross_length)
            local target_offset = dot best_point target_normal
            plane_data = #(target_normal, target_offset, candidate_vertices.count, best_cross_length, face_index)
        )
    )

    plane_data
    -- return
)


/*
Finds the strongest Wall-Fixer owning-face fallback plane for one non-planar vertex.
N-gons are preferred by clean support count and then by defining-triangle area.
*/
function geometryDiagnosticsGetPlanarVertexRepairPlane source_node vertex_index outlier_vertices =
(
    local best_plane_data = #()
    if not isValidNode source_node or classOf source_node.baseObject != Editable_Poly then return best_plane_data

    source_node.baseObject.showCage = off
    local source_poly = source_node.baseObject
    local faces_using_vertex = polyop.getFacesUsingVert source_poly #{vertex_index}
    local best_support_count = -1
    local best_cross_length = -1.0

    for face_index in faces_using_vertex do
    (
        local plane_data = geometryDiagnosticsGetPlanarFaceRepairPlane source_node face_index vertex_index outlier_vertices

        if plane_data.count >= 5 then
        (
            local support_count = plane_data[3]
            local cross_length = plane_data[4]

            if support_count > best_support_count or (support_count == best_support_count and cross_length > best_cross_length) then
            (
                best_plane_data = plane_data
                best_support_count = support_count
                best_cross_length = cross_length
            )
        )
    )

    best_plane_data
    -- return
)


/*
Moves each detected non-planar vertex onto the Wall-Fixer wall plane or shared-wall plane intersection.
When the real stack requires repair, it is collapsed to Editable Poly exactly as in the Wall-Fixer RMB action.
*/
function makeGeometryDiagnosticsPlanarWall source_node planar_tolerance:1.0 normal_angle_tolerance:5.0 wall_corner_angle:45.0 =
(
    if not isValidNode source_node then return #(false, 0, "Invalid geometry object.")
    if classOf source_node.baseObject == Editable_Poly then source_node.baseObject.showCage = off

    local precheck = analyzeGeometryDiagnosticsPlanarWall \
        source_node \
        planar_tolerance:planar_tolerance \
        normal_angle_tolerance:normal_angle_tolerance \
        wall_corner_angle:wall_corner_angle

    if not precheck[1] then return #(false, 0, precheck[7])
    if precheck[4].numberSet == 0 then return #(true, 0, "")

    local conversion_success = true

    if source_node.modifiers.count > 0 or classOf source_node.baseObject != Editable_Poly then
    (
        try
        (
            convertToPoly source_node
            if classOf source_node.baseObject == Editable_Poly then source_node.baseObject.showCage = off
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Geometry Diagnostics PLANAR FIX ERROR | stage:convertToPoly | node:% | exception:%\n" source_node.name exception_text
            conversion_success = false
        )
    )

    if not conversion_success or classOf source_node.baseObject != Editable_Poly then
    (
        return #(false, 0, "Wall could not be converted to Editable Poly for repair.")
    )

    local repair_data = analyzeGeometryDiagnosticsPlanarWall \
        source_node \
        planar_tolerance:planar_tolerance \
        normal_angle_tolerance:normal_angle_tolerance \
        wall_corner_angle:wall_corner_angle

    if not repair_data[1] then return #(false, 0, repair_data[7])

    local outlier_vertices = repair_data[4]
    local wall_cluster_records = if repair_data.count >= 8 then repair_data[8] else #()
    local repaired_count = 0
    local failed_repair_count = 0
    local inverse_object_tm = inverse source_node.objectTransform

    for vertex_index in outlier_vertices do
    (
        local vertex_local = polyop.getVert source_node.baseObject vertex_index
        local vertex_world = vertex_local * source_node.objectTransform
        local vertex_planes = geometryDiagnosticsGetPlanarVertexWallClusterPlanes wall_cluster_records vertex_index
        local target_world = geometryDiagnosticsGetPlanarVertexWallClusterTarget vertex_world vertex_planes

        if target_world == undefined then
        (
            local repair_plane = geometryDiagnosticsGetPlanarVertexRepairPlane source_node vertex_index outlier_vertices

            if repair_plane.count >= 2 then
            (
                local target_normal = repair_plane[1]
                local target_offset = repair_plane[2]
                local signed_deviation = (dot vertex_world target_normal) - target_offset
                target_world = vertex_world - (target_normal * signed_deviation)
            )
        )

        if target_world != undefined then
        (
            local target_local = target_world * inverse_object_tm
            polyop.setVert source_node.baseObject vertex_index target_local
            repaired_count += 1
        )
        else
        (
            failed_repair_count += 1
        )
    )

    update source_node

    local verify_data = analyzeGeometryDiagnosticsPlanarWall \
        source_node \
        planar_tolerance:planar_tolerance \
        normal_angle_tolerance:normal_angle_tolerance \
        wall_corner_angle:wall_corner_angle

    if failed_repair_count > 0 then
    (
        return #(false, repaired_count, "Unable to build wall-cluster planes for " + (failed_repair_count as string) + " non-planar vert(s).")
    )

    if verify_data[1] and verify_data[4].numberSet == 0 then return #(true, repaired_count, "")

    local remaining_count = if verify_data[1] then verify_data[4].numberSet else repaired_count
    #(false, repaired_count, "Repair verification failed; remaining non-planar verts: " + (remaining_count as string))
    -- return
)


/*
Removes face-unreferenced vertices after a successful planar repair.
Dead topology is synchronized before IDs are read and again only after deletion before a fresh count is queried.
*/
function cleanupGeometryDiagnosticsPlanarRedundantVertices source_node =
(
    if not isValidNode source_node or classOf source_node.baseObject != Editable_Poly then return 0

    local source_poly = source_node.baseObject
    source_poly.showCage = off

    if polyop.getHasDeadStructs source_poly != 0 then
    (
        polyop.collapseDeadStructs source_poly
    )

    local before_count = polyop.getNumVerts source_poly
    local face_count = polyop.getNumFaces source_poly
    local used_vertices = #{}

    for face_index = 1 to face_count do
    (
        local face_vertices = polyop.getFaceVerts source_poly face_index
        for vertex_index in face_vertices do used_vertices[vertex_index] = true
    )

    local redundant_vertices = #{}
    redundant_vertices.count = before_count

    for vertex_index = 1 to before_count do
    (
        if not used_vertices[vertex_index] then redundant_vertices[vertex_index] = true
    )

    if redundant_vertices.numberSet == 0 then return 0

    polyop.deleteVerts source_poly redundant_vertices

    if polyop.getHasDeadStructs source_poly != 0 then
    (
        polyop.collapseDeadStructs source_poly
    )

    update source_node
    local after_count = polyop.getNumVerts source_poly
    amax 0 (before_count - after_count)
    -- return
)


/*
Runs the Wall-Fixer planar-wall button contract on the current geometry selection.
LMB selects non-planar vertices; RMB repairs only those vertices and verifies the result.
*/
function runGeometryDiagnosticsPlanarWalls fix_vertices:false =
(
    local selected_nodes = selection as array
    local geometry_nodes = #()
    local total_outliers = 0
    local selected_outliers = 0
    local problem_nodes = #()
    local failed_nodes = #()
    local repaired_vertices = 0
    local repaired_walls = 0
    local failed_walls = 0
    local failure_messages = #()
    local planar_tolerance = 1.0
    local normal_angle_tolerance = 5.0
    local wall_corner_angle = 45.0

    for source_node in selected_nodes do
    (
        if source_node != undefined and isValidNode source_node and superClassOf source_node == GeometryClass then append geometry_nodes source_node
    )

    if geometry_nodes.count == 0 then
    (
        format "Geometry Diagnostics PLANAR ERROR | stage:input | required:at least one geometry object\n"
        return #(false, 0, 0, 0, 0, 0, "Select at least one wall object.")
    )

    if fix_vertices then
    (
        undo "Geometry Diagnostics - Make Walls Planar" on
        (
            with redraw off
            (
                for source_node in geometry_nodes do
                (
                    removeGeometryDiagnosticsPlanarSelectionMarker source_node
                    local precheck = analyzeGeometryDiagnosticsPlanarWall \
                        source_node \
                        planar_tolerance:planar_tolerance \
                        normal_angle_tolerance:normal_angle_tolerance \
                        wall_corner_angle:wall_corner_angle

                    if precheck[1] then
                    (
                        total_outliers += precheck[4].numberSet

                        if precheck[4].numberSet > 0 then
                        (
                            local repair_result = makeGeometryDiagnosticsPlanarWall \
                                source_node \
                                planar_tolerance:planar_tolerance \
                                normal_angle_tolerance:normal_angle_tolerance \
                                wall_corner_angle:wall_corner_angle

                            if repair_result[1] then
                            (
                                repaired_vertices += repair_result[2]
                                repaired_walls += 1
                                cleanupGeometryDiagnosticsPlanarRedundantVertices source_node
                            )
                            else
                            (
                                failed_walls += 1
                                if findItem failed_nodes source_node == 0 then append failed_nodes source_node
                                append failure_messages (source_node.name + ": " + repair_result[3])
                            )
                        )
                    )
                    else
                    (
                        failed_walls += 1
                        if findItem failed_nodes source_node == 0 then append failed_nodes source_node
                        append failure_messages (source_node.name + ": " + precheck[7])
                    )
                )
            )
        )

        clearSelection()
        if failed_nodes.count > 0 then select failed_nodes else select geometry_nodes
        max modify mode
        subObjectLevel = 0
        completeRedraw()

        if failed_walls > 0 then
        (
            local failure_text = if failure_messages.count > 0 then failure_messages[1] else "One or more walls could not be repaired."
            local message_text = "Made planar: " + (repaired_walls as string) + " wall(s), " + (repaired_vertices as string) + " vert(s). Failed: " + (failed_walls as string) + ". " + failure_text
            format "Geometry Diagnostics PLANAR FIX ERROR | %\n" message_text
            return #(false, total_outliers, selected_outliers, repaired_vertices, repaired_walls, failed_walls, message_text)
        )

        local success_message = if total_outliers == 0 then "All walls are planar" else ("Walls made planar: " + (repaired_walls as string) + " wall(s), " + (repaired_vertices as string) + " vert(s)")
        return #(true, total_outliers, selected_outliers, repaired_vertices, repaired_walls, failed_walls, success_message)
    )

    for source_node in geometry_nodes do
    (
        clearGeometryDiagnosticsPlanarCheckSelection source_node

        local check_data = analyzeGeometryDiagnosticsPlanarWall \
            source_node \
            planar_tolerance:planar_tolerance \
            normal_angle_tolerance:normal_angle_tolerance \
            wall_corner_angle:wall_corner_angle

        if check_data[1] then
        (
            local outlier_vertices = check_data[4]
            total_outliers += outlier_vertices.numberSet

            if outlier_vertices.numberSet > 0 then
            (
                if selectGeometryDiagnosticsPlanarOutlierVerts source_node outlier_vertices check_data[6] then
                (
                    selected_outliers += outlier_vertices.numberSet
                    if findItem problem_nodes source_node == 0 then append problem_nodes source_node
                )
                else
                (
                    failed_walls += 1
                    if findItem failed_nodes source_node == 0 then append failed_nodes source_node
                    append failure_messages (source_node.name + ": non-planar verts were found but could not be selected.")
                )
            )
        )
        else
        (
            failed_walls += 1
            if findItem failed_nodes source_node == 0 then append failed_nodes source_node
            append failure_messages (source_node.name + ": " + check_data[7])
        )
    )

    clearSelection()

    if problem_nodes.count > 0 then
    (
        select problem_nodes
        max modify mode
        subObjectLevel = 1
    )
    else if failed_nodes.count > 0 then
    (
        select failed_nodes
        max modify mode
        subObjectLevel = 0
    )
    else
    (
        select geometry_nodes
        max modify mode
        subObjectLevel = 0
    )

    completeRedraw()

    if failed_walls > 0 then
    (
        local failure_text = if failure_messages.count > 0 then failure_messages[1] else "One or more walls could not be analyzed."
        local message_text = "Planar check found " + (total_outliers as string) + " non-planar vert(s). Failed walls: " + (failed_walls as string) + ". " + failure_text
        format "Geometry Diagnostics PLANAR CHECK ERROR | %\n" message_text
        return #(false, total_outliers, selected_outliers, repaired_vertices, repaired_walls, failed_walls, message_text)
    )

    local success_message = if total_outliers == 0 then "All walls are planar" else ((total_outliers as string) + " verts out of plane")
    #(true, total_outliers, selected_outliers, repaired_vertices, repaired_walls, failed_walls, success_message)
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
        format "Geometry Diagnostics EDGE SELECTION NOTICE | stage:getAdapter | node:% | edit_poly:% | prepare:false | continuing with Wall-Fixer direct live-topology read\n" \
            source_node.name selection_edit_poly_mod
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
            ensureGeometryDiagnosticsEditPolyPrimaryNode source_node geometry_source

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
        ensureGeometryDiagnosticsEditPolyPrimaryNode source_node geometry_source

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

    local selection_applied = (actual_selection == requested_selection)

    if not selection_applied or not display_activated then
    (
        format "Geometry Diagnostics EDGE SELECTION DEBUG | stage:verifySelection | node:% | requested:% | immediate:% | final:% | display:%\n" \
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

    local final_display_activated = activateGeometryDiagnosticsEdgeSelectionDisplay source_node adapter
    completeRedraw()

    if not final_display_activated then
    (
        format "Geometry Diagnostics CHECK DIRECTION ERROR | stage:finalDisplay | node:% | direction:% | mode:% | required:Modify panel + Edge level\n" \
            source_node.name direction_type selection_mode
        return undefined
    )

    local actual_selection = getGeometryDiagnosticsDirectionEdgeSelection source_node adapter

    if actual_selection == undefined or actual_selection != matched_edges then
    (
        format "Geometry Diagnostics CHECK DIRECTION ERROR | stage:postReadback | node:% | requested:% | actual:%\n" \
            source_node.name matched_edges actual_selection
        return undefined
    )

    if getCommandPanelTaskMode() != #modify or modPanel.getCurrentObject() != adapter[2] or subObjectLevel != 2 then
    (
        format "Geometry Diagnostics CHECK DIRECTION ERROR | stage:finalPanelState | node:% | panel:% | current:% | expected:% | subObjectLevel:% | expected_level:2\n" \
            source_node.name (getCommandPanelTaskMode()) (modPanel.getCurrentObject()) adapter[2] subObjectLevel
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
Runs one Wall-Fixer-style direction selection over the current geometry-object selection.
The loop, geometry filtering, per-node Edit Poly activation, and final redraw mirror Wall-Fixer; only the distance classifier differs.
*/
function checkGeometryDiagnosticsSelectedDirectionEdges direction_type selection_mode position_precision_text =
(
    local selected_nodes = selection as array
    local total_selected_edges = 0
    local processed_count = 0
    local failed_count = 0
    local last_result = undefined

    if selected_nodes.count == 0 then
    (
        format "Geometry Diagnostics DIRECTION ERROR | select at least one geometry object.\n"
        return #(0, 0, 0, undefined)
    )

    if not ensureGeometryDiagnosticsCreatePanelMode() then
    (
        return #(0, 0, selected_nodes.count, undefined)
    )

    for source_node in selected_nodes do
    (
        if isValidNode source_node and superClassOf source_node == GeometryClass then
        (
            processed_count += 1

            local direction_result = checkGeometryDiagnosticsDirectionEdges \
                source_node \
                direction_type \
                selection_mode \
                position_precision_text

            if direction_result == undefined then
            (
                failed_count += 1
            )
            else
            (
                total_selected_edges += direction_result.edge_ids.numberSet
                last_result = direction_result
            )
        )
    )

    if last_result != undefined and isValidNode last_result.source_node and last_result.selection_edit_poly_mod != undefined then
    (
        local final_adapter = #(#edit_poly, last_result.selection_edit_poly_mod, false)
        local final_display_active = activateGeometryDiagnosticsEdgeSelectionDisplay last_result.source_node final_adapter
        local final_panel_mode = getCommandPanelTaskMode()

        if not final_display_active or final_panel_mode != #modify then
        (
            format "Geometry Diagnostics DIRECTION ERROR | stage:finalModifyPanel | node:% | edit_poly:% | display_active:% | panel_mode:% | required:#modify\n" \
                last_result.source_node.name last_result.selection_edit_poly_mod final_display_active final_panel_mode
            failed_count += 1
        )
    )
    else
    (
        try
        (
            max modify mode
        )
        catch
        (
            local exception_text = getCurrentException()
            format "Geometry Diagnostics DIRECTION ERROR | stage:finalModifyPanelFallback | exception:%\n" exception_text
            failed_count += 1
        )
    )

    if processed_count > 0 then
    (
        completeRedraw()
    )

    format "Geometry Diagnostics DIRECTION SELECTION | direction:% | mode:% | processed:% | failed:% | selected_edges:% | panel_mode:%\n" \
        direction_type selection_mode processed_count failed_count total_selected_edges (getCommandPanelTaskMode())

    #(total_selected_edges, processed_count, failed_count, last_result)
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
