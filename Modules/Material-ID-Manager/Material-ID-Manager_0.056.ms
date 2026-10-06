/* Material-ID-Manager_0.056.ms
   File version: 0.056
   Project version: 0.056
*/

global material_id_manager_project_version
global material_id_manager_file_version = 0.056
global material_id_manager_stored_project_version = 0.056
global material_id_manager_rollout_title
global material_id_manager_source_path = getSourceFileName()
global material_id_manager_lmb_log_path
global material_id_manager_volume_dump_path
global material_id_manager_dump_module_path
global material_id_manager_volume_dump
global DumpDevLoggerStruct
global material_id_manager_ini_path
global materialIdManagerCore
global materialIdManagerSettings
global materialIdManagerRollout
global materialIdManagerIdsRollout
global materialIdManagerMaterialSetupRollout
global materialIdManagerEditMeshRollout
global materialIdManagerSelectFacesRollout
global materialIdManagerPresetNameRollout
global material_id_manager_preset_name_value
global material_id_manager_preset_name_accepted = false
global asc_camera_face_alignment_threshold = 0.95

if material_id_manager_source_path != undefined and material_id_manager_source_path != "" then
(
    material_id_manager_lmb_log_path = (getFilenamePath material_id_manager_source_path) + "logs\\Material-ID-Manager-LMB.txt"
    material_id_manager_volume_dump_path = (getFilenamePath material_id_manager_source_path) + "logs\\Material-ID-Manager-Volume-Select-DUMP.txt"
    material_id_manager_dump_module_path = (getFilenamePath material_id_manager_source_path) + "..\\DUMP\\DUMP.ms"
    material_id_manager_ini_path = (getFilenamePath material_id_manager_source_path) + "Material-ID-Manager.ini"
)
else
(
    material_id_manager_ini_path = (getDir #plugcfg) + "\\Material-ID-Manager.ini"
)

if material_id_manager_project_version == undefined or material_id_manager_stored_project_version > material_id_manager_project_version then
(
    material_id_manager_project_version = material_id_manager_stored_project_version
)

material_id_manager_rollout_title = "Material ID Manager | v" + (formattedPrint material_id_manager_project_version format:".3f")

if DumpDevLoggerStruct == undefined then
(
    if material_id_manager_dump_module_path != undefined and doesFileExist material_id_manager_dump_module_path then
    (
        fileIn material_id_manager_dump_module_path
    )
    else
    (
        format "Material ID Manager DUMP: shared DUMP module not found: %\n" material_id_manager_dump_module_path
    )
)

if DumpDevLoggerStruct != undefined and material_id_manager_volume_dump_path != undefined then
(
    material_id_manager_volume_dump = DumpDevLoggerStruct()

    if not (material_id_manager_volume_dump.start material_id_manager_volume_dump_path) then
    (
        format "Material ID Manager DUMP: could not initialize Volume Select dump at %\n" material_id_manager_volume_dump_path
    )
)

/* Returns whether a scene node is valid visible geometry.
   Hidden or invalid nodes return false.
*/
function ascIsVisibleGeometry scene_node =
(
    is_candidate = false

    if isValidNode scene_node and superClassOf scene_node == GeometryClass then
    (
        is_candidate = not scene_node.isHidden
    )

    is_candidate -- return
)

/* Finds the topmost Edit Poly modifier on a scene node.
   Returns undefined when no Edit Poly modifier exists.
*/
function ascFindTopEditPolyModifier scene_node =
(
    edit_poly_mod = undefined

    if isValidNode scene_node then
    (
        for modifier_index = 1 to scene_node.modifiers.count while edit_poly_mod == undefined do
        (
            if classOf scene_node.modifiers[modifier_index] == Edit_Poly then
            (
                edit_poly_mod = scene_node.modifiers[modifier_index]
            )
        )
    )

    edit_poly_mod -- return
)

/* Gets the world-to-view transform used for normal comparison.
   An active camera is preferred; otherwise the active viewport is used.
*/
function ascGetActiveFaceViewTM =
(
    view_tm = undefined
    active_camera = undefined

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
        format "Camera face view transform failed: %\n" exception_text
        view_tm = undefined
    )

    view_tm -- return
)

/* Computes a polygon normal from ordered world-space positions.
   Newell accumulation works with triangles, quads, and N-gons.
*/
function ascGetPolygonNormalFromPositions vertex_positions =
(
    polygon_normal = [0.0,0.0,0.0]
    current_position = undefined
    next_position = undefined
    next_index = 0

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

    polygon_normal -- return
)

/* Tests whether a face normal tightly matches the current view direction.
   The threshold is cosine alignment where 1.0 means directly toward the camera.
*/
function ascFaceNormalMatchesView face_normal view_tm alignment_threshold:asc_camera_face_alignment_threshold =
(
    matches_view = false
    normalized_face_normal = [0.0,0.0,0.0]
    view_normal = [0.0,0.0,0.0]
    view_normal_length = 0.0
    normal_alignment = -1.0

    if view_tm != undefined and (length face_normal) > 0.0 then
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

    matches_view -- return
)

/* Gets polygon faces whose normals tightly match the supplied camera or viewport transform.
   Returns a face BitArray on success and undefined when a native topology read fails.
*/
function ascGetCameraFacingFaceSelection scene_node view_tm =
(
    face_selection = #{}
    edit_poly_mod = ascFindTopEditPolyModifier scene_node
    face_count = 0
    face_degree = 0
    face_vertices = undefined
    vertex_positions = #()
    vertex_index = 0
    vertex_position = undefined
    object_tm = undefined
    face_normal = undefined

    if view_tm != undefined and ascIsVisibleGeometry scene_node then
    (
        try
        (
            if edit_poly_mod != undefined then
            (
                object_tm = edit_poly_mod.GetNodeTM node:scene_node
                face_count = edit_poly_mod.GetNumFaces node:scene_node

                for face_index = 1 to face_count do
                (
                    vertex_positions = #()
                    face_degree = edit_poly_mod.GetFaceDegree face_index node:scene_node

                    for corner_index = 1 to face_degree do
                    (
                        vertex_index = edit_poly_mod.GetFaceVertex face_index corner_index node:scene_node
                        vertex_position = edit_poly_mod.GetVertex vertex_index node:scene_node
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
            local exception_text = getCurrentException()
            format "Camera-facing face detection failed on %: %\n" scene_node.name exception_text
            face_selection = undefined
        )
    )

    face_selection -- return
)

/* Stores and restores the small amount of persistent UI state used by the tool.
   Geometry and modifier operations are intentionally kept out of this struct.
*/
struct materialIdManagerSettings_v
(
    /* Read the last saved dialog position from the tool INI file.
       Invalid or missing values return undefined so createDialog can use its default position.
    */
    function loadDialogPosition =
    (
        x_text = getINISetting material_id_manager_ini_path "Dialog" "X"
        y_text = getINISetting material_id_manager_ini_path "Dialog" "Y"
        dialog_pos = undefined

        if x_text != "" and y_text != "" then
        (
            x_value = try(x_text as integer)catch(undefined)
            y_value = try(y_text as integer)catch(undefined)

            if x_value != undefined and y_value != undefined then
            (
                dialog_pos = [x_value, y_value]
            )
        )

        dialog_pos -- return
    ),

    /* Save one dialog position to the tool INI file.
       Returns true only when both coordinates were written successfully.
    */
    function saveDialogPosition dialog_pos =
    (
        result_value = false

        if dialog_pos != undefined then
        (
            x_result = setINISetting material_id_manager_ini_path "Dialog" "X" (dialog_pos.x as string)
            y_result = setINISetting material_id_manager_ini_path "Dialog" "Y" (dialog_pos.y as string)
            result_value = x_result and y_result
        )

        result_value -- return
    ),

    /* Read the last valid dialog height.
       Heights below the minimum usable layout return undefined.
    */
    function loadDialogHeight =
    (
        height_text = getINISetting material_id_manager_ini_path "Dialog" "Height"
        height_value = undefined

        if height_text != "" then
        (
            parsed_height = try(height_text as integer)catch(undefined)

            if parsed_height != undefined and parsed_height >= 1206 then
            (
                height_value = parsed_height
            )
        )

        height_value -- return
    ),

    /* Save one valid vertically resizable dialog height.
       Returns false for heights that would hide required controls.
    */
    function saveDialogHeight dialog_height =
    (
        result_value = false

        if dialog_height != undefined and dialog_height >= 1206 then
        (
            result_value = setINISetting material_id_manager_ini_path "Dialog" "Height" (dialog_height as string)
        )

        result_value -- return
    ),

    /* Create the first-run Material Setup defaults beside the running script.
       Existing INI files are never overwritten, so later user edits remain authoritative.
    */
    function initializeIniDefaults =
    (
        result_value = true

        if not (doesFileExist material_id_manager_ini_path) then
        (
            default_rows = #(
                #("LEVELS", "1|2|3|4"),
                #("WALLS", "INT|EXT|L|R|F|B"),
                #("BALCONY", "INT|EXT"),
                #("", "FLOOR|CEILING")
            )

            for set_index = 1 to default_rows.count while result_value do
            (
                set_number = if set_index < 10 then ("0" + (set_index as string)) else (set_index as string)
                name_key = "Set_" + set_number + "_Name"
                suffix_key = "Set_" + set_number + "_Suffixes"
                defined_key = "Set_" + set_number + "_Defined"

                name_result = setINISetting material_id_manager_ini_path "Material Setup" name_key default_rows[set_index][1]
                suffix_result = setINISetting material_id_manager_ini_path "Material Setup" suffix_key default_rows[set_index][2]
                defined_result = setINISetting material_id_manager_ini_path "Material Setup" defined_key "1"
                result_value = name_result and suffix_result and defined_result
            )
        )

        result_value -- return
    ),

    /* Return the maximum number of Material ID Set rows supported by Material Setup.
       Four seeded rows plus ten appendable rows provide fourteen persistent configuration rows.
    */
    function getMaterialIdSetCount =
    (
        14 -- return
    ),

    /* Return the number of persisted Material ID Set rows that should be visible.
       Defined rows are appended sequentially; older four-row INI files remain four rows until the user adds more.
    */
    function getVisibleMaterialIdSetCount =
    (
        visible_count = 0
        set_count = getMaterialIdSetCount()

        for set_index = 1 to set_count do
        (
            set_number = if set_index < 10 then ("0" + (set_index as string)) else (set_index as string)
            defined_key = "Set_" + set_number + "_Defined"

            if (getINISetting material_id_manager_ini_path "Material Setup" defined_key) == "1" then
            (
                visible_count = set_index
            )
        )

        if visible_count < 4 then
        (
            visible_count = 4
        )

        visible_count -- return
    ),

    /* Return the maximum Material ID count exposed by the tool.
       Twenty-four IDs preserve the existing 14 seeded IDs and allow all ten appendable setup rows to add one name-only material.
    */
    function getMaxMaterialIdCount =
    (
        24 -- return
    ),

    /* Return the fallback base name for a missing row in an existing INI file.
       First-run defaults are created separately by initializeIniDefaults.
    */
    function getDefaultMaterialIdSetName set_index =
    (
        "" -- return
    ),

    /* Return the fallback suffix list for a missing row in an existing INI file.
       First-run defaults are created separately by initializeIniDefaults.
    */
    function getDefaultMaterialIdSetSuffixes set_index =
    (
        "" -- return
    ),

    /* Test whether one persisted row exactly matches a built-in row written by older tool versions.
       These historical defaults are treated as unset unless the row has since been saved explicitly by the user.
    */
    function isLegacyHardcodedMaterialIdSetRow set_index set_name suffix_text =
    (
        is_legacy_default = false

        case set_index of
        (
            1: is_legacy_default = (set_name == "WALL" and suffix_text == "INT|EXT|L|R|F|B")
            2: is_legacy_default = (set_name == "" and suffix_text == "FLOOR|CEILING")
            3: is_legacy_default = (set_name == "BALCONY" and suffix_text == "EXT|INT")
            4: is_legacy_default = (set_name == "" and suffix_text == "")
            default: is_legacy_default = false
        )

        is_legacy_default -- return
    ),

    /* Load one persisted Material ID Set row.
       First-run rows come from the seeded INI; later edits and migrated custom values persist exactly.
    */
    function loadMaterialIdSetRow set_index =
    (
        row_data = undefined
        set_count = getMaterialIdSetCount()

        if classOf set_index == Integer and set_index >= 1 and set_index <= set_count then
        (
            set_number = if set_index < 10 then ("0" + (set_index as string)) else (set_index as string)
            defined_key = "Set_" + set_number + "_Defined"
            user_defined_key = "Set_" + set_number + "_UserDefined"
            name_key = "Set_" + set_number + "_Name"
            suffix_key = "Set_" + set_number + "_Suffixes"
            set_name = getINISetting material_id_manager_ini_path "Material Setup" name_key
            suffix_text = getINISetting material_id_manager_ini_path "Material Setup" suffix_key
            is_user_defined = (getINISetting material_id_manager_ini_path "Material Setup" user_defined_key) == "1"

            if not is_user_defined then
            (
                has_stored_value = (set_name != "" or suffix_text != "")
                is_legacy_default = isLegacyHardcodedMaterialIdSetRow set_index set_name suffix_text

                if has_stored_value and not is_legacy_default then
                (
                    setINISetting material_id_manager_ini_path "Material Setup" user_defined_key "1"
                )
                else
                (
                    set_name = getDefaultMaterialIdSetName set_index
                    suffix_text = getDefaultMaterialIdSetSuffixes set_index
                    setINISetting material_id_manager_ini_path "Material Setup" name_key set_name
                    setINISetting material_id_manager_ini_path "Material Setup" suffix_key suffix_text
                )
            )

            setINISetting material_id_manager_ini_path "Material Setup" defined_key "1"
            row_data = #(set_name, suffix_text)
        )

        row_data -- return
    ),

    /* Save one complete Material ID Set row.
       Blank base names and blank suffix lists are stored exactly as entered and marked as explicit user values.
    */
    function saveMaterialIdSetRow set_index set_name suffix_text =
    (
        result_value = false
        set_count = getMaterialIdSetCount()

        if classOf set_index == Integer and set_index >= 1 and set_index <= set_count and classOf set_name == String and classOf suffix_text == String then
        (
            set_number = if set_index < 10 then ("0" + (set_index as string)) else (set_index as string)
            defined_key = "Set_" + set_number + "_Defined"
            user_defined_key = "Set_" + set_number + "_UserDefined"
            name_key = "Set_" + set_number + "_Name"
            suffix_key = "Set_" + set_number + "_Suffixes"
            stored_name = trimRight (trimLeft set_name)
            stored_suffixes = trimRight (trimLeft suffix_text)

            name_result = setINISetting material_id_manager_ini_path "Material Setup" name_key stored_name
            suffix_result = setINISetting material_id_manager_ini_path "Material Setup" suffix_key stored_suffixes
            defined_result = setINISetting material_id_manager_ini_path "Material Setup" defined_key "1"
            user_defined_result = setINISetting material_id_manager_ini_path "Material Setup" user_defined_key "1"
            result_value = name_result and suffix_result and defined_result and user_defined_result
        )

        result_value -- return
    ),

    /* Append one new blank Material ID Set row to the persisted setup.
       Returns the new 1-based row index, or zero when the row capacity is already reached or persistence fails.
    */
    function appendMaterialIdSetRow =
    (
        new_row_index = 0
        visible_count = getVisibleMaterialIdSetCount()
        set_count = getMaterialIdSetCount()

        if visible_count < set_count then
        (
            candidate_index = visible_count + 1

            if saveMaterialIdSetRow candidate_index "" "" then
            (
                new_row_index = candidate_index
            )
        )

        new_row_index -- return
    ),

    /* Load the generated diffuse-color saturation percentage.
       Invalid persisted values are reported and replaced by the 65 percent default.
    */
    function loadDiffuseSaturation =
    (
        saturation_text = getINISetting material_id_manager_ini_path "Material Setup" "Diffuse Saturation"
        saturation_value = 65

        if saturation_text != "" then
        (
            parsed_saturation = undefined

            try
            (
                parsed_saturation = saturation_text as integer
            )
            catch
            (
                saturation_exception = getCurrentException()
                format "Material ID Manager saturation setting parse failed: %\n" saturation_exception
            )

            if parsed_saturation != undefined and parsed_saturation >= 1 and parsed_saturation <= 100 then
            (
                saturation_value = parsed_saturation
            )
            else
            (
                setINISetting material_id_manager_ini_path "Material Setup" "Diffuse Saturation" "65"
            )
        )
        else
        (
            setINISetting material_id_manager_ini_path "Material Setup" "Diffuse Saturation" "65"
        )

        saturation_value -- return
    ),

    /* Save one diffuse-color saturation percentage.
       Values from 1 through 100 preserve unique hue colors across all generated materials.
    */
    function saveDiffuseSaturation saturation_value =
    (
        result_value = false

        if classOf saturation_value == Integer and saturation_value >= 1 and saturation_value <= 100 then
        (
            result_value = setINISetting material_id_manager_ini_path "Material Setup" "Diffuse Saturation" (saturation_value as string)
        )

        result_value -- return
    ),

    /* Return the default semantic label for one Material ID row.
       Fresh Material ID rows intentionally start blank; semantic names come only from persisted user settings.
    */
    function getDefaultMaterialName material_id =
    (
        "" -- return
    ),

    /* Return labels that older tool versions wrote automatically.
       When no explicit user-defined marker exists, these historical defaults are treated as unset.
    */
    function getLegacyMaterialNames material_id =
    (
        legacy_names = #("Material " + (material_id as string))

        case material_id of
        (
            1: legacy_names = #("Material 1", "Walls", "Walls L", "Walls INT")
            2: legacy_names = #("Material 2", "Walls", "Walls R", "Walls EXT")
            3: legacy_names = #("Material 3", "Walls", "Walls F", "Walls L")
            4: legacy_names = #("Material 4", "Floors", "Walls B", "Walls R")
            5: legacy_names = #("Material 5", "Ceiling", "Floors", "Walls F")
            6: legacy_names = #("Material 6", "Balcony Exterior", "Ceiling", "Walls B")
            7: legacy_names = #("Material 7", "Balcony Interior", "Balcony Exterior", "Floors")
            8: legacy_names = #("Material 8", "Balcony Interior", "Ceiling")
            9: legacy_names = #("Material 9", "Balcony Exterior")
            10: legacy_names = #("Material 10", "Balcony Interior")
            default: legacy_names
        )

        legacy_names -- return
    ),

    /* Load one persisted semantic Material ID label.
       Fresh rows stay blank; custom older values migrate once and future explicit edits are loaded exactly, including blanks.
    */
    function loadMaterialName material_id =
    (
        key_text = "ID_" + (if material_id < 10 then ("0" + (material_id as string)) else (material_id as string))
        user_defined_key = key_text + "_UserDefined"
        name_text = getINISetting material_id_manager_ini_path "Material Names" key_text
        is_user_defined = (getINISetting material_id_manager_ini_path "Material Names" user_defined_key) == "1"

        if not is_user_defined then
        (
            legacy_names = getLegacyMaterialNames material_id

            if name_text != "" and findItem legacy_names name_text == 0 then
            (
                setINISetting material_id_manager_ini_path "Material Names" user_defined_key "1"
            )
            else
            (
                name_text = getDefaultMaterialName material_id
                setINISetting material_id_manager_ini_path "Material Names" key_text name_text
            )
        )

        name_text -- return
    ),

    /* Save one semantic Material ID label to the tool INI file.
       Empty text is a valid explicit user value and is persisted without substituting a built-in name.
    */
    function saveMaterialName material_id name_text =
    (
        key_text = "ID_" + (if material_id < 10 then ("0" + (material_id as string)) else (material_id as string))
        user_defined_key = key_text + "_UserDefined"
        name_result = setINISetting material_id_manager_ini_path "Material Names" key_text name_text
        user_defined_result = setINISetting material_id_manager_ini_path "Material Names" user_defined_key "1"
        (name_result and user_defined_result) -- return
    ),

    /* Return the Material Select preset INI path tied to the current saved .max scene.
       Unsaved scenes return undefined so presets cannot drift away from their owning scene.
    */
    function getSceneMaterialSelectPresetIniPath =
    (
        preset_ini_path = undefined

        if maxFileName != undefined and maxFileName != "" and maxFilePath != undefined and maxFilePath != "" then
        (
            preset_ini_path = maxFilePath + (getFilenameFile maxFileName) + ".Material-ID-Manager.ini"
        )

        preset_ini_path -- return
    ),

    /* Return all Material Select preset section names from one scene-local preset INI file.
       Each INI section is one preset, so no additional metadata section is mixed into the dropdown.
    */
    function getMaterialSelectPresetNames preset_ini_path:undefined =
    (
        preset_names = #()
        resolved_ini_path = preset_ini_path

        if resolved_ini_path == undefined then
        (
            resolved_ini_path = getSceneMaterialSelectPresetIniPath()
        )

        if resolved_ini_path != undefined and doesFileExist resolved_ini_path then
        (
            preset_names = getINISetting resolved_ini_path
            sort preset_names
        )

        preset_names -- return
    ),

    /* Test whether one exact preset section exists in the resolved scene-local preset INI.
       Blank preset names and unsaved scenes return false.
    */
    function hasMaterialSelectPreset preset_name preset_ini_path:undefined =
    (
        result_value = false
        resolved_ini_path = preset_ini_path

        if resolved_ini_path == undefined then
        (
            resolved_ini_path = getSceneMaterialSelectPresetIniPath()
        )

        if resolved_ini_path != undefined and classOf preset_name == String and preset_name != "" then
        (
            result_value = hasINISetting resolved_ini_path preset_name
        )

        result_value -- return
    ),

    /* Delete one complete Material Select preset section from the scene-local preset INI.
       Returns false when the preset does not exist or the scene has no valid preset INI path.
    */
    function deleteMaterialSelectPreset preset_name preset_ini_path:undefined =
    (
        result_value = false
        resolved_ini_path = preset_ini_path

        if resolved_ini_path == undefined then
        (
            resolved_ini_path = getSceneMaterialSelectPresetIniPath()
        )

        if resolved_ini_path != undefined and classOf preset_name == String and preset_name != "" and hasINISetting resolved_ini_path preset_name then
        (
            delINISetting resolved_ini_path preset_name
            result_value = not (hasINISetting resolved_ini_path preset_name)
        )

        result_value -- return
    ),

    on create do
    (
        if not (initializeIniDefaults()) then
        (
            format "Material ID Manager first-run INI initialization failed: %\n" material_id_manager_ini_path
        )
    )
)

materialIdManagerSettings = materialIdManagerSettings_v()

/* Resolves Editable Poly / Edit Poly context and assigns material IDs.
   Public entry point: materialIdManagerCore.assignMaterialId <1..65535>.
*/
struct materialIdManagerCore_v
(
    last_message = "Ready.",
    volume_add_in_progress = false,
    volume_debug_enabled = false,
    volume_debug_active = false,

    /* Store one status message for the rollout and Listener.
       Returns the same text for convenient caller chaining.
    */
    function setMessage message_text =
    (
        last_message = message_text
        format "Material ID Manager: %\n" message_text
        message_text -- return
    ),

    /* Initialize the Material-button LMB diagnostic log for this tool run.
       The log is stored in the repository-local logs folder beside the running script.
    */
    function initializeMaterialLmbLog =
    (
        result_value = false

        if material_id_manager_lmb_log_path != undefined and material_id_manager_lmb_log_path != "" then
        (
            log_dir = getFilenamePath material_id_manager_lmb_log_path

            if log_dir != "" and not (doesDirectoryExist log_dir) then
            (
                makeDir log_dir all:true
            )

            if log_dir == "" or doesDirectoryExist log_dir then
            (
                log_stream = createFile material_id_manager_lmb_log_path encoding:#utf8 writeBOM:false

                if log_stream != undefined then
                (
                    close log_stream
                    result_value = true
                )
            )
        )

        result_value -- return
    ),

    /* Append one Material-button LMB diagnostic line to both Listener and the log file.
       Logging failure never changes the Material ID operation result.
    */
    function writeMaterialLmbLog message_text =
    (
        result_value = false
        log_text = message_text as string

        if material_id_manager_lmb_log_path != undefined and material_id_manager_lmb_log_path != "" then
        (
            log_dir = getFilenamePath material_id_manager_lmb_log_path

            if log_dir != "" and not (doesDirectoryExist log_dir) then
            (
                makeDir log_dir all:true
            )

            if log_dir == "" or doesDirectoryExist log_dir then
            (
                log_stream = openFile material_id_manager_lmb_log_path mode:"a" encoding:#utf8 writeBOM:false

                if log_stream != undefined then
                (
                    format "Material ID Manager LMB: %\n" log_text
                    format "%\n" log_text to:log_stream
                    close log_stream
                    result_value = true
                )
            )
        )

        result_value -- return
    ),

    /* Format one value for Volume Select diagnostic output.
       The label includes the class and name when a name property is available.
    */
    function getVolumeSelectDebugValueLabel debug_value =
    (
        label_text = "<undefined>"

        if debug_value != undefined then
        (
            label_text = (classOf debug_value) as string

            if isProperty debug_value #name then
            (
                value_name_text = debug_value.name as string

                if value_name_text != "" then
                (
                    label_text += " \"" + value_name_text + "\""
                )
            )
        )

        label_text -- return
    ),

    /* Write one Volume Select diagnostic line through the shared DUMP logger.
       Logging is diagnostic only and never changes the modifier operation result.
    */
    function writeVolumeSelectDebugLog message_text =
    (
        result_value = false

        if volume_debug_active and material_id_manager_volume_dump != undefined then
        (
            result_value = material_id_manager_volume_dump.log message_text
        )

        result_value -- return
    ),

    /* Write one formatted snapshot of the Modify panel and live modifier stack.
       The snapshot records current object, subobject level, base object, and each modifier instance.
    */
    function logVolumeSelectDebugStage stage_number stage_name target_node:undefined =
    (
        result_value = false

        if volume_debug_active then
        (
            current_object = undefined
            panel_mode = getCommandPanelTaskMode()
            current_object_error = ""

            if panel_mode == #modify then
            (
                try
                (
                    current_object = modPanel.getCurrentObject()
                )
                catch
                (
                    current_object_error = getCurrentException()
                )
            )

            writeVolumeSelectDebugLog "----------------------------------------------------------------"
            writeVolumeSelectDebugLog ("VOL SELECT STAGE " + (stage_number as string) + " | " + stage_name)
            writeVolumeSelectDebugLog ("panel mode       : " + (panel_mode as string))
            writeVolumeSelectDebugLog ("subObjectLevel   : " + (subObjectLevel as string))
            writeVolumeSelectDebugLog ("selection.count  : " + (selection.count as string))
            writeVolumeSelectDebugLog ("add in progress  : " + (volume_add_in_progress as string))
            writeVolumeSelectDebugLog ("current object   : " + (getVolumeSelectDebugValueLabel current_object))

            if current_object_error != "" then
            (
                writeVolumeSelectDebugLog ("current read ERR : " + current_object_error)
            )

            if isValidNode target_node then
            (
                writeVolumeSelectDebugLog ("target node      : " + target_node.name)
                writeVolumeSelectDebugLog ("base object      : " + (getVolumeSelectDebugValueLabel target_node.baseObject))
                writeVolumeSelectDebugLog ("modifier count   : " + (target_node.modifiers.count as string))

                if target_node.modifiers.count == 0 then
                (
                    writeVolumeSelectDebugLog "stack            : <no modifiers>"
                )
                else
                (
                    for modifier_index = 1 to target_node.modifiers.count do
                    (
                        stack_mod = target_node.modifiers[modifier_index]
                        current_marker = if stack_mod == current_object then " <CURRENT>" else ""
                        writeVolumeSelectDebugLog ("stack[" + (modifier_index as string) + "]         : " + (getVolumeSelectDebugValueLabel stack_mod) + current_marker)
                    )
                )
            )
            else
            (
                writeVolumeSelectDebugLog "target node      : <undefined or invalid>"
            )

            result_value = true
        )

        result_value -- return
    ),
    /* Start an opt-in Volume Select diagnostic trace when development logging is explicitly enabled.
       Normal Material Select Set creation remains silent and does not write or print debug stages.
    */
    function beginVolumeSelectDebug target_node:undefined source_context:undefined source_face_bits:undefined =
    (
        result_value = false

        volume_debug_active = false

        if volume_debug_enabled and material_id_manager_volume_dump != undefined then
        (
            volume_debug_active = true
            material_id_manager_volume_dump.clear()
            writeVolumeSelectDebugLog "================================================================"
            writeVolumeSelectDebugLog "MATERIAL ID MANAGER | VOLUME SELECT LMB DEBUG"
            writeVolumeSelectDebugLog ("project version   : " + (formattedPrint material_id_manager_project_version format:".3f"))

            if source_context != undefined and source_context.count > 0 then
            (
                writeVolumeSelectDebugLog ("source context    : " + (source_context[1] as string))
            )

            if source_face_bits != undefined then
            (
                writeVolumeSelectDebugLog ("source face count : " + (source_face_bits.numberSet as string))
                writeVolumeSelectDebugLog ("source faces      : " + (source_face_bits as string))
            )

            result_value = logVolumeSelectDebugStage 0 "BEGIN addVolumeSelect" target_node:target_node
        )

        result_value -- return
    ),

    /* Finish the extended Volume Select LMB diagnostic trace after rollout refresh work.
       The last stage captures the final Modify-panel state seen by the user after the callback completes.
    */
    function finishVolumeSelectDebug target_node:undefined =
    (
        result_value = false

        if volume_debug_active then
        (
            result_value = logVolumeSelectDebugStage 40 "END OF Volume Select LMB CALLBACK" target_node:target_node
            writeVolumeSelectDebugLog "================================================================"
        )

        volume_debug_active = false
        result_value -- return
    ),

    /* Test whether one Edit Poly modifier belongs to the supplied node.
       Returns false for undefined values or unrelated modifier instances.
    */
    function isEditPolyOnNode target_node edit_poly_mod =
    (
        result_value = false

        if isValidNode target_node and edit_poly_mod != undefined and classOf edit_poly_mod == Edit_Poly then
        (
            for stack_mod in target_node.modifiers do
            (
                if stack_mod == edit_poly_mod then
                (
                    result_value = true
                )
            )
        )

        result_value -- return
    ),

    /* Test whether the node contains any Edit Poly modifier.
       Used to avoid silently editing the base Editable Poly when an Edit Poly stack exists.
    */
    function hasEditPolyModifier target_node =
    (
        result_value = false

        if isValidNode target_node then
        (
            for stack_mod in target_node.modifiers do
            (
                if classOf stack_mod == Edit_Poly then
                (
                    result_value = true
                )
            )
        )

        result_value -- return
    ),

    /* Resolve the exact geometry owner that the Material ID operation should modify.
       Active Edit Poly / Editable Poly stack items win; otherwise only a plain Editable Poly base is accepted.
    */
    function resolveContext =
    (
        context_data = #(#none, undefined, undefined)

        if selection.count != 1 then
        (
            setMessage "Select exactly one Editable Poly or Edit Poly object."
        )
        else
        (
            target_node = selection[1]

            if not isValidNode target_node then
            (
                setMessage "The selected node is not valid."
            )
            else
            (
                current_object = undefined

                if getCommandPanelTaskMode() == #modify then
                (
                    current_object = modPanel.getCurrentObject()
                )

                if current_object != undefined and classOf current_object == Edit_Poly and isEditPolyOnNode target_node current_object then
                (
                    context_data = #(#edit_poly, target_node, current_object)
                )
                else if current_object != undefined and classOf current_object == Editable_Poly and current_object == target_node.baseObject then
                (
                    context_data = #(#editable_poly, target_node, current_object)
                )
                else if classOf target_node.baseObject == Editable_Poly and not (hasEditPolyModifier target_node) then
                (
                    context_data = #(#editable_poly, target_node, target_node.baseObject)
                )
                else if hasEditPolyModifier target_node then
                (
                    setMessage "Make the target Edit Poly modifier current in the Modify panel."
                )
                else
                (
                    setMessage "The selected object is not Editable Poly and has no active Edit Poly modifier."
                )
            )
        )

        context_data -- return
    ),

    /* Return the active 3ds Max sub-object level for the resolved stack item.
       Object level is returned when the target is not currently open in the Modify panel.
    */
    function getCurrentSubObjectLevel context_data =
    (
        context_kind = context_data[1]
        target_node = context_data[2]
        current_object = context_data[3]
        level_number = 0

        if context_kind != #none and getCommandPanelTaskMode() == #modify and modPanel.getCurrentObject() == current_object then
        (
            if context_kind == #edit_poly then
            (
                if isEditPolyOnNode target_node current_object then
                (
                    if subObjectLevel != undefined then
                    (
                        level_number = subObjectLevel
                    )
                )
            )
            else if context_kind == #editable_poly and current_object == target_node.baseObject then
            (
                if subObjectLevel != undefined then
                (
                    level_number = subObjectLevel
                )
            )
        )

        level_number -- return
    ),

    /* Build a BitArray containing every face of one Editable Poly node.
       Returns an empty BitArray when the object has no faces.
    */
    function getAllEditablePolyFaces target_node =
    (
        face_bits = #{}
        face_count = polyop.getNumFaces target_node

        for face_id = 1 to face_count do
        (
            face_bits[face_id] = true
        )

        face_bits -- return
    ),

    /* Resolve the Editable Poly faces affected by the current sub-object selection.
       Vertex and edge/border levels expand to all faces touching the selected components.
    */
    function getEditablePolyTargetFaces target_node level_number =
    (
        face_bits = #{}

        case level_number of
        (
            0:
            (
                face_bits = getAllEditablePolyFaces target_node
            )
            1:
            (
                vertex_bits = polyop.getVertSelection target_node
                face_bits = polyop.getFacesUsingVert target_node vertex_bits
            )
            2:
            (
                edge_bits = polyop.getEdgeSelection target_node
                face_bits = polyop.getFacesUsingEdge target_node edge_bits
            )
            3:
            (
                edge_bits = polyop.getEdgeSelection target_node
                face_bits = polyop.getFacesUsingEdge target_node edge_bits
            )
            4:
            (
                face_bits = polyop.getFaceSelection target_node
            )
            5:
            (
                face_bits = polyop.getFaceSelection target_node
            )
            default:
            (
                face_bits = #{}
            )
        )

        face_bits -- return
    ),

    /* Build a BitArray containing every face exposed by one Edit Poly modifier instance.
       The node argument keeps instanced Edit Poly modifiers bound to the intended object.
    */
    function getAllEditPolyFaces target_node edit_poly_mod =
    (
        face_bits = #{}
        face_count = edit_poly_mod.GetNumFaces node:target_node

        for face_id = 1 to face_count do
        (
            face_bits[face_id] = true
        )

        face_bits -- return
    ),

    /* Convert an Edit Poly vertex selection to all faces touching those vertices.
       Uses the modifier's own topology so no temporary mesh face indexes are transferred.
    */
    function getEditPolyFacesUsingVertices target_node edit_poly_mod vertex_bits =
    (
        face_bits = #{}

        for vertex_id in vertex_bits do
        (
            face_count = edit_poly_mod.GetVertexFaceCount vertex_id node:target_node

            for face_offset = 1 to face_count do
            (
                face_id = edit_poly_mod.GetVertexFace vertex_id face_offset node:target_node

                if face_id > 0 then
                (
                    face_bits[face_id] = true
                )
            )
        )

        face_bits -- return
    ),

    /* Convert an Edit Poly edge or border selection to all adjacent faces.
       Border edges contribute only their valid face side because the other side returns zero.
    */
    function getEditPolyFacesUsingEdges target_node edit_poly_mod edge_bits =
    (
        face_bits = #{}

        for edge_id in edge_bits do
        (
            face_a = edit_poly_mod.GetEdgeFace edge_id 1 node:target_node
            face_b = edit_poly_mod.GetEdgeFace edge_id 2 node:target_node

            if face_a > 0 then
            (
                face_bits[face_a] = true
            )

            if face_b > 0 then
            (
                face_bits[face_b] = true
            )
        )

        face_bits -- return
    ),

    /* Resolve the Edit Poly faces affected by the current sub-object selection.
       Face and Element levels reuse the modifier's stored face selection directly.
    */
    function getEditPolyTargetFaces target_node edit_poly_mod level_number =
    (
        face_bits = #{}

        case level_number of
        (
            0:
            (
                face_bits = getAllEditPolyFaces target_node edit_poly_mod
            )
            1:
            (
                vertex_bits = edit_poly_mod.GetSelection #Vertex node:target_node
                face_bits = getEditPolyFacesUsingVertices target_node edit_poly_mod vertex_bits
            )
            2:
            (
                edge_bits = edit_poly_mod.GetSelection #Edge node:target_node
                face_bits = getEditPolyFacesUsingEdges target_node edit_poly_mod edge_bits
            )
            3:
            (
                edge_bits = edit_poly_mod.GetSelection #Edge node:target_node
                face_bits = getEditPolyFacesUsingEdges target_node edit_poly_mod edge_bits
            )
            4:
            (
                face_bits = edit_poly_mod.GetSelection #Face node:target_node
            )
            5:
            (
                face_bits = edit_poly_mod.GetSelection #Face node:target_node
            )
            default:
            (
                face_bits = #{}
            )
        )

        face_bits -- return
    ),

    /* Verify that every requested Editable Poly face contains the requested one-based Material ID.
       Returns false immediately when any face does not match.
    */
    function verifyEditablePolyMaterialId target_node face_bits material_id =
    (
        result_value = true

        for face_id in face_bits while result_value do
        (
            result_value = (polyop.getFaceMatID target_node face_id == material_id)
        )

        result_value -- return
    ),

    /* Verify that every requested Edit Poly face contains the requested one-based Material ID.
       Edit Poly exposes its Material-ID parameter and face data zero-based, so one is added for comparison.
    */
    function verifyEditPolyMaterialId target_node edit_poly_mod face_bits material_id =
    (
        result_value = true

        for face_id in face_bits while result_value do
        (
            stored_material_id = edit_poly_mod.GetFaceMaterial face_id node:target_node
            result_value = ((stored_material_id + 1) == material_id)
        )

        result_value -- return
    ),

    /* Assign one Material ID directly to selected Editable Poly faces without changing the user's selection.
       The operation is verified against every affected face before success is reported.
    */
    function assignEditablePolyMaterialId target_node editable_poly_obj face_bits material_id =
    (
        result_value = false

        if face_bits.numberSet == 0 then
        (
            setMessage "No faces belong to the current selection."
        )
        else
        (
            editable_poly_obj.showCage = off
            polyop.setFaceMatID target_node face_bits material_id
            result_value = verifyEditablePolyMaterialId target_node face_bits material_id

            if result_value then
            (
                setMessage ("Assigned Material ID " + (material_id as string) + " to " + (face_bits.numberSet as string) + " face(s).")
            )
            else
            (
                setMessage "Editable Poly Material ID verification failed."
            )
        )

        result_value -- return
    ),

    /* Restore the Edit Poly state changed temporarily by a Material ID operation.
       Face selection, Material-ID parameter, selection mode, stack-selection mode, and sub-object level are restored.
    */
    function restoreEditPolyState target_node edit_poly_mod old_face_selection old_material_id old_select_mode old_use_stack_selection old_epoly_level old_subobject_level =
    (
        restore_faces = (old_face_selection as array) as bitarray
        edit_poly_mod.SetEPolySelLevel #Face
        subObjectLevel = 4
        selection_restored = edit_poly_mod.SetSelection #Face restore_faces node:target_node
        edit_poly_mod.materialIDToSet = old_material_id
        edit_poly_mod.selectMode = old_select_mode
        edit_poly_mod.useStackSelection = old_use_stack_selection
        edit_poly_mod.SetEPolySelLevel old_epoly_level

        if old_subobject_level != undefined then
        (
            subObjectLevel = old_subobject_level
        )

        selection_restored -- return
    ),

    /* Assign one Material ID through the active Edit Poly modifier and restore its previous editing state.
       Uses the committed Edit Poly Set Material operation required by the modifier API.
    */
    function assignEditPolyMaterialId target_node edit_poly_mod face_bits material_id =
    (
        result_value = false

        if face_bits.numberSet == 0 then
        (
            setMessage "No faces belong to the current selection."
        )
        else
        (
            old_face_selection = edit_poly_mod.GetSelection #Face node:target_node
            old_material_id = edit_poly_mod.materialIDToSet
            old_select_mode = edit_poly_mod.selectMode
            old_use_stack_selection = edit_poly_mod.useStackSelection
            old_epoly_level = edit_poly_mod.GetEPolySelLevel()
            old_subobject_level = subObjectLevel
            target_faces = (face_bits as array) as bitarray
            operation_failed = false
            selection_failed = false
            exception_text = ""

            try
            (
                select target_node
                max modify mode

                edit_poly_mod.SetPrimaryNode target_node
                modPanel.setCurrentObject edit_poly_mod node:target_node
                edit_poly_mod.showCage = off
                edit_poly_mod.selectMode = 0
                edit_poly_mod.useStackSelection = false
                edit_poly_mod.SetEPolySelLevel #Face
                subObjectLevel = 4

                if edit_poly_mod.SetSelection #Face target_faces node:target_node then
                (
                    edit_poly_mod.SetOperation #SetMaterial
                    edit_poly_mod.materialIDToSet = material_id - 1
                    edit_poly_mod.Commit()
                    edit_poly_mod.RefreshScreen()
                    result_value = verifyEditPolyMaterialId target_node edit_poly_mod face_bits material_id
                )
                else
                (
                    selection_failed = true
                    setMessage "Unable to set the temporary Edit Poly face selection."
                )
            )
            catch
            (
                exception_text = getCurrentException()
                operation_failed = true
                result_value = false
            )

            state_restored = restoreEditPolyState target_node edit_poly_mod old_face_selection old_material_id old_select_mode old_use_stack_selection old_epoly_level old_subobject_level
            edit_poly_mod.RefreshScreen()
            completeRedraw()

            if not state_restored then
            (
                result_value = false
                setMessage "Material ID was processed, but the previous Edit Poly face selection could not be restored."
            )
            else if operation_failed then
            (
                setMessage ("Edit Poly Material ID operation failed: " + exception_text)
            )
            else if result_value then
            (
                setMessage ("Assigned Material ID " + (material_id as string) + " to " + (face_bits.numberSet as string) + " face(s).")
            )
            else if selection_failed then
            (
                result_value = false
            )
            else
            (
                setMessage "Edit Poly Material ID verification failed."
            )
        )

        result_value -- return
    ),

    /* Assign one one-based Material ID according to the current object or sub-object selection.
       Object level affects all faces; Vertex/Edge/Border/Polygon/Element affect the faces belonging to that selection.
    */
    function assignMaterialId material_id =
    (
        result_value = false

        if material_id < 1 or material_id > 65535 then
        (
            setMessage "Material ID must be between 1 and 65535."
        )
        else
        (
            context_data = resolveContext()
            context_kind = context_data[1]

            if context_kind != #none then
            (
                target_node = context_data[2]
                current_object = context_data[3]
                level_number = getCurrentSubObjectLevel context_data

                if context_kind == #editable_poly then
                (
                    face_bits = getEditablePolyTargetFaces target_node level_number

                    undo "Assign Material ID" on
                    (
                        result_value = assignEditablePolyMaterialId target_node current_object face_bits material_id
                    )

                    completeRedraw()
                )
                else if context_kind == #edit_poly then
                (
                    face_bits = getEditPolyTargetFaces target_node current_object level_number

                    undo "Assign Material ID" on
                    (
                        result_value = assignEditPolyMaterialId target_node current_object face_bits material_id
                    )
                )
            )
        )

        result_value -- return
    ),

    /* Test whether one Volume Select modifier belongs to the supplied node.
       Returns false for undefined values or unrelated modifier instances.
    */
    function isVolumeSelectOnNode target_node volume_select_mod =
    (
        result_value = false

        if isValidNode target_node and volume_select_mod != undefined and classOf volume_select_mod == VolumeSelect then
        (
            for stack_mod in target_node.modifiers while not result_value do
            (
                if stack_mod == volume_select_mod then
                (
                    result_value = true
                )
            )
        )

        result_value -- return
    ),

    /* Return the top-to-bottom modifier-stack index of one exact modifier instance.
       Returns 0 when the modifier is undefined or is not present on the supplied node.
    */
    function findModifierStackIndex target_node target_mod =
    (
        stack_index_value = 0

        if isValidNode target_node and target_mod != undefined then
        (
            for stack_index = 1 to target_node.modifiers.count while stack_index_value == 0 do
            (
                if target_node.modifiers[stack_index] == target_mod then
                (
                    stack_index_value = stack_index
                )
            )
        )

        stack_index_value -- return
    ),

    /* Resolve the Material modifier paired directly above one Volume Select stack index.
       Modifier-array indices follow the visible stack from top to bottom, so the direct modifier above is index - 1.
       Returns #(material_stack_index, material_modifier, material_id), or undefined when no direct pair exists.
    */
    function getPairedMaterialEntry target_node volume_stack_index =
    (
        pair_entry = undefined

        if isValidNode target_node and volume_stack_index > 1 and volume_stack_index <= target_node.modifiers.count then
        (
            material_stack_index = volume_stack_index - 1
            material_mod = target_node.modifiers[material_stack_index]

            if classOf material_mod == MaterialModifier then
            (
                pair_entry = #(material_stack_index, material_mod, material_mod.materialID)
            )
        )

        pair_entry -- return
    ),

    /* Return all Volume Select modifiers and their directly paired Material modifiers.
       Entry format is #(volume_stack_index, volume_select, material_stack_index, material_modifier, material_id).
       Entries are ordered top-to-bottom to match the visible modifier stack.
    */
    function getVolumeSelectStackEntries target_node =
    (
        stack_entries = #()

        if isValidNode target_node then
        (
            for stack_index = 1 to target_node.modifiers.count do
            (
                stack_mod = target_node.modifiers[stack_index]

                if classOf stack_mod == VolumeSelect then
                (
                    pair_entry = getPairedMaterialEntry target_node stack_index

                    if pair_entry == undefined then
                    (
                        append stack_entries #(stack_index, stack_mod, 0, undefined, undefined)
                    )
                    else
                    (
                        append stack_entries #(stack_index, stack_mod, pair_entry[1], pair_entry[2], pair_entry[3])
                    )
                )
            )
        )

        stack_entries -- return
    ),

    /* Resolve the semantic Material ID name used by one Material Select Modifier Set.
       Blank semantic names fall back to an explicit ID label so modifier names remain readable.
    */
    function getMaterialSelectSetMaterialName material_id =
    (
        material_name = materialIdManagerSettings.loadMaterialName material_id

        if material_name == "" then
        (
            material_name = "ID " + (material_id as string)
        )

        material_name -- return
    ),

    /* Synchronize names for every paired Material Select Modifier Set on one node.
       Duplicate sets using the same Material ID receive shared top-to-bottom indices on both modifiers.
    */
    function syncMaterialSelectModifierSetNames target_node =
    (
        result_value = false

        if isValidNode target_node then
        (
            stack_entries = getVolumeSelectStackEntries target_node
            material_ids = #()
            material_id_totals = #()
            material_id_indices = #()

            for stack_entry in stack_entries do
            (
                material_mod = stack_entry[4]
                material_id = stack_entry[5]

                if material_mod != undefined and material_id != undefined then
                (
                    material_id_index = findItem material_ids material_id

                    if material_id_index == 0 then
                    (
                        append material_ids material_id
                        append material_id_totals 1
                        append material_id_indices 0
                    )
                    else
                    (
                        material_id_totals[material_id_index] += 1
                    )
                )
            )

            result_value = true

            for stack_entry in stack_entries while result_value do
            (
                volume_select_mod = stack_entry[2]
                material_mod = stack_entry[4]
                material_id = stack_entry[5]

                if material_mod != undefined and material_id != undefined then
                (
                    material_id_index = findItem material_ids material_id
                    material_id_indices[material_id_index] += 1
                    material_name = getMaterialSelectSetMaterialName material_id
                    index_suffix = if material_id_totals[material_id_index] > 1 then ("[" + (material_id_indices[material_id_index] as string) + "]") else ""
                    set_name = material_name + index_suffix
                    select_name = set_name + " SELECT"
                    material_name_full = set_name + " MATERIAL"

                    volume_select_mod.name = select_name
                    material_mod.name = material_name_full
                    result_value = (volume_select_mod.name == select_name and material_mod.name == material_name_full)
                )
            )
        )

        result_value -- return
    ),

    /* Test whether any Volume Select lacks a MaterialModifier directly above it.
       Material IDs are explicit user values and are never compared with modifier-stack order.
    */
    function volumeMaterialPairsNeedSync target_node =
    (
        needs_sync = false

        if isValidNode target_node then
        (
            for stack_index = 1 to target_node.modifiers.count while not needs_sync do
            (
                stack_mod = target_node.modifiers[stack_index]

                if classOf stack_mod == VolumeSelect then
                (
                    if getPairedMaterialEntry target_node stack_index == undefined then
                    (
                        needs_sync = true
                    )
                )
            )
        )

        needs_sync -- return
    ),

    /* Ensure every Volume Select has one MaterialModifier directly above it.
       Existing MaterialModifier IDs are preserved exactly; newly created pairs start at Material ID 1.
    */
    function synchronizeVolumeMaterialPairs target_node =
    (
        result_value = false

        if not isValidNode target_node then
        (
            setMessage "Cannot synchronize Material select modifiers sets because the selected node is invalid."
        )
        else
        (
            volume_select_mods = #()
            added_material_mods = #()
            old_current_object = undefined
            old_sub_object_level = subObjectLevel
            operation_failed = false
            exception_text = ""

            for stack_index = 1 to target_node.modifiers.count do
            (
                stack_mod = target_node.modifiers[stack_index]

                if classOf stack_mod == VolumeSelect then
                (
                    append volume_select_mods stack_mod
                )
            )

            if getCommandPanelTaskMode() == #modify then
            (
                old_current_object = modPanel.getCurrentObject()
            )

            try
            (
                for volume_select_mod in volume_select_mods do
                (
                    volume_stack_index = findModifierStackIndex target_node volume_select_mod

                    if volume_stack_index == 0 then
                    (
                        throw "A Volume Select modifier disappeared while synchronizing the stack."
                    )

                    pair_entry = getPairedMaterialEntry target_node volume_stack_index

                    if pair_entry == undefined then
                    (
                        material_mod = materialModifier materialID:1 name:"Material ID"
                        addModifier target_node material_mod before:volume_stack_index
                        append added_material_mods material_mod

                        volume_stack_index = findModifierStackIndex target_node volume_select_mod
                        pair_entry = getPairedMaterialEntry target_node volume_stack_index

                        if pair_entry == undefined or pair_entry[2] != material_mod then
                        (
                            throw "A Material modifier could not be inserted directly above its Volume Select."
                        )
                    )
                )

                result_value = true

                for volume_select_mod in volume_select_mods while result_value do
                (
                    volume_stack_index = findModifierStackIndex target_node volume_select_mod
                    result_value = (getPairedMaterialEntry target_node volume_stack_index != undefined)
                )

                if result_value then
                (
                    result_value = syncMaterialSelectModifierSetNames target_node
                )
            )
            catch
            (
                exception_text = getCurrentException()
                operation_failed = true
                result_value = false
            )

            if not result_value then
            (
                cleanup_exception_text = ""

                for added_index = added_material_mods.count to 1 by -1 do
                (
                    added_material_mod = added_material_mods[added_index]

                    if added_material_mod != undefined then
                    (
                        try
                        (
                            deleteModifier target_node added_material_mod
                        )
                        catch
                        (
                            cleanup_exception_text = getCurrentException()
                        )
                    )
                )

                if cleanup_exception_text == "" then
                (
                    setMessage ("Material select modifiers set synchronization failed: " + exception_text)
                )
                else
                (
                    setMessage ("Material select modifiers set synchronization failed: " + exception_text + " | Cleanup: " + cleanup_exception_text)
                )
            )
            else
            (
                state_restore_failed = false
                state_restore_exception = ""

                try
                (
                    if old_current_object != undefined then
                    (
                        modPanel.setCurrentObject old_current_object node:target_node
                    )

                    if old_sub_object_level != undefined then
                    (
                        subObjectLevel = old_sub_object_level
                    )
                )
                catch
                (
                    state_restore_exception = getCurrentException()
                    state_restore_failed = true
                )

                if state_restore_failed then
                (
                    result_value = false
                    setMessage ("Material select modifiers sets were synchronized, but Modify-panel state restoration failed: " + state_restore_exception)
                )
                else
                (
                    completeRedraw()
                )
            )

            if operation_failed and exception_text == "" then
            (
                result_value = false
            )
        )

        result_value -- return
    ),

    /* Set one explicit Material ID on the Material modifier directly paired above one exact Volume Select.
       Pair synchronization never changes this user-assigned ID.
    */
    function setVolumeSelectPairMaterialId target_node volume_select_mod material_id =
    (
        result_value = false
        volume_stack_index = findModifierStackIndex target_node volume_select_mod

        if material_id < 1 or material_id > 65535 then
        (
            setMessage "Material ID must be between 1 and 65535."
        )
        else if volume_stack_index == 0 then
        (
            setMessage "The selected Volume Select modifier is not valid for the selected object."
        )
        else
        (
            pair_entry = getPairedMaterialEntry target_node volume_stack_index

            if pair_entry == undefined then
            (
                setMessage "This Volume Select has no Material modifier directly above it."
            )
            else
            (
                material_mod = pair_entry[2]
                material_mod.materialID = material_id
                result_value = (material_mod.materialID == material_id)

                if result_value then
                (
                    result_value = syncMaterialSelectModifierSetNames target_node
                )

                if result_value then
                (
                    completeRedraw()
                    setMessage ("Material select modifiers set ID: " + (material_id as string))
                )
                else
                (
                    setMessage "Material select modifiers set did not keep the requested Material ID and synchronized names."
                )
            )
        )

        result_value -- return
    ),

    /* Test whether one MaterialModifier belongs to the supplied node.
       Returns false for undefined values or unrelated modifier instances.
    */
    function isMaterialModifierOnNode target_node material_mod =
    (
        result_value = false

        if isValidNode target_node and material_mod != undefined and classOf material_mod == MaterialModifier then
        (
            for stack_mod in target_node.modifiers while not result_value do
            (
                if stack_mod == material_mod then
                (
                    result_value = true
                )
            )
        )

        result_value -- return
    ),

    /* Set one explicit Material ID on one exact MaterialModifier instance.
       The write is verified before success is reported.
    */
    function setMaterialModifierId target_node material_mod material_id =
    (
        result_value = false

        if material_id < 1 or material_id > 65535 then
        (
            setMessage "Material ID must be between 1 and 65535."
        )
        else if not (isMaterialModifierOnNode target_node material_mod) then
        (
            setMessage "The active Material modifier does not belong to the selected object."
        )
        else
        (
            material_mod.materialID = material_id
            result_value = (material_mod.materialID == material_id)

            if result_value then
            (
                result_value = syncMaterialSelectModifierSetNames target_node
            )

            if result_value then
            (
                completeRedraw()
                setMessage ("Material modifier ID: " + (material_id as string))
            )
            else
            (
                setMessage "The Material modifier did not keep the requested Material ID and synchronized set names."
            )
        )

        result_value -- return
    ),

    /* Assign one explicit Material ID according to the current Modify-panel context.
       Active MaterialModifier and Volume Select pairs are edited directly; poly contexts assign to their selected faces.
    */
    function applyMaterialIdFromUi material_id =
    (
        result_value = false

        if selection.count != 1 then
        (
            setMessage "Select exactly one object before assigning a Material ID."
        )
        else
        (
            target_node = selection[1]
            current_object = undefined

            if getCommandPanelTaskMode() == #modify then
            (
                current_object = modPanel.getCurrentObject()
            )

            if not isValidNode target_node then
            (
                setMessage "The selected node is not valid."
            )
            else if current_object != undefined and classOf current_object == MaterialModifier and isMaterialModifierOnNode target_node current_object then
            (
                undo "Set Material Modifier ID" on
                (
                    result_value = setMaterialModifierId target_node current_object material_id
                )
            )
            else if current_object != undefined and classOf current_object == VolumeSelect and isVolumeSelectOnNode target_node current_object then
            (
                undo "Set Paired Material ID" on
                (
                    result_value = setVolumeSelectPairMaterialId target_node current_object material_id
                )
            )
            else
            (
                result_value = assignMaterialId material_id
            )
        )

        result_value -- return
    ),

    /* Make one exact Volume Select modifier current in the Modify panel.
       Returns true only when the requested modifier belongs to the node and becomes current.
    */
    function activateVolumeSelectModifier target_node volume_select_mod =
    (
        result_value = false

        if not isValidNode target_node then
        (
            setMessage "The selected node is not valid."
        )
        else if not (isVolumeSelectOnNode target_node volume_select_mod) then
        (
            setMessage "The selected Volume Select modifier does not belong to the selected object."
        )
        else
        (
            select target_node
            max modify mode
            modPanel.setCurrentObject volume_select_mod node:target_node
            result_value = (modPanel.getCurrentObject() == volume_select_mod)

            if result_value then
            (
                setMessage ("Active Volume Select: " + volume_select_mod.name)
            )
            else
            (
                setMessage "The requested Volume Select modifier could not be made current."
            )
        )

        result_value -- return
    ),

    /* Remove one exact modifier instance from one node.
       Returns true only when that exact stack instance was found and deleted.
    */
    function removeModifierInstance target_node target_mod =
    (
        result_value = false

        if isValidNode target_node and target_mod != undefined then
        (
            for mod_index = target_node.modifiers.count to 1 by -1 while not result_value do
            (
                if target_node.modifiers[mod_index] == target_mod then
                (
                    deleteModifier target_node mod_index
                    result_value = true
                )
            )
        )

        result_value -- return
    ),

    /* Copy one complete Material Select Modifier Set directly above its source set.
       The Volume Select clone keeps independent local modifier data and the paired Material clone preserves the explicit Material ID.
    */
    function copyMaterialSelectModifierSet target_node volume_select_mod =
    (
        result_value = false
        copied_volume_mod = undefined
        copied_material_mod = undefined
        copied_volume_added = false
        copied_material_added = false
        old_add_in_progress = volume_add_in_progress
        operation_failed = false
        exception_text = ""

        if not isValidNode target_node then
        (
            setMessage "Cannot copy the Material Select Modifier Set because the selected node is invalid."
        )
        else
        (
            source_volume_index = findModifierStackIndex target_node volume_select_mod

            if source_volume_index == 0 then
            (
                setMessage "Select a valid Material Select Modifier Set before copying it."
            )
            else
            (
                source_pair_entry = getPairedMaterialEntry target_node source_volume_index

                if source_pair_entry == undefined then
                (
                    setMessage "The selected Material Select Modifier Set has no directly paired Material modifier."
                )
                else
                (
                    source_material_index = source_pair_entry[1]
                    source_material_mod = source_pair_entry[2]
                    source_material_id = source_pair_entry[3]
                    volume_add_in_progress = true

                    try
                    (
                        copied_volume_mod = copy volume_select_mod
                        copied_material_mod = copy source_material_mod

                        if copied_volume_mod == undefined or copied_volume_mod == volume_select_mod then
                        (
                            throw "The Volume Select modifier could not be copied as an independent modifier."
                        )

                        if copied_material_mod == undefined or copied_material_mod == source_material_mod then
                        (
                            throw "The paired Material modifier could not be copied as an independent modifier."
                        )

                        addModifierWithLocalData target_node copied_volume_mod target_node volume_select_mod before:source_material_index
                        copied_volume_index = findModifierStackIndex target_node copied_volume_mod
                        copied_volume_added = copied_volume_index > 0

                        if not copied_volume_added then
                        (
                            throw "The copied Volume Select modifier could not be inserted into the stack."
                        )

                        addModifier target_node copied_material_mod before:copied_volume_index
                        copied_material_added = isMaterialModifierOnNode target_node copied_material_mod

                        if not copied_material_added then
                        (
                            throw "The copied Material modifier could not be inserted into the stack."
                        )

                        copied_volume_index = findModifierStackIndex target_node copied_volume_mod
                        copied_pair_entry = getPairedMaterialEntry target_node copied_volume_index

                        if copied_pair_entry == undefined or copied_pair_entry[2] != copied_material_mod then
                        (
                            throw "The copied Material modifier is not directly above the copied Volume Select."
                        )

                        if copied_material_mod.materialID != source_material_id then
                        (
                            throw "The copied Material modifier did not preserve the source Material ID."
                        )

                        if not (syncMaterialSelectModifierSetNames target_node) then
                        (
                            throw "Material Select Modifier Set names could not be synchronized after copying."
                        )

                        result_value = true
                    )
                    catch
                    (
                        exception_text = getCurrentException()
                        operation_failed = true
                        result_value = false
                    )

                    if not result_value then
                    (
                        cleanup_exception_text = ""

                        if copied_material_mod != undefined and isMaterialModifierOnNode target_node copied_material_mod then
                        (
                            try
                            (
                                removeModifierInstance target_node copied_material_mod
                            )
                            catch
                            (
                                cleanup_exception_text = getCurrentException()
                                format "Material ID Manager set-copy Material cleanup ERROR: %\n" cleanup_exception_text
                            )
                        )

                        if copied_volume_mod != undefined and (findModifierStackIndex target_node copied_volume_mod) > 0 then
                        (
                            try
                            (
                                removeModifierInstance target_node copied_volume_mod
                            )
                            catch
                            (
                                cleanup_exception_text = getCurrentException()
                                format "Material ID Manager set-copy Volume Select cleanup ERROR: %\n" cleanup_exception_text
                            )
                        )

                        syncMaterialSelectModifierSetNames target_node
                    )

                    volume_add_in_progress = old_add_in_progress

                    if result_value then
                    (
                        completeRedraw()
                        setMessage ("Copied Material Select Modifier Set: " + copied_volume_mod.name)
                    )
                    else if operation_failed then
                    (
                        setMessage ("Could not copy Material Select Modifier Set: " + exception_text)
                    )
                )
            )
        )

        result_value -- return
    ),

    /* Remove one complete Material Select Modifier Set while preventing pair-repair callbacks from re-entering mid-delete.
       The paired Material modifier is removed first and is restored when Volume Select removal fails after that first deletion.
    */
    function removeMaterialSelectModifierSet target_node volume_select_mod =
    (
        result_value = false
        old_add_in_progress = volume_add_in_progress
        material_removed = false
        volume_removed = false
        material_backup = undefined
        operation_failed = false
        exception_text = ""

        if not isValidNode target_node then
        (
            setMessage "Cannot remove the Material Select Modifier Set because the selected node is invalid."
        )
        else
        (
            source_volume_index = findModifierStackIndex target_node volume_select_mod

            if source_volume_index == 0 then
            (
                setMessage "Select a valid Material Select Modifier Set before removing it."
            )
            else
            (
                source_pair_entry = getPairedMaterialEntry target_node source_volume_index

                if source_pair_entry == undefined then
                (
                    setMessage "The selected Material Select Modifier Set has no directly paired Material modifier."
                )
                else
                (
                    source_material_mod = source_pair_entry[2]
                    material_backup = copy source_material_mod
                    volume_add_in_progress = true

                    try
                    (
                        if getCommandPanelTaskMode() == #modify then
                        (
                            current_object = modPanel.getCurrentObject()

                            if current_object == source_material_mod or current_object == volume_select_mod then
                            (
                                modPanel.setCurrentObject target_node.baseObject node:target_node
                            )
                        )

                        if not (removeModifierInstance target_node source_material_mod) then
                        (
                            throw "The paired Material modifier could not be removed."
                        )

                        material_removed = not (isMaterialModifierOnNode target_node source_material_mod)

                        if not material_removed then
                        (
                            throw "The paired Material modifier remained in the stack after removal."
                        )

                        if not (removeModifierInstance target_node volume_select_mod) then
                        (
                            throw "The Volume Select modifier could not be removed."
                        )

                        volume_removed = (findModifierStackIndex target_node volume_select_mod) == 0

                        if not volume_removed then
                        (
                            throw "The Volume Select modifier remained in the stack after removal."
                        )

                        result_value = true
                    )
                    catch
                    (
                        exception_text = getCurrentException()
                        operation_failed = true
                        result_value = false
                    )

                    if not result_value and material_removed and not volume_removed and material_backup != undefined then
                    (
                        restore_volume_index = findModifierStackIndex target_node volume_select_mod

                        if restore_volume_index > 0 then
                        (
                            try
                            (
                                addModifier target_node material_backup before:restore_volume_index
                            )
                            catch
                            (
                                restore_exception_text = getCurrentException()
                                format "Material ID Manager set-removal restore ERROR: %\n" restore_exception_text
                            )
                        )
                    )

                    volume_add_in_progress = old_add_in_progress
                    sync_result = syncMaterialSelectModifierSetNames target_node

                    if result_value then
                    (
                        completeRedraw()

                        if sync_result then
                        (
                            setMessage "Removed Material Select Modifier Set."
                        )
                        else
                        (
                            setMessage "Removed Material Select Modifier Set, but remaining set names could not be synchronized."
                        )
                    )
                    else if operation_failed then
                    (
                        setMessage ("Could not remove Material Select Modifier Set: " + exception_text)
                    )
                )
            )
        )

        result_value -- return
    ),

    /* Resolve only the poly object currently exposed in the Modify panel.
       Returns #(#edit_poly|#editable_poly, node, object) or #(#none, node, undefined).
    */
    function resolveActivePolyContext target_node =
    (
        context_data = #(#none, target_node, undefined)
        current_object = undefined

        if isValidNode target_node and getCommandPanelTaskMode() == #modify then
        (
            current_object = modPanel.getCurrentObject()

            if current_object != undefined and classOf current_object == Edit_Poly and isEditPolyOnNode target_node current_object then
            (
                context_data = #(#edit_poly, target_node, current_object)
            )
            else if current_object != undefined and classOf current_object == Editable_Poly and current_object == target_node.baseObject then
            (
                context_data = #(#editable_poly, target_node, current_object)
            )
        )

        context_data -- return
    ),

    /* Read the stored face selection from one exact Editable Poly or Edit Poly context.
       The returned BitArray is independent from the current visible sub-object level.
    */
    function getContextFaceSelection context_data =
    (
        face_bits = #{}
        context_kind = context_data[1]
        target_node = context_data[2]
        current_object = context_data[3]

        if context_kind == #edit_poly then
        (
            face_bits = current_object.GetSelection #Face node:target_node
        )
        else if context_kind == #editable_poly then
        (
            face_bits = polyop.getFaceSelection target_node
        )

        face_bits -- return
    ),

    /* Write one exact face selection back to one Editable Poly or Edit Poly context.
       The write is verified and does not intentionally change the active modifier.
    */
    function setContextFaceSelection context_data face_bits =
    (
        result_value = false
        context_kind = context_data[1]
        target_node = context_data[2]
        current_object = context_data[3]

        if context_kind == #edit_poly and isEditPolyOnNode target_node current_object then
        (
            set_result = current_object.SetSelection #Face face_bits node:target_node
            stored_faces = current_object.GetSelection #Face node:target_node
            result_value = set_result and stored_faces == face_bits
        )
        else if context_kind == #editable_poly and isValidNode target_node and current_object == target_node.baseObject then
        (
            polyop.setFaceSelection target_node face_bits
            stored_faces = polyop.getFaceSelection target_node
            result_value = (stored_faces == face_bits)
        )

        result_value -- return
    ),

    /* Clear only the stored face selection owned by one exact poly context.
       The write is verified and does not intentionally change the active modifier.
    */
    function clearContextFaceSelection context_data =
    (
        setContextFaceSelection context_data #{} -- return
    ),

    /* Activate one exact poly source context before a face-selection write.
       Edit Poly selection writes in the middle of a modifier stack require that source modifier to be current.
    */
    function activateContextForFaceSelectionWrite context_data =
    (
        result_value = false
        context_kind = context_data[1]
        target_node = context_data[2]
        current_object = context_data[3]

        if context_kind == #edit_poly and isEditPolyOnNode target_node current_object then
        (
            max modify mode
            current_object.SetPrimaryNode target_node
            modPanel.setCurrentObject current_object node:target_node
            current_object.showCage = off
            current_object.SetEPolySelLevel #Face
            subObjectLevel = 4
            result_value = (modPanel.getCurrentObject() == current_object)
        )
        else if context_kind == #editable_poly and isValidNode target_node and current_object == target_node.baseObject then
        (
            max modify mode
            modPanel.setCurrentObject current_object node:target_node
            current_object.showCage = off
            subObjectLevel = 4
            result_value = (modPanel.getCurrentObject() == current_object)
        )

        result_value -- return
    ),

    /* Collect every face whose current Editable Poly Material ID matches the requested one-based value.
       Returns an empty BitArray when the object contains no matching faces.
    */
    function getEditablePolyFacesByMaterialId target_node material_id =
    (
        face_bits = #{}
        face_count = polyop.getNumFaces target_node

        for face_id = 1 to face_count do
        (
            if polyop.getFaceMatID target_node face_id == material_id then
            (
                face_bits[face_id] = true
            )
        )

        face_bits -- return
    ),

    /* Collect every face whose evaluated Edit Poly Material ID matches the requested one-based value.
       Edit Poly exposes GetFaceMaterial zero-based, so one is added before comparison.
    */
    function getEditPolyFacesByMaterialId target_node edit_poly_mod material_id =
    (
        face_bits = #{}
        face_count = edit_poly_mod.GetNumFaces node:target_node

        for face_id = 1 to face_count do
        (
            stored_material_id = edit_poly_mod.GetFaceMaterial face_id node:target_node

            if (stored_material_id + 1) == material_id then
            (
                face_bits[face_id] = true
            )
        )

        face_bits -- return
    ),

    /* Show one face BitArray as the live selection on an Edit Poly modifier.
       Uses the shared EPoly selection sequence: clear the old Face selection, select the requested faces, then verify.
    */
    function showEditPolyFaceSelection target_node edit_poly_mod face_bits =
    (
        result_value = false

        if isEditPolyOnNode target_node edit_poly_mod then
        (
            select target_node
            max modify mode
            edit_poly_mod.SetPrimaryNode target_node
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0

            if modPanel.getCurrentObject() != edit_poly_mod then
            (
                modPanel.setCurrentObject edit_poly_mod node:target_node
            )

            edit_poly_mod.showCage = off
            edit_poly_mod.SetEPolySelLevel #Face
            subObjectLevel = 4

            old_faces = edit_poly_mod.GetSelection #Face node:target_node
            writeMaterialLmbLog ("Edit Poly old faces: " + (old_faces as string))
            writeMaterialLmbLog ("Edit Poly requested faces: " + (face_bits as string))

            if old_faces.numberSet > 0 then
            (
                edit_poly_mod.Select #Face old_faces select:false
            )

            edit_poly_mod.Select #Face face_bits select:true
            stored_faces = edit_poly_mod.GetSelection #Face node:target_node
            result_value = (stored_faces == face_bits)

            writeMaterialLmbLog ("Edit Poly stored faces: " + (stored_faces as string))
            writeMaterialLmbLog ("Edit Poly selection verified: " + (result_value as string))

            edit_poly_mod.RefreshScreen()
            completeRedraw()
        )

        result_value -- return
    ),

    /* Show one face BitArray as the live selection on the base Editable Poly.
       Polygon level remains visible so the user can continue editing immediately.
    */
    function showEditablePolyFaceSelection target_node editable_poly_obj face_bits =
    (
        result_value = false

        if isValidNode target_node and editable_poly_obj == target_node.baseObject and classOf editable_poly_obj == Editable_Poly then
        (
            select target_node
            max modify mode
            modPanel.setCurrentObject editable_poly_obj node:target_node
            editable_poly_obj.showCage = off
            subObjectLevel = 4
            polyop.setFaceSelection target_node face_bits
            completeRedraw()
            result_value = (polyop.getFaceSelection target_node == face_bits)
        )

        result_value -- return
    ),

    /* Add one Edit Poly at the current working position and make it the active Polygon editor.
       When a Volume Select pair is active, insertion is moved above its Material modifier so the pair stays adjacent.
    */
    function addEditPolyForMaterialSelection target_node =
    (
        edit_poly_mod = undefined
        current_object = undefined
        operation_failed = false
        exception_text = ""

        if isValidNode target_node then
        (
            try
            (
                select target_node
                max modify mode
                current_object = modPanel.getCurrentObject()

                if current_object != undefined and classOf current_object == VolumeSelect and isVolumeSelectOnNode target_node current_object then
                (
                    volume_stack_index = findModifierStackIndex target_node current_object
                    pair_entry = getPairedMaterialEntry target_node volume_stack_index

                    if pair_entry != undefined then
                    (
                        modPanel.setCurrentObject pair_entry[2] node:target_node
                    )
                )

                volume_add_in_progress = true
                modPanel.addModToSelection (Edit_Poly()) ui:on
                windows.processPostedMessages()
                edit_poly_mod = modPanel.getCurrentObject()
                volume_add_in_progress = false

                if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly or not (isEditPolyOnNode target_node edit_poly_mod) then
                (
                    throw "The new Edit Poly modifier could not be resolved after insertion."
                )

                edit_poly_mod.SetPrimaryNode target_node
                edit_poly_mod.showCage = off
                edit_poly_mod.SetEPolySelLevel #Face
                subObjectLevel = 4
            )
            catch
            (
                exception_text = getCurrentException()
                operation_failed = true
                volume_add_in_progress = false

                if edit_poly_mod != undefined and isEditPolyOnNode target_node edit_poly_mod then
                (
                    try
                    (
                        removeModifierInstance target_node edit_poly_mod
                    )
                    catch
                    (
                        cleanup_exception_text = getCurrentException()
                        exception_text += " | Cleanup: " + cleanup_exception_text
                    )
                )

                edit_poly_mod = undefined
            )
        )

        if operation_failed then
        (
            setMessage ("Edit Poly creation for Material ID selection failed: " + exception_text)
        )

        edit_poly_mod -- return
    ),

    /* Select all faces with one explicit Material ID and leave them visible for continued polygon editing.
       A new Edit Poly is added only when the current working context is not already Editable Poly or Edit Poly.
    */
    function selectFacesByMaterialId material_id =
    (
        result_value = false
        created_edit_poly = false
        created_edit_poly_mod = undefined
        log_ready = writeMaterialLmbLog ("---- LMB Material ID " + (material_id as string) + " ----")

        if not log_ready then
        (
            format "Material ID Manager LMB: log file is unavailable: %\n" material_id_manager_lmb_log_path
        )

        writeMaterialLmbLog ("Selection count: " + (selection.count as string))

        if material_id < 1 or material_id > 65535 then
        (
            setMessage "Material ID must be between 1 and 65535."
        )
        else if selection.count != 1 then
        (
            setMessage "Select exactly one object before selecting faces by Material ID."
        )
        else
        (
            target_node = selection[1]

            if not isValidNode target_node then
            (
                setMessage "The selected node is not valid."
            )
            else
            (
                writeMaterialLmbLog ("Target node: " + target_node.name)
                operation_message_before = last_message

                undo "Select Faces By Material ID" on
                (
                    context_data = resolveActivePolyContext target_node
                    context_kind = context_data[1]
                    writeMaterialLmbLog ("Initial context: " + (context_kind as string))

                    if context_kind == #none then
                    (
                        if target_node.modifiers.count == 0 and classOf target_node.baseObject == Editable_Poly then
                        (
                            select target_node
                            max modify mode
                            modPanel.setCurrentObject target_node.baseObject node:target_node
                            context_data = #(#editable_poly, target_node, target_node.baseObject)
                            context_kind = #editable_poly
                        )
                        else
                        (
                            created_edit_poly_mod = addEditPolyForMaterialSelection target_node

                            if created_edit_poly_mod != undefined then
                            (
                                created_edit_poly = true
                                context_data = #(#edit_poly, target_node, created_edit_poly_mod)
                                context_kind = #edit_poly
                                writeMaterialLmbLog "Created a new Edit Poly for the LMB selection result."
                            )
                        )
                    )

                    writeMaterialLmbLog ("Resolved context: " + (context_kind as string))

                    if context_kind == #editable_poly then
                    (
                        face_bits = getEditablePolyFacesByMaterialId target_node material_id
                        writeMaterialLmbLog ("Matched Editable Poly faces: " + (face_bits as string))
                        result_value = showEditablePolyFaceSelection target_node context_data[3] face_bits
                    )
                    else if context_kind == #edit_poly then
                    (
                        face_bits = getEditPolyFacesByMaterialId target_node context_data[3] material_id
                        writeMaterialLmbLog ("Matched Edit Poly faces: " + (face_bits as string))
                        result_value = showEditPolyFaceSelection target_node context_data[3] face_bits
                    )

                    if not result_value and created_edit_poly and created_edit_poly_mod != undefined then
                    (
                        cleanup_result = removeModifierInstance target_node created_edit_poly_mod

                        if not cleanup_result then
                        (
                            setMessage "Material ID selection failed and the temporary Edit Poly could not be removed."
                        )
                    )
                )

                writeMaterialLmbLog ("LMB operation result: " + (result_value as string))

                if result_value then
                (
                    selected_count = 0
                    active_context = resolveActivePolyContext target_node

                    if active_context[1] != #none then
                    (
                        selected_count = (getContextFaceSelection active_context).numberSet
                    )

                    writeMaterialLmbLog ("Verified selected face count: " + (selected_count as string))
                    setMessage ("Selected " + (selected_count as string) + " face(s) with Material ID " + (material_id as string) + ".")
                )
                else if last_message == operation_message_before then
                (
                    setMessage "Material ID face selection could not be applied."
                )
            )
        )

        result_value -- return
    ),

    /* Return the unscaled Volume Select box size in system world units.
       The modifier-context bounding box defines the size represented by gizmo scale [1,1,1].
    */
    function getVolumeSelectBaseSize target_node volume_select_mod =
    (
        base_size = undefined

        if isValidNode target_node and isVolumeSelectOnNode target_node volume_select_mod then
        (
            bbox_min = getModContextBBoxMin target_node volume_select_mod
            bbox_max = getModContextBBoxMax target_node volume_select_mod

            if bbox_min != undefined and bbox_max != undefined then
            (
                base_size = [bbox_max.x - bbox_min.x, bbox_max.y - bbox_min.y, bbox_max.z - bbox_min.z]
            )
        )

        base_size -- return
    ),

    /* Convert a requested Volume Select box size to the matching gizmo scale.
       Returns undefined when any unscaled modifier-context dimension is exactly zero.
    */
    function getVolumeSelectScaleForSize target_node volume_select_mod gizmo_size =
    (
        gizmo_scale_value = undefined
        base_size = getVolumeSelectBaseSize target_node volume_select_mod

        if base_size != undefined then
        (
            if base_size.x != 0.0 and base_size.y != 0.0 and base_size.z != 0.0 then
            (
                gizmo_scale_value = [gizmo_size.x / base_size.x, gizmo_size.y / base_size.y, gizmo_size.z / base_size.z]
            )
        )

        gizmo_scale_value -- return
    ),

    /* Return the current Volume Select box size in system world units.
       The result combines modifier-context dimensions with the current gizmo scale.
    */
    function getVolumeSelectGizmoSize target_node volume_select_mod =
    (
        gizmo_size = undefined
        base_size = getVolumeSelectBaseSize target_node volume_select_mod

        if base_size != undefined then
        (
            gizmo_scale_value = volume_select_mod.gizmo.scale
            gizmo_size = [base_size.x * gizmo_scale_value.x, base_size.y * gizmo_scale_value.y, base_size.z * gizmo_scale_value.z]
        )

        gizmo_size -- return
    ),

    /* Offset Volume Select center Z to the current gizmo bottom while preserving the fresh gizmo.
       Capture the initial gizmo position before changing center, then explicitly restore that exact position.
       Gizmo scale is never written by this operation.
    */
    function setVolumeSelectCenterToGizmoBottom target_node volume_select_mod =
    (
        result_value = false
        gizmo_size = getVolumeSelectGizmoSize target_node volume_select_mod

        if gizmo_size == undefined then
        (
            setMessage "Volume Select gizmo size could not be read for bottom-center placement."
        )
        else
        (
            old_center = volume_select_mod.center
            old_gizmo_position = volume_select_mod.gizmo.position
            old_gizmo_scale = volume_select_mod.gizmo.scale
            target_center = [old_center.x, old_center.y, old_gizmo_position.z - (gizmo_size.z / 2.0)]

            volume_select_mod.center = target_center
            volume_select_mod.gizmo.position = old_gizmo_position

            result_value = (
                volume_select_mod.center == target_center and
                volume_select_mod.gizmo.position == old_gizmo_position and
                volume_select_mod.gizmo.scale == old_gizmo_scale
            )

            if not result_value then
            (
                setMessage "Volume Select center offset failed to preserve the initial gizmo size and position."
            )
        )

        result_value -- return
    ),

    /* Return current UI values for the active Volume Select as #(gizmo_size, center_position).
       Returns undefined when there is no valid active Volume Select on the single selected node.
    */
    function getActiveVolumeSelectState =
    (
        state_value = undefined

        if selection.count == 1 then
        (
            target_node = selection[1]
            current_object = undefined

            if getCommandPanelTaskMode() == #modify then
            (
                current_object = modPanel.getCurrentObject()
            )

            if (
                isValidNode target_node and
                current_object != undefined and
                classOf current_object == VolumeSelect and
                isVolumeSelectOnNode target_node current_object
            ) then
            (
                gizmo_size = getVolumeSelectGizmoSize target_node current_object

                if gizmo_size != undefined then
                (
                    state_value = #(gizmo_size, current_object.center)
                )
            )
        )

        state_value -- return
    ),

    /* Apply an absolute Volume Select box size and keep the gizmo bottom exactly on center.z.
       Gizmo X/Y position and the complete modifier center remain unchanged.
    */
    function setVolumeSelectGizmoSize target_node volume_select_mod gizmo_size =
    (
        result_value = false
        gizmo_scale_value = getVolumeSelectScaleForSize target_node volume_select_mod gizmo_size

        if gizmo_scale_value == undefined then
        (
            setMessage "Volume Select gizmo size cannot be resolved because its modifier-context size is zero on at least one axis."
        )
        else
        (
            old_gizmo_position = volume_select_mod.gizmo.position
            center_position = volume_select_mod.center

            volume_select_mod.gizmo.scale = gizmo_scale_value
            actual_gizmo_size = getVolumeSelectGizmoSize target_node volume_select_mod

            if actual_gizmo_size == undefined then
            (
                setMessage "Volume Select gizmo size could not be read after scaling."
            )
            else
            (
                target_gizmo_position = [old_gizmo_position.x, old_gizmo_position.y, center_position.z + (actual_gizmo_size.z / 2.0)]
                volume_select_mod.gizmo.position = target_gizmo_position

                result_value = (
                    volume_select_mod.gizmo.scale == gizmo_scale_value and
                    volume_select_mod.gizmo.position == target_gizmo_position and
                    volume_select_mod.center == center_position
                )

                if not result_value then
                (
                    setMessage "Volume Select gizmo resize or center-bottom realignment verification failed."
                )
            )
        )

        result_value -- return
    ),

    /* Set only Volume Select gizmo height, then realign the gizmo vertically so its bottom is exactly on center.z.
       Existing center, gizmo X/Y position, and gizmo X/Y scale remain unchanged.
    */
    function setVolumeSelectGizmoHeightAnchoredToCenter target_node volume_select_mod gizmo_height =
    (
        result_value = false
        base_size = getVolumeSelectBaseSize target_node volume_select_mod

        if base_size == undefined or base_size.z == 0.0 then
        (
            setMessage "Volume Select gizmo height cannot be resolved because its modifier-context Z size is zero."
        )
        else
        (
            old_center = volume_select_mod.center
            old_gizmo_position = volume_select_mod.gizmo.position
            old_gizmo_scale = volume_select_mod.gizmo.scale
            target_gizmo_scale = [old_gizmo_scale.x, old_gizmo_scale.y, gizmo_height / base_size.z]

            volume_select_mod.gizmo.scale = target_gizmo_scale

            actual_gizmo_size = getVolumeSelectGizmoSize target_node volume_select_mod

            if actual_gizmo_size == undefined then
            (
                setMessage "Volume Select gizmo height could not be read after scaling."
            )
            else
            (
                target_gizmo_position = [old_gizmo_position.x, old_gizmo_position.y, old_center.z + (actual_gizmo_size.z / 2.0)]
                volume_select_mod.gizmo.position = target_gizmo_position

                result_value = (
                    volume_select_mod.center == old_center and
                    volume_select_mod.gizmo.scale == target_gizmo_scale and
                    volume_select_mod.gizmo.position == target_gizmo_position
                )

                if not result_value then
                (
                    setMessage "Volume Select Z resize or center-bottom realignment verification failed."
                )
            )
        )

        result_value -- return
    ),

    /* Set Volume Select center Z and move the gizmo vertically so its bottom remains on that center Z.
       Existing center X/Y and gizmo X/Y values are preserved.
    */
    function setVolumeSelectCenterZ target_node volume_select_mod center_z =
    (
        result_value = false
        gizmo_size = getVolumeSelectGizmoSize target_node volume_select_mod

        if gizmo_size == undefined then
        (
            setMessage "Volume Select gizmo size could not be read."
        )
        else
        (
            old_center = volume_select_mod.center
            old_gizmo_position = volume_select_mod.gizmo.position
            target_center = [old_center.x, old_center.y, center_z]
            target_gizmo_position = [old_gizmo_position.x, old_gizmo_position.y, center_z + (gizmo_size.z / 2.0)]

            volume_select_mod.center = target_center
            volume_select_mod.gizmo.position = target_gizmo_position

            result_value = (
                volume_select_mod.center == target_center and
                volume_select_mod.gizmo.position == target_gizmo_position
            )

            if not result_value then
            (
                setMessage "Volume Select center Z or gizmo bottom-anchor verification failed."
            )
        )

        result_value -- return
    ),

    /* Restore the exact frozen Volume Select modifier context and gizmo after upstream selection changes.
       The captured context transform/bounds are restored before the exact center and gizmo PRS values are reapplied.
    */
    function restoreFrozenVolumeSelectContext target_node volume_select_mod context_tm context_bbox_min context_bbox_max center_position gizmo_position gizmo_rotation gizmo_scale =
    (
        result_value = false

        if isValidNode target_node and isVolumeSelectOnNode target_node volume_select_mod then
        (
            setModContextTM target_node volume_select_mod context_tm
            setModContextBBox target_node volume_select_mod context_bbox_min context_bbox_max
            volume_select_mod.center = center_position
            volume_select_mod.gizmo.scale = gizmo_scale
            volume_select_mod.gizmo.rotation = gizmo_rotation
            volume_select_mod.gizmo.position = gizmo_position

            result_value = (
                (getModContextTM target_node volume_select_mod) == context_tm and
                (getModContextBBoxMin target_node volume_select_mod) == context_bbox_min and
                (getModContextBBoxMax target_node volume_select_mod) == context_bbox_max and
                volume_select_mod.center == center_position and
                volume_select_mod.gizmo.scale == gizmo_scale and
                volume_select_mod.gizmo.rotation == gizmo_rotation and
                volume_select_mod.gizmo.position == gizmo_position
            )
        )

        result_value -- return
    ),

    /* Add one face-level box Volume Select from the current poly selection and pair it with one MaterialModifier.
       A valid Face/Element selection is used when present; otherwise all source faces are used as the whole-object default.
    */
    function addVolumeSelect =
    (
        result_value = false
        beginVolumeSelectDebug()

        if selection.count != 1 then
        (
            writeVolumeSelectDebugLog "PRECHECK FAILED: selection.count must equal 1."
            setMessage "Select exactly one object before adding Volume Select."
        )
        else
        (
            target_node = selection[1]
            logVolumeSelectDebugStage 1 "TARGET RESOLVED" target_node:target_node

            if not isValidNode target_node then
            (
                writeVolumeSelectDebugLog "PRECHECK FAILED: selected node is invalid."
                setMessage "The selected node is not valid."
            )
            else
            (
                source_context = resolveActivePolyContext target_node
                source_level = getCurrentSubObjectLevel source_context
                original_source_face_bits = getContextFaceSelection source_context
                source_face_bits = original_source_face_bits
                whole_object_source = false

                if source_context[1] != #none then
                (
                    if source_level == 0 or (source_level != 4 and source_level != 5) or source_face_bits.numberSet == 0 then
                    (
                        whole_object_source = true

                        if source_context[1] == #edit_poly then
                        (
                            source_face_bits = getAllEditPolyFaces target_node source_context[3]
                        )
                        else if source_context[1] == #editable_poly then
                        (
                            source_face_bits = getAllEditablePolyFaces target_node
                        )
                    )
                )

                writeVolumeSelectDebugLog ("resolved context   : " + (source_context[1] as string))
                writeVolumeSelectDebugLog ("source level       : " + (source_level as string))
                writeVolumeSelectDebugLog ("whole object mode  : " + (whole_object_source as string))
                writeVolumeSelectDebugLog ("original face count: " + (original_source_face_bits.numberSet as string))
                writeVolumeSelectDebugLog ("source face count  : " + (source_face_bits.numberSet as string))
                writeVolumeSelectDebugLog ("source faces       : " + (source_face_bits as string))
                logVolumeSelectDebugStage 2 "SOURCE CONTEXT RESOLVED" target_node:target_node

                if source_context[1] == #none then
                (
                    writeVolumeSelectDebugLog "PRECHECK FAILED: no active Editable Poly / Edit Poly source context."
                    setMessage "Make the source Editable Poly or Edit Poly current before adding Volume Select."
                )
                else if source_face_bits.numberSet == 0 then
                (
                    writeVolumeSelectDebugLog "PRECHECK FAILED: source contains no faces."
                    setMessage "The source Editable Poly / Edit Poly contains no faces."
                )
                else
                (
                    volume_select_mod = undefined
                    paired_material_mod = undefined
                    modifier_added = false
                    paired_material_added = false
                    operation_failed = false
                    cleanup_failed = false
                    cleanup_result = true
                    exception_text = ""
                    cleanup_exception_text = ""
                    creation_stage = "preparing Modify panel"
                    initialized_gizmo_size = undefined
                    initialized_gizmo_position = undefined
                    source_selection_requires_rollback = false
                    original_base_object = target_node.baseObject
                    original_modifier_stack = for stack_mod in target_node.modifiers collect stack_mod

                    volume_add_in_progress = true
                    writeVolumeSelectDebugLog ("original base      : " + (getVolumeSelectDebugValueLabel original_base_object))
                    writeVolumeSelectDebugLog ("original mods      : " + (original_modifier_stack.count as string))
                    logVolumeSelectDebugStage 3 "BEFORE max modify mode" target_node:target_node

                    try
                    (
                        max modify mode
                        logVolumeSelectDebugStage 4 "AFTER max modify mode" target_node:target_node
                        creation_stage = "activating source poly context"
                        logVolumeSelectDebugStage 5 "BEFORE source setCurrentObject" target_node:target_node
                        modPanel.setCurrentObject source_context[3] node:target_node
                        logVolumeSelectDebugStage 6 "AFTER source setCurrentObject" target_node:target_node

                        if source_context[1] == #edit_poly then
                        (
                            source_context[3].SetEPolySelLevel #Face
                            source_context[3].showCage = off
                        )
                        else if source_context[1] == #editable_poly then
                        (
                            source_context[3].showCage = off
                        )

                        subObjectLevel = 4

                        if whole_object_source then
                        (
                            creation_stage = "preparing whole-object source faces"
                            source_selection_requires_rollback = true

                            if not (setContextFaceSelection source_context source_face_bits) then
                            (
                                throw "The whole-object source face selection could not be prepared for Volume Select Auto Fit."
                            )
                        )

                        logVolumeSelectDebugStage 7 "SOURCE READY AT FACE LEVEL" target_node:target_node
                        creation_stage = "adding Volume Select"
                        logVolumeSelectDebugStage 8 "BEFORE addModToSelection Volume Select" target_node:target_node
                        modPanel.addModToSelection (Vol__Select ()) ui:on
                        logVolumeSelectDebugStage 9 "IMMEDIATELY AFTER addModToSelection Volume Select" target_node:target_node
                        windows.processPostedMessages()
                        logVolumeSelectDebugStage 10 "AFTER processPostedMessages for Volume Select" target_node:target_node

                        creation_stage = "resolving added Volume Select"
                        volume_select_mod = modPanel.getCurrentObject()
                        modifier_added = isVolumeSelectOnNode target_node volume_select_mod
                        writeVolumeSelectDebugLog ("resolved VolSelect : " + (getVolumeSelectDebugValueLabel volume_select_mod))
                        logVolumeSelectDebugStage 11 "RESOLVED ADDED VOLUME SELECT" target_node:target_node

                        if not modifier_added then
                        (
                            throw "The new Volume Select modifier could not be resolved after insertion."
                        )

                        creation_stage = "setting Face level"
                        volume_select_mod.level = 2
                        logVolumeSelectDebugStage "11A" "AFTER Volume Select Face level / BEFORE completeRedraw" target_node:target_node
                        completeRedraw()
                        logVolumeSelectDebugStage 12 "AFTER completeRedraw" target_node:target_node

                        creation_stage = "capturing initialized Auto Fit gizmo"
                        initialized_gizmo_size = getVolumeSelectGizmoSize target_node volume_select_mod
                        initialized_gizmo_position = volume_select_mod.gizmo.position
                        writeVolumeSelectDebugLog ("gizmo size        : " + (initialized_gizmo_size as string))
                        writeVolumeSelectDebugLog ("gizmo position    : " + (initialized_gizmo_position as string))
                        logVolumeSelectDebugStage 13 "AFTER Auto Fit gizmo capture" target_node:target_node

                        if initialized_gizmo_size == undefined then
                        (
                            throw "Volume Select initialized gizmo size could not be read."
                        )

                        creation_stage = "disabling Auto Fit"
                        volume_select_mod.autofit = false
                        logVolumeSelectDebugStage 14 "AFTER disabling Auto Fit" target_node:target_node

                        creation_stage = "restoring initialized gizmo"
                        restored_gizmo_scale = getVolumeSelectScaleForSize target_node volume_select_mod initialized_gizmo_size

                        if restored_gizmo_scale == undefined then
                        (
                            throw "Volume Select initialized gizmo size could not be restored after disabling Auto Fit."
                        )

                        volume_select_mod.gizmo.scale = restored_gizmo_scale
                        volume_select_mod.gizmo.position = initialized_gizmo_position
                        restored_gizmo_size = getVolumeSelectGizmoSize target_node volume_select_mod

                        if (
                            volume_select_mod.autofit != false or
                            restored_gizmo_size != initialized_gizmo_size or
                            volume_select_mod.gizmo.position != initialized_gizmo_position
                        ) then
                        (
                            throw "Volume Select Auto Fit could not be disabled while preserving the initialized gizmo size and position."
                        )

                        logVolumeSelectDebugStage 15 "AFTER restoring initialized gizmo" target_node:target_node
                        creation_stage = "placing center on gizmo bottom"

                        if not (setVolumeSelectCenterToGizmoBottom target_node volume_select_mod) then
                        (
                            throw "Volume Select center could not be placed on the fitted gizmo bottom."
                        )

                        frozen_context_tm = getModContextTM target_node volume_select_mod
                        frozen_context_bbox_min = getModContextBBoxMin target_node volume_select_mod
                        frozen_context_bbox_max = getModContextBBoxMax target_node volume_select_mod
                        frozen_center = volume_select_mod.center
                        frozen_gizmo_scale = volume_select_mod.gizmo.scale
                        frozen_gizmo_rotation = volume_select_mod.gizmo.rotation
                        frozen_gizmo_position = volume_select_mod.gizmo.position
                        writeVolumeSelectDebugLog ("center after fit   : " + (frozen_center as string))
                        writeVolumeSelectDebugLog ("frozen context TM : " + (frozen_context_tm as string))
                        writeVolumeSelectDebugLog ("frozen bbox min   : " + (frozen_context_bbox_min as string))
                        writeVolumeSelectDebugLog ("frozen bbox max   : " + (frozen_context_bbox_max as string))
                        writeVolumeSelectDebugLog ("frozen gizmo scale: " + (frozen_gizmo_scale as string))
                        writeVolumeSelectDebugLog ("frozen gizmo pos  : " + (frozen_gizmo_position as string))
                        logVolumeSelectDebugStage 16 "AFTER placing center on gizmo bottom / FROZEN CONTEXT CAPTURED" target_node:target_node
                        creation_stage = "adding paired Material modifier"
                        paired_material_mod = materialModifier materialID:1 name:"Material ID"
                        logVolumeSelectDebugStage 17 "BEFORE Volume Select setCurrentObject for Material" target_node:target_node
                        modPanel.setCurrentObject volume_select_mod node:target_node
                        logVolumeSelectDebugStage 18 "AFTER Volume Select setCurrentObject for Material" target_node:target_node
                        modPanel.addModToSelection paired_material_mod ui:on
                        logVolumeSelectDebugStage 19 "IMMEDIATELY AFTER addModToSelection Material" target_node:target_node
                        paired_material_added = (findModifierStackIndex target_node paired_material_mod) > 0

                        if not paired_material_added then
                        (
                            throw "The paired Material modifier was not added to the stack."
                        )

                        volume_stack_index = findModifierStackIndex target_node volume_select_mod
                        pair_entry = getPairedMaterialEntry target_node volume_stack_index

                        if pair_entry == undefined or pair_entry[2] != paired_material_mod then
                        (
                            throw "The paired Material modifier is not directly above the new Volume Select."
                        )

                        if not (syncMaterialSelectModifierSetNames target_node) then
                        (
                            throw "Material select modifiers set names could not be synchronized after creation."
                        )

                        logVolumeSelectDebugStage 20 "PAIR VERIFIED" target_node:target_node
                        creation_stage = "verifying existing modifier stack"

                        if target_node.baseObject != original_base_object then
                        (
                            throw "The existing modifier stack was collapsed while adding Volume Select."
                        )

                        original_modifier_index = 1

                        for stack_mod in target_node.modifiers while original_modifier_index <= original_modifier_stack.count do
                        (
                            if stack_mod == original_modifier_stack[original_modifier_index] then
                            (
                                original_modifier_index += 1
                            )
                        )

                        if original_modifier_index <= original_modifier_stack.count then
                        (
                            throw "An existing modifier was removed or reordered while adding Volume Select."
                        )

                        logVolumeSelectDebugStage 21 "EXISTING SCENE STACK VERIFIED" target_node:target_node
                        creation_stage = "reactivating source poly context for source selection finalization"

                        if not (activateContextForFaceSelectionWrite source_context) then
                        (
                            throw "The original source poly context could not be reactivated before finalizing its face selection."
                        )

                        if whole_object_source then
                        (
                            creation_stage = "restoring original source face selection"

                            if not (setContextFaceSelection source_context original_source_face_bits) then
                            (
                                throw "The original source face selection could not be restored after whole-object Volume Select fitting."
                            )

                            source_selection_requires_rollback = false
                        )
                        else
                        (
                            creation_stage = "clearing source face selection"
                            source_selection_requires_rollback = true

                            if not (clearContextFaceSelection source_context) then
                            (
                                throw "The original source face selection could not be cleared."
                            )
                        )

                        writeVolumeSelectDebugLog ("source faces final: " + ((getContextFaceSelection source_context) as string))
                        writeVolumeSelectDebugLog ("context TM final  : " + ((getModContextTM target_node volume_select_mod) as string))
                        writeVolumeSelectDebugLog ("bbox min final    : " + ((getModContextBBoxMin target_node volume_select_mod) as string))
                        writeVolumeSelectDebugLog ("bbox max final    : " + ((getModContextBBoxMax target_node volume_select_mod) as string))
                        writeVolumeSelectDebugLog ("center final      : " + (volume_select_mod.center as string))
                        writeVolumeSelectDebugLog ("gizmo scale final : " + (volume_select_mod.gizmo.scale as string))
                        writeVolumeSelectDebugLog ("gizmo pos final   : " + (volume_select_mod.gizmo.position as string))
                        logVolumeSelectDebugStage 22 "AFTER finalizing source face selection / CONTEXT CHANGED" target_node:target_node
                        creation_stage = "restoring frozen modifier context and gizmo after source selection finalization"

                        if not (restoreFrozenVolumeSelectContext target_node volume_select_mod frozen_context_tm frozen_context_bbox_min frozen_context_bbox_max frozen_center frozen_gizmo_position frozen_gizmo_rotation frozen_gizmo_scale) then
                        (
                            throw "The frozen Volume Select modifier context or gizmo could not be restored after finalizing the source face selection."
                        )

                        post_clear_gizmo_size = getVolumeSelectGizmoSize target_node volume_select_mod
                        writeVolumeSelectDebugLog ("context TM restored: " + ((getModContextTM target_node volume_select_mod) as string))
                        writeVolumeSelectDebugLog ("bbox min restored  : " + ((getModContextBBoxMin target_node volume_select_mod) as string))
                        writeVolumeSelectDebugLog ("bbox max restored  : " + ((getModContextBBoxMax target_node volume_select_mod) as string))
                        writeVolumeSelectDebugLog ("center restored    : " + (volume_select_mod.center as string))
                        writeVolumeSelectDebugLog ("gizmo size restored: " + (post_clear_gizmo_size as string))
                        writeVolumeSelectDebugLog ("gizmo scale restore: " + (volume_select_mod.gizmo.scale as string))
                        writeVolumeSelectDebugLog ("gizmo pos restored : " + (volume_select_mod.gizmo.position as string))

                        if (
                            volume_select_mod.autofit != false or
                            post_clear_gizmo_size != initialized_gizmo_size
                        ) then
                        (
                            throw "The frozen Volume Select world size changed after restoring its modifier context."
                        )

                        logVolumeSelectDebugStage 23 "AFTER restoring frozen modifier context and gizmo" target_node:target_node
                        creation_stage = "restoring Volume Select as current modifier"
                        logVolumeSelectDebugStage 24 "BEFORE final Volume Select setCurrentObject" target_node:target_node
                        modPanel.setCurrentObject volume_select_mod node:target_node
                        logVolumeSelectDebugStage 25 "AFTER final Volume Select setCurrentObject" target_node:target_node
                        result_value = (modPanel.getCurrentObject() == volume_select_mod)

                        if not result_value then
                        (
                            throw "The new Volume Select could not be restored as the active modifier."
                        )

                        logVolumeSelectDebugStage 26 "SUCCESS" target_node:target_node
                    )
                    catch
                    (
                        exception_text = getCurrentException()
                        operation_failed = true
                        result_value = false
                        writeVolumeSelectDebugLog ("ERROR creation_stage : " + creation_stage)
                        writeVolumeSelectDebugLog ("ERROR exception      : " + exception_text)
                        logVolumeSelectDebugStage 90 "FAILURE CAUGHT" target_node:target_node
                    )

                    if not result_value then
                    (
                        writeVolumeSelectDebugLog "CLEANUP BEGIN"
                        logVolumeSelectDebugStage 91 "BEFORE cleanup" target_node:target_node
                    )

                    if not result_value and paired_material_added then
                    (
                        try
                        (
                            cleanup_result = removeModifierInstance target_node paired_material_mod

                            if not cleanup_result then
                            (
                                cleanup_failed = true
                            )
                        )
                        catch
                        (
                            cleanup_exception_text = getCurrentException()
                            cleanup_failed = true
                        )
                    )

                    if not result_value and modifier_added then
                    (
                        try
                        (
                            cleanup_result = removeModifierInstance target_node volume_select_mod

                            if not cleanup_result then
                            (
                                cleanup_failed = true
                            )
                        )
                        catch
                        (
                            cleanup_exception_text = getCurrentException()
                            cleanup_failed = true
                        )
                    )

                    if not result_value and source_selection_requires_rollback then
                    (
                        try
                        (
                            cleanup_result = activateContextForFaceSelectionWrite source_context

                            if cleanup_result then
                            (
                                cleanup_result = setContextFaceSelection source_context original_source_face_bits
                            )

                            if not cleanup_result then
                            (
                                cleanup_failed = true
                            )
                        )
                        catch
                        (
                            cleanup_exception_text = getCurrentException()
                            cleanup_failed = true
                        )
                    )

                    if not result_value then
                    (
                        logVolumeSelectDebugStage 92 "AFTER cleanup" target_node:target_node
                        writeVolumeSelectDebugLog ("cleanup failed      : " + (cleanup_failed as string))

                        if cleanup_exception_text != "" then
                        (
                            writeVolumeSelectDebugLog ("cleanup exception   : " + cleanup_exception_text)
                        )
                    )

                    volume_add_in_progress = false

                    if cleanup_failed then
                    (
                        if cleanup_exception_text != "" then
                        (
                            setMessage ("Volume Select creation failed during " + creation_stage + " and cleanup also failed: " + exception_text + " | Cleanup: " + cleanup_exception_text)
                        )
                        else
                        (
                            setMessage ("Volume Select creation failed during " + creation_stage + " and an added modifier could not be removed: " + exception_text)
                        )
                    )
                    else if operation_failed then
                    (
                        setMessage ("Volume Select creation failed during " + creation_stage + ": " + exception_text)
                    )
                    else if result_value then
                    (
                        state_value = getActiveVolumeSelectState()

                        if whole_object_source then
                        (
                            if state_value != undefined then
                            (
                                setMessage ("Added Material select modifiers set for the whole object. Gizmo size: " + (state_value[1] as string) + " | Center Z: " + (state_value[2].z as string))
                            )
                            else
                            (
                                setMessage "Added Material select modifiers set for the whole object."
                            )
                        )
                        else if state_value != undefined then
                        (
                            setMessage ("Added Material select modifiers set. Gizmo size: " + (state_value[1] as string) + " | Center Z: " + (state_value[2].z as string) + " | Source faces cleared.")
                        )
                        else
                        (
                            setMessage "Added Material select modifiers set and cleared the source face selection."
                        )
                    )
                    else
                    (
                        setMessage "Material select modifiers set could not be added or verified."
                    )
                )
            )
        )

        result_value -- return
    ),

    /* Resize the active Volume Select gizmo to an absolute world-unit size.
       Gizmo X/Y position stays unchanged and gizmo Z is realigned so its bottom remains on center.z.
    */
    function resizeActiveVolumeSelectGizmo gizmo_size =
    (
        result_value = false

        if selection.count != 1 then
        (
            setMessage "Select exactly one object with an active Volume Select modifier."
        )
        else
        (
            target_node = selection[1]
            current_object = undefined

            if getCommandPanelTaskMode() == #modify then
            (
                current_object = modPanel.getCurrentObject()
            )

            if not isValidNode target_node then
            (
                setMessage "The selected node is not valid."
            )
            else if current_object == undefined or classOf current_object != VolumeSelect then
            (
                setMessage "Make a Volume Select modifier current in the Modify panel."
            )
            else if not (isVolumeSelectOnNode target_node current_object) then
            (
                setMessage "The active Volume Select modifier does not belong to the selected object."
            )
            else
            (
                result_value = setVolumeSelectGizmoSize target_node current_object gizmo_size
                completeRedraw()

                if result_value then
                (
                    setMessage ("Volume Select gizmo size: " + (gizmo_size as string))
                )
            )
        )

        result_value -- return
    ),

    /* Resize only the active Volume Select gizmo height and keep its bottom locked exactly to center.z.
       The modifier must belong to the single selected node and be current in the Modify panel.
    */
    function resizeActiveVolumeSelectGizmoHeight gizmo_height =
    (
        result_value = false

        if selection.count != 1 then
        (
            setMessage "Select exactly one object with an active Volume Select modifier."
        )
        else
        (
            target_node = selection[1]
            current_object = undefined

            if getCommandPanelTaskMode() == #modify then
            (
                current_object = modPanel.getCurrentObject()
            )

            if not isValidNode target_node then
            (
                setMessage "The selected node is not valid."
            )
            else if current_object == undefined or classOf current_object != VolumeSelect then
            (
                setMessage "Make a Volume Select modifier current in the Modify panel."
            )
            else if not (isVolumeSelectOnNode target_node current_object) then
            (
                setMessage "The active Volume Select modifier does not belong to the selected object."
            )
            else
            (
                result_value = setVolumeSelectGizmoHeightAnchoredToCenter target_node current_object gizmo_height
                completeRedraw()

                if result_value then
                (
                    setMessage ("Volume Select gizmo Z size: " + (gizmo_height as string))
                )
            )
        )

        result_value -- return
    ),

    /* Set center Z on the currently active Volume Select and keep the gizmo bottom locked to that center.
       The modifier must belong to the single selected node and be current in the Modify panel.
    */
    function setActiveVolumeSelectCenterZ center_z =
    (
        result_value = false

        if selection.count != 1 then
        (
            setMessage "Select exactly one object with an active Volume Select modifier."
        )
        else
        (
            target_node = selection[1]
            current_object = undefined

            if getCommandPanelTaskMode() == #modify then
            (
                current_object = modPanel.getCurrentObject()
            )

            if not isValidNode target_node then
            (
                setMessage "The selected node is not valid."
            )
            else if current_object == undefined or classOf current_object != VolumeSelect then
            (
                setMessage "Make a Volume Select modifier current in the Modify panel."
            )
            else if not (isVolumeSelectOnNode target_node current_object) then
            (
                setMessage "The active Volume Select modifier does not belong to the selected object."
            )
            else
            (
                result_value = setVolumeSelectCenterZ target_node current_object center_z
                completeRedraw()

                if result_value then
                (
                    setMessage ("Volume Select center Z: " + (center_z as string))
                )
            )
        )

        result_value -- return
    ),

    /* Normalize one preset name for use as an INI section.
       Empty names and names containing INI section delimiters or line breaks are rejected.
    */
    function normalizeMaterialSelectPresetName preset_name =
    (
        normalized_name = undefined

        if classOf preset_name == String then
        (
            candidate_name = trimRight (trimLeft preset_name)

            if (
                candidate_name != "" and
                findString candidate_name "[" == undefined and
                findString candidate_name "]" == undefined and
                findString candidate_name "\n" == undefined and
                findString candidate_name "\r" == undefined
            ) then
            (
                normalized_name = candidate_name
            )
        )

        normalized_name -- return
    ),

    /* Collect every complete Material Select Modifier Set as #(material_id, material_name, gizmo_size).
       Returns undefined when any paired Material or Volume Select size cannot be resolved exactly.
    */
    function collectMaterialSelectPresetEntries target_node =
    (
        preset_entries = #()
        collection_failed = false

        if not isValidNode target_node then
        (
            collection_failed = true
        )
        else
        (
            stack_entries = getVolumeSelectStackEntries target_node

            for stack_entry in stack_entries while not collection_failed do
            (
                volume_select_mod = stack_entry[2]
                material_mod = stack_entry[4]
                material_id = stack_entry[5]
                gizmo_size = getVolumeSelectGizmoSize target_node volume_select_mod

                if material_mod == undefined or gizmo_size == undefined then
                (
                    collection_failed = true
                )
                else
                (
                    material_name = getMaterialSelectSetMaterialName material_id
                    append preset_entries #(material_id, material_name, gizmo_size)
                )
            )
        )

        if collection_failed then undefined else preset_entries -- return
    ),

    /* Save every Material Select Modifier Set on one object into one preset section.
       Material ID/name plus exact X/Y/Z gizmo sizes are persisted; position and center are intentionally not stored.
    */
    function saveMaterialSelectPreset target_node preset_name preset_ini_path:undefined =
    (
        result_value = false
        normalized_name = normalizeMaterialSelectPresetName preset_name
        resolved_ini_path = preset_ini_path

        if resolved_ini_path == undefined then
        (
            resolved_ini_path = materialIdManagerSettings.getSceneMaterialSelectPresetIniPath()
        )

        if resolved_ini_path == undefined then
        (
            setMessage "Save the .max scene before adding Material Select presets."
        )
        else if normalized_name == undefined then
        (
            setMessage "Enter a valid preset name without [ ] or line breaks."
        )
        else
        (
            preset_entries = collectMaterialSelectPresetEntries target_node

            if preset_entries == undefined then
            (
                setMessage "Material Select preset data could not be read from the selected object."
            )
            else if preset_entries.count == 0 then
            (
                setMessage "The selected object has no Material Select Modifier Sets to save."
            )
            else
            (
                write_failed = false
                had_existing_preset = hasINISetting resolved_ini_path normalized_name
                existing_keys = #()
                existing_values = #()

                if had_existing_preset then
                (
                    existing_keys = getINISetting resolved_ini_path normalized_name

                    for existing_key in existing_keys do
                    (
                        append existing_values (getINISetting resolved_ini_path normalized_name existing_key)
                    )

                    delINISetting resolved_ini_path normalized_name
                    write_failed = hasINISetting resolved_ini_path normalized_name
                )

                for entry_index = 1 to preset_entries.count while not write_failed do
                (
                    entry_data = preset_entries[entry_index]
                    material_id = entry_data[1]
                    material_name = entry_data[2]
                    gizmo_size = entry_data[3]
                    entry_number = if entry_index < 10 then ("0" + (entry_index as string)) else (entry_index as string)
                    key_prefix = "Set_" + entry_number + "_"

                    id_result = setINISetting resolved_ini_path normalized_name (key_prefix + "MaterialID") (material_id as string)
                    name_result = setINISetting resolved_ini_path normalized_name (key_prefix + "MaterialName") material_name
                    x_result = setINISetting resolved_ini_path normalized_name (key_prefix + "SizeX") (gizmo_size.x as string)
                    y_result = setINISetting resolved_ini_path normalized_name (key_prefix + "SizeY") (gizmo_size.y as string)
                    z_result = setINISetting resolved_ini_path normalized_name (key_prefix + "SizeZ") (gizmo_size.z as string)
                    write_failed = not (id_result and name_result and x_result and y_result and z_result)
                )

                if not write_failed then
                (
                    count_result = setINISetting resolved_ini_path normalized_name "Count" (preset_entries.count as string)
                    write_failed = not count_result
                )

                if write_failed then
                (
                    if hasINISetting resolved_ini_path normalized_name then
                    (
                        delINISetting resolved_ini_path normalized_name
                    )

                    restore_failed = false

                    if had_existing_preset then
                    (
                        for key_index = 1 to existing_keys.count while not restore_failed do
                        (
                            restore_failed = not (setINISetting resolved_ini_path normalized_name existing_keys[key_index] existing_values[key_index])
                        )
                    )

                    if restore_failed then
                    (
                        setMessage "Material Select preset write failed and the previous preset could not be fully restored."
                    )
                    else
                    (
                        setMessage "Material Select preset could not be written completely."
                    )
                )
                else
                (
                    result_value = true
                    setMessage ("Saved Material Select preset: " + normalized_name)
                )
            )
        )

        result_value -- return
    ),

    /* Read one preset section as #(material_id, material_name, gizmo_size) entries.
       Invalid or incomplete persisted values return undefined instead of silently substituting geometry data.
    */
    function loadMaterialSelectPresetData preset_name preset_ini_path:undefined =
    (
        preset_entries = undefined
        normalized_name = normalizeMaterialSelectPresetName preset_name
        resolved_ini_path = preset_ini_path

        if resolved_ini_path == undefined then
        (
            resolved_ini_path = materialIdManagerSettings.getSceneMaterialSelectPresetIniPath()
        )

        if resolved_ini_path != undefined and normalized_name != undefined and hasINISetting resolved_ini_path normalized_name then
        (
            count_text = getINISetting resolved_ini_path normalized_name "Count"
            entry_count = undefined

            try
            (
                entry_count = count_text as integer
            )
            catch
            (
                parse_exception_text = getCurrentException()
                format "Material ID Manager preset Count parse ERROR: %\n" parse_exception_text
            )

            if entry_count != undefined and entry_count > 0 then
            (
                loaded_entries = #()
                parse_failed = false

                for entry_index = 1 to entry_count while not parse_failed do
                (
                    entry_number = if entry_index < 10 then ("0" + (entry_index as string)) else (entry_index as string)
                    key_prefix = "Set_" + entry_number + "_"
                    material_id_text = getINISetting resolved_ini_path normalized_name (key_prefix + "MaterialID")
                    material_name = getINISetting resolved_ini_path normalized_name (key_prefix + "MaterialName")
                    size_x_text = getINISetting resolved_ini_path normalized_name (key_prefix + "SizeX")
                    size_y_text = getINISetting resolved_ini_path normalized_name (key_prefix + "SizeY")
                    size_z_text = getINISetting resolved_ini_path normalized_name (key_prefix + "SizeZ")
                    material_id = undefined
                    size_x = undefined
                    size_y = undefined
                    size_z = undefined

                    try
                    (
                        material_id = material_id_text as integer
                        size_x = size_x_text as float
                        size_y = size_y_text as float
                        size_z = size_z_text as float
                    )
                    catch
                    (
                        parse_exception_text = getCurrentException()
                        format "Material ID Manager preset entry parse ERROR: %\n" parse_exception_text
                    )

                    if (
                        material_id == undefined or material_id < 1 or material_id > 65535 or
                        size_x == undefined or size_y == undefined or size_z == undefined or
                        size_x < 0.0 or size_y < 0.0 or size_z < 0.0
                    ) then
                    (
                        parse_failed = true
                    )
                    else
                    (
                        append loaded_entries #(material_id, material_name, [size_x,size_y,size_z])
                    )
                )

                if not parse_failed then
                (
                    preset_entries = loaded_entries
                )
            )
        )

        preset_entries -- return
    ),

    /* Resolve one stable Editable Poly / Edit Poly source used to build whole-object preset sets.
       The topmost Edit Poly is preferred; otherwise an Editable Poly base object is used.
    */
    function resolveMaterialSelectPresetSourceContext target_node =
    (
        context_data = #(#none, target_node, undefined)

        if isValidNode target_node then
        (
            for stack_index = 1 to target_node.modifiers.count while context_data[1] == #none do
            (
                stack_mod = target_node.modifiers[stack_index]

                if classOf stack_mod == Edit_Poly then
                (
                    context_data = #(#edit_poly, target_node, stack_mod)
                )
            )

            if context_data[1] == #none and classOf target_node.baseObject == Editable_Poly then
            (
                context_data = #(#editable_poly, target_node, target_node.baseObject)
            )
        )

        context_data -- return
    ),

    /* Replace the current object's Material Select Modifier Sets with one saved size/material preset.
       New sets are staged first; existing sets are removed only after every new set has been created and verified.
    */
    function applyMaterialSelectPreset target_node preset_name preset_ini_path:undefined =
    (
        result_value = false
        preset_entries = loadMaterialSelectPresetData preset_name preset_ini_path:preset_ini_path

        if not isValidNode target_node then
        (
            setMessage "Select one valid object before loading a Material Select preset."
        )
        else if preset_entries == undefined or preset_entries.count == 0 then
        (
            setMessage ("Material Select preset could not be read: " + preset_name)
        )
        else
        (
            source_context = resolveMaterialSelectPresetSourceContext target_node

            if source_context[1] == #none then
            (
                setMessage "Preset loading requires an Editable Poly base object or an Edit Poly modifier."
            )
            else
            (
                old_entries = getVolumeSelectStackEntries target_node
                old_volume_mods = for stack_entry in old_entries collect stack_entry[2]
                created_volume_mods = #()
                operation_failed = false
                exception_text = ""

                try
                (
                    for entry_index = 1 to preset_entries.count do
                    (
                        entry_data = preset_entries[entry_index]
                        material_id = entry_data[1]
                        gizmo_size = entry_data[3]

                        select target_node
                        max modify mode
                        modPanel.setCurrentObject source_context[3] node:target_node

                        if source_context[1] == #edit_poly then
                        (
                            source_context[3].SetPrimaryNode target_node
                            source_context[3].showCage = off
                        )
                        else
                        (
                            source_context[3].showCage = off
                        )

                        subObjectLevel = 0

                        if not (addVolumeSelect()) then
                        (
                            throw ("Preset set " + (entry_index as string) + " could not be created.")
                        )

                        created_volume_mod = modPanel.getCurrentObject()

                        if created_volume_mod == undefined or classOf created_volume_mod != VolumeSelect then
                        (
                            throw ("Preset set " + (entry_index as string) + " did not leave a valid Volume Select active.")
                        )

                        append created_volume_mods created_volume_mod

                        if not (setVolumeSelectGizmoSize target_node created_volume_mod gizmo_size) then
                        (
                            throw ("Preset set " + (entry_index as string) + " gizmo size could not be applied.")
                        )

                        if not (setVolumeSelectPairMaterialId target_node created_volume_mod material_id) then
                        (
                            throw ("Preset set " + (entry_index as string) + " Material ID could not be applied.")
                        )

                        finishVolumeSelectDebug target_node:target_node
                    )

                    for old_volume_mod in old_volume_mods do
                    (
                        if (findModifierStackIndex target_node old_volume_mod) > 0 then
                        (
                            if not (removeMaterialSelectModifierSet target_node old_volume_mod) then
                            (
                                throw "An existing Material Select Modifier Set could not be removed after staging the preset."
                            )
                        )
                    )

                    if not (syncMaterialSelectModifierSetNames target_node) then
                    (
                        throw "Loaded Material Select Modifier Set names could not be synchronized."
                    )

                    result_value = true
                )
                catch
                (
                    exception_text = getCurrentException()
                    operation_failed = true
                    result_value = false
                )

                if not result_value then
                (
                    for created_index = created_volume_mods.count to 1 by -1 do
                    (
                        created_volume_mod = created_volume_mods[created_index]

                        if (findModifierStackIndex target_node created_volume_mod) > 0 then
                        (
                            removeMaterialSelectModifierSet target_node created_volume_mod
                        )
                    )

                    finishVolumeSelectDebug target_node:target_node
                )

                if result_value then
                (
                    loaded_entries = getVolumeSelectStackEntries target_node

                    if loaded_entries.count > 0 then
                    (
                        activateVolumeSelectModifier target_node loaded_entries[1][2]
                    )

                    completeRedraw()
                    setMessage ("Loaded Material Select preset: " + preset_name)
                )
                else if operation_failed then
                (
                    setMessage ("Could not load Material Select preset: " + exception_text)
                )
            )
        )

        result_value -- return
    ),

    /* Remove one named preset section from the current scene-local preset INI.
       The selected object's modifier stack is not changed by preset deletion.
    */
    function removeMaterialSelectPreset preset_name preset_ini_path:undefined =
    (
        result_value = false
        normalized_name = normalizeMaterialSelectPresetName preset_name
        resolved_ini_path = preset_ini_path

        if resolved_ini_path == undefined then
        (
            resolved_ini_path = materialIdManagerSettings.getSceneMaterialSelectPresetIniPath()
        )

        if resolved_ini_path == undefined then
        (
            setMessage "Save the .max scene before removing Material Select presets."
        )
        else if normalized_name == undefined then
        (
            setMessage "Select a valid Material Select preset first."
        )
        else if materialIdManagerSettings.deleteMaterialSelectPreset normalized_name preset_ini_path:resolved_ini_path then
        (
            result_value = true
            setMessage ("Removed Material Select preset: " + normalized_name)
        )
        else
        (
            setMessage ("Material Select preset was not found: " + normalized_name)
        )

        result_value -- return
    ),

    /* Resolve the diffuse color used by one explicit Material ID on the selected node material.
       Returns a Color when a matching material exposes a diffuse property, otherwise undefined.
    */
    function getMaterialIdDiffuseColor target_node material_id =
    (
        diffuse_color = undefined

        if isValidNode target_node and material_id >= 1 then
        (
            target_material = target_node.material

            if target_material != undefined then
            (
                if isProperty target_material #materialList and isProperty target_material #materialIDList then
                (
                    material_slot_count = target_material.materialList.count

                    if target_material.materialIDList.count < material_slot_count then
                    (
                        material_slot_count = target_material.materialIDList.count
                    )

                    material_slot_index = 0

                    for slot_index = 1 to material_slot_count do
                    (
                        if material_slot_index == 0 and target_material.materialIDList[slot_index] == material_id then
                        (
                            material_slot_index = slot_index
                        )
                    )

                    if material_slot_index > 0 then
                    (
                        id_material = target_material.materialList[material_slot_index]

                        if id_material != undefined and isProperty id_material #diffuse then
                        (
                            diffuse_color = id_material.diffuse
                        )
                    )
                )
                else if material_id == 1 and isProperty target_material #diffuse then
                (
                    diffuse_color = target_material.diffuse
                )
            )
        )

        diffuse_color -- return
    ),

    /* Convert one hue and saturation percentage into a full-value RGB diffuse color.
       Hue is expected from 0 through 359 degrees and saturation from 1 through 100 percent.
    */
    function makeDiffuseColor hue_degrees saturation_percent =
    (
        diffuse_color = undefined

        if hue_degrees >= 0.0 and hue_degrees < 360.0 and saturation_percent >= 1 and saturation_percent <= 100 then
        (
            saturation_ratio = saturation_percent / 100.0
            white_ratio = 1.0 - saturation_ratio
            hue_fraction = 0.0
            red_base = 0.0
            green_base = 0.0
            blue_base = 0.0

            if hue_degrees < 60.0 then
            (
                hue_fraction = hue_degrees / 60.0
                red_base = 1.0
                green_base = hue_fraction
            )
            else if hue_degrees < 120.0 then
            (
                hue_fraction = (hue_degrees - 60.0) / 60.0
                red_base = 1.0 - hue_fraction
                green_base = 1.0
            )
            else if hue_degrees < 180.0 then
            (
                hue_fraction = (hue_degrees - 120.0) / 60.0
                green_base = 1.0
                blue_base = hue_fraction
            )
            else if hue_degrees < 240.0 then
            (
                hue_fraction = (hue_degrees - 180.0) / 60.0
                green_base = 1.0 - hue_fraction
                blue_base = 1.0
            )
            else if hue_degrees < 300.0 then
            (
                hue_fraction = (hue_degrees - 240.0) / 60.0
                red_base = hue_fraction
                blue_base = 1.0
            )
            else
            (
                hue_fraction = (hue_degrees - 300.0) / 60.0
                red_base = 1.0
                blue_base = 1.0 - hue_fraction
            )

            red_channel = ((red_base * saturation_ratio) + white_ratio) * 255.0
            green_channel = ((green_base * saturation_ratio) + white_ratio) * 255.0
            blue_channel = ((blue_base * saturation_ratio) + white_ratio) * 255.0
            diffuse_color = color red_channel green_channel blue_channel
        )

        diffuse_color -- return
    ),

    /* Return the deterministic diffuse palette at one shared saturation percentage.
       IDs 1-12 preserve the existing 30-degree hues; IDs 13-24 fill the unused 15-degree interleaved hues.
    */
    function getMultiIdDiffuseColors saturation_percent:65 =
    (
        diffuse_colors = #()

        if classOf saturation_percent == Integer and saturation_percent >= 1 and saturation_percent <= 100 then
        (
            max_material_id = materialIdManagerSettings.getMaxMaterialIdCount()

            for color_index = 1 to max_material_id do
            (
                hue_degrees = if color_index <= 12 then ((color_index - 1) * 30.0) else (((color_index - 12) * 30.0) - 15.0)
                append diffuse_colors (makeDiffuseColor hue_degrees saturation_percent)
            )
        )

        diffuse_colors -- return
    ),

    /* Parse one Material ID Set suffix field.
       Blank text is a valid inactive row; malformed pipe-separated text returns undefined.
    */
    function parseMaterialIdSetSuffixes suffix_config =
    (
        suffix_tokens = undefined

        if classOf suffix_config == String then
        (
            stored_text = trimRight (trimLeft suffix_config)

            if stored_text == "" then
            (
                suffix_tokens = #()
            )
            else
            (
                raw_tokens = filterString stored_text "|" splitEmptyTokens:true

                if raw_tokens.count > 0 and raw_tokens.count <= materialIdManagerSettings.getMaxMaterialIdCount() then
                (
                    parsed_tokens = #()
                    valid_tokens = true

                    for raw_token in raw_tokens while valid_tokens do
                    (
                        token_text = trimRight (trimLeft raw_token)

                        if token_text == "" then
                        (
                            valid_tokens = false
                        )
                        else
                        (
                            append parsed_tokens token_text
                        )
                    )

                    if valid_tokens then
                    (
                        suffix_tokens = parsed_tokens
                    )
                )
            )
        )

        suffix_tokens -- return
    ),

    /* Expand Material ID Set rows into final sub-material names.
       A name-only row creates one material; suffix rows keep the existing prefix or suffix-only expansion behavior.
    */
    function buildMultiIdMaterialNames set_names:#() set_suffixes:#() =
    (
        resolved_names = undefined

        if classOf set_names == Array and classOf set_suffixes == Array and set_names.count > 0 and set_names.count == set_suffixes.count then
        (
            generated_names = #()
            normalized_names = #()
            valid_sets = true

            for set_index = 1 to set_names.count while valid_sets do
            (
                if classOf set_names[set_index] != String or classOf set_suffixes[set_index] != String then
                (
                    valid_sets = false
                )
                else
                (
                    base_name = trimRight (trimLeft set_names[set_index])
                    suffix_tokens = parseMaterialIdSetSuffixes set_suffixes[set_index]

                    if suffix_tokens == undefined then
                    (
                        valid_sets = false
                    )
                    else if suffix_tokens.count == 0 then
                    (
                        if base_name != "" then
                        (
                            normalized_name = toUpper base_name

                            if findItem normalized_names normalized_name > 0 then
                            (
                                valid_sets = false
                            )
                            else
                            (
                                append generated_names base_name
                                append normalized_names normalized_name

                                if generated_names.count > materialIdManagerSettings.getMaxMaterialIdCount() then
                                (
                                    valid_sets = false
                                )
                            )
                        )
                    )
                    else
                    (
                        for suffix_token in suffix_tokens while valid_sets do
                        (
                            material_name = if base_name == "" then suffix_token else (base_name + "-" + suffix_token)
                            normalized_name = toUpper material_name

                            if findItem normalized_names normalized_name > 0 then
                            (
                                valid_sets = false
                            )
                            else
                            (
                                append generated_names material_name
                                append normalized_names normalized_name

                                if generated_names.count > materialIdManagerSettings.getMaxMaterialIdCount() then
                                (
                                    valid_sets = false
                                )
                            )
                        )
                    )
                )
            )

            if valid_sets and generated_names.count > 0 and generated_names.count <= materialIdManagerSettings.getMaxMaterialIdCount() then
            (
                resolved_names = generated_names
            )
        )

        resolved_names -- return
    ),

    /* Verify that every color in one palette is unique.
       Returns false immediately when any duplicate color is found.
    */
    function areDiffuseColorsUnique diffuse_colors =
    (
        result_value = (classOf diffuse_colors == Array and diffuse_colors.count > 0)

        if result_value then
        (
            for color_index = 1 to diffuse_colors.count while result_value do
            (
                for compare_index = color_index + 1 to diffuse_colors.count while result_value do
                (
                    if diffuse_colors[color_index] == diffuse_colors[compare_index] then
                    (
                        result_value = false
                    )
                )
            )
        )

        result_value -- return
    ),

    /* Resolve the active top-level Material Editor slot and material.
       Returns #(slot_index, material) so material generation can work even when no scene object is selected.
    */
    function getActiveMeditMaterialContext =
    (
        material_context = undefined
        active_slot = medit.GetActiveMtlSlot()

        if classOf active_slot == Integer and active_slot >= 1 then
        (
            active_material = medit.GetTopMtlSlot active_slot
            material_context = #(active_slot, active_material)
        )

        material_context -- return
    ),

    /* Return the explicit Material ID count from the current Multi/Sub-Object material.
       One selected node is preferred; with no selection the active top-level Material Editor slot is used.
    */
    function getCurrentMultiIdMaterialCount =
    (
        material_count = 0
        current_material = undefined

        if selection.count == 1 and isValidNode selection[1] then
        (
            current_material = selection[1].material
        )
        else if selection.count == 0 then
        (
            material_context = getActiveMeditMaterialContext()

            if material_context != undefined then
            (
                current_material = material_context[2]
            )
        )

        if current_material != undefined and classOf current_material == MultiMaterial then
        (
            explicit_id_count = current_material.materialIDList.count

            if (
                explicit_id_count >= 1 and
                explicit_id_count <= materialIdManagerSettings.getMaxMaterialIdCount() and
                current_material.materialList.count == explicit_id_count
            ) then
            (
                material_count = explicit_id_count
            )
        )

        material_count -- return
    ),

    /* Read Material ID names back from the current Multi/Sub-Object material after an update.
       One selected node is preferred; with no selection the active top-level Material Editor slot is used.
    */
    function getCurrentMultiIdMaterialNames =
    (
        resolved_names = undefined
        current_material = undefined

        if selection.count == 1 and isValidNode selection[1] then
        (
            current_material = selection[1].material
        )
        else if selection.count == 0 then
        (
            material_context = getActiveMeditMaterialContext()

            if material_context != undefined then
            (
                current_material = material_context[2]
            )
        )

        if current_material != undefined and classOf current_material == MultiMaterial then
        (
            material_count = current_material.materialList.count
            arrays_ready = (
                material_count >= 1 and
                material_count <= materialIdManagerSettings.getMaxMaterialIdCount() and
                current_material.materialIDList.count == material_count and
                current_material.names.count == material_count
            )

            if arrays_ready then
            (
                material_names = #()
                seen_ids = #()
                valid_material = true

                for material_index = 1 to material_count do
                (
                    append material_names ""
                    append seen_ids false
                )

                for slot_index = 1 to material_count while valid_material do
                (
                    explicit_id = current_material.materialIDList[slot_index]
                    slot_name = current_material.names[slot_index]

                    if classOf explicit_id != Integer or explicit_id < 1 or explicit_id > material_count then
                    (
                        valid_material = false
                    )
                    else if seen_ids[explicit_id] then
                    (
                        valid_material = false
                    )
                    else if classOf slot_name != String or slot_name == "" then
                    (
                        valid_material = false
                    )
                    else
                    (
                        material_names[explicit_id] = slot_name
                        seen_ids[explicit_id] = true
                    )
                )

                if valid_material then
                (
                    for material_id = 1 to material_count while valid_material do
                    (
                        if not seen_ids[material_id] then
                        (
                            valid_material = false
                        )
                    )
                )

                if valid_material then
                (
                    resolved_names = material_names
                )
            )
        )

        resolved_names -- return
    ),

    /* Generate or update one Multi/Sub-Object material from the configured Material ID Set rows.
       One selected node is preferred; with no selection the active top-level Material Editor slot is created or updated instead.
    */
    function createMultiIdMaterial set_names:#() set_suffixes:#() saturation_percent:65 =
    (
        result_value = false
        target_node = undefined
        target_material = undefined
        target_medit_slot = 0
        target_is_medit = false
        target_ready = false
        id_colors = getMultiIdDiffuseColors saturation_percent:saturation_percent
        resolved_names = buildMultiIdMaterialNames set_names:set_names set_suffixes:set_suffixes

        if resolved_names == undefined then
        (
            setMessage "Material Setup is empty or invalid. Enter at least one valid Material ID Set name or suffix before using Multi ID Material."
        )
        else if id_colors.count != materialIdManagerSettings.getMaxMaterialIdCount() then
        (
            setMessage "Diffuse saturation must be an integer from 1 to 100."
        )
        else if not (areDiffuseColorsUnique id_colors) then
        (
            setMessage "Multi ID diffuse palette contains duplicate colors."
        )
        else if selection.count > 1 then
        (
            setMessage "Select one object, or clear the selection to create/update the active Material Editor slot."
        )
        else
        (
            if selection.count == 1 then
            (
                target_node = selection[1]

                if isValidNode target_node then
                (
                    target_material = target_node.material
                    target_ready = true
                )
                else
                (
                    setMessage "The selected node is not valid."
                )
            )
            else
            (
                material_context = getActiveMeditMaterialContext()

                if material_context != undefined then
                (
                    target_medit_slot = material_context[1]
                    target_material = material_context[2]
                    target_is_medit = true
                    target_ready = true
                )
                else
                (
                    setMessage "Unable to resolve the active Material Editor slot."
                )
            )

            if target_ready then
            (
                material_count = resolved_names.count
                update_existing = (target_material != undefined and classOf target_material == MultiMaterial)
                existing_id_materials = #()

                if update_existing then
                (
                    material_slot_count = target_material.materialList.count

                    if target_material.materialIDList.count < material_slot_count then
                    (
                        material_slot_count = target_material.materialIDList.count
                    )

                    for material_index = 1 to material_count do
                    (
                        matched_material = undefined

                        for slot_index = 1 to material_slot_count while matched_material == undefined do
                        (
                            if target_material.materialIDList[slot_index] == material_index then
                            (
                                matched_material = target_material.materialList[slot_index]
                            )
                        )

                        append existing_id_materials matched_material
                    )

                    multi_id_material = target_material
                    multi_id_material.numsubs = material_count
                )
                else
                (
                    for material_index = 1 to material_count do
                    (
                        append existing_id_materials undefined
                    )

                    multi_id_material = multimaterial numsubs:material_count
                )

                arrays_ready = (
                    multi_id_material.materialList.count == material_count and
                    multi_id_material.materialIDList.count == material_count and
                    multi_id_material.names.count == material_count and
                    multi_id_material.mapEnabled.count == material_count
                )

                if not arrays_ready then
                (
                    setMessage "Unable to resize the Multi/Sub-Object material to the configured Material ID count."
                )
                else
                (
                    multi_id_material.name = "Material ID Set 01-" + (material_count as string)

                    for material_index = 1 to material_count do
                    (
                        material_name = resolved_names[material_index]
                        id_material = existing_id_materials[material_index]

                        if (id_material == undefined) or (classOf id_material != Standardmaterial) then
                        (
                            id_material = standardMaterial name:material_name diffuse:id_colors[material_index]
                        )
                        else
                        (
                            id_material.name = material_name
                            id_material.diffuse = id_colors[material_index]
                        )

                        multi_id_material.materialList[material_index] = id_material
                        multi_id_material.materialIDList[material_index] = material_index
                        multi_id_material.names[material_index] = material_name
                        multi_id_material.mapEnabled[material_index] = true
                    )

                    if target_is_medit then
                    (
                        medit.PutMtlToMtlEditor multi_id_material target_medit_slot
                    )
                    else
                    (
                        target_node.material = multi_id_material
                    )

                    updateMTLInMedit multi_id_material
                    redrawViews()

                    assignment_verified = false

                    if target_is_medit then
                    (
                        assignment_verified = (medit.GetTopMtlSlot target_medit_slot == multi_id_material)
                    )
                    else
                    (
                        assignment_verified = (target_node.material == multi_id_material)
                    )

                    result_value = (
                        assignment_verified and
                        multi_id_material.materialList.count == material_count and
                        multi_id_material.materialIDList.count == material_count and
                        multi_id_material.names.count == material_count and
                        multi_id_material.mapEnabled.count == material_count
                    )

                    if result_value then
                    (
                        for material_index = 1 to material_count while result_value do
                        (
                            id_material = multi_id_material.materialList[material_index]
                            result_value = (
                                id_material != undefined and
                                classOf id_material == Standardmaterial and
                                id_material.name == resolved_names[material_index] and
                                id_material.diffuse == id_colors[material_index] and
                                multi_id_material.materialIDList[material_index] == material_index and
                                multi_id_material.names[material_index] == resolved_names[material_index] and
                                multi_id_material.mapEnabled[material_index]
                            )
                        )
                    )

                    if result_value then
                    (
                        if target_is_medit then
                        (
                            if update_existing then
                            (
                                setMessage ("Updated active Material Editor Multi/Sub from config: " + (material_count as string) + " Material IDs.")
                            )
                            else
                            (
                                setMessage ("Created Multi/Sub in active Material Editor slot from config: " + (material_count as string) + " Material IDs.")
                            )
                        )
                        else if update_existing then
                        (
                            setMessage ("Updated selected object's Multi/Sub in place from config: " + (material_count as string) + " Material IDs.")
                        )
                        else
                        (
                            setMessage ("Created and assigned Multi/Sub from config: " + (material_count as string) + " Material IDs.")
                        )
                    )
                    else
                    (
                        setMessage "Multi ID material generation/update could not be verified."
                    )
                )
            )
        )

        result_value -- return
    ),

    /* Add the lowest missing configured Material ID to the selected object's existing Multi/Sub-Object material.
       The added slot uses the current Material ID Set name and deterministic diffuse color for that explicit ID.
    */
    function addMultiMaterialId set_names:#() set_suffixes:#() saturation_percent:65 =
    (
        result_value = false

        if selection.count != 1 then
        (
            setMessage "Select exactly one object before adding a Multi/Sub material ID."
        )
        else
        (
            target_node = selection[1]

            if not isValidNode target_node then
            (
                setMessage "The selected node is not valid."
            )
            else
            (
                target_material = target_node.material

                if target_material == undefined or not (isProperty target_material #materialList) or not (isProperty target_material #materialIDList) or not (isProperty target_material #names) then
                (
                    setMessage "Selected object must already have a Multi/Sub-Object material. Use Multi ID Material first."
                )
                else
                (
                    id_colors = getMultiIdDiffuseColors saturation_percent:saturation_percent
                    resolved_names = buildMultiIdMaterialNames set_names:set_names set_suffixes:set_suffixes

                    if resolved_names == undefined then
                    (
                        setMessage ("Material ID Set rows must generate 1-" + (materialIdManagerSettings.getMaxMaterialIdCount() as string) + " unique material names from valid names and suffix lists.")
                    )
                    else if id_colors.count != materialIdManagerSettings.getMaxMaterialIdCount() then
                    (
                        setMessage "Diffuse saturation must be an integer from 1 to 100."
                    )
                    else
                    (
                        used_ids = #()
                        material_slot_count = target_material.materialList.count

                        if target_material.materialIDList.count < material_slot_count then
                        (
                            material_slot_count = target_material.materialIDList.count
                        )

                        for slot_index = 1 to material_slot_count do
                        (
                            current_id = target_material.materialIDList[slot_index]

                            if findItem used_ids current_id == 0 then
                            (
                                append used_ids current_id
                            )
                        )

                        new_material_id = 0

                        for candidate_id = 1 to resolved_names.count while new_material_id == 0 do
                        (
                            if findItem used_ids candidate_id == 0 then
                            (
                                new_material_id = candidate_id
                            )
                        )

                        if new_material_id == 0 then
                        (
                            setMessage ("Multi/Sub-Object material already contains all " + (resolved_names.count as string) + " configured Material IDs.")
                        )
                        else
                        (
                            old_slot_count = target_material.materialList.count
                            new_slot_count = old_slot_count + 1
                            target_material.materialList.count = new_slot_count

                            arrays_ready = (
                                target_material.materialList.count >= new_slot_count and
                                target_material.materialIDList.count >= new_slot_count and
                                target_material.names.count >= new_slot_count
                            )

                            if not arrays_ready then
                            (
                                setMessage "Unable to expand the Multi/Sub-Object material slot arrays."
                            )
                            else
                            (
                                material_name = resolved_names[new_material_id]
                                id_material = standardMaterial name:material_name diffuse:id_colors[new_material_id]
                                target_material.materialList[new_slot_count] = id_material
                                target_material.materialIDList[new_slot_count] = new_material_id
                                target_material.names[new_slot_count] = material_name

                                if isProperty target_material #mapEnabled and target_material.mapEnabled.count >= new_slot_count then
                                (
                                    target_material.mapEnabled[new_slot_count] = true
                                )

                                resolved_color = getMaterialIdDiffuseColor target_node new_material_id
                                result_value = (
                                    target_material.materialList.count == new_slot_count and
                                    target_material.materialList[new_slot_count] == id_material and
                                    target_material.materialIDList[new_slot_count] == new_material_id and
                                    target_material.names[new_slot_count] == material_name and
                                    resolved_color == id_colors[new_material_id]
                                )

                                if result_value then
                                (
                                    setMessage ("Added Material ID " + (new_material_id as string) + " (" + material_name + ") to the Multi/Sub-Object material.")
                                )
                                else
                                (
                                    setMessage "Adding the Multi/Sub material ID could not be verified."
                                )
                            )
                        )
                    )
                )
            )
        )

        result_value -- return
    ),

    /* Resolve the semantic object name for one Material ID.
       Current Material ID row text wins; IDs outside the configured rows use a readable numeric fallback.
    */
    function getMaterialIdObjectName material_id material_names:#() =
    (
        name_text = ""

        if classOf material_names == Array and material_id >= 1 and material_id <= material_names.count then
        (
            name_text = trimRight (trimLeft (material_names[material_id] as string))
        )

        if name_text == "" then
        (
            if material_id >= 1 and material_id <= materialIdManagerSettings.getMaxMaterialIdCount() then
            (
                name_text = materialIdManagerSettings.getDefaultMaterialName material_id
            )
            else
            (
                name_text = "Material ID " + (material_id as string)
            )
        )

        name_text -- return
    ),

    /* Collect the distinct Material IDs used by one face set on an Editable Poly node.
       Invalid face indexes return undefined so topology mismatch is not confused with an empty result.
    */
    function getPolyMaterialIdsForFaces target_node face_bits =
    (
        material_ids = undefined

        if isValidNode target_node and classOf target_node.baseObject == Editable_Poly and face_bits != undefined then
        (
            face_count = polyop.getNumFaces target_node
            collected_ids = #()
            valid_faces = true

            for face_id in face_bits while valid_faces do
            (
                if face_id < 1 or face_id > face_count then
                (
                    valid_faces = false
                )
                else
                (
                    material_id = polyop.getFaceMatID target_node face_id

                    if findItem collected_ids material_id == 0 then
                    (
                        append collected_ids material_id
                    )
                )
            )

            if valid_faces then
            (
                sort collected_ids
                material_ids = collected_ids
            )
        )

        material_ids -- return
    ),

    /* Collect the distinct Material IDs used by every face of one Editable Poly node.
       Returns undefined for an invalid/non-poly node and an empty Array only for a legitimate zero-face poly.
    */
    function getPolyUsedMaterialIds target_node =
    (
        material_ids = undefined

        if isValidNode target_node and classOf target_node.baseObject == Editable_Poly then
        (
            face_bits = getAllEditablePolyFaces target_node
            material_ids = getPolyMaterialIdsForFaces target_node face_bits
        )

        material_ids -- return
    ),

    /* Create a temporary evaluated Editable Poly copy without changing the source node.
       The copy is collapsed independently and is deleted by the caller on failure or after output construction.
    */
    function createEditablePolyWorkCopy source_node =
    (
        work_node = undefined

        if isValidNode source_node then
        (
            try
            (
                work_node = copy source_node name:(uniqueName "__MIDM_EDIT_MESH_TMP__")

                if work_node != undefined then
                (
                    convertToPoly work_node

                    if classOf work_node.baseObject == Editable_Poly then
                    (
                        work_node.baseObject.showCage = off
                    )
                    else
                    (
                        delete work_node
                        work_node = undefined
                        setMessage ("Unable to convert " + source_node.name + " to a temporary Editable Poly.")
                    )
                )
                else
                (
                    setMessage ("Unable to copy " + source_node.name + " for mesh editing.")
                )
            )
            catch
            (
                copy_exception = getCurrentException()

                if work_node != undefined and isValidNode work_node then
                (
                    delete work_node
                )

                work_node = undefined
                setMessage ("Mesh work-copy creation failed for " + source_node.name + ": " + (copy_exception as string))
            )
        )

        work_node -- return
    ),

    /* Delete every still-valid node in one cleanup Array.
       This helper is used only for temporary/result cleanup after a failed transactional mesh operation.
    */
    function cleanupEditMeshNodes node_array =
    (
        if classOf node_array == Array then
        (
            for cleanup_node in node_array do
            (
                if cleanup_node != undefined and isValidNode cleanup_node then
                (
                    delete cleanup_node
                )
            )
        )

        true -- return
    ),

    /* Collect selected nodes, optionally rejecting anything hidden in the viewport.
       Invalid node references are ignored because they cannot participate in scene geometry operations.
    */
    function getSelectedEditMeshNodes visible_only:false =
    (
        selected_nodes = #()

        for selected_node in selection do
        (
            if isValidNode selected_node then
            (
                if (not visible_only) or (not selected_node.isHiddenInVpt) then
                (
                    append selected_nodes selected_node
                )
            )
        )

        selected_nodes -- return
    ),

    /* Assign one scene node to a requested source layer and verify the final layer.
       Returns false when the node/layer is invalid or 3ds Max does not keep the requested assignment.
    */
    function assignEditMeshNodeToLayer target_node target_layer =
    (
        result_value = false

        if isValidNode target_node and target_layer != undefined then
        (
            try
            (
                target_layer.addNode target_node
                assigned_layer = target_node.layer

                if assigned_layer != undefined and assigned_layer.name == target_layer.name then
                (
                    result_value = true
                )
                else
                (
                    setMessage ("Layer assignment verification failed for " + target_node.name + ".")
                )
            )
            catch
            (
                layer_exception = getCurrentException()
                setMessage ("Layer assignment failed for " + target_node.name + ": " + (layer_exception as string))
            )
        )
        else
        (
            setMessage "Layer assignment requires a valid node and source layer."
        )

        result_value -- return
    ),

    /* Detach one face set from a temporary Editable Poly as a new node while keeping the source copy unchanged.
       The new node is verified by face count and assigned source layer before it is returned.
    */
    function detachPolyFacesAsNode source_poly_node face_bits result_name source_material:undefined source_layer:undefined =
    (
        detached_node = undefined

        if isValidNode source_poly_node and classOf source_poly_node.baseObject == Editable_Poly and face_bits != undefined and face_bits.numberSet > 0 then
        (
            temporary_name = uniqueName "__MIDM_DETACHED_TMP__"
            detach_result = false

            try
            (
                detach_result = polyop.detachFaces source_poly_node face_bits delete:false asNode:true name:temporary_name
            )
            catch
            (
                detach_exception = getCurrentException()
                setMessage ("Detach operation failed: " + (detach_exception as string))
            )

            if detach_result then
            (
                detached_node = getNodeByName temporary_name exact:true

                if detached_node == undefined or not (isValidNode detached_node) then
                (
                    detached_node = undefined
                    setMessage "Detach reported success but the detached node could not be resolved."
                )
                else
                (
                    if classOf detached_node.baseObject == Editable_Poly then
                    (
                        detached_node.baseObject.showCage = off
                    )

                    if source_material != undefined then
                    (
                        detached_node.material = source_material
                    )

                    if source_layer == undefined or not (assignEditMeshNodeToLayer detached_node source_layer) then
                    (
                        delete detached_node
                        detached_node = undefined
                    )

                    if detached_node != undefined then
                    (
                        detached_node.name = result_name
                    )

                    if detached_node != undefined and polyop.getNumFaces detached_node != face_bits.numberSet then
                    (
                        delete detached_node
                        detached_node = undefined
                        setMessage "Detached-node face-count verification failed."
                    )
                )
            )
        )

        detached_node -- return
    ),

    /* Attach selected visible objects into one collapsed Editable Poly result per lowest used Material ID.
       When one source object uses several face IDs, its lowest used ID chooses the output group.
    */
    function attachSelectedVisibleByMaterialId material_names:#() =
    (
        result_value = false
        source_nodes = getSelectedEditMeshNodes visible_only:true

        if source_nodes.count < 2 then
        (
            setMessage "Select at least two visible objects to attach by Material ID."
        )
        else
        (
            group_ids = #()
            group_work_nodes = #()
            all_work_nodes = #()
            operation_ok = true

            for source_node in source_nodes while operation_ok do
            (
                work_node = createEditablePolyWorkCopy source_node

                if work_node == undefined then
                (
                    operation_ok = false
                )
                else
                (
                    append all_work_nodes work_node
                    used_ids = getPolyUsedMaterialIds work_node

                    if used_ids == undefined or used_ids.count == 0 then
                    (
                        setMessage ("Unable to resolve used Material IDs on " + source_node.name + ".")
                        operation_ok = false
                    )
                    else
                    (
                        group_material_id = used_ids[1]
                        group_index = findItem group_ids group_material_id

                        if group_index == 0 then
                        (
                            append group_ids group_material_id
                            append group_work_nodes #(work_node)
                        )
                        else
                        (
                            append group_work_nodes[group_index] work_node
                        )
                    )
                )
            )

            result_nodes = #()

            if operation_ok then
            (
                for group_index = 1 to group_ids.count while operation_ok do
                (
                    current_group = group_work_nodes[group_index]
                    target_node = current_group[1]

                    for attach_index = 2 to current_group.count while operation_ok do
                    (
                        source_work_node = current_group[attach_index]
                        target_face_count = polyop.getNumFaces target_node
                        source_face_count = polyop.getNumFaces source_work_node

                        try
                        (
                            polyop.attach target_node source_work_node
                        )
                        catch
                        (
                            attach_exception = getCurrentException()
                            setMessage ("Attach by Material ID failed: " + (attach_exception as string))
                            operation_ok = false
                        )

                        if operation_ok then
                        (
                            if isValidNode source_work_node or polyop.getNumFaces target_node != (target_face_count + source_face_count) then
                            (
                                setMessage "Attach by Material ID post-operation verification failed."
                                operation_ok = false
                            )
                        )
                    )

                    if operation_ok then
                    (
                        target_node.baseObject.showCage = off
                        target_node.name = getMaterialIdObjectName group_ids[group_index] material_names:material_names
                        append result_nodes target_node
                    )
                )
            )

            if operation_ok then
            (
                source_delete_ok = true

                for source_node in source_nodes while source_delete_ok do
                (
                    delete source_node

                    if isValidNode source_node then
                    (
                        source_delete_ok = false
                    )
                )

                if source_delete_ok then
                (
                    select result_nodes
                    redrawViews()
                    result_value = true
                    setMessage ("Attached " + (source_nodes.count as string) + " visible object(s) into " + (result_nodes.count as string) + " Material ID object(s).")
                )
                else
                (
                    select result_nodes
                    setMessage "Attach results were created, but one or more original objects could not be deleted."
                )
            )
            else
            (
                cleanupEditMeshNodes all_work_nodes
            )
        )

        result_value -- return
    ),

    /* Explode every selected object into collapsed Editable Poly objects grouped by its face Material IDs.
       Each output object is named from the corresponding Material ID semantic row.
    */
    function explodeSelectedObjectsByMaterialId material_names:#() =
    (
        result_value = false
        source_nodes = getSelectedEditMeshNodes visible_only:false

        if source_nodes.count == 0 then
        (
            setMessage "Select at least one object to explode by Material ID."
        )
        else
        (
            temporary_nodes = #()
            result_nodes = #()
            operation_ok = true

            for source_node in source_nodes while operation_ok do
            (
                source_layer = source_node.layer
                work_node = undefined

                if source_layer == undefined then
                (
                    setMessage ("Unable to resolve source layer on " + source_node.name + ".")
                    operation_ok = false
                )
                else
                (
                    work_node = createEditablePolyWorkCopy source_node
                )

                if operation_ok and work_node == undefined then
                (
                    operation_ok = false
                )
                else if operation_ok then
                (
                    append temporary_nodes work_node
                    used_ids = getPolyUsedMaterialIds work_node

                    if used_ids == undefined or used_ids.count == 0 then
                    (
                        setMessage ("Unable to resolve used Material IDs on " + source_node.name + ".")
                        operation_ok = false
                    )
                    else
                    (
                        for material_id in used_ids while operation_ok do
                        (
                            face_bits = getEditablePolyFacesByMaterialId work_node material_id

                            if face_bits.numberSet == 0 then
                            (
                                setMessage ("Material ID " + (material_id as string) + " resolved without any faces.")
                                operation_ok = false
                            )
                            else
                            (
                                result_name = getMaterialIdObjectName material_id material_names:material_names
                                detached_node = detachPolyFacesAsNode work_node face_bits result_name source_material:source_node.material source_layer:source_layer

                                if detached_node == undefined then
                                (
                                    operation_ok = false
                                )
                                else
                                (
                                    append result_nodes detached_node
                                )
                            )
                        )
                    )
                )
            )

            if operation_ok then
            (
                cleanupEditMeshNodes temporary_nodes
                source_delete_ok = true

                for source_node in source_nodes while source_delete_ok do
                (
                    delete source_node

                    if isValidNode source_node then
                    (
                        source_delete_ok = false
                    )
                )

                if source_delete_ok then
                (
                    select result_nodes
                    redrawViews()
                    result_value = true
                    setMessage ("Exploded " + (source_nodes.count as string) + " object(s) into " + (result_nodes.count as string) + " Material ID object(s).")
                )
                else
                (
                    select result_nodes
                    setMessage "Explode results were created, but one or more original objects could not be deleted."
                )
            )
            else
            (
                cleanupEditMeshNodes temporary_nodes
                cleanupEditMeshNodes result_nodes
            )
        )

        result_value -- return
    ),

    /* Detach the currently selected polygon faces as one new object named from their lowest Material ID.
       The source is replaced by an independently collapsed Editable Poly remainder only after all output checks pass.
    */
    function detachSelectedFacesByMaterialId material_names:#() =
    (
        result_value = false

        if selection.count != 1 then
        (
            setMessage "Select exactly one object with selected polygon faces to detach."
        )
        else if subObjectLevel != 4 and subObjectLevel != 5 then
        (
            setMessage "Use Polygon or Element sub-object level and select faces to detach."
        )
        else
        (
            context_data = resolveContext()
            context_kind = context_data[1]
            source_node = context_data[2]
            context_owner = context_data[3]

            if context_kind != #editable_poly and context_kind != #edit_poly then
            (
                setMessage "Detach requires an active Editable Poly or Edit Poly context."
            )
            else
            (
                selected_faces = getContextFaceSelection context_data

                if selected_faces.numberSet == 0 then
                (
                    setMessage "No polygon faces are selected for Detach."
                )
                else
                (
                    context_face_count = 0

                    if context_kind == #edit_poly then
                    (
                        context_face_count = context_owner.GetNumFaces node:source_node
                    )
                    else
                    (
                        context_face_count = polyop.getNumFaces source_node
                    )

                    source_layer = source_node.layer
                    work_node = undefined

                    if source_layer == undefined then
                    (
                        setMessage ("Unable to resolve source layer on " + source_node.name + ".")
                    )
                    else
                    (
                        work_node = createEditablePolyWorkCopy source_node
                    )

                    if work_node != undefined then
                    (
                        work_face_count = polyop.getNumFaces work_node

                        if work_face_count != context_face_count then
                        (
                            delete work_node
                            setMessage "Detach aborted because evaluated topology does not match the active face-selection context."
                        )
                        else
                        (
                            selected_ids = getPolyMaterialIdsForFaces work_node selected_faces

                            if selected_ids == undefined or selected_ids.count == 0 then
                            (
                                delete work_node
                                setMessage "Unable to resolve Material IDs for the selected faces."
                            )
                            else
                            (
                                detached_material_id = selected_ids[1]
                                detached_name = getMaterialIdObjectName detached_material_id material_names:material_names
                                detached_node = detachPolyFacesAsNode work_node selected_faces detached_name source_material:source_node.material source_layer:source_layer

                                if detached_node != undefined then
                                (
                                    delete_ok = true

                                    try
                                    (
                                        polyop.deleteFaces work_node selected_faces delIsoVerts:true
                                    )
                                    catch
                                    (
                                        delete_exception = getCurrentException()
                                        setMessage ("Source-face delete failed during Detach: " + (delete_exception as string))
                                        delete_ok = false
                                    )

                                    expected_remainder_count = work_face_count - selected_faces.numberSet

                                    if delete_ok and polyop.getNumFaces work_node != expected_remainder_count then
                                    (
                                        setMessage "Detach remainder face-count verification failed."
                                        delete_ok = false
                                    )

                                    if delete_ok and expected_remainder_count > 0 then
                                    (
                                        if not (assignEditMeshNodeToLayer work_node source_layer) then
                                        (
                                            delete_ok = false
                                        )
                                    )

                                    if delete_ok then
                                    (
                                        original_name = source_node.name
                                        delete source_node

                                        if isValidNode source_node then
                                        (
                                            setMessage "Detached object was created, but the original source object could not be replaced."
                                            delete detached_node
                                            delete work_node
                                        )
                                        else
                                        (
                                            if expected_remainder_count > 0 then
                                            (
                                                work_node.name = original_name
                                                work_node.baseObject.showCage = off
                                            )
                                            else
                                            (
                                                delete work_node
                                            )

                                            select detached_node
                                            subObjectLevel = 0
                                            redrawViews()
                                            result_value = true
                                            setMessage ("Detached " + (selected_faces.numberSet as string) + " face(s) as " + detached_name + ".")
                                        )
                                    )
                                    else
                                    (
                                        delete detached_node
                                        delete work_node
                                    )
                                )
                                else
                                (
                                    delete work_node
                                )
                            )
                        )
                    )
                )
            )
        )

        result_value -- return
    ),

    /* Select polygon faces whose world-space normals align with the active camera or viewport.
       One selected visible Editable Poly or Edit Poly is required; an optional view transform supports deterministic tests.
    */
    function selectFacesByCamera view_tm:undefined =
    (
        result_value = false
        face_bits = undefined
        selected_count = 0
        target_node = undefined
        edit_poly_mod = undefined
        active_view_tm = view_tm

        if selection.count != 1 then
        (
            setMessage "Select exactly one visible Editable Poly or Edit Poly object."
        )
        else
        (
            target_node = selection[1]

            if not (ascIsVisibleGeometry target_node) then
            (
                setMessage "The selected node must be visible geometry."
            )
            else
            (
                if active_view_tm == undefined then
                (
                    active_view_tm = ascGetActiveFaceViewTM()
                )

                if active_view_tm == undefined then
                (
                    setMessage "Could not resolve the active camera or viewport transform."
                )
                else
                (
                    edit_poly_mod = ascFindTopEditPolyModifier target_node

                    if edit_poly_mod != undefined then
                    (
                        face_bits = ascGetCameraFacingFaceSelection target_node active_view_tm

                        if face_bits == undefined then
                        (
                            setMessage "Camera-facing face detection failed on the active Edit Poly."
                        )
                        else
                        (
                            result_value = showEditPolyFaceSelection target_node edit_poly_mod face_bits
                        )
                    )
                    else if classOf target_node.baseObject == Editable_Poly then
                    (
                        face_bits = ascGetCameraFacingFaceSelection target_node active_view_tm

                        if face_bits == undefined then
                        (
                            setMessage "Camera-facing face detection failed on the Editable Poly."
                        )
                        else
                        (
                            result_value = showEditablePolyFaceSelection target_node target_node.baseObject face_bits
                        )
                    )
                    else
                    (
                        setMessage "Select an Editable Poly or an object with an Edit Poly modifier."
                    )
                )
            )
        )

        if result_value then
        (
            selected_count = face_bits.numberSet
            setMessage ("Selected " + (selected_count as string) + " camera-facing face(s).")
        )

        result_value -- return
    ),

    /* Find the newest versioned script sharing the current file's basename prefix.
       The version token is read from the final underscore-delimited filename segment.
    */
    function findNewestVersionFile source_path =
    (
        newest_file = source_path

        if source_path != undefined and source_path != "" then
        (
            source_dir = getFilenamePath source_path
            source_stem = getFilenameFile source_path
            stem_parts = filterString source_stem "_"

            if stem_parts.count >= 2 then
            (
                current_version_text = stem_parts[stem_parts.count]
                prefix_length = source_stem.count - current_version_text.count
                version_prefix = substring source_stem 1 prefix_length
                current_version = current_version_text as float
                newest_version = current_version
                candidate_files = getFiles (source_dir + version_prefix + "*.ms")

                for candidate_file in candidate_files do
                (
                    candidate_stem = getFilenameFile candidate_file
                    candidate_parts = filterString candidate_stem "_"

                    if candidate_parts.count >= 2 then
                    (
                        candidate_version_text = candidate_parts[candidate_parts.count]
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

        newest_file -- return
    ),

    /* Restart the tool from the newest matching versioned script beside the supplied source.
       The dialog Restart button uses the current source path; tests may supply another source path.
    */
    function restartNewestVersion source_path:material_id_manager_source_path =
    (
        result_value = false
        reload_path = findNewestVersionFile source_path

        if reload_path != undefined and reload_path != "" then
        (
            fileIn reload_path
            result_value = true
        )
        else
        (
            setMessage "Unable to resolve the current script path for reload."
        )

        result_value -- return
    ),

    on create do
    (
    )
)

materialIdManagerCore = materialIdManagerCore_v()

if not (materialIdManagerCore.initializeMaterialLmbLog()) then
(
    format "Material ID Manager: could not initialize LMB log at %\n" material_id_manager_lmb_log_path
)

callbacks.removeScripts id:#materialIdManagerVolumeSelectList

if materialIdManagerRollout != undefined then
(
    if isProperty materialIdManagerRollout #dialogBar then
    (
        if materialIdManagerRollout.dialogBar then
        (
            try
            (
                cui.UnRegisterDialogBar materialIdManagerRollout
            )
            catch
            (
                dialog_bar_cleanup_exception = getCurrentException()
                format "Material ID Manager dialog-bar cleanup: %\n" dialog_bar_cleanup_exception
            )
        )
    )

    try
    (
        destroyDialog materialIdManagerRollout
    )
    catch
    (
        dialog_cleanup_exception = getCurrentException()
        format "Material ID Manager dialog cleanup: %\n" dialog_cleanup_exception
    )
)

rollout materialIdManagerIdsRollout "Material IDs" height:18
(
    local updating_material_names = false
    local material_button_tooltip = undefined
    local visible_material_id_count = 0

    dotNetControl btn_id_01 "System.Windows.Forms.Button" pos:[12,12] width:48 height:24
    editText edt_id_01_name "" pos:[66,12] width:174 height:24 tooltip:"Semantic label for Material ID 1."

    dotNetControl btn_id_02 "System.Windows.Forms.Button" pos:[12,42] width:48 height:24
    editText edt_id_02_name "" pos:[66,42] width:174 height:24 tooltip:"Semantic label for Material ID 2."

    dotNetControl btn_id_03 "System.Windows.Forms.Button" pos:[12,72] width:48 height:24
    editText edt_id_03_name "" pos:[66,72] width:174 height:24 tooltip:"Semantic label for Material ID 3."

    dotNetControl btn_id_04 "System.Windows.Forms.Button" pos:[12,102] width:48 height:24
    editText edt_id_04_name "" pos:[66,102] width:174 height:24 tooltip:"Semantic label for Material ID 4."

    dotNetControl btn_id_05 "System.Windows.Forms.Button" pos:[12,132] width:48 height:24
    editText edt_id_05_name "" pos:[66,132] width:174 height:24 tooltip:"Semantic label for Material ID 5."

    dotNetControl btn_id_06 "System.Windows.Forms.Button" pos:[12,162] width:48 height:24
    editText edt_id_06_name "" pos:[66,162] width:174 height:24 tooltip:"Semantic label for Material ID 6."

    dotNetControl btn_id_07 "System.Windows.Forms.Button" pos:[12,192] width:48 height:24
    editText edt_id_07_name "" pos:[66,192] width:174 height:24 tooltip:"Semantic label for Material ID 7."

    dotNetControl btn_id_08 "System.Windows.Forms.Button" pos:[12,222] width:48 height:24
    editText edt_id_08_name "" pos:[66,222] width:174 height:24 tooltip:"Semantic label for Material ID 8."

    dotNetControl btn_id_09 "System.Windows.Forms.Button" pos:[12,252] width:48 height:24
    editText edt_id_09_name "" pos:[66,252] width:174 height:24 tooltip:"Semantic label for Material ID 9."

    dotNetControl btn_id_10 "System.Windows.Forms.Button" pos:[12,282] width:48 height:24
    editText edt_id_10_name "" pos:[66,282] width:174 height:24 tooltip:"Semantic label for Material ID 10."

    dotNetControl btn_id_11 "System.Windows.Forms.Button" pos:[12,312] width:48 height:24
    editText edt_id_11_name "" pos:[66,312] width:174 height:24 tooltip:"Semantic label for Material ID 11."

    dotNetControl btn_id_12 "System.Windows.Forms.Button" pos:[12,342] width:48 height:24
    editText edt_id_12_name "" pos:[66,342] width:174 height:24 tooltip:"Semantic label for Material ID 12."

    dotNetControl btn_id_13 "System.Windows.Forms.Button" pos:[12,372] width:48 height:24
    editText edt_id_13_name "" pos:[66,372] width:174 height:24 tooltip:"Semantic label for Material ID 13."

    dotNetControl btn_id_14 "System.Windows.Forms.Button" pos:[12,402] width:48 height:24
    editText edt_id_14_name "" pos:[66,402] width:174 height:24 tooltip:"Semantic label for Material ID 14."

    dotNetControl btn_id_15 "System.Windows.Forms.Button" pos:[12,432] width:48 height:24
    editText edt_id_15_name "" pos:[66,432] width:174 height:24 tooltip:"Semantic label for Material ID 15."

    dotNetControl btn_id_16 "System.Windows.Forms.Button" pos:[12,462] width:48 height:24
    editText edt_id_16_name "" pos:[66,462] width:174 height:24 tooltip:"Semantic label for Material ID 16."

    dotNetControl btn_id_17 "System.Windows.Forms.Button" pos:[12,492] width:48 height:24
    editText edt_id_17_name "" pos:[66,492] width:174 height:24 tooltip:"Semantic label for Material ID 17."

    dotNetControl btn_id_18 "System.Windows.Forms.Button" pos:[12,522] width:48 height:24
    editText edt_id_18_name "" pos:[66,522] width:174 height:24 tooltip:"Semantic label for Material ID 18."

    dotNetControl btn_id_19 "System.Windows.Forms.Button" pos:[12,552] width:48 height:24
    editText edt_id_19_name "" pos:[66,552] width:174 height:24 tooltip:"Semantic label for Material ID 19."

    dotNetControl btn_id_20 "System.Windows.Forms.Button" pos:[12,582] width:48 height:24
    editText edt_id_20_name "" pos:[66,582] width:174 height:24 tooltip:"Semantic label for Material ID 20."

    dotNetControl btn_id_21 "System.Windows.Forms.Button" pos:[12,612] width:48 height:24
    editText edt_id_21_name "" pos:[66,612] width:174 height:24 tooltip:"Semantic label for Material ID 21."

    dotNetControl btn_id_22 "System.Windows.Forms.Button" pos:[12,642] width:48 height:24
    editText edt_id_22_name "" pos:[66,642] width:174 height:24 tooltip:"Semantic label for Material ID 22."

    dotNetControl btn_id_23 "System.Windows.Forms.Button" pos:[12,672] width:48 height:24
    editText edt_id_23_name "" pos:[66,672] width:174 height:24 tooltip:"Semantic label for Material ID 23."

    dotNetControl btn_id_24 "System.Windows.Forms.Button" pos:[12,702] width:48 height:24
    editText edt_id_24_name "" pos:[66,702] width:174 height:24 tooltip:"Semantic label for Material ID 24."

    /* Return every Material ID button in explicit one-based Material ID order.
       The fixed control array covers the complete twenty-four-ID capacity while the parent subrollout supplies scrolling.
    */
    function getMaterialButtons =
    (
        #(btn_id_01, btn_id_02, btn_id_03, btn_id_04, btn_id_05, btn_id_06, btn_id_07, btn_id_08, btn_id_09, btn_id_10, btn_id_11, btn_id_12, btn_id_13, btn_id_14, btn_id_15, btn_id_16, btn_id_17, btn_id_18, btn_id_19, btn_id_20, btn_id_21, btn_id_22, btn_id_23, btn_id_24) -- return
    )

    /* Return every Material ID semantic-name control in explicit one-based Material ID order.
       The array stays aligned with getMaterialButtons and the INI Material Names keys.
    */
    function getMaterialNameControls =
    (
        #(
            edt_id_01_name,
            edt_id_02_name,
            edt_id_03_name,
            edt_id_04_name,
            edt_id_05_name,
            edt_id_06_name,
            edt_id_07_name,
            edt_id_08_name,
            edt_id_09_name,
            edt_id_10_name,
            edt_id_11_name,
            edt_id_12_name,
            edt_id_13_name,
            edt_id_14_name,
            edt_id_15_name,
            edt_id_16_name,
            edt_id_17_name,
            edt_id_18_name,
            edt_id_19_name,
            edt_id_20_name,
            edt_id_21_name,
            edt_id_22_name,
            edt_id_23_name,
            edt_id_24_name
        ) -- return
    )

    /* Return the number of Material ID rows currently visible in this rollout.
       The visible count mirrors the explicit ID count of the current Multi/Sub material.
    */
    function getVisibleMaterialIdCount =
    (
        visible_material_id_count -- return
    )

    /* Show exactly one Material ID row per current Multi/Sub explicit ID and resize the rollout to fit.
       Zero hides all ID rows; the parent subrollout remains only tall enough for the rollout header.
    */
    function setVisibleMaterialIdCount material_count =
    (
        result_value = false
        max_material_id_count = materialIdManagerSettings.getMaxMaterialIdCount()

        if classOf material_count == Integer and material_count >= 0 and material_count <= max_material_id_count then
        (
            material_buttons = getMaterialButtons()
            name_controls = getMaterialNameControls()

            for material_id = 1 to max_material_id_count do
            (
                row_visible = material_id <= material_count
                material_buttons[material_id].visible = row_visible
                name_controls[material_id].visible = row_visible
            )

            visible_material_id_count = material_count
            materialIdManagerIdsRollout.height = 18 + (material_count * 30)
            result_value = true
        )

        result_value -- return
    )

    /* Fit Material ID rows to the explicit ID count of the current selected or Material Editor Multi/Sub material.
       The parent dialog is relaid out after the child rollout height changes.
    */
    function fitToCurrentMultiMaterial =
    (
        material_count = materialIdManagerCore.getCurrentMultiIdMaterialCount()
        result_value = setVisibleMaterialIdCount material_count

        if result_value and materialIdManagerRollout != undefined then
        (
            materialIdManagerRollout.layoutDialog (getDialogSize materialIdManagerRollout)
        )

        result_value -- return
    )

    /* Return the current semantic names for all supported Material IDs.
       The array index is identical to the one-based explicit Material ID value.
    */
    function getMaterialNames =
    (
        material_names = #()
        name_controls = getMaterialNameControls()

        for name_control in name_controls do
        (
            append material_names name_control.text
        )

        material_names -- return
    )

    /* Apply generated Material ID Set names to the Material IDs rollout.
       IDs beyond the generated material count are cleared and every displayed value is persisted to the INI file.
    */
    function applyGeneratedMaterialNames generated_names =
    (
        result_value = (classOf generated_names == Array and generated_names.count >= 1 and generated_names.count <= materialIdManagerSettings.getMaxMaterialIdCount())

        if result_value then
        (
            name_controls = getMaterialNameControls()
            save_result = true
            updating_material_names = true

            for material_id = 1 to materialIdManagerSettings.getMaxMaterialIdCount() do
            (
                name_text = if material_id <= generated_names.count then generated_names[material_id] else ""
                name_controls[material_id].text = name_text

                if not (materialIdManagerSettings.saveMaterialName material_id name_text) then
                (
                    save_result = false
                )
            )

            updating_material_names = false

            if save_result then
            (
                save_result = setVisibleMaterialIdCount generated_names.count

                if save_result and materialIdManagerRollout != undefined then
                (
                    materialIdManagerRollout.layoutDialog (getDialogSize materialIdManagerRollout)
                )
            )

            result_value = save_result

            if result_value and selection.count == 1 and isValidNode selection[1] then
            (
                result_value = materialIdManagerCore.syncMaterialSelectModifierSetNames selection[1]
                materialIdManagerSelectFacesRollout.refreshVolumeSelectList()
            )
        )

        result_value -- return
    )

    /* Apply one scene-material diffuse color to one .NET Material ID button.
       Color channels are converted to 8-bit integers only for the Windows UI background.
    */
    function setMaterialButtonDiffuseColor material_button diffuse_color =
    (
        drawing_color_class = dotNetClass "System.Drawing.Color"
        system_colors_class = dotNetClass "System.Drawing.SystemColors"

        if diffuse_color != undefined then
        (
            red_channel = diffuse_color.r as integer
            green_channel = diffuse_color.g as integer
            blue_channel = diffuse_color.b as integer

            material_button.UseVisualStyleBackColor = false
            material_button.BackColor = drawing_color_class.FromArgb red_channel green_channel blue_channel
        )
        else
        (
            material_button.UseVisualStyleBackColor = true
            material_button.BackColor = system_colors_class.Control
        )

        true -- return
    )

    /* Refresh all Material ID button backgrounds from the currently selected node material.
       Multi/Sub-Object slots are matched by explicit materialIDList values, not by slot order.
    */
    function refreshMaterialButtonColors =
    (
        target_node = if selection.count == 1 and isValidNode selection[1] then selection[1] else undefined
        material_buttons = getMaterialButtons()

        for material_id = 1 to material_buttons.count do
        (
            setMaterialButtonDiffuseColor material_buttons[material_id] (materialIdManagerCore.getMaterialIdDiffuseColor target_node material_id)
        )

        true -- return
    )

    /* Load all Material ID semantic names from persistent settings.
       Programmatic text updates are guarded so they are not immediately written back as user edits.
    */
    function loadMaterialNames =
    (
        name_controls = getMaterialNameControls()
        updating_material_names = true

        for material_id = 1 to name_controls.count do
        (
            name_controls[material_id].text = materialIdManagerSettings.loadMaterialName material_id
        )

        updating_material_names = false
        setVisibleMaterialIdCount (materialIdManagerCore.getCurrentMultiIdMaterialCount())
        true -- return
    )

    /* Save one edited semantic Material ID name when the user changes its text field.
       Empty text is a valid persisted value; the settings backend never substitutes a built-in name.
    */
    function saveMaterialName material_id name_text =
    (
        result_value = false

        if not updating_material_names then
        (
            result_value = materialIdManagerSettings.saveMaterialName material_id name_text

            if result_value and selection.count == 1 and isValidNode selection[1] then
            (
                result_value = materialIdManagerCore.syncMaterialSelectModifierSetNames selection[1]
                materialIdManagerSelectFacesRollout.refreshVolumeSelectList()
            )
        )

        result_value -- return
    )

    /* Make every .NET Material ID button flat and borderless while preserving its diffuse-color background.
       The visual style is applied once when the rollout opens.
    */
    function setupMaterialButtonAppearance =
    (
        flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"
        material_buttons = getMaterialButtons()

        for material_button in material_buttons do
        (
            material_button.FlatStyle = flat_style_class.Flat
            material_button.FlatAppearance.BorderSize = 0
            material_button.TabStop = false
        )

        true -- return
    )

    /* Attach LMB/RMB tooltips to all Material ID buttons.
       Each tooltip names the explicit ID so mouse behavior is discoverable without a separate help row.
    */
    function setupMaterialButtonTooltips =
    (
        material_button_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
        material_buttons = getMaterialButtons()

        for material_id = 1 to material_buttons.count do
        (
            tooltip_text = "LMB: Select faces with Material ID " + (material_id as string) + ".\n\nRMB: Assign Material ID " + (material_id as string) + " to selected faces or the active Material select modifiers set."
            material_button_tooltip.SetToolTip material_buttons[material_id] tooltip_text
        )

        true -- return
    )

    /* Route one Material ID button mouse action.
       LMB selects faces by ID; RMB assigns the ID to the active face context, Material modifier, or Material select modifiers set.
    */
    function handleMaterialButton material_id event_args =
    (
        result_value = false
        mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"

        if event_args.Button == mouse_buttons.Left then
        (
            result_value = materialIdManagerCore.selectFacesByMaterialId material_id
        )
        else if event_args.Button == mouse_buttons.Right then
        (
            result_value = materialIdManagerCore.applyMaterialIdFromUi material_id
        )

        materialIdManagerRollout.lbl_status.text = materialIdManagerCore.last_message
        refreshMaterialButtonColors()
        materialIdManagerSelectFacesRollout.refreshVolumeSelectList()
        result_value -- return
    )

    on btn_id_01 MouseDown sender event_args do handleMaterialButton 1 event_args
    on btn_id_02 MouseDown sender event_args do handleMaterialButton 2 event_args
    on btn_id_03 MouseDown sender event_args do handleMaterialButton 3 event_args
    on btn_id_04 MouseDown sender event_args do handleMaterialButton 4 event_args
    on btn_id_05 MouseDown sender event_args do handleMaterialButton 5 event_args
    on btn_id_06 MouseDown sender event_args do handleMaterialButton 6 event_args
    on btn_id_07 MouseDown sender event_args do handleMaterialButton 7 event_args
    on btn_id_08 MouseDown sender event_args do handleMaterialButton 8 event_args
    on btn_id_09 MouseDown sender event_args do handleMaterialButton 9 event_args
    on btn_id_10 MouseDown sender event_args do handleMaterialButton 10 event_args
    on btn_id_11 MouseDown sender event_args do handleMaterialButton 11 event_args
    on btn_id_12 MouseDown sender event_args do handleMaterialButton 12 event_args
    on btn_id_13 MouseDown sender event_args do handleMaterialButton 13 event_args
    on btn_id_14 MouseDown sender event_args do handleMaterialButton 14 event_args
    on btn_id_15 MouseDown sender event_args do handleMaterialButton 15 event_args
    on btn_id_16 MouseDown sender event_args do handleMaterialButton 16 event_args
    on btn_id_17 MouseDown sender event_args do handleMaterialButton 17 event_args
    on btn_id_18 MouseDown sender event_args do handleMaterialButton 18 event_args
    on btn_id_19 MouseDown sender event_args do handleMaterialButton 19 event_args
    on btn_id_20 MouseDown sender event_args do handleMaterialButton 20 event_args
    on btn_id_21 MouseDown sender event_args do handleMaterialButton 21 event_args
    on btn_id_22 MouseDown sender event_args do handleMaterialButton 22 event_args
    on btn_id_23 MouseDown sender event_args do handleMaterialButton 23 event_args
    on btn_id_24 MouseDown sender event_args do handleMaterialButton 24 event_args

    on edt_id_01_name changed name_text do saveMaterialName 1 name_text
    on edt_id_02_name changed name_text do saveMaterialName 2 name_text
    on edt_id_03_name changed name_text do saveMaterialName 3 name_text
    on edt_id_04_name changed name_text do saveMaterialName 4 name_text
    on edt_id_05_name changed name_text do saveMaterialName 5 name_text
    on edt_id_06_name changed name_text do saveMaterialName 6 name_text
    on edt_id_07_name changed name_text do saveMaterialName 7 name_text
    on edt_id_08_name changed name_text do saveMaterialName 8 name_text
    on edt_id_09_name changed name_text do saveMaterialName 9 name_text
    on edt_id_10_name changed name_text do saveMaterialName 10 name_text
    on edt_id_11_name changed name_text do saveMaterialName 11 name_text
    on edt_id_12_name changed name_text do saveMaterialName 12 name_text
    on edt_id_13_name changed name_text do saveMaterialName 13 name_text
    on edt_id_14_name changed name_text do saveMaterialName 14 name_text
    on edt_id_15_name changed name_text do saveMaterialName 15 name_text
    on edt_id_16_name changed name_text do saveMaterialName 16 name_text
    on edt_id_17_name changed name_text do saveMaterialName 17 name_text
    on edt_id_18_name changed name_text do saveMaterialName 18 name_text
    on edt_id_19_name changed name_text do saveMaterialName 19 name_text
    on edt_id_20_name changed name_text do saveMaterialName 20 name_text
    on edt_id_21_name changed name_text do saveMaterialName 21 name_text
    on edt_id_22_name changed name_text do saveMaterialName 22 name_text
    on edt_id_23_name changed name_text do saveMaterialName 23 name_text
    on edt_id_24_name changed name_text do saveMaterialName 24 name_text

    on materialIdManagerIdsRollout open do
    (
        material_buttons = getMaterialButtons()

        for material_id = 1 to material_buttons.count do
        (
            material_buttons[material_id].text = material_id as string
        )

        setupMaterialButtonAppearance()
        setupMaterialButtonTooltips()
        loadMaterialNames()
        refreshMaterialButtonColors()
    )
)

rollout materialIdManagerMaterialSetupRollout "Material Setup" height:204
(
    local updating_setup_controls = false

    label lbl_saturation "Saturation" pos:[12,15] width:60 height:18
    slider sld_diffuse_saturation "" pos:[72,12] width:126 range:[1,100,65] type:#integer ticks:0 tooltip:"Diffuse saturation used when configured Multi/Sub materials are created."
    label lbl_saturation_value "65%" pos:[204,15] width:36 height:18

    editText edt_set_01_name "" pos:[12,42] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_01_suffixes "" pos:[90,42] width:150 height:24 tooltip:"Pipe-separated suffixes for this Material ID Set.\n\nWALL + INT|EXT creates WALL-INT and WALL-EXT."

    editText edt_set_02_name "" pos:[12,72] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_02_suffixes "" pos:[90,72] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_03_name "" pos:[12,102] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_03_suffixes "" pos:[90,102] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_04_name "" pos:[12,132] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_04_suffixes "" pos:[90,132] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_05_name "" pos:[12,162] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_05_suffixes "" pos:[90,162] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_06_name "" pos:[12,192] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_06_suffixes "" pos:[90,192] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_07_name "" pos:[12,222] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_07_suffixes "" pos:[90,222] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_08_name "" pos:[12,252] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_08_suffixes "" pos:[90,252] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_09_name "" pos:[12,282] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_09_suffixes "" pos:[90,282] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_10_name "" pos:[12,312] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_10_suffixes "" pos:[90,312] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_11_name "" pos:[12,342] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_11_suffixes "" pos:[90,342] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_12_name "" pos:[12,372] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_12_suffixes "" pos:[90,372] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_13_name "" pos:[12,402] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_13_suffixes "" pos:[90,402] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    editText edt_set_14_name "" pos:[12,432] width:72 height:24 tooltip:"Optional Material ID Set base name.\n\nBlank suffixes: this Name creates one Material ID.\nBlank Name: each suffix becomes the complete material name."
    editText edt_set_14_suffixes "" pos:[90,432] width:150 height:24 tooltip:"Optional pipe-separated suffixes. Each suffix creates one consecutive Material ID.\n\nIf suffixes are blank and Name is filled, the Name itself creates one Material ID."

    button btn_multi_id_material "Multi ID Material" pos:[12,168] width:108 height:24 tooltip:"LMB: Generate/update from the Material ID Set rows.\n\nOne selected object: create/update its material.\nNo selection: create/update the active Material Editor slot."
    button btn_add_multi_id "Add Multi ID" pos:[132,168] width:108 height:24 tooltip:"LMB: Append one new blank Material ID Set row and save it to the INI file."

    /* Refresh the percentage label beside the saturation slider.
       The native slider value is the exact integer percentage used for generated colors.
    */
    function refreshSaturationLabel =
    (
        lbl_saturation_value.text = (sld_diffuse_saturation.value as string) + "%"
        true -- return
    )

    /* Return every Material ID Set base-name control in row order.
       The control array is fixed at the fourteen-row capacity while visibility is driven by the INI file.
    */
    function getMaterialIdSetNameControls =
    (
        #(
            edt_set_01_name,
            edt_set_02_name,
            edt_set_03_name,
            edt_set_04_name,
            edt_set_05_name,
            edt_set_06_name,
            edt_set_07_name,
            edt_set_08_name,
            edt_set_09_name,
            edt_set_10_name,
            edt_set_11_name,
            edt_set_12_name,
            edt_set_13_name,
            edt_set_14_name
        ) -- return
    )

    /* Return every Material ID Set suffix control in row order.
       The control array mirrors the base-name array one-to-one.
    */
    function getMaterialIdSetSuffixControls =
    (
        #(
            edt_set_01_suffixes,
            edt_set_02_suffixes,
            edt_set_03_suffixes,
            edt_set_04_suffixes,
            edt_set_05_suffixes,
            edt_set_06_suffixes,
            edt_set_07_suffixes,
            edt_set_08_suffixes,
            edt_set_09_suffixes,
            edt_set_10_suffixes,
            edt_set_11_suffixes,
            edt_set_12_suffixes,
            edt_set_13_suffixes,
            edt_set_14_suffixes
        ) -- return
    )

    /* Position and show only the persisted Material ID Set rows.
       The Generate and Add buttons follow the last visible row and the rollout grows in 30 px row increments.
    */
    function layoutMaterialIdSetRows =
    (
        name_controls = getMaterialIdSetNameControls()
        suffix_controls = getMaterialIdSetSuffixControls()
        visible_count = materialIdManagerSettings.getVisibleMaterialIdSetCount()

        for set_index = 1 to name_controls.count do
        (
            row_y = 42 + ((set_index - 1) * 30)
            row_visible = set_index <= visible_count
            name_controls[set_index].pos = [12,row_y]
            suffix_controls[set_index].pos = [90,row_y]
            name_controls[set_index].visible = row_visible
            suffix_controls[set_index].visible = row_visible
        )

        button_y = 48 + (visible_count * 30)
        btn_multi_id_material.pos = [12,button_y]
        btn_add_multi_id.pos = [132,button_y]
        materialIdManagerMaterialSetupRollout.height = button_y + 36

        materialIdManagerMaterialSetupRollout.height -- return
    )

    /* Return the currently visible Material ID Set base names in row order.
       Blank base names are preserved because they intentionally generate suffix-only material names.
    */
    function getMaterialIdSetNames =
    (
        set_names = #()
        name_controls = getMaterialIdSetNameControls()
        visible_count = materialIdManagerSettings.getVisibleMaterialIdSetCount()

        for set_index = 1 to visible_count do
        (
            append set_names name_controls[set_index].text
        )

        set_names -- return
    )

    /* Return the currently visible Material ID Set suffix fields in row order.
       Each field is parsed only when a material operation is requested.
    */
    function getMaterialIdSetSuffixes =
    (
        set_suffixes = #()
        suffix_controls = getMaterialIdSetSuffixControls()
        visible_count = materialIdManagerSettings.getVisibleMaterialIdSetCount()

        for set_index = 1 to visible_count do
        (
            append set_suffixes suffix_controls[set_index].text
        )

        set_suffixes -- return
    )

    /* Save one visible Material ID Set row exactly as displayed.
       The settings layer preserves intentional blank base names and inactive blank suffix rows.
    */
    function saveMaterialIdSetRow set_index =
    (
        result_value = false
        name_controls = getMaterialIdSetNameControls()
        suffix_controls = getMaterialIdSetSuffixControls()

        if classOf set_index == Integer and set_index >= 1 and set_index <= name_controls.count then
        (
            result_value = materialIdManagerSettings.saveMaterialIdSetRow set_index name_controls[set_index].text suffix_controls[set_index].text
        )

        result_value -- return
    )

    /* Load persisted Material Setup controls without treating the assignments as user edits.
       Only defined rows are shown; appended blank rows therefore remain visible after restart.
    */
    function loadMaterialSetup =
    (
        updating_setup_controls = true
        name_controls = getMaterialIdSetNameControls()
        suffix_controls = getMaterialIdSetSuffixControls()
        visible_count = materialIdManagerSettings.getVisibleMaterialIdSetCount()

        for set_index = 1 to name_controls.count do
        (
            name_controls[set_index].text = ""
            suffix_controls[set_index].text = ""

            if set_index <= visible_count then
            (
                row_data = materialIdManagerSettings.loadMaterialIdSetRow set_index

                if row_data != undefined then
                (
                    name_controls[set_index].text = row_data[1]
                    suffix_controls[set_index].text = row_data[2]
                )
            )
        )

        sld_diffuse_saturation.value = materialIdManagerSettings.loadDiffuseSaturation()
        refreshSaturationLabel()
        layoutMaterialIdSetRows()
        updating_setup_controls = false
        true -- return
    )

    /* Append one new blank Material ID Set row and persist it immediately.
       The Material Setup and parent dialog are resized so the new row is visible without replacing any existing row.
    */
    function addMaterialIdSetRow =
    (
        result_value = false
        new_row_index = materialIdManagerSettings.appendMaterialIdSetRow()

        if new_row_index > 0 then
        (
            name_controls = getMaterialIdSetNameControls()
            suffix_controls = getMaterialIdSetSuffixControls()
            updating_setup_controls = true
            name_controls[new_row_index].text = ""
            suffix_controls[new_row_index].text = ""
            updating_setup_controls = false
            layoutMaterialIdSetRows()

            if materialIdManagerRollout != undefined then
            (
                materialIdManagerRollout.layoutDialog (getDialogSize materialIdManagerRollout)
            )

            materialIdManagerCore.setMessage ("Added Material ID Set row " + (new_row_index as string) + ".")
            result_value = true
        )
        else
        (
            materialIdManagerCore.setMessage ("Material Setup already contains the maximum " + (materialIdManagerSettings.getMaterialIdSetCount() as string) + " Material ID Set rows.")
        )

        result_value -- return
    )

    /* Return the current integer diffuse saturation percentage.
       Slider range is intentionally 1-100 so all generated hue colors remain distinct.
    */
    function getDiffuseSaturation =
    (
        sld_diffuse_saturation.value -- return
    )

    /* Update the current Multi/Sub material first, then synchronize the Material IDs rollout from that material.
       The rollout reads back explicit Material IDs and names only after the material update has succeeded and verified.
    */
    function generateOrUpdateMultiIdMaterial =
    (
        set_names = getMaterialIdSetNames()
        set_suffixes = getMaterialIdSetSuffixes()
        result_value = materialIdManagerCore.createMultiIdMaterial set_names:set_names set_suffixes:set_suffixes saturation_percent:(getDiffuseSaturation())

        if result_value then
        (
            current_material_names = materialIdManagerCore.getCurrentMultiIdMaterialNames()

            if current_material_names == undefined then
            (
                result_value = false
                materialIdManagerCore.setMessage "Multi ID material was updated, but Material IDs could not be read back from the current material."
            )
            else if not (materialIdManagerIdsRollout.applyGeneratedMaterialNames current_material_names) then
            (
                result_value = false
                materialIdManagerCore.setMessage "Multi ID material was updated, but the Material IDs rollout could not be synchronized to the current material."
            )
        )

        result_value -- return
    )

    on edt_set_01_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 1
    )

    on edt_set_01_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 1
    )

    on edt_set_02_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 2
    )

    on edt_set_02_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 2
    )

    on edt_set_03_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 3
    )

    on edt_set_03_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 3
    )

    on edt_set_04_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 4
    )

    on edt_set_04_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 4
    )

    on edt_set_05_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 5
    )

    on edt_set_05_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 5
    )

    on edt_set_06_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 6
    )

    on edt_set_06_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 6
    )

    on edt_set_07_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 7
    )

    on edt_set_07_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 7
    )

    on edt_set_08_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 8
    )

    on edt_set_08_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 8
    )

    on edt_set_09_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 9
    )

    on edt_set_09_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 9
    )

    on edt_set_10_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 10
    )

    on edt_set_10_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 10
    )

    on edt_set_11_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 11
    )

    on edt_set_11_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 11
    )

    on edt_set_12_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 12
    )

    on edt_set_12_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 12
    )

    on edt_set_13_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 13
    )

    on edt_set_13_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 13
    )

    on edt_set_14_name changed name_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 14
    )

    on edt_set_14_suffixes changed suffix_text do
    (
        if not updating_setup_controls then saveMaterialIdSetRow 14
    )

    on sld_diffuse_saturation changed saturation_value do
    (
        refreshSaturationLabel()

        if not updating_setup_controls then
        (
            materialIdManagerSettings.saveDiffuseSaturation saturation_value
        )
    )

    on btn_multi_id_material pressed do
    (
        try
        (
            undo "Generate / Update Multi ID Material" on
            (
                generateOrUpdateMultiIdMaterial()
            )
        )
        catch
        (
            exception_text = getCurrentException()
            materialIdManagerCore.setMessage ("Multi ID Material failed: " + exception_text)
            format "Multi ID Material failed: %\n" exception_text
        )

        materialIdManagerRollout.lbl_status.text = materialIdManagerCore.last_message
        materialIdManagerIdsRollout.refreshMaterialButtonColors()
    )

    on btn_add_multi_id pressed do
    (
        addMaterialIdSetRow()
        materialIdManagerRollout.lbl_status.text = materialIdManagerCore.last_message
    )

    on materialIdManagerMaterialSetupRollout open do
    (
        loadMaterialSetup()
    )
)

rollout materialIdManagerEditMeshRollout "EDIT MESH" height:102
(
    local edit_mesh_tooltip = dotNetObject "System.Windows.Forms.ToolTip"

    dotNetControl btn_attach_explode "System.Windows.Forms.Button" pos:[12,12] width:228 height:24
    button btn_detach "Detach" pos:[12,42] width:228 height:24 tooltip:"LMB: Detach the selected polygon faces as a new object.\n\nThe detached object is named from the lowest Material ID used by those faces."
    button btn_select_faces_camera "Select Faces by camera" pos:[12,72] width:228 height:24 tooltip:"LMB: Select polygon faces whose normals align with the active camera or viewport.\n\nAlignment threshold: 0.95."

    /* Configure the combined Attach / Explode button and document both mouse actions.
       LMB groups whole selected visible objects by lowest used ID; RMB splits faces by ID.
    */
    function setupEditMeshControls =
    (
        btn_attach_explode.Text = "ATTACH \\ EXPLODE by ID"
        edit_mesh_tooltip.SetToolTip btn_attach_explode "LMB: Attach selected visible objects into one object per lowest used Material ID.\n\nIf one object uses multiple face IDs, the lowest ID chooses its output group.\n\nRMB: Explode selected objects into separate objects by face Material ID.\n\nExploded object names use the Material ID names."
        true -- return
    )

    /* Route the combined .NET button by mouse button.
       Geometry operations stay in the core and the rollout only supplies current semantic Material ID names.
    */
    on btn_attach_explode MouseUp sender event_args do
    (
        mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"

        if event_args.Button == mouse_buttons.Left then
        (
            undo "Attach by Material ID" on
            (
                materialIdManagerCore.attachSelectedVisibleByMaterialId material_names:(materialIdManagerIdsRollout.getMaterialNames())
            )
        )
        else if event_args.Button == mouse_buttons.Right then
        (
            undo "Explode by Material ID" on
            (
                materialIdManagerCore.explodeSelectedObjectsByMaterialId material_names:(materialIdManagerIdsRollout.getMaterialNames())
            )
        )

        materialIdManagerRollout.lbl_status.text = materialIdManagerCore.last_message
        materialIdManagerIdsRollout.refreshMaterialButtonColors()
        materialIdManagerSelectFacesRollout.refreshVolumeSelectList()
    )

    on btn_detach pressed do
    (
        undo "Detach by Material ID" on
        (
            materialIdManagerCore.detachSelectedFacesByMaterialId material_names:(materialIdManagerIdsRollout.getMaterialNames())
        )

        materialIdManagerRollout.lbl_status.text = materialIdManagerCore.last_message
        materialIdManagerIdsRollout.refreshMaterialButtonColors()
        materialIdManagerSelectFacesRollout.refreshVolumeSelectList()
    )

    on btn_select_faces_camera pressed do
    (
        undo "Select Faces By Camera" on
        (
            materialIdManagerCore.selectFacesByCamera()
        )

        materialIdManagerRollout.lbl_status.text = materialIdManagerCore.last_message
    )

    on materialIdManagerEditMeshRollout open do
    (
        setupEditMeshControls()
    )
)

if materialIdManagerPresetNameRollout != undefined then
(
    try (destroyDialog materialIdManagerPresetNameRollout) catch ()
)

rollout materialIdManagerPresetNameRollout "Add Material Select Preset" width:252 height:84
(
    editText edt_preset_name "" pos:[12,12] width:228 height:20
    button btn_add "Add" pos:[12,48] width:111 height:24
    button btn_cancel "Cancel" pos:[129,48] width:111 height:24

    on btn_add pressed do
    (
        normalized_name = materialIdManagerCore.normalizeMaterialSelectPresetName edt_preset_name.text

        if normalized_name == undefined then
        (
            messageBox "Enter a non-empty preset name without [ ] or line breaks." title:"Material Select Preset"
        )
        else
        (
            material_id_manager_preset_name_value = normalized_name
            material_id_manager_preset_name_accepted = true
            destroyDialog materialIdManagerPresetNameRollout
        )
    )

    on btn_cancel pressed do
    (
        material_id_manager_preset_name_value = undefined
        material_id_manager_preset_name_accepted = false
        destroyDialog materialIdManagerPresetNameRollout
    )
)

rollout materialIdManagerSelectFacesRollout "Material Select Modifier Sets" height:270
(
    local updating_volume_select_controls = false
    local updating_volume_select_list = false
    local updating_preset_dropdown = false
    local volume_select_stack_entries = #()
    local copy_remove_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
    local preset_add_remove_tooltip = dotNetObject "System.Windows.Forms.ToolTip"

    button btn_volume_select "Volume Select" pos:[12,12] width:111 height:24 tooltip:"LMB: Build a Material Select Modifier Set from the current Face / Element selection. If no usable sub-object selection is active, fit the set to the whole object by default."
    dotNetControl btn_copy_remove "System.Windows.Forms.Button" pos:[129,12] width:111 height:24

    spinner spn_gizmo_x "X" pos:[12,48] width:72 height:24 range:[0.0,1000000000.0,1.0] type:#worldunits scale:0.1 fieldwidth:42 tooltip:"Set the active Volume Select gizmo X size in current display units."
    spinner spn_gizmo_y "Y" pos:[90,48] width:72 height:24 range:[0.0,1000000000.0,1.0] type:#worldunits scale:0.1 fieldwidth:42 tooltip:"Set the active Volume Select gizmo Y size in current display units."
    spinner spn_gizmo_z "Z" pos:[168,48] width:72 height:24 range:[0.0,1000000000.0,1.0] type:#worldunits scale:0.1 fieldwidth:42 tooltip:"Set the active Volume Select gizmo Z size. The gizmo bottom stays locked to Center Z."

    spinner spn_center_z "Center Z" pos:[12,84] width:228 height:24 range:[-1000000000.0,1000000000.0,0.0] type:#worldunits scale:1.0 fieldwidth:132 tooltip:"Set Vol__Select.center Z in current display units. The gizmo bottom stays locked to this height."

    listBox lb_volume_selects "" pos:[12,120] width:228 height:102 items:#() tooltip:"Select a Material select modifiers set by its Material ID name. Duplicate sets using the same Material ID receive matching [i] indices."

    dropDownList ddl_presets "" pos:[12,234] width:144 height:24 items:#()
    dotNetControl btn_preset_add_remove "System.Windows.Forms.Button" pos:[162,234] width:78 height:24

    /* Configure the Copy / Remove Material Select Modifier Set button and its two mouse actions.
       LMB copies the selected set; RMB removes that same selected set.
    */
    function setupCopyRemoveButton =
    (
        btn_copy_remove.Text = "Copy \\ Remove"
        copy_remove_tooltip.SetToolTip btn_copy_remove "LMB: Copy the selected Material Select Modifier Set.\n\nRMB: Remove the selected Material Select Modifier Set."
        true -- return
    )

    /* Configure the preset Add / Remove button and document both mouse actions.
       LMB saves all current sets as one named scene preset; RMB deletes the selected preset section.
    */
    function setupPresetAddRemoveButton =
    (
        btn_preset_add_remove.Text = "Add \\ Remove"
        preset_add_remove_tooltip.SetToolTip btn_preset_add_remove "LMB: Save all Material Select Modifier Set material IDs and X/Y/Z gizmo sizes as a named scene preset.\n\nRMB: Remove the preset selected in the dropdown."
        true -- return
    )

    /* Ask for one preset name in a modal edit dialog.
       Returns the normalized name when Add is accepted, or undefined when the dialog is cancelled.
    */
    function promptPresetName =
    (
        material_id_manager_preset_name_value = undefined
        material_id_manager_preset_name_accepted = false
        materialIdManagerPresetNameRollout.edt_preset_name.text = ""
        createDialog materialIdManagerPresetNameRollout 252 84 modal:true style:#(#style_titlebar,#style_sysmenu)

        if material_id_manager_preset_name_accepted then material_id_manager_preset_name_value else undefined -- return
    )

    /* Rebuild the scene-preset dropdown from INI section names without triggering a preset load.
       A neutral first row prevents tool open or refresh from loading a preset automatically.
    */
    function refreshPresetDropdown preferred_name:"" =
    (
        preset_names = materialIdManagerSettings.getMaterialSelectPresetNames()
        display_items = #("<Preset>")

        for preset_name in preset_names do
        (
            append display_items preset_name
        )

        updating_preset_dropdown = true
        ddl_presets.items = display_items
        target_selection = 1

        if preferred_name != "" then
        (
            preset_index = findItem preset_names preferred_name

            if preset_index > 0 then
            (
                target_selection = preset_index + 1
            )
        )

        ddl_presets.selection = target_selection
        updating_preset_dropdown = false
        preset_names -- return
    )

    /* Return the actual preset section name selected in the dropdown.
       The neutral first row returns undefined and cannot be loaded or removed.
    */
    function getSelectedPresetName =
    (
        preset_name = undefined
        preset_index = ddl_presets.selection

        if preset_index > 1 and preset_index <= ddl_presets.items.count then
        (
            preset_name = ddl_presets.items[preset_index]
        )

        preset_name -- return
    )

    /* Resolve the Volume Select belonging to the currently selected list row.
       Returns undefined when no single object or valid Material Select Modifier Set row is selected.
    */
    function getSelectedMaterialSelectVolume =
    (
        volume_select_mod = undefined
        item_index = lb_volume_selects.selection

        if (
            selection.count == 1 and
            item_index >= 1 and
            item_index <= volume_select_stack_entries.count
        ) then
        (
            volume_select_mod = volume_select_stack_entries[item_index][2]
        )

        volume_select_mod -- return
    )

    /* Read the three size spinners as one Point3 in system world units.
       The #worldunits controls display those internal values using the current 3ds Max Display Units.
    */
    function getGizmoSize =
    (
        [spn_gizmo_x.value, spn_gizmo_y.value, spn_gizmo_z.value] -- return
    )

    /* Fit the pair list to the current rollout and keep the preset row directly below it.
       The list grows or shrinks vertically while the preset dropdown/button stay bottom-pinned.
    */
    function fitListBoxToRollout rollout_height =
    (
        preset_row_y = rollout_height - 36
        list_height = preset_row_y - lb_volume_selects.pos.y - 12

        if list_height < 24 then
        (
            list_height = 24
            preset_row_y = lb_volume_selects.pos.y + list_height + 12
        )

        lb_volume_selects.height = list_height
        ddl_presets.pos = [12,preset_row_y]
        btn_preset_add_remove.pos = [162,preset_row_y]
        list_height -- return
    )

    /* Mirror the backend status into the parent rollout status label.
       The child rollout owns no geometry or modifier processing.
    */
    function refreshStatus =
    (
        materialIdManagerRollout.lbl_status.text = materialIdManagerCore.last_message
        materialIdManagerCore.last_message -- return
    )

    /* Load the active Volume Select gizmo size and center Z into the controls.
       Spinner events are suspended while values are copied from the live modifier.
    */
    function loadActiveVolumeSelectControls =
    (
        result_value = false
        state_value = materialIdManagerCore.getActiveVolumeSelectState()

        if state_value != undefined then
        (
            gizmo_size = state_value[1]
            center_position = state_value[2]

            updating_volume_select_controls = true
            spn_gizmo_x.value = gizmo_size.x
            spn_gizmo_y.value = gizmo_size.y
            spn_gizmo_z.value = gizmo_size.z
            spn_center_z.value = center_position.z
            updating_volume_select_controls = false
            result_value = true
        )

        result_value -- return
    )

    /* Rebuild the Material Select Modifier Set list for the selected object's live modifier stack.
       Missing Material modifiers are repaired, explicit Material IDs are preserved, and set names are synchronized.
    */
    function refreshVolumeSelectList =
    (
        result_value = false
        debug_target_node = if selection.count == 1 then selection[1] else undefined

        if materialIdManagerCore.volume_debug_active then
        (
            materialIdManagerCore.logVolumeSelectDebugStage 29 "refreshVolumeSelectList BEGIN" target_node:debug_target_node
        )

        if not updating_volume_select_list and not materialIdManagerCore.volume_add_in_progress then
        (
            updating_volume_select_list = true
            display_items = #()
            active_list_index = 0
            current_object = undefined
            volume_select_stack_entries = #()

            if selection.count == 1 and isValidNode selection[1] then
            (
                target_node = selection[1]
                sync_result = true
                pairs_need_sync = materialIdManagerCore.volumeMaterialPairsNeedSync target_node

                if materialIdManagerCore.volume_debug_active then
                (
                    materialIdManagerCore.writeVolumeSelectDebugLog ("refresh pairs sync : " + (pairs_need_sync as string))
                    materialIdManagerCore.logVolumeSelectDebugStage 30 "refreshVolumeSelectList PAIR CHECK" target_node:target_node
                )

                if pairs_need_sync then
                (
                    if materialIdManagerCore.volume_debug_active then
                    (
                        materialIdManagerCore.logVolumeSelectDebugStage 31 "BEFORE synchronizeVolumeMaterialPairs" target_node:target_node
                    )

                    undo "Repair Material Select Modifier Sets" on
                    (
                        sync_result = materialIdManagerCore.synchronizeVolumeMaterialPairs target_node
                    )

                    if materialIdManagerCore.volume_debug_active then
                    (
                        materialIdManagerCore.logVolumeSelectDebugStage 32 "AFTER synchronizeVolumeMaterialPairs" target_node:target_node
                    )
                )

                if sync_result then
                (
                    materialIdManagerCore.syncMaterialSelectModifierSetNames target_node
                    volume_select_stack_entries = materialIdManagerCore.getVolumeSelectStackEntries target_node

                    if materialIdManagerCore.volume_debug_active then
                    (
                        materialIdManagerCore.writeVolumeSelectDebugLog ("refresh pair rows  : " + (volume_select_stack_entries.count as string))
                        materialIdManagerCore.logVolumeSelectDebugStage 33 "AFTER getVolumeSelectStackEntries" target_node:target_node
                    )

                    if getCommandPanelTaskMode() == #modify then
                    (
                        current_object = modPanel.getCurrentObject()
                    )

                    for entry_index = 1 to volume_select_stack_entries.count do
                    (
                        stack_entry = volume_select_stack_entries[entry_index]
                        stack_index = stack_entry[1]
                        volume_select_mod = stack_entry[2]
                        material_stack_index = stack_entry[3]
                        material_mod = stack_entry[4]
                        material_id = stack_entry[5]

                        if material_mod == undefined then
                        (
                            append display_items volume_select_mod.name
                        )
                        else
                        (
                            select_suffix = " SELECT"
                            set_name = volume_select_mod.name

                            if set_name.count > select_suffix.count and (substring set_name (set_name.count - select_suffix.count + 1) select_suffix.count) == select_suffix then
                            (
                                set_name = substring set_name 1 (set_name.count - select_suffix.count)
                            )

                            append display_items set_name
                        )

                        if current_object == volume_select_mod or current_object == material_mod then
                        (
                            active_list_index = entry_index
                        )
                    )

                    result_value = true
                )
            )

            if materialIdManagerCore.volume_debug_active then
            (
                materialIdManagerCore.writeVolumeSelectDebugLog ("refresh active row : " + (active_list_index as string))
                materialIdManagerCore.logVolumeSelectDebugStage 34 "BEFORE listBox items assignment" target_node:debug_target_node
            )

            lb_volume_selects.items = display_items

            if materialIdManagerCore.volume_debug_active then
            (
                materialIdManagerCore.logVolumeSelectDebugStage 35 "AFTER listBox items assignment" target_node:debug_target_node
            )

            lb_volume_selects.selection = active_list_index

            if materialIdManagerCore.volume_debug_active then
            (
                materialIdManagerCore.logVolumeSelectDebugStage 36 "AFTER listBox selection assignment" target_node:debug_target_node
            )

            updating_volume_select_list = false

            if active_list_index > 0 and current_object != undefined and classOf current_object == VolumeSelect then
            (
                if materialIdManagerCore.volume_debug_active then
                (
                    materialIdManagerCore.logVolumeSelectDebugStage 37 "BEFORE loadActiveVolumeSelectControls" target_node:debug_target_node
                )

                loadActiveVolumeSelectControls()

                if materialIdManagerCore.volume_debug_active then
                (
                    materialIdManagerCore.logVolumeSelectDebugStage 38 "AFTER loadActiveVolumeSelectControls" target_node:debug_target_node
                )
            )
        )

        if materialIdManagerCore.volume_debug_active then
        (
            materialIdManagerCore.logVolumeSelectDebugStage 39 "refreshVolumeSelectList END" target_node:debug_target_node
        )

        result_value -- return
    )

    /* Activate one list entry's exact Volume Select modifier and synchronize its live controls.
       Returns false when the list index is no longer valid for the current selected object's stack.
    */
    function activateVolumeSelectListItem item_index =
    (
        result_value = false

        if (
            selection.count == 1 and
            item_index >= 1 and
            item_index <= volume_select_stack_entries.count
        ) then
        (
            target_node = selection[1]
            stack_entry = volume_select_stack_entries[item_index]
            volume_select_mod = stack_entry[2]

            updating_volume_select_list = true
            result_value = materialIdManagerCore.activateVolumeSelectModifier target_node volume_select_mod
            updating_volume_select_list = false

            if result_value then
            (
                lb_volume_selects.selection = item_index
                loadActiveVolumeSelectControls()
            )
        )

        if not result_value then
        (
            refreshVolumeSelectList()
        )

        result_value -- return
    )

    /* Remote-control the active Volume Select gizmo with the X/Y size spinners.
       After resizing, reload the live modifier state so the UI always reflects the actual result.
    */
    function applyActiveGizmoSize =
    (
        result_value = false

        undo "Resize Volume Select Gizmo" on
        (
            result_value = materialIdManagerCore.resizeActiveVolumeSelectGizmo (getGizmoSize())
        )

        if result_value then
        (
            loadActiveVolumeSelectControls()
        )

        refreshStatus()
        materialIdManagerCore.last_message -- return
    )

    /* Remote-control only the active Volume Select Z height.
       After scaling, the gizmo is realigned so its bottom is exactly on the modifier center Z.
    */
    function applyActiveGizmoHeight gizmo_height =
    (
        result_value = false

        undo "Resize Volume Select Gizmo Z" on
        (
            result_value = materialIdManagerCore.resizeActiveVolumeSelectGizmoHeight gizmo_height
        )

        if result_value then
        (
            loadActiveVolumeSelectControls()
        )

        refreshStatus()
        materialIdManagerCore.last_message -- return
    )

    on btn_volume_select pressed do
    (
        creation_result = false
        updating_volume_select_list = true

        undo "Add Volume Select" on
        (
            creation_result = materialIdManagerCore.addVolumeSelect()
        )

        if selection.count == 1 then
        (
            materialIdManagerCore.logVolumeSelectDebugStage 27 "RETURNED FROM addVolumeSelect / undo block" target_node:selection[1]
        )

        updating_volume_select_list = false

        if selection.count == 1 then
        (
            materialIdManagerCore.logVolumeSelectDebugStage 28 "BEFORE post-add refreshVolumeSelectList" target_node:selection[1]
        )

        refreshVolumeSelectList()
        refreshStatus()

        if selection.count == 1 then
        (
            materialIdManagerCore.finishVolumeSelectDebug target_node:selection[1]
        )
        else
        (
            materialIdManagerCore.finishVolumeSelectDebug()
        )
    )

    on btn_copy_remove MouseUp sender event_args do
    (
        mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"
        selected_volume_mod = getSelectedMaterialSelectVolume()

        if selection.count != 1 or selected_volume_mod == undefined then
        (
            materialIdManagerCore.setMessage "Select one Material Select Modifier Set in the list first."
        )
        else
        (
            target_node = selection[1]

            if event_args.Button == mouse_buttons.Left then
            (
                undo "Copy Material Select Modifier Set" on
                (
                    materialIdManagerCore.copyMaterialSelectModifierSet target_node selected_volume_mod
                )
            )
            else if event_args.Button == mouse_buttons.Right then
            (
                undo "Remove Material Select Modifier Set" on
                (
                    materialIdManagerCore.removeMaterialSelectModifierSet target_node selected_volume_mod
                )
            )
        )

        refreshVolumeSelectList()
        refreshStatus()
    )

    on btn_preset_add_remove MouseUp sender event_args do
    (
        mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"

        if event_args.Button == mouse_buttons.Left then
        (
            if selection.count != 1 or not (isValidNode selection[1]) then
            (
                materialIdManagerCore.setMessage "Select one object with Material Select Modifier Sets before adding a preset."
            )
            else
            (
                preset_name = promptPresetName()

                if preset_name != undefined then
                (
                    preset_ini_path = materialIdManagerSettings.getSceneMaterialSelectPresetIniPath()

                    if preset_ini_path == undefined then
                    (
                        materialIdManagerCore.setMessage "Save the .max scene before adding Material Select presets."
                    )
                    else
                    (
                        save_confirmed = true

                        if materialIdManagerSettings.hasMaterialSelectPreset preset_name preset_ini_path:preset_ini_path then
                        (
                            save_confirmed = queryBox ("Preset \"" + preset_name + "\" already exists. Replace it?") title:"Material Select Preset"
                        )

                        if save_confirmed then
                        (
                            if materialIdManagerCore.saveMaterialSelectPreset selection[1] preset_name preset_ini_path:preset_ini_path then
                            (
                                refreshPresetDropdown preferred_name:preset_name
                            )
                        )
                    )
                )
            )
        )
        else if event_args.Button == mouse_buttons.Right then
        (
            preset_name = getSelectedPresetName()

            if preset_name == undefined then
            (
                materialIdManagerCore.setMessage "Select a Material Select preset in the dropdown before removing it."
            )
            else
            (
                remove_confirmed = queryBox ("Remove preset \"" + preset_name + "\"?") title:"Material Select Preset"

                if remove_confirmed then
                (
                    if materialIdManagerCore.removeMaterialSelectPreset preset_name then
                    (
                        refreshPresetDropdown()
                    )
                )
            )
        )

        refreshStatus()
    )

    on ddl_presets selected preset_index do
    (
        if not updating_preset_dropdown then
        (
            preset_name = getSelectedPresetName()

            if preset_name != undefined then
            (
                if selection.count != 1 or not (isValidNode selection[1]) then
                (
                    materialIdManagerCore.setMessage "Select one object before loading a Material Select preset."
                    refreshPresetDropdown()
                )
                else
                (
                    load_confirmed = queryBox ("Load preset \"" + preset_name + "\"?\n\nCurrent Material Select Modifier Sets on the selected object will be replaced.") title:"Load Material Select Preset"

                    if load_confirmed then
                    (
                        undo "Load Material Select Preset" on
                        (
                            materialIdManagerCore.applyMaterialSelectPreset selection[1] preset_name
                        )

                        refreshVolumeSelectList()
                        refreshStatus()
                    )
                    else
                    (
                        refreshPresetDropdown()
                    )
                )
            )
        )
    )

    on lb_volume_selects selected item_index do
    (
        if not updating_volume_select_list then
        (
            activateVolumeSelectListItem item_index
            refreshStatus()
        )
    )

    on spn_gizmo_x changed spinner_value do
    (
        if not updating_volume_select_controls then
        (
            applyActiveGizmoSize()
        )
    )

    on spn_gizmo_y changed spinner_value do
    (
        if not updating_volume_select_controls then
        (
            applyActiveGizmoSize()
        )
    )

    on spn_gizmo_z changed spinner_value do
    (
        if not updating_volume_select_controls then
        (
            applyActiveGizmoHeight spinner_value
        )
    )

    on spn_center_z changed spinner_value do
    (
        if not updating_volume_select_controls then
        (
            move_result = false

            undo "Move Volume Select Center Z" on
            (
                move_result = materialIdManagerCore.setActiveVolumeSelectCenterZ spinner_value
            )

            if move_result then
            (
                loadActiveVolumeSelectControls()
            )

            refreshStatus()
        )
    )

    on materialIdManagerSelectFacesRollout open do
    (
        setupCopyRemoveButton()
        setupPresetAddRemoveButton()
        refreshPresetDropdown()

        if isProperty spn_gizmo_x #autoscale then
        (
            spn_gizmo_x.autoscale = false
            spn_gizmo_y.autoscale = false
            spn_gizmo_z.autoscale = false

            spn_gizmo_x.scale = 0.1
            spn_gizmo_y.scale = 0.1
            spn_gizmo_z.scale = 0.1
        )

        fitListBoxToRollout materialIdManagerSelectFacesRollout.height
        refreshVolumeSelectList()
    )
)

rollout materialIdManagerRollout material_id_manager_rollout_title
(
    subRollout sub_material_ids "" pos:[12,12] width:264 height:42 scrollBar:#off
    subRollout sub_material_setup "" pos:[12,66] width:264 height:228
    subRollout sub_edit_mesh "" pos:[12,306] width:264 height:126
    subRollout sub_select_faces "" pos:[12,444] width:264 height:294

    label lbl_status "Ready." pos:[12,684] width:264 height:24
    button btn_restart "Restart" pos:[12,720] width:264 height:24 tooltip:"LMB: Load the newest matching version of this tool, or reload the current version."

    /* Fit the vertically resizable dialog while keeping the complete dialog at 288 px width.
       Material IDs and Material Setup both resize to their live row counts, with no Material IDs scrollbar.
    */
    function layoutDialog dialog_size =
    (
        effective_height = dialog_size.y
        ids_child_height = materialIdManagerIdsRollout.height
        ids_slot_height = ids_child_height + 24
        setup_y = 12 + ids_slot_height + 12
        setup_child_height = materialIdManagerMaterialSetupRollout.height
        setup_slot_height = setup_child_height + 24
        edit_mesh_y = setup_y + setup_slot_height + 12
        select_faces_y = edit_mesh_y + 126 + 12
        minimum_height = select_faces_y + 378

        if effective_height < minimum_height then
        (
            effective_height = minimum_height
            setDialogSize materialIdManagerRollout [288,effective_height]
        )

        sub_material_ids.height = ids_slot_height
        sub_material_setup.pos = [12,setup_y]
        sub_material_setup.height = setup_slot_height
        sub_edit_mesh.pos = [12,edit_mesh_y]
        sub_select_faces.pos = [12,select_faces_y]

        status_y = effective_height - 72
        restart_y = effective_height - 36
        subrollout_height = status_y - (select_faces_y + 12)
        child_rollout_height = subrollout_height - 24

        sub_select_faces.height = subrollout_height
        lbl_status.pos = [12,status_y]
        btn_restart.pos = [12,restart_y]

        materialIdManagerSelectFacesRollout.height = child_rollout_height
        materialIdManagerSelectFacesRollout.fitListBoxToRollout child_rollout_height
        materialIdManagerSettings.saveDialogHeight effective_height

        effective_height -- return
    )

    on btn_restart pressed do
    (
        materialIdManagerCore.restartNewestVersion()
    )

    on materialIdManagerRollout open do
    (
        addSubRollout sub_material_ids materialIdManagerIdsRollout
        addSubRollout sub_material_setup materialIdManagerMaterialSetupRollout
        addSubRollout sub_edit_mesh materialIdManagerEditMeshRollout
        addSubRollout sub_select_faces materialIdManagerSelectFacesRollout
        materialIdManagerMaterialSetupRollout.layoutMaterialIdSetRows()
        layoutDialog (getDialogSize materialIdManagerRollout)
        materialIdManagerSelectFacesRollout.refreshVolumeSelectList()

        callbacks.removeScripts id:#materialIdManagerVolumeSelectList
        callbacks.addScript #selectionSetChanged "materialIdManagerIdsRollout.fitToCurrentMultiMaterial(); materialIdManagerIdsRollout.refreshMaterialButtonColors(); materialIdManagerSelectFacesRollout.refreshVolumeSelectList()" id:#materialIdManagerVolumeSelectList persistent:false
        callbacks.addScript #postModifierAdded "materialIdManagerSelectFacesRollout.refreshVolumeSelectList()" id:#materialIdManagerVolumeSelectList persistent:false
        callbacks.addScript #postModifierDeleted "materialIdManagerSelectFacesRollout.refreshVolumeSelectList()" id:#materialIdManagerVolumeSelectList persistent:false
        callbacks.addScript #filePostOpen "materialIdManagerIdsRollout.fitToCurrentMultiMaterial(); materialIdManagerSelectFacesRollout.refreshPresetDropdown(); materialIdManagerSelectFacesRollout.refreshVolumeSelectList()" id:#materialIdManagerVolumeSelectList persistent:false
        callbacks.addScript #filePostSave "materialIdManagerSelectFacesRollout.refreshPresetDropdown()" id:#materialIdManagerVolumeSelectList persistent:false
        callbacks.addScript #systemPostNew "materialIdManagerSelectFacesRollout.refreshPresetDropdown(); materialIdManagerSelectFacesRollout.refreshVolumeSelectList()" id:#materialIdManagerVolumeSelectList persistent:false
    )

    on materialIdManagerRollout close do
    (
        callbacks.removeScripts id:#materialIdManagerVolumeSelectList
    )

    on materialIdManagerRollout moved dialog_pos do
    (
        materialIdManagerSettings.saveDialogPosition dialog_pos
    )

    on materialIdManagerRollout resized dialog_size do
    (
        layoutDialog dialog_size
    )
)

dialog_pos = materialIdManagerSettings.loadDialogPosition()
dialog_height = materialIdManagerSettings.loadDialogHeight()

if dialog_height == undefined then
(
    dialog_height = 1248
)

if dialog_pos == undefined then
(
    createDialog materialIdManagerRollout width:288 height:dialog_height style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing) lockWidth:true lockHeight:false
)
else
(
    createDialog materialIdManagerRollout width:288 height:dialog_height pos:dialog_pos style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing) lockWidth:true lockHeight:false
)

try
(
    cui.RegisterDialogBar materialIdManagerRollout minSize:[288,240] maxSize:[288,-1] style:#(#cui_dock_left, #cui_dock_right, #cui_floatable, #cui_handles)
)
catch
(
    dialog_bar_register_exception = getCurrentException()
    format "Material ID Manager: could not register the window for left/right docking: %\n" dialog_bar_register_exception
)

windows.processPostedMessages()

/* Load scene presets and Volume Select / Material pairs after all child rollouts finish initializing.
   Preset sections are read from the current saved scene's companion INI without loading any preset automatically.
*/
materialIdManagerSelectFacesRollout.refreshPresetDropdown()
materialIdManagerSelectFacesRollout.refreshVolumeSelectList()
