/*
    Redundant Vertex Cleaner UI 0.76
    Frontend only. Defines the rollout and callbacks; package loading and standalone execution belong to Redundant-Vertex-Cleaner.ms.
*/


global TwoEdgeVerts
global TwoEdgeVertsMain
global TwoEdgeVertsUI
global TwoEdgeVerts_UI
global EPolyToolsIntegration
global epoly_tools_project_version
global two_edge_verts_ui_title


if epoly_tools_project_version == undefined or epoly_tools_project_version < 0.836 then
(
    epoly_tools_project_version = 0.836
)


two_edge_verts_ui_title = "Redundant Vertex Cleaner | v" + (epoly_tools_project_version as string)


struct TwoEdgeVertsUI_v
(
    file_version = 0.76,
    project_version = 0.836,


    /*
    Opens the standalone frontend dialog using the already loaded backend package.
    INPUT: none. OUTPUT: Boolean success.
    */
    function showUI =
    (
        this.hideUI()

        try
        (
            createDialog TwoEdgeVerts_UI style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
            windows.processPostedMessages()
        )
        catch
        (
            exception_text = getCurrentException()
            format "Redundant Vertex Cleaner | dialog open failed: %\n" exception_text
            messageBox ("Could not open Redundant Vertex Cleaner.\n\n" + (exception_text as string)) title:"Redundant Vertex Cleaner - Startup Error"
            return false
        )

        if not(TwoEdgeVerts_UI.inDialog) then
        (
            error_text = "Dialog creation returned without an open dialog."
            format "Redundant Vertex Cleaner | %\n" error_text
            messageBox error_text title:"Redundant Vertex Cleaner - Startup Error"
            return false
        )

        true
        -- return
    ),


    /*
    Closes only a standalone frontend dialog without changing backend state.
    INPUT: none. OUTPUT: Boolean success.
    */
    function hideUI =
    (
        try
        (
            if TwoEdgeVerts_UI != undefined and TwoEdgeVerts_UI.inDialog then destroyDialog TwoEdgeVerts_UI
        )
        catch
        (
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


rollout TwoEdgeVerts_UI two_edge_verts_ui_title width:286 height:536
(
    button btn_restart "RESTART" pos:[12,500] width:262 height:24 tooltip:"LMB: Reload the complete canonical Redundant Vertex Cleaner package through the main entry."
    label lbl_info "VERTS - - SEL - \\ UNSEL -" pos:[12,40] width:262 height:18 align:#left
    timer tmr_vertex_info interval:250 active:true
    button btn_fix_selected "FIX SELECTED VERT" pos:[12,64] width:262 height:48 tooltip:"LMB: Fix exactly one currently selected true 2-edge vertex immediately. Target-welds it into the closest visible neighbor so the opposite edge path stays connected. No SEARCH/manual queue is required."
    button btn_select "SEARCH 2-EDGE VERTS" pos:[12,118] width:262 height:30 tooltip:"LMB: FORCE selects every vertex with exactly two visible incident edges. No angle/class filter is applied.\n\nRMB: Select the existing filtered redundant 2-edge set and store it for SELECT \\ REMOVE."
    button btn_remove "REMOVE" pos:[12,154] width:262 height:30 tooltip:"LMB: Repeatedly search the filtered redundant 2-edge set and remove one current vertex until none remain."
    button btn_remove_vert "SELECT \\ REMOVE" pos:[12,190] width:262 height:30 tooltip:"LMB: Select the next stored true 2-edge candidate.\n\nRMB: Remove that candidate through the stored queue path; if that path cannot run, try the one currently selected true 2-edge vertex directly."
    button btn_duplicate_select "SELECT DUPLICATE VERTS" pos:[12,226] width:262 height:30 tooltip:"LMB: Select all vertices that share one exact Point3 position with another live vertex. No tolerance is used."
    button btn_duplicate_collapse "COLLAPSE DUPLICATE VERTS" pos:[12,262] width:262 height:30 tooltip:"LMB: Collapse every exact-position duplicate group to one surviving vertex. No distance threshold is used."
    button btn_t_junction "SELECT T-JUNCTION VERTS" pos:[12,298] width:262 height:30 tooltip:"LMB: Select topology T-junction vertices with exactly three live edges and a straight-through edge pair."
    button btn_border_t "SELECT BORDER T-JUNCTIONS" pos:[12,334] width:262 height:30 tooltip:"LMB: Select the T-junction subset whose two straight-through edges are open border edges."
    button btn_inner_border_corner "SELECT INNER BORDER CORNERS" pos:[12,370] width:262 height:30 tooltip:"LMB: Select hole/reflex border corners, such as corners around an inner square opening."
    button btn_outer_border_corner "SELECT OUTTER BORDER CORNERS" pos:[12,406] width:262 height:30 tooltip:"LMB: Select exterior-perimeter border corners, opposite to the inner-hole class."

    on btn_restart pressed do
    (
        TwoEdgeVertsMain.reloadTool()
    )

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
            messageBox "Select exactly one Editable Poly / Edit Poly object." title:"Redundant Vertex Cleaner"
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
            messageBox "Select exactly one Editable Poly / Edit Poly object." title:"Redundant Vertex Cleaner"
        )
        else
        (
            select_ok = TwoEdgeVerts.selectTwoEdgeVerts force_mode:false

            if select_ok then
            (
                stored_ok = TwoEdgeVerts.storeManualRemoveStateFromCurrentSelection()

                if not(stored_ok) then
                (
                    format "Redundant Vertex Cleaner | SEARCH RMB found no valid stored manual candidates.\n"
                )
            )
            else
            (
                TwoEdgeVerts.resetManualRemoveState()
            )
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
        fixed_ok = TwoEdgeVerts.fixManualRemoveCandidate()

        if not(fixed_ok) then
        (
            TwoEdgeVerts.fixSelectedVertex()
        )

        TwoEdgeVertsUI.refreshVertexInfo()
    )

    on btn_duplicate_select pressed do
    (
        TwoEdgeVerts.selectDuplicatePositionVerts()
    )

    on btn_duplicate_collapse pressed do
    (
        removed_count = TwoEdgeVerts.collapseDuplicatePositionVertsOnSelection()
        format "Redundant Vertex Cleaner | duplicate collapse removed:%\n" removed_count
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
        TwoEdgeVertsUI.refreshVertexInfo()
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
    EPolyToolsIntegration.registerTool "two-edge-verts" "Redundant Vertex Cleaner" TwoEdgeVerts TwoEdgeVerts_UI TwoEdgeVertsUI.file_version TwoEdgeVertsUI.project_version (getSourceFileName()) capabilities:#(#detect, #selection, #remove, #vertex, #editable_poly, #edit_poly, #ui)
)