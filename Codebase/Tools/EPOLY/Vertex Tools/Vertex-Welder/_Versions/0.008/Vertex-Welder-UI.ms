/*
    Vertex Welder UI 0.008
    Frontend-only rollout for Vertex Welder. The main entry owns dependency loading and dialog execution.
*/

global VertexWelder
global VertexWelder_UI
global vertexWelderOpenUi
global vertex_welder_project_version
global vertex_welder_ui_file_version = 0.008
global vertex_welder_ui_stored_project_version = 0.008
global vertex_welder_script_path
global vertex_welder_ui_ini_path
global vertex_welder_ui_ini_section
global vertex_welder_script_prefix
global vertex_welder_tool_title
global IniSettings
global DialogHost
global ToolTitleButton
global restartTool

if vertex_welder_project_version == undefined or vertex_welder_project_version < vertex_welder_ui_stored_project_version then
(
    vertex_welder_project_version = vertex_welder_ui_stored_project_version
)

if vertex_welder_tool_title == undefined or vertex_welder_tool_title == "" then
(
    vertex_welder_tool_title = "Vertex Welder " + (vertex_welder_project_version as string)
)

rollout VertexWelder_UI vertex_welder_tool_title width:336 height:240
(
    local ui_is_loading = false

    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:312 height:24

    label lbl_threshold "Threshold" pos:[12,48] width:72 height:24 align:#left
    spinner spn_threshold_mm "" pos:[96,48] width:180 height:24 range:[0.0,1000000.0,0.1] type:#float scale:0.01
    label lbl_units "mm" pos:[282,48] width:36 height:24 align:#left

    radiobuttons rdo_mode labels:#("WELD", "PER ELEMENT", "BORDERS") pos:[12,84] columns:3 default:1

    button btn_weld "WELD" pos:[12,120] width:312 height:36 tooltip:"LMB: Run the selected weld mode on one Editable Poly or Edit Poly object."
    button btn_test "TEST" pos:[12,168] width:312 height:24 tooltip:"LMB: Create a test source for the selected mode.\n\nRMB: Weld the stored test source and print debug data to the Listener."
    label lbl_status "Ready." pos:[12,204] width:312 height:24 align:#left

    /*
    Converts the active radio button to the backend mode symbol.
    Returns one supported mode symbol on every path.
    */
    function getUiMode =
    (
        case rdo_mode.state of
        (
            1: #weld
            2: #per_element
            3: #borders
            default: #weld
        )
        -- return
    )

    /*
    Loads the persistent threshold and mode values from the tool INI file.
    Invalid or missing values fall back to the production defaults.
    */
    function loadUiState =
    (
        ui_is_loading = true

        saved_threshold = IniSettings.getFloat vertex_welder_ui_ini_path vertex_welder_ui_ini_section "ThresholdMM" default_value:0.1
        if saved_threshold < 0.0 or saved_threshold > 1000000.0 then saved_threshold = 0.1

        saved_mode = IniSettings.getInteger vertex_welder_ui_ini_path vertex_welder_ui_ini_section "Mode" default_value:1
        if saved_mode < 1 or saved_mode > 3 then saved_mode = 1

        spn_threshold_mm.value = saved_threshold
        rdo_mode.state = saved_mode

        ui_is_loading = false
        true
        -- return
    )

    /*
    Saves the persistent threshold and mode values to the tool INI file.
    Dialog position and height are handled separately by the shared dialog host.
    */
    function saveUiState =
    (
        if not ui_is_loading then
        (
            IniSettings.setFloat vertex_welder_ui_ini_path vertex_welder_ui_ini_section "ThresholdMM" spn_threshold_mm.value
            IniSettings.setInteger vertex_welder_ui_ini_path vertex_welder_ui_ini_section "Mode" rdo_mode.state
        )

        true
        -- return
    )

    /*
    Copies the backend status message into the rollout status label.
    Returns true after the visible label has been synchronized.
    */
    function refreshStatus =
    (
        lbl_status.text = VertexWelder.last_message
        true
        -- return
    )

    /*
    Saves current UI/dialog state and restarts through the canonical shared reload helper.
    The newest matching versioned script is loaded when one exists.
    */
    function restartUiTool =
    (
        saveUiState()
        DialogHost.saveDialogState VertexWelder_UI vertex_welder_ui_ini_path vertex_welder_ui_ini_section min_height:240
        restartTool vertex_welder_script_path vertex_welder_script_prefix
        -- return
    )

    on btn_weld pressed do
    (
        operation_error = undefined

        try
        (
            VertexWelder.runSelected (getUiMode()) spn_threshold_mm.value
        )
        catch
        (
            operation_error = getCurrentException()
            format "Vertex Welder ERROR | %\n" operation_error
            VertexWelder.setMessage ("ERROR: " + operation_error)
            messageBox operation_error title:vertex_welder_tool_title
        )

        refreshStatus()
    )

    on btn_test pressed do
    (
        operation_error = undefined

        try
        (
            VertexWelder.createTestFixture (getUiMode()) spn_threshold_mm.value
        )
        catch
        (
            operation_error = getCurrentException()
            format "Vertex Welder TEST CREATE ERROR | %\n" operation_error
            VertexWelder.setMessage ("ERROR: " + operation_error)
            messageBox operation_error title:vertex_welder_tool_title
        )

        refreshStatus()
    )

    on btn_test rightClick do
    (
        operation_error = undefined

        try
        (
            VertexWelder.runStoredTest (getUiMode()) spn_threshold_mm.value
        )
        catch
        (
            operation_error = getCurrentException()
            format "Vertex Welder TEST RUN ERROR | %\n" operation_error
            VertexWelder.setMessage ("ERROR: " + operation_error)
            messageBox operation_error title:vertex_welder_tool_title
        )

        refreshStatus()
    )

    on btn_tool_title Click sender event_args do
    (
        restartUiTool()
    )

    on spn_threshold_mm changed spinner_value do
    (
        if not ui_is_loading then saveUiState()
    )

    on rdo_mode changed mode_state do
    (
        if not ui_is_loading then saveUiState()
    )

    on VertexWelder_UI open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Vertex Welder"
        ToolTitleButton.resizeToolTitleButton btn_tool_title (VertexWelder_UI.width - 24)
        loadUiState()
        refreshStatus()
    )

    on VertexWelder_UI moved dialog_pos do
    (
        DialogHost.saveDialogPosition VertexWelder_UI vertex_welder_ui_ini_path vertex_welder_ui_ini_section
    )

    on VertexWelder_UI resized dialog_size do
    (
        ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
        DialogHost.saveDialogHeight VertexWelder_UI vertex_welder_ui_ini_path vertex_welder_ui_ini_section min_height:240
    )

    on VertexWelder_UI close do
    (
        saveUiState()
        DialogHost.saveDialogState VertexWelder_UI vertex_welder_ui_ini_path vertex_welder_ui_ini_section min_height:240
    )

    on VertexWelder_UI help do
    (
        restartUiTool()
    )
)

/*
Opens the standalone managed Vertex Welder dialog after the main entry has loaded all shared UI dependencies.
The UI module itself never auto-opens when fileIn is called directly.
*/
function vertexWelderOpenUi =
(
    if VertexWelder_UI == undefined then return false
    if VertexWelder == undefined then return false
    if vertex_welder_ui_ini_path == undefined or vertex_welder_ui_ini_path == "" then return false

    if VertexWelder_UI.inDialog then destroyDialog VertexWelder_UI

    DialogHost.createManagedDialog VertexWelder_UI vertex_welder_ui_ini_path vertex_welder_ui_ini_section default_width:336 default_height:240 min_height:240
    windows.processPostedMessages()
    true
    -- return
)
