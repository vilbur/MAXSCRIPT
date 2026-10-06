/*
    Two Edge Verts Main 0.05
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
    file_version = 0.05,
    project_version = 0.818,
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
    Returns whether text contains only digits and at most one decimal point.
    This validates version suffixes before numeric conversion.
    */
    function isNumericVersionText version_text =
    (
        if version_text == undefined or version_text == "" then return false

        digit_count = 0
        decimal_count = 0

        for character_index = 1 to version_text.count do
        (
            character_text = substring version_text character_index 1

            if character_text == "." then
            (
                decimal_count += 1
                if decimal_count > 1 then return false
            )
            else if findString "0123456789" character_text != undefined then
            (
                digit_count += 1
            )
            else
            (
                return false
            )
        )

        digit_count > 0
        -- return
    ),

    /*
    Returns the newest versioned sibling main script when one is newer than this file, otherwise returns the canonical source path.
    The search derives its filename pattern from the running entry instead of hard-coding a project path.
    */
    function getReloadPath =
    (
        if source_path == undefined or source_path == "" then return ""
        if not(doesFileExist source_path) then return ""

        package_directory = getFilenamePath source_path
        canonical_name = getFilenameFile source_path
        versioned_paths = getFiles (package_directory + canonical_name + "_*.ms")
        newest_path = source_path
        newest_version = file_version

        for versioned_path in versioned_paths do
        (
            versioned_name = getFilenameFile versioned_path
            prefix_text = canonical_name + "_"

            if matchPattern versioned_name pattern:(prefix_text + "*") ignoreCase:true then
            (
                suffix_text = substring versioned_name (prefix_text.count + 1) (versioned_name.count - prefix_text.count)
                suffix_parts = filterString suffix_text "- "

                if suffix_parts.count > 0 and this.isNumericVersionText suffix_parts[1] then
                (
                    version_value = suffix_parts[1] as float

                    if version_value > newest_version then
                    (
                        newest_version = version_value
                        newest_path = versioned_path
                    )
                )
            )
        )

        newest_path
        -- return
    ),

    /*
    Reloads the complete Tool package, preferring a newer versioned sibling when one exists.
    INPUT: none. OUTPUT: Boolean success.
    */
    function reloadTool =
    (
        reload_path = this.getReloadPath()
        if reload_path == "" then
        (
            format "Two Edge Verts | main entry not found: %\n" source_path
            return false
        )

        if TwoEdgeVertsUI != undefined then
        (
            TwoEdgeVertsUI.hideUI()
        )

        try
        (
            fileIn reload_path quiet:true
        )
        catch
        (
            format "Two Edge Verts | restart failed: %\n" (getCurrentException())
            return false
        )

        true
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
