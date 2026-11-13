/* Selection-History UI. File version 0.001; project version 0.001. */

global selection_history_dialog

rollout selection_history_dialog "Selection-History - v0.001" width:336 height:216
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" width:312 height:18 align:#center
    listbox lb_history "Recent scene selections" items:#() height:5 width:312 align:#center
    label lbl_help "Click an entry to reselect its object." align:#center

    /* Refreshes names without treating a UI update as a user selection. */
    function refreshHistoryList =
    (
        lb_history.items = selectionHistoryCore.getLabels()
        true
        -- return
    )

    on selection_history_dialog open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Selection-History"
        refreshHistoryList()
        selectionHistoryCore.recordSelection()
        refreshHistoryList()
        callbacks.removeScripts id:#SelectionHistoryChanged
        callbacks.addScript #selectionSetChanged "selectionHistoryOnChanged()" id:#SelectionHistoryChanged persistent:false
    )

    on selection_history_dialog close do
    (
        callbacks.removeScripts id:#SelectionHistoryChanged
    )

    on lb_history selected item_index do
    (
        if item_index > 0 then selectionHistoryCore.selectHistoryIndex item_index
    )

    on btn_tool_title Click sender event_args do
    (
        local current_script = getSourceFileName()
        if current_script != undefined and current_script != "" then restartTool current_script "Selection-History"
    )

    on selection_history_dialog resized dialog_size do
    (
        ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
    )
)

/* Selection-change callback entry with no reference to a stale UI instance. */
function selectionHistoryOnChanged =
(
    if selectionHistoryCore != undefined then selectionHistoryCore.recordSelection()
    if selection_history_dialog != undefined then
    (
        if isDialogOpen selection_history_dialog then selection_history_dialog.refreshHistoryList()
    )
    true
    -- return
)
