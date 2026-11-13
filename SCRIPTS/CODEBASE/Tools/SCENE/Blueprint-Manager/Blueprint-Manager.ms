/*
Blueprint Manager v0.028 — five reference-image planes in 3ds Max.
Runtime requires the canonical shared MaxScript UI/Default framework.
*/
(
    local project_version = "0.028"
    local script_path = getSourceFileName()
    if script_path == undefined or script_path == "" then
    (
        throw "Blueprint Manager: run the saved Blueprint-Manager.ms file, not pasted Listener text."
    )

    local script_dir = getFilenamePath script_path
    local ini_path = script_dir + "Blueprint-Manager.ini"
    local ini_section = "MainUI"
    local ui_framework_candidates = #(
        "G:\\AI\\AGENTS\\Maxscript\\UI\\Default\\",
        "C:\\GoogleDrive\\AI\\AGENTS\\Maxscript\\UI\\Default\\",
        "D:\\GoogleDrive\\AI\\AGENTS\\Maxscript\\UI\\Default\\"
    )
    local framework_dir = ""

    for candidate_dir in ui_framework_candidates while framework_dir == "" do
    (
        if doesFileExist (candidate_dir + "ToolTitleButton.ms") then
        (
            framework_dir = candidate_dir
        )
    )
    if framework_dir == "" then
    (
        throw "Blueprint Manager: shared UI/Default framework not found. See README.md for expected location."
    )

    fileIn (framework_dir + "IniSettings.ms")
    fileIn (framework_dir + "RolloutState.ms")
    fileIn (framework_dir + "DialogHost.ms")
    fileIn (framework_dir + "ScriptReload.ms")
    fileIn (framework_dir + "ToolTitleButton.ms")

    /*
    Loads the canonical dark WinForms button style without copying its implementation.
    */
    local dark_button_template = framework_dir + "..\\default-dark-button.ms"
    if not doesFileExist dark_button_template then
    (
        throw ("Blueprint Manager: shared dark button template not found: " + dark_button_template)
    )
    fileIn dark_button_template

    /*
    Prevents dialog lifecycle events from saving a transient opening position.
    */
    local restoring_dialog_position = true

    /*
    Owns blueprint paths and operations without referring to rollout controls.
    Path ordering follows the cross-layout: TOP, FRONT, SIDE, BACK, BOTTOM.
    */
    struct BlueprintManager_v
    (
        role_names = #("TOP", "FRONT", "SIDE", "BACK", "BOTTOM"),
        image_paths = #("", "", "", "", ""),
        image_candidates = #(#(), #(), #(), #(), #()),
        position_offsets_mm = #(0.0, 0.0, 0.0, 0.0, 0.0),

        /*
        Returns an index for a named blueprint role, or zero when absent.
        */
        function getRoleIndex role_name =
        (
            findItem role_names role_name
            -- return
        ),

        /*
        Validates image filename extensions supported by both GDI+ and BitmapTexture.
        */
        function isImageFile file_path =
        (
            (findItem #(".png", ".jpg", ".jpeg", ".bmp", ".tif", ".tiff") (toLower (getFilenameType file_path))) > 0
            -- return
        ),

        /*
        Reads the actual image resolution in pixels; returns undefined on no path.
        */
        function readImageSize file_path =
        (
            if file_path == "" or not doesFileExist file_path then
            (
                format "BM ERROR | Missing image: %\n" file_path
                return undefined
            )

            local bitmap_ref = openBitmap file_path
            local image_size = [bitmap_ref.width, bitmap_ref.height]
            close bitmap_ref
            image_size
            -- return
        ),

        /*
        Retrieves the existing tagged Plane for the requested role, if any.
        */
        function getBlueprintNode role_name =
        (
            local result_node = undefined
            for scene_node in geometry while result_node == undefined do
            (
                if (getUserPropVal scene_node "BM_ROLE") == role_name then
                (
                    result_node = scene_node
                )
            )
            result_node
            -- return
        ),

        /*
        Adds an image to a view and optionally selects it without altering geometry.
        */
        function assignImage role_index file_path activate:true =
        (
            if role_index < 1 or role_index > 5 or not doesFileExist file_path or not isImageFile file_path then
            (
                format "BM ERROR | Invalid image assignment: role:% file:%\n" role_index file_path
                return false
            )
            local image_size = try (readImageSize file_path) catch
            (
                format "BM ERROR | Could not read %: %\n" file_path (getCurrentException())
                undefined
            )
            if image_size == undefined then return false

            local candidate_paths = image_candidates[role_index]
            local path_key = toLower file_path
            local existing_path = undefined
            for candidate_path in candidate_paths while existing_path == undefined do
            (
                if (toLower candidate_path) == path_key then existing_path = candidate_path
            )
            if existing_path == undefined then
            (
                append candidate_paths file_path
                existing_path = file_path
            )
            if activate or image_paths[role_index] == "" then image_paths[role_index] = existing_path
            true
            -- return
        ),

        /*
        Clears an assigned blueprint and removes only its matching managed Plane.
        Returns true only after the managed Plane is absent from the scene.
        */
        function resetBlueprint role_index =
        (
            local reset_ok = false
            if role_index < 1 or role_index > role_names.count then
            (
                format "BM RESET ERROR | Invalid blueprint role index: %\n" role_index
            )
            else
            (
                local role_name = role_names[role_index]
                local target_node = getBlueprintNode role_name
                if target_node != undefined and (classOf target_node.baseObject) != Plane then
                (
                    format "BM RESET ERROR | Managed role is not a Plane | role:% node:% class:%\n" role_name target_node.name (classOf target_node.baseObject)
                )
                else
                (
                    if target_node != undefined then
                    (
                        delete target_node
                    )
                    reset_ok = ((getBlueprintNode role_name) == undefined)
                    if reset_ok then
                    (
                        image_paths[role_index] = ""
                        image_candidates[role_index] = #()
                        position_offsets_mm[role_index] = 0.0
                    )
                    else
                    (
                        format "BM RESET ERROR | Managed Plane was not removed | role:%\n" role_name
                    )
                )
            )
            reset_ok
            -- return
        ),

        /*
        Resolves one file to a role by wildcard matching any part of its basename.
        Returns 0 (unmatched), -1 (ambiguous), or a slot index.
        */
        function classifyFilename file_path =
        (
            local base_name = toLower (getFilenameFile file_path)
            local found_roles = #()
            if matchPattern base_name pattern:"*top*" then append found_roles 1
            if matchPattern base_name pattern:"*front*" then append found_roles 2
            if matchPattern base_name pattern:"*side*" or matchPattern base_name pattern:"*left*" or matchPattern base_name pattern:"*right*" then append found_roles 3
            if matchPattern base_name pattern:"*back*" then append found_roles 4
            if matchPattern base_name pattern:"*bottom*" then append found_roles 5

            if found_roles.count > 1 then -1
            else if found_roles.count == 1 then found_roles[1]
            else 0
            -- return
        ),

        /*
        Adds every unambiguous image to its view in filename order.
        Returns #(views_with_images, ambiguous_files).
        */
        function assignFolder folder_path =
        (
            local imported_views = #(false, false, false, false, false)
            local imported_count = 0
            local conflict_count = 0
            local folder_files = getFiles (folder_path + "\\*.*")
            sort folder_files
            for file_path in folder_files where isImageFile file_path do
            (
                local role_index = classifyFilename file_path
                if role_index == 3 then
                (
                    local base_name = getFilenameFile file_path
                    if (matchPattern base_name pattern:"*left*" ignoreCase:true) and
                        (matchPattern base_name pattern:"*right*" ignoreCase:true) then role_index = -1
                )
                if role_index == -1 then
                (
                    conflict_count += 1
                    format "BM CONFLICT | Multiple role tokens in %\n" file_path
                )
                else if role_index > 0 then
                (
                    if assignImage role_index file_path activate:false then
                    (
                        if not imported_views[role_index] then imported_count += 1
                        imported_views[role_index] = true
                    )
                )
            )
            #(imported_count, conflict_count)
            -- return
        ),

        /*
        Computes the image plane width and height in 3ds Max system units.
        One image pixel is 1 mm by default, independent of display units.
        */
        function getPlaneSize role_index mm_per_pixel =
        (
            local image_size = readImageSize image_paths[role_index]
            if image_size == undefined then return undefined
            local mm_unit = units.decodeValue "1mm"
            [(image_size.x * mm_per_pixel * mm_unit), (image_size.y * mm_per_pixel * mm_unit)]
            -- return
        ),

        /*
        Collects assigned Plane dimensions and the three virtual-box spans.
        Returns #(five plane sizes, span Point3) in current system units.
        */
        function getSceneLayout mm_per_pixel =
        (
            local plane_sizes = #(undefined, undefined, undefined, undefined, undefined)
            local span_x = 0.0
            local span_y = 0.0
            local span_z = 0.0
            local reference_extent = 0.0

            for role_index = 1 to 5 do
            (
                if image_paths[role_index] != "" then
                (
                    local plane_size = getPlaneSize role_index mm_per_pixel
                    plane_sizes[role_index] = plane_size
                    if plane_size != undefined then
                    (
                        if plane_size.x > reference_extent then reference_extent = plane_size.x
                        if plane_size.y > reference_extent then reference_extent = plane_size.y
                        case role_index of
                        (
                            1: (if plane_size.x > span_x then span_x = plane_size.x; if plane_size.y > span_y then span_y = plane_size.y)
                            2: (if plane_size.x > span_x then span_x = plane_size.x; if plane_size.y > span_z then span_z = plane_size.y)
                            3: (if plane_size.x > span_y then span_y = plane_size.x; if plane_size.y > span_z then span_z = plane_size.y)
                            4: (if plane_size.x > span_x then span_x = plane_size.x; if plane_size.y > span_z then span_z = plane_size.y)
                            5: (if plane_size.x > span_x then span_x = plane_size.x; if plane_size.y > span_y then span_y = plane_size.y)
                        )
                    )
                )
            )

            if span_x == 0.0 then span_x = reference_extent
            if span_y == 0.0 then span_y = reference_extent
            if span_z == 0.0 then span_z = reference_extent

            #(plane_sizes, [span_x, span_y, span_z])
            -- return
        ),

        /*
        Returns five slider limits in millimeters, measured from neighboring views.
        A role without a perpendicular reference has no defined travel range.
        */
        function getPositionRangesMm layout_data =
        (
            local plane_sizes = layout_data[1]
            local travel_z = 0.0
            local travel_y = 0.0
            local travel_x = 0.0
            local mm_unit = units.decodeValue "1mm"

            for role_index in #(2, 3, 4) do
            (
                if plane_sizes[role_index] != undefined then
                (
                    if plane_sizes[role_index].y > travel_z then travel_z = plane_sizes[role_index].y
                )
            )

            if plane_sizes[3] != undefined then
            (
                travel_y = plane_sizes[3].x
            )
            else
            (
                for role_index in #(1, 5) do
                (
                    if plane_sizes[role_index] != undefined and plane_sizes[role_index].y > travel_y then travel_y = plane_sizes[role_index].y
                )
            )

            if plane_sizes[2] != undefined then travel_x = plane_sizes[2].x
            else if plane_sizes[4] != undefined then travel_x = plane_sizes[4].x
            else
            (
                for role_index in #(1, 5) do
                (
                    if plane_sizes[role_index] != undefined and plane_sizes[role_index].x > travel_x then travel_x = plane_sizes[role_index].x
                )
            )

            #(travel_z / mm_unit, travel_y / mm_unit, travel_x / mm_unit, travel_y / mm_unit, travel_z / mm_unit)
            -- return
        ),

        /*
        Moves one managed plane along its current local Z without cumulative drift.
        The offset is measured inward from its virtual-box wall in millimeters.
        */
        function setPositionOffset role_index offset_mm =
        (
            if role_index < 1 or role_index > 5 or offset_mm < 0.0 then
            (
                format "BM ERROR | Invalid position offset | role:% offset_mm:%\n" role_index offset_mm
                return false
            )

            local target_node = getBlueprintNode role_names[role_index]
            if target_node != undefined then
            (
                local old_offset_mm = getUserPropVal target_node "BM_OFFSET_MM"
                if old_offset_mm == undefined then old_offset_mm = 0.0
                local delta_units = (offset_mm - old_offset_mm) * (units.decodeValue "1mm")
                target_node.pos = target_node.pos + (target_node.transform.row3 * delta_units)
                setUserPropVal target_node "BM_OFFSET_MM" offset_mm
                redrawViews()
            )
            position_offsets_mm[role_index] = offset_mm
            true
            -- return
        ),

        /*
        Computes the orthonormal plane transform from view orientation and box spans.
        Plane +Z normals always face the scene origin.
        */
        function getPlaneTransform role_name span_x span_y span_z image_path =
        (
            case role_name of
            (
                "TOP":    (matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,(-span_z / 2.0)])
                "BOTTOM": (matrix3 [-1,0,0] [0,1,0] [0,0,-1] [0,0,(span_z / 2.0)])
                "FRONT":  (matrix3 [1,0,0] [0,0,1] [0,-1,0] [0,(span_y / 2.0),0])
                "BACK":   (matrix3 [-1,0,0] [0,0,1] [0,1,0] [0,(-span_y / 2.0),0])
                "SIDE":
                (
                    if matchPattern (getFilenameFile image_path) pattern:"*right*" then
                    (
                        matrix3 [0,1,0] [0,0,1] [1,0,0] [(-span_x / 2.0),0,0]
                    )
                    else
                    (
                        matrix3 [0,-1,0] [0,0,1] [-1,0,0] [(span_x / 2.0),0,0]
                    )
                )
            )
            -- return
        ),

        /*
        Creates or updates a managed blueprint plane and its Standard bitmap material.
        Leaves unrelated scene geometry untouched.
        */
        function createOrUpdate role_index plane_size scene_transform opacity_value =
        (
            local role_name = role_names[role_index]
            local file_path = image_paths[role_index]
            local target_node = getBlueprintNode role_name
            local is_new_node = target_node == undefined

            if is_new_node then
            (
                target_node = Plane name:("BM_" + role_name) width:plane_size.x length:plane_size.y widthsegs:1 lengthsegs:1 mapcoords:true
            )
            else if (classOf target_node.baseObject) != Plane then
            (
                format "BM ERROR | Tagged object is not Plane | role:% node:% class:%\n" role_name target_node.name (classOf target_node.baseObject)
                return false
            )

            target_node.width = plane_size.x
            target_node.length = plane_size.y
            target_node.mapCoords = true
            target_node.realWorldMapSize = false
            target_node.transform = scene_transform
            local offset_mm = position_offsets_mm[role_index]
            target_node.pos = target_node.pos + (scene_transform.row3 * (offset_mm * units.decodeValue "1mm"))
            target_node.wireColor = color 128 128 128
            target_node.showFrozenInGray = false

            local bitmap_map = bitmapTexture filename:file_path
            bitmap_map.coords.realWorldScale = false
            local image_material = standardMaterial name:("BM_MTL_" + role_name) diffuseMap:bitmap_map diffuseMapEnable:true opacity:opacity_value selfIllumAmount:100 twoSided:true
            target_node.material = image_material
            showTextureMap image_material bitmap_map true

            setUserPropVal target_node "BM_ROLE" role_name
            setUserPropVal target_node "BM_FILE" file_path
            setUserPropVal target_node "BM_OFFSET_MM" offset_mm
            if is_new_node then
            (
                target_node.isFrozen = true
            )
            true
            -- return
        ),

        /*
        Creates only assigned planes; their centres form a virtual box about [0,0,0].
        Updates managed planes without creating duplicates.
        */
        function createAll mm_per_pixel opacity_value existing_only:false =
        (
            local layout_data = getSceneLayout mm_per_pixel
            local plane_sizes = layout_data[1]
            local scene_spans = layout_data[2]
            local created_count = 0

            for role_index = 1 to 5 do
            (
                if plane_sizes[role_index] != undefined and
                    (not existing_only or (getBlueprintNode role_names[role_index]) != undefined) then
                (
                    local plane_transform = getPlaneTransform role_names[role_index] scene_spans.x scene_spans.y scene_spans.z image_paths[role_index]
                    if createOrUpdate role_index plane_sizes[role_index] plane_transform opacity_value then
                    (
                        created_count += 1
                    )
                )
            )
            redrawViews()
            created_count
            -- return
        ),

        /*
        Toggles one managed plane, returning true only when a plane exists.
        */
        function toggleOne role_name =
        (
            local target_node = getBlueprintNode role_name
            if target_node == undefined then return false
            target_node.isNodeHidden = not target_node.isNodeHidden
            redrawViews()
            true
            -- return
        ),

        /*
        Shows all planes if any is hidden; otherwise hides all managed planes.
        */
        function toggleAll =
        (
            local found_nodes = #()
            local any_hidden = false
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined then
                (
                    append found_nodes target_node
                    if target_node.isNodeHidden then any_hidden = true
                )
            )
            for target_node in found_nodes do
            (
                target_node.isNodeHidden = not any_hidden
            )
            if found_nodes.count > 0 then redrawViews()
            found_nodes.count
            -- return
        ),

        /*
        Updates opacity on each existing managed Standard material.
        */
        function setOpacity opacity_value =
        (
            local updated_count = 0
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined and target_node.material != undefined then
                (
                    if isKindOf target_node.material StandardMaterial then
                    (
                        target_node.material.opacity = opacity_value
                        updated_count += 1
                    )
                )
            )
            if updated_count > 0 then redrawViews()
            updated_count
            -- return
        ),

        /*
        Sets the frozen state of all managed planes from a checked UI toggle.
        Keeps the blueprint image colors while frozen.
        */
        function setFreezeState freeze_enabled =
        (
            local updated_count = 0
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined then
                (
                    target_node.isFrozen = freeze_enabled
                    target_node.showFrozenInGray = false
                    updated_count += 1
                )
            )
            if updated_count > 0 then redrawViews()
            updated_count
            -- return
        ),

        /*
        Sets viewport back-face culling and material two-sided display together.
        Checked TWO-SIDED means back faces remain visible.
        */
        function setTwoSidedState two_sided_enabled =
        (
            local updated_count = 0
            for role_name in role_names do
            (
                local target_node = getBlueprintNode role_name
                if target_node != undefined then
                (
                    target_node.backFaceCull = not two_sided_enabled
                    if target_node.material != undefined and isKindOf target_node.material StandardMaterial then
                    (
                        target_node.material.twoSided = two_sided_enabled
                    )
                    updated_count += 1
                )
            )
            if updated_count > 0 then redrawViews()
            updated_count
            -- return
        ),

        on create do
        (
        )
    )

    global BlueprintManager
    BlueprintManager = BlueprintManager_v()

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
            12 + 36 * row_count
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

    rollout blueprintManagerRollout ("Blueprint Manager v" + project_version) width:288 height:780 autoLayoutOnResize:false
    (
        local setup_mode = true
        local positions_expanded = true
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

        dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:264 height:20
        dotNetControl pnl_images "System.Windows.Forms.Panel" pos:[12,44] width:264 height:300
        subRollout sr_positions "" pos:[12,356] width:264 height:228 scrollBar:#off
        spinner spn_pixel_scale "RATIO 1px" pos:[24,596] width:88 align:#left offset:[0,0] range:[0.0001,10000.0,1.0] type:#float fieldWidth:36 toolTip:"Sets millimeters per image pixel.\r\n\r\nApplied by APPLY."
        label lbl_pixel_scale_unit "mm" pos:[118,598] width:24
        slider sld_opacity "Opacity" pos:[12,629] width:264 height:42 range:[0,100,100] type:#integer ticks:0 toolTip:"LMB: Adjust blueprint opacity.\r\n\r\nAlso used by APPLY."
        dotNetControl btn_apply_setup "System.Windows.Forms.Button" pos:[12,686] width:264 height:30
        checkbutton chk_freeze "FREEZE" pos:[12,724] width:126 height:30 checked:true toolTip:"LMB: Freeze or unfreeze all blueprint planes."
        checkbutton chk_two_sided "TWO-SIDED" pos:[150,724] width:126 height:30 checked:true toolTip:"LMB: Show or cull the back faces of blueprint planes."

        timer tmr_dialog_state interval:750 active:false

        /*
        Identifies the native floating dialog before reading or writing its geometry.
        */
        function isFloatingDialog =
        (
            blueprintManagerRollout.hwnd != 0 and not blueprintManagerRollout.dialogBar
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
            if not (isFloatingDialog()) then return false

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
                    "LMB: Assign an image.\r\n\r\nRMB: Choose an image or manage this blueprint.\r\n\r\nCTRL + LMB: Toggle all blueprint visibility."
                )
                else
                (
                    "LMB: Toggle this blueprint visibility.\r\n\r\nRMB: Choose an image or manage this blueprint.\r\n\r\nCTRL + LMB: Toggle all blueprint visibility."
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
            true
            -- return
        )

        /*
        Saves file assignments and the current numeric settings to the local INI.
        */
        function saveUiState =
        (
            RolloutState.saveSpinner spn_pixel_scale ini_path ini_section "MillimetersPerPixel"
            IniSettings.setInteger ini_path ini_section "Opacity" sld_opacity.value
            IniSettings.setBoolean ini_path ini_section "SetupMode" setup_mode
            IniSettings.setBoolean ini_path ini_section "Freeze" chk_freeze.checked
            IniSettings.setBoolean ini_path ini_section "TwoSided" chk_two_sided.checked
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
            RolloutState.loadSpinner spn_pixel_scale ini_path ini_section "MillimetersPerPixel" default_value:1.0
            sld_opacity.value = IniSettings.getInteger ini_path ini_section "Opacity" default_value:100
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
                blueprintPositionsRollout.updatePositionRanges spn_pixel_scale.value
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
                        blueprintPositionsRollout.updatePositionRanges spn_pixel_scale.value
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
        Handles the primary and Ctrl-modified left-click image-button actions.
        Right-clicks are handled by the button's native WinForms context menu.
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
                    BlueprintManager.toggleAll()
                )
                else if BlueprintManager.image_paths[role_index] == "" then
                (
                    local file_path = getOpenFileName caption:("Blueprint: " + role_name) types:"Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff|"
                    if file_path != undefined then BlueprintManager.assignImage role_index file_path
                )
                else
                (
                    BlueprintManager.toggleOne role_name
                )
                layoutPreviews()
                blueprintPositionsRollout.updatePositionRanges spn_pixel_scale.value
                blueprintManagerRollout.layoutControls()
                saveUiState()
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
                    BlueprintManager.createAll spn_pixel_scale.value sld_opacity.value existing_only:true
                    BlueprintManager.setTwoSidedState chk_two_sided.checked
                )
            )
            layoutPreviews()
            blueprintPositionsRollout.updatePositionRanges spn_pixel_scale.value
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
            positions_expanded = blueprintPositionsRollout.open
            if pnl_images.Height != canvas_height then pnl_images.Height = canvas_height
            sr_positions.pos = [12, (pnl_images.pos.y + canvas_height + 12)]
            sr_positions.height = if positions_expanded then position_height + 24 else 24

            local scale_y = sr_positions.pos.y + sr_positions.height + 12
            /* Anchor the native spinner near its field edge when moving the row at runtime. */
            spn_pixel_scale.pos = [100, scale_y]
            lbl_pixel_scale_unit.pos = [118, (scale_y + 2)]
            sld_opacity.pos = [12, (scale_y + 36)]
            btn_apply_setup.pos = [12, (sld_opacity.pos.y + 36)]
            chk_freeze.pos = [12, (btn_apply_setup.pos.y + btn_apply_setup.Height + 8)]
            chk_two_sided.pos = [150, chk_freeze.pos.y]
            btn_apply_setup.Text = if setup_mode then "APPLY" else "SETUP"
            local color_class = dotNetClass "System.Drawing.Color"
            btn_apply_setup.ForeColor = if setup_mode then color_class.FromArgb 64 212 96 else color_class.FromArgb 255 156 40
            updatePreviewScrolling()
            if tooltip_provider != undefined then
            (
                local action_text = if setup_mode then "LMB: Apply assigned images and hide unused controls." else "LMB: Show all blueprint slots and position sliders for setup."
                tooltip_provider.SetToolTip btn_apply_setup action_text
            )

            local target_height = chk_freeze.pos.y + chk_freeze.height + 12
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
        Registers the rollout only when docking and restores its native window on undock.
        */
        function changeDockMode dock_side =
        (
            if dock_side == #cui_floatable and isFloatingDialog() then return true

            local prior_restoring = restoring_dialog_position
            if not prior_restoring then saveFloatingGeometry()
            restoring_dialog_position = true
            local change_ok = false
            try
            (
                if dock_side == #cui_floatable then
                (
                    if blueprintManagerRollout.dialogBar then cui.UnRegisterDialogBar blueprintManagerRollout
                    restoreFloatingGeometry()
                    change_ok = isFloatingDialog()
                )
                else
                (
                    if not blueprintManagerRollout.dialogBar then
                    (
                        cui.RegisterDialogBar blueprintManagerRollout minSize:[288,360] style:#(#cui_dock_vert, #cui_floatable, #cui_handles)
                    )
                    cui.DockDialogBar blueprintManagerRollout dock_side
                    change_ok = (cui.getDockState blueprintManagerRollout) == dock_side
                )
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
            tooltip_provider.SetToolTip btn_tool_title "LMB: Restart Blueprint Manager.\r\n\r\nRMB: Dock left, dock right, or float."
            tooltip_provider.SetToolTip btn_apply_setup "LMB: Apply images or return to blueprint setup."
            createTitleContextMenu()
            createPreviewButtons()
            addSubRollout sr_positions blueprintPositionsRollout
            loadUiState()
            layoutPreviews()
            blueprintPositionsRollout.updatePositionRanges spn_pixel_scale.value
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

        on tmr_dialog_state tick do
        (
            if not restoring_dialog_position and not resizing_for_mode then
            (
                if blueprintManagerRollout.dialogBar and (cui.getDockState blueprintManagerRollout) == #cui_floatable then
                (
                    changeDockMode #cui_floatable
                )
                else if saveDockState() or (positions_expanded != blueprintPositionsRollout.open) then
                (
                    layoutControls()
                )
                saveFloatingGeometry()
            )
        )

        on blueprintManagerRollout close do
        (
            tmr_dialog_state.active = false
            if not restoring_dialog_position then
            (
                if last_dock_state == #cui_floatable then saveFloatingGeometry()
            )
            saveUiState()
            removeSubRollout sr_positions blueprintPositionsRollout
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

        on btn_apply_setup Click sender event_args do
        (
            if setup_mode then
            (
                undo "Blueprint Manager Apply" on
                (
                    local applied_count = BlueprintManager.createAll spn_pixel_scale.value sld_opacity.value
                    if applied_count == 0 then
                    (
                        messageBox "No blueprint images assigned." title:"Blueprint Manager"
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
            blueprintPositionsRollout.updatePositionRanges spn_pixel_scale.value
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

    /*
    Close any prior tool instance before validating the INI.
    The prior version may save its window position during its close callback.
    */
    DialogHost.destroyToolDialogs "Blueprint-Manager"
    local initial_pos = IniSettings.getPoint2 ini_path ini_section "PosX" "PosY" default_value:[100,100]
    local initial_height = IniSettings.getInteger ini_path ini_section "Height" default_value:636
    createDialog blueprintManagerRollout width:288 height:(amax 1 initial_height) pos:initial_pos \
        style:#(#style_titlebar, #style_border, #style_sysmenu) lockWidth:true lockHeight:true
    windows.processPostedMessages()
    blueprintManagerRollout.restoreFloatingGeometry()
    DialogHost.registerToolDialog "Blueprint-Manager" blueprintManagerRollout

    case (getINISetting ini_path ini_section "DockSide") of
    (
        "left": blueprintManagerRollout.changeDockMode #cui_dock_left
        "right": blueprintManagerRollout.changeDockMode #cui_dock_right
    )
    windows.processPostedMessages()
    restoring_dialog_position = false
    blueprintManagerRollout.saveDockState()
    blueprintManagerRollout.layoutControls()
    blueprintManagerRollout.saveFloatingGeometry()
    blueprintManagerRollout.tmr_dialog_state.active = true
)
