/*
    Vertex Welder UI 0.012
    Frontend-only rollout for Vertex Welder. The main entry owns dependency loading and dialog execution.
*/

global VertexWelder
global VertexWelder_UI
global vertexWelderOpenUi
global vertex_welder_project_version
global vertex_welder_ui_file_version = 0.012
global vertex_welder_ui_stored_project_version = 0.018
global vertex_welder_script_path
global vertex_welder_ui_ini_path
global vertex_welder_ui_ini_section
global vertex_welder_script_prefix
global vertex_welder_dialog_key
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

    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:312 height:18

    label lbl_threshold "Threshold" pos:[12,48] width:72 height:24 align:#left
    spinner spn_threshold_mm "" pos:[96,48] width:180 height:24 range:[0.0,1000000.0,0.1] type:#float scale:0.01
    label lbl_units "mm" pos:[282,48] width:36 height:24 align:#left

    button btn_weld "WELD" pos:[12,84] width:150 height:24 tooltip:"LMB: Run WELD on one selected Editable Poly or Edit Poly object."
    button btn_per_element "PER ELEMENT" pos:[174,84] width:150 height:24 tooltip:"LMB: Run PER ELEMENT on one selected Editable Poly or Edit Poly object."
    button btn_borders "BORDERS" pos:[12,120] width:150 height:24 tooltip:"LMB: Run BORDERS on one selected Editable Poly or Edit Poly object."
    button btn_per_element_border "PER ELEMENT BORDER" pos:[174,120] width:150 height:24 tooltip:"LMB: Stitch close twin border chains inside the same current element."

    label lbl_status "Ready." pos:[12,168] width:312 height:48 align:#left

    /*
    Loads the persistent threshold value from the tool INI file.
    Invalid or missing values fall back to the production default.
    */
    function loadUiState =
    (
        ui_is_loading = true

        saved_threshold = IniSettings.getFloat vertex_welder_ui_ini_path vertex_welder_ui_ini_section "ThresholdMM" default_value:0.1
        if saved_threshold < 0.0 or saved_threshold > 1000000.0 then saved_threshold = 0.1

        spn_threshold_mm.value = saved_threshold

        ui_is_loading = false
        true
        -- return
    )

    /*
    Saves the persistent threshold value to the tool INI file.
    Dialog position and height are handled separately by the shared dialog host.
    */
    function saveUiState =
    (
        if not ui_is_loading then
        (
            IniSettings.setFloat vertex_welder_ui_ini_path vertex_welder_ui_ini_section "ThresholdMM" spn_threshold_mm.value
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
    Runs one explicit weld mode from its dedicated action button.
    Backend exceptions remain visible in the Listener and in a modal error message.
    */
    function runUiMode mode_value =
    (
        operation_error = undefined

        try
        (
            VertexWelder.runSelected mode_value spn_threshold_mm.value
        )
        catch
        (
            operation_error = getCurrentException()
            format "Vertex Welder ERROR | %\n" operation_error
            VertexWelder.setMessage ("ERROR: " + operation_error)
            messageBox operation_error title:vertex_welder_tool_title
        )

        refreshStatus()
        operation_error == undefined
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
        runUiMode #weld
    )

    on btn_per_element pressed do
    (
        runUiMode #per_element
    )

    on btn_borders pressed do
    (
        runUiMode #borders
    )

    on btn_per_element_border pressed do
    (
        runUiMode #per_element_border
    )

    on btn_tool_title Click sender event_args do
    (
        restartUiTool()
    )

    on spn_threshold_mm changed spinner_value do
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

    DialogHost.createManagedDialog VertexWelder_UI vertex_welder_ui_ini_path vertex_welder_ui_ini_section tool_key:vertex_welder_dialog_key default_width:336 default_height:240 min_height:240
    windows.processPostedMessages()
    true
    -- return
)
