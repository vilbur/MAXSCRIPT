/*
Vertex Level Aligner Test 0.175
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
    align_here_index = findString ui_text "menuItem mi_align_here \"Align HERE\""
    align_top_index = findString ui_text "menuItem mi_align_top \"Align TOP\""
    if align_here_index == undefined or align_top_index == undefined or align_here_index > align_top_index then throw "VLevelA Test: Align HERE is not the first RMB alignment action."
    if (findString ui_text "Align MIDDLE") == undefined or (findString ui_text "Align BOTTOM") == undefined then throw "VLevelA Test: alignment RMB menu is incomplete."
    if (findString ui_text "vertex_level_aligner_rollout.alignContextHere()") == undefined then throw "VLevelA Test: Align HERE menu item is not wired to the rollout action."
    if (findString fn_text "function alignGroupToZ group_index target_z alignment_mode:#here") == undefined then throw "VLevelA Test: whole-group explicit-Z alignment backend is missing."
    if (findString ui_text "default:1") == undefined then throw "VLevelA Test: ALL LEVELS is not the default radio mode."
    if (findString fn_text "vertex_level_aligner_default_threshold = 0.0") == undefined then throw "VLevelA Test: zero backend threshold default is missing."
    if (findString ui_text "label lbl_threshold_unit \"mm\"") == undefined then throw "VLevelA Test: millimeter unit label is missing."
    if (findString ui_text "type:#float") == undefined or (findString ui_text "range:[0.0, 1000000.0, 0.0]") == undefined then throw "VLevelA Test: threshold UI is not a 0.0 mm float spinner."
    if (findString ui_text "thresholdMmToSystem") == undefined or (findString ui_text "thresholdSystemToMm") == undefined then throw "VLevelA Test: threshold mm/system conversion helpers are missing."
    if (findString fn_text "function filterSingleVertexLevels") == undefined then throw "VLevelA Test: single-vertex level filter is missing."
    if (findString fn_text "exact_level_tolerance = if threshold_value == 0.0 then 0.0 else exact_epsilon") == undefined then throw "VLevelA Test: zero threshold does not disable exact-level epsilon merging."
    if (findString fn_text "if threshold_limit == 0.0 then") == undefined then throw "VLevelA Test: zero threshold does not use one-group-per-level mode."
    if (findString ui_text "show_broken_only = (rb_view_mode.state == 2) and (vertex_level_aligner.threshold_value > 0.0)") == undefined then throw "VLevelA Test: threshold 0.0 does not force all exact levels visible."
    if (findString fn_text "selected_nodes.count == 0") == undefined then throw "VLevelA Test: scanSelection still rejects multi-object selection instead of using the first object."
    if (findString ui_text "scanSelection threshold:vertex_level_aligner.threshold_value") == undefined then throw "VLevelA Test: rollout open does not scan the first selected object."
    if (findString ui_text "if group_data[6] then") == undefined then throw "VLevelA Test: unbroken groups still create redundant child rows."
    if (findString ui_text "separator sep_tree_actions") == undefined then throw "VLevelA Test: TreeView context-menu separator is missing."
    if (findString ui_text "Collapse All") == undefined or (findString ui_text "Expand All") == undefined then throw "VLevelA Test: TreeView Collapse/Expand All context actions are missing."
    if (findString fn_text "copy exact_levels") != undefined then throw "VLevelA Test: mapped copy() regression returned to group data."
    if (findString ui_text "rollout vertex_level_aligner_rollout \"Vertex Level Aligner 0.786\"") == undefined then throw "VLevelA Test: literal static rollout title is missing."
    if (findString fn_text "rollout ") != undefined then throw "VLevelA Test: FN must not define rollouts."
    if (findString fn_text "createDialog") != undefined then throw "VLevelA Test: FN must not create dialogs."
    if (findString fn_text "global vertexLevelAlignerWriteLog") == undefined then throw "VLevelA Test: FN logger must be explicitly global."
    if (findString fn_text "global vertexLevelAlignerStartLog") == undefined then throw "VLevelA Test: FN log initializer must be explicitly global."
    if (findString fn_text "this.scanNode selected_nodes[1]") == undefined then throw "VLevelA Test: scanSelection must dispatch scanNode through this."
    if (findString fn_text "qsort sample_values this.compareVertexSamples") == undefined then throw "VLevelA Test: qsort comparator must dispatch through this."

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

    if vertex_level_aligner_rollout.title != "Vertex Level Aligner 0.786" then throw ("VLevelA Test: unexpected rollout title: " + vertex_level_aligner_rollout.title)
    if try(vertex_level_aligner_rollout.spn_threshold)catch(undefined) == undefined then throw "VLevelA Test: threshold spinner missing."
    if try(vertex_level_aligner_rollout.btn_scan)catch(undefined) == undefined then throw "VLevelA Test: SCAN OBJECT button missing."
    if try(vertex_level_aligner_rollout.rb_view_mode)catch(undefined) == undefined then throw "VLevelA Test: view-mode radios missing."
    if try(vertex_level_aligner_rollout.tv_levels)catch(undefined) == undefined then throw "VLevelA Test: TreeView missing."
    if try(vertex_level_aligner_rollout.btn_restart)catch(undefined) == undefined then throw "VLevelA Test: RESTART button missing."

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
Creates an Editable Poly with two nearby Z levels, scans it, aligns the group TOP, and verifies every group vertex.
*/
function partOfTest4 =
(
    threshold_value = try(units.decodeValue "1mm")catch(1.0)
    level_offset = threshold_value * 0.5
    test_object = undefined

    undo "Vertex Level Aligner Test 4 - Editable Poly Align TOP" on
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

        if not(vertex_level_aligner.alignGroup 1 #top) then throw "VLevelA Test 4: TOP alignment failed."

        context_data = vertex_level_aligner.resolveContext test_object

        for vertex_id = 1 to vertex_level_aligner.getContextVertexCount context_data do
        (
            world_position = vertex_level_aligner.getWorldVertexPosition context_data vertex_id
            if not(testZNear world_position.z target_z) then throw ("VLevelA Test 4: vertex did not align TOP: " + (vertex_id as string))
        )
    )

    true
    -- return
)

/*
Creates an Edit Poly context with two nearby Z levels, aligns the group BOTTOM, and verifies every modifier vertex.
*/
function partOfTest5 =
(
    threshold_value = try(units.decodeValue "1mm")catch(1.0)
    level_offset = threshold_value * 0.5
    test_object = undefined
    test_modifier = undefined

    undo "Vertex Level Aligner Test 5 - Edit Poly Align BOTTOM" on
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

        if not(vertex_level_aligner.alignGroup 1 #bottom) then throw "VLevelA Test 5: BOTTOM alignment failed."

        context_data = vertex_level_aligner.resolveContext test_object modifier_value:test_modifier

        for vertex_id = 1 to vertex_level_aligner.getContextVertexCount context_data do
        (
            world_position = vertex_level_aligner.getWorldVertexPosition context_data vertex_id
            if not(testZNear world_position.z target_z) then throw ("VLevelA Test 5: vertex did not align BOTTOM: " + (vertex_id as string))
        )
    )

    true
    -- return
)

/*
Verifies single-vertex exact levels are removed before threshold grouping.
*/
function partOfTest6 =
(
    single_bits = #{1}
    pair_bits = #{2,3}
    filtered_levels = vertex_level_aligner.filterSingleVertexLevels #(
        #(0.0, single_bits),
        #(1.0, pair_bits))

    if filtered_levels.count != 1 then throw "VLevelA Test 6: singleton exact level was not ignored."
    if filtered_levels[1][2].numberSet != 2 then throw "VLevelA Test 6: retained exact level vertex data changed."

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

partOfTest1()
partOfTest2()
partOfTest3()
partOfTest4()
partOfTest5()
partOfTest6()
partOfTest7()
partOfTest8()

format "\nVERTEX LEVEL ALIGNER PACKAGE TEST PASSED\n"
format "UNDO ORDER: Test 8 Align HERE -> Test 5 Edit Poly Align BOTTOM -> Test 4 Editable Poly Align TOP\n"
