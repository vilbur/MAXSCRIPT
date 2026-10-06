/*
Generic script reload helper for F1 UI reload behavior.
This file belongs to the UI infrastructure layer.
*/

struct ScriptReload_v
(
    /*
    Extracts a numeric version suffix from <prefix>_<version>.ms.
    */
    function getFileVersion file_path file_prefix =
    (
        local file_name = getFilenameFile file_path
        local prefix_text = file_prefix + "_"
        local version_value = -1.0

        if matchPattern file_name pattern:(prefix_text + "*") ignoreCase:true then
        (
            local version_text = substring file_name (prefix_text.count + 1) (file_name.count - prefix_text.count)
            version_value = try (version_text as float) catch (-1.0)
        )

        version_value
    ),

    /*
    Finds the newest matching versioned script in the current script directory.
    */
    function findNewestVersionedScript current_script file_prefix =
    (
        local newest_file = current_script

        if current_script != undefined and current_script != "" then
        (
            local script_dir = getFilenamePath current_script
            local candidate_files = getFiles (script_dir + file_prefix + "_*.ms")
            local newest_version = getFileVersion current_script file_prefix

            for candidate_file in candidate_files do
            (
                local candidate_version = getFileVersion candidate_file file_prefix

                if candidate_version > newest_version then
                (
                    newest_version = candidate_version
                    newest_file = candidate_file
                )
            )
        )

        newest_file
    ),

    /*
    Reloads the newest matching versioned script or the current script as fallback.
    */
    function reloadLatest current_script file_prefix =
    (
        local target_file = findNewestVersionedScript current_script file_prefix
        local loaded = false

        if target_file != undefined and target_file != "" and doesFileExist target_file then
        (
            fileIn target_file
            loaded = true
        )

        loaded
    ),

    on create do
    (
    )
)

global ScriptReload
ScriptReload = ScriptReload_v()
