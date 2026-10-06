/*
    Redundant-Loop-Fixer 1.143
    Clean rewrite development build.
*/

global RedundantLoopFixer
global RedundantLoopFixer1143
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

struct RedundantLoopFixer1143_v
(
    file_version = 1.143,
    project_version = 1.143,
    quiet_mode = true,
    straight_angle_threshold = 5.0,

    /*
    Resolves the currently active polygon editing domain on one node.
    Returns #(#editable_poly, base_object), #(#edit_poly, edit_poly_mod), or #(#unsupported, undefined).
    */
    function getCurrentPolyTarget node =
    (
        if node == undefined or not isValidNode node then return #(#unsupported, undefined)

        current_object = modPanel.getCurrentObject()

        if current_object != undefined and classOf current_object == Edit_Poly then
        (
            current_on_node = false

            for stack_index = 1 to node.modifiers.count while not current_on_node do
            (
                if node.modifiers[stack_index] == current_object then current_on_node = true
            )

            if current_on_node then return #(#edit_poly, current_object)
        )

        if current_object != undefined and classOf current_object == Editable_Poly then
        (
            if node.baseObject == current_object then return #(#editable_poly, node.baseObject)
        )

        if node.modifiers.count == 0 and classOf node.baseObject == Editable_Poly then
        (
            return #(#editable_poly, node.baseObject)
        )

        #(#unsupported, undefined)
        -- return
    ),

    /*
    Ensures one base Editable Poly has compact live topology before any index-sensitive reads.
    If dead vertex/edge/face slots exist, collapseDeadStructs removes them before IDs are read.
    Returns true when the supplied Editable Poly is ready for fresh topology queries.
    */
    function ensureCleanEditablePolyTopology poly_value =
    (
        if poly_value == undefined or classOf poly_value != Editable_Poly then return false

        dead_flags = polyop.getHasDeadStructs poly_value

        if dead_flags != 0 then
        (
            polyop.collapseDeadStructs poly_value
            format "Redundant-Loop-Fixer DEAD TOPOLOGY CLEANED | flags:%\n" dead_flags
        )

        true
        -- return
    ),

    /*
    Collects all visible edges from one Editable Poly topology.
    Returns a BitArray, or undefined when the supplied object is not Editable Poly.
    */
    function getVisibleEditablePolyEdges poly_value =
    (
        if poly_value == undefined or classOf poly_value != Editable_Poly then return undefined

        edge_count = polyop.getNumEdges poly_value
        visible_edges = #{}
        visible_edges.count = edge_count

        for edge_index = 1 to edge_count do
        (
            if polyop.getEdgeVis poly_value edge_index then visible_edges[edge_index] = true
        )

        visible_edges
        -- return
    ),

    /*
    Reads visible-edge flags from the Editable Poly base only when the current Edit Poly has the exact same vertex and edge ID topology.
    This is a safe temporary bridge for the first clean-rewrite stage; topology-changing Edit Poly states are rejected.
    */
    function getVisibleEditPolyEdgesFromBase node edit_poly_mod =
    (
        if node == undefined or not isValidNode node then return undefined
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return undefined
        if classOf node.baseObject != Editable_Poly then return undefined

        base_poly = node.baseObject
        dead_flags = polyop.getHasDeadStructs base_poly

        if dead_flags != 0 then
        (
            format "Redundant-Loop-Fixer EDIT POLY BASE HAS DEAD TOPOLOGY | flags:% | base cleanup skipped to protect modifier indexing\n" dead_flags
            return undefined
        )

        base_vertex_count = polyop.getNumVerts base_poly
        base_edge_count = polyop.getNumEdges base_poly
        edit_vertex_count = EditPolyMod.GetNumVertices edit_poly_mod node:node
        edit_edge_count = EditPolyMod.GetNumEdges edit_poly_mod node:node

        if base_vertex_count != edit_vertex_count then return undefined
        if base_edge_count != edit_edge_count then return undefined

        for edge_index = 1 to base_edge_count do
        (
            base_pair = polyop.getEdgeVerts base_poly edge_index
            edit_vertex_a = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 1 node:node
            edit_vertex_b = EditPolyMod.GetEdgeVertex edit_poly_mod edge_index 2 node:node

            if base_pair == undefined or base_pair.count != 2 then return undefined

            same_direction = base_pair[1] == edit_vertex_a and base_pair[2] == edit_vertex_b
            opposite_direction = base_pair[1] == edit_vertex_b and base_pair[2] == edit_vertex_a

            if not same_direction and not opposite_direction then return undefined
        )

        this.getVisibleEditablePolyEdges base_poly
        -- return
    ),

    /*
    Visibly selects one complete Edge BitArray on an Editable Poly base object.
    Selection is applied once after collection.
    */
    function selectEditablePolyEdges node poly_value edge_bits =
    (
        if node == undefined or not isValidNode node then return false
        if poly_value == undefined or classOf poly_value != Editable_Poly then return false
        if edge_bits == undefined then return false

        poly_value.showCage = off
        polyop.setEdgeSelection node edge_bits

        select node
        max modify mode
        modPanel.setCurrentObject poly_value node:node
        subObjectLevel = 2
        completeRedraw()

        stored_edges = polyop.getEdgeSelection node
        missing_edges = edge_bits - stored_edges
        extra_edges = stored_edges - edge_bits
        selection_matches = missing_edges.numberSet == 0 and extra_edges.numberSet == 0

        if not selection_matches then
        (
            format "Redundant-Loop-Fixer BASE SELECTION VERIFY FAILED | requested:% | stored:% | missing:% | extra:%\n" edge_bits stored_edges missing_edges extra_edges
        )

        selection_matches
        -- return
    ),

    /*
    Visibly selects one complete Edge BitArray on the active Edit Poly modifier.
    The modifier remains in normal component-selection mode with Show Cage disabled.
    */
    function selectEditPolyEdges node edit_poly_mod edge_bits =
    (
        if node == undefined or not isValidNode node then return false
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if edge_bits == undefined then return false

        select node
        max modify mode

        edit_poly_mod.SetPrimaryNode node
        edit_poly_mod.useStackSelection = false
        edit_poly_mod.selectMode = 0
        edit_poly_mod.showCage = off

        modPanel.setCurrentObject edit_poly_mod node:node
        edit_poly_mod.SetEPolySelLevel #Edge
        subObjectLevel = 2

        old_edges = edit_poly_mod.GetSelection #Edge

        if old_edges.numberSet > 0 then
        (
            edit_poly_mod.Select #Edge old_edges select:false
        )

        if edge_bits.numberSet > 0 then
        (
            edit_poly_mod.Select #Edge edge_bits select:true
        )

        edit_poly_mod.SetEPolySelLevel #Edge
        subObjectLevel = 2
        edit_poly_mod.RefreshScreen()
        completeRedraw()

        stored_edges = edit_poly_mod.GetSelection #Edge
        missing_edges = edge_bits - stored_edges
        extra_edges = stored_edges - edge_bits
        selection_matches = missing_edges.numberSet == 0 and extra_edges.numberSet == 0

        if not selection_matches then
        (
            format "Redundant-Loop-Fixer EDIT POLY SELECTION VERIFY FAILED | requested:% | stored:% | missing:% | extra:%\n" edge_bits stored_edges missing_edges extra_edges
        )

        selection_matches
        -- return
    ),

    /*
    Runs the currently implemented clean-rewrite selection stage from the main button.
    For now this stage selects visible edges only; later filters will replace this development result.
    */
    function runSelectRemove =
    (
        if selection.count != 1 then
        (
            messageBox "Select exactly one Editable Poly or active Edit Poly object." title:"Redundant-Loop-Fixer"
            return false
        )

        node = selection[1]
        target_data = this.getCurrentPolyTarget node
        target_kind = target_data[1]
        target_value = target_data[2]
        visible_edges = undefined
        selected_ok = false

        if target_kind == #editable_poly then
        (
            if not this.ensureCleanEditablePolyTopology target_value then
            (
                messageBox "Could not validate Editable Poly topology before reading component IDs." title:"Redundant-Loop-Fixer"
                return false
            )

            visible_edges = this.getVisibleEditablePolyEdges target_value

            if visible_edges == undefined then
            (
                messageBox "Could not read visible Editable Poly edges." title:"Redundant-Loop-Fixer"
                return false
            )

            selected_ok = this.selectEditablePolyEdges node target_value visible_edges
        )
        else if target_kind == #edit_poly then
        (
            visible_edges = this.getVisibleEditPolyEdgesFromBase node target_value

            if visible_edges == undefined then
            (
                messageBox "The current Edit Poly cannot safely use the Editable Poly base as its visibility source.\n\nThe base either contains dead topology or its IDs do not match the active Edit Poly. No base cleanup is performed underneath an active Edit Poly." title:"Redundant-Loop-Fixer"
                return false
            )

            selected_ok = this.selectEditPolyEdges node target_value visible_edges
        )
        else
        (
            messageBox "Make an Editable Poly base or an Edit Poly modifier current in the Modify panel." title:"Redundant-Loop-Fixer"
            return false
        )

        if not selected_ok then
        (
            messageBox "Visible-edge selection verification failed. See Listener for requested/stored/missing/extra edge sets." title:"Redundant-Loop-Fixer"
            return false
        )

        format "Redundant-Loop-Fixer CLEAN STAGE 1 | node:% | visibleEdges:% | count:%\n" node.name visible_edges visible_edges.numberSet
        true
        -- return
    ),

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
    Returns the visible tool title from this file's version.
    File version, project version, and visible title use one identical version value.
    */
    function getDisplayTitle =
    (
        "Redundant-Loop-Fixer | v" + (file_version as string)
        -- return
    ),

    on create do
    (
    )
)

RedundantLoopFixer1143 = RedundantLoopFixer1143_v()
RedundantLoopFixer = RedundantLoopFixer1143

if epoly_tools_project_version == undefined or epoly_tools_project_version < RedundantLoopFixer.project_version then
(
    epoly_tools_project_version = RedundantLoopFixer.project_version
)

RedundantLoopFixer_Title = "Redundant-Loop-Fixer | v" + (RedundantLoopFixer.file_version as string)

rollout RedundantLoopFixer_UI RedundantLoopFixer_Title width:286 height:272
(
    button btn_select_remove "SELECT | REMOVE" pos:[12,8] width:262 height:40 tooltip:"LMB: Run the current clean-rewrite selection stage.\n\nRMB: Removal is not wired yet."
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

    on btn_select_remove pressed do
    (
        RedundantLoopFixer.runSelectRemove()
    )

    on btn_restart pressed do
    (
        RedundantLoopFixer.restartLatest()
    )
)

if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "redundant-loop-fixer-clean" (RedundantLoopFixer.getDisplayTitle()) RedundantLoopFixer RedundantLoopFixer_UI RedundantLoopFixer.file_version RedundantLoopFixer.project_version (getSourceFileName()) capabilities:#(#ui, #selection, #edge, #editable_poly, #edit_poly)

    if EPolyToolsIntegration.shouldAutoOpenUI() then RedundantLoopFixer.showUI()
)
else
(
    RedundantLoopFixer.showUI()
)
