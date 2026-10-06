/*
Straight Edge Fixer 0.53
Detects repeated horizontal edge rows and aligns nearby horizontal edges to them.
*/

global WallFixerVersion
global WallFixerRollout
global wall_fixer_runtime_mode
global straight_edge_fixer_auto_open_dialog
global wall_fixer_version_system
global wall_fixer_version_epoch
global straight_edge_fixer_file_version = "0.53"
global straight_edge_fixer_tool_version = 1.0529
global EPolyToolsIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global EPOLY_TOOLS_MANAGER_PATH
global EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE
global EPOLY_TOOLS_MANAGER_LOAD_ERROR
global EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY
global EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY
global EPOLY_TOOLS_MANAGER_CANDIDATE_PATH
global EPOLY_TOOLS_MANAGER_SEARCH_DEPTH
global EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR
global epoly_tools_project_version

if EPolyToolsIntegration == undefined then
(
    EPOLY_TOOLS_MANAGER_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = getFilenamePath (getSourceFileName())
    EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DEPTH = 0

    while EPOLY_TOOLS_MANAGER_PATH == undefined and EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY != "" and EPOLY_TOOLS_MANAGER_SEARCH_DEPTH < 16 do
    (
        EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY + "PolyToosManager.ms"

        if doesFileExist EPOLY_TOOLS_MANAGER_CANDIDATE_PATH then
        (
            EPOLY_TOOLS_MANAGER_PATH = EPOLY_TOOLS_MANAGER_CANDIDATE_PATH
        )
        else
        (
            EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY

            if EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count > 0 and EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR[EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count] == "\\" then
            (
                EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = substring EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR 1 (EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR.count - 1)
            )

            EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = getFilenamePath EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR

            if EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY == EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY then
            (
                EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = ""
            )
            else
            (
                EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY
            )
        )

        EPOLY_TOOLS_MANAGER_SEARCH_DEPTH += 1
    )

    EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE = EPOLY_TOOLS_RUNTIME_MODE
    EPOLY_TOOLS_MANAGER_LOAD_ERROR = undefined
    EPOLY_TOOLS_RUNTIME_MODE = #library

    if EPOLY_TOOLS_MANAGER_PATH != undefined then
    (
        try
        (
            fileIn EPOLY_TOOLS_MANAGER_PATH quiet:true -- resolved parent PolyToosManager.ms
        )
        catch
        (
            EPOLY_TOOLS_MANAGER_LOAD_ERROR = getCurrentException()
        )
    )
    else
    (
        EPOLY_TOOLS_MANAGER_LOAD_ERROR = "PolyToosManager.ms was not found in any parent EPolyTools directory."
    )

    EPOLY_TOOLS_RUNTIME_MODE = EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE
    EPOLY_TOOLS_MANAGER_PREVIOUS_RUNTIME_MODE = undefined
    EPOLY_TOOLS_MANAGER_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_PARENT_DIRECTORY = undefined
    EPOLY_TOOLS_MANAGER_CANDIDATE_PATH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_DEPTH = undefined
    EPOLY_TOOLS_MANAGER_SEARCH_PATH_WITHOUT_SEPARATOR = undefined

    if EPOLY_TOOLS_MANAGER_LOAD_ERROR != undefined then
    (
        throw EPOLY_TOOLS_MANAGER_LOAD_ERROR
    )
)

/*
Registers this file's shared Wall-Fixer tool version.
Accepts legacy string or numeric global versions; the highest loaded version wins.
*/
if wall_fixer_version_system != 1 then
(
    wall_fixer_version_system = 1
)

if wall_fixer_version_epoch != 3 then
(
    wall_fixer_version_epoch = 3
    WallFixerVersion = undefined
)

straight_edge_fixer_current_tool_version_number = undefined

if WallFixerVersion != undefined then
(
    try
    (
        straight_edge_fixer_current_tool_version_number = WallFixerVersion as float
    )
    catch
    (
        straight_edge_fixer_current_tool_version_number = undefined
    )
)

if straight_edge_fixer_current_tool_version_number == undefined then
(
    WallFixerVersion = straight_edge_fixer_tool_version
)
else if straight_edge_fixer_tool_version > straight_edge_fixer_current_tool_version_number then
(
    WallFixerVersion = straight_edge_fixer_tool_version
)

if WallFixerRollout != undefined then
(
    try
    (
        WallFixerRollout.title = ("Wall-Fixer " + (WallFixerVersion as string))
    )
    catch
    (
    )
)


global straightEdgeFixerCompareData
global straightEdgeFixerCompareLevelData
global StraightEdgeFixer_v
global StraightEdgeFixer
global straightEdgeFixer_ui

/*
Compares edge records by their center world Z.
Used by qsort while detecting Z levels.
*/
function straightEdgeFixerCompareData item_a item_b =
(
    if (item_a[4] < item_b[4]) then
    (
        -1
    )
    else if (item_a[4] > item_b[4]) then
    (
        1
    )
    else
    (
        0
    )
) -- return

/*
Compares detected level records from bottom to top.
Used by qsort before reporting and alignment.
*/
function straightEdgeFixerCompareLevelData level_a level_b =
(
    if (level_a[4] < level_b[4]) then
    (
        -1
    )
    else if (level_a[4] > level_b[4]) then
    (
        1
    )
    else
    (
        0
    )
) -- return

struct StraightEdgeFixer_v
(
    version = "0.2",
    file_version = 0.53,
    project_version = 0.14,
    ini_file = ((getDir #plugcfg) + "\\Straight-Edge-Fixer.ini"),
    legacy_ini_file = ((getDir #plugcfg) + "\\Aling-Edges-To-Levels.ini"),

    /*
    Counts enabled bits in a BitArray.
    Used for edge and vertex report counts.
    */
    function countBits bit_set =
    (
        bit_count = 0

        if bit_set != undefined then
        (
            for bit_id in bit_set do
            (
                bit_count += 1
            )
        )

        bit_count
        -- return
    ),


    /*
    Migrates settings from the previous Aling-Edges-To-Levels INI file once.
    Existing Straight Edge Fixer settings are never overwritten.
    */
    function migrateLegacyIni =
    (
        if ((doesFileExist ini_file) == false) and (doesFileExist legacy_ini_file) then
        (
            level_tolerance = getIniSetting legacy_ini_file "Settings" "LevelTolerance"
            min_level_edges = getIniSetting legacy_ini_file "Settings" "MinLevelEdges"
            search_in_z = getIniSetting legacy_ini_file "Settings" "SearchInZ"
            angle_threshold = getIniSetting legacy_ini_file "Settings" "AngleThreshold"
            quiet_mode = getIniSetting legacy_ini_file "Settings" "QuietMode"
            dialog_x = getIniSetting legacy_ini_file "Dialog" "X"
            dialog_y = getIniSetting legacy_ini_file "Dialog" "Y"

            if (level_tolerance != "") then setIniSetting ini_file "Settings" "LevelTolerance" level_tolerance
            if (min_level_edges != "") then setIniSetting ini_file "Settings" "MinLevelEdges" min_level_edges
            if (search_in_z != "") then setIniSetting ini_file "Settings" "SearchInZ" search_in_z
            if (angle_threshold != "") then setIniSetting ini_file "Settings" "AngleThreshold" angle_threshold
            if (quiet_mode != "") then setIniSetting ini_file "Settings" "QuietMode" quiet_mode
            if (dialog_x != "") then setIniSetting ini_file "Dialog" "X" dialog_x
            if (dialog_y != "") then setIniSetting ini_file "Dialog" "Y" dialog_y
        )

        true
        -- return
    ),

    /*
    Safely converts an INI string to a floating-point value.
    Returns default_value when the stored value is missing or invalid.
    */
    function getIniFloat section_name key_name default_value =
    (
        result_value = default_value
        stored_value = getIniSetting ini_file section_name key_name

        if ((stored_value != undefined) and (stored_value != "")) then
        (
            try
            (
                result_value = stored_value as float
            )
            catch
            (
                result_value = default_value
            )
        )

        result_value
        -- return
    ),

    /*
    Safely converts an INI string to an integer value.
    Returns default_value when the stored value is missing or invalid.
    */
    function getIniInteger section_name key_name default_value =
    (
        result_value = default_value
        stored_value = getIniSetting ini_file section_name key_name

        if ((stored_value != undefined) and (stored_value != "")) then
        (
            try
            (
                result_value = stored_value as integer
            )
            catch
            (
                result_value = default_value
            )
        )

        result_value
        -- return
    ),

    /*
    Reads a persisted boolean value.
    Missing values use the supplied default.
    */
    function getIniBoolean section_name key_name default_value =
    (
        result_value = default_value
        stored_value = getIniSetting ini_file section_name key_name

        if (stored_value == "1") then
        (
            result_value = true
        )
        else if (stored_value == "0") then
        (
            result_value = false
        )

        result_value
        -- return
    ),

    /*
    Returns the compact label for the current 3ds Max display units.
    Custom display mode uses its physical CustomUnit suffix instead of the word custom.
    */
    function getDisplayUnitLabel =
    (
        display_type = units.DisplayType
        unit_label = "units"


        case display_type of
        (
            #Generic:
            (
                unit_label = "units"
            )
            #Metric:
            (
                case units.MetricType of
                (
                    #Millimeters: unit_label = "mm"
                    #Centimeters: unit_label = "cm"
                    #Meters: unit_label = "m"
                    #Kilometers: unit_label = "km"
                    default: unit_label = "units"
                )
            )
            #US:
            (
                case units.USType of
                (
                    #Frac_In: unit_label = "in"
                    #Dec_In: unit_label = "in"
                    #Frac_Ft: unit_label = "ft"
                    #Dec_Ft: unit_label = "ft"
                    #Ft_Frac_In: unit_label = "ft/in"
                    #Ft_Dec_In: unit_label = "ft/in"
                    default: unit_label = "units"
                )
            )
            #Custom:
            (
                case units.CustomUnit of
                (
                    #Millimeters: unit_label = "mm"
                    #Centimeters: unit_label = "cm"
                    #Meters: unit_label = "m"
                    #Kilometers: unit_label = "km"
                    #Inches: unit_label = "in"
                    #Feet: unit_label = "ft"
                    #Miles: unit_label = "mi"
                    default: unit_label = "units"
                )
            )
            default:
            (
                unit_label = "units"
            )
        )


        unit_label
        -- return
    ),


    /*
    Loads active tool settings from the INI file.
    Returns #(rows_distance, min_row_edges, angle_threshold, quiet_mode).
    */
    function loadSettings =
    (
        level_tolerance = getIniFloat "Settings" "LevelTolerance" 0.01
        min_level_edges = getIniInteger "Settings" "MinLevelEdges" 3
        angle_threshold = getIniFloat "Settings" "AngleThreshold" 45.0
        quiet_mode = getIniBoolean "Settings" "QuietMode" false

        if (level_tolerance <= 0.0) then
        (
            level_tolerance = 0.01
        )

        if (min_level_edges < 1) then
        (
            min_level_edges = 3
        )

        if (angle_threshold < 0.1) then
        (
            angle_threshold = 0.1
        )
        else if (angle_threshold > 45.0) then
        (
            angle_threshold = 45.0
        )

        #(level_tolerance, min_level_edges, angle_threshold, quiet_mode)
        -- return
    ),

    /*
    Saves active tool settings to the INI file.
    Horizontal and vertical direction matching both use Angle.
    */
    function saveSettings level_tolerance min_level_edges angle_threshold quiet_mode =
    (
        setIniSetting ini_file "Settings" "LevelTolerance" (level_tolerance as string)
        setIniSetting ini_file "Settings" "MinLevelEdges" (min_level_edges as string)
        setIniSetting ini_file "Settings" "AngleThreshold" (angle_threshold as string)
        setIniSetting ini_file "Settings" "QuietMode" (if quiet_mode then "1" else "0")

        true
        -- return
    ),


    /*
    Loads the saved dialog screen position.
    Returns a Point2 used directly by createDialog.
    */
    function loadDialogPosition =
    (
        position_x = getIniInteger "Dialog" "X" 100
        position_y = getIniInteger "Dialog" "Y" 100

        [position_x, position_y]
        -- return
    ),

    /*
    Saves the dialog screen position.
    The position is stored independently from tool settings.
    */
    function saveDialogPosition dialog_position =
    (
        if (dialog_position != undefined) then
        (
            setIniSetting ini_file "Dialog" "X" (dialog_position.x as string)
            setIniSetting ini_file "Dialog" "Y" (dialog_position.y as string)
        )

        true
        -- return
    ),

    /*
    Finds an existing top Edit Poly modifier.
    Returns undefined when the current top modifier is not Edit Poly.
    */
    function getTopEditPoly node =
    (
        edit_poly = undefined

        if (node.modifiers.count > 0) then
        (
            top_modifier = node.modifiers[1]

            if (classOf top_modifier == Edit_Poly) then
            (
                edit_poly = top_modifier
            )
        )

        edit_poly
        -- return
    ),

    /*
    Returns true when a modifier instance belongs to the supplied node stack.
    Uses modPanel.getModifierIndex so instanced modifiers are handled correctly.
    */
    function modifierBelongsToNode node modifier_value =
    (
        result_value = false

        if ((isValidNode node) and (modifier_value != undefined)) then
        (
            try
            (
                result_value = ((modPanel.getModifierIndex node modifier_value) != undefined)
            )
            catch
            (
                result_value = false
            )
        )

        result_value
        -- return
    ),

    /*
    Returns the currently active Edit Poly modifier when it belongs to this node.
    Undefined is returned when the Modify panel is closed or another stack item is active.
    */
    function getActiveEditPoly node =
    (
        edit_poly = undefined
        current_object = undefined

        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
            current_object = undefined
        )

        if ((current_object != undefined) and
            (classOf current_object == Edit_Poly) and
            (modifierBelongsToNode node current_object)) then
        (
            edit_poly = current_object
        )

        edit_poly
        -- return
    ),

    /*
    Finds the first Edit Poly modifier with an exact case-insensitive name.
    Search order follows the modifier stack from top to bottom.
    */
    function findNamedEditPoly node modifier_name =
    (
        edit_poly = undefined
        requested_name = toUpper modifier_name

        for modifier_index = 1 to node.modifiers.count while (edit_poly == undefined) do
        (
            modifier_value = node.modifiers[modifier_index]

            if ((classOf modifier_value == Edit_Poly) and
                ((toUpper modifier_value.name) == requested_name)) then
            (
                edit_poly = modifier_value
            )
        )

        edit_poly
        -- return
    ),

    /*
    Keeps the command panel in Create mode during EDGE FIXER processing.
    Avoids repeated Modify-panel and sub-object activation while selections are stored directly in Edit Poly.
    */
    function ensureCreatePanelMode =
    (
        current_panel_mode = undefined

        try
        (
            current_panel_mode = getCommandPanelTaskMode()
        )
        catch
        (
            current_panel_mode = undefined
        )

        if current_panel_mode != #create then
        (
            try
            (
                setCommandPanelTaskMode mode:#create
            )
            catch
            (
            )
        )

        true
        -- return
    ),


    /*
    Returns the one STRAIGHT EDGE FIXER modifier for this object.
    The topmost named modifier is kept and every lower duplicate is removed.
    */
    function ensureSingleStraightEdgeFixerModifier node =
    (
        fixer_name = "STRAIGHT EDGE FIXER"
        fixer_modifier = undefined
        duplicate_modifiers = #()
        created_new_modifier = false

        for modifier_index = 1 to node.modifiers.count do
        (
            modifier_value = node.modifiers[modifier_index]

            if ((classOf modifier_value == Edit_Poly) and
                ((toUpper modifier_value.name) == fixer_name)) then
            (
                if fixer_modifier == undefined then
                (
                    fixer_modifier = modifier_value
                )
                else
                (
                    append duplicate_modifiers modifier_value
                )
            )
        )

        if duplicate_modifiers.count > 0 then
        (
            ensureCreatePanelMode()

            for duplicate_modifier in duplicate_modifiers do
            (
                if modifierBelongsToNode node duplicate_modifier then
                (
                    try
                    (
                        deleteModifier node duplicate_modifier
                    )
                    catch
                    (
                    )
                )
            )

            update node
        )

        if fixer_modifier == undefined then
        (
            fixer_modifier = Edit_Poly()
            fixer_modifier.name = fixer_name
            fixer_modifier.showCage = off
            addModifier node fixer_modifier
            created_new_modifier = true
        )
        else
        (
            fixer_modifier.name = fixer_name
        )

        if classOf node.baseObject == Editable_Poly then
        (
            try(node.baseObject.showCage = off)catch()
        )

        if fixer_modifier != undefined then
        (
            try(fixer_modifier.showCage = off)catch()
        )

        #(fixer_modifier, created_new_modifier)
        -- return
    ),


    /*
    Binds an Edit Poly modifier to the node only when its primary node is different.
    Avoids rebinding local modifier data after a component selection has already been written.
    */
    function ensureEditPolyPrimaryNode node edit_poly =
    (
        primary_node = undefined
        bind_ok = false

        if ((node != undefined) and (edit_poly != undefined)) then
        (
            try
            (
                primary_node = EditPolyMod.GetPrimaryNode edit_poly
            )
            catch
            (
                primary_node = undefined
            )

            if primary_node != node then
            (
                try
                (
                    EditPolyMod.SetPrimaryNode edit_poly node
                )
                catch
                (
                )
            )

            try
            (
                primary_node = EditPolyMod.GetPrimaryNode edit_poly
            )
            catch
            (
                primary_node = undefined
            )

            bind_ok = (primary_node == node)
        )

        bind_ok
        -- return
    ),


    /*
    Prepares STRAIGHT EDGE FIXER as a live pass-through Edit Poly before topology is read.
    A lightweight bind is attempted first; Modify-panel activation is used only when live edges are still unavailable.
    */
    function prepareStraightEdgeFixerModifier node fixer_modifier =
    (
        modifier_ready = false
        live_edge_count = 0
        evaluated_mesh = undefined
        original_selection = selection as array

        if ((node != undefined) and (isValidNode node) and (fixer_modifier != undefined)) then
        (
            try
            (
                ensureCreatePanelMode()
                ensureEditPolyPrimaryNode node fixer_modifier
                fixer_modifier.useStackSelection = false
                fixer_modifier.showCage = off

                if ((EditPolyMod.GetEPolySelLevel fixer_modifier) != #Edge) then
                (
                    EditPolyMod.SetEPolySelLevel fixer_modifier #Edge
                )

                update node
                live_edge_count = EditPolyMod.GetNumEdges fixer_modifier node:node

                if live_edge_count <= 0 then
                (
                    evaluated_mesh = snapshotAsMesh node

                    if evaluated_mesh != undefined then
                    (
                        free evaluated_mesh
                        evaluated_mesh = undefined
                    )

                    update node
                    live_edge_count = EditPolyMod.GetNumEdges fixer_modifier node:node
                )

                /*
                Rare stale modifiers may require one Modify-panel evaluation.
                No component level is entered, and Create mode is restored immediately.
                */
                if live_edge_count <= 0 then
                (
                    select node
                    setCommandPanelTaskMode mode:#modify
                    modPanel.setCurrentObject fixer_modifier
                    update node

                    evaluated_mesh = snapshotAsMesh node

                    if evaluated_mesh != undefined then
                    (
                        free evaluated_mesh
                        evaluated_mesh = undefined
                    )

                    live_edge_count = EditPolyMod.GetNumEdges fixer_modifier node:node
                    ensureCreatePanelMode()

                    if original_selection.count > 0 then
                    (
                        select original_selection
                    )
                    else
                    (
                        clearSelection()
                    )
                )

                modifier_ready = (live_edge_count > 0)
            )
            catch
            (
                if evaluated_mesh != undefined then
                (
                    free evaluated_mesh
                )

                ensureCreatePanelMode()

                if original_selection.count > 0 then
                (
                    select original_selection
                )
                else
                (
                    clearSelection()
                )

                modifier_ready = false
            )
        )

        modifier_ready
        -- return
    ),


    /*
    Resolves a live dedicated STRAIGHT EDGE FIXER Edit Poly for this object.
    Stale zero-topology copies are rebuilt once before any EDGE FIXER caller receives the adapter.
    */
    function getGeometryAdapter node =
    (
        fixer_result = ensureSingleStraightEdgeFixerModifier node
        fixer_modifier = fixer_result[1]
        created_new_modifier = fixer_result[2]
        modifier_ready = prepareStraightEdgeFixerModifier node fixer_modifier
        should_rebuild = false

        if ((not modifier_ready) and (fixer_modifier != undefined)) then
        (
            if classOf node.baseObject == Editable_Poly then
            (
                try
                (
                    should_rebuild = ((polyop.getNumEdges node.baseObject) > 0)
                )
                catch
                (
                    should_rebuild = false
                )
            )
        )

        if should_rebuild then
        (
            deleteModifier node fixer_modifier
            update node

            fixer_result = ensureSingleStraightEdgeFixerModifier node
            fixer_modifier = fixer_result[1]
            created_new_modifier = true
            modifier_ready = prepareStraightEdgeFixerModifier node fixer_modifier
        )

        adapter = #(#edit_poly, fixer_modifier, created_new_modifier)

        adapter
        -- return
    ),

    /*
    Verifies an existing STRAIGHT EDGE FIXER is always reused and never duplicated.
    Repeated adapter requests must keep the same modifier reference and stack count.
    */
    function testSingleStraightEdgeFixerModifier =
    (
        test_passed = true
        test_node = undefined
        original_selection = selection as array

        try
        (
            test_node = box length:10.0 width:10.0 height:10.0
            convertToPoly test_node

            bottom_modifier = Edit_Poly()
            bottom_modifier.name = "STRAIGHT EDGE FIXER"
            addModifier test_node bottom_modifier

            middle_modifier = Edit_Poly()
            middle_modifier.name = "straight edge fixer"
            addModifier test_node middle_modifier

            top_modifier = Edit_Poly()
            top_modifier.name = "STRAIGHT EDGE FIXER"
            addModifier test_node top_modifier

            first_adapter = getGeometryAdapter test_node
            second_adapter = getGeometryAdapter test_node
            third_adapter = getGeometryAdapter test_node
            named_modifier_count = 0

            for modifier_index = 1 to test_node.modifiers.count do
            (
                modifier_value = test_node.modifiers[modifier_index]

                if ((classOf modifier_value == Edit_Poly) and
                    ((toUpper modifier_value.name) == "STRAIGHT EDGE FIXER")) then
                (
                    named_modifier_count += 1
                )
            )

            test_passed = test_passed and (first_adapter[2] == top_modifier)
            test_passed = test_passed and (second_adapter[2] == top_modifier)
            test_passed = test_passed and (third_adapter[2] == top_modifier)
            test_passed = test_passed and (not first_adapter[3])
            test_passed = test_passed and (not second_adapter[3])
            test_passed = test_passed and (not third_adapter[3])
            test_passed = test_passed and (named_modifier_count == 1)
        )
        catch
        (
            test_passed = false
        )

        if ((test_node != undefined) and (isValidNode test_node)) then
        (
            delete test_node
        )

        if original_selection.count > 0 then
        (
            select original_selection
        )
        else
        (
            clearSelection()
        )

        ensureCreatePanelMode()

        test_passed
        -- return
    ),


    /*
    Returns the number of live edges exposed by the current geometry adapter.
    Edit Poly is re-prepared once when a stale zero-topology read is encountered.
    */
    function getEdgeCount node adapter =
    (
        edge_count = 0

        if (adapter[1] == #editable_poly) then
        (
            edge_count = polyop.getNumEdges (adapter[2])
        )
        else if ((adapter[1] == #edit_poly) and (adapter[2] != undefined)) then
        (
            try
            (
                edge_count = EditPolyMod.GetNumEdges (adapter[2]) node:node
            )
            catch
            (
                edge_count = 0
            )

            if edge_count <= 0 then
            (
                if prepareStraightEdgeFixerModifier node (adapter[2]) then
                (
                    try
                    (
                        edge_count = EditPolyMod.GetNumEdges (adapter[2]) node:node
                    )
                    catch
                    (
                        edge_count = 0
                    )
                )
            )
        )

        edge_count
        -- return
    ),

    /*
    Verifies an untouched named STRAIGHT EDGE FIXER becomes live before the first topology scan.
    This reproduces the checker failure where GetNumEdges previously returned zero until the modifier was activated later.
    */
    function testStraightEdgeFixerLiveTopology =
    (
        test_passed = true
        test_node = undefined
        seeded_modifier = undefined
        original_selection = selection as array
        original_panel_mode = getCommandPanelTaskMode()
        original_current_object = undefined
        original_subobject_level = subObjectLevel

        try
        (
            original_current_object = modPanel.getCurrentObject()
        )
        catch
        (
        )

        try
        (
            test_node = box length:10.0 width:10.0 height:10.0
            convertToPoly test_node

            expected_edge_count = polyop.getNumEdges test_node.baseObject

            seeded_modifier = Edit_Poly()
            seeded_modifier.name = "STRAIGHT EDGE FIXER"
            seeded_modifier.showCage = off
            addModifier test_node seeded_modifier

            adapter = getGeometryAdapter test_node
            live_edge_count = getEdgeCount test_node adapter

            test_passed = test_passed and (adapter[2] == seeded_modifier)
            test_passed = test_passed and (expected_edge_count > 0)
            test_passed = test_passed and (live_edge_count == expected_edge_count)
            test_passed = test_passed and ((adapter[2]).useStackSelection == false)
            test_passed = test_passed and ((adapter[2]).showCage == off)
        )
        catch
        (
            test_passed = false
        )

        if ((test_node != undefined) and (isValidNode test_node)) then
        (
            delete test_node
        )

        if original_selection.count > 0 then
        (
            select original_selection
        )
        else
        (
            clearSelection()
        )

        try
        (
            setCommandPanelTaskMode mode:original_panel_mode

            if ((original_panel_mode == #modify) and (original_current_object != undefined)) then
            (
                modPanel.setCurrentObject original_current_object
                subObjectLevel = original_subobject_level
            )
        )
        catch
        (
        )

        test_passed
        -- return
    ),


    /*
    Returns the two vertex IDs used by one edge.
    Supports Editable Poly and Edit Poly.
    */
    function getEdgeVertIds node adapter edge_id =
    (
        edge_verts = #()

        if (adapter[1] == #editable_poly) then
        (
            edge_verts = polyop.getEdgeVerts (adapter[2]) edge_id
        )
        else if (adapter[1] == #edit_poly) then
        (
            vert_a = EditPolyMod.GetEdgeVertex (adapter[2]) edge_id 1 node:node
            vert_b = EditPolyMod.GetEdgeVertex (adapter[2]) edge_id 2 node:node
            edge_verts = #(vert_a, vert_b)
        )

        edge_verts
        -- return
    ),


    /*
    Returns true only when the current poly edge is visible.
    Invisible triangulation edges are ignored by direction checks and edge-level analysis.
    */
    function isEdgeVisible node adapter edge_id =
    (
        result_value = false

        try
        (
            if (adapter[1] == #editable_poly) then
            (
                result_value = polyop.getEdgeVis (adapter[2]) edge_id
            )
            else if (adapter[1] == #edit_poly) then
            (
                result_value = polyop.getEdgeVis node edge_id
            )
        )
        catch
        (
            /*
            Fallback for a top Edit Poly over an Editable Poly base object.
            Use this only when the evaluated-node query is unavailable.
            */
            try
            (
                if ((classOf node.baseObject == Editable_Poly) and (edge_id <= polyop.getNumEdges node.baseObject)) then
                (
                    result_value = polyop.getEdgeVis node.baseObject edge_id
                )
                else
                (
                    result_value = false
                )
            )
            catch
            (
                result_value = false
            )
        )

        result_value
        -- return
    ),

    /*
    Returns one vertex position in object-local coordinates.
    Supports Editable Poly and Edit Poly.
    */
    function getVertexPosition node adapter vert_id =
    (
        vertex_position = [0,0,0]

        if (adapter[1] == #editable_poly) then
        (
            vertex_position = polyop.getVert (adapter[2]) vert_id
        )
        else if (adapter[1] == #edit_poly) then
        (
            vertex_position = EditPolyMod.GetVertex (adapter[2]) vert_id node:node
        )

        vertex_position
        -- return
    ),

    /*
    Returns one vertex position in world coordinates.
    The node object transform is applied to the current geometry position.
    */
    function getVertexWorldPosition node adapter vert_id =
    (
        local_position = getVertexPosition node adapter vert_id
        world_position = local_position * node.objectTransform

        world_position
        -- return
    ),


    /*
    Returns true when one visible poly edge is an open border edge.
    Border topology is read from the current Editable Poly or evaluated Edit Poly result.
    */
    function isBorderEdge node adapter edge_id =
    (
        result_value = false

        if (isEdgeVisible node adapter edge_id) then
        (
            try
            (
                if (adapter[1] == #editable_poly) then
                (
                    edge_faces = polyop.getFacesUsingEdge (adapter[2]) edge_id
                )
                else
                (
                    edge_faces = polyop.getFacesUsingEdge node edge_id
                )

                result_value = (edge_faces.numberSet == 1)
            )
            catch
            (
                result_value = false
            )
        )

        result_value
        -- return
    ),

    /*
    Collects all visible open border edges.
    Invisible triangulation edges never participate in Border Check.
    */
    function getVisibleBorderEdges node adapter =
    (
        border_edges = #{}
        edge_count = getEdgeCount node adapter

        for edge_id = 1 to edge_count do
        (
            if (isBorderEdge node adapter edge_id) then
            (
                border_edges[edge_id] = true
            )
        )

        border_edges
        -- return
    ),

    /*
    Returns true when two local XY coordinates match inside tolerance.
    Local Z is intentionally ignored because it represents wall height.
    */
    function localXYMatches point_a point_b tolerance =
    (
        ((abs (point_a.x - point_b.x)) <= tolerance) and
        ((abs (point_a.y - point_b.y)) <= tolerance)
        -- return
    ),

    /*
    Returns true when one border edge follows one local XY column.
    Both endpoints must share the same local X and Y inside tolerance.
    */
    function isLocalVerticalBorderEdge node adapter edge_id tolerance =
    (
        result_value = false
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexPosition node adapter edge_verts[1]
            point_b = getVertexPosition node adapter edge_verts[2]
            result_value = localXYMatches point_a point_b tolerance
        )

        result_value
        -- return
    ),

    /*
    Tests whether two one-dimensional Z intervals overlap or touch.
    Tolerance allows tiny coordinate errors around the shared height.
    */
    function zRangesOverlapOrTouch min_a max_a min_b max_b tolerance =
    (
        ((max_a + tolerance) >= min_b) and ((max_b + tolerance) >= min_a)
        -- return
    ),

    /*
    Returns true when two border edges are separate IDs on the same local XY column
    and their local Z ranges overlap or touch without sharing a welded vertex.
    */
    function borderEdgesFormUnweldedColumn node adapter edge_a edge_b tolerance =
    (
        result_value = false
        edge_a_verts = getEdgeVertIds node adapter edge_a
        edge_b_verts = getEdgeVertIds node adapter edge_b

        if ((edge_a_verts.count == 2) and (edge_b_verts.count == 2)) then
        (
            shared_vertex =
                (edge_a_verts[1] == edge_b_verts[1]) or
                (edge_a_verts[1] == edge_b_verts[2]) or
                (edge_a_verts[2] == edge_b_verts[1]) or
                (edge_a_verts[2] == edge_b_verts[2])

            if (not shared_vertex) then
            (
                if ((isLocalVerticalBorderEdge node adapter edge_a tolerance) and
                    (isLocalVerticalBorderEdge node adapter edge_b tolerance)) then
                (
                    edge_a_point = getVertexPosition node adapter edge_a_verts[1]
                    edge_b_point = getVertexPosition node adapter edge_b_verts[1]

                    if (localXYMatches edge_a_point edge_b_point tolerance) then
                    (
                        edge_a_point_2 = getVertexPosition node adapter edge_a_verts[2]
                        edge_b_point_2 = getVertexPosition node adapter edge_b_verts[2]

                        min_a = amin edge_a_point.z edge_a_point_2.z
                        max_a = amax edge_a_point.z edge_a_point_2.z
                        min_b = amin edge_b_point.z edge_b_point_2.z
                        max_b = amax edge_b_point.z edge_b_point_2.z

                        result_value = zRangesOverlapOrTouch min_a max_a min_b max_b tolerance
                    )
                )
            )
        )

        result_value
        -- return
    ),

    /*
    Finds visible border edges that look like an unwelded vertical seam.
    Both members of every matching edge pair are selected.
    */
    function findUnweldedBorderEdges node adapter border_edges tolerance =
    (
        invalid_edges = #{}
        border_edge_array = for edge_id in border_edges collect edge_id

        if (border_edge_array.count > 1) then
        (
            for edge_index_a = 1 to (border_edge_array.count - 1) do
            (
                edge_a = border_edge_array[edge_index_a]

                for edge_index_b = (edge_index_a + 1) to border_edge_array.count do
                (
                    edge_b = border_edge_array[edge_index_b]

                    if (borderEdgesFormUnweldedColumn node adapter edge_a edge_b tolerance) then
                    (
                        invalid_edges[edge_a] = true
                        invalid_edges[edge_b] = true
                    )
                )
            )
        )

        invalid_edges
        -- return
    ),

    /*
    Returns all visible border edges using one vertex.
    Used to walk ordered border loops.
    */
    function getBorderEdgesAtVertex node adapter border_edges vert_id =
    (
        result_edges = #()

        for edge_id in border_edges do
        (
            edge_verts = getEdgeVertIds node adapter edge_id

            if (edge_verts.count == 2) then
            (
                if ((edge_verts[1] == vert_id) or (edge_verts[2] == vert_id)) then
                (
                    append result_edges edge_id
                )
            )
        )

        result_edges
        -- return
    ),

    /*
    Returns the opposite vertex of an edge.
    Zero is returned when the supplied vertex is not part of that edge.
    */
    function getOtherEdgeVertex node adapter edge_id vert_id =
    (
        other_vert = 0
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            if (edge_verts[1] == vert_id) then
            (
                other_vert = edge_verts[2]
            )
            else if (edge_verts[2] == vert_id) then
            (
                other_vert = edge_verts[1]
            )
        )

        other_vert
        -- return
    ),

    /*
    Walks one visible border chain from a seed edge.
    Returns #(ordered_vertices, ordered_edges, is_closed).
    */
    function traceBorderLoop node adapter border_edges seed_edge =
    (
        ordered_vertices = #()
        ordered_edges = #()
        closed_loop = false
        seed_verts = getEdgeVertIds node adapter seed_edge

        if (seed_verts.count == 2) then
        (
            start_vert = seed_verts[1]
            current_vert = seed_verts[2]
            current_edge = seed_edge

            append ordered_vertices start_vert
            append ordered_vertices current_vert
            append ordered_edges current_edge

            continue_walk = true
            safety_count = 0
            max_steps = border_edges.numberSet + 2

            while (continue_walk and (safety_count < max_steps)) do
            (
                safety_count += 1
                incident_edges = getBorderEdgesAtVertex node adapter border_edges current_vert
                next_edge = 0

                for candidate_edge in incident_edges while (next_edge == 0) do
                (
                    if (candidate_edge != current_edge) then
                    (
                        next_edge = candidate_edge
                    )
                )

                if (next_edge == 0) then
                (
                    continue_walk = false
                )
                else
                (
                    next_vert = getOtherEdgeVertex node adapter next_edge current_vert

                    if (next_vert == 0) then
                    (
                        continue_walk = false
                    )
                    else if (next_vert == start_vert) then
                    (
                        append ordered_edges next_edge
                        closed_loop = true
                        continue_walk = false
                    )
                    else if ((findItem ordered_vertices next_vert) > 0) then
                    (
                        continue_walk = false
                    )
                    else
                    (
                        append ordered_edges next_edge
                        append ordered_vertices next_vert
                        current_edge = next_edge
                        current_vert = next_vert
                    )
                )
            )
        )

        #(ordered_vertices, ordered_edges, closed_loop)
        -- return
    ),

    /*
    Calculates a Newell normal from an ordered local-space border loop.
    The normal is used only to distinguish convex and reflex turns.
    */
    function getBorderLoopNormal node adapter ordered_vertices =
    (
        normal_value = [0,0,0]
        vert_count = ordered_vertices.count

        if (vert_count >= 3) then
        (
            for vert_index = 1 to vert_count do
            (
                next_index = if (vert_index == vert_count) then 1 else (vert_index + 1)
                point_a = getVertexPosition node adapter ordered_vertices[vert_index]
                point_b = getVertexPosition node adapter ordered_vertices[next_index]

                normal_value.x += (point_a.y - point_b.y) * (point_a.z + point_b.z)
                normal_value.y += (point_a.z - point_b.z) * (point_a.x + point_b.x)
                normal_value.z += (point_a.x - point_b.x) * (point_a.y + point_b.y)
            )
        )

        if ((length normal_value) > 0.0000001) then
        (
            normal_value = normalize normal_value
        )

        normal_value
        -- return
    ),

    /*
    Finds border edges touching reflex border corners with interior angle above 180 degrees.
    Only closed visible border loops with an unambiguous two-edge border chain are tested.
    */
    function findReflexBorderEdges node adapter border_edges =
    (
        invalid_edges = #{}
        remaining_edges = copy border_edges

        while (remaining_edges.numberSet > 0) do
        (
            seed_edge = 0

            for edge_id in remaining_edges while (seed_edge == 0) do
            (
                seed_edge = edge_id
            )

            if (seed_edge > 0) then
            (
                loop_data = traceBorderLoop node adapter border_edges seed_edge
                ordered_vertices = loop_data[1]
                ordered_edges = loop_data[2]
                closed_loop = loop_data[3]

                for walked_edge in ordered_edges do
                (
                    remaining_edges[walked_edge] = false
                )

                if (closed_loop and (ordered_vertices.count >= 3) and
                    (ordered_edges.count == ordered_vertices.count)) then
                (
                    loop_normal = getBorderLoopNormal node adapter ordered_vertices

                    if ((length loop_normal) > 0.0000001) then
                    (
                        vert_count = ordered_vertices.count

                        for vert_index = 1 to vert_count do
                        (
                            previous_index = if (vert_index == 1) then vert_count else (vert_index - 1)
                            next_index = if (vert_index == vert_count) then 1 else (vert_index + 1)

                            previous_point = getVertexPosition node adapter ordered_vertices[previous_index]
                            current_point = getVertexPosition node adapter ordered_vertices[vert_index]
                            next_point = getVertexPosition node adapter ordered_vertices[next_index]

                            vector_to_previous = previous_point - current_point
                            vector_to_next = next_point - current_point

                            previous_length = length vector_to_previous
                            next_length = length vector_to_next

                            if ((previous_length > 0.0000001) and
                                (next_length > 0.0000001)) then
                            (
                                previous_direction = vector_to_previous / previous_length
                                next_direction = vector_to_next / next_length
                                direction_dot = dot previous_direction next_direction
                                direction_dot = amax -1.0 (amin 1.0 direction_dot)

                                turn_cross = cross vector_to_previous vector_to_next
                                signed_turn = dot turn_cross loop_normal

                                /*
                                Standard reflex corner:
                                With Newell normal built from the same loop order,
                                negative = convex turn and positive = reflex turn.
                                */
                                is_reflex_corner = (signed_turn > 0.0000001)

                                /*
                                360-degree backtrack:
                                Both neighboring vertices lie in almost the same direction
                                from the current border vertex. The border walks out and back
                                on itself. The two remote vertices do NOT need to share position.
                                */
                                is_backtrack_360 = (direction_dot >= 0.9999)

                                if (is_reflex_corner or is_backtrack_360) then
                                (
                                    previous_edge_index = if (vert_index == 1) then ordered_edges.count else (vert_index - 1)
                                    next_edge_index = vert_index

                                    invalid_edges[ordered_edges[previous_edge_index]] = true
                                    invalid_edges[ordered_edges[next_edge_index]] = true
                                )
                            )
                        )
                    )
                )
            )
        )

        invalid_edges
        -- return
    ),

    /*
    Checks visible open borders for unwelded local-Z seams and reflex corners.
    Results are stored in STRAIGHT EDGE FIXER while the command panel stays in Create mode.
    */
    function checkBorders tolerance =
    (
        selected_nodes = selection as array
        total_invalid_edges = 0
        total_unwelded_edges = 0
        total_reflex_edges = 0
        processed_count = 0

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            ensureCreatePanelMode()

            for node in selected_nodes do
            (
                if (isValidNode node and (superClassOf node == GeometryClass)) then
                (
                    processed_count += 1
                    adapter = getGeometryAdapter node
                    border_edges = getVisibleBorderEdges node adapter
                    unwelded_edges = findUnweldedBorderEdges node adapter border_edges tolerance
                    reflex_edges = findReflexBorderEdges node adapter border_edges
                    invalid_edges = copy unwelded_edges
                    invalid_edges += reflex_edges

                    if (adapter[1] == #editable_poly) then
                    (
                        polyop.setEdgeSelection (adapter[2]) invalid_edges
                    )
                    else if (adapter[1] == #edit_poly) then
                    (
                        geometry_source = adapter[2]
                        ensureEditPolyPrimaryNode node geometry_source
                        geometry_source.useStackSelection = false

                        if ((EditPolyMod.GetEPolySelLevel geometry_source) != #Edge) then
                        (
                            EditPolyMod.SetEPolySelLevel geometry_source #Edge
                        )

                        EditPolyMod.SetSelection geometry_source #Edge invalid_edges node:node
                    )

                    total_unwelded_edges += countBits unwelded_edges
                    total_reflex_edges += countBits reflex_edges
                    total_invalid_edges += countBits invalid_edges
                )
            )

            if (processed_count > 0) then
            (
                completeRedraw()
                format "Border Check: stored % invalid border edge(s). Unwelded/overlapping: %, reflex >180 deg: %. Create panel kept active.\n" total_invalid_edges total_unwelded_edges total_reflex_edges
            )
        )

        total_invalid_edges
        -- return
    ),

    /*
    Enters native Border sub-object mode on the selected Editable Poly/Edit Poly and selects all borders.
    This fast RMB path deliberately avoids geometry-adapter creation and explicit border-edge analysis.
    */
    function selectAllBorders =
    (
        selected_nodes = for node in (selection as array) where isValidNode node and superClassOf node == GeometryClass collect node

        if selected_nodes.count == 0 then return undefined

        node = selected_nodes[1]
        geometry_source = getActiveEditPoly node

        if geometry_source == undefined then
        (
            geometry_source = getTopEditPoly node
        )

        if geometry_source == undefined and classOf node.baseObject == Editable_Poly then
        (
            geometry_source = node.baseObject
        )

        if geometry_source == undefined then return undefined

        try
        (
            select node
            max modify mode

            if classOf geometry_source == Edit_Poly then
            (
                ensureEditPolyPrimaryNode node geometry_source
                geometry_source.useStackSelection = false
                geometry_source.showCage = off
                modPanel.setCurrentObject geometry_source
                EditPolyMod.SetEPolySelLevel geometry_source #Border
            )
            else
            (
                geometry_source.showCage = off
                modPanel.setCurrentObject geometry_source
            )

            subObjectLevel = 3
            max select all
            completeRedraw()
            format "Border Select All: native Border Select All completed on %.\n" node.name
            "all"
        )
        catch
        (
            undefined
        )
        -- return
    ),


    /*
    Returns true when an edge is horizontal within tolerance.
    Horizontal means endpoint world-Z difference does not exceed tolerance.
    */
    function isHorizontalEdge node adapter edge_id tolerance =
    (
        result_value = false
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]
            result_value = ((abs (point_a.z - point_b.z)) <= tolerance)
        )

        result_value
        -- return
    ),

    /*
    Returns true when an edge is vertical within tolerance.
    Vertical means endpoint world-X and world-Y differences are within tolerance.
    */
    function isVerticalEdge node adapter edge_id tolerance =
    (
        result_value = false
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]

            result_value =
                ((abs (point_a.x - point_b.x)) <= tolerance) and
                ((abs (point_a.y - point_b.y)) <= tolerance)
        )

        result_value
        -- return
    ),


    /*
    Verifies the geometry adapter exposes the helper functions required by direction and Border checks.
    The test confirms edge count, edge vertices, world positions, visibility and exact direction tests.
    */
    function testGeometryAdapterHelpers =
    (
        test_passed = true
        test_node = undefined
        original_selection = selection as array

        try
        (
            test_node = box length:10.0 width:10.0 height:10.0
            adapter = getGeometryAdapter test_node
            edge_count = getEdgeCount test_node adapter

            test_passed = test_passed and (edge_count > 0)

            if edge_count > 0 then
            (
                edge_verts = getEdgeVertIds test_node adapter 1
                test_passed = test_passed and (edge_verts.count == 2)

                if edge_verts.count == 2 then
                (
                    point_a = getVertexWorldPosition test_node adapter edge_verts[1]
                    point_b = getVertexWorldPosition test_node adapter edge_verts[2]
                    test_passed = test_passed and (point_a != undefined)
                    test_passed = test_passed and (point_b != undefined)
                )

                edge_visible = isEdgeVisible test_node adapter 1
                test_passed = test_passed and ((edge_visible == true) or (edge_visible == false))

                horizontal_value = isHorizontalEdge test_node adapter 1 0.0
                vertical_value = isVerticalEdge test_node adapter 1 0.0
                test_passed = test_passed and ((horizontal_value == true) or (horizontal_value == false))
                test_passed = test_passed and ((vertical_value == true) or (vertical_value == false))
            )
        )
        catch
        (
            test_passed = false
        )

        if ((test_node != undefined) and (isValidNode test_node)) then
        (
            delete test_node
        )

        if original_selection.count > 0 then
        (
            select original_selection
        )
        else
        (
            clearSelection()
        )

        test_passed
        -- return
    ),


    /*
    Returns horizontal/vertical direction angles from edge component lengths.
    The result is #(angle_from_horizontal, angle_from_vertical) in degrees.
    */
    function getDirectionAngles horizontal_length vertical_length =
    (
        result_value = #(undefined, undefined)
        edge_length = sqrt ((horizontal_length * horizontal_length) + (vertical_length * vertical_length))

        if (edge_length > 0.0000001) then
        (
            horizontal_ratio = horizontal_length / edge_length
            vertical_ratio = vertical_length / edge_length
            horizontal_ratio = amin 1.0 (amax 0.0 horizontal_ratio)
            vertical_ratio = amin 1.0 (amax 0.0 vertical_ratio)

            angle_from_horizontal = asin vertical_ratio
            angle_from_vertical = asin horizontal_ratio

            result_value = #(angle_from_horizontal, angle_from_vertical)
        )

        result_value
        -- return
    ),


    /*
    Clamps a floating-point value to a specified range.
    Used to keep acos input valid for direction classification.
    */
    function clampFloat input_value min_value max_value =
    (
        if input_value < min_value then
        (
            input_value = min_value
        )
        else if input_value > max_value then
        (
            input_value = max_value
        )

        input_value
        -- return
    ),

    /*
    Gets horizontal and vertical angular deviation for one edge in world space.
    Returns #(horizontal_deviation, vertical_deviation), or undefined for a zero/invalid edge.
    */
    function getEdgeAxisDeviation node adapter edge_id =
    (
        result_value = undefined
        edge_verts = getEdgeVertIds node adapter edge_id

        if edge_verts.count == 2 then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]

            if ((point_a != undefined) and (point_b != undefined)) then
            (
                edge_vector = point_b - point_a
                edge_length = length edge_vector

                if edge_length > 0.0000001 then
                (
                    z_ratio = abs(edge_vector.z) / edge_length
                    z_ratio = clampFloat z_ratio 0.0 1.0

                    vertical_deviation = acos z_ratio
                    horizontal_deviation = abs(90.0 - vertical_deviation)

                    result_value = #(
                        horizontal_deviation,
                        vertical_deviation
                    )
                )
            )
        )

        result_value
        -- return
    ),

    /*
    Classifies one edge as horizontal, vertical, skewed, or sloped.
    Skewed means near vertical but not exactly vertical, matching the stable classifier.
    */
    function getEdgeDirectionType node adapter edge_id angle_threshold:5.0 exact_epsilon:0.000001 =
    (
        result_value = undefined
        deviations = getEdgeAxisDeviation node adapter edge_id

        if deviations != undefined then
        (
            horizontal_deviation = deviations[1]
            vertical_deviation = deviations[2]

            if horizontal_deviation <= exact_epsilon then
            (
                result_value = #horizontal
            )
            else if vertical_deviation <= exact_epsilon then
            (
                result_value = #vertical
            )
            else if vertical_deviation <= angle_threshold then
            (
                result_value = #skewed
            )
            else
            (
                result_value = #sloped
            )
        )

        result_value
        -- return
    ),

    /*
    Gets all edges matching one stable direction category from the active geometry adapter.
    Supports #horizontal, #vertical, #skewed, and #sloped for Editable Poly and Edit Poly sources.
    */
    function getDirectionalEdgeSelection node adapter mode angle_threshold:5.0 exact_epsilon:0.000001 =
    (
        edge_selection = #{}

        if ((node != undefined) and (adapter != undefined)) then
        (
            edge_count = getEdgeCount node adapter

            for edge_id = 1 to edge_count do
            (
                edge_type = getEdgeDirectionType node adapter edge_id angle_threshold:angle_threshold exact_epsilon:exact_epsilon

                if edge_type == mode then
                (
                    edge_selection[edge_id] = true
                )
            )
        )

        edge_selection
        -- return
    ),

    /*
    Returns both world direction deviation angles for one edge.
    This compatibility method now uses the stable axis-deviation classifier.
    */
    function getEdgeDirectionAngles node adapter edge_id =
    (
        deviations = getEdgeAxisDeviation node adapter edge_id

        if deviations == undefined then
        (
            #(undefined, undefined)
        )
        else
        (
            deviations
        )
        -- return
    ),

    /*
    Returns the edge angle from the horizontal world plane in degrees.
    Zero degrees is horizontal and ninety degrees is vertical.
    */
    function getEdgeAngleFromHorizontal node adapter edge_id =
    (
        deviations = getEdgeAxisDeviation node adapter edge_id
        result_value = undefined

        if deviations != undefined then
        (
            result_value = deviations[1]
        )

        result_value
        -- return
    ),

    /*
    Returns true only for non-exact positive deviation inside the requested Angle.
    Exact zero-deviation edges are reserved for LMB and never qualify for RMB.
    */
    function isSkewedDirectionCandidate exact_match angle_from_target angle_threshold =
    (
        result_value = false

        if ((not exact_match) and (angle_from_target != undefined)) then
        (
            result_value = ((angle_from_target > 0.0) and (angle_from_target <= angle_threshold))
        )

        result_value
        -- return
    ),

    /*
    Returns true when an edge is inside the horizontal Angle cone but is not exactly horizontal.
    Detection is based on the stable world-space axis deviation used by all direction categories.
    */
    function isHorizontalCheckCandidate node adapter edge_id tolerance angle_threshold exact_epsilon:0.000001 =
    (
        result_value = false
        deviations = getEdgeAxisDeviation node adapter edge_id

        if deviations != undefined then
        (
            horizontal_deviation = deviations[1]
            exact_match = (horizontal_deviation <= exact_epsilon)
            result_value = isSkewedDirectionCandidate exact_match horizontal_deviation angle_threshold
        )

        result_value
        -- return
    ),

    /*
    Returns true when an edge is inside the vertical Angle cone but is not exactly vertical.
    Detection is based on the stable world-space axis deviation used by all direction categories.
    */
    function isVerticalCheckCandidate node adapter edge_id tolerance angle_threshold exact_epsilon:0.000001 =
    (
        result_value = false
        deviations = getEdgeAxisDeviation node adapter edge_id

        if deviations != undefined then
        (
            vertical_deviation = deviations[2]
            exact_match = (vertical_deviation <= exact_epsilon)
            result_value = isSkewedDirectionCandidate exact_match vertical_deviation angle_threshold
        )

        result_value
        -- return
    ),

    /*
    Tests exact-LMB versus strict positive skewed-RMB angle semantics.
    Tiny real deviations stay positive because getDirectionAngles uses component ratios and asin.
    */
    function testDirectionAngleThreshold =
    (
        test_passed = true

        test_passed = test_passed and (not (isSkewedDirectionCandidate true 0.0 5.0))
        test_passed = test_passed and (not (isSkewedDirectionCandidate false 0.0 5.0))
        test_passed = test_passed and (isSkewedDirectionCandidate false 0.001 5.0)
        test_passed = test_passed and (isSkewedDirectionCandidate false 5.0 5.0)
        test_passed = test_passed and (not (isSkewedDirectionCandidate false 5.001 5.0))
        test_passed = test_passed and (not (isSkewedDirectionCandidate false 90.0 5.0))

        vertical_test_angles = getDirectionAngles 0.0466476 1.0
        horizontal_test_angles = getDirectionAngles 1.0 0.0466476
        precision_vertical_angles = getDirectionAngles 0.001 7.15
        precision_horizontal_angles = getDirectionAngles 7.15 0.001

        test_passed = test_passed and ((abs (vertical_test_angles[2] - 2.6704)) < 0.01)
        test_passed = test_passed and (isSkewedDirectionCandidate false vertical_test_angles[2] 40.0)
        test_passed = test_passed and ((abs (horizontal_test_angles[1] - 2.6704)) < 0.01)
        test_passed = test_passed and (isSkewedDirectionCandidate false horizontal_test_angles[1] 40.0)
        test_passed = test_passed and (precision_vertical_angles[2] > 0.0)
        test_passed = test_passed and (precision_vertical_angles[2] < 0.01)
        test_passed = test_passed and (isSkewedDirectionCandidate false precision_vertical_angles[2] 0.1)
        test_passed = test_passed and (precision_horizontal_angles[1] > 0.0)
        test_passed = test_passed and (precision_horizontal_angles[1] < 0.01)
        test_passed = test_passed and (isSkewedDirectionCandidate false precision_horizontal_angles[1] 0.1)

        test_passed
        -- return
    ),


    /*
    Selects an edge BitArray on the current geometry source.
    Edit Poly uses its own local selection and verifies the written result.
    */
    function setEdgeSelection node adapter edge_selection =
    (
        geometry_source = if ((adapter != undefined) and (adapter.count >= 2)) then adapter[2] else undefined
        requested_selection = if edge_selection != undefined then edge_selection else #{}
        selection_applied = false
        actual_selection = #{}

        if ((adapter != undefined) and (adapter.count >= 2) and (adapter[1] == #editable_poly) and (geometry_source != undefined)) then
        (
            try
            (
                polyop.setEdgeSelection geometry_source requested_selection
                actual_selection = polyop.getEdgeSelection geometry_source
            )
            catch
            (
                actual_selection = #{}
            )

            if actual_selection == undefined then actual_selection = #{}
            selection_applied = (actual_selection == requested_selection)
        )
        else if ((adapter != undefined) and (adapter.count >= 2) and (adapter[1] == #edit_poly) and (geometry_source != undefined)) then
        (
            ensureCreatePanelMode()
            ensureEditPolyPrimaryNode node geometry_source
            geometry_source.useStackSelection = false

            if ((EditPolyMod.GetEPolySelLevel geometry_source) != #Edge) then
            (
                EditPolyMod.SetEPolySelLevel geometry_source #Edge
            )

            try
            (
                EditPolyMod.SetSelection geometry_source #Edge requested_selection node:node
                actual_selection = EditPolyMod.GetSelection geometry_source #Edge node:node
            )
            catch
            (
                actual_selection = #{}
            )

            if actual_selection == undefined then actual_selection = #{}
            selection_applied = (actual_selection == requested_selection)
        )

        selection_applied
        -- return
    ),


    /*
    Displays STRAIGHT EDGE FIXER at Edge sub-object level and verifies the Modify-panel state.
    Show Cage stays disabled on the dedicated modifier according to the project-wide cage-off rule.
    */
    function activateEdgeSelectionDisplay node adapter =
    (
        display_activated = false
        geometry_source = adapter[2]

        if ((node != undefined) and (isValidNode node)) then
        (
            try
            (
                select node
                max modify mode

                if (adapter[1] == #edit_poly) then
                (
                    ensureEditPolyPrimaryNode node geometry_source
                    geometry_source.useStackSelection = false
                    geometry_source.showCage = off
                    modPanel.setCurrentObject geometry_source
                    EditPolyMod.SetEPolySelLevel geometry_source #Edge
                )
                else if (adapter[1] == #editable_poly) then
                (
                    geometry_source.showCage = off
                    modPanel.setCurrentObject geometry_source
                )

                subObjectLevel = 2
                current_object = modPanel.getCurrentObject()
                display_activated = ((current_object == geometry_source) and (subObjectLevel == 2))

                if (adapter[1] == #edit_poly) then
                (
                    display_activated = display_activated and
                        ((EditPolyMod.GetEPolySelLevel geometry_source) == #Edge) and
                        (geometry_source.useStackSelection == false)
                )
            )
            catch
            (
                display_activated = false
            )
        )

        display_activated
        -- return
    ),

    /*
    Writes one checker edge selection into STRAIGHT EDGE FIXER and leaves it visibly active.
    Final read-back happens after Modify-panel activation at Edge sub-object level.
    */
    function setCheckerEdgeSelection node adapter edge_selection =
    (
        geometry_source = if ((adapter != undefined) and (adapter.count >= 2)) then adapter[2] else undefined
        requested_selection = if edge_selection != undefined then edge_selection else #{}
        set_selection_readback = #{}
        actual_selection = #{}
        display_activated = false

        if ((adapter != undefined) and (adapter.count >= 2) and (adapter[1] == #edit_poly) and (geometry_source != undefined)) then
        (
            display_activated = activateEdgeSelectionDisplay node adapter
            ensureEditPolyPrimaryNode node geometry_source
            geometry_source.useStackSelection = false
            geometry_source.showCage = off

            if ((EditPolyMod.GetEPolySelLevel geometry_source) != #Edge) then
            (
                EditPolyMod.SetEPolySelLevel geometry_source #Edge
            )

            try
            (
                EditPolyMod.SetSelection geometry_source #Edge requested_selection node:node
                set_selection_readback = EditPolyMod.GetSelection geometry_source #Edge node:node
            )
            catch
            (
                set_selection_readback = #{}
            )

            if set_selection_readback == undefined then set_selection_readback = #{}

            if set_selection_readback != requested_selection then
            (
                empty_selection = #{}

                try
                (
                    EditPolyMod.SetSelection geometry_source #Edge empty_selection node:node
                    EditPolyMod.Select geometry_source #Edge requested_selection invert:false select:true node:node
                    set_selection_readback = EditPolyMod.GetSelection geometry_source #Edge node:node
                )
                catch
                (
                    set_selection_readback = #{}
                )

                if set_selection_readback == undefined then set_selection_readback = #{}
            )

            update node
            display_activated = activateEdgeSelectionDisplay node adapter
            completeRedraw()

            try
            (
                actual_selection = EditPolyMod.GetSelection geometry_source #Edge node:node
            )
            catch
            (
                actual_selection = #{}
            )

            if actual_selection == undefined then actual_selection = #{}
        )
        else if ((adapter != undefined) and (adapter.count >= 2) and (adapter[1] == #editable_poly) and (geometry_source != undefined)) then
        (
            display_activated = activateEdgeSelectionDisplay node adapter

            try
            (
                polyop.setEdgeSelection geometry_source requested_selection
                set_selection_readback = polyop.getEdgeSelection geometry_source
                completeRedraw()
                actual_selection = polyop.getEdgeSelection geometry_source
            )
            catch
            (
                set_selection_readback = #{}
                actual_selection = #{}
            )

            if set_selection_readback == undefined then set_selection_readback = #{}
            if actual_selection == undefined then actual_selection = #{}
        )

        #((actual_selection == requested_selection), set_selection_readback, actual_selection, display_activated)
        -- return
    ),


    /*
    Prints detailed checker state only when selection storage or visible modifier activation fails.
    Normal successful checks keep concise per-object and summary output.
    */
    function printDirectionCheckerDebug node adapter edge_count candidate_edges requested_edges set_selection_readback actual_selection =
    (
        current_object = undefined
        geometry_source = adapter[2]
        use_stack_selection = undefined

        try
        (
            current_object = modPanel.getCurrentObject()
        )
        catch
        (
        )

        if (adapter[1] == #edit_poly) then
        (
            use_stack_selection = geometry_source.useStackSelection
        )

        format "Check DEBUG object:% adapter:% source:% modifier:% edgeCount:%\n" node.name adapter[1] (classOf geometry_source) geometry_source edge_count
        format "Check DEBUG candidate ids:%\n" candidate_edges
        format "Check DEBUG requested ids:%\n" requested_edges
        format "Check DEBUG SetSelection read-back ids:%\n" set_selection_readback
        format "Check DEBUG actual read-back ids:%\n" actual_selection
        format "Check DEBUG current Modify-panel object:% subObjectLevel:% useStackSelection:%\n" current_object subObjectLevel use_stack_selection

        true
        -- return
    ),


    /*
    Returns the current edge selection from Editable Poly or Edit Poly.
    Used by RMB straightening, which works on selected edges only.
    */
    function getEdgeSelection node adapter =
    (
        edge_selection = #{}
        geometry_source = if ((adapter != undefined) and (adapter.count >= 2)) then adapter[2] else undefined

        if ((adapter != undefined) and (adapter.count >= 2) and (adapter[1] == #editable_poly) and (geometry_source != undefined)) then
        (
            try
            (
                edge_selection = polyop.getEdgeSelection geometry_source
            )
            catch
            (
                edge_selection = #{}
            )
        )
        else if ((adapter != undefined) and (adapter.count >= 2) and (adapter[1] == #edit_poly) and (geometry_source != undefined)) then
        (
            try
            (
                edge_selection = EditPolyMod.GetSelection geometry_source #Edge node:node
            )
            catch
            (
                edge_selection = #{}
            )
        )

        if edge_selection == undefined then edge_selection = #{}

        edge_selection
        -- return
    ),


    /*
    Resolves the existing geometry source for DEBUG edge-angle inspection without creating modifiers.
    Prefer the dedicated STRAIGHT EDGE FIXER, then the top Edit Poly, then Editable Poly.
    */
    function getSelectedEdgeDebugAdapter node =
    (
        adapter = undefined
        fixer_modifier = findNamedEditPoly node "STRAIGHT EDGE FIXER"

        if (fixer_modifier != undefined) then
        (
            adapter = #(#edit_poly, fixer_modifier, false)
        )
        else if ((node.modifiers.count > 0) and (classOf node.modifiers[1] == Edit_Poly)) then
        (
            adapter = #(#edit_poly, node.modifiers[1], false)
        )
        else if (classOf node.baseObject == Editable_Poly) then
        (
            adapter = #(#editable_poly, node.baseObject, false)
        )

        adapter
        -- return
    ),


    /*
    Prints horizontal and vertical deviation angles for selected edges.
    DEBUG inspection never creates or changes an EDGE FIXER modifier.
    */
    function printSelectedEdgeAngles =
    (
        selected_nodes = selection as array
        printed_edge_count = 0

        format "============================================================\n"
        format "ANGLE OF EDGES | objects:%\n" selected_nodes.count
        format "============================================================\n"

        if (selected_nodes.count == 0) then
        (
            format "Angle of Edges: no objects selected.\n"
        )
        else
        (
            for node in selected_nodes do
            (
                if (isValidNode node and (superClassOf node == GeometryClass)) then
                (
                    adapter = getSelectedEdgeDebugAdapter node

                    if (adapter == undefined) then
                    (
                        format "% | unsupported geometry source.\n" node.name
                    )
                    else
                    (
                        selected_edges = getEdgeSelection node adapter
                        source_name =
                            if ((adapter[1] == #edit_poly) and (adapter[2] != undefined)) then
                                adapter[2].name
                            else if adapter[1] == #editable_poly then
                                "Editable Poly"
                            else
                                "<unavailable>"

                        format "% | source:% | ids:%\n" node.name source_name selected_edges

                        if (selected_edges.numberSet == 0) then
                        (
                            format "  No selected edges.\n"
                        )
                        else
                        (
                            for edge_id in selected_edges do
                            (
                                edge_verts = getEdgeVertIds node adapter edge_id
                                direction_angles = getEdgeDirectionAngles node adapter edge_id

                                if ((edge_verts.count == 2) and
                                    (direction_angles[1] != undefined) and
                                    (direction_angles[2] != undefined)) then
                                (
                                    format "  E% | V%-V% | horizontal:% deg | vertical:% deg\n"                                         edge_id edge_verts[1] edge_verts[2] direction_angles[1] direction_angles[2]
                                    printed_edge_count += 1
                                )
                                else
                                (
                                    format "  E% | angle unavailable.\n" edge_id
                                )
                            )
                        )
                    )
                )
            )
        )

        format "Angle of Edges: printed % edge(s).\n" printed_edge_count

        printed_edge_count
        -- return
    ),


    /*
    Tests DEBUG horizontal/vertical angle math with a 3-4-5 direction vector.
    */
    function testEdgeAngleDebugMath =
    (
        direction_angles = getDirectionAngles 4.0 3.0

        (
            ((abs (direction_angles[1] - 36.8699)) < 0.001) and
            ((abs (direction_angles[2] - 53.1301)) < 0.001) and
            ((abs ((direction_angles[1] + direction_angles[2]) - 90.0)) < 0.001)
        )
        -- return
    ),

    /*
    Tests dedicated EDGE FIXER selection persistence and visible Modify-panel activation.
    The legacy function name is retained for compatibility with existing regression calls.
    */
    function testDirectionSelectionDisplayActivation =
    (
        test_passed = true
        test_node = undefined
        original_selection = selection as array
        original_panel_mode = getCommandPanelTaskMode()
        original_current_object = undefined
        original_subobject_level = subObjectLevel

        try
        (
            original_current_object = modPanel.getCurrentObject()
        )
        catch
        (
        )

        try
        (
            test_node = box length:10.0 width:10.0 height:10.0
            convertToPoly test_node
            test_node.baseObject.showCage = off
            select test_node
            adapter = getGeometryAdapter test_node

            setCommandPanelTaskMode mode:#modify
            modPanel.setCurrentObject (adapter[2])
            subObjectLevel = 2

            requested_edges = #{1}
            selection_result = setCheckerEdgeSelection test_node adapter requested_edges
            actual_edges = getEdgeSelection test_node adapter
            panel_mode_after = getCommandPanelTaskMode()

            test_passed = test_passed and selection_result[1]
            test_passed = test_passed and (selection_result[2] == requested_edges)
            test_passed = test_passed and (actual_edges == requested_edges)
            test_passed = test_passed and selection_result[4]
            test_passed = test_passed and (panel_mode_after == #modify)
            test_passed = test_passed and (modPanel.getCurrentObject() == (adapter[2]))
            test_passed = test_passed and (subObjectLevel == 2)
            test_passed = test_passed and ((adapter[2]).useStackSelection == false)
            test_passed = test_passed and ((adapter[2]).showCage == off)
        )
        catch
        (
            test_passed = false
        )

        if ((test_node != undefined) and (isValidNode test_node)) then
        (
            delete test_node
        )

        if original_selection.count > 0 then
        (
            select original_selection
        )
        else
        (
            clearSelection()
        )

        try
        (
            setCommandPanelTaskMode mode:original_panel_mode

            if ((original_panel_mode == #modify) and (original_current_object != undefined)) then
            (
                modPanel.setCurrentObject original_current_object
                subObjectLevel = original_subobject_level
            )
        )
        catch
        (
        )

        test_passed
        -- return
    ),


    /*
    Returns the current vertex selection from Editable Poly or Edit Poly.
    */
    function getVertexSelection node adapter =
    (
        vertex_selection = #{}
        geometry_source = if ((adapter != undefined) and (adapter.count >= 2)) then adapter[2] else undefined

        if ((adapter != undefined) and (adapter.count >= 2) and (adapter[1] == #editable_poly) and (geometry_source != undefined)) then
        (
            try
            (
                vertex_selection = polyop.getVertSelection geometry_source
            )
            catch
            (
                vertex_selection = #{}
            )
        )
        else if ((adapter != undefined) and (adapter.count >= 2) and (adapter[1] == #edit_poly) and (geometry_source != undefined)) then
        (
            try
            (
                vertex_selection = EditPolyMod.GetSelection geometry_source #Vertex node:node
            )
            catch
            (
                vertex_selection = #{}
            )
        )

        if vertex_selection == undefined then vertex_selection = #{}

        vertex_selection
        -- return
    ),

    /*
    Returns all edges incident to one vertex.
    */
    function getVertexIncidentEdges node adapter vertex_id =
    (
        incident_edges = #{}
        geometry_source = adapter[2]

        if (adapter[1] == #editable_poly) then
        (
            incident_edges = polyop.getEdgesUsingVert geometry_source #{vertex_id}
        )
        else if (adapter[1] == #edit_poly) then
        (
            edge_count = EditPolyMod.GetVertexEdgeCount geometry_source vertex_id node:node

            for edge_slot = 1 to edge_count do
            (
                edge_id = EditPolyMod.GetVertexEdge geometry_source vertex_id edge_slot node:node
                if (edge_id != undefined and edge_id > 0) then incident_edges[edge_id] = true
            )
        )

        incident_edges
        -- return
    ),

    /*
    Sets vertex selection on Editable Poly or Edit Poly.
    Used to expose vertices from edges which cannot be straightened.
    */
    function setVertexSelection node adapter vertex_selection =
    (
        geometry_source = adapter[2]

        if (adapter[1] == #editable_poly) then
        (
            polyop.setVertSelection geometry_source vertex_selection
        )
        else if (adapter[1] == #edit_poly) then
        (
            EditPolyMod.SetEPolySelLevel geometry_source #Vertex
            EditPolyMod.SetSelection geometry_source #Vertex vertex_selection node:node
        )

        true
        -- return
    ),

    /*
    Returns the world-space center of one edge.
    Undefined is returned when the edge does not contain two valid vertices.
    */
    function getEdgeCenterWorld node adapter edge_id =
    (
        center_position = undefined
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]
            center_position = (point_a + point_b) * 0.5
        )

        center_position
        -- return
    ),

    /*
    Returns a normalized world-space edge direction.
    Undefined is returned for a zero-length edge.
    */
    function getEdgeDirectionWorld node adapter edge_id =
    (
        direction_value = undefined
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]
            edge_vector = point_b - point_a

            if ((length edge_vector) > 0.0000001) then
            (
                direction_value = normalize edge_vector
            )
        )

        direction_value
        -- return
    ),

    /*
    Returns face IDs using one edge on the current geometry source.
    Editable Poly reads the base object; Edit Poly reads the evaluated node.
    */
    function getEdgeFaceIds node adapter edge_id =
    (
        face_ids = #{}

        try
        (
            if (adapter[1] == #editable_poly) then
            (
                face_ids = polyop.getFacesUsingEdge (adapter[2]) edge_id
            )
            else if (adapter[1] == #edit_poly) then
            (
                face_ids = polyop.getFacesUsingEdge node edge_id
            )
        )
        catch
        (
            face_ids = #{}
        )

        face_ids
        -- return
    ),


    /*
    Returns ordered vertex IDs for one face on the current geometry source.
    Unavailable topology returns an empty array.
    */
    function getFaceVertIds node adapter face_id =
    (
        face_verts = #()

        try
        (
            if (adapter[1] == #editable_poly) then
            (
                face_verts = polyop.getFaceVerts (adapter[2]) face_id
            )
            else if (adapter[1] == #edit_poly) then
            (
                face_verts = polyop.getFaceVerts node face_id
            )
        )
        catch
        (
            face_verts = #()
        )

        face_verts
        -- return
    ),


    /*
    Builds one face normal directly from world-space face vertices.
    World-space construction preserves rotated wall orientation.
    */
    function getFaceNormalWorld node adapter face_id =
    (
        normal_value = undefined
        face_verts = getFaceVertIds node adapter face_id

        if (face_verts.count >= 3) then
        (
            point_a = getVertexWorldPosition node adapter face_verts[1]

            for vert_index = 2 to (face_verts.count - 1) while (normal_value == undefined) do
            (
                point_b = getVertexWorldPosition node adapter face_verts[vert_index]
                point_c = getVertexWorldPosition node adapter face_verts[vert_index + 1]
                candidate_normal = cross (point_b - point_a) (point_c - point_a)

                if ((length candidate_normal) > 0.0000001) then
                (
                    normal_value = normalize candidate_normal
                )
            )
        )

        normal_value
        -- return
    ),


    /*
    Returns a horizontal tangent perpendicular to one face normal.
    The sign follows the current edge direction to preserve vertex order.
    */
    function getHorizontalDirectionFromFaceNormal face_normal current_direction =
    (
        tangent_direction = undefined

        if ((face_normal != undefined) and (current_direction != undefined)) then
        (
            horizontal_normal = [face_normal.x, face_normal.y, 0.0]

            if ((length horizontal_normal) > 0.0000001) then
            (
                horizontal_normal = normalize horizontal_normal
                tangent_direction = normalize (cross horizontal_normal [0,0,1])

                if ((dot tangent_direction current_direction) < 0.0) then
                (
                    tangent_direction = -tangent_direction
                )
            )
        )

        tangent_direction
        -- return
    ),


    /*
    Finds the adjacent wall-face tangent best aligned with the selected edge.
    If no usable wall face exists, the current XY edge direction is retained.
    */
    function getHorizontalWallDirection node adapter edge_id =
    (
        result_direction = undefined
        edge_direction = getEdgeDirectionWorld node adapter edge_id

        if (edge_direction != undefined) then
        (
            current_xy = [edge_direction.x, edge_direction.y, 0.0]

            if ((length current_xy) > 0.0000001) then
            (
                current_xy = normalize current_xy
                best_alignment = -1.0
                edge_faces = getEdgeFaceIds node adapter edge_id

                for face_id in edge_faces do
                (
                    face_normal = getFaceNormalWorld node adapter face_id
                    tangent_direction = getHorizontalDirectionFromFaceNormal face_normal current_xy

                    if (tangent_direction != undefined) then
                    (
                        alignment = abs (dot tangent_direction current_xy)

                        if (alignment > best_alignment) then
                        (
                            best_alignment = alignment
                            result_direction = tangent_direction
                        )
                    )
                )

                if (result_direction == undefined) then
                (
                    result_direction = current_xy
                )
            )
        )

        result_direction
        -- return
    ),


    /*
    Verifies rotated-wall horizontal tangent construction without scene geometry.
    The tangent must be horizontal and perpendicular to the wall face normal.
    */
    function testHorizontalFaceDirection =
    (
        face_normal = normalize [0.6, 0.8, 0.0]
        current_direction = normalize [0.8, -0.6, 0.0]
        tangent_direction = getHorizontalDirectionFromFaceNormal face_normal current_direction

        test_passed = (
            (tangent_direction != undefined) and
            ((abs tangent_direction.z) < 0.000001) and
            ((abs (dot tangent_direction face_normal)) < 0.000001) and
            ((dot tangent_direction current_direction) > 0.9999)
        )

        test_passed
        -- return
    ),


    /*
    Returns the unsigned parallel angle between two edges in degrees.
    Opposite directions are treated as the same baseline direction.
    */
    function getParallelAngle node adapter edge_a edge_b =
    (
        angle_value = 180.0
        direction_a = getEdgeDirectionWorld node adapter edge_a
        direction_b = getEdgeDirectionWorld node adapter edge_b

        if ((direction_a != undefined) and (direction_b != undefined)) then
        (
            dot_value = abs (dot direction_a direction_b)
            dot_value = amax 0.0 (amin 1.0 dot_value)
            angle_value = acos dot_value
        )

        angle_value
        -- return
    ),

    /*
    Returns a common vertex ID shared by two edges.
    Zero means the edges are not direct neighbors.
    */
    function getSharedVertexId node adapter edge_a edge_b =
    (
        shared_vertex = 0
        edge_a_verts = getEdgeVertIds node adapter edge_a
        edge_b_verts = getEdgeVertIds node adapter edge_b

        if ((edge_a_verts.count == 2) and (edge_b_verts.count == 2)) then
        (
            if ((edge_a_verts[1] == edge_b_verts[1]) or (edge_a_verts[1] == edge_b_verts[2])) then
            (
                shared_vertex = edge_a_verts[1]
            )
            else if ((edge_a_verts[2] == edge_b_verts[1]) or (edge_a_verts[2] == edge_b_verts[2])) then
            (
                shared_vertex = edge_a_verts[2]
            )
        )

        shared_vertex
        -- return
    ),

    /*
    Returns true when an edge is already a valid straight reference for the requested mode.
    Only visible edges can become references.
    */
    function isStraightReferenceEdge node adapter edge_id check_type tolerance =
    (
        result_value = false

        if (isEdgeVisible node adapter edge_id) then
        (
            if (check_type == #horizontal) then
            (
                result_value = isHorizontalEdge node adapter edge_id tolerance
            )
            else if (check_type == #vertical) then
            (
                result_value = isVerticalEdge node adapter edge_id tolerance
            )
        )

        result_value
        -- return
    ),

    /*
    Finds the best visible straight edge directly neighboring the bad edge.
    Candidate reference direction must be within Angle of the selected bad edge.
    Returns #(reference_edge_id, shared_vertex_id, #neighbor) or undefined.
    */
    function findNeighborReference node adapter target_edge check_type tolerance angle_threshold =
    (
        best_reference = undefined
        best_angle = 1.0e30
        edge_count = getEdgeCount node adapter

        for reference_edge = 1 to edge_count do
        (
            if ((reference_edge != target_edge) and (isStraightReferenceEdge node adapter reference_edge check_type tolerance)) then
            (
                shared_vertex = getSharedVertexId node adapter target_edge reference_edge

                if (shared_vertex > 0) then
                (
                    parallel_angle = getParallelAngle node adapter target_edge reference_edge

                    if ((parallel_angle <= angle_threshold) and (parallel_angle < best_angle)) then
                    (
                        best_angle = parallel_angle
                        best_reference = #(reference_edge, shared_vertex, #neighbor)
                    )
                )
            )
        )

        best_reference
        -- return
    ),

    /*
    Finds the nearest visible straight reference whose direction is within Angle.
    No Z-position cutoff is used; horizontal and vertical fallback use the same angle rule.
    */
    function findAngleReference node adapter target_edge check_type tolerance angle_threshold =
    (
        best_reference = undefined
        best_distance = 1.0e30
        target_center = getEdgeCenterWorld node adapter target_edge
        edge_count = getEdgeCount node adapter

        if (target_center != undefined) then
        (
            for reference_edge = 1 to edge_count do
            (
                if ((reference_edge != target_edge) and (isStraightReferenceEdge node adapter reference_edge check_type tolerance)) then
                (
                    reference_center = getEdgeCenterWorld node adapter reference_edge
                    parallel_angle = getParallelAngle node adapter target_edge reference_edge

                    if ((reference_center != undefined) and (parallel_angle <= angle_threshold)) then
                    (
                        spatial_distance = distance target_center reference_center

                        if (spatial_distance < best_distance) then
                        (
                            best_distance = spatial_distance
                            best_reference = #(reference_edge, 0, #angle)
                        )
                    )
                )
            )
        )

        best_reference
        -- return
    ),


    /*
    Moves one vertex to an exact world-space position.
    Supports Editable Poly and Edit Poly without converting the object.
    */
    function setVertexWorldPosition node adapter vert_id target_world_position =
    (
        result_value = false

        try
        (
            if (adapter[1] == #editable_poly) then
            (
                inverse_tm = inverse node.objectTransform
                target_local_position = target_world_position * inverse_tm
                polyop.setVert (adapter[2]) vert_id target_local_position
                update node
                result_value = true
            )
            else if (adapter[1] == #edit_poly) then
            (
                current_world_position = getVertexWorldPosition node adapter vert_id
                move_delta = target_world_position - current_world_position

                if ((length move_delta) > 0.0000001) then
                (
                    one_vertex = #{}
                    one_vertex[vert_id] = true

                    EditPolyMod.SetEPolySelLevel (adapter[2]) #Vertex
                    EditPolyMod.SetSelection (adapter[2]) #Vertex one_vertex node:node
                    EditPolyMod.MoveSelection (adapter[2]) move_delta
                    EditPolyMod.Commit (adapter[2])
                )

                update node
                result_value = true
            )
        )
        catch
        (
            result_value = false
        )

        result_value
        -- return
    ),

    /*
    Tests Vertical Vertex-mode endpoint alignment.
    The selected vertex takes unselected XY and preserves its own Z.
    */
    function testVerticalSelectedVertexTarget =
    (
        selected_position = [10.0, 20.0, 3.0]
        unselected_position = [30.0, 40.0, 9.0]
        target_position = [unselected_position.x, unselected_position.y, selected_position.z]

        target_position == [30.0, 40.0, 3.0]
        -- return
    ),


    /*
    Tests axis-specific alignment targets.
    Horizontal changes only Z; Vertical changes only XY.
    */
    function testDirectionAlignmentTargets =
    (
        point_a = [10.0, 20.0, 3.0]
        point_b = [14.0, 26.0, 9.0]
        horizontal_reference = [100.0, 200.0, 7.0]
        vertical_reference = [30.0, 40.0, 500.0]

        horizontal_a = [point_a.x, point_a.y, horizontal_reference.z]
        horizontal_b = [point_b.x, point_b.y, horizontal_reference.z]
        vertical_a = [vertical_reference.x, vertical_reference.y, point_a.z]
        vertical_b = [vertical_reference.x, vertical_reference.y, point_b.z]

        test_passed = true
        test_passed = test_passed and horizontal_a.x == point_a.x and horizontal_a.y == point_a.y
        test_passed = test_passed and horizontal_b.x == point_b.x and horizontal_b.y == point_b.y
        test_passed = test_passed and horizontal_a.z == horizontal_reference.z and horizontal_b.z == horizontal_reference.z
        test_passed = test_passed and vertical_a.x == vertical_reference.x and vertical_a.y == vertical_reference.y
        test_passed = test_passed and vertical_b.x == vertical_reference.x and vertical_b.y == vertical_reference.y
        test_passed = test_passed and vertical_a.z == point_a.z and vertical_b.z == point_b.z

        test_passed
        -- return
    ),


    /*
    Fixes one selected edge using the requested alignment axis.
    Horizontal changes Z only and prefers a neighboring horizontal edge Z.
    Vertical changes XY only and prefers a neighboring vertical edge XY.
    */
    function fixSelectedDirectionEdge node adapter edge_id check_type tolerance:0.01 angle_threshold:45.0 =
    (
        result_value = false
        edge_verts = getEdgeVertIds node adapter edge_id

        if (edge_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter edge_verts[1]
            point_b = getVertexWorldPosition node adapter edge_verts[2]
            target_a = point_a
            target_b = point_b
            neighbor_reference = findNeighborReference node adapter edge_id check_type tolerance angle_threshold
            can_fix = false

            if (check_type == #horizontal) then
            (
                target_z = (point_a.z + point_b.z) * 0.5

                if (neighbor_reference != undefined) then
                (
                    shared_vertex = neighbor_reference[2]
                    if (shared_vertex > 0) then
                    (
                        reference_position = getVertexWorldPosition node adapter shared_vertex
                        if (reference_position != undefined) then target_z = reference_position.z
                    )
                )

                target_a = [point_a.x, point_a.y, target_z]
                target_b = [point_b.x, point_b.y, target_z]
                can_fix = true
            )
            else if (check_type == #vertical) then
            (
                target_x = (point_a.x + point_b.x) * 0.5
                target_y = (point_a.y + point_b.y) * 0.5

                if (neighbor_reference != undefined) then
                (
                    shared_vertex = neighbor_reference[2]
                    if (shared_vertex > 0) then
                    (
                        reference_position = getVertexWorldPosition node adapter shared_vertex
                        if (reference_position != undefined) then
                        (
                            target_x = reference_position.x
                            target_y = reference_position.y
                        )
                    )
                )

                target_a = [target_x, target_y, point_a.z]
                target_b = [target_x, target_y, point_b.z]
                can_fix = true
            )

            if (can_fix) then
            (
                moved_a = setVertexWorldPosition node adapter edge_verts[1] target_a
                moved_b = setVertexWorldPosition node adapter edge_verts[2] target_b

                if (moved_a and moved_b) then
                (
                    if (check_type == #horizontal) then
                    (
                        result_value = isHorizontalEdge node adapter edge_id tolerance
                    )
                    else if (check_type == #vertical) then
                    (
                        result_value = isVerticalEdge node adapter edge_id tolerance
                    )
                )
            )
        )

        result_value
        -- return
    ),


    /*
    Chooses the best Vertical Vertex-mode reference candidate.
    Visible exact-vertical edges win; otherwise the smallest vertical angle inside Angle wins.
    */
    function chooseVerticalVertexReferenceCandidate candidate_records angle_threshold =
    (
        exact_candidate = undefined
        fallback_candidate = undefined
        fallback_angle = 1.0e30

        for candidate_record in candidate_records do
        (
            if (candidate_record.count >= 5 and candidate_record[3]) then
            (
                if candidate_record[4] then
                (
                    if exact_candidate == undefined then exact_candidate = candidate_record
                )
                else if (candidate_record[5] != undefined and candidate_record[5] <= angle_threshold and candidate_record[5] < fallback_angle) then
                (
                    fallback_angle = candidate_record[5]
                    fallback_candidate = candidate_record
                )
            )
        )

        if exact_candidate != undefined then exact_candidate else fallback_candidate
        -- return
    ),


    /*
    Finds the visible incident edge used to realign one selected vertex vertically.
    If no exact vertical edge exists, the most vertical visible edge inside Angle is used.
    */
    function findSelectedVertexVerticalReference node adapter selected_vertex selected_vertices tolerance angle_threshold =
    (
        candidate_records = #()
        incident_edges = getVertexIncidentEdges node adapter selected_vertex
        selected_position = getVertexWorldPosition node adapter selected_vertex

        if selected_position != undefined then
        (
            for edge_id in incident_edges do
            (
                edge_verts = getEdgeVertIds node adapter edge_id

                if (edge_verts.count == 2) then
                (
                    other_vertex = if (edge_verts[1] == selected_vertex) then edge_verts[2] else edge_verts[1]
                    other_is_selected = (other_vertex <= selected_vertices.count and selected_vertices[other_vertex])

                    if not other_is_selected then
                    (
                        other_position = getVertexWorldPosition node adapter other_vertex

                        if other_position != undefined then
                        (
                            edge_visible = isEdgeVisible node adapter edge_id
                            horizontal_length = distance [selected_position.x, selected_position.y, 0.0] [other_position.x, other_position.y, 0.0]
                            vertical_length = abs(selected_position.z - other_position.z)
                            direction_angles = getDirectionAngles horizontal_length vertical_length
                            vertical_angle = if direction_angles != undefined then direction_angles[2] else undefined
                            edge_is_vertical = ((vertical_angle != undefined) and (isVerticalEdge node adapter edge_id tolerance))

                            append candidate_records #(edge_id, other_vertex, edge_visible, edge_is_vertical, vertical_angle)
                        )
                    )
                )
            )
        )

        chooseVerticalVertexReferenceCandidate candidate_records angle_threshold
        -- return
    ),


    /*
    Tests Vertical Vertex-mode reference priority and skewed fallback selection.
    Invisible exact edges are ignored and the most vertical visible skewed edge wins inside Angle.
    */
    function testVerticalVertexReferenceFallback =
    (
        test_passed = true
        candidate_records = #(
            #(11, 101, true, false, 12.0),
            #(12, 102, false, true, 0.0),
            #(13, 103, true, false, 4.0),
            #(14, 104, true, false, 8.0)
        )

        fallback_result = chooseVerticalVertexReferenceCandidate candidate_records 10.0
        test_passed = test_passed and fallback_result != undefined and fallback_result[1] == 13 and fallback_result[2] == 103

        append candidate_records #(15, 105, true, true, 0.0)
        exact_result = chooseVerticalVertexReferenceCandidate candidate_records 10.0
        test_passed = test_passed and exact_result != undefined and exact_result[1] == 15 and exact_result[2] == 105

        no_fallback_records = #(
            #(21, 201, true, false, 12.0),
            #(22, 202, false, true, 0.0)
        )
        no_fallback_result = chooseVerticalVertexReferenceCandidate no_fallback_records 10.0
        test_passed = test_passed and no_fallback_result == undefined

        test_passed
        -- return
    ),


    /*
    Aligns selected vertices vertically to the opposite endpoint of the best visible incident edge.
    Exact vertical edges have priority; otherwise the most vertical visible edge inside Angle is used.
    */
    function fixSelectedVerticalVertices node adapter selected_vertices tolerance:0.01 angle_threshold:45.0 =
    (
        fixed_count = 0
        failed_vertices = #{}

        for selected_vertex in selected_vertices do
        (
            vertex_fixed = false
            reference_data = findSelectedVertexVerticalReference node adapter selected_vertex selected_vertices tolerance angle_threshold

            if reference_data != undefined then
            (
                other_vertex = reference_data[2]
                selected_position = getVertexWorldPosition node adapter selected_vertex
                other_position = getVertexWorldPosition node adapter other_vertex

                if (selected_position != undefined and other_position != undefined) then
                (
                    target_position = [other_position.x, other_position.y, selected_position.z]

                    if (setVertexWorldPosition node adapter selected_vertex target_position) then
                    (
                        vertex_fixed = true
                        fixed_count += 1
                    )
                )
            )

            if not vertex_fixed then failed_vertices[selected_vertex] = true
        )

        #(fixed_count, failed_vertices)
        -- return
    ),


    /*
    Fixes every currently selected edge for the requested direction.
    In Vertex sub-object mode, Vertical moves selected vertices to the unselected endpoint XY.
    */
    function fixSelectedDirectionEdges check_type tolerance:0.01 angle_threshold:45.0 =
    (
        selected_nodes = selection as array
        object_results = #()
        total_fixed_edges = 0
        has_failed_edges = false
        failure_report = ""
        use_vertex_vertical_mode = (check_type == #vertical and subObjectLevel == 1)

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            undo "Fix Selected Direction Edges" on
            (
                for node in selected_nodes do
                (
                    if (isValidNode node and (superClassOf node == GeometryClass)) then
                    (
                        adapter = getGeometryAdapter node
                        original_edge_selection = getEdgeSelection node adapter
                        failed_vertices = #{}

                        if use_vertex_vertical_mode then
                        (
                            original_vertex_selection = getVertexSelection node adapter
                            vertex_result = fixSelectedVerticalVertices                                 node                                 adapter                                 original_vertex_selection                                 tolerance:tolerance                                 angle_threshold:angle_threshold

                            total_fixed_edges += vertex_result[1]
                            failed_vertices = vertex_result[2]
                        )
                        else
                        (
                            for edge_id in original_edge_selection do
                            (
                                if (fixSelectedDirectionEdge node adapter edge_id check_type tolerance:tolerance angle_threshold:angle_threshold) then
                                (
                                    total_fixed_edges += 1
                                )
                                else
                                (
                                    failed_edge_verts = getEdgeVertIds node adapter edge_id

                                    if (failed_edge_verts.count == 2) then
                                    (
                                        failed_vertices[failed_edge_verts[1]] = true
                                        failed_vertices[failed_edge_verts[2]] = true
                                    )
                                )
                            )
                        )

                        if (failed_vertices.numberSet > 0) then
                        (
                            has_failed_edges = true
                            failure_report += node.name + ": " + (bitIdsToString failed_vertices) + "\n"
                        )

                        append object_results #(node, adapter, original_edge_selection, failed_vertices)
                    )
                )
            )

            if (has_failed_edges) then
            (
                for object_result in object_results do
                (
                    setVertexSelection object_result[1] object_result[2] object_result[4]
                )

                ensureCreatePanelMode()
                completeRedraw()

                messageBox ("Unable to fix selected edges with vertices:\n\n" + failure_report) title:"Straight Edge Fixer"
            )
            else
            (
                for object_result in object_results do
                (
                    setEdgeSelection object_result[1] object_result[2] object_result[3]
                )

                ensureCreatePanelMode()
                completeRedraw()

                format "Straight Edge Fixer: fixed % selected % edge(s). Create panel kept active.\n" total_fixed_edges check_type
            )
        )

        #(total_fixed_edges, has_failed_edges)
        -- return
    ),


    /*
    Straightens one selected edge using only the coordinate controlled by the requested direction.
    Horizontal uses reference Z while preserving target XY.
    Vertical uses reference XY while preserving target Z.
    */
    function straightenEdgeUsingReference node adapter target_edge reference_data check_type tolerance =
    (
        result_value = false
        target_verts = getEdgeVertIds node adapter target_edge
        reference_edge = reference_data[1]
        shared_vertex = reference_data[2]
        reference_method = reference_data[3]

        if (target_verts.count == 2) then
        (
            point_a = getVertexWorldPosition node adapter target_verts[1]
            point_b = getVertexWorldPosition node adapter target_verts[2]
            reference_position = undefined

            if ((reference_method == #neighbor) and (shared_vertex > 0)) then
            (
                reference_position = getVertexWorldPosition node adapter shared_vertex
            )
            else if (reference_method == #level) then
            (
                reference_position = getEdgeCenterWorld node adapter reference_edge
            )

            if (reference_position != undefined) then
            (
                if (check_type == #horizontal) then
                (
                    target_a = [point_a.x, point_a.y, reference_position.z]
                    target_b = [point_b.x, point_b.y, reference_position.z]
                )
                else if (check_type == #vertical) then
                (
                    target_a = [reference_position.x, reference_position.y, point_a.z]
                    target_b = [reference_position.x, reference_position.y, point_b.z]
                )

                moved_a = setVertexWorldPosition node adapter target_verts[1] target_a
                moved_b = setVertexWorldPosition node adapter target_verts[2] target_b
                result_value = moved_a and moved_b
            )
        )

        if (result_value) then
        (
            if (check_type == #horizontal) then
            (
                result_value = isHorizontalEdge node adapter target_edge tolerance
            )
            else if (check_type == #vertical) then
            (
                result_value = isVerticalEdge node adapter target_edge tolerance
            )
        )

        result_value
        -- return
    ),

    /*
    Converts a BitArray of IDs to comma-separated text.
    Used in the failed-vertex diagnostic message.
    */
    function bitIdsToString bit_set =
    (
        result_text = ""
        first_item = true

        for item_id in bit_set do
        (
            if (not first_item) then
            (
                result_text += ", "
            )

            result_text += (item_id as string)
            first_item = false
        )

        result_text
        -- return
    ),

    /*
    Straightens only the currently selected visible edges for Horizontal or Vertical mode.
    Reference priority is neighboring straight edge, then nearest straight edge on the same level.
    Failed edge vertices are selected automatically for manual correction.
    */
    function straightenSelectedEdges check_type tolerance angle_threshold =
    (
        selected_nodes = selection as array
        object_results = #()
        total_selected_candidates = 0
        total_fixed_edges = 0
        has_failed_edges = false
        failure_report = ""

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            undo "Straighten Selected Edges" on
            (
                for node in selected_nodes do
                (
                    if (isValidNode node and (superClassOf node == GeometryClass)) then
                    (
                        adapter = getGeometryAdapter node
                        original_edge_selection = getEdgeSelection node adapter
                        pending_edges = #{}
                        failed_vertices = #{}

                        for edge_id in original_edge_selection do
                        (
                            if (check_type == #horizontal) then
                            (
                                if (isHorizontalCheckCandidate node adapter edge_id tolerance angle_threshold) then
                                (
                                    pending_edges[edge_id] = true
                                )
                            )
                            else if (check_type == #vertical) then
                            (
                                if (isVerticalCheckCandidate node adapter edge_id tolerance angle_threshold) then
                                (
                                    pending_edges[edge_id] = true
                                )
                            )
                        )

                        total_selected_candidates += countBits pending_edges
                        continue_processing = true

                        /*
                        Multiple passes let a newly fixed edge become the straight neighbor
                        reference for the next selected edge in a chain.
                        */
                        while ((pending_edges.numberSet > 0) and continue_processing) do
                        (
                            continue_processing = false
                            pending_snapshot = copy pending_edges

                            for edge_id in pending_snapshot do
                            (
                                reference_data = findNeighborReference node adapter edge_id check_type tolerance angle_threshold

                                if (reference_data == undefined) then
                                (
                                    reference_data = findAngleReference node adapter edge_id check_type tolerance angle_threshold
                                )

                                if (reference_data != undefined) then
                                (
                                    if (straightenEdgeUsingReference node adapter edge_id reference_data check_type tolerance) then
                                    (
                                        pending_edges[edge_id] = false
                                        total_fixed_edges += 1
                                        continue_processing = true
                                    )
                                )
                            )
                        )

                        for failed_edge in pending_edges do
                        (
                            failed_edge_verts = getEdgeVertIds node adapter failed_edge

                            if (failed_edge_verts.count == 2) then
                            (
                                failed_vertices[failed_edge_verts[1]] = true
                                failed_vertices[failed_edge_verts[2]] = true
                            )
                        )

                        if (failed_vertices.numberSet > 0) then
                        (
                            has_failed_edges = true
                            failure_report += node.name + ": " + (bitIdsToString failed_vertices) + "\n"
                        )

                        append object_results #(node, adapter, original_edge_selection, failed_vertices)
                    )
                )
            )

            /*
            If any heuristic failed, expose only failed vertices for manual repair.
            Otherwise keep the original edge selection visible.
            */
            if (has_failed_edges) then
            (
                for object_result in object_results do
                (
                    setVertexSelection object_result[1] object_result[2] object_result[4]
                )

                ensureCreatePanelMode()
                completeRedraw()

                messageBox ("Unable to straighten edges with vertices:\n\n" + failure_report) title:"Straight Edge Fixer"
            )
            else
            (
                for object_result in object_results do
                (
                    setEdgeSelection object_result[1] object_result[2] object_result[3]
                )

                ensureCreatePanelMode()
                completeRedraw()

                format "Straight Edge Fixer: fixed % selected edge(s). Create panel kept active.\n" total_fixed_edges

                if (total_selected_candidates == 0) then
                (
                    format "Straight Edge Fixer: no selected visible candidate edges matched the requested direction.\n"
                )
            )
        )

        #(total_fixed_edges, has_failed_edges)
        -- return
    ),

    /*
    Selects exact or skewed edges for Horizontal / Vertical direction checks.
    Exact mode uses zero coordinate tolerance; skewed mode uses 0 < deviation <= Angle.
    */
    function checkEdgeDirection check_type tolerance angle_threshold selection_mode:#skewed =
    (
        selected_nodes = selection as array
        total_selected_edges = 0
        processed_count = 0

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            ensureCreatePanelMode()

            for node in selected_nodes do
            (
                if (isValidNode node and (superClassOf node == GeometryClass)) then
                (
                    processed_count += 1
                    adapter = getGeometryAdapter node
                    edge_count = getEdgeCount node adapter
                    matched_edges = #{}

                    if edge_count <= 0 then
                    (
                        format "Check % WARNING: % STRAIGHT EDGE FIXER exposes zero live edges; direction scan skipped.\n" check_type node.name
                    )

                    for edge_id = 1 to edge_count do
                    (
                        edge_matches = false

                        if (selection_mode == #exact) then
                        (
                            edge_type = getEdgeDirectionType node adapter edge_id angle_threshold:angle_threshold

                            if (check_type == #horizontal) then
                            (
                                edge_matches = (edge_type == #horizontal)
                            )
                            else if (check_type == #vertical) then
                            (
                                edge_matches = (edge_type == #vertical)
                            )
                        )
                        else
                        (
                            if (check_type == #horizontal) then
                            (
                                edge_matches = isHorizontalCheckCandidate node adapter edge_id tolerance angle_threshold
                            )
                            else if (check_type == #vertical) then
                            (
                                edge_matches = isVerticalCheckCandidate node adapter edge_id tolerance angle_threshold
                            )
                        )

                        if (edge_matches) then
                        (
                            matched_edges[edge_id] = true
                        )
                    )

                    selection_result = setCheckerEdgeSelection node adapter matched_edges
                    selection_applied = selection_result[1]
                    set_selection_readback = selection_result[2]
                    actual_selection = selection_result[3]
                    display_activated = selection_result[4]
                    actual_count = countBits actual_selection
                    total_selected_edges += actual_count


                    if (selection_mode == #exact) then
                    (
                        format "Check %: % selected % exact zero-deviation edge(s). ids: %\n" check_type node.name actual_count actual_selection
                    )
                    else
                    (
                        format "Check %: % selected % skewed edge(s), deviation >0 and <= % deg. ids: %\n" check_type node.name actual_count angle_threshold actual_selection
                    )

                    if (set_selection_readback != matched_edges) then
                    (
                        format "Check % WARNING: % SetSelection requested ids:% but immediate read-back ids:%\n" check_type node.name matched_edges set_selection_readback
                    )

                    if (not selection_applied) then
                    (
                        format "Check % WARNING: % requested ids:% but final modifier selection ids:%\n" check_type node.name matched_edges actual_selection
                    )

                    if ((not selection_applied) or (not display_activated)) then
                    (
                        printDirectionCheckerDebug node adapter edge_count matched_edges matched_edges set_selection_readback actual_selection
                    )
                )
            )

            if (processed_count > 0) then
            (
                completeRedraw()

                if (selection_mode == #exact) then
                (
                    format "Check %: selected % exact zero-deviation edge(s); STRAIGHT EDGE FIXER active at Edge level.\n" check_type total_selected_edges
                )
                else
                (
                    format "Check %: selected % skewed edge(s), deviation >0 and <= % deg; STRAIGHT EDGE FIXER active at Edge level.\n" check_type total_selected_edges angle_threshold
                )
            )
        )

        total_selected_edges
        -- return
    ),

    /*
    Selects one stable direction category and verifies STRAIGHT EDGE FIXER stores it.
    Returns the final modifier selection, not merely the detected/requested edge BitArray.
    */
    function testDirectionalEdgeSelection mode:#skewed angle_threshold:5.0 exact_epsilon:0.000001 =
    (
        detected_selection = #{}
        actual_selection = #{}

        if selection.count != 1 then
        (
            messageBox "Select exactly one supported geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            test_node = selection[1]

            if ((not isValidNode test_node) or (superClassOf test_node != GeometryClass)) then
            (
                messageBox "Selected object must be supported geometry." title:"Straight Edge Fixer"
            )
            else
            (
                adapter = getGeometryAdapter test_node
                detected_selection = getDirectionalEdgeSelection test_node adapter mode angle_threshold:angle_threshold exact_epsilon:exact_epsilon
                selection_result = setCheckerEdgeSelection test_node adapter detected_selection
                completeRedraw()
                actual_selection = getEdgeSelection test_node adapter

                format "%: detected % edge(s). ids: %\n" mode detected_selection.numberSet detected_selection
                format "%: STRAIGHT EDGE FIXER stored % edge(s). ids: %\n" mode actual_selection.numberSet actual_selection

                if actual_selection != detected_selection then
                (
                    format "% ERROR: modifier selection mismatch. requested:% stored:%\n" mode detected_selection actual_selection
                )
            )
        )

        actual_selection
        -- return
    ),

    /*
    Creates one triangular Editable Poly with a known target edge for checker regression tests.
    The other two triangle edges are deliberately far from the tested direction.
    */
    function createDirectionCheckerTestNode node_name point_a point_b point_c =
    (
        test_node = mesh vertices:#(point_a, point_b, point_c) faces:#([1,2,3])
        test_node.name = node_name
        convertToPoly test_node
        test_node.baseObject.showCage = off

        test_node
        -- return
    ),

    /*
    Finds the edge whose world-space endpoints match the supplied points.
    Endpoint order is ignored.
    */
    function findDirectionCheckerTestEdge node adapter point_a point_b tolerance:0.000001 =
    (
        matched_edge_id = undefined
        edge_count = getEdgeCount node adapter

        for edge_id = 1 to edge_count while (matched_edge_id == undefined) do
        (
            edge_verts = getEdgeVertIds node adapter edge_id

            if (edge_verts.count == 2) then
            (
                edge_point_a = getVertexWorldPosition node adapter edge_verts[1]
                edge_point_b = getVertexWorldPosition node adapter edge_verts[2]
                forward_match = ((distance edge_point_a point_a) <= tolerance) and ((distance edge_point_b point_b) <= tolerance)
                reverse_match = ((distance edge_point_a point_b) <= tolerance) and ((distance edge_point_b point_a) <= tolerance)

                if (forward_match or reverse_match) then
                (
                    matched_edge_id = edge_id
                )
            )
        )

        matched_edge_id
        -- return
    ),

    /*
    Runs one real Edit Poly checker case and verifies the target edge is the only stored selection.
    It also verifies STRAIGHT EDGE FIXER displays the selection in Modify mode and remains unique on the object.
    */
    function runDirectionCheckerRegressionCase node_name check_type selection_mode point_a point_b point_c angle_threshold =
    (
        test_passed = false
        test_node = undefined

        try
        (
            test_node = createDirectionCheckerTestNode node_name point_a point_b point_c
            select test_node
            adapter = getGeometryAdapter test_node
            target_edge_id = findDirectionCheckerTestEdge test_node adapter point_a point_b
            expected_selection = #{}

            if target_edge_id != undefined then
            (
                expected_selection[target_edge_id] = true
                checkEdgeDirection check_type 0.0 angle_threshold selection_mode:selection_mode
                actual_selection = getEdgeSelection test_node adapter
                panel_mode_after = getCommandPanelTaskMode()
                fixer_count = 0

                for modifier_index = 1 to test_node.modifiers.count do
                (
                    modifier_value = test_node.modifiers[modifier_index]

                    if ((classOf modifier_value == Edit_Poly) and ((toUpper modifier_value.name) == "STRAIGHT EDGE FIXER")) then
                    (
                        fixer_count += 1
                    )
                )

                test_passed = (actual_selection == expected_selection) and
                    (panel_mode_after == #modify) and
                    (modPanel.getCurrentObject() == (adapter[2])) and
                    (subObjectLevel == 2) and
                    ((adapter[2]).useStackSelection == false) and
                    ((adapter[2]).showCage == off) and
                    (fixer_count == 1)
            )
        )
        catch
        (
            test_passed = false
        )

        if ((test_node != undefined) and (isValidNode test_node)) then
        (
            delete test_node
        )

        test_passed
        -- return
    ),

    /*
    Verifies one target edge is included by the stable four-mode directional selection.
    The helper uses the same geometry adapter path as production EDGE FIXER checks.
    */
    function runDirectionalSelectionRegressionCase node_name mode point_a point_b point_c angle_threshold =
    (
        test_passed = false
        test_node = undefined

        try
        (
            test_node = createDirectionCheckerTestNode node_name point_a point_b point_c
            adapter = getGeometryAdapter test_node
            target_edge_id = findDirectionCheckerTestEdge test_node adapter point_a point_b

            if target_edge_id != undefined then
            (
                edge_selection = getDirectionalEdgeSelection test_node adapter mode angle_threshold:angle_threshold
                edge_type = getEdgeDirectionType test_node adapter target_edge_id angle_threshold:angle_threshold
                test_passed = edge_selection[target_edge_id] and (edge_type == mode)
            )
        )
        catch
        (
            test_passed = false
        )

        if ((test_node != undefined) and (isValidNode test_node)) then
        (
            delete test_node
        )

        test_passed
        -- return
    ),

    /*
    Tests the stable classifier categories independently of viewport selection state.
    Covers exact horizontal, exact vertical, near-vertical skewed, and general sloped edges.
    */
    function testDirectionalSelectionModes =
    (
        horizontal_ok = runDirectionalSelectionRegressionCase \
            "_WF_DIRECTION_HORIZONTAL" #horizontal \
            [0,0,0] [10,0,0] [5,5,10] 5.0

        vertical_ok = runDirectionalSelectionRegressionCase \
            "_WF_DIRECTION_VERTICAL" #vertical \
            [0,0,0] [0,0,10] [10,10,4] 5.0

        skewed_ok = runDirectionalSelectionRegressionCase \
            "_WF_DIRECTION_SKEWED" #skewed \
            [0,0,0] [0.25,0,7.15] [10,10,3] 5.0

        sloped_ok = runDirectionalSelectionRegressionCase \
            "_WF_DIRECTION_SLOPED" #sloped \
            [0,0,0] [10,0,0.5] [5,5,10] 5.0

        test_passed = horizontal_ok and vertical_ok and skewed_ok and sloped_ok

        format "EDGE FIXER stable direction modes: horizontal:% vertical:% skewed:% sloped:% => %\n" \
            horizontal_ok vertical_ok skewed_ok sloped_ok test_passed

        test_passed
        -- return
    ),

    /*
    Returns whether the standalone Straight Edge Fixer dialog should open for this load context.
    Bundled Wall-Fixer loads stay headless, while directly running Straight-Edge-Fixer.ms still opens the dialog.
    */
    function shouldAutoOpenDialog runtime_mode source_file_name =
    (
        normalized_source_name = ""

        if source_file_name != undefined then
        (
            try
            (
                normalized_source_name = toLower (filenameFromPath source_file_name)
            )
            catch
            (
                normalized_source_name = ""
            )
        )

        (runtime_mode != #bundled) or (normalized_source_name == "straight-edge-fixer.ms")
        -- return
    ),


    /*
    Verifies bundled Wall-Fixer loading stays headless while direct standalone loading still opens the dialog.
    Covers the case where Wall-Fixer was already loaded before the standalone file is run.
    */
    function testAutoOpenDialogPolicy =
    (
        bundled_ok = not (shouldAutoOpenDialog #bundled "C:\\Tools\\Wall-Fixer.ms")
        standalone_ok = shouldAutoOpenDialog undefined "C:\\Tools\\Straight-Edge-Fixer.ms"
        standalone_after_bundle_ok = shouldAutoOpenDialog #bundled "C:\\Tools\\Straight-Edge-Fixer.ms"
        test_passed = bundled_ok and standalone_ok and standalone_after_bundle_ok

        format "Straight Edge Fixer dialog auto-open policy: bundled:% standalone:% standalone-after-bundle:% => %\n" \
            bundled_ok standalone_ok standalone_after_bundle_ok test_passed

        test_passed
        -- return
    ),


    /*
    Verifies undefined component-selection reads are normalized to empty BitArrays.
    Prevents mapped-iteration crashes when an Edit Poly component-selection read is unavailable.
    */
    function testUndefinedSelectionSafety =
    (
        test_passed = true
        empty_count = countBits undefined
        empty_adapter_selection = getEdgeSelection undefined undefined
        empty_vertex_selection = getVertexSelection undefined undefined

        test_passed = test_passed and (empty_count == 0)
        test_passed = test_passed and (empty_adapter_selection == #{})
        test_passed = test_passed and (empty_vertex_selection == #{})

        format "EDGE FIXER undefined selection safety: count:% edges:% verts:% => %\n" \
            empty_count empty_adapter_selection empty_vertex_selection test_passed

        test_passed
        -- return
    ),


    /*
    Regression suite for EDGE FIXER Horizontal/Vertical LMB and RMB checkers.
    Covers exact, skewed, tiny non-zero deviation, visible selection persistence, Modify mode, and modifier uniqueness.
    */
    function testDirectionCheckerRegression =
    (
        original_selection = selection as array
        original_panel_mode = getCommandPanelTaskMode()
        original_current_object = undefined
        original_subobject_level = subObjectLevel

        try
        (
            original_current_object = modPanel.getCurrentObject()
        )
        catch
        (
        )

        exact_vertical_ok = runDirectionCheckerRegressionCase \
            "_WF_CHECK_EXACT_VERTICAL" #vertical #exact \
            [0,0,0] [0,0,10] [10,10,4] 5.0

        skewed_vertical_ok = runDirectionCheckerRegressionCase \
            "_WF_CHECK_SKEW_VERTICAL" #vertical #skewed \
            [0,0,0] [0.25,0,7.15] [10,10,3] 5.0

        tiny_vertical_ok = runDirectionCheckerRegressionCase \
            "_WF_CHECK_TINY_VERTICAL" #vertical #skewed \
            [0,0,0] [0.001,0,7.15] [10,10,3] 0.1

        exact_horizontal_ok = runDirectionCheckerRegressionCase \
            "_WF_CHECK_EXACT_HORIZONTAL" #horizontal #exact \
            [0,0,0] [10,0,0] [5,5,10] 5.0

        skewed_horizontal_ok = runDirectionCheckerRegressionCase \
            "_WF_CHECK_SKEW_HORIZONTAL" #horizontal #skewed \
            [0,0,0] [10,0,0.5] [5,5,10] 5.0

        tiny_angles = getDirectionAngles 0.001 7.15
        tiny_angle_ok = (tiny_angles[2] > 0.0) and
            (tiny_angles[2] < 0.01) and
            (isSkewedDirectionCandidate false tiny_angles[2] 0.1)

        stable_modes_ok = testDirectionalSelectionModes()
        persistence_ok = testDirectionSelectionDisplayActivation()
        single_modifier_ok = testSingleStraightEdgeFixerModifier()
        live_topology_ok = testStraightEdgeFixerLiveTopology()
        undefined_selection_ok = testUndefinedSelectionSafety()
        test_passed = stable_modes_ok and
            exact_vertical_ok and
            skewed_vertical_ok and
            tiny_vertical_ok and
            exact_horizontal_ok and
            skewed_horizontal_ok and
            tiny_angle_ok and
            persistence_ok and
            single_modifier_ok and
            live_topology_ok and
            undefined_selection_ok

        format "EDGE FIXER Checkers regression: stableModes:% exactV:% skewV:% tinyV:% exactH:% skewH:% tinyAngle:% persistence:% singleModifier:% liveTopology:% undefinedSelection:% => %\n" \
            stable_modes_ok exact_vertical_ok skewed_vertical_ok tiny_vertical_ok exact_horizontal_ok skewed_horizontal_ok tiny_angle_ok persistence_ok single_modifier_ok live_topology_ok undefined_selection_ok test_passed

        if original_selection.count > 0 then
        (
            select original_selection
        )
        else
        (
            clearSelection()
        )

        try
        (
            setCommandPanelTaskMode mode:original_panel_mode

            if ((original_panel_mode == #modify) and (original_current_object != undefined)) then
            (
                modPanel.setCurrentObject original_current_object
                subObjectLevel = original_subobject_level
            )
        )
        catch
        (
        )

        test_passed
        -- return
    ),


    /*
    Tests the horizontal row angle rule without scene geometry.
    Zero through Angle qualifies; values above Angle do not.
    */
    function testHorizontalRowAngleThreshold =
    (
        horizontal_zero = getDirectionAngles 1.0 0.0
        horizontal_five = getDirectionAngles 1.0 0.0874886635
        horizontal_over = getDirectionAngles 1.0 0.087507

        test_passed = (
            (horizontal_zero[1] <= 5.0) and
            (horizontal_five[1] <= 5.0) and
            (horizontal_over[1] > 5.0)
        )

        test_passed
        -- return
    ),


    /*
    Reads visible horizontal-direction edge data using the shared Angle threshold.
    Rows distance is not used to classify direction; it is reserved for row clustering.
    */
    function getHorizontalEdgeData node adapter angle_threshold =
    (
        edge_data = #()
        edge_count = getEdgeCount node adapter

        for edge_id = 1 to edge_count do
        (
            if (isEdgeVisible node adapter edge_id) then
            (
                angle_from_horizontal = getEdgeAngleFromHorizontal node adapter edge_id

                if ((angle_from_horizontal != undefined) and (angle_from_horizontal <= angle_threshold)) then
                (
                    edge_verts = getEdgeVertIds node adapter edge_id

                    if (edge_verts.count == 2) then
                    (
                        point_a = getVertexWorldPosition node adapter edge_verts[1]
                        point_b = getVertexWorldPosition node adapter edge_verts[2]
                        z_min = amin point_a.z point_b.z
                        z_max = amax point_a.z point_b.z
                        z_center = (point_a.z + point_b.z) * 0.5

                        append edge_data #(edge_id, z_min, z_max, z_center, edge_verts[1], edge_verts[2])
                    )
                )
            )
        )

        edge_data
        -- return
    ),


    /*
    Builds one detected Z-level record from defining horizontal edges.
    The level center is the midpoint of the minimum and maximum defining edge centers.
    */
    function makeLevel cluster =
    (
        definition_edges = #{}
        level_min = cluster[1][4]
        level_max = cluster[1][4]

        for item in cluster do
        (
            definition_edges[item[1]] = true

            if (item[4] < level_min) then
            (
                level_min = item[4]
            )

            if (item[4] > level_max) then
            (
                level_max = item[4]
            )
        )

        level_center = (level_min + level_max) * 0.5

        #(definition_edges, level_min, level_max, level_center, #{}, level_center, #CENTER, 0)
        -- return
    ),

    /*
    Detects repeated world-Z levels from horizontal edges.
    A valid level requires at least Min Level Edges inside Level Tolerance.
    */
    function findLevels edge_data level_tolerance min_level_edges =
    (
        levels = #()

        if (edge_data.count > 0) then
        (
            qsort edge_data straightEdgeFixerCompareData
            cluster = #()
            cluster_min_z = 0.0
            max_cluster_span = level_tolerance * 2.0

            for item in edge_data do
            (
                if (cluster.count == 0) then
                (
                    cluster = #(item)
                    cluster_min_z = item[4]
                )
                else if ((item[4] - cluster_min_z) <= max_cluster_span) then
                (
                    append cluster item
                )
                else
                (
                    if (cluster.count >= min_level_edges) then
                    (
                        append levels (makeLevel cluster)
                    )

                    cluster = #(item)
                    cluster_min_z = item[4]
                )
            )

            if (cluster.count >= min_level_edges) then
            (
                append levels (makeLevel cluster)
            )

            if (levels.count > 1) then
            (
                qsort levels straightEdgeFixerCompareLevelData
            )
        )

        levels
        -- return
    ),

    /*
    Assigns every angle-qualified horizontal edge to its nearest detected row.
    There is no Z-distance search cutoff; Angle controls horizontal eligibility.
    */
    function assignEdgesToLevels levels edge_data =
    (
        if (levels.count > 0) then
        (
            for item in edge_data do
            (
                edge_id = item[1]
                edge_z = item[4]
                nearest_level = 0
                nearest_distance = 1.0e30

                for level_index = 1 to levels.count do
                (
                    level_distance = abs (edge_z - levels[level_index][4])

                    if (level_distance < nearest_distance) then
                    (
                        nearest_distance = level_distance
                        nearest_level = level_index
                    )
                )

                if (nearest_level > 0) then
                (
                    levels[nearest_level][5][edge_id] = true
                )
            )
        )

        levels
        -- return
    ),


    /*
    Finds one horizontal edge record by edge ID.
    Returns undefined when the edge is not present in edge_data.
    */
    function getEdgeDataById edge_data edge_id =
    (
        result_data = undefined

        for item in edge_data while (result_data == undefined) do
        (
            if (item[1] == edge_id) then
            (
                result_data = item
            )
        )

        result_data
        -- return
    ),

    /*
    Chooses TOP, BOTTOM, or CENTER target Z for every detected edge level.
    The decision uses assigned edge centers outside the defining edge cluster.
    */
    function calculateTargets levels edge_data =
    (
        for level_index = 1 to levels.count do
        (
            level_data = levels[level_index]
            definition_edges = level_data[1]
            assigned_edges = level_data[5]
            level_min = level_data[2]
            level_max = level_data[3]
            level_center = level_data[4]
            outside_count = 0
            below_count = 0
            above_count = 0

            for edge_id in assigned_edges do
            (
                if (not definition_edges[edge_id]) then
                (
                    item = getEdgeDataById edge_data edge_id

                    if (item != undefined) then
                    (
                        outside_count += 1
                        edge_z = item[4]

                        if (edge_z < level_min) then
                        (
                            below_count += 1
                        )
                        else if (edge_z > level_max) then
                        (
                            above_count += 1
                        )
                    )
                )
            )

            if (outside_count == 0) then
            (
                level_data[6] = level_center
                level_data[7] = #CENTER
            )
            else if (below_count == outside_count) then
            (
                level_data[6] = level_max
                level_data[7] = #TOP
            )
            else if (above_count == outside_count) then
            (
                level_data[6] = level_min
                level_data[7] = #BOTTOM
            )
            else
            (
                level_data[6] = level_center
                level_data[7] = #CENTER
            )

            level_data[8] = outside_count
        )

        levels
        -- return
    ),

    /*
    Collects unique vertex IDs used by the assigned edges of one level.
    Shared vertices are moved only once.
    */
    function getLevelVertexIds node adapter assigned_edges =
    (
        vertex_ids = #{}

        for edge_id in assigned_edges do
        (
            edge_verts = getEdgeVertIds node adapter edge_id

            if (edge_verts.count == 2) then
            (
                vertex_ids[edge_verts[1]] = true
                vertex_ids[edge_verts[2]] = true
            )
        )

        vertex_ids
        -- return
    ),

    /*
    Aligns one vertex to target world Z on an Editable Poly base object.
    World X and Y remain unchanged.
    */
    function setEditablePolyVertexWorldZ node editable_poly vert_id target_z =
    (
        object_tm = node.objectTransform
        inverse_tm = inverse object_tm
        local_position = polyop.getVert editable_poly vert_id
        world_position = local_position * object_tm
        target_world_position = [world_position.x, world_position.y, target_z]
        target_local_position = target_world_position * inverse_tm

        polyop.setVert editable_poly vert_id target_local_position

        true
        -- return
    ),

    /*
    Aligns assigned edge vertices directly on an Editable Poly base object.
    Shared vertices are moved once per detected level.
    */
    function applyToEditablePoly node editable_poly adapter levels =
    (
        for level_data in levels do
        (
            vertex_ids = getLevelVertexIds node adapter level_data[5]
            target_z = level_data[6]

            for vert_id in vertex_ids do
            (
                setEditablePolyVertexWorldZ node editable_poly vert_id target_z
            )
        )

        update node
        true
        -- return
    ),

    /*
    Aligns assigned edge vertices through an Edit Poly modifier.
    Existing vertex selection and Edit Poly sub-object level are restored afterwards.
    */
    function applyToEditPoly node edit_poly adapter levels =
    (
        previous_selection = EditPolyMod.GetSelection edit_poly #Vertex node:node
        previous_level = EditPolyMod.GetEPolySelLevel edit_poly
        object_tm = node.objectTransform

        EditPolyMod.SetEPolySelLevel edit_poly #Vertex

        for level_data in levels do
        (
            vertex_ids = getLevelVertexIds node adapter level_data[5]
            target_z = level_data[6]

            for vert_id in vertex_ids do
            (
                current_local_position = EditPolyMod.GetVertex edit_poly vert_id node:node
                current_world_position = current_local_position * object_tm
                world_move_delta = [0,0,(target_z - current_world_position.z)]

                if ((length world_move_delta) > 0.0000001) then
                (
                    one_vert = #{}
                    one_vert[vert_id] = true
                    EditPolyMod.SetSelection edit_poly #Vertex one_vert node:node
                    EditPolyMod.MoveSelection edit_poly world_move_delta
                    EditPolyMod.Commit edit_poly
                )
            )
        )

        EditPolyMod.SetSelection edit_poly #Vertex previous_selection node:node
        EditPolyMod.SetEPolySelLevel edit_poly previous_level
        update node

        true
        -- return
    ),

    /*
    Formats one object's detected edge levels from bottom to top.
    Reports defining edges, outside aligned edges, mode, and final target Z.
    */
    function buildObjectReport node levels =
    (
        report_text = "OBJECT: " + node.name + "\n"

        if (levels.count == 0) then
        (
            report_text += "  No edge rows found.\n"
        )
        else
        (
            for level_index = 1 to levels.count do
            (
                level_data = levels[level_index]
                definition_count = countBits level_data[1]
                assigned_count = countBits level_data[5]
                outside_count = level_data[8]

                report_text +=
                    "  Row " + (level_index as string) +
                    " | detected Z: " + (level_data[4] as string) +
                    " | mode: " + (level_data[7] as string) +
                    " | target Z: " + (level_data[6] as string) +
                    " | row edges: " + (definition_count as string) +
                    " | outside aligned: " + (outside_count as string) +
                    " | total aligned: " + (assigned_count as string) + "\n"
            )
        )

        report_text
        -- return
    ),

    /*
    Processes one selected object using horizontal edges instead of loose vertices.
    Returns a diagnostic text block for that object.
    */
    function processObject node level_tolerance min_level_edges angle_threshold =
    (
        report_text = ""
        adapter = undefined
        created_new_modifier = false

        try
        (
            adapter = getGeometryAdapter node
            created_new_modifier = adapter[3]
            edge_data = getHorizontalEdgeData node adapter angle_threshold
            levels = findLevels edge_data level_tolerance min_level_edges
            levels = assignEdgesToLevels levels edge_data
            levels = calculateTargets levels edge_data

            if (levels.count > 0) then
            (
                if (adapter[1] == #editable_poly) then
                (
                    applyToEditablePoly node (adapter[2]) adapter levels
                )
                else
                (
                    applyToEditPoly node (adapter[2]) adapter levels
                )
            )
            else if (created_new_modifier) then
            (
                deleteModifier node (adapter[2])
            )

            report_text = buildObjectReport node levels
        )
        catch
        (
            if (created_new_modifier and (adapter != undefined)) then
            (
                try
                (
                    deleteModifier node (adapter[2])
                )
                catch
                (
                )
            )

            report_text = "OBJECT: " + node.name + "\n  ERROR: " + (getCurrentException() as string) + "\n"
        )

        report_text
        -- return
    ),

    /*
    Detects and aligns horizontal edge levels on all selected geometry objects.
    Quiet Mode suppresses the final diagnostic message box.
    */
    function alignSelection level_tolerance:0.01 min_level_edges:3 angle_threshold:45.0 quiet_mode:false =
    (
        selected_nodes = selection as array
        report_text = "STRAIGHT EDGE FIXER " + version + "\n\n"
        processed_count = 0

        if (selected_nodes.count == 0) then
        (
            messageBox "Select at least one geometry object." title:"Straight Edge Fixer"
        )
        else
        (
            undo "Straight Edge Fixer" on
            (
                for node in selected_nodes do
                (
                    if (isValidNode node and (superClassOf node == GeometryClass)) then
                    (
                        processed_count += 1
                        report_text += processObject node level_tolerance min_level_edges angle_threshold
                        report_text += "\n"
                    )
                )
            )

            completeRedraw()

            if (processed_count == 0) then
            (
                messageBox "The selection contains no supported geometry objects." title:"Straight Edge Fixer"
            )
            else if (not quiet_mode) then
            (
                messageBox report_text title:"Straight Edge Fixer - Report"
            )
        )

        true
        -- return
    ),

    /*
    Opens the standalone Straight Edge Fixer dialog using the persisted dialog position.
    Embedded and library loads can call this explicitly when UI is desired.
    */
    function showUI =
    (
        this.hideUI()
        dialog_position = this.loadDialogPosition()
        createDialog straightEdgeFixer_ui pos:dialog_position style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
        true
        -- return
    ),

    /*
    Closes the standalone Straight Edge Fixer dialog without changing the public API instance.
    */
    function hideUI =
    (
        try(destroyDialog straightEdgeFixer_ui)catch()
        true
        -- return
    ),

    on create do
    (
        migrateLegacyIni()
    )
)

StraightEdgeFixer = StraightEdgeFixer_v()

straight_edge_fixer_auto_open_dialog = StraightEdgeFixer.shouldAutoOpenDialog wall_fixer_runtime_mode (getSourceFileName())

if EPolyToolsIntegration != undefined then
(
    if not(EPolyToolsIntegration.shouldAutoOpenUI()) then straight_edge_fixer_auto_open_dialog = false
)

rollout straightEdgeFixer_ui "Straight Edge Fixer" width:300
(
    groupBox grp_settings "ROWS SETTINGS" pos:[8,8] width:284 height:132

    label lbl_level_tolerance "Rows distance:" pos:[20,32] width:120 height:18
    spinner spn_level_tolerance "" pos:[150,30] width:93 height:18 range:[0.000001,1000000.0,0.01] type:#worldunits scale:0.001 tooltip:"Maximum world-space distance used to detect and group horizontal edge rows."
    label lbl_rows_distance_units "unit" pos:[247,32] width:36 height:18

    label lbl_min_level_edges "Min Edges:" pos:[20,60] width:120 height:18
    spinner spn_min_level_edges "" pos:[150,58] width:93 height:18 range:[1,100000,3] type:#integer scale:1 tooltip:"Minimum number of horizontal edges required to define a valid edge row."
    label lbl_min_edges_units "edges" pos:[247,60] width:36 height:18

    checkbox chk_quiet_mode "Quiet Mode" pos:[20,88] width:240 height:18 checked:false tooltip:"Run edge-row alignment without showing the final report."

    groupBox grp_checks "EDGE CHECKS" pos:[8,148] width:284 height:144

    label lbl_angle_threshold "Angle:" pos:[20,172] width:46 height:18 tooltip:"Maximum allowed angle away from the requested direction."
    spinner spn_angle_threshold "" pos:[64,170] width:58 height:18 range:[0.0,45.0,45.0] type:#float scale:1.0 tooltip:"Maximum direction deviation in degrees."
    label lbl_angle_units "°" pos:[124,172] width:16 height:18

    button btn_check_horizontal "CHECK HORIZONTAL" pos:[18,198] width:127 height:42 tooltip:"LMB: select visible edges whose deviation from horizontal is greater than Angle.\n\nRMB: straighten currently selected horizontal-direction error edges. Reference priority: straight neighbor, then nearest straight edge on the same level. Failed vertices are selected automatically."
    button btn_check_vertical "CHECK VERTICAL" pos:[155,198] width:127 height:42 tooltip:"LMB: select visible edges whose deviation from vertical is greater than Angle.\n\nRMB: straighten currently selected vertical-direction error edges. Reference priority: straight neighbor, then nearest straight edge on the same level. Failed vertices are selected automatically."

    button btn_border_check "BORDER CHECK" pos:[18,248] width:264 height:28 tooltip:"Select visible border edges with an unwelded/overlapping local-Z seam, a reflex corner above 180 degrees, or a 360-degree backtracking border. Backtracking does not require the remote vertices to share position."

    button btn_align "STRAIGHT EDGE FIXER" pos:[8,302] width:284 height:38 tooltip:"Detect repeated horizontal edge rows and align nearby horizontal edges to TOP, BOTTOM, or CENTER target Z."

    on straightEdgeFixer_ui open do
    (
        settings_data = StraightEdgeFixer.loadSettings()
        display_unit_label = StraightEdgeFixer.getDisplayUnitLabel()


        spn_level_tolerance.value = settings_data[1]
        spn_min_level_edges.value = settings_data[2]
        spn_angle_threshold.value = settings_data[3]
        chk_quiet_mode.checked = settings_data[4]
        lbl_rows_distance_units.text = display_unit_label
    )

    on straightEdgeFixer_ui moved dialog_position do
    (
        StraightEdgeFixer.saveDialogPosition dialog_position
    )

    on spn_level_tolerance changed control_value do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked
    )

    on spn_min_level_edges changed control_value do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked
    )

    on spn_angle_threshold changed control_value do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked
    )

    on chk_quiet_mode changed control_state do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked
    )

    on btn_check_horizontal pressed do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.checkEdgeDirection #horizontal spn_level_tolerance.value spn_angle_threshold.value
    )


    on btn_check_horizontal rightclick do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.straightenSelectedEdges #horizontal spn_level_tolerance.value spn_angle_threshold.value
    )

    on btn_check_vertical pressed do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.checkEdgeDirection #vertical spn_level_tolerance.value spn_angle_threshold.value
    )


    on btn_check_vertical rightclick do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.straightenSelectedEdges #vertical spn_level_tolerance.value spn_angle_threshold.value
    )


    on btn_border_check pressed do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked
        StraightEdgeFixer.checkBorders spn_level_tolerance.value
    )

    on btn_align pressed do
    (
        StraightEdgeFixer.saveSettings spn_level_tolerance.value spn_min_level_edges.value spn_angle_threshold.value chk_quiet_mode.checked

        StraightEdgeFixer.alignSelection \
            level_tolerance:spn_level_tolerance.value \
            min_level_edges:spn_min_level_edges.value \
            angle_threshold:spn_angle_threshold.value \
            quiet_mode:chk_quiet_mode.checked
    )
)


if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "straight-edge-fixer" "Straight Edge Fixer" StraightEdgeFixer straightEdgeFixer_ui StraightEdgeFixer.file_version StraightEdgeFixer.project_version (getSourceFileName()) capabilities:#(#detect, #selection, #repair, #edge, #border, #align, #editable_poly, #edit_poly, #ui)
)

if straight_edge_fixer_auto_open_dialog then StraightEdgeFixer.showUI()
