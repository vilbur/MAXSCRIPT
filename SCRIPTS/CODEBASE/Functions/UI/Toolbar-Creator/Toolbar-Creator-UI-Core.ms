/*
Toolbar-Creator UI core 0.21 | project 0.37.
Dialog for browsing script sources and managing toolbars through the independent backend.

Run Toolbar-Creator.ms or Toolbar-Creator-UI.ms to open this dialog safely.
This core implementation must not be executed directly while the dialog is open.
Evaluating Toolbar-Creator-FN.ms alone remains backend-only.
*/

global toolbarCreatorUiCoreFileVersion
global toolbarCreatorUiProjectVersion
global toolbarCreatorProjectVersion
global toolbarCreatorUiFrameworkDir
global toolbar_creator_ui_source_file
global toolbar_creator_ui_ini_path
global toolbar_creator_ui_buttons
global toolbar_creator_ui_managed_records
global toolbar_creator_ui_caption
global toolbarCreatorRestartTimer
global toolbarCreatorRestartPhase
global toolbarCreatorRestartTarget
global toolbarCreatorUiFileLogTooltip
global toolbar_creator_ui_min_height

toolbarCreatorUiCoreFileVersion = 0.21
toolbarCreatorUiProjectVersion = 0.37
toolbar_creator_ui_min_height = (amax (560 + 24) (558 + 20)) + 16

toolbar_creator_ui_source_file = getSourceFileName()
if toolbar_creator_ui_source_file == undefined or toolbar_creator_ui_source_file == "" then
(
    throw "Toolbar-Creator UI must be loaded from a saved .ms file."
)

toolbar_creator_ui_directory = getFilenamePath toolbar_creator_ui_source_file
toolbar_creator_ui_backend_path = toolbar_creator_ui_directory + "Toolbar-Creator-FN.ms"

if not doesFileExist toolbar_creator_ui_backend_path then
(
    throw ("Missing Toolbar-Creator backend: " + toolbar_creator_ui_backend_path)
)

fileIn toolbar_creator_ui_backend_path quiet:true

if toolbarCreatorProjectVersion == undefined or toolbarCreatorProjectVersion < toolbarCreatorUiProjectVersion then
(
    toolbarCreatorProjectVersion = toolbarCreatorUiProjectVersion
)

/*
The shared UI helpers live in the canonical MaxScript agent UI framework.
Override this global before loading the UI if your local Drive mount differs.
*/
if toolbarCreatorUiFrameworkDir == undefined or toolbarCreatorUiFrameworkDir == "" then
(
    toolbarCreatorUiFrameworkDir = @"G:\AI\AGENTS\Maxscript\UI\Default\"
)

if (substring toolbarCreatorUiFrameworkDir toolbarCreatorUiFrameworkDir.count 1) != "\\" then
(
    toolbarCreatorUiFrameworkDir += "\\"
)

toolbar_creator_ui_helpers = #("IniSettings.ms", "RolloutState.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms")

for helper_name in toolbar_creator_ui_helpers do
(
    helper_path = toolbarCreatorUiFrameworkDir + helper_name
    if not doesFileExist helper_path then
    (
        throw ("Missing canonical UI helper: " + helper_path)
    )
    fileIn helper_path quiet:true
)

toolbar_creator_ui_ini_path = toolbar_creator_ui_directory + "Toolbar-Creator-UI.ini"
toolbar_creator_ui_buttons = #()
toolbar_creator_ui_managed_records = #()
toolbar_creator_ui_caption = "Toolbar-Creator - v" + (toolbarCreatorProjectVersion as string)

/*
The restart timer and its callback live outside the rollout. Never fileIn or
destroy the dialog from a .NET control's own Click handler.
*/
function toolbarCreatorStopRestartTimer =
(
    if toolbarCreatorRestartTimer != undefined then
    (
        toolbarCreatorRestartTimer.Stop()
        dotNet.removeAllEventHandlers toolbarCreatorRestartTimer
        toolbarCreatorRestartTimer.Dispose()
        toolbarCreatorRestartTimer = undefined
    )
    toolbarCreatorRestartPhase = #idle
    true
    -- return
)

function toolbarCreatorRestartTick sender event_args =
(
    try
    (
        if toolbarCreatorRestartTimer != undefined then toolbarCreatorRestartTimer.Stop()

        if toolbarCreatorRestartPhase == #close then
        (
            local close_ok = true
            if isKindOf toolbarCreatorUiRollout RolloutClass then
            (
                if toolbarCreatorUiRollout.isDisplayed then
                (
                    try (destroyDialog toolbarCreatorUiRollout) catch ()
                )
                close_ok = not toolbarCreatorUiRollout.isDisplayed
            )
            if close_ok then
            (
                toolbarCreatorRestartPhase = #reload
                toolbarCreatorRestartTimer.Start()
            )
            else
            (
                format "[Toolbar-Creator UI] Restart cancelled: could not close the old dialog.\n"
                toolbarCreatorStopRestartTimer()
            )
        )
        else if toolbarCreatorRestartPhase == #reload then
        (
            local rollout_visible = false
            if isKindOf toolbarCreatorUiRollout RolloutClass then
            (
                rollout_visible = toolbarCreatorUiRollout.isDisplayed
            )

            if rollout_visible then
            (
                format "[Toolbar-Creator UI] Restart cancelled: previous rollout is still displayed.\n"
                toolbarCreatorStopRestartTimer()
            )
            else
            (
                local launch_script_path = toolbarCreatorRestartTarget
                toolbarCreatorStopRestartTimer()

                if launch_script_path != undefined and doesFileExist launch_script_path then
                (
                    format "[Toolbar-Creator UI] Reloading latest scripts from disk: %\n" launch_script_path
                    fileIn launch_script_path quiet:true
                )
                else
                (
                    format "[Toolbar-Creator UI] Restart failed: launcher not found: %\n" launch_script_path
                )
            )
        )
        else
        (
            toolbarCreatorStopRestartTimer()
        )
    )
    catch
    (
        format "[Toolbar-Creator UI] Restart error: %\n" (getCurrentException())
        toolbarCreatorStopRestartTimer()
    )
)

function toolbarCreatorRequestRestart =
(
    local queued = false
    local launch_script_path = (getFilenamePath toolbar_creator_ui_source_file) + "Toolbar-Creator.ms"

    if toolbarCreatorRestartTimer != undefined then
    (
        format "[Toolbar-Creator UI] A restart is already queued.\n"
        queued = true
    )
    else if not doesFileExist launch_script_path then
    (
        format "[Toolbar-Creator UI] Cannot restart; launcher missing: %\n" launch_script_path
    )
    else
    (
        toolbarCreatorRestartTarget = launch_script_path
        toolbarCreatorRestartPhase = #close
        toolbarCreatorRestartTimer = dotNetObject "System.Windows.Forms.Timer"
        toolbarCreatorRestartTimer.Interval = 80
        dotNet.addEventHandler toolbarCreatorRestartTimer "Tick" toolbarCreatorRestartTick
        toolbarCreatorRestartTimer.Start()
        queued = true
    )

    queued
    -- return
)

/*
Save position and height for a floating, non-dockable dialog.
*/
function toolbarCreatorSaveFloatingDialogState =
(
    local dialog_pos = try (getDialogPos toolbarCreatorUiRollout) catch (undefined)
    if dialog_pos != undefined then
    (
        IniSettings.setPoint2 toolbar_creator_ui_ini_path "MainUI" "PosX" "PosY" dialog_pos
    )
    local dialog_height = try (toolbarCreatorUiRollout.height) catch (undefined)
    if dialog_height != undefined then
    (
        IniSettings.setInteger toolbar_creator_ui_ini_path "MainUI" "Height" (amax toolbar_creator_ui_min_height dialog_height)
    )
    true
    -- return
)

rollout toolbarCreatorUiRollout toolbar_creator_ui_caption width:1024 height:600
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:1000 height:20

    /* Left: managed toolbars. Right: the complete toolbar configuration. */
    label lbl_managed_toolbars "Managed Toolbars" pos:[12,48] width:238 height:16
    dotNetControl lst_managed_toolbars "System.Windows.Forms.ListBox" pos:[12,72] width:238 height:396
    dotNetControl btn_create "System.Windows.Forms.Button" pos:[12,480] width:112 height:28
    dotNetControl btn_update "System.Windows.Forms.Button" pos:[136,480] width:114 height:28
    dotNetControl btn_rename "System.Windows.Forms.Button" pos:[12,520] width:112 height:28
    dotNetControl btn_delete "System.Windows.Forms.Button" pos:[136,520] width:114 height:28
    checkbox chk_save_ui "Save UI" pos:[12,560] width:112 height:24 checked:true tooltip:"Keep the toolbar in your active CUIX after restarting 3ds Max."
    checkbox chk_show_toolbar "Show Toolbar" pos:[136,560] width:114 height:24 checked:true tooltip:"Show the toolbar immediately after integration."

    label lbl_config "Toolbar Config" pos:[276,48] width:736 height:16
    edittext edt_toolbar_name "Toolbar" pos:[276,76] width:736 height:24 text:""

    button btn_add_folder "Add Folder" pos:[276,112] width:112 height:28 tooltip:"Include .ms files from the selected folder and every subfolder."
    button btn_add_files "Add Files" pos:[396,112] width:98 height:28 tooltip:"Select multiple individual .ms files."
    button btn_clear "Clear List" pos:[502,112] width:88 height:28 tooltip:"Remove every proposed toolbar button after confirmation."
    button btn_up "Up" pos:[598,112] width:56 height:28 tooltip:"Move the selected button earlier in the toolbar."
    button btn_down "Down" pos:[662,112] width:64 height:28 tooltip:"Move the selected button later in the toolbar."
    button btn_remove "Remove" pos:[734,112] width:92 height:28 tooltip:"Remove the selected button without deleting its script."
    button btn_customize_toolbars "Customize Toolbars" pos:[834,112] width:178 height:28 tooltip:"Open 3ds Max Customize User Interface to edit toolbars."

    label lbl_scripts "Scripts" pos:[276,150] width:736 height:16
    dotNetControl lst_scripts "System.Windows.Forms.ListView" pos:[276,170] width:736 height:300

    edittext edt_button_label "Button Text" pos:[276,482] width:356 height:24 text:""
    edittext edt_button_tooltip "Tooltip" pos:[644,482] width:368 height:24 text:""

    label lbl_status "" pos:[276,526] width:736 height:24
    dotNetControl lbl_ui_file_log "System.Windows.Forms.Label" pos:[276,558] width:736 height:20

    /*
    Measures the last control on each side, leaving a 16 px bottom margin.
    Native MAXScript checkbox controls do not expose a height property.
    */
    function getToolbarDialogContentHeight =
    (
        left_bottom = chk_show_toolbar.pos.y + 24
        right_bottom = lbl_ui_file_log.pos.y + lbl_ui_file_log.height
        (amax left_bottom right_bottom) + 16
        -- return
    )

    /*
    Sets the shared dark WinForms action-button style with semantic text colors.
    Create/Update are green; Rename/Delete are orange.
    */
    function setupToolbarActionButtons =
    (
        color_type = dotNetClass "System.Drawing.Color"
        flat_style_type = dotNetClass "System.Windows.Forms.FlatStyle"
        font_style_type = dotNetClass "System.Drawing.FontStyle"

        for action_button in #(btn_create, btn_update, btn_rename, btn_delete) do
        (
            action_button.UseVisualStyleBackColor = false
            action_button.FlatStyle = flat_style_type.Flat
            action_button.BackColor = color_type.FromArgb 68 68 68
            action_button.ForeColor = color_type.FromArgb 190 190 190
            action_button.FlatAppearance.BorderColor = color_type.FromArgb 120 120 120
            action_button.FlatAppearance.BorderSize = 1
            action_button.FlatAppearance.MouseOverBackColor = color_type.FromArgb 78 78 78
            action_button.FlatAppearance.MouseDownBackColor = color_type.FromArgb 55 55 55
            action_button.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 9.0 font_style_type.Bold
        )

        btn_create.Text = "Create"
        btn_update.Text = "Update"
        btn_rename.Text = "Rename"
        btn_delete.Text = "Delete"
        btn_create.ForeColor = color_type.FromArgb 120 210 130
        btn_update.ForeColor = color_type.FromArgb 120 210 130
        btn_rename.ForeColor = color_type.FromArgb 230 165 75
        btn_delete.ForeColor = color_type.FromArgb 230 165 75
        true
        -- return
    )

    /*
    Shows the INI, generated MacroScript and active CUIX locations on one line.
    The hover tooltip contains the complete paths when the label is truncated.
    */
    function updateSavedFileInfo =
    (
        toolbar_name = trimLeft (trimRight edt_toolbar_name.text)
        macro_path = "(enter toolbar name)"
        if toolbar_name != "" then macro_path = toolbarCreatorGetGeneratedMacroPath toolbar_name undefined

        active_cuix_path = toolbarCreatorGetActiveCuixPath()
        if active_cuix_path == "" then active_cuix_path = "(unavailable)"

        cuix_mode = "Save UI ON: saved on Create / Update / Delete"
        if not chk_save_ui.checked then cuix_mode = "Save UI OFF: temporary session UI"

        file_log_text = "INI: " + toolbar_creator_ui_ini_path + " | MCR: " + macro_path + " | CUIX: " + active_cuix_path
        lbl_ui_file_log.Text = file_log_text
        if toolbarCreatorUiFileLogTooltip != undefined then
        (
            full_log_text = "Dialog state: " + toolbar_creator_ui_ini_path + "\r\n" + \
                "Toolbar macro: " + macro_path + "\r\n" + \
                "Active UI (" + cuix_mode + "): " + active_cuix_path
            toolbarCreatorUiFileLogTooltip.SetToolTip lbl_ui_file_log full_log_text
        )
        true
        -- return
    )

    /*
    Returns the selected toolbar-button position as a 1-based Integer.
    Returns zero when there is no selection.
    */
    function getSelectedButtonIndex =
    (
        selected_index = 0
        if lst_scripts.SelectedItems.Count > 0 then
        (
            selected_index = lst_scripts.SelectedItems.Item[0].Index + 1
        )
        selected_index
        -- return
    )

    /*
    Displays an informative status without interrupting normal editing.
    */
    function showToolbarStatus status_text =
    (
        lbl_status.text = status_text
        format "[Toolbar-Creator UI] %\n" status_text
        true
        -- return
    )

    /*
    Reads native toolbar names using the verified v0.17 live synchronization API.
    Resolves unique signatures without showing stale native-rename aliases.
    */
    function getLiveManagedToolbarRecords =
    (
        local native_names = listManagedScriptToolbars sync_live:true
        local live_records = undefined
        if classOf native_names == Array then
        (
            local saved_records = getManagedScriptToolbarRecords()
            if classOf saved_records == Array then
            (
                local unique_records = toolbarCreatorFilterRenamedRecords saved_records
                live_records = #()
                for native_name in native_names do
                (
                    local matched_record = undefined
                    for record in unique_records while matched_record == undefined do
                    (
                        if record[1] == native_name then matched_record = record
                    )
                    if matched_record != undefined then append live_records matched_record
                )
                if live_records.count != native_names.count then
                (
                    format "[Toolbar-Creator UI] FAILED | Live name/signature mismatch | names:% | records:%\n" native_names.count live_records.count
                    live_records = undefined
                )
            )
        )
        live_records
        -- return
    )

    /*
    Rebuilds native toolbar names after syncing the active 3ds Max CUIX.
    Keeps only the newest name for each stable action signature.
    */
    function refreshManagedToolbarList select_toolbar_name:undefined select_toolbar_signature:undefined live_records:undefined =
    (
        managed_records = live_records
        if managed_records == undefined then managed_records = getLiveManagedToolbarRecords()
        list_loaded = (classOf managed_records == Array)
        if list_loaded then
        (
            selected_toolbar_name = ""
            selected_signature = ""
            selected_object_name = ""
            previous_index = lst_managed_toolbars.SelectedIndex
            if select_toolbar_name != undefined then selected_toolbar_name = select_toolbar_name
            if select_toolbar_signature != undefined then selected_signature = select_toolbar_signature

            if previous_index >= 0 then
            (
                if selected_toolbar_name == "" then selected_toolbar_name = lst_managed_toolbars.SelectedItem as string
                if previous_index < toolbar_creator_ui_managed_records.count then
                (
                    previous_record = toolbar_creator_ui_managed_records[previous_index + 1]
                    if selected_signature == "" then selected_signature = previous_record[3]
                    selected_object_name = previous_record[2]
                )
            )

            matched_index = -1
            for record_index = 1 to managed_records.count do
            (
                record = managed_records[record_index]
                if matched_index < 0 and selected_signature != "" and record[3] == selected_signature then matched_index = record_index - 1
            )
            if matched_index < 0 then
            (
                for record_index = 1 to managed_records.count do
                (
                    record = managed_records[record_index]
                    if matched_index < 0 and selected_object_name != "" and record[2] == selected_object_name then matched_index = record_index - 1
                )
            )
            if matched_index < 0 then
            (
                for record_index = 1 to managed_records.count do
                (
                    record = managed_records[record_index]
                    if matched_index < 0 and selected_toolbar_name != "" and record[1] == selected_toolbar_name then matched_index = record_index - 1
                )
            )

            lst_managed_toolbars.BeginUpdate()
            lst_managed_toolbars.Items.Clear()
            toolbar_creator_ui_managed_records = managed_records
            for record in managed_records do lst_managed_toolbars.Items.Add record[1]
            lst_managed_toolbars.EndUpdate()
            lst_managed_toolbars.SelectedIndex = matched_index
        )
        else
        (
            showToolbarStatus "Unable to read saved managed toolbars; see Listener."
        )
        list_loaded
        -- return
    )

    /*
    Synchronizes current native names, then compares visible managed records.
    Avoids replacing in-progress UI edits when no native toolbar changed.
    */
    function syncManagedToolbarNames =
    (
        changed = false
        managed_records = getLiveManagedToolbarRecords()
        if classOf managed_records == Array then
        (
            changed = (managed_records.count != toolbar_creator_ui_managed_records.count)
            if not changed then
            (
                for record_index = 1 to managed_records.count while not changed do
                (
                    old_record = toolbar_creator_ui_managed_records[record_index]
                    new_record = managed_records[record_index]
                    if old_record[1] != new_record[1] or old_record[2] != new_record[2] or old_record[3] != new_record[3] then changed = true
                )
            )
            if changed then
            (
                refreshManagedToolbarList live_records:managed_records
                if lst_managed_toolbars.SelectedIndex < 0 and lst_managed_toolbars.Items.Count > 0 then
                (
                    lst_managed_toolbars.SelectedIndex = 0
                )
                showToolbarStatus "Managed toolbars synchronized with native 3ds Max UI."
            )
        )
        changed
        -- return
    )

    /*
    Rebuilds the preview list while preserving the requested selection.
    */
    function refreshToolbarPreview preferred_index:0 =
    (
        missing_path_color = (dotNetClass "System.Drawing.Color").FromArgb 255 95 95
        lst_scripts.BeginUpdate()
        lst_scripts.Items.Clear()

        for button_record in toolbar_creator_ui_buttons do
        (
            list_item = dotNetObject "System.Windows.Forms.ListViewItem" button_record[2]
            list_item.SubItems.Add button_record[1]
            resolved_script_path = toolbarCreatorResolveScriptPath button_record[1]
            if resolved_script_path == undefined or not doesFileExist resolved_script_path then
            (
                list_item.UseItemStyleForSubItems = false
                list_item.SubItems.Item[1].ForeColor = missing_path_color
            )
            lst_scripts.Items.Add list_item
        )

        lst_scripts.EndUpdate()

        if toolbar_creator_ui_buttons.count > 0 then
        (
            if preferred_index < 1 then preferred_index = 1
            if preferred_index > toolbar_creator_ui_buttons.count then preferred_index = toolbar_creator_ui_buttons.count
            lst_scripts.Items.Item[preferred_index - 1].Selected = true
            lst_scripts.Items.Item[preferred_index - 1].Focused = true
            lst_scripts.EnsureVisible (preferred_index - 1)
        )
        else
        (
            edt_button_label.text = ""
            edt_button_tooltip.text = ""
        )

        true
        -- return
    )

    /*
    Appends new source records without introducing duplicate script paths.
    */
    function mergeToolbarButtons additional_buttons =
    (
        if classOf additional_buttons != Array then
        (
            showToolbarStatus "Unable to collect script paths; see Listener."
            false
        )
        else
        (
            added_count = 0

            for new_button in additional_buttons do
            (
                new_button[1] = toolbarCreatorToPortablePath new_button[1]
                already_present = false

                for old_button in toolbar_creator_ui_buttons while not already_present do
                (
                    if (toLower (toolbarCreatorToPortablePath old_button[1])) == (toLower new_button[1]) then already_present = true
                )

                if not already_present then
                (
                    append toolbar_creator_ui_buttons new_button
                    added_count += 1
                )
            )

            refreshToolbarPreview preferred_index:toolbar_creator_ui_buttons.count
            showToolbarStatus ((added_count as string) + " script(s) added. " + (toolbar_creator_ui_buttons.count as string) + " total.")
            true
        )
        -- return
    )

    /*
    Applies the label and tooltip currently typed for the selected record.
    */
    function applyCurrentButtonText =
    (
        selected_index = getSelectedButtonIndex()
        updated = false

        if selected_index > 0 then
        (
            label_text = trimLeft (trimRight edt_button_label.text)

            if label_text != "" then
            (
                toolbar_creator_ui_buttons[selected_index][2] = label_text
                toolbar_creator_ui_buttons[selected_index][3] = edt_button_tooltip.text
                refreshToolbarPreview preferred_index:selected_index
                updated = true
            )
            else
            (
                showToolbarStatus "Button text cannot be empty."
            )
        )

        updated
        -- return
    )

    /*
    Saves the curated button records and editable UI options beside the script.
    */
    function saveToolbarUiState =
    (
        if getSelectedButtonIndex() > 0 then applyCurrentButtonText()

        RolloutState.saveEditText edt_toolbar_name toolbar_creator_ui_ini_path "MainUI" "ToolbarName"
        RolloutState.saveCheckbox chk_save_ui toolbar_creator_ui_ini_path "MainUI" "SaveUI"
        RolloutState.saveCheckbox chk_show_toolbar toolbar_creator_ui_ini_path "MainUI" "ShowToolbar"
        selected_toolbar_name = ""
        if lst_managed_toolbars.SelectedIndex >= 0 then
        (
            selected_toolbar_name = lst_managed_toolbars.SelectedItem as string
        )
        IniSettings.setString toolbar_creator_ui_ini_path "MainUI" "SelectedToolbar" selected_toolbar_name
        selected_signature = ""
        if lst_managed_toolbars.SelectedIndex >= 0 and (lst_managed_toolbars.SelectedIndex + 1) <= toolbar_creator_ui_managed_records.count then
        (
            selected_signature = toolbar_creator_ui_managed_records[lst_managed_toolbars.SelectedIndex + 1][3]
        )
        IniSettings.setString toolbar_creator_ui_ini_path "MainUI" "SelectedToolbarSignature" selected_signature

        old_count = IniSettings.getInteger toolbar_creator_ui_ini_path "Buttons" "Count" default_value:0
        if old_count < 0 or old_count > 10000 then old_count = 0
        IniSettings.setInteger toolbar_creator_ui_ini_path "Buttons" "Count" toolbar_creator_ui_buttons.count

        for button_index = 1 to toolbar_creator_ui_buttons.count do
        (
            prefix_text = "Button" + (button_index as string)
            button_record = toolbar_creator_ui_buttons[button_index]
            IniSettings.setString toolbar_creator_ui_ini_path "Buttons" (prefix_text + "Path") (toolbarCreatorToPortablePath button_record[1])
            IniSettings.setString toolbar_creator_ui_ini_path "Buttons" (prefix_text + "Text") button_record[2]
            IniSettings.setString toolbar_creator_ui_ini_path "Buttons" (prefix_text + "Tooltip") button_record[3]
        )

        if old_count > toolbar_creator_ui_buttons.count then
        (
            for button_index = (toolbar_creator_ui_buttons.count + 1) to old_count do
            (
                prefix_text = "Button" + (button_index as string)
                IniSettings.setString toolbar_creator_ui_ini_path "Buttons" (prefix_text + "Path") ""
                IniSettings.setString toolbar_creator_ui_ini_path "Buttons" (prefix_text + "Text") ""
                IniSettings.setString toolbar_creator_ui_ini_path "Buttons" (prefix_text + "Tooltip") ""
            )
        )

        true
        -- return
    )

    /*
    Browses for a replacement .ms path for one script button.
    Keeps the existing button text and tooltip; Update applies the path to 3ds Max.
    */
    function browseToolbarScriptPath button_index =
    (
        changed = false

        if button_index >= 1 and button_index <= toolbar_creator_ui_buttons.count then
        (
            old_script_path = toolbar_creator_ui_buttons[button_index][1]
            resolved_script_path = toolbarCreatorResolveScriptPath old_script_path
            script_directory = getFilenamePath resolved_script_path
            if script_directory == "" or not doesDirectoryExist script_directory then
            (
                script_directory = getDir #userScripts
            )

            file_dialog = dotNetObject "System.Windows.Forms.OpenFileDialog"
            dialog_result_type = dotNetClass "System.Windows.Forms.DialogResult"
            file_dialog.Title = "Choose script for toolbar button"
            file_dialog.Filter = "MaxScript (*.ms)|*.ms"
            file_dialog.Multiselect = false
            file_dialog.CheckFileExists = true
            file_dialog.InitialDirectory = script_directory
            if doesFileExist resolved_script_path then file_dialog.FileName = resolved_script_path

            if file_dialog.ShowDialog() == dialog_result_type.OK then
            (
                chosen_script_path = file_dialog.FileName as string
                if not doesFileExist chosen_script_path or (toLower (getFilenameType chosen_script_path)) != ".ms" then
                (
                    showToolbarStatus ("Select an existing .ms file: " + chosen_script_path)
                )
                else
                (
                    portable_script_path = toolbarCreatorToPortablePath chosen_script_path
                    already_used = false
                    for other_index = 1 to toolbar_creator_ui_buttons.count while not already_used do
                    (
                        if other_index != button_index then
                        (
                            other_script_path = toolbarCreatorToPortablePath toolbar_creator_ui_buttons[other_index][1]
                            if (toLower other_script_path) == (toLower portable_script_path) then already_used = true
                        )
                    )

                    if already_used then
                    (
                        showToolbarStatus ("Script path is already in this toolbar: " + portable_script_path)
                    )
                    else
                    (
                        toolbar_creator_ui_buttons[button_index][1] = portable_script_path
                        refreshToolbarPreview preferred_index:button_index
                        saveToolbarUiState()
                        next_action = "Create"
                        if lst_managed_toolbars.SelectedIndex >= 0 then next_action = "Update"
                        showToolbarStatus ("Script path changed: " + portable_script_path + ". Click " + next_action + " to apply it to the toolbar.")
                        changed = true
                    )
                )
            )
            file_dialog.Dispose()
        )

        changed
        -- return
    )

    /*
    Starts a clean toolbar draft without changing any saved 3ds Max toolbar.
    The current Windows username is the proposed toolbar name.
    */
    function resetNewToolbarDraft =
    (
        lst_managed_toolbars.SelectedIndex = -1
        toolbar_creator_ui_buttons = #()
        refreshToolbarPreview()

        username_text = systemTools.getEnvVariable "USERNAME"
        if username_text == undefined or username_text == "" then username_text = sysInfo.username
        if username_text == undefined then username_text = ""
        edt_toolbar_name.text = username_text

        saveToolbarUiState()
        updateSavedFileInfo()
        setFocus edt_toolbar_name
        true
        -- return
    )

    /*
    Restores persisted controls only; actual scripts come from the selected toolbar.
    */
    function loadToolbarUiState =
    (
        RolloutState.loadEditText edt_toolbar_name toolbar_creator_ui_ini_path "MainUI" "ToolbarName" default_value:""
        RolloutState.loadCheckbox chk_save_ui toolbar_creator_ui_ini_path "MainUI" "SaveUI" default_value:true
        RolloutState.loadCheckbox chk_show_toolbar toolbar_creator_ui_ini_path "MainUI" "ShowToolbar" default_value:true

        toolbar_creator_ui_buttons = #()
        refreshToolbarPreview()
        true
        -- return
    )

    /*
    Moves the selected toolbar button exactly one position in the given direction.
    */
    function moveSelectedButton index_offset =
    (
        selected_index = getSelectedButtonIndex()
        target_index = selected_index + index_offset
        moved = false

        if selected_index > 0 and target_index >= 1 and target_index <= toolbar_creator_ui_buttons.count then
        (
            applyCurrentButtonText()
            previous_button = toolbar_creator_ui_buttons[target_index]
            toolbar_creator_ui_buttons[target_index] = toolbar_creator_ui_buttons[selected_index]
            toolbar_creator_ui_buttons[selected_index] = previous_button
            refreshToolbarPreview preferred_index:target_index
            moved = true
        )

        moved
        -- return
    )

    /*
    Creates, replaces, or deletes the toolbar using the existing backend API.
    */
    function executeToolbarAction operation =
    (
        toolbar_name = trimLeft (trimRight edt_toolbar_name.text)
        action_ok = true

        if operation == #delete then
        (
            if lst_managed_toolbars.SelectedIndex >= 0 then
            (
                toolbar_name = lst_managed_toolbars.SelectedItem as string
            )
            else
            (
                showToolbarStatus "Select an existing managed toolbar to delete."
                action_ok = false
            )
        )

        if action_ok and toolbar_name == "" then
        (
            showToolbarStatus "Enter a toolbar name first."
            action_ok = false
        )

        if action_ok and operation != #delete then
        (
            selected_index = getSelectedButtonIndex()
            if selected_index > 0 then action_ok = applyCurrentButtonText()

            if action_ok and toolbar_creator_ui_buttons.count == 0 then
            (
                showToolbarStatus "Add at least one .ms file first."
                action_ok = false
            )
        )

        if action_ok and operation == #delete then
        (
            action_ok = queryBox ("Delete toolbar '" + toolbar_name + "' from the 3ds Max UI?") title:"Toolbar-Creator"
        )

        if action_ok then
        (
            saveToolbarUiState()
            action_ok = manageScriptToolbar operation toolbar_name button_data:toolbar_creator_ui_buttons \
                macro_category:"Toolbar-Creator" \
                save_ui:chk_save_ui.checked \
                show_toolbar:chk_show_toolbar.checked

            if action_ok then
            (
                refreshManagedToolbarList()
                if operation == #create then
                (
                    resetNewToolbarDraft()
                    showToolbarStatus ("Created toolbar: " + toolbar_name + ". Ready for another toolbar.")
                )
                else if operation == #delete then
                (
                    resetNewToolbarDraft()
                    showToolbarStatus ("Deleted toolbar: " + toolbar_name)
                )
                else
                (
                    showToolbarStatus (((operation as string) + " completed for toolbar: " + toolbar_name))
                )
                updateSavedFileInfo()
            )
            else
            (
                showToolbarStatus ("Toolbar action failed; details are in Listener.")
            )
        )

        action_ok
        -- return
    )

    /*
    Renames the selected managed toolbar using the edited toolbar name.
    Keeps the current button data intact until the backend reports success.
    */
    function executeToolbarRename =
    (
        rename_ok = (lst_managed_toolbars.SelectedIndex >= 0)

        if not rename_ok then
        (
            showToolbarStatus "Select an existing managed toolbar to rename first."
        )
        else
        (
            old_toolbar_name = lst_managed_toolbars.SelectedItem as string
            new_toolbar_name = trimLeft (trimRight edt_toolbar_name.text)

            if new_toolbar_name == "" then
            (
                showToolbarStatus "Enter the new toolbar name first."
                rename_ok = false
            )
            else if (toLower old_toolbar_name) == (toLower new_toolbar_name) then
            (
                showToolbarStatus "Enter a different toolbar name to rename it."
                rename_ok = false
            )
        )

        if rename_ok then
        (
            selected_index = getSelectedButtonIndex()
            if selected_index > 0 then rename_ok = applyCurrentButtonText()

            if rename_ok and toolbar_creator_ui_buttons.count == 0 then
            (
                showToolbarStatus "Cannot rename a toolbar with an empty script list."
                rename_ok = false
            )
        )

        if rename_ok then
        (
            rename_ok = queryBox ("Rename toolbar '" + old_toolbar_name + "' to '" + new_toolbar_name + "'?") title:"Toolbar-Creator"
        )

        if rename_ok then
        (
            saveToolbarUiState()
            rename_ok = renameManagedScriptToolbar old_toolbar_name new_toolbar_name \
                button_data:toolbar_creator_ui_buttons macro_category:"Toolbar-Creator" \
                save_ui:chk_save_ui.checked show_toolbar:chk_show_toolbar.checked

            if rename_ok then
            (
                edt_toolbar_name.text = new_toolbar_name
                refreshManagedToolbarList select_toolbar_name:new_toolbar_name
                updateSavedFileInfo()
                showToolbarStatus ("Renamed toolbar: " + old_toolbar_name + " -> " + new_toolbar_name)
            )
            else
            (
                showToolbarStatus "Toolbar rename failed; see Listener for the cause."
            )
        )

        rename_ok
        -- return
    )

    /*
    Keeps the left managed-toolbar sidebar and right configuration column aligned while resizing.
    */
    function resizeToolbarDialog dialog_size =
    (
        vertical_delta = dialog_size.y - toolbar_creator_ui_min_height
        if vertical_delta < 0 then vertical_delta = 0
        horizontal_delta = dialog_size.x - 1024
        if horizontal_delta < 0 then horizontal_delta = 0

        lst_scripts.height = 300 + vertical_delta
        lst_scripts.width = 736 + horizontal_delta
        if lst_scripts.Columns.Count > 1 then lst_scripts.Columns.Item[1].Width = 568 + horizontal_delta
        lst_managed_toolbars.height = 396 + vertical_delta
        lbl_config.width = 736 + horizontal_delta
        edt_toolbar_name.width = 736 + horizontal_delta
        lbl_scripts.width = 736 + horizontal_delta
        edt_button_tooltip.width = 368 + horizontal_delta
        lbl_status.width = 736 + horizontal_delta
        lbl_ui_file_log.width = 736 + horizontal_delta
        btn_create.pos = [12, 480 + vertical_delta]
        btn_update.pos = [136, 480 + vertical_delta]
        btn_rename.pos = [12, 520 + vertical_delta]
        btn_delete.pos = [136, 520 + vertical_delta]
        edt_button_label.pos = [276, 482 + vertical_delta]
        edt_button_tooltip.pos = [644, 482 + vertical_delta]
        chk_save_ui.pos = [12, 560 + vertical_delta]
        chk_show_toolbar.pos = [136, 560 + vertical_delta]
        lbl_status.pos = [276, 526 + vertical_delta]
        lbl_ui_file_log.pos = [276, 558 + vertical_delta]
        true
        -- return
    )

    on toolbarCreatorUiRollout open do
    (
        if toolbarCreatorUiRollout.height <= toolbar_creator_ui_min_height then
        (
            toolbar_creator_ui_min_height = getToolbarDialogContentHeight()
        )
        ToolTitleButton.setupToolTitleButton btn_tool_title "Toolbar-Creator"
        ToolTitleButton.resizeToolTitleButton btn_tool_title (toolbarCreatorUiRollout.width - 24)
        setupToolbarActionButtons()
        color_type = dotNetClass "System.Drawing.Color"
        lst_scripts.BackColor = color_type.FromArgb 45 45 48
        lst_scripts.ForeColor = color_type.FromArgb 230 230 230
        lst_scripts.View = (dotNetClass "System.Windows.Forms.View").Details
        lst_scripts.FullRowSelect = true
        lst_scripts.MultiSelect = false
        lst_scripts.HideSelection = false
        lst_scripts.GridLines = false
        lst_scripts.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").Nonclickable
        lst_scripts.Columns.Add "Button Text" 144
        lst_scripts.Columns.Add "Script Path" 568
        lst_managed_toolbars.BackColor = color_type.FromArgb 45 45 48
        lst_managed_toolbars.ForeColor = color_type.FromArgb 230 230 230
        lst_managed_toolbars.HorizontalScrollbar = true
        lbl_ui_file_log.AutoSize = false
        lbl_ui_file_log.AutoEllipsis = true
        lbl_ui_file_log.BackColor = color_type.FromArgb 45 45 48
        lbl_ui_file_log.ForeColor = color_type.FromArgb 215 215 215
        lbl_ui_file_log.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 9.0
        toolbarCreatorUiFileLogTooltip = dotNetObject "System.Windows.Forms.ToolTip"
        toolbarCreatorUiFileLogTooltip.SetToolTip btn_create "Selected toolbar: start a new empty toolbar draft.\r\nNo selection: create the prepared toolbar."
        toolbarCreatorUiFileLogTooltip.SetToolTip btn_update "Selected toolbar: update its buttons and refresh the managed list.\r\nNo selection: refresh the managed toolbar list."
        toolbarCreatorUiFileLogTooltip.SetToolTip lst_scripts "LMB DOUBLE-CLICK: Browse for a replacement .ms file for this row.\r\n\r\nClick Create or Update to apply the new path to the toolbar."
        loadToolbarUiState()
        saved_selected_toolbar = IniSettings.getString toolbar_creator_ui_ini_path "MainUI" "SelectedToolbar" default_value:""
        saved_selected_signature = IniSettings.getString toolbar_creator_ui_ini_path "MainUI" "SelectedToolbarSignature" default_value:""
        if saved_selected_toolbar == "" then saved_selected_toolbar = edt_toolbar_name.text
        if refreshManagedToolbarList select_toolbar_name:saved_selected_toolbar select_toolbar_signature:saved_selected_signature then
        (
            if lst_managed_toolbars.SelectedIndex < 0 and lst_managed_toolbars.Items.Count > 0 then
            (
                lst_managed_toolbars.SelectedIndex = 0
            )
            if lst_managed_toolbars.SelectedIndex < 0 then
            (
                showToolbarStatus "No managed toolbars found."
            )
        )
        updateSavedFileInfo()
    )

    on toolbarCreatorUiRollout moved dialog_pos do
    (
        toolbarCreatorSaveFloatingDialogState()
    )

    on toolbarCreatorUiRollout resized dialog_size do
    (
        if (dialog_size.x < 1024 or dialog_size.y < toolbar_creator_ui_min_height) and not toolbarCreatorUiRollout.dialogBar then
        (
            setDialogSize toolbarCreatorUiRollout [(amax 1024 dialog_size.x), (amax toolbar_creator_ui_min_height dialog_size.y)]
        )
        else
        (
            resizeToolbarDialog dialog_size
            ToolTitleButton.resizeToolTitleButton btn_tool_title (toolbarCreatorUiRollout.width - 24)
            toolbarCreatorSaveFloatingDialogState()
        )
    )

    on toolbarCreatorUiRollout close do
    (
        saveToolbarUiState()
        toolbarCreatorSaveFloatingDialogState()
        if toolbarCreatorUiFileLogTooltip != undefined then
        (
            toolbarCreatorUiFileLogTooltip.Dispose()
            toolbarCreatorUiFileLogTooltip = undefined
        )
    )

    on btn_tool_title Click sender event_args do
    (
        /* Queue teardown and disk reload after this .NET Click event exits. */
        try
        (
            saveToolbarUiState()
            toolbarCreatorSaveFloatingDialogState()
            if toolbarCreatorRequestRestart() then
            (
                showToolbarStatus "Restart queued; loading the latest files from disk."
            )
            else
            (
                showToolbarStatus "Cannot restart Toolbar-Creator; see Listener."
            )
        )
        catch
        (
            showToolbarStatus ("Cannot schedule restart: " + (getCurrentException()))
        )
    )

    on lst_scripts SelectedIndexChanged sender event_args do
    (
        selected_index = getSelectedButtonIndex()
        if selected_index > 0 then
        (
            edt_button_label.text = toolbar_creator_ui_buttons[selected_index][2]
            edt_button_tooltip.text = toolbar_creator_ui_buttons[selected_index][3]
        )
    )

    on lst_scripts MouseDoubleClick sender event_args do
    (
        if event_args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left then
        (
            hit_item = lst_scripts.GetItemAt event_args.X event_args.Y
            if hit_item != undefined then
            (
                hit_item.Selected = true
                browseToolbarScriptPath (hit_item.Index + 1)
            )
        )
    )

    on edt_button_label changed edited_text do
    (
        selected_index = getSelectedButtonIndex()
        if selected_index > 0 then
        (
            toolbar_creator_ui_buttons[selected_index][2] = edited_text
            lst_scripts.Items.Item[selected_index - 1].Text = edited_text
        )
    )

    on edt_button_tooltip changed edited_text do
    (
        selected_index = getSelectedButtonIndex()
        if selected_index > 0 then toolbar_creator_ui_buttons[selected_index][3] = edited_text
    )

    on lst_managed_toolbars MouseEnter sender event_args do
    (
        syncManagedToolbarNames()
    )

    on lst_managed_toolbars MouseDown sender event_args do
    (
        syncManagedToolbarNames()
    )

    on lst_managed_toolbars SelectedIndexChanged sender event_args do
    (
        if lst_managed_toolbars.SelectedIndex >= 0 then
        (
            selected_toolbar_name = lst_managed_toolbars.SelectedItem as string
            IniSettings.setString toolbar_creator_ui_ini_path "MainUI" "SelectedToolbar" selected_toolbar_name
            if (lst_managed_toolbars.SelectedIndex + 1) <= toolbar_creator_ui_managed_records.count then
            (
                IniSettings.setString toolbar_creator_ui_ini_path "MainUI" "SelectedToolbarSignature" toolbar_creator_ui_managed_records[lst_managed_toolbars.SelectedIndex + 1][3]
            )
            loaded_buttons = getManagedScriptToolbarButtons selected_toolbar_name

            if classOf loaded_buttons == Array then
            (
                toolbar_creator_ui_buttons = loaded_buttons
                edt_toolbar_name.text = selected_toolbar_name
                refreshToolbarPreview()
                saveToolbarUiState()
                updateSavedFileInfo()
                showToolbarStatus ((loaded_buttons.count as string) + " script(s) loaded from toolbar: " + selected_toolbar_name)
            )
            else
            (
                toolbar_creator_ui_buttons = #()
                edt_toolbar_name.text = selected_toolbar_name
                refreshToolbarPreview()
                updateSavedFileInfo()
                showToolbarStatus ("Cannot load button details; Delete remains available for: " + selected_toolbar_name)
            )
        )
    )

    on btn_add_folder pressed do
    (
        if getSelectedButtonIndex() > 0 then applyCurrentButtonText()
        folder_path = getSavePath caption:"Choose a folder containing MaxScript files" initialDir:(getDir #userScripts)
        if folder_path != undefined and folder_path != "" then
        (
            collected_data = collectToolbarScripts #(folder_path) recursive:true
            mergeToolbarButtons collected_data
        )
    )

    on btn_add_files pressed do
    (
        if getSelectedButtonIndex() > 0 then applyCurrentButtonText()
        file_dialog = dotNetObject "System.Windows.Forms.OpenFileDialog"
        dialog_result = dotNetClass "System.Windows.Forms.DialogResult"
        file_dialog.Title = "Select MaxScript files"
        file_dialog.Filter = "MaxScript (*.ms)|*.ms"
        file_dialog.Multiselect = true
        file_dialog.CheckFileExists = true
        file_dialog.InitialDirectory = (getDir #userScripts)

        if file_dialog.ShowDialog() == dialog_result.OK then
        (
            selected_paths = #()
            for selected_file_path in file_dialog.FileNames do
            (
                append selected_paths (selected_file_path as string)
            )

            mergeToolbarButtons (collectToolbarScripts selected_paths)
        )

        file_dialog.Dispose()
    )

    on btn_clear pressed do
    (
        if toolbar_creator_ui_buttons.count > 0 then
        (
            if queryBox ("Clear all " + (toolbar_creator_ui_buttons.count as string) + " scripts from the current list? This will not update the toolbar until you click Update.") title:"Toolbar-Creator" then
            (
                toolbar_creator_ui_buttons = #()
                refreshToolbarPreview()
                showToolbarStatus "Button list cleared."
            )
        )
    )

    on btn_customize_toolbars pressed do
    (
        max customize UI
        syncManagedToolbarNames()
    )

    on btn_remove pressed do
    (
        selected_index = getSelectedButtonIndex()
        if selected_index > 0 then
        (
            deleteItem toolbar_creator_ui_buttons selected_index
            refreshToolbarPreview preferred_index:selected_index
        )
    )

    on btn_up pressed do
    (
        moveSelectedButton -1
    )

    on btn_down pressed do
    (
        moveSelectedButton 1
    )

    on edt_toolbar_name changed entered_text do
    (
        updateSavedFileInfo()
    )

    on edt_toolbar_name entered entered_text do
    (
        saveToolbarUiState()
    )

    on chk_save_ui changed checked_state do
    (
        RolloutState.saveCheckbox chk_save_ui toolbar_creator_ui_ini_path "MainUI" "SaveUI"
        updateSavedFileInfo()
    )

    on chk_show_toolbar changed checked_state do
    (
        RolloutState.saveCheckbox chk_show_toolbar toolbar_creator_ui_ini_path "MainUI" "ShowToolbar"
    )

    on btn_create Click sender event_args do
    (
        if lst_managed_toolbars.SelectedIndex >= 0 or toolbar_creator_ui_buttons.count == 0 then
        (
            resetNewToolbarDraft()
            showToolbarStatus "New toolbar draft ready. Add .ms files, then click Create."
        )
        else
        (
            executeToolbarAction #create
        )
    )

    on btn_update Click sender event_args do
    (
        if lst_managed_toolbars.SelectedIndex >= 0 then
        (
            executeToolbarAction #update
        )
        else if refreshManagedToolbarList() then
        (
            showToolbarStatus ((lst_managed_toolbars.Items.Count as string) + " managed toolbar(s) refreshed.")
        )
    )

    on btn_rename Click sender event_args do
    (
        executeToolbarRename()
    )

    on btn_delete Click sender event_args do
    (
        executeToolbarAction #delete
    )
)

/*
Create the tool as an ordinary floating dialog, without CUI dialog-bar registration.
Remove only legacy Toolbar-Creator registrations, preserving all other dialogs.
*/
if not (DialogHost.destroyToolDialogs "Toolbar-Creator") then
(
    throw "Toolbar-Creator could not release its previous dockable dialog."
)
try (destroyDialog toolbarCreatorUiRollout) catch ()
toolbar_creator_startup_pos = IniSettings.getPoint2 toolbar_creator_ui_ini_path "MainUI" "PosX" "PosY" default_value:[100,100]
createDialog toolbarCreatorUiRollout width:1024 height:toolbar_creator_ui_min_height pos:toolbar_creator_startup_pos lockWidth:true lockHeight:false autoLayoutOnResize:true
windows.processPostedMessages()
