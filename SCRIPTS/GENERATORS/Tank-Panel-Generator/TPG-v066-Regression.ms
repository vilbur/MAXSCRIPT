/*
Tests TPG presets (including v0.072 scoped loads), rotation, and per-ID Extrude layout.
Run after loading Tank-Panel-Generator.ms in 3ds Max.
*/

/*
Tests persistent named snapshots independently from the live TPG settings INI.
*/
function testTpgPresetRoundTrip =
(
    local test_ini = (getDir #temp) + "\\TPG_Preset_Test_" + ((random 100000 999999) as string) + ".ini"
    setINISetting test_ini "MainUI" "Rows" "4"
    setINISetting test_ini "MainUI" "Columns" "3"
    setINISetting test_ini "MainUI" "RuleInsets" "0;100;25"
    setINISetting test_ini "MainUI" "SetupExpanded" "1"
    local preset_manager = TPGPresetManager_v ini_path:test_ini main_section:"MainUI"
    if not (preset_manager.savePreset "  Sample A  ") then throw "TPG PRESETS TEST | Save failed."
    if (preset_manager.getPresetNames()) != #("Sample A") then throw "TPG PRESETS TEST | List failed."
    setINISetting test_ini "MainUI" "Rows" "7"
    setINISetting test_ini "MainUI" "RuleInsets" "0;0;0"
    setINISetting test_ini "MainUI" "SetupExpanded" "0"
    if not (preset_manager.loadPreset "Sample A") then throw "TPG PRESETS TEST | Load failed."
    if (getINISetting test_ini "MainUI" "Rows") != "4" then throw "TPG PRESETS TEST | Row round-trip failed."
    if (getINISetting test_ini "MainUI" "RuleInsets") != "0;100;25" then throw "TPG PRESETS TEST | Rule arrays lost."
    if (getINISetting test_ini "MainUI" "SetupExpanded") != "0" then throw "TPG PRESETS TEST | A preset changed the rollout state."
    if not (preset_manager.savePreset "Sample A") then throw "TPG PRESETS TEST | Overwrite failed."
    if (preset_manager.getPresetNames()).count != 1 then throw "TPG PRESETS TEST | Overwrite created a duplicate."
    if not (preset_manager.renamePreset "Sample A" "Panel B") then throw "TPG PRESETS TEST | Rename failed."
    if (preset_manager.getPresetNames()) != #("Panel B") then throw "TPG PRESETS TEST | Rename list failed."
    if not (preset_manager.deletePreset "Panel B") then throw "TPG PRESETS TEST | Delete failed."
    if (preset_manager.getPresetNames()).count != 0 then throw "TPG PRESETS TEST | Deleted preset still listed."
    deleteFile test_ini
    format "PASS TPG PRESETS | save/load/rename/delete/full INI values\n"
    true
    -- return
)

/*
Tests that each preset load mode restores only its own INI settings.
The full mode must still restore all groups for existing saved presets.
*/
function testTpgPresetSectionLoads =
(
    local test_ini = (getDir #temp) + "\\TPG_Preset_Groups_Test_" + ((random 100000 999999) as string) + ".ini"
    local preset_manager = TPGPresetManager_v ini_path:test_ini main_section:"MainUI"
    setINISetting test_ini "MainUI" "Rows" "4"
    setINISetting test_ini "MainUI" "CellIDs" "1;2;3;4"
    setINISetting test_ini "MainUI" "MaterialMode" "1"
    setINISetting test_ini "MainUI" "RuleCount" "99"
    setINISetting test_ini "MainUI" "RuleInsets" "0;10;20"
    setINISetting test_ini "MainUI" "CapEndRadius" "15"
    if not (preset_manager.savePreset "Grouped") then throw "TPG PRESET GROUP TEST | Save failed."

    setINISetting test_ini "MainUI" "Rows" "8"
    setINISetting test_ini "MainUI" "CellIDs" "9;9;9;9"
    setINISetting test_ini "MainUI" "MaterialMode" "0"
    setINISetting test_ini "MainUI" "RuleCount" "120"
    setINISetting test_ini "MainUI" "RuleInsets" "1;1;1"
    setINISetting test_ini "MainUI" "CapEndRadius" "50"

    if not (preset_manager.loadPreset "Grouped" mode:#panels) then throw "TPG PRESET GROUP TEST | Panels load failed."
    if (getINISetting test_ini "MainUI" "Rows") != "4" then throw "TPG PRESET GROUP TEST | Panels did not restore Rows."
    if (getINISetting test_ini "MainUI" "CellIDs") != "1;2;3;4" then throw "TPG PRESET GROUP TEST | Panels did not restore CellIDs."
    if (getINISetting test_ini "MainUI" "MaterialMode") != "1" then throw "TPG PRESET GROUP TEST | Panels did not restore MaterialMode."
    if (getINISetting test_ini "MainUI" "RuleInsets") != "1;1;1" then throw "TPG PRESET GROUP TEST | Panels overwrote extrusion."
    if (getINISetting test_ini "MainUI" "RuleCount") != "120" then throw "TPG PRESET GROUP TEST | Panels overwrote rule count."
    if (getINISetting test_ini "MainUI" "CapEndRadius") != "50" then throw "TPG PRESET GROUP TEST | Panels overwrote hatch."

    setINISetting test_ini "MainUI" "Rows" "8"
    if not (preset_manager.loadPreset "Grouped" mode:#extrude) then throw "TPG PRESET GROUP TEST | Extrude load failed."
    if (getINISetting test_ini "MainUI" "Rows") != "8" then throw "TPG PRESET GROUP TEST | Extrude overwrote panels."
    if (getINISetting test_ini "MainUI" "RuleCount") != "99" then throw "TPG PRESET GROUP TEST | Extrude did not restore rule count."
    if (getINISetting test_ini "MainUI" "RuleInsets") != "0;10;20" then throw "TPG PRESET GROUP TEST | Extrude did not restore inset."
    if (getINISetting test_ini "MainUI" "CapEndRadius") != "50" then throw "TPG PRESET GROUP TEST | Extrude overwrote hatch."

    setINISetting test_ini "MainUI" "RuleInsets" "3;3;3"
    if not (preset_manager.loadPreset "Grouped" mode:#hatch) then throw "TPG PRESET GROUP TEST | Hatch load failed."
    if (getINISetting test_ini "MainUI" "CapEndRadius") != "15" then throw "TPG PRESET GROUP TEST | Hatch did not restore radius."
    if (getINISetting test_ini "MainUI" "Rows") != "8" then throw "TPG PRESET GROUP TEST | Hatch overwrote panels."
    if (getINISetting test_ini "MainUI" "RuleInsets") != "3;3;3" then throw "TPG PRESET GROUP TEST | Hatch overwrote extrusion."

    if (preset_manager.loadPreset "Grouped" mode:#invalid) then throw "TPG PRESET GROUP TEST | Invalid load mode accepted."
    if (getINISetting test_ini "MainUI" "Rows") != "8" then throw "TPG PRESET GROUP TEST | Invalid mode mutated the settings."

    if not (preset_manager.loadPreset "Grouped") then throw "TPG PRESET GROUP TEST | Full load failed."
    if (getINISetting test_ini "MainUI" "Rows") != "4" then throw "TPG PRESET GROUP TEST | Full load omitted panels."
    if (getINISetting test_ini "MainUI" "RuleInsets") != "0;10;20" then throw "TPG PRESET GROUP TEST | Full load omitted extrusion."
    if (getINISetting test_ini "MainUI" "CapEndRadius") != "15" then throw "TPG PRESET GROUP TEST | Full load omitted hatch."
    deleteFile test_ini
    format "PASS TPG PRESET GROUPS | panels/extrude/hatch/all isolated\n"
    true
    -- return
)

/*
Tests generated module orientation without changing scene node rotation.
*/
function testTpgModuleOffsetRotation =
(
    local previous_node = SurfacePanelGenerator.last_node
    local previous_bend = SurfacePanelGenerator.last_bend_mod
    local test_node = undefined
    try
    (
        test_node = SurfacePanelGenerator.generateModule 1 4 (SurfacePanelGenerator.makeMask 1 4 enabled:true) 100.0 200.0 0.0 2 0.01
        if not isValidNode test_node then throw "TPG ROTATION TEST | Generation failed."
        if test_node.rotation != (quat 0 0 0 1) then throw "TPG ROTATION TEST | Node rotation is non-identity."
        if test_node.objectOffsetRot != (quat 0 0 -1 0) then throw "TPG ROTATION TEST | Mesh offset must be 180 degrees around Z."
        if test_node.modifiers.count != 2 or (classOf test_node.modifiers[2]) != Bend then throw "TPG ROTATION TEST | Modifier stack changed."
    )
    catch
    (
        if isValidNode test_node then delete test_node
        SurfacePanelGenerator.last_node = previous_node
        SurfacePanelGenerator.last_bend_mod = previous_bend
        throw()
    )
    if isValidNode test_node then delete test_node
    SurfacePanelGenerator.last_node = previous_node
    SurfacePanelGenerator.last_bend_mod = previous_bend
    format "PASS TPG ROTATION | identity node, offset quaternion, original stack\n"
    true
    -- return
)

/*
Checks material-row heights/colors and Height-before-Inset column order.
*/
function testTpgExtrudeRowLayout =
(
    local dialog_ref = undefined
    for registry_entry in ::dialog_host_registry do
    (
        if registry_entry[1] == "Tank-Panel-Generator" then dialog_ref = registry_entry[2]
    )
    if dialog_ref == undefined then throw "TPG UI TEST | No rollout in dialog registry."
    dialog_ref.rebuildMaterialRows force:true
    local row_controls = dialog_ref.native_rule_slots[1]
    local id_button = row_controls[1]
    if id_button.height != 28 then throw "TPG UI TEST | Material-ID button must fill the 28px row."
    if not id_button.visible then throw "TPG UI TEST | First used Material-ID button is still hidden after row initialization."
    if row_controls[3].pos.x >= row_controls[2].pos.x then throw "TPG UI TEST | HEIGHT must precede INSET."
    if (getProperty id_button #BackColor) == undefined then throw "TPG UI TEST | ID has no background color."
    format "PASS TPG UI | ID colored/full-height, HEIGHT before INSET\n"
    true
    -- return
)

testTpgPresetRoundTrip()
testTpgPresetSectionLoads()
testTpgModuleOffsetRotation()
testTpgExtrudeRowLayout()
