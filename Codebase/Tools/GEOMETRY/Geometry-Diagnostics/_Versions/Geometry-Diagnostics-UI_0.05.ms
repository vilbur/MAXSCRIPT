/*
Geometry Diagnostics frontend.
Defines the standalone test UI and delegates all processing to the backend.
*/

global geometry_diagnostics_ui_version = "0.05"
global geometry_diagnostics_ui_project_version = "0.11"
global geometry_diagnostics_project_version
global geometry_diagnostics_source_file
global geometry_diagnostics_directory
global geometry_diagnostics_ini_path
global geometry_diagnostics_ui_source_file = getSourceFileName()

if geometry_diagnostics_project_version == undefined then
(
    geometry_diagnostics_project_version = geometry_diagnostics_ui_project_version
)
else if (geometry_diagnostics_project_version as float) < (geometry_diagnostics_ui_project_version as float) then
(
    geometry_diagnostics_project_version = geometry_diagnostics_ui_project_version
)

if geometry_diagnostics_directory == undefined or geometry_diagnostics_directory == "" then
(
    if geometry_diagnostics_ui_source_file != undefined and geometry_diagnostics_ui_source_file != "" then
    (
        geometry_diagnostics_directory = getFilenamePath geometry_diagnostics_ui_source_file
    )
)

if geometry_diagnostics_ini_path == undefined or geometry_diagnostics_ini_path == "" then
(
    if geometry_diagnostics_directory != undefined and geometry_diagnostics_directory != "" then
    (
        geometry_diagnostics_ini_path = geometry_diagnostics_directory + "Geometry-Diagnostics.ini"
    )
)

global geometryDiagnosticsRollout
global IniSettings


rollout geometryDiagnosticsRollout ("Geometry Diagnostics - v" + geometry_diagnostics_project_version) width:336 height:336
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" width:312 height:24 align:#center

    button btn_create_test_box "CREATE TEST BOX" width:288 height:24 tooltip:"LMB: Create an Editable Poly box with split channel-0 face-corner colors and the canonical Tessellate modifier."

    button btn_paint_face_colors "PAINT FACE COLORS" width:288 height:24 tooltip:"LMB: Paint faces on the currently selected Editable Poly or supported modifier stack level with the diagnostic color palette."

    button btn_restore_colors "RESTORE COLORS" width:288 height:24 tooltip:"LMB: Restore the exact channel-0 colors and display state captured before painting."

    button btn_dump_channel "DUMP CHANNEL 0" width:288 height:24 tooltip:"LMB: Print Editable Poly geometry and channel-0 map topology to the Listener."

    label lbl_status "Ready." width:288 height:36 align:#left

    group "DEBUG"
    (
        dropdownList ddl_position_precision "postion preccision" items:#("1mm", "0.1mm", "0.01mm") selection:3 width:288
        button btn_check_ortho_edges "CHECK ORTHO EDGES" width:288 height:24 tooltip:"LMB: Classify visible edges as horizontal / vertical and paint suspicious edges red through face-corner vertex data."
    )

    /*
    Writes one concise status message to the UI.
    This function does not perform geometry processing.
    */
    function setGeometryDiagnosticsStatus status_text =
    (
        lbl_status.text = status_text
        true
        -- return
    )


    on geometryDiagnosticsRollout open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Geometry Diagnostics"
        ToolTitleButton.resizeToolTitleButton btn_tool_title (geometryDiagnosticsRollout.width - 24)

        local saved_precision = IniSettings.getString geometry_diagnostics_ini_path "Debug" "PositionPrecision" default_value:"0.01mm"
        local precision_index = findItem #("1mm", "0.1mm", "0.01mm") saved_precision

        if precision_index == 0 then
        (
            precision_index = 3
        )

        ddl_position_precision.selection = precision_index
        setGeometryDiagnosticsStatus "Ready."
    )


    on geometryDiagnosticsRollout moved dialog_pos do
    (
        DialogHost.saveDialogPosition geometryDiagnosticsRollout geometry_diagnostics_ini_path "MainUI"
    )


    on geometryDiagnosticsRollout resized dialog_size do
    (
        ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)

        DialogHost.saveDialogHeight geometryDiagnosticsRollout geometry_diagnostics_ini_path "MainUI" min_height:336
    )


    on geometryDiagnosticsRollout close do
    (
        DialogHost.saveDialogState geometryDiagnosticsRollout geometry_diagnostics_ini_path "MainUI" min_height:336
    )


    on geometryDiagnosticsRollout help do
    (
        if geometry_diagnostics_source_file != undefined and geometry_diagnostics_source_file != "" then
        (
            restartTool geometry_diagnostics_source_file "Geometry-Diagnostics"
        )
    )


    on btn_tool_title Click sender event_args do
    (
        if geometry_diagnostics_source_file != undefined and geometry_diagnostics_source_file != "" then
        (
            restartTool geometry_diagnostics_source_file "Geometry-Diagnostics"
        )
    )


    on btn_create_test_box pressed do
    (
        local created_node = createGeometryDiagnosticsTestBox()

        if created_node != undefined then
        (
            setGeometryDiagnosticsStatus ("Created with Tessellate: " + created_node.name)
        )
        else
        (
            setGeometryDiagnosticsStatus "Create test box failed. See Listener."
        )
    )


    on btn_paint_face_colors pressed do
    (
        local source_node = getGeometryDiagnosticsTargetNode()

        if source_node == undefined then
        (
            setGeometryDiagnosticsStatus "Create or select one Editable Poly first."
        )
        else if paintGeometryDiagnosticsTestBox source_node then
        (
            setGeometryDiagnosticsStatus "Six face colors painted."
        )
        else
        (
            setGeometryDiagnosticsStatus "Paint failed. See Listener."
        )
    )


    on btn_restore_colors pressed do
    (
        local source_node = getGeometryDiagnosticsTargetNode()

        if source_node == undefined then
        (
            setGeometryDiagnosticsStatus "No Editable Poly target available."
        )
        else if restoreGeometryDiagnosticsColors source_node then
        (
            setGeometryDiagnosticsStatus "Original channel-0 state restored."
        )
        else
        (
            setGeometryDiagnosticsStatus "Restore refused or no session exists."
        )
    )


    on btn_dump_channel pressed do
    (
        local source_node = getGeometryDiagnosticsTargetNode()

        if source_node == undefined then
        (
            setGeometryDiagnosticsStatus "No Editable Poly target available."
        )
        else if dumpGeometryDiagnosticsChannelZero source_node then
        (
            setGeometryDiagnosticsStatus "Channel 0 dumped to Listener."
        )
        else
        (
            setGeometryDiagnosticsStatus "Dump failed. See Listener."
        )
    )


    on ddl_position_precision selected precision_index do
    (
        if precision_index >= 1 and precision_index <= ddl_position_precision.items.count then
        (
            IniSettings.setString geometry_diagnostics_ini_path "Debug" "PositionPrecision" ddl_position_precision.selected
        )
    )


    on btn_check_ortho_edges pressed do
    (
        local source_node = getGeometryDiagnosticsTargetNode()

        if source_node == undefined then
        (
            setGeometryDiagnosticsStatus "No Editable Poly target available."
        )
        else
        (
            local ortho_result = checkGeometryDiagnosticsOrthoEdges source_node ddl_position_precision.selected

            if ortho_result == undefined then
            (
                setGeometryDiagnosticsStatus "Ortho edge check failed. See Listener."
            )
            else
            (
                setGeometryDiagnosticsStatus \
                    ("Ortho H:" + (ortho_result.horizontal_edges.numberSet as string) + \
                    " V:" + (ortho_result.vertical_edges.numberSet as string) + \
                    " suspicious:" + (ortho_result.suspicious_edges.numberSet as string))
            )
        )
    )
)


/*
Opens the managed standalone Geometry Diagnostics dialog.
The shared dialog helper owns position and vertical-height persistence.
*/
function openGeometryDiagnostics =
(
    if ::DialogHost == undefined then
    (
        format "Geometry Diagnostics: DialogHost is not loaded.\n"
        return false
    )

    if ::ToolTitleButton == undefined then
    (
        format "Geometry Diagnostics: ToolTitleButton is not loaded.\n"
        return false
    )

    local dialog_created = DialogHost.createManagedDialog geometryDiagnosticsRollout geometry_diagnostics_ini_path "MainUI" tool_key:"Geometry-Diagnostics" default_width:336 default_height:336 min_height:336

    if dialog_created then
    (
        windows.processPostedMessages()
    )

    dialog_created
    -- return
)
