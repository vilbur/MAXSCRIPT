/*
Blueprint Manager v0.039 — five reference-image planes in 3ds Max.
Runtime requires the canonical shared MaxScript UI/Default framework.
*/
(
    local project_version = "0.039"
    local script_path = getSourceFileName()
    if script_path == undefined or script_path == "" then
    (
        throw "Blueprint Manager: run the saved Blueprint-Manager.ms file, not pasted Listener text."
    )


    local script_dir = getFilenamePath script_path
    local ini_path = script_dir + "Blueprint-Manager.ini"
    local ini_section = "MainUI"
    local ui_framework_candidates = #(
        "G:\\AI\\AGENTS\\Maxscript\\UI\\Default\\",
        "C:\\GoogleDrive\\AI\\AGENTS\\Maxscript\\UI\\Default\\",
        "D:\\GoogleDrive\\AI\\AGENTS\\Maxscript\\UI\\Default\\"
    )
    local framework_dir = ""


    for candidate_dir in ui_framework_candidates while framework_dir == "" do
    (
        if doesFileExist (candidate_dir + "ToolTitleButton.ms") then
        (
            framework_dir = candidate_dir
        )
    )
    if framework_dir == "" then
    (
        throw "Blueprint Manager: shared UI/Default framework not found. See README.md for expected location."
    )


    fileIn (framework_dir + "IniSettings.ms")
    fileIn (framework_dir + "RolloutState.ms")
    fileIn (framework_dir + "DialogHost.ms")
    fileIn (framework_dir + "ScriptReload.ms")
    fileIn (framework_dir + "ToolTitleButton.ms")


    /*
    Loads the canonical dark WinForms button style without copying its implementation.
    */
    local dark_button_template = framework_dir + "..\\default-dark-button.ms"
    if not doesFileExist dark_button_template then
    (
        throw ("Blueprint Manager: shared dark button template not found: " + dark_button_template)
    )
    fileIn dark_button_template


    /*
    Prevents dialog lifecycle events from saving a transient opening position.
    */
    local restoring_dialog_position = true


    include "Blueprint-Manager-FN.ms"
    include "Blueprint-Manager-UI.ms"


    /*
    Close any prior tool instance before validating the INI.
    The prior version may save its window position during its close callback.
    */
    DialogHost.destroyToolDialogs "Blueprint-Manager"
    local initial_pos = IniSettings.getPoint2 ini_path ini_section "PosX" "PosY" default_value:[100,100]
    local initial_height = IniSettings.getInteger ini_path ini_section "Height" default_value:636
    createDialog blueprintManagerRollout width:288 height:(amax 1 initial_height) pos:initial_pos \
        style:#(#style_titlebar, #style_border, #style_sysmenu) lockWidth:true lockHeight:true
    windows.processPostedMessages()
    blueprintManagerRollout.restoreFloatingGeometry()
    DialogHost.registerToolDialog "Blueprint-Manager" blueprintManagerRollout


    case (getINISetting ini_path ini_section "DockSide") of
    (
        "left": blueprintManagerRollout.changeDockMode #cui_dock_left
        "right": blueprintManagerRollout.changeDockMode #cui_dock_right
        default: blueprintManagerRollout.changeDockMode #cui_floatable
    )
    windows.processPostedMessages()
    restoring_dialog_position = false
    blueprintManagerRollout.saveDockState()
    blueprintManagerRollout.layoutControls()
    blueprintManagerRollout.saveFloatingGeometry()
    blueprintManagerRollout.tmr_dialog_state.active = true
)