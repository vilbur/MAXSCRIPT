/*
 Tank Panel Generator, version 0.092 — INIT STABLE.
Standalone dockable 2D panel layout editor and cylindrical module generator.
*/






(
    /*
    Explicitly bind the globals supplied by fileIn before compiling the rollout.
    Without these declarations MAXScript can capture undefined implicit locals.
    */
    global IniSettings
    global RolloutState
    global DialogHost
    global ScriptReload
    global ToolTitleButton
    global SurfacePanelGenerator
    global TPGPresetManager_v
    global tpgDecodeExtrusionMode
    global tpgEncodeExtrusionMode
    global CapHatchGenerator
    global restartTool
    global tpg_preset_load_menu




    local project_version = "0.092"
    local source_file = getSourceFileName()




    if source_file == undefined or source_file == "" then
    (
        throw "Tank Panel Generator must be loaded from a saved .ms file."
    )




    local script_dir = getFilenamePath source_file
    local framework_dir = pathConfig.appendPath script_dir "Lib\\"
    local ini_path = script_dir + "Tank-Panel-Generator.ini"
    local startup_log_path = script_dir + "Tank-Panel-Generator-Startup.log"
    local ini_section = "MainUI"
    local tool_key = "Tank-Panel-Generator"
    local tool_prefix = "Tank-Panel-Generator"
    local position_restore_target = undefined
    local position_restore_active = false


    /* Append one timestamped startup marker to the project-local diagnostic log.
    */
    function logSpgStartup stage detail:"" =
    (
        local log_stream = undefined
        try
        (
            log_stream = openFile startup_log_path mode:"a"
            if log_stream == undefined then throw "Could not open startup log."
            format "% | version:% | stage:% | %\n" (localTime as string) project_version stage detail to:log_stream
            close log_stream
            true
        )
        catch
        (
            local exception_text = getCurrentException()
            if log_stream != undefined then try (close log_stream) catch ()
            format "TPG STARTUP LOG ERROR | path:% | stage:% | %\n" startup_log_path stage exception_text
            false
        )
    )


    logSpgStartup "script-enter" detail:source_file




    /*
    Loads a bundled, project-owned copy of the UI helper. No shared Codebase is needed.
    */
    function loadSpgDependency file_path =
    (
        logSpgStartup "dependency-begin" detail:file_path
        if not doesFileExist file_path then
        (
            format "TPG ERROR | Bundled UI helper missing:%\n" file_path
            throw ("TPG | Incomplete local installation. Missing file: " + file_path + ". Synchronize the entire Tank-Panel-Generator/Lib folder.")
        )




        fileIn file_path
        logSpgStartup "dependency-loaded" detail:file_path
        true
        -- return
    )




    /*
    A previous release may have left a struct instance without the newer
    binding and material fields. Inspect its declared members before reading;
    keep a legitimate bound node but never infer Bend ownership from its name.
    */
    local previous_cap_generator = ::CapHatchGenerator
    local previous_cap_node = undefined
    local previous_cap_lathe = undefined
    local previous_cap_chamfer = undefined
    local previous_cap_module = undefined
    if previous_cap_generator != undefined then
    (
        local cap_members = getPropNames previous_cap_generator
        if (findItem cap_members #last_node) > 0 then previous_cap_node = previous_cap_generator.last_node
        if (findItem cap_members #last_lathe_mod) > 0 then previous_cap_lathe = previous_cap_generator.last_lathe_mod
        if (findItem cap_members #last_chamfer_mod) > 0 then previous_cap_chamfer = previous_cap_generator.last_chamfer_mod
        if (findItem cap_members #last_module) > 0 then previous_cap_module = previous_cap_generator.last_module
    )




    local previous_generator = ::SurfacePanelGenerator
    local previously_bound_node = undefined
    local previously_owned_bend = undefined
    local previous_material_mode = #multi
    local previously_assigned_ids = undefined
    local previously_rule_depths = undefined
    local previously_rule_thicknesses = undefined
    local previously_rule_offsets = undefined
    local previously_rule_insets = undefined
    local previously_rule_tapers = undefined




    if previous_generator != undefined then
    (
        local previous_members = getPropNames previous_generator




        if (findItem previous_members #last_node) > 0 then
        (
            previously_bound_node = previous_generator.last_node
        )
        if (findItem previous_members #last_bend_mod) > 0 then
        (
            previously_owned_bend = previous_generator.last_bend_mod
        )
        if (findItem previous_members #material_mode) > 0 then
        (
            previous_material_mode = previous_generator.material_mode
        )
        if (findItem previous_members #cell_ids) > 0 then previously_assigned_ids = previous_generator.cell_ids
        if (findItem previous_members #rule_depths) > 0 then previously_rule_depths = previous_generator.rule_depths
        if (findItem previous_members #rule_thicknesses) > 0 then previously_rule_thicknesses = previous_generator.rule_thicknesses
        if (findItem previous_members #rule_offsets) > 0 then previously_rule_offsets = previous_generator.rule_offsets
        if (findItem previous_members #rule_insets) > 0 then previously_rule_insets = previous_generator.rule_insets
        if (findItem previous_members #rule_tapers) > 0 then previously_rule_tapers = previous_generator.rule_tapers
    )
    logSpgStartup "previous-state-read"




    -- Print exact running source/version before attempting dependency loading.
    -- Stale synchronized local copies can otherwise masquerade as this release.
    format "TPG START | v% | Entry:% | Required:Tank-Panel-Generator-FN.ms, Tank-Panel-Generator-Cap-FN.ms\n" project_version source_file




    loadSpgDependency (framework_dir + "IniSettings.ms")
    loadSpgDependency (framework_dir + "RolloutState.ms")
    loadSpgDependency (framework_dir + "DialogHost.ms")
    loadSpgDependency (framework_dir + "ScriptReload.ms")
    loadSpgDependency (framework_dir + "ToolTitleButton.ms")




    -- Close a legacy-named dialog before loading the new functional modules.
    -- The old dialog's close handler gets an opportunity to persist its state.
    DialogHost.destroyToolDialogs "Surface-Panel-Generator"




    -- Preserve settings on the first launch under the new tool name. The old
    -- INI is left intact so existing installations remain recoverable.
    if not doesFileExist ini_path then
    (
        local legacy_ini_path = script_dir + "Surface-Panel-Generator.ini"
        if doesFileExist legacy_ini_path then
        (
            if not (copyFile legacy_ini_path ini_path) then
            (
                throw ("Tank Panel Generator could not migrate its previous UI settings from: " + legacy_ini_path)
            )
        )
    )
    -- Both dependencies must use Tank filenames. Legacy Surface filenames are
    -- preserved only in archived releases, not loaded as active dependencies.
    loadSpgDependency (script_dir + "Tank-Panel-Generator-FN.ms")
    loadSpgDependency (script_dir + "Tank-Panel-Generator-Cap-FN.ms")
    if isValidNode previous_cap_node then
    (
        CapHatchGenerator.last_node = previous_cap_node
        CapHatchGenerator.last_lathe_mod = previous_cap_lathe
        CapHatchGenerator.last_chamfer_mod = previous_cap_chamfer
        CapHatchGenerator.last_module = previous_cap_module
    )
    else if isValidNode previous_cap_module then
    (
        CapHatchGenerator.last_module = previous_cap_module
    )




    if isValidNode previously_bound_node then
    (
        SurfacePanelGenerator.last_node = previously_bound_node
        SurfacePanelGenerator.last_bend_mod = previously_owned_bend
        SurfacePanelGenerator.material_mode = previous_material_mode
    )
    if previously_assigned_ids != undefined then SurfacePanelGenerator.cell_ids = previously_assigned_ids
    if previously_rule_depths != undefined then SurfacePanelGenerator.rule_depths = previously_rule_depths
    if previously_rule_thicknesses != undefined then SurfacePanelGenerator.rule_thicknesses = previously_rule_thicknesses
    if previously_rule_offsets != undefined then SurfacePanelGenerator.rule_offsets = previously_rule_offsets
    if previously_rule_insets != undefined then SurfacePanelGenerator.rule_insets = previously_rule_insets
    if previously_rule_tapers != undefined then SurfacePanelGenerator.rule_tapers = previously_rule_tapers




    if DialogHost == undefined then
    (
        format "TPG ERROR | DialogHost global not initialized | dependency:%\n" (framework_dir + "DialogHost.ms")
        throw "Tank Panel Generator could not initialize the shared DialogHost."
    )




    rollout surfacePanelGeneratorRollout ("Tank Panel Generator - v" + project_version) width:288 height:1440
    (
        dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:312 height:20
        timer tmr_position_restore interval:500 active:false
        -- Rollout-like sections are collapsible inside the registered dialog bar.
        -- Keep a single owning MAXScript rollout so events and live node state remain scoped.
        groupBox grp_setup "" pos:[6,40] width:276 height:158
        button btn_setup_toggle "- MAIN MODULE" pos:[12,42] width:264 height:22 toolTip:"Expand or collapse the dimensions, repeats, and panel counts."
        label lbl_dimension_radius "RADIUS" pos:[114,68] width:72 height:18
        label lbl_dimension_length "LENGTH" pos:[194,68] width:64 height:18
        spinner spn_radius "" pos:[178,90] width:58 range:[0,1000000,250.0] type:#float scale:0.001 fieldWidth:58 align:#right toolTip:"Positive radius of the cylindrical module in the selected SIZE unit."
        spinner spn_length "" pos:[258,90] width:58 range:[0,1000000,700.0] type:#float scale:0.001 fieldWidth:58 align:#right toolTip:"Positive total axial length of the module in the selected SIZE unit."
        label lbl_base_thickness "BASE THICKNESS" pos:[18,192] width:154 height:18
        spinner spn_base_thickness "" pos:[258,190] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right toolTip:"Thickness of the flat source mesh. Baked into Editable Poly before Bend, Seams or Extrusion; zero keeps a single sheet."
        dotNetControl ddl_size "System.Windows.Forms.ComboBox" pos:[18,90] width:88 height:24
        label lbl_row_repeat "Repeat" pos:[18,126] width:88 height:18
        dotNetControl ddl_repeat_x "System.Windows.Forms.ComboBox" pos:[114,124] width:58 height:24
        dotNetControl ddl_repeat_y "System.Windows.Forms.ComboBox" pos:[194,124] width:58 height:24
        label lbl_row_panels "Grid" pos:[20,150] width:68 height:18
        dotNetControl ddl_columns "System.Windows.Forms.ComboBox" pos:[96,148] width:78 height:24
        dotNetControl ddl_rows "System.Windows.Forms.ComboBox" pos:[185,148] width:78 height:24




        button btn_reset "Reset" pos:[20,236] width:96 height:24 toolTip:"Restore Material ID 1 to every grid cell without changing enabled cells or saved per-ID extrusion rules."
        label lbl_enabled "12 / 12 active" pos:[204,239] width:112 height:18 align:#right
        label lbl_rule_hint "Ctrl+click: select  |  ID buttons: assign" pos:[20,320] width:296 height:18




        dotNetControl btn_generate "System.Windows.Forms.Button" pos:[20,372] width:296 height:48
        button btn_load_object "Load selected object" pos:[18,194] width:252 height:24 toolTip:"Load the selected generated module and continue editing that same object."
        label lbl_bound "Object: none" pos:[20,462] width:296 height:18




        groupBox grp_cap "" pos:[6,456] width:276 height:28
        button btn_cap_toggle "[+] CAP HATCH GENERATOR" pos:[12,458] width:264 height:22 toolTip:"Expand or collapse the separate lathed cap hatch generator."
        label lbl_cap_end "End radius" pos:[20,492] width:184 height:18
        spinner spn_cap_end "" pos:[400,490] width:76 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:48 align:#right toolTip:"Radius at which the lathed cap profile ends towards the centre."
        label lbl_cap_thickness "Inset radius" pos:[20,520] width:184 height:18
        spinner spn_cap_thickness "" pos:[400,518] width:76 range:[0,1000000,3] type:#float scale:0.001 fieldWidth:48 align:#right toolTip:"Hatch outer radius is Main Module Radius plus Inset radius."
        label lbl_cap_depth "Thickness" pos:[20,548] width:184 height:18
        spinner spn_cap_depth "" pos:[400,546] width:76 range:[-1000000,1000000,5] type:#float scale:0.001 fieldWidth:48 align:#right toolTip:"Cap profile displacement along the module axis. Negative values point inward."
        label lbl_cap_seams "Seams" pos:[20,576] width:184 height:18
        dotNetControl ddl_cap_seams "System.Windows.Forms.ComboBox" pos:[240,574] width:100 height:24
        label lbl_cap_first "First seam from outside" pos:[20,604] width:184 height:18
        spinner spn_cap_first "" pos:[400,602] width:76 range:[0,1000000,5] type:#float scale:0.001 fieldWidth:48 align:#right toolTip:"Distance of the first radial seam from the outer edge."
        label lbl_cap_spacing "Seam spacing" pos:[20,632] width:184 height:18
        spinner spn_cap_spacing "" pos:[400,630] width:76 range:[0,1000000,10] type:#float scale:0.001 fieldWidth:48 align:#right toolTip:"Radial separation between adjacent cap seams."
        label lbl_cap_chamfer "Seam Width" pos:[20,660] width:184 height:18
        spinner spn_cap_chamfer "" pos:[400,658] width:76 range:[0,1000000,1] type:#float scale:0.001 fieldWidth:48 align:#right toolTip:"Chamfer amount at boundaries between different cap material IDs."
        label lbl_cap_seam_depth "Seam Depth" pos:[20,688] width:184 height:18
        spinner spn_cap_seam_depth "" pos:[400,686] width:76 range:[-1000000,1000000,5] type:#float scale:0.001 fieldWidth:48 align:#right toolTip:"Offset depth of the seam inset in the selected SIZE unit."
        label lbl_cap_inset "Seam Stich Width" pos:[20,716] width:184 height:18
        spinner spn_cap_inset "" pos:[400,714] width:76 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:48 align:#right toolTip:"Width of the stitch inset around the seam."
        label lbl_cap_seam_segments "Seam Segments" pos:[20,744] width:168 height:18
        spinner spn_cap_seam_segments "" pos:[400,742] width:76 range:[0,100,0] type:#integer fieldWidth:48 align:#right
        label lbl_cap_top_segments "Segments Top" pos:[20,772] width:168 height:18
        spinner spn_cap_top_segments "" pos:[400,770] width:76 range:[0,100,0] type:#integer fieldWidth:48 align:#right
        label lbl_cap_material "Seam Material" pos:[20,800] width:168 height:18
        spinner spn_cap_material "" pos:[400,798] width:76 range:[1,65535,99] type:#integer fieldWidth:48 align:#right
        checkbox chk_cap_enter "Cap Enter" pos:[20,830] width:116 height:20 checked:false toolTip:"Generate a Hatch at the module entrance."
        checkbox chk_cap_exit "Cap Exit" pos:[152,830] width:116 height:20 checked:true toolTip:"Generate a Hatch at the module exit."
        dotNetControl btn_cap_generate "System.Windows.Forms.Button" pos:[20,750] width:252 height:32




        -- Panels owns the paint grid, material palette and per-ID extrusion rows.
        groupBox grp_panels_setup "" pos:[6,492] width:276 height:354
        button btn_panels_setup_toggle "- PANELS" pos:[12,494] width:264 height:22 toolTip:"Expand or collapse the panel pattern, geometry settings, and preview grid."
        dropdownlist ddl_extrusion_mode "" items:#("Group direction","Local normals") selection:1 height:3 pos:[18,544] width:252 tooltip:"Choose height direction for all Material IDs. Local normals follows the selected facets; Group direction preserves the existing behavior."
        label lbl_extrude_title "EXTRUDE - per Material ID" pos:[18,522] width:252 height:18
        label lbl_rule_id "ID" pos:[18,540] width:30 height:18
        dotNetControl dn_extrude_id_host "System.Windows.Forms.Panel" pos:[22,566] width:22 height:28
        spinner spn_extrude_inset_01 "" pos:[110,566] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_01 "" pos:[178,566] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_01 "" pos:[246,566] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_02 "" pos:[110,594] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_02 "" pos:[178,594] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_02 "" pos:[246,594] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_03 "" pos:[110,622] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_03 "" pos:[178,622] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_03 "" pos:[246,622] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_04 "" pos:[110,650] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_04 "" pos:[178,650] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_04 "" pos:[246,650] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_05 "" pos:[110,678] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_05 "" pos:[178,678] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_05 "" pos:[246,678] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_06 "" pos:[110,706] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_06 "" pos:[178,706] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_06 "" pos:[246,706] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_07 "" pos:[110,734] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_07 "" pos:[178,734] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_07 "" pos:[246,734] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_08 "" pos:[110,762] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_08 "" pos:[178,762] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_08 "" pos:[246,762] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_09 "" pos:[110,790] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_09 "" pos:[178,790] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_09 "" pos:[246,790] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_10 "" pos:[110,818] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_10 "" pos:[178,818] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_10 "" pos:[246,818] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_11 "" pos:[110,846] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_11 "" pos:[178,846] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_11 "" pos:[246,846] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_inset_12 "" pos:[110,874] width:58 range:[0,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_height_12 "" pos:[178,874] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        spinner spn_extrude_taper_12 "" pos:[246,874] width:58 range:[-1000000,1000000,0] type:#float scale:0.001 fieldWidth:58 align:#right visible:false
        button btn_rule_previous "< PREV" pos:[18,912] width:60 height:22 visible:false
        label lbl_rule_page "Page 1 / 1" pos:[85,914] width:105 height:18 visible:false
        button btn_rule_next "NEXT >" pos:[210,912] width:60 height:22 visible:false
        label lbl_arc_segments "SUBDIVISION" pos:[18,160] width:88 height:18
        dotNetControl ddl_arc_segments "System.Windows.Forms.ComboBox" pos:[114,158] width:58 height:24
        dotNetControl ddl_length_segments "System.Windows.Forms.ComboBox" pos:[194,158] width:58 height:24
        groupBox grp_grid "Panel Grid" pos:[12,648] width:264 height:240
        dotNetControl dn_id_palette "System.Windows.Forms.FlowLayoutPanel" pos:[18,674] width:252 height:28
        dotNetControl dn_grid_host "System.Windows.Forms.Panel" pos:[18,724] width:252 height:154
        groupBox grp_presets "" pos:[6,946] width:276 height:130
        button btn_presets_toggle "- PRESETS" pos:[12,948] width:264 height:22
        dotNetControl ddl_preset_names "System.Windows.Forms.ComboBox" pos:[18,976] width:252 height:24
        dotNetControl txt_preset_name "System.Windows.Forms.TextBox" pos:[18,1006] width:252 height:24
        button btn_preset_save "Save" pos:[18,1036] width:60 height:24
        button btn_preset_load "Load" pos:[82,1036] width:60 height:24 toolTip:"LMB: Load all. RMB: Choose Panels, Extrude, Seams, Chamfer, or Hatch."
        button btn_preset_rename "Rename" pos:[146,1036] width:60 height:24
        button btn_preset_delete "Delete" pos:[210,1036] width:60 height:24
        label lbl_rule_height "HEIGHT" pos:[28,760] width:100 height:18
        spinner spn_rule_height "" pos:[230,760] width:69 range:[-1000000,1000000,(units.decodeValue "1cm")] type:#float scale:0.1 fieldWidth:54 align:#right toolTip:"HEIGHT: Extrusion height for the active Material ID or all IDs represented by Ctrl-selected panels."
        label lbl_rule_inset "INSET" pos:[28,850] width:100 height:18
        spinner spn_rule_inset "" pos:[230,850] width:69 range:[0,1000000,0] type:#float scale:0.1 fieldWidth:54 align:#right toolTip:"INSET: Inward border width before extrusion. Applies to the active ID or IDs of Ctrl-selected panels."
        label lbl_rule_taper "TAPER" pos:[28,880] width:100 height:18
        spinner spn_rule_taper "" pos:[230,880] width:69 range:[-1000000,1000000,0] type:#float scale:0.1 fieldWidth:54 align:#right toolTip:"TAPER: Signed outline adjustment during extrusion, for the active ID or Ctrl-selected panel IDs."




        -- MATERIAL is an independent root section, never hidden by PANELS.
        groupBox grp_material "" pos:[6,854] width:276 height:88
        button btn_material_toggle "- MATERIAL" pos:[12,856] width:264 height:22 toolTip:"Show or hide the material assignment controls."
        dotNetControl btn_material "System.Windows.Forms.Button" pos:[20,884] width:296 height:24
        label lbl_hint "LMB: Multi-ID   RMB: Grey" pos:[20,916] width:296 height:20


        groupBox grp_seams "" pos:[6,952] width:276 height:114
        button btn_seams_toggle "+ SEAMS" pos:[12,954] width:264 height:22 toolTip:"Axial boundary seam rings using a native Chamfer below Bend."
        checkbox chk_seams_enabled "Enabled" pos:[20,984] width:96 height:22 checked:false toolTip:"Enable the native Seams Chamfer at material boundaries on the flat source sheet."
        label lbl_seams_amount "Amount" pos:[18,1012] width:120 height:18
        spinner spn_seams_amount "" pos:[250,1010] width:76 range:[0,1000000,10] type:#float scale:0.1 fieldWidth:52 align:#right
        label lbl_seams_offset "Inset offset" pos:[18,1040] width:120 height:18
        spinner spn_seams_offset "" pos:[250,1038] width:76 range:[0,1000000,20] type:#float scale:0.1 fieldWidth:52 align:#right


        groupBox grp_chamfer "" pos:[6,1074] width:276 height:114
        button btn_chamfer_toggle "+ CHAMFER" pos:[12,1076] width:264 height:22 toolTip:"Native finishing Chamfer above the procedural panel extrusion."
        checkbox chk_chamfer_enabled "Enabled" pos:[20,1106] width:96 height:22 checked:false
        label lbl_chamfer_amount "Amount" pos:[18,1134] width:120 height:18
        spinner spn_chamfer_amount "" pos:[250,1132] width:76 range:[0,1000000,1] type:#float scale:0.1 fieldWidth:52 align:#right
        label lbl_chamfer_segments "Segments" pos:[18,1162] width:120 height:18
        spinner spn_chamfer_segments "" pos:[250,1160] width:76 range:[0,100,1] type:#integer fieldWidth:52 align:#right toolTip:"Native TPG Chamfer segment count; updates the existing modifier."




        local cell_width = 48.0
        local cell_height = 36.0
        local grid_left = 0.0
        local grid_top = 0.0
        local drag_active = false
        local drag_enable = true
        local drag_changed = false
        local ui_loading = false
        local ui_ready = false
        local active_rule_id = 1
        local selected_cells = #{}
        local cap_expanded = false
        local cap_profile_chamfer_depth = 0.5
        local setup_expanded = true
        local panels_setup_expanded = true
        local material_expanded = true
        local unit_index = 1
        local ui_tooltip = undefined
        local palette_loading = false
        local palette_depth_menu = undefined
        local rule_controls_loading = false
        local rendered_rule_ids = #()
        local native_rule_slots = #()
        local native_rule_controls = #()
        local rule_page_index = 1
        local rule_rows_origin_y = 0
        local presets_expanded = true
        local seams_expanded = false
        local chamfer_expanded = false
        local preset_loading = false
        local preset_manager = undefined
        local position_restore_correction = [6,29]




        /*
        Predeclare rollout-local functions called before their definitions.
        MAXScript resolves rollout functions in declaration order; without these
        locals an early call can bind to undefined (loadUiState previously failed).
        */
        local getSpgUnitScale, getHatchSettings, setHatchSettings, saveBoundObjectUiData, rebuildRuleSelector, rebuildIdPalette, rebuildGrid, rebuildMaterialRows, extrudeRowIdClick, getUsedMaterialIds, saveUiState, updateIdPaletteSelection, refreshBoundModule, settingsChanged, extrusionSettingsChanged, fitGridHeightToGeometry, refreshCapHatch, capSettingsChanged, loadActiveRuleControls, resizeLayout, resetGridMaterialIds




        /* Converts the actual saved screen position to the pre-CUI creation position.
        The measured registration/float displacement is [6,29] pixels.
        */
        function getCorrectedDialogPos saved_pos =
        (
            saved_pos - position_restore_correction
            -- return
        )




        /*
        Displays the bound object; deleted nodes are not silently rebound by name.
        */
        function updateBoundLabel =
        (
            lbl_bound.text = if isValidNode SurfacePanelGenerator.last_node then ("Object: " + SurfacePanelGenerator.last_node.name) else "Object: none"
            true
            -- return
        )




        /*
        Updates the active-cell counter in the owning rollout.
        */
        function updateActiveCount =
        (
            local selected_count = selected_cells.numberSet
            lbl_enabled.text = if selected_count > 0 then ((selected_count as string) + " selected") else (((SurfacePanelGenerator.countEnabled SurfacePanelGenerator.mask) as string) + " / " + (SurfacePanelGenerator.mask.count as string) + " active")
        )




        /*
        Applies the current state to a single .NET button.
        */
        function styleGridButton grid_button enabled assigned_id cell_id =
        (
            local color_class = dotNetClass "System.Drawing.Color"
            local id_color = SurfacePanelGenerator.getPanelColor assigned_id
            local is_selected = selected_cells[cell_id]
            grid_button.Checked = enabled
            grid_button.Text = (assigned_id as string)
            grid_button.BackColor = if enabled then (color_class.FromArgb (id_color.r as integer) (id_color.g as integer) (id_color.b as integer)) else (color_class.FromArgb 68 68 68)
            grid_button.ForeColor = if enabled then (color_class.FromArgb 35 35 35) else (color_class.FromArgb 220 220 220)
            grid_button.FlatAppearance.BorderSize = if is_selected then 3 else 1
            grid_button.FlatAppearance.BorderColor = if is_selected then (color_class.FromArgb 50 230 255) else if assigned_id == active_rule_id then (color_class.FromArgb 255 210 80) else (color_class.FromArgb 120 120 120)
            true
            -- return
        )




        /*
        Height, Inset and Taper display the active swatch ID. When a grid
        selection exists, edits affect each distinct ID used by those cells.
        IDs shared by nonselected cells retain their global per-ID semantics.
        */
        function loadActiveRuleControls =
        (
            if active_rule_id >= 1 and active_rule_id <= SurfacePanelGenerator.rule_depths.count then
            (
                rule_controls_loading = true
                spn_rule_height.value = SurfacePanelGenerator.rule_depths[active_rule_id] / (getSpgUnitScale unit_index)
                spn_rule_inset.value = SurfacePanelGenerator.rule_insets[active_rule_id] / (getSpgUnitScale unit_index)
                spn_rule_taper.value = SurfacePanelGenerator.rule_tapers[active_rule_id] / (getSpgUnitScale unit_index)
                rule_controls_loading = false
            )
            true
        )




        /*
        Returns distinct IDs actually assigned to cells in the source grid.
        Disabled cells keep their assigned IDs and remain configurable.
        Unused IDs and their rule arrays are intentionally not deleted.
        */
        function getUsedMaterialIds =
        (
            local used_bits = #{}
            local used_ids = #()
            for material_id in SurfacePanelGenerator.cell_ids do
            (
                if material_id >= 1 and material_id <= SurfacePanelGenerator.rule_depths.count then
                    used_bits[material_id] = true
            )
            for material_id in used_bits do append used_ids material_id
            used_ids
            -- return
        )
        /* Updates one Material ID from its native spinner without changing other IDs.
        */
        function materialRowNativeChanged material_id field_name property_value =
        (
            if not ui_loading and not rule_controls_loading then
            (
                case field_name of
                (
                    #inset: SurfacePanelGenerator.rule_insets[material_id] = property_value * (getSpgUnitScale unit_index)
                    #height: SurfacePanelGenerator.rule_depths[material_id] = property_value * (getSpgUnitScale unit_index)
                    #taper: SurfacePanelGenerator.rule_tapers[material_id] = property_value * (getSpgUnitScale unit_index)
                )
                extrusionSettingsChanged()
            )
            true
            -- return
        )


        /* Positions the native spinner slots and the hosted colored ID buttons.
        The buttons share a single .NET parent to keep their drawing order stable.
        */
        function layoutMaterialSpinners =
        (
            local content_left = 18
            dn_extrude_id_host.pos = [content_left + 4,rule_rows_origin_y]
            dn_extrude_id_host.width = 22
            dn_extrude_id_host.height = amax 1 (native_rule_controls.count * 28)
            dn_extrude_id_host.visible = panels_setup_expanded and native_rule_controls.count > 0
            for slot_index = 1 to native_rule_slots.count do
            (
                local row_controls = native_rule_slots[slot_index]
                local row_y = rule_rows_origin_y + ((slot_index - 1) * 28)
                local row_visible = panels_setup_expanded and slot_index <= native_rule_controls.count
                row_controls[1].Bounds = dotNetObject "System.Drawing.Rectangle" 0 ((slot_index - 1) * 28) 22 28
                row_controls[1].Visible = row_visible
                for field_index = 1 to 3 do
                (
                    local field_offset = if field_index == 1 then 96 else if field_index == 2 then 28 else 164
                    local field_x = content_left + field_offset
                    row_controls[field_index + 1].pos = [field_x + 64,row_y]
                    row_controls[field_index + 1].visible = row_visible
                )
            )
            dn_extrude_id_host.BringToFront()
            true
            -- return
        )


        /* Routes one native slot's edit to its current material ID.
        */
        function materialRowSlotChanged slot_index field_name property_value =
        (
            local used_index = ((rule_page_index - 1) * 12) + slot_index
            if used_index >= 1 and used_index <= rendered_rule_ids.count then
            (
                materialRowNativeChanged rendered_rule_ids[used_index] field_name property_value
            )
            true
            -- return
        )


        /* Rebinds fixed native spinner slots to the current page of used IDs.
        Existing rule arrays, including unused high IDs, are never truncated.
        */
        function rebuildMaterialRows force:false =
        (
            if not ui_ready then return true
            if native_rule_slots.count == 0 then
            (
                for slot_index = 1 to 12 do
                (
                    local suffix = if slot_index < 10 then ("0" + (slot_index as string)) else (slot_index as string)
                    local id_control = dotNetObject "System.Windows.Forms.Button"
                    local inset_control = getProperty surfacePanelGeneratorRollout (("spn_extrude_inset_" + suffix) as name)
                    local height_control = getProperty surfacePanelGeneratorRollout (("spn_extrude_height_" + suffix) as name)
                    local taper_control = getProperty surfacePanelGeneratorRollout (("spn_extrude_taper_" + suffix) as name)
                    append native_rule_slots #(id_control,inset_control,height_control,taper_control)
                    id_control.Name = "TPG_ExtrudeID_" + suffix
                    id_control.Tag = slot_index
                    id_control.AutoSize = false
                    id_control.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
                    id_control.UseVisualStyleBackColor = false
                    id_control.FlatAppearance.BorderSize = 0
                    id_control.TabStop = false
                    id_control.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                    id_control.Bounds = dotNetObject "System.Drawing.Rectangle" 0 ((slot_index - 1) * 28) 22 28
                    dotNet.addEventHandler id_control "Click" extrudeRowIdClick
                    dn_extrude_id_host.Controls.Add id_control
                )
            )
            local used_ids = getUsedMaterialIds()
            local used_id_set_changed = (used_ids != rendered_rule_ids)
            local page_count = amax 1 (1 + ((floor ((used_ids.count - 1) / 12.0)) as integer))
            rule_page_index = amax 1 (amin page_count rule_page_index)
            if force or used_id_set_changed then
            (
                rule_controls_loading = true
                native_rule_controls = #()
                rendered_rule_ids = used_ids
                lbl_extrude_title.text = "EXTRUDE - " + (used_ids.count as string) + " Material IDs"
                local first_index = ((rule_page_index - 1) * 12) + 1
                for slot_index = 1 to native_rule_slots.count do
                (
                    local used_index = first_index + slot_index - 1
                    local row_controls = native_rule_slots[slot_index]
                    if used_index <= used_ids.count then
                    (
                        local material_id = used_ids[used_index]
                        row_controls[1].text = material_id as string
                        local id_color = SurfacePanelGenerator.getPanelColor material_id
                        local color_class = dotNetClass "System.Drawing.Color"
                        row_controls[1].BackColor = color_class.FromArgb (id_color.r as integer) (id_color.g as integer) (id_color.b as integer)
                        row_controls[1].ForeColor = color_class.FromArgb 30 30 30
                        row_controls[1].FlatAppearance.BorderSize = if material_id == active_rule_id then 2 else 0
                        row_controls[1].FlatAppearance.BorderColor = color_class.FromArgb 255 224 120
                        row_controls[2].value = SurfacePanelGenerator.rule_insets[material_id] / (getSpgUnitScale unit_index)
                        row_controls[3].value = SurfacePanelGenerator.rule_depths[material_id] / (getSpgUnitScale unit_index)
                        row_controls[4].value = SurfacePanelGenerator.rule_tapers[material_id] / (getSpgUnitScale unit_index)
                        append native_rule_controls #(material_id,row_controls[1],row_controls[2],row_controls[3],row_controls[4])
                    )
                )
                rule_controls_loading = false
            )
            lbl_rule_page.text = "Page " + (rule_page_index as string) + " / " + (page_count as string)
            btn_rule_previous.enabled = rule_page_index > 1
            btn_rule_next.enabled = rule_page_index < page_count
            local pager_visible = panels_setup_expanded and page_count > 1
            btn_rule_previous.visible = pager_visible
            btn_rule_next.visible = pager_visible
            lbl_rule_page.visible = pager_visible
            layoutMaterialSpinners()
            if used_id_set_changed and surfacePanelGeneratorRollout.inDialog then
            (
                local dialog_size = getDialogSize surfacePanelGeneratorRollout
                resizeLayout dialog_size.y dialog_size.x
            )
            true
            -- return
        )


        /*
        Makes the full-height colored ID row button choose the matching paint ID.
        High-ID rows remain editable but cannot be selected in the nine-ID palette.
        */
        function extrudeRowIdClick sender event_args =
        (
            local slot_index = sender.Tag as integer
            local used_index = ((rule_page_index - 1) * 12) + slot_index
            if used_index >= 1 and used_index <= rendered_rule_ids.count then
            (
                local selected_id = rendered_rule_ids[used_index]
                if selected_id >= 1 and selected_id <= 9 then
                (
                    active_rule_id = selected_id
                    updateIdPaletteSelection()
                    loadActiveRuleControls()
                    rebuildMaterialRows force:true
                    saveUiState()
                )
            )
            true
            -- return
        )




        /* Changes the visible native spinner page without creating UI controls.
        */
        function showMaterialRulePage page_number =
        (
            rule_page_index = page_number
            rebuildMaterialRows force:true
            if surfacePanelGeneratorRollout.inDialog then
            (
                local dialog_size = getDialogSize surfacePanelGeneratorRollout
                resizeLayout dialog_size.y dialog_size.x
            )
            true
            -- return
        )
        function activeRuleGeometryChanged changed_property new_value =
        (
            if not ui_loading and not rule_controls_loading and active_rule_id >= 1 and active_rule_id <= SurfacePanelGenerator.rule_depths.count then
            (
                local affected_ids = #{}
                if selected_cells.numberSet > 0 then
                (
                    for selected_cell in selected_cells do affected_ids[SurfacePanelGenerator.cell_ids[selected_cell]] = true
                )
                else
                (
                    affected_ids[active_rule_id] = true
                )
                for target_id in affected_ids do
                (
                    case changed_property of
                    (
                        #height: SurfacePanelGenerator.rule_depths[target_id] = new_value * (getSpgUnitScale unit_index)
                        #inset: SurfacePanelGenerator.rule_insets[target_id] = new_value * (getSpgUnitScale unit_index)
                        #taper: SurfacePanelGenerator.rule_tapers[target_id] = new_value * (getSpgUnitScale unit_index)
                    )
                )
                rebuildMaterialRows force:true
                extrusionSettingsChanged()
            )
            true
        )




        /*
        Highlights the selected paint ID without rebuilding the palette.
        */
        function updateIdPaletteSelection =
        (
            local colors = dotNetClass "System.Drawing.Color"
            for button_index = 0 to dn_id_palette.Controls.Count - 1 do
            (
                local palette_button = dn_id_palette.Controls.Item[button_index]
                local button_id = palette_button.Tag as integer
                palette_button.FlatAppearance.BorderSize = if button_id == active_rule_id then 3 else 1
                palette_button.FlatAppearance.BorderColor = if button_id == active_rule_id then (colors.FromArgb 255 224 120) else (colors.FromArgb 75 75 75)
            )
            true
            -- return
        )




        /*
        A palette click chooses the paint ID; when cells are selected, assign
        the clicked ID to every selected cell without clearing the selection.
        */
        function paletteButtonClick sender event_args =
        (
            if not palette_loading and not ui_loading then
            (
                local selected_id = sender.Tag as integer
                if selected_id >= 1 and selected_id <= 9 then
                (
                    active_rule_id = selected_id
                    local changed_cells = false
                    for cell_id in selected_cells do
                    (
                        if not SurfacePanelGenerator.mask[cell_id] or SurfacePanelGenerator.cell_ids[cell_id] != selected_id then
                        (
                            SurfacePanelGenerator.mask[cell_id] = true
                            SurfacePanelGenerator.cell_ids[cell_id] = selected_id
                            changed_cells = true
                        )
                    )
                    loadActiveRuleControls()
                    updateIdPaletteSelection()
                    if changed_cells then
                    (
                        for cell_id in selected_cells do
                        (
                            local grid_button = dn_grid_host.Controls.Item[cell_id - 1]
                            styleGridButton grid_button SurfacePanelGenerator.mask[cell_id] SurfacePanelGenerator.cell_ids[cell_id] cell_id
                        )
                        updateActiveCount()
                        rebuildMaterialRows()
                        settingsChanged()
                    )
                    else saveUiState()
                )
            )
        )




        /*
        Restore Material ID 1 across the logical grid without changing masks,
        high-ID rule arrays, cell-selection state or .NET control identities.
        */
        function resetGridMaterialIds =
        (
            local changed_cells = false
            active_rule_id = 1
            for cell_id = 1 to SurfacePanelGenerator.cell_ids.count do
            (
                if SurfacePanelGenerator.cell_ids[cell_id] != 1 then
                (
                    SurfacePanelGenerator.cell_ids[cell_id] = 1
                    changed_cells = true
                )
                local grid_button = dn_grid_host.Controls.Item[cell_id - 1]
                styleGridButton grid_button SurfacePanelGenerator.mask[cell_id] 1 cell_id
            )
            updateIdPaletteSelection()
            loadActiveRuleControls()
            if changed_cells then
            (
                rebuildMaterialRows()
                settingsChanged()
            )
            else saveUiState()
            true
            -- return
        )




        function rebuildIdPalette =
        (
            palette_loading = true
            dn_id_palette.SuspendLayout()
            for item_index = dn_id_palette.Controls.Count - 1 to 0 by -1 do
            (
                local old_button = dn_id_palette.Controls.Item[item_index]
                dn_id_palette.Controls.Remove old_button
                old_button.Dispose()
            )
            local color_class = dotNetClass "System.Drawing.Color"
            local flat_style = dotNetClass "System.Windows.Forms.FlatStyle"
            local text_align = dotNetClass "System.Drawing.ContentAlignment"
            local palette_count = 9
            -- Nine equal-width buttons occupy the complete palette row.
            local swatch_width = (floor ((dn_id_palette.ClientSize.Width - (palette_count * 2)) / palette_count)) as integer
            for rule_id = 1 to palette_count do
            (
                local swatch = dotNetObject "System.Windows.Forms.Button"
                local id_color = SurfacePanelGenerator.getPanelColor rule_id
                swatch.Name = "SPG_Palette_" + (rule_id as string)
                swatch.Tag = rule_id
                swatch.Text = rule_id as string
                swatch.Width = swatch_width
                swatch.Height = 22
                swatch.Margin = dotNetObject "System.Windows.Forms.Padding" 1 1 1 1
                swatch.FlatStyle = flat_style.Flat
                swatch.UseVisualStyleBackColor = false
                swatch.BackColor = color_class.FromArgb (id_color.r as integer) (id_color.g as integer) (id_color.b as integer)
                swatch.ForeColor = color_class.FromArgb 30 30 30
                swatch.TextAlign = text_align.MiddleCenter
                swatch.TabStop = false
                if ui_tooltip != undefined then ui_tooltip.SetToolTip swatch ("Material ID " + (rule_id as string) + ". Click: paint with this ID; if Ctrl-selected panels exist, assign this ID to all of them.")
                dotNet.addEventHandler swatch "Click" paletteButtonClick
                dn_id_palette.Controls.Add swatch
            )
            dn_id_palette.ResumeLayout()
            palette_loading = false
            updateIdPaletteSelection()
            true
            -- return
        )




        /*
        Displays every dropdown item when screen space permits. Long lists
        are capped by the screen working area and remain scrollable.
        */
        function fitDropdownPopup dropdown_control =
        (
            local display_height = (dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea.Height
            local item_height = amax 16 dropdown_control.ItemHeight
            local popup_height = (amax 1 dropdown_control.Items.Count) * item_height + 4
            dropdown_control.IntegralHeight = false
            dropdown_control.DropDownHeight = amax 28 (amin popup_height (amax 96 (display_height - 120)))
            true
            -- return
        )




        /*
        Fills a read-only .NET integer dropdown with inclusive limits.
        */
        function fillIntegerDropdown dropdown_control first_number last_number =
        (
            dropdown_control.Items.Clear()
            for number_value = first_number to last_number do
            (
                dropdown_control.Items.Add (number_value as string)
            )
            fitDropdownPopup dropdown_control
            true
            -- return
        )




        /*
        Selects a numeric item, retaining existing INI values outside presets.
        The integer-only dropdown never exposes non-numeric choices.
        */
        function setIntegerDropdown dropdown_control numeric_value =
        (
            local rounded_value = if numeric_value >= 0.0 then (floor (numeric_value + 0.5)) as integer else (ceil (numeric_value - 0.5)) as integer
            local value_text = rounded_value as string
            local item_index = dropdown_control.Items.IndexOf value_text
            if item_index < 0 then
            (
                dropdown_control.Items.Add value_text
                item_index = dropdown_control.Items.Count - 1
                fitDropdownPopup dropdown_control
            )
            dropdown_control.SelectedIndex = item_index
            true
            -- return
        )




        /*
        Returns the selected integer without relying on zero-based item offsets.
        */
        function getIntegerDropdown dropdown_control =
        (
            if dropdown_control.SelectedIndex < 0 then
            (
                format "TPG ERROR | Integer dropdown has no selection.\n"
                throw "Tank Panel Generator: an integer dropdown has no selection."
            )
            (dropdown_control.Text as integer)
            -- return
        )




        /* Read Auto as zero while preserving existing numeric Length counts.
           The sentinel is stored by the existing INI and preset pipeline.
        */
        function getLengthSegmentsSetting =
        (
            if ddl_length_segments.Text == "Auto" then 0 else getIntegerDropdown ddl_length_segments
            -- return
        )

        /* Restore Auto or a manual Length count, including custom saved counts.
           Numeric zero is never presented as a subdivision count in the UI.
        */
        function setLengthSegmentsSetting segment_count =
        (
            if segment_count == 0 then ddl_length_segments.SelectedIndex = 0 else setIntegerDropdown ddl_length_segments segment_count
            true
            -- return
        )

        /*
        Configures a native-height .NET ComboBox as a read-only integer list.
        */
        function setupSpgDropdown dropdown_control =
        (
            dropdown_control.DropDownStyle = (dotNetClass "System.Windows.Forms.ComboBoxStyle").DropDownList
            dropdown_control.IntegralHeight = false
            dropdown_control.DropDownHeight = 28
            true
            -- return
        )




        /*
        Returns the number of scene system units per one selected display unit.
        The SIZE dropdown is explicit: 0=mm, 1=cm, 2=m.
        */
        function getSpgUnitScale selected_index =
        (
            case selected_index of
            (
                0: units.decodeValue "1mm"
                1: units.decodeValue "1cm"
                2: units.decodeValue "1m"
                default: units.decodeValue "1m"
            )
            -- return
        )




        /*
        Migrates old unit indices to SIZE mm/cm/m. Scene, inches and feet
        map to metre display only;
        persisted Radius/Length retain their system-unit values.
        */
        function migrateSpgUnitIndex old_index schema_version =
        (
            local physical_index = if schema_version == 0 then old_index - 1 else old_index
            if physical_index >= 0 and physical_index <= 2 then physical_index else 2
            -- return
        )




        /*
        Converts the displayed dimension back into unmodified system units.
        */
        function moduleRadius =
        (
            spn_radius.value * (getSpgUnitScale unit_index)
            -- return
        )




        function moduleBaseThickness =
        (
            spn_base_thickness.value * (getSpgUnitScale unit_index)
            -- return
        )


        function moduleLength =
        (
            spn_length.value * (getSpgUnitScale unit_index)
            -- return
        )




        /* Read all Hatch distances in scene units; counts/IDs remain unitless.
           The legacy dimensionless Chamfer profile depth stays internal.
        */
        function getHatchSettings =
        (
            local unit_scale = getSpgUnitScale unit_index
            #(spn_cap_end.value * unit_scale,spn_cap_thickness.value * unit_scale,spn_cap_depth.value * unit_scale,(getIntegerDropdown ddl_cap_seams),spn_cap_first.value * unit_scale,spn_cap_spacing.value * unit_scale,spn_cap_chamfer.value * unit_scale,cap_profile_chamfer_depth,spn_cap_inset.value * unit_scale,spn_cap_seam_depth.value * unit_scale,spn_cap_seam_segments.value,spn_cap_top_segments.value,spn_cap_material.value,(if chk_cap_enter.checked then 1 else 0),(if chk_cap_exit.checked then 1 else 0))
            -- return
        )

        /* Restore scene-valued Hatch settings in the selected tool unit.
           Nine-value legacy snapshots retain their original physical sizes.
        */
        function setHatchSettings scene_values =
        (
            local restored_values = copy scene_values #noMap
            local unit_scale = getSpgUnitScale unit_index
            if restored_values.count == 9 then
            (
                for extra_value in #(5.0 * unit_scale,0,0,99) do append restored_values extra_value
            )
            if restored_values.count == 13 then
            (
                append restored_values 0
                append restored_values 1
            )
            if restored_values.count != 15 then throw "TPG HATCH | Invalid settings count."
            spn_cap_end.value = restored_values[1] / unit_scale
            spn_cap_thickness.value = restored_values[2] / unit_scale
            spn_cap_depth.value = restored_values[3] / unit_scale
            setIntegerDropdown ddl_cap_seams (restored_values[4] as integer)
            spn_cap_first.value = restored_values[5] / unit_scale
            spn_cap_spacing.value = restored_values[6] / unit_scale
            spn_cap_chamfer.value = restored_values[7] / unit_scale
            cap_profile_chamfer_depth = restored_values[8]
            spn_cap_inset.value = restored_values[9] / unit_scale
            spn_cap_seam_depth.value = restored_values[10] / unit_scale
            spn_cap_seam_segments.value = restored_values[11]
            spn_cap_top_segments.value = restored_values[12]
            spn_cap_material.value = restored_values[13]
            chk_cap_enter.checked = restored_values[14] == 1
            chk_cap_exit.checked = restored_values[15] == 1
            true
            -- return
        )

        /*
        Moves all dimension displays when changing units, without regenerating
        intermediate geometry or changing the true world-space dimensions.
        */
        function changeDimensionUnit new_index =
        (
            if new_index != unit_index and new_index >= 0 then
            (
                local radius_scene = moduleRadius()
                local length_scene = moduleLength()
                local thickness_scene = moduleBaseThickness()
                local hatch_settings = getHatchSettings()
                local previous_loading = ui_loading
                ui_loading = true
                unit_index = new_index
                local scale_value = getSpgUnitScale unit_index
                spn_radius.value = radius_scene / scale_value
                spn_length.value = length_scene / scale_value
                spn_base_thickness.value = thickness_scene / scale_value
                setHatchSettings hatch_settings
                spn_seams_amount.value = SurfacePanelGenerator.seams_amount / scale_value
                spn_seams_offset.value = SurfacePanelGenerator.seams_offset / scale_value
                spn_chamfer_amount.value = SurfacePanelGenerator.chamfer_amount / scale_value
                rebuildMaterialRows force:true
                loadActiveRuleControls()
                ui_loading = previous_loading
                if not ui_loading then saveUiState()
            )
            true
            -- return
        )




        /*
        Saves the complete logical panel layout beside the owning .ms script.
        */
        function saveUiState =
        (
            IniSettings.setInteger ini_path ini_section "Rows" SurfacePanelGenerator.rows
            IniSettings.setInteger ini_path ini_section "Columns" SurfacePanelGenerator.columns
            IniSettings.setInteger ini_path ini_section "XMultiplier" (getIntegerDropdown ddl_repeat_x)
            IniSettings.setInteger ini_path ini_section "YMultiplier" (getIntegerDropdown ddl_repeat_y)
            IniSettings.setString ini_path ini_section "Mask" (SurfacePanelGenerator.encodeMask SurfacePanelGenerator.mask)
            IniSettings.setString ini_path ini_section "CellIDs" (SurfacePanelGenerator.encodeCellIds SurfacePanelGenerator.cell_ids)
            IniSettings.setString ini_path ini_section "MaterialMode" (if SurfacePanelGenerator.material_mode == #gray then "Gray" else "Multi")
            IniSettings.setString ini_path ini_section "ExtrusionMode" (tpgEncodeExtrusionMode SurfacePanelGenerator.extrusion_mode)
            IniSettings.setInteger ini_path ini_section "SeamsEnabled" (if chk_seams_enabled.checked then 1 else 0)
            IniSettings.setFloat ini_path ini_section "SeamsAmount" (spn_seams_amount.value * (getSpgUnitScale unit_index))
            IniSettings.setFloat ini_path ini_section "SeamsOffset" (spn_seams_offset.value * (getSpgUnitScale unit_index))
            IniSettings.setInteger ini_path ini_section "ChamferEnabled" (if chk_chamfer_enabled.checked then 1 else 0)
            IniSettings.setFloat ini_path ini_section "ChamferAmount" (spn_chamfer_amount.value * (getSpgUnitScale unit_index))
            IniSettings.setInteger ini_path ini_section "ChamferSegments" spn_chamfer_segments.value
            IniSettings.setInteger ini_path ini_section "RuleCount" SurfacePanelGenerator.rule_depths.count
            IniSettings.setString ini_path ini_section "RuleDepths" (SurfacePanelGenerator.encodeRuleDepths SurfacePanelGenerator.rule_depths)
            IniSettings.setString ini_path ini_section "RuleThicknesses" (SurfacePanelGenerator.encodeRuleDepths SurfacePanelGenerator.rule_thicknesses)
            IniSettings.setString ini_path ini_section "RuleOffsets" (SurfacePanelGenerator.encodeRuleDepths SurfacePanelGenerator.rule_offsets)
            IniSettings.setString ini_path ini_section "RuleInsets" (SurfacePanelGenerator.encodeRuleDepths SurfacePanelGenerator.rule_insets)
            IniSettings.setString ini_path ini_section "RuleTapers" (SurfacePanelGenerator.encodeRuleDepths SurfacePanelGenerator.rule_tapers)
            IniSettings.setInteger ini_path ini_section "ActiveRuleID" active_rule_id
            IniSettings.setFloat ini_path ini_section "Radius" (moduleRadius())
            IniSettings.setFloat ini_path ini_section "Length" (moduleLength())
            IniSettings.setFloat ini_path ini_section "BaseThickness" (moduleBaseThickness())
            IniSettings.setInteger ini_path ini_section "ArcSegments" (getIntegerDropdown ddl_arc_segments)
            IniSettings.setInteger ini_path ini_section "LengthSegments" (getLengthSegmentsSetting())
            IniSettings.setInteger ini_path ini_section "CapExpanded" (if cap_expanded then 1 else 0)
            IniSettings.setInteger ini_path ini_section "SetupExpanded" (if setup_expanded then 1 else 0)
            IniSettings.setInteger ini_path ini_section "PanelsSetupExpanded" (if panels_setup_expanded then 1 else 0)
            IniSettings.setInteger ini_path ini_section "MaterialExpanded" (if material_expanded then 1 else 0)
            IniSettings.setInteger ini_path ini_section "PresetsExpanded" (if presets_expanded then 1 else 0)
            IniSettings.setInteger ini_path ini_section "SeamsExpanded" (if seams_expanded then 1 else 0)
            IniSettings.setInteger ini_path ini_section "ChamferExpanded" (if chamfer_expanded then 1 else 0)
            IniSettings.setInteger ini_path ini_section "DimensionUnit" unit_index
            IniSettings.setInteger ini_path ini_section "DimensionUnitSchema" 2
            local cap_values = getHatchSettings()
            IniSettings.setFloat ini_path ini_section "CapEndRadius" cap_values[1]
            IniSettings.setFloat ini_path ini_section "CapThickness" cap_values[2]
            IniSettings.setFloat ini_path ini_section "CapDepth" cap_values[3]
            IniSettings.setInteger ini_path ini_section "CapSeams" cap_values[4]
            IniSettings.setFloat ini_path ini_section "CapFirstSeam" cap_values[5]
            IniSettings.setFloat ini_path ini_section "CapSeamSpacing" cap_values[6]
            IniSettings.setFloat ini_path ini_section "CapChamferAmount" cap_values[7]
            IniSettings.setFloat ini_path ini_section "CapChamferDepth" cap_values[8]
            IniSettings.setFloat ini_path ini_section "CapInset" cap_values[9]
            IniSettings.setFloat ini_path ini_section "CapSeamDepth" cap_values[10]
            IniSettings.setInteger ini_path ini_section "CapSeamSegments" cap_values[11]
            IniSettings.setInteger ini_path ini_section "CapTopSegments" cap_values[12]
            IniSettings.setInteger ini_path ini_section "CapSeamMaterial" cap_values[13]
            IniSettings.setInteger ini_path ini_section "CapEnter" cap_values[14]
            IniSettings.setInteger ini_path ini_section "CapExit" cap_values[15]
            saveBoundObjectUiData()
            true
            -- return
        )




        /* Store editor-only preferences on the bound module beside geometry data.
        */
        function saveBoundObjectUiData =
        (
            if not ui_loading and isValidNode SurfacePanelGenerator.last_node then
            (
                local source_node = SurfacePanelGenerator.last_node
                setUserProp source_node "SPG_DimensionUnit" unit_index
                setUserProp source_node "SPG_ActiveRuleID" active_rule_id
                local cap_values = getHatchSettings()
                setUserProp source_node "SPG_CapSettings" (SurfacePanelGenerator.encodeRuleDepths cap_values)
            )
            true
            -- return
        )


        /* Validate the complete selected-object record before changing editor state.
        Loading does not generate geometry; subsequent edits target this exact node.
        */
        function loadObjectData source_node =
        (
            local previous_loading = ui_loading
            local object_data = undefined
            local cap_data = #()
            local cap_values = #(0.0,3.0,5.0,3,5.0,10.0,1.0,0.5,0.0)
            local saved_brush = 1
            local validation_ok = true
            try
            (
                object_data = SurfacePanelGenerator.readModuleData source_node
                cap_data = CapHatchGenerator.readModuleCap source_node default_seam_depth:(5.0 * (getSpgUnitScale object_data.unit_index))
                local cap_text = getUserPropVal source_node "SPG_CapSettings" asString:true
                if cap_data.count == 0 and cap_text != undefined then
                (
                    local cap_tokens = filterString cap_text ";"
                    if cap_tokens.count != 9 and cap_tokens.count != 13 and cap_tokens.count != 15 then throw "TPG LOAD | Invalid saved cap settings."
                    cap_values = for token_text in cap_tokens collect (token_text as float)
                )
                if cap_data.count > 0 then cap_values = cap_data[4]
                if cap_values.count == 9 then
                    for extra_value in #(5.0 * (getSpgUnitScale object_data.unit_index),0,0,99) do append cap_values extra_value
                if cap_values.count == 13 then
                (
                    append cap_values 0
                    append cap_values 1
                )
                for cap_value in cap_values do
                (
                    if cap_value == undefined then throw "TPG LOAD | Non-numeric cap setting."
                )
                if cap_values[1] < 0 or cap_values[2] < 0 or cap_values[4] < 0 or cap_values[4] > 16 or cap_values[4] != (cap_values[4] as integer) or cap_values[5] <= 0 or cap_values[6] <= 0 or cap_values[7] < 0 or cap_values[8] < -10 or cap_values[8] > 10 or cap_values[9] < 0 then
                    throw "TPG LOAD | Invalid saved Hatch dimensions or seam count."
                for count_index in #(11,12,13,14,15) do
                (
                    local count_value = cap_values[count_index]
                    local minimum_value = if count_index == 13 then 1 else 0
                    local maximum_value = if count_index >= 14 then 1 else if count_index == 13 then 65535 else 100
                    if count_value != (count_value as integer) or count_value < minimum_value or count_value > maximum_value then
                        throw ("TPG LOAD | Invalid Hatch count/material at index:" + count_index as string + " value:" + count_value as string)
                )
                if cap_data.count > 0 then
                (
                    local restored_seams = CapHatchGenerator.makeSeamRadii (object_data.radius_value + cap_values[2]) cap_values[1] (cap_values[4] as integer) cap_values[5] cap_values[6]
                    if restored_seams == undefined then throw "TPG LOAD | Saved child Hatch profile is incompatible with the module."
                )
                for rule_values in #(object_data.rule_depths,object_data.rule_insets,object_data.rule_tapers) do
                (
                    for rule_value in rule_values do
                    (
                        if rule_value != rule_value or rule_value < -1.0e30 or rule_value > 1.0e30 then throw "TPG LOAD | Stored extrusion value exceeds native spinner range."
                    )
                )
                local display_scale = getSpgUnitScale object_data.unit_index
                if object_data.radius_value / display_scale <= 0.0 or object_data.radius_value / display_scale > 1.0e30 or object_data.length_value / display_scale <= 0.0 or object_data.length_value / display_scale > 1.0e30 then
                    throw "TPG LOAD | Saved dimensions exceed the editor's spinner range."
                local brush_text = getUserPropVal source_node "SPG_ActiveRuleID" asString:true
                if brush_text != undefined then
                (
                    saved_brush = brush_text as integer
                    if saved_brush == undefined or (brush_text as float) != saved_brush or saved_brush < 1 or saved_brush > 9 then throw "TPG LOAD | Invalid saved paint ID."
                )
            )
            catch
            (
                local exception_text = getCurrentException()
                format "TPG LOAD ERROR | node:% | %\n" source_node exception_text
                validation_ok = false
            )
            if validation_ok then
            (
                ui_loading = true
                try
                (
                    SurfacePanelGenerator.rows = object_data.rows
                    SurfacePanelGenerator.columns = object_data.columns
                    SurfacePanelGenerator.mask = object_data.mask
                    SurfacePanelGenerator.cell_ids = object_data.cell_ids
                    SurfacePanelGenerator.rule_depths = object_data.rule_depths
                    SurfacePanelGenerator.rule_thicknesses = object_data.rule_thicknesses
                    SurfacePanelGenerator.rule_offsets = object_data.rule_offsets
                    SurfacePanelGenerator.rule_insets = object_data.rule_insets
                    SurfacePanelGenerator.rule_tapers = object_data.rule_tapers
                    SurfacePanelGenerator.material_mode = object_data.material_mode
                    SurfacePanelGenerator.extrusion_mode = object_data.extrusion_mode
                    SurfacePanelGenerator.seams_enabled = object_data.seams_enabled
                    SurfacePanelGenerator.seams_amount = object_data.seams_amount
                    SurfacePanelGenerator.seams_offset = object_data.seams_offset
                    SurfacePanelGenerator.chamfer_enabled = object_data.chamfer_enabled
                    SurfacePanelGenerator.chamfer_amount = object_data.chamfer_amount
                    SurfacePanelGenerator.chamfer_segments = object_data.chamfer_segments
                    SurfacePanelGenerator.base_thickness = object_data.base_thickness
                    chk_seams_enabled.checked = object_data.seams_enabled
                    spn_seams_amount.value = object_data.seams_amount / (getSpgUnitScale object_data.unit_index)
                    spn_seams_offset.value = object_data.seams_offset / (getSpgUnitScale object_data.unit_index)
                    chk_chamfer_enabled.checked = object_data.chamfer_enabled
                    spn_chamfer_amount.value = object_data.chamfer_amount / (getSpgUnitScale object_data.unit_index)
                    spn_chamfer_segments.value = object_data.chamfer_segments
                    ddl_extrusion_mode.selection = if object_data.extrusion_mode == #local then 2 else 1
                    SurfacePanelGenerator.last_node = source_node
                    SurfacePanelGenerator.last_bend_mod = object_data.bend_mod
                    unit_index = object_data.unit_index
                    ddl_size.SelectedIndex = unit_index
                    local display_scale = getSpgUnitScale unit_index
                    spn_radius.value = object_data.radius_value / display_scale
                    spn_length.value = object_data.length_value / display_scale
                    spn_base_thickness.value = object_data.base_thickness / display_scale
                    setIntegerDropdown ddl_rows object_data.rows
                    setIntegerDropdown ddl_columns object_data.columns
                    setIntegerDropdown ddl_repeat_x object_data.repeat_x
                    setIntegerDropdown ddl_repeat_y object_data.repeat_y
                    setIntegerDropdown ddl_arc_segments object_data.arc_segments
                    setLengthSegmentsSetting (if object_data.length_segments_auto then 0 else object_data.length_segments)
                    setHatchSettings cap_values
                    CapHatchGenerator.last_node = if cap_data.count > 0 then cap_data[1] else undefined
                    CapHatchGenerator.last_lathe_mod = if cap_data.count > 0 then cap_data[2] else undefined
                    CapHatchGenerator.last_chamfer_mod = if cap_data.count > 0 then cap_data[3] else undefined
                    CapHatchGenerator.last_module = if cap_data.count > 0 or (getUserPropVal source_node "SPG_HatchManaged" asString:true) == "1" then source_node else undefined
                    active_rule_id = saved_brush
                    selected_cells = #{}
                    selected_cells.count = object_data.mask.count
                    rebuildRuleSelector()
                    loadActiveRuleControls()
                    rebuildMaterialRows force:true
                    rebuildGrid()
                    updateBoundLabel()
                    fitGridHeightToGeometry()
                )
                catch
                (
                    local exception_text = getCurrentException()
                    ui_loading = previous_loading
                    rule_controls_loading = false
                    format "TPG LOAD ERROR | Could not restore editor | %\n" exception_text
                    throw()
                )
                ui_loading = previous_loading
                saveUiState()
                dn_grid_host.Refresh()
                format "TPG | Loaded editable generator data from:% (geometry unchanged).\n" source_node.name
            )
            validation_ok
            -- return
        )


        /*
        Restores grid dimensions, cell mask, and generation settings.
        */
        function loadUiState =
        (
            local rows_value = IniSettings.getInteger ini_path ini_section "Rows" default_value:4
            local columns_value = IniSettings.getInteger ini_path ini_section "Columns" default_value:3
            local stored_material_mode = IniSettings.getString ini_path ini_section "MaterialMode" default_value:"Multi"
            if stored_material_mode != "Multi" and stored_material_mode != "Gray" then
            (
                format "TPG | Unknown saved material mode:% | fallback:Multi\n" stored_material_mode
                stored_material_mode = "Multi"
            )
            SurfacePanelGenerator.material_mode = if stored_material_mode == "Gray" then #gray else #multi
            SurfacePanelGenerator.extrusion_mode = tpgDecodeExtrusionMode (IniSettings.getString ini_path ini_section "ExtrusionMode" default_value:"Group")
            ddl_extrusion_mode.selection = if SurfacePanelGenerator.extrusion_mode == #local then 2 else 1
            SurfacePanelGenerator.seams_enabled = (IniSettings.getInteger ini_path ini_section "SeamsEnabled" default_value:0) == 1
            SurfacePanelGenerator.seams_amount = IniSettings.getFloat ini_path ini_section "SeamsAmount" default_value:10.0
            SurfacePanelGenerator.seams_offset = IniSettings.getFloat ini_path ini_section "SeamsOffset" default_value:20.0
            SurfacePanelGenerator.chamfer_enabled = (IniSettings.getInteger ini_path ini_section "ChamferEnabled" default_value:0) == 1
            SurfacePanelGenerator.chamfer_amount = IniSettings.getFloat ini_path ini_section "ChamferAmount" default_value:1.0
            SurfacePanelGenerator.chamfer_segments = IniSettings.getInteger ini_path ini_section "ChamferSegments" default_value:1
            chk_seams_enabled.checked = SurfacePanelGenerator.seams_enabled
            chk_chamfer_enabled.checked = SurfacePanelGenerator.chamfer_enabled
            spn_chamfer_segments.value = SurfacePanelGenerator.chamfer_segments




            SurfacePanelGenerator.rows = amax 1 (amin 32 rows_value)
            SurfacePanelGenerator.columns = amax 1 (amin 32 columns_value)
            SurfacePanelGenerator.mask = SurfacePanelGenerator.decodeMask (IniSettings.getString ini_path ini_section "Mask" default_value:"") (SurfacePanelGenerator.rows * SurfacePanelGenerator.columns) default_enabled:true
            setIntegerDropdown ddl_rows SurfacePanelGenerator.rows
            setIntegerDropdown ddl_columns SurfacePanelGenerator.columns
            setIntegerDropdown ddl_repeat_x (amax 1 (amin 16 (IniSettings.getInteger ini_path ini_section "XMultiplier" default_value:1)))
            setIntegerDropdown ddl_repeat_y (amax 1 (amin 16 (IniSettings.getInteger ini_path ini_section "YMultiplier" default_value:1)))
            local stored_unit = IniSettings.getInteger ini_path ini_section "DimensionUnit" default_value:1
            local stored_schema = IniSettings.getInteger ini_path ini_section "DimensionUnitSchema" default_value:1
            unit_index = migrateSpgUnitIndex stored_unit stored_schema
            ddl_size.SelectedIndex = unit_index
            local scale_value = getSpgUnitScale unit_index
            spn_seams_amount.value = SurfacePanelGenerator.seams_amount / scale_value
            spn_seams_offset.value = SurfacePanelGenerator.seams_offset / scale_value
            spn_chamfer_amount.value = SurfacePanelGenerator.chamfer_amount / scale_value
            spn_radius.value = (IniSettings.getFloat ini_path ini_section "Radius" default_value:(units.decodeValue "2500mm")) / scale_value
            spn_length.value = (IniSettings.getFloat ini_path ini_section "Length" default_value:(units.decodeValue "7000mm")) / scale_value
            SurfacePanelGenerator.base_thickness = amax 0.0 (IniSettings.getFloat ini_path ini_section "BaseThickness" default_value:0.0)
            spn_base_thickness.value = SurfacePanelGenerator.base_thickness / scale_value
            -- New ID heights default to an exact physical centimetre.
            -- Existing per-ID saved heights are preserved below.
            local default_height = units.decodeValue "1cm"
            setIntegerDropdown ddl_arc_segments (IniSettings.getInteger ini_path ini_section "ArcSegments" default_value:8)
            setLengthSegmentsSetting (IniSettings.getInteger ini_path ini_section "LengthSegments" default_value:0)
            cap_expanded = (IniSettings.getInteger ini_path ini_section "CapExpanded" default_value:0) == 1
            setup_expanded = (IniSettings.getInteger ini_path ini_section "SetupExpanded" default_value:1) == 1
            panels_setup_expanded = (IniSettings.getInteger ini_path ini_section "PanelsSetupExpanded" default_value:1) == 1
            material_expanded = (IniSettings.getInteger ini_path ini_section "MaterialExpanded" default_value:1) == 1
            presets_expanded = (IniSettings.getInteger ini_path ini_section "PresetsExpanded" default_value:1) == 1
            seams_expanded = (IniSettings.getInteger ini_path ini_section "SeamsExpanded" default_value:0) == 1
            chamfer_expanded = (IniSettings.getInteger ini_path ini_section "ChamferExpanded" default_value:0) == 1
            setHatchSettings #((IniSettings.getFloat ini_path ini_section "CapEndRadius" default_value:0.0),(IniSettings.getFloat ini_path ini_section "CapThickness" default_value:3.0),(IniSettings.getFloat ini_path ini_section "CapDepth" default_value:5.0),(IniSettings.getInteger ini_path ini_section "CapSeams" default_value:3),(IniSettings.getFloat ini_path ini_section "CapFirstSeam" default_value:5.0),(IniSettings.getFloat ini_path ini_section "CapSeamSpacing" default_value:10.0),(IniSettings.getFloat ini_path ini_section "CapChamferAmount" default_value:1.0),(IniSettings.getFloat ini_path ini_section "CapChamferDepth" default_value:0.5),(IniSettings.getFloat ini_path ini_section "CapInset" default_value:0.0),(IniSettings.getFloat ini_path ini_section "CapSeamDepth" default_value:(5.0 * scale_value)),(IniSettings.getInteger ini_path ini_section "CapSeamSegments" default_value:0),(IniSettings.getInteger ini_path ini_section "CapTopSegments" default_value:0),(IniSettings.getInteger ini_path ini_section "CapSeamMaterial" default_value:99),(IniSettings.getInteger ini_path ini_section "CapEnter" default_value:0),(IniSettings.getInteger ini_path ini_section "CapExit" default_value:1))
            SurfacePanelGenerator.cell_ids = SurfacePanelGenerator.decodeCellIds (IniSettings.getString ini_path ini_section "CellIDs" default_value:"") SurfacePanelGenerator.rows SurfacePanelGenerator.columns
            local rule_count = amax (IniSettings.getInteger ini_path ini_section "RuleCount" default_value:99) (amax 99 (amax (SurfacePanelGenerator.rows * SurfacePanelGenerator.columns) (SurfacePanelGenerator.cell_ids.count)))
            -- Older INI files have no RuleCount. Recover their serialized
            -- array lengths before loading; unused high IDs must survive.
            local old_depth_count = (filterString (IniSettings.getString ini_path ini_section "RuleDepths" default_value:"") ";").count
            local old_inset_count = (filterString (IniSettings.getString ini_path ini_section "RuleInsets" default_value:"") ";").count
            local old_taper_count = (filterString (IniSettings.getString ini_path ini_section "RuleTapers" default_value:"") ";").count
            rule_count = amax rule_count (amax old_depth_count (amax old_inset_count old_taper_count))
            for cell_id in SurfacePanelGenerator.cell_ids do rule_count = amax rule_count cell_id
            SurfacePanelGenerator.rule_depths = SurfacePanelGenerator.decodeRuleDepths (IniSettings.getString ini_path ini_section "RuleDepths" default_value:"") rule_count default_height
            -- Preserve signed, fractional heights and the previous ID values.
            SurfacePanelGenerator.rule_thicknesses = SurfacePanelGenerator.decodeRuleDepths (IniSettings.getString ini_path ini_section "RuleThicknesses" default_value:"") rule_count 0.0
            SurfacePanelGenerator.rule_offsets = SurfacePanelGenerator.decodeRuleDepths (IniSettings.getString ini_path ini_section "RuleOffsets" default_value:"") rule_count 0.0
            SurfacePanelGenerator.rule_insets = SurfacePanelGenerator.decodeRuleDepths (IniSettings.getString ini_path ini_section "RuleInsets" default_value:"") rule_count 0.0
            SurfacePanelGenerator.rule_tapers = SurfacePanelGenerator.decodeRuleDepths (IniSettings.getString ini_path ini_section "RuleTapers" default_value:"") rule_count 0.0
            active_rule_id = amax 1 (amin 32 (IniSettings.getInteger ini_path ini_section "ActiveRuleID" default_value:1))
            rebuildRuleSelector()
            loadActiveRuleControls()
            true
            -- return
        )




        /*
        Rebinds preset selection after a save, rename, or deletion.
        */
        function refreshPresetNames selected_name:undefined =
        (
            local saved_name = selected_name
            if saved_name == undefined and ddl_preset_names.SelectedIndex >= 0 then saved_name = ddl_preset_names.Text
            preset_loading = true
            ddl_preset_names.Items.Clear()
            local selected_index = -1
            for preset_name in (preset_manager.getPresetNames()) do
            (
                local added_index = ddl_preset_names.Items.Add preset_name
                if saved_name != undefined and preset_name == saved_name then selected_index = added_index
            )
            ddl_preset_names.SelectedIndex = selected_index
            if selected_index >= 0 then txt_preset_name.Text = ddl_preset_names.Text
            fitDropdownPopup ddl_preset_names
            preset_loading = false
            true
            -- return
        )


        /*
        Saves current generator parameters under the entered preset name.
        */
        function saveNamedPreset =
        (
            local preset_name = txt_preset_name.Text
            if preset_name == "" and ddl_preset_names.SelectedIndex >= 0 then preset_name = ddl_preset_names.Text
            if preset_name != "" then
            (
                saveUiState()
                if preset_manager.savePreset preset_name then refreshPresetNames selected_name:(trimRight (trimLeft preset_name))
            )
            true
            -- return
        )


        /*
        Loads all or one section of a preset and updates only the affected geometry.
        */
        function loadNamedPreset mode:#all =
        (
            if ddl_preset_names.SelectedIndex < 0 then return false
            local preset_name = ddl_preset_names.Text
            saveUiState()
            if not (preset_manager.loadPreset preset_name mode:mode) then return false
            local previous_loading = ui_loading
            ui_loading = true
            try
            (
                loadUiState()
                selected_cells = #{}
                selected_cells.count = SurfacePanelGenerator.mask.count
                rebuildMaterialRows force:true
                rebuildGrid()
                updateActiveCount()
                fitGridHeightToGeometry()
            )
            catch
            (
                ui_loading = previous_loading
                throw()
            )
            ui_loading = previous_loading
            case mode of
            (
                #extrude: extrusionSettingsChanged()
                #seams: chamferSettingsChanged()
                #chamfer: chamferSettingsChanged()
                #hatch: capSettingsChanged()
                default: settingsChanged()
            )
            true
            -- return
        )


        /*
        Changes only the selected preset's name, leaving its stored values intact.
        */
        function renameNamedPreset =
        (
            if ddl_preset_names.SelectedIndex < 0 then return false
            local new_name = trimRight (trimLeft txt_preset_name.Text)
            if preset_manager.renamePreset ddl_preset_names.Text new_name then refreshPresetNames selected_name:new_name
            true
            -- return
        )


        /*
        Confirms deletion of the selected preset before removing its INI section.
        */
        function deleteNamedPreset =
        (
            if ddl_preset_names.SelectedIndex < 0 then return false
            local selected_name = ddl_preset_names.Text
            if queryBox ("Delete TPG preset '" + selected_name + "'?") title:"Tank Panel Generator" then
            (
                if preset_manager.deletePreset selected_name then
                (
                    refreshPresetNames()
                    txt_preset_name.Text = ""
                )
            )
            true
            -- return
        )


        /*
        Rebuilds the nine-button palette without an ID dropdown.
        Historical IDs above nine remain in saved cell data and rule arrays.
        */
        function rebuildRuleSelector =
        (
            active_rule_id = amax 1 (amin 9 active_rule_id)
            rebuildIdPalette()
            true
            -- return
        )




        /*
        Applies one paint stroke to the cell under the current screen pointer.
        */
        function paintCellUnderPointer enabled =
        (
            local control_type = dotNetClass "System.Windows.Forms.Control"
            local point_value = dn_grid_host.PointToClient control_type.MousePosition
            -- Letterboxing centres the flat-plane preview when its aspect
            -- ratio does not match the host. Subtract the same origin used
            -- to draw the buttons, otherwise painting selects the wrong ID.
            local column_id = ((floor ((point_value.X - grid_left) / cell_width)) as integer) + 1
            local row_id = ((floor ((point_value.Y - grid_top) / cell_height)) as integer) + 1




            if row_id >= 1 and row_id <= SurfacePanelGenerator.rows and column_id >= 1 and column_id <= SurfacePanelGenerator.columns then
            (
                local cell_id = ((row_id - 1) * SurfacePanelGenerator.columns) + column_id




                if SurfacePanelGenerator.mask[cell_id] != enabled or (enabled and SurfacePanelGenerator.cell_ids[cell_id] != active_rule_id) then
                (
                    SurfacePanelGenerator.mask[cell_id] = enabled
                    if enabled then SurfacePanelGenerator.cell_ids[cell_id] = active_rule_id
                    local grid_button = dn_grid_host.Controls.Item[cell_id - 1]
                    styleGridButton grid_button enabled SurfacePanelGenerator.cell_ids[cell_id] cell_id
                    updateActiveCount()
                    drag_changed = true
                )
            )




            true
            -- return
        )




        /*
        Ctrl-click toggles a panel selection without painting or changing IDs.
        Plain left/right mouse actions retain the existing painting behavior.
        */
        function togglePanelSelection cell_id =
        (
            if cell_id >= 1 and cell_id <= SurfacePanelGenerator.mask.count then
            (
                selected_cells[cell_id] = not selected_cells[cell_id]
                local grid_button = dn_grid_host.Controls.Item[cell_id - 1]
                styleGridButton grid_button SurfacePanelGenerator.mask[cell_id] SurfacePanelGenerator.cell_ids[cell_id] cell_id
                updateActiveCount()
                true
            )
            else
            (
                format "TPG SELECTION ERROR | Cell:% expected 1..%\n" cell_id SurfacePanelGenerator.mask.count
                false
            )
        )




        /*
        Begins a left-enable or right-disable stroke without relying on automatic checkbox toggling.
        */
        function gridMouseDown sender event_args =
        (
            local mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"
            local key_state = (dotNetClass "System.Windows.Forms.Control").ModifierKeys as string
            local ctrl_pressed = (findString key_state "Control") != undefined
            if event_args.Button == mouse_buttons.Left or event_args.Button == mouse_buttons.Right then
            (
                if ctrl_pressed then
                (
                    drag_active = false
                    togglePanelSelection (sender.Tag as integer)
                )
                else
                (
                    drag_active = true
                    drag_changed = false
                    drag_enable = (event_args.Button == mouse_buttons.Left)
                    paintCellUnderPointer drag_enable
                )
            )
        )




        /*
        Continues painting while the original checkbox owns mouse capture.
        */
        function gridMouseMove sender event_args =
        (
            if drag_active then paintCellUnderPointer drag_enable
        )




        /*
        Ends a panel painting stroke.
        */
        function gridMouseUp sender event_args =
        (
            if drag_active then paintCellUnderPointer drag_enable
            drag_active = false
            if drag_changed then
            (
                rebuildMaterialRows()
                fitGridHeightToGeometry()
                saveUiState()
                refreshBoundModule()
            )
            drag_changed = false
        )




        /*
        Fit the source panel pattern proportionally inside the grid host.
        If the physical aspect ratio would make the pattern narrower than 50%
        of the host width, stretch only the displayed X dimension to that floor.
        Keep the original Y scale, centre both axes and never change geometry.
        */
        function layoutGridButtons =
        (
            local columns_value = amax 1 SurfacePanelGenerator.columns
            local rows_value = amax 1 SurfacePanelGenerator.rows
            local usable_width = amax columns_value dn_grid_host.ClientSize.Width
            local usable_height = amax rows_value dn_grid_host.ClientSize.Height
            local real_cell_size = SurfacePanelGenerator.getUnbentPanelDimensions rows_value columns_value (moduleRadius()) (moduleLength()) x_multiplier:(getIntegerDropdown ddl_repeat_x)




            if real_cell_size == undefined then
            (
                format "TPG ERROR | Cannot calculate unbent panel preview dimensions.\n"
                false
            )
            else
            (
                local source_width = real_cell_size.x * columns_value
                local source_height = real_cell_size.y * rows_value
                local pixel_scale = amin ((usable_width as float) / source_width) ((usable_height as float) / source_height)
                local minimum_grid_width = (usable_width as float) * 0.5
                cell_width = amax (real_cell_size.x * pixel_scale) (minimum_grid_width / columns_value)
                cell_height = real_cell_size.y * pixel_scale
                local content_width = cell_width * columns_value
                local content_height = cell_height * rows_value
                grid_left = ((usable_width as float) - content_width) / 2.0
                grid_top = ((usable_height as float) - content_height) / 2.0




                if dn_grid_host.Controls.Count == (rows_value * columns_value) then
                (
                    dn_grid_host.SuspendLayout()
                    for row_id = 1 to rows_value do
                    (
                        local top_y = (floor (grid_top + ((row_id - 1) * cell_height))) as integer
                        local bottom_y = (floor (grid_top + (row_id * cell_height))) as integer
                        for column_id = 1 to columns_value do
                        (
                            local left_x = (floor (grid_left + ((column_id - 1) * cell_width))) as integer
                            local right_x = (floor (grid_left + (column_id * cell_width))) as integer
                            local cell_id = ((row_id - 1) * columns_value) + column_id
                            local grid_button = dn_grid_host.Controls.Item[cell_id - 1]
                            grid_button.Bounds = dotNetObject "System.Drawing.Rectangle" left_x top_y (amax 1 (right_x - left_x)) (amax 1 (bottom_y - top_y))
                        )
                    )
                    dn_grid_host.ResumeLayout()
                )
                true
            )
            -- return
        )




        /*
        Exposes the live preview's unrounded panel scale and offset for
        repeatable UI tests, without changing geometry or dialog state.
        */
        function getPanelPreviewMetrics =
        (
            #(grid_left, grid_top, cell_width, cell_height)
            -- return
        )




        /*
        Rebuilds interactive cell buttons when logical panel counts change.
        */
        function rebuildGrid =
        (
            dn_grid_host.SuspendLayout()
            drag_active = false
            drag_changed = false
            if selected_cells.count != SurfacePanelGenerator.mask.count then
            (
                selected_cells = #{}
                selected_cells.count = SurfacePanelGenerator.mask.count
            )




            for item_id = dn_grid_host.Controls.Count - 1 to 0 by -1 do
            (
                local old_button = dn_grid_host.Controls.Item[item_id]
                dn_grid_host.Controls.Remove old_button
                old_button.Dispose()
            )




            local color_class = dotNetClass "System.Drawing.Color"
            local appearance_type = dotNetClass "System.Windows.Forms.Appearance"
            local flat_style_type = dotNetClass "System.Windows.Forms.FlatStyle"




            for row_id = 1 to SurfacePanelGenerator.rows do
            (
                for column_id = 1 to SurfacePanelGenerator.columns do
                (
                    local cell_id = ((row_id - 1) * SurfacePanelGenerator.columns) + column_id
                    local grid_button = dotNetObject "System.Windows.Forms.CheckBox"
                    grid_button.Name = "SPG_Cell_" + (cell_id as string)
                    grid_button.Tag = cell_id
                    grid_button.Appearance = appearance_type.Button
                    grid_button.AutoCheck = false
                    grid_button.AutoSize = false
                    grid_button.FlatStyle = flat_style_type.Flat
                    grid_button.FlatAppearance.BorderSize = 1
                    grid_button.Text = (SurfacePanelGenerator.cell_ids[cell_id] as string)
                    grid_button.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
                    grid_button.Bounds = dotNetObject "System.Drawing.Rectangle" 1 1 8 8
                    grid_button.TabStop = false
                    styleGridButton grid_button SurfacePanelGenerator.mask[cell_id] SurfacePanelGenerator.cell_ids[cell_id] cell_id
                    if ui_tooltip != undefined then
                    (
                        ui_tooltip.SetToolTip grid_button ("Source panel " + (cell_id as string) + ". Ctrl+click: select/deselect without changing its ID. LMB: paint. RMB: disable.")
                    )




                    dotNet.addEventHandler grid_button "MouseDown" gridMouseDown
                    dotNet.addEventHandler grid_button "MouseMove" gridMouseMove
                    dotNet.addEventHandler grid_button "MouseUp" gridMouseUp
                    dn_grid_host.Controls.Add grid_button
                )
            )




            dn_grid_host.AutoScrollMinSize = dotNetObject "System.Drawing.Size" 0 0
            dn_grid_host.ResumeLayout()
            layoutGridButtons()
            updateActiveCount()
            rebuildMaterialRows()
            if surfacePanelGeneratorRollout.inDialog then fitGridHeightToGeometry()
            true
            -- return
        )




        /*
        Resizes only the logical grid and preserves overlapping panel states.
        */
        function applyGridDimensions rows_value columns_value =
        (
            if rows_value != SurfacePanelGenerator.rows or columns_value != SurfacePanelGenerator.columns then
            (
                SurfacePanelGenerator.cell_ids = SurfacePanelGenerator.resizeCellIds SurfacePanelGenerator.cell_ids SurfacePanelGenerator.rows SurfacePanelGenerator.columns rows_value columns_value
                SurfacePanelGenerator.mask = SurfacePanelGenerator.resizeMask SurfacePanelGenerator.mask SurfacePanelGenerator.rows SurfacePanelGenerator.columns rows_value columns_value
                SurfacePanelGenerator.rows = rows_value
                SurfacePanelGenerator.columns = columns_value
                selected_cells = #{}
                selected_cells.count = rows_value * columns_value
                local rule_count = amax 99 (amax (rows_value * columns_value) SurfacePanelGenerator.rule_depths.count)
                SurfacePanelGenerator.rule_depths = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_depths rule_count (units.decodeValue "1cm")
                SurfacePanelGenerator.rule_thicknesses = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_thicknesses rule_count 0.0
                SurfacePanelGenerator.rule_offsets = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_offsets rule_count 0.0
                SurfacePanelGenerator.rule_insets = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_insets rule_count 0.0
                SurfacePanelGenerator.rule_tapers = SurfacePanelGenerator.resizeRuleDepths SurfacePanelGenerator.rule_tapers rule_count 0.0
                rebuildRuleSelector()
                rebuildGrid()
                fitGridHeightToGeometry()
                settingsChanged()
            )
            true
            -- return
        )




        /*
        Regenerates the existing bound node when a setting changes.
        Initial UI loading and a missing/deleted node must never spawn an object.
        */
        function refreshBoundModule =
        (
            if not ui_loading and isValidNode SurfacePanelGenerator.last_node then
            (
                local precision_value = 0.01
                local original_node = SurfacePanelGenerator.last_node
                local result_node = undefined




                undo "TPG - Live Update" on
                (
                    result_node = SurfacePanelGenerator.generateModule SurfacePanelGenerator.rows SurfacePanelGenerator.columns SurfacePanelGenerator.mask (moduleRadius()) (moduleLength()) (units.decodeValue "1cm") (getIntegerDropdown ddl_arc_segments) precision_value x_multiplier:(getIntegerDropdown ddl_repeat_x) y_multiplier:(getIntegerDropdown ddl_repeat_y) target_node:original_node owned_bend:SurfacePanelGenerator.last_bend_mod material_mode_value:SurfacePanelGenerator.material_mode cell_ids_value:SurfacePanelGenerator.cell_ids rule_depths_value:SurfacePanelGenerator.rule_depths rule_thicknesses_value:SurfacePanelGenerator.rule_thicknesses rule_offsets_value:SurfacePanelGenerator.rule_offsets rule_insets_value:SurfacePanelGenerator.rule_insets rule_tapers_value:SurfacePanelGenerator.rule_tapers extrusion_mode_value:SurfacePanelGenerator.extrusion_mode length_segments:(getLengthSegmentsSetting()) seams_enabled_value:SurfacePanelGenerator.seams_enabled seams_amount_value:SurfacePanelGenerator.seams_amount seams_offset_value:SurfacePanelGenerator.seams_offset chamfer_enabled_value:SurfacePanelGenerator.chamfer_enabled chamfer_amount_value:SurfacePanelGenerator.chamfer_amount chamfer_segments_value:SurfacePanelGenerator.chamfer_segments base_thickness_value:(moduleBaseThickness())
                )




                if not isValidNode result_node then
                (
                    format "TPG ERROR | Live update failed; bound node:% (unchanged if validation refused).\n" original_node
                )
                if isValidNode result_node then refreshCapHatch()
                updateBoundLabel()
            )
            true
            -- return
        )




        /*
        Build or update a cap attached to the current module. Initial UI load
        does not create one; subsequent settings changes update an existing cap.
        */
        function refreshCapHatch force_create:false =
        (
            if not ui_loading and (force_create or isValidNode CapHatchGenerator.last_node or isValidNode CapHatchGenerator.last_module) then
            (
                local source_module = if isValidNode SurfacePanelGenerator.last_node then SurfacePanelGenerator.last_node else undefined
                local previous_hatch = if isValidNode CapHatchGenerator.last_node then CapHatchGenerator.last_node else undefined
                local previously_linked = isValidNode source_module and CapHatchGenerator.last_module == source_module
                local generate_linked = isValidNode source_module and (force_create or previously_linked)
                local standalone_target = if isValidNode previous_hatch and not isValidNode CapHatchGenerator.last_module and (getUserPropVal previous_hatch "SPG_StandaloneHatch" asString:true) == "1" then previous_hatch else undefined
                local expanded_radius = moduleRadius()
                local expanded_length = (moduleLength()) * (getIntegerDropdown ddl_repeat_y)
                local lathe_segments = amax 32 (getIntegerDropdown ddl_arc_segments) * SurfacePanelGenerator.columns * (getIntegerDropdown ddl_repeat_x)
                local cap_result = undefined
                local cap_values = getHatchSettings()
                if generate_linked or force_create or isValidNode standalone_target then
                (
                    undo "Tank Panel Generator - Generate Hatch" on
                    (
                        if generate_linked then
                        (
                            local linked_target = if previously_linked then previous_hatch else undefined
                            cap_result = CapHatchGenerator.generateModuleHatches source_module expanded_radius expanded_length cap_values lathe_segments:lathe_segments
                        )
                        else
                        (
                            cap_result = CapHatchGenerator.generateStandaloneHatch expanded_radius cap_values[1] cap_values[2] cap_values[3] (cap_values[4] as integer) cap_values[5] cap_values[6] lathe_segments:lathe_segments target_node:standalone_target owned_lathe:CapHatchGenerator.last_lathe_mod owned_chamfer:CapHatchGenerator.last_chamfer_mod chamfer_amount:cap_values[7] chamfer_depth:cap_values[8] stitch_width:cap_values[9] seam_depth:cap_values[10] seam_segments:(cap_values[11] as integer) top_segments:(cap_values[12] as integer) seam_material:(cap_values[13] as integer)
                        )
                    )
                    if not isValidNode cap_result and (not generate_linked or chk_cap_enter.checked or chk_cap_exit.checked) then format "TPG HATCH ERROR | Generation failed: verify radii, profile seams and modifier ownership.\n"
                )
            )
            true
            -- return
        )




        /*
        Persists the cap values and live-updates only a previously generated cap.
        */
        function capSettingsChanged =
        (
            if not ui_loading then
            (
                saveUiState()
                refreshCapHatch()
            )
            true
            -- return
        )




        /*
        Persists changed parameters and refreshes existing geometry.
        Does not generate a new scene node until the user presses Generate.
        */
        function settingsChanged =
        (
            if not ui_loading then
            (
                saveUiState()
                refreshBoundModule()
            )
            true
            -- return
        )


        /*
        Limit the finishing bevel to half every nonzero extrusion component
        on used Material IDs; zero values impose no positive-width limit.
        */
        function clampChamferAmount =
        (
            local smallest_positive = 1.0e30
            for rule_id in (getUsedMaterialIds()) do
            (
                if rule_id <= SurfacePanelGenerator.rule_depths.count then
                (
                    local current_dimensions = #(abs SurfacePanelGenerator.rule_depths[rule_id],abs SurfacePanelGenerator.rule_insets[rule_id],abs SurfacePanelGenerator.rule_tapers[rule_id])
                    for dimension_value in current_dimensions do
                    (
                        if dimension_value > 0.0 then smallest_positive = amin smallest_positive dimension_value
                    )
                )
            )
            if smallest_positive < 1.0e30 and (spn_chamfer_amount.value * (getSpgUnitScale unit_index)) > (smallest_positive * 0.5) then
            (
                local previous_loading = ui_loading
                ui_loading = true
                spn_chamfer_amount.value = (smallest_positive * 0.5) / (getSpgUnitScale unit_index)
                ui_loading = previous_loading
                format "TPG CHAMFER | Reduced finishing Amount to 50 percent of the smallest nonzero Height/Inset/Taper value: %\n" spn_chamfer_amount.value
            )
            true
            -- return
        )


        /*
        Updates only the existing TPG Extrusion for Height, Inset and Taper.
        Radius, grid, subdivisions and other structural controls retain full rebuild.
        */
        function extrusionSettingsChanged =
        (
            if not ui_loading then
            (
                clampChamferAmount()
                SurfacePanelGenerator.chamfer_amount = spn_chamfer_amount.value * (getSpgUnitScale unit_index)
                SurfacePanelGenerator.chamfer_segments = spn_chamfer_segments.value
                saveUiState()
                if isValidNode SurfacePanelGenerator.last_node then
                (
                    local edited_node = SurfacePanelGenerator.last_node
                    local extrusion_result = undefined
                    try
                    (
                        undo "TPG - Edit Extrusion Only" on
                        (
                            extrusion_result = SurfacePanelGenerator.updateExtrusionOnly edited_node SurfacePanelGenerator.last_bend_mod rule_depths_value:SurfacePanelGenerator.rule_depths rule_insets_value:SurfacePanelGenerator.rule_insets rule_tapers_value:SurfacePanelGenerator.rule_tapers extrusion_mode_value:SurfacePanelGenerator.extrusion_mode
                        )
                    )
                    catch
                    (
                        format "TPG FAST ERROR | Extrusion-only refresh failed: %\n" (getCurrentException())
                    )
                    if isValidNode extrusion_result then
                    (
                        updateBoundLabel()
                        SurfacePanelGenerator.syncChamferStack edited_node SurfacePanelGenerator.last_bend_mod seams_enabled_value:SurfacePanelGenerator.seams_enabled seams_amount_value:SurfacePanelGenerator.seams_amount seams_offset_value:SurfacePanelGenerator.seams_offset chamfer_enabled_value:SurfacePanelGenerator.chamfer_enabled chamfer_amount_value:SurfacePanelGenerator.chamfer_amount chamfer_segments_value:SurfacePanelGenerator.chamfer_segments
                    )
                )
            )
            true
            -- return
        )


        /*
        Updates only the two tool-owned native Chamfer modifiers on the bound node.
        The procedural extrusion remains enabled and retains its existing instance.
        */
        function chamferSettingsChanged =
        (
            if not ui_loading then
            (
                clampChamferAmount()
                SurfacePanelGenerator.seams_enabled = chk_seams_enabled.checked
                SurfacePanelGenerator.seams_amount = spn_seams_amount.value * (getSpgUnitScale unit_index)
                SurfacePanelGenerator.seams_offset = spn_seams_offset.value * (getSpgUnitScale unit_index)
                SurfacePanelGenerator.chamfer_enabled = chk_chamfer_enabled.checked
                SurfacePanelGenerator.chamfer_amount = spn_chamfer_amount.value * (getSpgUnitScale unit_index)
                SurfacePanelGenerator.chamfer_segments = spn_chamfer_segments.value
                saveUiState()
                if isValidNode SurfacePanelGenerator.last_node then
                (
                    try
                    (
                        undo "TPG - Edit Seams and Chamfer" on
                        (
                            SurfacePanelGenerator.syncChamferStack SurfacePanelGenerator.last_node SurfacePanelGenerator.last_bend_mod seams_enabled_value:SurfacePanelGenerator.seams_enabled seams_amount_value:SurfacePanelGenerator.seams_amount seams_offset_value:SurfacePanelGenerator.seams_offset chamfer_enabled_value:SurfacePanelGenerator.chamfer_enabled chamfer_amount_value:SurfacePanelGenerator.chamfer_amount chamfer_segments_value:SurfacePanelGenerator.chamfer_segments
                        )
                    )
                    catch
                    (
                        format "TPG CHAMFER ERROR | %\n" (getCurrentException())
                    )
                )
            )
            true
            -- return
        )




        /*
        Root order: Main Module, Panels, Presets, Material, Seams, Chamfer, Hatch.
        The dialog stays at the original 288px width. Only the Panels
        grid host is fixed at exactly 264px height. Existing saved dialog
        height and the original 288px dialog width are unchanged.
        */
        function resizeLayout available_height available_width =
        (
            -- Retain original 288px dialog width and keep the panel grid
            -- exactly 264px high; preserve native spinner and aspect ratio.
            available_width = amax 288 available_width
            local section_left = 6
            local section_width = available_width - 12
            local header_left = 12
            local header_width = available_width - 24
            local content_left = 18
            local content_width = available_width - 36
            local section_y = 40
            local spacing = 8
            local radius_x = 114
            local length_x = 194
            local cap_spinner_x = available_width - 94
            -- Native MAXScript spinners have a visually hidden 64px X origin.
            local native_spinner_offset_x = 64




            -- MAIN MODULE: independent outer group with full-width controls.
            local main_height = if setup_expanded then 284 else 28
            grp_setup.pos = [section_left,section_y]
            grp_setup.width = section_width
            grp_setup.height = main_height
            btn_setup_toggle.pos = [header_left,section_y + 2]
            btn_setup_toggle.width = header_width
            btn_setup_toggle.text = if setup_expanded then "- MAIN MODULE" else "+ MAIN MODULE"
            ddl_size.pos = [content_left,section_y + 50]
            ddl_size.width = 88
            lbl_dimension_radius.pos = [radius_x,section_y + 28]
            lbl_dimension_length.pos = [length_x,section_y + 28]
            spn_radius.pos = [radius_x + native_spinner_offset_x,section_y + 50]
            spn_length.pos = [length_x + native_spinner_offset_x,section_y + 50]
            lbl_row_repeat.pos = [content_left,section_y + 86]
            ddl_repeat_x.pos = [radius_x,section_y + 84]
            ddl_repeat_x.width = 58
            ddl_repeat_y.pos = [length_x,section_y + 84]
            ddl_repeat_y.width = 58
            -- Subdivisions are the final input row; precision is internal.
            lbl_arc_segments.text = "SUBDIVISION"
            lbl_arc_segments.pos = [content_left,section_y + 120]
            lbl_arc_segments.width = 88
            ddl_arc_segments.pos = [radius_x,section_y + 118]
            ddl_arc_segments.width = 58
            ddl_length_segments.pos = [length_x,section_y + 118]
            ddl_length_segments.width = 58
            lbl_base_thickness.pos = [content_left,section_y + 154]
            spn_base_thickness.pos = [length_x + native_spinner_offset_x,section_y + 152]
            local main_fields = #(ddl_size,lbl_dimension_radius,lbl_dimension_length,spn_radius,spn_length,lbl_row_repeat,ddl_repeat_x,ddl_repeat_y,lbl_arc_segments,ddl_arc_segments,ddl_length_segments,lbl_base_thickness,spn_base_thickness)
            for ctrl in main_fields do ctrl.visible = setup_expanded




            -- Generate is directly in MAIN MODULE; no one-control subrollout.
            btn_load_object.pos = [content_left,section_y + 184]
            btn_load_object.width = content_width
            btn_load_object.visible = setup_expanded
            btn_generate.pos = [content_left,section_y + 214]
            btn_generate.width = content_width
            btn_generate.height = 48
            lbl_bound.pos = [content_left,section_y + 266]
            lbl_bound.width = content_width
            btn_generate.visible = setup_expanded
            lbl_bound.visible = setup_expanded
            section_y += main_height + spacing




            -- PANELS: panel-count/paint controls are directly in PANELS.
            -- There is no additional LAYOUT rollout or collapse state.
            local material_height = if material_expanded then 82 else 28
            local cap_height = if cap_expanded then 466 else 28
            local used_rule_count = (getUsedMaterialIds()).count
            local page_count = amax 1 (1 + ((floor ((used_rule_count - 1) / 12.0)) as integer))
            rule_page_index = amax 1 (amin page_count rule_page_index)
            local visible_rule_count = amin 12 (amax 1 (used_rule_count - ((rule_page_index - 1) * 12)))
            local rule_list_height = visible_rule_count * 28
            local pager_height = if page_count > 1 then 26 else 0
            local extrusion_height = 68 + rule_list_height + pager_height
            local palette_height = 28
            local panel_fixed_height = 140 + extrusion_height
            local grid_host_height = 264
            local panels_height = if panels_setup_expanded then (panel_fixed_height + grid_host_height) else 28




            grp_panels_setup.pos = [section_left,section_y]
            grp_panels_setup.width = section_width
            grp_panels_setup.height = panels_height
            btn_panels_setup_toggle.pos = [header_left,section_y + 2]
            btn_panels_setup_toggle.width = header_width
            btn_panels_setup_toggle.text = if panels_setup_expanded then "- PANELS" else "+ PANELS"
            lbl_row_panels.pos = [content_left,section_y + 34]
            lbl_row_panels.width = 56
            ddl_columns.pos = [80,section_y + 30]
            ddl_columns.width = 58
            ddl_rows.pos = [160,section_y + 30]
            ddl_rows.width = 58
            btn_reset.pos = [content_left,section_y + 60]
            btn_reset.width = 96
            lbl_enabled.pos = [content_left + 106,section_y + 62]
            lbl_enabled.width = content_width - 106
            local grid_y = section_y + 86
            grp_grid.pos = [header_left,grid_y]
            grp_grid.width = header_width
            grp_grid.height = grid_host_height + 8
            grp_grid.text = ""
            dn_grid_host.pos = [content_left,grid_y + 4]
            dn_grid_host.width = content_width
            dn_grid_host.height = grid_host_height
            for ctrl in #(lbl_row_panels,ddl_columns,ddl_rows,btn_reset,lbl_enabled,grp_grid,dn_grid_host) do
                ctrl.visible = panels_setup_expanded




            -- One full-width row of nine ID buttons, without a dropdown.
            -- Historical IDs above nine remain stored in existing cells.
            local ids_y = grid_y + grid_host_height + 8
            dn_id_palette.pos = [content_left,ids_y]
            dn_id_palette.width = content_width
            dn_id_palette.height = palette_height
            local palette_button_count = dn_id_palette.Controls.Count
            if palette_button_count > 0 then
            (
                local swatch_width = (floor ((content_width - (palette_button_count * 2)) / palette_button_count)) as integer
                for swatch_index = 0 to palette_button_count - 1 do dn_id_palette.Controls.Item[swatch_index].Width = swatch_width
            )
            dn_id_palette.visible = panels_setup_expanded
            lbl_rule_hint.visible = false




            -- Native Extrude spinners belong directly to PANELS, without a child rollout.
            local extrusion_y = ids_y + palette_height + 6
            lbl_extrude_title.text = "EXTRUDE - " + (used_rule_count as string) + " Material IDs"
            lbl_extrude_title.pos = [content_left,extrusion_y]
            lbl_extrude_title.width = content_width
            ddl_extrusion_mode.pos = [content_left,extrusion_y + 22]
            ddl_extrusion_mode.width = content_width
            local label_y = extrusion_y + 52
            rule_rows_origin_y = extrusion_y + 72
            layoutMaterialSpinners()
            lbl_rule_id.pos = [content_left + 4,label_y]
            lbl_rule_id.width = 22
            lbl_rule_height.pos = [content_left + 28,label_y]
            lbl_rule_height.width = 58
            lbl_rule_inset.pos = [content_left + 96,label_y]
            lbl_rule_inset.width = 58
            lbl_rule_taper.pos = [content_left + 164,label_y]
            lbl_rule_taper.width = 58
            local pager_y = rule_rows_origin_y + rule_list_height + 2
            btn_rule_previous.pos = [content_left,pager_y]
            lbl_rule_page.pos = [content_left + 68,pager_y + 2]
            btn_rule_next.pos = [content_left + content_width - 60,pager_y]
            local pager_visible = panels_setup_expanded and page_count > 1
            btn_rule_previous.visible = pager_visible
            lbl_rule_page.visible = pager_visible
            btn_rule_next.visible = pager_visible
            for ctrl in #(lbl_extrude_title,ddl_extrusion_mode,lbl_rule_id,lbl_rule_height,lbl_rule_inset,lbl_rule_taper) do
                ctrl.visible = panels_setup_expanded
            for ctrl in #(spn_rule_height,spn_rule_inset,spn_rule_taper) do ctrl.visible = false
            section_y += panels_height + spacing




            -- PRESETS: independent collapsible section after the Extrude rows.
            local presets_height = if presets_expanded then 124 else 28
            grp_presets.pos = [section_left,section_y]
            grp_presets.width = section_width
            grp_presets.height = presets_height
            btn_presets_toggle.pos = [header_left,section_y + 2]
            btn_presets_toggle.width = header_width
            btn_presets_toggle.text = if presets_expanded then "- PRESETS" else "+ PRESETS"
            ddl_preset_names.pos = [content_left,section_y + 30]
            ddl_preset_names.width = content_width
            txt_preset_name.pos = [content_left,section_y + 60]
            txt_preset_name.width = content_width
            local preset_button_width = ((content_width - 12) / 4) as integer
            btn_preset_save.pos = [content_left,section_y + 90]
            btn_preset_load.pos = [content_left + preset_button_width + 4,section_y + 90]
            btn_preset_rename.pos = [content_left + (preset_button_width + 4) * 2,section_y + 90]
            btn_preset_delete.pos = [content_left + (preset_button_width + 4) * 3,section_y + 90]
            for ctrl in #(btn_preset_save,btn_preset_load,btn_preset_rename,btn_preset_delete) do ctrl.width = preset_button_width
            for ctrl in #(ddl_preset_names,txt_preset_name,btn_preset_save,btn_preset_load,btn_preset_rename,btn_preset_delete) do ctrl.visible = presets_expanded
            section_y += presets_height + spacing




            -- MATERIAL is a separate root section, not nested in PANELS.
            grp_material.pos = [section_left,section_y]
            grp_material.width = section_width
            grp_material.height = material_height
            btn_material_toggle.pos = [header_left,section_y + 2]
            btn_material_toggle.width = header_width
            btn_material_toggle.text = if material_expanded then "- MATERIAL" else "+ MATERIAL"
            btn_material.pos = [header_left,section_y + 30]
            btn_material.width = header_width
            lbl_hint.pos = [header_left,section_y + 58]
            lbl_hint.width = header_width
            grp_material.visible = true
            btn_material_toggle.visible = true
            btn_material.visible = material_expanded
            lbl_hint.visible = material_expanded
            section_y += material_height + spacing


            -- SEAMS: native material-boundary bevel beneath Bend.
            local seams_height = if seams_expanded then 114 else 28
            grp_seams.pos = [section_left,section_y]
            grp_seams.width = section_width
            grp_seams.height = seams_height
            btn_seams_toggle.pos = [header_left,section_y + 2]
            btn_seams_toggle.width = header_width
            btn_seams_toggle.text = if seams_expanded then "- SEAMS" else "+ SEAMS"
            chk_seams_enabled.pos = [content_left,section_y + 30]
            lbl_seams_amount.pos = [content_left,section_y + 58]
            spn_seams_amount.pos = [cap_spinner_x + native_spinner_offset_x,section_y + 56]
            lbl_seams_offset.pos = [content_left,section_y + 86]
            spn_seams_offset.pos = [cap_spinner_x + native_spinner_offset_x,section_y + 84]
            for ctrl in #(chk_seams_enabled,lbl_seams_amount,spn_seams_amount,lbl_seams_offset,spn_seams_offset) do ctrl.visible = seams_expanded
            section_y += seams_height + spacing


            -- CHAMFER: finishing bevel at the top of the module stack.
            local chamfer_height = if chamfer_expanded then 114 else 28
            grp_chamfer.pos = [section_left,section_y]
            grp_chamfer.width = section_width
            grp_chamfer.height = chamfer_height
            btn_chamfer_toggle.pos = [header_left,section_y + 2]
            btn_chamfer_toggle.width = header_width
            btn_chamfer_toggle.text = if chamfer_expanded then "- CHAMFER" else "+ CHAMFER"
            chk_chamfer_enabled.pos = [content_left,section_y + 30]
            lbl_chamfer_amount.pos = [content_left,section_y + 58]
            spn_chamfer_amount.pos = [cap_spinner_x + native_spinner_offset_x,section_y + 56]
            lbl_chamfer_segments.pos = [content_left,section_y + 86]
            spn_chamfer_segments.pos = [cap_spinner_x + native_spinner_offset_x,section_y + 84]
            for ctrl in #(chk_chamfer_enabled,lbl_chamfer_amount,spn_chamfer_amount,lbl_chamfer_segments,spn_chamfer_segments) do ctrl.visible = chamfer_expanded
            section_y += chamfer_height + spacing




            -- HATCH is another root section with right-aligned compact spinners.
            grp_cap.pos = [section_left,section_y]
            grp_cap.width = section_width
            grp_cap.height = cap_height
            btn_cap_toggle.pos = [header_left,section_y + 2]
            btn_cap_toggle.width = header_width
            btn_cap_toggle.text = if cap_expanded then "- HATCH" else "+ HATCH"
            local cap_row_labels = #(lbl_cap_end,lbl_cap_thickness,lbl_cap_depth,lbl_cap_seams,lbl_cap_first,lbl_cap_spacing,lbl_cap_chamfer,lbl_cap_inset,lbl_cap_seam_depth,lbl_cap_seam_segments,lbl_cap_top_segments,lbl_cap_material)
            local cap_row_controls = #(spn_cap_end,spn_cap_thickness,spn_cap_depth,ddl_cap_seams,spn_cap_first,spn_cap_spacing,spn_cap_chamfer,spn_cap_inset,spn_cap_seam_depth,spn_cap_seam_segments,spn_cap_top_segments,spn_cap_material)
            for row_index = 1 to cap_row_labels.count do
            (
                local paragraph_gap = 4 * ((if row_index > 3 then 1 else 0) + (if row_index > 6 then 1 else 0) + (if row_index > 9 then 1 else 0) + (if row_index > 11 then 1 else 0))
                local row_y = section_y + 30 + ((row_index - 1) * 28) + paragraph_gap
                cap_row_labels[row_index].pos = [header_left,row_y + 2]
                cap_row_labels[row_index].width = cap_spinner_x - header_left - 6
                -- The fourth row is a ComboBox, not a native spinner.
                local row_control_x = if row_index == 4 then cap_spinner_x else (cap_spinner_x + native_spinner_offset_x)
                cap_row_controls[row_index].pos = [row_control_x,row_y]
                cap_row_labels[row_index].visible = cap_expanded
                cap_row_controls[row_index].visible = cap_expanded
            )
            ddl_cap_seams.width = 76
            chk_cap_enter.pos = [header_left,section_y + 386]
            chk_cap_exit.pos = [header_left + 132,section_y + 386]
            chk_cap_enter.visible = cap_expanded
            chk_cap_exit.visible = cap_expanded
            btn_cap_generate.pos = [header_left,section_y + 418]
            btn_cap_generate.width = header_width
            btn_cap_generate.height = 32
            btn_cap_generate.visible = cap_expanded
            layoutGridButtons()
            true
            -- return
        )




        /*
        Fits the panel grid to the current dialog size. A registered CUI dialog
        bar must never be resized with setDialogSize; the user can resize its
        floating window vertically and the grid reflows inside it instead.
        */
        function fitGridHeightToGeometry =
        (
            if surfacePanelGeneratorRollout.inDialog then
            (
                local dialog_size = getDialogSize surfacePanelGeneratorRollout
                resizeLayout dialog_size.y dialog_size.x
            )
            true
            -- return
        )




        /*
        Uses the shared title-button style but keeps this tool's explicitly
        requested +2 px height, including after dialog width changes.
        */
        function resizeSpgTitleButton available_width =
        (
            ToolTitleButton.resizeToolTitleButton btn_tool_title available_width
            btn_tool_title.height = 20
            local font_style = dotNetClass "System.Drawing.FontStyle"
            local graphics_unit = dotNetClass "System.Drawing.GraphicsUnit"
            btn_tool_title.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 16.0 font_style.Bold graphics_unit.Pixel
            true
            -- return
        )




        on surfacePanelGeneratorRollout open do
        (
            logSpgStartup "rollout-open-enter"
            try
            (
            preset_manager = TPGPresetManager_v ini_path:ini_path main_section:ini_section
            logSpgStartup "preset-manager-created"
            ToolTitleButton.setupToolTitleButton btn_tool_title "Tank Panel Generator"
            resizeSpgTitleButton 264
            logSpgStartup "title-button-ready"
            ui_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
            ui_tooltip.ShowAlways = true
            ui_tooltip.AutoPopDelay = 12000
            ui_tooltip.InitialDelay = 450
            ui_tooltip.ReshowDelay = 150
            ui_tooltip.SetToolTip btn_tool_title "Restart this tool while preserving its saved UI settings and dialog position."
            ui_tooltip.SetToolTip ddl_size "Display Radius and Length in the selected physical unit without changing geometry."
            ui_tooltip.SetToolTip ddl_repeat_x "Repeat the source panel pattern around the same-radius cylinder. The source pattern becomes narrower; the cylinder radius stays fixed."
            ui_tooltip.SetToolTip ddl_repeat_y "Repeat the source panel pattern along the cylinder length."
            ui_tooltip.SetToolTip ddl_columns "Grid columns: number of source panel cells around the cylinder circumference. Changes the source grid dimensions."
            ui_tooltip.SetToolTip ddl_rows "Grid rows: number of source panel cells along the cylinder axis. Changes the source grid dimensions."
            ui_tooltip.SetToolTip btn_generate "Create the module, or update the previously bound module without creating duplicates."
            ui_tooltip.SetToolTip ddl_arc_segments "Subdivision count around each logical panel (Radius)."
            ui_tooltip.SetToolTip ddl_length_segments "Length subdivisions per panel. Auto matches the flat base polygon height to its width; recalculates from dimensions, grid and Around subdivisions."
            ui_tooltip.SetToolTip ddl_cap_seams "How many radial seams to create in the cap profile."
            ui_tooltip.SetToolTip btn_cap_generate "Generate or update an editable spline profile with native Lathe. Works without a module; a bound module gets a linked cap."
            ui_tooltip.SetToolTip btn_material "LMB: assign muted Multi/Sub-Object materials. RMB: assign grey material."
            ui_tooltip.SetToolTip dn_grid_host "LMB paints current ID; RMB disables. Ctrl+click toggles cell selection without changing material ID or enabled state."
            ui_tooltip.SetToolTip dn_id_palette "Nine wide Material ID buttons. Click an ID to assign it to all Ctrl-selected grid cells, or to choose the single-cell paint ID."
            ui_tooltip.SetToolTip txt_preset_name "Enter a name for Save, or a new name for Rename. Load and Delete act on the selected preset."
            ui_tooltip.SetToolTip ddl_preset_names "Select a saved full module configuration, including grid, dimensions, material IDs and extrusion rules."
            dn_id_palette.AutoScroll = false
            dn_id_palette.WrapContents = false
            dn_id_palette.FlowDirection = (dotNetClass "System.Windows.Forms.FlowDirection").LeftToRight
            dn_id_palette.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 45 45 48
            -- Each used material ID owns an independent live extrusion row.
            palette_depth_menu = undefined
            dn_grid_host.AutoScroll = false
            dn_grid_host.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 45 45 48
            local color_class = dotNetClass "System.Drawing.Color"
            local flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"
            btn_material.Text = "Material    LMB: Multi-ID    RMB: Grey"
            btn_material.UseVisualStyleBackColor = false
            btn_material.FlatStyle = flat_style_class.Flat
            btn_material.BackColor = color_class.FromArgb 68 68 68
            btn_material.ForeColor = color_class.FromArgb 190 190 190
            btn_material.FlatAppearance.BorderColor = color_class.FromArgb 120 120 120
            btn_material.FlatAppearance.MouseOverBackColor = color_class.FromArgb 78 78 78
            btn_material.FlatAppearance.MouseDownBackColor = color_class.FromArgb 55 55 55
            -- Green-text, tall .NET Generate button for the primary action.
            btn_generate.Text = "Generate / Update module"
            btn_generate.UseVisualStyleBackColor = false
            btn_generate.FlatStyle = flat_style_class.Flat
            btn_generate.BackColor = color_class.FromArgb 45 55 47
            btn_generate.ForeColor = color_class.FromArgb 115 226 135
            btn_generate.FlatAppearance.BorderColor = color_class.FromArgb 80 145 92
            btn_generate.FlatAppearance.MouseOverBackColor = color_class.FromArgb 53 72 56
            btn_generate.FlatAppearance.MouseDownBackColor = color_class.FromArgb 38 65 42
            btn_generate.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
            btn_generate.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 14.0 (dotNetClass "System.Drawing.FontStyle").Bold (dotNetClass "System.Drawing.GraphicsUnit").Pixel
            -- Explicit .NET action: create an editable spline profile with native Lathe.
            btn_cap_generate.Text = "Generate Hatch"
            btn_cap_generate.UseVisualStyleBackColor = false
            btn_cap_generate.FlatStyle = flat_style_class.Flat
            btn_cap_generate.BackColor = color_class.FromArgb 45 55 47
            btn_cap_generate.ForeColor = color_class.FromArgb 115 226 135
            btn_cap_generate.FlatAppearance.BorderColor = color_class.FromArgb 80 145 92
            btn_cap_generate.FlatAppearance.MouseOverBackColor = color_class.FromArgb 53 72 56
            btn_cap_generate.FlatAppearance.MouseDownBackColor = color_class.FromArgb 38 65 42
            btn_cap_generate.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
            btn_cap_generate.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 12.0 (dotNetClass "System.Drawing.FontStyle").Bold (dotNetClass "System.Drawing.GraphicsUnit").Pixel
            -- Use read-only ComboBoxes so popup height follows each item count.
            -- Preserve existing INI keys and the previous numeric values.
            ui_loading = true
            for dropdown_control in #(ddl_rows, ddl_columns, ddl_repeat_x, ddl_repeat_y, ddl_arc_segments, ddl_length_segments, ddl_cap_seams, ddl_size, ddl_preset_names) do
            (
                setupSpgDropdown dropdown_control
            )
            fillIntegerDropdown ddl_rows 1 32
            fillIntegerDropdown ddl_columns 1 32
            fillIntegerDropdown ddl_repeat_x 1 16
            fillIntegerDropdown ddl_repeat_y 1 16
            fillIntegerDropdown ddl_arc_segments 1 64
            fillIntegerDropdown ddl_length_segments 1 32
            ddl_length_segments.Items.Insert 0 "Auto"
            fitDropdownPopup ddl_length_segments
            fillIntegerDropdown ddl_cap_seams 0 16
            for unit_label in #("SIZE mm", "SIZE cm", "SIZE m") do ddl_size.Items.Add unit_label
            fitDropdownPopup ddl_size
            loadUiState()
            logSpgStartup "ui-state-loaded"
            refreshPresetNames()
            logSpgStartup "presets-refreshed"
            resizeLayout surfacePanelGeneratorRollout.height surfacePanelGeneratorRollout.width
            logSpgStartup "layout-resized"
            dn_id_palette.SendToBack()
            rebuildGrid()
            logSpgStartup "open-grid-built"
            ui_loading = false
            updateBoundLabel()
            logSpgStartup "rollout-open-complete"
            )
            catch
            (
                local startup_exception = getCurrentException()
                logSpgStartup "ERROR-rollout-open" detail:startup_exception
                format "TPG STARTUP ERROR | stage:rollout-open | %\n" startup_exception
                throw()
            )
        )




        on surfacePanelGeneratorRollout resized dialog_size do
        (
            resizeSpgTitleButton (dialog_size.x - 24)
            resizeLayout dialog_size.y dialog_size.x
            DialogHost.saveDialogHeight surfacePanelGeneratorRollout ini_path ini_section min_height:840
        )




        on surfacePanelGeneratorRollout moved dialog_pos do
        (
            -- The event supplies the actual position. Store it directly so
            -- moving a registered dialog bar survives close and reload.
            if dialog_pos != undefined and not position_restore_active then
            (
                IniSettings.setPoint2 ini_path ini_section "PosX" "PosY" dialog_pos
            )
        )




        on tmr_position_restore tick do
        (
            tmr_position_restore.active = false
            local restored_pos = try (getDialogPos surfacePanelGeneratorRollout) catch (undefined)
            if restored_pos != undefined and position_restore_target != undefined then
            (
                local remaining_offset = restored_pos - position_restore_target
                format "TPG POSITION | saved:% restored:% remaining offset:%\n" position_restore_target restored_pos remaining_offset
                if (abs remaining_offset.x) <= 1 and (abs remaining_offset.y) <= 1 then
                    format "TPG POSITION | PASS (within 1 pixel)\n"
                else
                    format "TPG POSITION | OFFSET REMAINS (see saved/restored values)\n"
            )
        )




        on surfacePanelGeneratorRollout close do
        (
            saveUiState()
            DialogHost.saveDialogState surfacePanelGeneratorRollout ini_path ini_section min_height:840
        )




        on btn_tool_title Click sender event_args do
        (
            -- Save the floating dialog state before the reload destroys it.
            DialogHost.saveDialogState surfacePanelGeneratorRollout ini_path ini_section min_height:840
            restartTool source_file tool_prefix
        )




        on ddl_rows SelectedIndexChanged sender event_args do
        (
            if not ui_loading and ddl_rows.SelectedIndex >= 0 then applyGridDimensions (getIntegerDropdown ddl_rows) SurfacePanelGenerator.columns
        )




        on ddl_columns SelectedIndexChanged sender event_args do
        (
            if not ui_loading and ddl_columns.SelectedIndex >= 0 then applyGridDimensions SurfacePanelGenerator.rows (getIntegerDropdown ddl_columns)
        )




        on ddl_size SelectedIndexChanged sender event_args do
        (
            if not ui_loading and ddl_size.SelectedIndex >= 0 then changeDimensionUnit ddl_size.SelectedIndex
        )




        on ddl_repeat_x SelectedIndexChanged sender event_args do (if not ui_loading and ddl_repeat_x.SelectedIndex >= 0 then (fitGridHeightToGeometry(); settingsChanged()))
        on ddl_repeat_y SelectedIndexChanged sender event_args do (if not ui_loading and ddl_repeat_y.SelectedIndex >= 0 then settingsChanged())
        on spn_radius changed dimension_value do
        (
            if not ui_loading then
            (
                fitGridHeightToGeometry()
                settingsChanged()
            )
        )
        on spn_base_thickness changed thickness_value do (if not ui_loading then settingsChanged())
        on spn_length changed dimension_value do
        (
            if not ui_loading then
            (
                fitGridHeightToGeometry()
                settingsChanged()
            )
        )
        on ddl_arc_segments SelectedIndexChanged sender event_args do (if not ui_loading and ddl_arc_segments.SelectedIndex >= 0 then settingsChanged())
        on ddl_length_segments SelectedIndexChanged sender event_args do (if not ui_loading and ddl_length_segments.SelectedIndex >= 0 then settingsChanged())
        on ddl_extrusion_mode selected mode_index do
        (
            if not ui_loading then
            (
                SurfacePanelGenerator.extrusion_mode = if mode_index == 2 then #local else #group
                extrusionSettingsChanged()
            )
        )


        on spn_rule_height changed new_value do activeRuleGeometryChanged #height new_value
        on spn_rule_inset changed new_value do activeRuleGeometryChanged #inset new_value
        on spn_rule_taper changed new_value do activeRuleGeometryChanged #taper new_value
        on spn_extrude_inset_01 changed new_value do materialRowSlotChanged 1 #inset new_value
        on spn_extrude_height_01 changed new_value do materialRowSlotChanged 1 #height new_value
        on spn_extrude_taper_01 changed new_value do materialRowSlotChanged 1 #taper new_value
        on spn_extrude_inset_02 changed new_value do materialRowSlotChanged 2 #inset new_value
        on spn_extrude_height_02 changed new_value do materialRowSlotChanged 2 #height new_value
        on spn_extrude_taper_02 changed new_value do materialRowSlotChanged 2 #taper new_value
        on spn_extrude_inset_03 changed new_value do materialRowSlotChanged 3 #inset new_value
        on spn_extrude_height_03 changed new_value do materialRowSlotChanged 3 #height new_value
        on spn_extrude_taper_03 changed new_value do materialRowSlotChanged 3 #taper new_value
        on spn_extrude_inset_04 changed new_value do materialRowSlotChanged 4 #inset new_value
        on spn_extrude_height_04 changed new_value do materialRowSlotChanged 4 #height new_value
        on spn_extrude_taper_04 changed new_value do materialRowSlotChanged 4 #taper new_value
        on spn_extrude_inset_05 changed new_value do materialRowSlotChanged 5 #inset new_value
        on spn_extrude_height_05 changed new_value do materialRowSlotChanged 5 #height new_value
        on spn_extrude_taper_05 changed new_value do materialRowSlotChanged 5 #taper new_value
        on spn_extrude_inset_06 changed new_value do materialRowSlotChanged 6 #inset new_value
        on spn_extrude_height_06 changed new_value do materialRowSlotChanged 6 #height new_value
        on spn_extrude_taper_06 changed new_value do materialRowSlotChanged 6 #taper new_value
        on spn_extrude_inset_07 changed new_value do materialRowSlotChanged 7 #inset new_value
        on spn_extrude_height_07 changed new_value do materialRowSlotChanged 7 #height new_value
        on spn_extrude_taper_07 changed new_value do materialRowSlotChanged 7 #taper new_value
        on spn_extrude_inset_08 changed new_value do materialRowSlotChanged 8 #inset new_value
        on spn_extrude_height_08 changed new_value do materialRowSlotChanged 8 #height new_value
        on spn_extrude_taper_08 changed new_value do materialRowSlotChanged 8 #taper new_value
        on spn_extrude_inset_09 changed new_value do materialRowSlotChanged 9 #inset new_value
        on spn_extrude_height_09 changed new_value do materialRowSlotChanged 9 #height new_value
        on spn_extrude_taper_09 changed new_value do materialRowSlotChanged 9 #taper new_value
        on spn_extrude_inset_10 changed new_value do materialRowSlotChanged 10 #inset new_value
        on spn_extrude_height_10 changed new_value do materialRowSlotChanged 10 #height new_value
        on spn_extrude_taper_10 changed new_value do materialRowSlotChanged 10 #taper new_value
        on spn_extrude_inset_11 changed new_value do materialRowSlotChanged 11 #inset new_value
        on spn_extrude_height_11 changed new_value do materialRowSlotChanged 11 #height new_value
        on spn_extrude_taper_11 changed new_value do materialRowSlotChanged 11 #taper new_value
        on spn_extrude_inset_12 changed new_value do materialRowSlotChanged 12 #inset new_value
        on spn_extrude_height_12 changed new_value do materialRowSlotChanged 12 #height new_value
        on spn_extrude_taper_12 changed new_value do materialRowSlotChanged 12 #taper new_value
        on btn_rule_previous pressed do showMaterialRulePage (rule_page_index - 1)
        on btn_rule_next pressed do showMaterialRulePage (rule_page_index + 1)




        on btn_reset pressed do resetGridMaterialIds()




        on btn_material MouseUp sender event_args do
        (
            local mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"
            if event_args.Button == mouse_buttons.Left or event_args.Button == mouse_buttons.Right then
            (
                if isValidNode SurfacePanelGenerator.last_node then
                (
                    local chosen_mode = if event_args.Button == mouse_buttons.Left then #multi else #gray
                    local material_applied = false
                    undo "Tank Panel Generator - Material" on
                    (
                        material_applied = SurfacePanelGenerator.applyMaterial SurfacePanelGenerator.last_node SurfacePanelGenerator.rows SurfacePanelGenerator.columns chosen_mode rule_count:SurfacePanelGenerator.rule_depths.count
                    )
                    if material_applied then saveUiState()
                )
                else
                (
                    format "TPG | Material button: generate the object first.\n"
                )
                updateBoundLabel()
            )
        )




        /*
        Expands or collapses a named section without resizing the registered
        CUI dialog bar. Current floating dialog size and position are preserved.
        */
        function sectionVisibilityChanged =
        (
            local dialog_size = getDialogSize surfacePanelGeneratorRollout
            resizeLayout dialog_size.y dialog_size.x
            saveUiState()
            true
            -- return
        )




        on btn_setup_toggle pressed do (setup_expanded = not setup_expanded; sectionVisibilityChanged())
        on btn_cap_toggle pressed do (cap_expanded = not cap_expanded; sectionVisibilityChanged())
        on btn_panels_setup_toggle pressed do (panels_setup_expanded = not panels_setup_expanded; sectionVisibilityChanged())
        on btn_presets_toggle pressed do (presets_expanded = not presets_expanded; sectionVisibilityChanged())
        on btn_material_toggle pressed do (material_expanded = not material_expanded; sectionVisibilityChanged())
        on btn_seams_toggle pressed do (seams_expanded = not seams_expanded; sectionVisibilityChanged())
        on btn_chamfer_toggle pressed do (chamfer_expanded = not chamfer_expanded; sectionVisibilityChanged())
        on chk_seams_enabled changed new_value do (chamferSettingsChanged())
        on spn_seams_amount changed new_value do (chamferSettingsChanged())
        on spn_seams_offset changed new_value do (chamferSettingsChanged())
        on chk_chamfer_enabled changed new_value do (chamferSettingsChanged())
        on spn_chamfer_amount changed new_value do (chamferSettingsChanged())
        on spn_chamfer_segments changed new_value do (chamferSettingsChanged())


        on ddl_preset_names SelectedIndexChanged sender event_args do
        (
            if not preset_loading and not ui_loading and ddl_preset_names.SelectedIndex >= 0 then
            (
                txt_preset_name.Text = ddl_preset_names.Text
                loadNamedPreset mode:#all
            )
        )
        on btn_preset_save pressed do saveNamedPreset()
        on btn_preset_load pressed do loadNamedPreset mode:#all
        on btn_preset_load rightclick do popupMenu tpg_preset_load_menu
        on btn_preset_rename pressed do renameNamedPreset()
        on btn_preset_delete pressed do deleteNamedPreset()




        on btn_cap_generate Click sender event_args do
        (
            if not ui_loading then
            (
                refreshCapHatch force_create:true
                saveUiState()
            )
        )
        on spn_cap_end changed new_value do (if not ui_loading then capSettingsChanged())
        on spn_cap_thickness changed new_value do (if not ui_loading then capSettingsChanged())
        on spn_cap_depth changed new_value do (if not ui_loading then capSettingsChanged())
        on ddl_cap_seams SelectedIndexChanged sender event_args do (if not ui_loading and ddl_cap_seams.SelectedIndex >= 0 then capSettingsChanged())
        on spn_cap_first changed new_value do (if not ui_loading then capSettingsChanged())
        on spn_cap_spacing changed new_value do (if not ui_loading then capSettingsChanged())
        on spn_cap_chamfer changed new_value do (if not ui_loading then capSettingsChanged())
        on spn_cap_seam_depth changed new_value do (if not ui_loading then capSettingsChanged())
        on spn_cap_inset changed new_value do (if not ui_loading then capSettingsChanged())
        on spn_cap_seam_segments changed new_value do (if not ui_loading then capSettingsChanged())
        on spn_cap_top_segments changed new_value do (if not ui_loading then capSettingsChanged())
        on spn_cap_material changed new_value do (if not ui_loading then capSettingsChanged())
        on chk_cap_enter changed checked_state do (if not ui_loading then capSettingsChanged())
        on chk_cap_exit changed checked_state do (if not ui_loading then capSettingsChanged())




        on btn_load_object pressed do
        (
            if selection.count == 1 then
            (
                loadObjectData selection[1]
            )
            else
            (
                format "TPG LOAD | Select exactly one generated module, then click Load selected object.\n"
            )
        )


        on btn_generate Click sender event_args do
        (
            local precision_value = 0.01
            local target_node = if isValidNode SurfacePanelGenerator.last_node then SurfacePanelGenerator.last_node else undefined




            undo "Tank Panel Generator - Generate / Update Module" on
            (
                local result_node = SurfacePanelGenerator.generateModule SurfacePanelGenerator.rows SurfacePanelGenerator.columns SurfacePanelGenerator.mask (moduleRadius()) (moduleLength()) (units.decodeValue "1cm") (getIntegerDropdown ddl_arc_segments) precision_value x_multiplier:(getIntegerDropdown ddl_repeat_x) y_multiplier:(getIntegerDropdown ddl_repeat_y) target_node:target_node owned_bend:SurfacePanelGenerator.last_bend_mod material_mode_value:SurfacePanelGenerator.material_mode cell_ids_value:SurfacePanelGenerator.cell_ids rule_depths_value:SurfacePanelGenerator.rule_depths rule_thicknesses_value:SurfacePanelGenerator.rule_thicknesses rule_offsets_value:SurfacePanelGenerator.rule_offsets rule_insets_value:SurfacePanelGenerator.rule_insets rule_tapers_value:SurfacePanelGenerator.rule_tapers extrusion_mode_value:SurfacePanelGenerator.extrusion_mode length_segments:(getLengthSegmentsSetting()) seams_enabled_value:SurfacePanelGenerator.seams_enabled seams_amount_value:SurfacePanelGenerator.seams_amount seams_offset_value:SurfacePanelGenerator.seams_offset chamfer_enabled_value:SurfacePanelGenerator.chamfer_enabled chamfer_amount_value:SurfacePanelGenerator.chamfer_amount chamfer_segments_value:SurfacePanelGenerator.chamfer_segments base_thickness_value:(moduleBaseThickness())
                if isValidNode result_node then
                (
                    select result_node
                    refreshCapHatch()
                )
            )
            updateBoundLabel()
            saveUiState()
        )
    )


    /*
    Exposes selective preset restore commands through the native Load button menu.
    */
    rcmenu tpg_preset_load_menu
    (
        menuItem item_load_all "Load All"
        menuItem item_load_panels "Load Panels Layout"
        menuItem item_load_extrude "Load Extrude Settings"
        menuItem item_load_seams "Load Seams Settings"
        menuItem item_load_chamfer "Load Chamfer Settings"
        menuItem item_load_hatch "Load Hatch Settings"


        on item_load_all picked do surfacePanelGeneratorRollout.loadNamedPreset mode:#all
        on item_load_panels picked do surfacePanelGeneratorRollout.loadNamedPreset mode:#panels
        on item_load_extrude picked do surfacePanelGeneratorRollout.loadNamedPreset mode:#extrude
        on item_load_seams picked do surfacePanelGeneratorRollout.loadNamedPreset mode:#seams
        on item_load_chamfer picked do surfacePanelGeneratorRollout.loadNamedPreset mode:#chamfer
        on item_load_hatch picked do surfacePanelGeneratorRollout.loadNamedPreset mode:#hatch
    )




    /* Applies the known CUI float offset without changing shared DialogHost.
    DialogHost still owns registry, unregister and register operations.
    */
    function createPositionCorrectedTankDialog rollout_ref =
    (
        logSpgStartup "dialog-create-enter"
        local saved_pos = IniSettings.getPoint2 ini_path ini_section "PosX" "PosY" default_value:[100,100]
        local saved_height = IniSettings.getInteger ini_path ini_section "Height" default_value:1440
        if saved_height < 840 then saved_height = 840
        for registry_entry in ::dialog_host_registry do
        (
            if registry_entry != undefined and registry_entry.count >= 2 and registry_entry[1] == tool_key then
            (
                local live_pos = try (getDialogPos registry_entry[2]) catch (undefined)
                if live_pos != undefined then saved_pos = live_pos
            )
        )
        DialogHost.destroyToolDialogs tool_key
        logSpgStartup "old-dialogs-destroyed"
        -- Preserve the screen coordinate captured before unregister/destroy.
        IniSettings.setPoint2 ini_path ini_section "PosX" "PosY" saved_pos
        position_restore_target = saved_pos
        position_restore_active = true
        DialogHost.unregisterDockableDialog rollout_ref
        try (destroyDialog rollout_ref) catch ()
        local creation_pos = rollout_ref.getCorrectedDialogPos saved_pos
        try
        (
            logSpgStartup "create-dialog-begin"
            createDialog rollout_ref width:288 height:saved_height pos:creation_pos lockWidth:true lockHeight:false autoLayoutOnResize:true
            logSpgStartup "create-dialog-returned"
            if not (DialogHost.registerDockableDialog rollout_ref) then
                throw "TPG POSITION | Could not register the corrected CUI dialog."
            logSpgStartup "dialog-registered"
            cui.FloatDialogBar rollout_ref
            DialogHost.registerToolDialog tool_key rollout_ref
            position_restore_active = false
            rollout_ref.tmr_position_restore.active = true
            logSpgStartup "dialog-create-complete"
        )
        catch
        (
            local startup_exception = getCurrentException()
            logSpgStartup "ERROR-dialog-create" detail:startup_exception
            position_restore_active = false
            DialogHost.unregisterDockableDialog rollout_ref
            try (destroyDialog rollout_ref) catch ()
            format "TPG POSITION ERROR | %\n" startup_exception
            throw()
        )
        true
        -- return
    )


    createPositionCorrectedTankDialog surfacePanelGeneratorRollout
    logSpgStartup "posted-messages-begin"
    windows.processPostedMessages()
    logSpgStartup "posted-messages-complete"
    /* Complete the initial grid after managed CUI creation and posted sizing.
    */
    surfacePanelGeneratorRollout.ui_ready = true
    surfacePanelGeneratorRollout.rebuildMaterialRows force:true
    logSpgStartup "material-rows-built"
    surfacePanelGeneratorRollout.rebuildGrid()
    logSpgStartup "post-open-grid-built"
    surfacePanelGeneratorRollout.dn_extrude_id_host.Refresh()
    local initial_id_host = surfacePanelGeneratorRollout.dn_extrude_id_host
    format "TPG UI | Material ID buttons:% host-visible:% first-visible:%\n" initial_id_host.Controls.Count initial_id_host.Visible (if initial_id_host.Controls.Count > 0 then initial_id_host.Controls.Item[0].Visible else false)
    surfacePanelGeneratorRollout.dn_grid_host.Refresh()
    logSpgStartup "script-complete"
)





