/*
Vertex Level Aligner Test 0.185
Package architecture regression for main / UI / FN separation.
*/

global EPOLY_TOOLS_RUNTIME_MODE
global vertex_level_aligner
global vertex_level_aligner_ui
global vertex_level_aligner_rollout

/*
Loads the package through the main entry in library mode.
The main must load FN and UI without opening a standalone dialog.
*/
function partOfTest1 =
(
    test_directory = getFilenamePath (getSourceFileName())
    main_path = test_directory + "..\\Vertex-Level-Aligner.ms"

    if not(doesFileExist main_path) then throw ("VLevelA Test: missing main entry: " + main_path)

    previous_runtime_mode = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_RUNTIME_MODE = #library
    fileIn main_path quiet:true
    EPOLY_TOOLS_RUNTIME_MODE = previous_runtime_mode

    if vertex_level_aligner == undefined then throw "VLevelA Test: FN backend was not loaded by main."
    if vertex_level_aligner_ui == undefined then throw "VLevelA Test: UI frontend was not loaded by main."
    if vertex_level_aligner_rollout == undefined then throw "VLevelA Test: rollout was not defined by UI."

    true
    -- return
)

/*
Verifies the three-file package roles from source text.
Main loads FN/UI, UI does not load FN/main, and FN contains no rollout declaration.
*/
function partOfTest2 =
(
    tool_directory = getFilenamePath (getSourceFileName()) + "..\\"
    main_path = tool_directory + "Vertex-Level-Aligner.ms"
    ui_path = tool_directory + "Vertex-Level-Aligner-UI.ms"
    fn_path = tool_directory + "Vertex-Level-Aligner-FN.ms"

    for file_path in #(main_path, ui_path, fn_path) do
    (
        if not(doesFileExist file_path) then throw ("VLevelA Test: missing package file: " + file_path)
    )

    main_text = ""
    ui_text = ""
    fn_text = ""

    stream = openFile main_path mode:"rt"
    while not(eof stream) do main_text += readLine stream + "\n"
    close stream

    stream = openFile ui_path mode:"rt"
    while not(eof stream) do ui_text += readLine stream + "\n"
    close stream

    stream = openFile fn_path mode:"rt"
    while not(eof stream) do fn_text += readLine stream + "\n"
    close stream

    if (findString main_text "Vertex-Level-Aligner-FN.ms") == undefined then throw "VLevelA Test: main does not load FN."
    if (findString main_text "Vertex-Level-Aligner-UI.ms") == undefined then throw "VLevelA Test: main does not load UI."
    if (findString main_text "Vertex-Layer-Aligner") != undefined or (findString ui_text "Vertex-Layer-Aligner") != undefined or (findString fn_text "Vertex-Layer-Aligner") != undefined then throw "VLevelA Test: old tool name remains in current package source."
    if (findString ui_text "fileIn") != undefined then throw "VLevelA Test: UI must not load package dependencies."
    if (findString ui_text "vertex_level_aligner_rollout.title =") != undefined then throw "VLevelA Test: runtime rollout-title mutation is forbidden."
    if (findString ui_text "dotNetControl tv_levels \"System.Windows.Forms.TreeView\"") == undefined then throw "VLevelA Test: TreeView is missing."
    if (findString ui_text "on tv_levels AfterSelect") == undefined then throw "VLevelA Test: TreeView selection callback is missing."
    align_to_index = findString ui_text "menuItem mi_align_here \"Align to Z\""
    align_up_index = findString ui_text "menuItem mi_align_up \"Align UP\""
    if align_to_index == undefined or align_up_index == undefined or align_to_index > align_up_index then throw "VLevelA Test: dynamic Align to Z action is not the first RMB alignment action."
    if (findString ui_text "function getContextTargetZ") == undefined then throw "VLevelA Test: RMB target-Z resolver is missing."
    if (findString ui_text "function updateAlignToMenuText") == undefined then throw "VLevelA Test: dynamic Align to {Z} menu updater is missing."
    if (findString ui_text "mi_align_here.text = \"Align to \" + formatWorldPositionValue target_z") == undefined then throw "VLevelA Test: RMB action does not display the clicked Z position."
    if (findString ui_text "Align MIDDLE") == undefined or (findString ui_text "Align DOWN") == undefined then throw "VLevelA Test: alignment RMB menu is incomplete."
    if (findString ui_text "vertex_level_aligner_rollout.alignContextHere()") == undefined then throw "VLevelA Test: Align-to-Z menu item is not wired to the rollout action."
    if (findString ui_text "menuItem mi_align_up \"Align UP\"") == undefined or (findString ui_text "menuItem mi_align_down \"Align DOWN\"") == undefined then throw "VLevelA Test: UP/DOWN RMB labels are missing."
    if (findString ui_text "Align TOP") != undefined or (findString ui_text "Align BOTTOM") != undefined then throw "VLevelA Test: legacy TOP/BOTTOM RMB labels remain."
    if (findString fn_text "#top: \"UP\"") == undefined or (findString fn_text "#bottom: \"DOWN\"") == undefined then throw "VLevelA Test: backend status labels are not UP/DOWN."
    if (findString ui_text "group_index = group_count - group_offset + 1") == undefined then throw "VLevelA Test: TreeView groups are not displayed highest-Z first."
    if (findString ui_text "level_index = exact_levels.count - level_offset + 1") == undefined then throw "VLevelA Test: broken-group child levels are not displayed highest-Z first."
    if (findString fn_text "function alignGroupToZ group_index target_z alignment_mode:#here") == undefined then throw "VLevelA Test: whole-group explicit-Z alignment backend is missing."
    if (findString ui_text "default:1") == undefined then throw "VLevelA Test: ALL LEVELS is not the default radio mode."
    if (findString fn_text "vertex_level_aligner_default_threshold = 0.0") == undefined then throw "VLevelA Test: zero backend threshold default is missing."
    if (findString ui_text "label lbl_threshold_unit \"mm\"") == undefined then throw "VLevelA Test: millimeter unit label is missing."
    if (findString ui_text "type:#float") == undefined or (findString ui_text "range:[0.0, 1000000.0, 0.0]") == undefined then throw "VLevelA Test: threshold UI is not a 0.0 mm float spinner."
    if (findString ui_text "thresholdMmToSystem") == undefined or (findString ui_text "thresholdSystemToMm") == undefined then throw "VLevelA Test: threshold mm/system conversion helpers are missing."
    if (findString ui_text "function scanCurrentThreshold") == undefined then throw "VLevelA Test: shared threshold scan helper is missing."
    if (findString ui_text "on spn_threshold changed value do") == undefined or (findString ui_text "scanCurrentThreshold()") == undefined then throw "VLevelA Test: threshold change does not trigger an immediate scan."
    if (findString ui_text "button btn_scan \"SCAN OBJECT\" pos:[8,3] width:304 height:32") == undefined then throw "VLevelA Test: SCAN OBJECT is not the first full-width 32 px control."
    if (findString ui_text "rollout vertex_level_aligner_rollout \"Vertex Level Aligner 0.799\" width:320 height:552") == undefined then throw "VLevelA Test: rollout width is not fixed at 320 px."
    if (findString ui_text "dialog_width = 320") == undefined or (findString ui_text "lockWidth:true lockHeight:false") == undefined then throw "VLevelA Test: standalone dialog width is not locked at 320 px."
    if (findString ui_text "getIniInteger \"Width\"") != undefined then throw "VLevelA Test: obsolete persisted dialog width is still being read."
    scan_control_index = findString ui_text "button btn_scan \"SCAN OBJECT\""
    threshold_control_index = findString ui_text "spinner spn_threshold \"Threshold:\""
    if scan_control_index == undefined or threshold_control_index == undefined or scan_control_index > threshold_control_index then throw "VLevelA Test: SCAN OBJECT is not declared before the threshold control."
    if (findString ui_text "function updateGroupExpansionIndicator") == undefined then throw "VLevelA Test: explicit group expansion indicator helper is missing."
    if (findString ui_text "function getLargestLevelVertexCount") == undefined then throw "VLevelA Test: largest-level vertex-count helper is missing."
    if (findString ui_text "level_text += \"  [MOST]\"") == undefined then throw "VLevelA Test: dominant level text marker is missing."
    if (findString ui_text "level_node.NodeFont = dotNetObject \"System.Drawing.Font\" tv_levels.Font font_style.Bold") == undefined then throw "VLevelA Test: dominant level bold highlight is missing."
    if (findString ui_text "on tv_levels AfterExpand") == undefined or (findString ui_text "on tv_levels AfterCollapse") == undefined then throw "VLevelA Test: group +/- indicator is not wired to TreeView expansion events."
    if (findString ui_text "\"- \" + getGroupText group_index group_data") == undefined then throw "VLevelA Test: initially expanded groups do not show the '-' indicator."
    if (findString fn_text "function filterSingleVertexLevels") == undefined then throw "VLevelA Test: compatibility level-retention helper is missing."
    if (findString fn_text "exact_level_tolerance = if threshold_value == 0.0 then 0.0 else exact_epsilon") == undefined then throw "VLevelA Test: zero threshold does not disable exact-level epsilon merging."
    if (findString fn_text "exact_levels = this.buildExactLevels sample_values tolerance:exact_level_tolerance") == undefined then throw "VLevelA Test: scanner does not retain the complete exact-level list."
    if (findString fn_text "exact_levels = this.filterSingleVertexLevels all_exact_levels") != undefined then throw "VLevelA Test: scanner still drops singleton exact levels before threshold grouping."
    if (findString fn_text "if threshold_limit == 0.0 then") == undefined then throw "VLevelA Test: zero threshold does not use one-group-per-level mode."
    if (findString fn_text "maximum_span = threshold_limit * 2.0") != undefined then throw "VLevelA Test: legacy total-span threshold grouping is still present."
    if (findString fn_text "(level_z - previous_z) <= (threshold_limit + exact_epsilon)") == undefined then throw "VLevelA Test: neighboring-gap threshold chaining is missing."
    if (findString ui_text "show_broken_only = (rb_view_mode.state == 2) and (vertex_level_aligner.threshold_value > 0.0)") == undefined then throw "VLevelA Test: threshold 0.0 does not force all exact levels visible."
    if (findString fn_text "selected_nodes.count == 0") == undefined then throw "VLevelA Test: scanSelection still rejects multi-object selection instead of using the first object."
    if (findString ui_text "scanSelection threshold:vertex_level_aligner.threshold_value") == undefined then throw "VLevelA Test: rollout open does not scan the first selected object."
    if (findString ui_text "if group_data[6] then") == undefined then throw "VLevelA Test: unbroken groups still create redundant child rows."
    if (findString ui_text "separator sep_tree_actions") == undefined then throw "VLevelA Test: TreeView context-menu separator is missing."
    if (findString ui_text "Collapse All") == undefined or (findString ui_text "Expand All") == undefined then throw "VLevelA Test: TreeView Collapse/Expand All context actions are missing."
    if (findString fn_text "copy exact_levels") != undefined then throw "VLevelA Test: mapped copy() regression returned to group data."
    if (findString ui_text "rollout vertex_level_aligner_rollout \"Vertex Level Aligner 0.799\"") == undefined then throw "VLevelA Test: literal static rollout title is missing."
    if (findString fn_text "rollout ") != undefined then throw "VLevelA Test: FN must not define rollouts."
    if (findString fn_text "createDialog") != undefined then throw "VLevelA Test: FN must not create dialogs."
    if (findString fn_text "global vertexLevelAlignerWriteLog") == undefined then throw "VLevelA Test: FN logger must be explicitly global."
    if (findString fn_text "global vertexLevelAlignerStartLog") == undefined then throw "VLevelA Test: FN log initializer must be explicitly global."
    if (findString fn_text "this.scanNode selected_nodes[1]") == undefined then throw "VLevelA Test: scanSelection must dispatch scanNode through this."
    if (findString fn_text "qsort sample_values this.compareVertexSamples") == undefined then throw "VLevelA Test: qsort comparator must dispatch through this."
    if (findString fn_text "vertex_position * node_value.objectTransform") == undefined then throw "VLevelA Test: vertex world positions do not use objectTransform."
    if (findString fn_text "inverse scan_node.objectTransform") == undefined then throw "VLevelA Test: Editable Poly world-Z alignment does not use objectTransform."
    if (findString fn_text "function getEdgesBetweenVertexBits") == undefined then throw "VLevelA Test: level edge resolver is missing."
    if (findString fn_text "function unhideVertexBits") == undefined then throw "VLevelA Test: TreeView selection vertex-unhide helper is missing."
    if (findString fn_text "polyop.getHiddenVerts topology_value") == undefined or (findString fn_text "polyop.unHideAllVerts topology_value") == undefined then throw "VLevelA Test: Editable Poly target-vertex unhide path is missing."
    if (findString fn_text "modifier_value.ButtonOp #UnhideAllVertex") == undefined then throw "VLevelA Test: Edit Poly vertex-unhide operation is missing."
    if (findString fn_text "this.unhideVertexBits group_data[4]") == undefined or (findString fn_text "this.unhideVertexBits level_data[2]") == undefined then throw "VLevelA Test: group/level selection does not unhide its vertices first."
    if (findString fn_text "current_subobject_level == 2") == undefined then throw "VLevelA Test: Tree selection does not honor Edge sub-object level."
    if (findString fn_text "polyop.setEdgeSelection topology_value edge_bits") == undefined then throw "VLevelA Test: Editable Poly edge writer is missing."
    if (findString fn_text "modifier_value.Select #Edge edge_bits select:true") == undefined then throw "VLevelA Test: Edit Poly edge writer is missing."
    if (findString ui_text "spinner spn_z_offset \"Z Offset:\"") == undefined then throw "VLevelA Test: Z Offset spinner is missing."
    if (findString ui_text "dropdownlist ddl_z_offset_unit") == undefined or (findString ui_text "items:#(\"mm\", \"cm\", \"m\")") == undefined then throw "VLevelA Test: Z Offset mm/cm/m unit dropdown is missing."
    if (findString ui_text "function zOffsetDisplayToMillimeters") == undefined or (findString ui_text "function zOffsetMillimetersToDisplay") == undefined then throw "VLevelA Test: Z Offset dynamic unit conversion helpers are missing."
    if (findString ui_text "\"ZOffsetMm\"") == undefined or (findString ui_text "\"ZOffsetUnit\"") == undefined then throw "VLevelA Test: Z Offset physical value/unit persistence is missing."
    if (findString ui_text "on ddl_z_offset_unit selected unit_index do") == undefined then throw "VLevelA Test: Z Offset unit dropdown conversion event is missing."
    if (findString ui_text "formatWorldPositionValue") == undefined then throw "VLevelA Test: world-Z display offset formatter is missing."

    true
    -- return
)

/*
Opens and closes the frontend explicitly after library-mode package loading.
This confirms UI remains independently callable without auto-execution.
*/
function partOfTest3 =
(
    vertex_level_aligner_ui.showUI()

    if vertex_level_aligner_rollout.title != "Vertex Level Aligner 0.799" then throw ("VLevelA Test: unexpected rollout title: " + vertex_level_aligner_rollout.title)
    if try(vertex_level_aligner_rollout.spn_threshold)catch(undefined) == undefined then throw "VLevelA Test: threshold spinner missing."
    if try(vertex_level_aligner_rollout.btn_scan)catch(undefined) == undefined then throw "VLevelA Test: SCAN OBJECT button missing."
    if try(vertex_level_aligner_rollout.rb_view_mode)catch(undefined) == undefined then throw "VLevelA Test: view-mode radios missing."
    if try(vertex_level_aligner_rollout.tv_levels)catch(undefined) == undefined then throw "VLevelA Test: TreeView missing."
    if try(vertex_level_aligner_rollout.btn_restart)catch(undefined) == undefined then throw "VLevelA Test: RESTART button missing."

    dialog_size = getDialogSize vertex_level_aligner_rollout
    if dialog_size.x != 320 then throw ("VLevelA Test: dialog width is not locked to 320 px: " + (dialog_size.x as string))

    vertex_level_aligner_ui.hideUI()

    true
    -- return
)


/*
Returns true when two world-Z values are equal within a small numeric tolerance.
*/
function testZNear value_a value_b =
(
    abs(value_a - value_b) <= 0.00001
    -- return
)

/*
Creates an Editable Poly with two nearby Z levels, scans it, aligns the group UP, and verifies every group vertex.
*/
function partOfTest4 =
(
    threshold_value = try(units.decodeValue "1mm")catch(1.0)
    level_offset = threshold_value * 0.5
    test_object = undefined

    undo "Vertex Level Aligner Test 4 - Editable Poly Align UP" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_EDITABLE"
        convertToPoly test_object
        try(test_object.baseObject.showCage = off)catch()

        upper_bits = #{3,4}
        upper_positions = #()

        for vertex_id in upper_bits do
        (
            vertex_position = polyop.getVert test_object.baseObject vertex_id
            vertex_position.z += level_offset
            append upper_positions vertex_position
        )

        polyop.setVert test_object.baseObject upper_bits upper_positions
        update test_object

        if not(vertex_level_aligner.scanNode test_object threshold:threshold_value) then throw "VLevelA Test 4: Editable Poly scan failed."
        if vertex_level_aligner.getGroupCount() != 1 then throw "VLevelA Test 4: expected one threshold group."
        if vertex_level_aligner.getBrokenGroupCount() != 1 then throw "VLevelA Test 4: expected one broken group."

        group_data = vertex_level_aligner.getGroupData 1
        target_z = group_data[3]

        if not(vertex_level_aligner.alignGroup 1 #top) then throw "VLevelA Test 4: UP alignment failed."

        context_data = vertex_level_aligner.resolveContext test_object

        for vertex_id = 1 to vertex_level_aligner.getContextVertexCount context_data do
        (
            world_position = vertex_level_aligner.getWorldVertexPosition context_data vertex_id
            if not(testZNear world_position.z target_z) then throw ("VLevelA Test 4: vertex did not align UP: " + (vertex_id as string))
        )
    )

    true
    -- return
)

/*
Creates an Edit Poly context with two nearby Z levels, aligns the group DOWN, and verifies every modifier vertex.
*/
function partOfTest5 =
(
    threshold_value = try(units.decodeValue "1mm")catch(1.0)
    level_offset = threshold_value * 0.5
    test_object = undefined
    test_modifier = undefined

    undo "Vertex Level Aligner Test 5 - Edit Poly Align DOWN" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_EDITPOLY"
        convertToPoly test_object
        try(test_object.baseObject.showCage = off)catch()

        upper_bits = #{3,4}
        upper_positions = #()

        for vertex_id in upper_bits do
        (
            vertex_position = polyop.getVert test_object.baseObject vertex_id
            vertex_position.z += level_offset
            append upper_positions vertex_position
        )

        polyop.setVert test_object.baseObject upper_bits upper_positions
        update test_object

        test_modifier = Edit_Poly()
        test_modifier.name = "VLevelA TEST EDIT POLY"
        test_modifier.showCage = off
        addModifier test_object test_modifier

        select test_object
        max modify mode
        test_modifier.SetPrimaryNode test_object
        test_modifier.useStackSelection = false
        test_modifier.selectMode = 0
        modPanel.setCurrentObject test_modifier node:test_object
        test_modifier.SetEPolySelLevel #Vertex
        subObjectLevel = 1

        if not(vertex_level_aligner.scanNode test_object modifier_value:test_modifier threshold:threshold_value) then throw "VLevelA Test 5: Edit Poly scan failed."
        if vertex_level_aligner.getGroupCount() != 1 then throw "VLevelA Test 5: expected one threshold group."
        if vertex_level_aligner.getBrokenGroupCount() != 1 then throw "VLevelA Test 5: expected one broken group."

        group_data = vertex_level_aligner.getGroupData 1
        target_z = group_data[2]

        if not(vertex_level_aligner.alignGroup 1 #bottom) then throw "VLevelA Test 5: DOWN alignment failed."

        context_data = vertex_level_aligner.resolveContext test_object modifier_value:test_modifier

        for vertex_id = 1 to vertex_level_aligner.getContextVertexCount context_data do
        (
            world_position = vertex_level_aligner.getWorldVertexPosition context_data vertex_id
            if not(testZNear world_position.z target_z) then throw ("VLevelA Test 5: vertex did not align DOWN: " + (vertex_id as string))
        )
    )

    true
    -- return
)

/*
Verifies single-vertex exact levels are retained and participate in threshold grouping.
All exact levels from all vertices must remain available to the TreeView.
*/
function partOfTest6 =
(
    single_bits = #{1}
    pair_bits = #{2,3}
    retained_levels = vertex_level_aligner.filterSingleVertexLevels #(
        #(0.0, single_bits),
        #(1.0, pair_bits))

    if retained_levels.count != 2 then throw "VLevelA Test 6: a single-vertex exact level was dropped."
    if retained_levels[1][2].numberSet != 1 then throw "VLevelA Test 6: singleton exact level vertex data changed."
    if retained_levels[2][2].numberSet != 2 then throw "VLevelA Test 6: paired exact level vertex data changed."

    grouped_levels = vertex_level_aligner.buildThresholdGroups retained_levels threshold:10.0
    if grouped_levels.count != 1 then throw "VLevelA Test 6: threshold did not group the retained singleton with its neighboring level."
    if grouped_levels[1][4].numberSet != 3 then throw "VLevelA Test 6: grouped vertex set does not contain every vertex."

    true
    -- return
)

/*
Verifies threshold 0.0 preserves distinct Z values even when they are closer than the normal numeric epsilon.
Each valid exact level becomes its own unbroken group.
*/
function partOfTest7 =
(
    tiny_offset = vertex_level_aligner.exact_epsilon * 0.5
    sample_values = #(
        #(0.0, 1),
        #(0.0, 2),
        #(tiny_offset, 3),
        #(tiny_offset, 4))

    exact_levels = vertex_level_aligner.buildExactLevels sample_values tolerance:0.0
    filtered_levels = vertex_level_aligner.filterSingleVertexLevels exact_levels
    zero_groups = vertex_level_aligner.buildThresholdGroups filtered_levels threshold:0.0

    if exact_levels.count != 2 then throw "VLevelA Test 7: threshold-zero exact-level construction rounded distinct Z values together."
    if zero_groups.count != 2 then throw "VLevelA Test 7: threshold 0.0 did not create one group per exact Z level."
    if zero_groups[1][6] or zero_groups[2][6] then throw "VLevelA Test 7: threshold-zero exact groups must not be marked broken."
    if zero_groups[1][5].count != 1 or zero_groups[2][5].count != 1 then throw "VLevelA Test 7: threshold-zero groups contain merged exact levels."

    true
    -- return
)

/*
Creates one broken Editable Poly group and aligns the whole group to the Z of its selected lower exact level.
This covers the backend behavior used by the first RMB action, Align HERE.
*/
function partOfTest8 =
(
    threshold_value = try(units.decodeValue "1mm")catch(1.0)
    level_offset = threshold_value * 0.5
    test_object = undefined

    undo "Vertex Level Aligner Test 8 - Align HERE" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_ALIGN_HERE"
        convertToPoly test_object
        try(test_object.baseObject.showCage = off)catch()

        upper_bits = #{3,4}
        upper_positions = #()

        for vertex_id in upper_bits do
        (
            vertex_position = polyop.getVert test_object.baseObject vertex_id
            vertex_position.z += level_offset
            append upper_positions vertex_position
        )

        polyop.setVert test_object.baseObject upper_bits upper_positions
        update test_object

        if not(vertex_level_aligner.scanNode test_object threshold:threshold_value) then throw "VLevelA Test 8: Editable Poly scan failed."
        if vertex_level_aligner.getGroupCount() != 1 then throw "VLevelA Test 8: expected one threshold group."

        level_data = vertex_level_aligner.getLevelData 1 1
        if level_data == undefined then throw "VLevelA Test 8: selected exact level is missing."
        target_z = level_data[1]

        if not(vertex_level_aligner.alignGroupToZ 1 target_z alignment_mode:#here) then throw "VLevelA Test 8: Align HERE backend failed."

        context_data = vertex_level_aligner.resolveContext test_object

        for vertex_id = 1 to vertex_level_aligner.getContextVertexCount context_data do
        (
            world_position = vertex_level_aligner.getWorldVertexPosition context_data vertex_id
            if not(testZNear world_position.z target_z) then throw ("VLevelA Test 8: group vertex did not align HERE: " + (vertex_id as string))
        )
    )

    true
    -- return
)

/*
Verifies threshold grouping chains by adjacent Z gaps rather than by distance from a fixed group anchor.
Four levels whose total span exceeds 2 x threshold must remain one broken group when every neighboring gap is within threshold.
*/
function partOfTest9 =
(
    threshold_value = 10.0
    chain_levels = #(
        #(0.0, #{1,2}),
        #(9.0, #{3,4}),
        #(18.0, #{5,6}),
        #(27.0, #{7,8}),
        #(42.0, #{9,10}))

    groups = vertex_level_aligner.buildThresholdGroups chain_levels threshold:threshold_value

    if groups.count != 2 then throw ("VLevelA Test 9: expected 2 groups from neighbor chaining, got " + (groups.count as string))
    if groups[1][5].count != 4 then throw "VLevelA Test 9: chained group did not keep all four threshold-connected levels."
    if not(groups[1][6]) then throw "VLevelA Test 9: chained multi-level group was not marked broken."
    if not(testZNear groups[1][2] 0.0) or not(testZNear groups[1][3] 27.0) then throw "VLevelA Test 9: chained group min/max Z is wrong."
    if groups[2][5].count != 1 then throw "VLevelA Test 9: level beyond the threshold gap did not start a new group."

    true
    -- return
)

/*
Creates a broken two-level Editable Poly group and verifies Edge mode selects only edges inside each exact level.
Edges connecting vertices across the two Z levels must not be selected by the group row.
*/
function partOfTest10 =
(
    threshold_value = try(units.decodeValue "1mm")catch(1.0)
    level_offset = threshold_value * 0.5
    test_object = undefined

    undo "Vertex Level Aligner Test 10 - Edge Level Selection" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_EDGE_SELECTION"
        convertToPoly test_object
        try(test_object.baseObject.showCage = off)catch()

        upper_bits = #{3,4}
        upper_positions = #()

        for vertex_id in upper_bits do
        (
            vertex_position = polyop.getVert test_object.baseObject vertex_id
            vertex_position.z += level_offset
            append upper_positions vertex_position
        )

        polyop.setVert test_object.baseObject upper_bits upper_positions
        update test_object

        if not(vertex_level_aligner.scanNode test_object threshold:threshold_value) then throw "VLevelA Test 10: Editable Poly scan failed."
        if vertex_level_aligner.getGroupCount() != 1 then throw "VLevelA Test 10: expected one broken threshold group."

        select test_object
        max modify mode
        subObjectLevel = 2

        if not(vertex_level_aligner.selectGroup 1) then throw "VLevelA Test 10: group Edge selection failed."

        selected_edges = polyop.getEdgeSelection test_object.baseObject
        if selected_edges.numberSet != 2 then throw ("VLevelA Test 10: group row should select exactly 2 same-level edges, got " + (selected_edges.numberSet as string))

        if not(vertex_level_aligner.selectLevel 1 1) then throw "VLevelA Test 10: child level Edge selection failed."

        selected_edges = polyop.getEdgeSelection test_object.baseObject
        if selected_edges.numberSet != 1 then throw ("VLevelA Test 10: exact level should select exactly 1 edge, got " + (selected_edges.numberSet as string))
    )

    true
    -- return
)

/*
Creates two threshold groups, hides vertices from both, then selects one group.
Only the selected group's hidden vertices must become visible; unrelated Editable Poly hidden vertices stay hidden.
*/
function partOfTest11 =
(
    threshold_value = try(units.decodeValue "1mm")catch(1.0)
    test_object = undefined

    undo "Vertex Level Aligner Test 11 - Unhide Selected Group" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_UNHIDE_GROUP"
        convertToPoly test_object
        try(test_object.baseObject.showCage = off)catch()

        upper_bits = #{3,4}
        upper_positions = #()

        for vertex_id in upper_bits do
        (
            vertex_position = polyop.getVert test_object.baseObject vertex_id
            vertex_position.z += threshold_value * 20.0
            append upper_positions vertex_position
        )

        polyop.setVert test_object.baseObject upper_bits upper_positions
        update test_object

        if not(vertex_level_aligner.scanNode test_object threshold:threshold_value) then throw "VLevelA Test 11: Editable Poly scan failed."
        if vertex_level_aligner.getGroupCount() != 2 then throw "VLevelA Test 11: expected two separated groups."

        lower_group = vertex_level_aligner.getGroupData 1
        upper_group = vertex_level_aligner.getGroupData 2
        if lower_group == undefined or upper_group == undefined then throw "VLevelA Test 11: group data missing."

        hidden_before = lower_group[4] + upper_group[4]
        polyop.setHiddenVerts test_object.baseObject hidden_before
        update test_object

        select test_object
        max modify mode
        subObjectLevel = 1

        if not(vertex_level_aligner.selectGroup 1) then throw "VLevelA Test 11: group selection failed."

        hidden_after = polyop.getHiddenVerts test_object.baseObject
        if (hidden_after * lower_group[4]).numberSet != 0 then throw "VLevelA Test 11: selected group vertices stayed hidden."
        if (hidden_after * upper_group[4]).numberSet != upper_group[4].numberSet then throw "VLevelA Test 11: unrelated hidden group vertices were unhidden."
    )

    true
    -- return
)

/*
Verifies the dynamic Z Offset unit conversions using the user's large-offset case.
500000 mm must display as 500 m without changing the physical offset.
*/
function partOfTest12 =
(
    offset_mm = vertex_level_aligner_rollout.zOffsetDisplayToMillimeters 500.0 3
    if abs(offset_mm - 500000.0) > 0.0001 then throw "VLevelA Test 12: 500 m did not convert to 500000 mm."

    offset_m = vertex_level_aligner_rollout.zOffsetMillimetersToDisplay 500000.0 3
    if abs(offset_m - 500.0) > 0.0001 then throw "VLevelA Test 12: 500000 mm did not convert to 500 m."

    offset_cm = vertex_level_aligner_rollout.zOffsetMillimetersToDisplay 500000.0 2
    if abs(offset_cm - 50000.0) > 0.0001 then throw "VLevelA Test 12: 500000 mm did not convert to 50000 cm."

    true
    -- return
)

partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()
partOfTest6()
partOfTest7()
partOfTest8()
partOfTest9()
partOfTest10()
partOfTest11()
partOfTest12()

format "\nVERTEX LEVEL ALIGNER PACKAGE TEST PASSED\n"
format "UNDO ORDER: Test 11 Unhide Selected Group -> Test 10 Edge Selection -> Test 8 Align HERE -> Test 5 Edit Poly Align DOWN -> Test 4 Editable Poly Align UP\n"
