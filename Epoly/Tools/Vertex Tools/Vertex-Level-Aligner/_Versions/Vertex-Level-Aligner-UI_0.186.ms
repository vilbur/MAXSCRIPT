/*
Vertex Level Aligner UI 0.186
Frontend-only module. Uses a .NET TreeView for level selection and a native RMB alignment menu while keeping the rollout title literal and static.
*/

global vertex_level_aligner
global vertex_level_aligner_ui
global vertex_level_aligner_rollout
global vertex_level_aligner_ui_source_path
global reloadVertexLevelAlignerMain
global vertex_level_aligner_default_threshold
global vertex_level_aligner_context_menu

vertex_level_aligner_default_threshold = 0.0

try(vertexLevelAlignerWriteLog "100 UI file execution started")catch()
vertex_level_aligner_ui_source_path = getSourceFileName()
try(vertexLevelAlignerWriteLog "101 UI source path resolved")catch()
try(vertexLevelAlignerWriteLog "105 UI frontend module loading")catch()

struct vertex_level_aligner_ui_v
(
    file_version = 0.186,
    project_version = 0.807,
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
        setting_text = getINISetting ini_path ini_section key_name
        if setting_text == "" then return default_value

        try(setting_text as integer)catch(default_value)
        -- return
    ),

    /*
    Reads one persisted float or returns the supplied default.
    Invalid INI values are ignored safely.
    */
    function getIniFloat key_name default_value =
    (
        setting_text = getINISetting ini_path ini_section key_name
        if setting_text == "" then return default_value

        try(setting_text as float)catch(default_value)
        -- return
    ),

    /*
    Writes one UI value to the tool INI file as text.
    This helper is used for threshold, mode, position, and size persistence.
    */
    function setIniValue key_name value =
    (
        setINISetting ini_path ini_section key_name (value as string)
        true
        -- return
    ),

    /*
    Returns true only when this rollout currently owns a standalone CreateDialog window.
    Rollout.inDialog is specific to CreateDialog ownership and stays false for embedded manager rollouts.
    */
    function isStandaloneDialogOpen =
    (
        dialog_is_open = try(vertex_level_aligner_rollout.inDialog)catch(false)

        -- return
        dialog_is_open
    ),


    /*
    Opens the standalone dialog using the last valid position and resizable dimensions.
    Width and height are clamped so required controls cannot disappear.
    */
    function showUI =
    (
        try(vertexLevelAlignerWriteLog "200 UI showUI entered")catch()

        dialog_x = getIniInteger "PosX" 120
        dialog_y = getIniInteger "PosY" 120
        dialog_width = 320
        dialog_height = getIniInteger "Height" 552
        try(vertexLevelAlignerWriteLog "201 UI persisted dialog values read")catch()

        if dialog_height < 300 then dialog_height = 300

        try(vertexLevelAlignerWriteLog "202 UI before createDialog")catch()
        createDialog vertex_level_aligner_rollout width:dialog_width height:dialog_height pos:[dialog_x, dialog_y] lockWidth:true lockHeight:false autoLayoutOnResize:false style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing)
        try(vertexLevelAlignerWriteLog "203 UI createDialog returned")catch()
        true
        -- return
    ),

    /*
    Closes only a standalone dialog owned by this frontend.
    Embedded manager rollouts are never passed to DestroyDialog.
    */
    function hideUI =
    (
        if this.isStandaloneDialogOpen() then
        (
            try(destroyDialog vertex_level_aligner_rollout)catch()
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
        true
        -- return
    ),

    on create do
    (
    )
)

try(vertexLevelAlignerWriteLog "110 UI before API struct instance")catch()
vertex_level_aligner_ui = vertex_level_aligner_ui_v()
try(vertexLevelAlignerWriteLog "111 UI API struct instance created")catch()
try(vertexLevelAlignerWriteLog "115 UI literal static title ready")catch()

rcmenu vertex_level_aligner_context_menu
(
    menuItem mi_align_here "Align to Axis"
    separator sep_align_here
    menuItem mi_align_up "Align UP"
    menuItem mi_align_middle "Align MIDDLE"
    menuItem mi_align_down "Align DOWN"
    separator sep_round_actions
    menuItem mi_round_up "Round UP"
    menuItem mi_round_down "Round DOWN"
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

rollout vertex_level_aligner_rollout "Vertex Level Aligner 0.807" width:320 height:552
(
    local context_target_tag = ""
    local z_offset_unit_index = 1
    local is_updating_z_offset = false
    local is_updating_world_axis = false

    button btn_scan "SCAN OBJECT" pos:[8,3] width:148 height:32 tooltip:"LMB: Scan the first selected Editable Poly or Edit Poly object."
    checkbutton cb_axis_x "X" pos:[164,3] width:48 height:32 checked:false tooltip:"LMB: Use world X for level detection, threshold grouping, selection, offset display, and alignment."
    checkbutton cb_axis_y "Y" pos:[214,3] width:48 height:32 checked:false tooltip:"LMB: Use world Y for level detection, threshold grouping, selection, offset display, and alignment."
    checkbutton cb_axis_z "Z" pos:[264,3] width:48 height:32 checked:true tooltip:"LMB: Use world Z for level detection, threshold grouping, selection, offset display, and alignment."
    spinner spn_threshold "Threshold:" pos:[8,43] width:148 height:18 range:[0.0, 1000000.0, 0.0] type:#float scale:0.1 fieldWidth:64 align:#left tooltip:"Maximum gap between neighboring levels on the selected world axis, in millimeters. Adjacent levels within the threshold chain into one group. 0.0 keeps every distinct axis level exact; default is 0.0 mm."
    spinner spn_z_offset "Axis Offset:" pos:[164,43] width:100 height:18 range:[-100000000.0, 100000000.0, 0.0] type:#float scale:0.1 fieldWidth:46 tooltip:"Display-only offset for the selected world axis. X, Y, and Z keep separate values; changing the axis checkbutton swaps this spinner to that axis offset. The unit dropdown is shared and converts the displayed value without changing the physical offset."
    dropdownlist ddl_z_offset_unit "" pos:[268,41] width:44 height:20 items:#("mm", "cm", "m") selection:1 tooltip:"Display unit for Axis Offset. Switching units converts the current value without changing the physical offset."
    radiobuttons rb_view_mode labels:#("ALL LEVELS", "BROKEN ONLY") columns:2 default:1 pos:[48,69] width:224 height:28 align:#center tooltip:"ALL LEVELS: Show every level group on the selected world axis.\n\nBROKEN ONLY: Show only groups containing multiple exact axis levels connected by threshold-sized neighboring gaps."
    label lbl_definition "Threshold = max neighboring axis gap | Broken = chained multiple levels" pos:[8,97] width:304 height:18 align:#left
    dotNetControl tv_levels "System.Windows.Forms.TreeView" pos:[8,118] width:304 height:368
    label lbl_status "Select one Editable Poly or Edit Poly object." pos:[8,494] width:304 height:18 align:#left
    button btn_restart "RESTART" pos:[8,520] width:304 height:24 tooltip:"LMB: Close this dialog and reload the canonical Vertex Level Aligner package."

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
    Applies one mandatory X/Y/Z checkbutton state without allowing all axes to become unchecked.
    */
    function setWorldAxisControls axis_index =
    (
        if axis_index < 1 or axis_index > 3 then axis_index = 3

        is_updating_world_axis = true
        cb_axis_x.checked = (axis_index == 1)
        cb_axis_y.checked = (axis_index == 2)
        cb_axis_z.checked = (axis_index == 3)
        is_updating_world_axis = false

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
        millimeter_scale = try(units.decodeValue "1mm")catch(1.0)
        value_mm * millimeter_scale
        -- return
    )

    /*
    Returns how many millimeters are represented by one selected Axis Offset display unit.
    Unit indexes are 1=mm, 2=cm, and 3=m.
    */
    function getZOffsetUnitScaleMm unit_index =
    (
        case unit_index of
        (
            2: 10.0
            3: 1000.0
            default: 1.0
        )
        -- return
    )

    /*
    Converts one Axis Offset spinner value from its selected UI unit to millimeters.
    */
    function zOffsetDisplayToMillimeters display_value unit_index =
    (
        display_value * (getZOffsetUnitScaleMm unit_index)
        -- return
    )

    /*
    Converts one millimeter Axis Offset value into the selected UI unit.
    */
    function zOffsetMillimetersToDisplay value_mm unit_index =
    (
        unit_scale_mm = getZOffsetUnitScaleMm unit_index
        if unit_scale_mm <= 0.0 then return value_mm

        value_mm / unit_scale_mm
        -- return
    )

    /*
    Returns the current display-only Axis Offset in millimeters regardless of the selected UI unit.
    */
    function getZOffsetMillimeters =
    (
        zOffsetDisplayToMillimeters spn_z_offset.value z_offset_unit_index
        -- return
    )

    /*
    Returns the INI key used to persist the physical Axis Offset for one world axis.
    X, Y, and Z keep independent offset values while sharing the current display unit.
    */
    function getAxisOffsetIniKey axis_index =
    (
        case axis_index of
        (
            1: "AxisOffsetXmm"
            2: "AxisOffsetYmm"
            default: "AxisOffsetZmm"
        )
        -- return
    )

    /*
    Reads one persisted physical Axis Offset in millimeters.
    Missing per-axis values default to zero after the one-time legacy migration.
    */
    function getStoredAxisOffsetMillimeters axis_index =
    (
        key_name = getAxisOffsetIniKey axis_index
        vertex_level_aligner_ui.getIniFloat key_name 0.0
        -- return
    )

    /*
    Persists one physical Axis Offset in millimeters.
    The legacy shared ZOffsetMm key mirrors the active value for downgrade compatibility.
    */
    function setStoredAxisOffsetMillimeters axis_index offset_mm =
    (
        key_name = getAxisOffsetIniKey axis_index
        vertex_level_aligner_ui.setIniValue key_name offset_mm
        vertex_level_aligner_ui.setIniValue "ZOffsetMm" offset_mm
        true
        -- return
    )

    /*
    Initializes missing X/Y/Z offset keys from the pre-0.805 shared Axis Offset.
    The legacy value is assigned only to the axis that was active in the old UI; other axes start at zero.
    */
    function initializeAxisOffsetStorage saved_axis_index legacy_offset_mm =
    (
        for axis_index = 1 to 3 do
        (
            key_name = getAxisOffsetIniKey axis_index
            setting_text = getINISetting vertex_level_aligner_ui.ini_path vertex_level_aligner_ui.ini_section key_name

            if setting_text == "" then
            (
                initial_offset_mm = if axis_index == saved_axis_index then legacy_offset_mm else 0.0
                vertex_level_aligner_ui.setIniValue key_name initial_offset_mm
            )
        )

        true
        -- return
    )

    /*
    Loads the persisted offset for one axis into the spinner using the currently selected display unit.
    */
    function loadAxisOffsetSpinner axis_index =
    (
        offset_mm = getStoredAxisOffsetMillimeters axis_index

        is_updating_z_offset = true
        spn_z_offset.value = zOffsetMillimetersToDisplay offset_mm z_offset_unit_index
        is_updating_z_offset = false
        true
        -- return
    )

    /*
    Adds comma thousands separators to the leading numeric integer part of one display string.
    Decimal digits and any trailing unit text remain unchanged.
    */
    function addThousandsSeparators numeric_text =
    (
        if numeric_text == undefined or numeric_text == "" then return numeric_text

        text_length = numeric_text.count
        integer_start = 1
        prefix_text = ""
        first_character = substring numeric_text 1 1

        if first_character == "-" or first_character == "+" then
        (
            prefix_text = first_character
            integer_start = 2
        )

        integer_end = integer_start - 1

        while integer_end < text_length and (findString "0123456789" (substring numeric_text (integer_end + 1) 1)) != undefined do
        (
            integer_end += 1
        )

        integer_count = integer_end - integer_start + 1
        if integer_count <= 3 then return numeric_text

        grouped_integer = ""

        for digit_offset = 0 to (integer_count - 1) do
        (
            if digit_offset > 0 and (mod (integer_count - digit_offset) 3) == 0 then
            (
                grouped_integer += ","
            )

            grouped_integer += substring numeric_text (integer_start + digit_offset) 1
        )

        suffix_start = integer_end + 1
        suffix_text = if suffix_start <= text_length then substring numeric_text suffix_start (text_length - suffix_start + 1) else ""

        prefix_text + grouped_integer + suffix_text
        -- return
    )

    /*
    Formats one scene-space value for TreeView/RMB display, removes meter letters, and groups thousands with commas.
    Other TreeView label text remains unchanged.
    */
    function formatWorldItemValue value =
    (
        formatted_value = try(units.formatValue value)catch(value as string)
        formatted_value = substituteString formatted_value "m" ""
        formatted_value = substituteString formatted_value "M" ""
        addThousandsSeparators formatted_value
        -- return
    )

    /*
    Formats a real selected-axis world position after subtracting the display-only unit-aware offset.
    The backend keeps the unmodified world coordinate for grouping, selection, and alignment.
    */
    function formatWorldPositionValue value =
    (
        display_value = value - (millimetersToSystem (getZOffsetMillimeters()))
        formatWorldItemValue display_value
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
        millimeter_scale = try(units.decodeValue "1mm")catch(1.0)
        threshold_mm = threshold_system

        if millimeter_scale > 0.0 then
        (
            threshold_mm = threshold_system / millimeter_scale
        )

        threshold_mm
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
    Builds the parent label for one threshold group.
    */
    function getGroupText group_index group_data =
    (
        center_axis = group_data[1]
        min_axis = group_data[2]
        max_axis = group_data[3]
        vertex_count = group_data[4].numberSet
        exact_levels = group_data[5]
        exact_level_count = if isKindOf exact_levels Array then exact_levels.count else 0
        is_broken = group_data[6]

        if is_broken then
        (
            "BROKEN | Group " + (group_index as string) + " | center " + formatWorldPositionValue center_axis + " | spread " + formatWorldItemValue (max_axis - min_axis) + " | " + (vertex_count as string) + " verts | " + (exact_level_count as string) + " levels"
        )
        else
        (
            if vertex_level_aligner.threshold_value == 0.0 then
            (
                "Level " + (group_index as string) + " | " + formatWorldPositionValue center_axis + " | " + (vertex_count as string) + " verts"
            )
            else
            (
                "Group " + (group_index as string) + " | " + formatWorldPositionValue center_axis + " | " + (vertex_count as string) + " verts"
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
            group_index = try(tag_parts[2] as integer)catch(0)
            if group_index > 0 then return #(#group, group_index)
        )
        else if tag_parts.count == 3 and tag_parts[1] == "L" then
        (
            group_index = try(tag_parts[2] as integer)catch(0)
            level_index = try(tag_parts[3] as integer)catch(0)

            if group_index > 0 and level_index > 0 then
            (
                return #(#level, group_index, level_index)
            )
        )

        undefined
        -- return
    )

    /*
    Selects the vertices represented by one TreeView node.
    */
    function selectTreeNode node_value =
    (
        if node_value == undefined then return false

        tag_text = try(node_value.Tag as string)catch("")
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
    Refreshes one parent group label with an explicit expansion indicator.
    "-" means the group is open; "+" means it is collapsed.
    */
    function updateGroupExpansionIndicator node_value expanded_state =
    (
        if node_value == undefined then return false

        tag_text = try(node_value.Tag as string)catch("")
        target_data = getTargetFromTag tag_text
        if target_data == undefined or target_data[1] != #group then return false

        group_data = vertex_level_aligner.getGroupData target_data[2]
        if group_data == undefined then return false

        indicator_text = if expanded_state then "- " else "+ "
        node_value.Text = indicator_text + getGroupText target_data[2] group_data
        true
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
    Rebuilds the TreeView from the stored scan without rescanning geometry.
    */
    function rebuildTree =
    (
        vertex_level_aligner_ui.is_rebuilding_tree = true
        tv_levels.BeginUpdate()
        tv_levels.Nodes.Clear()

        show_broken_only = (rb_view_mode.state == 2) and (vertex_level_aligner.threshold_value > 0.0)
        group_count = vertex_level_aligner.getGroupCount()

        if group_count > 0 then
        (
            for group_offset = 1 to group_count do
            (
                group_index = group_count - group_offset + 1
                group_data = vertex_level_aligner.getGroupData group_index

                if group_data != undefined then
                (
                    exact_levels = group_data[5]

                    if isKindOf exact_levels Array then
                    (
                        largest_level_vertex_count = getLargestLevelVertexCount exact_levels

                        if not(show_broken_only) or group_data[6] then
                        (
                            group_color = getGroupColor group_index
                            group_node = dotNetObject "System.Windows.Forms.TreeNode" ("- " + getGroupText group_index group_data)
                            group_node.ForeColor = group_color
                            group_node.Tag = "G|" + (group_index as string)

                            if group_data[6] then
                            (
                                for level_offset = 1 to exact_levels.count do
                                (
                                    level_index = exact_levels.count - level_offset + 1
                                    level_data = exact_levels[level_index]
                                    level_vertex_count = level_data[2].numberSet
                                    is_largest_level = level_vertex_count == largest_level_vertex_count
                                    level_text = formatWorldPositionValue level_data[1] + " | " + (level_vertex_count as string) + " verts"

                                    if is_largest_level then
                                    (
                                        level_text += "  [MOST]"
                                    )

                                    level_node = dotNetObject "System.Windows.Forms.TreeNode" level_text
                                    level_node.ForeColor = group_color
                                    level_node.Tag = "L|" + (group_index as string) + "|" + (level_index as string)

                                    if is_largest_level then
                                    (
                                        font_style = dotNetClass "System.Drawing.FontStyle"
                                        level_node.NodeFont = dotNetObject "System.Drawing.Font" tv_levels.Font font_style.Bold
                                    )

                                    group_node.Nodes.Add level_node
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
        vertex_level_aligner_ui.is_rebuilding_tree = false
        lbl_status.text = vertex_level_aligner.last_message
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
        legacy_offset_mm = vertex_level_aligner_ui.getIniFloat "ZOffsetMm" 0.0
        saved_z_offset_unit = vertex_level_aligner_ui.getIniInteger "ZOffsetUnit" 1

        if saved_threshold < 0.0 then saved_threshold = vertex_level_aligner_default_threshold
        if saved_mode < 1 or saved_mode > 2 then saved_mode = 1
        if saved_world_axis < 1 or saved_world_axis > 3 then saved_world_axis = 3
        if saved_z_offset_unit < 1 or saved_z_offset_unit > 3 then saved_z_offset_unit = 1

        initializeAxisOffsetStorage saved_world_axis legacy_offset_mm

        is_updating_z_offset = true
        z_offset_unit_index = saved_z_offset_unit
        ddl_z_offset_unit.selection = saved_z_offset_unit
        is_updating_z_offset = false

        setWorldAxisControls saved_world_axis
        loadAxisOffsetSpinner saved_world_axis

        spn_threshold.value = thresholdSystemToMm saved_threshold
        rb_view_mode.state = saved_mode
        vertex_level_aligner.threshold_value = saved_threshold
        true
        -- return
    )

    /*
    Persists threshold, mode, position, and current resizable dialog dimensions.
    */
    function saveUiState dialog_pos:undefined dialog_size:undefined =
    (
        vertex_level_aligner_ui.setIniValue "Threshold" (thresholdMmToSystem spn_threshold.value)
        vertex_level_aligner_ui.setIniValue "ViewMode" rb_view_mode.state
        current_axis_index = getSelectedWorldAxisIndex()
        vertex_level_aligner_ui.setIniValue "WorldAxis" current_axis_index
        setStoredAxisOffsetMillimeters current_axis_index (getZOffsetMillimeters())
        vertex_level_aligner_ui.setIniValue "ZOffsetUnit" z_offset_unit_index

        if dialog_pos != undefined then
        (
            vertex_level_aligner_ui.setIniValue "PosX" dialog_pos.x
            vertex_level_aligner_ui.setIniValue "PosY" dialog_pos.y
        )

        if dialog_size != undefined then
        (
            if dialog_size.y >= 260 then vertex_level_aligner_ui.setIniValue "Height" dialog_size.y
        )

        true
        -- return
    )

    /*
    Resizes the TreeView and lower controls to the current dialog client size.
    */
    function resizeControls dialog_size =
    (
        tree_width = 304
        tree_height = dialog_size.y - 184

        if tree_height < 108 then tree_height = 108

        tv_levels.width = tree_width
        tv_levels.height = tree_height
        lbl_definition.width = tree_width
        lbl_status.pos = [8, dialog_size.y - 58]
        lbl_status.width = tree_width
        btn_restart.pos = [8, dialog_size.y - 32]
        btn_restart.width = tree_width
        true
        -- return
    )

    /*
    Collapses every visible TreeView group without changing stored scan data.
    */
    function collapseAllLevels =
    (
        try(tv_levels.CollapseAll())catch()
        true
        -- return
    )

    /*
    Expands every visible TreeView group without changing stored scan data.
    */
    function expandAllLevels =
    (
        try(tv_levels.ExpandAll())catch()
        true
        -- return
    )

    /*
    Returns the real selected-axis world position represented by the current right-click TreeView target.
    Child rows use their exact level value; group rows use the group's current center value.
    */
    function getContextTargetAxisValue =
    (
        target_data = getTargetFromTag context_target_tag
        if target_data == undefined then return undefined

        group_index = target_data[2]

        if target_data[1] == #group then
        (
            group_data = vertex_level_aligner.getGroupData group_index
            if group_data != undefined then return group_data[1]
        )
        else if target_data[1] == #level then
        (
            level_data = vertex_level_aligner.getLevelData group_index target_data[3]
            if level_data != undefined then return level_data[1]
        )

        undefined
        -- return
    )

    /*
    Updates the first RMB action to show the clicked target's displayed selected-axis value.
    The displayed value honors Axis Offset; the alignment itself still uses the real world coordinate.
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
    Aligns the entire parent group to the exact selected-axis position represented by the right-clicked TreeView row.
    Child rows use their exact level value; group rows use the group's displayed center/current axis value.
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
            align_ok = vertex_level_aligner.alignGroupToAxisValue group_index target_axis_value alignment_mode:#here
        )

        rebuildTree()
        lbl_status.text = vertex_level_aligner.last_message
        align_ok
        -- return
    )

    /*
    Rounds only the vertices represented by the current RMB TreeView item to the selected-axis 5 mm grid.
    Group rows move their group rigidly; child rows move only that exact level.
    */
    function roundContextTarget round_direction =
    (
        target_data = getTargetFromTag context_target_tag
        if target_data == undefined then return false

        offset_axis_value = millimetersToSystem (getZOffsetMillimeters())
        round_ok = false

        undo "Vertex Level Round Item" on
        (
            if target_data[1] == #group then
            (
                round_ok = vertex_level_aligner.roundGroupToFiveMillimeters target_data[2] round_direction offset_axis_value:offset_axis_value
            )
            else if target_data[1] == #level then
            (
                round_ok = vertex_level_aligner.roundLevelToFiveMillimeters target_data[2] target_data[3] round_direction offset_axis_value:offset_axis_value
            )
        )

        rebuildTree()
        lbl_status.text = vertex_level_aligner.last_message
        round_ok
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
        rebuildTree()

        if not(scan_ok) then
        (
            lbl_status.text = vertex_level_aligner.last_message
        )

        scan_ok
        -- return
    )

    /*
    Switches the active world axis and swaps the Axis Offset spinner to that axis's stored value.
    The previous axis offset is persisted before the checkbutton state changes.
    scanCurrentThreshold is defined above this function so MAXScript does not resolve it as undefined.
    */
    function switchWorldAxis axis_index =
    (
        previous_axis_index = getWorldAxisIndex vertex_level_aligner.world_axis
        setStoredAxisOffsetMillimeters previous_axis_index (getZOffsetMillimeters())

        setWorldAxisControls axis_index
        loadAxisOffsetSpinner axis_index
        scanCurrentThreshold()
        true
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

        rebuildTree()
        lbl_status.text = vertex_level_aligner.last_message
        align_ok
        -- return
    )

    on vertex_level_aligner_rollout open do
    (
        try(vertexLevelAlignerWriteLog "300 UI rollout open entered")catch()
        try(vertexLevelAlignerWriteLog "302 UI static rollout title already set")catch()

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

        try(vertexLevelAlignerWriteLog "303 UI before loadUiState")catch()
        loadUiState()
        try(vertexLevelAlignerWriteLog "304 UI after loadUiState")catch()

        current_size = try(getDialogSize vertex_level_aligner_rollout)catch([320, 552])
        resizeControls current_size

        try(vertexLevelAlignerWriteLog "305 UI before initial selected-object scan")catch()
        vertex_level_aligner.scanSelection threshold:vertex_level_aligner.threshold_value world_axis_value:(getSelectedWorldAxis())
        rebuildTree()
        try(vertexLevelAlignerWriteLog "306 UI initial selected-object scan complete")catch()

        try(vertexLevelAlignerWriteLog "310 UI rollout open complete")catch()
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

    on spn_z_offset changed value do
    (
        if not(is_updating_z_offset) then
        (
            current_axis_index = getSelectedWorldAxisIndex()
            setStoredAxisOffsetMillimeters current_axis_index (zOffsetDisplayToMillimeters value z_offset_unit_index)
            vertex_level_aligner_ui.setIniValue "ZOffsetUnit" z_offset_unit_index
            rebuildTree()
        )
    )

    on ddl_z_offset_unit selected unit_index do
    (
        if not(is_updating_z_offset) then
        (
            offset_mm = zOffsetDisplayToMillimeters spn_z_offset.value z_offset_unit_index

            is_updating_z_offset = true
            z_offset_unit_index = unit_index
            spn_z_offset.value = zOffsetMillimetersToDisplay offset_mm z_offset_unit_index
            is_updating_z_offset = false

            current_axis_index = getSelectedWorldAxisIndex()
            setStoredAxisOffsetMillimeters current_axis_index offset_mm
            vertex_level_aligner_ui.setIniValue "ZOffsetUnit" z_offset_unit_index
            rebuildTree()
        )
    )

    on btn_restart pressed do
    (
        vertex_level_aligner_ui.reloadLatestScript()
    )

    on btn_scan pressed do
    (
        try(vertexLevelAlignerWriteLog "400 UI SCAN OBJECT pressed")catch()
        scan_ok = scanCurrentThreshold()
        try(vertexLevelAlignerWriteLog ("410 UI SCAN OBJECT complete = " + (scan_ok as string) + " | " + vertex_level_aligner.last_message))catch()
    )

    on tv_levels AfterExpand sender event_args do
    (
        updateGroupExpansionIndicator event_args.Node true
    )

    on tv_levels AfterCollapse sender event_args do
    (
        updateGroupExpansionIndicator event_args.Node false
    )

    on tv_levels AfterSelect sender event_args do
    (
        if not(vertex_level_aligner_ui.is_rebuilding_tree) then
        (
            selectTreeNode event_args.Node
        )
    )

    on tv_levels MouseDown sender event_args do
    (
        mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"

        if event_args.Button == mouse_buttons.Right then
        (
            node_value = tv_levels.GetNodeAt event_args.X event_args.Y

            if node_value != undefined then
            (
                tv_levels.SelectedNode = node_value
                context_target_tag = try(node_value.Tag as string)catch("")

                if context_target_tag != "" then
                (
                    updateAlignToMenuText()
                    popupMenu vertex_level_aligner_context_menu
                )
            )
        )
    )
)

try(vertexLevelAlignerWriteLog "120 UI rollout definition complete")catch()
try(vertexLevelAlignerWriteLog "199 UI frontend module loaded")catch()
