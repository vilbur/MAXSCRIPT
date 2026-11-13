/*
 Tank Panel Generator v0.092 test suite.
Run this saved test file in 3ds Max; the final generated node remains for inspection.
*/


global IniSettings
global RolloutState
global DialogHost
global ScriptReload
global ToolTitleButton
global TPG_InsetRegressionOnly
global TPG_NormalRegressionOnly
global TPG_SeamsRegressionOnly
global TPG_BaseThicknessRegressionOnly
global TPG_HatchRegressionOnly
global TPG_TaperLoopsRegressionOnly
global TPG_TaperSpacingRegressionOnly
global TPG_LengthSubdivisionRegressionOnly
global TPG_BentWeldRegressionOnly
global TPG_ThicknessSeamRegressionOnly
global TPG_HatchOptionsRegressionOnly
global CapHatchGenerator
global TPG_SkipNormalRegression

/* Reject unsafe native SpinnerControl ranges before the entry script is loaded.
   Extreme 1.0e30 bounds can terminate 3ds Max during rollout initialization.
*/
function testTpgNativeSpinnerRanges source_path =
(
    local source_stream = openFile source_path
    if source_stream == undefined then throw ("TPG STARTUP TEST | Cannot open source: " + source_path)
    local line_number = 0
    local unsafe_line = 0
    while not (eof source_stream) and unsafe_line == 0 do
    (
        line_number += 1
        local line_text = readLine source_stream
        if (findString line_text "spinner ") != undefined and (findString line_text "1.0e30") != undefined then unsafe_line = line_number
    )
    close source_stream
    if unsafe_line > 0 then throw ("TPG STARTUP TEST | Unsafe native spinner range at line: " + unsafe_line as string)
    true
    -- return
)

testTpgNativeSpinnerRanges ((getFilenamePath (getSourceFileName())) + "Tank-Panel-Generator.ms")
/* Validate the editable profile on a temporary spline node with modifiers removed.
   Spline methods receive a node, never the Editable Spline base-object wrapper.
*/
function testTpgCapProfile cap_node expected_segments lip_offset:1 =
(
    local profile_copy = copy cap_node
    try
    (
        for stack_index = profile_copy.modifiers.count to 1 by -1 do deleteModifier profile_copy stack_index
        local spline_count = numSplines profile_copy
        local segment_count = numSegments profile_copy 1
        if spline_count != 1 or segment_count != expected_segments then
            throw ("TPG CAP PROFILE TEST | splines:" + spline_count as string + " segments:" + segment_count as string + " expected:" + expected_segments as string)
        for segment_id = 1 to segment_count do
        (
            local material_id = getMaterialID profile_copy 1 segment_id
            local expected_id = amax 1 (segment_id - lip_offset)
            if material_id != expected_id then
                throw ("TPG CAP PROFILE TEST | segment:" + segment_id as string + " material:" + material_id as string)
        )
    )
    catch
    (
        format "TPG CAP PROFILE TEST FAILED | %\n" (getCurrentException())
        if isValidNode profile_copy then delete profile_copy
        throw()
    )
    delete profile_copy
    true
    -- return
)

TPG_SkipNormalRegression = (TPG_InsetRegressionOnly == true and TPG_NormalRegressionOnly != true)


/* Set TPG_InsetRegressionOnly = true before fileIn for Parts 47-50 only.
   The flag is consumed once; default execution retains the legacy suite.
*/
if TPG_InsetRegressionOnly == true or TPG_NormalRegressionOnly == true or TPG_SeamsRegressionOnly == true or TPG_BaseThicknessRegressionOnly == true or TPG_HatchRegressionOnly == true or TPG_TaperLoopsRegressionOnly == true or TPG_TaperSpacingRegressionOnly == true or TPG_LengthSubdivisionRegressionOnly == true or TPG_BentWeldRegressionOnly == true or TPG_ThicknessSeamRegressionOnly == true or TPG_HatchOptionsRegressionOnly == true then
(
    TPG_InsetRegressionOnly = false
    if TPG_HatchOptionsRegressionOnly != true then
    (
        fileIn ((getFilenamePath (getSourceFileName())) + "Tank-Panel-Generator-FN.ms")
        if TPG_HatchRegressionOnly == true then fileIn ((getFilenamePath (getSourceFileName())) + "Tank-Panel-Generator-Cap-FN.ms")
    )
)
else
(
    global SurfacePanelGenerator


    local script_dir = getFilenamePath (getSourceFileName())


    /* Verify shared-root discovery without depending on the tool folder depth.
    */
    function partOfTest36 =
    (
        local bundled_ui_dir = pathConfig.appendPath script_dir "Lib"
        local expected_helpers = #("IniSettings.ms", "RolloutState.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms")
        for file_name in expected_helpers do
        (
            local helper_path = pathConfig.appendPath bundled_ui_dir file_name
            if not (doesFileExist helper_path) then
            (
                format "PART 36 FAILED | Local UI helper missing: %\n" helper_path
                throw "PART 36 FAILED: incomplete standalone Lib folder."
            )
        )
        -- File loading verifies that the fork does not need an external shared root.
        for file_name in expected_helpers do
        (
            fileIn (pathConfig.appendPath bundled_ui_dir file_name)
        )
        if IniSettings == undefined or RolloutState == undefined or DialogHost == undefined or ScriptReload == undefined or ToolTitleButton == undefined then
        (
            throw "PART 36 FAILED: one or more bundled UI globals were not initialized."
        )
        format "PASS PART 36 | Five local UI helpers loaded without shared Codebase or external configuration.\n"
        true
        -- return
    )


    partOfTest36()


    -- Fail before any scene operation if a partial/stale rename was synced.
    for expected_file in #("Tank-Panel-Generator.ms", "Tank-Panel-Generator-FN.ms", "Tank-Panel-Generator-Cap-FN.ms") do
    (
        if not doesFileExist (script_dir + expected_file) then
            throw ("TPG v0.027 TEST SETUP | Missing file: " + script_dir + expected_file)
    )
    fileIn (script_dir + "Tank-Panel-Generator-FN.ms")
    fileIn (script_dir + "Tank-Panel-Generator-Cap-FN.ms")


    local test_mask = #()
    local test_node = undefined


    /* Counts evaluated triangles independently of the modifier implementation.
    */
    function getTpgTestFaceCount source_node =
    (
        local result_mesh = snapshotAsMesh source_node
        local result_count = result_mesh.numfaces
        delete result_mesh
        result_count
        -- return
    )


    /* Counts evaluated vertices independently of the modifier implementation.
    */
    function getTpgTestVertexCount source_node =
    (
        local result_mesh = snapshotAsMesh source_node
        local result_count = result_mesh.numverts
        delete result_mesh
        result_count
        -- return
    )


    /*
    Simulates the v0.005 instance reported by the user. Newer members such as
    last_bend_mod and material_mode must not be accessed on this old struct.
    */
    struct SurfacePanelGeneratorLegacyTest_v
    (
        file_version = "0.009",
        rows = 4,
        columns = 3,
        mask = #(),
        last_node = undefined
    )


    /*
    Tests mask dimensions, row-major addressing, and state preservation on resize.
    */
    function partOfTest1 =
    (
        test_mask = SurfacePanelGenerator.makeMask 4 3 enabled:false
        test_mask[1] = true
        test_mask[6] = true
        test_mask[12] = true


        if test_mask.count != 12 or (SurfacePanelGenerator.countEnabled test_mask) != 3 then
        (
            throw "PART 1 FAILED: mask cardinality or enabled counter."
        )


        local resized_mask = SurfacePanelGenerator.resizeMask test_mask 4 3 5 4


        if resized_mask.count != 20 or not resized_mask[1] or not resized_mask[7] or not resized_mask[15] then
        (
            throw "PART 1 FAILED: resize changed preserved cell states."
        )


        local encoded_mask = SurfacePanelGenerator.encodeMask test_mask
        local decoded_mask = SurfacePanelGenerator.decodeMask encoded_mask 12 default_enabled:false


        if decoded_mask != test_mask then
        (
            throw "PART 1 FAILED: mask INI round-trip mismatch."
        )


        local tiled_mask = SurfacePanelGenerator.tileMask test_mask 4 3 2 3
        local untiled_mask = SurfacePanelGenerator.tileMask test_mask 4 3 1 1


        if tiled_mask.count != 72 or (SurfacePanelGenerator.countEnabled tiled_mask) != 18 then
        (
            throw "PART 1 FAILED: X/Y tiling must create 6 columns and 12 rows with 18 active cells."
        )


        if not tiled_mask[1] or not tiled_mask[4] or not tiled_mask[25] or not tiled_mask[28] or not tiled_mask[9] or not tiled_mask[12] or tiled_mask[2] or untiled_mask != test_mask then
        (
            throw "PART 1 FAILED: tiled pattern positions do not match repeated source."
        )


        format "PASS PART 1 | grid, resize, serialization, X/Y tiling\n"
        true
        -- return
    )


    /*
    Creates one real cylindrical test object with three enabled panel cells.
    */
    function partOfTest2 =
    (
        undo "TPG TEST 2 - Create Bent Module" on
        (
            test_node = SurfacePanelGenerator.generateModule 4 3 test_mask 100.0 200.0 5.0 8 0.01 x_multiplier:2 y_multiplier:3
        )


        if not isValidNode test_node then
        (
            throw "PART 2 FAILED: module creation returned no node."
        )


        format "PASS PART 2 | node:%\n" test_node.name
        true
        -- return
    )


    /*
    Confirms owned geometry metadata and final Bend modifier are present.
    */
    function partOfTest3 =
    (
        if test_node.modifiers.count != 2 or classOf test_node.modifiers[1] != TPGExtrusion_v or classOf test_node.modifiers[2] != Bend then
            throw "PART 3 FAILED: expected base -> Bend -> persistent extrusion."
        if (getAppData test_node.modifiers[1] 1847365210) != "TPG:Extrusion" then
            throw "PART 3 FAILED: extrusion ownership missing."
        for vertex_id = 1 to (polyop.getNumVerts test_node.baseObject) do
        (
            if (polyop.getVert test_node.baseObject vertex_id).z != 0.0 then
                throw "PART 3 FAILED: extrusion modified the flat base object."
        )
        if (getTpgTestFaceCount test_node) <= (2 * (polyop.getNumFaces test_node.baseObject)) then
            throw "PART 3 FAILED: procedural extrusion did not add topology."
        local face_vertex_ids = polyop.getFaceVerts test_node.baseObject 1
        if face_vertex_ids.count != 4 then
        (
            format "TPG TEST 3 FAILED | first polygon vertex count:% expected:4\n" face_vertex_ids.count
            throw "PART 3 FAILED: polygon vertex count mismatch."
        )


        local face_center = [0.0, 0.0, 0.0]
        for vertex_id in face_vertex_ids do
        (
            face_center += (polyop.getVert test_node.baseObject vertex_id)
        )
        face_center /= face_vertex_ids.count


        if (classOf face_center != Point3) then
        (
            format "TPG TEST 3 FAILED | expected Point3, got:%\n" (classOf face_center)
            throw "PART 3 FAILED: face-center reconstruction is invalid."
        )


        if (getUserProp test_node "SPG_Owner") != "Tank-Panel-Generator" then
        (
            throw "PART 3 FAILED: new modules must record the Tank Panel Generator owner."
        )


        local stored_rows = getUserProp test_node "SPG_Rows"
        local stored_columns = getUserProp test_node "SPG_Columns"
        local stored_mask = getUserProp test_node "SPG_Mask"
        local stored_x = getUserProp test_node "SPG_XMultiplier"
        local stored_y = getUserProp test_node "SPG_YMultiplier"
        local stored_total_rows = getUserProp test_node "SPG_TotalRows"
        local stored_total_columns = getUserProp test_node "SPG_TotalColumns"
        local stored_radius = getUserProp test_node "SPG_ExpandedRadius"
        local stored_length = getUserProp test_node "SPG_ExpandedLength"
        local bend_found = false


        for stack_mod in test_node.modifiers do
        (
            if classOf stack_mod == Bend then bend_found = true
        )


        if not bend_found or (stored_rows as integer) != 4 or (stored_columns as integer) != 3 or (stored_x as integer) != 2 or (stored_y as integer) != 3 or (stored_total_rows as integer) != 12 or (stored_total_columns as integer) != 6 or (stored_radius as float) != 100.0 or (stored_length as float) != 600.0 or stored_mask != (SurfacePanelGenerator.encodeMask test_mask) then
        (
            throw "PART 3 FAILED: generated node metadata or Bend missing."
        )


        format "PASS PART 3 | 18 repeated active cells | Bend found | metadata matches\n"
        format "UNDO ORDER | 1: TPG TEST 2 - Create Bent Module\n"
        true
        -- return
    )


    /*
    Verifies a fresh Edit Poly extrusion works without a preselected node
    or an open Modify panel, and restores the user's selection and panel mode.
    */
    function partOfTest35 =
    (
        local previous_selection = selection as array
        local previous_mode = getCommandPanelTaskMode()
        local previous_node = SurfacePanelGenerator.last_node
        local previous_bend = SurfacePanelGenerator.last_bend_mod
        local fixture_node = undefined
        local fixture_mask = SurfacePanelGenerator.makeMask 1 8 enabled:false
        fixture_mask[1] = true


        clearSelection()
        setCommandPanelTaskMode #create


        undo "TPG TEST 35 - Cold Edit Poly Context" on
        (
            fixture_node = SurfacePanelGenerator.generateModule 1 8 fixture_mask 100.0 200.0 0.0 1 0.01 rule_depths_value:(SurfacePanelGenerator.makeRuleDepths 8 10.0)
        )


        if not isValidNode fixture_node then throw "PART 35 FAILED: cold-start extrusion returned no node."
        local base_faces = polyop.getNumFaces fixture_node.baseObject
        local final_faces = getTpgTestFaceCount fixture_node
        format "TPG TEST 35 | Bend -> TPG Extrusion | base_faces:% triangles:%\n" base_faces final_faces
        if base_faces != 8 or final_faces <= (2 * base_faces) then
            throw "PART 35 FAILED: procedural modifier has no extruded topology after a cold start."
        if selection.count != 0 or getCommandPanelTaskMode() != #create then
            throw "PART 35 FAILED: generation did not restore the original empty selection and Create panel."


        delete fixture_node
        fixture_node = undefined
        undo "TPG TEST 35 - Reported 96 Face Context" on
        (
            fixture_node = SurfacePanelGenerator.generateModule 4 3 (SurfacePanelGenerator.makeMask 4 3 enabled:true) 100.0 200.0 0.0 8 0.01 rule_depths_value:(SurfacePanelGenerator.makeRuleDepths 12 10.0)
        )
        if not isValidNode fixture_node then throw "PART 35 FAILED: 96-face fixture returned no node."
        base_faces = polyop.getNumFaces fixture_node.baseObject
        final_faces = getTpgTestFaceCount fixture_node
        format "TPG TEST 35 | reported fixture | expected_base:96 base_faces:% final_faces:%\n" base_faces final_faces
        if base_faces != 96 or final_faces <= (2 * base_faces) then
            throw "PART 35 FAILED: reported 96-face fixture has no extrusion topology; see raw counts above."
        if selection.count != 0 or getCommandPanelTaskMode() != #create then
            throw "PART 35 FAILED: 96-face fixture did not restore empty selection and Create panel."
        delete fixture_node
        SurfacePanelGenerator.last_node = previous_node
        SurfacePanelGenerator.last_bend_mod = previous_bend
        if previous_selection.count > 0 then select previous_selection else clearSelection()
        setCommandPanelTaskMode previous_mode
        format "PASS PART 35 | procedural extrusion topology present, UI context preserved\n"
        true
        -- return
    )


    /*
    Checks UI globals and standalone managed dialog startup from a fresh scope.
    This catches createManagedDialog failing on an implicit local.
    */
    function partOfTest4 =
    (
        local entry_path = script_dir + "Tank-Panel-Generator.ms"
        if not doesFileExist entry_path then
        (
            format "TPG TEST 4 FAILED | Entry script missing: %\n" entry_path
            throw "PART 4 FAILED: missing Tank Panel Generator entry file."
        )


        fileIn entry_path


        if ::DialogHost == undefined or ::dialog_host_registry == undefined then
        (
            format "TPG TEST 4 FAILED | DialogHost:% registry:%\n" ::DialogHost ::dialog_host_registry
            throw "PART 4 FAILED: missing shared DialogHost state."
        )


        local dialog_count = 0
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then
            (
                dialog_count += 1
                dialog_ref = registry_entry[2]
            )
        )


        if dialog_count != 1 or dialog_ref == undefined then
        (
            format "TPG TEST 4 FAILED | registered dialogs:% expected:1\n" dialog_count
            throw "PART 4 FAILED: managed dialog was not registered exactly once."
        )
        /* A legacy Hatch snapshot expands locally without changing its caller.
           Plain mapped copy returns OK and used to abort rollout initialization.
        */
        local hatch_snapshot = dialog_ref.getHatchSettings()
        local legacy_hatch_values = for hatch_index = 1 to 9 collect hatch_snapshot[hatch_index]
        dialog_ref.setHatchSettings legacy_hatch_values
        if legacy_hatch_values.count != 9 or (dialog_ref.getHatchSettings()).count != 15 then
            throw "PART 4 FAILED: Hatch settings copy changed its input or failed legacy expansion."
        dialog_ref.setHatchSettings hatch_snapshot
        if (not isProperty dialog_ref #rebuildRuleSelector) or (not isProperty dialog_ref #rebuildGrid) or (not isProperty dialog_ref #saveUiState) or (not isProperty dialog_ref #refreshBoundModule) or (not isProperty dialog_ref #settingsChanged) then
        (
            throw "PART 4 FAILED: rollout forward-declared callbacks are missing."
        )
        /* Verify initial grid before any palette or rebuild callback can repair it.
        */
        local expected_cells = SurfacePanelGenerator.rows * SurfacePanelGenerator.columns
        if dialog_ref.dn_grid_host.Controls.Count != expected_cells then
        (
            format "TPG TEST 4 FAILED | initial cells:% expected:%\n" dialog_ref.dn_grid_host.Controls.Count expected_cells
            throw "PART 4 FAILED: initial grid requires a palette click."
        )
        for cell_index = 0 to expected_cells - 1 do
        (
            local cell_control = dialog_ref.dn_grid_host.Controls.Item[cell_index]
            if cell_control.Width <= 0 or cell_control.Height <= 0 or cell_control.Right > dialog_ref.dn_grid_host.ClientSize.Width or cell_control.Bottom > dialog_ref.dn_grid_host.ClientSize.Height then
            (
                format "TPG TEST 4 FAILED | cell:% bounds:% host:%\n" cell_index cell_control.Bounds dialog_ref.dn_grid_host.ClientSize
                throw "PART 4 FAILED: initial grid cell bounds are invalid."
            )
        )
        if dialog_ref.native_rule_slots.count != 12 or dialog_ref.native_rule_controls.count != (amin 12 (dialog_ref.getUsedMaterialIds()).count) then
            throw "PART 4 FAILED: direct native Extrude slots in Panels are missing."
        if classOf (getProperty dialog_ref #spn_extrude_inset_01) != SpinnerControl then
            throw "PART 4 FAILED: native Extrude spinner is not declared in the Panels rollout."
        for row_controls in dialog_ref.native_rule_controls do
        (
            local id_badge = row_controls[2]
            if (id_badge.text as string) != (row_controls[1] as string) then
                throw "PART 4 FAILED: native ID label was not initialized."
        )
        if (isProperty dialog_ref #btn_extrude) then throw "PART 4 FAILED: redundant Extrude button still exists."
        if dialog_ref.btn_cap_generate.Text != "Generate Hatch" then throw "PART 4 FAILED: .NET Generate Hatch action missing."
        if (not dialog_ref.rebuildRuleSelector()) or dialog_ref.dn_id_palette.Controls.Count != 9 then
        (
            throw "PART 4 FAILED: nine-button ID palette failed to initialise."
        )
        if isProperty dialog_ref #ddl_rule_id then throw "PART 4 FAILED: removed ID dropdown still exists."


        -- The four top-level sections are MAIN MODULE, PANELS, MATERIAL, HATCH.
        if dialog_ref.btn_generate.pos.y <= dialog_ref.ddl_arc_segments.pos.y or dialog_ref.btn_generate.pos.y >= dialog_ref.grp_panels_setup.pos.y then
            throw "PART 4 FAILED: Generate must be directly in Main Module."
        if dialog_ref.grp_panels_setup.pos.y <= dialog_ref.grp_setup.pos.y or dialog_ref.grp_material.pos.y <= dialog_ref.grp_panels_setup.pos.y or dialog_ref.grp_cap.pos.y <= dialog_ref.grp_material.pos.y then
            throw "PART 4 FAILED: root order is not Main Module, Panels, Material, Hatch."
        if dialog_ref.btn_setup_toggle.text != "- MAIN MODULE" and dialog_ref.btn_setup_toggle.text != "+ MAIN MODULE" then
            throw "PART 4 FAILED: Main Module section title is wrong."
        if dialog_ref.grp_material.pos.y < (dialog_ref.grp_panels_setup.pos.y + dialog_ref.grp_panels_setup.height) then
            throw "PART 4 FAILED: Material must start below Panels as a separate root."
        if dialog_ref.grp_cap.pos.y < (dialog_ref.grp_panels_setup.pos.y + dialog_ref.grp_panels_setup.height) then
            throw "PART 4 FAILED: Hatch overlaps Panels."
        if not dialog_ref.dialogBar then
        (
            throw "PART 4 FAILED: managed window must be registered as a dockable dialog bar."
        )
        if dialog_ref.dn_grid_host.AutoScroll then
        (
            throw "PART 4 FAILED: bottom panel grid must not scroll."
        )
        -- Saving the floating position must work even with a registered bar.
        local current_position = getDialogPos dialog_ref
        ::DialogHost.saveDialogPosition dialog_ref (script_dir + "Tank-Panel-Generator.ini") "MainUI"
        local saved_position = ::IniSettings.getPoint2 (script_dir + "Tank-Panel-Generator.ini") "MainUI" "PosX" "PosY" default_value:[-1,-1]
        if saved_position != current_position then
        (
            format "TPG TEST 4 FAILED | saved dialog position:% actual:%\n" saved_position current_position
            throw "PART 4 FAILED: floating dialog position was not persisted."
        )


        if dialog_ref.btn_generate.height != 48 then
        (
            throw "PART 4 FAILED: Generate button height must be 48 pixels."
        )
        local green_foreground = dialog_ref.btn_generate.ForeColor
        if green_foreground.G <= green_foreground.R or green_foreground.G <= green_foreground.B then
        (
            throw "PART 4 FAILED: Generate button text is not green."
        )
        if dialog_ref.btn_tool_title.height != 20 then
        (
            format "TPG TEST 4 FAILED | Title button height:% expected:20\n" dialog_ref.btn_tool_title.height
            throw "PART 4 FAILED: title button did not retain +2 px height."
        )
        if dialog_ref.dn_id_palette.pos.y <= dialog_ref.dn_grid_host.pos.y then
        (
            throw "PART 4 FAILED: palette is not below the panel grid."
        )


        -- Only the two continuous physical dimensions retain native spinners.
        for dropdown_control in #(dialog_ref.ddl_rows, dialog_ref.ddl_columns, dialog_ref.ddl_repeat_x, dialog_ref.ddl_repeat_y, dialog_ref.ddl_arc_segments, dialog_ref.ddl_length_segments) do
        (
            if dropdown_control.DropDownStyle != (dotNetClass "System.Windows.Forms.ComboBoxStyle").DropDownList then
            (
                throw "PART 4 FAILED: dropdown is editable or not initialised."
            )
            local item_height = amax 16 dropdown_control.ItemHeight
            local expected_height = (dropdown_control.Items.Count * item_height) + 4
            if dropdown_control.DropDownHeight < (amin expected_height ((dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea.Height - 120)) then
            (
                throw "PART 4 FAILED: popup height does not fit item count."
            )
        )
        if dialog_ref.spn_radius.value <= 0 or dialog_ref.spn_length.value <= 0 then
        (
            throw "PART 4 FAILED: radius/length spinners not initialised."
        )
        local repeat_value = dialog_ref.getIntegerDropdown dialog_ref.ddl_repeat_x
        local subdivision_value = dialog_ref.getIntegerDropdown dialog_ref.ddl_arc_segments
        if repeat_value < 1 or repeat_value > 16 or subdivision_value < 1 then
        (
            throw "PART 4 FAILED: integer dropdown has an invalid selected value."
        )


        format "PASS PART 4 | position persisted, dockable dialog, bottom grid, 20 px title, integer dropdowns\n"
        true
        -- return
    )


    /*
    Verifies documented integer-rounding primitives work in both directions.
    These expressions match the quantization in generateModule.
    */
    function partOfTest5 =
    (
        local positive_scaled = 1.6
        local negative_scaled = -1.6
        local positive_round = if positive_scaled >= 0.0 then (floor (positive_scaled + 0.5)) else (ceil (positive_scaled - 0.5))
        local negative_round = if negative_scaled >= 0.0 then (floor (negative_scaled + 0.5)) else (ceil (negative_scaled - 0.5))


        if positive_round != 2.0 or negative_round != -2.0 then
        (
            format "TPG TEST 5 FAILED | positive:% expected:2.0 negative:% expected:-2.0\n" positive_round negative_round
            throw "PART 5 FAILED: signed nearest-step quantization is wrong."
        )


        format "PASS PART 5 | signed rounding via floor/ceil\n"
        true
        -- return
    )


    /*
    Verifies per-source-cell material IDs and the default multicolour palette.
    Each tile repeats exactly the source cell IDs rather than creating new ones.
    */
    function partOfTest6 =
    (
        if classOf test_node.material != MultiMaterial then
        (
            format "TPG TEST 6 FAILED | material type:% expected:MultiMaterial\n" (classOf test_node.material)
            throw "PART 6 FAILED: default material is not Multi/Sub-Object."
        )
        if test_node.material.materialList.count != 12 then
        (
            format "TPG TEST 6 FAILED | material slots:% expected:12\n" test_node.material.materialList.count
            throw "PART 6 FAILED: material palette size must equal source grid cells."
        )
        for material_id = 1 to 12 do
        (
            if classOf test_node.material.materialList[material_id] != StandardMaterial then
            (
                format "TPG TEST 6 FAILED | submaterial ID:% class:%\n" material_id (classOf test_node.material.materialList[material_id])
                throw "PART 6 FAILED: submaterial is not Standard."
            )
        )


        local material_counts = for item_id = 1 to 12 collect 0
        local evaluated_mesh = snapshotAsMesh test_node
        local face_count = evaluated_mesh.numfaces
        for face_id = 1 to face_count do
        (
            if face_id <= evaluated_mesh.numfaces then
            (
                local material_id = getFaceMatID evaluated_mesh face_id
                if material_id < 1 or material_id > 12 then
                (
                    format "TPG TEST 6 FAILED | face:% unexpected material ID:%\n" face_id material_id
                    throw "PART 6 FAILED: face material ID outside source-grid range."
                )
                material_counts[material_id] += 1
            )
        )
        delete evaluated_mesh
        for material_id = 1 to 12 do
        (
            if material_counts[material_id] < 1 then
            (
                format "TPG TEST 6 FAILED | unused source material ID:%\n" material_id
                throw "PART 6 FAILED: source material ID is unused."
            )
        )
        if (getUserProp test_node "SPG_MaterialMode") != "Multi" then
        (
            throw "PART 6 FAILED: default Multi material mode was not stored."
        )
        format "PASS PART 6 | 12 Standard submaterials, repeated source IDs, no missing IDs\n"
        true
        -- return
    )


    /*
    Rebuilds the same node without changing its handle, name or transform.
    */
    function partOfTest7 =
    (
        local original_handle = getHandleByAnim test_node
        local original_name = test_node.name
        test_node.pos = [25,10,5]
        local original_position = test_node.pos
        local original_count = objects.count
        local bound_bend = SurfacePanelGenerator.last_bend_mod
        local updated_node = undefined


        undo "TPG TEST 7 - In-Place Regeneration" on
        (
            updated_node = SurfacePanelGenerator.generateModule 4 3 test_mask 90.0 150.0 3.0 6 0.01 x_multiplier:1 y_multiplier:2 target_node:test_node owned_bend:bound_bend material_mode_value:#multi
        )


        if not isValidNode updated_node or updated_node != test_node then
        (
            throw "PART 7 FAILED: bound node was replaced with another scene object."
        )
        if (getHandleByAnim updated_node) != original_handle or updated_node.name != original_name or updated_node.pos != original_position or objects.count != original_count then
        (
            format "TPG TEST 7 FAILED | handle:% expected:% name:% expected:% position:% expected:% node count:% expected:%\n" (getHandleByAnim updated_node) original_handle updated_node.name original_name updated_node.pos original_position objects.count original_count
            throw "PART 7 FAILED: in-place update did not preserve scene node identity."
        )
        if (getUserProp updated_node "SPG_TotalRows") != "8" or (getUserProp updated_node "SPG_TotalColumns") != "3" then
        (
            throw "PART 7 FAILED: updated geometry dimensions not stored."
        )
        format "PASS PART 7 | in-place update keeps handle, name, transform, object count\n"
        true
        -- return
    )


    /*
    Switches material modes on one node, then confirms grey persists on regeneration.
    */
    function partOfTest8 =
    (
        if not (SurfacePanelGenerator.applyMaterial test_node 4 3 #gray) then
        (
            throw "PART 8 FAILED: could not apply grey material."
        )
        if classOf test_node.material != StandardMaterial or SurfacePanelGenerator.material_mode != #gray then
        (
            throw "PART 8 FAILED: grey mode did not apply Standard material."
        )
        local old_handle = getHandleByAnim test_node
        undo "TPG TEST 8 - Grey Mode Regeneration" on
        (
            test_node = SurfacePanelGenerator.generateModule 4 3 test_mask 85.0 130.0 2.0 6 0.01 x_multiplier:1 y_multiplier:1 target_node:test_node owned_bend:SurfacePanelGenerator.last_bend_mod material_mode_value:SurfacePanelGenerator.material_mode
        )
        if not isValidNode test_node or (getHandleByAnim test_node) != old_handle or classOf test_node.material != StandardMaterial then
        (
            throw "PART 8 FAILED: grey material was not preserved on the bound object."
        )
        if not (SurfacePanelGenerator.applyMaterial test_node 4 3 #multi) then
        (
            throw "PART 8 FAILED: failed to restore Multi/Sub material."
        )
        if classOf test_node.material != MultiMaterial or (getUserProp test_node "SPG_MaterialMode") != "Multi" then
        (
            throw "PART 8 FAILED: restored material mode is wrong."
        )
        format "PASS PART 8 | LMB Multi-ID / RMB Grey / mode persists through update\n"
        true
        -- return
    )


    /*
    Refuses unsafe replacement when an unrelated modifier is on the node.
    Leaves that modifier untouched and the scene object alive for inspection.
    */
    function partOfTest9 =
    (
        local user_added_mod = TurboSmooth iterations:1
        addModifier test_node user_added_mod
        local original_handle = getHandleByAnim test_node
        local rejected_node = SurfacePanelGenerator.generateModule 4 3 test_mask 88.0 140.0 4.0 6 0.01 x_multiplier:1 y_multiplier:1 target_node:test_node owned_bend:SurfacePanelGenerator.last_bend_mod material_mode_value:#multi
        if rejected_node != undefined or not isValidNode test_node or (getHandleByAnim test_node) != original_handle or test_node.modifiers[1] != user_added_mod then
        (
            throw "PART 9 FAILED: foreign modifier was replaced or bound node changed."
        )
        deleteModifier test_node user_added_mod
        format "PASS PART 9 | foreign modifier blocks destructive regeneration\n"
        true
        -- return
    )


    /*
    Loads the UI with a legacy v0.005 struct already present.
    Verifies startup upgrades missing struct members safely.
    */
    function partOfTest10 =
    (
        local entry_path = script_dir + "Tank-Panel-Generator.ms"
        local legacy_state = SurfacePanelGeneratorLegacyTest_v()
        ::SurfacePanelGenerator = legacy_state
        fileIn entry_path


        if ::SurfacePanelGenerator == undefined then
        (
            throw "PART 10 FAILED: latest generator instance was not installed."
        )


        local current_members = getPropNames ::SurfacePanelGenerator
        if (findItem current_members #last_bend_mod) == 0 or (findItem current_members #material_mode) == 0 then
        (
            throw "PART 10 FAILED: legacy struct was not upgraded to the current schema."
        )
        if ::SurfacePanelGenerator.last_node != undefined or ::SurfacePanelGenerator.last_bend_mod != undefined or ::SurfacePanelGenerator.material_mode != #multi then
        (
            throw "PART 10 FAILED: migration did not use safe defaults."
        )


        format "PASS PART 10 | v0.005 struct without Bend/material fields loads current UI\n"
        true
        -- return
    )


    /*
    Verifies segment-count dropdown changes use the existing mask-resize and
    in-place geometry-update contract (no second scene node is created).
    */
    function partOfTest11 =
    (
        local new_rows = 3
        local new_columns = 2
        local shorter_mask = SurfacePanelGenerator.resizeMask test_mask 4 3 new_rows new_columns
        local old_handle = getHandleByAnim test_node
        local old_count = objects.count
        local updated_node = undefined


        undo "TPG TEST 11 - Segment Dimension Update" on
        (
            updated_node = SurfacePanelGenerator.generateModule new_rows new_columns shorter_mask 85.0 130.0 2.0 6 0.01 x_multiplier:1 y_multiplier:1 target_node:test_node owned_bend:SurfacePanelGenerator.last_bend_mod material_mode_value:SurfacePanelGenerator.material_mode
        )


        if not isValidNode updated_node or (getHandleByAnim updated_node) != old_handle or objects.count != old_count then
        (
            throw "PART 11 FAILED: segment dropdown update must keep bound node identity."
        )
        if (getUserProp updated_node "SPG_Rows") != "3" or (getUserProp updated_node "SPG_Columns") != "2" or (getUserProp updated_node "SPG_Mask") != (SurfacePanelGenerator.encodeMask shorter_mask) then
        (
            throw "PART 11 FAILED: resized segment grid was not committed to the bound node."
        )


        format "PASS PART 11 | dropdown segment change regenerates the same node\n"
        true
        -- return
    )


    /*
    New cells default to ID 1; manually painted IDs survive serialization
    and grid resizing, while newly added cells remain ID 1.
    */
    function partOfTest12 =
    (
        local ids_value = SurfacePanelGenerator.makeCellIds 2 3
        if ids_value != #(1,1,1,1,1,1) then
        (
            throw "PART 12 FAILED: new grid cells must default to ID 1."
        )
        ids_value[2] = 4
        ids_value[3] = 9
        ids_value[5] = 12
        local restored_ids = SurfacePanelGenerator.decodeCellIds (SurfacePanelGenerator.encodeCellIds ids_value) 2 3
        if restored_ids != ids_value then
        (
            throw "PART 12 FAILED: manually assigned IDs did not survive serialization."
        )
        local expanded_ids = SurfacePanelGenerator.resizeCellIds ids_value 2 3 3 4
        if expanded_ids[2] != 4 or expanded_ids[3] != 9 or expanded_ids[6] != 12 or expanded_ids[4] != 1 or expanded_ids[12] != 1 then
        (
            throw "PART 12 FAILED: changing grid size lost the logical ID layout."
        )
        format "PASS PART 12 | default ID 1, painted IDs, persistence and resize defaults\n"
        true
        -- return
    )


    /*
    Confirms per-ID extrusion depth data is independent from mask and segment count.
    */
    function partOfTest13 =
    (
        local depths_value = SurfacePanelGenerator.makeRuleDepths 16 5.0
        depths_value[1] = 0.0
        depths_value[2] = -2.0
        depths_value[3] = 11.0
        local restored_depths = SurfacePanelGenerator.decodeRuleDepths (SurfacePanelGenerator.encodeRuleDepths depths_value) 16 5.0
        if restored_depths != depths_value then
        (
            throw "PART 13 FAILED: per-ID extrusion depth persistence mismatch."
        )
        local expanded_depths = SurfacePanelGenerator.resizeRuleDepths restored_depths 20 7.0
        if expanded_depths[2] != -2.0 then
        (
            throw "PART 13 FAILED: expanding rule count erased ID-specific extrusion."
        )
        format "PASS PART 13 | depth=0, recessed depth, raised depth, persistence\n"
        true
        -- return
    )


    /*
    Produces a repeated tiled object with shared per-ID options and verifies
    the material-ID and user-property contract on its original polygon faces.
    */
    function partOfTest14 =
    (
        local ids_value = SurfacePanelGenerator.makeCellIds 2 2
        ids_value[2] = 1
        ids_value[4] = 3
        local rule_values = SurfacePanelGenerator.makeRuleDepths 16 0.0
        rule_values[1] = 5.0
        rule_values[3] = -2.0
        local old_handle = getHandleByAnim test_node
        local replacement_node = undefined
        undo "TPG TEST 14 - Custom IDs and Rule Extrusion" on
        (
            replacement_node = SurfacePanelGenerator.generateModule 2 2 (SurfacePanelGenerator.makeMask 2 2 enabled:true) 95.0 125.0 0.0 6 0.01 x_multiplier:2 y_multiplier:2 target_node:test_node owned_bend:SurfacePanelGenerator.last_bend_mod material_mode_value:#multi cell_ids_value:ids_value rule_depths_value:rule_values
        )
        if not isValidNode replacement_node or (getHandleByAnim replacement_node) != old_handle then
        (
            throw "PART 14 FAILED: custom rules did not update the existing bound node."
        )
        if (getUserProp replacement_node "SPG_CellIDs") != (SurfacePanelGenerator.encodeCellIds ids_value) or (getUserProp replacement_node "SPG_RuleDepths") != (SurfacePanelGenerator.encodeRuleDepths rule_values) then
        (
            throw "PART 14 FAILED: panel ID assignments and rule depths were not saved on the node."
        )
        if classOf replacement_node.material != MultiMaterial or replacement_node.material.numsubs < 16 then
        (
            throw "PART 14 FAILED: Multi/Sub material lacks source rule IDs."
        )
        format "PASS PART 14 | shared rule IDs and per-ID extrusions on bound object\n"
        true
        -- return
    )


    /*
    Checks the fixed subdued ID palette and stable repeated-cycle variants.
    */
    function partOfTest15 =
    (
        local grey_value = SurfacePanelGenerator.getPanelColor 1
        if grey_value.r != grey_value.g or grey_value.g != grey_value.b then
        (
            throw "PART 15 FAILED: ID 1 must be neutral grey."
        )
        local colors_value = for rule_id = 1 to 14 collect (SurfacePanelGenerator.getPanelColor rule_id)
        if colors_value[2].r <= colors_value[2].g or colors_value[3].g <= colors_value[3].r or colors_value[4].b <= colors_value[4].r then
        (
            throw "PART 15 FAILED: base material IDs are not red, green, blue."
        )
        if colors_value[2] == colors_value[9] or (SurfacePanelGenerator.getPanelColor 9) != colors_value[9] then
        (
            throw "PART 15 FAILED: repeat palette must vary but be deterministic."
        )
        local material_value = SurfacePanelGenerator.makePaletteMaterial 2 3 rule_count:14
        if material_value.numsubs < 14 then
        (
            throw "PART 15 FAILED: palette does not cover rule IDs."
        )
        if material_value.materialList[1].diffuse != grey_value or material_value.materialList[9].diffuse != colors_value[9] then
        (
            throw "PART 15 FAILED: Multi/Sub diffuse colors do not match grid colors."
        )
        format "PASS PART 15 | subdued palette, ID 1 grey, deterministic cycle, Multi/Sub\n"
        true
        -- return
    )


    /*
    Checks outside-to-inside seam radii and validation without editing scene.
    */
    function partOfTest16 =
    (
        local values = CapHatchGenerator.makeSeamRadii 103.0 0.0 3 5.0 10.0
        if values == undefined or values.count != 3 or values[1] != 98.0 or values[2] != 88.0 or values[3] != 78.0 then
        (
            throw "PART 16 FAILED: outside-to-inside seam spacing is incorrect."
        )
        local invalid_values = CapHatchGenerator.makeSeamRadii 50.0 25.0 3 5.0 10.0
        if invalid_values != undefined then throw "PART 16 FAILED: invalid seam interval was not refused."
        format "PASS PART 16 | cap seam radii, count, spacing and validation\n"
        true
        -- return
    )


    /*
    Generates a linked cap profile with stable spline-segment IDs and fresh
    Lathe/Chamfer modifiers, then updates the same scene node.
    */
    function partOfTest17 =
    (
        if not isValidNode test_node then throw "PART 17 FAILED: missing source module."
        local cap_node = undefined
        undo "TPG TEST 17 - Create Lathe Cap Hatch" on
        (
            cap_node = CapHatchGenerator.generateCap test_node 190.0 250.0 0.0 3.0 5.0 3 5.0 10.0 1.0 0.5 0.0 lathe_segments:64
        )
        if not isValidNode cap_node or cap_node.parent != test_node or cap_node.modifiers.count != 2 then
        (
            throw "PART 17 FAILED: cap was not linked with exactly two modifiers."
        )
        if classOf cap_node.modifiers[2] != Lathe or classOf cap_node.modifiers[1] != Chamfer then
        (
            throw "PART 17 FAILED: modifier stack must be Chamfer above Lathe."
        )
        if not cap_node.modifiers[2].useShapeIDs or not cap_node.modifiers[2].matIDs or cap_node.modifiers[1].selectionoption != 5 or cap_node.modifiers[1].materialoption != 1 then
        (
            throw "PART 17 FAILED: Lathe shape IDs or chamfer selection settings incorrect."
        )
        testTpgCapProfile cap_node 5
        if classOf cap_node.material != MultiMaterial or cap_node.material.numsubs < 5 then
        (
            throw "PART 17 FAILED: cap material palette is incomplete."
        )
        local original_handle = getHandleByAnim cap_node
        undo "TPG TEST 17 - Update Lathe Cap Hatch" on
        (
            cap_node = CapHatchGenerator.generateCap test_node 190.0 250.0 8.0 4.0 -3.0 2 4.0 12.0 2.0 -0.2 1.0 lathe_segments:48 target_node:cap_node owned_lathe:CapHatchGenerator.last_lathe_mod owned_chamfer:CapHatchGenerator.last_chamfer_mod
        )
        if not isValidNode cap_node or (getHandleByAnim cap_node) != original_handle or cap_node.modifiers.count != 2 or cap_node.modifiers[1].amount != 2.0 or cap_node.modifiers[1].depth != -0.2 or not cap_node.modifiers[1].addinset then
        (
            throw "PART 17 FAILED: bound cap update or fresh chamfer configuration failed."
        )
        format "PASS PART 17 | linked Lathe profile, shape IDs, clean Chamfer, cap node retained\n"
        true
        -- return
    )


    -- Exercise Edit Poly's first insertion before any generator test warms the Modify panel.
    partOfTest35()
    partOfTest15()
    partOfTest12()
    partOfTest13()
    partOfTest1()
    partOfTest5()
    partOfTest2()
    partOfTest3()
    partOfTest6()
    partOfTest7()
    partOfTest8()
    partOfTest9()
    partOfTest11()
    partOfTest4()
    partOfTest10()
    partOfTest14()
    partOfTest16()
    /*
    Verifies the explicit display-unit conversion round-trip used for Radius
    and Length, without changing scene geometry or rounding source values.
    */
    function partOfTest18 =
    (
        local scene_value = 123.456789
        for unit_text in #("1mm", "1cm", "1m", "1in", "1ft") do
        (
            local scene_per_unit = units.decodeValue unit_text
            if scene_per_unit <= 0.0 then throw ("PART 18 FAILED: unit scale is nonpositive: " + unit_text)
            local display_value = scene_value / scene_per_unit
            local recovered_scene_value = display_value * scene_per_unit
            if abs (recovered_scene_value - scene_value) > (abs scene_value * 0.00001) then
            (
                throw ("PART 18 FAILED: unit conversion round-trip: " + unit_text)
            )
        )
        format "PASS PART 18 | dimension unit conversions preserve system-unit values\n"
        true
        -- return
    )


    /*
    Checks source dimensions against the Plane before Bend, independently
    of the display preview. Preview fits naturally until it would become
    narrower than 50% of the host; only then its visible X scale grows.
    Keeps Y proportional, centres the grid and avoids clipping.
    */
    function partOfTest19 =
    (
        local panel_size = SurfacePanelGenerator.getUnbentPanelDimensions 4 3 100.0 200.0
        local expected_width = (2.0 * pi * 100.0) / 3.0
        local expected_height = 200.0 / 4.0
        if panel_size == undefined or (abs (panel_size.x - expected_width)) > 0.0001 or (abs (panel_size.y - expected_height)) > 0.0001 then
        (
            throw "PART 19 FAILED: source panel differs from the pre-Bend Plane polygon footprint."
        )
        local repeated_size = SurfacePanelGenerator.getUnbentPanelDimensions 4 3 100.0 200.0 x_multiplier:3
        local repeated_width = (2.0 * pi * 100.0) / (3.0 * 3.0)
        local repeated_height = ((200.0 * 4.0) / (4.0 * 4.0))
        if repeated_size == undefined or (abs (repeated_width - repeated_size.x)) > 0.0001 or (abs (repeated_height - repeated_size.y)) > 0.0001 or (abs ((repeated_size.x * 3.0) - panel_size.x)) > 0.0001 then
        (
            throw "PART 19 FAILED: repeating Around must shrink source width by 1/repeat, not grow the module."
        )
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 19 FAILED: missing generator UI."
        dialog_ref.layoutGridButtons()
        local preview = dialog_ref.getPanelPreviewMetrics()
        local actual_size = SurfacePanelGenerator.getUnbentPanelDimensions ::SurfacePanelGenerator.rows ::SurfacePanelGenerator.columns (dialog_ref.moduleRadius()) (dialog_ref.moduleLength()) x_multiplier:(dialog_ref.getIntegerDropdown dialog_ref.ddl_repeat_x)
        if actual_size == undefined or preview[3] <= 0.0 or preview[4] <= 0.0 then
        (
            throw "PART 19 FAILED: preview returned invalid cell dimensions."
        )
        local host_width = dialog_ref.dn_grid_host.ClientSize.Width
        local host_height = dialog_ref.dn_grid_host.ClientSize.Height
        local source_width = actual_size.x * ::SurfacePanelGenerator.columns
        local source_height = actual_size.y * ::SurfacePanelGenerator.rows
        local natural_scale = amin ((host_width as float) / source_width) ((host_height as float) / source_height)
        local expected_grid_width = amax (source_width * natural_scale) ((host_width as float) * 0.5)
        local displayed_grid_width = preview[3] * ::SurfacePanelGenerator.columns
        if (abs (displayed_grid_width - expected_grid_width)) > 0.01 or displayed_grid_width < ((host_width as float) * 0.5) then
            throw "PART 19 FAILED: preview grid must use at least half the host width."
        if (abs (preview[4] - (actual_size.y * natural_scale))) > 0.01 then
            throw "PART 19 FAILED: minimum width changed the preview's original vertical scale."
        if preview[1] < -0.01 or preview[2] < -0.01 or (preview[1] + preview[3] * ::SurfacePanelGenerator.columns) > (host_width + 0.01) or (preview[2] + preview[4] * ::SurfacePanelGenerator.rows) > (host_height + 0.01) then
        (
            throw "PART 19 FAILED: preview does not fit inside the visible host bounds."
        )
        if (SurfacePanelGenerator.getUnbentPanelDimensions 0 3 100.0 200.0) != undefined then
        (
            throw "PART 19 FAILED: invalid source-panel counts were accepted."
        )
        format "PASS PART 19 | fixed-Radius source, 50% grid-width floor, vertical scale, no clipping\n"
        true
        -- return
    )


    /*
    Checks the three SIZE choices, legacy INI migration and table alignment.
    A Scene-unit setting is displayed as metres without changing its saved
    Radius and Length (stored in native 3ds Max system units).
    */
    function partOfTest20 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 20 FAILED: missing generator UI."
        if isProperty dialog_ref #ddl_units or isProperty dialog_ref #lbl_row_dimensions then
            throw "PART 20 FAILED: obsolete units/Dimensions controls remain."
        local expected_units = #("SIZE mm", "SIZE cm", "SIZE m")
        if dialog_ref.ddl_size.Items.Count != 3 then throw "PART 20 FAILED: expected three SIZE units."
        for unit_id = 0 to 2 do
        (
            if (dialog_ref.ddl_size.Items.Item[unit_id] as string) != expected_units[unit_id + 1] then
                throw "PART 20 FAILED: SIZE contents or order incorrect."
        )
        for schema_version in #(0,1,2) do
        (
            for old_index = 0 to 5 do
            (
                local expected_index = if schema_version == 0 then (if old_index >= 1 and old_index <= 3 then old_index - 1 else 2) else (if old_index >= 0 and old_index <= 2 then old_index else 2)
                if (dialog_ref.migrateSpgUnitIndex old_index schema_version) != expected_index then
                    throw "PART 20 FAILED: SIZE migration mismatch."
            )
        )
        if (dialog_ref.getSpgUnitScale 2) != (units.decodeValue "1m") then throw "PART 20 FAILED: metres unit scale."
        if dialog_ref.ddl_size.pos.x >= dialog_ref.ddl_repeat_x.pos.x or dialog_ref.ddl_size.pos.y != dialog_ref.spn_radius.pos.y then
            throw "PART 20 FAILED: SIZE must lead the dimension row."
        if dialog_ref.ddl_arc_segments.pos.x != dialog_ref.ddl_repeat_x.pos.x or dialog_ref.ddl_length_segments.pos.x != dialog_ref.ddl_repeat_y.pos.x then
            throw "PART 20 FAILED: Main Module value columns are not aligned."
        if (dialog_ref.spn_radius.pos.x - 64) != dialog_ref.ddl_repeat_x.pos.x or (dialog_ref.spn_length.pos.x - 64) != dialog_ref.ddl_repeat_y.pos.x then
            throw "PART 20 FAILED: SIZE/Repeat/Subdivision columns differ."
        local default_radius = (units.decodeValue "2500mm")
        local default_length = (units.decodeValue "7000mm")
        if default_radius <= 0.0 or default_length <= default_radius then throw "PART 20 FAILED: invalid physical defaults."
        format "PASS PART 20 | SIZE mm/cm/m, legacy migration and table columns\n"
        true
        -- return
    )


    /*
    Verifies the bounded preview, 32-ID selector, Main Module subdivisions
    and root panel/extrusion controls after the UI opens.
    */
    function partOfTest21 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 21 FAILED: missing owning rollout."
        local dialog_size = getDialogSize dialog_ref
        dialog_ref.resizeLayout dialog_size.y dialog_size.x
        if dialog_ref.dn_grid_host.height != 264 then throw "PART 21 FAILED: Panels grid must be exactly 264px high."
        if dialog_ref.palette_depth_menu != undefined then throw "PART 21 FAILED: old popup should be replaced by shared Extrude controls."
        if dialog_ref.ddl_arc_segments.pos.y != dialog_ref.ddl_length_segments.pos.y or dialog_ref.ddl_arc_segments.pos.y <= dialog_ref.ddl_repeat_x.pos.y then
            throw "PART 21 FAILED: subdivisions must be the final Main Module input row."
        if dialog_ref.grp_panels_setup.pos.y >= dialog_ref.dn_grid_host.pos.y then throw "PART 21 FAILED: panel grid must be directly beneath the Panels header."
        if dialog_ref.dn_grid_host.pos.y >= dialog_ref.lbl_extrude_title.pos.y then throw "PART 21 FAILED: Extrude controls must follow the panel grid."
        if dialog_ref.lbl_row_panels.text != "Grid" then throw "PART 21 FAILED: Panels grid label must read Grid."
        if isProperty dialog_ref #sr_rule_rows then throw "PART 21 FAILED: nested Extrude subrollout still exists."
        if isProperty dialog_ref #ddl_rule_id then throw "PART 21 FAILED: obsolete ID dropdown exists."
        if dialog_ref.ui_tooltip == undefined then throw "PART 21 FAILED: missing WinForms tooltip provider."
        if ((dialog_ref.ui_tooltip.GetToolTip dialog_ref.ddl_rows) as string) == "" or ((dialog_ref.ui_tooltip.GetToolTip dialog_ref.ddl_columns) as string) == "" then
            throw "PART 21 FAILED: Grid row/column dropdowns lack tooltips."
        if ((dialog_ref.ui_tooltip.GetToolTip dialog_ref.btn_cap_generate) as string) == "" then throw "PART 21 FAILED: missing Generate Hatch explanation."
        format "PASS PART 21 | Main Module subdivision/precision row, shared Extrude controls, tooltips\n"
        true
        -- return
    )


    partOfTest17()
    partOfTest18()
    partOfTest19()
    partOfTest20()
    /*
    Verifies full-width root and nested groupboxes, native spinner spacing,
    the single-row nine-swatch palette, and the Material root section.
    */
    function partOfTest22 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 22 FAILED: missing generator UI."
        local dialog_size = getDialogSize dialog_ref
        dialog_ref.resizeLayout dialog_size.y dialog_size.x
        if dialog_ref.spn_radius.pos.x != 178 or dialog_ref.spn_length.pos.x != 258 then
        (
            throw "PART 22 FAILED: main dimension fields are misaligned."
        )
        if dialog_ref.lbl_dimension_radius.text != "RADIUS" or dialog_ref.lbl_dimension_length.text != "LENGTH" then
            throw "PART 22 FAILED: Main Module dimension labels must read RADIUS and LENGTH."
        if (dialog_ref.spn_radius.pos.x - dialog_ref.lbl_dimension_radius.pos.x) != 64 or (dialog_ref.spn_length.pos.x - dialog_ref.lbl_dimension_length.pos.x) != 64 then
            throw "PART 22 FAILED: dimension labels must align with their spinners."
        if dialog_ref.lbl_dimension_radius.pos.y >= dialog_ref.spn_radius.pos.y or dialog_ref.lbl_dimension_length.pos.y >= dialog_ref.spn_length.pos.y then
            throw "PART 22 FAILED: dimension labels must appear above their spinners."
        if dialog_ref.spn_radius.pos.y != dialog_ref.spn_length.pos.y then
            throw "PART 22 FAILED: dimension spinners must share a row."
        if dialog_ref.lbl_dimension_radius.visible != dialog_ref.setup_expanded or dialog_ref.lbl_dimension_length.visible != dialog_ref.setup_expanded then
            throw "PART 22 FAILED: dimension labels must follow Main Module collapse state."
        if dialog_ref.spn_cap_depth.pos.x != (amax 288 dialog_size.x) - 30 then
        (
            throw "PART 22 FAILED: hatch spinners do not follow the dialog right edge."
        )
        -- Every Hatch native spinner shares the same +64px anchor correction.
        -- The Seam count ComboBox must retain its original X position.
        for hatch_spinner in #(dialog_ref.spn_cap_end,dialog_ref.spn_cap_thickness,dialog_ref.spn_cap_depth,dialog_ref.spn_cap_first,dialog_ref.spn_cap_spacing,dialog_ref.spn_cap_chamfer,dialog_ref.spn_cap_chamfer_depth,dialog_ref.spn_cap_inset) do
        (
            if hatch_spinner.pos.x != (dialog_ref.ddl_cap_seams.pos.x + 64) then
                throw "PART 22 FAILED: Hatch native spinner X origin is missing its +64px correction."
        )
        if (dialog_ref.ddl_size.pos.x + dialog_ref.ddl_size.width) > (amax 288 dialog_size.x) then throw "PART 22 FAILED: units clipped."
        if isProperty dialog_ref #ddl_precision or isProperty dialog_ref #lbl_precision then throw "PART 22 FAILED: position precision must remain internal, without UI controls."
        if isProperty dialog_ref #lbl_radius or isProperty dialog_ref #lbl_length or isProperty dialog_ref #lbl_length_divisions then throw "PART 22 FAILED: obsolete Around/Length subdivision labels remain."
        if dialog_ref.lbl_arc_segments.text != "SUBDIVISION" then throw "PART 22 FAILED: subdivision row must have its leading label."
        for compact_dropdown in #(dialog_ref.ddl_repeat_x,dialog_ref.ddl_repeat_y,dialog_ref.ddl_arc_segments,dialog_ref.ddl_length_segments,dialog_ref.ddl_columns,dialog_ref.ddl_rows) do
            if compact_dropdown.width != 58 then throw "PART 22 FAILED: input dropdown width differs from Radius spinner width."
        if dialog_ref.btn_generate.pos.y >= dialog_ref.grp_panels_setup.pos.y then
            throw "PART 22 FAILED: Generate must belong directly to Main Module."
        if dialog_ref.lbl_extrude_title.pos.y <= dialog_ref.dn_id_palette.pos.y then
            throw "PART 22 FAILED: per-ID extrusion controls must follow the ID strip."
        if isProperty dialog_ref #btn_extrude then throw "PART 22 FAILED: redundant Extrude button still exists."
        if dialog_ref.btn_cap_generate.Text != "Generate Hatch" then throw "PART 22 FAILED: .NET Hatch button missing."
        local palette_count = amin 9 SurfacePanelGenerator.rule_depths.count
        if dialog_ref.dn_id_palette.Controls.Count != palette_count then
        (
            throw "PART 22 FAILED: palette count must match nine visible material IDs."
        )
        if dialog_ref.dn_id_palette.AutoScroll or dialog_ref.dn_id_palette.WrapContents then
        (
            throw "PART 22 FAILED: nine palette buttons must fit without wrapping or scrollbars."
        )
        if dialog_ref.dn_id_palette.pos.y <= (dialog_ref.dn_grid_host.pos.y + dialog_ref.dn_grid_host.height) then
        (
            throw "PART 22 FAILED: ID palette must appear below the panel grid."
        )
        local first_color = SurfacePanelGenerator.getPanelColor 1
        local first_button = dialog_ref.dn_id_palette.Controls.Item[0]
        if first_button.BackColor.R != (first_color.r as integer) or first_button.BackColor.G != (first_color.g as integer) or first_button.BackColor.B != (first_color.b as integer) then
        (
            throw "PART 22 FAILED: palette swatches do not match material-ID colours."
        )
        if dialog_ref.dn_grid_host.height != 264 then throw "PART 22 FAILED: Panels grid height differs from 264px."
        local content_width = (amax 288 dialog_size.x) - 36
        if dialog_ref.grp_setup.width != ((amax 288 dialog_size.x) - 12) then throw "PART 22 FAILED: root groupbox does not fill the dialog."
        if dialog_ref.lbl_extrude_title.width != content_width then throw "PART 22 FAILED: inline Extrude heading leaves unused horizontal space."
        if dialog_ref.dn_grid_host.width != content_width or dialog_ref.dn_id_palette.width != content_width then
            throw "PART 22 FAILED: grid or ID slots leave unused panel width."
        if dialog_ref.dn_id_palette.Controls.Count != 9 then throw "PART 22 FAILED: palette must have exactly nine wide ID buttons."
        if dialog_ref.dn_id_palette.height > 30 then throw "PART 22 FAILED: palette must fit on one row."
        for swatch_index = 0 to 8 do
        (
            local swatch = dialog_ref.dn_id_palette.Controls.Item[swatch_index]
            if swatch.Width < 26 or (swatch.Left + swatch.Width) > dialog_ref.dn_id_palette.ClientSize.Width then
                throw "PART 22 FAILED: nine ID buttons must use available palette width without clipping."
        )
        if dialog_ref.grp_material.pos.x != dialog_ref.grp_panels_setup.pos.x or dialog_ref.grp_material.width != dialog_ref.grp_panels_setup.width then
            throw "PART 22 FAILED: Material must be a full-width root section."
        format "PASS PART 22 | full-width groups and grid, one-row nine-swatch palette, Material root\n"
        true
        -- return
    )


    partOfTest21()
    partOfTest22()


    /*
    Verifies palette Tag conversion and both ID selection code paths without
    relying on CLR ToString on a MAXScript integer or string.
    */
    function partOfTest23 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 23 FAILED: missing generator UI."
        if dialog_ref.dn_id_palette.Controls.Count != 9 then throw "PART 23 FAILED: nine material swatches required."
        if (dialog_ref.dn_id_palette.Controls.Item[0].Tag as integer) != 1 then throw "PART 23 FAILED: ID 1 is not the first swatch."
        if (dialog_ref.dn_id_palette.Controls.Item[8].Tag as integer) != 9 then throw "PART 23 FAILED: ID 9 is not the last swatch."


        -- Preserve existing scene/grid data while testing selection and mass edits.
        local original_ids = deepCopy SurfacePanelGenerator.cell_ids
        local original_mask = deepCopy SurfacePanelGenerator.mask
        local original_heights = deepCopy SurfacePanelGenerator.rule_depths
        local original_insets = deepCopy SurfacePanelGenerator.rule_insets
        local original_tapers = deepCopy SurfacePanelGenerator.rule_tapers
        local previous_active = dialog_ref.active_rule_id
        SurfacePanelGenerator.cell_ids[1] = 1
        SurfacePanelGenerator.cell_ids[2] = 2
        dialog_ref.rebuildGrid()


        local first_mask = SurfacePanelGenerator.mask[1]
        local second_mask = SurfacePanelGenerator.mask[2]
        if not (dialog_ref.togglePanelSelection 1) then
            throw "PART 23 FAILED: could not select first grid cell."
        if not (dialog_ref.togglePanelSelection 2) then
            throw "PART 23 FAILED: could not select second grid cell."
        if dialog_ref.selected_cells.numberSet != 2 then throw "PART 23 FAILED: Ctrl selection did not retain two cells."
        if SurfacePanelGenerator.cell_ids[1] != 1 or SurfacePanelGenerator.cell_ids[2] != 2 then
            throw "PART 23 FAILED: selecting cells changed their IDs."
        if SurfacePanelGenerator.mask[1] != first_mask or SurfacePanelGenerator.mask[2] != second_mask then
            throw "PART 23 FAILED: selecting cells changed enabled state."
        if dialog_ref.dn_grid_host.Controls.Item[0].FlatAppearance.BorderSize != 3 then
            throw "PART 23 FAILED: selected cell has no visible outline."


        dialog_ref.activeRuleGeometryChanged #inset 1.5
        if SurfacePanelGenerator.rule_insets[1] != 1.5 or SurfacePanelGenerator.rule_insets[2] != 1.5 then
            throw "PART 23 FAILED: bulk Inset must edit both selected IDs."
        if SurfacePanelGenerator.rule_depths[1] != original_heights[1] or SurfacePanelGenerator.rule_tapers[2] != original_tapers[2] then
            throw "PART 23 FAILED: changing Inset unexpectedly changed Height or Taper."


        dialog_ref.dn_id_palette.Controls.Item[2].PerformClick()
        if dialog_ref.active_rule_id != 3 or SurfacePanelGenerator.cell_ids[1] != 3 or SurfacePanelGenerator.cell_ids[2] != 3 then
            throw "PART 23 FAILED: palette click/forward-declared rebuildGrid did not recolor selected panels."
        if dialog_ref.selected_cells.numberSet != 2 then
            throw "PART 23 FAILED: palette assignment discarded the multi-selection."
        -- Re-click unchanged ID: must persist without undefined saveUiState call.
        dialog_ref.dn_id_palette.Controls.Item[2].PerformClick()
        if SurfacePanelGenerator.cell_ids[1] != 3 or SurfacePanelGenerator.cell_ids[2] != 3 then
            throw "PART 23 FAILED: unchanged palette click modified material IDs."
        if dialog_ref.selected_cells.numberSet != 2 then
            throw "PART 23 FAILED: unchanged palette click cleared selection."


        -- Revert all test mutations and restore the initial paint ID.
        SurfacePanelGenerator.cell_ids = original_ids
        SurfacePanelGenerator.mask = original_mask
        SurfacePanelGenerator.rule_depths = original_heights
        SurfacePanelGenerator.rule_insets = original_insets
        SurfacePanelGenerator.rule_tapers = original_tapers
        dialog_ref.togglePanelSelection 1
        dialog_ref.togglePanelSelection 2
        dialog_ref.active_rule_id = previous_active
        dialog_ref.rebuildGrid()
        dialog_ref.loadActiveRuleControls()
        dialog_ref.updateIdPaletteSelection()
        dialog_ref.saveUiState()
        dialog_ref.refreshBoundModule()
        format "PASS PART 23 | Ctrl selection preserves IDs, mass Inset updates selected IDs, nine palette buttons bulk assign colour\n"
        true
        -- return
    )


    partOfTest23()


    /*
    Connected same-ID panels must extrude as one group; splitting the ID on
    the same two-panel plane adds an internal wall and therefore more faces.
    */
    function partOfTest24 =
    (
        local all_enabled = SurfacePanelGenerator.makeMask 1 8 enabled:false
        all_enabled[1] = true
        all_enabled[2] = true
        local heights = SurfacePanelGenerator.makeRuleDepths 2 5.0
        local thicknesses = SurfacePanelGenerator.makeRuleDepths 2 0.0
        local insets = SurfacePanelGenerator.makeRuleDepths 2 0.0
        local offsets = SurfacePanelGenerator.makeRuleDepths 2 0.0
        local tapers = SurfacePanelGenerator.makeRuleDepths 2 0.0
        local joined_node = SurfacePanelGenerator.generateModule 1 8 all_enabled 100.0 120.0 5.0 1 0.01 cell_ids_value:#(1,1,2,2,2,2,2,2) rule_depths_value:heights rule_thicknesses_value:thicknesses rule_offsets_value:offsets rule_insets_value:insets rule_tapers_value:tapers length_segments:2
        if not isValidNode joined_node then throw "PART 24 FAILED: joined ID generation refused."
        local joined_faces = getTpgTestFaceCount joined_node
        local split_node = SurfacePanelGenerator.generateModule 1 8 all_enabled 100.0 120.0 5.0 1 0.01 cell_ids_value:#(1,2,2,2,2,2,2,2) rule_depths_value:heights rule_thicknesses_value:thicknesses rule_offsets_value:offsets rule_insets_value:insets rule_tapers_value:tapers length_segments:2
        if not isValidNode split_node then throw "PART 24 FAILED: split ID generation refused."
        local split_faces = getTpgTestFaceCount split_node
        if split_faces <= joined_faces then
        (
            format "TPG TEST 24 | joined faces:% split faces:%\n" joined_faces split_faces
            throw "PART 24 FAILED: same-ID neighbours extruded separately."
        )
        if (getUserProp joined_node "SPG_LengthSegments") != "2" then throw "PART 24 FAILED: longitudinal subdivisions not recorded."
        delete joined_node
        delete split_node
        format "PASS PART 24 | connected same-ID extrusion shares a perimeter; length subdivision works\n"
        true
    )
    partOfTest24()


    /*
    Verifies material mode survives a fresh UI reload through the tool INI.
    Restores the previous mode and settings when successful.
    */
    function partOfTest25 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 25 FAILED: missing generator UI."


        local previous_mode = SurfacePanelGenerator.material_mode
        SurfacePanelGenerator.material_mode = #gray
        dialog_ref.saveUiState()
        fileIn (script_dir + "Tank-Panel-Generator.ms")
        if SurfacePanelGenerator.material_mode != #gray then
        (
            format "TPG TEST 25 | expected:#gray actual:%\n" SurfacePanelGenerator.material_mode
            throw "PART 25 FAILED: grey material choice did not survive reload."
        )


        dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 25 FAILED: missing reloaded generator UI."
        SurfacePanelGenerator.material_mode = #multi
        dialog_ref.saveUiState()
        fileIn (script_dir + "Tank-Panel-Generator.ms")
        if SurfacePanelGenerator.material_mode != #multi then
        (
            format "TPG TEST 25 | expected:#multi actual:%\n" SurfacePanelGenerator.material_mode
            throw "PART 25 FAILED: Multi-ID material choice did not survive reload."
        )


        dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 25 FAILED: missing final generator UI."
        SurfacePanelGenerator.material_mode = previous_mode
        dialog_ref.saveUiState()
        format "PASS PART 25 | Grey and Multi-ID choices persist across UI reloads\n"
        true
        -- return
    )
    partOfTest25()


    /*
    Verifies Height/Inset in one row, Taper below and independent Material.
    Confirms the fixed 264px grid and initial physical one-centimetre heights.
    */
    function partOfTest26 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 26 FAILED: owning rollout missing."
        local dialog_size = getDialogSize dialog_ref
        dialog_ref.resizeLayout dialog_size.y dialog_size.x


        if dialog_ref.spn_rule_inset.visible or dialog_ref.spn_rule_height.visible or dialog_ref.spn_rule_taper.visible then
            throw "PART 26 FAILED: obsolete single-ID Extrude spinners remain visible."
        if dialog_ref.native_rule_slots.count != 12 then
            throw "PART 26 FAILED: native per-ID spinner slots are not directly in Panels."
        local used_ids = dialog_ref.getUsedMaterialIds()
        if dialog_ref.native_rule_controls.count != (amin 12 used_ids.count) then
            throw "PART 26 FAILED: visible native spinner page does not match used IDs."
        for row_index = 1 to dialog_ref.native_rule_controls.count do
        (
            local material_id = used_ids[row_index]
            local row_controls = dialog_ref.native_rule_controls[row_index]
            if row_controls[1] != material_id then
                throw "PART 26 FAILED: native row ID does not match the grid."
            if row_controls[2].pos.y <= dialog_ref.dn_id_palette.pos.y then
                throw "PART 26 FAILED: native spinner row is not positioned below the grid palette."
            for field_index = 1 to 3 do
            (
                local field_control = row_controls[field_index + 2]
                if ((classOf field_control) as string) != "SpinnerControl" then
                    throw "PART 26 FAILED: editor is not a native MAXScript spinner."
                local expected_value = case field_index of
                (
                    1: SurfacePanelGenerator.rule_insets[material_id]
                    2: SurfacePanelGenerator.rule_depths[material_id]
                    3: SurfacePanelGenerator.rule_tapers[material_id]
                )
                if field_control.value != expected_value then
                    throw "PART 26 FAILED: native spinner did not retain its exact saved value."
                if field_control.pos.y != row_controls[3].pos.y then
                    throw "PART 26 FAILED: native spinners must share a row."
            )
        )
                if isProperty dialog_ref #spn_rule_thickness or isProperty dialog_ref #spn_rule_offset or isProperty dialog_ref #ddl_depth then
            throw "PART 26 FAILED: redundant Thickness/Depth controls remain."
        if isProperty dialog_ref #grp_output or isProperty dialog_ref #btn_output_toggle then
            throw "PART 26 FAILED: obsolete one-control Generated Object rollout remains."
        if isProperty dialog_ref #ddl_rule_id then
            throw "PART 26 FAILED: obsolete ID dropdown must not exist."
        if (dialog_ref.dn_id_palette.Controls.Item[8].Tag as integer) != 9 then
            throw "PART 26 FAILED: ninth button must be ID 9."


        local new_generator = SurfacePanelGenerator_v()
        local default_height = units.decodeValue "1cm"
        if new_generator.rule_depths[1] != default_height then
        (
            format "TPG TEST 26 | expected default:% actual:%\n" default_height new_generator.rule_depths[1]
            throw "PART 26 FAILED: freshly created IDs must default to one centimetre."
        )
        if dialog_ref.getSpgUnitScale 1 != default_height then
            throw "PART 26 FAILED: centimetre unit scale is incorrect."


        if SurfacePanelGenerator.rule_depths.count < 32 then
            throw "PART 26 FAILED: historical extrusion settings for IDs above nine were discarded."


        local was_expanded = dialog_ref.panels_setup_expanded
        dialog_ref.panels_setup_expanded = false
        dialog_ref.resizeLayout dialog_size.y dialog_size.x
        local root_material_ok = dialog_ref.grp_material.visible and dialog_ref.btn_material_toggle.visible
        dialog_ref.panels_setup_expanded = was_expanded
        dialog_ref.resizeLayout dialog_size.y dialog_size.x
        if not root_material_ok then
            throw "PART 26 FAILED: Material disappeared when Panels was collapsed."


        local old_main = dialog_ref.setup_expanded
        local old_panels = dialog_ref.panels_setup_expanded
        local old_cap = dialog_ref.cap_expanded
        dialog_ref.setup_expanded = true
        dialog_ref.panels_setup_expanded = true
        dialog_ref.cap_expanded = false
        dialog_ref.resizeLayout 1120 dialog_size.x
        local expanded_grid_height = dialog_ref.dn_grid_host.height
        dialog_ref.setup_expanded = old_main
        dialog_ref.panels_setup_expanded = old_panels
        dialog_ref.cap_expanded = old_cap
        dialog_ref.resizeLayout dialog_size.y dialog_size.x
        if expanded_grid_height != 264 then
        (
            format "TPG TEST 26 | preview height:% expected:264\n" expanded_grid_height
            throw "PART 26 FAILED: Panels grid is not exactly 264px high."
        )
        dialog_ref.saveUiState()
        format "PASS PART 26 | inline native Extrude spinners, preserved ID values, 264px grid, 9 swatches\n"
        true
        -- return
    )
    partOfTest26()


    /*
    Changing a grid cell Material ID must keep the existing grid controls.
    The changed cell is repainted in place and its source value is preserved.
    */
    function partOfTest38 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 38 FAILED: generator dialog is missing."
        local original_ids = deepCopy SurfacePanelGenerator.cell_ids
        local original_mask = deepCopy SurfacePanelGenerator.mask
        local original_selection = copy dialog_ref.selected_cells
        local original_active_id = dialog_ref.active_rule_id
        local original_node = SurfacePanelGenerator.last_node
        local original_grid_button = dialog_ref.dn_grid_host.Controls.Item[0]
        local target_id = if original_ids[1] == 1 then 2 else 1
        local test_exception = undefined
        try
        (
            SurfacePanelGenerator.last_node = undefined
            dialog_ref.selected_cells = #{1}
            dialog_ref.paletteButtonClick (dialog_ref.dn_id_palette.Controls.Item[target_id - 1]) undefined
            if SurfacePanelGenerator.cell_ids[1] != target_id then
                throw "PART 38 FAILED: selected cell did not receive the Material ID."
            if dialog_ref.dn_grid_host.Controls.Item[0] != original_grid_button then
                throw "PART 38 FAILED: Material ID click rebuilt the entire grid."
        )
        catch
        (
            test_exception = getCurrentException()
            format "PART 38 ERROR | %\n" test_exception
        )
        SurfacePanelGenerator.cell_ids = original_ids
        SurfacePanelGenerator.mask = original_mask
        SurfacePanelGenerator.last_node = original_node
        dialog_ref.selected_cells = original_selection
        dialog_ref.active_rule_id = original_active_id
        dialog_ref.styleGridButton original_grid_button original_mask[1] original_ids[1] 1
        dialog_ref.updateIdPaletteSelection()
        dialog_ref.updateActiveCount()
        dialog_ref.rebuildMaterialRows()
        dialog_ref.saveUiState()
        if test_exception != undefined then throw test_exception
        format "PASS PART 38 | Material ID painting preserves existing grid control instances\n"
        true
        -- return
    )
    partOfTest38()


    /* Reset must update existing cell controls in place, while preserving
       enabled masks, selections, high-ID rule values and the active brush.
    */
    function partOfTest39 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 39 FAILED: generator dialog missing."
        local original_ids = deepCopy SurfacePanelGenerator.cell_ids
        local original_mask = deepCopy SurfacePanelGenerator.mask
        local original_selection = copy dialog_ref.selected_cells
        local original_active_id = dialog_ref.active_rule_id
        local original_node = SurfacePanelGenerator.last_node
        local original_depths = deepCopy SurfacePanelGenerator.rule_depths
        local first_grid_button = dialog_ref.dn_grid_host.Controls.Item[0]
        local last_grid_button = dialog_ref.dn_grid_host.Controls.Item[SurfacePanelGenerator.cell_ids.count - 1]
        local test_exception = undefined
        try
        (
            SurfacePanelGenerator.last_node = undefined
            SurfacePanelGenerator.cell_ids[1] = 9
            SurfacePanelGenerator.cell_ids[SurfacePanelGenerator.cell_ids.count] = 17
            dialog_ref.active_rule_id = 9
            dialog_ref.selected_cells = #{1}
            dialog_ref.resetGridMaterialIds()
            for material_id in SurfacePanelGenerator.cell_ids do
                if material_id != 1 then throw "PART 39 FAILED: Reset left non-1 Material IDs."
            if SurfacePanelGenerator.mask != original_mask then throw "PART 39 FAILED: Reset changed cell enable states."
            if dialog_ref.selected_cells != #{1} then throw "PART 39 FAILED: Reset changed Ctrl-selection."
            if dialog_ref.active_rule_id != 1 then throw "PART 39 FAILED: Reset did not select ID 1."
            if dialog_ref.dn_grid_host.Controls.Item[0] != first_grid_button or dialog_ref.dn_grid_host.Controls.Item[SurfacePanelGenerator.cell_ids.count - 1] != last_grid_button then
                throw "PART 39 FAILED: Reset rebuilt the grid controls."
            if SurfacePanelGenerator.rule_depths != original_depths then throw "PART 39 FAILED: Reset changed extrusion rules."
            if isProperty dialog_ref #btn_all or isProperty dialog_ref #btn_none then throw "PART 39 FAILED: All/None still exist."
            if not (isProperty dialog_ref #btn_reset) then throw "PART 39 FAILED: Reset button missing."
        )
        catch
        (
            test_exception = getCurrentException()
            format "PART 39 ERROR | %\n" test_exception
        )
        SurfacePanelGenerator.cell_ids = original_ids
        SurfacePanelGenerator.mask = original_mask
        SurfacePanelGenerator.last_node = original_node
        dialog_ref.selected_cells = original_selection
        dialog_ref.active_rule_id = original_active_id
        dialog_ref.updateIdPaletteSelection()
        for cell_id = 1 to SurfacePanelGenerator.cell_ids.count do
            dialog_ref.styleGridButton (dialog_ref.dn_grid_host.Controls.Item[cell_id - 1]) original_mask[cell_id] original_ids[cell_id] cell_id
        dialog_ref.rebuildMaterialRows()
        dialog_ref.saveUiState()
        if test_exception != undefined then throw test_exception
        format "PASS PART 39 | Reset assigns ID 1 without rebuilding grid or changing masks/rules\n"
        true
        -- return
    )
    partOfTest39()


    /* Verifies saved screen coordinates and the registered-bar correction.
       The separate 500ms startup timer reports the measured native offset.
    */
    function partOfTest40 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 40 FAILED: generator dialog missing."
        if dialog_ref.position_restore_correction != [6,29] then
            throw "PART 40 FAILED: expected registered dialog correction [6,29]."
        local saved_probe = [256,229]
        if (dialog_ref.getCorrectedDialogPos saved_probe) != [250,200] then
            throw "PART 40 FAILED: CUI creation position did not subtract the measured offset."
        local actual_pos = getDialogPos dialog_ref
        local settings_file = script_dir + "Tank-Panel-Generator.ini"
        DialogHost.saveDialogPosition dialog_ref settings_file "MainUI"
        local stored_pos = IniSettings.getPoint2 settings_file "MainUI" "PosX" "PosY" default_value:[-1,-1]
        if stored_pos != actual_pos then
            throw "PART 40 FAILED: INI must store the actual registered screen position."
        format "PASS PART 40 | registered dialog saved:% corrected create:%\n" stored_pos (dialog_ref.getCorrectedDialogPos stored_pos)
        true
        -- return
    )
    partOfTest40()


    /*
    Tests a true zero-height grouped inset before extrusion.
    Builds two inspectable fixtures; native inset must add flat rim faces and
    reduce the top face area. Obsolete thickness/offset data must not extrude.
    */
    function partOfTest27 =
    (
        local mask_value = SurfacePanelGenerator.makeMask 1 8 enabled:false
        mask_value[1] = true
        local height_value = units.decodeValue "1cm"
        local inset_value = units.decodeValue "2mm"
        local unused_rule_value = units.decodeValue "20cm"
        local flat_node = undefined
        local inset_node = undefined
        local ignored_node = undefined


        undo "TPG TEST 27 - Flat Source" on
        (
            flat_node = SurfacePanelGenerator.generateModule 1 8 mask_value 100.0 100.0 0.0 1 0.01 rule_depths_value:(SurfacePanelGenerator.makeRuleDepths 8 0.0) rule_insets_value:(SurfacePanelGenerator.makeRuleDepths 8 0.0) rule_tapers_value:(SurfacePanelGenerator.makeRuleDepths 8 0.0)
        )
        if not isValidNode flat_node then throw "PART 27 FAILED: zero-height flat test source could not be created."
        local flat_result = copy flat_node
        convertToPoly flat_result
        local original_face_count = polyop.getNumFaces flat_result.baseObject
        local measured_face = 0
        for face_id = 1 to (polyop.getNumFaces flat_result.baseObject) do
        (
            if (polyop.getFaceMatID flat_result.baseObject face_id) == 1 then measured_face = face_id
        )
        local original_area = polyop.getFaceArea flat_result.baseObject measured_face


        undo "TPG TEST 27 - Group Inset And Height" on
        (
            inset_node = SurfacePanelGenerator.generateModule 1 8 mask_value 100.0 100.0 0.0 1 0.01 rule_depths_value:(SurfacePanelGenerator.makeRuleDepths 8 height_value) rule_insets_value:(SurfacePanelGenerator.makeRuleDepths 8 inset_value) rule_tapers_value:(SurfacePanelGenerator.makeRuleDepths 8 0.0)
        )
        if not isValidNode inset_node then throw "PART 27 FAILED: grouped inset test module could not be created."
        local inset_result = copy inset_node
        convertToPoly inset_result
        local inset_face_count = polyop.getNumFaces inset_result.baseObject
        local inset_area = polyop.getFaceArea inset_result.baseObject measured_face
        if inset_face_count <= (original_face_count + 4) or inset_area >= original_area then
        (
            format "TPG TEST 27 | base faces:% inset faces:% original area:% inset area:%\n" original_face_count inset_face_count original_area inset_area
            throw "PART 27 FAILED: real inset must add a rim and shrink the top before extrusion."
        )


        undo "TPG TEST 27 - Legacy Fields Ignored" on
        (
            ignored_node = SurfacePanelGenerator.generateModule 1 8 mask_value 100.0 100.0 0.0 1 0.01 rule_depths_value:(SurfacePanelGenerator.makeRuleDepths 8 height_value) rule_thicknesses_value:(SurfacePanelGenerator.makeRuleDepths 8 unused_rule_value) rule_offsets_value:(SurfacePanelGenerator.makeRuleDepths 8 unused_rule_value) rule_insets_value:(SurfacePanelGenerator.makeRuleDepths 8 inset_value) rule_tapers_value:(SurfacePanelGenerator.makeRuleDepths 8 0.0)
        )
        if not isValidNode ignored_node then throw "PART 27 FAILED: compatibility fixture could not be created."
        if (getTpgTestFaceCount ignored_node) != (getTpgTestFaceCount inset_node) then
            throw "PART 27 FAILED: legacy Thickness/Depth must not change topology."
        if (getTpgTestVertexCount ignored_node) != (getTpgTestVertexCount inset_node) then
            throw "PART 27 FAILED: legacy Thickness/Depth must not change the extrusion."
        flat_node.pos = [-220,0,0]
        inset_node.pos = [0,0,0]
        ignored_node.pos = [220,0,0]
        format "PASS PART 27 | grouped inset before 1cm extrusion, smaller inset top, ignored legacy Thickness/Depth\n"
        format "UNDO ORDER | 1: Flat Source | 2: Group Inset And Height | 3: Legacy Fields Ignored\n"
        true
        -- return
    )
    partOfTest27()


    /*
    Verifies the grid can reach twice its former maximum height.
    The window remains 288px wide and the grid must be exactly 264px high.
    */
    function partOfTest28 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 28 FAILED: owning rollout not registered."


        local actual_size = getDialogSize dialog_ref
        local old_main = dialog_ref.setup_expanded
        local old_panels = dialog_ref.panels_setup_expanded
        local old_material = dialog_ref.material_expanded
        local old_hatch = dialog_ref.cap_expanded
        dialog_ref.setup_expanded = true
        dialog_ref.panels_setup_expanded = true
        dialog_ref.material_expanded = true
        dialog_ref.cap_expanded = false


        dialog_ref.resizeLayout 1440 288
        local preview_width = dialog_ref.dn_grid_host.width
        local preview_height = dialog_ref.dn_grid_host.height
        local client_width = dialog_ref.dn_grid_host.ClientSize.Width
        local client_height = dialog_ref.dn_grid_host.ClientSize.Height
        local metrics = dialog_ref.getPanelPreviewMetrics()
        local source_size = SurfacePanelGenerator.getUnbentPanelDimensions SurfacePanelGenerator.rows SurfacePanelGenerator.columns (dialog_ref.moduleRadius()) (dialog_ref.moduleLength()) x_multiplier:(dialog_ref.getIntegerDropdown dialog_ref.ddl_repeat_x)


        dialog_ref.setup_expanded = old_main
        dialog_ref.panels_setup_expanded = old_panels
        dialog_ref.material_expanded = old_material
        dialog_ref.cap_expanded = old_hatch
        dialog_ref.resizeLayout actual_size.y actual_size.x


        if preview_width != 252 or preview_height != 264 then
        (
            format "TPG TEST 28 | width:% expected:252 height:% expected:264\n" preview_width preview_height
            throw "PART 28 FAILED: fixed 264px preview area not allocated."
        )
        local physical_grid_width = source_size.x * SurfacePanelGenerator.columns
        local physical_grid_height = source_size.y * SurfacePanelGenerator.rows
        local natural_scale = amin ((client_width as float) / physical_grid_width) ((client_height as float) / physical_grid_height)
        local expected_content_width = amax (physical_grid_width * natural_scale) ((client_width as float) * 0.5)
        if (abs ((metrics[3] * SurfacePanelGenerator.columns) - expected_content_width)) > 0.01 then
            throw "PART 28 FAILED: grid did not enforce 50% minimum content width."
        if (abs (metrics[4] - source_size.y * natural_scale)) > 0.01 then
            throw "PART 28 FAILED: minimum-width rule changed cell height."
        if dialog_ref.dn_grid_host.AutoScroll then throw "PART 28 FAILED: preview must remain without scrollbars."
        format "PASS PART 28 | original dialog width, 264px host height, 50% minimum grid width\n"
        true
        -- return
    )
    partOfTest28()


    /*
    Verifies Repeat Around subdivides the same circumference instead of
    multiplying the final cylinder radius. The source plane is measured
    before its owned Bend modifier is evaluated.
    */
    function partOfTest29 =
    (
        local fixed_radius = 100.0
        local expected_circumference = 2.0 * pi * fixed_radius
        local width_precision = units.decodeValue "0.01mm"
        local previous_node = SurfacePanelGenerator.last_node
        local previous_bend = SurfacePanelGenerator.last_bend_mod
        local test_mask_value = SurfacePanelGenerator.makeMask 2 3 enabled:true


        for repeat_around in #(1,2,4) do
        (
            local generated_node = SurfacePanelGenerator.generateModule 2 3 test_mask_value fixed_radius 200.0 0.0 4 0.01 x_multiplier:repeat_around
            if not isValidNode generated_node then
                throw "PART 29 FAILED: module generation returned no valid node."


            local source_poly = generated_node.baseObject
            local first_position = polyop.getVert source_poly 1
            local x_min = first_position.x
            local x_max = first_position.x
            for vert_id = 2 to (polyop.getNumVerts source_poly) do
            (
                local position_value = polyop.getVert source_poly vert_id
                x_min = amin x_min position_value.x
                x_max = amax x_max position_value.x
            )


            local measured_width = x_max - x_min
            local source_cell = SurfacePanelGenerator.getUnbentPanelDimensions 2 3 fixed_radius 200.0 x_multiplier:repeat_around
            local stored_radius = (getUserProp generated_node "SPG_ExpandedRadius") as float
            local stored_columns = (getUserProp generated_node "SPG_TotalColumns") as integer
            local panel_width = measured_width / (3.0 * repeat_around)


            if (abs (measured_width - expected_circumference)) > width_precision then
            (
                format "TPG TEST 29 | Around:% width:% expected:%\n" repeat_around measured_width expected_circumference
                throw "PART 29 FAILED: repeat around changed flat sheet circumference."
            )
            if source_cell == undefined or (abs (panel_width - source_cell.x)) > width_precision then
                throw "PART 29 FAILED: source panel width did not shrink by repeat count."
            if stored_radius != fixed_radius or stored_columns != (3 * repeat_around) then
                throw "PART 29 FAILED: repeat around changed module radius metadata or lost tiled columns."
            if generated_node.modifiers.count != 2 or (classOf generated_node.modifiers[1]) != TPGExtrusion_v or (classOf generated_node.modifiers[2]) != Bend then
                throw "PART 29 FAILED: 360-degree Bend modifier missing."
            delete generated_node
        )


        SurfacePanelGenerator.last_node = previous_node
        SurfacePanelGenerator.last_bend_mod = previous_bend
        format "PASS PART 29 | unchanged module radius with 1, 2 and 4 Around repeats; source plane rescales\n"
        true
        -- return
    )
    partOfTest29()
    /*
    Exercises disappearing/reappearing IDs with an ID larger than the
    nine-button palette. Confirms the full INI rule arrays restore values.
    Original layout and saved configuration are restored before returning.
    */
    function partOfTest30 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 30 FAILED: no generator dialog."
        local saved_ids = deepCopy SurfacePanelGenerator.cell_ids
        local saved_depths = deepCopy SurfacePanelGenerator.rule_depths
        local saved_insets = deepCopy SurfacePanelGenerator.rule_insets
        local saved_tapers = deepCopy SurfacePanelGenerator.rule_tapers
        local saved_thicknesses = deepCopy SurfacePanelGenerator.rule_thicknesses
        local saved_offsets = deepCopy SurfacePanelGenerator.rule_offsets
        local original_rule_page = dialog_ref.rule_page_index
        local hidden_id = SurfacePanelGenerator.rule_depths.count + 1
        SurfacePanelGenerator.rule_depths = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_depths hidden_id (units.decodeValue "1cm")
        SurfacePanelGenerator.rule_insets = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_insets hidden_id 0.0
        SurfacePanelGenerator.rule_tapers = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_tapers hidden_id 0.0
        SurfacePanelGenerator.rule_thicknesses = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_thicknesses hidden_id 0.0
        SurfacePanelGenerator.rule_offsets = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_offsets hidden_id 0.0
        SurfacePanelGenerator.rule_depths[hidden_id] = 13.5
        SurfacePanelGenerator.rule_insets[hidden_id] = 2.25
        SurfacePanelGenerator.rule_tapers[hidden_id] = -1.5
        SurfacePanelGenerator.cell_ids[1] = hidden_id
        dialog_ref.rebuildMaterialRows force:true
        local hidden_row = findItem (dialog_ref.getUsedMaterialIds()) hidden_id
        if hidden_row == 0 then
            throw "PART 30 FAILED: assigned high ID has no editable row."
        local hidden_page = 1 + ((floor ((hidden_row - 1) / 12.0)) as integer)
        dialog_ref.showMaterialRulePage hidden_page
        local visible_row = hidden_row - ((hidden_page - 1) * 12)
        local height_spinner = dialog_ref.native_rule_controls[visible_row][4]
        local taper_spinner = dialog_ref.native_rule_controls[visible_row][5]
        if height_spinner.value != 13.5 or taper_spinner.value != -1.5 then
            throw "PART 30 FAILED: native spinners must preserve signed/fractional values beyond 0..10."
        if SurfacePanelGenerator.rule_depths[hidden_id] != 13.5 or SurfacePanelGenerator.rule_tapers[hidden_id] != -1.5 then
            throw "PART 30 FAILED: merely showing native spinners must never modify stored geometry values."
        SurfacePanelGenerator.cell_ids = saved_ids
        dialog_ref.rebuildMaterialRows force:true
        dialog_ref.showMaterialRulePage original_rule_page
        if (findItem (dialog_ref.getUsedMaterialIds()) hidden_id) != 0 then
            throw "PART 30 FAILED: unassigned ID row stayed visible."
        dialog_ref.saveUiState()
        local saved_count = IniSettings.getInteger (script_dir + "Tank-Panel-Generator.ini") "MainUI" "RuleCount" default_value:0
        local restored_depths = SurfacePanelGenerator.decodeRuleDepths (IniSettings.getString (script_dir + "Tank-Panel-Generator.ini") "MainUI" "RuleDepths" default_value:"") saved_count 0.0
        local restored_insets = SurfacePanelGenerator.decodeRuleDepths (IniSettings.getString (script_dir + "Tank-Panel-Generator.ini") "MainUI" "RuleInsets" default_value:"") saved_count 0.0
        local restored_tapers = SurfacePanelGenerator.decodeRuleDepths (IniSettings.getString (script_dir + "Tank-Panel-Generator.ini") "MainUI" "RuleTapers" default_value:"") saved_count 0.0
        if saved_count < hidden_id or (abs (restored_depths[hidden_id] - 13.5)) > 0.001 or (abs (restored_insets[hidden_id] - 2.25)) > 0.001 or (abs (restored_tapers[hidden_id] + 1.5)) > 0.001 then
            throw "PART 30 FAILED: hidden per-ID extrusion values were lost in INI."
        SurfacePanelGenerator.rule_depths = saved_depths
        SurfacePanelGenerator.rule_insets = saved_insets
        SurfacePanelGenerator.rule_tapers = saved_tapers
        SurfacePanelGenerator.rule_thicknesses = saved_thicknesses
        SurfacePanelGenerator.rule_offsets = saved_offsets
        SurfacePanelGenerator.cell_ids = saved_ids
        dialog_ref.rebuildMaterialRows force:true
        dialog_ref.saveUiState()
        dialog_ref.fitGridHeightToGeometry()
        format "PASS PART 30 | high-ID rows appear/disappear without losing INI extrusion settings\n"
        true
        -- return
    )
    partOfTest30()


    /* Verify source rows run from negative to positive sheet Y before Bend.
    */
    function partOfTest31 =
    (
        local previous_node = SurfacePanelGenerator.last_node
        local previous_bend = SurfacePanelGenerator.last_bend_mod
        local zero_depths = SurfacePanelGenerator.makeRuleDepths 6 0.0
        local direction_node = undefined
        undo "TPG TEST 31 - Longitudinal Material Order" on
        (
            direction_node = SurfacePanelGenerator.generateModule 2 3 (SurfacePanelGenerator.makeMask 2 3 enabled:true) 100.0 200.0 0.0 2 0.01 x_multiplier:2 length_segments:2 cell_ids_value:#(1,2,3,4,5,6) rule_depths_value:zero_depths
        )
        if not isValidNode direction_node then throw "PART 31 FAILED: direction test module missing."
        local source_poly = direction_node.baseObject
        for face_id = 1 to (polyop.getNumFaces source_poly) do
        (
            local face_ids = polyop.getFaceVerts source_poly face_id
            local center_y = 0.0
            for vertex_id in face_ids do center_y += (polyop.getVert source_poly vertex_id).y
            center_y /= face_ids.count
            local material_id = polyop.getFaceMatID source_poly face_id
            if (material_id <= 3 and center_y >= 0.0) or (material_id >= 4 and center_y <= 0.0) then
            (
                format "TPG TEST 31 FAILED | face:% ID:% sheet Y:% expected IDs 1..3 below zero, 4..6 above zero\n" face_id material_id center_y
                throw "PART 31 FAILED: longitudinal material order is reversed."
            )
        )
        undo "TPG TEST 31 - Remove Direction Test" on (delete direction_node)
        SurfacePanelGenerator.last_node = previous_node
        SurfacePanelGenerator.last_bend_mod = previous_bend
        format "PASS PART 31 | reversed longitudinal ID order with around repeats and subdivisions\n"
        true
        -- return
    )
    partOfTest31()


    /* Signed height and equal taper edge distances on a bent rectangular sector.
    A single sector is planar after Bend, providing an exact geometric oracle.
    */
    function partOfTest32 position_precision_mm =
    (
        local previous_node = SurfacePanelGenerator.last_node
        local previous_bend = SurfacePanelGenerator.last_bend_mod
        local comparison_precision = units.decodeValue ((position_precision_mm as string) + "mm")
        local sector_mask = SurfacePanelGenerator.makeMask 1 8 enabled:false
        sector_mask[1] = true
        local zero_rules = SurfacePanelGenerator.makeRuleDepths 8 0.0
        local reference_node = undefined
        undo "TPG TEST 32 - Bent Reference" on
        (
            reference_node = SurfacePanelGenerator.generateModule 1 8 sector_mask 100.0 1000.0 0.0 1 position_precision_mm length_segments:4 rule_depths_value:zero_rules
        )
        local reference_mesh = snapshotAsMesh reference_node
        local top_faces = #{}
        for candidate_id = 1 to reference_mesh.numfaces do
        (
            if (getFaceMatID reference_mesh candidate_id) == 1 then top_faces[candidate_id] = true
        )
        if top_faces.numberSet == 0 then throw "PART 32 FAILED: missing material ID 1 sector."
        local reference_points = #()
        for face_id in top_faces do
        (
            local face_vertices = meshop.getFace reference_mesh face_id
            for corner_id = 1 to 3 do append reference_points (getVert reference_mesh face_vertices[corner_id])
        )
        delete reference_mesh
        local origin_point = reference_points[1]
        local axis_u = normalize (reference_points[2] - origin_point)
        local normal_value = normalize (cross (reference_points[2] - origin_point) (reference_points[3] - origin_point))
        local axis_v = normalize (cross normal_value axis_u)
        local reference_u = for point_value in reference_points collect (dot (point_value - origin_point) axis_u)
        local reference_v = for point_value in reference_points collect (dot (point_value - origin_point) axis_v)
        for test_height in #(20.0,-20.0) do
        (
            for test_taper in #(2.0,-2.0) do
            (
                for test_inset in #(0.0,3.0) do
                (
                    local height_rules = deepCopy zero_rules
                    local taper_rules = deepCopy zero_rules
                    local inset_rules = deepCopy zero_rules
                    height_rules[1] = test_height
                    taper_rules[1] = test_taper
                    inset_rules[1] = test_inset
                    local result_node = undefined
                    undo "TPG TEST 32 - Post Bend Taper" on
                    (
                        result_node = SurfacePanelGenerator.generateModule 1 8 sector_mask 100.0 1000.0 0.0 1 position_precision_mm length_segments:4 rule_depths_value:height_rules rule_insets_value:inset_rules rule_tapers_value:taper_rules
                    )
                    local result_mesh = snapshotAsMesh result_node
                    local result_u = #()
                    local result_v = #()
                    for face_id in top_faces do for corner_id = 1 to 3 do
                    (
                        local result_face = meshop.getFace result_mesh face_id
                        local point_value = getVert result_mesh result_face[corner_id]
                        append result_u (dot (point_value - origin_point) axis_u)
                        append result_v (dot (point_value - origin_point) axis_v)
                        if abs ((dot (point_value - origin_point) normal_value) - test_height) > comparison_precision then
                            throw "PART 32 FAILED: Height does not follow the bent sector normal."
                    )
                    local expected_outline = test_inset + test_taper
                    local measured_offsets = #((amin result_u)-(amin reference_u),(amax reference_u)-(amax result_u),(amin result_v)-(amin reference_v),(amax reference_v)-(amax result_v))
                    for offset_value in measured_offsets do
                    (
                        if abs (offset_value - expected_outline) > comparison_precision then
                            throw "PART 32 FAILED: unequal taper edge distances after Bend."
                    )
                    delete result_mesh
                    if (polyop.getNumFaces result_node.baseObject) != 32 then throw "PART 32 FAILED: extrusion changed base topology."
                )
            )
        )
        SurfacePanelGenerator.last_node = previous_node
        SurfacePanelGenerator.last_bend_mod = previous_bend
        format "PASS PART 32 | bent sector normals, equal taper distances, signed height/taper and optional inset\n"
        true
        -- return
    )
    partOfTest32 0.01
    /* Verify object data can restore editing without replacing the scene node.
    */
    function partOfTest33 =
    (
        local dialog_ref = undefined
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
        )
        if dialog_ref == undefined then throw "PART 33 FAILED: owning UI missing."
        local saved_depths = SurfacePanelGenerator.makeRuleDepths 12 0.0
        local saved_insets = SurfacePanelGenerator.makeRuleDepths 12 0.0
        local saved_tapers = SurfacePanelGenerator.makeRuleDepths 12 0.0
        saved_depths[12] = 1.2345678
        saved_tapers[12] = -0.125
        local restored_node = undefined
        undo "TPG TEST 33 - Persistent Module" on
        (
            restored_node = SurfacePanelGenerator.generateModule 2 3 #(false,true,false,true,false,true) 100.0 300.0 0.0 2 0.01 x_multiplier:2 y_multiplier:2 length_segments:2 cell_ids_value:#(1,2,3,4,5,12) rule_depths_value:saved_depths rule_insets_value:saved_insets rule_tapers_value:saved_tapers
        )
        if not isValidNode restored_node then throw "PART 33 FAILED: test generation failed."
        local original_handle = getHandleByAnim restored_node
        local original_transform = restored_node.transform
        SurfacePanelGenerator.last_node = undefined
        SurfacePanelGenerator.last_bend_mod = undefined
        local object_data = SurfacePanelGenerator.readModuleData restored_node
        if object_data.rows != 2 or object_data.columns != 3 or object_data.repeat_x != 2 or object_data.repeat_y != 2 then
            throw "PART 33 FAILED: object grid/repeat data mismatch."
        if object_data.mask != #(false,true,false,true,false,true) or object_data.cell_ids != #(1,2,3,4,5,12) then
            throw "PART 33 FAILED: leading-zero mask or cell IDs lost."
        if object_data.rule_depths[12] != saved_depths[12] or object_data.rule_tapers[12] != -0.125 then
            throw "PART 33 FAILED: signed/fractional high-ID rules lost."
        local saved_mask_text = getUserPropVal restored_node "SPG_Mask" asString:true
        setUserProp restored_node "SPG_Mask" "broken"
        local rejected_data = false
        try (SurfacePanelGenerator.readModuleData restored_node) catch
        (
            local exception_text = getCurrentException()
            format "TPG TEST 33 | Expected invalid-data rejection:%\n" exception_text
            rejected_data = true
        )
        setUserProp restored_node "SPG_Mask" saved_mask_text
        if not rejected_data then throw "PART 33 FAILED: invalid object data was accepted."
        local foreign_bend = Bend()
        undo "TPG TEST 33 - Foreign Modifier" on (addModifier restored_node foreign_bend)
        local rejected_stack = false
        try (SurfacePanelGenerator.readModuleData restored_node) catch
        (
            local exception_text = getCurrentException()
            format "TPG TEST 33 | Expected foreign-stack rejection:%\n" exception_text
            rejected_stack = true
        )
        if not rejected_stack or restored_node.modifiers[1] != foreign_bend then
            throw "PART 33 FAILED: foreign stack was accepted or modified."
        undo "TPG TEST 33 - Remove Test Modifier" on (deleteModifier restored_node 1)
        setUserProp restored_node "SPG_DimensionUnit" 0
        local restored_cap = undefined
        undo "TPG TEST 33 - Persistent Hatch" on
        (
            restored_cap = CapHatchGenerator.generateCap restored_node 100.0 600.0 0.0 3.0 5.0 3 5.0 10.0 1.0 0.5 0.0 lathe_segments:64
        )
        if not isValidNode restored_cap then throw "PART 33 FAILED: test Hatch generation failed."
        CapHatchGenerator.last_node = undefined
        CapHatchGenerator.last_lathe_mod = undefined
        CapHatchGenerator.last_chamfer_mod = undefined
        CapHatchGenerator.last_module = undefined
        local saved_cap_end = getUserPropVal restored_cap "SPG_CapEndRadius" asString:true
        setUserProp restored_cap "SPG_CapEndRadius" 1000.0
        if (dialog_ref.loadObjectData restored_node) or SurfacePanelGenerator.last_node != undefined then
            throw "PART 33 FAILED: invalid child Hatch profile changed editor binding."
        setUserProp restored_cap "SPG_CapEndRadius" saved_cap_end
        setUserProp restored_node "SPG_CapSettings" "stale draft"
        if not (dialog_ref.loadObjectData restored_node) then throw "PART 33 FAILED: UI did not load object data."
        if SurfacePanelGenerator.last_node != restored_node or SurfacePanelGenerator.last_bend_mod != restored_node.modifiers[2] then
            throw "PART 33 FAILED: loaded object was not bound to its exact Bend."
        if (getHandleByAnim restored_node) != original_handle or restored_node.transform != original_transform then
            throw "PART 33 FAILED: loading changed the node or its transform."
        if SurfacePanelGenerator.mask != object_data.mask or SurfacePanelGenerator.rule_depths[12] != saved_depths[12] then
            throw "PART 33 FAILED: editor did not restore object rules."
        if dialog_ref.ddl_size.SelectedIndex != 0 or CapHatchGenerator.last_node != restored_cap or CapHatchGenerator.last_module != restored_node then
            throw "PART 33 FAILED: object SIZE or generated child Hatch was not restored."
        dialog_ref.refreshBoundModule()
        if SurfacePanelGenerator.last_node != restored_node or (getHandleByAnim restored_node) != original_handle then
            throw "PART 33 FAILED: continued editing replaced the original node identity."
        format "PASS PART 33 | saved object data, exact rule values, rejected bad data, load and same-node update\n"
        true
        -- return
    )
    partOfTest33()


    /* Legacy one-Bend records migrate only when Generate is requested. */
    function partOfTest34 =
    (
        local legacy_node = undefined
        undo "TPG TEST 34 - Legacy Stack Fixture" on
        (
            legacy_node = SurfacePanelGenerator.generateModule 1 8 (SurfacePanelGenerator.makeMask 1 8 enabled:false) 100.0 200.0 0.0 2 0.01
            deleteModifier legacy_node 1
            setUserProp legacy_node "SPG_DataSchema" 1
            setUserProp legacy_node "SPG_GeneratorVersion" "0.048"
        )
        local original_handle = getHandleByAnim legacy_node
        local saved_data = SurfacePanelGenerator.readModuleData legacy_node
        if legacy_node.modifiers.count != 1 then throw "PART 34 FAILED: loading migrated geometry prematurely."
        undo "TPG TEST 34 - Upgrade Legacy Stack" on
        (
            local updated_node = SurfacePanelGenerator.generateModule saved_data.rows saved_data.columns saved_data.mask saved_data.radius_value saved_data.length_value 0.0 saved_data.arc_segments 0.01 target_node:legacy_node owned_bend:saved_data.bend_mod cell_ids_value:saved_data.cell_ids rule_depths_value:saved_data.rule_depths rule_insets_value:saved_data.rule_insets rule_tapers_value:saved_data.rule_tapers
            if updated_node != legacy_node then throw "PART 34 FAILED: migration replaced scene node identity."
        )
        if (getHandleByAnim legacy_node) != original_handle or legacy_node.modifiers.count != 2 then
            throw "PART 34 FAILED: legacy migration lost identity or new stack."
        local loaded_data = SurfacePanelGenerator.readModuleData legacy_node
        if loaded_data.bend_mod != legacy_node.modifiers[2] then throw "PART 34 FAILED: schema-2 Bend binding wrong."
        undo "TPG TEST 34 - Foreign Edit Poly" on
        (
            deleteModifier legacy_node 1
            addModifier legacy_node (Edit_Poly name:"TPG Extrusion")
        )
        if SurfacePanelGenerator.canReplaceBoundNode legacy_node loaded_data.bend_mod then
            throw "PART 34 FAILED: adopted foreign Edit Poly by name/class."
        format "PASS PART 34 | legacy stack migration preserves node; foreign Edit Poly blocks regeneration\n"
        true
        -- return
    )
    partOfTest34()


    /* Exercise compound operations on short rule selections in a 96-face sheet.
    */
    function partOfTest37 =
    (
        local fixture_node = undefined
        undo "TPG TEST 37 - Full Face Selection Domain" on
        (
            local height_values = #(10.0,-5.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0)
            local inset_values = #(1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0)
            local taper_values = #(1.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0)
            fixture_node = SurfacePanelGenerator.generateModule 4 3 (SurfacePanelGenerator.makeMask 4 3 enabled:true) 100.0 200.0 0.0 8 0.01 rule_depths_value:height_values rule_insets_value:inset_values rule_tapers_value:taper_values
            if not isValidNode fixture_node then throw "PART 37 FAILED: no generated node."
            if fixture_node.modifiers.count != 2 then throw "PART 37 FAILED: modifier stack changed."
            if (polyop.getNumFaces fixture_node.baseObject) != 96 then throw "PART 37 FAILED: expected 96 base faces."
            if (getTpgTestFaceCount fixture_node) <= 192 then throw "PART 37 FAILED: extrusion did not add faces."
        )
        format "PASS PART 37 | 96-face sheet, inset, signed heights, elevated and zero-height taper.\n"
        true
        -- return
    )
    partOfTest37()


    /*
    Confirms that Inset works per logical panel even when every neighbouring
    panel shares the same Material ID. Separate IDs are a topology reference.
    */
    function partOfTest41 =
    (
        local panel_mask = SurfacePanelGenerator.makeMask 3 3 enabled:true
        local shared_ids = #(1,1,1,1,1,1,1,1,1)
        local separate_ids = #(1,2,3,4,5,6,7,8,9)
        local zero_heights = SurfacePanelGenerator.makeRuleDepths 9 0.0
        local inset_rules = SurfacePanelGenerator.makeRuleDepths 9 (units.decodeValue "2mm")
        local shared_node = undefined
        local separate_node = undefined


        undo "TPG TEST 41 - Same Material ID Inset" on
        (
            shared_node = SurfacePanelGenerator.generateModule 3 3 panel_mask 100.0 120.0 0.0 2 0.01 length_segments:2 cell_ids_value:shared_ids rule_depths_value:zero_heights rule_insets_value:inset_rules
        )
        if not isValidNode shared_node then throw "PART 41 FAILED: all-same-ID fixture not generated."


        undo "TPG TEST 41 - Distinct Material ID Inset" on
        (
            separate_node = SurfacePanelGenerator.generateModule 3 3 panel_mask 100.0 120.0 0.0 2 0.01 length_segments:2 cell_ids_value:separate_ids rule_depths_value:zero_heights rule_insets_value:inset_rules
        )
        if not isValidNode separate_node then throw "PART 41 FAILED: distinct-ID fixture not generated."


        local shared_faces = getTpgTestFaceCount shared_node
        local separate_faces = getTpgTestFaceCount separate_node
        local shared_verts = getTpgTestVertexCount shared_node
        local separate_verts = getTpgTestVertexCount separate_node
        if shared_faces != separate_faces or shared_verts != separate_verts then
        (
            format "TPG TEST 41 | same-ID faces:% verts:% distinct-ID faces:% verts:% expected equal\n" shared_faces shared_verts separate_faces separate_verts
            throw "PART 41 FAILED: a same-ID neighbour changed a panel's inset boundary."
        )
        if shared_faces <= 36 then
        (
            format "TPG TEST 41 | inset faces:% expected more than 36 source faces\n" shared_faces
            throw "PART 41 FAILED: inset produced no rim faces."
        )


        shared_node.pos = [-220,0,0]
        separate_node.pos = [220,0,0]
        format "PASS PART 41 | inset topology independent of neighbouring IDs; inspect both fixtures side by side\n"
        format "UNDO ORDER | 1: Same Material ID Inset | 2: Distinct Material ID Inset\n"
        true
        -- return
    )
    partOfTest41()


    /*
    Tests persistent extrusion changes without rebuilding the modifier, sheet or Bend.
    The same owned extrusion instance must survive multiple numeric edits.
    */
    function partOfTest42 =
    (
        local fixture_mask = SurfacePanelGenerator.makeMask 2 2 enabled:true
        local fixture_ids = #(1,2,1,2)
        local initial_heights = SurfacePanelGenerator.makeRuleDepths 2 0.0
        local updated_heights = #(12.0,-4.0)
        local updated_insets = #(1.0,0.5)
        local updated_tapers = #(0.4,0.3)
        local fixture_node = undefined
        undo "TPG TEST 42 - Extrusion Only" on
        (
            fixture_node = SurfacePanelGenerator.generateModule 2 2 fixture_mask 90.0 120.0 0.0 3 0.01 cell_ids_value:fixture_ids rule_depths_value:initial_heights
            if not isValidNode fixture_node then throw "PART 42 FAILED: initial node not generated."
            local original_handle = getHandleByAnim fixture_node
            local original_base = fixture_node.baseObject
            local original_bend = fixture_node.modifiers[2]
            local original_extrusion = fixture_node.modifiers[1]
            local original_base_faces = polyop.getNumFaces original_base
            local update_result = SurfacePanelGenerator.updateExtrusionOnly fixture_node original_bend rule_depths_value:updated_heights rule_insets_value:updated_insets rule_tapers_value:updated_tapers
            if update_result != fixture_node or (getHandleByAnim fixture_node) != original_handle then
                throw "PART 42 FAILED: live update replaced the scene node."
            if fixture_node.baseObject != original_base or fixture_node.modifiers[2] != original_bend then
                throw "PART 42 FAILED: live update rebuilt the base mesh or Bend."
            if fixture_node.modifiers.count != 2 or fixture_node.modifiers[1] != original_extrusion then
                throw "PART 42 FAILED: the TPG Extrusion modifier instance was replaced."
            if (polyop.getNumFaces original_base) != original_base_faces then
                throw "PART 42 FAILED: immutable base topology changed."
            if (getAppData fixture_node.modifiers[1] 1847365210) != "TPG:Extrusion" then
                throw "PART 42 FAILED: persistent extrusion has no ownership marker."
            if (getUserPropVal fixture_node "SPG_RuleDepths" asString:true) != (SurfacePanelGenerator.encodeRuleDepths updated_heights) then
                throw "PART 42 FAILED: object did not persist updated heights."
            local result_mesh = snapshotAsMesh fixture_node
            local extruded_faces = result_mesh.numfaces
            delete result_mesh
            if extruded_faces <= (2 * original_base_faces) then
                throw "PART 42 FAILED: procedural Inset / Height / Taper yielded no geometry."
            local updated_again = #(-2.0,16.0)
            SurfacePanelGenerator.updateExtrusionOnly fixture_node original_bend rule_depths_value:updated_again rule_insets_value:updated_insets rule_tapers_value:updated_tapers
            if fixture_node.modifiers[1] != original_extrusion then
                throw "PART 42 FAILED: a second update changed the extrusion instance."
            local refused_invalid = false
            try
            (
                SurfacePanelGenerator.updateExtrusionOnly fixture_node original_bend rule_depths_value:updated_heights rule_insets_value:#(-1.0,0.5) rule_tapers_value:updated_tapers
            )
            catch
            (
                refused_invalid = true
            )
            if not refused_invalid or fixture_node.baseObject != original_base or fixture_node.modifiers[2] != original_bend or fixture_node.modifiers.count != 2 then
                throw "PART 42 FAILED: invalid update damaged the existing stack."
        )
        format "PASS PART 42 | Height, Inset, Taper update a persistent TPG Extrusion modifier; base/Bend/node identity preserved.\n"
        true
        -- return
    )
    partOfTest42()


    /* Exercises the one-time v0.061 Edit Poly to persistent extrusion migration.
    */
    function partOfTest43 =
    (
        local fixture_node = undefined
        undo "TPG TEST 43 - Legacy Extrusion Migration" on
        (
            local fixture_mask = SurfacePanelGenerator.makeMask 1 2 enabled:true
            local heights_value = #(3.0,5.0)
            fixture_node = SurfacePanelGenerator.generateModule 1 2 fixture_mask 100.0 100.0 0.0 1 0.01 cell_ids_value:#(1,2) rule_depths_value:heights_value
            if not isValidNode fixture_node then throw "PART 43 FAILED: initial fixture generation."
            local saved_base = fixture_node.baseObject
            local saved_bend = fixture_node.modifiers[2]
            local saved_handle = getHandleByAnim fixture_node
            deleteModifier fixture_node 1
            local legacy_extrusion = Edit_Poly name:"TPG Extrusion"
            addModifier fixture_node legacy_extrusion
            setAppData legacy_extrusion 1847365210 "TPG:Extrusion"
            local migrated_node = SurfacePanelGenerator.updateExtrusionOnly fixture_node saved_bend rule_depths_value:#(8.0,1.0)
            if migrated_node != fixture_node or (getHandleByAnim fixture_node) != saved_handle or fixture_node.baseObject != saved_base or fixture_node.modifiers[2] != saved_bend then
                throw "PART 43 FAILED: migration replaced node, base or Bend."
            if fixture_node.modifiers.count != 2 or classOf fixture_node.modifiers[1] != TPGExtrusion_v then
                throw "PART 43 FAILED: legacy Edit Poly was not migrated."
            local persistent_extrusion = fixture_node.modifiers[1]
            SurfacePanelGenerator.updateExtrusionOnly fixture_node saved_bend rule_depths_value:#(1.0,8.0)
            if fixture_node.modifiers[1] != persistent_extrusion then
                throw "PART 43 FAILED: post-migration numeric edit replaced the extrusion modifier."
        )
        format "PASS PART 43 | one-time native Edit Poly migration, then stable extrusion identity.\n"
        true
        -- return
    )
    partOfTest43()


    /* Part 44 retired: its world-Z-only helper hid the real modifier-space bug.
       Parts 47-50 below test complete generation and native reference geometry.
    */


    /* Verifies MeshOp inset on a sloped pair of triangles does not escape the
       source face plane, including corners shared by the two triangles.
    */
    function partOfTest45 =
    (
        local fixture_node = mesh vertices:#(
            [0.0,0.0,0.0],
            [100.0,100.0,0.0],
            [100.0,100.0,200.0],
            [0.0,0.0,200.0]
        ) faces:#([1,2,3],[1,3,4])
        local source_mesh = snapshotAsMesh fixture_node
        delete fixture_node
        local source_positions = #()
        local source_normals = #()
        for face_id = 1 to 2 do
        (
            local triangle = getFace source_mesh face_id
            append source_positions (meshop.getVert source_mesh (triangle.x as integer))
            append source_normals (getFaceNormal source_mesh face_id)
        )
        tpgInsetFaceRegion source_mesh #{1..2} 20.0
        if source_mesh.numfaces <= 2 then
            throw "PART 45 FAILED: inset failed to add rim faces."
        for face_id = 1 to 2 do
        (
            local triangle = getFace source_mesh face_id
            for corner_id = 1 to 3 do
            (
                local inset_position = meshop.getVert source_mesh (triangle[corner_id] as integer)
                local plane_error = abs (dot (inset_position - source_positions[face_id]) source_normals[face_id])
                if plane_error > 0.01 then
                    throw ("PART 45 FAILED: inset corner left the original face plane; face:" + (face_id as string))
            )
        )
        format "PASS PART 45 | planar facet inset retains all top-face vertices on source plane.\n"
        true
        -- return
    )
    partOfTest45()


    /* Tests real triangulated cylinder-facet inset with both side borders.
       Unlike a plane-only test, four endpoint positions must change in XY.
    */
    function partOfTest46 =
    (
        local upper_z = 1166.67
        local lower_z = -1166.67
        local source_positions = #(
            [-866.025,-500.0,upper_z],[-500.0,-133.974,upper_z],[0.0,0.0,upper_z],
            [500.0,-133.974,upper_z],[866.026,-500.0,upper_z],
            [-866.025,-500.0,lower_z],[-500.0,-133.974,lower_z],[0.0,0.0,lower_z],
            [500.0,-133.974,lower_z],[866.026,-500.0,lower_z]
        )
        local source_faces = #()
        for edge_id = 1 to 4 do
        (
            append source_faces [edge_id,edge_id + 1,edge_id + 6]
            append source_faces [edge_id + 6,edge_id + 5,edge_id]
        )
        local fixture_node = mesh vertices:source_positions faces:source_faces
        local source_mesh = snapshotAsMesh fixture_node
        delete fixture_node
        local source_face_vertices = #()
        for face_id = 1 to 8 do append source_face_vertices (getFace source_mesh face_id)
        tpgInsetFaceRegion source_mesh #{1..8} 100.0
        local expected_vertices = #(
            #(1,[-795.3143,-429.2893,1066.67]),
            #(5,[795.3153,-429.2893,1066.67]),
            #(6,[-795.3143,-429.2893,-1066.67]),
            #(10,[795.3153,-429.2893,-1066.67])
        )
        for expected_item in expected_vertices do
        (
            local old_vertex_id = expected_item[1]
            local new_vertex_id = 0
            for face_id = 1 to 8 while new_vertex_id == 0 do
            (
                local old_triangle = source_face_vertices[face_id]
                local new_triangle = getFace source_mesh face_id
                for corner_id = 1 to 3 do
                (
                    if old_triangle[corner_id] == old_vertex_id then
                        new_vertex_id = new_triangle[corner_id]
                )
            )
            if new_vertex_id == 0 then throw "PART 46 FAILED: top vertex correspondence missing."
            local actual_position = meshop.getVert source_mesh new_vertex_id
            if (distance actual_position expected_item[2]) > 0.02 then
                throw ("PART 46 FAILED: side border not inset at original vertex:" + (old_vertex_id as string))
        )
        format "PASS PART 46 | both lateral and axial border edges inset on a faceted cylinder patch.\n"
        true
        -- return
    )
    partOfTest46()


)










/* Runs real generation and persistent-modifier regressions without the legacy UI suite.
   The independent oracle uses the original flat grid and actual bent edge vectors.
*/
global tpgInsetRegressionReport
global runTpgInsetRegression
global TpgInsetRegression_v
struct TpgInsetRegression_v
(
    report = stringStream "",
    position_tolerance = units.decodeValue "0.01mm",
    saved_node = undefined,
    saved_bend = undefined,
    fixtures = #(),
    checked_corners = 0,
    checked_rim_pairs = 0,
    maximum_position_error = 0.0,
    maximum_plane_error = 0.0,


    /* Generates the real sheet/Bend/TPG stack, captures its zero-inset source,
       then updates the SAME extrusion instance through the public editor path.
    */
    function partOfTest47 label_value rows_value columns_value arc_value length_segments_value active_cells inset_values cell_ids_value repeat_x repeat_y rotated_value =
    (
        local fixture_mask = SurfacePanelGenerator.makeMask rows_value columns_value enabled:false
        for cell_id in active_cells do fixture_mask[cell_id] = true
        local zero_values = SurfacePanelGenerator.makeRuleDepths inset_values.count 0.0
        local fixture_node = undefined
        local source_mesh = undefined
        local result_mesh = undefined
        local base_positions = #()
        undo "TPG TEST 47 - Generate Inset Fixture" on
        (
            fixture_node = SurfacePanelGenerator.generateModule rows_value columns_value fixture_mask 1000.0 7000.0 0.0 arc_value 0.01 length_segments:length_segments_value cell_ids_value:cell_ids_value rule_depths_value:zero_values rule_insets_value:inset_values x_multiplier:repeat_x y_multiplier:repeat_y
            fixture_node.name = "TPG_065_TEST_" + label_value
            if rotated_value then rotate fixture_node (eulerAngles 23 37 11)
            local initial_mesh = snapshotAsMesh fixture_node
            SurfacePanelGenerator.updateExtrusionOnly fixture_node fixture_node.modifiers[2] rule_depths_value:zero_values rule_insets_value:zero_values rule_tapers_value:zero_values
            source_mesh = snapshotAsMesh fixture_node
            base_positions = for vertex_id = 1 to source_mesh.numverts collect (polyop.getVert fixture_node.baseObject vertex_id)
            local original_base = fixture_node.baseObject
            local original_bend = fixture_node.modifiers[2]
            local original_extrusion = fixture_node.modifiers[1]
            SurfacePanelGenerator.updateExtrusionOnly fixture_node original_bend rule_depths_value:zero_values rule_insets_value:inset_values rule_tapers_value:zero_values
            if fixture_node.baseObject != original_base or fixture_node.modifiers[2] != original_bend or fixture_node.modifiers[1] != original_extrusion then
                throw ("PART 47 FAILED | identity changed | " + label_value)
            result_mesh = snapshotAsMesh fixture_node
            if initial_mesh.numverts != result_mesh.numverts or initial_mesh.numfaces != result_mesh.numfaces then throw ("PART 47 FAILED | Generate versus update topology | " + label_value)
            for vertex_id = 1 to result_mesh.numverts do
            (
                if distance (getVert initial_mesh vertex_id) (getVert result_mesh vertex_id) > position_tolerance then throw ("PART 47 FAILED | Generate versus update position | " + label_value)
            )
            delete initial_mesh
        )
        append fixtures #(fixture_node,source_mesh,result_mesh,base_positions,inset_values,arc_value,length_segments_value)
        true
        -- return
    ),


    /* Checks every original face corner against an independent grid-edge oracle.
       Checks each rim quad against its source facet and against itself, including winding.
    */
    function partOfTest48 fixture =
    (
        local fixture_node = fixture[1]
        local source_mesh = fixture[2]
        local result_mesh = fixture[3]
        local base_positions = fixture[4]
        local inset_values = fixture[5]
        local region_count = (getUserProp fixture_node "SPG_TotalRows") * (getUserProp fixture_node "SPG_TotalColumns")
        local regions = for cell_id = 1 to region_count collect #{}
        local active_region_count = 0
        for face_id = 1 to source_mesh.numfaces do
        (
            local tag_face = meshop.getMapFace source_mesh 99 face_id
            local cell_tag = meshop.getMapVert source_mesh 99 (tag_face.x as integer)
            local inset_amount = inset_values[getFaceMatID source_mesh face_id]
            if cell_tag.y > 0.5 and inset_amount > 0.0 then regions[cell_tag.x as integer][face_id] = true
            else
            (
                local source_ids = getFace source_mesh face_id
                local result_ids = getFace result_mesh face_id
                for corner_id = 1 to 3 do
                (
                    local position_error = distance (getVert source_mesh (source_ids[corner_id] as integer)) (getVert result_mesh (result_ids[corner_id] as integer))
                    if position_error > position_tolerance then throw ("PART 48 FAILED | inactive face moved | " + fixture_node.name + " face:" + face_id as string)
                )
            )
        )
        for face_region in regions where face_region.numberSet > 0 do
        (
            active_region_count += 1
            local vertex_set = meshop.getVertsUsingFace source_mesh face_region
            local vertex_ids = vertex_set as array
            local first_position = base_positions[vertex_ids[1]]
            local min_x = first_position.x
            local max_x = first_position.x
            local min_y = first_position.y
            local max_y = first_position.y
            for vertex_id in vertex_ids do
            (
                min_x = amin min_x base_positions[vertex_id].x
                max_x = amax max_x base_positions[vertex_id].x
                min_y = amin min_y base_positions[vertex_id].y
                max_y = amax max_y base_positions[vertex_id].y
            )
            local expected_positions = #()
            expected_positions.count = source_mesh.numverts
            local inset_amount = inset_values[getFaceMatID source_mesh ((face_region as array)[1])]
            for vertex_id in vertex_ids do
            (
                local flat_position = base_positions[vertex_id]
                local expected_position = getVert source_mesh vertex_id
                if flat_position.x == min_x or flat_position.x == max_x then
                (
                    local neighbor_id = 0
                    local smallest_step = undefined
                    for other_id in vertex_ids where base_positions[other_id].y == flat_position.y and base_positions[other_id].x != flat_position.x do
                    (
                        local step_value = abs (base_positions[other_id].x - flat_position.x)
                        if smallest_step == undefined or step_value < smallest_step then
                        (
                            smallest_step = step_value
                            neighbor_id = other_id
                        )
                    )
                    expected_position += normalize ((getVert source_mesh neighbor_id) - (getVert source_mesh vertex_id)) * inset_amount
                )
                if flat_position.y == min_y or flat_position.y == max_y then
                (
                    local neighbor_id = 0
                    local smallest_step = undefined
                    for other_id in vertex_ids where base_positions[other_id].x == flat_position.x and base_positions[other_id].y != flat_position.y do
                    (
                        local step_value = abs (base_positions[other_id].y - flat_position.y)
                        if smallest_step == undefined or step_value < smallest_step then
                        (
                            smallest_step = step_value
                            neighbor_id = other_id
                        )
                    )
                    expected_position += normalize ((getVert source_mesh neighbor_id) - (getVert source_mesh vertex_id)) * inset_amount
                )
                expected_positions[vertex_id] = expected_position
            )
            for face_id in face_region do
            (
                local source_ids = getFace source_mesh face_id
                local result_ids = getFace result_mesh face_id
                local source_origin = getVert source_mesh (source_ids.x as integer)
                local source_normal = getFaceNormal source_mesh face_id
                if dot source_normal (getFaceNormal result_mesh face_id) <= 0.0 then throw ("PART 48 FAILED | inverted top face | " + fixture_node.name + " face:" + face_id as string)
                for corner_id = 1 to 3 do
                (
                    local actual_position = getVert result_mesh (result_ids[corner_id] as integer)
                    local expected_position = expected_positions[source_ids[corner_id] as integer]
                    local position_error = distance actual_position expected_position
                    local plane_error = abs (dot (actual_position - source_origin) source_normal)
                    maximum_position_error = amax maximum_position_error position_error
                    maximum_plane_error = amax maximum_plane_error plane_error
                    checked_corners += 1
                    if position_error > position_tolerance or plane_error > position_tolerance then
                    (
                        format "FAIL | % F% corner:% expected:% actual:% position_error:% plane_error:% tolerance:%\n" fixture_node.name face_id corner_id expected_position actual_position position_error plane_error position_tolerance to:report
                        throw ("PART 48 FAILED | source-surface inset | " + fixture_node.name)
                    )
                )
                if (getFaceMatID source_mesh face_id) != (getFaceMatID result_mesh face_id) then throw "PART 48 FAILED | top Material ID changed."
            )
        )
        local expected_faces = source_mesh.numfaces + active_region_count * 4 * (fixture[6] + fixture[7])
        if result_mesh.numfaces != expected_faces then throw ("PART 48 FAILED | missing/extra rim topology | " + fixture_node.name + " actual:" + result_mesh.numfaces as string + " expected:" + expected_faces as string)
        for face_id = source_mesh.numfaces + 1 to result_mesh.numfaces by 2 do
        (
            local first_triangle = getFace result_mesh face_id
            local second_triangle = getFace result_mesh (face_id + 1)
            local rim_vertices = #{}
            for corner_id = 1 to 3 do
            (
                rim_vertices[first_triangle[corner_id] as integer] = true
                rim_vertices[second_triangle[corner_id] as integer] = true
            )
            local original_vertices = for vertex_id in rim_vertices where vertex_id <= source_mesh.numverts collect vertex_id
            if original_vertices.count != 2 or rim_vertices.numberSet != 4 then throw "PART 48 FAILED | rim edge correspondence."
            local source_face_id = 0
            for candidate_id = 1 to source_mesh.numfaces while source_face_id == 0 do
            (
                local candidate_triangle = getFace source_mesh candidate_id
                local candidate_vertices = for corner_id = 1 to 3 collect (candidate_triangle[corner_id] as integer)
                local tag_face = meshop.getMapFace source_mesh 99 candidate_id
                local cell_tag = meshop.getMapVert source_mesh 99 (tag_face.x as integer)
                if (findItem candidate_vertices original_vertices[1]) > 0 and (findItem candidate_vertices original_vertices[2]) > 0 and cell_tag.y > 0.5 and (getFaceMatID source_mesh candidate_id) == (getFaceMatID result_mesh face_id) then
                (
                    local candidate_normal = getFaceNormal source_mesh candidate_id
                    local candidate_origin = getVert source_mesh original_vertices[1]
                    local all_on_plane = true
                    for vertex_id in rim_vertices do
                    (
                        if abs (dot ((getVert result_mesh vertex_id) - candidate_origin) candidate_normal) > position_tolerance then all_on_plane = false
                    )
                    if all_on_plane then source_face_id = candidate_id
                )
            )
            if source_face_id == 0 then throw ("PART 48 FAILED | rim left source facet | " + fixture_node.name + " face:" + face_id as string)
            local first_normal = getFaceNormal result_mesh face_id
            local second_normal = getFaceNormal result_mesh (face_id + 1)
            local source_normal = getFaceNormal source_mesh source_face_id
            if dot first_normal source_normal <= 0.0 or dot second_normal source_normal <= 0.0 then throw ("PART 48 FAILED | degenerate/inverted rim | " + fixture_node.name + " face:" + face_id as string)
            local rim_origin = getVert result_mesh (first_triangle.x as integer)
            for vertex_id in rim_vertices do
            (
                local plane_error = abs (dot ((getVert result_mesh vertex_id) - rim_origin) first_normal)
                maximum_plane_error = amax maximum_plane_error plane_error
                if plane_error > position_tolerance then throw ("PART 48 FAILED | twisted rim quad | " + fixture_node.name + " face:" + face_id as string)
            )
            if (getFaceMatID result_mesh face_id) != (getFaceMatID result_mesh (face_id + 1)) then throw "PART 48 FAILED | rim Material ID mismatch."
            checked_rim_pairs += 1
        )
        format "PASS | % | source:%v/%f result:%v/%f panels:%\n" fixture_node.name source_mesh.numverts source_mesh.numfaces result_mesh.numverts result_mesh.numfaces active_region_count to:report
        true
        -- return
    ),


    /* Confirms signed Height and Taper still evaluate, followed by an exact
       return to the inset-only result on the same modifier, base and Bend.
    */
    function partOfTest49 =
    (
        local fixture = fixtures[1]
        local fixture_node = fixture[1]
        local extrusion_mod = fixture_node.modifiers[1]
        local bend_mod = fixture_node.modifiers[2]
        local base_object = fixture_node.baseObject
        undo "TPG TEST 49 - Height Taper Round Trip" on
        (
            for height_value in #(50.0,-50.0) do
            (
                SurfacePanelGenerator.updateExtrusionOnly fixture_node bend_mod rule_depths_value:#(0.0,height_value,0.0) rule_insets_value:#(0.0,100.0,100.0) rule_tapers_value:#(0.0,5.0,0.0)
                local elevated_mesh = snapshotAsMesh fixture_node
                if elevated_mesh.numfaces <= fixture[3].numfaces then throw "PART 49 FAILED | Height/Taper added no walls."
                delete elevated_mesh
            )
            SurfacePanelGenerator.updateExtrusionOnly fixture_node bend_mod rule_depths_value:#(0.0,0.0,0.0) rule_insets_value:#(0.0,100.0,100.0) rule_tapers_value:#(0.0,0.0,0.0)
        )
        if fixture_node.modifiers[1] != extrusion_mod or fixture_node.modifiers[2] != bend_mod or fixture_node.baseObject != base_object then throw "PART 49 FAILED | modifier/base identity changed."
        local restored_mesh = snapshotAsMesh fixture_node
        if restored_mesh.numverts != fixture[3].numverts or restored_mesh.numfaces != fixture[3].numfaces then throw "PART 49 FAILED | restored topology changed."
        for vertex_id = 1 to restored_mesh.numverts do
        (
            if distance (getVert restored_mesh vertex_id) (getVert fixture[3] vertex_id) > position_tolerance then throw "PART 49 FAILED | accumulated geometry drift."
        )
        delete restored_mesh
        format "PASS | signed Height/Taper round trip; persistent node/base/Bend/extrusion identity\n" to:report
        true
        -- return
    ),


    /* Compares the reported case to native Edit Poly Group Inset, the operation
       used by the inspected Inset Faces reference, without depending on its path.
    */
    function partOfTest50 =
    (
        local previous_selection = selection as array
        local previous_mode = getCommandPanelTaskMode()
        local previous_level = subObjectLevel
        local previous_current = modPanel.getCurrentObject()
        local reference_node = undefined
        local reference_mesh = undefined
        local native_exception = undefined
        try
        (
            undo "TPG TEST 50 - Native Inset Reference" on
            (
                reference_node = copy fixtures[1][1]
                reference_node.name = "TPG_065_TEST_native_reference"
                deleteModifier reference_node 1
                local native_inset = Edit_Poly()
                addModifier reference_node native_inset
                select reference_node
                setCommandPanelTaskMode #modify
                modPanel.setCurrentObject native_inset
                subObjectLevel = 4
                native_inset.SetEPolySelLevel #Face
                local polygon_selection = #{}
                polygon_selection.count = native_inset.GetNumFaces node:reference_node
                for face_id = 1 to polygon_selection.count do
                (
                    if native_inset.GetFaceMaterial face_id node:reference_node == 2 then polygon_selection[face_id] = true
                )
                native_inset.SetSelection #Face polygon_selection node:reference_node
                native_inset.animationMode = 1
                native_inset.insetType = 0
                native_inset.insetAmount = 100.0
                native_inset.SetOperation #Inset
                reference_mesh = snapshotAsMesh reference_node
            )
        )
        catch
        (
            native_exception = getCurrentException()
        )
        subObjectLevel = 0
        select previous_selection
        setCommandPanelTaskMode previous_mode
        if previous_mode == #modify and previous_current != undefined then modPanel.setCurrentObject previous_current
        subObjectLevel = previous_level
        if native_exception != undefined then throw native_exception
        local actual_mesh = fixtures[1][3]
        if reference_mesh.numverts != actual_mesh.numverts or reference_mesh.numfaces != actual_mesh.numfaces then
            throw ("PART 50 FAILED | native counts:" + reference_mesh.numverts as string + "/" + reference_mesh.numfaces as string + " TPG counts:" + actual_mesh.numverts as string + "/" + actual_mesh.numfaces as string)
        local matched_vertices = #{}
        local maximum_reference_error = 0.0
        for vertex_id = 1 to actual_mesh.numverts do
        (
            local actual_position = getVert actual_mesh vertex_id
            local nearest_id = 0
            local nearest_distance = undefined
            for reference_id = 1 to reference_mesh.numverts where not matched_vertices[reference_id] do
            (
                local candidate_distance = distance actual_position (getVert reference_mesh reference_id)
                if nearest_distance == undefined or candidate_distance < nearest_distance then
                (
                    nearest_id = reference_id
                    nearest_distance = candidate_distance
                )
            )
            if nearest_id == 0 or nearest_distance > position_tolerance then
                throw ("PART 50 FAILED | native position mismatch vertex:" + vertex_id as string + " distance:" + nearest_distance as string + " tolerance:" + position_tolerance as string)
            matched_vertices[nearest_id] = true
            maximum_reference_error = amax maximum_reference_error nearest_distance
        )
        format "PASS | native Group Inset reference | %v/%f maximum vertex difference:%\n" reference_mesh.numverts reference_mesh.numfaces maximum_reference_error to:report
        delete reference_mesh
        true
        -- return
    ),


    /* Executes the numbered integration stages and restores generator bindings.
       Leaves all regression fixture nodes in the scene for visual inspection.
    */
    function runTests =
    (
    saved_node = SurfacePanelGenerator.last_node
    saved_bend = SurfacePanelGenerator.last_bend_mod
    try
    (
        -- Explicit execution queue: generate, validate, then exercise numeric edits.
        partOfTest47 "reported" 4 3 4 1 #{1..12} #(0.0,100.0,100.0) #(1,1,1,1,1,1,1,2,1,1,1,1) 1 1 false
        partOfTest47 "open_corners" 4 3 4 2 #{1,12} #(65.0) (for cell_id = 1 to 12 collect 1) 1 1 false
        partOfTest47 "adjacent_same_id" 3 3 4 2 #{4,5,7,8} #(80.0) (for cell_id = 1 to 9 collect 1) 1 1 false
        partOfTest47 "adjacent_mixed_ids" 3 4 3 3 #{1..12} #(25.0,90.0) (for cell_id = 1 to 12 collect (1 + mod cell_id 2)) 1 1 false
        partOfTest47 "all_panels" 2 5 3 3 #{1..10} #(30.0) (for cell_id = 1 to 10 collect 1) 1 1 false
        partOfTest47 "single_open_seam" 1 1 12 3 #{1} #(100.0) #(1) 1 1 false
        partOfTest47 "repeated_grid" 2 3 2 2 #{1,2,6} #(40.0) #(1,1,1,1,1,1) 2 2 false
        partOfTest47 "rotated_node" 3 4 5 2 #{2,3,6,7,10,11} #(15.25) (for cell_id = 1 to 12 collect 1) 1 1 true
        for fixture in fixtures do partOfTest48 fixture
        partOfTest49()
        partOfTest50()
        format "TOTAL | fixtures:% top corners:% rim pairs:% max_position_error:% max_plane_error:% tolerance:%\n" fixtures.count checked_corners checked_rim_pairs maximum_position_error maximum_plane_error position_tolerance to:report
        format "UNDO ORDER | eight TPG TEST 47 generation/update entries, then TPG TEST 49 Height/Taper round trip, then TPG TEST 50 native reference. Fixtures remain for inspection.\n" to:report
    )
    catch
    (
        local exception_text = getCurrentException()
        SurfacePanelGenerator.last_node = saved_node
        SurfacePanelGenerator.last_bend_mod = saved_bend
        format "%\n" exception_text to:report
        tpgInsetRegressionReport = report as string
        format "%" tpgInsetRegressionReport
        throw()
    )
    SurfacePanelGenerator.last_node = saved_node
    SurfacePanelGenerator.last_bend_mod = saved_bend
    tpgInsetRegressionReport = report as string
    format "%" tpgInsetRegressionReport
    tpgInsetRegressionReport
    -- return
    )
)


/* Creates isolated test state and returns the complete runtime report.
   The fixture geometry is deliberately retained in the current scene.
*/
function runTpgInsetRegression =
(
    local regression = TpgInsetRegression_v()
    regression.runTests()
)


-- Explicit integration execution queue.
if TPG_NormalRegressionOnly != true and TPG_SeamsRegressionOnly != true and TPG_TaperSpacingRegressionOnly != true and TPG_LengthSubdivisionRegressionOnly != true and TPG_HatchRegressionOnly != true and TPG_BentWeldRegressionOnly != true and TPG_ThicknessSeamRegressionOnly != true and TPG_HatchOptionsRegressionOnly != true then runTpgInsetRegression()


/* Full-pipeline local normals regressions; no production helper computes the oracle.
   Set TPG_NormalRegressionOnly = true before loading this file to run Parts 51-54.
*/
global TpgNormalRegression_v
global runTpgNormalRegression
struct TpgNormalRegression_v
(
    fixtures = #(),
    position_tolerance = units.decodeValue "0.01mm",
    maximum_error = 0.0,
    checked_corners = 0,


    /* Generate a real module and exercise mode changes on its existing modifier.
    */
    function partOfTest51 label_value rows_value columns_value arc_value length_value active_cells inset_value height_value taper_value bent_value =
    (
        local fixture_mask = SurfacePanelGenerator.makeMask rows_value columns_value enabled:true
        local cell_ids = for cell_id = 1 to (rows_value * columns_value) collect (if active_cells[cell_id] then 3 else 1)
        local zero_values = #(0.0,0.0,0.0)
        local inset_values = #(0.0,0.0,inset_value)
        local height_values = #(0.0,0.0,height_value)
        local taper_values = #(0.0,0.0,taper_value)
        local fixture_node = undefined
        local source_mesh = undefined
        local inset_mesh = undefined
        local result_mesh = undefined
        local untapered_mesh = undefined
        undo "TPG TEST 51 - Local Normals Fixture" on
        (
            fixture_node = SurfacePanelGenerator.generateModule rows_value columns_value fixture_mask 1000.0 5000.0 0.0 arc_value 0.01 length_segments:length_value cell_ids_value:cell_ids rule_depths_value:zero_values rule_insets_value:zero_values rule_tapers_value:zero_values extrusion_mode_value:#group
            fixture_node.name = "TPG_073_TEST_" + label_value
            local original_base = fixture_node.baseObject
            local original_bend = fixture_node.modifiers[2]
            local original_extrusion = fixture_node.modifiers[1]
            original_bend.enabled = bent_value
            source_mesh = snapshotAsMesh fixture_node
            SurfacePanelGenerator.updateExtrusionOnly fixture_node original_bend rule_depths_value:zero_values rule_insets_value:inset_values rule_tapers_value:zero_values extrusion_mode_value:#local
            inset_mesh = snapshotAsMesh fixture_node
            SurfacePanelGenerator.updateExtrusionOnly fixture_node original_bend rule_depths_value:height_values rule_insets_value:inset_values rule_tapers_value:taper_values extrusion_mode_value:#local
            result_mesh = snapshotAsMesh fixture_node
            if taper_value != 0.0 then
            (
                SurfacePanelGenerator.updateExtrusionOnly fixture_node original_bend rule_tapers_value:zero_values
                untapered_mesh = snapshotAsMesh fixture_node
                SurfacePanelGenerator.updateExtrusionOnly fixture_node original_bend rule_tapers_value:taper_values
            )
            if fixture_node.baseObject != original_base or fixture_node.modifiers[1] != original_extrusion or fixture_node.modifiers[2] != original_bend then
                throw ("PART 51 FAILED | modifier/base identity changed: " + label_value)
            if (SurfacePanelGenerator.readModuleData fixture_node).extrusion_mode != #local then
                throw ("PART 51 FAILED | stored mode expected #local: " + label_value)
        )
        append fixtures #(fixture_node,source_mesh,inset_mesh,result_mesh,height_value,taper_value,untapered_mesh)
        true
        -- return
    ),


    /* Check signed facet offsets and minimum-length corner displacement independently.
       The two most divergent incident selected facet normals define each cylindrical seam.
    */
    function partOfTest52 fixture =
    (
        local fixture_node = fixture[1]
        local raw_mesh = fixture[2]
        local source_mesh = fixture[3]
        local result_mesh = fixture[4]
        local height_value = fixture[5]
        local taper_value = fixture[6]
        if taper_value != 0.0 then
        (
            local untapered_mesh = fixture[7]
            if result_mesh.numverts != untapered_mesh.numverts then throw "PART 52 FAILED | taper changed vertex count."
            local maximum_taper_movement = 0.0
            for vertex_id = 1 to result_mesh.numverts do
                maximum_taper_movement = amax maximum_taper_movement (distance (getVert result_mesh vertex_id) (getVert untapered_mesh vertex_id))
            if maximum_taper_movement <= position_tolerance then
            (
                format "PART 52 FAILED | taper:% movement:% required greater than:%\n" taper_value maximum_taper_movement position_tolerance
                throw "TPG Local normals ignored nonzero taper."
            )
        )
        local normals_by_vertex = #()
        normals_by_vertex.count = source_mesh.numverts
        for face_id = 1 to raw_mesh.numfaces where (getFaceMatID raw_mesh face_id) == 3 do
        (
            local triangle_ids = getFace source_mesh face_id
            local face_normal = getFaceNormal source_mesh face_id
            for corner_id = 1 to 3 do
            (
                local vertex_id = triangle_ids[corner_id] as integer
                if normals_by_vertex[vertex_id] == undefined then normals_by_vertex[vertex_id] = #()
                append normals_by_vertex[vertex_id] face_normal
            )
        )
        for face_id = 1 to raw_mesh.numfaces do
        (
            local source_ids = getFace source_mesh face_id
            local result_ids = getFace result_mesh face_id
            local active_face = (getFaceMatID raw_mesh face_id) == 3
            if (getFaceMatID result_mesh face_id) != (getFaceMatID raw_mesh face_id) then
                throw ("PART 52 FAILED | top Material ID changed: " + fixture_node.name)
            for corner_id = 1 to 3 do
            (
                local source_id = source_ids[corner_id] as integer
                local source_position = getVert source_mesh source_id
                local result_position = getVert result_mesh (result_ids[corner_id] as integer)
                local expected_position = source_position
                if active_face and taper_value == 0.0 then
                (
                    local incident_normals = normals_by_vertex[source_id]
                    local first_normal = incident_normals[1]
                    local second_normal = first_normal
                    local minimum_dot = dot first_normal second_normal
                    for normal_a in incident_normals do
                    (
                        for normal_b in incident_normals do
                        (
                            local pair_dot = dot normal_a normal_b
                            if pair_dot < minimum_dot then
                            (
                                minimum_dot = pair_dot
                                first_normal = normal_a
                                second_normal = normal_b
                            )
                        )
                    )
                    expected_position += (first_normal + second_normal) * (height_value / (1.0 + minimum_dot))
                )
                if not active_face or taper_value == 0.0 then
                (
                    local position_error = distance expected_position result_position
                    maximum_error = amax maximum_error position_error
                    checked_corners += 1
                    if position_error > position_tolerance then
                    (
                        format "PART 52 FAILED | % F% corner:% expected:% actual:% error:% tolerance:%\n" fixture_node.name face_id corner_id expected_position result_position position_error position_tolerance
                        throw "TPG Local normals does not match the independent facet-offset oracle."
                    )
                )
                if active_face then
                (
                    local plane_error = abs ((dot (result_position - source_position) (getFaceNormal source_mesh face_id)) - height_value)
                    if plane_error > position_tolerance then
                    (
                        format "PART 52 FAILED | % F% height:% plane error:% tolerance:%\n" fixture_node.name face_id height_value plane_error position_tolerance
                        throw "TPG Local normals lost its signed facet distance."
                    )
                )
            )
        )
        if result_mesh.numfaces <= source_mesh.numfaces then throw ("PART 52 FAILED | extrusion added no walls: " + fixture_node.name)
        for face_id = raw_mesh.numfaces + 1 to result_mesh.numfaces do
        (
            if (getFaceMatID result_mesh face_id) != 3 then throw ("PART 52 FAILED | wall/rim Material ID expected 3: " + fixture_node.name)
        )
        format "PASS PART 52 | % | checked corners:% maximum error:%\n" fixture_node.name checked_corners maximum_error
        true
        -- return
    ),


    /* Verify legacy fallback, reversible modes and generation/update equivalence.
    */
    function partOfTest53 =
    (
        local fixture = fixtures[1]
        local fixture_node = fixture[1]
        local local_mesh = fixture[4]
        undo "TPG TEST 53 - Mode Round Trip" on
        (
            local owned_extrusion = fixture_node.modifiers[1]
            SurfacePanelGenerator.updateExtrusionOnly fixture_node fixture_node.modifiers[2] extrusion_mode_value:#group
            local group_mesh = snapshotAsMesh fixture_node
            local maximum_mode_difference = 0.0
            for vertex_id = 1 to group_mesh.numverts do maximum_mode_difference = amax maximum_mode_difference (distance (getVert group_mesh vertex_id) (getVert local_mesh vertex_id))
            if maximum_mode_difference <= position_tolerance then throw "PART 53 FAILED | Group and Local unexpectedly identical on the curved reference."
            deleteUserProp fixture_node "SPG_ExtrusionMode"
            if (SurfacePanelGenerator.readModuleData fixture_node).extrusion_mode != #group then throw "PART 53 FAILED | legacy object did not default to Group."
            owned_extrusion.refresh_counter += 1
            local legacy_mesh = snapshotAsMesh fixture_node
            for vertex_id = 1 to group_mesh.numverts do
            (
                if distance (getVert group_mesh vertex_id) (getVert legacy_mesh vertex_id) > position_tolerance then throw "PART 53 FAILED | legacy Group geometry changed."
            )
            SurfacePanelGenerator.updateExtrusionOnly fixture_node fixture_node.modifiers[2] extrusion_mode_value:#local
            local restored_mesh = snapshotAsMesh fixture_node
            for vertex_id = 1 to local_mesh.numverts do
            (
                if distance (getVert restored_mesh vertex_id) (getVert local_mesh vertex_id) > position_tolerance then throw "PART 53 FAILED | Local mode round trip changed geometry."
            )
            if fixture_node.modifiers[1] != owned_extrusion then throw "PART 53 FAILED | mode switch replaced extrusion."
            local direct_node = SurfacePanelGenerator.generateModule 3 3 (SurfacePanelGenerator.makeMask 3 3) 1000.0 5000.0 0.0 2 0.01 cell_ids_value:#(1,1,1,1,3,1,1,1,1) rule_depths_value:#(0.0,0.0,100.0) extrusion_mode_value:#local
            direct_node.name = "TPG_073_TEST_direct_local"
            local direct_mesh = snapshotAsMesh direct_node
            if direct_mesh.numverts != local_mesh.numverts or direct_mesh.numfaces != local_mesh.numfaces then throw "PART 53 FAILED | direct generation topology differs."
            for vertex_id = 1 to local_mesh.numverts do
            (
                if distance (getVert direct_mesh vertex_id) (getVert local_mesh vertex_id) > position_tolerance then throw "PART 53 FAILED | direct generation position differs."
            )
        )
        format "PASS PART 53 | defaults, mode round trip, modifier identity, direct generation.\n"
        true
        -- return
    ),


    /* Exercise scoped preset mode persistence in an isolated temporary INI.
    */
    function partOfTest54 =
    (
        local temp_ini = (getDir #temp) + "\\TPG_NormalRegression_" + (timeStamp() as string) + ".ini"
        local preset_manager = TPGPresetManager_v ini_path:temp_ini main_section:"MainUI"
        setINISetting temp_ini "MainUI" "ExtrusionMode" "Local"
        preset_manager.savePreset "Local fixture"
        setINISetting temp_ini "MainUI" "ExtrusionMode" "Group"
        preset_manager.loadPreset "Local fixture" mode:#panels
        if getINISetting temp_ini "MainUI" "ExtrusionMode" != "Group" then throw "PART 54 FAILED | Panels changed extrusion mode."
        preset_manager.loadPreset "Local fixture" mode:#hatch
        if getINISetting temp_ini "MainUI" "ExtrusionMode" != "Group" then throw "PART 54 FAILED | Hatch changed extrusion mode."
        preset_manager.loadPreset "Local fixture" mode:#extrude
        if getINISetting temp_ini "MainUI" "ExtrusionMode" != "Local" then throw "PART 54 FAILED | Extrude did not load Local."
        local preset_id = preset_manager.findPresetId "Local fixture"
        delINISetting temp_ini (preset_manager.presetSection preset_id) "ExtrusionMode"
        preset_manager.loadPreset "Local fixture" mode:#all
        if getINISetting temp_ini "MainUI" "ExtrusionMode" != "Group" then throw "PART 54 FAILED | old preset did not default to Group."
        deleteFile temp_ini
        format "PASS PART 54 | scoped preset persistence and legacy fallback.\n"
        true
        -- return
    ),


    /* Execute fixtures without touching user nodes; preserve the editor binding.
    */
    function runTests =
    (
        local saved_node = SurfacePanelGenerator.last_node
        local saved_bend = SurfacePanelGenerator.last_bend_mod
        try
        (
            partOfTest51 "reference" 3 3 2 1 #{5} 0.0 100.0 0.0 true
            partOfTest51 "negative" 3 3 2 1 #{5} 0.0 -100.0 0.0 true
            partOfTest51 "flat" 3 3 2 1 #{5} 0.0 100.0 0.0 false
            partOfTest51 "adjacent" 3 3 4 2 #{4,5,7,8} 0.0 37.25 0.0 true
            partOfTest51 "inset" 4 3 4 2 #{1,5,6,12} 65.0 50.0 0.0 true
            partOfTest51 "taper" 3 3 4 2 #{5} 30.0 50.0 10.0 true
            for fixture in fixtures do partOfTest52 fixture
            partOfTest53()
            partOfTest54()
        )
        catch
        (
            local exception_text = getCurrentException()
            SurfacePanelGenerator.last_node = saved_node
            SurfacePanelGenerator.last_bend_mod = saved_bend
            format "TPG NORMAL REGRESSION FAILED | %\n" exception_text
            throw exception_text
        )
        SurfacePanelGenerator.last_node = saved_node
        SurfacePanelGenerator.last_bend_mod = saved_bend
        format "TPG NORMAL REGRESSION PASS | fixtures:% corners:% maximum error:% tolerance:%\n" fixtures.count checked_corners maximum_error position_tolerance
        format "UNDO ORDER | six TPG TEST 51 fixture entries, then TPG TEST 53 mode round trip. Test objects remain for inspection.\n"
        true
        -- return
    ),
    on create do ()
)


/* Run the complete Local normals regression independently of the legacy suite.
*/
function runTpgNormalRegression =
(
    local regression = TpgNormalRegression_v()
    regression.runTests()
    -- return
)


TPG_NormalRegressionOnly = false
if not TPG_SkipNormalRegression and TPG_SeamsRegressionOnly != true and TPG_TaperSpacingRegressionOnly != true and TPG_LengthSubdivisionRegressionOnly != true and TPG_HatchRegressionOnly != true and TPG_BentWeldRegressionOnly != true and TPG_ThicknessSeamRegressionOnly != true and TPG_HatchOptionsRegressionOnly != true then runTpgNormalRegression()
TPG_SkipNormalRegression = false


/*
Regression: native Seams Chamfer below Bend and finishing Chamfer at the top.
Both are evaluated with procedural extrusion ENABLED; no display-name matching.
*/
function runTpgSeamsChamferRegression =
(
    local saved_node = SurfacePanelGenerator.last_node
    local saved_bend = SurfacePanelGenerator.last_bend_mod
    local fixture_node = undefined
    try
    (
        local fixture_mask = SurfacePanelGenerator.makeMask 4 3 enabled:true
        local fixture_ids = #(1,1,1,2,2,2,1,1,1,1,1,1)
        fixture_node = SurfacePanelGenerator.generateModule 4 3 fixture_mask 1000.0 5000.0 0.0 4 0.01 cell_ids_value:fixture_ids rule_depths_value:#(0.0,50.0) rule_insets_value:#(0.0,5.0) rule_tapers_value:#(0.0,2.0) seams_enabled_value:true seams_amount_value:10.0 seams_offset_value:20.0 chamfer_enabled_value:true chamfer_amount_value:1.0
        fixture_node.name = "TPG_078_TEST_seams_and_extrusion"
        local stack_parts = SurfacePanelGenerator.getOwnedStackParts fixture_node
        if stack_parts == undefined or fixture_node.modifiers.count != 4 then
            throw "PART 55 FAILED | Expected four native/procedural modifiers."
        if stack_parts[1] != fixture_node.modifiers[1] or stack_parts[2] != fixture_node.modifiers[2] or stack_parts[3] != fixture_node.modifiers[3] or stack_parts[4] != fixture_node.modifiers[4] then
            throw "PART 55 FAILED | Wrong native Chamfer / Extrusion / Bend / Seams order."
        if (getAppData stack_parts[4] 1847365210) != "TPG:Seams" or (getAppData stack_parts[2] 1847365210) != "TPG:Extrusion" then
            throw "PART 55 FAILED | Modifier ownership markers missing."
        if not stack_parts[2].enabled or not stack_parts[4].enabled then
            throw "PART 55 FAILED | Seams and TPG Extrusion must both be enabled."
        if stack_parts[4].selectionoption != 5 or stack_parts[4].materialoption != 1 or stack_parts[4].addinset != true or stack_parts[4].insetoffset != 20.0 or stack_parts[4].segments != 0 then
            throw "PART 55 FAILED | Seams does not match the native Chamfer reference."
        if stack_parts[1].name != "TPG_Chamfer" or stack_parts[1].materialoption != 2 or stack_parts[1].segments != 1 then
            throw "PART 55 FAILED | Finishing Chamfer default materialoption/segments/name is incorrect."
        local saved_data = SurfacePanelGenerator.readModuleData fixture_node
        if not saved_data.seams_enabled or not saved_data.chamfer_enabled or saved_data.chamfer_segments != 1 then
            throw "PART 55 FAILED | Enabled Chamfer settings not restored from object."
        local original_top_chamfer = stack_parts[1]
        SurfacePanelGenerator.syncChamferStack fixture_node stack_parts[3] seams_enabled_value:true seams_amount_value:10.0 seams_offset_value:20.0 chamfer_enabled_value:true chamfer_amount_value:1.0 chamfer_segments_value:3
        local revised_stack = SurfacePanelGenerator.getOwnedStackParts fixture_node
        if revised_stack[1] != original_top_chamfer or revised_stack[1].materialoption != 2 or revised_stack[1].segments != 3 then
            throw "PART 55 FAILED | Segments change must update existing top Chamfer only."
        if (SurfacePanelGenerator.readModuleData fixture_node).chamfer_segments != 3 then
            throw "PART 55 FAILED | Updated Chamfer Segments were not stored on the module."
        stack_parts[1].enabled = false
        local extruded_mesh = snapshotAsMesh fixture_node
        stack_parts[2].enabled = false
        local seams_only_mesh = snapshotAsMesh fixture_node
        stack_parts[2].enabled = true
        stack_parts[1].enabled = true
        if extruded_mesh.numfaces <= seams_only_mesh.numfaces then
            throw "PART 55 FAILED | Extrusion added no faces above enabled Seams."
        local saved_extrusion_mod = stack_parts[2]
        SurfacePanelGenerator.updateExtrusionOnly fixture_node stack_parts[3] rule_depths_value:#(0.0,60.0)
        local stack_after = SurfacePanelGenerator.getOwnedStackParts fixture_node
        if stack_after[2] != saved_extrusion_mod or stack_after[4] != stack_parts[4] or not stack_after[2].enabled then
            throw "PART 55 FAILED | Live extrusion edit broke Seams or replaced the modifier."
        format "PASS PART 55 | Seams below Bend, top Chamfer materialoption:2, Segments 1 -> 3, extrusion faces:% -> %\n" seams_only_mesh.numfaces extruded_mesh.numfaces
    )
    catch
    (
        format "TPG SEAMS REGRESSION FAILED | %\n" (getCurrentException())
        SurfacePanelGenerator.last_node = saved_node
        SurfacePanelGenerator.last_bend_mod = saved_bend
        throw()
    )
    SurfacePanelGenerator.last_node = saved_node
    SurfacePanelGenerator.last_bend_mod = saved_bend
    true
    -- return
)


if TPG_SeamsRegressionOnly == true then runTpgSeamsChamferRegression()
TPG_SeamsRegressionOnly = false
/* Isolated Part 56: the flat Editable Poly has real thickness, not a Shell modifier.
   Only the outer panel faces may retain positive private map-channel 99 tags.
*/
function runTpgBaseThicknessRegression =
(
    local test_thickness = units.decodeValue "2mm"
    local tolerance = units.decodeValue "0.01mm"
    local test_mask = SurfacePanelGenerator.makeMask 2 2 enabled:true
    local test_heights = SurfacePanelGenerator.makeRuleDepths 16 0.0
    local node_value = undefined
    try
    (
        node_value = SurfacePanelGenerator.generateModule 2 2 test_mask 100.0 200.0 0.0 2 0.01 base_thickness_value:test_thickness rule_depths_value:test_heights
        if not isValidNode node_value then throw "PART 56 FAILED | Could not generate a thick base."
        if classOf node_value.baseObject != Editable_Poly or node_value.modifiers.count != 2 then
            throw "PART 56 FAILED | Shell must be baked into the Editable Poly base."
        local expected_top_faces = 8
        local actual_top_faces = 0
        local min_z = 1.0e30
        local max_z = -1.0e30
        local base_poly = node_value.baseObject
        if (polyop.getNumFaces base_poly) <= expected_top_faces then
            throw "PART 56 FAILED | Base is still a single sheet."
        for vertex_id = 1 to (polyop.getNumVerts base_poly) do
        (
            local z_value = (polyop.getVert base_poly vertex_id).z
            min_z = amin min_z z_value
            max_z = amax max_z z_value
        )
        if (abs (min_z + test_thickness)) > tolerance or (abs max_z) > tolerance then
            throw "PART 56 FAILED | Thickness must extend inward from the original flat front."
        for face_id = 1 to (polyop.getNumFaces base_poly) do
        (
            local face_tag_indices = polyop.getMapFace base_poly 99 face_id
            local tag_value = polyop.getMapVert base_poly 99 (face_tag_indices[1] as integer)
            local normal_value = polyop.getFaceNormal base_poly face_id
            if normal_value.z > 0.5 then
            (
                actual_top_faces += 1
                if tag_value.x < 1 or tag_value.y < 0.5 then
                    throw "PART 56 FAILED | Original outer panel face lost its active tag."
            )
            else if tag_value.x != 0.0 or tag_value.y != 0.0 then
                throw "PART 56 FAILED | Back and side faces must be excluded from extrusion."
        )
        if actual_top_faces != expected_top_faces then
            throw "PART 56 FAILED | Source panel face count changed."
        if (abs ((SurfacePanelGenerator.readModuleData node_value).base_thickness - test_thickness)) > tolerance then
            throw "PART 56 FAILED | Thickness object-property round trip."
        local original_handle = getHandleByAnim node_value
        local owned_bend = (SurfacePanelGenerator.getOwnedStackParts node_value)[3]
        local new_thickness = test_thickness * 2.0
        local updated_node = SurfacePanelGenerator.generateModule 2 2 test_mask 100.0 200.0 0.0 2 0.01 base_thickness_value:new_thickness rule_depths_value:test_heights target_node:node_value owned_bend:owned_bend
        if updated_node != node_value or getHandleByAnim node_value != original_handle then
            throw "PART 56 FAILED | Updating thickness changed the bound node."
        if (abs ((SurfacePanelGenerator.readModuleData node_value).base_thickness - new_thickness)) > tolerance then
            throw "PART 56 FAILED | Updated thickness was not persisted."
        format "PASS PART 56 | Baked sheet thickness, tagged front faces, excluded back/side faces, persistent editing.\n"
    )
    catch
    (
        format "FAIL PART 56 | %\n" (getCurrentException())
        throw()
    )
    if isValidNode node_value then delete node_value
    true
)
if TPG_BaseThicknessRegressionOnly == true then runTpgBaseThicknessRegression()
TPG_BaseThicknessRegressionOnly = false


/* Part 57 — the Hatch button backend works without generating a module.
   Result is a native SplineShape with one tagged Lathe modifier, not mesh.
*/
function runTpgHatchRegression =
(
    local previous_hatch = CapHatchGenerator.last_node
    local previous_lathe = CapHatchGenerator.last_lathe_mod
    local previous_chamfer = CapHatchGenerator.last_chamfer_mod
    local previous_module = CapHatchGenerator.last_module
    local hatch_node = undefined
    local linked_module = undefined
    local linked_hatch = undefined
    try
    (
        hatch_node = CapHatchGenerator.generateStandaloneHatch 100.0 0.0 3.0 5.0 3 5.0 10.0 lathe_segments:32
        if not isValidNode hatch_node then throw "PART 57 FAILED | Hatch was not created."
        if hatch_node.modifiers.count != 2 or classOf hatch_node.modifiers[2] != Lathe or classOf hatch_node.modifiers[1] != Chamfer then
            throw "PART 57 FAILED | Expected owned Chamfer above native Lathe."
        testTpgCapProfile hatch_node 5
        if (getAppData hatch_node.modifiers[2] 1847365210) != "TPG:Lathe" then
            throw "PART 57 FAILED | Lathe ownership marker missing."
        if (getUserPropVal hatch_node "SPG_StandaloneHatch" asString:true) != "1" then
            throw "PART 57 FAILED | Standalone Hatch metadata missing."
        local previous_handle = getHandleByAnim hatch_node
        local owned_lathe = hatch_node.modifiers[2]
        local owned_chamfer = hatch_node.modifiers[1]
        local updated_node = CapHatchGenerator.generateStandaloneHatch 100.0 0.0 3.0 8.0 3 5.0 10.0 lathe_segments:48 target_node:hatch_node owned_lathe:owned_lathe owned_chamfer:owned_chamfer
        if updated_node != hatch_node or (getHandleByAnim updated_node) != previous_handle or updated_node.modifiers.count != 2 then
            throw "PART 57 FAILED | Updating Hatch changed the scene node or stack cardinality."
        if updated_node.modifiers[2].segs != 48 then
            throw "PART 57 FAILED | Updated native Lathe segments not applied."
        linked_module = dummy name:"TPG_TEST_HatchOwner"
        linked_hatch = CapHatchGenerator.generateCap linked_module 100.0 200.0 0.0 3.0 5.0 3 5.0 10.0 1.0 0.5 0.0 lathe_segments:32
        if not isValidNode linked_hatch or linked_hatch.parent != linked_module or linked_hatch.modifiers.count != 2 then
            throw "PART 57 FAILED | Linked Hatch creation or parent/stack failed."
        testTpgCapProfile linked_hatch 5
        if (findItem linked_hatch.material.materialIDList 99) == 0 or (findItem hatch_node.material.materialIDList 99) == 0 then
            throw "PART 57 FAILED | Seam material ID 99 is missing."
        format "PASS PART 57 | Standalone and linked editable profiles, five material bands, native Lathe, identity-preserving update.\n"
    )
    catch
    (
        format "FAIL PART 57 | %\n" (getCurrentException())
        if isValidNode linked_hatch then delete linked_hatch
        if isValidNode linked_module then delete linked_module
        if isValidNode hatch_node then delete hatch_node
        CapHatchGenerator.last_node = previous_hatch
        CapHatchGenerator.last_lathe_mod = previous_lathe
        CapHatchGenerator.last_chamfer_mod = previous_chamfer
        CapHatchGenerator.last_module = previous_module
        throw()
    )
    if isValidNode linked_hatch then delete linked_hatch
    if isValidNode linked_module then delete linked_module
    if isValidNode hatch_node then delete hatch_node
    CapHatchGenerator.last_node = previous_hatch
    CapHatchGenerator.last_lathe_mod = previous_lathe
    CapHatchGenerator.last_chamfer_mod = previous_chamfer
    CapHatchGenerator.last_module = previous_module
    true
)
if TPG_HatchRegressionOnly == true then runTpgHatchRegression()
TPG_HatchRegressionOnly = false

/* Part 58 — Taper moves only the upper perimeter, equally inward/outward
   from the source border, retaining parallel edge loops and inner vertices.
   This runs without a generated cylindrical scene node.
*/
function runTpgTaperLoopsRegression =
(
    local position_tolerance = units.decodeValue "0.01mm"
    local test_vertices = #([0,0,0],[100,0,0],[100,100,0],[0,100,0],[50,50,0])
    local test_faces = #([1,2,5],[2,3,5],[3,4,5],[4,1,5])
    local baseline_positions = #()
    local test_regions = #{1..4}
    for offset_amount in #(5.0,-5.0,0.0) do
    (
        for test_direction in #(#common,#independent) do
        (
            for height_amount in #(0.0,20.0) do
            (
                local source_mesh = mesh vertices:test_vertices faces:test_faces
                local original_topology = for face_id in test_regions collect #(face_id,(getFace source_mesh face_id))
                tpgExtrudeFaceRegion source_mesh test_regions height_amount offset_amount test_direction
                local expected_min = offset_amount
                local expected_max = 100.0 - offset_amount
                local original_source_ids = #{1..5}
                for face_info in original_topology do
                (
                    local top_ids = getFace source_mesh face_info[1]
                    for corner_index = 1 to 3 do
                    (
                        local original_id = face_info[2][corner_index] as integer
                        local top_id = top_ids[corner_index] as integer
                        local actual_position = getVert source_mesh top_id
                        local expected_position = if original_id == 5 then [50,50,height_amount] else
                        (
                            case original_id of
                            (
                                1: [expected_min,expected_min,height_amount]
                                2: [expected_max,expected_min,height_amount]
                                3: [expected_max,expected_max,height_amount]
                                4: [expected_min,expected_max,height_amount]
                            )
                        )
                        if (distance actual_position expected_position) > position_tolerance then
                        (
                            format "TPG TAPER FAILED | ID:% height:% offset:% mode:% actual:% expected:% tolerance:%\n" original_id height_amount offset_amount test_direction actual_position expected_position position_tolerance
                            throw "PART 58 FAILED | Top perimeter was not offset parallel to lower border."
                        )
                    )
                )
                -- Lower source border stays in place after the upper ring moves.
                for vertex_id = 1 to test_vertices.count do
                (
                    if (distance (getVert source_mesh vertex_id) test_vertices[vertex_id]) > position_tolerance then
                        throw "PART 58 FAILED | Lower border or interior source vertex moved."
                )
            )
        )
    )
    format "PASS PART 58 | Parallel top loops, signed taper, zero height, both extrusion directions, unchanged lower perimeter.\n"
    true
    -- return
)
if TPG_TaperLoopsRegressionOnly == true then runTpgTaperLoopsRegression()
TPG_TaperLoopsRegressionOnly = false


/* Compare scalar vertex positions when ordering the diagnostic ring.
   The reproduced panel is monotonic in object-space Z on each cylinder side.
*/
function compareTpgRingZ first_point second_point =
(
    if first_point.z < second_point.z then -1 else if first_point.z > second_point.z then 1 else 0
    -- return
)

/* Part 59 reproduces the user's subdivided bent panel through the real generator.
   Equal chord lengths measure the actual distances between parallel axial edges.
*/
function runTpgTaperSpacingRegression =
(
    local position_precision = units.decodeValue "0.01mm"
    local saved_node = SurfacePanelGenerator.last_node
    local saved_bend = SurfacePanelGenerator.last_bend_mod
    local fixture_node = undefined
    local ring_count = 0
    try
    (
        for mode_value in #(#group,#local) do
        (
            for height_value in #(0.0,100.0,-100.0) do
            (
                for inset_value in #(0.0,50.0) do
                (
                    for taper_value in #(100.0,-100.0) do
                    (
                        local fixture_mask = SurfacePanelGenerator.makeMask 4 3 enabled:true
                        local fixture_ids = #(1,1,1,1,2,1,1,3,1,1,4,1)
                        fixture_node = SurfacePanelGenerator.generateModule 4 3 fixture_mask 1000.0 7000.0 0.0 4 0.01 x_multiplier:2 length_segments:2 cell_ids_value:fixture_ids rule_depths_value:#(0.0,10.0,50.0,height_value) rule_insets_value:#(0.0,10.0,10.0,inset_value) rule_tapers_value:#(0.0,0.0,0.0,taper_value) extrusion_mode_value:mode_value
                        local fixture_mesh = snapshotAsMesh fixture_node
                        local top_vertices = #{}
                        top_vertices.count = fixture_mesh.numverts
                        /* Original top face IDs survive the compound MeshOp stages. */
                        for face_id = 1 to 384 where (getFaceMatID fixture_mesh face_id) == 4 do
                        (
                            local vertex_ids = getFace fixture_mesh face_id
                            for corner_id = 1 to 3 do top_vertices[vertex_ids[corner_id] as integer] = true
                        )
                        for side_value in #(-1,1) do
                        (
                            local side_points = for vertex_id in top_vertices where ((getVert fixture_mesh vertex_id).x * side_value) > 0.0 collect (getVert fixture_mesh vertex_id)
                            local row_levels = #()
                            for point_value in side_points where (findItem row_levels point_value.y) == 0 do append row_levels point_value.y
                            if row_levels.count != 3 then throw ("PART 59 FAILED | Expected three ring rows, actual:" + row_levels.count as string)
                            for row_level in row_levels do
                            (
                                local ring_points = for point_value in side_points where point_value.y == row_level collect point_value
                                qsort ring_points compareTpgRingZ
                                if ring_points.count != 5 then throw ("PART 59 FAILED | Expected five ring vertices, actual:" + ring_points.count as string)
                                local expected_spacing = distance ring_points[1] ring_points[2]
                                for point_id = 2 to 4 do
                                (
                                    local actual_spacing = distance ring_points[point_id] ring_points[point_id + 1]
                                    if abs (actual_spacing - expected_spacing) > position_precision then
                                    (
                                        format "PART 59 FAILED | mode:% height:% inset:% taper:% side:% row:% segment:% expected:% actual:% precision:%\n" mode_value height_value inset_value taper_value side_value row_level point_id expected_spacing actual_spacing position_precision
                                        throw "PART 59 FAILED | Parallel axial edges are unevenly spaced."
                                    )
                                )
                                ring_count += 1
                            )
                        )
                        delete fixture_node
                        fixture_node = undefined
                    )
                )
            )
        )
    )
    catch
    (
        format "FAIL PART 59 | %\n" (getCurrentException())
        if isValidNode fixture_node then delete fixture_node
        SurfacePanelGenerator.last_node = saved_node
        SurfacePanelGenerator.last_bend_mod = saved_bend
        throw()
    )
    SurfacePanelGenerator.last_node = saved_node
    SurfacePanelGenerator.last_bend_mod = saved_bend
    format "PASS PART 59 | Equal subdivision spacing, rings:% precision:%\n" ring_count position_precision
    true
    -- return
)
if TPG_TaperSpacingRegressionOnly == true then runTpgTaperSpacingRegression()
TPG_TaperSpacingRegressionOnly = false


/* Part 60 checks Auto Length subdivisions on the flat Editable Poly base.
   Manual mode, legacy records, object reload, repeats and preset storage are covered.
*/
function runTpgLengthSubdivisionRegression =
(
    local saved_node = SurfacePanelGenerator.last_node
    local saved_bend = SurfacePanelGenerator.last_bend_mod
    local fixture_node = undefined
    local fixture_mask = SurfacePanelGenerator.makeMask 4 3 enabled:true
    local zero_heights = SurfacePanelGenerator.makeRuleDepths 16 0.0
    local fixtures = #(#(1000.0,7000.0,4,2,1,7),#(1000.0,7000.0,8,2,1,13),#(1000.0,100.0,4,2,1,1),#(1000.0,70000.0,4,2,1,67),#(1000.0,7000.0,4,2,3,7),#(100.0,700.0,4,2,1,7))
    try
    (
        for fixture in fixtures do
        (
            fixture_node = SurfacePanelGenerator.generateModule 4 3 fixture_mask fixture[1] fixture[2] 0.0 fixture[3] 0.01 x_multiplier:fixture[4] y_multiplier:fixture[5] length_segments:0 rule_depths_value:zero_heights
            if not isValidNode fixture_node then throw "PART 60 FAILED | Auto did not generate a module."
            local restored_data = SurfacePanelGenerator.readModuleData fixture_node
            if not restored_data.length_segments_auto or restored_data.length_segments != fixture[6] then
            (
                format "PART 60 FAILED | fixture:% expected segments:% actual:% auto:%\n" fixture fixture[6] restored_data.length_segments restored_data.length_segments_auto
                throw "PART 60 FAILED | Auto count or mode was not persisted."
            )
            local expected_faces = 4 * 3 * fixture[4] * fixture[5] * fixture[3] * fixture[6]
            local actual_faces = polyop.getNumFaces fixture_node.baseObject
            if actual_faces != expected_faces then
            (
                format "PART 60 FAILED | expected base quads:% actual:%\n" expected_faces actual_faces
                throw "PART 60 FAILED | Wrong base subdivision topology."
            )
            delete fixture_node
            fixture_node = undefined
        )
        fixture_node = SurfacePanelGenerator.generateModule 4 3 fixture_mask 1000.0 7000.0 0.0 4 0.01 x_multiplier:2 length_segments:3 rule_depths_value:zero_heights
        local manual_data = SurfacePanelGenerator.readModuleData fixture_node
        if manual_data.length_segments_auto or manual_data.length_segments != 3 then throw "PART 60 FAILED | Manual count changed."
        deleteUserProp fixture_node "SPG_LengthSegmentsAuto"
        local legacy_data = SurfacePanelGenerator.readModuleData fixture_node
        if legacy_data.length_segments_auto or legacy_data.length_segments != 3 then throw "PART 60 FAILED | Legacy object must remain manual."
        local owned_bend = (SurfacePanelGenerator.getOwnedStackParts fixture_node)[3]
        local original_node = fixture_node
        fixture_node = SurfacePanelGenerator.generateModule 4 3 fixture_mask 1000.0 7000.0 0.0 4 0.01 x_multiplier:2 length_segments:0 target_node:fixture_node owned_bend:owned_bend rule_depths_value:zero_heights
        if fixture_node != original_node or (SurfacePanelGenerator.readModuleData fixture_node).length_segments != 7 then throw "PART 60 FAILED | Bound manual-to-Auto update failed."
        local preset_test_path = (getDir #temp) + "\\TPG-Auto-Length-Test.ini"
        local TPGPresetManager = TPGPresetManager_v ini_path:preset_test_path
        if (findItem TPGPresetManager.setting_keys "LengthSegments") == 0 or (findItem TPGPresetManager.panels_setting_keys "LengthSegments") == 0 then throw "PART 60 FAILED | Auto sentinel missing from preset scopes."
        setINISetting preset_test_path "MainUI" "LengthSegments" "0"
        if (getINISetting preset_test_path "MainUI" "LengthSegments") != "0" then throw "PART 60 FAILED | Auto INI sentinel round trip."
        TPGPresetManager.savePreset "Auto Length"
        setINISetting preset_test_path "MainUI" "LengthSegments" "3"
        TPGPresetManager.loadPreset "Auto Length" mode:#panels
        if (getINISetting preset_test_path "MainUI" "LengthSegments") != "0" then throw "PART 60 FAILED | Panels preset lost Auto."
        setINISetting preset_test_path "MainUI" "LengthSegments" "5"
        TPGPresetManager.loadPreset "Auto Length" mode:#extrude
        if (getINISetting preset_test_path "MainUI" "LengthSegments") != "5" then throw "PART 60 FAILED | Extrude preset overwrote Length subdivision."
        deleteFile preset_test_path
    )
    catch
    (
        format "FAIL PART 60 | %\n" (getCurrentException())
        if isValidNode fixture_node then delete fixture_node
        SurfacePanelGenerator.last_node = saved_node
        SurfacePanelGenerator.last_bend_mod = saved_bend
        throw()
    )
    if isValidNode fixture_node then delete fixture_node
    SurfacePanelGenerator.last_node = saved_node
    SurfacePanelGenerator.last_bend_mod = saved_bend
    format "PASS PART 60 | Auto square base quads, manual/legacy preservation, reload, repeats, bound update and INI sentinel.\n"
    true
    -- return
)
if TPG_LengthSubdivisionRegressionOnly == true then runTpgLengthSubdivisionRegression()
TPG_LengthSubdivisionRegressionOnly = false



/* Part 61 closes the bent cylinder seam before region IDs are collected.
   Verify actual evaluated topology, threshold units, map tags and stack identity.
*/
function runTpgBentWeldRegression =
(
    local saved_node = SurfacePanelGenerator.last_node
    local saved_bend = SurfacePanelGenerator.last_bend_mod
    local fixture_node = undefined
    try
    (
        local fixture_mask = SurfacePanelGenerator.makeMask 2 3 enabled:true
        local radius_value = units.decodeValue "1000mm"
        local length_value = units.decodeValue "2000mm"
        fixture_node = SurfacePanelGenerator.generateModule 2 3 fixture_mask radius_value length_value 0.0 4 0.01 length_segments:2 cell_ids_value:#(1,2,1,1,2,1) rule_depths_value:#(0.0,0.0)
        local original_base = fixture_node.baseObject
        local owned_parts = SurfacePanelGenerator.getOwnedStackParts fixture_node
        local original_extrusion = owned_parts[2]
        local original_bend = owned_parts[3]
        original_extrusion.enabled = false
        local bent_mesh = snapshotAsMesh fixture_node
        original_extrusion.enabled = true
        local welded_mesh = tpgBuildExtrusionMesh (copy bent_mesh) fixture_node
        if bent_mesh.numverts != 65 or welded_mesh.numverts != 60 or welded_mesh.numfaces != bent_mesh.numfaces then
        (
            format "PART 61 FAILED | input verts:% expected:65 output verts:% expected:60 input faces:% output faces:%\n" bent_mesh.numverts welded_mesh.numverts bent_mesh.numfaces welded_mesh.numfaces
            throw "PART 61 FAILED | Bent seam was not welded before extrusion."
        )
        local evaluated_mesh = snapshotAsMesh fixture_node
        if evaluated_mesh.numverts != 60 then
            throw ("PART 61 FAILED | Procedural output verts:" + evaluated_mesh.numverts as string + " expected:60")
        for face_id = 1 to bent_mesh.numfaces do
        (
            if (getFaceMatID bent_mesh face_id) != (getFaceMatID welded_mesh face_id) then
                throw ("PART 61 FAILED | Weld changed material ID at face:" + face_id as string)
            local old_map_face = meshop.getMapFace bent_mesh 99 face_id
            local new_map_face = meshop.getMapFace welded_mesh 99 face_id
            for corner_id = 1 to 3 do
            (
                local expected_tag = meshop.getMapVert bent_mesh 99 (old_map_face[corner_id] as integer)
                local actual_tag = meshop.getMapVert welded_mesh 99 (new_map_face[corner_id] as integer)
                if expected_tag != actual_tag then
                    throw ("PART 61 FAILED | Map tag changed at face:" + face_id as string + " corner:" + corner_id as string + " expected:" + expected_tag as string + " actual:" + actual_tag as string)
            )
        )
        /* Source grid vertex 13 is the duplicate of vertex 1 at this seam row. */
        local perturbed_mesh = copy bent_mesh
        local seam_gap = units.decodeValue "0.05mm"
        setVert perturbed_mesh 13 ((getVert perturbed_mesh 1) + [seam_gap,0,0])
        local narrow_result = tpgBuildExtrusionMesh (copy perturbed_mesh) fixture_node
        setUserProp fixture_node "SPG_PositionPrecisionMM" "0.1"
        local wide_result = tpgBuildExtrusionMesh (copy perturbed_mesh) fixture_node
        if narrow_result.numverts != 61 or wide_result.numverts != 60 then
            throw ("PART 61 FAILED | Threshold 0.01mm verts:" + narrow_result.numverts as string + " expected:61; 0.1mm verts:" + wide_result.numverts as string + " expected:60")
        setUserProp fixture_node "SPG_PositionPrecisionMM" "0.01"
        for mode_value in #(#group,#local) do
        (
            SurfacePanelGenerator.updateExtrusionOnly fixture_node original_bend rule_depths_value:#(0.0,20.0) rule_insets_value:#(0.0,5.0) rule_tapers_value:#(0.0,2.0) extrusion_mode_value:mode_value
            local extruded_mesh = tpgBuildExtrusionMesh (copy bent_mesh) fixture_node
            if extruded_mesh.numfaces <= welded_mesh.numfaces then throw "PART 61 FAILED | No extrusion after weld."
            local revised_parts = SurfacePanelGenerator.getOwnedStackParts fixture_node
            if fixture_node.baseObject != original_base or revised_parts[2] != original_extrusion or revised_parts[3] != original_bend then
                throw "PART 61 FAILED | Welding changed original base or modifier identity."
        )
        if (polyop.getNumVerts original_base) != 65 then throw "PART 61 FAILED | Flat base was modified."
    )
    catch
    (
        format "FAIL PART 61 | %\n" (getCurrentException())
        if isValidNode fixture_node then delete fixture_node
        SurfacePanelGenerator.last_node = saved_node
        SurfacePanelGenerator.last_bend_mod = saved_bend
        throw()
    )
    if isValidNode fixture_node then delete fixture_node
    SurfacePanelGenerator.last_node = saved_node
    SurfacePanelGenerator.last_bend_mod = saved_bend
    format "PASS PART 61 | Bent seam welded, saved threshold honored, tags/materials preserved, Group/Local extrusion and unchanged base/stack.\n"
    true
    -- return
)
if TPG_BentWeldRegressionOnly == true then runTpgBentWeldRegression()
TPG_BentWeldRegressionOnly = false


/* Part 62 verifies thickness seam walls are removed before Bend and welding.
   Keep both skins and axial rims, then close both thickness layers at the seam.
*/
function runTpgThicknessSeamRegression =
(
    local saved_node = SurfacePanelGenerator.last_node
    local saved_bend = SurfacePanelGenerator.last_bend_mod
    local fixture_node = undefined
    try
    (
        local fixture_mask = SurfacePanelGenerator.makeMask 2 3 enabled:true
        local zero_heights = #(0.0,0.0)
        for thickness_mm in #(2.0,8.0) do
        (
            fixture_node = SurfacePanelGenerator.generateModule 2 3 fixture_mask (units.decodeValue "1000mm") (units.decodeValue "2000mm") 0.0 4 0.01 length_segments:2 base_thickness_value:(units.decodeValue ((thickness_mm as string) + "mm")) cell_ids_value:#(1,2,1,1,2,1) rule_depths_value:zero_heights
            if not isValidNode fixture_node then throw "PART 62 FAILED | Thick module generation failed."
            local base_poly = fixture_node.baseObject
            local front_count = 0
            local back_count = 0
            local rim_count = 0
            local seam_count = 0
            for face_id = 1 to (polyop.getNumFaces base_poly) do
            (
                local face_normal = polyop.getFaceNormal base_poly face_id
                if face_normal.z == 1.0 then front_count += 1
                else if face_normal.z == -1.0 then back_count += 1
                else if abs face_normal.y == 1.0 then rim_count += 1
                else seam_count += 1
            )
            if front_count != 48 or back_count != 48 or rim_count != 24 or seam_count != 0 then
            (
                format "PART 62 FAILED | thickness mm:% front:% expected:48 back:% expected:48 axial rims:% expected:24 seam walls:% expected:0\n" thickness_mm front_count back_count rim_count seam_count
                throw "PART 62 FAILED | Thickness seam-wall deletion damaged the source shell."
            )
            local welded_mesh = snapshotAsMesh fixture_node
            if welded_mesh.numfaces != 240 or welded_mesh.numverts != 120 then
                throw ("PART 62 FAILED | Welded thick tube faces:" + welded_mesh.numfaces as string + " expected:240 vertices:" + welded_mesh.numverts as string + " expected:120")
            local owned_parts = SurfacePanelGenerator.getOwnedStackParts fixture_node
            for mode_value in #(#group,#local) do
            (
                SurfacePanelGenerator.updateExtrusionOnly fixture_node owned_parts[3] rule_depths_value:#(0.0,20.0) extrusion_mode_value:mode_value
                local extruded_mesh = snapshotAsMesh fixture_node
                if extruded_mesh.numfaces <= 240 then throw "PART 62 FAILED | Extrusion failed after thickness seam cleanup."
            )
            delete fixture_node
            fixture_node = undefined
        )
    )
    catch
    (
        format "FAIL PART 62 | %\n" (getCurrentException())
        if isValidNode fixture_node then delete fixture_node
        SurfacePanelGenerator.last_node = saved_node
        SurfacePanelGenerator.last_bend_mod = saved_bend
        throw()
    )
    SurfacePanelGenerator.last_node = saved_node
    SurfacePanelGenerator.last_bend_mod = saved_bend
    format "PASS PART 62 | Seam thickness walls removed, skins/rims retained, both layers welded, Group/Local extrusion.\n"
    true
    -- return
)
if TPG_ThicknessSeamRegressionOnly == true then runTpgThicknessSeamRegression()
TPG_ThicknessSeamRegressionOnly = false


/* Part 63 validates shared units, managed seam settings and both module ends.
   Run after loading the current main tool so its real UI can be exercised.
*/
function runTpgHatchOptionsRegression =
(
    local dialog_ref = undefined
    if ::dialog_host_registry != undefined then
        for registry_entry in ::dialog_host_registry where registry_entry[1] == "Tank-Panel-Generator" do dialog_ref = registry_entry[2]
    if dialog_ref == undefined then throw "PART 63 | Load Tank-Panel-Generator.ms before running this regression."
    local position_precision = units.decodeValue "0.01mm"
    local original_settings = dialog_ref.getHatchSettings()
    local original_unit = dialog_ref.ddl_size.SelectedIndex
    local original_loading = dialog_ref.ui_loading
    local previous_hatch = CapHatchGenerator.last_node
    local previous_lathe = CapHatchGenerator.last_lathe_mod
    local previous_chamfer = CapHatchGenerator.last_chamfer_mod
    local previous_module = CapHatchGenerator.last_module
    local test_module = undefined
    try
    (
        dialog_ref.ui_loading = true
        local radius_before = dialog_ref.moduleRadius()
        local length_before = dialog_ref.moduleLength()
        local seam_before = SurfacePanelGenerator.seams_amount
        local chamfer_before = SurfacePanelGenerator.chamfer_amount
        for unit_index in #(0,1,2,0,1,2) do
        (
            dialog_ref.ddl_size.SelectedIndex = unit_index
            dialog_ref.changeDimensionUnit unit_index
            local actual_settings = dialog_ref.getHatchSettings()
            for value_index = 1 to original_settings.count do
            (
                local actual_value = actual_settings[value_index]
                local expected_value = original_settings[value_index]
                if value_index == 4 or value_index == 8 or value_index >= 11 then
                (
                    if actual_value != expected_value then throw ("PART 63 | Unit switch changed a count/ID/flag at index:" + value_index as string)
                )
                else if abs (actual_value - expected_value) > position_precision then
                    throw ("PART 63 | Unit switch changed Hatch dimension at index:" + value_index as string + " actual:" + actual_value as string + " expected:" + expected_value as string)
            )
            if abs ((dialog_ref.moduleRadius()) - radius_before) > position_precision or abs ((dialog_ref.moduleLength()) - length_before) > position_precision then
                throw "PART 63 | Unit switch changed the module size."
            local unit_scale = dialog_ref.getSpgUnitScale unit_index
            if abs (dialog_ref.spn_seams_amount.value * unit_scale - seam_before) > position_precision or abs (dialog_ref.spn_chamfer_amount.value * unit_scale - chamfer_before) > position_precision then
                throw "PART 63 | Global Seam/Chamfer display does not follow SIZE."
        )
        test_module = dummy name:"TPG_TEST_Hatch_Ends"
        test_module.pos = [120,230,340]
        test_module.rotation = (quat 30 [0,0,1])
        test_module.scale = [1.2,1.2,1.2]
        test_module.objectOffsetRot = (quat 0 0 -1 0)
        local radius_value = units.decodeValue "100mm"
        local length_value = units.decodeValue "200mm"
        local settings_value = #((units.decodeValue "20mm"),(units.decodeValue "3mm"),(units.decodeValue "5mm"),3,(units.decodeValue "5mm"),(units.decodeValue "10mm"),(units.decodeValue "1mm"),0.5,0.0,(units.decodeValue "5mm"),0,0,99,1,1)
        CapHatchGenerator.generateModuleHatches test_module radius_value length_value settings_value lathe_segments:32
        local cap_data = CapHatchGenerator.readModuleCap test_module
        if cap_data.count != 5 or cap_data[5].count != 2 or cap_data[4][14] != 1 or cap_data[4][15] != 1 then
            throw "PART 63 | Both module ends were not created/restored."
        local exit_node = undefined
        for cap_record in cap_data[5] do
        (
            local cap_node = cap_record[1]
            local lathe_mod = cap_record[2]
            local seam_mod = cap_record[3]
            local end_sign = if cap_record[4] == #enter then -1.0 else 1.0
            local expected_position = [0,end_sign * length_value * 0.5,-radius_value] * test_module.objectTransform
            if (distance cap_node.pos expected_position) > position_precision then
                throw ("PART 63 | Hatch alignment actual:" + cap_node.pos as string + " expected:" + expected_position as string)
            if (dot cap_node.transform.row2 test_module.objectTransform.row2) * end_sign <= 0.0 then
                throw "PART 63 | Entrance/exit profile points in the wrong direction."
            if lathe_mod.axis.position != [0,0,0] then throw "PART 63 | Lathe is not centered on the profile origin."
            if not seam_mod.addinset or not seam_mod.setmaterial or seam_mod.materialid != 99 or seam_mod.insetsegments != 0 or seam_mod.segments != 0 then
                throw "PART 63 | Managed seam options differ from requested values."
            if abs (seam_mod.amount - settings_value[7]) > position_precision or abs (seam_mod.insetamount - settings_value[9]) > position_precision or abs (seam_mod.insetoffset - settings_value[10]) > position_precision then
                throw "PART 63 | Seam Width/Stich Width/Depth was not passed in scene units."
            if (findItem cap_node.material.materialIDList 99) == 0 then throw "PART 63 | Seam material slot 99 is missing."
            testTpgCapProfile cap_node 5
            seam_mod.enabled = false
            local lathe_mesh = snapshotAsMesh cap_node
            seam_mod.enabled = true
            local maximum_radius = 0.0
            for vertex_id = 1 to lathe_mesh.numverts do
            (
                local point_value = getVert lathe_mesh vertex_id
                maximum_radius = amax maximum_radius (sqrt (point_value.x * point_value.x + point_value.z * point_value.z))
            )
            if abs (maximum_radius - radius_value - settings_value[2]) > position_precision then
                throw ("PART 63 | Lathe outer radius actual:" + maximum_radius as string + " expected:" + (radius_value + settings_value[2]) as string)
            if cap_record[4] == #exit then exit_node = cap_node
        )
        settings_value[14] = 0
        CapHatchGenerator.generateModuleHatches test_module radius_value length_value settings_value lathe_segments:32
        cap_data = CapHatchGenerator.readModuleCap test_module
        if cap_data[5].count != 1 or cap_data[1] != exit_node then throw "PART 63 | Disabling Enter changed the Exit node."
        settings_value[15] = 0
        CapHatchGenerator.generateModuleHatches test_module radius_value length_value settings_value lathe_segments:32
        if (CapHatchGenerator.readModuleCap test_module).count != 0 then throw "PART 63 | Disabled owned end remained."
        if (getUserPropVal test_module "SPG_HatchManaged" asString:true) != "1" or CapHatchGenerator.last_module != test_module then
            throw "PART 63 | All-disabled Hatch management state was lost."
        local rejected_radius = false
        try (CapHatchGenerator.makeSeamRadii radius_value radius_value 0 1.0 1.0) catch
        (
            format "PART 63 | Expected invalid end-radius rejection:%\n" (getCurrentException())
            rejected_radius = true
        )
        /* makeSeamRadii has an undefined-on-invalid legacy contract. */
        if not rejected_radius and (CapHatchGenerator.makeSeamRadii radius_value radius_value 0 1.0 1.0) != undefined then
            throw "PART 63 | End radius equal to outer radius was accepted."
        local custom_mod = CapHatchGenerator.createCleanChamfer 2.0 0.5 0.25 seam_depth:3.0 seam_segments:2 top_segments:3 seam_material:77
        if custom_mod.amount != 2.0 or custom_mod.insetamount != 0.25 or custom_mod.insetoffset != 3.0 or custom_mod.insetsegments != 2 or custom_mod.segments != 3 or custom_mod.materialid != 77 then
            throw "PART 63 | Exposed seam controls were not applied independently."
    )
    catch
    (
        format "FAIL PART 63 | %\n" (getCurrentException())
        if isValidNode test_module then
        (
            for child_node in (test_module.children as array) do delete child_node
            delete test_module
        )
        dialog_ref.ui_loading = true
        dialog_ref.ddl_size.SelectedIndex = original_unit
        dialog_ref.changeDimensionUnit original_unit
        dialog_ref.setHatchSettings original_settings
        dialog_ref.ui_loading = original_loading
        CapHatchGenerator.last_node = previous_hatch
        CapHatchGenerator.last_lathe_mod = previous_lathe
        CapHatchGenerator.last_chamfer_mod = previous_chamfer
        CapHatchGenerator.last_module = previous_module
        throw()
    )
    if isValidNode test_module then delete test_module
    dialog_ref.ui_loading = true
    dialog_ref.ddl_size.SelectedIndex = original_unit
    dialog_ref.changeDimensionUnit original_unit
    dialog_ref.setHatchSettings original_settings
    dialog_ref.ui_loading = original_loading
    CapHatchGenerator.last_node = previous_hatch
    CapHatchGenerator.last_lathe_mod = previous_lathe
    CapHatchGenerator.last_chamfer_mod = previous_chamfer
    CapHatchGenerator.last_module = previous_module
    format "PASS PART 63 | Shared mm/cm/m, managed seam controls, outer corner excluded, aligned Enter/Exit, end toggles and ownership.\n"
    true
    -- return
)
if TPG_HatchOptionsRegressionOnly == true then runTpgHatchOptionsRegression()
TPG_HatchOptionsRegressionOnly = false
