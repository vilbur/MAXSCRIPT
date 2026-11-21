    /*
    UI rollouts, controls and callbacks. Compile-time included by Blueprint-Manager.ms.
    File version: 0.049 | Project version: 0.049.
    */
    /*
    Subrollout directly below image previews for millimeter-local-Z adjustments.
    Each independent slider travels the full virtual-box depth on its own axis.
    */
    rollout blueprintPositionsRollout "POSITIONS" width:264 height:204
    (
        local updating_position_ranges = false


        slider sld_position_top "TOP (mm)" pos:[8,20] width:240 range:[0.0,100.0,0.0] type:#float ticks:0 toolTip:"LMB: Move TOP along local Z.\r\n\r\nRange: perpendicular view height (mm)."
        slider sld_position_front "FRONT (mm)" pos:[8,56] width:240 range:[0.0,100.0,0.0] type:#float ticks:0 toolTip:"LMB: Move FRONT along local Z.\r\n\r\nRange: SIDE width (TOP/BOTTOM fallback), mm."
        slider sld_position_side "SIDE (mm)" pos:[8,92] width:240 range:[0.0,100.0,0.0] type:#float ticks:0 toolTip:"LMB: Move SIDE along local Z.\r\n\r\nRange: FRONT/BACK width (TOP/BOTTOM fallback), mm."
        slider sld_position_back "BACK (mm)" pos:[8,128] width:240 range:[0.0,100.0,0.0] type:#float ticks:0 toolTip:"LMB: Move BACK along local Z.\r\n\r\nRange: SIDE width (TOP/BOTTOM fallback), mm."
        slider sld_position_bottom "BOTTOM (mm)" pos:[8,164] width:240 range:[0.0,100.0,0.0] type:#float ticks:0 toolTip:"LMB: Move BOTTOM along local Z.\r\n\r\nRange: perpendicular view height (mm)."


        /*
        Resets slider bounds based on image-derived scene extents in millimeters.
        When image dimensions shrink, an invalid offset is constrained to the new range.
        */
        function updatePositionRanges mm_per_pixel =
        (
            local sliders = #(sld_position_top, sld_position_front, sld_position_side, sld_position_back, sld_position_bottom)
            local layout_data = BlueprintManager.getSceneLayout mm_per_pixel
            local plane_sizes = layout_data[1]
            local limits_mm = BlueprintManager.getPositionRangesMm layout_data
            updating_position_ranges = true


            for role_index = 1 to 5 do
            (
                local limit_mm = limits_mm[role_index]
                local offset_mm = BlueprintManager.position_offsets_mm[role_index]
                if limit_mm > 0.0 and offset_mm > limit_mm then
                (
                    format "BM POSITION | % offset % mm exceeds new range % mm; limiting travel.\n" BlueprintManager.role_names[role_index] offset_mm limit_mm
                    BlueprintManager.setPositionOffset role_index limit_mm
                    offset_mm = limit_mm
                )
                if limit_mm > 0.0 then
                (
                    sliders[role_index].range = [0.0, limit_mm, offset_mm]
                    sliders[role_index].enabled = (plane_sizes[role_index] != undefined)
                )
                else
                (
                    sliders[role_index].range = [0.0, 1.0, 0.0]
                    sliders[role_index].enabled = false
                )
            )


            updating_position_ranges = false
            true
            -- return
        )


        /*
        Hides unassigned position sliders in APPLY mode and stacks visible rows.
        Returns the height needed by the visible rows, including caption clearance.
        */
        function layoutPositionSliders setup_enabled =
        (
            local sliders = #(sld_position_top, sld_position_front, sld_position_side, sld_position_back, sld_position_bottom)
            local row_count = 0
            for role_index = 1 to 5 do
            (
                local show_slider = setup_enabled or (BlueprintManager.image_paths[role_index] != "")
                sliders[role_index].visible = show_slider
                if show_slider then
                (
                    sliders[role_index].pos = [8, (20 + 36 * row_count)]
                    row_count += 1
                )
            )
            24 + 36 * row_count
            -- return
        )


        /*
        Applies an absolute slider value to the matching scene Plane and saves it.
        */
        function handlePositionChanged role_index offset_mm =
        (
            if updating_position_ranges then return false
            undo "Blueprint Manager Position" on
            (
                BlueprintManager.setPositionOffset role_index offset_mm
            )
            IniSettings.setFloat ini_path "Positions" BlueprintManager.role_names[role_index] offset_mm
            true
            -- return
        )


        on sld_position_top changed value_mm do (handlePositionChanged 1 value_mm)
        on sld_position_front changed value_mm do (handlePositionChanged 2 value_mm)
        on sld_position_side changed value_mm do (handlePositionChanged 3 value_mm)
        on sld_position_back changed value_mm do (handlePositionChanged 4 value_mm)
        on sld_position_bottom changed value_mm do (handlePositionChanged 5 value_mm)
    )


    /*
    Aligns the blueprint group to the origin by its outer bounds on three axes.
    Each independent axis occupies one vertical radio-button column.
    */
    rollout blueprintAlignmentRollout "ALIGNMENT" width:264 height:112
    (
        local updating_alignment_controls = false


        radiobuttons rdo_align_vertical labels:#("TOP", "CENTER", "GROUND") columns:1 default:3 pos:[8,16] width:80 height:84 align:#left tooltip:"LMB: Align group top, middle or ground to world Z = 0."
        radiobuttons rdo_align_depth labels:#("FRONT", "CENTER", "BACK") columns:1 default:2 pos:[92,16] width:80 height:84 align:#left tooltip:"LMB: Align group front, middle or back to world Y = 0."
        radiobuttons rdo_align_horizontal labels:#("LEFT", "CENTER", "RIGHT") columns:1 default:2 pos:[176,16] width:80 height:84 align:#left tooltip:"LMB: Align group left, middle or right to world X = 0."


        /*
        Loads axis choices from the existing tool INI without moving scene nodes.
        GROUND defaults the Z axis; the other two axes default to CENTER.
        */
        function loadAlignmentState =
        (
            updating_alignment_controls = true
            local setting_names = #("Vertical", "Depth", "Horizontal")
            for axis_index = 1 to 3 do
            (
                local default_state = if axis_index == 1 then 3 else 2
                local saved_state = IniSettings.getInteger ini_path "Alignment" setting_names[axis_index] default_value:default_state
                if saved_state < 1 or saved_state > 3 then saved_state = default_state
                BlueprintManager.alignment_modes[axis_index] = saved_state
            )
            rdo_align_vertical.state = BlueprintManager.alignment_modes[1]
            rdo_align_depth.state = BlueprintManager.alignment_modes[2]
            rdo_align_horizontal.state = BlueprintManager.alignment_modes[3]
            updating_alignment_controls = false
            true
            -- return
        )


        /*
        Moves the managed Plane group on the selected axis only.
        Stores the choice even before any blueprint planes have been created.
        */
        function handleAlignmentChanged axis_index selected_state =
        (
            if updating_alignment_controls then return false
            BlueprintManager.alignment_modes[axis_index] = selected_state
            undo "Blueprint Manager Alignment" on
            (
                if BlueprintManager.alignBlueprintAxis axis_index selected_state then redrawViews()
            )
            local setting_names = #("Vertical", "Depth", "Horizontal")
            local setting_name = setting_names[axis_index]
            IniSettings.setInteger ini_path "Alignment" setting_name selected_state
            true
            -- return
        )


        on rdo_align_vertical changed selected_state do (handleAlignmentChanged 1 selected_state)
        on rdo_align_depth changed selected_state do (handleAlignmentChanged 2 selected_state)
        on rdo_align_horizontal changed selected_state do (handleAlignmentChanged 3 selected_state)
    )


    /*
    Combines image scale and opacity on one compact horizontal row.
    Both settings remain stored in the existing Blueprint-Manager.ini.
    */
    rollout blueprintOptionsRollout "OPTIONS" width:264 height:88
    (
        spinner spn_pixel_scale "RATIO 1px" pos:[8,22] width:112 align:#left offset:[0,0] range:[0.0001,10000.0,1.0] type:#float fieldWidth:36 toolTip:"Sets millimeters per image pixel.\r\n\r\nApplied by APPLY."
        label lbl_pixel_scale_unit "mm" pos:[118,24] width:24
        slider sld_opacity "Opacity" pos:[146,20] width:110 height:30 range:[0,100,100] type:#integer ticks:0 toolTip:"LMB: Adjust blueprint opacity.\r\n\r\nAlso used by APPLY."
        editText edt_layer_name "Layer Name" pos:[8,54] width:248 height:24 text:"_BLUEPRINTS" toolTip:"Name of the scene layer for managed blueprint planes.\r\n\r\nUsed when applying images."


        on edt_layer_name changed new_name do
        (
            BlueprintManager.layer_name = new_name
        )


        on edt_layer_name entered new_name do
        (
            IniSettings.setString ini_path ini_section "LayerName" new_name
        )


        on spn_pixel_scale changed new_value do
        (
            RolloutState.saveSpinner spn_pixel_scale ini_path ini_section "MillimetersPerPixel"
            blueprintPositionsRollout.updatePositionRanges new_value
        )


        on sld_opacity changed new_value do
        (
            BlueprintManager.setOpacity new_value
            IniSettings.setInteger ini_path ini_section "Opacity" new_value
        )
    )


    rollout blueprintManagerRollout ("Blueprint Manager v" + project_version) width:288 height:780 autoLayoutOnResize:false
    (
        local setup_mode = true
        local options_expanded = true
        local positions_expanded = true
        local alignment_expanded = true
        local resizing_for_mode = false
        local last_floating_position = undefined
        local last_floating_size = undefined
        local last_dock_state = undefined
        local preview_content_height = 300
        local preview_content_width = 264
        local preview_buttons = #()
        local preview_menus = #()
        local preview_menu_items = #(#(), #(), #(), #(), #())
        local preview_images = #(undefined, undefined, undefined, undefined, undefined)
        local tooltip_provider = undefined
        local title_context_menu = undefined
        local pending_preview_role = ""
        local pending_preview_position = undefined


        dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:264 height:20
        dotNetControl pnl_images "System.Windows.Forms.Panel" pos:[12,44] width:264 height:300
        dotNetControl btn_on_off "System.Windows.Forms.Button" pos:[12,356] width:126 height:38
        dotNetControl btn_apply_setup "System.Windows.Forms.Button" pos:[150,356] width:126 height:38
        checkbutton chk_freeze "FREEZE" pos:[12,402] width:126 height:30 checked:true toolTip:"LMB: Freeze or unfreeze all blueprint planes."
        checkbutton chk_two_sided "TWO-SIDED" pos:[150,402] width:126 height:30 checked:true toolTip:"LMB: Show or cull the back faces of blueprint planes."
        subRollout sr_sections "" pos:[-4,440] width:296 height:476 scrollBar:#off


        timer tmr_dialog_state interval:750 active:false
        timer tmr_preview_click interval:500 active:false


        /*
        Identifies a floating rollout, including one registered with CUI.
        */
        function isFloatingDialog =
        (
            blueprintManagerRollout.hwnd != 0 and
                (not blueprintManagerRollout.dialogBar or (cui.getDockState blueprintManagerRollout) == #cui_floatable)
            -- return
        )


        /*
        Saves the floating position and height through the shared host.
        */
        function saveFloatingGeometry =
        (
            if not (isFloatingDialog()) then return false


            local dialog_pos = getDialogPos blueprintManagerRollout
            local dialog_size = getDialogSize blueprintManagerRollout
            if dialog_size.x <= 0 or dialog_size.y <= 0 then return false


            if dialog_pos != last_floating_position or dialog_size != last_floating_size then
            (
                DialogHost.saveDialogState blueprintManagerRollout ini_path ini_section min_height:1
                last_floating_position = dialog_pos
                last_floating_size = dialog_size
            )
            true
            -- return
        )


        /*
        Stores the current CUI docking side without touching floating geometry.
        */
        function saveDockState =
        (
            local dock_state = if blueprintManagerRollout.dialogBar then (cui.getDockState blueprintManagerRollout) else #cui_floatable
            if dock_state == last_dock_state then return false


            local dock_side = case dock_state of
            (
                #cui_dock_left: "left"
                #cui_dock_right: "right"
                default: "floating"
            )
            IniSettings.setString ini_path ini_section "DockSide" dock_side
            last_dock_state = dock_state
            true
            -- return
        )


        /*
        Restores native floating geometry and recovers an off-screen title bar.
        */
        function restoreFloatingGeometry =
        (
            /* Registered dialog bars cannot be moved with setDialogPos. */
            if blueprintManagerRollout.dialogBar or not (isFloatingDialog()) then return false


            local target_pos = IniSettings.getPoint2 ini_path ini_section "PosX" "PosY" default_value:[100,100]
            setDialogPos blueprintManagerRollout target_pos


            local screen_pos = getDialogPos blueprintManagerRollout removeUIScaling:false
            local screen_size = getDialogSize blueprintManagerRollout removeUIScaling:false
            local screen_class = dotNetClass "System.Windows.Forms.Screen"
            local title_visible = false
            for monitor_ref in screen_class.AllScreens while not title_visible do
            (
                local work_area = monitor_ref.WorkingArea
                local visible_width = (amin work_area.Right (screen_pos.x + screen_size.x)) - (amax work_area.Left screen_pos.x)
                title_visible = (visible_width >= 96) and (screen_pos.y >= work_area.Top) and (screen_pos.y + 32 <= work_area.Bottom)
            )
            if not title_visible then
            (
                local work_area = screen_class.PrimaryScreen.WorkingArea
                setDialogPos blueprintManagerRollout [work_area.Left + 24, work_area.Top + 24] applyUIScaling:false
            )
            true
            -- return
        )


        /*
        Returns an existing image button for a slot by its index.
        */
        function getPreviewButton role_index =
        (
            preview_buttons[role_index]
            -- return
        )


        /*
        Creates one resized thumbnail, tinting it when its plane is hidden.
        The source bitmap is immediately disposed so Photoshop can rewrite files.
        */
        function createThumbnail file_path image_width image_height dimmed =
        (
            local original_bitmap = dotNetObject "System.Drawing.Bitmap" file_path
            local target_size = dotNetObject "System.Drawing.Size" image_width image_height
            local thumbnail = dotNetObject "System.Drawing.Bitmap" original_bitmap target_size
            original_bitmap.Dispose()


            if dimmed then
            (
                local graphics_ref = (dotNetClass "System.Drawing.Graphics").FromImage thumbnail
                local shade_color = (dotNetClass "System.Drawing.Color").FromArgb 160 38 38 38
                local brush_ref = dotNetObject "System.Drawing.SolidBrush" shade_color
                graphics_ref.FillRectangle brush_ref 0 0 image_width image_height
                brush_ref.Dispose()
                graphics_ref.Dispose()
            )
            thumbnail
            -- return
        )


        /*
        Disposes the previous preview bitmap and applies the current image/visibility.
        Returns the effective preview height in pixels.
        */
        function updatePreview role_index =
        (
            local view_button = getPreviewButton role_index
            local file_path = BlueprintManager.image_paths[role_index]
            local target_height = 80
            local dimmed = false
            local target_node = BlueprintManager.getBlueprintNode BlueprintManager.role_names[role_index]
            if target_node != undefined then dimmed = target_node.isNodeHidden


            view_button.BackgroundImage = undefined
            if preview_images[role_index] != undefined then
            (
                preview_images[role_index].Dispose()
                preview_images[role_index] = undefined
            )


            if file_path != "" and doesFileExist file_path then
            (
                local image_size = BlueprintManager.readImageSize file_path
                if image_size != undefined then
                (
                    target_height = amax 1 ((80.0 * image_size.y / image_size.x) as integer)
                    preview_images[role_index] = createThumbnail file_path 80 target_height dimmed
                    view_button.BackgroundImage = preview_images[role_index]
                    view_button.Text = ""
                )
            )
            else
            (
                view_button.Text = BlueprintManager.role_names[role_index]
            )


            view_button.Height = target_height
            view_button.Width = 80
            view_button.Tag = BlueprintManager.role_names[role_index]


            if tooltip_provider != undefined then
            (
                local tooltip_text = if file_path == "" then
                (
                    "LMB: Assign an image.\r\n\r\nDBL LMB: Toggle all blueprints.\r\n\r\nRMB: Choose an image or manage this blueprint.\r\n\r\nCTRL + LMB: Toggle all blueprint visibility."
                )
                else
                (
                    "LMB: Toggle this blueprint visibility.\r\n\r\nDBL LMB: Toggle all blueprints.\r\n\r\nRMB: Choose an image or manage this blueprint.\r\n\r\nCTRL + LMB: Toggle all blueprint visibility."
                )
                tooltip_provider.SetToolTip view_button tooltip_text
            )
            target_height
            -- return
        )


        /*
        Enables scrolling only when preview contents exceed the panel height.
        Avoids changing scroll limits and scrollbar state unless required.
        */
        function updatePreviewScrolling =
        (
            local needs_scroll = (preview_content_height > (pnl_images.ClientSize.Height + 1))
            local scroll_height = if needs_scroll then preview_content_height else 0
            local current_scroll_size = pnl_images.AutoScrollMinSize
            if pnl_images.AutoScroll and not needs_scroll then pnl_images.AutoScroll = false
            if current_scroll_size.Width != 0 or current_scroll_size.Height != scroll_height then
            (
                pnl_images.AutoScrollMinSize = dotNetObject "System.Drawing.Size" 0 scroll_height
            )
            if needs_scroll and not pnl_images.AutoScroll then pnl_images.AutoScroll = true
            needs_scroll
            -- return
        )


        /*
        Shows ON in green when at least one blueprint is visible; OFF in red otherwise.
        A blueprint hidden by its actual scene layer also counts as off.
        */
        function updateOnOffButtonColor =
        (
            local visible_blueprint_found = false
            for role_name in BlueprintManager.role_names while not visible_blueprint_found do
            (
                local target_node = BlueprintManager.getBlueprintNode role_name
                if target_node != undefined and not target_node.isNodeHidden then
                (
                    local scene_layer = target_node.layer
                    if scene_layer == undefined or not scene_layer.isHidden then visible_blueprint_found = true
                )
            )
            local color_type = dotNetClass "System.Drawing.Color"
            local target_color = if visible_blueprint_found then color_type.FromArgb 64 212 96 else color_type.FromArgb 255 76 76
            if btn_on_off.ForeColor.ToArgb() != target_color.ToArgb() then btn_on_off.ForeColor = target_color
            visible_blueprint_found
            -- return
        )


        /*
        Lays out variable-height image buttons in the five-slot cross.
        Only refreshes scrolling when the resulting content does not fit.
        */
        function layoutPreviews =
        (
            local heights = #()
            local has_image = false
            for role_index = 1 to 5 do
            (
                append heights (updatePreview role_index)
                if preview_images[role_index] != undefined then has_image = true
            )


            if preview_images[3] != undefined then
            (
                heights[2] = heights[3]
                heights[4] = heights[3]
                preview_buttons[2].Height = heights[3]
                preview_buttons[4].Height = heights[3]
            )


            if not has_image then setup_mode = true


            for role_index = 1 to 5 do
            (
                local show_slot = setup_mode or (preview_images[role_index] != undefined)
                preview_buttons[role_index].Visible = show_slot
                if not show_slot then heights[role_index] = 0
            )


            local middle_height = amax heights[2] (amax heights[3] heights[4])
            local mid_y = if heights[1] > 0 then heights[1] + 12 else 0
            local bottom_y = if middle_height > 0 then mid_y + middle_height + 12 else mid_y
            local x_coords = #(92, 0, 92, 184, 92)
            local y_coords = #(0, mid_y, mid_y, mid_y, bottom_y)
            if not setup_mode then
            (
                local middle_count = 0
                for role_index in #(2, 3, 4) do
                (
                    if preview_buttons[role_index].Visible then middle_count += 1
                )
                if middle_count > 0 then
                (
                    local group_width = (middle_count * 80 + (middle_count - 1) * 12)
                    local next_x = ((264 - group_width) / 2.0) as integer
                    for role_index in #(2, 3, 4) do
                    (
                        if preview_buttons[role_index].Visible then
                        (
                            x_coords[role_index] = next_x
                            next_x += 92
                        )
                    )
                )
            )
            local min_x = 264
            local max_x = 0
            local min_y = 100000
            local max_y = 0
            for role_index = 1 to 5 do
            (
                if preview_buttons[role_index].Visible then
                (
                    min_x = amin min_x x_coords[role_index]
                    max_x = amax max_x (x_coords[role_index] + 80)
                    min_y = amin min_y y_coords[role_index]
                    max_y = amax max_y (y_coords[role_index] + heights[role_index])
                )
            )
            if max_x == 0 then
            (
                min_x = 0
                max_x = 264
                min_y = 0
                max_y = 80
            )
            if setup_mode then
            (
                min_x = 0
                max_x = 264
                min_y = 0
            )
            preview_content_width = (max_x - min_x)
            preview_content_height = (max_y - min_y + 6)
            pnl_images.Width = preview_content_width
            pnl_images.pos = [(12 + ((264 - preview_content_width) / 2.0) as integer), 44]
            pnl_images.SuspendLayout()
            for role_index = 1 to 5 do
            (
                preview_buttons[role_index].Location = dotNetObject "System.Drawing.Point" (x_coords[role_index] - min_x) (y_coords[role_index] - min_y)
            )
            pnl_images.ResumeLayout()
            updateOnOffButtonColor()
            true
            -- return
        )


        /*
        Saves file assignments and the current numeric settings to the local INI.
        */
        function saveUiState =
        (
            RolloutState.saveSpinner blueprintOptionsRollout.spn_pixel_scale ini_path ini_section "MillimetersPerPixel"
            IniSettings.setInteger ini_path ini_section "Opacity" blueprintOptionsRollout.sld_opacity.value
            BlueprintManager.layer_name = blueprintOptionsRollout.edt_layer_name.text
            IniSettings.setString ini_path ini_section "LayerName" BlueprintManager.layer_name
            IniSettings.setBoolean ini_path ini_section "SetupMode" setup_mode
            IniSettings.setBoolean ini_path ini_section "Freeze" chk_freeze.checked
            IniSettings.setBoolean ini_path ini_section "TwoSided" chk_two_sided.checked
            IniSettings.setInteger ini_path "Alignment" "Vertical" BlueprintManager.alignment_modes[1]
            IniSettings.setInteger ini_path "Alignment" "Depth" BlueprintManager.alignment_modes[2]
            IniSettings.setInteger ini_path "Alignment" "Horizontal" BlueprintManager.alignment_modes[3]
            for role_index = 1 to 5 do
            (
                local role_name = BlueprintManager.role_names[role_index]
                IniSettings.setString ini_path ini_section role_name BlueprintManager.image_paths[role_index]
                local candidate_text = ""
                for candidate_path in BlueprintManager.image_candidates[role_index] do
                (
                    if candidate_text != "" then candidate_text += "|"
                    candidate_text += candidate_path
                )
                IniSettings.setString ini_path "BlueprintCandidates" role_name candidate_text
                IniSettings.setFloat ini_path "Positions" role_name BlueprintManager.position_offsets_mm[role_index]
            )
            true
            -- return
        )


        /*
        Loads saved image assignments, preferring paths embedded in this scene.
        */
        function loadUiState =
        (
            RolloutState.loadSpinner blueprintOptionsRollout.spn_pixel_scale ini_path ini_section "MillimetersPerPixel" default_value:1.0
            blueprintOptionsRollout.sld_opacity.value = IniSettings.getInteger ini_path ini_section "Opacity" default_value:100
            BlueprintManager.layer_name = IniSettings.getString ini_path ini_section "LayerName" default_value:"_BLUEPRINTS"
            if BlueprintManager.layer_name == "" then BlueprintManager.layer_name = "_BLUEPRINTS"
            blueprintOptionsRollout.edt_layer_name.text = BlueprintManager.layer_name
            setup_mode = IniSettings.getBoolean ini_path ini_section "SetupMode" default_value:true
            chk_freeze.checked = IniSettings.getBoolean ini_path ini_section "Freeze" default_value:true
            chk_two_sided.checked = IniSettings.getBoolean ini_path ini_section "TwoSided" default_value:true
            local found_nodes = 0
            local all_frozen = true
            local all_two_sided = true
            for role_index = 1 to 5 do
            (
                local role_name = BlueprintManager.role_names[role_index]
                local file_path = IniSettings.getString ini_path ini_section role_name default_value:""
                local candidate_text = IniSettings.getString ini_path "BlueprintCandidates" role_name default_value:""
                for candidate_path in (filterString candidate_text "|") where doesFileExist candidate_path do
                (
                    BlueprintManager.assignImage role_index candidate_path activate:false
                )
                local offset_mm = IniSettings.getFloat ini_path "Positions" role_name default_value:0.0
                local target_node = BlueprintManager.getBlueprintNode role_name
                if target_node != undefined then
                (
                    found_nodes += 1
                    if not target_node.isNodeFrozen then all_frozen = false
                    if target_node.backFaceCull then all_two_sided = false
                    local scene_file = getUserPropVal target_node "BM_FILE"
                    if scene_file != undefined and doesFileExist scene_file then file_path = scene_file
                    local scene_offset_mm = getUserPropVal target_node "BM_OFFSET_MM"
                    if scene_offset_mm != undefined then offset_mm = scene_offset_mm
                )
                BlueprintManager.position_offsets_mm[role_index] = offset_mm
                if file_path != "" and doesFileExist file_path then
                (
                    BlueprintManager.assignImage role_index file_path
                )
            )
            if found_nodes > 0 then
            (
                chk_freeze.checked = all_frozen
                chk_two_sided.checked = all_two_sided
            )
            true
            -- return
        )


        /*
        Imports candidates for all five views while preserving active selections.
        Reports filenames whose role tokens are ambiguous.
        */
        function handleBrowseDirectoryMenu sender event_args =
        (
            local folder_path = getSavePath caption:"Select blueprint image folder"
            if folder_path != undefined then
            (
                local result_counts = BlueprintManager.assignFolder folder_path
                format "BM IMPORT | assigned:% conflicts:%\n" result_counts[1] result_counts[2]
                if result_counts[2] > 0 then
                (
                    messageBox ("Blueprint files contain " + (result_counts[2] as string) + " ambiguous matches. Details in Listener.") title:"Blueprint Manager"
                )
                layoutPreviews()
                blueprintPositionsRollout.updatePositionRanges blueprintOptionsRollout.spn_pixel_scale.value
                blueprintManagerRollout.layoutControls()
                saveUiState()
            )
            true
            -- return
        )


        /*
        Resets only the blueprint slot whose context-menu item was clicked.
        Confirms deletion of an existing managed scene Plane before proceeding.
        */
        function handleResetBlueprintMenu sender event_args =
        (
            local role_name = sender.Tag as string
            local role_index = BlueprintManager.getRoleIndex role_name
            local reset_ok = false
            if role_index > 0 then
            (
                local target_node = BlueprintManager.getBlueprintNode role_name
                local confirm_reset = true
                if target_node != undefined then
                (
                    confirm_reset = queryBox ("Reset " + role_name + " and delete its managed Plane?") title:"Blueprint Manager"
                )
                if confirm_reset then
                (
                    undo "Blueprint Manager Reset" on
                    (
                        reset_ok = BlueprintManager.resetBlueprint role_index
                    )
                    if reset_ok then
                    (
                        layoutPreviews()
                        blueprintPositionsRollout.updatePositionRanges blueprintOptionsRollout.spn_pixel_scale.value
                        blueprintManagerRollout.updatePlaneCheckStates()
                        blueprintManagerRollout.layoutControls()
                        saveUiState()
                    )
                )
            )
            reset_ok
            -- return
        )


        /*
        Refreshes previews and saved UI state after a visibility or image action.
        The control positions and current setup mode are preserved.
        */
        function refreshPreviewControls =
        (
            layoutPreviews()
            blueprintPositionsRollout.updatePositionRanges blueprintOptionsRollout.spn_pixel_scale.value
            blueprintManagerRollout.layoutControls()
            saveUiState()
            true
            -- return
        )


        /*
        Performs the original single-click action after double-click detection.
        Existing empty slots still open the image chooser on a single click.
        */
        function handlePreviewSingleClick role_name =
        (
            local role_index = BlueprintManager.getRoleIndex role_name
            if role_index < 1 then return false
            if BlueprintManager.image_paths[role_index] == "" then
            (
                local file_path = getOpenFileName caption:("Blueprint: " + role_name) types:"Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff|"
                if file_path != undefined then BlueprintManager.assignImage role_index file_path
            )
            else
            (
                BlueprintManager.toggleOne role_name
            )
            refreshPreviewControls()
            true
            -- return
        )


        /*
        Distinguishes two quick clicks on the same preview from a single click.
        WinForms Button controls do not reliably raise a DoubleClick event.
        */
        function handlePreviewMouseDown sender event_args =
        (
            local role_name = sender.Name
            local role_index = BlueprintManager.getRoleIndex role_name
            local handled_ok = false
            local mouse_button = dotNetClass "System.Windows.Forms.MouseButtons"
            if role_index > 0 and event_args.Button == mouse_button.Left then
            (
                if keyboard.controlPressed then
                (
                    tmr_preview_click.active = false
                    pending_preview_role = ""
                    pending_preview_position = undefined
                    BlueprintManager.toggleAll()
                    refreshPreviewControls()
                )
                else
                (
                    local click_position = [event_args.X, event_args.Y]
                    local double_click_size = (dotNetClass "System.Windows.Forms.SystemInformation").DoubleClickSize
                    local matching_location = false
                    if pending_preview_position != undefined then
                    (
                        matching_location = ((abs (pending_preview_position.x - click_position.x)) <= (double_click_size.Width / 2.0)) and
                            ((abs (pending_preview_position.y - click_position.y)) <= (double_click_size.Height / 2.0))
                    )
                    if tmr_preview_click.active and pending_preview_role == role_name and matching_location then
                    (
                        tmr_preview_click.active = false
                        pending_preview_role = ""
                        pending_preview_position = undefined
                        BlueprintManager.toggleAll()
                        refreshPreviewControls()
                    )
                    else
                    (
                        if tmr_preview_click.active and pending_preview_role != "" then
                        (
                            tmr_preview_click.active = false
                            local previous_role = pending_preview_role
                            pending_preview_role = ""
                            pending_preview_position = undefined
                            handlePreviewSingleClick previous_role
                        )
                        pending_preview_role = role_name
                        pending_preview_position = click_position
                        tmr_preview_click.active = true
                    )
                )
                handled_ok = true
            )
            handled_ok
            -- return
        )


        /*
        Restores empty preview slots so they can be assigned manually.
        */
        function handleShowUnusedSlotsMenu sender event_args =
        (
            setup_mode = true
            layoutPreviews()
            blueprintManagerRollout.layoutControls()
            saveUiState()
            -- return
        )


        /*
        Selects the image and refreshes any existing blueprint planes.
        */
        function selectPreviewImage role_index file_path =
        (
            if not (BlueprintManager.assignImage role_index file_path) then return false
            local role_name = BlueprintManager.role_names[role_index]
            if (BlueprintManager.getBlueprintNode role_name) != undefined then
            (
                undo "Blueprint Manager Switch Image" on
                (
                    BlueprintManager.createAll blueprintOptionsRollout.spn_pixel_scale.value blueprintOptionsRollout.sld_opacity.value existing_only:true
                    BlueprintManager.setTwoSidedState chk_two_sided.checked
                )
            )
            layoutPreviews()
            blueprintPositionsRollout.updatePositionRanges blueprintOptionsRollout.spn_pixel_scale.value
            blueprintManagerRollout.layoutControls()
            saveUiState()
            true
            -- return
        )


        /*
        Selects the candidate represented by a filename menu item.
        */
        function handleSelectPreviewImage sender event_args =
        (
            local role_index = BlueprintManager.getRoleIndex (sender.Owner.Tag as string)
            local file_path = sender.Tag as string
            selectPreviewImage role_index file_path
            -- return
        )


        /*
        Adds an individual image to the selected view.
        */
        function handleAddPreviewImage sender event_args =
        (
            local role_name = sender.Owner.Tag as string
            local role_index = BlueprintManager.getRoleIndex role_name
            local file_path = getOpenFileName caption:("Blueprint: " + role_name) types:"Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff|"
            if file_path != undefined then selectPreviewImage role_index file_path else false
            -- return
        )


        /*
        Lists filenames first, then separates them from the preview commands.
        */
        function populatePreviewImageMenu sender event_args =
        (
            local role_index = BlueprintManager.getRoleIndex (sender.Tag as string)
            if role_index < 1 then return false


            for menu_item in preview_menu_items[role_index] do
            (
                dotNet.removeAllEventHandlers menu_item
                menu_item.Dispose()
            )
            local menu_items = #()
            local active_path = BlueprintManager.image_paths[role_index]
            local check_prefix = ((dotNetClass "System.Char").ConvertFromUtf32 10004) + " "
            for file_path in BlueprintManager.image_candidates[role_index] do
            (
                local display_name = (getFilenameFile file_path) + (getFilenameType file_path)
                if file_path == active_path then display_name = check_prefix + display_name
                local menu_item = dotNetObject "System.Windows.Forms.ToolStripMenuItem" (substituteString display_name "&" "&&")
                menu_item.Tag = file_path
                menu_item.ToolTipText = file_path
                menu_item.Enabled = doesFileExist file_path
                menu_item.BackColor = sender.BackColor
                menu_item.ForeColor = sender.ForeColor
                menu_item.Owner = sender
                dotNet.addEventHandler menu_item "Click" handleSelectPreviewImage
                append menu_items menu_item
            )


            if menu_items.count > 0 then
            (
                local separator_item = dotNetObject "System.Windows.Forms.ToolStripSeparator"
                separator_item.Owner = sender
                append menu_items separator_item
            )


            local commands = #(
                #("Browse Directory", handleBrowseDirectoryMenu),
                #("Add Image...", handleAddPreviewImage),
                #("Reset Blueprint", handleResetBlueprintMenu),
                #("Show Unused Slots", handleShowUnusedSlotsMenu)
            )
            for command_data in commands do
            (
                local menu_item = dotNetObject "System.Windows.Forms.ToolStripMenuItem" command_data[1]
                menu_item.BackColor = sender.BackColor
                menu_item.ForeColor = sender.ForeColor
                menu_item.Tag = sender.Tag
                menu_item.Owner = sender
                dotNet.addEventHandler menu_item "Click" command_data[2]
                append menu_items menu_item
            )
            preview_menu_items[role_index] = menu_items
            true
            -- return
        )


        /*
        Creates the five clickable preview buttons inside the scrollable Panel.
        */
        function createPreviewButtons =
        (
            local background_layout = dotNetClass "System.Windows.Forms.ImageLayout"
            pnl_images.AutoScroll = false
            pnl_images.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 37 37 40


            for role_name in BlueprintManager.role_names do
            (
                local view_button = dotNetObject "System.Windows.Forms.Button"
                view_button.Name = role_name
                view_button.Width = 80
                view_button.Height = 80
                view_button.Text = role_name
                setupDarkButton view_button
                view_button.BackgroundImageLayout = background_layout.Zoom
                view_button.TabStop = false


                local context_menu = dotNetObject "System.Windows.Forms.ContextMenuStrip"
                local menu_color = dotNetClass "System.Drawing.Color"
                context_menu.BackColor = menu_color.FromArgb 45 45 48
                context_menu.ForeColor = menu_color.FromArgb 220 220 220
                context_menu.ShowImageMargin = false
                context_menu.Tag = role_name
                populatePreviewImageMenu context_menu undefined
                dotNet.addEventHandler context_menu "Opening" populatePreviewImageMenu
                view_button.ContextMenuStrip = context_menu


                pnl_images.Controls.Add view_button
                dotNet.addEventHandler view_button "MouseDown" handlePreviewMouseDown
                append preview_buttons view_button
                append preview_menus context_menu
            )
            true
            -- return
        )


        /*
        Stacks the preview and controls, then fits the native floating dialog.
        */
        function layoutControls =
        (
            local floating_dialog = isFloatingDialog()
            local canvas_height = if floating_dialog then (amin 300 preview_content_height) else 300
            local position_height = blueprintPositionsRollout.layoutPositionSliders setup_mode
            options_expanded = blueprintOptionsRollout.open
            alignment_expanded = blueprintAlignmentRollout.open
            positions_expanded = blueprintPositionsRollout.open
            if blueprintPositionsRollout.height != position_height then blueprintPositionsRollout.height = position_height
            if pnl_images.Height != canvas_height then pnl_images.Height = canvas_height
            btn_on_off.pos = [12, (pnl_images.pos.y + canvas_height + 12)]
            btn_apply_setup.pos = [150, btn_on_off.pos.y]
            chk_freeze.pos = [12, (btn_apply_setup.pos.y + btn_apply_setup.Height + 8)]
            chk_two_sided.pos = [150, chk_freeze.pos.y]


            /* One slot stacks OPTIONS, ALIGNMENT, POSITIONS with no inserted spacing. */
            sr_sections.pos = [-4, (chk_freeze.pos.y + chk_freeze.height + 8)]
            local options_height = if options_expanded then (blueprintOptionsRollout.height + 24) else 24
            local alignment_height = if alignment_expanded then (blueprintAlignmentRollout.height + 24) else 24
            local positions_height = if positions_expanded then (position_height + 24) else 24
            sr_sections.height = options_height + alignment_height + positions_height
            btn_apply_setup.Text = if setup_mode then "APPLY" else "SETUP"
            local color_class = dotNetClass "System.Drawing.Color"
            btn_apply_setup.ForeColor = if setup_mode then color_class.FromArgb 64 212 96 else color_class.FromArgb 255 156 40
            updatePreviewScrolling()
            if tooltip_provider != undefined then
            (
                local action_text = if setup_mode then "LMB: Apply assigned images and hide unused controls." else "LMB: Show all blueprint slots and position sliders.\r\n\r\nRMB: Delete managed blueprint planes and remove their empty layer after confirmation."
                tooltip_provider.SetToolTip btn_apply_setup action_text
            )


            local target_height = sr_sections.pos.y + sr_sections.height + 12
            if floating_dialog and not restoring_dialog_position and (getDialogSize blueprintManagerRollout).y != target_height then
            (
                resizing_for_mode = true
                try
                (
                    setDialogSize blueprintManagerRollout [288,target_height]
                )
                catch
                (
                    format "BM UI RESIZE ERROR | target height:% message:%\n" target_height (getCurrentException())
                )
                resizing_for_mode = false
                saveFloatingGeometry()
            )
            true
            -- return
        )


        /*
        Refreshes freeze and two-sided check states from existing scene nodes.
        Uses the current INI-backed choices when no managed nodes exist.
        */
        function updatePlaneCheckStates =
        (
            local found_nodes = 0
            local all_frozen = true
            local all_two_sided = true
            for role_name in BlueprintManager.role_names do
            (
                local target_node = BlueprintManager.getBlueprintNode role_name
                if target_node != undefined then
                (
                    found_nodes += 1
                    if not target_node.isNodeFrozen then all_frozen = false
                    if target_node.backFaceCull then all_two_sided = false
                )
            )
            if found_nodes > 0 then
            (
                chk_freeze.checked = all_frozen
                chk_two_sided.checked = all_two_sided
            )
            true
            -- return
        )


        /*
        Draws tooltips with the configured dark background and light text.
        */
        function drawDarkTooltip sender event_args =
        (
            event_args.DrawBackground()
            local text_flags = dotNetClass "System.Windows.Forms.TextFormatFlags"
            event_args.DrawText text_flags.NoPrefix
            -- return
        )


        /*
        Keeps the dialog CUI-registered in floating, left-docked and right-docked modes.
        A registered floating bar supports drag docking without losing the CUI gripper.
        */
        function changeDockMode dock_side =
        (
            if blueprintManagerRollout.dialogBar and (cui.getDockState blueprintManagerRollout) == dock_side then return true


            local prior_restoring = restoring_dialog_position
            if not prior_restoring then saveFloatingGeometry()
            restoring_dialog_position = true
            local change_ok = false
            try
            (
                if not blueprintManagerRollout.dialogBar then
                (
                    cui.RegisterDialogBar blueprintManagerRollout minSize:[288,360] maxSize:[288,-1] style:#(#cui_dock_vert, #cui_floatable, #cui_handles)
                )
                if dock_side == #cui_floatable then
                (
                    cui.FloatDialogBar blueprintManagerRollout
                )
                else if dock_side == #cui_dock_left or dock_side == #cui_dock_right then
                (
                    cui.DockDialogBar blueprintManagerRollout dock_side
                )
                change_ok = blueprintManagerRollout.dialogBar and (cui.getDockState blueprintManagerRollout) == dock_side
            )
            catch
            (
                format "BM WINDOW DOCK ERROR | mode:% | %\n" dock_side (getCurrentException())
            )
            restoring_dialog_position = prior_restoring
            if change_ok then saveDockState()
            layoutControls()
            change_ok
            -- return
        )


        /*
        Applies the docking command selected from the title button menu.
        */
        function handleDockModeMenu sender event_args =
        (
            local dock_side = case (sender.Tag as string) of
            (
                "left": #cui_dock_left
                "right": #cui_dock_right
                default: #cui_floatable
            )
            changeDockMode dock_side
            -- return
        )


        /*
        Adds explicit left, right and floating commands to the title button.
        */
        function createTitleContextMenu =
        (
            title_context_menu = dotNetObject "System.Windows.Forms.ContextMenuStrip"
            local menu_color = dotNetClass "System.Drawing.Color"
            title_context_menu.BackColor = menu_color.FromArgb 45 45 48
            title_context_menu.ForeColor = menu_color.FromArgb 220 220 220
            title_context_menu.ShowImageMargin = false
            for menu_data in #(#("Dock Left", "left"), #("Dock Right", "right"), #("Float", "floating")) do
            (
                local menu_item = dotNetObject "System.Windows.Forms.ToolStripMenuItem" menu_data[1]
                menu_item.Tag = menu_data[2]
                menu_item.BackColor = title_context_menu.BackColor
                menu_item.ForeColor = title_context_menu.ForeColor
                menu_item.Owner = title_context_menu
                dotNet.addEventHandler menu_item "Click" handleDockModeMenu
            )
            btn_tool_title.ContextMenuStrip = title_context_menu
            -- return
        )


        on blueprintManagerRollout open do
        (
            ToolTitleButton.setupToolTitleButton btn_tool_title "Blueprint Manager"
            ToolTitleButton.resizeToolTitleButton btn_tool_title 264
            btn_on_off.Text = "ON \\ OFF"
            setupDarkButton btn_on_off
            btn_apply_setup.Text = "APPLY"
            setupDarkButton btn_apply_setup
            tooltip_provider = dotNetObject "System.Windows.Forms.ToolTip"
            local color_class = dotNetClass "System.Drawing.Color"
            tooltip_provider.BackColor = color_class.FromArgb 45 45 48
            tooltip_provider.ForeColor = color_class.FromArgb 220 220 220
            tooltip_provider.OwnerDraw = true
            dotNet.addEventHandler tooltip_provider "Draw" drawDarkTooltip
            tooltip_provider.AutoPopDelay = 20000
            tooltip_provider.InitialDelay = 500
            tooltip_provider.ReshowDelay = 200
            tooltip_provider.ShowAlways = true
            tooltip_provider.SetToolTip btn_tool_title "LMB: Restart Blueprint Manager.\r\n\r\nRMB: Dock left, dock right, or float.\r\n\r\nDrag the title or gripper to dock left/right."
            tooltip_provider.SetToolTip btn_on_off "LMB: Show all blueprint planes.\r\n\r\nRMB: Hide all blueprint planes."
            tooltip_provider.SetToolTip btn_apply_setup "LMB: Apply images or return to blueprint setup.\r\n\r\nRMB (SETUP): Delete managed blueprint planes after confirmation."
            createTitleContextMenu()
            createPreviewButtons()
            tmr_preview_click.interval = (dotNetClass "System.Windows.Forms.SystemInformation").DoubleClickTime
            addSubRollout sr_sections blueprintOptionsRollout
            addSubRollout sr_sections blueprintAlignmentRollout
            addSubRollout sr_sections blueprintPositionsRollout
            loadUiState()
            blueprintAlignmentRollout.loadAlignmentState()
            layoutPreviews()
            blueprintPositionsRollout.updatePositionRanges blueprintOptionsRollout.spn_pixel_scale.value
            updatePlaneCheckStates()
            layoutControls()
        )


        on blueprintManagerRollout moved dialog_pos do
        (
            if not restoring_dialog_position and not resizing_for_mode then
            (
                saveFloatingGeometry()
            )
        )


        on blueprintManagerRollout resized dialog_size do
        (
            ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
        )


        on tmr_preview_click tick do
        (
            tmr_preview_click.active = false
            local click_role = pending_preview_role
            pending_preview_role = ""
            pending_preview_position = undefined
            if click_role != "" then handlePreviewSingleClick click_role
        )


        on tmr_dialog_state tick do
        (
            if not restoring_dialog_position and not resizing_for_mode then
            (
                updateOnOffButtonColor()
                if saveDockState() or (options_expanded != blueprintOptionsRollout.open) or (positions_expanded != blueprintPositionsRollout.open) or (alignment_expanded != blueprintAlignmentRollout.open) then
                (
                    layoutControls()
                )
                saveFloatingGeometry()
            )
        )


        on blueprintManagerRollout close do
        (
            tmr_dialog_state.active = false
            tmr_preview_click.active = false
            pending_preview_role = ""
            pending_preview_position = undefined
            if not restoring_dialog_position then
            (
                if last_dock_state == #cui_floatable then saveFloatingGeometry()
            )
            saveUiState()
            removeSubRollout sr_sections blueprintPositionsRollout
            removeSubRollout sr_sections blueprintAlignmentRollout
            removeSubRollout sr_sections blueprintOptionsRollout
            for preview_image in preview_images do
            (
                if preview_image != undefined then preview_image.Dispose()
            )
            for context_menu in preview_menus do
            (
                if context_menu != undefined then context_menu.Dispose()
            )
            preview_menus = #()
            preview_menu_items = #(#(), #(), #(), #(), #())
            if title_context_menu != undefined then
            (
                title_context_menu.Dispose()
                title_context_menu = undefined
            )
            if tooltip_provider != undefined then
            (
                tooltip_provider.Dispose()
                tooltip_provider = undefined
            )
        )


        on btn_tool_title Click sender event_args do
        (
            restartTool script_path "Blueprint-Manager"
        )


        /*
        Deletes blueprint scene nodes after confirming the SETUP right-click action.
        Keeps image paths assigned so the user can create blueprints again.
        */
        function deleteBlueprintsFromSetup =
        (
            if setup_mode then return false
            local managed_count = 0
            for role_name in BlueprintManager.role_names do
            (
                if BlueprintManager.getBlueprintNode role_name != undefined then managed_count += 1
            )
            if managed_count == 0 then return false
            if not (queryBox ("Delete " + (managed_count as string) + " managed blueprint plane(s) and remove their layer if empty?") title:"Blueprint Manager") then return false


            local deleted_count = -1
            undo "Blueprint Manager Delete" on
            (
                deleted_count = BlueprintManager.deleteManagedBlueprints()
            )
            if deleted_count < 0 then return false


            setup_mode = true
            layoutPreviews()
            blueprintPositionsRollout.updatePositionRanges blueprintOptionsRollout.spn_pixel_scale.value
            updatePlaneCheckStates()
            layoutControls()
            saveUiState()
            true
            -- return
        )


        on btn_on_off MouseDown sender event_args do
        (
            local mouse_button = dotNetClass "System.Windows.Forms.MouseButtons"
            if event_args.Button == mouse_button.Left then
            (
                BlueprintManager.setVisibilityState true
                layoutPreviews()
            )
            else if event_args.Button == mouse_button.Right then
            (
                BlueprintManager.setVisibilityState false
                layoutPreviews()
            )
        )


        on btn_apply_setup MouseDown sender event_args do
        (
            local mouse_button = dotNetClass "System.Windows.Forms.MouseButtons"
            if event_args.Button == mouse_button.Right then deleteBlueprintsFromSetup()
        )


        on btn_apply_setup Click sender event_args do
        (
            if setup_mode then
            (
                undo "Blueprint Manager Apply" on
                (
                    local applied_count = BlueprintManager.createAll blueprintOptionsRollout.spn_pixel_scale.value blueprintOptionsRollout.sld_opacity.value
                    if applied_count == 0 then
                    (
                        messageBox "No blueprint planes created. Check image assignments and Layer Name (see Listener)." title:"Blueprint Manager"
                    )
                    else
                    (
                        BlueprintManager.setFreezeState chk_freeze.checked
                        BlueprintManager.setTwoSidedState chk_two_sided.checked
                        setup_mode = false
                        format "BM APPLY | created/updated % blueprint planes\n" applied_count
                    )
                )
            )
            else
            (
                setup_mode = true
            )
            layoutPreviews()
            blueprintPositionsRollout.updatePositionRanges blueprintOptionsRollout.spn_pixel_scale.value
            updatePlaneCheckStates()
            layoutControls()
            saveUiState()
        )


        on chk_freeze changed freeze_enabled do
        (
            undo "Blueprint Manager Freeze" on
            (
                BlueprintManager.setFreezeState freeze_enabled
            )
            IniSettings.setBoolean ini_path ini_section "Freeze" freeze_enabled
        )


        on chk_two_sided changed two_sided_enabled do
        (
            undo "Blueprint Manager Two-Sided" on
            (
                BlueprintManager.setTwoSidedState two_sided_enabled
            )
            IniSettings.setBoolean ini_path ini_section "TwoSided" two_sided_enabled
        )


    )
