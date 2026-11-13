/*
Render Studio frontend.
File version: 0.10
Project version: 0.13
*/


global render_studio_project_version
global render_studio_ui_file_version = 0.10
global render_studio_ui_stored_project_version = 0.13
global render_studio_rollout_title
global render_studio_rollout


if render_studio_project_version == undefined or render_studio_ui_stored_project_version > render_studio_project_version then
(
    render_studio_project_version = render_studio_ui_stored_project_version
)


render_studio_rollout_title = "Render Studio - v" + (formattedPrint render_studio_project_version format:".2f")


rollout render_studio_rollout render_studio_rollout_title width:288 height:744
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:264 height:18 align:#center


    groupbox grp_hdri "HDRI" pos:[12,42] width:264 height:420
    edittext edt_hdri_dir "Directory:" pos:[24,66] width:240 height:24 tooltip:"HDRI directory scanned for .hdr and .exr files."
    button btn_browse_hdri "BROWSE" pos:[24,102] width:168 height:24 tooltip:"LMB: Choose the HDRI directory."
    button btn_refresh_hdri "REFRESH" pos:[204,102] width:60 height:24 tooltip:"LMB: Rescan the current HDRI directory."
    listbox lst_hdri_files "HDRI files:" pos:[24,138] width:240 height:9 items:#() selection:0 tooltip:"Select the HDRI used by the active HDRI mode."
    checkbox chk_use_hdri "Use selected HDRI" pos:[24,318] width:240 height:24 checked:true tooltip:"Enable the selected HDRI. Disable it to use the neutral Arnold Skydome fallback."
    dropdownlist ddl_hdri_mode "Mode" pos:[24,342] width:240 height:24 items:#("Dome Light", "Environment") selection:1 tooltip:"Dome Light maps the HDRI directly to an Arnold Skydome.\n\nEnvironment uses the 3ds Max Environment Map."
    spinner spn_hdri_strength "Strength" pos:[24,378] width:144 height:24 range:[0.0,5.0,0.35] type:#float scale:0.06 fieldWidth:48 tooltip:"Scales the HDRI bitmap RGB level."
    checkbutton btn_viewport_hdri "VIEWPORT" pos:[180,378] width:84 height:24 checked:false tooltip:"Add/remove the current STUDIO_HDRI as the active viewport Environment background."
    slider sld_hdri_rotation "Dome Rotation" pos:[24,408] width:240 range:[0,360,0] type:#integer ticks:0 tooltip:"Rotate STUDIO_Sky around Z. Each HDRI stores its own 1-degree rotation in the dome user properties."


    groupbox grp_scene "SCENE SETUP" pos:[12,474] width:264 height:84
    checkbox chk_apply_material "Apply gray Physical Material" pos:[24,498] width:240 height:24 checked:true tooltip:"Apply the neutral gray sculpture material to the selected source objects."
    checkbox chk_create_camera "Create Physical Camera" pos:[24,522] width:240 height:24 checked:true tooltip:"Create and activate a targeted Physical Camera."


    button btn_setup "SET UP ARNOLD STUDIO" pos:[12,570] width:264 height:24 tooltip:"LMB: Build or rebuild the Tool-owned Arnold studio around the current selection."
    dotNetControl btn_render "System.Windows.Forms.Button" pos:[12,606] width:264 height:32
    button btn_clone_buffer "CLONE BUFFER" pos:[12,650] width:264 height:24 tooltip:"Clone the last rendered image into a separate VFB window for comparison."
    label lbl_status "Ready." pos:[12,686] width:264 height:42


    local hdri_paths = #()


    /*
    Applies the standard dark .NET button style with orange text to the Render action.
    */
    function setupRenderButton =
    (
        local color_type = dotNetClass "System.Drawing.Color"
        local flat_style_type = dotNetClass "System.Windows.Forms.FlatStyle"
        local font_style_type = dotNetClass "System.Drawing.FontStyle"


        btn_render.Text = "RENDER"
        btn_render.UseVisualStyleBackColor = false
        btn_render.FlatStyle = flat_style_type.Flat
        btn_render.BackColor = color_type.FromArgb 68 68 68
        btn_render.ForeColor = color_type.FromArgb 255 165 0
        btn_render.FlatAppearance.BorderColor = color_type.FromArgb 120 120 120
        btn_render.FlatAppearance.BorderSize = 1
        btn_render.FlatAppearance.MouseOverBackColor = color_type.FromArgb 78 78 78
        btn_render.FlatAppearance.MouseDownBackColor = color_type.FromArgb 55 55 55
        btn_render.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 9.0 font_style_type.Bold
        btn_render.TabStop = true
        true
        -- return
    )


    /*
    Shows one concise status message.
    */
    function setStatus message_text =
    (
        if classOf message_text == String then
        (
            lbl_status.text = message_text
        )


        true
        -- return
    )


    /*
    Enables or disables HDRI-specific controls from the persisted HDRI toggle.
    */
    function updateHdriControls =
    (
        local hdri_enabled = chk_use_hdri.checked


        lst_hdri_files.enabled = hdri_enabled
        ddl_hdri_mode.enabled = hdri_enabled
        spn_hdri_strength.enabled = hdri_enabled
        btn_viewport_hdri.enabled = hdri_enabled and hdri_paths.count > 0
        sld_hdri_rotation.enabled = \
            hdri_enabled and \
            ddl_hdri_mode.selection == 1 and \
            RenderStudio.hasDomeLight()
        true
        -- return
    )


    /*
    Saves all persistent frontend settings.
    */
    function saveUiState =
    (
        RolloutState.saveEditText edt_hdri_dir render_studio_ini_path "MainUI" "HDRIDirectory"
        RolloutState.saveCheckbox chk_use_hdri render_studio_ini_path "MainUI" "UseHDRI"
        RolloutState.saveDropdown ddl_hdri_mode render_studio_ini_path "MainUI" "HDRIMode"
        RolloutState.saveSpinner spn_hdri_strength render_studio_ini_path "MainUI" "HDRIStrength"
        RolloutState.saveCheckbox chk_apply_material render_studio_ini_path "MainUI" "ApplyMaterial"
        RolloutState.saveCheckbox chk_create_camera render_studio_ini_path "MainUI" "CreateCamera"


        if lst_hdri_files.selection > 0 and lst_hdri_files.selection <= hdri_paths.count then
        (
            IniSettings.setString render_studio_ini_path "MainUI" "HDRIFile" hdri_paths[lst_hdri_files.selection]
        )


        true
        -- return
    )


    /*
    Rescans the current HDRI directory and optionally restores one full-path selection.
    */
    function refreshHdriList preferred_path:undefined =
    (
        local hdri_names = #()
        local selected_index = 0


        hdri_paths = RenderStudio.getHdriFiles edt_hdri_dir.text
        hdri_names = RenderStudio.getHdriDisplayNames hdri_paths
        lst_hdri_files.items = hdri_names


        if preferred_path != undefined and preferred_path != "" then
        (
            for item_index = 1 to hdri_paths.count while selected_index == 0 do
            (
                if hdri_paths[item_index] == preferred_path then selected_index = item_index
            )
        )


        if selected_index == 0 and hdri_paths.count > 0 then selected_index = 1
        lst_hdri_files.selection = selected_index
        hdri_paths.count
        -- return
    )


    /*
    Restores persistent frontend state and the last selected HDRI when it still exists.
    */
    function loadUiState =
    (
        local last_hdri_path = ""


        RolloutState.loadEditText edt_hdri_dir render_studio_ini_path "MainUI" "HDRIDirectory" default_value:""
        RolloutState.loadCheckbox chk_use_hdri render_studio_ini_path "MainUI" "UseHDRI" default_value:true
        RolloutState.loadDropdown ddl_hdri_mode render_studio_ini_path "MainUI" "HDRIMode" default_value:1
        RolloutState.loadSpinner spn_hdri_strength render_studio_ini_path "MainUI" "HDRIStrength" default_value:0.35
        RolloutState.loadCheckbox chk_apply_material render_studio_ini_path "MainUI" "ApplyMaterial" default_value:true
        RolloutState.loadCheckbox chk_create_camera render_studio_ini_path "MainUI" "CreateCamera" default_value:true


        last_hdri_path = IniSettings.getString render_studio_ini_path "MainUI" "HDRIFile" default_value:""
        refreshHdriList preferred_path:last_hdri_path
        updateHdriControls()
        true
        -- return
    )


    /*
    Returns the selected HDRI path, or undefined when HDRI is disabled or no file is selected.
    */
    function getSelectedHdriPath =
    (
        local selected_hdri_path = undefined
        local selected_index = lst_hdri_files.selection


        if chk_use_hdri.checked and selected_index > 0 and selected_index <= hdri_paths.count then
        (
            selected_hdri_path = hdri_paths[selected_index]
        )


        selected_hdri_path
        -- return
    )


    /*
    Shows a short status for the currently selected HDRI.
    */
    function setHdriChangedStatus =
    (
        local selected_hdri_path = getSelectedHdriPath()


        if selected_hdri_path != undefined then
        (
            setStatus ("HDRI: " + filenameFromPath selected_hdri_path)
        )
        else
        (
            setStatus "HDRI: none"
        )


        true
        -- return
    )


    /*
    Updates the existing Tool-owned HDRI map immediately after the user changes file or strength.
    The map remains instanced in Material Editor slot 1 and on the current dome/environment when present.
    */
    function updateActiveHdriMap =
    (
        local selected_hdri_path = getSelectedHdriPath()
        local update_ok = true


        if selected_hdri_path != undefined then
        (
            update_ok = RenderStudio.updateHdriAssignment selected_hdri_path spn_hdri_strength.value
        )


        update_ok
        -- return
    )


    /*
    Syncs the rotation slider to the saved angle for the currently selected HDRI.
    */
    function syncDomeRotationControl =
    (
        local selected_hdri_path = getSelectedHdriPath()
        local saved_rotation = 0


        if selected_hdri_path != undefined then
        (
            saved_rotation = RenderStudio.getDomeHdriRotation selected_hdri_path
        )


        sld_hdri_rotation.value = saved_rotation
        updateHdriControls()
        true
        -- return
    ),


    /*
    Keeps width-dependent controls aligned to the locked 288 px dialog width.
    */
    function layoutDialog dialog_size =
    (
        local content_width = dialog_size.x - 24


        ToolTitleButton.resizeToolTitleButton btn_tool_title content_width
        btn_render.width = content_width
        btn_clone_buffer.width = content_width
        lbl_status.width = content_width
        true
        -- return
    )


    on render_studio_rollout open do
    (
        ToolTitleButton.setupToolTitleButton btn_tool_title "Render Studio"
        setupRenderButton()
        layoutDialog (getDialogSize render_studio_rollout)
        loadUiState()
        updateActiveHdriMap()
        btn_viewport_hdri.checked = RenderStudio.isViewportHdriEnabled()
        syncDomeRotationControl()
        setStatus "Ready."
    )


    on render_studio_rollout moved dialog_pos do
    (
        DialogHost.saveDialogPosition render_studio_rollout render_studio_ini_path "MainUI"
    )


    on render_studio_rollout resized dialog_size do
    (
        layoutDialog dialog_size
        DialogHost.saveDialogHeight render_studio_rollout render_studio_ini_path "MainUI" min_height:744
    )


    on render_studio_rollout close do
    (
        if btn_viewport_hdri.checked then RenderStudio.setViewportHdriEnabled false
        saveUiState()
        DialogHost.saveDialogState render_studio_rollout render_studio_ini_path "MainUI" min_height:744
    )


    on btn_tool_title Click sender event_args do
    (
        restartTool render_studio_source_path "Render Studio"
    )


    on edt_hdri_dir entered text_value do
    (
        RolloutState.saveEditText edt_hdri_dir render_studio_ini_path "MainUI" "HDRIDirectory"
        refreshHdriList()
        saveUiState()
    )


    on btn_browse_hdri pressed do
    (
        local initial_dir = edt_hdri_dir.text
        local selected_dir = undefined


        if initial_dir == "" or not doesDirectoryExist initial_dir then initial_dir = getDir #maxroot


        selected_dir = getSavePath caption:"Select HDRI Directory" initialDir:initial_dir


        if selected_dir != undefined then
        (
            edt_hdri_dir.text = selected_dir
            refreshHdriList()
            saveUiState()
            updateActiveHdriMap()
            setHdriChangedStatus()
        )
    )


    on btn_refresh_hdri pressed do
    (
        refreshHdriList preferred_path:(IniSettings.getString render_studio_ini_path "MainUI" "HDRIFile" default_value:"")
        saveUiState()
        updateActiveHdriMap()
        setHdriChangedStatus()
    )


    on lst_hdri_files selected item_index do
    (
        saveUiState()
        updateActiveHdriMap()
        syncDomeRotationControl()
        setHdriChangedStatus()
    )


    on chk_use_hdri changed checked_state do
    (
        if not checked_state and btn_viewport_hdri.checked then
        (
            btn_viewport_hdri.checked = false
            RenderStudio.setViewportHdriEnabled false
        )


        updateHdriControls()
        saveUiState()
    )


    on ddl_hdri_mode selected item_index do
    (
        saveUiState()
        updateActiveHdriMap()
        syncDomeRotationControl()
    )


    on spn_hdri_strength changed spinner_value do
    (
        saveUiState()
        updateActiveHdriMap()
        setHdriChangedStatus()
    )


    on chk_apply_material changed checked_state do
    (
        saveUiState()
    )


    on chk_create_camera changed checked_state do
    (
        saveUiState()
    )


    on btn_viewport_hdri changed checked_state do
    (
        local viewport_result = undefined


        if checked_state then updateActiveHdriMap()
        viewport_result = RenderStudio.setViewportHdriEnabled checked_state


        if not viewport_result.passed and checked_state then
        (
            btn_viewport_hdri.checked = false
        )


        setStatus viewport_result.message
    )


    on btn_setup pressed do
    (
        local selected_hdri_path = getSelectedHdriPath()
        local hdri_mode = if ddl_hdri_mode.selection == 2 then #environment else #dome
        local selected_nodes = selection as array
        local setup_result = RenderStudio.setupStudio \
            selected_nodes \
            hdri_path:selected_hdri_path \
            hdri_strength:spn_hdri_strength.value \
            hdri_mode:hdri_mode \
            apply_material:chk_apply_material.checked \
            create_camera:chk_create_camera.checked


        saveUiState()
        syncDomeRotationControl()
        setStatus setup_result.message
    )


    on sld_hdri_rotation changed rotation_value do
    (
        local selected_hdri_path = getSelectedHdriPath()
        local rotation_result = RenderStudio.setDomeHdriRotation selected_hdri_path rotation_value


        setStatus rotation_result.message
    )


    on btn_clone_buffer pressed do
    (
        local clone_result = RenderStudio.cloneRenderBuffer()


        setStatus clone_result.message
    )


    on btn_render Click sender event_args do
    (
        setStatus "Rendering..."
        windows.processPostedMessages()


        local render_result = RenderStudio.renderCurrentFrame()
        setStatus render_result.message
    )
)
