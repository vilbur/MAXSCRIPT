/*
Defines the Print-Debug UI using the canonical shared MaxScript UI helpers.
File version: 0.01
Project version: 0.01
*/
global print_debug_global_project_version
if print_debug_global_project_version == undefined then
(
    print_debug_global_project_version = 0.01
)
else if print_debug_global_project_version < 0.01 then
(
    print_debug_global_project_version = 0.01
)

(
    local ui_source_file = getSourceFileName()
    if ui_source_file == undefined or ui_source_file == "" then throw "Print-Debug UI must be loaded from a saved script file."
    local ui_tool_folder = getFilenamePath ui_source_file
    local ui_framework_dir = pathConfig.appendPath ui_tool_folder @"..\..\..\UI\Default"

    global print_debug_ui_ini_path
    global print_debug_ui_section
    global print_debug_ui_tool_key
    global print_debug_ui_script_prefix
    global print_debug_window_title

    print_debug_ui_ini_path = pathConfig.appendPath ui_tool_folder "Print-Debug.ini"
    print_debug_ui_section = "MainUI"
    print_debug_ui_tool_key = "Print-Debug"
    print_debug_ui_script_prefix = "Print-Debug"
    print_debug_window_title = "Print-Debug - v" + (print_debug_global_project_version as string)

    /*
    Loads one canonical UI helper from the shared framework directory.
    Throws a path-specific error when the helper is unavailable.
    */
    function loadUiFrameworkHelper helper_name =
    (
        local helper_path = pathConfig.appendPath ui_framework_dir helper_name
        if not doesFileExist helper_path then throw ("Print-Debug UI dependency is missing: " + helper_path)
        fileIn helper_path
        true
    ) -- return

    loadUiFrameworkHelper "IniSettings.ms"
    loadUiFrameworkHelper "RolloutState.ms"
    loadUiFrameworkHelper "DialogHost.ms"
    loadUiFrameworkHelper "ScriptReload.ms"
    loadUiFrameworkHelper "ToolTitleButton.ms"

    rollout print_debug_rollout print_debug_window_title width:336 height:504
    (
        local ui_global_names = #()

        dotNetControl btn_tool_title "System.Windows.Forms.Button" width:312 height:18 align:#center
        label lbl_version "Project version:" align:#left

        group "Object Geometry"
        (
            checkbox chk_verts "Vertex IDs" checked:true across:3
            checkbox chk_positions "Positions" checked:true
            checkbox chk_vertex_normals "Vertex normals" checked:false
            checkbox chk_tri_faces "Triangle faces" checked:true
            checkbox chk_face_normals "Face normals" checked:false
            checkbox chk_polygons "Polygons" checked:true
            checkbox chk_material_ids "Material IDs" checked:true
            button btn_print_object "Print Selected Object" width:288 height:24
        )

        group "Current Modifier"
        (
            button btn_print_modifier "Print Selected Modifier" width:288 height:24
        )

        group "Dialog / Rollout"
        (
            dropdownlist ddl_ui_target "Open rollout or floater:" items:#() width:288
            button btn_refresh_targets "Refresh Targets" across:2 width:144 height:24
            button btn_print_ui_target "Print UI Properties" width:144 height:24
        )

        /*
        Restores persisted UI controls and refreshes selectable rollout targets.
        The target list remains empty when no global rollout or floater is open.
        */
        function loadUiState =
        (
            RolloutState.loadCheckbox chk_verts print_debug_ui_ini_path print_debug_ui_section "VertexIDs" default_value:true
            RolloutState.loadCheckbox chk_positions print_debug_ui_ini_path print_debug_ui_section "Positions" default_value:true
            RolloutState.loadCheckbox chk_vertex_normals print_debug_ui_ini_path print_debug_ui_section "VertexNormals" default_value:false
            RolloutState.loadCheckbox chk_tri_faces print_debug_ui_ini_path print_debug_ui_section "TriangleFaces" default_value:true
            RolloutState.loadCheckbox chk_face_normals print_debug_ui_ini_path print_debug_ui_section "FaceNormals" default_value:false
            RolloutState.loadCheckbox chk_polygons print_debug_ui_ini_path print_debug_ui_section "Polygons" default_value:true
            RolloutState.loadCheckbox chk_material_ids print_debug_ui_ini_path print_debug_ui_section "MaterialIDs" default_value:true
            refreshTargets()
        ) -- return

        /*
Saves geometry options and the selected rollout/floater name to the INI file.
The selected name is stable when the global-variable list order changes.
        */
        function saveUiState =
        (
            RolloutState.saveCheckbox chk_verts print_debug_ui_ini_path print_debug_ui_section "VertexIDs"
            RolloutState.saveCheckbox chk_positions print_debug_ui_ini_path print_debug_ui_section "Positions"
            RolloutState.saveCheckbox chk_vertex_normals print_debug_ui_ini_path print_debug_ui_section "VertexNormals"
            RolloutState.saveCheckbox chk_tri_faces print_debug_ui_ini_path print_debug_ui_section "TriangleFaces"
            RolloutState.saveCheckbox chk_face_normals print_debug_ui_ini_path print_debug_ui_section "FaceNormals"
            RolloutState.saveCheckbox chk_polygons print_debug_ui_ini_path print_debug_ui_section "Polygons"
            RolloutState.saveCheckbox chk_material_ids print_debug_ui_ini_path print_debug_ui_section "MaterialIDs"
            if ddl_ui_target.selection > 0 and ddl_ui_target.selection <= ui_global_names.count then
            (
                IniSettings.setString print_debug_ui_ini_path print_debug_ui_section "SelectedTarget" (ui_global_names[ddl_ui_target.selection] as string)
            )
        ) -- return

        /*
Refreshes the selectable global rollout and floater names.
Restores the last selected target when it remains available.
        */
        function refreshTargets =
        (
            local selected_target_name = IniSettings.getString print_debug_ui_ini_path print_debug_ui_section "SelectedTarget" default_value:""
            local display_names = #()
            local selected_index = 0
            ui_global_names = PrintDebugFN.getInspectableGlobals()

            for global_name in ui_global_names do
            (
                append display_names (global_name as string)
                if (global_name as string) == selected_target_name then selected_index = display_names.count
            )

            ddl_ui_target.items = display_names
            if selected_index > 0 then ddl_ui_target.selection = selected_index
            else if display_names.count > 0 then ddl_ui_target.selection = 1
            else ddl_ui_target.selection = 0

            display_names.count
        ) -- return

        on print_debug_rollout open do
        (
            ToolTitleButton.setupToolTitleButton btn_tool_title "Print-Debug"
            ToolTitleButton.resizeToolTitleButton btn_tool_title (print_debug_rollout.width - 24)
            btn_print_object.tooltip = "Print checked evaluated mesh sections to the Listener."
            btn_print_modifier.tooltip = "Print the current Modify panel modifier properties."
            ddl_ui_target.tooltip = "Choose an open, globally accessible rollout or floater."
            btn_refresh_targets.tooltip = "Refresh the available rollout and floater list."
            btn_print_ui_target.tooltip = "Print the selected rollout, floater, control, and window properties."
        lbl_version.text = "Project version: " + (print_debug_global_project_version as string)
            loadUiState()
        ),

        on print_debug_rollout moved dialog_pos do
        (
            DialogHost.saveDialogPosition print_debug_rollout print_debug_ui_ini_path print_debug_ui_section
        ),

        on print_debug_rollout resized dialog_size do
        (
            ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
            DialogHost.saveDialogHeight print_debug_rollout print_debug_ui_ini_path print_debug_ui_section min_height:420
        ),

        on print_debug_rollout close do
        (
            saveUiState()
            DialogHost.saveDialogState print_debug_rollout print_debug_ui_ini_path print_debug_ui_section min_height:420
        ),

        on btn_tool_title Click sender event_args do
        (
            local source_file = getSourceFileName()
            if source_file != undefined and source_file != "" then restartTool source_file print_debug_ui_script_prefix
        ),

        on chk_verts changed state do RolloutState.saveCheckbox chk_verts print_debug_ui_ini_path print_debug_ui_section "VertexIDs"
        on chk_positions changed state do RolloutState.saveCheckbox chk_positions print_debug_ui_ini_path print_debug_ui_section "Positions"
        on chk_vertex_normals changed state do RolloutState.saveCheckbox chk_vertex_normals print_debug_ui_ini_path print_debug_ui_section "VertexNormals"
        on chk_tri_faces changed state do RolloutState.saveCheckbox chk_tri_faces print_debug_ui_ini_path print_debug_ui_section "TriangleFaces"
        on chk_face_normals changed state do RolloutState.saveCheckbox chk_face_normals print_debug_ui_ini_path print_debug_ui_section "FaceNormals"
        on chk_polygons changed state do RolloutState.saveCheckbox chk_polygons print_debug_ui_ini_path print_debug_ui_section "Polygons"
        on chk_material_ids changed state do RolloutState.saveCheckbox chk_material_ids print_debug_ui_ini_path print_debug_ui_section "MaterialIDs"

        on btn_print_object pressed do
        (
            if selection.count == 0 then
            (
                format "PRINT-DEBUG | select an object before printing geometry.\n"
            )
            else
            (
                PrintDebugFN.printObject selection[1] chk_verts.checked chk_positions.checked chk_vertex_normals.checked chk_tri_faces.checked chk_face_normals.checked chk_polygons.checked chk_material_ids.checked
            )
        ),

        on btn_print_modifier pressed do
        (
            PrintDebugFN.printCurrentModifier()
        ),

        on btn_refresh_targets pressed do
        (
            refreshTargets()
        ),

        on ddl_ui_target selected index do
        (
            if index > 0 and index <= ui_global_names.count then
            (
                IniSettings.setString print_debug_ui_ini_path print_debug_ui_section "SelectedTarget" (ui_global_names[index] as string)
            )
        ),

        on btn_print_ui_target pressed do
        (
            if ddl_ui_target.selection > 0 and ddl_ui_target.selection <= ui_global_names.count then
            (
                PrintDebugFN.printRolloutOrFloater ui_global_names[ddl_ui_target.selection]
            )
            else
            (
                format "PRINT-DEBUG | no open rollout or floater is selected.\n"
            )
        )
    )
)

struct PrintDebugUI_v
(
    file_version = 0.01,
    project_version = 0.01,

    /*
    Opens the registered Print-Debug dialog with persisted location and height.
    Applies the user's measured registered-dialog correction before creation.
    */
    function show =
    (
        local saved_position = IniSettings.getPoint2 print_debug_ui_ini_path print_debug_ui_section "PosX" "PosY" default_value:[100,100]
        local corrected_position = saved_position - [6,29]
        IniSettings.setPoint2 print_debug_ui_ini_path print_debug_ui_section "PosX" "PosY" corrected_position
        DialogHost.createManagedDialog print_debug_rollout print_debug_ui_ini_path print_debug_ui_section tool_key:print_debug_ui_tool_key default_width:336 default_height:504 min_height:420
        cui.FloatDialogBar print_debug_rollout
        windows.processPostedMessages()
        true
    ),

    on create do ()
)

global PrintDebugUI
PrintDebugUI = PrintDebugUI_v()
