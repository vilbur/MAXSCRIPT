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
            local version_parts = filterString version_text "-"

            if version_parts.count > 0 then
            (
                local parsed_version = version_parts[1] as float

                if parsed_version != undefined then
                (
                    version_value = parsed_version
                )
            )
        )

        version_value
        -- return
    ),

    /*
    Reports whether a versioned script is the preferred -LATEST alias.
    */
    function isLatestVersionAlias file_path =
    (
        local file_name = getFilenameFile file_path
        local is_latest = matchPattern file_name pattern:"*-LATEST" ignoreCase:true

        is_latest
        -- return
    ),

    /*
    Finds the newest matching versioned script in the current script directory.
    */
    function findNewestVersionedScript current_script file_prefix =
    (
        local newest_file = current_script
        local newest_version = -1.0

        if current_script != undefined and current_script != "" then
        (
            local script_dir = getFilenamePath current_script
            local candidate_files = getFiles (script_dir + file_prefix + "_*.ms")

            newest_version = getFileVersion current_script file_prefix

            for candidate_file in candidate_files do
            (
                local candidate_version = getFileVersion candidate_file file_prefix

                if candidate_version > newest_version then
                (
                    newest_version = candidate_version
                    newest_file = candidate_file
                )
                else if candidate_version == newest_version and candidate_version >= 0.0 then
                (
                    if isLatestVersionAlias candidate_file and not isLatestVersionAlias newest_file then
                    (
                        newest_file = candidate_file
                    )
                )
            )
        )

        newest_file
        -- return
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
        -- return
    ),

    on create do
    (
    )
)

global ScriptReload
ScriptReload = ScriptReload_v()
