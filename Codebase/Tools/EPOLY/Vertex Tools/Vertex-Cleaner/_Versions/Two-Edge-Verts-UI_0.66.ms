/*
    Redundant Vertex Cleaner UI 0.66
    Frontend only. Defines the rollout and callbacks; package loading and standalone execution belong to Two-Edge-Verts.ms.
*/


global TwoEdgeVerts
global TwoEdgeVertsMain
global TwoEdgeVertsUI
global TwoEdgeVerts_UI
global EPolyToolsIntegration
global epoly_tools_project_version
global two_edge_verts_ui_title


if epoly_tools_project_version == undefined or epoly_tools_project_version < 0.823 then
(
    epoly_tools_project_version = 0.823
)


two_edge_verts_ui_title = "Redundant Vertex Cleaner | v" + (epoly_tools_project_version as string)


struct TwoEdgeVertsUI_v
(
    file_version = 0.66,
    project_version = 0.823,


    /*
    Opens the standalone frontend dialog using the already loaded backend package.
    INPUT: none. OUTPUT: Boolean success.
    */
    function showUI =
    (
        this.hideUI()
        createDialog TwoEdgeVerts_UI style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
        windows.processPostedMessages()
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


    on create do
    (
    )
)


TwoEdgeVertsUI = TwoEdgeVertsUI_v()


rollout TwoEdgeVerts_UI two_edge_verts_ui_title width:286 height:404
(
    button btn_restart "RESTART" pos:[12,366] width:262 height:24 tooltip:"LMB: Reload the complete canonical Redundant Vertex Cleaner package through the main entry."
    label lbl_info "Redundant vertex topology cleanup" pos:[12,40] width:262 height:18 align:#left
    button btn_select "SEARCH 2-EDGE VERTS" pos:[12,62] width:262 height:30 tooltip:"LMB: Search one Editable Poly / Edit Poly object, select only true 2-edge vertices, and store their exact live vertex IDs."
    button btn_remove_vert "SELECT \\ REMOVE" pos:[12,98] width:262 height:30 tooltip:"LMB: Select the next stored true 2-edge candidate.\n\nRMB: Remove that candidate with native Remove Vertex, using the visible-neighbor weld only as fallback."
    button btn_duplicate_select "SELECT DUPLICATE VERTS" pos:[12,134] width:262 height:30 tooltip:"LMB: Select all vertices that share one exact Point3 position with another live vertex. No tolerance is used."
    button btn_duplicate_collapse "COLLAPSE DUPLICATE VERTS" pos:[12,170] width:262 height:30 tooltip:"LMB: Collapse every exact-position duplicate group to one surviving vertex. No distance threshold is used."
    button btn_t_junction "SELECT T-JUNCTION VERTS" pos:[12,206] width:262 height:30 tooltip:"LMB: Select topology T-junction vertices with exactly three live edges and a straight-through edge pair."
    button btn_border_t "SELECT BORDER T-JUNCTIONS" pos:[12,242] width:262 height:30 tooltip:"LMB: Select the T-junction subset whose two straight-through edges are open border edges."
    button btn_border_corner "SELECT BORDER CORNERS" pos:[12,278] width:262 height:30 tooltip:"LMB: Select non-T-junction border corners with exactly two open border edges that are not straight-through."

    on btn_restart pressed do
    (
        TwoEdgeVertsMain.reloadTool()
    )

    on btn_select pressed do
    (
        if selection.count != 1 then
        (
            TwoEdgeVerts.resetManualRemoveState()
            messageBox "Select exactly one Editable Poly / Edit Poly object." title:"Redundant Vertex Cleaner"
        )
        else
        (
            select_ok = TwoEdgeVerts.selectTwoEdgeVerts()

            if select_ok then
            (
                stored_ok = TwoEdgeVerts.storeManualRemoveStateFromCurrentSelection()

                if not(stored_ok) then
                (
                    format "Redundant Vertex Cleaner | SEARCH found no valid stored manual candidates.\n"
                )
            )
            else
            (
                TwoEdgeVerts.resetManualRemoveState()
            )
        )
    )

    on btn_remove_vert pressed do
    (
        TwoEdgeVerts.selectNextManualRemoveCandidate()
    )

    on btn_remove_vert rightclick do
    (
        TwoEdgeVerts.fixManualRemoveCandidate()
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

    on btn_border_corner pressed do
    (
        TwoEdgeVerts.selectBorderCornerVerts()
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