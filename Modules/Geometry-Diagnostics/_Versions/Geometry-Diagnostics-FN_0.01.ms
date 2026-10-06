/*
Geometry Diagnostics backend.
Owns direct Editable Poly channel-0 painting and the first test-box workflow.
*/

global geometry_diagnostics_fn_version = "0.01"
global geometry_diagnostics_fn_project_version = "0.01"
global geometry_diagnostics_project_version
global geometry_diagnostics_color_backups
global geometry_diagnostics_test_node

if geometry_diagnostics_project_version == undefined then
(
    geometry_diagnostics_project_version = geometry_diagnostics_fn_project_version
)
else if (geometry_diagnostics_project_version as float) < (geometry_diagnostics_fn_project_version as float) then
(
    geometry_diagnostics_project_version = geometry_diagnostics_fn_project_version
)

if geometry_diagnostics_color_backups == undefined then
(
    geometry_diagnostics_color_backups = #()
)

if geometry_diagnostics_test_node == undefined then
(
    geometry_diagnostics_test_node = undefined
)


/*
Returns the stored paint-backup index for one node.
Returns 0 when no paint session is stored for the node.
*/
function getGeometryDiagnosticsBackupIndex source_node =
(
    if source_node == undefined then return 0

    for backup_index = 1 to geometry_diagnostics_color_backups.count do
    (
        if geometry_diagnostics_color_backups[backup_index][1] == source_node then
        (
            return backup_index
        )
    )

    0
    -- return
)


/*
Compares two integer arrays without relying on array identity.
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
This backend intentionally does not treat Edit Poly modifier topology as the same domain.
*/
function isGeometryDiagnosticsEditablePolyNode source_node =
(
    if not isValidNode source_node then return false

    classOf source_node.baseObject == Editable_Poly
    -- return
)


/*
Ensures Editable Poly topology is compact before index-sensitive work.
Any stored paint backup is invalidated before dead topology is collapsed.
*/
function ensureGeometryDiagnosticsCleanTopology source_node =
(
    if not isGeometryDiagnosticsEditablePolyNode source_node then return false

    local poly_value = source_node.baseObject
    poly_value.showCage = off

    local dead_flags = polyop.getHasDeadStructs poly_value

    if dead_flags != 0 then
    (
        local backup_index = getGeometryDiagnosticsBackupIndex source_node

        if backup_index > 0 then
        (
            deleteItem geometry_diagnostics_color_backups backup_index
            format "Geometry Diagnostics: paint backup invalidated because Editable Poly topology contained dead structures.\n"
        )

        polyop.collapseDeadStructs poly_value
    )

    true
    -- return
)


/*
Converts a MAXScript Color to the Point3 representation used by map channel 0.
The conversion preserves the full channel value without display rounding.
*/
function geometryDiagnosticsColorToMapPoint color_value =
(
    if color_value == undefined then return undefined
    if classOf color_value != Color then return undefined

    [color_value.r / 255.0, color_value.g / 255.0, color_value.b / 255.0]
    -- return
)


/*
Captures geometry topology, channel-0 colors, and viewport display state once per node.
The captured state is used only for exact restoration of a paint session.
*/
function captureGeometryDiagnosticsColorBackup source_node =
(
    if not ensureGeometryDiagnosticsCleanTopology source_node then return false

    if getGeometryDiagnosticsBackupIndex source_node > 0 then return true

    local poly_value = source_node.baseObject
    local vertex_count = polyop.getNumVerts poly_value
    local face_count = polyop.getNumFaces poly_value
    local geometry_faces = #()
    local had_map_support = polyop.getMapSupport poly_value 0
    local map_vert_count = 0
    local map_faces = #()
    local map_colors = #()

    for face_id = 1 to face_count do
    (
        append geometry_faces (polyop.getFaceVerts poly_value face_id)
    )

    if had_map_support then
    (
        map_vert_count = polyop.getNumMapVerts poly_value 0

        for face_id = 1 to face_count do
        (
            append map_faces (polyop.getMapFace poly_value 0 face_id)
        )

        for map_vert_id = 1 to map_vert_count do
        (
            append map_colors (polyop.getMapVert poly_value 0 map_vert_id)
        )
    )

    append geometry_diagnostics_color_backups #(
        source_node,
        had_map_support,
        vertex_count,
        face_count,
        geometry_faces,
        map_vert_count,
        map_faces,
        map_colors,
        source_node.showVertexColors,
        source_node.vertexColorType,
        source_node.vertexColorsShaded
    )

    true
    -- return
)


/*
Makes channel 0 usable for direct Editable Poly painting.
A missing channel is initialized with the native default white vertex-color map.
*/
function prepareGeometryDiagnosticsVertexColorMap source_node =
(
    if not isGeometryDiagnosticsEditablePolyNode source_node then return false

    local poly_value = source_node.baseObject
    local has_map_support = polyop.getMapSupport poly_value 0

    if not has_map_support then
    (
        polyop.setMapSupport poly_value 0 true
        polyop.defaultMapFaces poly_value 0
    )
    else if polyop.getNumMapVerts poly_value 0 < 1 then
    (
        format "Geometry Diagnostics: channel 0 exists but has no map vertices; paint operation aborted.\n"
        return false
    )

    if polyop.getNumMapVerts poly_value 0 < 1 then
    (
        format "Geometry Diagnostics: channel 0 initialization did not create map vertices.\n"
        return false
    )

    true
    -- return
)


/*
Enables pure RGB vertex-color display for one node.
This changes display state only and does not modify geometry topology.
*/
function enableGeometryDiagnosticsVertexColorDisplay source_node =
(
    if not isValidNode source_node then return false

    source_node.showVertexColors = true
    source_node.vertexColorType = #color
    source_node.vertexColorsShaded = true

    true
    -- return
)


/*
Restores the exact channel-0 values and display state captured at paint-session start.
Restoration is refused when geometry or map-face topology no longer matches.
*/
function restoreGeometryDiagnosticsColors source_node =
(
    local backup_index = getGeometryDiagnosticsBackupIndex source_node

    if backup_index == 0 then
    (
        format "Geometry Diagnostics: no stored paint session for the requested node.\n"
        return false
    )

    if not isGeometryDiagnosticsEditablePolyNode source_node then return false

    local backup_data = geometry_diagnostics_color_backups[backup_index]
    local poly_value = source_node.baseObject
    local had_map_support = backup_data[2]
    local saved_vertex_count = backup_data[3]
    local saved_face_count = backup_data[4]
    local saved_geometry_faces = backup_data[5]
    local saved_map_vert_count = backup_data[6]
    local saved_map_faces = backup_data[7]
    local saved_map_colors = backup_data[8]
    local current_vertex_count = polyop.getNumVerts poly_value
    local current_face_count = polyop.getNumFaces poly_value

    if polyop.getHasDeadStructs poly_value != 0 then
    (
        format "Geometry Diagnostics: restore refused because Editable Poly contains dead topology.\n"
        return false
    )

    if current_vertex_count != saved_vertex_count or current_face_count != saved_face_count then
    (
        format "Geometry Diagnostics: restore refused because geometry topology count changed.\n"
        return false
    )

    for face_id = 1 to current_face_count do
    (
        local current_face_verts = polyop.getFaceVerts poly_value face_id

        if not geometryDiagnosticsIntegerArraysMatch current_face_verts saved_geometry_faces[face_id] then
        (
            format "Geometry Diagnostics: restore refused because Editable Poly face topology changed at face %.\n" face_id
            return false
        )
    )

    if had_map_support then
    (
        if not polyop.getMapSupport poly_value 0 then
        (
            format "Geometry Diagnostics: restore refused because original channel 0 no longer exists.\n"
            return false
        )

        if polyop.getNumMapVerts poly_value 0 != saved_map_vert_count then
        (
            format "Geometry Diagnostics: restore refused because channel-0 map-vertex count changed.\n"
            return false
        )

        if polyop.getNumMapFaces poly_value 0 != saved_face_count then
        (
            format "Geometry Diagnostics: restore refused because channel-0 map-face count changed.\n"
            return false
        )

        for face_id = 1 to saved_face_count do
        (
            local current_map_face = polyop.getMapFace poly_value 0 face_id

            if not geometryDiagnosticsIntegerArraysMatch current_map_face saved_map_faces[face_id] then
            (
                format "Geometry Diagnostics: restore refused because channel-0 map topology changed at face %.\n" face_id
                return false
            )
        )

        for map_vert_id = 1 to saved_map_vert_count do
        (
            polyop.setMapVert poly_value 0 map_vert_id saved_map_colors[map_vert_id]
        )
    )
    else
    (
        if polyop.getMapSupport poly_value 0 then
        (
            polyop.setMapSupport poly_value 0 false
        )
    )

    source_node.showVertexColors = backup_data[9]
    source_node.vertexColorType = backup_data[10]
    source_node.vertexColorsShaded = backup_data[11]

    deleteItem geometry_diagnostics_color_backups backup_index
    completeRedraw()

    true
    -- return
)


/*
Begins a reversible channel-0 paint session for one Editable Poly node.
The original state is captured before the backend creates or changes paint data.
*/
function beginGeometryDiagnosticsPaint source_node =
(
    if not captureGeometryDiagnosticsColorBackup source_node then return false

    if not prepareGeometryDiagnosticsVertexColorMap source_node then
    (
        restoreGeometryDiagnosticsColors source_node
        return false
    )

    enableGeometryDiagnosticsVertexColorDisplay source_node
    true
    -- return
)


/*
Writes one color to the requested geometry vertices through the high-level polyop API.
A geometry vertex can fan out to several channel-0 map vertices internally.
*/
function paintGeometryDiagnosticsVertices source_node vertex_ids color_value =
(
    if vertex_ids == undefined then return false
    if geometryDiagnosticsColorToMapPoint color_value == undefined then return false
    if not beginGeometryDiagnosticsPaint source_node then return false

    polyop.setVertColor source_node.baseObject 0 vertex_ids color_value
    completeRedraw()

    true
    -- return
)


/*
Writes one color to every channel-0 map vertex referenced by one polygon face.
Shared map vertices intentionally affect every polygon that references the same map vertex.
*/
function paintGeometryDiagnosticsFaceCorners source_node face_id color_value =
(
    if not ensureGeometryDiagnosticsCleanTopology source_node then return false

    local poly_value = source_node.baseObject
    local face_count = polyop.getNumFaces poly_value
    local map_point = geometryDiagnosticsColorToMapPoint color_value

    if map_point == undefined then return false
    if face_id < 1 or face_id > face_count then return false
    if not beginGeometryDiagnosticsPaint source_node then return false

    local map_face_ids = polyop.getMapFace poly_value 0 face_id

    for map_vert_id in map_face_ids do
    (
        polyop.setMapVert poly_value 0 map_vert_id map_point
    )

    completeRedraw()

    true
    -- return
)


/*
Creates fully face-split channel-0 topology on a generated test object.
This helper is destructive by design and must not be used on arbitrary user geometry.
*/
function buildGeometryDiagnosticsTestColorMap source_node =
(
    if not ensureGeometryDiagnosticsCleanTopology source_node then return false

    local poly_value = source_node.baseObject
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

    enableGeometryDiagnosticsVertexColorDisplay source_node
    true
    -- return
)


/*
Creates the first Geometry Diagnostics test object.
The result is an 8-vertex / 6-polygon Editable Poly box with 24 split color-map vertices.
*/
function createGeometryDiagnosticsTestBox =
(
    local created_node = undefined

    undo "Geometry Diagnostics - Create Test Box" on
    (
        created_node = box name:(uniqueName "GeometryDiagnostics_TestBox") length:100.0 width:100.0 height:100.0 lengthsegs:1 widthsegs:1 heightsegs:1

        convertTo created_node Editable_Poly
        created_node.baseObject.showCage = off

        if not buildGeometryDiagnosticsTestColorMap created_node then
        (
            delete created_node
            created_node = undefined
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
Applies six distinct polygon colors to the first test box.
The paint session remains active so RESTORE COLORS can recover the original white map.
*/
function paintGeometryDiagnosticsTestBox source_node =
(
    if not ensureGeometryDiagnosticsCleanTopology source_node then return false

    local poly_value = source_node.baseObject
    local face_count = polyop.getNumFaces poly_value
    local face_colors = #(
        (color 255 0 0),
        (color 0 255 0),
        (color 0 0 255),
        (color 255 255 0),
        (color 0 255 255),
        (color 255 0 255)
    )

    if face_count != face_colors.count then
    (
        format "Geometry Diagnostics: six-color test requires exactly 6 polygon faces; found %.\n" face_count
        return false
    )

    if not beginGeometryDiagnosticsPaint source_node then return false

    undo "Geometry Diagnostics - Paint Face Colors" on
    (
        for face_id = 1 to face_count do
        (
            local map_face_ids = polyop.getMapFace poly_value 0 face_id
            local map_point = geometryDiagnosticsColorToMapPoint face_colors[face_id]

            for map_vert_id in map_face_ids do
            (
                polyop.setMapVert poly_value 0 map_vert_id map_point
            )
        )
    )

    enableGeometryDiagnosticsVertexColorDisplay source_node
    completeRedraw()

    true
    -- return
)


/*
Returns the currently tracked test node, or one selected Editable Poly node as fallback.
Returns undefined when no valid backend target is available.
*/
function getGeometryDiagnosticsTargetNode =
(
    if isGeometryDiagnosticsEditablePolyNode geometry_diagnostics_test_node then
    (
        return geometry_diagnostics_test_node
    )

    if selection.count == 1 then
    (
        if isGeometryDiagnosticsEditablePolyNode selection[1] then
        (
            return selection[1]
        )
    )

    undefined
    -- return
)


/*
Prints current geometry and channel-0 mapping data to the Listener.
The dump uses Editable Poly face IDs and never exposes TriMesh triangle IDs.
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
