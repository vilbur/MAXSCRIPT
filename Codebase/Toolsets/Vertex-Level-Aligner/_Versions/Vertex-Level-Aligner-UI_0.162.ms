/*
Vertex Level Aligner UI 0.162
Frontend-only module. Uses a .NET TreeView for level selection and a native RMB alignment menu while keeping the rollout title literal and static.
*/

global vertex_level_aligner
global vertex_level_aligner_ui
global vertex_level_aligner_rollout
global vertex_level_aligner_ui_source_path
global reloadVertexLevelAlignerMain
global vertex_level_aligner_default_threshold
global vertex_level_aligner_context_menu

if vertex_level_aligner_default_threshold == undefined then
(
    vertex_level_aligner_default_threshold = try(units.decodeValue "1mm")catch(1.0)
)

try(vertexLevelAlignerWriteLog "100 UI file execution started")catch()
vertex_level_aligner_ui_source_path = getSourceFileName()
try(vertexLevelAlignerWriteLog "101 UI source path resolved")catch()
try(vertexLevelAlignerWriteLog "105 UI frontend module loading")catch()

struct vertex_level_aligner_ui_v
(
    file_version = 0.162,
    project_version = 0.782,
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
        dialog_width = getIniInteger "Width" 430
        dialog_height = getIniInteger "Height" 552
        try(vertexLevelAlignerWriteLog "201 UI persisted dialog values read")catch()

        if dialog_width < 340 then dialog_width = 340
        if dialog_height < 300 then dialog_height = 300

        try(vertexLevelAlignerWriteLog "202 UI before createDialog")catch()
        createDialog vertex_level_aligner_rollout width:dialog_width height:dialog_height pos:[dialog_x, dialog_y] lockWidth:false lockHeight:false autoLayoutOnResize:false style:#(#style_titlebar, #style_sysmenu, #style_toolwindow, #style_resizing)
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
    menuItem mi_align_top "Align TOP"
    menuItem mi_align_middle "Align MIDDLE"
    menuItem mi_align_bottom "Align BOTTOM"

    on mi_align_top picked do
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

    on mi_align_bottom picked do
    (
        if vertex_level_aligner_rollout != undefined then
        (
            vertex_level_aligner_rollout.alignContextTarget #bottom
        )
    )
)

rollout vertex_level_aligner_rollout "Vertex Level Aligner 0.782" width:430 height:552
(
    local context_target_tag = ""

    spinner spn_threshold "Threshold:" pos:[8,10] width:180 height:18 range:[0.0, 1000000.0, vertex_level_aligner_default_threshold] type:#worldUnits scale:0.1 fieldWidth:78 tooltip:"Maximum Z deviation from a common level center. Default is 1 mm."
    button btn_scan "SCAN OBJECT" pos:[196,7] width:110 height:24 tooltip:"LMB: Scan every vertex on the selected Editable Poly or Edit Poly object."
    label lbl_hint "LMB selects verts | RMB aligns" pos:[314,11] width:108 height:18 align:#right
    radiobuttons rb_view_mode labels:#("ALL LEVELS", "BROKEN ONLY") columns:2 default:1 pos:[8,38] width:260 height:32 tooltip:"ALL LEVELS: Show every Z level group.\n\nBROKEN ONLY: Show only groups containing multiple exact Z values inside the threshold."
    label lbl_definition "Broken = multiple exact Z values inside one threshold group" pos:[8,67] width:414 height:18 align:#left
    dotNetControl tv_levels "System.Windows.Forms.TreeView" pos:[8,88] width:414 height:398
    label lbl_status "Select one Editable Poly or Edit Poly object." pos:[8,494] width:414 height:18 align:#left
    button btn_restart "RESTART" pos:[8,520] width:414 height:24 tooltip:"LMB: Close this dialog and reload the canonical Vertex Level Aligner package."

    /*
    Formats one scene-space distance using the current 3ds Max display units.
    */
    function formatWorldValue value =
    (
        try(units.formatValue value)catch(value as string)
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
        center_z = group_data[1]
        min_z = group_data[2]
        max_z = group_data[3]
        vertex_count = group_data[4].numberSet
        exact_levels = group_data[5]
        exact_level_count = if isKindOf exact_levels Array then exact_levels.count else 0
        is_broken = group_data[6]

        if is_broken then
        (
            "BROKEN | Group " + (group_index as string) + " | center " + formatWorldValue center_z + " | spread " + formatWorldValue (max_z - min_z) + " | " + (vertex_count as string) + " verts | " + (exact_level_count as string) + " levels"
        )
        else
        (
            "Group " + (group_index as string) + " | Z " + formatWorldValue center_z + " | " + (vertex_count as string) + " verts"
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
    Rebuilds the TreeView from the stored scan without rescanning geometry.
    */
    function rebuildTree =
    (
        vertex_level_aligner_ui.is_rebuilding_tree = true
        tv_levels.BeginUpdate()
        tv_levels.Nodes.Clear()

        show_broken_only = rb_view_mode.state == 2

        for group_index = 1 to vertex_level_aligner.getGroupCount() do
        (
            group_data = vertex_level_aligner.getGroupData group_index

            if group_data != undefined then
            (
                exact_levels = group_data[5]

                if isKindOf exact_levels Array then
                (
                    if not(show_broken_only) or group_data[6] then
                    (
                        group_color = getGroupColor group_index
                        group_node = dotNetObject "System.Windows.Forms.TreeNode" (getGroupText group_index group_data)
                        group_node.ForeColor = group_color
                        group_node.Tag = "G|" + (group_index as string)

                        for level_index = 1 to exact_levels.count do
                        (
                            level_data = exact_levels[level_index]
                            level_text = formatWorldValue level_data[1] + " | " + (level_data[2].numberSet as string) + " verts"
                            level_node = dotNetObject "System.Windows.Forms.TreeNode" level_text
                            level_node.ForeColor = group_color
                            level_node.Tag = "L|" + (group_index as string) + "|" + (level_index as string)
                            group_node.Nodes.Add level_node
                        )

                        tv_levels.Nodes.Add group_node
                        group_node.Expand()
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

        if saved_threshold < 0.0 then saved_threshold = vertex_level_aligner_default_threshold
        if saved_mode < 1 or saved_mode > 2 then saved_mode = 1

        spn_threshold.value = saved_threshold
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
        vertex_level_aligner_ui.setIniValue "Threshold" spn_threshold.value
        vertex_level_aligner_ui.setIniValue "ViewMode" rb_view_mode.state

        if dialog_pos != undefined then
        (
            vertex_level_aligner_ui.setIniValue "PosX" dialog_pos.x
            vertex_level_aligner_ui.setIniValue "PosY" dialog_pos.y
        )

        if dialog_size != undefined then
        (
            if dialog_size.x >= 340 then vertex_level_aligner_ui.setIniValue "Width" dialog_size.x
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
        tree_width = dialog_size.x - 16
        tree_height = dialog_size.y - 154

        if tree_width < 324 then tree_width = 324
        if tree_height < 138 then tree_height = 138

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

        try(vertexLevelAlignerWriteLog "303 UI before loadUiState")catch()
        loadUiState()
        try(vertexLevelAlignerWriteLog "304 UI after loadUiState")catch()

        current_size = try(getDialogSize vertex_level_aligner_rollout)catch([430, 552])
        resizeControls current_size
        rebuildTree()

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

    on spn_threshold changed value do
    (
        vertex_level_aligner.threshold_value = value
        vertex_level_aligner_ui.setIniValue "Threshold" value
        lbl_status.text = "Threshold changed. Press SCAN OBJECT to rebuild groups."
    )

    on rb_view_mode changed state do
    (
        vertex_level_aligner_ui.setIniValue "ViewMode" state
        rebuildTree()
    )

    on btn_restart pressed do
    (
        vertex_level_aligner_ui.reloadLatestScript()
    )

    on btn_scan pressed do
    (
        try(vertexLevelAlignerWriteLog "400 UI SCAN OBJECT pressed")catch()

        vertex_level_aligner.threshold_value = spn_threshold.value
        scan_ok = vertex_level_aligner.scanSelection threshold:spn_threshold.value
        rebuildTree()

        if not(scan_ok) then
        (
            lbl_status.text = vertex_level_aligner.last_message
        )

        try(vertexLevelAlignerWriteLog ("410 UI SCAN OBJECT complete = " + (scan_ok as string) + " | " + vertex_level_aligner.last_message))catch()
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
                    popupMenu vertex_level_aligner_context_menu
                )
            )
        )
    )
)

try(vertexLevelAlignerWriteLog "120 UI rollout definition complete")catch()
try(vertexLevelAlignerWriteLog "199 UI frontend module loaded")catch()
