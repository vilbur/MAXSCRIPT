/*
Vertex Level Aligner UI 0.496
Frontend-only module. Uses a .NET TreeView for level selection and a native RMB alignment menu while keeping the rollout title literal and static.
*/

global vertex_level_aligner
global epoly_tools_project_version
global vertex_level_aligner_ui
global vertex_level_aligner_rollout
global vertex_level_aligner_ui_source_path
global reloadVertexLevelAlignerMain
global vertex_level_aligner_default_threshold
global vertex_level_aligner_context_menu

vertex_level_aligner_default_threshold = 0.0

if epoly_tools_project_version == undefined or epoly_tools_project_version < 1.117 then
(
    epoly_tools_project_version = 1.117
)

vertexLevelAlignerWriteLog "100 UI file execution started"
vertex_level_aligner_ui_source_path = getSourceFileName()
vertexLevelAlignerWriteLog "101 UI source path resolved"
vertexLevelAlignerWriteLog "105 UI frontend module loading"

struct vertex_level_aligner_ui_v
(
    file_version = 0.496,
    project_version = 1.117,
    source_path = vertex_level_aligner_ui_source_path,
    ini_path = (getDir #plugcfg + "\\Vertex-Level-Aligner.ini"),
    ini_section = "MainUI",
    is_rebuilding_tree = false,

    /*
    Reads one persisted integer or returns the supplied default.
    Invalid INI values are ignored safely.
    */
    function getIniInteger key_name default_value =
    (
        setting_text = ""

        try
        (
            setting_text = getINISetting ini_path ini_section key_name
        )
        catch
        (
            ini_integer_read_exception = getCurrentException()
            return default_value
        )

        if setting_text == "" then return default_value

        parsed_value = default_value

        try
        (
            parsed_value = setting_text as integer
        )
        catch
        (
            ini_integer_exception = getCurrentException()
            parsed_value = default_value
        )

        parsed_value
        -- return
    ),

    /*
    Reads one persisted float or returns the supplied default.
    Invalid INI values are ignored safely.
    */
    function getIniFloat key_name default_value =
    (
        setting_text = ""

        try
        (
            setting_text = getINISetting ini_path ini_section key_name
        )
        catch
        (
            ini_float_read_exception = getCurrentException()
            return default_value
        )

        if setting_text == "" then return default_value

        parsed_value = default_value

        try
        (
            parsed_value = setting_text as float
        )
        catch
        (
            ini_float_exception = getCurrentException()
            parsed_value = default_value
        )

        parsed_value
        -- return
    ),

    /*
    Writes one UI value to the tool INI file as text.
    This helper is used for threshold, mode, position, and size persistence.
    */
    function setIniValue key_name value =
    (
        write_ok = true

        try
        (
            setINISetting ini_path ini_section key_name (value as string)
        )
        catch
        (
            ini_write_exception = getCurrentException()
            write_ok = false
        )

        write_ok
        -- return
    ),

    /*
    Returns true only when this rollout currently owns a standalone CreateDialog window.
    Rollout.inDialog is specific to CreateDialog ownership and stays false for embedded manager rollouts.
    */
    function isStandaloneDialogOpen =
    (
        vertex_level_aligner_rollout.inDialog
        -- return
    ),


    /*
    Opens the standalone dialog using the last valid position and resizable dimensions.
    Width and height are clamped so required controls cannot disappear.
    */
    function showUI =
    (
        vertexLevelAlignerWriteLog "200 UI showUI entered"

        dialog_x = getIniInteger "PosX" 120
        dialog_y = getIniInteger "PosY" 120
        dialog_width = 320
        dialog_height = getIniInteger "Height" 576
        vertexLevelAlignerWriteLog "201 UI persisted dialog values read"

        if dialog_height < 360 then dialog_height = 360

        vertexLevelAlignerWriteLog "202 UI before createDialog"
        createDialog vertex_level_aligner_rollout width:dialog_width height:dialog_height pos:[dialog_x, dialog_y] lockWidth:true lockHeight:false autoLayoutOnResize:false style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing)
        vertexLevelAlignerWriteLog "203 UI createDialog returned"
        true
        -- return
    ),

    /*
    Closes only a standalone dialog owned by this frontend.
    Embedded manager rollouts are never passed to DestroyDialog.
    */
    function hideUI =
    (
        dialog_is_open = false

        try
        (
            dialog_is_open = this.isStandaloneDialogOpen()
        )
        catch
        (
            dialog_state_exception = getCurrentException()
            return false
        )

        if dialog_is_open then
        (
            destroy_ok = true

            try
            (
                destroyDialog vertex_level_aligner_rollout
            )
            catch
            (
                destroy_exception = getCurrentException()
                destroy_ok = false
            )

            if not(destroy_ok) then return false
        )

        true
        -- return
    ),

    /*
    Reloads the canonical backend so development changes are picked up without restarting 3ds Max.
    The frontend keeps calling the refreshed global backend instance.
    */
    function reloadLatestScript =
    (
        if reloadVertexLevelAlignerMain == undefined then return false

        reloadVertexLevelAlignerMain()
        -- return
    ),

    on create do
    (
    )
)

vertexLevelAlignerWriteLog "110 UI before API struct instance"
vertex_level_aligner_ui = vertex_level_aligner_ui_v()
vertexLevelAlignerWriteLog "111 UI API struct instance created"
vertexLevelAlignerWriteLog "115 UI literal static title ready"

rcmenu vertex_level_aligner_context_menu
(
    menuItem mi_align_here "Align to Axis"
    separator sep_align_here
    menuItem mi_align_up "Align UP"
    menuItem mi_align_middle "Align MIDDLE"
    menuItem mi_align_down "Align DOWN"
    separator sep_round_actions
    menuItem mi_round_up "Round to next"
    menuItem mi_round_down "Round to previous"
    separator sep_tree_actions
    menuItem mi_collapse_all "Collapse All"
    menuItem mi_expand_all "Expand All"

    on mi_align_here picked do
    (
        if vertex_level_aligner_rollout != undefined then
        (
            vertex_level_aligner_rollout.alignContextHere()
        )
    )

    on mi_align_up picked do
    (
        if vertex_level_aligner_rollout != undefined then
        (
            vertex_level_aligner_rollout.alignContextTarget #top
        )
    )

    on mi_align_middle picked do
    (
        if vertex_level_aligner_rollout != undefined then
        (
            vertex_level_aligner_rollout.alignContextTarget #middle
        )
    )

    on mi_align_down picked do
    (
        if vertex_level_aligner_rollout != undefined then
        (
            vertex_level_aligner_rollout.alignContextTarget #bottom
        )
    )

    on mi_round_up picked do
    (
        if vertex_level_aligner_rollout != undefined then
        (
            vertex_level_aligner_rollout.roundContextTarget #up
        )
    )

    on mi_round_down picked do
    (
        if vertex_level_aligner_rollout != undefined then
        (
            vertex_level_aligner_rollout.roundContextTarget #down
        )
    )

    on mi_collapse_all picked do
    (
        if vertex_level_aligner_rollout != undefined then
        (
            vertex_level_aligner_rollout.collapseAllLevels()
        )
    )

    on mi_expand_all picked do
    (
        if vertex_level_aligner_rollout != undefined then
        (
            vertex_level_aligner_rollout.expandAllLevels()
        )
    )
)

rollout vertex_level_aligner_rollout "Vertex Level Aligner 1.117" width:320 height:576
(
    local context_target_tag = ""
    local selected_tree_tags = #()
    local is_ctrl_tree_selection = false
    local is_context_tree_selection = false
    local is_updating_display_trim = false
    local is_updating_world_axis = false

    button btn_scan "SCAN OBJECT" pos:[8,3] width:148 height:32 tooltip:"LMB: Scan the first selected Editable Poly or Edit Poly object."
    checkbutton cb_axis_x "X" pos:[164,3] width:48 height:32 checked:false tooltip:"LMB: Use world X for level detection, threshold grouping, selection, offset display, and alignment."
    checkbutton cb_axis_y "Y" pos:[214,3] width:48 height:32 checked:false tooltip:"LMB: Use world Y for level detection, threshold grouping, selection, offset display, and alignment."
    checkbutton cb_axis_z "Z" pos:[264,3] width:48 height:32 checked:true tooltip:"LMB: Use world Z for level detection, threshold grouping, selection, offset display, and alignment."
    spinner spn_threshold "Threshold:" pos:[8,43] width:120 height:18 range:[0.0, 1000000.0, 0.0] type:#float scale:0.1 fieldWidth:52 align:#left tooltip:"0.0 mm: List every detected level separately.\n\nAbove 0.0 mm: Group nearby detected levels when each gap to the next level is within Threshold.\n\nBROKEN: A group containing more than one detected level.\n\nThreshold groups levels only; it does not move vertices.\n\nUnits: millimeters."
    dropdownlist ddl_round_precision "" pos:[136,41] width:80 height:20 items:#("EXACT", "BUILDING", "MODEL", "PRINT") selection:2 tooltip:"EXACT: Round on a 0.001 mm step.\n\nBUILDING: Round on a 1 mm step.\n\nMODEL: Round on a 0.1 mm step.\n\nPRINT: Round on a 0.05 mm step.\n\nUsed by TreeView RMB rounding."
    label lbl_display_trim "Remove:" pos:[224,44] width:40 height:18 align:#left
    dropdownlist ddl_display_trim "" pos:[264,41] width:48 height:20 items:#("", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10") selection:1 tooltip:"Display only: hide this many leading integer digits from TreeView position values on the current X/Y/Z axis. Blank shows the full coordinate. Real position data is never changed."
    radiobuttons rb_view_mode labels:#("ALL LEVELS", "BROKEN ONLY") columns:2 default:1 pos:[8,69] width:184 height:28 align:#left tooltip:"ALL LEVELS: Show every level group on the selected world axis.\n\nBROKEN ONLY: Show only groups containing multiple exact axis levels connected by threshold-sized neighboring gaps."
    button btn_expand_collapse "Expand \\ Collapse" pos:[200,67] width:112 height:24 tooltip:"LMB: Expand selected group(s), or all groups when none is selected.\n\nRMB: Collapse selected group(s), or all groups when none is selected."
    label lbl_level_vertex_filter "Level verts:" pos:[8,100] width:64 height:18 align:#left
    dropdownlist ddl_level_vertex_condition "" pos:[80,97] width:112 height:20 items:#("EQUAL", "MORE", "LESS") selection:1 tooltip:"EQUAL: Show levels with exactly the selected vertex count.\n\nMORE: Show levels with more than the selected vertex count.\n\nLESS: Show levels with fewer than the selected vertex count."
    dropdownlist ddl_level_vertex_count "" pos:[200,97] width:112 height:20 items:#("") selection:1 tooltip:"Filter TreeView LEVEL rows by vertex count.\n\nBlank disables this filter."
    label lbl_face_material_id "Mat ID:" pos:[8,124] width:64 height:18 align:#left
    dropdownlist ddl_face_material_id "" pos:[80,121] width:72 height:20 items:#("1") selection:1 tooltip:"Choose Material ID 1 through 100."
    button btn_apply_face_material_id "SET POLY MAT ID" pos:[160,119] width:152 height:24 tooltip:"LMB: Apply the chosen Material ID only to polygons whose every vertex belongs to the selected TreeView level(s)."
    label lbl_status "Select one Editable Poly or Edit Poly object." pos:[8,149] width:304 height:18 align:#left
    dotNetControl tv_levels "System.Windows.Forms.TreeView" pos:[8,170] width:304 height:340
    label lbl_definition "BBox: —" pos:[8,518] width:248 height:18 align:#left
    dropdownlist ddl_bbox_unit "" pos:[264,515] width:48 height:20 items:#("mm", "cm", "m") selection:1 tooltip:"Choose the display unit for the local bounding-box size."
    button btn_restart "RESTART" pos:[8,544] width:224 height:24 tooltip:"LMB: Close this dialog and reload the canonical Vertex Level Aligner package."
    checkbox cb_debug "DEBUG" pos:[240,547] width:72 height:18 checked:false tooltip:"Enable Listener position diagnostics for TreeView selections."

    /*
    Returns the selected X/Y/Z checkbutton index. Exactly one axis is kept checked at all times.
    */
    function getSelectedWorldAxisIndex =
    (
        if cb_axis_x.checked then return 1
        if cb_axis_y.checked then return 2
        3
        -- return
    )

    /*
    Converts the selected X/Y/Z checkbutton state to a world-axis symbol.
    */
    function getSelectedWorldAxis =
    (
        case getSelectedWorldAxisIndex() of
        (
            1: #x
            2: #y
            default: #z
        )
        -- return
    )

    /*
    Returns one stored world-axis symbol as the matching checkbutton index.
    */
    function getWorldAxisIndex world_axis_value =
    (
        case world_axis_value of
        (
            #x: 1
            #y: 2
            default: 3
        )
        -- return
    )

    /*
    Builds the blank/off plus 1..100 vertex-count dropdown items.
    The blank first item disables vertex-count filtering.
    */
    function buildLevelVertexCountFilterItems =
    (
        filter_items = #("")

        for level_vertex_count = 1 to 100 do
        (
            append filter_items (level_vertex_count as string)
        )

        filter_items
        -- return
    )

    /*
    Builds the 1..100 Material ID dropdown items used by polygon assignment.
    */
    function buildFaceMaterialIdItems =
    (
        material_id_items = #()

        for material_id_value = 1 to 100 do
        (
            append material_id_items (material_id_value as string)
        )

        material_id_items
        -- return
    )

    /*
    Returns the 1-based Material ID selected for polygon assignment.
    */
    function getSelectedFaceMaterialId =
    (
        selected_material_id = ddl_face_material_id.selection
        if selected_material_id < 1 then selected_material_id = 1
        if selected_material_id > 100 then selected_material_id = 100

        selected_material_id
        -- return
    )

    /*
    Returns the selected level vertex-count filter value.
    Zero means the blank/off dropdown item is selected.
    */
    function getSelectedLevelVertexCountFilterValue =
    (
        filter_value = ddl_level_vertex_count.selection - 1
        if filter_value < 0 then filter_value = 0
        filter_value
        -- return
    )

    /*
    Tests one exact LEVEL vertex count against EQUAL, MORE, or LESS.
    A filter value of zero keeps every level visible.
    */
    function levelVertexCountMatchesFilter level_vertex_count condition_index filter_value =
    (
        if filter_value <= 0 then return true

        case condition_index of
        (
            1: level_vertex_count == filter_value
            2: level_vertex_count > filter_value
            3: level_vertex_count < filter_value
            default: true
        )
        -- return
    )

    /*
    Returns true when at least one exact LEVEL in a group passes the active vertex-count filter.
    */
    function groupHasMatchingLevelVertexCount exact_levels condition_index filter_value =
    (
        if not(isKindOf exact_levels Array) then return false

        for level_data in exact_levels do
        (
            if level_data != undefined and level_data.count >= 2 and level_data[2] != undefined then
            (
                level_vertex_count = level_data[2].numberSet

                if levelVertexCountMatchesFilter level_vertex_count condition_index filter_value then
                (
                    return true
                )
            )
        )

        false
        -- return
    )

    /*
    Applies one mandatory X/Y/Z checkbutton state without allowing all axes to become unchecked.
    */
    function setWorldAxisControls axis_index =
    (
        if axis_index < 1 or axis_index > 3 then axis_index = 3

        controls_ok = true
        is_updating_world_axis = true

        try
        (
            cb_axis_x.checked = (axis_index == 1)
            cb_axis_y.checked = (axis_index == 2)
            cb_axis_z.checked = (axis_index == 3)
        )
        catch
        (
            axis_control_exception = getCurrentException()
            controls_ok = false
        )

        is_updating_world_axis = false
        if not(controls_ok) then return false

        vertex_level_aligner.world_axis = getSelectedWorldAxis()
        vertex_level_aligner_ui.setIniValue "WorldAxis" axis_index
        true
        -- return
    )

    /*
    Returns the selected world-axis name for UI text.
    */
    function getSelectedWorldAxisText =
    (
        vertex_level_aligner.getWorldAxisText world_axis_value:(getSelectedWorldAxis())
        -- return
    )

    /*
    Converts one millimeter value into current scene system units.
    */
    function millimetersToSystem value_mm =
    (
        millimeter_scale = units.decodeValue "1mm"
        value_mm * millimeter_scale
        -- return
    )

    /*
    Returns the INI key used to persist TreeView leading-digit removal for one world axis.
    X, Y, and Z keep independent display-only trim counts.
    */
    function getAxisDisplayTrimIniKey axis_index =
    (
        case axis_index of
        (
            1: "DisplayTrimXDigits"
            2: "DisplayTrimYDigits"
            default: "DisplayTrimZDigits"
        )
        -- return
    )

    /*
    Reads one persisted display trim count and clamps it to the dropdown's 0..10 range.
    */
    function getStoredAxisDisplayTrimDigits axis_index =
    (
        key_name = getAxisDisplayTrimIniKey axis_index
        trim_digits = vertex_level_aligner_ui.getIniInteger key_name 0

        if trim_digits < 0 then trim_digits = 0
        if trim_digits > 10 then trim_digits = 10

        trim_digits
        -- return
    )

    /*
    Persists one display-only leading-digit trim count for a world axis.
    */
    function setStoredAxisDisplayTrimDigits axis_index trim_digits =
    (
        if trim_digits < 0 then trim_digits = 0
        if trim_digits > 10 then trim_digits = 10

        key_name = getAxisDisplayTrimIniKey axis_index
        vertex_level_aligner_ui.setIniValue key_name trim_digits
        -- return
    )

    /*
    Returns the active dropdown trim count.
    Selection 1 is blank/full position, selections 2..11 remove 1..10 leading integer digits.
    */
    function getCurrentDisplayTrimDigits =
    (
        trim_digits = ddl_display_trim.selection - 1
        if trim_digits < 0 then trim_digits = 0
        if trim_digits > 10 then trim_digits = 10

        trim_digits
        -- return
    )

    /*
    Loads one axis's persisted trim count into the display dropdown.
    */
    function loadAxisDisplayTrimDropdown axis_index =
    (
        trim_digits = getStoredAxisDisplayTrimDigits axis_index
        dropdown_ok = true
        is_updating_display_trim = true

        try
        (
            ddl_display_trim.selection = trim_digits + 1
        )
        catch
        (
            display_trim_exception = getCurrentException()
            dropdown_ok = false
        )

        is_updating_display_trim = false
        dropdown_ok
        -- return
    )

    /*
    Returns the physical millimeter step used by TreeView RMB rounding.
    Precision modes are display workflow presets and never change scan/group classification.
    */
    function getRoundPrecisionStepMm =
    (
        case ddl_round_precision.selection of
        (
            1: 0.001d0
            2: 1.0d0
            3: 0.1d0
            4: 0.05d0
            default: 1.0d0
        )
        -- return
    )

    /*
    Adds comma thousands separators to the leading numeric integer part of one display string.
    Decimal digits and any trailing unit text remain unchanged.
    */
    function addThousandsSeparators numeric_text =
    (
        if numeric_text == undefined or numeric_text == "" then return numeric_text

        plain_text = substituteString numeric_text "," ""
        text_length = plain_text.count
        integer_start = 1
        prefix_text = ""
        first_character = substring plain_text 1 1

        if first_character == "-" or first_character == "+" then
        (
            prefix_text = first_character
            integer_start = 2
        )

        integer_end = integer_start - 1

        while integer_end < text_length and (findString "0123456789" (substring plain_text (integer_end + 1) 1)) != undefined do
        (
            integer_end += 1
        )

        integer_count = integer_end - integer_start + 1
        if integer_count <= 3 then return plain_text

        grouped_integer = ""

        for digit_offset = 0 to (integer_count - 1) do
        (
            if digit_offset > 0 and (mod (integer_count - digit_offset) 3) == 0 then
            (
                grouped_integer += ","
            )

            grouped_integer += substring plain_text (integer_start + digit_offset) 1
        )

        suffix_start = integer_end + 1
        suffix_text = if suffix_start <= text_length then substring plain_text suffix_start (text_length - suffix_start + 1) else ""

        prefix_text + grouped_integer + suffix_text
        -- return
    )

    /*
    Removes only the requested count of leading integer digits from display text.
    The sign, decimal portion, and at least one integer digit are preserved; geometry data is untouched.
    */
    function trimLeadingIntegerDigits numeric_text trim_digits =
    (
        if numeric_text == undefined or numeric_text == "" then return numeric_text
        if trim_digits <= 0 then return addThousandsSeparators numeric_text

        plain_text = substituteString numeric_text "," ""
        text_length = plain_text.count
        integer_start = 1
        prefix_text = ""
        first_character = substring plain_text 1 1

        if first_character == "-" or first_character == "+" then
        (
            prefix_text = first_character
            integer_start = 2
        )

        integer_end = integer_start - 1

        while integer_end < text_length and (findString "0123456789" (substring plain_text (integer_end + 1) 1)) != undefined do
        (
            integer_end += 1
        )

        integer_count = integer_end - integer_start + 1
        if integer_count <= 1 then return addThousandsSeparators plain_text

        remove_count = trim_digits
        maximum_remove_count = integer_count - 1
        if remove_count > maximum_remove_count then remove_count = maximum_remove_count

        remaining_integer_start = integer_start + remove_count
        remaining_integer_count = integer_count - remove_count
        remaining_integer = substring plain_text remaining_integer_start remaining_integer_count
        suffix_start = integer_end + 1
        suffix_text = if suffix_start <= text_length then substring plain_text suffix_start (text_length - suffix_start + 1) else ""

        addThousandsSeparators (prefix_text + remaining_integer + suffix_text)
        -- return
    )

    /*
    Formats one scene-space value for TreeView/RMB display, removes meter letters, and groups thousands with commas.
    Other TreeView label text remains unchanged.
    */
    function formatWorldItemValue value =
    (
        formatted_value = undefined

        try
        (
            formatted_value = units.formatValue value
        )
        catch
        (
            format_item_exception = getCurrentException()
            formatted_value = value as string
        )

        formatted_value = substituteString formatted_value "cm" ""
        formatted_value = substituteString formatted_value "CM" ""
        formatted_value = substituteString formatted_value "m" ""
        formatted_value = substituteString formatted_value "M" ""
        addThousandsSeparators formatted_value
        -- return
    )

    /*
    Formats a real selected-axis world position and removes the configured leading display digits.
    The full real coordinate remains in backend scan/group/alignment data; only TreeView/RMB text is shortened.
    */
    function formatWorldPositionValue value =
    (
        formatted_value = undefined

        try
        (
            formatted_value = units.formatValue value
        )
        catch
        (
            format_position_exception = getCurrentException()
            formatted_value = value as string
        )

        formatted_value = substituteString formatted_value "cm" ""
        formatted_value = substituteString formatted_value "CM" ""
        formatted_value = substituteString formatted_value "m" ""
        formatted_value = substituteString formatted_value "M" ""
        trimLeadingIntegerDigits formatted_value (getCurrentDisplayTrimDigits())
        -- return
    )

    /*
    Converts a millimeter UI value into current scene system units.
    The backend continues storing physical scene-space threshold values.
    */
    function thresholdMmToSystem threshold_mm =
    (
        millimetersToSystem threshold_mm
        -- return
    )

    /*
    Converts one stored scene-system threshold into millimeters for the UI spinner.
    Existing INI threshold values remain compatible across this UI change.
    */
    function thresholdSystemToMm threshold_system =
    (
        millimeter_scale = units.decodeValue "1mm"
        if millimeter_scale <= 0.0 then throw "Invalid millimeter system-unit scale."

        threshold_system / millimeter_scale
        -- return
    )

    /*
    Returns the selected display-unit scale in current scene system units.
    This affects only the local bounding-box readout.
    */
    function getBoundingBoxUnitScale =
    (
        case ddl_bbox_unit.selection of
        (
            1: units.decodeValue "1mm"
            2: units.decodeValue "1cm"
            3: units.decodeValue "1m"
            default: units.decodeValue "1mm"
        )
        -- return
    )

    /*
    Formats one local bounding-box size in the selected display unit.
    Values stay in scene system units internally.
    */
    function formatBoundingBoxValue value =
    (
        unit_scale = getBoundingBoxUnitScale()
        if unit_scale <= 0.0 then return (value as string)

        display_value = value / unit_scale
        format_string = case ddl_bbox_unit.selection of
        (
            1: "0.1f"
            2: "0.1f"
            3: "0.2f"
            default: "0.1f"
        )

        addThousandsSeparators (formattedPrint display_value format:format_string)
        -- return
    )

    /*
    Refreshes the bottom readout with the scanned node's local bounding-box size.
    The node-local bounds and selected display unit never affect scan, grouping, selection, or geometry.
    */
    function updateLocalBoundingBoxLabel =
    (
        node_value = vertex_level_aligner.scan_node

        if node_value == undefined or not(isValidNode node_value) then
        (
            lbl_definition.text = "BBox: —"
            return false
        )

        bbox_values = undefined
        bbox_ok = true

        try
        (
            bbox_values = nodeLocalBoundingBox node_value
        )
        catch
        (
            local_bbox_exception = getCurrentException()
            bbox_ok = false
        )

        if not(bbox_ok) or bbox_values == undefined or bbox_values.count < 2 then
        (
            lbl_definition.text = "BBox: —"
            return false
        )

        size_x = abs (bbox_values[2].x - bbox_values[1].x)
        size_y = abs (bbox_values[2].y - bbox_values[1].y)
        size_z = abs (bbox_values[2].z - bbox_values[1].z)

        lbl_definition.text = "BBox: X " + formatBoundingBoxValue size_x + " | Y " + formatBoundingBoxValue size_y + " | Z " + formatBoundingBoxValue size_z
        true
        -- return
    )

    /*
    Returns one restrained TreeView text color for the supplied stored group index.
    Children reuse the parent color so threshold membership remains visually obvious.
    */
    function getGroupColor group_index =
    (
        color_class = dotNetClass "System.Drawing.Color"
        palette_index = (mod (group_index - 1) 8) + 1

        case palette_index of
        (
            1: color_class.FromArgb 155 195 220
            2: color_class.FromArgb 190 170 220
            3: color_class.FromArgb 150 205 175
            4: color_class.FromArgb 220 185 145
            5: color_class.FromArgb 205 155 165
            6: color_class.FromArgb 145 200 205
            7: color_class.FromArgb 205 200 145
            default: color_class.FromArgb 180 180 205
        )
        -- return
    )

    /*
    Returns the selected-axis position for one stored vertex set.
    When that exact vertex set is currently selected, 3ds Max's native Selection Center is used so the value matches Transform Type-In.
    Otherwise the live vertex average remains the non-destructive fallback, with the stored scan value used only if live geometry cannot be read.
    */
    function getLiveDisplayAxisValue vertex_bits fallback_axis_value =
    (
        selection_center_axis_value = vertex_level_aligner.getCurrentVertexSelectionCenterAxisValue vertex_bits
        if selection_center_axis_value != undefined then return selection_center_axis_value

        live_axis_value = vertex_level_aligner.getLiveVertexBitsAxisValue vertex_bits
        if live_axis_value == undefined then fallback_axis_value else live_axis_value
        -- return
    )

    /*
    Builds the parent label for one threshold group.
    */
    function getGroupText group_index group_data center_axis_override:undefined =
    (
        center_axis = if center_axis_override == undefined then getLiveDisplayAxisValue group_data[4] group_data[1] else center_axis_override
        min_axis = group_data[2]
        max_axis = group_data[3]
        vertex_count = group_data[4].numberSet
        exact_levels = group_data[5]
        exact_level_count = if isKindOf exact_levels Array then exact_levels.count else 0
        is_broken = group_data[6]

        if is_broken then
        (
            "❌| ›‹ " + formatWorldPositionValue center_axis + " | ‹› " + formatWorldItemValue (max_axis - min_axis) + " | " + (vertex_count as string) + " verts"
        )
        else
        (
            if vertex_level_aligner.threshold_value == 0.0 then
            (
                "Level " + (group_index as string) + " | " + formatWorldPositionValue center_axis + " | " + (vertex_count as string) + " verts"
            )
            else
            (
                "✔| ›‹ " + formatWorldPositionValue center_axis + " | " + (vertex_count as string) + " verts"
            )
        )
        -- return
    )

    /*
    Parses one TreeView node tag into #(#group, groupIndex) or #(#level, groupIndex, levelIndex).
    */
    function getTargetFromTag tag_text =
    (
        if tag_text == undefined or tag_text == "" then return undefined

        tag_parts = filterString tag_text "|"

        if tag_parts.count == 2 and tag_parts[1] == "G" then
        (
            group_index = 0

            try
            (
                group_index = tag_parts[2] as integer
            )
            catch
            (
                group_tag_exception = getCurrentException()
                group_index = 0
            )

            if group_index > 0 then return #(#group, group_index)
        )
        else if tag_parts.count == 3 and tag_parts[1] == "L" then
        (
            group_index = 0
            level_index = 0

            try
            (
                group_index = tag_parts[2] as integer
                level_index = tag_parts[3] as integer
            )
            catch
            (
                level_tag_exception = getCurrentException()
                group_index = 0
                level_index = 0
            )

            if group_index > 0 and level_index > 0 then
            (
                return #(#level, group_index, level_index)
            )
        )

        undefined
        -- return
    )

    /*
    Returns one TreeView node tag as text.
    Failed .NET tag reads return an empty string and never create a selection target.
    */
    function getTreeNodeTag node_value =
    (
        if node_value == undefined then return ""

        tag_text = ""

        try
        (
            tag_text = node_value.Tag as string
        )
        catch
        (
            node_tag_exception = getCurrentException()
            tag_text = ""
        )

        tag_text
        -- return
    )

    /*
    Returns all custom TreeView selections as backend target arrays.
    Invalid or stale tags are ignored.
    */
    function getSelectedTreeTargets =
    (
        selected_targets = #()

        for tag_text in selected_tree_tags do
        (
            target_data = getTargetFromTag tag_text
            if target_data != undefined then append selected_targets target_data
        )

        selected_targets
        -- return
    )

    /*
    Formats one scene-space diagnostic value using the current 3ds Max Display Units.
    Diagnostic formatting never changes the underlying scene/system-unit value.
    */
    function formatDebugDisplayValue value =
    (
        formatted_value = undefined

        try
        (
            formatted_value = units.formatValue value
        )
        catch
        (
            debug_format_exception = getCurrentException()
            formatted_value = value as string
        )

        formatted_value
        -- return
    )

    /*
    Prints stored/display position against live world positions for every selected TreeView item.
    Numeric diagnostics use the current 3ds Max Display Units.
    This diagnostic is read-only and never changes TreeView, geometry, modifier-stack, or sub-object state.
    */
    function debugSelectedTreePositions target_node:undefined =
    (
        if not(cb_debug.checked) then return true

        format "\n============================================================\n"
        format "VERTEX LEVEL ALIGNER POSITION DEBUG\n"
        format "============================================================\n"

        debug_tags = #()

        if target_node == undefined then
        (
            debug_tags = selected_tree_tags
        )
        else
        (
            target_tag = getTreeNodeTag target_node
            if target_tag != "" then append debug_tags target_tag
        )

        if debug_tags.count == 0 then
        (
            format "No TreeView items selected.\n"
            return false
        )

        if not(vertex_level_aligner.isStoredContextCurrent()) then
        (
            format "Stored scan is stale. Scan the object again.\n"
            return false
        )

        debug_axis = getSelectedWorldAxis()
        debug_axis_text = getSelectedWorldAxisText()
        context_data = vertex_level_aligner.resolveContext vertex_level_aligner.scan_node modifier_value:vertex_level_aligner.scan_modifier

        format "ACTIVE AXIS: % | DEBUG ITEMS: % | VALUES: DISPLAY UNITS\n" debug_axis_text debug_tags.count

        for tag_text in debug_tags do
        (
            target_data = getTargetFromTag tag_text

            if target_data == undefined then
            (
                format "\nITEM % | INVALID TAG\n" tag_text
            )
            else
            (
                item_kind_text = ""
                item_axis_value = undefined
                item_vertex_bits = undefined

                if target_data[1] == #group then
                (
                    group_data = vertex_level_aligner.getGroupData target_data[2] context_validated:true

                    if group_data != undefined then
                    (
                        item_kind_text = "GROUP " + (target_data[2] as string)
                        item_axis_value = group_data[1]
                        item_vertex_bits = group_data[4]
                    )
                )
                else if target_data[1] == #level then
                (
                    level_data = vertex_level_aligner.getLevelData target_data[2] target_data[3] context_validated:true

                    if level_data != undefined then
                    (
                        item_kind_text = "GROUP " + (target_data[2] as string) + " / LEVEL " + (target_data[3] as string)
                        item_axis_value = level_data[1]
                        item_vertex_bits = level_data[2]
                    )
                )

                if item_axis_value == undefined or item_vertex_bits == undefined then
                (
                    format "\nITEM % | COULD NOT RESOLVE DATA\n" tag_text
                )
                else
                (
                    display_axis_value = getLiveDisplayAxisValue item_vertex_bits item_axis_value
                    display_position_text = formatWorldPositionValue display_axis_value
                    live_axis_reference = undefined
                    live_axis_delta_total = 0.0
                    live_axis_count = 0
                    live_axis_min = undefined
                    live_axis_max = undefined

                    format "\n------------------------------------------------------------\n"
                    format "ITEM: % | TAG: % | SELECTED: %\n" item_kind_text tag_text ((findItem selected_tree_tags tag_text) > 0)
                    format "ITEM STORED %: %\n" debug_axis_text (formatDebugDisplayValue item_axis_value)
                    format "ITEM DISPLAY %: %\n" debug_axis_text (formatDebugDisplayValue display_axis_value)
                    format "ITEM TREE TEXT: %\n" display_position_text
                    selection_center_axis_value = vertex_level_aligner.getCurrentVertexSelectionCenterAxisValue item_vertex_bits
                    if selection_center_axis_value != undefined then
                    (
                        format "ITEM SELECTION CENTER %: %\n" debug_axis_text (formatDebugDisplayValue selection_center_axis_value)
                    )
                    format "VERTEX COUNT: %\n" item_vertex_bits.numberSet

                    for vertex_id in item_vertex_bits do
                    (
                        world_position = vertex_level_aligner.getWorldVertexPosition context_data vertex_id topology_validated:true

                        if world_position == undefined then
                        (
                            format "  V% | WORLD READ FAILED\n" vertex_id
                        )
                        else
                        (
                            live_axis_value = vertex_level_aligner.getWorldAxisValue world_position world_axis_value:debug_axis
                            stored_axis_delta = live_axis_value - item_axis_value
                            display_axis_delta = live_axis_value - display_axis_value

                            if live_axis_reference == undefined then
                            (
                                live_axis_reference = live_axis_value
                            )
                            else
                            (
                                live_axis_delta_total += live_axis_value - live_axis_reference
                            )

                            live_axis_count += 1

                            if live_axis_min == undefined or live_axis_value < live_axis_min then live_axis_min = live_axis_value
                            if live_axis_max == undefined or live_axis_value > live_axis_max then live_axis_max = live_axis_value

                            format "  V% | WORLD [%, %, %] | %=% | DELTA_TO_STORED=% | DELTA_TO_DISPLAY=%\n" vertex_id (formatDebugDisplayValue world_position.x) (formatDebugDisplayValue world_position.y) (formatDebugDisplayValue world_position.z) debug_axis_text (formatDebugDisplayValue live_axis_value) (formatDebugDisplayValue stored_axis_delta) (formatDebugDisplayValue display_axis_delta)
                        )
                    )

                    if live_axis_count > 0 and live_axis_reference != undefined then
                    (
                        live_axis_average = live_axis_reference + (live_axis_delta_total / live_axis_count)
                        format "LIVE % MIN: %\n" debug_axis_text (formatDebugDisplayValue live_axis_min)
                        format "LIVE % MAX: %\n" debug_axis_text (formatDebugDisplayValue live_axis_max)
                        format "LIVE % AVERAGE: %\n" debug_axis_text (formatDebugDisplayValue live_axis_average)
                        format "AVERAGE - ITEM STORED DELTA: %\n" (formatDebugDisplayValue (live_axis_average - item_axis_value))
                        format "AVERAGE - ITEM DISPLAY DELTA: %\n" (formatDebugDisplayValue (live_axis_average - display_axis_value))
                    )
                )
            )
        )

        format "============================================================\n"
        true
        -- return
    )

    /*
    Returns unique parent-group indexes represented by the current TreeView selection.
    Child-level selections contribute their parent group.
    */
    function getSelectedTreeGroupIndexes =
    (
        group_indices = #()
        selected_targets = getSelectedTreeTargets()

        for target_data in selected_targets do
        (
            group_index = target_data[2]
            if (findItem group_indices group_index) == 0 then append group_indices group_index
        )

        group_indices
        -- return
    )

    /*
    Applies or clears the custom multi-selection background for one TreeView node.
    The node's existing group/level foreground color is preserved.
    */
    function setTreeNodeMultiSelectedVisual node_value selected_state =
    (
        if node_value == undefined then return false

        color_class = dotNetClass "System.Drawing.Color"

        if selected_state then
        (
            node_value.BackColor = color_class.FromArgb 72 88 108
        )
        else
        (
            node_value.BackColor = tv_levels.BackColor
        )

        true
        -- return
    )

    /*
    Refreshes custom selection backgrounds for all visible TreeView items.
    Only tags stored in selected_tree_tags are shown as selected.
    */
    function refreshTreeMultiSelectionVisuals =
    (
        root_count = tv_levels.Nodes.Count

        for root_index = 0 to (root_count - 1) do
        (
            root_node = tv_levels.Nodes.Item[root_index]
            root_tag = getTreeNodeTag root_node
            setTreeNodeMultiSelectedVisual root_node ((findItem selected_tree_tags root_tag) > 0)

            child_count = root_node.Nodes.Count

            for child_index = 0 to (child_count - 1) do
            (
                child_node = root_node.Nodes.Item[child_index]
                child_tag = getTreeNodeTag child_node
                setTreeNodeMultiSelectedVisual child_node ((findItem selected_tree_tags child_tag) > 0)
            )
        )

        true
        -- return
    )

    /*
    Clears the visible EPoly component selection without changing the stored scan.
    Edge mode stays Edge; every other supported state uses Vertex mode like selectTargets().
    */
    function clearTreeSelectionGeometry =
    (
        current_subobject_level = vertex_level_aligner.getCurrentSubObjectLevelSafe()
        if current_subobject_level == undefined then return false

        if current_subobject_level == 2 then
        (
            vertex_level_aligner.selectEdgeBitsFast #{}
        )
        else
        (
            vertex_level_aligner.selectVertexBitsFast #{}
        )
        -- return
    )

    /*
    Writes the union of the custom TreeView selection to the viewport.
    An empty custom selection clears the current Vertex/Edge selection.
    */
    function applyTreeMultiSelectionToGeometry =
    (
        selected_targets = getSelectedTreeTargets()
        selection_ok = false

        if selected_targets.count == 0 then
        (
            selection_ok = clearTreeSelectionGeometry()
        )
        else
        (
            selection_ok = vertex_level_aligner.selectTargetsFast selected_targets
        )

        lbl_status.text = vertex_level_aligner.last_message
        selection_ok
        -- return
    )

    /*
    Returns true only while CTRL is held for TreeView multi-selection.
    Plain LMB keeps the native single-selection path.
    */
    function isTreeControlModifierDown =
    (
        forms_control_class = dotNetClass "System.Windows.Forms.Control"
        modifier_text = forms_control_class.ModifierKeys.ToString()

        (findString modifier_text "Control") != undefined
        -- return
    )

    /*
    Selects the vertices represented by one TreeView node.
    */
    function selectTreeNode node_value =
    (
        if node_value == undefined then return false

        tag_text = ""
        try
        (
            tag_text = node_value.Tag as string
        )
        catch
        (
            node_tag_exception = getCurrentException()
            tag_text = ""
        )
        target_data = getTargetFromTag tag_text
        if target_data == undefined then return false

        selection_ok = false

        if target_data[1] == #group then
        (
            selection_ok = vertex_level_aligner.selectGroup target_data[2]
        )
        else if target_data[1] == #level then
        (
            selection_ok = vertex_level_aligner.selectLevel target_data[2] target_data[3]
        )

        lbl_status.text = vertex_level_aligner.last_message
        selection_ok
        -- return
    )


    /*
    Returns the largest exact-level vertex count inside one group.
    If multiple levels tie for the largest count, all tied levels are highlighted.
    */
    function getLargestLevelVertexCount exact_levels =
    (
        largest_count = 0

        if exact_levels == undefined then return largest_count

        for level_data in exact_levels do
        (
            if level_data != undefined and level_data.count >= 2 and level_data[2] != undefined then
            (
                level_count = level_data[2].numberSet
                if level_count > largest_count then largest_count = level_count
            )
        )

        largest_count
        -- return
    )

    /*
    Builds one exact-level child label, optionally using a native Selection Center axis value already read for the active selection.
    */
    function getLevelText level_data is_largest_level axis_value_override:undefined =
    (
        if level_data == undefined or level_data.count < 2 or level_data[2] == undefined then return ""

        level_vertex_count = level_data[2].numberSet
        level_display_axis = if axis_value_override == undefined then getLiveDisplayAxisValue level_data[2] level_data[1] else axis_value_override
        level_text = formatWorldPositionValue level_display_axis + " | " + (level_vertex_count as string) + " verts"

        if is_largest_level then
        (
            level_text += "  [MOST]"
        )

        level_text
        -- return
    )

    /*
    Refreshes one selected TreeView row from 3ds Max's native vertex Selection Center.
    The function never changes the component selection; it updates text only when the supplied row already matches the active Vertex selection.
    */
    function refreshTreeNodeSelectionCenterValue node_value =
    (
        if node_value == undefined then return false

        tag_text = getTreeNodeTag node_value
        target_data = getTargetFromTag tag_text
        if target_data == undefined then return false

        if target_data[1] == #group then
        (
            group_data = vertex_level_aligner.getGroupData target_data[2]
            if group_data == undefined then return false

            selection_center_axis_value = vertex_level_aligner.getCurrentVertexSelectionCenterAxisValue group_data[4]
            if selection_center_axis_value == undefined then return false

            indicator_text = if node_value.IsExpanded then "- " else "+ "
            node_value.Text = indicator_text + getGroupText target_data[2] group_data center_axis_override:selection_center_axis_value
            return true
        )

        if target_data[1] == #level then
        (
            group_data = vertex_level_aligner.getGroupData target_data[2]
            level_data = vertex_level_aligner.getLevelData target_data[2] target_data[3]
            if group_data == undefined or level_data == undefined then return false

            selection_center_axis_value = vertex_level_aligner.getCurrentVertexSelectionCenterAxisValue level_data[2]
            if selection_center_axis_value == undefined then return false

            largest_level_vertex_count = getLargestLevelVertexCount group_data[5]
            is_largest_level = level_data[2].numberSet == largest_level_vertex_count
            node_value.Text = getLevelText level_data is_largest_level axis_value_override:selection_center_axis_value
            return true
        )

        false
        -- return
    )

    /*
    Replaces the custom selection with one TreeView item and uses the stable single-item selector.
    This remains the plain-LMB path.
    */
    function selectTreeNodeExclusive node_value =
    (
        tag_text = getTreeNodeTag node_value
        if tag_text == "" then return false

        selected_tree_tags = #(tag_text)
        refreshTreeMultiSelectionVisuals()
        selection_ok = selectTreeNode node_value
        debugSelectedTreePositions target_node:node_value
        selection_ok
        -- return
    )

    /*
    Toggles one TreeView item in the custom selection.
    This is called only from CTRL+LMB and writes the resulting union to the viewport.
    */
    function toggleTreeNodeSelection node_value =
    (
        tag_text = getTreeNodeTag node_value
        if tag_text == "" then return false

        selected_index = findItem selected_tree_tags tag_text

        if selected_index > 0 then
        (
            deleteItem selected_tree_tags selected_index
        )
        else
        (
            append selected_tree_tags tag_text
        )

        refreshTreeMultiSelectionVisuals()
        selection_ok = applyTreeMultiSelectionToGeometry()
        debugSelectedTreePositions target_node:node_value
        selection_ok
        -- return
    )

    /*
    Refreshes one parent group label with an explicit expansion indicator.
    "-" means the group is open; "+" means it is collapsed.
    */
    function updateGroupExpansionIndicator node_value expanded_state =
    (
        if node_value == undefined then return false

        tag_text = ""
        try
        (
            tag_text = node_value.Tag as string
        )
        catch
        (
            node_tag_exception = getCurrentException()
            tag_text = ""
        )
        target_data = getTargetFromTag tag_text
        if target_data == undefined or target_data[1] != #group then return false

        current_text = node_value.Text as string
        indicator_text = if expanded_state then "- " else "+ "

        if current_text.count >= 2 and ((substring current_text 1 2) == "- " or (substring current_text 1 2) == "+ ") then
        (
            node_value.Text = indicator_text + substring current_text 3 (current_text.count - 2)
        )
        else
        (
            node_value.Text = indicator_text + current_text
        )

        true
        -- return
    )

    /*
    Rebuilds the TreeView from the stored scan without rescanning geometry.
    */
    function rebuildTree =
    (
        vertex_level_aligner_ui.is_rebuilding_tree = true
        selected_tree_tags = #()
        is_ctrl_tree_selection = false
        is_context_tree_selection = false
        tree_update_started = false
        rebuild_ok = true

        try
        (
            tv_levels.BeginUpdate()
            tree_update_started = true
            tv_levels.Nodes.Clear()

            show_broken_only = (rb_view_mode.state == 2) and (vertex_level_aligner.threshold_value > 0.0)
            level_vertex_condition = ddl_level_vertex_condition.selection
            level_vertex_filter_value = getSelectedLevelVertexCountFilterValue()
            group_count = vertex_level_aligner.getGroupCount()

            level_font_style_class = dotNetClass "System.Drawing.FontStyle"
            level_font_size = tv_levels.Font.Size - 1.5
            if level_font_size < 1.0 then level_font_size = 1.0
            level_regular_font = dotNetObject "System.Drawing.Font" tv_levels.Font.FontFamily level_font_size tv_levels.Font.Style
            level_bold_font = dotNetObject "System.Drawing.Font" tv_levels.Font.FontFamily level_font_size level_font_style_class.Bold

            if group_count > 0 then
            (
                for group_offset = 1 to group_count do
                (
                    group_index = group_count - group_offset + 1
                    group_data = vertex_level_aligner.getGroupData group_index context_validated:true

                    if group_data != undefined then
                    (
                        exact_levels = group_data[5]

                        if isKindOf exact_levels Array then
                        (
                            largest_level_vertex_count = if group_data[6] then getLargestLevelVertexCount exact_levels else 0
                            group_matches_vertex_filter = groupHasMatchingLevelVertexCount exact_levels level_vertex_condition level_vertex_filter_value

                            if (not(show_broken_only) or group_data[6]) and group_matches_vertex_filter then
                            (
                                group_color = getGroupColor group_index
                                group_node = dotNetObject "System.Windows.Forms.TreeNode" ("- " + getGroupText group_index group_data center_axis_override:group_data[1])
                                group_node.ForeColor = group_color
                                group_node.Tag = "G|" + (group_index as string)

                                if group_data[6] then
                                (
                                    for level_offset = 1 to exact_levels.count do
                                    (
                                        level_index = exact_levels.count - level_offset + 1
                                        level_data = exact_levels[level_index]
                                        level_vertex_count = level_data[2].numberSet

                                        if levelVertexCountMatchesFilter level_vertex_count level_vertex_condition level_vertex_filter_value then
                                        (
                                            is_largest_level = level_vertex_count == largest_level_vertex_count
                                            level_text = getLevelText level_data is_largest_level axis_value_override:level_data[1]

                                            level_node = dotNetObject "System.Windows.Forms.TreeNode" level_text
                                            level_node.ForeColor = group_color
                                            level_node.Tag = "L|" + (group_index as string) + "|" + (level_index as string)

                                            level_node.NodeFont = if is_largest_level then level_bold_font else level_regular_font

                                            group_node.Nodes.Add level_node
                                        )
                                    )
                                )

                                tv_levels.Nodes.Add group_node
                                group_node.Expand()
                            )
                        )
                    )
                )
            )

            tv_levels.EndUpdate()
            tree_update_started = false
        )
        catch
        (
            rebuild_exception = getCurrentException()
            rebuild_ok = false

            if tree_update_started then
            (
                try
                (
                    tv_levels.EndUpdate()
                )
                catch
                (
                    tree_cleanup_exception = getCurrentException()
                )
            )
        )

        vertex_level_aligner_ui.is_rebuilding_tree = false

        if not(rebuild_ok) then
        (
            lbl_status.text = "Could not rebuild the level tree."
            updateLocalBoundingBoxLabel()
            return false
        )

        lbl_status.text = vertex_level_aligner.last_message
        updateLocalBoundingBoxLabel()
        true
        -- return
    )

    /*
    Applies persisted threshold and view mode values when the rollout opens.
    */
    function loadUiState =
    (
        saved_threshold = vertex_level_aligner_ui.getIniFloat "Threshold" vertex_level_aligner_default_threshold
        saved_mode = vertex_level_aligner_ui.getIniInteger "ViewMode" 1
        saved_world_axis = vertex_level_aligner_ui.getIniInteger "WorldAxis" 3
        saved_round_precision = vertex_level_aligner_ui.getIniInteger "RoundPrecision" 2
        saved_bbox_unit = vertex_level_aligner_ui.getIniInteger "BBoxUnit" 1
        saved_level_vertex_condition = vertex_level_aligner_ui.getIniInteger "LevelVertexCondition" 1
        saved_level_vertex_count = vertex_level_aligner_ui.getIniInteger "LevelVertexCount" 0
        saved_face_material_id = vertex_level_aligner_ui.getIniInteger "FaceMaterialID" 1

        if saved_threshold < 0.0 then saved_threshold = vertex_level_aligner_default_threshold
        if saved_mode < 1 or saved_mode > 2 then saved_mode = 1
        if saved_world_axis < 1 or saved_world_axis > 3 then saved_world_axis = 3
        if saved_round_precision < 1 or saved_round_precision > 4 then saved_round_precision = 2
        if saved_bbox_unit < 1 or saved_bbox_unit > 3 then saved_bbox_unit = 1
        if saved_level_vertex_condition < 1 or saved_level_vertex_condition > 3 then saved_level_vertex_condition = 1
        if saved_level_vertex_count < 0 or saved_level_vertex_count > 100 then saved_level_vertex_count = 0
        if saved_face_material_id < 1 or saved_face_material_id > 100 then saved_face_material_id = 1

        ddl_level_vertex_count.items = buildLevelVertexCountFilterItems()
        ddl_face_material_id.items = buildFaceMaterialIdItems()

        if not(setWorldAxisControls saved_world_axis) then return false
        if not(loadAxisDisplayTrimDropdown saved_world_axis) then return false

        spn_threshold.value = thresholdSystemToMm saved_threshold
        rb_view_mode.state = saved_mode
        ddl_round_precision.selection = saved_round_precision
        ddl_bbox_unit.selection = saved_bbox_unit
        ddl_level_vertex_condition.selection = saved_level_vertex_condition
        ddl_level_vertex_count.selection = saved_level_vertex_count + 1
        ddl_face_material_id.selection = saved_face_material_id
        vertex_level_aligner.threshold_value = saved_threshold
        true
        -- return
    )

    /*
    Persists threshold, mode, position, and current resizable dialog dimensions.
    */
    function saveUiState dialog_pos:undefined dialog_size:undefined =
    (
        save_ok = true

        if not(vertex_level_aligner_ui.setIniValue "Threshold" (thresholdMmToSystem spn_threshold.value)) then save_ok = false
        if not(vertex_level_aligner_ui.setIniValue "ViewMode" rb_view_mode.state) then save_ok = false
        if not(vertex_level_aligner_ui.setIniValue "RoundPrecision" ddl_round_precision.selection) then save_ok = false
        if not(vertex_level_aligner_ui.setIniValue "BBoxUnit" ddl_bbox_unit.selection) then save_ok = false
        if not(vertex_level_aligner_ui.setIniValue "LevelVertexCondition" ddl_level_vertex_condition.selection) then save_ok = false
        if not(vertex_level_aligner_ui.setIniValue "LevelVertexCount" (getSelectedLevelVertexCountFilterValue())) then save_ok = false
        if not(vertex_level_aligner_ui.setIniValue "FaceMaterialID" (getSelectedFaceMaterialId())) then save_ok = false
        current_axis_index = getSelectedWorldAxisIndex()
        if not(vertex_level_aligner_ui.setIniValue "WorldAxis" current_axis_index) then save_ok = false
        if not(setStoredAxisDisplayTrimDigits current_axis_index (getCurrentDisplayTrimDigits())) then save_ok = false

        if dialog_pos != undefined then
        (
            if not(vertex_level_aligner_ui.setIniValue "PosX" dialog_pos.x) then save_ok = false
            if not(vertex_level_aligner_ui.setIniValue "PosY" dialog_pos.y) then save_ok = false
        )

        if dialog_size != undefined and dialog_size.y >= 260 then
        (
            if not(vertex_level_aligner_ui.setIniValue "Height" dialog_size.y) then save_ok = false
        )

        save_ok
        -- return
    )

    /*
    Resizes the TreeView and lower controls to the current dialog client size.
    */
    function resizeControls dialog_size =
    (
        tree_width = 304
        tree_height = dialog_size.y - 236

        if tree_height < 108 then tree_height = 108

        tv_levels.width = tree_width
        tv_levels.height = tree_height
        lbl_status.width = tree_width
        lbl_definition.pos = [8, dialog_size.y - 58]
        lbl_definition.width = 248
        ddl_bbox_unit.pos = [264, dialog_size.y - 61]
        btn_restart.pos = [8, dialog_size.y - 32]
        btn_restart.width = 224
        cb_debug.pos = [240, dialog_size.y - 29]
        true
        -- return
    )

    /*
    Collapses every visible TreeView group without changing stored scan data.
    Each root node is collapsed explicitly so the visible +/- indicator stays synchronized.
    */
    function collapseAllLevels =
    (
        root_count = tv_levels.Nodes.Count

        for root_index = 0 to (root_count - 1) do
        (
            root_node = tv_levels.Nodes.Item[root_index]
            root_node.Collapse()
            updateGroupExpansionIndicator root_node false
        )

        true
        -- return
    )

    /*
    Expands every visible TreeView group without changing stored scan data.
    Each root node is expanded explicitly so the visible +/- indicator stays synchronized.
    */
    function expandAllLevels =
    (
        root_count = tv_levels.Nodes.Count

        for root_index = 0 to (root_count - 1) do
        (
            root_node = tv_levels.Nodes.Item[root_index]
            root_node.Expand()
            updateGroupExpansionIndicator root_node true
        )

        true
        -- return
    )

    /*
    Expands every selected parent group, or all visible groups when nothing is selected.
    Child-level selections contribute their parent groups.
    */
    function expandSelectedOrAllLevels =
    (
        group_indices = getSelectedTreeGroupIndexes()

        if group_indices.count == 0 then return expandAllLevels()

        root_count = tv_levels.Nodes.Count

        for root_index = 0 to (root_count - 1) do
        (
            root_node = tv_levels.Nodes.Item[root_index]
            target_data = getTargetFromTag (getTreeNodeTag root_node)

            if target_data != undefined and target_data[1] == #group and (findItem group_indices target_data[2]) > 0 then
            (
                root_node.Expand()
                updateGroupExpansionIndicator root_node true
            )
        )

        true
        -- return
    )

    /*
    Collapses every selected parent group, or all visible groups when nothing is selected.
    Child-level selections contribute their parent groups.
    */
    function collapseSelectedOrAllLevels =
    (
        group_indices = getSelectedTreeGroupIndexes()

        if group_indices.count == 0 then return collapseAllLevels()

        root_count = tv_levels.Nodes.Count

        for root_index = 0 to (root_count - 1) do
        (
            root_node = tv_levels.Nodes.Item[root_index]
            target_data = getTargetFromTag (getTreeNodeTag root_node)

            if target_data != undefined and target_data[1] == #group and (findItem group_indices target_data[2]) > 0 then
            (
                root_node.Collapse()
                updateGroupExpansionIndicator root_node false
            )
        )

        true
        -- return
    )

    /*
    Returns the live selected-axis world position represented by the current right-click TreeView item.
    The item vertex IDs are already known from the working selection path; their real mesh positions supply the alignment target.
    */
    function getContextTargetAxisValue =
    (
        target_data = getTargetFromTag context_target_tag
        if target_data == undefined then return undefined

        group_index = target_data[2]
        target_bits = undefined

        if target_data[1] == #group then
        (
            group_data = vertex_level_aligner.getGroupData group_index
            if group_data != undefined then target_bits = group_data[4]
        )
        else if target_data[1] == #level then
        (
            level_data = vertex_level_aligner.getLevelData group_index target_data[3]
            if level_data != undefined then target_bits = level_data[2]
        )

        if target_bits == undefined then return undefined

        selection_center_axis_value = vertex_level_aligner.getCurrentVertexSelectionCenterAxisValue target_bits
        if selection_center_axis_value != undefined then return selection_center_axis_value

        vertex_level_aligner.getLiveVertexBitsAxisValue target_bits
        -- return
    )

    /*
    Updates the first RMB action to show the clicked target's displayed selected-axis value.
    The displayed value honors the active axis display trim; alignment still uses the full real world coordinate.
    */
    function updateAlignToMenuText =
    (
        target_axis_value = getContextTargetAxisValue()

        if target_axis_value == undefined then
        (
            vertex_level_aligner_context_menu.mi_align_here.text = "Align " + (getSelectedWorldAxisText()) + " to position"
            return false
        )

        vertex_level_aligner_context_menu.mi_align_here.text = "Align " + (getSelectedWorldAxisText()) + " to " + formatWorldPositionValue target_axis_value
        true
        -- return
    )

    /*
    Returns the live selected-axis reference used by rounding.
    The RMB label and the geometry operation therefore derive their target from the same current vertex position.
    */
    function getContextRoundSourceAxisValue =
    (
        getContextTargetAxisValue()
        -- return
    )

    /*
    Formats one rounded RMB destination directly in physical millimeters.
    This avoids feeding a large-coordinate Double target back through units.formatValue, which can reintroduce Float display noise.
    The decimal count follows the active precision preset and the existing Remove trim is applied afterward.
    */
    function formatRoundMenuPositionValue target_axis_value =
    (
        if target_axis_value == undefined then return ""

        millimeter_scale_double = (units.decodeValue "1mm") as Double
        if millimeter_scale_double <= 0.0d0 then return formatWorldPositionValue target_axis_value

        target_millimeters_double = (target_axis_value as Double) / millimeter_scale_double
        format_string = case ddl_round_precision.selection of
        (
            1: "0.3f"
            2: "0.1f"
            3: "0.1f"
            4: "0.2f"
            default: "0.1f"
        )

        formatted_value = formattedPrint target_millimeters_double format:format_string
        trimLeadingIntegerDigits formatted_value (getCurrentDisplayTrimDigits())
        -- return
    )

    /*
    Updates the two RMB rounding actions with the actual destination values for the active precision preset.
    Menu text is display-only; the same physical step is passed separately to the backend operation.
    */
    function updateRoundMenuText =
    (
        source_axis_value = getContextRoundSourceAxisValue()
        round_step_mm = getRoundPrecisionStepMm()

        if source_axis_value == undefined then
        (
            vertex_level_aligner_context_menu.mi_round_up.text = "Round to next"
            vertex_level_aligner_context_menu.mi_round_down.text = "Round to previous"
            return false
        )

        round_up_value = vertex_level_aligner.roundAxisValueToStepMillimeters source_axis_value #up round_step_mm
        round_down_value = vertex_level_aligner.roundAxisValueToStepMillimeters source_axis_value #down round_step_mm

        if round_up_value == undefined or round_down_value == undefined then return false

        vertex_level_aligner_context_menu.mi_round_up.text = "Round " + formatRoundMenuPositionValue round_up_value
        vertex_level_aligner_context_menu.mi_round_down.text = "Round " + formatRoundMenuPositionValue round_down_value
        true
        -- return
    )

    /*
    Reads the current item's live vertex position, applies that selected-axis value to every vertex in its parent group, then rescans.
    Selection remains unchanged; TreeView display text is never used as geometry data.
    */
    function alignContextHere =
    (
        target_data = getTargetFromTag context_target_tag
        if target_data == undefined then return false

        group_index = target_data[2]
        target_axis_value = getContextTargetAxisValue()
        if target_axis_value == undefined then return false

        align_ok = false

        undo "Vertex Level Align to Axis" on
        (
            align_ok = vertex_level_aligner.flattenGroupToAxisValue group_index target_axis_value alignment_mode:#here
        )

        tree_ok = rebuildTree()
        if tree_ok then lbl_status.text = vertex_level_aligner.last_message
        align_ok and tree_ok
        -- return
    )

    /*
    Dumps the selected RMB TreeView item and the exact rounded destination used by the active precision preset.
    Output is diagnostic-only and remains silent unless DEBUG is enabled.
    */
    function dumpContextRoundTarget round_direction round_step_mm =
    (
        if not(cb_debug.checked) then return true

        source_axis_value = getContextRoundSourceAxisValue()
        if source_axis_value == undefined then return false

        rounded_axis_value = vertex_level_aligner.roundAxisValueToStepMillimeters source_axis_value round_direction round_step_mm
        if rounded_axis_value == undefined then return false

        precision_text = case ddl_round_precision.selection of
        (
            1: "EXACT"
            2: "BUILDING"
            3: "MODEL"
            4: "PRINT"
            default: "BUILDING"
        )

        item_text = context_target_tag
        selected_node = tv_levels.SelectedNode
        if selected_node != undefined then item_text = selected_node.Text

        millimeter_scale = units.decodeValue "1mm"
        if millimeter_scale <= 0.0 then return false

        source_mm = source_axis_value / millimeter_scale
        rounded_mm = rounded_axis_value / millimeter_scale
        source_text = formattedPrint source_mm format:"0.12g"
        rounded_text = formattedPrint rounded_mm format:"0.12g"
        step_text = formattedPrint round_step_mm format:"0.8g"
        direction_text = if round_direction == #up then "UP" else "DOWN"

        format "\nROUND DEBUG | ITEM: % | TAG: %\n" item_text context_target_tag
        format "MODE: % | STEP: % mm | DIRECTION: %\n" precision_text step_text direction_text
        format "SOURCE: % mm | ROUNDED: % mm\n" source_text rounded_text
        true
        -- return
    )

    /*
    Rounds only the vertices represented by the current RMB TreeView item on the active precision grid.
    Group rows move their group rigidly; child rows move only that exact level.
    */
    function roundContextTarget round_direction =
    (
        target_data = getTargetFromTag context_target_tag
        if target_data == undefined then return false

        offset_axis_value = 0.0
        round_step_mm = getRoundPrecisionStepMm()
        source_axis_value = getContextRoundSourceAxisValue()
        if source_axis_value == undefined then return false
        dumpContextRoundTarget round_direction round_step_mm
        round_ok = false

        undo "Vertex Level Round Item" on
        (
            if target_data[1] == #group then
            (
                round_ok = vertex_level_aligner.roundGroupToStepMillimeters target_data[2] round_direction round_step_mm offset_axis_value:offset_axis_value source_axis_value:source_axis_value
            )
            else if target_data[1] == #level then
            (
                round_ok = vertex_level_aligner.roundLevelToStepMillimeters target_data[2] target_data[3] round_direction round_step_mm offset_axis_value:offset_axis_value source_axis_value:source_axis_value
            )
        )

        tree_ok = rebuildTree()
        if tree_ok then lbl_status.text = vertex_level_aligner.last_message
        round_ok and tree_ok
        -- return
    )

    /*
    Applies the selected Material ID to polygons whose every vertex belongs to the selected TreeView target set.
    TreeView and vertex/edge selections are preserved; the scan is not rebuilt because topology is unchanged.
    */
    function applySelectedTreeMaterialId =
    (
        selected_targets = getSelectedTreeTargets()

        if selected_targets.count == 0 then
        (
            lbl_status.text = "Select one or more TreeView levels first."
            return false
        )

        material_id = getSelectedFaceMaterialId()
        material_ok = false

        undo "Vertex Level Polygon Material ID" on
        (
            material_ok = vertex_level_aligner.applyMaterialIdToTargets selected_targets material_id
        )

        lbl_status.text = vertex_level_aligner.last_message
        material_ok
        -- return
    )

    /*
    Scans the first selected object using the current threshold spinner value and rebuilds the TreeView.
    This is shared by the threshold-change event and the explicit SCAN OBJECT button.
    */
    function scanCurrentThreshold =
    (
        threshold_system = thresholdMmToSystem spn_threshold.value
        vertex_level_aligner.threshold_value = threshold_system
        vertex_level_aligner.world_axis = getSelectedWorldAxis()
        vertex_level_aligner_ui.setIniValue "Threshold" threshold_system
        vertex_level_aligner_ui.setIniValue "WorldAxis" (getSelectedWorldAxisIndex())

        scan_ok = vertex_level_aligner.scanSelection threshold:threshold_system world_axis_value:vertex_level_aligner.world_axis
        tree_ok = rebuildTree()

        if not(scan_ok) then
        (
            lbl_status.text = vertex_level_aligner.last_message
        )

        scan_ok and tree_ok
        -- return
    )

    /*
    Switches the active world axis, swaps that axis's display-trim dropdown value, and rescans.
    scanCurrentThreshold is defined above this function so MAXScript does not resolve it as undefined.
    */
    function switchWorldAxis axis_index =
    (
        if not(setWorldAxisControls axis_index) then return false
        if not(loadAxisDisplayTrimDropdown axis_index) then return false

        scanCurrentThreshold()
        -- return
    )

    /*
    Aligns the current right-click TreeView target and refreshes the tree.
    */
    function alignContextTarget alignment_mode =
    (
        target_data = getTargetFromTag context_target_tag
        if target_data == undefined then return false

        align_ok = false

        undo "Vertex Level Align" on
        (
            if target_data[1] == #group then
            (
                align_ok = vertex_level_aligner.alignGroup target_data[2] alignment_mode
            )
            else if target_data[1] == #level then
            (
                align_ok = vertex_level_aligner.alignLevel target_data[2] target_data[3] alignment_mode
            )
        )

        tree_ok = rebuildTree()
        if tree_ok then lbl_status.text = vertex_level_aligner.last_message
        align_ok and tree_ok
        -- return
    )

    on vertex_level_aligner_rollout open do
    (
        vertexLevelAlignerWriteLog "300 UI rollout open entered"
        vertexLevelAlignerWriteLog "302 UI static rollout title already set"

        color_class = dotNetClass "System.Drawing.Color"
        border_style = dotNetClass "System.Windows.Forms.BorderStyle"

        tv_levels.BackColor = color_class.FromArgb 48 48 48
        tv_levels.ForeColor = color_class.FromArgb 210 210 210
        tv_levels.BorderStyle = border_style.FixedSingle
        tv_levels.HideSelection = false
        tv_levels.ShowLines = true
        tv_levels.ShowPlusMinus = true
        tv_levels.ShowRootLines = false
        tv_levels.FullRowSelect = true

        tree_font = tv_levels.Font
        tv_levels.Font = dotNetObject "System.Drawing.Font" tree_font.FontFamily tree_font.Size tree_font.Style

        vertexLevelAlignerWriteLog "303 UI before loadUiState"
        loadUiState()
        vertexLevelAlignerWriteLog "304 UI after loadUiState"

        current_size = [320, 576]
        try
        (
            current_size = getDialogSize vertex_level_aligner_rollout
        )
        catch
        (
            dialog_size_exception = getCurrentException()
            current_size = [320, 576]
        )
        resizeControls current_size

        vertexLevelAlignerWriteLog "305 UI before initial selected-object scan"
        vertex_level_aligner.scanSelection threshold:vertex_level_aligner.threshold_value world_axis_value:(getSelectedWorldAxis())
        rebuildTree()
        vertexLevelAlignerWriteLog "306 UI initial selected-object scan complete"

        vertexLevelAlignerWriteLog "310 UI rollout open complete"
    )

    on vertex_level_aligner_rollout close do
    (
        saveUiState()
    )

    on vertex_level_aligner_rollout moved dialog_pos do
    (
        saveUiState dialog_pos:dialog_pos
    )

    on vertex_level_aligner_rollout resized dialog_size do
    (
        resizeControls dialog_size
        saveUiState dialog_size:dialog_size
    )

    on vertex_level_aligner_rollout help do
    (
        vertex_level_aligner_ui.reloadLatestScript()
    )

    on cb_axis_x changed state do
    (
        if not(is_updating_world_axis) then
        (
            if state then
            (
                switchWorldAxis 1
            )
            else
            (
                setWorldAxisControls (getWorldAxisIndex vertex_level_aligner.world_axis)
            )
        )
    )

    on cb_axis_y changed state do
    (
        if not(is_updating_world_axis) then
        (
            if state then
            (
                switchWorldAxis 2
            )
            else
            (
                setWorldAxisControls (getWorldAxisIndex vertex_level_aligner.world_axis)
            )
        )
    )

    on cb_axis_z changed state do
    (
        if not(is_updating_world_axis) then
        (
            if state then
            (
                switchWorldAxis 3
            )
            else
            (
                setWorldAxisControls (getWorldAxisIndex vertex_level_aligner.world_axis)
            )
        )
    )

    on spn_threshold changed value do
    (
        scanCurrentThreshold()
    )

    on rb_view_mode changed state do
    (
        vertex_level_aligner_ui.setIniValue "ViewMode" state
        rebuildTree()
    )

    on ddl_level_vertex_condition selected condition_selection do
    (
        vertex_level_aligner_ui.setIniValue "LevelVertexCondition" condition_selection
        rebuildTree()
    )

    on ddl_level_vertex_count selected count_selection do
    (
        filter_value = count_selection - 1
        if filter_value < 0 then filter_value = 0

        vertex_level_aligner_ui.setIniValue "LevelVertexCount" filter_value
        rebuildTree()
    )

    on ddl_face_material_id selected material_id_selection do
    (
        vertex_level_aligner_ui.setIniValue "FaceMaterialID" material_id_selection
    )

    on btn_apply_face_material_id pressed do
    (
        applySelectedTreeMaterialId()
    )

    on ddl_round_precision selected precision_selection do
    (
        vertex_level_aligner_ui.setIniValue "RoundPrecision" precision_selection
    )

    on ddl_bbox_unit selected bbox_unit_selection do
    (
        vertex_level_aligner_ui.setIniValue "BBoxUnit" bbox_unit_selection
        updateLocalBoundingBoxLabel()
    )

    on ddl_display_trim selected trim_selection do
    (
        if not(is_updating_display_trim) then
        (
            trim_digits = trim_selection - 1
            current_axis_index = getSelectedWorldAxisIndex()
            setStoredAxisDisplayTrimDigits current_axis_index trim_digits
            rebuildTree()
        )
    )

    on btn_expand_collapse pressed do
    (
        expandSelectedOrAllLevels()
    )

    on btn_expand_collapse rightClick do
    (
        collapseSelectedOrAllLevels()
    )

    on btn_restart pressed do
    (
        vertex_level_aligner_ui.reloadLatestScript()
    )

    on btn_scan pressed do
    (
        vertexLevelAlignerWriteLog "400 UI SCAN OBJECT pressed"
        scan_ok = scanCurrentThreshold()
        vertexLevelAlignerWriteLog ("410 UI SCAN OBJECT complete = " + (scan_ok as string) + " | " + vertex_level_aligner.last_message)
    )

    on tv_levels AfterExpand sender event_args do
    (
        updateGroupExpansionIndicator event_args.Node true
    )

    on tv_levels AfterCollapse sender event_args do
    (
        updateGroupExpansionIndicator event_args.Node false
    )

    on tv_levels BeforeSelect sender event_args do
    (
        if not(is_context_tree_selection) and isTreeControlModifierDown() then
        (
            event_args.Cancel = true
        )
    )

    on tv_levels AfterSelect sender event_args do
    (
        if not(vertex_level_aligner_ui.is_rebuilding_tree) and not(is_ctrl_tree_selection) and not(is_context_tree_selection) then
        (
            selectTreeNodeExclusive event_args.Node
        )
    )

    on tv_levels MouseDown sender event_args do
    (
        mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"
        node_value = tv_levels.GetNodeAt event_args.X event_args.Y

        if event_args.Button == mouse_buttons.Left then
        (
            if node_value != undefined and isTreeControlModifierDown() then
            (
                node_bounds = node_value.Bounds
                clicked_on_item = event_args.X >= node_bounds.Left and event_args.X <= node_bounds.Right and event_args.Y >= node_bounds.Top and event_args.Y <= node_bounds.Bottom

                if clicked_on_item then
                (
                    is_ctrl_tree_selection = true
                    toggleTreeNodeSelection node_value
                )
            )
        )
        else if event_args.Button == mouse_buttons.Right and node_value != undefined then
        (
            clicked_tag = getTreeNodeTag node_value

            if clicked_tag != "" then
            (
                if (findItem selected_tree_tags clicked_tag) == 0 then
                (
                    selected_tree_tags = #(clicked_tag)
                    refreshTreeMultiSelectionVisuals()
                    selectTreeNode node_value
                )

                is_context_tree_selection = true
                tv_levels.SelectedNode = node_value
                is_context_tree_selection = false
                context_target_tag = clicked_tag

                updateAlignToMenuText()
                updateRoundMenuText()
                popupMenu vertex_level_aligner_context_menu
            )
        )
    )

    on tv_levels MouseUp sender event_args do
    (
        mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"

        if event_args.Button == mouse_buttons.Left and is_ctrl_tree_selection then
        (
            is_ctrl_tree_selection = false
        )
    )
)

vertexLevelAlignerWriteLog "120 UI rollout definition complete"
vertexLevelAlignerWriteLog "199 UI frontend module loaded"
