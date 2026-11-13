/*
MAX BOOST SERVICE v0.02.
A central host for lightweight 3ds Max experience-enhancement services.
*/
 
global max_boost_service_version = "0.02"
global max_boost_service_source_path = getSourceFileName()
global max_boost_service_ini_path = ""
global max_boost_service_ui_prefix = "Max-Boost-Service"
 
/*
Loads one required dependency and reports the exact missing file if not found.
*/
function maxBoostLoadFile file_path =
(
    if not doesFileExist file_path then
    (
        throw ("MAX BOOST SERVICE | Missing dependency: " + file_path)
    )
 
    fileIn file_path
    true
    -- return
)
 
(
    script_dir = getFilenamePath max_boost_service_source_path
    shared_ui_dir = script_dir + "..\\UI\\Default\\"
    module_dir = script_dir + "Modules\\Selection\\"
 
    max_boost_service_ini_path = script_dir + "Max-Boost-Service.ini"
 
    maxBoostLoadFile (shared_ui_dir + "IniSettings.ms")
    maxBoostLoadFile (shared_ui_dir + "RolloutState.ms")
    maxBoostLoadFile (shared_ui_dir + "DialogHost.ms")
    maxBoostLoadFile (shared_ui_dir + "ScriptReload.ms")
    maxBoostLoadFile (shared_ui_dir + "ToolTitleButton.ms")
 
    maxBoostLoadFile (module_dir + "instanceModifiersOnCopy.ms")
    maxBoostLoadFile (module_dir + "maxBoostWaitForNodesCloned.ms")
    maxBoostLoadFile (module_dir + "MaxBoostSelection.ms")
 
    ini_section = "Selection"
    initial_enabled = IniSettings.getBoolean max_boost_service_ini_path ini_section "ReinstanceModifiersOnObjectCopy" default_value:false
 
    try
    (
        MaxBoostService.setReinstanceEnabled initial_enabled
    )
    catch
    (
        exception_text = getCurrentException()
        format "MAX BOOST SERVICE | Failed to initialise Selection callback: %\n" exception_text
        throw()
    )
 
    rollout maxBoostSelectionRollout "Selection" width:312 height:72
    (
        checkbox chk_reinstance "Reinstance modifiers on object copy" checked:false pos:[12,24] width:288 height:24 tooltip:"Ask to instance the source object's modifiers after copying objects."
 
        on maxBoostSelectionRollout open do
        (
            chk_reinstance.checked = MaxBoostService.reinstance_enabled
        )
 
        on chk_reinstance changed enabled_state do
        (
            try
            (
                MaxBoostService.setReinstanceEnabled enabled_state
                IniSettings.setBoolean max_boost_service_ini_path "Selection" "ReinstanceModifiersOnObjectCopy" MaxBoostService.reinstance_enabled
            )
            catch
            (
                exception_text = getCurrentException()
                format "MAX BOOST SERVICE | Could not change Selection callback: %\n" exception_text
                chk_reinstance.checked = MaxBoostService.reinstance_enabled
                messageBox ("Could not change service state:\n" + exception_text) title:"Max Boost Service"
            )
        )
    )
 
    rollout maxBoostMainRollout ("Max Boost Service - v" + max_boost_service_version) width:336 height:180
    (
        dotNetControl btn_title "System.Windows.Forms.Button" pos:[12,12] width:312 height:18
        subRollout sr_selection "" pos:[12,42] width:312 height:102
        label lbl_service_status "Service remains active when this window closes." pos:[12,150] width:312 height:18
 
        on maxBoostMainRollout open do
        (
            ToolTitleButton.setupToolTitleButton btn_title "MAX BOOST SERVICE"
            ToolTitleButton.resizeToolTitleButton btn_title (maxBoostMainRollout.width - 24)
            addSubRollout sr_selection maxBoostSelectionRollout
        )
 
        on maxBoostMainRollout moved dialog_pos do
        (
            DialogHost.saveDialogPosition maxBoostMainRollout max_boost_service_ini_path "MainUI"
        )
 
        on maxBoostMainRollout resized dialog_size do
        (
            ToolTitleButton.resizeToolTitleButton btn_title (dialog_size.x - 24)
            DialogHost.saveDialogHeight maxBoostMainRollout max_boost_service_ini_path "MainUI" min_height:180
        )
 
        on maxBoostMainRollout close do
        (
            DialogHost.saveDialogState maxBoostMainRollout max_boost_service_ini_path "MainUI" min_height:180
        )
 
        on btn_title Click sender event_args do
        (
            restartTool max_boost_service_source_path max_boost_service_ui_prefix
        )
    )
 
    DialogHost.createManagedDialog maxBoostMainRollout max_boost_service_ini_path "MainUI" tool_key:"MaxBoostService" default_width:336 default_height:180 min_height:180
    windows.processPostedMessages()
)