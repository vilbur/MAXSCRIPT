/*
    Vertex Cleaner Main 0.847
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
    file_version = 0.847,
    project_version = 0.847,
    source_path = two_edge_verts_main_source_path,
    startup_error = "",
    backend_file_name = "Vertex-Cleaner-FN.ms",
    backend_legacy_file_name = "Two-Edge-Verts-FN.ms",
    frontend_file_name = "Vertex-Cleaner-UI.ms",
    frontend_legacy_file_name = "Two-Edge-Verts-UI.ms",

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
    Stores and reports one startup failure without converting it into a successful load.
    INPUT: failure text. OUTPUT: false.
    */
    function failStartup error_text =
    (
        startup_error = error_text
        format "Vertex Cleaner | %\n" startup_error
        false
        -- return
    ),

    /*
    Resolves one current package sibling, with the pre-rename filename accepted as a transition fallback.
    INPUT: canonical and legacy filenames. OUTPUT: existing full path String or empty String.
    */
    function resolvePackageSibling canonical_file_name legacy_file_name =
    (
        package_directory = this.getPackageDirectory()
        if package_directory == "" then return ""

        canonical_path = package_directory + canonical_file_name
        if doesFileExist canonical_path then return canonical_path

        legacy_path = package_directory + legacy_file_name
        if doesFileExist legacy_path then
        (
            format "Vertex Cleaner | using legacy sibling filename: %\n" legacy_path
            return legacy_path
        )

        ""
        -- return
    ),

    /*
    Loads the backend implementation from the canonical sibling -FN file.
    INPUT: none. OUTPUT: Boolean success.
    */
    function loadBackend =
    (
        startup_error = ""
        backend_path = this.resolvePackageSibling backend_file_name backend_legacy_file_name

        if backend_path == "" then
        (
            return this.failStartup ("backend not found. Expected " + backend_file_name + " beside the main file.")
        )

        try
        (
            fileIn backend_path quiet:true
        )
        catch
        (
            exception_text = getCurrentException()
            return this.failStartup ("backend load failed: " + (exception_text as string))
        )

        if TwoEdgeVerts == undefined then
        (
            return this.failStartup "backend loaded but TwoEdgeVerts was not defined."
        )

        true
        -- return
    ),

    /*
    Loads the frontend definition from the canonical sibling UI file.
    INPUT: none. OUTPUT: Boolean success.
    */
    function loadFrontend =
    (
        startup_error = ""
        frontend_path = this.resolvePackageSibling frontend_file_name frontend_legacy_file_name

        if frontend_path == "" then
        (
            return this.failStartup ("frontend not found. Expected " + frontend_file_name + " beside the main file.")
        )

        try
        (
            fileIn frontend_path quiet:true
        )
        catch
        (
            exception_text = getCurrentException()
            return this.failStartup ("frontend load failed: " + (exception_text as string))
        )

        if TwoEdgeVertsUI == undefined or TwoEdgeVerts_UI == undefined then
        (
            return this.failStartup "frontend loaded but the UI rollout was not defined."
        )

        true
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
            format "Vertex Cleaner | main entry not found: %\n" source_path
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
            format "Vertex Cleaner | restart failed: %\n" (getCurrentException())
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
        startup_error = ""

        if not(this.loadBackend()) then
        (
            if runtime_mode == #standalone then
            (
                messageBox startup_error title:"Vertex Cleaner - Startup Error"
            )
            return false
        )

        if epoly_tools_project_version == undefined or epoly_tools_project_version < project_version then
        (
            epoly_tools_project_version = project_version
        )

        -- EPolyManager loads the sibling UI companion itself in embedded mode.
        if runtime_mode == #embedded then return true

        if not(this.loadFrontend()) then
        (
            if runtime_mode == #standalone then
            (
                messageBox startup_error title:"Vertex Cleaner - Startup Error"
            )
            return false
        )

        if runtime_mode == #library then return true

        if runtime_mode != #standalone then
        (
            return this.failStartup ("unsupported runtime mode: " + (runtime_mode as string))
        )

        if TwoEdgeVertsUI == undefined then
        (
            return this.failStartup "frontend API is unavailable after load."
        )

        show_ok = TwoEdgeVertsUI.showUI()

        if not(show_ok) then
        (
            return false
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
