/*
    Two Edge Verts Main 0.03
    Standalone/embedded package entry. Loads the backend and frontend, then opens the standalone dialog when appropriate.
*/

global TwoEdgeVertsMain
global TwoEdgeVerts
global TwoEdgeVertsUI
global TwoEdgeVerts_UI
global EPolyToolsIntegration
global EPOLY_TOOLS_RUNTIME_MODE
global epoly_tools_project_version
global two_edge_verts_main_source_path

two_edge_verts_main_source_path = getSourceFileName()

struct TwoEdgeVertsMain_v
(
    file_version = 0.03,
    project_version = 0.812,
    source_path = two_edge_verts_main_source_path,

    /*
    Returns the directory containing the canonical package entry file.
    INPUT: none. OUTPUT: package directory String.
    */
    function getPackageDirectory =
    (
        if source_path == undefined or source_path == "" then return ""
        getFilenamePath source_path
        -- return
    ),

    /*
    Loads the backend implementation from the canonical sibling -FN file.
    INPUT: none. OUTPUT: Boolean success.
    */
    function loadBackend =
    (
        package_directory = this.getPackageDirectory()
        if package_directory == "" then return false

        backend_path = package_directory + "Two-Edge-Verts-FN.ms"
        if not(doesFileExist backend_path) then
        (
            format "Two Edge Verts | backend not found: %\n" backend_path
            return false
        )

        try
        (
            fileIn backend_path quiet:true
        )
        catch
        (
            format "Two Edge Verts | backend load failed: %\n" (getCurrentException())
            return false
        )

        TwoEdgeVerts != undefined
        -- return
    ),

    /*
    Loads the frontend definition from the canonical sibling UI file.
    INPUT: none. OUTPUT: Boolean success.
    */
    function loadFrontend =
    (
        package_directory = this.getPackageDirectory()
        if package_directory == "" then return false

        frontend_path = package_directory + "Two-Edge-Verts-UI.ms"
        if not(doesFileExist frontend_path) then
        (
            format "Two Edge Verts | frontend not found: %\n" frontend_path
            return false
        )

        try
        (
            fileIn frontend_path quiet:true
        )
        catch
        (
            format "Two Edge Verts | frontend load failed: %\n" (getCurrentException())
            return false
        )

        TwoEdgeVertsUI != undefined and TwoEdgeVerts_UI != undefined
        -- return
    ),

    /*
    Reloads only the backend implementation while keeping the active frontend rollout intact.
    INPUT: none. OUTPUT: Boolean success.
    */
    function reloadBackend =
    (
        this.loadBackend()
        -- return
    ),

    /*
    Loads the package for the current runtime mode and opens the standalone dialog when required.
    INPUT: none. OUTPUT: Boolean success.
    */
    function run =
    (
        runtime_mode = if EPOLY_TOOLS_RUNTIME_MODE == undefined then #standalone else EPOLY_TOOLS_RUNTIME_MODE

        if not(this.loadBackend()) then return false

        if epoly_tools_project_version == undefined or epoly_tools_project_version < project_version then
        (
            epoly_tools_project_version = project_version
        )

        -- EPolyManager loads the sibling UI companion itself in embedded mode.
        if runtime_mode == #embedded then return true

        if not(this.loadFrontend()) then return false

        if runtime_mode != #library then
        (
            if TwoEdgeVertsUI == undefined then return false
            return TwoEdgeVertsUI.showUI()
        )

        true
        -- return
    ),

    on create do
    (
    )
)

TwoEdgeVertsMain = TwoEdgeVertsMain_v()
TwoEdgeVertsMain.run()
