/* WORLD SYMMETRY - startup service and UI v0.02
   Install in getDir #userStartupScripts. No helpers or scene nodes are created by startup.
   Scene open/new only binds a delayed transform event; no alignment is run on initialization.
   Open the UI via Customize User Interface > Vilbur > World Symmetry,
   or call world_symmetry_manager.openUi() from the MAXScript Listener.
*/

global world_symmetry_manager
global world_symmetry_script_path
global world_symmetry_ini_path
global worldSymmetryRollout

world_symmetry_script_path = getSourceFileName()
world_symmetry_ini_path = (getFilenamePath world_symmetry_script_path) + "World-Symmetry.ini"

struct WorldSymmetryManager_v
(
    watched_nodes = #(),
    transform_handler = undefined,
    is_aligning = false,
    precision_mm = 0.01,

    /*
    Returns the axis encoded in an explicitly named WORLD SYMMETRY modifier.
    Returns -1 for a modifier that is not managed by this service.
    */
    function getAxisIndex modifier_name =
    (
        case (toUpper (modifier_name as string)) of
        (
            "WORLD SYMMETRY X": 0
            "WORLD SYMMETRY Y": 1
            "WORLD SYMMETRY Z": 2
            default: -1
        )
        -- return
    ),

    /*
    Returns the managed uppercase modifier name for an axis index.
    The function returns an empty string for invalid input.
    */
    function getAxisName axis_index =
    (
        case axis_index of
        (
            0: "WORLD SYMMETRY X"
            1: "WORLD SYMMETRY Y"
            2: "WORLD SYMMETRY Z"
            default: ""
        )
        -- return
    ),

    /*
    Converts the explicitly selected position precision from millimeters.
    All comparisons use the active 3ds Max system units.
    */
    function getPositionPrecision =
    (
        case precision_mm of
        (
            1.0: (units.decodeValue "1mm")
            0.1: (units.decodeValue "0.1mm")
            default: (units.decodeValue "0.01mm")
        )
        -- return
    ),

    /*
    Rounds only a temporary comparison copy of a Point3 to the selected precision.
    Source transforms and scene geometry remain completely unrounded.
    */
    function roundPositionToPrecision position_value position_precision =
    (
        [
            (round (position_value.x / position_precision)) * position_precision,
            (round (position_value.y / position_precision)) * position_precision,
            (round (position_value.z / position_precision)) * position_precision]
        -- return
    ),

    /*
    Returns the first managed Symmetry of the requested axis on a node.
    No unrelated native Symmetry modifiers are adopted or changed.
    */
    function findAxisModifier node_item axis_index =
    (
        local found_mod = undefined
        local required_name = getAxisName axis_index

        if ((isValidNode node_item) and (required_name != "")) then
        (
            for stack_mod in node_item.modifiers while (found_mod == undefined) do
            (
                if ((classOf stack_mod == Symmetry) and ((toUpper stack_mod.name) == required_name)) then
                (
                    found_mod = stack_mod
                )
            )
        )

        found_mod
        -- return
    ),

    /*
    Returns true when at least one named managed Symmetry exists on a node.
    This test does not modify the stack or the gizmo.
    */
    function hasWorldSymmetry node_item =
    (
        local found = false

        if (isValidNode node_item) then
        (
            for stack_mod in node_item.modifiers while (not found) do
            (
                if ((classOf stack_mod == Symmetry) and (getAxisIndex stack_mod.name >= 0)) then
                (
                    found = true
                )
            )
        )

        found
        -- return
    ),

    /*
    Returns the current managed gizmo matrix in world coordinates.
    Uses Autodesk modifier context and node object-offset compensation.
    */
    function getWorldMirrorTM node_item stack_mod =
    (
        local context_tm = getModContextTM node_item stack_mod
        stack_mod.mirror.value * (inverse context_tm) * node_item.objectTransform
        -- return
    ),

    /*
    Checks world-origin position at the selected millimeter precision.
    Orientation and scale are compared without inventing an angular tolerance.
    */
    function needsAlignment world_tm position_precision =
    (
        local unit_tm = matrix3 1
        local rounded_current_pos = roundPositionToPrecision world_tm.row4 position_precision
        local rounded_origin = roundPositionToPrecision [0,0,0] position_precision

        ((rounded_current_pos != rounded_origin) or \
         (world_tm.row1 != unit_tm.row1) or \
         (world_tm.row2 != unit_tm.row2) or \
         (world_tm.row3 != unit_tm.row3))
        -- return
    ),

    /*
    Aligns one named Symmetry gizmo to the world origin without moving geometry.
    Returns true only if a modifier property actually needed updating.
    */
    function realignModifier node_item stack_mod axis_index position_precision =
    (
        local current_world_tm = getWorldMirrorTM node_item stack_mod
        local should_align = needsAlignment current_world_tm position_precision
        local axis_changed = stack_mod.axis != axis_index

        if (should_align or axis_changed) then
        (
            local context_tm = getModContextTM node_item stack_mod
            local target_tm = (inverse node_item.objectTransform) * context_tm

            with animate off
            (
                if (axis_changed) then
                (
                    stack_mod.axis = axis_index
                )

                if (should_align) then
                (
                    stack_mod.mirror.value = target_tm
                )
            )
        )

        (should_align or axis_changed)
        -- return
    ),

    /*
    Realigns only the object reported by the deferred transform change handler.
    One transform notification calls this method once; never at scene initialization.
    */
    function realignNode node_item =
    (
        local adjusted_count = 0

        if ((not is_aligning) and (isValidNode node_item)) then
        (
            is_aligning = true

            try
            (
                local position_precision = getPositionPrecision()

                for stack_mod in node_item.modifiers do
                (
                    if (classOf stack_mod == Symmetry) then
                    (
                        local axis_index = getAxisIndex stack_mod.name

                        if (axis_index >= 0) then
                        (
                            if (realignModifier node_item stack_mod axis_index position_precision) then
                            (
                                adjusted_count += 1
                            )
                        )
                    )
                )
            )
            catch
            (
                local exception_text = getCurrentException()
                format "[WORLD SYMMETRY] Realign ERROR | node:% | %\n" node_item.name exception_text
            )

            is_aligning = false
        )

        adjusted_count
        -- return
    ),

    /*
    Scans existing named modifiers and replaces its one transform change handler.
    No gizmo realignment, alignment test, or geometry edit occurs here.
    */
    function bindScene =
    (
        deleteAllChangeHandlers id:#worldSymmetryTransform
        transform_handler = undefined
        watched_nodes = #()

        for node_item in objects do
        (
            if (hasWorldSymmetry node_item) then
            (
                append watched_nodes node_item
            )
        )

        if (watched_nodes.count > 0) then
        (
            transform_handler = when transform watched_nodes changes id:#worldSymmetryTransform handleAt:#redrawViews changed_node do
            (
                if (world_symmetry_manager != undefined) then
                (
                    world_symmetry_manager.realignNode changed_node
                )
            )
        )

        format "[WORLD SYMMETRY] Bound transform events: % nodes.\n" watched_nodes.count
        watched_nodes.count
        -- return
    ),

    /*
    The X/Y/Z UI action selects, enables or creates named Symmetry modifiers.
    A new modifier is aligned immediately by this deliberate user action only.
    */
    function activateAxisOnSelection axis_index =
    (
        local changed_count = 0
        local created_count = 0
        local first_mod = undefined
        local first_node = undefined
        local required_name = getAxisName axis_index
        local position_precision = getPositionPrecision()

        if ((required_name != "") and (selection.count > 0)) then
        (
            undo "World Symmetry Axis" on
            (
                for node_item in selection do
                (
                    if (isValidNode node_item) then
                    (
                        local stack_mod = findAxisModifier node_item axis_index
                        local new_mod = false

                        if (stack_mod == undefined) then
                        (
                            if (validModifier node_item Symmetry) then
                            (
                                stack_mod = Symmetry()
                                stack_mod.name = required_name
                                stack_mod.axis = axis_index
                                addModifier node_item stack_mod
                                new_mod = true
                                created_count += 1
                            )
                            else
                            (
                                format "[WORLD SYMMETRY] Unsupported object: %\n" node_item.name
                            )
                        )

                        if (stack_mod != undefined) then
                        (
                            stack_mod.enabled = true

                            /* This is a button action, not startup initialization. */
                            realignModifier node_item stack_mod axis_index position_precision

                            if (first_mod == undefined) then
                            (
                                first_mod = stack_mod
                                first_node = node_item
                            )

                            changed_count += 1
                        )
                    )
                )
            )

            if (changed_count > 0) then
            (
                /* New modifiers have joined the watched set; bind once after the batch. */
                bindScene()

                if (selection.count == 1) then
                (
                    max modify mode
                    modPanel.setCurrentObject first_mod node:first_node ui:true
                )
            )
        )
        else
        (
            if (selection.count == 0) then
            (
                format "[WORLD SYMMETRY] Select one or more objects first.\n"
            )
        )

        format "[WORLD SYMMETRY] % | activated:% created:%\n" required_name changed_count created_count
        #(changed_count, created_count)
        -- return
    ),

    /*
    Prints raw and rounded world gizmo positions for selected managed modifiers.
    This is a read-only precision and orientation diagnostic.
    */
    function testSelection =
    (
        local checked_count = 0
        local position_precision = getPositionPrecision()

        for node_item in selection do
        (
            if (isValidNode node_item) then
            (
                for stack_mod in node_item.modifiers do
                (
                    if (classOf stack_mod == Symmetry) then
                    (
                        local axis_index = getAxisIndex stack_mod.name

                        if (axis_index >= 0) then
                        (
                            local world_tm = getWorldMirrorTM node_item stack_mod
                            local raw_pos = world_tm.row4
                            local rounded_pos = roundPositionToPrecision raw_pos position_precision
                            local rounded_origin = roundPositionToPrecision [0,0,0] position_precision
                            local passed = ((not (needsAlignment world_tm position_precision)) and (stack_mod.axis == axis_index))
                            format "[WORLD SYMMETRY TEST] node:% | mod:% | raw:% | rounded:% | expected:% | precision:%mm | PASS:%\n" \
                                node_item.name stack_mod.name raw_pos rounded_pos rounded_origin precision_mm passed
                            checked_count += 1
                        )
                    )
                )
            )
        )

        format "[WORLD SYMMETRY TEST] Checked % modifiers.\n" checked_count
        checked_count
        -- return
    ),

    /*
    Opens the compact axis row; startup and scene-open callbacks never open UI.
    The macro button and Listener may both call this same method.
    */
    function openUi =
    (
        if (not worldSymmetryRollout.open) then
        (
            createDialog worldSymmetryRollout 336 156
            cui.RegisterDialogBar worldSymmetryRollout style:#(#cui_dock_vert, #cui_floatable, #cui_handles)
            windows.processPostedMessages()
        )
        true
        -- return
    ),

    /*
    Stops just this service's callbacks and change handler.
    Leaves all scene objects and all modifiers unchanged.
    */
    function stop =
    (
        deleteAllChangeHandlers id:#worldSymmetryTransform
        callbacks.removeScripts id:#worldSymmetryStartup
        transform_handler = undefined
        watched_nodes = #()
        true
        -- return
    ),

    on create do
    (
        watched_nodes = #()
        transform_handler = undefined
        is_aligning = false
        precision_mm = 0.01
    )
)

/* Re-execution cleanup prevents duplicate dialogs and event registration. */
if (worldSymmetryRollout != undefined) then
(
    if (worldSymmetryRollout.open) then
    (
        cui.UnRegisterDialogBar worldSymmetryRollout
        destroyDialog worldSymmetryRollout
    )
)

if (world_symmetry_manager != undefined) then
(
    world_symmetry_manager.stop()
)

world_symmetry_manager = WorldSymmetryManager_v()

/* User preference is a millimeter value, independent of the system unit. */
case (getINISetting world_symmetry_ini_path "UI" "PositionPrecision") of
(
    "1mm": (world_symmetry_manager.precision_mm = 1.0)
    "0.1mm": (world_symmetry_manager.precision_mm = 0.1)
    default: (world_symmetry_manager.precision_mm = 0.01)
)

/* Compact dockable UI. Neither startup nor scene-open displays it automatically. */
rollout worldSymmetryRollout "WORLD SYMMETRY - v0.02" width:336 height:156
(
    dotNetControl btn_title "System.Windows.Forms.Button" pos:[12,12] width:312 height:18
    button btn_axis_x "SYMMETRY X" pos:[12,48] width:96 height:24
    button btn_axis_y "SYMMETRY Y" pos:[120,48] width:96 height:24
    button btn_axis_z "SYMMETRY Z" pos:[228,48] width:96 height:24
    dropdownlist ddl_precision "postion preccision" pos:[12,84] width:312 height:24 items:#("1mm", "0.1mm", "0.01mm") selection:3
    label lbl_status "Select objects, then choose an axis." pos:[12,125] width:312 height:18

    on worldSymmetryRollout open do
    (
        local color_class = dotNetClass "System.Drawing.Color"
        local font_style_type = dotNetClass "System.Drawing.FontStyle"
        local graphics_unit_type = dotNetClass "System.Drawing.GraphicsUnit"
        local flat_style_type = dotNetClass "System.Windows.Forms.FlatStyle"
        local dark_color = color_class.FromArgb 45 45 48

        btn_title.Text = "WORLD SYMMETRY"
        btn_title.UseVisualStyleBackColor = false
        btn_title.FlatStyle = flat_style_type.Flat
        btn_title.AutoSize = false
        btn_title.TabStop = false
        btn_title.FlatAppearance.BorderSize = 0
        btn_title.FlatAppearance.BorderColor = dark_color
        btn_title.FlatAppearance.MouseOverBackColor = dark_color
        btn_title.FlatAppearance.MouseDownBackColor = dark_color
        btn_title.BackColor = dark_color
        btn_title.ForeColor = color_class.FromArgb 62 158 255
        btn_title.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 14.0 font_style_type.Bold graphics_unit_type.Pixel

        case world_symmetry_manager.precision_mm of
        (
            1.0: (ddl_precision.selection = 1)
            0.1: (ddl_precision.selection = 2)
            default: (ddl_precision.selection = 3)
        )

        local saved_x = getINISetting world_symmetry_ini_path "UI" "DialogX"
        local saved_y = getINISetting world_symmetry_ini_path "UI" "DialogY"

        if ((saved_x != "") and (saved_y != "")) then
        (
            setDialogPos worldSymmetryRollout [(saved_x as integer),(saved_y as integer)]
        )
    )

    on worldSymmetryRollout moved dialog_pos do
    (
        setINISetting world_symmetry_ini_path "UI" "DialogX" (dialog_pos.x as string)
        setINISetting world_symmetry_ini_path "UI" "DialogY" (dialog_pos.y as string)
    )

    on btn_axis_x pressed do
    (
        local result_counts = world_symmetry_manager.activateAxisOnSelection 0
        lbl_status.text = ("X: " + (result_counts[1] as string) + " active / " + (result_counts[2] as string) + " new")
    )

    on btn_axis_y pressed do
    (
        local result_counts = world_symmetry_manager.activateAxisOnSelection 1
        lbl_status.text = ("Y: " + (result_counts[1] as string) + " active / " + (result_counts[2] as string) + " new")
    )

    on btn_axis_z pressed do
    (
        local result_counts = world_symmetry_manager.activateAxisOnSelection 2
        lbl_status.text = ("Z: " + (result_counts[1] as string) + " active / " + (result_counts[2] as string) + " new")
    )

    on ddl_precision selected item_index do
    (
        local precision_text = ddl_precision.items[item_index]

        case item_index of
        (
            1: (world_symmetry_manager.precision_mm = 1.0)
            2: (world_symmetry_manager.precision_mm = 0.1)
            3: (world_symmetry_manager.precision_mm = 0.01)
        )

        setINISetting world_symmetry_ini_path "UI" "PositionPrecision" precision_text
    )

    on btn_title Click sender event_args do
    (
        if ((world_symmetry_script_path != undefined) and (doesFileExist world_symmetry_script_path)) then
        (
            cui.UnRegisterDialogBar worldSymmetryRollout
            destroyDialog worldSymmetryRollout
            fileIn world_symmetry_script_path
            world_symmetry_manager.openUi()
        )
    )
)

/* Non-persistent startup service callbacks. Every scene open binds once, never aligns. */
callbacks.removeScripts id:#worldSymmetryStartup
callbacks.addScript #filePostOpen "world_symmetry_manager.bindScene()" id:#worldSymmetryStartup persistent:false
callbacks.addScript #systemPostNew "world_symmetry_manager.bindScene()" id:#worldSymmetryStartup persistent:false
world_symmetry_manager.bindScene()

/* The UI is user-invoked; startup never opens a tool window by itself. */
macroScript Vilbur_WorldSymmetry category:"Vilbur" tooltip:"World Symmetry" buttonText:"World Symmetry"
(
    on execute do
    (
        if (world_symmetry_manager != undefined) then
        (
            world_symmetry_manager.openUi()
        )
    )
)
