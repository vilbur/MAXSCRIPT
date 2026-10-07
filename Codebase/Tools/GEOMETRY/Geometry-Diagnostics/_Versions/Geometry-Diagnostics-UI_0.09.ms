/*
Geometry Diagnostics frontend.
Defines the standalone test UI and delegates all processing to the backend.
*/

global geometry_diagnostics_ui_version = "0.09"
global geometry_diagnostics_ui_project_version = "0.20"
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


/*
Applies the Wall-Fixer dark WinForms button style to one Geometry Diagnostics .NET button.
The colors, border, hover state, pressed state, and bold Segoe UI font mirror the source control.
*/
function setupGeometryDiagnosticsDarkButton button_control =
(
    local color_class = dotNetClass "System.Drawing.Color"
    local font_style_class = dotNetClass "System.Drawing.FontStyle"
    local flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"

    button_control.UseVisualStyleBackColor = false
    button_control.FlatStyle = flat_style_class.Flat
    button_control.BackColor = color_class.FromArgb 68 68 68
    button_control.ForeColor = color_class.FromArgb 170 220 170
    button_control.FlatAppearance.BorderColor = color_class.FromArgb 120 120 120
    button_control.FlatAppearance.BorderSize = 1
    button_control.FlatAppearance.MouseOverBackColor = color_class.FromArgb 78 78 78
    button_control.FlatAppearance.MouseDownBackColor = color_class.FromArgb 55 55 55
    button_control.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 9.0 font_style_class.Bold

    button_control
    -- return
)


/*
Returns the WinForms mouse button name used by the directional diagnostic controls.
This preserves explicit LMB/RMB routing from the Wall-Fixer source buttons.
*/
function geometryDiagnosticsGetDotNetMouseButton event_args =
(
    ((event_args.Button.ToString()) as string)
    -- return
)


rollout geometryDiagnosticsRollout ("Geometry Diagnostics - v" + geometry_diagnostics_project_version) width:336 height:420
(
    local direction_button_tooltip

    dotNetControl btn_tool_title "System.Windows.Forms.Button" width:312 height:24 align:#center

    button btn_create_test_box "CREATE TEST BOX" width:288 height:24 tooltip:"LMB: Create an Editable Poly box with split channel-0 face-corner colors and the canonical Tessellate modifier."

    button btn_paint_face_colors "PAINT FACE COLORS" width:288 height:24 tooltip:"LMB: Paint faces on the currently selected Editable Poly or supported modifier stack level with the diagnostic color palette."

    button btn_restore_colors "RESTORE COLORS" width:288 height:24 tooltip:"LMB: Restore the exact channel-0 colors and display state captured before painting."

    button btn_dump_channel "DUMP CHANNEL 0" width:288 height:24 tooltip:"LMB: Print Editable Poly geometry and channel-0 map topology to the Listener."

    label lbl_status "Ready." width:288 height:36 align:#left

    group "DEBUG"
    (
        dropdownList ddl_position_precision "postion preccision" items:#("1mm", "0.1mm", "0.01mm") selection:3 width:288
        dropdownList ddl_ortho_tolerance "ortho tolerance" items:#("1.00mm", "2.00mm", "5.00mm", "10.00mm") selection:1 width:288

        dotNetControl btn_check_vertical "System.Windows.Forms.Button" width:132 height:38 across:2
        dotNetControl btn_check_horizontal "System.Windows.Forms.Button" width:132 height:38

        button btn_check_ortho_edges "CHECK ORTHO EDGES" width:288 height:24 tooltip:"LMB: Paint visible edges by distance severity: white valid ortho, green-to-blue valid skew/sloped through ortho tolerance, yellow-to-red invalid above tolerance."
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

        local saved_ortho_tolerance = IniSettings.getString geometry_diagnostics_ini_path "Debug" "OrthoTolerance" default_value:"1.00mm"
        local ortho_tolerance_index = findItem #("1.00mm", "2.00mm", "5.00mm", "10.00mm") saved_ortho_tolerance

        if ortho_tolerance_index == 0 then
        (
            ortho_tolerance_index = 1
        )

        ddl_ortho_tolerance.selection = ortho_tolerance_index

        if direction_button_tooltip == undefined then
        (
            direction_button_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
        )

        setupGeometryDiagnosticsDarkButton btn_check_vertical
        setupGeometryDiagnosticsDarkButton btn_check_horizontal

        local direction_orange = (dotNetClass "System.Drawing.Color").Orange
        btn_check_vertical.Text = "VERTICAL\\SKEWED"
        btn_check_vertical.ForeColor = direction_orange
        direction_button_tooltip.SetToolTip btn_check_vertical "LMB: select Z-direction edges whose XY drift is within postion preccision.\n\nRMB: select Z-direction edges whose XY drift is greater than postion preccision."

        btn_check_horizontal.Text = "HORIZONTAL SLOPED"
        btn_check_horizontal.ForeColor = direction_orange
        direction_button_tooltip.SetToolTip btn_check_horizontal "LMB: select horizontal X/Y-direction edges within postion preccision. X uses YZ drift; Y uses XZ drift.\n\nRMB: select matching horizontal edges whose off-axis drift is greater than postion preccision."

        setGeometryDiagnosticsStatus "Ready."
    )


    on geometryDiagnosticsRollout moved dialog_pos do
    (
        DialogHost.saveDialogPosition geometryDiagnosticsRollout geometry_diagnostics_ini_path "MainUI"
    )


    on geometryDiagnosticsRollout resized dialog_size do
    (
        ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)

        DialogHost.saveDialogHeight geometryDiagnosticsRollout geometry_diagnostics_ini_path "MainUI" min_height:420
    )


    on geometryDiagnosticsRollout close do
    (
        DialogHost.saveDialogState geometryDiagnosticsRollout geometry_diagnostics_ini_path "MainUI" min_height:420
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


    on ddl_ortho_tolerance selected tolerance_index do
    (
        if tolerance_index >= 1 and tolerance_index <= ddl_ortho_tolerance.items.count then
        (
            IniSettings.setString geometry_diagnostics_ini_path "Debug" "OrthoTolerance" ddl_ortho_tolerance.selected
        )
    )


    /*
    Runs one directional .NET button event through the Wall-Fixer-style edge-selection workflow.
    LMB stores the within-precision set; RMB stores the beyond-precision set and activates Edge level.
    */
    function runGeometryDiagnosticsDirectionButton direction_type selection_mode =
    (
        local selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            setGeometryDiagnosticsStatus "Select at least one geometry object."
            return false
        )

        local selection_result = checkGeometryDiagnosticsSelectedDirectionEdges \
            direction_type \
            selection_mode \
            ddl_position_precision.selected

        local selected_edge_count = selection_result[1]
        local processed_count = selection_result[2]
        local failed_count = selection_result[3]

        if processed_count == 0 then
        (
            setGeometryDiagnosticsStatus "No supported geometry object selected."
            return false
        )

        if failed_count > 0 then
        (
            setGeometryDiagnosticsStatus "Direction edge selection failed. See Listener."
            return false
        )

        local mode_text = if selection_mode == #exact then "straight" else "off-axis"

        setGeometryDiagnosticsStatus \
            ((direction_type as string) + " " + mode_text + " selected: " + (selected_edge_count as string))

        true
        -- return
    )



    on btn_check_horizontal MouseUp sender event_args do
    (
        local mouse_button = geometryDiagnosticsGetDotNetMouseButton event_args

        if mouse_button == "Left" then
        (
            runGeometryDiagnosticsDirectionButton #horizontal #exact
        )
        else if mouse_button == "Right" then
        (
            runGeometryDiagnosticsDirectionButton #horizontal #skewed
        )
    )


    on btn_check_vertical MouseUp sender event_args do
    (
        local mouse_button = geometryDiagnosticsGetDotNetMouseButton event_args

        if mouse_button == "Left" then
        (
            runGeometryDiagnosticsDirectionButton #vertical #exact
        )
        else if mouse_button == "Right" then
        (
            runGeometryDiagnosticsDirectionButton #vertical #skewed
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
            local ortho_result = checkGeometryDiagnosticsOrthoEdges source_node ddl_position_precision.selected ddl_ortho_tolerance.selected

            if ortho_result == undefined then
            (
                setGeometryDiagnosticsStatus "Ortho edge check failed. See Listener."
            )
            else
            (
                setGeometryDiagnosticsStatus \
                    ("Ortho valid:" + (ortho_result.orthogonal_edges.numberSet as string) + \
                    " tolerated:" + (ortho_result.valid_skewed_edges.numberSet as string) + \
                    " invalid:" + (ortho_result.invalid_edges.numberSet as string))
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

    local dialog_created = DialogHost.createManagedDialog geometryDiagnosticsRollout geometry_diagnostics_ini_path "MainUI" tool_key:"Geometry-Diagnostics" default_width:336 default_height:420 min_height:420

    if dialog_created then
    (
        windows.processPostedMessages()
    )

    dialog_created
    -- return
)
