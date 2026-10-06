/*
    Select-By-Props
    Compact property-based selection tools for large imported architectural scenes.

    Left-click the vertex and size buttons to select values below the threshold.
    Right-click those buttons to select values above the threshold.
*/

global asc_tool_floater
global asc_file_version = "0.003"
global asc_project_version = "0.003"
global asc_camera_face_alignment_threshold = 0.95
global asc_tool_title = "Select-By-Props " + asc_project_version
global asc_source_path = getSourceFileName()
global asc_script_directory = getFilenamePath asc_source_path
global asc_saved_dialog_position

/*
Tests whether a filename suffix is a plain numeric version token.
Only digits and one optional decimal point are accepted.
*/
function ascIsVersionText version_text =
(
    local is_valid = version_text != ""
    local digit_count = 0
    local decimal_count = 0
    local character_value = ""

    if is_valid then
    (
        for character_index = 1 to version_text.count while is_valid do
        (
            character_value = substring version_text character_index 1

            if character_value == "." then
            (
                decimal_count += 1

                if decimal_count > 1 then
                (
                    is_valid = false
                )
            )
            else if (findString "0123456789" character_value) != undefined then
            (
                digit_count += 1
            )
            else
            (
                is_valid = false
            )
        )

        if digit_count == 0 then
        (
            is_valid = false
        )
    )

    -- return
    is_valid
)

/*
Finds the newest versioned script sharing the current filename prefix.
Only files whose suffix is a plain numeric version are eligible.
*/
function ascFindNewestVersionFile source_path =
(
    local newest_file = source_path
    local source_directory = ""
    local source_stem = ""
    local source_parts = #()
    local current_version_text = ""
    local version_prefix = ""
    local current_version = 0.0
    local newest_version = 0.0
    local candidate_files = #()
    local candidate_stem = ""
    local candidate_version_text = ""
    local candidate_version = 0.0

    if (source_path != undefined) and (source_path != "") then
    (
        source_directory = getFilenamePath source_path
        source_stem = getFilenameFile source_path
        source_parts = filterString source_stem "_"

        if source_parts.count >= 2 then
        (
            current_version_text = source_parts[source_parts.count]

            if ascIsVersionText current_version_text then
            (
                version_prefix = substring source_stem 1 (source_stem.count - current_version_text.count)
                current_version = current_version_text as float
                newest_version = current_version
                candidate_files = getFiles (source_directory + version_prefix + "*.ms")

                for candidate_file in candidate_files do
                (
                    candidate_stem = getFilenameFile candidate_file

                    if candidate_stem.count > version_prefix.count then
                    (
                        candidate_version_text = substring candidate_stem (version_prefix.count + 1) (candidate_stem.count - version_prefix.count)

                        if ascIsVersionText candidate_version_text then
                        (
                            candidate_version = candidate_version_text as float

                            if candidate_version > newest_version then
                            (
                                newest_version = candidate_version
                                newest_file = candidate_file
                            )
                        )
                    )
                )
            )
        )
    )

    -- return
    newest_file
)

/*
Reloads the newest matching versioned script beside the current source file.
When no newer version exists, the currently running script is loaded again.
*/
function ascRestartNewestVersion source_path:asc_source_path =
(
    local operation_ok = false
    local reload_path = ascFindNewestVersionFile source_path
    local exception_text = ""

    if (reload_path != undefined) and (reload_path != "") then
    (
        try
        (
            fileIn reload_path
            operation_ok = true
        )
        catch
        (
            exception_text = getCurrentException()
            format "Select-By-Props restart failed: %\n" exception_text
            operation_ok = false
        )
    )
    else
    (
        format "Select-By-Props restart failed: current script path is unavailable.\n"
    )

    -- return
    operation_ok
)

/*
Gets the INI file used by Select-By-Props.
The file lives beside the loaded Select-By-Props script source file.
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

    settings_path += "Select-By-Props.ini"

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
        messageBox "Enable at least one Select Similar option." title:"Select-By-Props"
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
            messageBox "Select one or more visible geometry reference objects first." title:"Select-By-Props"
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
Gets a world-to-view transform for face-normal comparison.
An active camera uses its inverse node transform; other 3D views use the viewport transform.
*/
function ascGetActiveFaceViewTM =
(
    local view_tm = undefined
    local active_camera = undefined
    local exception_text = ""

    try
    (
        active_camera = getActiveCamera()

        if active_camera != undefined then
        (
            view_tm = inverse active_camera.transform
        )
        else
        (
            view_tm = viewport.getTM()
        )

        if view_tm != undefined then
        (
            view_tm.row4 = [0,0,0]
        )
    )
    catch
    (
        exception_text = getCurrentException()
        format "Select-By-Props view transform failed: %\n" exception_text
        view_tm = undefined
    )

    -- return
    view_tm
)

/*
Computes one polygon normal from ordered world-space vertex positions.
Newell accumulation supports triangles, quads, and higher-order polygon faces.
*/
function ascGetPolygonNormalFromPositions vertex_positions =
(
    local polygon_normal = [0.0,0.0,0.0]
    local current_position = undefined
    local next_position = undefined
    local next_index = 0

    if vertex_positions.count >= 3 then
    (
        for vertex_index = 1 to vertex_positions.count do
        (
            next_index = vertex_index + 1

            if next_index > vertex_positions.count then
            (
                next_index = 1
            )

            current_position = vertex_positions[vertex_index]
            next_position = vertex_positions[next_index]

            polygon_normal.x += (current_position.y - next_position.y) * (current_position.z + next_position.z)
            polygon_normal.y += (current_position.z - next_position.z) * (current_position.x + next_position.x)
            polygon_normal.z += (current_position.x - next_position.x) * (current_position.y + next_position.y)
        )
    )

    if (length polygon_normal) > 0.0 then
    (
        polygon_normal = normalize polygon_normal
    )

    -- return
    polygon_normal
)

/*
Tests whether one polygon normal is tightly aligned with the active camera or viewport.
The alignment threshold is a cosine value where 1.0 is exactly toward the view.
*/
function ascFaceNormalMatchesView face_normal view_tm alignment_threshold:asc_camera_face_alignment_threshold =
(
    local matches_view = false
    local normalized_face_normal = [0.0,0.0,0.0]
    local view_normal = [0.0,0.0,0.0]
    local view_normal_length = 0.0
    local normal_alignment = -1.0

    if (view_tm != undefined) and ((length face_normal) > 0.0) then
    (
        normalized_face_normal = normalize face_normal
        view_normal = normalized_face_normal * view_tm
        view_normal_length = length view_normal

        if view_normal_length > 0.0 then
        (
            normal_alignment = view_normal.z / view_normal_length
            matches_view = normal_alignment >= alignment_threshold
        )
    )

    -- return
    matches_view
)

/*
Builds the face BitArray whose polygon normals closely match the active camera or viewport direction.
Edit Poly geometry is read at modifier level; Editable Poly geometry is read from its base object.
*/
function ascGetCameraFacingFaceSelection scene_node view_tm =
(
    local face_selection = #{}
    local edit_poly_modifier = ascFindTopEditPolyModifier scene_node
    local face_count = 0
    local face_degree = 0
    local face_vertices = undefined
    local vertex_positions = #()
    local vertex_index = 0
    local vertex_position = undefined
    local object_tm = undefined
    local face_normal = undefined
    local exception_text = ""

    if (view_tm != undefined) and (ascIsVisibleGeometry scene_node) then
    (
        try
        (
            if edit_poly_modifier != undefined then
            (
                object_tm = edit_poly_modifier.GetNodeTM node:scene_node
                face_count = edit_poly_modifier.GetNumFaces node:scene_node

                for face_index = 1 to face_count do
                (
                    vertex_positions = #()
                    face_degree = edit_poly_modifier.GetFaceDegree face_index node:scene_node

                    for corner_index = 1 to face_degree do
                    (
                        vertex_index = edit_poly_modifier.GetFaceVertex face_index corner_index node:scene_node
                        vertex_position = edit_poly_modifier.GetVertex vertex_index node:scene_node
                        append vertex_positions (vertex_position * object_tm)
                    )

                    face_normal = ascGetPolygonNormalFromPositions vertex_positions

                    if ascFaceNormalMatchesView face_normal view_tm then
                    (
                        face_selection[face_index] = true
                    )
                )
            )
            else if classOf scene_node.baseObject == Editable_Poly then
            (
                object_tm = scene_node.objectTransform
                face_count = polyop.getNumFaces scene_node.baseObject

                for face_index = 1 to face_count do
                (
                    vertex_positions = #()
                    face_vertices = polyop.getFaceVerts scene_node.baseObject face_index

                    for vertex_index in face_vertices do
                    (
                        vertex_position = polyop.getVert scene_node.baseObject vertex_index
                        append vertex_positions (vertex_position * object_tm)
                    )

                    face_normal = ascGetPolygonNormalFromPositions vertex_positions

                    if ascFaceNormalMatchesView face_normal view_tm then
                    (
                        face_selection[face_index] = true
                    )
                )
            )
        )
        catch
        (
            exception_text = getCurrentException()
            format "Select-By-Props camera-facing face detection failed on %: %\n" scene_node.name exception_text
            face_selection = #{}
        )
    )

    -- return
    face_selection
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
Applies a face selection through Edit Poly when present or Editable Poly directly.
Both supported Poly contexts keep their cage display disabled.
*/
function ascApplyFaceSelection scene_node face_selection =
(
    local operation_ok = false
    local edit_poly_modifier = ascFindTopEditPolyModifier scene_node
    local stored_selection = #{}
    local exception_text = ""

    if edit_poly_modifier != undefined then
    (
        try
        (
            edit_poly_modifier.showCage = off
            operation_ok = edit_poly_modifier.SetSelection #Face face_selection node:scene_node

            if operation_ok then
            (
                edit_poly_modifier.SetEPolySelLevel #Face
                stored_selection = edit_poly_modifier.GetSelection #Face node:scene_node
                operation_ok = stored_selection == face_selection
            )
        )
        catch
        (
            exception_text = getCurrentException()
            format "Select-By-Props Edit Poly face selection failed on %: %\n" scene_node.name exception_text
            operation_ok = false
        )
    )
    else if classOf scene_node.baseObject == Editable_Poly then
    (
        try
        (
            scene_node.baseObject.showCage = off
            polyop.setFaceSelection scene_node face_selection
            stored_selection = polyop.getFaceSelection scene_node
            operation_ok = stored_selection == face_selection
        )
        catch
        (
            exception_text = getCurrentException()
            format "Select-By-Props Editable Poly face selection failed on %: %\n" scene_node.name exception_text
            operation_ok = false
        )
    )

    -- return
    operation_ok
)

/*
Selects matching polygon faces on the current visible Editable Poly or Edit Poly objects.
Camera-facing mode evaluates the current mesh against one active-view transform.
*/
function ascSelectFaces selection_kind =
(
    local processed_nodes = #()
    local face_selection = #{}
    local edit_poly_modifier = undefined
    local has_supported_poly = false
    local view_tm = undefined

    if selection_kind == #cameraFacing then
    (
        view_tm = ascGetActiveFaceViewTM()
    )

    if (selection_kind != #cameraFacing) or (view_tm != undefined) then
    (
        for scene_node in (selection as array) do
        (
            if ascIsVisibleGeometry scene_node then
            (
                edit_poly_modifier = ascFindTopEditPolyModifier scene_node

                if selection_kind == #cameraFacing then
                (
                    has_supported_poly = (edit_poly_modifier != undefined) or (classOf scene_node.baseObject == Editable_Poly)
                )
                else
                (
                    has_supported_poly = classOf scene_node.baseObject == Editable_Poly
                )

                if has_supported_poly then
                (
                    if selection_kind == #cameraFacing then
                    (
                        face_selection = ascGetCameraFacingFaceSelection scene_node view_tm
                    )
                    else if classOf scene_node.baseObject == Editable_Poly then
                    (
                        face_selection = ascGetMatchingFaceSelection scene_node selection_kind
                    )
                    else
                    (
                        face_selection = #{}
                    )

                    if ascApplyFaceSelection scene_node face_selection then
                    (
                        append processed_nodes scene_node
                    )
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
            local exception_text = getCurrentException()
            format "Select-By-Props could not enter polygon sub-object mode: %\n" exception_text
        )
    )
    else
    (
        if (selection_kind == #cameraFacing) and (view_tm == undefined) then
        (
            messageBox "The active camera or viewport does not provide a usable 3D view transform." title:"Select-By-Props"
        )
        else
        (
            messageBox "Select one or more visible Editable Poly objects, or objects with an Edit Poly modifier, first." title:"Select-By-Props"
        )
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
                            format "Select-By-Props: could not move node '%' to layer '%'.\n" scene_node.name layer_name
                        )
                    )
                )

                operation_ok = true
            )
            else
            (
                messageBox "Select one or more visible scene objects first." title:"Select-By-Props"
            )
        )
        else
        (
            messageBox ("The layer no longer exists:\n" + layer_name + "\n\nRefresh the layer lists and choose another layer.") title:"Select-By-Props"
        )
    )
    else
    (
        messageBox "Choose a target layer first." title:"Select-By-Props"
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
                messageBox ("The layer visibility could not be changed:\n" + layer_name) title:"Select-By-Props"
            )
        )
        else
        (
            messageBox ("The layer no longer exists:\n" + layer_name + "\n\nRefresh the layer lists and choose another layer.") title:"Select-By-Props"
        )
    )
    else
    (
        messageBox "Choose a target layer first." title:"Select-By-Props"
    )

    -- return
    operation_ok
)

rollout asc_selection_rollout "Selection" width:270
(
    local is_loading_settings = false
    local current_size_unit = "m"

    groupBox grp_prepare "PREPARE GEOMETRY" pos:[4, 6] width:262 height:92
    button btn_convert_to_poly "Convert to Editable Poly" pos:[18, 27] width:244 height:33 tooltip:"Convert selected visible geometry, or all visible geometry when nothing is selected, to Editable Poly."
    button btn_weld_vertices "Weld Vertices" pos:[18, 62] width:109 height:33 tooltip:"Convert when needed and weld all vertices on selected visible geometry, or all visible geometry when nothing is selected."
    spinner spn_weld_threshold "Threshold:" pos:[134, 70] width:128 range:[0.0, 1000000.0, 0.01] type:#float scale:0.001 fieldWidth:55 tooltip:"Maximum vertex distance to weld, measured in current system units."

    groupBox grp_vertex "Select by Vertex Count" pos:[4, 104] width:262 height:62
    spinner spn_vertex_threshold "Threshold:" pos:[134, 131] width:128 range:[0, 100000000, 100] type:#integer fieldWidth:55 tooltip:"Vertex-count threshold; a selected reference can replace this value."
    button btn_vertex_select "Select  <  /  >" pos:[18, 123] width:109 height:33 tooltip:"Left-click: below. Right-click: above. Ctrl+Left-click: copy the lowest selected vertex count into Threshold without changing selection."

    groupBox grp_size "Select by SIZE" pos:[4, 172] width:262 height:62
    button btn_size_select "Select  <  /  >" pos:[18, 191] width:91 height:33 tooltip:"Left-click: below. Right-click: above. Ctrl+Left-click: copy the lowest selected largest bounding-box edge into Threshold without changing selection."
    spinner spn_size_threshold "Threshold:" pos:[114, 199] width:96 range:[0.0, 1000000000.0, 1.0] type:#float scale:0.1 fieldWidth:43 tooltip:"Largest local bounding-box edge expressed in the unit selected beside it."
    dropdownList ddl_size_units "" pos:[214, 197] width:48 items:#("mm", "cm", "m") selection:3 tooltip:"Display unit for the size threshold; changing it preserves the physical distance."

    groupBox grp_bbox "Select by BBOX" pos:[4, 240] width:262 height:92
    spinner spn_bbox_ratio "Ratio  1 :" pos:[18, 263] width:116 range:[1, 100, 4] type:#integer fieldWidth:44 tooltip:"Shape ratio used by Flat, Tall, and Long. A value of 4 means a 1:4 threshold."
    button btn_select_flat "Flat" pos:[18, 291] width:55 height:33 tooltip:"Select visible objects whose local Z height is at most 1 divided by the chosen Ratio of their largest XY edge."
    button btn_select_tall "Tall" pos:[81, 291] width:55 height:33 tooltip:"Select visible objects whose local Z height is at least the chosen Ratio times their largest XY edge."
    button btn_select_long "Long" pos:[144, 291] width:55 height:33 tooltip:"Select visible objects whose oriented horizontal length is at least the chosen Ratio times their oriented width."
    button btn_select_box "Box" pos:[207, 291] width:55 height:33 tooltip:"Select visible objects whose largest local bounding-box edge is no more than 1.5 times the smallest."

    groupBox grp_complexity "Complexity" pos:[4, 338] width:262 height:120
    spinner spn_complexity_edges "Edges to sample:" pos:[18, 360] width:138 range:[5, 1000, 20] type:#integer fieldWidth:35 tooltip:"Maximum number of distributed non-coplanar internal edges tested per uncached object."
    spinner spn_complexity_tolerance "Tolerance:" pos:[160, 360] width:102 range:[0.0, 45.0, 5.0] type:#float scale:0.5 fieldWidth:38 tooltip:"Degrees allowed around square or folded-back corners (90 and 180). Coplanar triangulation edges are ignored."
    spinner spn_non_orthogonal_threshold "Non-orthogonal %:" pos:[18, 388] width:150 range:[0.0, 100.0, 50.0] type:#float scale:1.0 fieldWidth:40 tooltip:"Minimum percentage of sampled internal edges that must be non-orthogonal."
    checkbox chk_complexity_find_similar "Find similar" pos:[176, 388] width:86 checked:true tooltip:"Reuse results for likely mesh copies with matching topology counts and bounding-box proportions."
    button btn_select_complex "Select Complex" pos:[18, 417] width:244 height:33 tooltip:"Left-click: select complex geometry. Right-click: show scores and sample diagnostics for the current selection."

    groupBox grp_similar "Select Similar" pos:[4, 464] width:262 height:92
    checkbox chk_similar_vertices "Vertex Count" pos:[18, 486] width:82 checked:true tooltip:"Require candidates to match the evaluated vertex count."
    checkbox chk_similar_faces "Face Count" pos:[102, 486] width:72 checked:false tooltip:"Require candidates to match the evaluated face count."
    checkbox chk_similar_wirecolor "Wirecolor" pos:[178, 486] width:76 checked:false tooltip:"Require candidates to match the exact object wirecolor."
    button btn_select_similar "Select Similar" pos:[18, 515] width:244 height:33 tooltip:"Select visible geometry matching every enabled property of any currently selected reference object."

    groupBox grp_select_faces "Select Faces" pos:[4, 562] width:262 height:100
    button btn_non_planar_faces "non PLANAR" pos:[18, 583] width:118 height:33 tooltip:"Select geometrically non-planar polygon faces on the current visible Editable Poly objects."
    button btn_ngon_faces "N-GONS" pos:[144, 583] width:118 height:33 tooltip:"Select polygon faces with more than four vertices on the current visible Editable Poly objects."
    button btn_camera_facing_faces "FACING CAMERA" pos:[18, 621] width:244 height:33 tooltip:"Select polygon faces whose normal/view alignment is at least 0.95, keeping only faces strongly aimed toward the active camera or viewport."

    button btn_restart "Restart" pos:[18, 670] width:244 height:24 tooltip:"LMB: Load the newest matching version of this tool, or reload the current version."

    /*
    Gets the currently selected readable size unit suffix.
    Invalid dropdown state falls back to meters for a stable physical conversion.
    */
    function getSelectedSizeUnitName =
    (
        local unit_name = "m"

        if (ddl_size_units.selection > 0) and (ddl_size_units.selection <= ddl_size_units.items.count) then
        (
            unit_name = ddl_size_units.items[ddl_size_units.selection]
        )

        -- return
        unit_name
    )
    /*
    Saves all selection controls for the current scene section.
    Numeric values are stored as strings through the native INI API.
    */
    function saveSelectionSettings =
    (
        ascWriteSetting "WeldThreshold" spn_weld_threshold.value
        ascWriteSetting "VertexThreshold" spn_vertex_threshold.value
        current_size_unit = getSelectedSizeUnitName()
        ascWriteSetting "SizeThreshold" (ascDisplayValueToSystem spn_size_threshold.value current_size_unit)
        ascWriteSetting "SizeThresholdDisplay" spn_size_threshold.value
        ascWriteSetting "SizeThresholdUnit" current_size_unit
        ascWriteSetting "BboxShapeRatio" spn_bbox_ratio.value
        ascWriteSetting "ComplexityEdgeSamples" spn_complexity_edges.value
        ascWriteSetting "ComplexityAngleTolerance" spn_complexity_tolerance.value
        ascWriteSetting "ComplexityThreshold" spn_non_orthogonal_threshold.value

        if chk_complexity_find_similar.checked then
        (
            ascWriteSetting "ComplexityFindSimilar" "1"
        )
        else
        (
            ascWriteSetting "ComplexityFindSimilar" "0"
        )

        if chk_similar_vertices.checked then
        (
            ascWriteSetting "SimilarVertexCount" "1"
        )
        else
        (
            ascWriteSetting "SimilarVertexCount" "0"
        )

        if chk_similar_faces.checked then
        (
            ascWriteSetting "SimilarFaceCount" "1"
        )
        else
        (
            ascWriteSetting "SimilarFaceCount" "0"
        )

        if chk_similar_wirecolor.checked then
        (
            ascWriteSetting "SimilarWirecolor" "1"
        )
        else
        (
            ascWriteSetting "SimilarWirecolor" "0"
        )

        -- return
        true
    )

    /*
    Loads all selection controls from the current scene section.
    Invalid stored values fail safely and leave the corresponding UI default unchanged.
    */
    function loadSelectionSettings =
    (
        local stored_size_unit = ascReadSetting "SizeThresholdUnit" "m"
        local stored_size_unit_index = findItem ddl_size_units.items stored_size_unit
        local stored_size_display = ascReadSetting "SizeThresholdDisplay" ""
        local stored_size_system = ""

        is_loading_settings = true

        if stored_size_unit_index == 0 then
        (
            stored_size_unit_index = 3
        )

        ddl_size_units.selection = stored_size_unit_index
        current_size_unit = getSelectedSizeUnitName()

        try
        (
            spn_weld_threshold.value = (ascReadSetting "WeldThreshold" (spn_weld_threshold.value as string)) as float
        )
        catch
        (
        )

        try
        (
            spn_vertex_threshold.value = (ascReadSetting "VertexThreshold" (spn_vertex_threshold.value as string)) as integer
        )
        catch
        (
        )

        try
        (
            if stored_size_display != "" then
            (
                spn_size_threshold.value = stored_size_display as float
            )
            else
            (
                stored_size_system = ascReadSetting "SizeThreshold" ((ascDisplayValueToSystem spn_size_threshold.value current_size_unit) as string)
                spn_size_threshold.value = ascSystemValueToDisplay (stored_size_system as float) current_size_unit
            )
        )
        catch
        (
        )

        try
        (
            spn_bbox_ratio.value = ((ascReadSetting "BboxShapeRatio" (spn_bbox_ratio.value as string)) as float) as integer
        )
        catch
        (
        )

        try
        (
            spn_complexity_edges.value = (ascReadSetting "ComplexityEdgeSamples" (spn_complexity_edges.value as string)) as integer
        )
        catch
        (
        )

        try
        (
            spn_complexity_tolerance.value = (ascReadSetting "ComplexityAngleTolerance" (spn_complexity_tolerance.value as string)) as float
        )
        catch
        (
        )

        try
        (
            spn_non_orthogonal_threshold.value = (ascReadSetting "ComplexityThreshold" (spn_non_orthogonal_threshold.value as string)) as float
        )
        catch
        (
        )

        chk_complexity_find_similar.checked = (ascReadSetting "ComplexityFindSimilar" "1") == "1"

        chk_similar_vertices.checked = (ascReadSetting "SimilarVertexCount" "1") == "1"
        chk_similar_faces.checked = (ascReadSetting "SimilarFaceCount" "0") == "1"
        chk_similar_wirecolor.checked = (ascReadSetting "SimilarWirecolor" "0") == "1"

        is_loading_settings = false

        -- return
        true
    )

    on asc_selection_rollout open do
    (
        loadSelectionSettings()
    )

    on asc_selection_rollout moved dialog_position do
    (
        ascSaveDialogPosition dialog_position
    )

    on spn_weld_threshold changed spinner_value do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on spn_vertex_threshold changed spinner_value do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on spn_size_threshold changed spinner_value do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on ddl_size_units selected selected_index do
    (
        local system_threshold = ascDisplayValueToSystem spn_size_threshold.value current_size_unit
        local selected_size_unit = getSelectedSizeUnitName()

        current_size_unit = selected_size_unit

        if not is_loading_settings then
        (
            spn_size_threshold.value = ascSystemValueToDisplay system_threshold current_size_unit
            saveSelectionSettings()
        )
    )
    on spn_bbox_ratio changed spinner_value do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on spn_complexity_edges changed spinner_value do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on spn_complexity_tolerance changed spinner_value do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on spn_non_orthogonal_threshold changed spinner_value do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on chk_complexity_find_similar changed checked_state do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on chk_similar_vertices changed checked_state do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on chk_similar_faces changed checked_state do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on chk_similar_wirecolor changed checked_state do
    (
        if not is_loading_settings then
        (
            saveSelectionSettings()
        )
    )

    on btn_convert_to_poly pressed do
    (
        ascConvertPreparationGeometry()
    )

    on btn_weld_vertices pressed do
    (
        ascWeldPreparationGeometry spn_weld_threshold.value
    )

    on btn_vertex_select pressed do
    (
        if keyboard.controlPressed then
        (
            spn_vertex_threshold.value = ascResolveReferenceThreshold #vertexCount true spn_vertex_threshold.value
        )
        else
        (
            spn_vertex_threshold.value = ascSelectByNumericThreshold #vertexCount spn_vertex_threshold.value true
        )

        saveSelectionSettings()
    )

    on btn_vertex_select rightClick do
    (
        spn_vertex_threshold.value = ascSelectByNumericThreshold #vertexCount spn_vertex_threshold.value false
        saveSelectionSettings()
    )

    on btn_size_select pressed do
    (
        local system_threshold = ascDisplayValueToSystem spn_size_threshold.value current_size_unit

        if keyboard.controlPressed then
        (
            system_threshold = ascResolveReferenceThreshold #largestDimension true system_threshold
        )
        else
        (
            system_threshold = ascSelectByNumericThreshold #largestDimension system_threshold true
        )

        spn_size_threshold.value = ascSystemValueToDisplay system_threshold current_size_unit
        saveSelectionSettings()
    )

    on btn_size_select rightClick do
    (
        local system_threshold = ascDisplayValueToSystem spn_size_threshold.value current_size_unit
        system_threshold = ascSelectByNumericThreshold #largestDimension system_threshold false
        spn_size_threshold.value = ascSystemValueToDisplay system_threshold current_size_unit
        saveSelectionSettings()
    )

    on btn_select_flat pressed do
    (
        ascSelectBySizeShape #flat spn_bbox_ratio.value
    )

    on btn_select_tall pressed do
    (
        ascSelectBySizeShape #tall spn_bbox_ratio.value
    )

    on btn_select_long pressed do
    (
        ascSelectBySizeShape #long spn_bbox_ratio.value
    )

    on btn_select_box pressed do
    (
        ascSelectBySizeShape #box spn_bbox_ratio.value
    )

    on btn_select_complex pressed do
    (
        ascSelectComplexGeometry spn_complexity_edges.value spn_complexity_tolerance.value spn_non_orthogonal_threshold.value chk_complexity_find_similar.checked
    )

    on btn_select_complex rightClick do
    (
        ascReportSelectedComplexity spn_complexity_edges.value spn_complexity_tolerance.value spn_non_orthogonal_threshold.value
    )

    on btn_select_similar pressed do
    (
        ascSelectSimilar chk_similar_vertices.checked chk_similar_faces.checked chk_similar_wirecolor.checked
    )

    on btn_non_planar_faces pressed do
    (
        ascSelectFaces #nonPlanar
    )

    on btn_ngon_faces pressed do
    (
        ascSelectFaces #ngons
    )

    on btn_camera_facing_faces pressed do
    (
        ascSelectFaces #cameraFacing
    )

    on btn_restart pressed do
    (
        ascRestartNewestVersion()
    )
)

/*
Creates a compact scene for manually testing every Select-By-Props operation.
It is never called automatically; run ascCreateTestScene() explicitly when desired.
*/
function ascCreateTestScene =
(
    local test_nodes = #()
    local target_layer = layerManager.getLayerFromName "ASC_Test_Target"
    local test_node = undefined

    undo "Create Select-By-Props Test Scene" on
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

try
(
    closeRolloutFloater asc_tool_floater
)
catch
(
)

asc_tool_floater = newRolloutFloater asc_tool_title 290 730
addRollout asc_selection_rollout asc_tool_floater rolledUp:false

asc_saved_dialog_position = ascGetSavedDialogPosition()

if asc_saved_dialog_position != undefined then
(
    try
    (
        asc_tool_floater.pos = asc_saved_dialog_position
    )
    catch
    (
    )
)

