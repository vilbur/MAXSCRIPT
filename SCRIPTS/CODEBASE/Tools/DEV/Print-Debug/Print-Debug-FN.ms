/*
Prints selected object, modifier, and rollout diagnostics to the Listener.
File version: 0.01
Project version: 0.01
*/
global print_debug_global_project_version
if print_debug_global_project_version == undefined then
(
    print_debug_global_project_version = 0.01
)
else if print_debug_global_project_version < 0.01 then
(
    print_debug_global_project_version = 0.01
)

/*
Filters global values to Rollout and RolloutFloater objects.
Returns true only for values supported by the UI inspector.
*/
function printDebugIsInspectableGlobal global_name global_value =
(
    (classOf global_value == Rollout) or (classOf global_value == RolloutFloater)
) -- return

struct PrintDebugFN_v
(
    file_version = 0.01,
    project_version = 0.01,

    /*
    Prints the selected geometry sections from an evaluated mesh snapshot.
    Returns false when the node is missing or does not produce a mesh.
    */
    function printObject target_node print_verts print_positions print_vertex_normals print_tri_faces print_face_normals print_polygons print_material_ids =
    (
        if target_node == undefined then
        (
            format "PRINT-DEBUG | no object was supplied.\n"
            false
        )
        else
        (
            local snapshot_mesh = snapshotAsMesh target_node
            if not (isKindOf snapshot_mesh TriMesh) then
            (
                format "PRINT-DEBUG | snapshot is not a TriMesh | object:% class:%\n" target_node.name (classOf snapshot_mesh)
                false
            )
            else
            (
                local vert_count = getNumVerts snapshot_mesh
                local face_count = getNumFaces snapshot_mesh
                format "\nPRINT-DEBUG OBJECT | name:% class:% evaluated snapshot | verts:% faces:%\n" target_node.name (classOf target_node.baseObject) vert_count face_count

                if print_verts then
                (
                    format "VERTEX IDS | count:%\n" vert_count
                    for vert_id = 1 to vert_count do format "VERTEX | id:%\n" vert_id
                )

                if print_positions then
                (
                    format "VERTEX POSITIONS | count:%\n" vert_count
                    for vert_id = 1 to vert_count do format "VERTEX POSITION | id:% position:%\n" vert_id (getVert snapshot_mesh vert_id)
                )

                if print_vertex_normals then
                (
                    format "VERTEX NORMALS | count:%\n" vert_count
                    for vert_id = 1 to vert_count do format "VERTEX NORMAL | id:% normal:%\n" vert_id (getNormal snapshot_mesh vert_id)
                )

                if print_tri_faces or print_face_normals or print_material_ids then
                (
                    for face_id = 1 to face_count do
                    (
                        local face_verts = meshop.getFace snapshot_mesh face_id
                        if print_tri_faces then format "TRI FACE | id:% verts:%\n" face_id face_verts
                        if print_face_normals then
                        (
                            local first_position = getVert snapshot_mesh face_verts.x
                            local second_position = getVert snapshot_mesh face_verts.y
                            local third_position = getVert snapshot_mesh face_verts.z
                            local normal_value = cross (second_position - first_position) (third_position - first_position)
                            local normal_length = length normal_value
                            local face_normal = if normal_length == 0 then [0,0,0] else normal_value / normal_length
                            format "FACE NORMAL | id:% normal:%\n" face_id face_normal
                        )
                        if print_material_ids then format "MATERIAL ID | face:% matID:%\n" face_id (meshop.getFaceMatID snapshot_mesh face_id)
                    )
                )

                if print_polygons then
                (
                    local polygon_groups = getVisibleEdgePolygonGroups snapshot_mesh
                    format "POLYGONS | grouped across invisible edges | count:%\n" polygon_groups.count
                    for group_id = 1 to polygon_groups.count do format "POLYGON | id:% triangleFaces:%\n" group_id polygon_groups[group_id]
                )

                true
            )
        )
    ),

    /*
Groups evaluated triangle faces by their shared invisible edges.
Returns one face-ID BitArray for each visible-edge polygon.
    */
    function getVisibleEdgePolygonGroups snapshot_mesh =
    (
        local face_count = getNumFaces snapshot_mesh
        local edge_map = dotNetObject "System.Collections.Hashtable"
        local edge_keys = #()
        local face_neighbors = #()
        face_neighbors.count = face_count
        for face_id = 1 to face_count do face_neighbors[face_id] = #{}

        for face_id = 1 to face_count do
        (
            local face_verts = meshop.getFace snapshot_mesh face_id
            local face_vertex_ids = #(face_verts.x, face_verts.y, face_verts.z)
            for edge_slot = 1 to 3 do
            (
                local vertex_a = face_vertex_ids[edge_slot]
                local vertex_b = face_vertex_ids[(if edge_slot == 3 then 1 else edge_slot + 1)]
                local low_vertex = if vertex_a < vertex_b then vertex_a else vertex_b
                local high_vertex = if vertex_a < vertex_b then vertex_b else vertex_a
                local edge_key = (low_vertex as string) + ":" + (high_vertex as string)
                local edge_visibility = getEdgeVis snapshot_mesh face_id edge_slot
                local edge_records = undefined

                if edge_map.ContainsKey edge_key then
                (
                    edge_records = edge_map.Item[edge_key]
                    append edge_records #(face_id, edge_visibility)
                )
                else
                (
                    edge_records = #(#(face_id, edge_visibility))
                    edge_map.Add edge_key edge_records
                    append edge_keys edge_key
                )
            )
        )

        for edge_key in edge_keys do
        (
            local edge_records = edge_map.Item[edge_key]
            if edge_records.count > 1 then
            (
                local has_invisible_side = false
                for edge_record in edge_records while not has_invisible_side do
                (
                    if edge_record[2] == false then has_invisible_side = true
                )
                if has_invisible_side then
                (
                    for edge_record_a in edge_records do
                    (
                        for edge_record_b in edge_records do
                        (
                            if edge_record_a[1] != edge_record_b[1] then face_neighbors[edge_record_a[1]][edge_record_b[1]] = true
                        )
                    )
                )
            )
        )

        local visited_faces = #{}
        visited_faces.count = face_count
        local polygon_groups = #()
        for seed_id = 1 to face_count do
        (
            if not visited_faces[seed_id] then
            (
                local group_faces = #{}
                local face_stack = #(seed_id)
                local stack_index = 1
                visited_faces[seed_id] = true
                group_faces[seed_id] = true

                while stack_index <= face_stack.count do
                (
                    local current_face = face_stack[stack_index]
                    stack_index += 1
                    for neighbor_id in face_neighbors[current_face] do
                    (
                        if not visited_faces[neighbor_id] then
                        (
                            visited_faces[neighbor_id] = true
                            group_faces[neighbor_id] = true
                            append face_stack neighbor_id
                        )
                    )
                )
                append polygon_groups group_faces
            )
        )

        polygon_groups
    ),

    /*
Prints properties of the modifier currently selected in the Modify panel.
Returns false when the current stack item is not a modifier.
    */
    function printCurrentModifier =
    (
        local current_stack_item = modPanel.getCurrentObject()
        if current_stack_item == undefined then
        (
            format "PRINT-DEBUG | no current modifier or stack object is available.\n"
            false
        )
        else if not (isKindOf current_stack_item Modifier) then
        (
            format "PRINT-DEBUG | current stack item is not a modifier | class:%\n" (classOf current_stack_item)
            false
        )
        else
        (
            format "\nPRINT-DEBUG CURRENT MODIFIER | class:% name:%\n" (classOf current_stack_item) current_stack_item.name
            showProperties current_stack_item
            true
        )
    ),

    /*
Returns the names of globally accessible Rollout and RolloutFloater values.
The returned names can be used to choose an inspector target in the UI.
    */
    function getInspectableGlobals =
    (
        globalVars.gather filter:printDebugIsInspectableGlobal
    ),

    /*
Prints properties and geometry for a selected Rollout or RolloutFloater.
Returns false when the global value is missing or no longer inspectable.
    */
    function printRolloutOrFloater global_name =
    (
        if not (globalVars.isGlobal global_name) then
        (
            format "PRINT-DEBUG | selected global no longer exists | name:%\n" global_name
            false
        )
        else
        (
            local target_value = globalVars.get global_name
            local target_rollouts = #()
            if (classOf target_value == RolloutFloater) or (classOf target_value == Rollout) then
            (
                format "\nPRINT-DEBUG UI TARGET | global:% class:%\n" global_name (classOf target_value)
                showProperties target_value

                if classOf target_value == RolloutFloater then
                (
                    target_rollouts = target_value.rollouts
                    format "FLOATER | title:% pos:% size:% dialogBar:% placement:% hwnd:%\n" target_value.title target_value.pos target_value.size target_value.dialogBar target_value.placementName target_value.hwnd
                    local floater_window_pos = windows.getWindowPos target_value.hwnd
                    format "FLOATER WINDOW RECT | %\n" floater_window_pos
                    printDockState target_value
                )
                else
                (
                    target_rollouts = #(target_value)
                    printDockState target_value
                )

                if target_rollouts.count > 0 then
                (
                    for rollout_value in target_rollouts do printRolloutDetails rollout_value
                    true
                )
                else
                (
                    format "PRINT-DEBUG | selected floater contains no rollouts.\n"
                    true
                )
            )
            else
            (
                format "PRINT-DEBUG | selected global is no longer a rollout or floater | name:%\n" global_name
                false
            )
        )
    ),

    /*
Prints the docking state when MAXScript recognizes a registered dialog bar.
Prints the exact API exception when the target has no registered dock state.
    */
    function printDockState ui_target =
    (
        try
        (
            format "DOCK STATE | %\n" (cui.getDockState ui_target)
        )
        catch
        (
            local exception_text = getCurrentException()
            format "DOCK STATE | unavailable | %\n" exception_text
        )
    ),

    /*
Prints a rollout's properties, bounds, controls, and native child windows.
Control names are reported as their MaxScript control IDs.
    */
    function printRolloutDetails rollout_value =
    (
        format "\nROLLOUT | name:% title:% open:% displayed:% pos:% size:% hwnd:%\n" rollout_value.name rollout_value.title rollout_value.open rollout_value.isDisplayed rollout_value.pos [rollout_value.width, rollout_value.height] rollout_value.hwnd
        showProperties rollout_value

        if rollout_value.hwnd != 0 then
        (
            format "ROLLOUT WINDOW RECT | %\n" (windows.getWindowPos rollout_value.hwnd)
            local control_values = rollout_value.controls
            format "ROLLOUT CONTROLS | count:%\n" control_values.count
            for control_index = 1 to control_values.count do
            (
                local control_value = control_values[control_index]
                if (classOf control_value == GroupStartControl) or (classOf control_value == GroupEndControl) then
                (
                    format "CONTROL | index:% class:% name:% group marker\n" control_index (classOf control_value) control_value.name
                )
                else
                (
                    format "CONTROL | index:% id:% class:% pos:% size:%\n" control_index control_value.name (classOf control_value) control_value.pos [control_value.width, control_value.height]
                )
                showProperties control_value
            )

            local native_children = windows.getChildrenHWND rollout_value
            if native_children != undefined then
            (
                format "NATIVE CHILD WINDOWS | count:%\n" native_children.count
                for child_data in native_children do printNativeWindowDetails child_data
            )
            else
            (
                format "NATIVE CHILD WINDOWS | unavailable | rollout hwnd:%\n" rollout_value.hwnd
            )
        )
        else
        (
            format "ROLLOUT WINDOW | closed or not displayed; MaxScript properties were printed.\n"
        )
    ),

    /*
Prints the native child window handle, class, caption, bounds, and ID.
Reports an unavailable native ID when the installed 3ds Max API cannot read it.
    */
    function printNativeWindowDetails child_data =
    (
        local native_id = undefined
        try
        (
            native_id = windows.getWindowLong child_data[1] #id
        )
        catch
        (
            local exception_text = getCurrentException()
            format "NATIVE CONTROL ID | hwnd:% unavailable | %\n" child_data[1] exception_text
        )
        local native_window_pos = windows.getWindowPos child_data[1]
        format "NATIVE WINDOW | hwnd:% parent:% class:% caption:% id:% rect:%\n" child_data[1] child_data[2] child_data[4] child_data[5] native_id native_window_pos
    ),

    on create do ()
)

global PrintDebugFN
PrintDebugFN = PrintDebugFN_v()
