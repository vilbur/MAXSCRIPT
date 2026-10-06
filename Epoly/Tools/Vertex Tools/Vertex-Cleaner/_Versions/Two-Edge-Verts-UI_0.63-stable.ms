/*
    Two Edge Verts UI 0.63
    Frontend only. Defines the rollout and callbacks; package loading and standalone execution belong to Two-Edge-Verts.ms.
*/

global TwoEdgeVerts
global TwoEdgeVertsMain
global TwoEdgeVertsUI
global TwoEdgeVerts_UI
global EPolyToolsIntegration
global epoly_tools_project_version

struct TwoEdgeVertsUI_v
(
    file_version = 0.63,
    project_version = 0.813,

    /*
    Opens the standalone frontend dialog using the already loaded backend package.
    INPUT: none. OUTPUT: Boolean success.
    */
    function showUI =
    (
        this.hideUI()
        this.updateTitle()
        createDialog TwoEdgeVerts_UI style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
        true
        -- return
    ),

    /*
    Updates the rollout title from the highest loaded shared project version.
    Falls back to this frontend's stored project version in standalone mode.
    */
    function updateTitle =
    (
        display_version = project_version

        if epoly_tools_project_version != undefined and epoly_tools_project_version > display_version then
        (
            display_version = epoly_tools_project_version
        )

        TwoEdgeVerts_UI.title = "Two Edge Verts | v" + (display_version as string)
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

rollout TwoEdgeVerts_UI "Two Edge Verts" width:286 height:342
(
    button btn_restart "RESTART" pos:[12,304] width:262 height:24 tooltip:"LMB: Reload the complete canonical Two-Edge-Verts Tool through the main entry."
    label lbl_info "Select topology cleanup vertices" pos:[12,40] width:262 height:18 align:#left
    button btn_select "SEARCH 2-EDGE VERTS" pos:[12,62] width:262 height:30 tooltip:"LMB: Search and select 2-edge vertices, then store their vertex IDs.\n\nRMB: Run the existing automatic remove/fix action."
    button btn_remove_vert "SELECT \\ REMOVE" pos:[12,98] width:262 height:30 tooltip:"LMB: Select the next stored candidate.\n\nRMB: Remove the selected candidate by welding only across an actually visible edge."
    button btn_t_junction "SELECT T-JUNCTION VERTS" pos:[12,134] width:262 height:30 enabled:false tooltip:"Disabled."
    checkbox chk_ignore_border_corners "Ignore border corners" pos:[12,170] width:262 height:18 checked:true tooltip:"Ignore degree-two border vertices whose two border edges form a 90 degree corner."
    button btn_debug_clear "DEBUG: CLEAR EDIT POLY SELECTIONS" pos:[12,196] width:262 height:30 tooltip:"LMB: Clear Vertex, Edge, and Face selections from every Edit Poly modifier on all selected objects."

    on btn_restart pressed do
    (
        TwoEdgeVertsMain.reloadTool()
    )

    on btn_select pressed do
    (
        TwoEdgeVerts.ignore_border_corners = chk_ignore_border_corners.checked
        select_ok = TwoEdgeVerts.selectTwoEdgeVerts()

        if select_ok then
        (
            TwoEdgeVerts.storeManualRemoveStateFromCurrentSelection()
        )
        else
        (
            TwoEdgeVerts.resetManualRemoveState()
        )
    )

    on btn_select rightclick do
    (
        TwoEdgeVerts.ignore_border_corners = chk_ignore_border_corners.checked
        TwoEdgeVerts.removeTwoEdgeVerts()
    )

    on btn_remove_vert pressed do
    (
        TwoEdgeVerts.ignore_border_corners = chk_ignore_border_corners.checked
        TwoEdgeVerts.selectNextManualRemoveCandidate()
    )

    on btn_remove_vert rightclick do
    (
        TwoEdgeVerts.ignore_border_corners = chk_ignore_border_corners.checked
        TwoEdgeVerts.fixManualRemoveCandidate()
    )

    on btn_t_junction pressed do
    (
        TwoEdgeVerts.selectTJunctionVerts()
    )

    on btn_debug_clear pressed do
    (
        TwoEdgeVerts.clearAllEditPolySelections()
    )
)

TwoEdgeVertsUI.updateTitle()

if EPolyToolsIntegration != undefined then
(
    EPolyToolsIntegration.registerTool "two-edge-verts" "Two Edge Verts" TwoEdgeVerts TwoEdgeVerts_UI TwoEdgeVertsUI.file_version TwoEdgeVertsUI.project_version (getSourceFileName()) capabilities:#(#detect, #selection, #remove, #vertex, #editable_poly, #edit_poly, #ui)
)
