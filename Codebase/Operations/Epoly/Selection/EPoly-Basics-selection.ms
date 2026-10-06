/* EPoly-Basics-selection.ms
   File version: 0.13
   Project version: 0.33
   Five-row sub-object selection editor with front-end UI separated from scene functionality.
*/

global epoly_tools_project_version
global epoly_basics_selection_file_version = 0.13
global epoly_basics_selection_project_version = 0.33
global epoly_basics_selection_rollout_title
global epoly_basics_selection_ini_path = (getDir #plugcfg) + "\\EPoly-Basics-selection.ini"
global epoly_basics_selection_ini_section = "EPoly Basics Selection"
global epolyBasicsSelectionSceneTools
global epoly_basics_selection_source_path = try(getSourceFileName())catch("")

if epoly_tools_project_version == undefined or epoly_basics_selection_project_version > epoly_tools_project_version then
(
    epoly_tools_project_version = epoly_basics_selection_project_version
)

epoly_basics_selection_rollout_title = "EPoly Basics Selection | v" + (formattedPrint epoly_tools_project_version format:".2f")

/* Persistent front-end settings only.
   No geometry or Modify-panel operations belong in this state object.
*/
struct epolyBasicsSelectionSettings_v
(
    /* Convert an EPoly level value to the persistent INI text form.
    */
    function epolyLevelToIniText epoly_level =
    (
        level_text = "Object"

        case epoly_level of
        (
            #Vertex: level_text = "Vertex"
            #Edge: level_text = "Edge"
            #Border: level_text = "Border"
            #Face: level_text = "Face"
            #Element: level_text = "Element"
            default: level_text = "Object"
        )

        level_text -- return
    ),

    /* Convert persistent INI text to an EPoly level value.
    */
    function iniTextToEPolyLevel level_text =
    (
        epoly_level = #Object

        case level_text of
        (
            "Vertex": epoly_level = #Vertex
            "Edge": epoly_level = #Edge
            "Border": epoly_level = #Border
            "Face": epoly_level = #Face
            "Element": epoly_level = #Element
            default: epoly_level = #Object
        )

        epoly_level -- return
    ),

    /* Read the viewer tab from persistent INI state.
    */
    function loadViewerLevel =
    (
        level_text = getINISetting epoly_basics_selection_ini_path epoly_basics_selection_ini_section "SubObjectLevel"
        iniTextToEPolyLevel level_text -- return
    ),

    /* Save the viewer tab to persistent INI state.
    */
    function saveViewerLevel epoly_level =
    (
        level_text = epolyLevelToIniText epoly_level
        setINISetting epoly_basics_selection_ini_path epoly_basics_selection_ini_section "SubObjectLevel" level_text
        epoly_level -- return
    ),

    /* Read the persistent rollout position from the INI file.
    */
    function loadDialogPosition =
    (
        x_text = getINISetting epoly_basics_selection_ini_path epoly_basics_selection_ini_section "DialogX"
        y_text = getINISetting epoly_basics_selection_ini_path epoly_basics_selection_ini_section "DialogY"
        dialog_pos = undefined

        if x_text != "" and y_text != "" then
        (
            x_value = try(x_text as integer)catch(undefined)
            y_value = try(y_text as integer)catch(undefined)

            if x_value != undefined and y_value != undefined then
            (
                dialog_pos = [x_value, y_value]
            )
        )

        dialog_pos -- return
    ),

    /* Save the rollout position to the INI file.
    */
    function saveDialogPosition dialog_pos =
    (
        result_value = false

        if dialog_pos != undefined then
        (
            x_result = setINISetting epoly_basics_selection_ini_path epoly_basics_selection_ini_section "DialogX" (dialog_pos.x as string)
            y_result = setINISetting epoly_basics_selection_ini_path epoly_basics_selection_ini_section "DialogY" (dialog_pos.y as string)
            result_value = x_result and y_result
        )

        result_value -- return
    ),

    on create do
    (
    )
)

epolyBasicsSelectionSettings = epolyBasicsSelectionSettings_v()

try
(
    epolyBasicsSelectionSettings.saveDialogPosition (getDialogPos epolyUiDebugRollout)
)
catch()

try(destroyDialog epolyUiDebugRollout)catch()

/* Selection-viewer functionality.
   This object never changes Modify-panel UI state and never reads rollout controls or INI settings.
*/
struct epolyBasicsSelectionCore_v
(
    snapshot_vertex = #{},
    snapshot_edge = #{},
    snapshot_border = #{},
    snapshot_face = #{},
    snapshot_element = #{},
    snapshot_valid = false,

    /* Find the first Edit Poly modifier on the selected node without depending on Modify-panel state.
    */
    function getTargetEditPolyModifier node_value =
    (
        target_modifier = undefined

        for modifier_index = 1 to node_value.modifiers.count do
        (
            if target_modifier == undefined then
            (
                modifier_value = node_value.modifiers[modifier_index]

                if classOf modifier_value == Edit_Poly then
                (
                    target_modifier = modifier_value
                )
            )
        )

        target_modifier -- return
    ),

    /* Resolve the Poly target from the selected node without depending on Modify-panel state.
       Edit Poly modifiers take priority; otherwise the Editable Poly base object is used.
    */
    function resolveContext =
    (
        context_data = #(#none, undefined, undefined)

        if selection.count == 1 then
        (
            node_value = selection[1]
            target_modifier = getTargetEditPolyModifier node_value

            if target_modifier != undefined then
            (
                context_data = #(#edit_poly, node_value, target_modifier)
            )
            else if classOf node_value.baseObject == Editable_Poly then
            (
                context_data = #(#editable_poly, node_value, node_value.baseObject)
            )
        )

        context_data -- return
    ),

    /* Convert an Editable Poly UI level to the underlying selection storage level.
    */
    function getMeshLevel epoly_level =
    (
        mesh_level = #Object

        case epoly_level of
        (
            #Vertex: mesh_level = #Vertex
            #Edge: mesh_level = #Edge
            #Border: mesh_level = #Edge
            #Face: mesh_level = #Face
            #Element: mesh_level = #Face
            default: mesh_level = #Object
        )

        mesh_level -- return
    ),

    /* Get a readable label for an Editable Poly UI level.
    */
    function getLevelLabel epoly_level =
    (
        level_label = "Object"

        case epoly_level of
        (
            #Vertex: level_label = "Vertex"
            #Edge: level_label = "Edge"
            #Border: level_label = "Border"
            #Face: level_label = "Polygon"
            #Element: level_label = "Element"
            default: level_label = "Object"
        )

        level_label -- return
    ),

    /* Read the raw selection bitarray for one requested sub-object level without changing Modify-panel state.
    */
    function getSelectionBitsForLevel context_data epoly_level =
    (
        context_kind = context_data[1]
        node_value = context_data[2]
        current_object = context_data[3]
        mesh_level = getMeshLevel epoly_level
        selection_bits = #{}

        if mesh_level != #Object then
        (
            if context_kind == #edit_poly then
            (
                selection_bits = current_object.GetSelection mesh_level node:node_value
            )
            else if context_kind == #editable_poly then
            (
                case mesh_level of
                (
                    #Vertex: selection_bits = polyop.getVertSelection node_value
                    #Edge: selection_bits = polyop.getEdgeSelection node_value
                    #Face: selection_bits = polyop.getFaceSelection node_value
                    default: selection_bits = #{}
                )
            )
        )

        selection_bits -- return
    ),

    /* Capture the current object's selections for every rollout viewer tab in one Get operation.
       Border shares edge storage and Element shares face storage in Editable Poly / Edit Poly.
    */
    function captureSelectionSnapshot =
    (
        context_data = resolveContext()
        context_kind = context_data[1]
        result_value = false

        snapshot_vertex = #{}
        snapshot_edge = #{}
        snapshot_border = #{}
        snapshot_face = #{}
        snapshot_element = #{}
        snapshot_valid = false

        if context_kind != #none then
        (
            snapshot_vertex = getSelectionBitsForLevel context_data #Vertex
            snapshot_edge = getSelectionBitsForLevel context_data #Edge
            snapshot_border = snapshot_edge
            snapshot_face = getSelectionBitsForLevel context_data #Face
            snapshot_element = snapshot_face
            snapshot_valid = true
            result_value = true
        )

        result_value -- return
    ),

    /* Return the cached selection for one rollout viewer tab.
    */
    function getSnapshotSelectionBits epoly_level =
    (
        selection_bits = #{}

        if snapshot_valid then
        (
            case epoly_level of
            (
                #Vertex: selection_bits = snapshot_vertex
                #Edge: selection_bits = snapshot_edge
                #Border: selection_bits = snapshot_border
                #Face: selection_bits = snapshot_face
                #Element: selection_bits = snapshot_element
                default: selection_bits = #{}
            )
        )

        selection_bits -- return
    ),

    /* Compatibility selection writer for callers that use the core API directly.
       SET always delegates to the scene backend so the current Modify-panel stack item owns the selection.
    */
    function setSelectionBitsForLevel epoly_level selection_bits =
    (
        mesh_level = getMeshLevel epoly_level
        result_value = false

        if mesh_level == #Object then
        (
            format "EPoly Basics Selection: choose a sub-object level before setting indexes.\n"
        )
        else if epolyBasicsSelectionSceneTools != undefined then
        (
            result_value = epolyBasicsSelectionSceneTools.applySelectionBitsForLevel epoly_level selection_bits
        )

        result_value -- return
    ),

    /* Convert a selection bitarray to comma-separated indexes for the edit text.
    */
    function selectionBitsToText selection_bits =
    (
        index_values = selection_bits as array
        text_value = ""

        for item_index = 1 to index_values.count do
        (
            if item_index > 1 then
            (
                text_value += ","
            )

            text_value += index_values[item_index] as string
        )

        text_value -- return
    ),

    /* Parse comma/space separated indexes and positive ranges such as 3-8 into a bitarray.
    */
    function parseIndexText text_value =
    (
        selection_bits = #{}
        token_values = filterString text_value " ,;\t\r\n"
        parse_ok = true

        for token_value in token_values do
        (
            range_values = filterString token_value "-"

            if range_values.count == 1 then
            (
                index_value = try(range_values[1] as integer)catch(undefined)

                if index_value != undefined and index_value > 0 then
                (
                    selection_bits[index_value] = true
                )
                else
                (
                    parse_ok = false
                    format "EPoly Basics Selection: invalid index token '%'.\n" token_value
                )
            )
            else if range_values.count == 2 then
            (
                start_index = try(range_values[1] as integer)catch(undefined)
                end_index = try(range_values[2] as integer)catch(undefined)

                if start_index != undefined and end_index != undefined and start_index > 0 and end_index > 0 then
                (
                    if start_index > end_index then
                    (
                        swap_value = start_index
                        start_index = end_index
                        end_index = swap_value
                    )

                    for index_value = start_index to end_index do
                    (
                        selection_bits[index_value] = true
                    )
                )
                else
                (
                    parse_ok = false
                    format "EPoly Basics Selection: invalid range token '%'.\n" token_value
                )
            )
            else
            (
                parse_ok = false
                format "EPoly Basics Selection: invalid token '%'.\n" token_value
            )
        )

        #(parse_ok, selection_bits) -- return
    ),

    /* Parse index text and replace the scene selection for one explicit viewer level.
    */
    function setSelectionFromTextForLevel epoly_level text_value =
    (
        parse_data = parseIndexText text_value
        result_value = false

        if parse_data[1] then
        (
            result_value = setSelectionBitsForLevel epoly_level parse_data[2]
        )

        result_value -- return
    ),

    /* Build status text for the selected Poly target and one explicit viewer level.
       This is read-only and never changes Modify-panel state.
    */
    function getContextText epoly_level =
    (
        context_data = resolveContext()
        context_kind = context_data[1]
        node_value = context_data[2]
        current_object = context_data[3]
        context_text = "No supported Poly target"

        if context_kind == #edit_poly then
        (
            mesh_level = getMeshLevel epoly_level
            context_text = node_value.name + " | Edit Poly | Level: " + getLevelLabel epoly_level + " | data: " + (mesh_level as string)
            context_text += " | stackSel:" + (current_object.useStackSelection as string)
            context_text += " | selectMode:" + (current_object.selectMode as string)
        )
        else if context_kind == #editable_poly then
        (
            mesh_level = getMeshLevel epoly_level
            context_text = node_value.name + " | Editable Poly | Level: " + getLevelLabel epoly_level + " | data: " + (mesh_level as string)
        )
        else if selection.count != 1 then
        (
            context_text = "Select exactly one object"
        )

        context_text -- return
    ),

    on create do
    (
    )
)

epolyBasicsSelectionCore = epolyBasicsSelectionCore_v()

/* Scene helper actions used by the debug controls.
   These operations are intentionally separate from the selection viewer core.
*/
struct epolyBasicsSelectionSceneTools_v
(
    /* Test whether the requested stack object is already current in the Modify panel.
    */
    function isModifyObjectActive target_object =
    (
        is_active = false

        if target_object != undefined and getCommandPanelTaskMode() == #modify then
        (
            is_active = (modPanel.getCurrentObject() == target_object)
        )

        is_active -- return
    ),

    /* Resolve only the stack object that is currently active in the Modify panel.
       SET uses this context so it never jumps to another Edit Poly modifier in the stack.
    */
    function resolveCurrentStackContext =
    (
        context_data = #(#none, undefined, undefined)

        if selection.count == 1 and getCommandPanelTaskMode() == #modify then
        (
            node_value = selection[1]
            current_object = modPanel.getCurrentObject()

            if current_object != undefined and classOf current_object == Edit_Poly then
            (
                modifier_found = false

                for modifier_value in node_value.modifiers do
                (
                    if not modifier_found then
                    (
                        modifier_found = (modifier_value == current_object)
                    )
                )

                if modifier_found then
                (
                    context_data = #(#edit_poly, node_value, current_object)
                )
            )
            else if current_object != undefined and classOf current_object == Editable_Poly then
            (
                if current_object == node_value.baseObject then
                (
                    context_data = #(#editable_poly, node_value, current_object)
                )
            )
        )

        context_data -- return
    ),

    /* Convert one EPoly level to the Modify-panel subObjectLevel number.
    */
    function getSubObjectLevelNumber epoly_level =
    (
        level_number = 0

        case epoly_level of
        (
            #Vertex: level_number = 1
            #Edge: level_number = 2
            #Border: level_number = 3
            #Face: level_number = 4
            #Element: level_number = 5
            default: level_number = 0
        )

        level_number -- return
    ),

    /* Convert a Modify-panel subObjectLevel number to one EPoly level.
    */
    function getEPolyLevelFromNumber level_number =
    (
        epoly_level = #Object

        case level_number of
        (
            1: epoly_level = #Vertex
            2: epoly_level = #Edge
            3: epoly_level = #Border
            4: epoly_level = #Face
            5: epoly_level = #Element
            default: epoly_level = #Object
        )

        epoly_level -- return
    ),

    /* Read the selected tool target's current Modify-panel sub-object level when that target is active.
    */
    function getModifySubObjectLevel =
    (
        context_data = epolyBasicsSelectionCore.resolveContext()
        target_object = context_data[3]
        epoly_level = #Object

        if target_object != undefined and isModifyObjectActive target_object then
        (
            epoly_level = getEPolyLevelFromNumber subObjectLevel
        )

        epoly_level -- return
    ),

    /* Activate one sub-object level in the Modify panel for the selected Edit Poly or Editable Poly target.
       The expensive current-object switch runs only when the desired target is not already active.
    */
    function activateSubObjectLevel epoly_level context_data:undefined =
    (
        if context_data == undefined then
        (
            context_data = epolyBasicsSelectionCore.resolveContext()
        )
        context_kind = context_data[1]
        node_value = context_data[2]
        current_object = context_data[3]
        level_number = getSubObjectLevelNumber epoly_level
        result_value = false

        if context_kind != #none and level_number > 0 then
        (
            if getCommandPanelTaskMode() != #modify then
            (
                max modify mode
            )

            if context_kind == #edit_poly then
            (
                try(current_object.SetPrimaryNode node_value)catch()
                current_object.useStackSelection = false
                current_object.selectMode = 0

                if not (isModifyObjectActive current_object) then
                (
                    modPanel.setCurrentObject current_object node:node_value
                )

                current_object.SetEPolySelLevel epoly_level
                subObjectLevel = level_number
                result_value = true
            )
            else if context_kind == #editable_poly then
            (
                try(current_object.showCage = off)catch()

                if not (isModifyObjectActive current_object) then
                (
                    modPanel.setCurrentObject current_object node:node_value
                )

                subObjectLevel = level_number
                result_value = true
            )
        )
        else
        (
            format "EPoly Basics Selection: select exactly one Editable Poly or Edit Poly target.\n"
        )

        if result_value then
        (
            redrawViews()
        )

        result_value -- return
    ),

    /* Apply one visible sub-object selection through the native Editable Poly / Edit Poly API.
       Edit Poly uses explicit literal .Select calls from epoly-guides.md and keeps the requested level visible.
    */
    function applySelectionBitsForLevel epoly_level selection_bits =
    (
        context_data = resolveCurrentStackContext()
        context_kind = context_data[1]
        node_value = context_data[2]
        current_object = context_data[3]
        mesh_level = epolyBasicsSelectionCore.getMeshLevel epoly_level
        result_value = false
        stored_selection = #{}

        if mesh_level == #Object then
        (
            format "EPoly Basics Selection: invalid sub-object level.\n"
        )
        else if context_kind == #edit_poly then
        (
            if activateSubObjectLevel epoly_level context_data:context_data then
            (
                case mesh_level of
                (
                    #Vertex:
                    (
                        old_selection = current_object.GetSelection #Vertex

                        if old_selection.numberSet > 0 then
                        (
                            current_object.Select #Vertex old_selection select:false
                        )

                        current_object.Select #Vertex selection_bits select:true
                        stored_selection = current_object.GetSelection #Vertex
                    )
                    #Edge:
                    (
                        old_selection = current_object.GetSelection #Edge

                        if old_selection.numberSet > 0 then
                        (
                            current_object.Select #Edge old_selection select:false
                        )

                        current_object.Select #Edge selection_bits select:true
                        stored_selection = current_object.GetSelection #Edge
                    )
                    #Face:
                    (
                        old_selection = current_object.GetSelection #Face

                        if old_selection.numberSet > 0 then
                        (
                            current_object.Select #Face old_selection select:false
                        )

                        current_object.Select #Face selection_bits select:true
                        stored_selection = current_object.GetSelection #Face
                    )
                )

                current_object.SetEPolySelLevel epoly_level
                subObjectLevel = getSubObjectLevelNumber epoly_level
                current_object.RefreshScreen()
                completeRedraw()

                result_value = (stored_selection == selection_bits)

                format "EPoly Basics Selection: Edit Poly requested:% stored:% level:% subObjectLevel:%\n" selection_bits stored_selection epoly_level subObjectLevel
            )
        )
        else if context_kind == #editable_poly then
        (
            if activateSubObjectLevel epoly_level context_data:context_data then
            (
                case mesh_level of
                (
                    #Vertex: polyop.setVertSelection node_value selection_bits
                    #Edge: polyop.setEdgeSelection node_value selection_bits
                    #Face: polyop.setFaceSelection node_value selection_bits
                )

                completeRedraw()
                result_value = true
            )
        )
        else
        (
            format "EPoly Basics Selection: SET requires the current Modify-panel stack item to be Edit Poly or Editable Poly.\n"
        )

        result_value -- return
    ),

    /* Parse one row and apply it as a visible sub-object selection through the scene backend.
    */
    function applySelectionTextForLevel epoly_level text_value =
    (
        parse_data = epolyBasicsSelectionCore.parseIndexText text_value
        result_value = false

        if parse_data[1] then
        (
            result_value = applySelectionBitsForLevel epoly_level parse_data[2]
        )

        result_value -- return
    ),

    /* Create a teapot at the default position and make it the active selection.
    */
    function createTeapotObject =
    (
        teapot_value = teapot()

        select teapot_value
        redrawViews()

        teapot_value -- return
    ),

    /* Convert every currently selected scene node to Editable Poly.
    */
    function convertSelectionToEditablePoly =
    (
        selected_nodes = selection as array
        converted_count = 0

        if selected_nodes.count > 0 then
        (
            subObjectLevel = 0

            for node_value in selected_nodes do
            (
                if isValidNode node_value then
                (
                    convert_result = try
                    (
                        convertToPoly node_value
                        try(node_value.baseObject.showCage = off)catch()
                        true
                    )
                    catch
                    (
                        false
                    )

                    if convert_result then
                    (
                        converted_count += 1
                    )
                )
            )

            select selected_nodes
            max modify mode
            redrawViews()
        )
        else
        (
            format "EPoly Basics Selection: select at least one object before converting to Editable Poly.\n"
        )

        converted_count -- return
    ),

    /* Add an Edit Poly modifier to the single selected node and make it current in the Modify panel.
    */
    function addEditPolyModifier =
    (
        result_value = false

        if selection.count == 1 then
        (
            node_value = selection[1]
            modifier_value = Edit_Poly()

            max modify mode
            addModifier node_value modifier_value

            if not (isModifyObjectActive modifier_value) then
            (
                modPanel.setCurrentObject modifier_value node:node_value
            )

            result_value = true
            redrawViews()
        )
        else
        (
            format "EPoly Basics Selection: select exactly one object before adding Edit Poly.\n"
        )

        result_value -- return
    ),

    /* Remove only the Edit Poly modifier currently active in the Modify panel.
    */
    function removeCurrentEditPolyModifier =
    (
        result_value = false

        if selection.count == 1 then
        (
            node_value = selection[1]

            max modify mode
            current_object = modPanel.getCurrentObject()

            if current_object != undefined and classOf current_object == Edit_Poly then
            (
                subObjectLevel = 0
                deleteModifier node_value current_object

                result_value = true
                redrawViews()
            )
            else
            (
                format "EPoly Basics Selection: current Modify-panel item is not an Edit Poly modifier.\n"
            )
        )
        else
        (
            format "EPoly Basics Selection: select exactly one object before removing Edit Poly.\n"
        )

        result_value -- return
    ),

    on create do
    (
    )
)

epolyBasicsSelectionSceneTools = epolyBasicsSelectionSceneTools_v()

/* Compatibility alias for older calls that used the previous backend instance name.
*/
epolyUiDebug = epolyBasicsSelectionCore

rollout epolyUiDebugRollout epoly_basics_selection_rollout_title
(
    local level_buttons_syncing = false

    groupBox gb_viewer "SUB-OBJECT SELECTIONS" pos:[8,8] width:444 height:244

    button btn_get "GET ALL SELECTIONS" pos:[16,30] width:428 height:32 tooltip:"LMB: Snapshot Vertex, Edge, Border, Polygon, and Element selections into all rows."

    checkbutton btn_vertex "Vertex" pos:[16,70] width:76 height:28 tooltip:"LMB: Set Modify-panel subObjectLevel to Vertex."
    editText edt_vertex_indexes "" pos:[100,74] width:274 height:20
    button btn_set_vertex "SET" pos:[382,70] width:62 height:28 tooltip:"LMB: Apply this row to the Vertex selection."

    checkbutton btn_edge "Edge" pos:[16,104] width:76 height:28 tooltip:"LMB: Set Modify-panel subObjectLevel to Edge."
    editText edt_edge_indexes "" pos:[100,108] width:274 height:20
    button btn_set_edge "SET" pos:[382,104] width:62 height:28 tooltip:"LMB: Apply this row to the Edge selection."

    checkbutton btn_border "Border" pos:[16,138] width:76 height:28 tooltip:"LMB: Set Modify-panel subObjectLevel to Border."
    editText edt_border_indexes "" pos:[100,142] width:274 height:20
    button btn_set_border "SET" pos:[382,138] width:62 height:28 tooltip:"LMB: Apply this row to the Border selection."

    checkbutton btn_polygon "Polygon" pos:[16,172] width:76 height:28 tooltip:"LMB: Set Modify-panel subObjectLevel to Polygon."
    editText edt_polygon_indexes "" pos:[100,176] width:274 height:20
    button btn_set_polygon "SET" pos:[382,172] width:62 height:28 tooltip:"LMB: Apply this row to the Polygon selection."

    checkbutton btn_element "Element" pos:[16,206] width:76 height:28 tooltip:"LMB: Set Modify-panel subObjectLevel to Element."
    editText edt_element_indexes "" pos:[100,210] width:274 height:20
    button btn_set_element "SET" pos:[382,206] width:62 height:28 tooltip:"LMB: Apply this row to the Element selection."

    label lbl_context "" pos:[16,258] width:428 height:28

    groupBox gb_scene "SCENE HELPERS" pos:[8,292] width:444 height:70
    button btn_create_object "Create object" pos:[16,314] width:210 height:34 tooltip:"LMB: Create a teapot.\n\nRMB: Convert the current selection to Editable Poly."
    button btn_edit_poly "Edit Poly" pos:[234,314] width:210 height:34 tooltip:"LMB: Add an Edit Poly modifier.\n\nRMB: Remove the current Edit Poly modifier."

    button btn_restart "RELOAD LATEST" pos:[8,370] width:444 height:34 tooltip:"LMB: Save dialog position and load the newest versioned script from this folder."

    /* Return the last valid front-end sub-object level from INI state.
    */
    function getStoredSubObjectLevel =
    (
        epoly_level = epolyBasicsSelectionSettings.loadViewerLevel()

        if epoly_level == #Object then
        (
            epoly_level = #Vertex
        )

        epoly_level -- return
    )

    /* Render one active sub-object level without letting programmatic button changes call scene actions.
    */
    function setLevelButtonState epoly_level =
    (
        level_buttons_syncing = true

        btn_vertex.checked = (epoly_level == #Vertex)
        btn_edge.checked = (epoly_level == #Edge)
        btn_border.checked = (epoly_level == #Border)
        btn_polygon.checked = (epoly_level == #Face)
        btn_element.checked = (epoly_level == #Element)

        level_buttons_syncing = false
        epoly_level -- return
    )

    /* Resolve the active Modify-panel level, falling back to the last INI level when the target is not active.
    */
    function getUiSubObjectLevel =
    (
        epoly_level = epolyBasicsSelectionSceneTools.getModifySubObjectLevel()

        if epoly_level == #Object then
        (
            epoly_level = getStoredSubObjectLevel()
        )

        epoly_level -- return
    )

    /* Display the complete cached Get snapshot in the five independent index rows.
       This only renders cached data and never reads scene selection.
    */
    function showCachedRows =
    (
        if epolyBasicsSelectionCore.snapshot_valid then
        (
            edt_vertex_indexes.text = epolyBasicsSelectionCore.selectionBitsToText (epolyBasicsSelectionCore.getSnapshotSelectionBits #Vertex)
            edt_edge_indexes.text = epolyBasicsSelectionCore.selectionBitsToText (epolyBasicsSelectionCore.getSnapshotSelectionBits #Edge)
            edt_border_indexes.text = epolyBasicsSelectionCore.selectionBitsToText (epolyBasicsSelectionCore.getSnapshotSelectionBits #Border)
            edt_polygon_indexes.text = epolyBasicsSelectionCore.selectionBitsToText (epolyBasicsSelectionCore.getSnapshotSelectionBits #Face)
            edt_element_indexes.text = epolyBasicsSelectionCore.selectionBitsToText (epolyBasicsSelectionCore.getSnapshotSelectionBits #Element)
        )

        epolyBasicsSelectionCore.snapshot_valid -- return
    )

    /* Clear all five displayed index rows.
    */
    function clearIndexRows =
    (
        edt_vertex_indexes.text = ""
        edt_edge_indexes.text = ""
        edt_border_indexes.text = ""
        edt_polygon_indexes.text = ""
        edt_element_indexes.text = ""

        true -- return
    )

    /* Connect one rollout sub-object checkbutton to Modify-panel subObjectLevel.
       The scene operation stays in the scene-tools backend; this function only routes UI state.
    */
    function activateUiSubObjectLevel epoly_level =
    (
        result_value = epolyBasicsSelectionSceneTools.activateSubObjectLevel epoly_level

        if result_value then
        (
            epolyBasicsSelectionSettings.saveViewerLevel epoly_level
            setLevelButtonState epoly_level
            lbl_context.text = epolyBasicsSelectionCore.getContextText epoly_level
        )
        else
        (
            setLevelButtonState (getUiSubObjectLevel())
        )

        result_value -- return
    )

    /* Refresh front-end state from the active Modify-panel target without changing selection data.
    */
    function refreshStatus =
    (
        epoly_level = getUiSubObjectLevel()
        setLevelButtonState epoly_level
        lbl_context.text = epolyBasicsSelectionCore.getContextText epoly_level
        lbl_context.text -- return
    )

    /* GET: capture all five scene selections once and populate every sub-object row.
    */
    function captureSelectionsToRows =
    (
        result_value = epolyBasicsSelectionCore.captureSelectionSnapshot()

        if result_value then
        (
            showCachedRows()
        )
        else
        (
            clearIndexRows()
        )

        refreshStatus()
        result_value -- return
    )

    /* SET one explicit row through the scene backend, then mirror the resulting Modify-panel level in the checkbuttons.
       Other row texts and the cached Get snapshot stay unchanged.
    */
    function applyRowSelection epoly_level text_value =
    (
        result_value = epolyBasicsSelectionSceneTools.applySelectionTextForLevel epoly_level text_value

        if result_value then
        (
            refreshStatus()
        )

        result_value -- return
    )

    /* Resolve the base tool name from the currently loaded script filename.
       A trailing numeric _<version> suffix is ignored so canonical and versioned files share one reload family.
    */
    function getReloadBaseName source_path =
    (
        source_name = getFilenameFile source_path
        name_parts = filterString source_name "_"
        base_name = source_name

        if name_parts.count > 1 then
        (
            version_text = name_parts[name_parts.count]
            version_value = try(version_text as float)catch(undefined)

            if version_value != undefined then
            (
                suffix_text = "_" + version_text
                base_name = substring source_name 1 (source_name.count - suffix_text.count)
            )
        )

        base_name -- return
    )

    /* Find the highest numeric versioned script beside the currently loaded file.
       If none exists, return the currently loaded script path.
    */
    function getLatestReloadScript =
    (
        source_path = epoly_basics_selection_source_path
        latest_path = source_path

        if source_path != undefined and source_path != "" then
        (
            source_dir = getFilenamePath source_path
            base_name = getReloadBaseName source_path
            file_pattern = source_dir + base_name + "_*.ms"
            versioned_files = getFiles file_pattern
            latest_version = -1.0

            for file_path in versioned_files do
            (
                file_name = getFilenameFile file_path
                prefix_text = base_name + "_"

                if file_name.count > prefix_text.count then
                (
                    version_text = substring file_name (prefix_text.count + 1) (file_name.count - prefix_text.count)
                    version_value = try(version_text as float)catch(undefined)

                    if version_value != undefined and version_value > latest_version then
                    (
                        latest_version = version_value
                        latest_path = file_path
                    )
                )
            )
        )

        latest_path -- return
    )

    /* Save the persistent position, close this rollout, and load the newest versioned script in this folder.
       The reloaded script restores the same position from INI, including across 3ds Max sessions.
    */
    function restartViewer =
    (
        reload_path = getLatestReloadScript()
        try(epolyBasicsSelectionSettings.saveDialogPosition (getDialogPos epolyUiDebugRollout))catch()
        try(destroyDialog epolyUiDebugRollout)catch()

        if reload_path != undefined and reload_path != "" and doesFileExist reload_path then
        (
            fileIn reload_path
        )
        else
        (
            saved_dialog_pos = epolyBasicsSelectionSettings.loadDialogPosition()

            if saved_dialog_pos != undefined then
            (
                createDialog epolyUiDebugRollout 460 412 pos:saved_dialog_pos
            )
            else
            (
                createDialog epolyUiDebugRollout 460 412
            )
        )

        true -- return
    )

    on btn_create_object pressed do
    (
        undo "Create Teapot" on
        (
            epolyBasicsSelectionSceneTools.createTeapotObject()
        )

        refreshStatus()
    )

    on btn_create_object rightclick do
    (
        undo "Convert Selection To Editable Poly" on
        (
            epolyBasicsSelectionSceneTools.convertSelectionToEditablePoly()
        )

        refreshStatus()
    )

    on btn_edit_poly pressed do
    (
        undo "Add Edit Poly" on
        (
            epolyBasicsSelectionSceneTools.addEditPolyModifier()
        )

        refreshStatus()
    )

    on btn_edit_poly rightclick do
    (
        undo "Remove Edit Poly" on
        (
            epolyBasicsSelectionSceneTools.removeCurrentEditPolyModifier()
        )

        refreshStatus()
    )

    on btn_restart pressed do
    (
        restartViewer()
    )

    on btn_vertex changed button_state do
    (
        if not level_buttons_syncing then
        (
            if button_state then
            (
                activateUiSubObjectLevel #Vertex
            )
            else
            (
                setLevelButtonState (getUiSubObjectLevel())
            )
        )
    )

    on btn_edge changed button_state do
    (
        if not level_buttons_syncing then
        (
            if button_state then
            (
                activateUiSubObjectLevel #Edge
            )
            else
            (
                setLevelButtonState (getUiSubObjectLevel())
            )
        )
    )

    on btn_border changed button_state do
    (
        if not level_buttons_syncing then
        (
            if button_state then
            (
                activateUiSubObjectLevel #Border
            )
            else
            (
                setLevelButtonState (getUiSubObjectLevel())
            )
        )
    )

    on btn_polygon changed button_state do
    (
        if not level_buttons_syncing then
        (
            if button_state then
            (
                activateUiSubObjectLevel #Face
            )
            else
            (
                setLevelButtonState (getUiSubObjectLevel())
            )
        )
    )

    on btn_element changed button_state do
    (
        if not level_buttons_syncing then
        (
            if button_state then
            (
                activateUiSubObjectLevel #Element
            )
            else
            (
                setLevelButtonState (getUiSubObjectLevel())
            )
        )
    )

    on btn_get pressed do
    (
        captureSelectionsToRows()
    )

    on btn_set_vertex pressed do
    (
        applyRowSelection #Vertex edt_vertex_indexes.text
    )

    on btn_set_edge pressed do
    (
        applyRowSelection #Edge edt_edge_indexes.text
    )

    on btn_set_border pressed do
    (
        applyRowSelection #Border edt_border_indexes.text
    )

    on btn_set_polygon pressed do
    (
        applyRowSelection #Face edt_polygon_indexes.text
    )

    on btn_set_element pressed do
    (
        applyRowSelection #Element edt_element_indexes.text
    )

    on epolyUiDebugRollout open do
    (
        epolyUiDebugRollout.title = epoly_basics_selection_rollout_title
        refreshStatus()
    )

    on epolyUiDebugRollout moved dialog_pos do
    (
        epolyBasicsSelectionSettings.saveDialogPosition dialog_pos
    )

    on epolyUiDebugRollout close do
    (
        try(epolyBasicsSelectionSettings.saveDialogPosition (getDialogPos epolyUiDebugRollout))catch()
    )
)
try
(
    epolyBasicsSelectionSettings.saveDialogPosition (getDialogPos epolyUiDebugRollout)
)
catch()

try(destroyDialog epolyUiDebugRollout)catch()

saved_dialog_pos = epolyBasicsSelectionSettings.loadDialogPosition()

if saved_dialog_pos != undefined then
(
    createDialog epolyUiDebugRollout 460 412 pos:saved_dialog_pos
)
else
(
    createDialog epolyUiDebugRollout 460 412
)
