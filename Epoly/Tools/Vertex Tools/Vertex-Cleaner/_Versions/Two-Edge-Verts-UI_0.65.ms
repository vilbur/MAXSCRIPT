/*
    Two Edge Verts UI 0.65
    Frontend only. Defines the rollout and callbacks; package loading and standalone execution belong to Two-Edge-Verts.ms.
*/


global TwoEdgeVerts
global TwoEdgeVertsMain
global TwoEdgeVertsUI
global TwoEdgeVerts_UI
global EPolyToolsIntegration
global epoly_tools_project_version
global two_edge_verts_ui_title


if epoly_tools_project_version == undefined or epoly_tools_project_version < 0.818 then
(
    epoly_tools_project_version = 0.818
)


two_edge_verts_ui_title = "Two Edge Verts | v" + (epoly_tools_project_version as string)


struct TwoEdgeVertsUI_v
(
    file_version = 0.65,
    project_version = 0.818,


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


rollout TwoEdgeVerts_UI two_edge_verts_ui_title width:286 height:342
(
    button btn_restart "RESTART" pos:[12,304] width:262 height:24 tooltip:"LMB: Reload the complete canonical Two-Edge-Verts Tool through the main entry."
    label lbl_info "Select topology cleanup vertices" pos:[12,40] width:262 height:18 align:#left
    button btn_select "SEARCH 2-EDGE VERTS" pos:[12,62] width:262 height:30 tooltip:"LMB: Search one Editable Poly / Edit Poly object, select all 2-edge vertices, and store their exact live vertex IDs."
    button btn_remove_vert "SELECT \\ REMOVE" pos:[12,98] width:262 height:30 tooltip:"LMB: Select the next stored candidate.\n\nRMB: Remove the selected candidate by welding only across an actually visible edge."
    button btn_t_junction "SELECT T-JUNCTION VERTS" pos:[12,134] width:262 height:30 enabled:false tooltip:"Disabled."


    on btn_restart pressed do
    (
        TwoEdgeVertsMain.reloadTool()
    )


    on btn_select pressed do
    (
        if selection.count != 1 then
        (
            TwoEdgeVerts.resetManualRemoveState()
            messageBox "Select exactly one Editable Poly / Edit Poly object." title:"Two Edge Verts"
        )
        else
        (
            select_ok = TwoEdgeVerts.selectTwoEdgeVerts()

            if select_ok then
            (
                stored_ok = TwoEdgeVerts.storeManualRemoveStateFromCurrentSelection()

                if not(stored_ok) then
                (
                    format "Two Edge Verts | SEARCH found no valid stored manual candidates.\n"
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


    on btn_t_junction pressed do
    (
        TwoEdgeVerts.selectTJunctionVerts()
    )


    on TwoEdgeVerts_UI help do
    (
        TwoEdgeVertsMain.reloadTool()
    )
)




if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "two-edge-verts" "Two Edge Verts" TwoEdgeVerts TwoEdgeVerts_UI TwoEdgeVertsUI.file_version TwoEdgeVertsUI.project_version (getSourceFileName()) capabilities:#(#detect, #selection, #remove, #vertex, #editable_poly, #edit_poly, #ui)
)