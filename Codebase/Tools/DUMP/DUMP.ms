/*
Reusable DEV-only logger for MaxScript projects.
The caller supplies the repository-local dump-file path explicitly.
*/
struct DumpDevLoggerStruct
(
    dump_file = undefined,
    enabled = true,
    started = false,

    /*
    Creates/truncates the dump file for a new logical tool run.
    Returns true when the logger is ready.
    */
    function start dump_file_path =
    (
        if dump_file_path == undefined then return false
        if classOf dump_file_path != String then return false
        if dump_file_path == "" then return false

        local dump_dir = getFilenamePath dump_file_path

        if dump_dir != "" and not doesDirectoryExist dump_dir then
        (
            if not makeDir dump_dir all:true then return false
        )

        local dump_stream = createFile dump_file_path encoding:#utf8 writeBOM:false
        if dump_stream == undefined then return false

        close dump_stream

        dump_file = dump_file_path
        started = true
        true
    ),

    /*
    Clears the current dump file without changing its configured path.
    Returns true when the file was cleared.
    */
    function clear =
    (
        if dump_file == undefined then return false
        if dump_file == "" then return false

        local dump_stream = createFile dump_file encoding:#utf8 writeBOM:false
        if dump_stream == undefined then return false

        close dump_stream
        true
    ),

    /*
    Writes the same line to the 3ds Max Listener and the dump file.
    Returns true when the line was written to both destinations.
    */
    function log value =
    (
        if not enabled then return false
        if not started then return false
        if dump_file == undefined then return false

        local line = value as string
        local dump_stream = openFile dump_file mode:"a" encoding:#utf8 writeBOM:false

        if dump_stream == undefined then return false

        format "%\n" line
        format "%\n" line to:dump_stream
        close dump_stream

        true
    )
)
