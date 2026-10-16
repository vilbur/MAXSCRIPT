/*
Reusable tool title button helper for MaxScript dialogs and docked tool UIs.
The tool title button uses the production host appearance and LMB restart pattern.
*/

struct ToolTitleButton_v
(
    file_version = "0.05",

    /*
    Applies the canonical tool title button appearance and tool-name label.
    */
    function setupToolTitleButton button_control tool_name =
    (
        if button_control == undefined then return false
        if tool_name == undefined or tool_name == "" then return false

        local color_class = dotNetClass "System.Drawing.Color"
        local flat_style_class = dotNetClass "System.Windows.Forms.FlatStyle"
        local dark_color = color_class.FromArgb 45 45 48
        local title_color = color_class.FromArgb 62 158 255
        local current_font = button_control.Font

        button_control.Text = tool_name
        button_control.UseVisualStyleBackColor = false
        button_control.FlatStyle = flat_style_class.Flat
        button_control.AutoSize = false
        button_control.TabStop = false

        button_control.BackColor = dark_color
        button_control.ForeColor = title_color

        button_control.FlatAppearance.BorderSize = 0
        button_control.FlatAppearance.BorderColor = dark_color
        button_control.FlatAppearance.MouseOverBackColor = dark_color
        button_control.FlatAppearance.MouseDownBackColor = dark_color

        button_control.height = 18

        if current_font != undefined then
        (
            button_control.Font = dotNetObject \
                "System.Drawing.Font" \
                current_font.FontFamily \
                (current_font.Size + 2.0) \
                current_font.Style
        )

        true
        -- return
    ),

    /*
    Resizes the tool title button to the full available width and standard 18 px height.
    */
    function resizeToolTitleButton button_control available_width =
    (
        if button_control == undefined then return false

        if available_width < 1 then available_width = 1

        button_control.width = available_width
        button_control.height = 18

        true
        -- return
    ),

    on create do
    (
    )
)

global ToolTitleButton
ToolTitleButton = ToolTitleButton_v()

/*
Restarts the owning tool through the shared reload helper.
The tool title button LMB action calls this function.
*/
function restartTool current_script file_prefix =
(
    if current_script == undefined or current_script == "" then return false
    if file_prefix == undefined or file_prefix == "" then return false

    ScriptReload.reloadLatest current_script file_prefix
    -- return
)
