/*
Vertex Color Painter reusable EPoly paint operation.
Binds one instance to one node and one topology level, caches topology, and paints channel 0 directly or through PaintLayerMod.
*/

global vertex_color_painter_file_version = "0.01"
global VertexColorPainter


struct VertexColorPainter_v
(
    source_node = undefined,
    stack_index = -1,
    map_channel = 0,
    backend_type = #none,
    target_stack_mod = undefined,
    paint_layer_mod = undefined,
    paint_layer_name = "VERTEX COLOR PAINTER",

    evaluated_mesh = undefined,
    vertex_count = 0,
    edge_count = 0,
    face_count = 0,
    face_vertices = #(),
    face_edges = #(),
    edge_vertices = #(),
    edge_faces = #(),
    vertex_faces = #(),

    face_map_vertices = #(),
    geo_to_map_vertices = #(),

    cache_valid = false,
    topology_dirty = true,

    paint_active = false,
    paint_state = undefined,

    display_backup_valid = false,
    display_show_vertex_colors = false,
    display_vertex_color_type = undefined,
    display_vertex_colors_shaded = false,

    base_backup_valid = false,
    base_backup_had_map_support = false,
    base_backup_vertex_count = 0,
    base_backup_face_count = 0,
    base_backup_face_vertices = #(),
    base_backup_map_vert_count = 0,
    base_backup_map_faces = #(),
    base_backup_map_colors = #(),


    /*
    Compares two integer arrays by value.
    Returns true only when count and every indexed value match.
    */
    function integerArraysMatch values_a values_b =
    (
        if values_a == undefined or values_b == undefined then return false
        if values_a.count != values_b.count then return false

        for value_index = 1 to values_a.count do
        (
            if values_a[value_index] != values_b[value_index] then return false
        )

        true
        -- return
    ),


    /*
    Converts a MAXScript Color to the Point3 representation used by direct map-channel storage.
    Returns undefined when the supplied value is not a Color.
    */
    function colorToMapPoint color_value =
    (
        if color_value == undefined then return undefined
        if classOf color_value != Color then return undefined

        [color_value.r / 255.0, color_value.g / 255.0, color_value.b / 255.0]
        -- return
    ),


    /*
    Converts a MAXScript Color to the normalized Point4 required by VertexPaintState.
    Alpha is always 1.0 so diagnostic paint fully affects the requested entries.
    */
    function colorToPaintPoint4 color_value =
    (
        if color_value == undefined then return undefined
        if classOf color_value != Color then return undefined

        [color_value.r / 255.0, color_value.g / 255.0, color_value.b / 255.0, 1.0]
        -- return
    ),


    /*
    Clears topology-cache data owned by this instance.
    The bound target itself is preserved.
    */
    function resetCache =
    (
        if evaluated_mesh != undefined then
        (
            delete evaluated_mesh
        )

        evaluated_mesh = undefined
        vertex_count = 0
        edge_count = 0
        face_count = 0
        face_vertices = #()
        face_edges = #()
        edge_vertices = #()
        edge_faces = #()
        vertex_faces = #()
        face_map_vertices = #()
        geo_to_map_vertices = #()
        cache_valid = false

        true
        -- return
    ),


    /*
    Marks cached topology as stale without changing the target or current paint data.
    Call refresh() before using component IDs again.
    */
    function invalidate =
    (
        topology_dirty = true
        cache_valid = false

        true
        -- return
    ),


    /*
    Finds the current modifier-stack index of the stored target modifier reference.
    Returns 0 for the base-object target and -1 when the stored modifier is no longer present.
    */
    function getCurrentTargetStackIndex =
    (
        if not isValidNode source_node then return -1
        if stack_index == 0 then return 0
        if target_stack_mod == undefined then return -1

        for mod_index = 1 to source_node.modifiers.count do
        (
            if source_node.modifiers[mod_index] == target_stack_mod then
            (
                return mod_index
            )
        )

        -1
        -- return
    ),


    /*
    Finds the current stack index of the tool-owned PaintLayerMod reference.
    Returns 0 when no owned paint layer is present on the bound node.
    */
    function getPaintLayerStackIndex =
    (
        if not isValidNode source_node then return 0
        if paint_layer_mod == undefined then return 0

        for mod_index = 1 to source_node.modifiers.count do
        (
            if source_node.modifiers[mod_index] == paint_layer_mod then
            (
                return mod_index
            )
        )

        0
        -- return
    ),


    /*
    Returns the tool-owned PaintLayerMod when it is still present on the bound node.
    Falls back to the exact reserved layer name so a reloaded module can recover its own layer.
    */
    function getPaintLayerMod =
    (
        if not isValidNode source_node then return undefined

        local paint_index = getPaintLayerStackIndex()

        if paint_index > 0 then return paint_layer_mod

        for stack_mod in source_node.modifiers do
        (
            if classOf stack_mod == PaintLayerMod and stack_mod.name == paint_layer_name then
            (
                paint_layer_mod = stack_mod
                return paint_layer_mod
            )
        )

        undefined
        -- return
    ),


    /*
    Captures the node's viewport vertex-color display state once for the current paint session.
    The saved state is restored by clear().
    */
    function captureDisplayState =
    (
        if not isValidNode source_node then return false
        if display_backup_valid then return true

        display_show_vertex_colors = source_node.showVertexColors
        display_vertex_color_type = source_node.vertexColorType
        display_vertex_colors_shaded = source_node.vertexColorsShaded
        display_backup_valid = true

        true
        -- return
    ),


    /*
    Enables RGB vertex-color display on the bound node.
    This changes viewport display state only.
    */
    function enableDisplay =
    (
        if not isValidNode source_node then return false

        source_node.showVertexColors = true
        source_node.vertexColorType = #color
        source_node.vertexColorsShaded = true

        true
        -- return
    ),


    /*
    Restores the display state captured before the current paint session.
    Returns true when no display backup exists or restoration succeeds.
    */
    function restoreDisplayState =
    (
        if not display_backup_valid then return true
        if not isValidNode source_node then return false

        source_node.showVertexColors = display_show_vertex_colors
        source_node.vertexColorType = display_vertex_color_type
        source_node.vertexColorsShaded = display_vertex_colors_shaded
        display_backup_valid = false

        true
        -- return
    ),


    /*
    Validates and compacts dead topology for a base Editable Poly target.
    Dead topology is never collapsed underneath an existing modifier stack.
    */
    function ensureBaseTopologySafe =
    (
        if not isValidNode source_node then return false
        if classOf source_node.baseObject != Editable_Poly then return false

        local poly_value = source_node.baseObject
        local dead_flags = polyop.getHasDeadStructs poly_value

        if dead_flags != 0 then
        (
            if source_node.modifiers.count > 0 then
            (
                format "VertexColorPainter: base Editable Poly contains dead topology below an active modifier stack; refresh refused.\n"
                return false
            )

            polyop.collapseDeadStructs poly_value
        )

        true
        -- return
    ),


    /*
    Builds one temporary TriMesh snapshot evaluated exactly through the bound target level.
    Modifier layers above the target are removed only from a temporary copied node.
    */
    function buildTargetSnapshot =
    (
        if not isValidNode source_node then return undefined

        local current_target_index = getCurrentTargetStackIndex()

        if current_target_index < 0 then return undefined

        local temp_node = undefined
        local snapshot_mesh = undefined
        local operation_failed = false
        local exception_text = ""

        try
        (
            with redraw off
            with undo off
            (
                temp_node = copy source_node
                temp_node.name = uniqueName "VertexColorPainter_Snapshot"

                if current_target_index == 0 then
                (
                    for mod_index = temp_node.modifiers.count to 1 by -1 do
                    (
                        deleteModifier temp_node mod_index
                    )
                )
                else
                (
                    for mod_index = (current_target_index - 1) to 1 by -1 do
                    (
                        deleteModifier temp_node mod_index
                    )
                )

                snapshot_mesh = snapshotAsMesh temp_node
                delete temp_node
                temp_node = undefined
            )
        )
        catch
        (
            exception_text = getCurrentException()
            operation_failed = true
        )

        if operation_failed then
        (
            if isValidNode temp_node then
            (
                delete temp_node
            )

            format "VertexColorPainter buildTargetSnapshot ERROR: %\n" exception_text
            return undefined
        )

        snapshot_mesh
        -- return
    ),


    /*
    Initializes vertex-to-face adjacency arrays from the cached polygon face-vertex data.
    Returns false when a cached face references an invalid vertex ID.
    */
    function buildVertexFaceCache =
    (
        vertex_faces = #()

        for vertex_id = 1 to vertex_count do
        (
            append vertex_faces #()
        )

        for face_id = 1 to face_count do
        (
            local geometry_face_ids = face_vertices[face_id]

            for vertex_id in geometry_face_ids do
            (
                if vertex_id < 1 or vertex_id > vertex_count then
                (
                    format "VertexColorPainter: face % references invalid vertex %.\n" face_id vertex_id
                    return false
                )

                if findItem vertex_faces[vertex_id] face_id == 0 then
                (
                    append vertex_faces[vertex_id] face_id
                )
            )
        )

        true
        -- return
    ),


    /*
    Builds geometry, edge, and face caches from an Editable Poly base object.
    Map-channel cache is built separately because channel 0 can be created lazily at paint start.
    */
    function buildBaseTopologyCache =
    (
        if not ensureBaseTopologySafe() then return false

        local poly_value = source_node.baseObject

        vertex_count = polyop.getNumVerts poly_value
        edge_count = polyop.getNumEdges poly_value
        face_count = polyop.getNumFaces poly_value

        face_vertices = #()
        face_edges = #()
        edge_vertices = #()
        edge_faces = #()

        for face_id = 1 to face_count do
        (
            append face_vertices (polyop.getFaceVerts poly_value face_id)
            append face_edges (polyop.getFaceEdges poly_value face_id)
        )

        for edge_id = 1 to edge_count do
        (
            local current_edge_vertices = polyop.getEdgeVerts poly_value edge_id
            local current_edge_faces = #()
            local edge_face_bits = polyop.getEdgeFaces poly_value edge_id

            for face_id in edge_face_bits do
            (
                append current_edge_faces face_id
            )

            append edge_vertices current_edge_vertices
            append edge_faces current_edge_faces
        )

        buildVertexFaceCache()
        -- return
    ),


    /*
    Builds geometry, edge, and face caches directly from the bound Edit Poly modifier.
    The cached IDs are the same public polygon/edge/vertex domain used by callers.
    */
    function buildEditPolyTopologyCache =
    (
        if not isValidNode source_node then return false
        if target_stack_mod == undefined then return false
        if classOf target_stack_mod != Edit_Poly then return false

        target_stack_mod.SetPrimaryNode source_node

        vertex_count = target_stack_mod.GetNumVertices node:source_node
        edge_count = target_stack_mod.GetNumEdges node:source_node
        face_count = target_stack_mod.GetNumFaces node:source_node

        if vertex_count < 1 or face_count < 1 then
        (
            format "VertexColorPainter: target Edit Poly returned unusable topology counts.\n"
            return false
        )

        face_vertices = #()
        face_edges = #()
        edge_vertices = #()
        edge_faces = #()

        for face_id = 1 to face_count do
        (
            local face_degree = target_stack_mod.GetFaceDegree face_id node:source_node
            local geometry_face_ids = #()

            if face_degree < 3 then
            (
                format "VertexColorPainter: target Edit Poly face % has invalid degree %.\n" face_id face_degree
                return false
            )

            for corner_id = 1 to face_degree do
            (
                append geometry_face_ids (target_stack_mod.GetFaceVertex face_id corner_id node:source_node)
            )

            append face_vertices geometry_face_ids
            append face_edges #()
        )

        for edge_id = 1 to edge_count do
        (
            local vertex_a = target_stack_mod.GetEdgeVertex edge_id 1 node:source_node
            local vertex_b = target_stack_mod.GetEdgeVertex edge_id 2 node:source_node
            local face_a = target_stack_mod.GetEdgeFace edge_id 1 node:source_node
            local face_b = target_stack_mod.GetEdgeFace edge_id 2 node:source_node
            local current_edge_faces = #()

            if vertex_a < 1 or vertex_a > vertex_count or vertex_b < 1 or vertex_b > vertex_count then
            (
                format "VertexColorPainter: target Edit Poly edge % references invalid vertices.\n" edge_id
                return false
            )

            append edge_vertices #(vertex_a, vertex_b)

            if face_a != undefined and face_a > 0 then
            (
                if face_a > face_count then
                (
                    format "VertexColorPainter: target Edit Poly edge % references invalid face %.\n" edge_id face_a
                    return false
                )

                append current_edge_faces face_a
            )

            if face_b != undefined and face_b > 0 and face_b != face_a then
            (
                if face_b > face_count then
                (
                    format "VertexColorPainter: target Edit Poly edge % references invalid face %.\n" edge_id face_b
                    return false
                )

                append current_edge_faces face_b
            )

            append edge_faces current_edge_faces

            for adjacent_face_id in current_edge_faces do
            (
                append face_edges[adjacent_face_id] edge_id
            )
        )

        buildVertexFaceCache()
        -- return
    ),


    /*
    Builds direct map-channel face and geometry-vertex lookup caches for the base backend.
    Returns false when map topology cannot be paired safely with polygon corners.
    */
    function buildBaseMapCache =
    (
        face_map_vertices = #()
        geo_to_map_vertices = #()

        if backend_type != #baseObject then return false
        if not isValidNode source_node then return false

        local poly_value = source_node.baseObject

        if not polyop.getMapSupport poly_value map_channel then return false

        local map_face_count = polyop.getNumMapFaces poly_value map_channel

        if map_face_count != face_count then
        (
            format "VertexColorPainter: map-face count does not match polygon face count.\n"
            return false
        )

        for vertex_id = 1 to vertex_count do
        (
            append geo_to_map_vertices #()
        )

        for face_id = 1 to face_count do
        (
            local geometry_face_ids = face_vertices[face_id]
            local map_face_ids = polyop.getMapFace poly_value map_channel face_id

            if map_face_ids == undefined or geometry_face_ids.count != map_face_ids.count then
            (
                format "VertexColorPainter: geometry/map corner count mismatch at face %.\n" face_id
                return false
            )

            append face_map_vertices map_face_ids

            for corner_id = 1 to geometry_face_ids.count do
            (
                local vertex_id = geometry_face_ids[corner_id]
                local map_vert_id = map_face_ids[corner_id]

                if findItem geo_to_map_vertices[vertex_id] map_vert_id == 0 then
                (
                    append geo_to_map_vertices[vertex_id] map_vert_id
                )
            )
        )

        true
        -- return
    ),


    /*
    Returns true while the stored node and target topology still satisfy the cached target contract.
    Call invalidate() after topology edits because equal counts alone cannot detect every topology change.
    */
    function isTargetValid =
    (
        if not isValidNode source_node then return false
        if stack_index < 0 then return false

        if stack_index == 0 then
        (
            if classOf source_node.baseObject != Editable_Poly then return false

            if cache_valid then
            (
                local poly_value = source_node.baseObject

                if polyop.getNumVerts poly_value != vertex_count then return false
                if polyop.getNumEdges poly_value != edge_count then return false
                if polyop.getNumFaces poly_value != face_count then return false
            )

            return true
        )

        if target_stack_mod == undefined then return false
        if classOf target_stack_mod != Edit_Poly then return false
        if getCurrentTargetStackIndex() < 1 then return false

        if cache_valid then
        (
            if target_stack_mod.GetNumVertices node:source_node != vertex_count then return false
            if target_stack_mod.GetNumEdges node:source_node != edge_count then return false
            if target_stack_mod.GetNumFaces node:source_node != face_count then return false
        )

        true
        -- return
    ),


    /*
    Rebuilds the complete cached topology for the currently bound node and stack level.
    The modifier backend requires an Edit Poly target so public IDs remain polygon/edge/vertex IDs.
    */
    function refresh =
    (
        if not isValidNode source_node then return false
        if stack_index < 0 then return false

        resetCache()

        local topology_result = false

        if stack_index == 0 then
        (
            backend_type = #baseObject
            topology_result = buildBaseTopologyCache()
        )
        else
        (
            backend_type = #vertexPaint
            topology_result = buildEditPolyTopologyCache()
        )

        if not topology_result then
        (
            topology_dirty = true
            return false
        )

        evaluated_mesh = buildTargetSnapshot()

        if evaluated_mesh == undefined then
        (
            topology_dirty = true
            return false
        )

        local snapshot_vertex_count = getNumVerts evaluated_mesh

        if snapshot_vertex_count != vertex_count then
        (
            format "VertexColorPainter: evaluated snapshot vertex count % does not match target topology vertex count %.\n" snapshot_vertex_count vertex_count
            delete evaluated_mesh
            evaluated_mesh = undefined
            topology_dirty = true
            return false
        )

        if backend_type == #baseObject then
        (
            local poly_value = source_node.baseObject

            if polyop.getMapSupport poly_value map_channel then
            (
                if not buildBaseMapCache() then
                (
                    topology_dirty = true
                    return false
                )
            )
        )

        cache_valid = true
        topology_dirty = false

        true
        -- return
    ),


    /*
    Binds the instance to one node and one topology level.
    Stack index 0 means the Editable Poly base; positive indices must identify an Edit Poly modifier.
    */
    function setTarget target_node target_stack_index =
    (
        if not isValidNode target_node then return false
        if classOf target_stack_index != Integer then return false
        if target_stack_index < 0 then return false
        if target_stack_index > target_node.modifiers.count then return false

        local same_target = false

        if source_node == target_node and stack_index == target_stack_index then
        (
            if target_stack_index == 0 then
            (
                same_target = true
            )
            else if target_stack_mod != undefined and getCurrentTargetStackIndex() > 0 then
            (
                same_target = true
            )
        )

        if same_target then
        (
            if cache_valid and not topology_dirty then return true
            return refresh()
        )

        if source_node != undefined then
        (
            if not clear() then
            (
                format "VertexColorPainter: previous paint session could not be cleared; target change refused.\n"
                return false
            )
        )

        resetCache()

        source_node = target_node
        stack_index = target_stack_index
        target_stack_mod = undefined
        paint_layer_mod = undefined
        backend_type = #none

        if target_stack_index == 0 then
        (
            if classOf source_node.baseObject != Editable_Poly then
            (
                format "VertexColorPainter: stack index 0 requires an Editable Poly base object.\n"
                return false
            )

            backend_type = #baseObject
        )
        else
        (
            target_stack_mod = source_node.modifiers[target_stack_index]

            if target_stack_mod == undefined or classOf target_stack_mod != Edit_Poly then
            (
                format "VertexColorPainter: positive stack indices currently require an Edit Poly modifier target.\n"
                target_stack_mod = undefined
                return false
            )

            backend_type = #vertexPaint
        )

        refresh()
        -- return
    ),


    /*
    Captures the original base map-channel state before the first direct paint write.
    The backup is kept until clear() restores it successfully.
    */
    function captureBaseBackup =
    (
        if backend_type != #baseObject then return false
        if base_backup_valid then return true
        if not cache_valid then return false

        local poly_value = source_node.baseObject

        base_backup_had_map_support = polyop.getMapSupport poly_value map_channel
        base_backup_vertex_count = vertex_count
        base_backup_face_count = face_count
        base_backup_face_vertices = #()
        base_backup_map_vert_count = 0
        base_backup_map_faces = #()
        base_backup_map_colors = #()

        for face_id = 1 to face_count do
        (
            local copied_face_vertices = #()

            for vertex_id in face_vertices[face_id] do
            (
                append copied_face_vertices vertex_id
            )

            append base_backup_face_vertices copied_face_vertices
        )

        if base_backup_had_map_support then
        (
            base_backup_map_vert_count = polyop.getNumMapVerts poly_value map_channel

            for face_id = 1 to face_count do
            (
                local current_map_face = polyop.getMapFace poly_value map_channel face_id
                local copied_map_face = #()

                for map_vert_id in current_map_face do
                (
                    append copied_map_face map_vert_id
                )

                append base_backup_map_faces copied_map_face
            )

            for map_vert_id = 1 to base_backup_map_vert_count do
            (
                append base_backup_map_colors (polyop.getMapVert poly_value map_channel map_vert_id)
            )
        )

        base_backup_valid = true

        true
        -- return
    ),


    /*
    Ensures the direct base-object map channel exists and rebuilds its corner lookup cache.
    A missing map channel is initialized with native default map faces.
    */
    function prepareBaseMap =
    (
        if backend_type != #baseObject then return false
        if not isTargetValid() then return false

        local poly_value = source_node.baseObject

        if not polyop.getMapSupport poly_value map_channel then
        (
            polyop.setMapSupport poly_value map_channel true
            polyop.defaultMapFaces poly_value map_channel
        )

        if polyop.getNumMapVerts poly_value map_channel < 1 then
        (
            format "VertexColorPainter: map channel initialization produced no map vertices.\n"
            return false
        )

        buildBaseMapCache()
        -- return
    ),


    /*
    Creates or reuses the tool-owned PaintLayerMod immediately above the bound Edit Poly target.
    Existing unrelated VertexPaint modifiers are never reused or deleted.
    */
    function ensurePaintLayer =
    (
        if backend_type != #vertexPaint then return undefined
        if not isTargetValid() then return undefined

        local current_target_index = getCurrentTargetStackIndex()

        if current_target_index < 1 then return undefined

        local existing_paint_layer = getPaintLayerMod()

        if existing_paint_layer != undefined then
        (
            local existing_paint_index = getPaintLayerStackIndex()
            local updated_target_index = getCurrentTargetStackIndex()

            if existing_paint_index > 0 and updated_target_index == (existing_paint_index + 1) then
            (
                return existing_paint_layer
            )

            format "VertexColorPainter: owned paint layer is no longer immediately above the target Edit Poly; clear and refresh are required.\n"
            return undefined
        )

        local new_paint_layer = PaintLayerMod()
        new_paint_layer.name = paint_layer_name
        new_paint_layer.mapChannel = map_channel
        new_paint_layer.layerMode = "Normal"
        new_paint_layer.layerOpacity = 100.0
        new_paint_layer.layerIsolated = true

        undo "Vertex Color Painter - Add Paint Layer" on
        (
            addModifier source_node new_paint_layer before:current_target_index
        )

        paint_layer_mod = new_paint_layer

        local paint_index = getPaintLayerStackIndex()
        local new_target_index = getCurrentTargetStackIndex()

        if paint_index < 1 or new_target_index != (paint_index + 1) then
        (
            format "VertexColorPainter: PaintLayerMod was not inserted immediately above the target Edit Poly.\n"
            paint_layer_mod = undefined
            return undefined
        )

        paint_layer_mod
        -- return
    ),


    /*
    Applies the cached VertexPaintState while temporarily disabling active sub-object masking.
    Returns false when ApplyPaintState raises an exception.
    */
    function applyPaintState =
    (
        if backend_type != #vertexPaint then return false
        if paint_layer_mod == undefined or paint_state == undefined then return false
        if classOf paint_layer_mod != PaintLayerMod then return false

        local restore_subobject_level = undefined
        local apply_succeeded = true
        local exception_text = ""

        if findItem (selection as array) source_node > 0 then
        (
            if subObjectLevel != undefined and subObjectLevel > 0 then
            (
                restore_subobject_level = subObjectLevel
                subObjectLevel = 0
            )
        )

        try
        (
            paint_layer_mod.ApplyPaintState source_node paint_state
        )
        catch
        (
            exception_text = getCurrentException()
            apply_succeeded = false
        )

        if restore_subobject_level != undefined then
        (
            subObjectLevel = restore_subobject_level
        )

        if not apply_succeeded then
        (
            format "VertexColorPainter ApplyPaintState ERROR: %\n" exception_text
            return false
        )

        true
        -- return
    ),


    /*
    Begins a paint transaction for the current cached target.
    Modifier paint acquires one VertexPaintState that remains cached until endPaint().
    */
    function beginPaint =
    (
        if paint_active then return true
        if not cache_valid or topology_dirty then return false
        if not isTargetValid() then return false
        if not captureDisplayState() then return false

        if backend_type == #baseObject then
        (
            if not captureBaseBackup() then return false

            if not prepareBaseMap() then
            (
                return false
            )

            paint_active = true
        )
        else if backend_type == #vertexPaint then
        (
            local current_paint_layer = ensurePaintLayer()

            if current_paint_layer == undefined then return false

            completeRedraw()
            paint_state = current_paint_layer.AcquirePaintState source_node

            if paint_state == undefined then
            (
                format "VertexColorPainter: VertexPaint state acquisition failed.\n"
                return false
            )

            paint_active = true
        )
        else
        (
            return false
        )

        enableDisplay()
        true
        -- return
    ),


    /*
    Ends the current paint transaction and commits cached VertexPaintState once.
    Direct base painting is already written and only requires one final redraw.
    */
    function endPaint =
    (
        if not paint_active then return true

        local result_value = true

        if backend_type == #vertexPaint then
        (
            result_value = applyPaintState()

            if paint_layer_mod != undefined and paint_state != undefined then
            (
                paint_layer_mod.ReleasePaintState source_node paint_state
            )

            paint_state = undefined
        )

        paint_active = false

        if result_value then
        (
            enableDisplay()
            completeRedraw()
        )

        result_value
        -- return
    ),


    /*
    Returns true when one polygon face contains the supplied geometry vertex.
    This validates the public face-corner contract before any paint transaction starts.
    */
    function faceContainsVertex geo_vertex_id face_id =
    (
        if not cache_valid then return false
        if face_id < 1 or face_id > face_count then return false
        if geo_vertex_id < 1 or geo_vertex_id > vertex_count then return false

        findItem face_vertices[face_id] geo_vertex_id > 0
        -- return
    ),


    /*
    Resolves one base-object face corner to its exact map-vertex ID.
    Returns 0 when the target is not the direct base backend or the corner is invalid.
    */
    function getMapVertexForCorner geo_vertex_id face_id =
    (
        if backend_type != #baseObject then return 0
        if not cache_valid then return 0
        if face_id < 1 or face_id > face_count then return 0
        if face_map_vertices.count != face_count then return 0

        local corner_index = findItem face_vertices[face_id] geo_vertex_id

        if corner_index == 0 then return 0

        face_map_vertices[face_id][corner_index]
        -- return
    ),


    /*
    Paints one exact polygon face corner.
    The direct backend writes one map vertex; the modifier backend writes one VertexPaint face-vertex entry.
    */
    function paintCorner geo_vertex_id face_id color_value =
    (
        if not faceContainsVertex geo_vertex_id face_id then return false

        local map_point = colorToMapPoint color_value
        local paint_point = colorToPaintPoint4 color_value

        if map_point == undefined or paint_point == undefined then return false

        local auto_transaction = not paint_active

        if auto_transaction then
        (
            if not beginPaint() then return false
        )

        local result_value = true

        if backend_type == #baseObject then
        (
            local map_vert_id = getMapVertexForCorner geo_vertex_id face_id

            if map_vert_id < 1 then
            (
                result_value = false
            )
            else
            (
                polyop.setMapVert source_node.baseObject map_channel map_vert_id map_point
            )
        )
        else if backend_type == #vertexPaint then
        (
            paint_state.SetFaceVertColor face_id geo_vertex_id paint_point
        )
        else
        (
            result_value = false
        )

        if auto_transaction then
        (
            local end_result = endPaint()
            result_value = result_value and end_result
        )

        result_value
        -- return
    ),


    /*
    Paints every face-corner representation of one geometry vertex.
    The modifier backend uses VertexPaintState.SetVertColor on the bound evaluated topology.
    */
    function paintVertex geo_vertex_id color_value =
    (
        if not cache_valid then return false
        if geo_vertex_id < 1 or geo_vertex_id > vertex_count then return false

        local map_point = colorToMapPoint color_value
        local paint_point = colorToPaintPoint4 color_value

        if map_point == undefined or paint_point == undefined then return false

        local auto_transaction = not paint_active

        if auto_transaction then
        (
            if not beginPaint() then return false
        )

        local result_value = true

        if backend_type == #baseObject then
        (
            if geo_to_map_vertices.count != vertex_count then
            (
                result_value = false
            )
            else
            (
                for map_vert_id in geo_to_map_vertices[geo_vertex_id] do
                (
                    polyop.setMapVert source_node.baseObject map_channel map_vert_id map_point
                )
            )
        )
        else if backend_type == #vertexPaint then
        (
            paint_state.SetVertColor geo_vertex_id paint_point
        )
        else
        (
            result_value = false
        )

        if auto_transaction then
        (
            local end_result = endPaint()
            result_value = result_value and end_result
        )

        result_value
        -- return
    ),


    /*
    Paints an Integer, BitArray, or Array collection of geometry vertices in one transaction.
    All IDs are validated before any write occurs.
    */
    function paintVertices vertex_ids color_value =
    (
        if not cache_valid then return false
        if vertex_ids == undefined then return false

        local target_class = classOf vertex_ids
        local resolved_vertex_ids = #()

        if target_class == Integer then
        (
            append resolved_vertex_ids vertex_ids
        )
        else if target_class == BitArray then
        (
            for vertex_id in vertex_ids do
            (
                append resolved_vertex_ids vertex_id
            )
        )
        else if target_class == Array then
        (
            for vertex_id in vertex_ids do
            (
                append resolved_vertex_ids vertex_id
            )
        )
        else
        (
            return false
        )

        if resolved_vertex_ids.count == 0 then return false

        for vertex_id in resolved_vertex_ids do
        (
            if classOf vertex_id != Integer then return false
            if vertex_id < 1 or vertex_id > vertex_count then return false
        )

        local auto_transaction = not paint_active

        if auto_transaction then
        (
            if not beginPaint() then return false
        )

        local result_value = true

        for vertex_id in resolved_vertex_ids while result_value do
        (
            result_value = paintVertex vertex_id color_value
        )

        if auto_transaction then
        (
            local end_result = endPaint()
            result_value = result_value and end_result
        )

        result_value
        -- return
    ),


    /*
    Paints all corners of one Editable Poly polygon face.
    The public face ID always belongs to the topology cached by setTarget().
    */
    function paintFace face_id color_value =
    (
        if not cache_valid then return false
        if face_id < 1 or face_id > face_count then return false

        local map_point = colorToMapPoint color_value
        local paint_point = colorToPaintPoint4 color_value

        if map_point == undefined or paint_point == undefined then return false

        local auto_transaction = not paint_active

        if auto_transaction then
        (
            if not beginPaint() then return false
        )

        local result_value = true

        if backend_type == #baseObject then
        (
            if face_map_vertices.count != face_count then
            (
                result_value = false
            )
            else
            (
                for map_vert_id in face_map_vertices[face_id] do
                (
                    polyop.setMapVert source_node.baseObject map_channel map_vert_id map_point
                )
            )
        )
        else if backend_type == #vertexPaint then
        (
            paint_state.SetFaceColor face_id paint_point
        )
        else
        (
            result_value = false
        )

        if auto_transaction then
        (
            local end_result = endPaint()
            result_value = result_value and end_result
        )

        result_value
        -- return
    ),


    /*
    Paints both geometry vertices of one edge on every adjacent Editable Poly polygon face.
    This preserves per-face corner separation at hard color seams.
    */
    function paintEdge edge_id color_value =
    (
        if not cache_valid then return false
        if edge_id < 1 or edge_id > edge_count then return false

        local current_edge_vertices = edge_vertices[edge_id]
        local current_edge_faces = edge_faces[edge_id]

        if current_edge_vertices == undefined or current_edge_vertices.count != 2 then return false
        if current_edge_faces == undefined or current_edge_faces.count == 0 then return false

        for face_id in current_edge_faces do
        (
            for vertex_id in current_edge_vertices do
            (
                if not faceContainsVertex vertex_id face_id then return false
            )
        )

        local auto_transaction = not paint_active

        if auto_transaction then
        (
            if not beginPaint() then return false
        )

        local result_value = true

        for face_id in current_edge_faces while result_value do
        (
            for vertex_id in current_edge_vertices while result_value do
            (
                result_value = paintCorner vertex_id face_id color_value
            )
        )

        if auto_transaction then
        (
            local end_result = endPaint()
            result_value = result_value and end_result
        )

        result_value
        -- return
    ),


    /*
    Paints an array of exact corner requests in one transaction.
    Each row must be #(geo_vertex_id, face_id, color_value).
    */
    function paintCorners paint_data =
    (
        if not cache_valid then return false
        if paint_data == undefined or classOf paint_data != Array then return false
        if paint_data.count == 0 then return false

        for paint_item in paint_data do
        (
            if paint_item == undefined or classOf paint_item != Array then return false
            if paint_item.count != 3 then return false
            if classOf paint_item[1] != Integer then return false
            if classOf paint_item[2] != Integer then return false
            if classOf paint_item[3] != Color then return false

            if not faceContainsVertex paint_item[1] paint_item[2] then return false
        )

        local auto_transaction = not paint_active

        if auto_transaction then
        (
            if not beginPaint() then return false
        )

        local result_value = true

        for paint_item in paint_data while result_value do
        (
            result_value = paintCorner paint_item[1] paint_item[2] paint_item[3]
        )

        if auto_transaction then
        (
            local end_result = endPaint()
            result_value = result_value and end_result
        )

        result_value
        -- return
    ),


    /*
    Restores the exact direct map-channel state captured before base-object painting.
    Restoration is refused when geometry or map topology no longer matches the backup.
    */
    function restoreBasePaint =
    (
        if not base_backup_valid then return true
        if backend_type != #baseObject then return false
        if not isValidNode source_node then return false
        if classOf source_node.baseObject != Editable_Poly then return false

        local poly_value = source_node.baseObject
        local current_vertex_count = polyop.getNumVerts poly_value
        local current_face_count = polyop.getNumFaces poly_value

        if current_vertex_count != base_backup_vertex_count or current_face_count != base_backup_face_count then
        (
            format "VertexColorPainter: base restore refused because geometry topology counts changed.\n"
            return false
        )

        for face_id = 1 to current_face_count do
        (
            local current_face_vertices = polyop.getFaceVerts poly_value face_id

            if not integerArraysMatch current_face_vertices base_backup_face_vertices[face_id] then
            (
                format "VertexColorPainter: base restore refused because polygon topology changed at face %.\n" face_id
                return false
            )
        )

        if base_backup_had_map_support then
        (
            if not polyop.getMapSupport poly_value map_channel then
            (
                format "VertexColorPainter: base restore refused because the original map channel no longer exists.\n"
                return false
            )

            if polyop.getNumMapVerts poly_value map_channel != base_backup_map_vert_count then
            (
                format "VertexColorPainter: base restore refused because map-vertex count changed.\n"
                return false
            )

            if polyop.getNumMapFaces poly_value map_channel != base_backup_face_count then
            (
                format "VertexColorPainter: base restore refused because map-face count changed.\n"
                return false
            )

            for face_id = 1 to base_backup_face_count do
            (
                local current_map_face = polyop.getMapFace poly_value map_channel face_id

                if not integerArraysMatch current_map_face base_backup_map_faces[face_id] then
                (
                    format "VertexColorPainter: base restore refused because map topology changed at face %.\n" face_id
                    return false
                )
            )

            for map_vert_id = 1 to base_backup_map_vert_count do
            (
                polyop.setMapVert poly_value map_channel map_vert_id base_backup_map_colors[map_vert_id]
            )
        )
        else
        (
            if polyop.getMapSupport poly_value map_channel then
            (
                polyop.setMapSupport poly_value map_channel false
            )
        )

        base_backup_valid = false
        base_backup_had_map_support = false
        base_backup_vertex_count = 0
        base_backup_face_count = 0
        base_backup_face_vertices = #()
        base_backup_map_vert_count = 0
        base_backup_map_faces = #()
        base_backup_map_colors = #()

        if polyop.getMapSupport poly_value map_channel then
        (
            buildBaseMapCache()
        )
        else
        (
            face_map_vertices = #()
            geo_to_map_vertices = #()
        )

        true
        -- return
    ),


    /*
    Removes only the tool-owned PaintLayerMod from the bound node.
    The target Edit Poly and every unrelated modifier remain untouched.
    */
    function removeModifierPaint =
    (
        if backend_type != #vertexPaint then return false
        if not isValidNode source_node then return false

        local current_paint_layer = getPaintLayerMod()

        if current_paint_layer == undefined then
        (
            paint_layer_mod = undefined
            return true
        )

        local paint_index = getPaintLayerStackIndex()

        if paint_index < 1 then return false

        undo "Vertex Color Painter - Remove Paint Layer" on
        (
            deleteModifier source_node paint_index
        )

        paint_layer_mod = undefined
        getCurrentTargetStackIndex()

        true
        -- return
    ),


    /*
    Clears the current diagnostic paint while preserving the bound target and cached target topology.
    Base paint is restored from backup; modifier paint removes only this instance's owned PaintLayerMod.
    */
    function clear =
    (
        if paint_active then
        (
            if backend_type == #vertexPaint and paint_layer_mod != undefined and paint_state != undefined then
            (
                paint_layer_mod.ReleasePaintState source_node paint_state
            )

            paint_state = undefined
            paint_active = false
        )

        local result_value = true

        if backend_type == #baseObject then
        (
            result_value = restoreBasePaint()
        )
        else if backend_type == #vertexPaint then
        (
            result_value = removeModifierPaint()
        )

        if result_value then
        (
            result_value = restoreDisplayState()
        )

        if result_value then
        (
            completeRedraw()
        )

        result_value
        -- return
    ),


    /*
    Initializes all instance state to an unbound clean session.
    The required create handler keeps every new instance independent and reusable.
    */
    on create do
    (
        source_node = undefined
        stack_index = -1
        map_channel = 0
        backend_type = #none
        target_stack_mod = undefined
        paint_layer_mod = undefined
        evaluated_mesh = undefined
        cache_valid = false
        topology_dirty = true
        paint_active = false
        paint_state = undefined
        display_backup_valid = false
        base_backup_valid = false
    )
)


VertexColorPainter = VertexColorPainter_v()
