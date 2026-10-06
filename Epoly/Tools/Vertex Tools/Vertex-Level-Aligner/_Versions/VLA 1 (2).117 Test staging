/*
Vertex Level Aligner Test 0.249
Package architecture regression for main / UI / FN separation.
*/

global EPOLY_TOOLS_RUNTIME_MODE
global vertex_level_aligner
global vertex_level_aligner_ui
global vertex_level_aligner_rollout
global vertex_level_aligner_main_version
global vertex_level_aligner_test_project_version

vertex_level_aligner_test_project_version = 1.117

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

    try
    (
        EPOLY_TOOLS_RUNTIME_MODE = #library
        fileIn main_path quiet:true
    )
    catch
    (
        package_load_exception = getCurrentException()
        EPOLY_TOOLS_RUNTIME_MODE = previous_runtime_mode
        throw
    )

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
/*
Reads one property for regression probes without using a silent compact catch.
Missing controls return undefined so callers can assert the expected UI surface.
*/
function getTestPropertyValue target_value property_name =
(
    property_value = undefined

    try
    (
        property_value = getProperty target_value property_name
    )
    catch
    (
        property_exception = getCurrentException()
        property_value = undefined
    )

    property_value
    -- return
)

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
    if (findString ui_text "dropdownlist ddl_face_material_id") == undefined or (findString ui_text "button btn_apply_face_material_id \"SET POLY MAT ID\"") == undefined then throw "VLevelA Test: polygon Material ID controls are missing."
    if (findString fn_text "function getFullySelectedFacesFromVertexBits") == undefined or (findString fn_text "function applyMaterialIdToTargets") == undefined then throw "VLevelA Test: polygon Material ID backend is missing."
    if (findString fn_text "function synchronizeEditablePolyTopology context_data") == undefined then throw "VLevelA Test: Editable Poly dead-topology synchronization helper is missing."
    if (findString fn_text "polyop.getHasDeadStructs topology_value") == undefined or (findString fn_text "polyop.collapseDeadStructs topology_value") == undefined then throw "VLevelA Test: Editable Poly dead-topology synchronization does not use the required PolyOp APIs."
    if (findString fn_text "function invalidateStoredTopologyCache") == undefined or (findString fn_text "topology_compaction_serial") == undefined then throw "VLevelA Test: topology cache invalidation state is missing."
    if (findString fn_text "if context_kind != #editable_poly then return #not_applicable") == undefined then throw "VLevelA Test: dead-topology collapse is not restricted to Editable Poly contexts."
    if (findString fn_text "function getGroupData group_index context_validated:false") == undefined or (findString fn_text "function getLevelData group_index level_index context_validated:false") == undefined then throw "VLevelA Test: cached group/level access is not topology-validated."
    if (findString ui_text "function debugSelectedTreePositions") == undefined or (findString ui_text "ITEM DISPLAY ") == undefined or (findString ui_text "getWorldVertexPosition context_data vertex_id") == undefined or (findString ui_text "AVERAGE - ITEM STORED DELTA") == undefined then throw "VLevelA Test: selected-item world/display position diagnostic is missing."
    if (findString ui_text "on tv_levels BeforeSelect sender event_args do") == undefined or (findString ui_text "if not(is_context_tree_selection) and isTreeControlModifierDown() then") == undefined or (findString ui_text "event_args.Cancel = true") == undefined then throw "VLevelA Test: direct CTRL native TreeView selection cancellation is missing."
    align_to_index = findString ui_text "menuItem mi_align_here \"Align to Axis\""
    align_up_index = findString ui_text "menuItem mi_align_up \"Align UP\""
    align_middle_index = findString ui_text "menuItem mi_align_middle \"Align MIDDLE\""
    align_down_index = findString ui_text "menuItem mi_align_down \"Align DOWN\""
    if align_to_index == undefined or align_up_index == undefined or align_middle_index == undefined or align_down_index == undefined or align_to_index > align_up_index or align_up_index > align_middle_index or align_middle_index > align_down_index then throw "VLevelA Test: native Align TO / UP / MIDDLE / DOWN RMB order is wrong."
    if (findString ui_text "Align MOST") != undefined then throw "VLevelA Test: removed Align MOST action returned."
    if (findString ui_text "function getContextTargetAxisValue") == undefined then throw "VLevelA Test: RMB selected-axis target resolver is missing."
    if (findString ui_text "function updateAlignToMenuText") == undefined then throw "VLevelA Test: dynamic Align-to-axis menu updater is missing."
    if (findString ui_text "mi_align_here.text = \"Align \" + (getSelectedWorldAxisText()) + \" to \" + formatWorldPositionValue target_axis_value") == undefined then throw "VLevelA Test: RMB action does not display the clicked selected-axis position."
    if (findString ui_text "Align MIDDLE") == undefined then throw "VLevelA Test: stable Align MIDDLE action is missing."
    if (findString ui_text "Align DOWN") == undefined then throw "VLevelA Test: Align DOWN action is missing."
    if (findString ui_text "vertex_level_aligner_rollout.alignContextHere()") == undefined then throw "VLevelA Test: Align-to-axis menu item is not wired to the rollout action."
    if (findString ui_text "menuItem mi_align_up \"Align UP\"") == undefined or (findString ui_text "menuItem mi_align_down \"Align DOWN\"") == undefined then throw "VLevelA Test: UP/DOWN RMB labels are missing."
    if (findString ui_text "Align TOP") != undefined or (findString ui_text "Align BOTTOM") != undefined then throw "VLevelA Test: legacy TOP/BOTTOM RMB labels remain."
    if (findString fn_text "#top: \"UP\"") == undefined or (findString fn_text "#bottom: \"DOWN\"") == undefined then throw "VLevelA Test: backend status labels are not UP/DOWN."
    if (findString ui_text "group_index = group_count - group_offset + 1") == undefined then throw "VLevelA Test: TreeView groups are not displayed highest selected-axis value first."
    if (findString ui_text "level_index = exact_levels.count - level_offset + 1") == undefined then throw "VLevelA Test: broken-group child levels are not displayed highest selected-axis value first."
    if (findString fn_text "function alignGroupToAxisValue group_index target_axis_value alignment_mode:#here") == undefined then throw "VLevelA Test: whole-group explicit selected-axis alignment backend is missing."
    if (findString fn_text "function getLiveVertexBitsAxisValue vertex_bits") == undefined then throw "VLevelA Test: live current-item vertex-position resolver is missing."
    if (findString fn_text "in coordsys world") == undefined or (findString fn_text "node:scan_node") == undefined then throw "VLevelA Test: Editable Poly alignment is not using native world-coordinate PolyOp context."
    if (findString ui_text "vertex_level_aligner.getLiveVertexBitsAxisValue target_bits") == undefined then throw "VLevelA Test: Align TO target is not read from the current item's live vertices."
    if (findString fn_text "write_ok = this.setEditablePolyVertexBitsToWorldAxisValue group_bits target_axis_value") == undefined then throw "VLevelA Test: Editable Poly Align TO does not set the complete group directly."
    if (findString fn_text "polyop.setVert topology_value vertex_bits world_positions node:scan_node") == undefined then throw "VLevelA Test: Editable Poly direct world-coordinate group writer is missing."
    if (findString fn_text "this.scanNode target_node modifier_value:target_modifier threshold:target_threshold world_axis_value:target_world_axis") == undefined then throw "VLevelA Test: Align TO does not rescan the object after setting group positions."
    if (findString ui_text "vertex_level_aligner.flattenGroupToAxisValue group_index target_axis_value alignment_mode:#here") == undefined then throw "VLevelA Test: UI Align TO does not call the group flatten path."
    if (findString ui_text "default:1") == undefined then throw "VLevelA Test: ALL LEVELS is not the default radio mode."
    if (findString fn_text "vertex_level_aligner_default_threshold = 0.0") == undefined then throw "VLevelA Test: zero backend threshold default is missing."
    if (findString ui_text "type:#float") == undefined or (findString ui_text "range:[0.0, 1000000.0, 0.0]") == undefined then throw "VLevelA Test: threshold UI is not a 0.0 mm float spinner."
    if (findString ui_text "thresholdMmToSystem") == undefined or (findString ui_text "thresholdSystemToMm") == undefined then throw "VLevelA Test: threshold mm/system conversion helpers are missing."
    if (findString ui_text "function scanCurrentThreshold") == undefined then throw "VLevelA Test: shared threshold scan helper is missing."
    if (findString ui_text "on spn_threshold changed value do") == undefined or (findString ui_text "scanCurrentThreshold()") == undefined then throw "VLevelA Test: threshold change does not trigger an immediate scan."
    if (findString ui_text "button btn_scan \"SCAN OBJECT\" pos:[8,3] width:148 height:32") == undefined then throw "VLevelA Test: SCAN OBJECT is not half-width on row 1."
    if (findString ui_text "checkbutton cb_axis_x \"X\"") == undefined or (findString ui_text "checkbutton cb_axis_y \"Y\"") == undefined or (findString ui_text "checkbutton cb_axis_z \"Z\"") == undefined then throw "VLevelA Test: XYZ world-axis checkbuttons are missing."
    if (findString ui_text "function setWorldAxisControls") == undefined then throw "VLevelA Test: mandatory one-of-three axis controller is missing."
    if (findString ui_text "on cb_axis_x changed state do") == undefined or (findString ui_text "on cb_axis_y changed state do") == undefined or (findString ui_text "on cb_axis_z changed state do") == undefined or (findString ui_text "scanCurrentThreshold()") == undefined then throw "VLevelA Test: world-axis checkbutton change does not trigger a rescan."
    if (findString ui_text "\"WorldAxis\"") == undefined then throw "VLevelA Test: selected world axis is not persisted."
    if (findString ui_text "rollout vertex_level_aligner_rollout \"Vertex Level Aligner 1.117\" width:320 height:576") == undefined then throw "VLevelA Test: rollout width is not fixed at 320 px."
    if (findString ui_text "spinner spn_threshold \"Threshold:\" pos:[8,43] width:120") == undefined or (findString ui_text "align:#left") == undefined then throw "VLevelA Test: Threshold spinner is not left-aligned on row 2."
    if (findString ui_text "Threshold groups levels only; it does not move vertices.") == undefined or (findString ui_text "Units: millimeters.") == undefined then throw "VLevelA Test: Threshold tooltip does not clearly explain grouping and physical units."
    if (findString ui_text "label lbl_display_trim \"Remove:\" pos:[224,44] width:40") == undefined or (findString ui_text "dropdownlist ddl_display_trim \"\" pos:[264,41] width:48") == undefined then throw "VLevelA Test: Remove dropdown is not 48 px wide like the XYZ buttons."
    if (findString ui_text "radiobuttons rb_view_mode") == undefined or (findString ui_text "pos:[8,69] width:184 height:28 align:#left") == undefined then throw "VLevelA Test: view-mode radios do not leave room for the Expand/Collapse button."
    if (findString ui_text "button btn_expand_collapse") == undefined then throw "VLevelA Test: Expand/Collapse button is missing."
    if (findString ui_text "function expandSelectedOrAllLevels") == undefined or (findString ui_text "on btn_expand_collapse pressed do") == undefined then throw "VLevelA Test: Expand button path is not wired."
    if (findString ui_text "function collapseSelectedOrAllLevels") == undefined or (findString ui_text "on btn_expand_collapse rightClick do") == undefined then throw "VLevelA Test: Collapse button path is not wired."
    if (findString ui_text "tree_font.FontFamily tree_font.Size tree_font.Style") == undefined or (findString ui_text "tree_font.Size + 0.75") != undefined then throw "VLevelA Test: TreeView item font was not reduced by another 1 px."
    if (findString ui_text "dialog_width = 320") == undefined or (findString ui_text "lockWidth:true lockHeight:false") == undefined then throw "VLevelA Test: standalone dialog width is not locked at 320 px."
    if (findString ui_text "getIniInteger \"Width\"") != undefined then throw "VLevelA Test: obsolete persisted dialog width is still being read."
    scan_control_index = findString ui_text "button btn_scan \"SCAN OBJECT\""
    threshold_control_index = findString ui_text "spinner spn_threshold \"Threshold:\""
    if scan_control_index == undefined or threshold_control_index == undefined or scan_control_index > threshold_control_index then throw "VLevelA Test: SCAN OBJECT is not declared before the threshold control."
    if (findString ui_text "function updateGroupExpansionIndicator") == undefined then throw "VLevelA Test: explicit group expansion indicator helper is missing."
    if (findString ui_text "function getLargestLevelVertexCount") == undefined then throw "VLevelA Test: largest-level vertex-count helper is missing."
    if (findString ui_text "level_text += \"  [MOST]\"") == undefined then throw "VLevelA Test: dominant level text marker is missing."
    if (findString ui_text "level_node.NodeFont = if is_largest_level then level_bold_font else level_regular_font") == undefined then throw "VLevelA Test: dominant level bold highlight is missing."
    if (findString ui_text "on tv_levels AfterExpand") == undefined or (findString ui_text "on tv_levels AfterCollapse") == undefined then throw "VLevelA Test: group +/- indicator is not wired to TreeView expansion events."
    if (findString ui_text "\"- \" + getGroupText group_index group_data") == undefined then throw "VLevelA Test: initially expanded groups do not show the '-' indicator."
    if (findString fn_text "function filterSingleVertexLevels") == undefined then throw "VLevelA Test: compatibility level-retention helper is missing."
    if (findString fn_text "working_spinner_precision = preferences.spinnerPrecision") == undefined then throw "VLevelA Test: production scan does not use 3ds Max spinner precision."
    if (findString fn_text "function buildSpinnerPrecisionLevels sample_values spinner_precision") == undefined then throw "VLevelA Test: spinner-precision level builder is missing."
    if (findString fn_text "exact_levels = this.buildSpinnerPrecisionLevels sample_values working_spinner_precision") == undefined then throw "VLevelA Test: scanner does not retain the complete spinner-precision level list."
    if (findString fn_text "exact_levels = this.filterSingleVertexLevels all_exact_levels") != undefined then throw "VLevelA Test: scanner still drops singleton exact levels before threshold grouping."
    if (findString fn_text "if threshold_limit == 0.0 then") == undefined then throw "VLevelA Test: zero threshold does not use one-group-per-level mode."
    if (findString fn_text "maximum_span = threshold_limit * 2.0") != undefined then throw "VLevelA Test: legacy total-span threshold grouping is still present."
    if (findString fn_text "(level_axis - previous_axis) <= (threshold_limit + exact_epsilon)") == undefined then throw "VLevelA Test: neighboring-gap threshold chaining is missing."
    if (findString ui_text "show_broken_only = (rb_view_mode.state == 2) and (vertex_level_aligner.threshold_value > 0.0)") == undefined then throw "VLevelA Test: threshold 0.0 does not force all exact levels visible."
    if (findString fn_text "selected_nodes.count == 0") == undefined then throw "VLevelA Test: scanSelection still rejects multi-object selection instead of using the first object."
    if (findString ui_text "scanSelection threshold:vertex_level_aligner.threshold_value") == undefined then throw "VLevelA Test: rollout open does not scan the first selected object."
    if (findString ui_text "if group_data[6] then") == undefined then throw "VLevelA Test: unbroken groups still create redundant child rows."
    if (findString ui_text "separator sep_align_most") != undefined or (findString ui_text "separator sep_align_here") == undefined or (findString ui_text "separator sep_round_actions") == undefined or (findString ui_text "separator sep_tree_actions") == undefined then throw "VLevelA Test: stable RMB menu sections are wrong."
    if (findString ui_text "menuItem mi_round_up \"Round to next\"") == undefined or (findString ui_text "menuItem mi_round_down \"Round to previous\"") == undefined then throw "VLevelA Test: Round UP/DOWN RMB actions are missing."
    if (findString ui_text "roundContextTarget #up") == undefined or (findString ui_text "roundContextTarget #down") == undefined then throw "VLevelA Test: Round UP/DOWN menu callbacks are not wired."
    if (findString ui_text "Collapse All") == undefined or (findString ui_text "Expand All") == undefined then throw "VLevelA Test: TreeView Collapse/Expand All context actions are missing."
    if (findString fn_text "copy exact_levels") != undefined then throw "VLevelA Test: mapped copy() regression returned to group data."
    if (findString ui_text "rollout vertex_level_aligner_rollout \"Vertex Level Aligner 1.117\"") == undefined then throw "VLevelA Test: literal static rollout title is missing."
    if (findString fn_text "rollout ") != undefined then throw "VLevelA Test: FN must not define rollouts."
    if (findString fn_text "createDialog") != undefined then throw "VLevelA Test: FN must not create dialogs."
    if (findString fn_text "global vertexLevelAlignerWriteLog") == undefined then throw "VLevelA Test: FN logger must be explicitly global."
    if (findString fn_text "global vertexLevelAlignerStartLog") == undefined then throw "VLevelA Test: FN log initializer must be explicitly global."
    if (findString fn_text "this.scanNode selected_nodes[1]") == undefined then throw "VLevelA Test: scanSelection must dispatch scanNode through this."
    if (findString fn_text "qsort sample_values this.compareVertexSamples") == undefined then throw "VLevelA Test: qsort comparator must dispatch through this."
    if (findString fn_text "polyop.getVert topology_value vertex_id node:node_value") == undefined then throw "VLevelA Test: Editable Poly world positions do not use native PolyOp node context."
    if (findString fn_text "world_axis = #z") == undefined then throw "VLevelA Test: backend default world axis is not Z."
    if (findString fn_text "function getWorldAxisValue") == undefined or (findString fn_text "function getWorldAxisDeltaVector") == undefined then throw "VLevelA Test: generic XYZ world-axis helpers are missing."
    if (findString fn_text "function moveVertexBitsByWorldAxisDelta") == undefined then throw "VLevelA Test: generic world-axis movement dispatcher is missing."
    if (findString fn_text "function moveVertexBitsToAxisValue") == undefined or (findString fn_text "function moveGroupToAxisValue") == undefined or (findString fn_text "function moveLevelToAxisValue") == undefined then throw "VLevelA Test: selected-item axis move helpers are missing."
    if (findString fn_text "function roundAxisValueToFiveMillimeters") == undefined or (findString fn_text "function roundGroupToFiveMillimeters") == undefined or (findString fn_text "function roundLevelToFiveMillimeters") == undefined then throw "VLevelA Test: backend 5 mm rounding helpers are missing."
    if (findString ui_text "function roundContextTarget") == undefined then throw "VLevelA Test: RMB round wrapper is missing."
    if (findString fn_text "world_axis_value:world_axis_value") == undefined then throw "VLevelA Test: scan pipeline does not propagate the selected world axis."
    if (findString fn_text "inverse scan_node.objectTransform") == undefined then throw "VLevelA Test: Editable Poly world-axis alignment does not use objectTransform."
    if (findString fn_text "function getEdgesBetweenVertexBits") == undefined then throw "VLevelA Test: level edge resolver is missing."
    if (findString fn_text "function unhideVertexBits") == undefined then throw "VLevelA Test: TreeView selection vertex-unhide helper is missing."
    if (findString fn_text "polyop.getHiddenVerts topology_value") == undefined or (findString fn_text "polyop.unHideAllVerts topology_value") == undefined then throw "VLevelA Test: Editable Poly target-vertex unhide path is missing."
    if (findString fn_text "modifier_value.ButtonOp #UnhideAllVertex") == undefined then throw "VLevelA Test: Edit Poly vertex-unhide operation is missing."
    if (findString fn_text "this.unhideVertexBits group_data[4]") == undefined or (findString fn_text "this.unhideVertexBits level_data[2]") == undefined then throw "VLevelA Test: group/level selection does not unhide its vertices first."
    if (findString fn_text "current_subobject_level == 2") == undefined then throw "VLevelA Test: Tree selection does not honor Edge sub-object level."
    if (findString fn_text "polyop.setEdgeSelection topology_value edge_bits") == undefined then throw "VLevelA Test: Editable Poly edge writer is missing."
    if (findString fn_text "modifier_value.Select #Edge edge_bits select:true") == undefined then throw "VLevelA Test: Edit Poly edge writer is missing."
    if (findString ui_text "spinner spn_z_offset") != undefined or (findString ui_text "dropdownlist ddl_z_offset_unit") != undefined then throw "VLevelA Test: obsolete numeric Axis Offset controls remain."
    if (findString ui_text "dropdownlist ddl_display_trim") == undefined or (findString ui_text "items:#(\"\", \"1\", \"2\", \"3\", \"4\", \"5\", \"6\", \"7\", \"8\", \"9\", \"10\")") == undefined then throw "VLevelA Test: display trim dropdown is missing or incomplete."
    if (findString ui_text "\"DisplayTrimXDigits\"") == undefined or (findString ui_text "\"DisplayTrimYDigits\"") == undefined or (findString ui_text "\"DisplayTrimZDigits\"") == undefined then throw "VLevelA Test: independent X/Y/Z display trim storage is missing."
    if (findString ui_text "function switchWorldAxis") == undefined or (findString ui_text "loadAxisDisplayTrimDropdown axis_index") == undefined then throw "VLevelA Test: axis switching does not swap the per-axis display trim dropdown."
    if (findString ui_text "function trimLeadingIntegerDigits") == undefined then throw "VLevelA Test: display-only leading-digit trim helper is missing."
    if (findString ui_text "offset_axis_value = 0.0") == undefined then throw "VLevelA Test: UI rounding still depends on the removed numeric Axis Offset."
    scan_helper_index = findString ui_text "function scanCurrentThreshold"
    switch_axis_index = findString ui_text "function switchWorldAxis"
    if scan_helper_index == undefined or switch_axis_index == undefined or switch_axis_index < scan_helper_index then throw "VLevelA Test: switchWorldAxis is defined before scanCurrentThreshold and can hit an undefined forward reference."
    if (findString ui_text "switchWorldAxis 1") == undefined or (findString ui_text "switchWorldAxis 2") == undefined or (findString ui_text "switchWorldAxis 3") == undefined then throw "VLevelA Test: XYZ checkbuttons are not wired to per-axis display trim switching."
    if (findString ui_text "on ddl_display_trim selected trim_selection do") == undefined then throw "VLevelA Test: display trim dropdown event is missing."
    if (findString ui_text "formatWorldPositionValue") == undefined then throw "VLevelA Test: world-axis display trim formatter is missing."
    if (findString ui_text "function addThousandsSeparators") == undefined or (findString ui_text "addThousandsSeparators formatted_value") == undefined then throw "VLevelA Test: TreeView thousands-separator formatting is missing."
    if (findString ui_text "local selected_tree_tags = #()") == undefined then throw "VLevelA Test: CTRL+LMB TreeView selection storage is missing."
    if (findString ui_text "function selectTreeNode node_value") == undefined or (findString ui_text "function selectTreeNodeExclusive node_value") == undefined then throw "VLevelA Test: stable plain-LMB single-node selection path is missing."
    if (findString ui_text "on tv_levels AfterSelect sender event_args do") == undefined or (findString ui_text "selectTreeNodeExclusive event_args.Node") == undefined then throw "VLevelA Test: native TreeView AfterSelect no longer owns plain LMB."
    if (findString ui_text "function isTreeControlModifierDown") == undefined or (findString ui_text "toggleTreeNodeSelection node_value") == undefined then throw "VLevelA Test: CTRL+LMB toggle path is missing."
    if (findString ui_text "vertex_level_aligner.selectTargetsFast selected_targets") == undefined then throw "VLevelA Test: CTRL+LMB selection union is not sent through the fast selection path."
    if (findString fn_text "function selectTargetsFast target_data_array") == undefined or (findString fn_text "function selectVertexBitsFast vertex_bits context_validated:false") == undefined or (findString fn_text "function selectEdgeBitsFast edge_bits context_validated:false") == undefined then throw "VLevelA Test: fast CTRL selection backend is missing."
    if (findString fn_text "if current_subobject_level != 1 then return this.selectVertexBits vertex_bits") == undefined or (findString fn_text "if current_subobject_level != 2 then return this.selectEdgeBits edge_bits") == undefined then throw "VLevelA Test: fast selection does not preserve an already-correct subObjectLevel."
    if (findString fn_text "if not(this.isStoredModifyContextActive()) then return this.selectVertexBits vertex_bits") == undefined or (findString fn_text "if not(this.isStoredModifyContextActive()) then return this.selectEdgeBits edge_bits") == undefined then throw "VLevelA Test: fast selection does not fall back only when Modify-panel activation is actually needed."
    if (findString fn_text "context_validated:true") == undefined then throw "VLevelA Test: fast multi-target selection repeats the full topology validation inside its writer."
    if (findString ui_text "is_ctrl_tree_selection = true\n                    toggleTreeNodeSelection node_value") == undefined or (findString ui_text "tv_levels.SelectedNode = undefined") != undefined then throw "VLevelA Test: CTRL+LMB still mutates native SelectedNode instead of preserving the prior native selection."
    if (findString ui_text "on tv_levels MouseUp sender event_args do") == undefined or (findString ui_text "is_ctrl_tree_selection = false") == undefined then throw "VLevelA Test: CTRL+LMB guard is not released on MouseUp."
    if (findString ui_text "event_args.Button == mouse_buttons.Left") == undefined or (findString ui_text "isTreeControlModifierDown()") == undefined then throw "VLevelA Test: TreeView MouseDown does not restrict custom selection handling to CTRL+LMB."
    if (findString ui_text "event_args.Button == mouse_buttons.Right") == undefined or (findString ui_text "is_context_tree_selection = true") == undefined then throw "VLevelA Test: RMB context targeting does not preserve custom multi-selection."
    if (findString ui_text "function alignSelectedGroupsToMost") != undefined or (findString ui_text "vertex_level_aligner.alignGroupsToMost") != undefined then throw "VLevelA Test: Align MOST UI wiring returned."
    if (findString ui_text "try(tv_levels.CollapseAll())catch()") != undefined or (findString ui_text "root_node.Collapse()") == undefined then throw "VLevelA Test: explicit group collapse path is missing."

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

    if vertex_level_aligner_rollout.title != "Vertex Level Aligner 1.117" then throw ("VLevelA Test: unexpected rollout title: " + vertex_level_aligner_rollout.title)
    if getTestPropertyValue vertex_level_aligner_rollout #cb_axis_x == undefined or getTestPropertyValue vertex_level_aligner_rollout #cb_axis_y == undefined or getTestPropertyValue vertex_level_aligner_rollout #cb_axis_z == undefined then throw "VLevelA Test: XYZ world-axis checkbuttons missing."
    if getTestPropertyValue vertex_level_aligner_rollout #spn_threshold == undefined then throw "VLevelA Test: threshold spinner missing."
    if getTestPropertyValue vertex_level_aligner_rollout #btn_scan == undefined then throw "VLevelA Test: SCAN OBJECT button missing."
    if getTestPropertyValue vertex_level_aligner_rollout #rb_view_mode == undefined then throw "VLevelA Test: view-mode radios missing."
    if getTestPropertyValue vertex_level_aligner_rollout #btn_expand_collapse == undefined then throw "VLevelA Test: Expand/Collapse button missing."
    if getTestPropertyValue vertex_level_aligner_rollout #ddl_face_material_id == undefined or getTestPropertyValue vertex_level_aligner_rollout #btn_apply_face_material_id == undefined then throw "VLevelA Test: polygon Material ID controls missing."
    if getTestPropertyValue vertex_level_aligner_rollout #tv_levels == undefined then throw "VLevelA Test: TreeView missing."
    if getTestPropertyValue vertex_level_aligner_rollout #btn_restart == undefined then throw "VLevelA Test: RESTART button missing."

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
    threshold_value = units.decodeValue "1mm"
    level_offset = threshold_value * 0.5
    test_object = undefined

    undo "Vertex Level Aligner Test 4 - Editable Poly Align UP" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_EDITABLE"
        convertToPoly test_object

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
    threshold_value = units.decodeValue "1mm"
    level_offset = threshold_value * 0.5
    test_object = undefined
    test_modifier = undefined

    undo "Vertex Level Aligner Test 5 - Edit Poly Align DOWN" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_EDITPOLY"
        convertToPoly test_object

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
Verifies threshold 0.0 still preserves meaningful distinct Z values while allowing only a few Point3 ULPs of transform noise.
Each valid exact level becomes its own unbroken group.
*/
function partOfTest7 =
(
    tiny_offset = (vertex_level_aligner.getAxisPrecisionTolerance 1.0 1.0) * 2.0
    sample_values = #(
        #(1.0, 1),
        #(1.0, 2),
        #(1.0 + tiny_offset, 3),
        #(1.0 + tiny_offset, 4))

    exact_levels = vertex_level_aligner.buildExactLevels sample_values tolerance:0.0
    filtered_levels = vertex_level_aligner.filterSingleVertexLevels exact_levels
    zero_groups = vertex_level_aligner.buildThresholdGroups filtered_levels threshold:0.0

    if exact_levels.count != 2 then throw "VLevelA Test 7: threshold-zero exact-level construction merged values beyond the Point3 precision allowance."
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
    threshold_value = units.decodeValue "1mm"
    level_offset = threshold_value * 0.5
    test_object = undefined

    undo "Vertex Level Aligner Test 8 - Align HERE" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_ALIGN_HERE"
        convertToPoly test_object

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
    threshold_value = units.decodeValue "1mm"
    level_offset = threshold_value * 0.5
    test_object = undefined

    undo "Vertex Level Aligner Test 10 - Edge Level Selection" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_EDGE_SELECTION"
        convertToPoly test_object

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
    threshold_value = units.decodeValue "1mm"
    test_object = undefined

    undo "Vertex Level Aligner Test 11 - Unhide Selected Group" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_UNHIDE_GROUP"
        convertToPoly test_object

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
Verifies per-axis TreeView display-trim persistence and leading-digit shortening.
Real coordinate data is not passed into this helper by reference and remains unchanged.
*/
function partOfTest12 =
(
    if vertex_level_aligner_rollout.getAxisDisplayTrimIniKey 1 != "DisplayTrimXDigits" then throw "VLevelA Test 12: X display trim key mapping failed."
    if vertex_level_aligner_rollout.getAxisDisplayTrimIniKey 2 != "DisplayTrimYDigits" then throw "VLevelA Test 12: Y display trim key mapping failed."
    if vertex_level_aligner_rollout.getAxisDisplayTrimIniKey 3 != "DisplayTrimZDigits" then throw "VLevelA Test 12: Z display trim key mapping failed."

    if vertex_level_aligner_rollout.trimLeadingIntegerDigits "1,234,567.89" 0 != "1,234,567.89" then throw "VLevelA Test 12: blank display trim changed the full coordinate."
    if vertex_level_aligner_rollout.trimLeadingIntegerDigits "1,234,567.89" 1 != "234,567.89" then throw "VLevelA Test 12: remove-1 display trim failed."
    if vertex_level_aligner_rollout.trimLeadingIntegerDigits "1,234,567.89" 4 != "567.89" then throw "VLevelA Test 12: remove-4 display trim failed."
    if vertex_level_aligner_rollout.trimLeadingIntegerDigits "1,234,567.89" 6 != "7.89" then throw "VLevelA Test 12: leading-digit trim did not preserve the final integer digit."
    if vertex_level_aligner_rollout.trimLeadingIntegerDigits "-1,234,567.89" 4 != "-567.89" then throw "VLevelA Test 12: negative display trim failed."

    true
    -- return
)

/*
Verifies X/Y/Z helper values and real Editable Poly movement along selected world X and Y axes on a rotated node.
*/
function partOfTest13 =
(
    if (vertex_level_aligner.getWorldAxisValue [10,20,30] world_axis_value:#x) != 10 then throw "VLevelA Test 13: X axis value helper failed."
    if (vertex_level_aligner.getWorldAxisValue [10,20,30] world_axis_value:#y) != 20 then throw "VLevelA Test 13: Y axis value helper failed."
    if (vertex_level_aligner.getWorldAxisValue [10,20,30] world_axis_value:#z) != 30 then throw "VLevelA Test 13: Z axis value helper failed."

    x_delta = vertex_level_aligner.getWorldAxisDeltaVector 25.0 world_axis_value:#x
    y_delta = vertex_level_aligner.getWorldAxisDeltaVector 25.0 world_axis_value:#y
    if x_delta != [25,0,0] then throw "VLevelA Test 13: X delta vector helper failed."
    if y_delta != [0,25,0] then throw "VLevelA Test 13: Y delta vector helper failed."

    test_object = undefined

    undo "Vertex Level Aligner Test 13 - XYZ World Axis" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_XYZ_AXIS"
        test_object.rotation = angleaxis 31 [0,0,1]
        convertToPoly test_object

        if not(vertex_level_aligner.scanNode test_object threshold:0.0 world_axis_value:#x) then throw "VLevelA Test 13: X-axis Editable Poly scan failed."
        context_data = vertex_level_aligner.resolveContext test_object
        before_x = vertex_level_aligner.getWorldVertexPosition context_data 1

        if not(vertex_level_aligner.moveEditablePolyVertexBitsByWorldAxisDelta #{1} 25.0 world_axis_value:#x) then throw "VLevelA Test 13: X-axis movement failed."
        after_x = vertex_level_aligner.getWorldVertexPosition context_data 1

        if abs((after_x.x - before_x.x) - 25.0) > 0.001 then throw "VLevelA Test 13: X-axis movement did not change world X by 25."
        if abs(after_x.y - before_x.y) > 0.001 or abs(after_x.z - before_x.z) > 0.001 then throw "VLevelA Test 13: X-axis movement changed another world component."

        if not(vertex_level_aligner.scanNode test_object threshold:0.0 world_axis_value:#y) then throw "VLevelA Test 13: Y-axis Editable Poly scan failed."
        context_data = vertex_level_aligner.resolveContext test_object
        before_y = vertex_level_aligner.getWorldVertexPosition context_data 2

        if not(vertex_level_aligner.moveEditablePolyVertexBitsByWorldAxisDelta #{2} 25.0 world_axis_value:#y) then throw "VLevelA Test 13: Y-axis movement failed."
        after_y = vertex_level_aligner.getWorldVertexPosition context_data 2

        if abs((after_y.y - before_y.y) - 25.0) > 0.001 then throw "VLevelA Test 13: Y-axis movement did not change world Y by 25."
        if abs(after_y.x - before_y.x) > 0.001 or abs(after_y.z - before_y.z) > 0.001 then throw "VLevelA Test 13: Y-axis movement changed another world component."
    )

    true
    -- return
)

/*
Verifies 5 mm UP/DOWN rounding and that child-level rounding moves only the selected item's vertices.
The sibling exact level in the same threshold group must remain unchanged.
*/
function partOfTest14 =
(
    one_mm = units.decodeValue "1mm"
    offset_axis_value = 500000.0 * one_mm
    source_axis_value = offset_axis_value + (12.0 * one_mm)

    rounded_up = vertex_level_aligner.roundAxisValueToFiveMillimeters source_axis_value #up offset_axis_value:offset_axis_value
    rounded_down = vertex_level_aligner.roundAxisValueToFiveMillimeters source_axis_value #down offset_axis_value:offset_axis_value

    if abs(rounded_up - (offset_axis_value + (15.0 * one_mm))) > 0.0001 then throw "VLevelA Test 14: 12 mm display value did not round UP to 15 mm."
    if abs(rounded_down - (offset_axis_value + (10.0 * one_mm))) > 0.0001 then throw "VLevelA Test 14: 12 mm display value did not round DOWN to 10 mm."

    threshold_value = 10.0 * one_mm
    lower_world_value = 12.0 * one_mm
    upper_offset = 2.0 * one_mm
    test_object = undefined

    undo "Vertex Level Aligner Test 14 - Round Selected Level" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_ROUND_SELECTED_LEVEL"
        test_object.position.z = lower_world_value
        convertToPoly test_object

        upper_bits = #{3,4}
        upper_positions = #()

        for vertex_id in upper_bits do
        (
            vertex_position = polyop.getVert test_object.baseObject vertex_id
            vertex_position.z += upper_offset
            append upper_positions vertex_position
        )

        polyop.setVert test_object.baseObject upper_bits upper_positions
        update test_object

        if not(vertex_level_aligner.scanNode test_object threshold:threshold_value world_axis_value:#z) then throw "VLevelA Test 14: scan failed."
        if vertex_level_aligner.getGroupCount() != 1 then throw "VLevelA Test 14: expected one threshold group."

        lower_level = vertex_level_aligner.getLevelData 1 1
        upper_level = vertex_level_aligner.getLevelData 1 2
        if lower_level == undefined or upper_level == undefined then throw "VLevelA Test 14: exact levels are missing."

        lower_bits = lower_level[2]
        upper_bits = upper_level[2]
        upper_axis_before = upper_level[1]

        if not(vertex_level_aligner.roundLevelToFiveMillimeters 1 1 #up) then throw "VLevelA Test 14: selected-level Round UP failed."

        context_data = vertex_level_aligner.resolveContext test_object
        rounded_target = 15.0 * one_mm

        for vertex_id in lower_bits do
        (
            world_position = vertex_level_aligner.getWorldVertexPosition context_data vertex_id
            if abs(world_position.z - rounded_target) > 0.001 then throw "VLevelA Test 14: selected level vertex did not move to the 15 mm target."
        )

        for vertex_id in upper_bits do
        (
            world_position = vertex_level_aligner.getWorldVertexPosition context_data vertex_id
            if abs(world_position.z - upper_axis_before) > 0.001 then throw "VLevelA Test 14: sibling level vertex moved during selected-item rounding."
        )
    )

    true
    -- return
)

/*
Verifies TreeView numeric text uses comma thousands separators without changing decimal digits.
*/
function partOfTest15 =
(
    if vertex_level_aligner_rollout.addThousandsSeparators "100000.134" != "100,000.134" then throw "VLevelA Test 15: 100000.134 was not formatted as 100,000.134."
    if vertex_level_aligner_rollout.addThousandsSeparators "1000000.5" != "1,000,000.5" then throw "VLevelA Test 15: million-value thousands grouping failed."
    if vertex_level_aligner_rollout.addThousandsSeparators "-100000.134" != "-100,000.134" then throw "VLevelA Test 15: negative-value thousands grouping failed."
    if vertex_level_aligner_rollout.addThousandsSeparators "999.134" != "999.134" then throw "VLevelA Test 15: sub-thousand value changed unexpectedly."

    true
    -- return
)

/*
Verifies the CTRL+LMB TreeView multi-selection contract without restoring Align MOST.
Plain LMB remains native single-select; CTRL+LMB alone toggles the custom selection union.
*/
function partOfTest16 =
(
    tool_directory = getFilenamePath (getSourceFileName()) + "..\\"
    ui_path = tool_directory + "Vertex-Level-Aligner-UI.ms"

    stream = openFile ui_path mode:"rt"
    ui_text = ""
    while not(eof stream) do ui_text += readLine stream + "\n"
    close stream

    if (findString ui_text "on tv_levels AfterSelect sender event_args do") == undefined then throw "VLevelA Test 16: native TreeView AfterSelect handler is missing."
    if (findString ui_text "selectTreeNodeExclusive event_args.Node") == undefined then throw "VLevelA Test 16: plain LMB no longer routes through the exclusive single-selection path."
    if (findString ui_text "local selected_tree_tags = #()") == undefined then throw "VLevelA Test 16: CTRL+LMB multi-selection storage is missing."
    if (findString ui_text "function toggleTreeNodeSelection node_value") == undefined then throw "VLevelA Test 16: CTRL+LMB toggle helper is missing."
    if (findString ui_text "function applyTreeMultiSelectionToGeometry") == undefined then throw "VLevelA Test 16: multi-selection geometry union helper is missing."
    if (findString ui_text "if node_value != undefined and isTreeControlModifierDown() then") == undefined then throw "VLevelA Test 16: custom LMB handling is not restricted to CTRL."
    if (findString ui_text "function getSelectedTreeGroupIndexes") == undefined then throw "VLevelA Test 16: multi-selected parent-group resolver is missing for Expand/Collapse."
    if (findString ui_text "Align MOST") != undefined then throw "VLevelA Test 16: Align MOST returned."

    true
    -- return
)

/*
Verifies Align TO on exactly two levels by directly setting every Editable Poly group vertex to one X/Y/Z position.
This specifically guards the two-item X/Y failure where Z worked but the object and TreeView stayed unchanged.
*/
function partOfTest17 =
(
    one_mm = units.decodeValue "1mm"
    threshold_value = 5.0 * one_mm
    axis_values = #(#x, #y, #z)

    for test_axis in axis_values do
    (
        test_object = undefined

        undo "Vertex Level Aligner Test 17 - Two Level Direct Align" on
        (
            test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_ALIGN_TO_TWO_LEVEL"
            convertToPoly test_object
    
            lower_bits = #{1,2}
            upper_bits = #{3,4}
            lower_axis_value = 0.0
            upper_axis_value = 2.0 * one_mm

            for vertex_id = 1 to 4 do
            (
                vertex_position = polyop.getVert test_object.baseObject vertex_id

                case test_axis of
                (
                    #x: vertex_position.x = if lower_bits[vertex_id] then lower_axis_value else upper_axis_value
                    #y: vertex_position.y = if lower_bits[vertex_id] then lower_axis_value else upper_axis_value
                    default: vertex_position.z = if lower_bits[vertex_id] then lower_axis_value else upper_axis_value
                )

                polyop.setVert test_object.baseObject vertex_id vertex_position
            )

            update test_object

            if not(vertex_level_aligner.scanNode test_object threshold:threshold_value world_axis_value:test_axis) then throw ("VLevelA Test 17: initial " + (test_axis as string) + " scan failed.")
            if vertex_level_aligner.getGroupCount() != 1 then throw ("VLevelA Test 17: expected one two-level group on " + (test_axis as string) + ".")

            source_group = vertex_level_aligner.getGroupData 1
            if source_group == undefined or not(source_group[6]) then throw ("VLevelA Test 17: two-level source group is not broken on " + (test_axis as string) + ".")
            if source_group[5].count != 2 then throw ("VLevelA Test 17: expected exactly two child levels on " + (test_axis as string) + ".")

            target_level = vertex_level_aligner.getLevelData 1 1
            if target_level == undefined then throw ("VLevelA Test 17: target level missing on " + (test_axis as string) + ".")

            target_axis_value = vertex_level_aligner.getLiveVertexBitsAxisValue target_level[2]
            if target_axis_value == undefined then throw ("VLevelA Test 17: live target position missing on " + (test_axis as string) + ".")

            source_bits = source_group[4]

            if not(vertex_level_aligner.flattenGroupToAxisValue 1 target_axis_value alignment_mode:#here) then throw ("VLevelA Test 17: direct group align failed on " + (test_axis as string) + ": " + vertex_level_aligner.last_message)

            context_data = vertex_level_aligner.resolveContext test_object

            for vertex_id in source_bits do
            (
                world_position = vertex_level_aligner.getWorldVertexPosition context_data vertex_id
                current_axis_value = vertex_level_aligner.getWorldAxisValue world_position world_axis_value:test_axis

                if abs(current_axis_value - target_axis_value) > 0.001 then throw ("VLevelA Test 17: group vertex stayed off target on " + (test_axis as string) + ".")
            )

            if not(vertex_level_aligner.scanNode test_object threshold:threshold_value world_axis_value:test_axis) then throw ("VLevelA Test 17: rescan failed on " + (test_axis as string) + ".")

            aligned_group = vertex_level_aligner.getGroupData 1
            if aligned_group == undefined then throw ("VLevelA Test 17: aligned group missing on " + (test_axis as string) + ".")
            if aligned_group[6] then throw ("VLevelA Test 17: group stayed broken on " + (test_axis as string) + ".")
            if aligned_group[5].count != 1 then throw ("VLevelA Test 17: aligned group did not merge to one exact level on " + (test_axis as string) + ".")
        )
    )

    true
    -- return
)


/*
Verifies native world-coordinate PolyOp alignment collapses two- and three-level groups on X/Y at large transformed coordinates.
This guards float/transform differences that previously left 2 items unchanged or reduced 3 items only to 2.
*/
function partOfTest18 =
(
    one_mm = units.decodeValue "1mm"
    threshold_value = 50.0 * one_mm
    axis_values = #(#x, #y)

    for test_axis in axis_values do
    (
        for level_count in #(2,3) do
        (
            test_object = undefined

            undo "Vertex Level Aligner Test 18 - World Context Collapse" on
            (
                test_object = plane length:200 width:200 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_WORLD_CONTEXT_COLLAPSE"
                convertToPoly test_object
        
                test_object.position = [500000.0 * one_mm, 400000.0 * one_mm, 300000.0 * one_mm]
                test_object.rotation = eulerAngles 17 23 31

                base_axis_value = case test_axis of
                (
                    #x: test_object.position.x
                    #y: test_object.position.y
                    default: test_object.position.z
                )

                in coordsys world
                (
                    for vertex_id = 1 to 4 do
                    (
                        world_position = polyop.getVert test_object.baseObject vertex_id node:test_object
                        level_id = if level_count == 2 then (if vertex_id <= 2 then 1 else 2) else (if vertex_id <= 2 then 1 else vertex_id - 1)
                        level_axis_value = base_axis_value + ((level_id - 1) * 20.0 * one_mm)

                        case test_axis of
                        (
                            #x: world_position.x = level_axis_value
                            #y: world_position.y = level_axis_value
                            default: world_position.z = level_axis_value
                        )

                        polyop.setVert test_object.baseObject vertex_id world_position node:test_object
                    )
                )

                update test_object

                if not(vertex_level_aligner.scanNode test_object threshold:threshold_value world_axis_value:test_axis) then throw ("VLevelA Test 18: initial scan failed on " + (test_axis as string) + ".")
                source_group = vertex_level_aligner.getGroupData 1
                if source_group == undefined then throw ("VLevelA Test 18: source group missing on " + (test_axis as string) + ".")
                if source_group[5].count != level_count then throw ("VLevelA Test 18: expected " + (level_count as string) + " child levels on " + (test_axis as string) + ".")

                target_level = vertex_level_aligner.getLevelData 1 1
                target_axis_value = vertex_level_aligner.getLiveVertexBitsAxisValue target_level[2]

                if not(vertex_level_aligner.flattenGroupToAxisValue 1 target_axis_value alignment_mode:#here) then throw ("VLevelA Test 18: align failed on " + (test_axis as string) + ".")

                aligned_group = vertex_level_aligner.getGroupData 1
                if aligned_group == undefined then throw ("VLevelA Test 18: aligned group missing on " + (test_axis as string) + ".")
                if aligned_group[6] then throw ("VLevelA Test 18: " + (level_count as string) + "-item group stayed broken on " + (test_axis as string) + ".")
                if aligned_group[5].count != 1 then throw ("VLevelA Test 18: " + (level_count as string) + "-item group did not collapse to one level on " + (test_axis as string) + ".")

                aligned_context = vertex_level_aligner.resolveContext test_object
                for vertex_id = 1 to 4 do
                (
                    aligned_world_position = vertex_level_aligner.getWorldVertexPosition aligned_context vertex_id
                    aligned_axis_value = vertex_level_aligner.getWorldAxisValue aligned_world_position world_axis_value:test_axis
                    allowed_error = vertex_level_aligner.getAxisPrecisionTolerance aligned_axis_value target_axis_value
                    if abs(aligned_axis_value - target_axis_value) > allowed_error then throw ("VLevelA Test 18: aligned vertex exceeded Point3 precision allowance on " + (test_axis as string) + ".")
                )
            )
        )
    )

    true
    -- return
)

/*
Verifies the audit return contracts that must fail explicitly instead of fabricating clean data.
These checks are non-destructive and target the 0.819/0.820 safety fixes directly.
*/
function partOfTest19 =
(
    if vertex_level_aligner_test_project_version != 1.117 then throw "VLevelA Test 19: unexpected test project version."
    if vertex_level_aligner_main_version != 0.387 then throw "VLevelA Test 19: unexpected main file version."
    if vertex_level_aligner.file_version != 0.142 then throw "VLevelA Test 19: unexpected backend file version."
    if vertex_level_aligner.project_version != 1.117 then throw "VLevelA Test 19: backend project version is not 1.117."
    if vertex_level_aligner_ui.file_version != 0.496 then throw "VLevelA Test 19: unexpected UI file version."
    if vertex_level_aligner_ui.project_version != 1.117 then throw "VLevelA Test 19: UI project version is not 1.117."

    failed_vertex_count = vertex_level_aligner.getContextVertexCount #(#editable_poly, undefined, undefined)
    if failed_vertex_count != -1 then throw "VLevelA Test 19: failed vertex-count read did not return -1."

    if vertex_level_aligner.unhideVertexBits undefined then throw "VLevelA Test 19: undefined unhide target reported success."

    invalid_round_value = vertex_level_aligner.roundAxisValueToFiveMillimeters 0.0 #invalid
    if invalid_round_value != undefined then throw "VLevelA Test 19: invalid round direction produced a fake target."

    if vertex_level_aligner.selectTargets undefined then throw "VLevelA Test 19: undefined multi-target selection reported success."
    if vertex_level_aligner.selectTargets #() then throw "VLevelA Test 19: empty multi-target selection reported success."

    true
    -- return
)

/*
Verifies that a same-vertex-count topology mutation invalidates the stored scan.
A diagonal edge splits the scanned quad while keeping the vertex count unchanged.
*/
function partOfTest20 =
(
    test_object = undefined

    undo "Vertex Level Aligner Test 20 - Same Count Topology Mutation" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_TOPOLOGY_SIGNATURE"
        convertToPoly test_object

        if not(vertex_level_aligner.scanNode test_object threshold:0.0 world_axis_value:#z) then throw "VLevelA Test 20: initial scan failed."
        if not(vertex_level_aligner.isStoredContextCurrent()) then throw "VLevelA Test 20: fresh scan is not current."

        context_data = vertex_level_aligner.resolveContext test_object
        vertex_count_before = vertex_level_aligner.getContextVertexCount context_data
        face_vertices = polyop.getFaceVerts test_object.baseObject 1

        if face_vertices.count < 4 then throw "VLevelA Test 20: test plane does not expose one quad face."

        created_edge = polyop.createEdge test_object.baseObject face_vertices[1] face_vertices[3]
        if created_edge == undefined then throw "VLevelA Test 20: could not create the topology-changing diagonal edge."

        update test_object

        current_context = vertex_level_aligner.resolveContext test_object
        vertex_count_after = vertex_level_aligner.getContextVertexCount current_context
        if vertex_count_after != vertex_count_before then throw "VLevelA Test 20: fixture changed vertex count; same-count regression is invalid."

        if vertex_level_aligner.isStoredContextCurrent() then throw "VLevelA Test 20: same-count topology mutation was accepted as current."
        if vertex_level_aligner.selectGroup 1 then throw "VLevelA Test 20: stale group selection succeeded after topology mutation."
    )

    true
    -- return
)

/*
Verifies that partial live reads and failed edge contexts stay distinct from legitimate empty results.
One valid plus one invalid vertex ID must not be averaged into a usable axis target.
*/
function partOfTest21 =
(
    test_object = undefined

    undo "Vertex Level Aligner Test 21 - Failure Versus Empty" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_FAILURE_CONTRACTS"
        convertToPoly test_object

        if not(vertex_level_aligner.scanNode test_object threshold:0.0 world_axis_value:#z) then throw "VLevelA Test 21: initial scan failed."

        context_data = vertex_level_aligner.resolveContext test_object
        vertex_count = vertex_level_aligner.getContextVertexCount context_data
        if vertex_count < 1 then throw "VLevelA Test 21: fixture has no vertices."

        valid_bits = #{1}
        valid_axis_value = vertex_level_aligner.getLiveVertexBitsAxisValue valid_bits
        if valid_axis_value == undefined then throw "VLevelA Test 21: valid live vertex read failed."

        mixed_bits = #{1}
        mixed_bits[vertex_count + 100] = true
        mixed_axis_value = vertex_level_aligner.getLiveVertexBitsAxisValue mixed_bits
        if mixed_axis_value != undefined then throw "VLevelA Test 21: partial live read was averaged into a target value."

        legitimate_empty_edges = vertex_level_aligner.getEditablePolyEdgesBetweenVertexBits #{1}
        if legitimate_empty_edges == undefined then throw "VLevelA Test 21: legitimate one-vertex edge query returned failure."
        if legitimate_empty_edges.numberSet != 0 then throw "VLevelA Test 21: one-vertex edge query should be legitimately empty."

        saved_scan_node = vertex_level_aligner.scan_node
        failed_edges = undefined
        vertex_level_aligner.scan_node = undefined

        try
        (
            failed_edges = vertex_level_aligner.getEditablePolyEdgesBetweenVertexBits #{1,2}
        )
        catch
        (
            edge_failure_probe_exception = getCurrentException()
            vertex_level_aligner.scan_node = saved_scan_node
            throw
        )

        vertex_level_aligner.scan_node = saved_scan_node
        if failed_edges != undefined then throw "VLevelA Test 21: failed edge context was converted to an empty BitArray."
    )

    true
    -- return
)

/*
Verifies the TreeView LEVEL vertex-count filter contract without touching scene geometry.
Blank/off keeps all counts; EQUAL, MORE, and LESS use exact integer comparisons.
*/
function partOfTest22 =
(
    filter_items = vertex_level_aligner_rollout.buildLevelVertexCountFilterItems()

    if filter_items.count != 101 then throw "VLevelA Test 22: vertex-count filter list must contain blank plus 1..100."
    if filter_items[1] != "" then throw "VLevelA Test 22: first vertex-count filter item is not blank/off."
    if filter_items[2] != "1" then throw "VLevelA Test 22: vertex-count filter does not start at 1."
    if filter_items[101] != "100" then throw "VLevelA Test 22: vertex-count filter does not end at 100."

    if not(vertex_level_aligner_rollout.levelVertexCountMatchesFilter 5 1 0) then throw "VLevelA Test 22: blank/off filter hid a level."
    if not(vertex_level_aligner_rollout.levelVertexCountMatchesFilter 5 1 5) then throw "VLevelA Test 22: EQUAL failed on an exact match."
    if vertex_level_aligner_rollout.levelVertexCountMatchesFilter 5 1 4 then throw "VLevelA Test 22: EQUAL accepted a different count."
    if not(vertex_level_aligner_rollout.levelVertexCountMatchesFilter 5 2 4) then throw "VLevelA Test 22: MORE failed for a larger count."
    if vertex_level_aligner_rollout.levelVertexCountMatchesFilter 5 2 5 then throw "VLevelA Test 22: MORE must be strictly greater."
    if not(vertex_level_aligner_rollout.levelVertexCountMatchesFilter 5 3 6) then throw "VLevelA Test 22: LESS failed for a smaller count."
    if vertex_level_aligner_rollout.levelVertexCountMatchesFilter 5 3 5 then throw "VLevelA Test 22: LESS must be strictly smaller."

    exact_levels = #(#(0.0, #{1,2}), #(10.0, #{3,4,5,6}))
    if not(vertex_level_aligner_rollout.groupHasMatchingLevelVertexCount exact_levels 1 4) then throw "VLevelA Test 22: matching child level did not keep its group visible."
    if vertex_level_aligner_rollout.groupHasMatchingLevelVertexCount exact_levels 1 3 then throw "VLevelA Test 22: group stayed visible without a matching child level."

    true
    -- return
)


/*
Verifies Editable Poly polygon qualification and Material ID assignment.
A polygon qualifies only when every one of its vertices belongs to the selected TreeView target set.
*/
function partOfTest23 =
(
    test_object = undefined

    undo "Vertex Level Aligner Test 23 - Editable Poly Material ID" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_EDITABLE_MAT_ID"
        convertToPoly test_object

        if not(vertex_level_aligner.scanNode test_object threshold:0.0 world_axis_value:#z) then throw "VLevelA Test 23: scan failed."
        if vertex_level_aligner.getGroupCount() != 1 then throw "VLevelA Test 23: expected one exact level."

        group_data = vertex_level_aligner.getGroupData 1
        if group_data == undefined then throw "VLevelA Test 23: group data missing."

        full_faces = vertex_level_aligner.getFullySelectedFacesFromVertexBits group_data[4]
        if full_faces == undefined or full_faces.numberSet != 1 or not(full_faces[1]) then throw "VLevelA Test 23: fully selected plane polygon was not resolved."

        partial_vertex_bits = copy group_data[4]
        first_vertex_id = (partial_vertex_bits as array)[1]
        partial_vertex_bits[first_vertex_id] = false

        partial_faces = vertex_level_aligner.getFullySelectedFacesFromVertexBits partial_vertex_bits
        if partial_faces == undefined then throw "VLevelA Test 23: partial-vertex face query failed."
        if partial_faces.numberSet != 0 then throw "VLevelA Test 23: polygon with one unselected vertex was incorrectly included."

        target_data_array = #(#(#group, 1))
        if not(vertex_level_aligner.applyMaterialIdToTargets target_data_array 7) then throw ("VLevelA Test 23: Material ID assignment failed: " + vertex_level_aligner.last_message)

        if polyop.getFaceMatID test_object.baseObject 1 != 7 then throw "VLevelA Test 23: Editable Poly face Material ID is not 7."
    )

    true
    -- return
)

/*
Verifies Edit Poly polygon qualification, SetMaterial operation, and restoration of Vertex selection/sub-object level.
*/
function partOfTest24 =
(
    test_object = undefined
    test_modifier = undefined

    undo "Vertex Level Aligner Test 24 - Edit Poly Material ID" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_EDITPOLY_MAT_ID"
        convertToPoly test_object

        test_modifier = Edit_Poly()
        test_modifier.name = "VLevelA TEST MAT ID"
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

        if not(vertex_level_aligner.scanNode test_object modifier_value:test_modifier threshold:0.0 world_axis_value:#z) then throw "VLevelA Test 24: scan failed."
        if vertex_level_aligner.getGroupCount() != 1 then throw "VLevelA Test 24: expected one exact level."

        group_data = vertex_level_aligner.getGroupData 1
        if group_data == undefined then throw "VLevelA Test 24: group data missing."

        old_vertices = test_modifier.GetSelection #Vertex node:test_object
        if old_vertices.numberSet > 0 then test_modifier.Select #Vertex old_vertices select:false node:test_object
        test_modifier.Select #Vertex group_data[4] select:true node:test_object

        expected_vertices = test_modifier.GetSelection #Vertex node:test_object
        if not(vertex_level_aligner.bitArraysEqual expected_vertices group_data[4]) then throw "VLevelA Test 24: fixture vertex selection failed."

        target_data_array = #(#(#group, 1))
        if not(vertex_level_aligner.applyMaterialIdToTargets target_data_array 9) then throw ("VLevelA Test 24: Material ID assignment failed: " + vertex_level_aligner.last_message)

        if EditPolyMod.GetFaceMaterial test_modifier 1 node:test_object != 8 then throw "VLevelA Test 24: Edit Poly face Material ID is not internal ID 8 for UI Material ID 9."
        if subObjectLevel != 1 then throw "VLevelA Test 24: Vertex sub-object level was not restored."

        restored_vertices = test_modifier.GetSelection #Vertex node:test_object
        if not(vertex_level_aligner.bitArraysEqual restored_vertices expected_vertices) then throw "VLevelA Test 24: Vertex selection changed after Material ID assignment."

        restored_faces = test_modifier.GetSelection #Face node:test_object
        if restored_faces.numberSet != 0 then throw "VLevelA Test 24: temporary face selection was not restored."
    )

    true
    -- return
)

/*
Verifies that a dead Editable Poly face is compacted before the scan reads or stores component IDs.
*/
function partOfTest25 =
(
    test_object = undefined

    undo "Vertex Level Aligner Test 25 - Dead Topology Before Scan" on
    (
        test_object = plane length:100 width:100 lengthsegs:2 widthsegs:2 name:"VLevelA_TEST_DEAD_BEFORE_SCAN"
        convertToPoly test_object

        topology_value = test_object.baseObject
        if polyop.getHasDeadStructs topology_value != 0 then throw "VLevelA Test 25: clean fixture unexpectedly contains dead topology."

        face_count = polyop.getNumFaces topology_value
        target_face_id = 0

        for face_id = 1 to face_count do
        (
            if target_face_id == 0 and not(polyop.isFaceDead topology_value face_id) then
            (
                target_face_id = face_id
            )
        )

        if target_face_id == 0 then throw "VLevelA Test 25: could not find a live face for the dead-topology fixture."

        dead_flag = bit.set 0 2 true
        polyop.setFaceFlags topology_value #{target_face_id} dead_flag

        if polyop.getHasDeadStructs topology_value == 0 then throw "VLevelA Test 25: fixture did not create a dead Editable Poly component."

        compaction_serial_before = vertex_level_aligner.topology_compaction_serial

        if not(vertex_level_aligner.scanNode test_object threshold:0.0 world_axis_value:#z) then throw ("VLevelA Test 25: scan failed after dead-topology synchronization: " + vertex_level_aligner.last_message)

        if polyop.getHasDeadStructs topology_value != 0 then throw "VLevelA Test 25: dead topology survived the scan boundary."
        if vertex_level_aligner.topology_compaction_serial <= compaction_serial_before then throw "VLevelA Test 25: compaction serial did not advance."
        if not(vertex_level_aligner.isStoredContextCurrent()) then throw "VLevelA Test 25: fresh post-collapse scan is not current."
        if vertex_level_aligner.scan_vertex_count != polyop.getNumVerts topology_value then throw "VLevelA Test 25: stored vertex count was not rebuilt from compact topology."
        if vertex_level_aligner.scan_topology_signature.count != polyop.getNumFaces topology_value then throw "VLevelA Test 25: stored topology signature was not rebuilt from compact topology."
        if (polyop.getDeadVerts topology_value).numberSet != 0 then throw "VLevelA Test 25: dead vertices remain after compaction."
        if (polyop.getDeadEdges topology_value).numberSet != 0 then throw "VLevelA Test 25: dead edges remain after compaction."
        if (polyop.getDeadFaces topology_value).numberSet != 0 then throw "VLevelA Test 25: dead faces remain after compaction."
    )

    true
    -- return
)

/*
Verifies that a dead-topology synchronization invalidates every stored scan cache before old IDs can be reused.
*/
function partOfTest26 =
(
    test_object = undefined

    undo "Vertex Level Aligner Test 26 - Dead Topology Cache Invalidation" on
    (
        test_object = plane length:100 width:100 lengthsegs:2 widthsegs:2 name:"VLevelA_TEST_DEAD_CACHE_INVALIDATION"
        convertToPoly test_object

        if not(vertex_level_aligner.scanNode test_object threshold:0.0 world_axis_value:#z) then throw "VLevelA Test 26: initial clean scan failed."
        if vertex_level_aligner.getGroupCount() == 0 then throw "VLevelA Test 26: initial scan produced no stored groups."

        topology_value = test_object.baseObject
        if polyop.getHasDeadStructs topology_value != 0 then throw "VLevelA Test 26: initial fixture unexpectedly contains dead topology."

        face_count = polyop.getNumFaces topology_value
        target_face_id = 0

        for face_id = 1 to face_count do
        (
            if target_face_id == 0 and not(polyop.isFaceDead topology_value face_id) then
            (
                target_face_id = face_id
            )
        )

        if target_face_id == 0 then throw "VLevelA Test 26: could not find a live face for cache invalidation."

        dead_flag = bit.set 0 2 true
        polyop.setFaceFlags topology_value #{target_face_id} dead_flag

        if polyop.getHasDeadStructs topology_value == 0 then throw "VLevelA Test 26: fixture did not create dead topology."

        compaction_serial_before = vertex_level_aligner.topology_compaction_serial

        if vertex_level_aligner.isStoredContextCurrent() then throw "VLevelA Test 26: stale scan incorrectly survived a topology compaction boundary."

        if polyop.getHasDeadStructs topology_value != 0 then throw "VLevelA Test 26: dead topology survived current-context validation."
        if vertex_level_aligner.topology_compaction_serial <= compaction_serial_before then throw "VLevelA Test 26: compaction serial did not advance."
        if vertex_level_aligner.scan_node != undefined then throw "VLevelA Test 26: scan node cache survived compaction."
        if vertex_level_aligner.scan_modifier != undefined then throw "VLevelA Test 26: scan modifier cache survived compaction."
        if vertex_level_aligner.scan_kind != #none then throw "VLevelA Test 26: scan kind cache survived compaction."
        if vertex_level_aligner.scan_vertex_count != 0 then throw "VLevelA Test 26: scan vertex-count cache survived compaction."
        if vertex_level_aligner.scan_topology_signature.count != 0 then throw "VLevelA Test 26: topology signature cache survived compaction."
        if vertex_level_aligner.level_groups.count != 0 then throw "VLevelA Test 26: group/level BitArray caches survived compaction."
        if vertex_level_aligner.getGroupData 1 != undefined then throw "VLevelA Test 26: stale group data remained accessible after compaction."

        if not(vertex_level_aligner.scanNode test_object threshold:0.0 world_axis_value:#z) then throw "VLevelA Test 26: rescan after invalidation failed."
        if not(vertex_level_aligner.isStoredContextCurrent()) then throw "VLevelA Test 26: rebuilt scan is not current."
    )

    true
    -- return
)

/*
Verifies that dead-topology synchronization never collapses the base object for an Edit Poly modifier context.
*/
function partOfTest27 =
(
    test_object = undefined
    test_modifier = undefined

    undo "Vertex Level Aligner Test 27 - Edit Poly Separation" on
    (
        test_object = plane length:100 width:100 lengthsegs:1 widthsegs:1 name:"VLevelA_TEST_EDITPOLY_DEAD_SYNC"
        convertToPoly test_object

        test_modifier = Edit_Poly()
        test_modifier.name = "VLevelA TEST DEAD SYNC"
        test_modifier.showCage = off
        addModifier test_object test_modifier

        context_data = vertex_level_aligner.resolveContext test_object modifier_value:test_modifier
        if context_data[1] != #edit_poly then throw "VLevelA Test 27: Edit Poly context was not resolved."

        compaction_serial_before = vertex_level_aligner.topology_compaction_serial
        sync_state = vertex_level_aligner.synchronizeEditablePolyTopology context_data

        if sync_state != #not_applicable then throw "VLevelA Test 27: Edit Poly context entered the Editable Poly compaction path."
        if vertex_level_aligner.topology_compaction_serial != compaction_serial_before then throw "VLevelA Test 27: Edit Poly context changed the Editable Poly compaction serial."
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
partOfTest9()
partOfTest10()
partOfTest11()
partOfTest12()
partOfTest13()
partOfTest14()
partOfTest15()
partOfTest16()
partOfTest17()
partOfTest18()
partOfTest19()
partOfTest20()
partOfTest21()
partOfTest22()
partOfTest23()
partOfTest24()
partOfTest25()
partOfTest26()
partOfTest27()

format "\nVERTEX LEVEL ALIGNER PACKAGE TEST PASSED\n"
format "UNDO ORDER: Test 27 Edit Poly Dead-Sync Separation -> Test 26 Dead Cache Invalidation -> Test 25 Dead Before Scan -> Test 24 Edit Poly Material ID -> Test 23 Editable Poly Material ID -> Test 21 Failure Versus Empty -> Test 20 Same Count Topology Mutation -> Test 18 World Context Collapse -> Test 17 Two-Level XYZ Direct Align -> Test 14 Round Selected Level -> Test 13 XYZ World Axis -> Test 11 Unhide Selected Group -> Test 10 Edge Selection -> Test 8 Align HERE -> Test 5 Edit Poly Align DOWN -> Test 4 Editable Poly Align UP\n"
