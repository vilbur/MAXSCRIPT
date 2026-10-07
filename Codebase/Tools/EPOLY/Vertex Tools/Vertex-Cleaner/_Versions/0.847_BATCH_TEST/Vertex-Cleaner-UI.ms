/*
    Vertex Cleaner UI 0.847
    Frontend only. Defines the rollout and callbacks; package loading and standalone execution belong to Vertex-Cleaner.ms.
*/


global TwoEdgeVerts
global TwoEdgeVertsMain
global TwoEdgeVertsUI
global TwoEdgeVerts_UI
global EPolyToolsIntegration
global epoly_tools_project_version
global two_edge_verts_ui_title
global two_edge_verts_ui_ini_path
global two_edge_verts_ui_source_path


if epoly_tools_project_version == undefined or epoly_tools_project_version < 0.847 then
(
    epoly_tools_project_version = 0.847
)


two_edge_verts_ui_ini_path = (getDir #plugcfg) + "\\Vertex-Cleaner.ini"
two_edge_verts_ui_source_path = getSourceFileName()


struct TwoEdgeVertsUI_v
(
    file_version = 0.847,
    project_version = 0.847,


    /*
    Reads the remembered floating dialog position from the tool INI file.
    Missing or invalid coordinates return undefined so 3ds Max can choose a safe default.
    */
    function getSavedDialogPosition =
    (
        x_text = getINISetting two_edge_verts_ui_ini_path "Dialog" "X"
        y_text = getINISetting two_edge_verts_ui_ini_path "Dialog" "Y"
        dialog_position = undefined

        if x_text != "" and y_text != "" then
        (
            try
            (
                dialog_position = [x_text as integer, y_text as integer]
            )
            catch
            (
                exception_text = getCurrentException()
                format "Vertex Cleaner | saved dialog position is invalid: %\n" exception_text
                dialog_position = undefined
            )
        )

        dialog_position
        -- return
    ),


    /*
    Stores one valid floating dialog position in the tool INI file.
    Docked positions are intentionally not written by callers.
    */
    function saveDialogPosition dialog_position =
    (
        if dialog_position == undefined then return false

        setINISetting two_edge_verts_ui_ini_path "Dialog" "X" (dialog_position.x as string)
        setINISetting two_edge_verts_ui_ini_path "Dialog" "Y" (dialog_position.y as string)

        true
        -- return
    ),


    /*
    Returns true only when the current standalone dialog is floating or not yet registered as a dialog bar.
    Left/right docked states return false so docking never overwrites the remembered floating position.
    */
    function isDialogFloating =
    (
        if TwoEdgeVerts_UI == undefined or not(TwoEdgeVerts_UI.inDialog) then return false
        if not(TwoEdgeVerts_UI.dialogBar) then return true

        dock_state = undefined

        try
        (
            dock_state = cui.getDockState TwoEdgeVerts_UI
        )
        catch
        (
            exception_text = getCurrentException()
            format "Vertex Cleaner | dock state read failed: %\n" exception_text
            return false
        )

        dock_state == #cui_floatable
        -- return
    ),


    /*
    Saves the current floating dialog position without modifying remembered position while docked.
    This is called before unregister/destroy and from the rollout moved callback.
    */
    function saveCurrentDialogPosition =
    (
        if not(this.isDialogFloating()) then return false

        dialog_position = undefined

        try
        (
            dialog_position = getDialogPos TwoEdgeVerts_UI
        )
        catch
        (
            exception_text = getCurrentException()
            format "Vertex Cleaner | dialog position read failed: %\n" exception_text
            return false
        )

        this.saveDialogPosition dialog_position
        -- return
    ),


    /*
    Applies the canonical dark .NET tool title button appearance.
    The button label remains the tool name only and its LMB action is restart.
    */
    function setupToolTitleButton =
    (
        if TwoEdgeVerts_UI == undefined then return false

        button_control = TwoEdgeVerts_UI.btn_tool_title
        color_class = dotNetClass "System.Drawing.Color"
        flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"

        try
        (
            button_control.Text = "Vertex Cleaner"
            button_control.UseVisualStyleBackColor = false
            button_control.FlatStyle = flat_style_class.Flat
            button_control.BackColor = color_class.FromArgb 45 45 48
            button_control.ForeColor = color_class.FromArgb 62 158 255
            button_control.FlatAppearance.BorderSize = 0
            button_control.FlatAppearance.MouseOverBackColor = button_control.BackColor
            button_control.FlatAppearance.MouseDownBackColor = button_control.BackColor
        )
        catch
        (
            exception_text = getCurrentException()
            format "Vertex Cleaner | tool title button setup failed: %\n" exception_text
            return false
        )

        true
        -- return
    ),


    /*
    Keeps the tool title button full-width when a docked CUI bar changes width.
    Standard 12 px side margins are preserved.
    */
    function resizeToolTitleButton dialog_size =
    (
        if TwoEdgeVerts_UI == undefined or dialog_size == undefined then return false

        button_width = amax #(24, dialog_size.x - 24)
        TwoEdgeVerts_UI.btn_tool_title.width = button_width

        true
        -- return
    ),


    /*
    Restarts the owning Tool through the canonical main-entry reload path.
    INPUT: current script path and file prefix are validated for the shared restart contract.
    */
    function restartTool current_script file_prefix =
    (
        if current_script == undefined or current_script == "" then return false
        if file_prefix == undefined or file_prefix == "" then return false
        if TwoEdgeVertsMain == undefined then return false

        TwoEdgeVertsMain.reloadTool()
        -- return
    ),


    /*
    Registers the standalone rollout as a CUI dialog bar that can float or dock only left/right.
    The registration is performed once after createDialog succeeds.
    */
    function registerDocking =
    (
        if TwoEdgeVerts_UI == undefined or not(TwoEdgeVerts_UI.inDialog) then return false
        if TwoEdgeVerts_UI.dialogBar then return true

        try
        (
            cui.RegisterDialogBar TwoEdgeVerts_UI minSize:[286,456] maxSize:[286,-1] style:#(#cui_dock_left, #cui_dock_right, #cui_floatable, #cui_handles)
        )
        catch
        (
            exception_text = getCurrentException()
            format "Vertex Cleaner | left/right docking registration failed: %\n" exception_text
            return false
        )

        true
        -- return
    ),


    /*
    Opens the standalone frontend dialog using the remembered floating position when available.
    The created rollout is registered as a left/right dockable CUI dialog bar before returning.
    */
    function showUI =
    (
        if not(this.hideUI()) then return false
        saved_position = this.getSavedDialogPosition()

        try
        (
            if saved_position != undefined then
            (
                createDialog TwoEdgeVerts_UI pos:saved_position style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
            )
            else
            (
                createDialog TwoEdgeVerts_UI style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
            )

            windows.processPostedMessages()
        )
        catch
        (
            exception_text = getCurrentException()
            format "Vertex Cleaner | dialog open failed: %\n" exception_text
            messageBox ("Could not open Vertex Cleaner.\n\n" + (exception_text as string)) title:"Vertex Cleaner - Startup Error"
            return false
        )

        if not(TwoEdgeVerts_UI.inDialog) then
        (
            error_text = "Dialog creation returned without an open dialog."
            format "Vertex Cleaner | %\n" error_text
            messageBox error_text title:"Vertex Cleaner - Startup Error"
            return false
        )

        if not(this.registerDocking()) then
        (
            messageBox "Vertex Cleaner opened, but left/right docking could not be registered." title:"Vertex Cleaner - Docking Error"
            this.hideUI()
            return false
        )

        true
        -- return
    ),


    /*
    Closes only a standalone frontend dialog without changing backend state.
    A registered dialog bar is unregistered before destroyDialog, preserving floating position first.
    */
    function hideUI =
    (
        if TwoEdgeVerts_UI == undefined or not(TwoEdgeVerts_UI.inDialog) then return true

        this.saveCurrentDialogPosition()

        if TwoEdgeVerts_UI.dialogBar then
        (
            try
            (
                cui.UnRegisterDialogBar TwoEdgeVerts_UI
            )
            catch
            (
                exception_text = getCurrentException()
                format "Vertex Cleaner | dialog bar unregister failed: %\n" exception_text
                return false
            )
        )

        try
        (
            destroyDialog TwoEdgeVerts_UI
        )
        catch
        (
            exception_text = getCurrentException()
            format "Vertex Cleaner | dialog close failed: %\n" exception_text
            return false
        )

        true
        -- return
    ),


    /*
    Refreshes the top vertex-count label from the backend without changing geometry or component selection.
    INPUT: current scene selection. OUTPUT: Boolean success.
    */
    function refreshVertexInfo =
    (
        info_text = "VERTS - - SEL - \\ UNSEL -"

        if TwoEdgeVerts != undefined then
        (
            vertex_counts = TwoEdgeVerts.getSelectedVertexCounts()

            if classOf vertex_counts == Array and vertex_counts.count == 3 then
            (
                info_text = "VERTS " + (vertex_counts[1] as string) + " - SEL " + (vertex_counts[2] as string) + " \\ UNSEL " + (vertex_counts[3] as string)
            )
        )

        if TwoEdgeVerts_UI != undefined then
        (
            TwoEdgeVerts_UI.lbl_info.text = info_text
        )

        true
        -- return
    ),


    on create do
    (
    )
)


TwoEdgeVertsUI = TwoEdgeVertsUI_v()

/*
The visible rollout title is derived from this Tool's own project version.
It must never depend on a higher version published by another EPolyTools component.
*/
two_edge_verts_ui_title = "Vertex Cleaner | v" + (TwoEdgeVertsUI.project_version as string)


rollout TwoEdgeVerts_UI two_edge_verts_ui_title width:286 height:456
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:262 height:24
    label lbl_info "VERTS - - SEL - \\ UNSEL -" pos:[12,40] width:262 height:18 align:#left
    timer tmr_vertex_info interval:250 active:true
    button btn_fix_selected "FIX SELECTED VERT" pos:[12,64] width:262 height:48 tooltip:"LMB: Fix exactly one currently selected true 2-edge vertex immediately. Target-welds it into the closest visible neighbor so the opposite edge path stays connected. No SEARCH/manual queue is required."
    button btn_select "SEARCH 2-EDGE VERTS" pos:[12,118] width:262 height:30 tooltip:"LMB: FORCE selects vertices with exactly two visible edges that deviate no more than 15 degrees from a straight continuation.\n\nRMB: Batched FORCE cleanup. Captures the current FORCE set once, processes highest vertex ID to lowest, and uses the stable edge-preserving target-weld path with UI/redraw updates suppressed until the batch finishes."
    button btn_remove "REMOVE" pos:[12,154] width:262 height:30 tooltip:"LMB: Repeatedly search the filtered redundant 2-edge set and remove one current vertex until none remain."
    button btn_remove_vert "SELECT \\ REMOVE" pos:[12,190] width:262 height:30 tooltip:"LMB: Run a fresh filtered search, select the highest current candidate, and arm it.\n\nRMB: Remove that exact armed candidate through the stable manual path."
    button btn_duplicate_select "SELECT DUPLICATE VERTS" pos:[12,226] width:262 height:30 tooltip:"LMB: Select all vertices that share one exact Point3 position with another live vertex. No tolerance is used."
    button btn_duplicate_collapse "COLLAPSE DUPLICATE VERTS" pos:[12,262] width:262 height:30 tooltip:"LMB: Collapse every exact-position duplicate group to one surviving vertex. No distance threshold is used."
    button btn_t_junction "SELECT T-JUNCTION VERTS" pos:[12,298] width:262 height:30 tooltip:"LMB: Select topology T-junction vertices with exactly three live edges and a straight-through edge pair."
    button btn_border_t "SELECT BORDER T-JUNCTIONS" pos:[12,334] width:262 height:30 tooltip:"LMB: Select the T-junction subset whose two straight-through edges are open border edges."
    button btn_inner_border_corner "SELECT INNER BORDER CORNERS" pos:[12,370] width:262 height:30 tooltip:"LMB: Select hole/reflex border corners, such as corners around an inner square opening."
    button btn_outer_border_corner "SELECT OUTTER BORDER CORNERS" pos:[12,406] width:262 height:30 tooltip:"LMB: Select exterior-perimeter border corners, opposite to the inner-hole class."

    on btn_fix_selected pressed do
    (
        TwoEdgeVerts.fixSelectedVertex()
        TwoEdgeVertsUI.refreshVertexInfo()
    )

    on btn_select pressed do
    (
        TwoEdgeVerts.resetManualRemoveState()

        if selection.count != 1 then
        (
            messageBox "Select exactly one Editable Poly / Edit Poly object." title:"Vertex Cleaner"
        )
        else
        (
            TwoEdgeVerts.selectTwoEdgeVerts force_mode:true
        )
    )

    on btn_select rightclick do
    (
        if selection.count != 1 then
        (
            TwoEdgeVerts.resetManualRemoveState()
            messageBox "Select exactly one Editable Poly / Edit Poly object." title:"Vertex Cleaner"
        )
        else
        (
            TwoEdgeVerts.removeTwoEdgeVertsUsingManualWorkflow()
            TwoEdgeVertsUI.refreshVertexInfo()
        )
    )

    on btn_remove pressed do
    (
        TwoEdgeVerts.removeTwoEdgeVertsUntilStable()
        TwoEdgeVertsUI.refreshVertexInfo()
    )

    on btn_remove_vert pressed do
    (
        TwoEdgeVerts.selectNextManualRemoveCandidate()
    )

    on btn_remove_vert rightclick do
    (
        TwoEdgeVerts.fixManualRemoveCandidate()
        TwoEdgeVertsUI.refreshVertexInfo()
    )

    on btn_duplicate_select pressed do
    (
        TwoEdgeVerts.selectDuplicatePositionVerts()
    )

    on btn_duplicate_collapse pressed do
    (
        removed_count = TwoEdgeVerts.collapseDuplicatePositionVertsOnSelection()
        format "Vertex Cleaner | duplicate collapse removed:%\n" removed_count
    )

    on btn_t_junction pressed do
    (
        TwoEdgeVerts.selectTJunctionVerts()
    )

    on btn_border_t pressed do
    (
        TwoEdgeVerts.selectBorderTJunctionVerts()
    )

    on btn_inner_border_corner pressed do
    (
        TwoEdgeVerts.selectInnerBorderCornerVerts()
    )

    on btn_outer_border_corner pressed do
    (
        TwoEdgeVerts.selectOuterBorderCornerVerts()
    )

    on TwoEdgeVerts_UI open do
    (
        TwoEdgeVertsUI.setupToolTitleButton()
        TwoEdgeVertsUI.refreshVertexInfo()
    )

    on TwoEdgeVerts_UI moved dialog_pos do
    (
        if TwoEdgeVertsUI.isDialogFloating() then
        (
            TwoEdgeVertsUI.saveDialogPosition dialog_pos
        )
    )

    on TwoEdgeVerts_UI resized dialog_size do
    (
        TwoEdgeVertsUI.resizeToolTitleButton dialog_size
    )

    on btn_tool_title MouseClick event_args do
    (
        mouse_buttons_class = dotNetClass "System.Windows.Forms.MouseButtons"

        if event_args.Button == mouse_buttons_class.Left then
        (
            TwoEdgeVertsUI.restartTool two_edge_verts_ui_source_path "Vertex-Cleaner"
        )
    )

    on tmr_vertex_info tick do
    (
        TwoEdgeVertsUI.refreshVertexInfo()
    )

    on TwoEdgeVerts_UI help do
    (
        TwoEdgeVertsMain.reloadTool()
    )
)



if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "two-edge-verts" "Vertex Cleaner" TwoEdgeVerts TwoEdgeVerts_UI TwoEdgeVertsUI.file_version TwoEdgeVertsUI.project_version (getSourceFileName()) capabilities:#(#detect, #selection, #remove, #vertex, #editable_poly, #edit_poly, #ui)
)