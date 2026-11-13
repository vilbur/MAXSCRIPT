/* Selection-History backend. File version 0.001; project version 0.001. */

global selectionHistoryCore

struct SelectionHistoryCore_v
(
    file_version = "0.001",
    project_version = "0.001",
    history_nodes = #(),
    max_items = 5,
    suppress_record = false,

    /* Removes deleted scene nodes and preserves their order. */
    function pruneHistory =
    (
        local kept_nodes = for history_node in history_nodes where isValidNode history_node collect history_node
        history_nodes = kept_nodes
        history_nodes.count
        -- return
    ),

    /* Records the currently selected single object, newest first. */
    function recordSelection =
    (
        if not suppress_record then
        (
            pruneHistory()
            if selection.count == 1 then
            (
                local current_node = selection[1]
                if isValidNode current_node then
                (
                    local kept_nodes = for history_node in history_nodes where history_node != current_node collect history_node
                    insertItem current_node kept_nodes 1
                    if kept_nodes.count > max_items then kept_nodes.count = max_items
                    history_nodes = kept_nodes
                )
            )
        )
        history_nodes.count
        -- return
    ),

    /* Selects a valid node without promoting it to the top of history. */
    function selectHistoryIndex history_index =
    (
        pruneHistory()
        local operation_ok = history_index >= 1 and history_index <= history_nodes.count
        if operation_ok then
        (
            local target_node = history_nodes[history_index]
            suppress_record = true
            try
            (
                select target_node
            )
            catch
            (
                local exception_text = getCurrentException()
                format "Selection-History select failed | index:% node:% error:%\n" history_index target_node exception_text
                operation_ok = false
            )
            suppress_record = false
        )
        operation_ok
        -- return
    ),

    /* Returns up to five currently valid names for the list. */
    function getLabels =
    (
        pruneHistory()
        for history_node in history_nodes collect history_node.name
        -- return
    ),

    on create do
    (
    )
)

selectionHistoryCore = SelectionHistoryCore_v()
