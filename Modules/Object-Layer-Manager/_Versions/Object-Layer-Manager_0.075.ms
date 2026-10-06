/*
    Arch Scene Cleaner
    Compact selection and layer tools for large imported architectural scenes.

    Left-click the vertex and size buttons to select values below the threshold.
    Right-click those buttons to select values above the threshold.
*/

global asc_tool_floater
global asc_tool_dialog
global asc_main_rollout

/*
Closes the previous Object Layer Manager dialog before any rollout or helper is redefined.
Dynamic child rollouts are detached while the old parent is still alive, then a registered dialog bar is unregistered before DestroyDialog.
*/
function ascClosePreviousObjectLayerManagerDialog =
(
    local existing_dialog = asc_tool_dialog
    local dialog_is_open = false
    local is_dialog_bar = false

    if existing_dialog == undefined then
    (
        existing_dialog = try(asc_main_rollout)catch(undefined)
    )

    if existing_dialog != undefined then
    (
        dialog_is_open = try(existing_dialog.inDialog)catch(false)
        is_dialog_bar = try(existing_dialog.dialogBar)catch(false)

        if dialog_is_open then
        (
            try
            (
                existing_dialog.clearLayerHierarchy()
            )
            catch
            (
            )
        )

        if is_dialog_bar then
        (
            try
            (
                cui.UnRegisterDialogBar existing_dialog
            )
            catch
            (
            )
        )

        if dialog_is_open then
        (
            try
            (
                destroyDialog existing_dialog
            )
            catch
            (
            )
        )
    )

    asc_tool_dialog = undefined
    asc_tool_floater = undefined

    true
    -- return
)

ascClosePreviousObjectLayerManagerDialog()
global asc_layer_button_tooltip

try
(
    if asc_layer_button_tooltip != undefined then
    (
        asc_layer_button_tooltip.Dispose()
    )
)
catch
(
)

asc_layer_button_tooltip = try(dotNetObject "System.Windows.Forms.ToolTip")catch(undefined)

/*
Applies the enlarged layer-button font without sharing a disposable Font instance between controls.
A failed GDI/.NET font assignment is contained so dialog creation can continue with the control's default font.
*/
function ascApplyLayerButtonFont button_control =
(
    local operation_ok = false
    local button_font = undefined

    try
    (
        button_font = dotNetObject "System.Drawing.Font" button_control.Font.FontFamily 9.0
        button_control.Font = button_font
        operation_ok = true
    )
    catch
    (
        operation_ok = false
    )

    -- return
    operation_ok
)

/*
Applies the dark layer-button appearance without changing the control's geometry or event behavior.
All .NET color assignments are contained so a Windows Forms style failure cannot abort dialog creation.
*/
function ascApplyLayerButtonStyle button_control =
(
    local operation_ok = false
    local color_class = undefined
    local flat_style_class = undefined

    try
    (
        color_class = dotNetClass "System.Drawing.Color"
        flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"
        button_control.FlatStyle = flat_style_class.Flat
        button_control.FlatAppearance.BorderSize = 0
        button_control.UseVisualStyleBackColor = false
        button_control.BackColor = color_class.FromArgb 52 52 52
        button_control.ForeColor = color_class.FromArgb 235 235 235
        operation_ok = true
    )
    catch
    (
        operation_ok = false
    )

    -- return
    operation_ok
)

global asc_script_directory = getFilenamePath (getSourceFileName())
global asc_saved_dialog_position
global asc_saved_dialog_height
global object_layer_manager_file_version = 0.075
global object_layer_manager_project_version

if (object_layer_manager_project_version == undefined) or (object_layer_manager_project_version < 0.075) then
(
    object_layer_manager_project_version = 0.075
)

/*
Gets the INI file used by Object Layer Manager.
The file lives beside the loaded Object-Layer-Manager.ms source file.
*/
function ascGetSettingsFilePath =
(
    local settings_directory = asc_script_directory
    local settings_path = settings_directory
    local final_character = ""

    if settings_directory.count > 0 then
    (
        final_character = substring settings_directory settings_directory.count 1

        if final_character != "\\" then
        (
            settings_path += "\\"
        )
    )

    settings_path += "Object-Layer-Manager.ini"

    -- return
    settings_path
)

/*
Gets the current scene basename for use as an INI section.
A trailing numeric revision and its preceding underscore, hyphen, or space are removed.
*/
function ascGetSceneSettingsSection =
(
    local section_name = ""
    local source_length = 0
    local suffix_index = 0
    local suffix_character = ""
    local separator_character = ""

    try
    (
        section_name = getFilenameFile maxFileName
    )
    catch
    (
        section_name = ""
    )

    if section_name == "" then
    (
        section_name = "Untitled"
    )
    else
    (
        source_length = section_name.count
        suffix_index = source_length

        while suffix_index > 0 do
        (
            suffix_character = substring section_name suffix_index 1

            if (findString "0123456789" suffix_character) != undefined then
            (
                suffix_index -= 1
            )
            else
            (
                exit
            )
        )

        if suffix_index < source_length then
        (
            if suffix_index > 0 then
            (
                separator_character = substring section_name suffix_index 1

                if (separator_character == "_") or (separator_character == "-") or (separator_character == " ") then
                (
                    suffix_index -= 1
                )
            )

            if suffix_index > 0 then
            (
                section_name = substring section_name 1 suffix_index
            )
            else
            (
                section_name = "Scene"
            )
        )
    )

    -- return
    section_name
)

/*
Reads one setting from the current scene's INI section.
A missing or unreadable value falls back to the supplied default string.
*/
function ascReadSetting setting_key default_value =
(
    local stored_value = default_value

    try
    (
        stored_value = getINISetting (ascGetSettingsFilePath()) (ascGetSceneSettingsSection()) setting_key

        if stored_value == "" then
        (
            stored_value = default_value
        )
    )
    catch
    (
        stored_value = default_value
    )

    -- return
    stored_value
)

/*
Writes one setting to the current scene's INI section.
The native INI writer creates the file or section when necessary.
*/
function ascWriteSetting setting_key setting_value =
(
    local operation_ok = false

    try
    (
        setINISetting (ascGetSettingsFilePath()) (ascGetSceneSettingsSection()) setting_key (setting_value as string)
        operation_ok = true
    )
    catch
    (
        operation_ok = false
    )

    -- return
    operation_ok
)

/*
Reads the saved floater screen position for the current scene section.
Missing or invalid coordinates yield undefined so 3ds Max chooses the default position.
*/
function ascGetSavedDialogPosition =
(
    local x_value = ascReadSetting "DialogX" ""
    local y_value = ascReadSetting "DialogY" ""
    local dialog_position = undefined

    if (x_value != "") and (y_value != "") then
    (
        try
        (
            dialog_position = [x_value as integer, y_value as integer]
        )
        catch
        (
            dialog_position = undefined
        )
    )

    -- return
    dialog_position
)

/*
Saves the floater screen position in the current scene's INI section.
Both Point2 coordinates are written independently through the existing settings helper.
*/
function ascSaveDialogPosition dialog_position =
(
    local operation_ok = false

    if dialog_position != undefined then
    (
        ascWriteSetting "DialogX" dialog_position.x
        ascWriteSetting "DialogY" dialog_position.y
        operation_ok = true
    )

    -- return
    operation_ok
)

/*
Reads the saved floating dialog height for the current scene section.
Invalid or missing values fall back to the standard 640 pixel height.
*/
function ascGetSavedDialogHeight =
(
    local height_value = ascReadSetting "DialogHeight" "640"
    local dialog_height = 640

    try
    (
        dialog_height = amax #(240, height_value as integer)
    )
    catch
    (
        dialog_height = 640
    )

    -- return
    dialog_height
)

/*
Saves the current floating dialog height for the current scene section.
Heights below the usable minimum are clamped before being written.
*/
function ascSaveDialogHeight dialog_height =
(
    local saved_height = amax #(240, dialog_height as integer)

    -- return
    ascWriteSetting "DialogHeight" saved_height
)

/*
Returns whether a node is valid, visible geometry.
The check fails closed when a node exposes an unsupported property.
*/
function ascIsVisibleGeometry scene_node =
(
    local is_candidate = false

    try
    (
        if (isValidNode scene_node) and (superClassOf scene_node == GeometryClass) then
        (
            is_candidate = not scene_node.isHidden
        )
    )
    catch
    (
        is_candidate = false
    )

    -- return
    is_candidate
)

/*
Collects visible geometry for preparation operations using one consistent scope.
A nonempty scene selection takes priority; otherwise every visible geometry node is used.
*/
function ascGetPreparationNodes =
(
    local preparation_nodes = #()

    if selection.count > 0 then
    (
        for scene_node in (selection as array) do
        (
            if ascIsVisibleGeometry scene_node then
            (
                append preparation_nodes scene_node
            )
        )
    )
    else
    (
        for scene_node in geometry do
        (
            if ascIsVisibleGeometry scene_node then
            (
                append preparation_nodes scene_node
            )
        )
    )

    -- return
    preparation_nodes
)

/*
Converts the scoped visible geometry nodes to Editable Poly inside one undo step.
Already-converted and unsupported objects are left unchanged without stopping the batch.
*/
function ascConvertPreparationGeometry =
(
    local preparation_nodes = ascGetPreparationNodes()
    local converted_count = 0

    if preparation_nodes.count > 0 then
    (
        undo "Prepare Geometry: Convert to Editable Poly" on
        (
            for scene_node in preparation_nodes do
            (
                if classOf scene_node.baseObject != Editable_Poly then
                (
                    try
                    (
                        convertToPoly scene_node

                        if classOf scene_node.baseObject == Editable_Poly then
                        (
                            converted_count += 1
                        )
                    )
                    catch
                    (
                    )
                )
            )
        )

        redrawViews()
    )

    -- return
    converted_count
)

/*
Converts eligible scoped geometry and welds through the Editable Poly node interface.
The threshold property is assigned before the native two-argument PolyOp weld call.
*/
function ascWeldPreparationGeometry weld_threshold =
(
    local preparation_nodes = ascGetPreparationNodes()
    local processed_count = 0
    local vertex_count = 0
    local vertex_selection = #{}

    if preparation_nodes.count > 0 then
    (
        undo "Prepare Geometry: Weld Vertices" on
        (
            for scene_node in preparation_nodes do
            (
                try
                (
                    if classOf scene_node.baseObject != Editable_Poly then
                    (
                        convertToPoly scene_node
                    )

                    if classOf scene_node.baseObject == Editable_Poly then
                    (
                        scene_node.weldThreshold = weld_threshold
                        vertex_count = polyop.getNumVerts scene_node

                        if vertex_count > 1 then
                        (
                            vertex_selection = #{1..vertex_count}
                            polyop.weldVertsByThreshold scene_node vertex_selection
                            processed_count += 1
                        )
                    )
                )
                catch
                (
                )
            )
        )

        completeRedraw()
    )

    -- return
    processed_count
)
/*
Gets evaluated vertex and face counts without collapsing a geometry node.
The polygon-count query is preferred, with one temporary mesh as a safe fallback.
*/
function ascGetSafeTopologyCounts scene_node =
(
    local topology_counts = undefined
    local polygon_data = undefined
    local temp_mesh = undefined
    local vertex_count = undefined
    local face_count = undefined

    if ascIsVisibleGeometry scene_node then
    (
        try
        (
            polygon_data = getPolygonCount scene_node
            vertex_count = polygon_data[2] as integer
            face_count = polygon_data[1] as integer
        )
        catch
        (
            vertex_count = undefined
            face_count = undefined
        )

        if (vertex_count == undefined) or (face_count == undefined) then
        (
            try
            (
                temp_mesh = snapshotAsMesh scene_node
                vertex_count = getNumVerts temp_mesh
                face_count = getNumFaces temp_mesh
            )
            catch
            (
                vertex_count = undefined
                face_count = undefined
            )

            temp_mesh = undefined
        )

        if (vertex_count != undefined) and (face_count != undefined) then
        (
            topology_counts = #(vertex_count, face_count)
        )
    )

    -- return
    topology_counts
)

/*
Gets the evaluated vertex count for a geometry node without collapsing it.
The shared topology-count helper keeps modifier-stack inspection non-destructive.
*/
function ascGetSafeVertexCount scene_node =
(
    local topology_counts = ascGetSafeTopologyCounts scene_node
    local vertex_count = undefined

    if topology_counts != undefined then
    (
        vertex_count = topology_counts[1]
    )

    -- return
    vertex_count
)

/*
Gets the evaluated face count for a geometry node without collapsing it.
The result uses the same evaluated topology path as vertex-count matching.
*/
function ascGetSafeFaceCount scene_node =
(
    local topology_counts = ascGetSafeTopologyCounts scene_node
    local face_count = undefined

    if topology_counts != undefined then
    (
        face_count = topology_counts[2]
    )

    -- return
    face_count
)
/*
Gets evaluated local bounding-box dimensions for a visible geometry node.
Passing the node transform to nodeGetBoundingBox keeps X, Y, and Z local.
*/
function ascGetLocalBoundingBoxDimensions scene_node =
(
    local size_data = undefined
    local bounds_data = undefined

    if ascIsVisibleGeometry scene_node then
    (
        try
        (
            bounds_data = nodeGetBoundingBox scene_node scene_node.transform
            size_data = bounds_data[2] - bounds_data[1]
            size_data = [abs size_data.x, abs size_data.y, abs size_data.z]
        )
        catch
        (
            size_data = undefined
        )
    )

    -- return
    size_data
)

/*
Gets the largest evaluated local bounding-box edge for a geometry node.
The shared dimension helper keeps threshold and proportion tests consistent.
*/
function ascGetLargestLocalDimension scene_node =
(
    local largest_dimension = undefined
    local size_data = ascGetLocalBoundingBoxDimensions scene_node

    if size_data != undefined then
    (
        largest_dimension = amax #(size_data.x, size_data.y, size_data.z)
    )

    -- return
    largest_dimension
)

/*
Gets a rotation-independent horizontal length-to-width ratio for a geometry node.
The evaluated mesh is sampled at distributed vertices to keep dense scenes responsive.
*/
function ascGetOrientedHorizontalRatio scene_node =
(
    local horizontal_ratio = undefined
    local temp_mesh = undefined
    local vertex_count = 0
    local sample_count = 0
    local sampled_positions = #()
    local position_sum_x = 0.0
    local position_sum_y = 0.0
    local mean_x = 0.0
    local mean_y = 0.0
    local covariance_xx = 0.0
    local covariance_yy = 0.0
    local covariance_xy = 0.0
    local trace_value = 0.0
    local difference_value = 0.0
    local discriminant = 0.0
    local largest_eigenvalue = 0.0
    local axis_x = 0.0
    local axis_y = 0.0
    local axis_length = 0.0
    local projection_length = 0.0
    local projection_width = 0.0
    local length_min = undefined
    local length_max = undefined
    local width_min = undefined
    local width_max = undefined
    local oriented_length = 0.0
    local oriented_width = 0.0
    local vertex_index = 0
    local vertex_position = undefined
    local centered_x = 0.0
    local centered_y = 0.0
    local epsilon_value = 0.000001

    if ascIsVisibleGeometry scene_node then
    (
        try
        (
            temp_mesh = snapshotAsMesh scene_node
            vertex_count = getNumVerts temp_mesh

            if vertex_count > 0 then
            (
                sample_count = amin #(vertex_count, 64)

                for sample_index = 1 to sample_count do
                (
                    vertex_index = 1 + floor (((sample_index - 0.5) * vertex_count) / sample_count)
                    vertex_index = amin #(vertex_index, vertex_count)
                    vertex_position = getVert temp_mesh vertex_index
                    append sampled_positions vertex_position
                    position_sum_x += vertex_position.x
                    position_sum_y += vertex_position.y
                )

                mean_x = position_sum_x / sample_count
                mean_y = position_sum_y / sample_count

                for sampled_position in sampled_positions do
                (
                    centered_x = sampled_position.x - mean_x
                    centered_y = sampled_position.y - mean_y
                    covariance_xx += centered_x * centered_x
                    covariance_yy += centered_y * centered_y
                    covariance_xy += centered_x * centered_y
                )

                covariance_xx /= sample_count
                covariance_yy /= sample_count
                covariance_xy /= sample_count
                trace_value = covariance_xx + covariance_yy
                difference_value = covariance_xx - covariance_yy
                discriminant = sqrt ((difference_value * difference_value) + (4.0 * covariance_xy * covariance_xy))
                largest_eigenvalue = (trace_value + discriminant) / 2.0

                if abs covariance_xy > epsilon_value then
                (
                    axis_x = largest_eigenvalue - covariance_yy
                    axis_y = covariance_xy
                )
                else
                (
                    if covariance_xx >= covariance_yy then
                    (
                        axis_x = 1.0
                        axis_y = 0.0
                    )
                    else
                    (
                        axis_x = 0.0
                        axis_y = 1.0
                    )
                )

                axis_length = sqrt ((axis_x * axis_x) + (axis_y * axis_y))

                if axis_length > epsilon_value then
                (
                    axis_x /= axis_length
                    axis_y /= axis_length

                    for sampled_position in sampled_positions do
                    (
                        centered_x = sampled_position.x - mean_x
                        centered_y = sampled_position.y - mean_y
                        projection_length = (centered_x * axis_x) + (centered_y * axis_y)
                        projection_width = (centered_x * -axis_y) + (centered_y * axis_x)

                        if (length_min == undefined) or (projection_length < length_min) then
                        (
                            length_min = projection_length
                        )
                        if (length_max == undefined) or (projection_length > length_max) then
                        (
                            length_max = projection_length
                        )
                        if (width_min == undefined) or (projection_width < width_min) then
                        (
                            width_min = projection_width
                        )
                        if (width_max == undefined) or (projection_width > width_max) then
                        (
                            width_max = projection_width
                        )
                    )

                    oriented_length = abs (length_max - length_min)
                    oriented_width = abs (width_max - width_min)

                    if oriented_width > oriented_length then
                    (
                        projection_length = oriented_length
                        oriented_length = oriented_width
                        oriented_width = projection_length
                    )

                    if oriented_width > epsilon_value then
                    (
                        horizontal_ratio = oriented_length / oriented_width
                    )
                    else if oriented_length > epsilon_value then
                    (
                        horizontal_ratio = 1000000.0
                    )
                )
            )
        )
        catch
        (
            horizontal_ratio = undefined
        )
    )

    temp_mesh = undefined

    -- return
    horizontal_ratio
)

/*
Tests one visible object against a compact local bounding-box shape heuristic.
Flat and Tall compare Z to XY; Long uses an oriented footprint; Box compares all edges.
*/
function ascMatchesSizeShape scene_node shape_kind shape_ratio =
(
    local size_data = ascGetLocalBoundingBoxDimensions scene_node
    local horizontal_largest = 0.0
    local oriented_horizontal_ratio = undefined
    local box_largest = 0.0
    local box_smallest = 0.0
    local box_ratio = 1.5
    local shape_matches = false

    if size_data != undefined then
    (
        horizontal_largest = amax #(size_data.x, size_data.y)
        box_largest = amax #(size_data.x, size_data.y, size_data.z)
        box_smallest = amin #(size_data.x, size_data.y, size_data.z)

        case shape_kind of
        (
            #flat:
            (
                if horizontal_largest > 0.000001 then
                (
                    shape_matches = size_data.z <= (horizontal_largest / shape_ratio)
                )
            )
            #tall:
            (
                if horizontal_largest > 0.000001 then
                (
                    shape_matches = size_data.z >= (horizontal_largest * shape_ratio)
                )
                else
                (
                    shape_matches = size_data.z > 0.000001
                )
            )
            #long:
            (
                oriented_horizontal_ratio = ascGetOrientedHorizontalRatio scene_node

                if oriented_horizontal_ratio != undefined then
                (
                    shape_matches = oriented_horizontal_ratio >= shape_ratio
                )
            )
            #box:
            (
                if box_smallest > 0.000001 then
                (
                    shape_matches = box_largest <= (box_smallest * box_ratio)
                )
            )
            default:
            (
                shape_matches = false
            )
        )
    )

    -- return
    shape_matches
)

/*
Selects all visible geometry matching one local bounding-box shape category.
The supplied ratio controls Flat, Tall, and the rotation-independent Long test.
*/
function ascSelectBySizeShape shape_kind shape_ratio =
(
    local result_nodes = #()

    for scene_node in geometry do
    (
        if ascMatchesSizeShape scene_node shape_kind shape_ratio then
        (
            append result_nodes scene_node
        )
    )

    if result_nodes.count > 0 then
    (
        select result_nodes
    )
    else
    (
        clearSelection()
    )

    -- return
    result_nodes.count
)/*
Gets the system-unit scale represented by one display-unit suffix.
Native unit decoding keeps conversion correct for every scene system-unit setup.
*/
function ascGetDisplayUnitScale unit_name =
(
    local unit_scale = 1.0

    try
    (
        unit_scale = units.decodeValue ("1" + unit_name)
    )
    catch
    (
        unit_scale = 1.0
    )

    if unit_scale <= 0.0 then
    (
        unit_scale = 1.0
    )

    -- return
    unit_scale
)

/*
Converts a readable unit value into the current scene's native system units.
Millimeters, centimeters, and meters are resolved through the shared scale helper.
*/
function ascDisplayValueToSystem display_value unit_name =
(
    local system_value = display_value * (ascGetDisplayUnitScale unit_name)

    -- return
    system_value
)

/*
Converts a native system-unit distance into a readable selected unit value.
A validated positive unit scale prevents division errors in unusual unit setups.
*/
function ascSystemValueToDisplay system_value unit_name =
(
    local display_value = system_value / (ascGetDisplayUnitScale unit_name)

    -- return
    display_value
)
/*
Gets one supported numeric metric from a geometry node.
Metric routing is centralized so reference and scene passes use identical logic.
*/
function ascGetNumericMetric scene_node metric_kind =
(
    local metric_value = undefined

    case metric_kind of
    (
        #vertexCount:
        (
            metric_value = ascGetSafeVertexCount scene_node
        )
        #largestDimension:
        (
            metric_value = ascGetLargestLocalDimension scene_node
        )
        default:
        (
            metric_value = undefined
        )
    )

    -- return
    metric_value
)

/*
Resolves the numeric threshold from the current valid visible selection.
Below mode uses the lowest reference value and above mode uses the highest.
*/
function ascResolveReferenceThreshold metric_kind select_below spinner_value =
(
    local reference_values = #()
    local reference_value = undefined
    local used_threshold = spinner_value

    for scene_node in (selection as array) do
    (
        reference_value = ascGetNumericMetric scene_node metric_kind

        if reference_value != undefined then
        (
            append reference_values reference_value
        )
    )

    if reference_values.count > 0 then
    (
        used_threshold = reference_values[1]

        for reference_value in reference_values do
        (
            if select_below then
            (
                if reference_value < used_threshold then
                (
                    used_threshold = reference_value
                )
            )
            else
            (
                if reference_value > used_threshold then
                (
                    used_threshold = reference_value
                )
            )
        )
    )

    -- return
    used_threshold
)

/*
Selects visible geometry using one numeric metric and a strict threshold.
The resulting array replaces the current selection and the used threshold is returned.
*/
function ascSelectByNumericThreshold metric_kind spinner_value select_below =
(
    local used_threshold = ascResolveReferenceThreshold metric_kind select_below spinner_value
    local result_nodes = #()
    local metric_value = undefined
    local is_match = false

    for scene_node in geometry do
    (
        if ascIsVisibleGeometry scene_node then
        (
            metric_value = ascGetNumericMetric scene_node metric_kind

            if metric_value != undefined then
            (
                if select_below then
                (
                    is_match = metric_value < used_threshold
                )
                else
                (
                    is_match = metric_value > used_threshold
                )

                if is_match then
                (
                    append result_nodes scene_node
                )
            )
        )
    )

    if result_nodes.count > 0 then
    (
        select result_nodes
    )
    else
    (
        clearSelection()
    )

    -- return
    used_threshold
)

/*
Builds evenly distributed indices into a collection without random sampling.
The result never exceeds the requested sample limit or the available item count.
*/
function ascBuildDistributedSampleIndices item_count requested_samples =
(
    local sample_indices = #()
    local sample_count = amin #(item_count, requested_samples)
    local item_index = 0

    if sample_count > 0 then
    (
        for sample_index = 1 to sample_count do
        (
            item_index = 1 + floor (((sample_index - 0.5) * item_count) / sample_count)
            item_index = amax #(1, amin #(item_count, item_index))
            append sample_indices item_index
        )
    )

    -- return
    sample_indices
)

/*
Gets the two faces sharing one evaluated triangular-mesh edge.
Border, non-manifold, invalid, and degenerate edges produce an empty array.
*/
function ascGetAdjacentEdgeFaces temp_mesh edge_index =
(
    local face_indices = #()
    local edge_selection = #{}
    local edge_vertices = undefined
    local vertex_indices = #()
    local first_vertex_selection = #{}
    local second_vertex_selection = #{}
    local first_vertex_faces = undefined
    local second_vertex_faces = undefined

    try
    (
        edge_selection[edge_index] = true
        edge_vertices = meshop.getVertsUsingEdge temp_mesh edge_selection

        if edge_vertices.numberSet == 2 then
        (
            vertex_indices = edge_vertices as array
            first_vertex_selection[vertex_indices[1]] = true
            second_vertex_selection[vertex_indices[2]] = true
            first_vertex_faces = meshop.getFacesUsingVert temp_mesh first_vertex_selection
            second_vertex_faces = meshop.getFacesUsingVert temp_mesh second_vertex_selection

            for face_index in first_vertex_faces do
            (
                if second_vertex_faces[face_index] then
                (
                    append face_indices face_index
                )
            )
        )

        if face_indices.count != 2 then
        (
            face_indices = #()
        )
    )
    catch
    (
        face_indices = #()
    )

    -- return
    face_indices
)

/*
Measures the face-normal angle across one eligible internal mesh edge.
Invalid normals or anything other than exactly two adjacent faces yield undefined.
*/
function ascGetAdjacentFaceAngle temp_mesh edge_index =
(
    local measured_angle = undefined
    local face_indices = ascGetAdjacentEdgeFaces temp_mesh edge_index
    local first_normal = undefined
    local second_normal = undefined
    local first_length = 0.0
    local second_length = 0.0
    local normal_dot = 0.0

    if face_indices.count == 2 then
    (
        try
        (
            first_normal = getFaceNormal temp_mesh face_indices[1]
            second_normal = getFaceNormal temp_mesh face_indices[2]
            first_length = length first_normal
            second_length = length second_normal

            if (first_length > 0.000001) and (second_length > 0.000001) then
            (
                normal_dot = dot (first_normal / first_length) (second_normal / second_length)
                normal_dot = amax #(-1.0, amin #(1.0, normal_dot))
                measured_angle = acos normal_dot
            )
        )
        catch
        (
            measured_angle = undefined
        )
    )

    -- return
    measured_angle
)

/*
Collects each eligible two-face internal edge once from an evaluated triangular mesh.
Open and non-manifold edges are excluded before angle sampling begins.
*/
function ascCollectEligibleInternalEdges temp_mesh =
(
    local eligible_edges = #()
    local face_count = 0
    local edge_slot_count = 0
    local open_edges = #{}
    local adjacent_faces = #()
    local owner_face_index = 0

    try
    (
        face_count = getNumFaces temp_mesh
        edge_slot_count = face_count * 3
        open_edges = meshop.getOpenEdges temp_mesh

        for edge_index = 1 to edge_slot_count do
        (
            if not open_edges[edge_index] then
            (
                adjacent_faces = ascGetAdjacentEdgeFaces temp_mesh edge_index

                if adjacent_faces.count == 2 then
                (
                    owner_face_index = 1 + floor ((edge_index - 1) / 3)

                    if owner_face_index == adjacent_faces[1] then
                    (
                        append eligible_edges edge_index
                    )
                )
            )
        )
    )
    catch
    (
        eligible_edges = #()
    )

    -- return
    eligible_edges
)

/*
Builds scale-independent local bounding-box proportions for complexity caching.
Sorted dimensions make the signature insensitive to local axis ordering.
*/
function ascGetBoundingBoxProportionSignature scene_node =
(
    local proportion_signature = undefined
    local bounds_data = undefined
    local size_data = undefined
    local smallest_dimension = 0.0
    local middle_dimension = 0.0
    local largest_dimension = 0.0
    local smallest_ratio = 0
    local middle_ratio = 0

    try
    (
        bounds_data = nodeGetBoundingBox scene_node scene_node.transform
        size_data = bounds_data[2] - bounds_data[1]
        size_data = [abs size_data.x, abs size_data.y, abs size_data.z]
        smallest_dimension = amin #(size_data.x, size_data.y, size_data.z)
        largest_dimension = amax #(size_data.x, size_data.y, size_data.z)
        middle_dimension = size_data.x + size_data.y + size_data.z - smallest_dimension - largest_dimension

        if largest_dimension > 0.000001 then
        (
            smallest_ratio = floor (((smallest_dimension / largest_dimension) * 1000.0) + 0.5)
            middle_ratio = floor (((middle_dimension / largest_dimension) * 1000.0) + 0.5)
            proportion_signature = (smallest_ratio as string) + ":" + (middle_ratio as string)
        )
    )
    catch
    (
        proportion_signature = undefined
    )

    -- return
    proportion_signature
)

/*
Builds a fast topology-and-proportion signature for complexity result reuse.
Vertex, edge, and face counts come from the same temporary evaluated mesh.
*/
function ascBuildComplexitySignature scene_node temp_mesh =
(
    local geometry_signature = undefined
    local vertex_count = 0
    local face_count = 0
    local edge_count = 0
    local open_edges = #{}
    local proportion_signature = undefined

    try
    (
        vertex_count = getNumVerts temp_mesh
        face_count = getNumFaces temp_mesh
        open_edges = meshop.getOpenEdges temp_mesh
        edge_count = (((face_count * 3) + open_edges.numberSet) / 2) as integer
        proportion_signature = ascGetBoundingBoxProportionSignature scene_node

        if proportion_signature != undefined then
        (
            geometry_signature = (vertex_count as string) + "|" + (edge_count as string) + "|" + (face_count as string) + "|" + proportion_signature
        )
    )
    catch
    (
        geometry_signature = undefined
    )

    -- return
    geometry_signature
)

/*
Collects real crease and bend edges for complexity sampling.
Effectively coplanar triangulation edges are ignored so they cannot dilute the score.
*/
function ascCollectComplexityEdges temp_mesh planar_epsilon =
(
    local complexity_edges = #()
    local eligible_edges = ascCollectEligibleInternalEdges temp_mesh
    local measured_angle = undefined

    for edge_index in eligible_edges do
    (
        measured_angle = ascGetAdjacentFaceAngle temp_mesh edge_index

        if (measured_angle != undefined) and (measured_angle > planar_epsilon) then
        (
            append complexity_edges edge_index
        )
    )

    -- return
    complexity_edges
)

/*
Tests whether a real crease or bend is close to a square or folded-back corner.
Near-zero angles have already been removed as coplanar triangulation edges.
*/
function ascIsOrthogonalAngle measured_angle angle_tolerance =
(
    local nearest_difference = amin #(
        abs (measured_angle - 90.0),
        abs (measured_angle - 180.0))
    local is_orthogonal = nearest_difference <= angle_tolerance

    -- return
    is_orthogonal
)

/*
Measures one evaluated mesh from distributed samples of eligible internal edges.
The returned array contains eligible edges, valid samples, non-orthogonal samples,
the score percentage, the classification result, and the sampled deviation range.
*/
function ascMeasureMeshComplexity temp_mesh requested_samples angle_tolerance non_orthogonal_threshold =
(
    local eligible_edges = ascCollectComplexityEdges temp_mesh 0.1
    local sample_indices = ascBuildDistributedSampleIndices eligible_edges.count requested_samples
    local measured_angle = undefined
    local orthogonal_deviation = 0.0
    local valid_sample_count = 0
    local non_orthogonal_count = 0
    local non_orthogonal_percent = 0.0
    local minimum_deviation = undefined
    local maximum_deviation = undefined
    local is_complex = false

    for sample_index in sample_indices do
    (
        measured_angle = ascGetAdjacentFaceAngle temp_mesh eligible_edges[sample_index]

        if measured_angle != undefined then
        (
            valid_sample_count += 1
            orthogonal_deviation = amin #(
                abs (measured_angle - 90.0),
                abs (measured_angle - 180.0))

            if (minimum_deviation == undefined) or (orthogonal_deviation < minimum_deviation) then
            (
                minimum_deviation = orthogonal_deviation
            )

            if (maximum_deviation == undefined) or (orthogonal_deviation > maximum_deviation) then
            (
                maximum_deviation = orthogonal_deviation
            )

            if not (ascIsOrthogonalAngle measured_angle angle_tolerance) then
            (
                non_orthogonal_count += 1
            )
        )
    )

    if valid_sample_count > 0 then
    (
        non_orthogonal_percent = (100.0 * non_orthogonal_count) / valid_sample_count
        is_complex = non_orthogonal_percent >= non_orthogonal_threshold
    )

    -- return
    #(eligible_edges.count, valid_sample_count, non_orthogonal_count, non_orthogonal_percent, is_complex, minimum_deviation, maximum_deviation)
)

/*
Classifies one evaluated mesh using the same measurement exposed by diagnostics.
*/
function ascClassifyMeshComplexity temp_mesh requested_samples angle_tolerance non_orthogonal_threshold =
(
    local complexity_measurement = ascMeasureMeshComplexity temp_mesh requested_samples angle_tolerance non_orthogonal_threshold

    -- return
    complexity_measurement[5]
)

/*
Reports the exact Select Complex score for the current visible geometry selection.
This diagnostic does not change the scene selection.
*/
function ascReportSelectedComplexity requested_samples angle_tolerance non_orthogonal_threshold =
(
    local report_text = ""
    local diagnosed_count = 0
    local skipped_count = 0
    local temp_mesh = undefined
    local complexity_measurement = undefined
    local result_label = ""

    if selection.count == 0 then
    (
        messageBox "Select one or more visible geometry objects first." title:"Complexity Diagnostic"
    )
    else
    (
        report_text = "Score = non-orthogonal samples / valid samples\n"
    report_text += "Tolerance: " + (angle_tolerance as string) + " deg    Cutoff: " + (non_orthogonal_threshold as string) + "%\n\n"

    for scene_node in (selection as array) do
    (
        if ascIsVisibleGeometry scene_node then
        (
            temp_mesh = undefined

            try
            (
                temp_mesh = snapshotAsMesh scene_node
                complexity_measurement = ascMeasureMeshComplexity temp_mesh requested_samples angle_tolerance non_orthogonal_threshold
                result_label = if complexity_measurement[5] then "COMPLEX" else "not complex"

                report_text += scene_node.name + "\n"
                report_text += "  Score: " + (complexity_measurement[4] as string) + "%  (" + (complexity_measurement[3] as string) + "/" + (complexity_measurement[2] as string) + ")  -> " + result_label + "\n"
                report_text += "  Eligible edges: " + (complexity_measurement[1] as string) + "; requested: " + (requested_samples as string) + "\n"

                if complexity_measurement[6] != undefined then
                (
                    report_text += "  Sample deviation from 90/180: " + (complexity_measurement[6] as string) + " to " + (complexity_measurement[7] as string) + " deg\n"

                    if not complexity_measurement[5] then
                    (
                        report_text += "  Hint: lower Tolerance below sampled deviations to raise this score.\n"
                    )
                )
                else
                (
                    report_text += "  No valid two-face edge samples.\n"
                )

                report_text += "\n"
                diagnosed_count += 1
            )
            catch
            (
                skipped_count += 1
            )

            temp_mesh = undefined
        )
        else
        (
            skipped_count += 1
        )
    )

    if skipped_count > 0 then
    (
        report_text += "Skipped unsupported or hidden selected objects: " + (skipped_count as string) + "\n"
    )

    if diagnosed_count > 0 then
    (
        messageBox report_text title:"Complexity Diagnostic"
    )
        else
        (
            messageBox "No selected objects could be measured. Select visible geometry and try again." title:"Complexity Diagnostic"
        )
    )

    -- return
    diagnosed_count > 0
)

/*
Selects visible geometry classified as complex by internal edge-angle samples.
Optional signature caching reuses results for likely copies with matching proportions.
*/
function ascSelectComplexGeometry requested_samples angle_tolerance non_orthogonal_threshold find_similar =
(
    local result_nodes = #()
    local cached_signatures = #()
    local cached_results = #()
    local temp_mesh = undefined
    local geometry_signature = undefined
    local cache_index = 0
    local is_complex = false

    for scene_node in geometry do
    (
        if ascIsVisibleGeometry scene_node then
        (
            temp_mesh = undefined

            try
            (
                temp_mesh = snapshotAsMesh scene_node

                if find_similar then
                (
                    geometry_signature = ascBuildComplexitySignature scene_node temp_mesh
                    cache_index = findItem cached_signatures geometry_signature

                    if (geometry_signature != undefined) and (cache_index > 0) then
                    (
                        is_complex = cached_results[cache_index]
                    )
                    else
                    (
                        is_complex = ascClassifyMeshComplexity temp_mesh requested_samples angle_tolerance non_orthogonal_threshold

                        if geometry_signature != undefined then
                        (
                            append cached_signatures geometry_signature
                            append cached_results is_complex
                        )
                    )
                )
                else
                (
                    is_complex = ascClassifyMeshComplexity temp_mesh requested_samples angle_tolerance non_orthogonal_threshold
                )

                if is_complex then
                (
                    append result_nodes scene_node
                )
            )
            catch
            (
            )

            temp_mesh = undefined
        )
    )

    if result_nodes.count > 0 then
    (
        select result_nodes
    )
    else
    (
        clearSelection()
    )

    -- return
    result_nodes.count
)
/*
Builds one compact similarity signature from the enabled object properties.
Vertex and face values share one evaluated topology query for speed.
*/
function ascBuildSimilaritySignature scene_node match_vertex_count match_face_count match_wirecolor =
(
    local similarity_signature = #()
    local topology_counts = undefined
    local wire_color = undefined
    local signature_valid = ascIsVisibleGeometry scene_node

    if signature_valid and (match_vertex_count or match_face_count) then
    (
        topology_counts = ascGetSafeTopologyCounts scene_node

        if topology_counts == undefined then
        (
            signature_valid = false
        )
    )

    if signature_valid and match_vertex_count then
    (
        append similarity_signature topology_counts[1]
    )

    if signature_valid and match_face_count then
    (
        append similarity_signature topology_counts[2]
    )

    if signature_valid and match_wirecolor then
    (
        try
        (
            wire_color = scene_node.wireColor
            append similarity_signature wire_color
        )
        catch
        (
            signature_valid = false
        )
    )

    if not signature_valid then
    (
        similarity_signature = undefined
    )

    -- return
    similarity_signature
)

/*
Compares two compact similarity signatures value by value.
Different lengths or any unequal enabled property produce a non-match.
*/
function ascSimilaritySignaturesMatch first_signature second_signature =
(
    local signatures_match = false

    if (first_signature != undefined) and (second_signature != undefined) then
    (
        if first_signature.count == second_signature.count then
        (
            signatures_match = true

            for signature_index = 1 to first_signature.count while signatures_match do
            (
                if first_signature[signature_index] != second_signature[signature_index] then
                (
                    signatures_match = false
                )
            )
        )
    )

    -- return
    signatures_match
)

/*
Selects visible geometry matching all enabled properties of any selected reference.
The current references are captured before the resulting selection replaces them.
*/
function ascSelectSimilar match_vertex_count match_face_count match_wirecolor =
(
    local result_nodes = #()
    local reference_signatures = #()
    local reference_signature = undefined
    local candidate_signature = undefined
    local candidate_matches = false
    local enabled_option_count = 0

    if match_vertex_count then
    (
        enabled_option_count += 1
    )

    if match_face_count then
    (
        enabled_option_count += 1
    )

    if match_wirecolor then
    (
        enabled_option_count += 1
    )

    if enabled_option_count == 0 then
    (
        messageBox "Enable at least one Select Similar option." title:"Arch Scene Cleaner"
    )
    else
    (
        for reference_node in (selection as array) do
        (
            reference_signature = ascBuildSimilaritySignature reference_node match_vertex_count match_face_count match_wirecolor

            if reference_signature != undefined then
            (
                append reference_signatures reference_signature
            )
        )

        if reference_signatures.count == 0 then
        (
            messageBox "Select one or more visible geometry reference objects first." title:"Arch Scene Cleaner"
        )
        else
        (
            for scene_node in geometry do
            (
                if ascIsVisibleGeometry scene_node then
                (
                    candidate_signature = ascBuildSimilaritySignature scene_node match_vertex_count match_face_count match_wirecolor
                    candidate_matches = false

                    for stored_signature in reference_signatures while not candidate_matches do
                    (
                        candidate_matches = ascSimilaritySignaturesMatch candidate_signature stored_signature
                    )

                    if candidate_matches then
                    (
                        append result_nodes scene_node
                    )
                )
            )

            if result_nodes.count > 0 then
            (
                select result_nodes
            )
            else
            (
                clearSelection()
            )
        )
    )

    -- return
    result_nodes.count
)

/*
Gets ordered local vertex positions for one Editable Poly face.
Invalid, dead, or inaccessible polygon data yields an empty array.
*/
function ascGetFaceVertexPositions scene_node face_index =
(
    local vertex_positions = #()
    local face_vertices = undefined
    local vertex_position = undefined

    try
    (
        face_vertices = polyop.getFaceVerts scene_node face_index

        for vertex_index in face_vertices do
        (
            vertex_position = polyop.getVert scene_node vertex_index
            append vertex_positions vertex_position
        )
    )
    catch
    (
        vertex_positions = #()
    )

    -- return
    vertex_positions
)

/*
Tests one Editable Poly face for geometric non-planarity.
The tolerance scales with face size while retaining a small absolute floor.
*/
function ascIsFaceNonPlanar scene_node face_index =
(
    local vertex_positions = ascGetFaceVertexPositions scene_node face_index
    local is_non_planar = false
    local has_valid_plane = false
    local origin_position = undefined
    local plane_normal = undefined
    local cross_vector = undefined
    local face_scale = 0.0
    local position_distance = 0.0
    local planar_tolerance = 0.00001

    if vertex_positions.count > 3 then
    (
        origin_position = vertex_positions[1]

        for vertex_index = 2 to (vertex_positions.count - 1) while not has_valid_plane do
        (
            cross_vector = cross (vertex_positions[vertex_index] - origin_position) (vertex_positions[vertex_index + 1] - origin_position)

            if (length cross_vector) > 0.000001 then
            (
                plane_normal = normalize cross_vector
                has_valid_plane = true
            )
        )

        if has_valid_plane then
        (
            for vertex_position in vertex_positions do
            (
                position_distance = length (vertex_position - origin_position)

                if position_distance > face_scale then
                (
                    face_scale = position_distance
                )
            )

            planar_tolerance = amax #(0.00001, face_scale * 0.0001)

            for vertex_position in vertex_positions while not is_non_planar do
            (
                position_distance = abs (dot plane_normal (vertex_position - origin_position))

                if position_distance > planar_tolerance then
                (
                    is_non_planar = true
                )
            )
        )
    )

    -- return
    is_non_planar
)

/*
Builds a face-selection BitArray for one supported polygon criterion.
Only valid Editable Poly polygon faces are evaluated.
*/
function ascGetMatchingFaceSelection scene_node selection_kind =
(
    local face_selection = #{}
    local face_count = 0
    local face_vertices = undefined
    local face_matches = false

    try
    (
        face_count = polyop.getNumFaces scene_node

        for face_index = 1 to face_count do
        (
            face_matches = false

            case selection_kind of
            (
                #nonPlanar:
                (
                    face_matches = ascIsFaceNonPlanar scene_node face_index
                )
                #ngons:
                (
                    face_vertices = polyop.getFaceVerts scene_node face_index
                    face_matches = face_vertices.count > 4
                )
                default:
                (
                    face_matches = false
                )
            )

            if face_matches then
            (
                face_selection[face_index] = true
            )
        )
    )
    catch
    (
        face_selection = #{}
    )

    -- return
    face_selection
)

/*
Finds the topmost Edit Poly modifier on a scene node when one exists.
An unsupported or inaccessible modifier stack yields undefined.
*/
function ascFindTopEditPolyModifier scene_node =
(
    local edit_poly_modifier = undefined

    try
    (
        for modifier_index = 1 to scene_node.modifiers.count while edit_poly_modifier == undefined do
        (
            if classOf scene_node.modifiers[modifier_index] == Edit_Poly then
            (
                edit_poly_modifier = scene_node.modifiers[modifier_index]
            )
        )
    )
    catch
    (
        edit_poly_modifier = undefined
    )

    -- return
    edit_poly_modifier
)

/*
Applies a face selection through Edit Poly when practical or Editable Poly directly.
Failures are contained so one unsupported stack cannot interrupt other objects.
*/
function ascApplyFaceSelection scene_node face_selection =
(
    local operation_ok = false
    local edit_poly_modifier = ascFindTopEditPolyModifier scene_node

    if edit_poly_modifier != undefined then
    (
        try
        (
            edit_poly_modifier.SetSelection #Face face_selection
            operation_ok = true
        )
        catch
        (
            operation_ok = false
        )
    )

    if not operation_ok then
    (
        try
        (
            polyop.setFaceSelection scene_node face_selection
            operation_ok = true
        )
        catch
        (
            operation_ok = false
        )
    )

    -- return
    operation_ok
)

/*
Selects matching polygon faces on the current visible Editable Poly objects.
Processed objects remain selected and 3ds Max enters polygon sub-object mode.
*/
function ascSelectFaces selection_kind =
(
    local processed_nodes = #()
    local face_selection = #{}

    for scene_node in (selection as array) do
    (
        if ascIsVisibleGeometry scene_node then
        (
            if classOf scene_node.baseObject == Editable_Poly then
            (
                face_selection = ascGetMatchingFaceSelection scene_node selection_kind

                if ascApplyFaceSelection scene_node face_selection then
                (
                    append processed_nodes scene_node
                )
            )
        )
    )

    if processed_nodes.count > 0 then
    (
        select processed_nodes

        try
        (
            max modify mode
            subObjectLevel = 4
            redrawViews()
        )
        catch
        (
        )
    )
    else
    (
        messageBox "Select one or more visible Editable Poly objects first." title:"Arch Scene Cleaner"
    )

    -- return
    processed_nodes.count
)

/*
Gets the user-facing name for one native scene layer name.
The native layer named 0 is displayed as Default.
*/
function ascGetLayerDisplayName layer_name =
(
    local display_name = layer_name

    if layer_name == "0" then
    (
        display_name = "Default"
    )

    -- return
    display_name
)

/*
Sorts native layer names alphabetically by their user-facing names.
The insertion sort preserves the native names needed for layer operations.
*/
function ascSortLayerNamesAlphabetically layer_names =
(
    local sorted_names = for layer_name in layer_names collect layer_name
    local current_name = ""
    local current_display_name = ""
    local comparison_display_name = ""
    local insertion_index = 0

    for source_index = 2 to sorted_names.count do
    (
        current_name = sorted_names[source_index]
        current_display_name = ascGetLayerDisplayName current_name
        insertion_index = source_index - 1

        while insertion_index >= 1 do
        (
            comparison_display_name = ascGetLayerDisplayName sorted_names[insertion_index]

            if (stricmp comparison_display_name current_display_name) > 0 then
            (
                sorted_names[insertion_index + 1] = sorted_names[insertion_index]
                insertion_index -= 1
            )
            else
            (
                exit
            )
        )

        sorted_names[insertion_index + 1] = current_name
    )

    -- return
    sorted_names
)

/*
Collects all current scene layer names in display-alphabetical order.
Invalid layer references are skipped without interrupting the refresh.
*/
function ascGetLayerNames =
(
    local layer_names = #()
    local scene_layer = undefined

    for layer_index = 0 to (layerManager.count - 1) do
    (
        try
        (
            scene_layer = layerManager.getLayer layer_index

            if scene_layer != undefined then
            (
                append layer_names scene_layer.name
            )
        )
        catch
        (
            scene_layer = undefined
        )
    )

    layer_names = ascSortLayerNamesAlphabetically layer_names

    -- return
    layer_names
)

/*
Builds user-facing layer names while keeping native layer identifiers unchanged.
The special 3ds Max layer named 0 is shown in the UI as Default.
*/
function ascGetLayerDisplayNames layer_names =
(
    local display_names = #()

    for layer_name in layer_names do
    (
        append display_names (ascGetLayerDisplayName layer_name)
    )

    -- return
    display_names
)

/*
Returns the layer used by the largest number of supplied valid nodes.
When counts are tied, the layer encountered first in the supplied node order wins.
*/
function ascGetMajoritySelectedLayer scene_nodes =
(
    local layer_names = #()
    local layer_counts = #()
    local majority_layer = undefined
    local majority_count = 0
    local scene_layer = undefined
    local layer_name = ""
    local layer_index = 0

    for scene_node in scene_nodes do
    (
        if isValidNode scene_node then
        (
            scene_layer = try(scene_node.layer)catch(undefined)

            if scene_layer != undefined then
            (
                layer_name = scene_layer.name
                layer_index = findItem layer_names layer_name

                if layer_index == 0 then
                (
                    append layer_names layer_name
                    append layer_counts 1
                    layer_index = layer_names.count
                )
                else
                (
                    layer_counts[layer_index] += 1
                )

                if layer_counts[layer_index] > majority_count then
                (
                    majority_count = layer_counts[layer_index]
                    majority_layer = scene_layer
                )
            )
        )
    )

    -- return
    majority_layer
)

/*
Creates a child layer for all selected nodes under the majority selected-node layer.
The proposed name uses the parent display name followed by -NEW and is confirmed by the user before creation.
*/
function ascCreateLayerForSelection =
(
    local selected_nodes = #()
    local parent_layer = undefined
    local parent_name = ""
    local default_name = ""
    local new_name = undefined
    local new_layer = undefined
    local parent_set = true
    local moved_count = 0
    local operation_ok = false

    for scene_node in (selection as array) do
    (
        if isValidNode scene_node then
        (
            append selected_nodes scene_node
        )
    )

    if selected_nodes.count == 0 then
    (
        messageBox "Select one or more scene objects first." title:"Object Layer Manager"
    )
    else
    (
        parent_layer = ascGetMajoritySelectedLayer selected_nodes

        if parent_layer != undefined then
        (
            parent_name = ascGetLayerDisplayName parent_layer.name
            default_name = parent_name + "-NEW"
            new_name = getString "New layer name:" default:default_name

            if new_name != undefined then
            (
                if new_name == "" then
                (
                    messageBox "Layer name cannot be empty." title:"Object Layer Manager"
                )
                else if layerManager.getLayerFromName new_name != undefined then
                (
                    messageBox ("A layer with this name already exists:\n" + new_name) title:"Object Layer Manager"
                )
                else
                (
                    undo "Create Scene Layer" on
                    (
                        new_layer = layerManager.newLayerFromName new_name

                        if new_layer != undefined then
                        (
                            parent_set = try(new_layer.setParent parent_layer)catch(false)

                            if parent_set then
                            (
                                for scene_node in selected_nodes do
                                (
                                    try
                                    (
                                        new_layer.addNode scene_node
                                        moved_count += 1
                                    )
                                    catch
                                    (
                                    )
                                )

                                operation_ok = moved_count == selected_nodes.count
                            )
                            else
                            (
                                try(layerManager.deleteLayerByName new_name)catch()
                            )
                        )
                    )

                    if not operation_ok then
                    (
                        messageBox "The new layer could not be created for every selected object." title:"Object Layer Manager"
                    )
                )
            )
        )
        else
        (
            messageBox "Could not resolve the layer used by the current selection." title:"Object Layer Manager"
        )
    )

    -- return
    operation_ok
)

/*
Moves the current visible valid selection into an existing named scene layer.
Layer changes are undoable and a missing layer produces a clear message.
*/
function ascMoveSelectionToLayer layer_name =
(
    local operation_ok = false
    local target_layer = undefined
    local selected_nodes = #()

    if (layer_name != undefined) and (layer_name != "") then
    (
        target_layer = layerManager.getLayerFromName layer_name

        if target_layer != undefined then
        (
            for scene_node in (selection as array) do
            (
                if (isValidNode scene_node) and (not scene_node.isHidden) then
                (
                    append selected_nodes scene_node
                )
            )

            if selected_nodes.count > 0 then
            (
                undo "Add Selection to Layer" on
                (
                    for scene_node in selected_nodes do
                    (
                        try
                        (
                            target_layer.addNode scene_node
                        )
                        catch
                        (
                            format "Arch Scene Cleaner: could not move node '%' to layer '%'.\n" scene_node.name layer_name
                        )
                    )
                )

                operation_ok = true
            )
            else
            (
                messageBox "Select one or more visible scene objects first." title:"Arch Scene Cleaner"
            )
        )
        else
        (
            messageBox ("The layer no longer exists:\n" + layer_name + "\n\nRefresh the layer lists and choose another layer.") title:"Arch Scene Cleaner"
        )
    )
    else
    (
        messageBox "Choose a target layer first." title:"Arch Scene Cleaner"
    )

    -- return
    operation_ok
)

/*
Toggles visibility for an existing native scene layer.
The layer-state change is undoable and missing layers fail with a clear message.
*/
function ascToggleLayerVisibility layer_name =
(
    local operation_ok = false
    local target_layer = undefined

    if (layer_name != undefined) and (layer_name != "") then
    (
        target_layer = layerManager.getLayerFromName layer_name

        if target_layer != undefined then
        (
            try
            (
                undo "Toggle Layer Visibility" on
                (
                    target_layer.isHidden = not target_layer.isHidden
                )

                operation_ok = true
            )
            catch
            (
                messageBox ("The layer visibility could not be changed:\n" + layer_name) title:"Arch Scene Cleaner"
            )
        )
        else
        (
            messageBox ("The layer no longer exists:\n" + layer_name + "\n\nRefresh the layer lists and choose another layer.") title:"Arch Scene Cleaner"
        )
    )
    else
    (
        messageBox "Choose a target layer first." title:"Arch Scene Cleaner"
    )

    -- return
    operation_ok
)

global asc_temporary_layer_names = #()
global asc_temporary_layer_hidden_states = #()
global asc_temporary_layer_isolate_active = false
global asc_dynamic_layer_rollout_counter
global asc_dynamic_layer_names = #()

if asc_dynamic_layer_rollout_counter == undefined then
(
    asc_dynamic_layer_rollout_counter = 0
)

/*
Gets the alphabetically sorted native child layer names for one scene layer.
Missing layers or invalid child references produce an empty or partial result.
*/
function ascGetChildLayerNames layer_name =
(
    local child_names = #()
    local scene_layer = layerManager.getLayerFromName layer_name
    local child_layer = undefined
    local child_count = 0

    if scene_layer != undefined then
    (
        try
        (
            child_count = scene_layer.getNumChildren()

            for child_index = 1 to child_count do
            (
                child_layer = scene_layer.getChild child_index

                if child_layer != undefined then
                (
                    append child_names child_layer.name
                )
            )
        )
        catch
        (
        )
    )

    child_names = ascSortLayerNamesAlphabetically child_names

    -- return
    child_names
)

/*
Builds the source-layer dropdown order for the current scene hierarchy.
Top-level parent layers come first, followed by every other non-Default layer alphabetically.
*/
function ascGetSourceLayerNames =
(
    local top_parent_names = #()
    local other_layer_names = #()
    local scene_layer = undefined
    local parent_layer = undefined
    local child_count = 0
    local is_top_parent = false
    local ordered_names = #()

    for layer_index = 0 to (layerManager.count - 1) do
    (
        try
        (
            scene_layer = layerManager.getLayer layer_index

            if (scene_layer != undefined) and (scene_layer.name != "0") then
            (
                parent_layer = scene_layer.getParent()
                child_count = scene_layer.getNumChildren()
                is_top_parent = false

                if child_count > 0 then
                (
                    if parent_layer == undefined then
                    (
                        is_top_parent = true
                    )
                    else if parent_layer.name == "0" then
                    (
                        is_top_parent = true
                    )
                )

                if is_top_parent then
                (
                    append top_parent_names scene_layer.name
                )
                else
                (
                    append other_layer_names scene_layer.name
                )
            )
        )
        catch
        (
        )
    )

    top_parent_names = ascSortLayerNamesAlphabetically top_parent_names
    other_layer_names = ascSortLayerNamesAlphabetically other_layer_names

    join ordered_names top_parent_names
    join ordered_names other_layer_names

    -- return
    ordered_names
)

/*
Gets every non-Default layer that begins directly at the scene's top hierarchy level.
The result is alphabetically sorted and is used when the source dropdown's blank item is selected.
*/
function ascGetTopLevelLayerNames =
(
    local top_level_names = #()
    local scene_layer = undefined
    local parent_layer = undefined

    for layer_index = 0 to (layerManager.count - 1) do
    (
        try
        (
            scene_layer = layerManager.getLayer layer_index

            if (scene_layer != undefined) and (scene_layer.name != "0") then
            (
                parent_layer = scene_layer.getParent()

                if (parent_layer == undefined) or (parent_layer.name == "0") then
                (
                    append top_level_names scene_layer.name
                )
            )
        )
        catch
        (
        )
    )

    top_level_names = ascSortLayerNamesAlphabetically top_level_names

    -- return
    top_level_names
)

/*
Returns whether one native scene layer has at least one child layer.
Missing or invalid layer references are treated as childless.
*/
function ascLayerHasChildren layer_name =
(
    local has_children = false
    local scene_layer = layerManager.getLayerFromName layer_name

    if scene_layer != undefined then
    (
        try
        (
            has_children = scene_layer.getNumChildren() > 0
        )
        catch
        (
            has_children = false
        )
    )

    -- return
    has_children
)

/*
Calculates the required content height for one dynamic parent-layer rollout subtree.
Leaf children contribute plain button rows while only child layers with children contribute nested rollout headers.
*/
function ascGetLayerRolloutContentHeight layer_name =
(
    local child_names = ascGetChildLayerNames layer_name
    local content_height = 46
    local child_slot_height = 0
    local leaf_button_count = 0

    for child_name in child_names do
    (
        if ascLayerHasChildren child_name then
        (
            child_slot_height += 24 + ascGetLayerRolloutContentHeight child_name
        )
        else
        (
            leaf_button_count += 1
        )
    )

    content_height += leaf_button_count * 38

    if child_slot_height > 0 then
    (
        content_height += 8 + child_slot_height
    )

    -- return
    content_height
)

/*
Restores every surviving layer to the visibility state captured before temporary isolation.
Layers created after isolation remain unchanged because they have no captured state.
*/
function ascRestoreTemporaryLayerVisibility =
(
    local restored_layer = undefined

    if asc_temporary_layer_isolate_active then
    (
        undo "Restore Temporary Layer Isolation" on
        (
            for snapshot_index = 1 to asc_temporary_layer_names.count do
            (
                restored_layer = layerManager.getLayerFromName asc_temporary_layer_names[snapshot_index]

                if restored_layer != undefined then
                (
                    try
                    (
                        restored_layer.isHidden = asc_temporary_layer_hidden_states[snapshot_index]
                    )
                    catch
                    (
                    )
                )
            )
        )

        asc_temporary_layer_names = #()
        asc_temporary_layer_hidden_states = #()
        asc_temporary_layer_isolate_active = false
        redrawViews()
    )

    -- return
    true
)

/*
Temporarily isolates one native layer and restores the previous visibility snapshot on the next use.
The action preserves the previous single-layer isolation behavior used by the original controls.
*/
function ascToggleTemporaryLayerIsolation layer_name =
(
    local target_layer = undefined
    local scene_layer = undefined
    local operation_ok = false

    if asc_temporary_layer_isolate_active then
    (
        operation_ok = ascRestoreTemporaryLayerVisibility()
    )
    else if (layer_name != undefined) and (layer_name != "") then
    (
        target_layer = layerManager.getLayerFromName layer_name

        if target_layer != undefined then
        (
            asc_temporary_layer_names = #()
            asc_temporary_layer_hidden_states = #()

            for layer_index = 0 to (layerManager.count - 1) do
            (
                scene_layer = layerManager.getLayer layer_index

                if scene_layer != undefined then
                (
                    append asc_temporary_layer_names scene_layer.name
                    append asc_temporary_layer_hidden_states scene_layer.isHidden
                )
            )

            undo "Temporary Layer Isolation" on
            (
                for layer_index = 0 to (layerManager.count - 1) do
                (
                    scene_layer = layerManager.getLayer layer_index

                    if scene_layer != undefined then
                    (
                        scene_layer.isHidden = (scene_layer.name != layer_name)
                    )
                )
            )

            asc_temporary_layer_isolate_active = true
            operation_ok = true
            redrawViews()
        )
        else
        (
            messageBox ("The layer no longer exists:\n" + layer_name + "\n\nRefresh the layer hierarchy.") title:"Arch Scene Cleaner"
        )
    )
    else
    (
        messageBox "Choose a target layer first." title:"Arch Scene Cleaner"
    )

    -- return
    operation_ok
)

/*
Handles the primary action for one generated layer rollout button.
The current visible selection is moved to the rollout's native layer.
*/
function ascHandleLayerButtonPressed layer_name =
(
    local operation_ok = ascMoveSelectionToLayer layer_name

    -- return
    operation_ok
)

global asc_layer_context_menu_target = ""

/*
Provides the layer actions exposed by CTRL + RMB.
The target layer is resolved from the shared menu target set immediately before the popup opens.
*/
rcmenu asc_layer_context_menu
(
    menuitem add_selection_menu_item "Add Selection to Layer"
    menuitem toggle_visibility_menu_item "Toggle Layer Visibility"
    menuitem temporary_isolate_menu_item "Temporary Isolate Layer"

    on add_selection_menu_item picked do
    (
        ascMoveSelectionToLayer asc_layer_context_menu_target
    )

    on toggle_visibility_menu_item picked do
    (
        ascToggleLayerVisibility asc_layer_context_menu_target
    )

    on temporary_isolate_menu_item picked do
    (
        ascToggleTemporaryLayerIsolation asc_layer_context_menu_target
    )
)

/*
Opens the native layer-action context menu for one target layer.
The popup path avoids creating another .NET menu object during repeated UI use.
*/
function ascShowLayerContextMenu layer_name =
(
    local operation_ok = false

    asc_layer_context_menu_target = layer_name

    try
    (
        popupMenu asc_layer_context_menu
        operation_ok = true
    )
    catch
    (
        operation_ok = false
    )

    -- return
    operation_ok
)

/*
Handles the secondary actions for one generated layer rollout button.
RMB toggles visibility, SHIFT + RMB toggles temporary isolation, and CTRL + RMB opens the layer-action menu.
*/
function ascHandleLayerButtonRightClick layer_name =
(
    local operation_ok = false

    if keyboard.controlPressed then
    (
        operation_ok = ascShowLayerContextMenu layer_name
    )
    else if keyboard.shiftPressed then
    (
        operation_ok = ascToggleTemporaryLayerIsolation layer_name
    )
    else
    (
        operation_ok = ascToggleLayerVisibility layer_name
    )

    -- return
    operation_ok
)

/*
Creates one rollout definition for one layer that owns child layers.
Leaf child layers are represented directly as buttons; only branches with children receive nested rollouts.
*/
function ascCreateLayerRolloutDefinition layer_name depth =
(
    local child_names = ascGetChildLayerNames layer_name
    local branch_child_names = #()
    local leaf_child_names = #()
    local child_slot_height = 0
    local rollout_width = amax #(160, 222 - (depth * 14))
    local control_width = amax #(144, rollout_width - 16)
    local rollout_name = ""
    local rollout_creator = undefined
    local control_parameters = ""
    local layer_name_index = 0
    local next_control_y = 46
    local leaf_control_index = 0
    local leaf_control_name = undefined
    local leaf_name_index = 0
    local handler_code = ""
    local open_handler_code = ""
    local rollout_stream = undefined

    for child_name in child_names do
    (
        if ascLayerHasChildren child_name then
        (
            append branch_child_names child_name
            child_slot_height += 24 + ascGetLayerRolloutContentHeight child_name
        )
        else
        (
            append leaf_child_names child_name
        )
    )

    asc_dynamic_layer_rollout_counter += 1
    rollout_name = "asc_dynamic_layer_rollout_" + (asc_dynamic_layer_rollout_counter as string)
    append asc_dynamic_layer_names layer_name
    layer_name_index = asc_dynamic_layer_names.count

    rollout_creator = rolloutCreator rollout_name (ascGetLayerDisplayName layer_name)
    rollout_creator.begin()
    rollout_creator.addLocal "layer_name_index" init:layer_name_index

    control_parameters = "pos:[8,8] width:" + (control_width as string) + " height:30"
    rollout_creator.addControl #dotNetControl #btn_add_selection "System.Windows.Forms.Button" paramStr:control_parameters
    handler_code = "(\nlocal mouse_button = event_args.Button.ToString()\nif mouse_button == \"Left\" then\n(\nascHandleLayerButtonPressed asc_dynamic_layer_names[layer_name_index]\n)\nelse if mouse_button == \"Right\" then\n(\nascHandleLayerButtonRightClick asc_dynamic_layer_names[layer_name_index]\n)\n)"
    rollout_creator.addHandler #btn_add_selection #MouseUp paramStr:"sender event_args" codeStr:handler_code

    open_handler_code = "btn_add_selection.Text = ascGetLayerDisplayName asc_dynamic_layer_names[layer_name_index]\n"
    open_handler_code += "ascApplyLayerButtonFont btn_add_selection\n"
    open_handler_code += "ascApplyLayerButtonStyle btn_add_selection\n"
    open_handler_code += "if asc_layer_button_tooltip != undefined then asc_layer_button_tooltip.SetToolTip btn_add_selection \"LMB: Add selection to this layer.\\n\\nRMB: Toggle layer visibility.\\n\\nSHIFT + RMB: Temporarily isolate this layer.\\n\\nCTRL + RMB: Open the layer actions menu.\"\n"

    for leaf_name in leaf_child_names do
    (
        leaf_control_index += 1
        leaf_control_name = (("btn_leaf_layer_" + (leaf_control_index as string)) as name)
        append asc_dynamic_layer_names leaf_name
        leaf_name_index = asc_dynamic_layer_names.count

        control_parameters = "pos:[8," + (next_control_y as string) + "] width:" + (control_width as string) + " height:30"
        rollout_creator.addControl #dotNetControl leaf_control_name "System.Windows.Forms.Button" paramStr:control_parameters

        handler_code = "(\nlocal mouse_button = event_args.Button.ToString()\nif mouse_button == \"Left\" then\n(\nascHandleLayerButtonPressed asc_dynamic_layer_names[" + (leaf_name_index as string) + "]\n)\nelse if mouse_button == \"Right\" then\n(\nascHandleLayerButtonRightClick asc_dynamic_layer_names[" + (leaf_name_index as string) + "]\n)\n)"
        rollout_creator.addHandler leaf_control_name #MouseUp paramStr:"sender event_args" codeStr:handler_code

        open_handler_code += (leaf_control_name as string) + ".Text = ascGetLayerDisplayName asc_dynamic_layer_names[" + (leaf_name_index as string) + "]\n"
        open_handler_code += "ascApplyLayerButtonFont " + (leaf_control_name as string) + "\n"
        open_handler_code += "ascApplyLayerButtonStyle " + (leaf_control_name as string) + "\n"
        open_handler_code += "if asc_layer_button_tooltip != undefined then asc_layer_button_tooltip.SetToolTip " + (leaf_control_name as string) + " \"LMB: Add selection to this layer.\\n\\nRMB: Toggle layer visibility.\\n\\nSHIFT + RMB: Temporarily isolate this layer.\\n\\nCTRL + RMB: Open the layer actions menu.\"\n"

        next_control_y += 38
    )

    if branch_child_names.count > 0 then
    (
        control_parameters = "pos:[8," + (next_control_y as string) + "] width:" + (control_width as string) + " height:" + (child_slot_height as string) + " scrollBar:#off"
        rollout_creator.addControl #subRollout #children_slot "" paramStr:control_parameters
    )

    rollout_creator.addText ("on " + rollout_name + " open do\n(\n" + open_handler_code + ")\n") filter:false

    rollout_stream = rollout_creator.end executeDefinition:false

    -- return
    execute rollout_stream
)

/*
Builds a recursive rollout tree beginning at one selected source layer.
Only branch children become child rollout trees; leaf children remain plain buttons in their parent rollout.
*/
function ascBuildLayerRolloutTree layer_name depth =
(
    local child_names = ascGetChildLayerNames layer_name
    local child_trees = #()
    local rollout_definition = ascCreateLayerRolloutDefinition layer_name depth

    for child_name in child_names do
    (
        if ascLayerHasChildren child_name then
        (
            append child_trees (ascBuildLayerRolloutTree child_name (depth + 1))
        )
    )

    -- return
    #(rollout_definition, child_trees, layer_name)
)

/*
Installs one recursive layer rollout tree into the supplied subrollout slot.
Child rollout trees are installed into the generated children slot of their parent rollout.
*/
function ascInstallLayerRolloutTree parent_slot rollout_tree =
(
    local rollout_definition = rollout_tree[1]
    local child_trees = rollout_tree[2]

    addSubRollout parent_slot rollout_definition rolledUp:false

    if child_trees.count > 0 then
    (
        for child_tree in child_trees do
        (
            ascInstallLayerRolloutTree rollout_definition.children_slot child_tree
        )
    )

    -- return
    true
)

/*
Removes one recursive layer rollout tree from its supplied subrollout slot.
Children are removed first so repeated hierarchy refreshes do not retain stale rollout instances.
*/
function ascRemoveLayerRolloutTree parent_slot rollout_tree =
(
    local rollout_definition = rollout_tree[1]
    local child_trees = rollout_tree[2]

    if child_trees.count > 0 then
    (
        for child_tree in child_trees do
        (
            try
            (
                ascRemoveLayerRolloutTree rollout_definition.children_slot child_tree
            )
            catch
            (
            )
        )
    )

    try
    (
        removeSubRollout parent_slot rollout_definition
    )
    catch
    (
    )

    -- return
    true
)

/*
Hosts the source selector, Default controls, and the dynamically generated layer hierarchy.
Every non-Default layer can be used as the root of the visible hierarchy.
*/
rollout asc_main_rollout "Object Layer Manager | v0.075" width:256 height:640
(
    local source_layer_names = #()
    local active_rollout_trees = #()
    local is_loading_source = false

    button btn_refresh_layers "Refresh Layers" width:116 height:32 across:2 tooltip:"LMB: Refresh the source list and rebuild the layer hierarchy."
    button btn_create_layer "Create" width:116 height:32 tooltip:"LMB: Create a new layer for all selected objects.\n\nThe new layer is nested under the layer containing most selected objects.\n\nThe name prompt starts with {Parent-Layer}-NEW."
    label lbl_source_layer "Source:" pos:[8,54] width:54 height:16 align:#left
    dropdownList ddl_source_layer "" pos:[66,46] width:182 items:#() tooltip:"Blank: show the hierarchy from the scene top level.\n\nNamed layer: show the hierarchy beginning at that layer."

    dotNetControl btn_add_default "System.Windows.Forms.Button" pos:[8,84] width:240 height:32

    subRollout hierarchy_slot "" pos:[8,122] width:240 height:470 scrollBar:#asNeeded
    button btn_restart "Restart" pos:[8,600] width:240 height:32 tooltip:"LMB: Reload Object Layer Manager."

    /*
    Resizes one installed dynamic rollout tree to the currently available hierarchy width.
    Button and nested-subrollout widths follow the parent while guarded assignments keep resize safe.
    */
    function resizeLayerRolloutTree rollout_tree available_width depth =
    (
        local rollout_definition = rollout_tree[1]
        local child_trees = rollout_tree[2]
        local rollout_width = amax #(96, available_width - (depth * 14))
        local control_width = amax #(80, rollout_width - 16)

        try(rollout_definition.width = rollout_width)catch()

        try
        (
            for control_item in rollout_definition.controls do
            (
                try(control_item.width = control_width)catch()
            )
        )
        catch
        (
        )

        for child_tree in child_trees do
        (
            resizeLayerRolloutTree child_tree available_width (depth + 1)
        )

        -- return
        true
    )

    /*
    Expands the hierarchy between the fixed header controls and the bottom Restart button.
    The dialog stays fixed at 256 px wide while vertical resize keeps Restart at the bottom.
    */
    function resizeHierarchySlot dialog_size =
    (
        local restart_y = amax #(200, dialog_size.y - 40)
        local available_height = amax #(60, restart_y - 130)
        local content_width = amax #(112, dialog_size.x - 16)
        local source_width = amax #(48, content_width - 58)

        ddl_source_layer.width = source_width
        btn_add_default.width = content_width
        hierarchy_slot.width = content_width
        hierarchy_slot.height = available_height
        btn_restart.pos = [8, restart_y]
        btn_restart.width = content_width

        for rollout_tree in active_rollout_trees do
        (
            resizeLayerRolloutTree rollout_tree content_width 0
        )

        -- return
        available_height
    )

    /*
    Gets the native source layer name selected in the top dropdown.
    An empty or out-of-range selection yields undefined.
    */
    function getSelectedSourceLayerName =
    (
        local selected_name = undefined
        local source_index = ddl_source_layer.selection - 1

        if (source_index > 0) and (source_index <= source_layer_names.count) then
        (
            selected_name = source_layer_names[source_index]
        )

        -- return
        selected_name
    )

    /*
    Removes the currently displayed dynamic layer hierarchy.
    The function is safe when no hierarchy is currently installed.
    */
    function clearLayerHierarchy =
    (
        for rollout_tree in active_rollout_trees do
        (
            ascRemoveLayerRolloutTree hierarchy_slot rollout_tree
        )

        active_rollout_trees = #()
        asc_dynamic_layer_names = #()

        -- return
        true
    )

    /*
    Rebuilds the dynamic hierarchy from the supplied native source layer name.
    An empty source displays every non-Default top-level layer as a root rollout.
    */
    function rebuildLayerHierarchy source_name =
    (
        local root_layer_names = #()
        local rollout_tree = undefined

        clearLayerHierarchy()

        if (source_name == undefined) or (source_name == "") then
        (
            root_layer_names = ascGetTopLevelLayerNames()
        )
        else if layerManager.getLayerFromName source_name != undefined then
        (
            append root_layer_names source_name
        )

        for root_layer_name in root_layer_names do
        (
            rollout_tree = ascBuildLayerRolloutTree root_layer_name 0
            append active_rollout_trees rollout_tree
            ascInstallLayerRolloutTree hierarchy_slot rollout_tree
        )

        try(resizeHierarchySlot (getDialogSize asc_main_rollout))catch()

        -- return
        active_rollout_trees
    )

    /*
    Repopulates the source dropdown while preserving a preferred native layer name when possible.
    The first blank item means the scene top level; named sources keep the existing ordered layer list.
    */
    function updateSourceLayerDropdown preferred_name =
    (
        local display_names = #()
        local dropdown_names = #("")
        local source_index = 0
        local selected_index = 1

        source_layer_names = ascGetSourceLayerNames()
        display_names = ascGetLayerDisplayNames source_layer_names
        join dropdown_names display_names
        ddl_source_layer.items = dropdown_names

        if (preferred_name != undefined) and (preferred_name != "") then
        (
            source_index = findItem source_layer_names preferred_name

            if source_index > 0 then
            (
                selected_index = source_index + 1
            )
        )

        ddl_source_layer.selection = selected_index

        -- return
        selected_index
    )

    /*
    Saves the currently selected source layer for the current scene.
    Empty source selections are stored as an empty string.
    */
    function saveSourceLayerSetting =
    (
        local source_name = getSelectedSourceLayerName()

        if source_name == undefined then
        (
            source_name = ""
        )

        -- return
        ascWriteSetting "SourceLayer" source_name
    )

    /*
    Refreshes the source list and rebuilds the visible hierarchy without changing a still-valid source.
    If the previous source disappeared, the blank scene-top-level entry becomes active.
    */
    function refreshLayerHierarchy =
    (
        local previous_source = getSelectedSourceLayerName()

        is_loading_source = true
        updateSourceLayerDropdown previous_source
        is_loading_source = false

        rebuildLayerHierarchy (getSelectedSourceLayerName())
        saveSourceLayerSetting()

        -- return
        true
    )

    /*
    Loads the stored source layer for the current scene and builds the initial hierarchy.
    Empty or missing stored layers use the blank scene-top-level source.
    */
    function loadLayerHierarchy =
    (
        local stored_source = ascReadSetting "SourceLayer" ""

        is_loading_source = true
        updateSourceLayerDropdown stored_source
        is_loading_source = false

        rebuildLayerHierarchy (getSelectedSourceLayerName())

        -- return
        true
    )

    on asc_main_rollout open do
    (
        btn_add_default.Text = "Default"

        ascApplyLayerButtonFont btn_add_default
        ascApplyLayerButtonStyle btn_add_default

        if asc_layer_button_tooltip != undefined then
        (
            asc_layer_button_tooltip.SetToolTip btn_add_default "LMB: Add selection to Default.\n\nRMB: Toggle Default layer visibility.\n\nSHIFT + RMB: Temporarily isolate Default.\n\nCTRL + RMB: Open the layer actions menu."
        )

        loadLayerHierarchy()

        try
        (
            resizeHierarchySlot (getDialogSize asc_main_rollout)
        )
        catch
        (
        )
    )

    on asc_main_rollout moved dialog_pos do
    (
        ascSaveDialogPosition dialog_pos
    )

    on asc_main_rollout resized dialog_size do
    (
        resizeHierarchySlot dialog_size
        ascSaveDialogHeight dialog_size.y
    )

    on asc_main_rollout close do
    (
        ascRestoreTemporaryLayerVisibility()
        asc_tool_dialog = undefined
        asc_tool_floater = undefined
    )

    on btn_refresh_layers pressed do
    (
        refreshLayerHierarchy()
    )

    on btn_create_layer pressed do
    (
        if ascCreateLayerForSelection() then
        (
            refreshLayerHierarchy()
        )
    )

    on btn_restart pressed do
    (
        local restart_path = asc_script_directory + "Object-Layer-Manager.ms"

        if doesFileExist restart_path then
        (
            fileIn restart_path quiet:true
        )
        else
        (
            messageBox ("Cannot restart. Missing script:\n" + restart_path) title:"Object Layer Manager"
        )
    )

    on ddl_source_layer selected selected_index do
    (
        if not is_loading_source then
        (
            rebuildLayerHierarchy (getSelectedSourceLayerName())
            saveSourceLayerSetting()
        )
    )

    on btn_add_default MouseUp sender event_args do
    (
        local mouse_button = event_args.Button.ToString()

        if mouse_button == "Left" then
        (
            ascHandleLayerButtonPressed "0"
        )
        else if mouse_button == "Right" then
        (
            ascHandleLayerButtonRightClick "0"
        )
    )
)

/*
Creates a compact scene for manually testing every cleaner operation.
It is never called automatically; run ascCreateTestScene() explicitly when desired.
*/
function ascCreateTestScene =
(
    local test_nodes = #()
    local target_layer = layerManager.getLayerFromName "ASC_Test_Target"
    local test_node = undefined

    undo "Create Arch Scene Cleaner Test Scene" on
    (
        if target_layer == undefined then
        (
            target_layer = layerManager.newLayerFromName "ASC_Test_Target"
        )

        test_node = box name:"ASC_Small_Fragment" length:0.25 width:0.35 height:0.15 pos:[-90, -50, 0]
        append test_nodes test_node

        test_node = box name:"ASC_Simple_Box" length:25 width:25 height:25 pos:[-45, -50, 12.5]
        append test_nodes test_node

        test_node = box name:"ASC_Thin_Wall" length:140 width:4 height:45 pos:[35, -50, 22.5]
        append test_nodes test_node

        test_node = box name:"ASC_Large_Orthogonal" length:80 width:70 height:60 pos:[-50, 35, 30]
        append test_nodes test_node

        test_node = sphere name:"ASC_High_Vertex_Sphere" radius:32 segments:32 pos:[45, 35, 32]
        append test_nodes test_node

        test_node = cone name:"ASC_Irregular_Angles" radius1:35 radius2:8 height:60 sides:7 capsegs:1 heightsegs:2 smooth:on pos:[120, 35, 0]
        append test_nodes test_node

        test_node = plane name:"ASC_Dense_Thin_Plane" length:55 width:55 lengthsegs:12 widthsegs:12 pos:[120, -50, 0]
        append test_nodes test_node

        select test_nodes
    )

    -- return
    test_nodes
)

asc_saved_dialog_position = ascGetSavedDialogPosition()
asc_saved_dialog_height = ascGetSavedDialogHeight()

if asc_saved_dialog_position != undefined then
(
    createDialog asc_main_rollout width:256 height:asc_saved_dialog_height pos:asc_saved_dialog_position style:#(#style_titlebar, #style_sysmenu, #style_resizing) lockWidth:true lockHeight:false
)
else
(
    createDialog asc_main_rollout width:256 height:asc_saved_dialog_height style:#(#style_titlebar, #style_sysmenu, #style_resizing) lockWidth:true lockHeight:false
)

asc_tool_dialog = asc_main_rollout

try
(
    cui.RegisterDialogBar asc_main_rollout minSize:[256,240] maxSize:[256,-1] style:#(#cui_dock_left, #cui_dock_right, #cui_floatable, #cui_handles)
)
catch
(
    format "Object Layer Manager: Could not register the window for left/right docking.\n"
)

