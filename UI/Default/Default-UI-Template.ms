/*
Mandatory first-version frontend-only MaxScript UI baseline template.
Start every new standalone tool dialog/owning rollout from this scaffold unless explicitly overridden.
Keep feature processing in separate modules.
*/

(
    local ui_template_version = "0.05"

    /*
    Replace with the current shared project version when creating a project UI.
    The main entry-file version and visible native dialog title must use the same project version.
    */
    local project_version = "0.01"

    local ui_source_file = getSourceFileName()
    local ui_framework_dir = if ui_source_file != undefined and ui_source_file != "" then getFilenamePath ui_source_file else ""

    /*
    Loads one UI framework helper from the template directory.
    */
    function loadUiFrameworkHelper helper_name =
    (
        if ui_framework_dir == "" then
        (
            throw "Cannot resolve UI framework directory. Run this template from a saved .ms file."
        )

        local helper_path = ui_framework_dir + helper_name

        if not doesFileExist helper_path then
        (
            throw ("Missing UI framework helper: " + helper_path)
        )

        fileIn helper_path
        true
    )

    loadUiFrameworkHelper "IniSettings.ms"
    loadUiFrameworkHelper "RolloutState.ms"
    loadUiFrameworkHelper "DialogHost.ms"
    loadUiFrameworkHelper "ScriptReload.ms"
    loadUiFrameworkHelper "ToolTitleButton.ms"

    local ui_ini_path = (getDir #userScripts) + "\\ToolName-UI.ini"
    local ui_ini_section = "MainUI"

    /*
    Stable dialog-owner key. Keep this identical across all versions of the same tool.
    Never append the file version or project version.
    */
    local ui_tool_key = "ToolName"
    local ui_script_prefix = "ToolName"

    rollout defaultUiRollout ("Tool Name - v" + project_version) width:336 height:504
    (
        dotNetControl btn_tool_title "System.Windows.Forms.Button" width:312 height:24 align:#center
        checkbox chk_enabled "Enabled" checked:true
        spinner spn_amount "Amount" range:[0.0, 100.0, 1.0] type:#float fieldWidth:70
        dropdownlist ddl_mode "Mode" items:#("Mode A", "Mode B", "Mode C") selection:1
        edittext edt_value "Value" text:""
        button btn_run "Run" width:120 height:24

        /*
        Loads frontend state only.
        */
        function loadUiState =
        (
            RolloutState.loadCheckbox chk_enabled ui_ini_path ui_ini_section "Enabled" default_value:true
            RolloutState.loadSpinner spn_amount ui_ini_path ui_ini_section "Amount" default_value:1.0
            RolloutState.loadDropdown ddl_mode ui_ini_path ui_ini_section "Mode" default_value:1
            RolloutState.loadEditText edt_value ui_ini_path ui_ini_section "Value" default_value:""
        )

        /*
        Saves frontend state only.
        */
        function saveUiState =
        (
            RolloutState.saveCheckbox chk_enabled ui_ini_path ui_ini_section "Enabled"
            RolloutState.saveSpinner spn_amount ui_ini_path ui_ini_section "Amount"
            RolloutState.saveDropdown ddl_mode ui_ini_path ui_ini_section "Mode"
            RolloutState.saveEditText edt_value ui_ini_path ui_ini_section "Value"
        )

        on defaultUiRollout open do
        (
            ToolTitleButton.setupToolTitleButton btn_tool_title "Tool Name"
            ToolTitleButton.resizeToolTitleButton btn_tool_title (defaultUiRollout.width - 24)
            loadUiState()
        )

        on defaultUiRollout moved dialog_pos do
        (
            DialogHost.saveDialogPosition defaultUiRollout ui_ini_path ui_ini_section
        )

        on defaultUiRollout resized dialog_size do
        (
            ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
            DialogHost.saveDialogHeight defaultUiRollout ui_ini_path ui_ini_section min_height:180
        )

        on defaultUiRollout close do
        (
            saveUiState()
            DialogHost.saveDialogState defaultUiRollout ui_ini_path ui_ini_section min_height:180
        )

        on btn_tool_title Click sender event_args do
        (
            local source_file = getSourceFileName()

            if source_file != undefined and source_file != "" then
            (
                restartTool source_file ui_script_prefix
            )
        )

        on chk_enabled changed state do
        (
            RolloutState.saveCheckbox chk_enabled ui_ini_path ui_ini_section "Enabled"
        )

        on spn_amount changed value do
        (
            RolloutState.saveSpinner spn_amount ui_ini_path ui_ini_section "Amount"
        )

        on ddl_mode selected index do
        (
            RolloutState.saveDropdown ddl_mode ui_ini_path ui_ini_section "Mode"
        )

        on edt_value entered value do
        (
            RolloutState.saveEditText edt_value ui_ini_path ui_ini_section "Value"
        )

        on btn_run pressed do
        (
            /*
            Frontend only.
            Collect UI values here, call one public feature function, then update displayed state.
            Never place feature-processing code in this event handler.
            */
        )
    )

    DialogHost.createManagedDialog defaultUiRollout ui_ini_path ui_ini_section tool_key:ui_tool_key default_width:336 default_height:504 min_height:180
)
