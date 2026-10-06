/*
    Redundant-Loop-Fixer 0.835
    Clean rewrite shell. Old production detection logic is intentionally not copied.
*/

global RedundantLoopFixer
global RedundantLoopFixer0835
global RedundantLoopFixer_UI
global RedundantLoopFixer_Dialog_Position
global RedundantLoopFixer_Title
global EPolyToolsIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global epoly_tools_project_version

/*
Closes a previous standalone dialog before the rollout is redefined.
Preserves the last known standalone position when possible.
*/
try
(
    if RedundantLoopFixer_UI != undefined then
    (
        if RedundantLoopFixer_UI.inDialog then
        (
            try
            (
                RedundantLoopFixer_Dialog_Position = getDialogPos RedundantLoopFixer_UI
            )
            catch
            (
                format "Redundant-Loop-Fixer UI POSITION ERROR | %\n" (getCurrentException())
            )

            try
            (
                destroyDialog RedundantLoopFixer_UI
            )
            catch
            (
                format "Redundant-Loop-Fixer UI CLOSE ERROR | %\n" (getCurrentException())
            )
        )
    )
)
catch
(
    format "Redundant-Loop-Fixer UI RESET ERROR | %\n" (getCurrentException())
)

struct RedundantLoopFixer0835_v
(
    file_version = 0.835,
    project_version = 1.139,
    quiet_mode = true,
    straight_angle_threshold = 5.0,

    /*
    Returns the persistent INI file used by this clean rewrite.
    The filename stays compatible with the existing tool settings.
    */
    function getSettingsPath =
    (
        source_path = getSourceFileName()
        source_directory = getFilenamePath source_path
        source_directory + "Redundant-Loop-Fixer.ini"
        -- return
    ),

    /*
    Saves the standalone dialog position.
    Invalid coordinates are rejected instead of being written.
    */
    function saveDialogPosition dialog_pos =
    (
        if dialog_pos == undefined then return false

        dialog_x = try(dialog_pos.x as integer)catch(undefined)
        dialog_y = try(dialog_pos.y as integer)catch(undefined)

        if dialog_x == undefined or dialog_y == undefined then return false
        if dialog_x < -32000 or dialog_x > 32000 or dialog_y < -32000 or dialog_y > 32000 then return false

        RedundantLoopFixer_Dialog_Position = [dialog_x, dialog_y]
        settings_path = this.getSettingsPath()
        settings_error = undefined

        try
        (
            setINISetting settings_path "Dialog" "X" (dialog_x as string)
            setINISetting settings_path "Dialog" "Y" (dialog_y as string)
        )
        catch
        (
            settings_error = getCurrentException()
        )

        if settings_error != undefined then
        (
            format "Redundant-Loop-Fixer SETTINGS WRITE ERROR | dialog position | %\n" settings_error
            false
        )
        else
        (
            true
        )
        -- return
    ),

    /*
    Loads the remembered standalone dialog position.
    In-memory position takes priority over the INI file.
    */
    function loadDialogPosition =
    (
        if RedundantLoopFixer_Dialog_Position != undefined then return RedundantLoopFixer_Dialog_Position

        settings_path = this.getSettingsPath()
        dialog_x_text = try(getINISetting settings_path "Dialog" "X")catch("")
        dialog_y_text = try(getINISetting settings_path "Dialog" "Y")catch("")

        if dialog_x_text == "" or dialog_y_text == "" then return undefined

        dialog_x = try(dialog_x_text as integer)catch(undefined)
        dialog_y = try(dialog_y_text as integer)catch(undefined)

        if dialog_x == undefined or dialog_y == undefined then return undefined
        if dialog_x < -32000 or dialog_x > 32000 or dialog_y < -32000 or dialog_y > 32000 then return undefined

        RedundantLoopFixer_Dialog_Position = [dialog_x, dialog_y]
        RedundantLoopFixer_Dialog_Position
        -- return
    ),

    /*
    Saves QUIET mode for future detector functions.
    The clean rewrite keeps the current UI state behavior.
    */
    function saveQuietMode quiet_value =
    (
        this.quiet_mode = quiet_value == true
        settings_path = this.getSettingsPath()
        settings_error = undefined

        try
        (
            setINISetting settings_path "Settings" "Quiet" (if this.quiet_mode then "true" else "false")
        )
        catch
        (
            settings_error = getCurrentException()
        )

        if settings_error != undefined then
        (
            format "Redundant-Loop-Fixer SETTINGS WRITE ERROR | QUIET | %\n" settings_error
            false
        )
        else
        (
            true
        )
        -- return
    ),

    /*
    Loads QUIET mode from the shared tool INI.
    Missing settings default to enabled.
    */
    function loadQuietMode =
    (
        settings_path = this.getSettingsPath()
        quiet_text = try(getINISetting settings_path "Settings" "Quiet")catch("")
        quiet_value = quiet_text != "false"

        this.quiet_mode = quiet_value
        quiet_value
        -- return
    ),

    /*
    Saves the ANGLE UI value for later detector work.
    This shell does not use ANGLE for detection yet.
    */
    function saveStraightAngleThreshold angle_value =
    (
        straight_value = try(angle_value as float)catch(undefined)
        if straight_value == undefined then return false
        if straight_value < 0.0 then straight_value = 0.0
        if straight_value > 45.0 then straight_value = 45.0

        this.straight_angle_threshold = straight_value
        settings_path = this.getSettingsPath()
        settings_error = undefined

        try
        (
            setINISetting settings_path "Settings" "StraightAngleThreshold" (straight_value as string)
        )
        catch
        (
            settings_error = getCurrentException()
        )

        if settings_error != undefined then
        (
            format "Redundant-Loop-Fixer SETTINGS WRITE ERROR | ANGLE | %\n" settings_error
            false
        )
        else
        (
            true
        )
        -- return
    ),

    /*
    Loads the ANGLE UI value from the shared tool INI.
    Missing or invalid values fall back to 5 degrees.
    */
    function loadStraightAngleThreshold =
    (
        settings_path = this.getSettingsPath()
        straight_text = try(getINISetting settings_path "Settings" "StraightAngleThreshold")catch("")
        straight_value = try(straight_text as float)catch(undefined)

        if straight_text == "" or straight_value == undefined then straight_value = 5.0
        if straight_value < 0.0 then straight_value = 0.0
        if straight_value > 45.0 then straight_value = 45.0

        this.straight_angle_threshold = straight_value
        straight_value
        -- return
    ),

    /*
    Finds the highest numeric Redundant-Loop-Fixer version in the source directory.
    The current source file is the fallback when no versioned file is found.
    */
    function getLatestScriptPath =
    (
        source_path = getSourceFileName()
        source_directory = getFilenamePath source_path
        file_prefix = "Redundant-Loop-Fixer_"
        candidate_files = getFiles (source_directory + file_prefix + "*.ms")
        latest_path = source_path
        latest_version = -1.0

        for candidate_path in candidate_files do
        (
            candidate_name = getFilenameFile candidate_path

            if matchPattern candidate_name pattern:(file_prefix + "*") then
            (
                version_text = substring candidate_name (file_prefix.count + 1) (candidate_name.count - file_prefix.count)
                version_value = try(version_text as float)catch(undefined)

                if version_value != undefined and version_value > latest_version then
                (
                    latest_version = version_value
                    latest_path = candidate_path
                )
            )
        )

        latest_path
        -- return
    ),

    /*
    Reloads the highest numeric versioned script found beside this file.
    This remains the only active action in the clean shell.
    */
    function restartLatest =
    (
        latest_path = this.getLatestScriptPath()

        if latest_path == undefined or latest_path == "" then return false
        if not doesFileExist latest_path then return false

        fileIn latest_path quiet:true
        true
        -- return
    ),

    /*
    Saves the current standalone dialog position if a dialog exists.
    Returns false when the rollout is not currently standalone.
    */
    function saveCurrentDialogPosition =
    (
        if RedundantLoopFixer_UI == undefined then return false

        dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch(false)
        if not dialog_is_standalone then return false

        dialog_pos = try(getDialogPos RedundantLoopFixer_UI)catch(undefined)
        if dialog_pos == undefined then return false

        this.saveDialogPosition dialog_pos
        -- return
    ),

    /*
    Closes the standalone dialog without touching embedded manager UI.
    Any failure is reported instead of being swallowed.
    */
    function hideUI =
    (
        hide_ok = true

        if RedundantLoopFixer_UI != undefined then
        (
            dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch(false)

            if dialog_is_standalone then
            (
                this.saveCurrentDialogPosition()
                hide_error = undefined

                try
                (
                    destroyDialog RedundantLoopFixer_UI
                )
                catch
                (
                    hide_error = getCurrentException()
                )

                if hide_error != undefined then
                (
                    format "Redundant-Loop-Fixer HIDE UI ERROR | %\n" hide_error
                    hide_ok = false
                )
            )
        )

        hide_ok
        -- return
    ),

    /*
    Opens the standalone clean-rewrite UI.
    The previous saved position is restored when available.
    */
    function showUI =
    (
        this.hideUI()
        dialog_pos = this.loadDialogPosition()

        if dialog_pos != undefined then
        (
            createDialog RedundantLoopFixer_UI pos:dialog_pos
        )
        else
        (
            createDialog RedundantLoopFixer_UI
        )

        windows.processPostedMessages()
        true
        -- return
    ),

    /*
    Returns the visible tool title resolved from the current global project version.
    The global project version is established before the rollout is defined.
    */
    function getDisplayTitle =
    (
        "Redundant-Loop-Fixer | v" + (epoly_tools_project_version as string)
        -- return
    ),

    on create do
    (
    )
)

RedundantLoopFixer0835 = RedundantLoopFixer0835_v()
RedundantLoopFixer = RedundantLoopFixer0835

if epoly_tools_project_version == undefined or epoly_tools_project_version < RedundantLoopFixer.project_version then
(
    epoly_tools_project_version = RedundantLoopFixer.project_version
)

RedundantLoopFixer_Title = "Redundant-Loop-Fixer | v" + (epoly_tools_project_version as string)

rollout RedundantLoopFixer_UI RedundantLoopFixer_Title width:286 height:272
(
    button btn_select_remove "SELECT | REMOVE" pos:[12,8] width:262 height:40 enabled:false tooltip:"LMB: Clean rewrite detector is not wired yet.\n\nRMB: Clean rewrite removal is not wired yet."
    button btn_debug_all "1  SELECT ALL LOOPS" pos:[12,60] width:262 height:24 enabled:false tooltip:"Unused in the clean rewrite."
    button btn_debug_border "2  SELECT BORDER CORNER LOOPS" pos:[12,88] width:262 height:24 enabled:false tooltip:"Unused in the clean rewrite."
    button btn_debug_wall_corner "3  SELECT WALL CORNER LOOP" pos:[12,116] width:262 height:24 enabled:false tooltip:"Unused in the clean rewrite."
    button btn_debug_angle "4  SELECT ANGLED LOOPS" pos:[12,144] width:262 height:24 enabled:false tooltip:"Unused in the clean rewrite."
    checkbox chk_quiet "QUIET" pos:[12,178] width:72 height:20 checked:true tooltip:"Reserved for the clean detector diagnostics."
    spinner spn_straight_angle "ANGLE:" pos:[12,210] width:112 range:[0.0,45.0,5.0] type:#float scale:0.1 fieldwidth:46 tooltip:"Reserved for later detector rules."
    label lbl_straight_units "deg" pos:[126,212] width:28 height:16
    button btn_get_angle "GET ANGLE" pos:[147,204] width:127 height:24 enabled:false tooltip:"Unused in the clean rewrite."
    button btn_restart "RESTART" pos:[12,240] width:262 height:24 tooltip:"LMB: Load the highest numeric Redundant-Loop-Fixer version from this script directory."

    on RedundantLoopFixer_UI open do
    (
        chk_quiet.checked = RedundantLoopFixer.loadQuietMode()
        spn_straight_angle.value = RedundantLoopFixer.loadStraightAngleThreshold()
    )

    on RedundantLoopFixer_UI moved dialog_pos do
    (
        dialog_is_standalone = try(RedundantLoopFixer_UI.inDialog)catch(false)
        if dialog_is_standalone then RedundantLoopFixer.saveDialogPosition dialog_pos
    )

    on chk_quiet changed quiet_value do
    (
        RedundantLoopFixer.saveQuietMode quiet_value
    )

    on spn_straight_angle changed angle_value do
    (
        RedundantLoopFixer.saveStraightAngleThreshold angle_value
    )

    on btn_restart pressed do
    (
        RedundantLoopFixer.restartLatest()
    )
)

if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "redundant-loop-fixer-clean" (RedundantLoopFixer.getDisplayTitle()) RedundantLoopFixer RedundantLoopFixer_UI RedundantLoopFixer.file_version RedundantLoopFixer.project_version (getSourceFileName()) capabilities:#(#ui)

    if EPolyToolsIntegration.shouldAutoOpenUI() then RedundantLoopFixer.showUI()
)
else
(
    RedundantLoopFixer.showUI()
)
