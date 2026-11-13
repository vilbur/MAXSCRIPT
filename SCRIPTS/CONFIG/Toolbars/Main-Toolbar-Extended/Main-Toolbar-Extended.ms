/*
Main-Toolbar-Extended 0.001
Installs 27 icon-only native-state MAXScript actions into one CUIX toolbar.
Requires canonical shared Toolbar-Creator.ms to be evaluated first.
No shared Codebase source is modified.
*/

global mainToolbarExtendedProjectVersion
global manageScriptToolbar
mainToolbarExtendedProjectVersion = 0.001

/*
Returns the ordered action manifest used by the native CUI toolbar installer.
Each record contains source ID, short fallback label, tooltip, checked expression, and execute expression.
*/
function getMainToolbarExtendedActions =
(
    #(
        #("center_pivot", "PC", "Transform Center: Pivot Point", "getCoordCenter() == #local", "setCoordCenter #local"),
        #("center_selection", "SC", "Transform Center: Selection Center", "getCoordCenter() == #selection", "setCoordCenter #selection"),
        #("center_transform", "TC", "Transform Center: Transform Coordinate Center", "getCoordCenter() == #system", "setCoordCenter #system"),
        #("coord_view", "VW", "Coordinates: View", "getRefCoordSys() == #hybrid", "toolMode.coordsys #view"),
        #("coord_world", "W", "Coordinates: World", "getRefCoordSys() == #world", "toolMode.coordsys #world"),
        #("coord_local", "L", "Coordinates: Local", "getRefCoordSys() == #local", "toolMode.coordsys #local"),
        #("coord_gimbal", "G", "Coordinates: Gimbal", "getRefCoordSys() == #gimbal", "toolMode.coordsys #gimbal"),
        #("coord_parent", "P", "Coordinates: Parent", "getRefCoordSys() == #parent", "toolMode.coordsys #parent"),
        #("coord_pick", "PK", "Coordinates: Pick Object", "(getRefCoordSys() == #object and isValidNode toolMode.coordSysNode)", "picked_node = pickObject prompt:\"Pick a reference coordinate object\"\n        if isValidNode picked_node then toolMode.coordsys picked_node"),
        #("coord_constant", "CT", "Coordinates: Constant Across Transform Tools", "preferences.constantReferenceSystem", "preferences.constantReferenceSystem = not preferences.constantReferenceSystem"),
        #("axis_x", "X", "Axis Constraint: X", "toolMode.axisConstraints == #X", "toolMode.axisConstraints = #X"),
        #("axis_y", "Y", "Axis Constraint: Y", "toolMode.axisConstraints == #Y", "toolMode.axisConstraints = #Y"),
        #("axis_z", "Z", "Axis Constraint: Z", "toolMode.axisConstraints == #Z", "toolMode.axisConstraints = #Z"),
        #("axis_xy", "XY", "Axis Constraint: XY", "toolMode.axisConstraints == #XY", "toolMode.axisConstraints = #XY"),
        #("axis_yz", "YZ", "Axis Constraint: YZ", "toolMode.axisConstraints == #YZ", "toolMode.axisConstraints = #YZ"),
        #("axis_zx", "ZX", "Axis Constraint: ZX", "toolMode.axisConstraints == #ZX", "toolMode.axisConstraints = #ZX"),
        #("snap_master", "SN", "Position Snaps: Enable/Disable", "snapMode.active", "snapMode.active = not snapMode.active"),
        #("snap_2d", "2D", "Snap Projection: 2D", "snapMode.type == #2D", "snapMode.type = #2D"),
        #("snap_25d", "25", "Snap Projection: 2.5D", "snapMode.type == #2_5D", "snapMode.type = #2_5D"),
        #("snap_3d", "3D", "Snap Projection: 3D", "snapMode.type == #3D", "snapMode.type = #3D"),
        #("snap_grid", "GP", "Snap Target: Grid Points", "snapMode.getOSnapItemActive 4 1", "snapMode.setOSnapItemActive 4 1 (not (snapMode.getOSnapItemActive 4 1))"),
        #("snap_vertex", "VT", "Snap Target: Vertex", "snapMode.getOSnapItemActive 7 1", "snapMode.setOSnapItemActive 7 1 (not (snapMode.getOSnapItemActive 7 1))"),
        #("snap_pivot", "PV", "Snap Target: Pivot", "snapMode.getOSnapItemActive 5 1", "snapMode.setOSnapItemActive 5 1 (not (snapMode.getOSnapItemActive 5 1))"),
        #("snap_midpoint", "MP", "Snap Target: Midpoint", "snapMode.getOSnapItemActive 7 4", "snapMode.setOSnapItemActive 7 4 (not (snapMode.getOSnapItemActive 7 4))"),
        #("snap_bbox", "BB", "Snap Target: Bounding Box", "snapMode.getOSnapItemActive 5 2", "snapMode.setOSnapItemActive 5 2 (not (snapMode.getOSnapItemActive 5 2))"),
        #("snap_center_face", "CF", "Snap Target: Center Face", "snapMode.getOSnapItemActive 7 6", "snapMode.setOSnapItemActive 7 6 (not (snapMode.getOSnapItemActive 7 6))"),
        #("snap_angle", "A°", "Rotation: Angle Snap", "snapMode.angleSnapActive", "snapMode.angleSnapActive = not snapMode.angleSnapActive")
    )
    -- return
)

/*
Escapes text for embedding in generated MAXScript string literals.
Returns a String that retains the original value when parsed.
*/
function escapeMainToolbarExtendedString source_text =
(
    escaped_text = substituteString source_text "\\" "\\\\"
    escaped_text = substituteString escaped_text "\"" "\\\""
    escaped_text = substituteString escaped_text "\r" ""
    escaped_text = substituteString escaped_text "\n" "\\n"
    escaped_text
    -- return
)

/*
Creates or replaces Main-Toolbar-Extended using canonical Toolbar-Creator.
Returns true only after new MacroScripts are registered with checked-state handlers.
*/
function installMainToolbarExtended operation:#create =
(
    operation_ok = true
    source_path = getSourceFileName()
    package_directory = if source_path != undefined and source_path != "" then getFilenamePath source_path else ""
    source_actions = getMainToolbarExtendedActions()
    action_buttons = #()
    toolbar_name = "Main-Toolbar-Extended"
    macro_category = "Main-Toolbar-Extended"
    macro_file_path = (getDir #userMacros) + "\\Main-Toolbar-Extended.mcr"

    if package_directory == "" then
    (
        format "[Main-Toolbar-Extended] FAILED | Run the saved .ms file, not pasted Listener text.\n"
        operation_ok = false
    )

    if operation_ok and manageScriptToolbar == undefined then
    (
        format "[Main-Toolbar-Extended] FAILED | Load canonical Toolbar-Creator.ms before running this installer.\n"
        operation_ok = false
    )

    if operation_ok then
    (
        for action_record in source_actions while operation_ok do
        (
            action_path = package_directory + "Actions\\" + action_record[1] + ".ms"
            if doesFileExist action_path then
            (
                append action_buttons #(action_path, action_record[2], action_record[3])
            )
            else
            (
                format "[Main-Toolbar-Extended] FAILED | Missing action script: %\n" action_path
                operation_ok = false
            )
        )
    )

    /* Place both light and dark icon sets in the 3ds Max user icon directory. */
    if operation_ok then
    (
        file_type = dotNetClass "System.IO.File"
        directory_type = dotNetClass "System.IO.Directory"

        for theme_name in #("Dark", "Light") while operation_ok do
        (
            target_icon_directory = (getDir #userIcons) + "\\" + theme_name + "\\MainToolbarExtended\\"
            source_icon_directory = package_directory + "Icons\\" + theme_name + "\\MainToolbarExtended\\"
            try
            (
                if not (directory_type.Exists target_icon_directory) then directory_type.CreateDirectory target_icon_directory
                for action_record in source_actions do
                (
                    icon_filename = action_record[1] + ".svg"
                    source_icon_path = source_icon_directory + icon_filename
                    target_icon_path = target_icon_directory + icon_filename
                    if not (doesFileExist source_icon_path) then
                    (
                        format "[Main-Toolbar-Extended] FAILED | Missing SVG icon: %\n" source_icon_path
                        operation_ok = false
                    )
                    else if operation_ok then
                    (
                        file_type.Copy source_icon_path target_icon_path true
                    )
                )
            )
            catch
            (
                exception_text = getCurrentException()
                format "[Main-Toolbar-Extended] FAILED | Icon installation | theme:% | exception:%\n" theme_name exception_text
                operation_ok = false
            )
        )
    )

    if operation_ok then
    (
        operation_ok = manageScriptToolbar operation toolbar_name action_buttons \
            macro_category:macro_category macro_file_path:macro_file_path \
            save_ui:true show_toolbar:true register_macros:true
    )

    /* Upgrade Creator's script-launching actions to live checked-state actions. */
    if operation_ok then
    (
        file_type = dotNetClass "System.IO.File"
        source_lines = filterString (file_type.ReadAllText macro_file_path) "\r\n"
        generated_macro_names = #()

        for source_line in source_lines do
        (
            if matchPattern source_line pattern:"macroScript *" ignoreCase:true then
            (
                parts = filterString source_line " \t"
                if parts.count >= 2 then append generated_macro_names parts[2]
            )
        )

        if generated_macro_names.count != source_actions.count then
        (
            format "[Main-Toolbar-Extended] FAILED | Creator macros count:% expected:%\n" generated_macro_names.count source_actions.count
            operation_ok = false
        )
        else
        (
            enhanced_macro_text = "/* Main-Toolbar-Extended 0.001 | Generated checked-state actions. */\r\n\r\n"

            for action_index = 1 to source_actions.count do
            (
                action_record = source_actions[action_index]
                action_name = generated_macro_names[action_index]
                action_label = escapeMainToolbarExtendedString action_record[2]
                action_tip = escapeMainToolbarExtendedString action_record[3]
                icon_reference = "MainToolbarExtended/" + action_record[1]

                enhanced_macro_text += "macroScript " + action_name + \
                    " category:\"" + macro_category + "\" buttonText:\"" + action_label + \
                    "\" tooltip:\"" + action_tip + "\" iconName:\"" + icon_reference + "\"\r\n"
                enhanced_macro_text += "(\r\n"
                enhanced_macro_text += "    on isChecked do (" + action_record[4] + ")\r\n"
                enhanced_macro_text += "    on execute do\r\n    (\r\n        " + action_record[5] + "\r\n"
                enhanced_macro_text += "        updateToolbarButtons()\r\n    )\r\n"
                enhanced_macro_text += ")\r\n\r\n"
            )

            try
            (
                utf8_encoding = dotNetObject "System.Text.UTF8Encoding" true
                file_type.WriteAllText macro_file_path enhanced_macro_text utf8_encoding
                fileIn macro_file_path quiet:true
                updateToolbarButtons()
            )
            catch
            (
                exception_text = getCurrentException()
                format "[Main-Toolbar-Extended] FAILED | Checked-state MacroScript install | file:% | exception:%\n" macro_file_path exception_text
                operation_ok = false
            )
        )
    )

    if operation_ok then
    (
        format "[Main-Toolbar-Extended] INSTALLED | version:% | toolbar:% | buttons:%\n" \
            mainToolbarExtendedProjectVersion toolbar_name source_actions.count
    )
    else
    (
        format "[Main-Toolbar-Extended] Installation incomplete. See prior diagnostic; toolbar may require removal with Toolbar-Creator before retry.\n"
    )

    operation_ok
    -- return
)

installMainToolbarExtended operation:#create
