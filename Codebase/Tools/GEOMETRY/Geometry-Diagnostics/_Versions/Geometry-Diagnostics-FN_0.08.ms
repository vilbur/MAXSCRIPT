/*
Geometry Diagnostics backend.
Owns Geometry Diagnostics test helpers and delegates reusable color painting to VertexColorPainter.
*/

global geometry_diagnostics_fn_version = "0.08"
global geometry_diagnostics_fn_project_version = "0.10"
global geometry_diagnostics_project_version
global geometry_diagnostics_test_node
global VertexColorPainter

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
