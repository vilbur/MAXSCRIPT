
/*
===============================================================================
Module:         EPoly-Stack-Test
File version:   1.25
Project version: 1.25
Description:    Diagnostic script proving multi-modifier Edit_Poly stack integrity.
                Keeps plane parametric. Never collapses stack. No hardcoded IDs.
===============================================================================
*/

try (destroyDialog EPolyStackTestRollout) catch ()

global epoly_stack_test_project_version
global epoly_stack_test_file_version = 1.25
global epoly_stack_test_file_project_version = 1.25
global epoly_stack_test_source_path = getSourceFileName()
global epoly_stack_test_module_root = getFilenamePath epoly_stack_test_source_path
global epoly_stack_test_dump_module_path = pathConfig.appendPath epoly_stack_test_module_root @"..\DUMP\DUMP.ms"
global epoly_stack_test_dump_file_path = pathConfig.appendPath epoly_stack_test_module_root @"logs\EPoly-Stack-Test-DUMP.txt"
global epoly_stack_test_dump_logger

if epoly_stack_test_project_version == undefined or epoly_stack_test_project_version < epoly_stack_test_file_project_version then
(
    epoly_stack_test_project_version = epoly_stack_test_file_project_version
)

if doesFileExist epoly_stack_test_dump_module_path then
(
    fileIn epoly_stack_test_dump_module_path quiet:true
    epoly_stack_test_dump_logger = DumpDevLoggerStruct()
    epoly_stack_test_dump_logger.start epoly_stack_test_dump_file_path
)
else
(
    epoly_stack_test_dump_logger = undefined
    format "EPoly-Stack-Test | LOGGER FAILED | Missing DUMP module: %\n" epoly_stack_test_dump_module_path
)

rollout EPolyStackTestRollout ("EPoly-Stack-Test v" + (epoly_stack_test_project_version as string)) width:220 height:492
(
    -- -------------------------------------------------------------------------
    -- UI COMPONENTS (Check Line 23 for missing parameters or unexpected text)
    -- -------------------------------------------------------------------------
    button btn_stg00 "00 SETUP PLANE"      width:180 height:26 align:#center
    button btn_stg01 "01 CREATE CROSS"     width:180 height:26 align:#center
    button btn_stg02 "02 MAKE OPEN BOX"    width:180 height:26 align:#center
    button btn_stg03 "03 WELD RESULT"        width:180 height:26 align:#center
    button btn_stg04 "04 ADD LOOPS HORIZONTAL"       width:180 height:26 align:#center
    button btn_stg05 "05 ADD LOOPS VERTICAL" width:180 height:26 align:#center
    button btn_stg06 "06 INSERT VERTICES" width:180 height:26 align:#center tooltip:"LMB: Add one vertex on each horizontal edge.\n\nRMB: Add two vertices on each horizontal edge."
    button btn_stg07 "07 CONNECT 2 EDGE VERTS" width:180 height:26 align:#center
    button btn_stg08 "08 REMOVE UP FACE" width:180 height:26 align:#center
    button btn_move_selected_out "MOVE SELECTED VERTS OUT" width:180 height:26 align:#center tooltip:"Moves selected vertices away from the bounding-box center by 25% of the current bounding-box maximum dimension."
    
    button btn_all   "RUN ALL"             width:180 height:32 align:#center
    button btn_rst   "RESTART"             width:180 height:26 align:#center
    
    -- ... structural event handlers follow below

    -- -------------------------------------------------------------------------
    -- INTERNAL UTILITIES & LOGGING
    -- -------------------------------------------------------------------------
    local node_name = "EPOLY_STACK_TEST"
    
    /*
    Writes one diagnostic line to Listener and the repository-local DUMP file.
    Returns true when logging completed through the shared logger.
    */
    function logMsg message_text =
    (
        full_message = "EPoly-Stack-Test | " + message_text

        if epoly_stack_test_dump_logger != undefined then
        (
            epoly_stack_test_dump_logger.log full_message
        )
        else
        (
            format "%\n" full_message
            false
        )
        -- return
    )

    /*
    Returns the dedicated test node by name.
    Returns undefined when the test node does not exist.
    */
    function getTestObject = (getNodeByName node_name)

    /*
    Selects the test node and focuses the supplied Edit Poly modifier.
    Does nothing when the test node does not exist.
    */
    function selectAndFocusMod target_mod = 
    (
        local obj = getTestObject()
        if obj != undefined then
        (
            select obj
            max modify mode
            modPanel.setCurrentObject target_mod
        )
    )

    -- -------------------------------------------------------------------------
    -- STAGE 00: SETUP PLANE
    -- -------------------------------------------------------------------------
    /*
    Creates the fresh parametric one-quad Plane for the diagnostic test.
    Returns true after setup completes.
    */
    function runStage00 = 
    (
        undo "00 Setup Plane" on
        (
            logMsg "Executing Stage 00: SETUP PLANE..."
            local old_obj = getTestObject()
            if old_obj != undefined then delete old_obj
            
            local p = Plane length:100 width:100 lengthsegs:1 widthsegs:1 name:node_name isSelected:true
            p.pos = [0,0,0]
            max modify mode
            logMsg "Stage 00 SUCCESS | Plane created parametric (1x1 segments)."
            true
        )
    )

    -- -------------------------------------------------------------------------
    -- STAGE 01: CREATE CROSS
    -- -------------------------------------------------------------------------
    /*
    Creates exactly four square arm faces around the incoming one-quad Plane.
    Uses documented EditPolyMod CreateVertex/CreateFace methods and validates 12 verts, 16 edges, and 5 faces.
    */
    function runStage01 =
    (
        local obj = getTestObject()
        if obj == undefined then
        (
            logMsg "01 FAILED | Missing target object."
            return false
        )

        if obj.modifiers.count > 0 then
        (
            for stack_mod in obj.modifiers do
            (
                if stack_mod.name == "01 CREATE CROSS" then
                (
                    logMsg "01 FAILED | Modifier already exists. Run 00 SETUP PLANE first."
                    return false
                )
            )
        )

        local result_value = false

        undo "01 Create Cross" on
        (
            logMsg "Executing Stage 01: CREATE CROSS..."

            local edit_poly_mod = Edit_Poly()
            edit_poly_mod.name = "01 CREATE CROSS"
            edit_poly_mod.showCage = off
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            addModifier obj edit_poly_mod

            select obj
            max modify mode
            edit_poly_mod.SetPrimaryNode obj
            modPanel.setCurrentObject edit_poly_mod node:obj

            local input_vertex_count = edit_poly_mod.GetNumVertices node:obj
            local input_edge_count = edit_poly_mod.GetNumEdges node:obj
            local input_face_count = edit_poly_mod.GetNumFaces node:obj

            logMsg ("01 INPUT | verts:" + (input_vertex_count as string) + " edges:" + (input_edge_count as string) + " faces:" + (input_face_count as string))

            if input_vertex_count != 4 or input_edge_count != 4 or input_face_count != 1 then
            (
                logMsg "01 FAILED | Expected one quad: 4 verts, 4 edges, 1 face."
            )
            else
            (
                local base_face_id = 0

                for face_id = 1 to input_face_count while base_face_id == 0 do
                (
                    if edit_poly_mod.GetFaceDegree face_id node:obj == 4 then
                    (
                        base_face_id = face_id
                    )
                )

                if base_face_id == 0 then
                (
                    logMsg "01 FAILED | Could not resolve the incoming quad face."
                )
                else
                (
                    local base_vertex_ids = #()
                    local base_center = [0.0, 0.0, 0.0]
                    local base_degree = edit_poly_mod.GetFaceDegree base_face_id node:obj

                    for corner_id = 1 to base_degree do
                    (
                        local vertex_id = edit_poly_mod.GetFaceVertex base_face_id corner_id node:obj
                        append base_vertex_ids vertex_id
                        base_center += edit_poly_mod.GetVertex vertex_id node:obj
                    )

                    base_center /= base_degree

                    local build_ok = true
                    local created_face_ids = #()

                    for corner_id = 1 to base_degree while build_ok do
                    (
                        local next_corner_id = corner_id + 1
                        if next_corner_id > base_degree then next_corner_id = 1

                        local shared_vertex_a = base_vertex_ids[corner_id]
                        local shared_vertex_b = base_vertex_ids[next_corner_id]
                        local position_a = edit_poly_mod.GetVertex shared_vertex_a node:obj
                        local position_b = edit_poly_mod.GetVertex shared_vertex_b node:obj
                        local edge_center = (position_a + position_b) / 2.0
                        local outward_vector = edge_center - base_center
                        local outward_length = length outward_vector
                        local arm_depth = distance position_a position_b

                        if outward_length == 0.0 then
                        (
                            logMsg ("01 FAILED | Could not resolve outward direction for side " + (corner_id as string))
                            build_ok = false
                        )
                        else
                        (
                            local outward_direction = outward_vector / outward_length
                            local arm_offset = outward_direction * arm_depth
                            local new_position_a = position_a + arm_offset
                            local new_position_b = position_b + arm_offset

                            local new_vertex_a = edit_poly_mod.CreateVertex new_position_a node:obj
                            local new_vertex_b = edit_poly_mod.CreateVertex new_position_b node:obj

                            if new_vertex_a <= 0 or new_vertex_b <= 0 then
                            (
                                logMsg ("01 FAILED | CreateVertex failed on side " + (corner_id as string))
                                build_ok = false
                            )
                            else
                            (
                                -- Reverse the shared edge winding so the new quad matches the base face orientation.
                                local new_face_id = edit_poly_mod.CreateFace #(shared_vertex_b, shared_vertex_a, new_vertex_a, new_vertex_b) node:obj

                                if new_face_id <= 0 then
                                (
                                    logMsg ("01 FAILED | CreateFace failed on side " + (corner_id as string))
                                    build_ok = false
                                )
                                else
                                (
                                    append created_face_ids new_face_id
                                    logMsg ("01 ARM | side:" + (corner_id as string) + " face:" + (new_face_id as string) + " newVerts:#(" + (new_vertex_a as string) + "," + (new_vertex_b as string) + ")")
                                )
                            )
                        )
                    )

                    if build_ok then
                    (
                        edit_poly_mod.Commit()
                    )

                    edit_poly_mod.RefreshScreen()
                    completeRedraw()

                    local final_vertex_count = edit_poly_mod.GetNumVertices node:obj
                    local final_edge_count = edit_poly_mod.GetNumEdges node:obj
                    local final_face_count = edit_poly_mod.GetNumFaces node:obj

                    logMsg ("01 RESULT | verts:" + (final_vertex_count as string) + " edges:" + (final_edge_count as string) + " faces:" + (final_face_count as string))

                    if build_ok and created_face_ids.count == 4 and final_vertex_count == 12 and final_edge_count == 16 and final_face_count == 5 then
                    (
                        logMsg "Stage 01 SUCCESS | exact five-quad cross created."
                        result_value = true
                    )
                    else
                    (
                        logMsg ("01 FAILED | expected verts:12 edges:16 faces:5 | createdFaces:" + (created_face_ids.count as string))
                    )
                )
            )
        )

        result_value
        -- return
    )

    -- -------------------------------------------------------------------------
    -- STAGE 02: MAKE OPEN BOX
    -- -------------------------------------------------------------------------
    /*
    Folds the four cross arms vertically around the center face in a new Edit Poly modifier.
    Returns true only when eight vertical wall edges and exact coincident corner pairs are present.
    */
    function runStage02 =
    (
        local obj = getTestObject()
        if obj == undefined then
        (
            logMsg "02 FAILED | Missing target object."
            return false
        )

        for stack_mod in obj.modifiers do
        (
            if stack_mod.name == "02 MAKE OPEN BOX" then
            (
                logMsg "02 FAILED | Modifier already exists. Run 00 SETUP PLANE and 01 CREATE CROSS first."
                return false
            )
        )

        local result_value = false

        undo "02 Make Open Box" on
        (
            logMsg "Executing Stage 02: MAKE OPEN BOX..."

            local edit_poly_mod = Edit_Poly()
            edit_poly_mod.name = "02 MAKE OPEN BOX"
            edit_poly_mod.showCage = off
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            addModifier obj edit_poly_mod

            select obj
            max modify mode
            edit_poly_mod.SetPrimaryNode obj
            modPanel.setCurrentObject edit_poly_mod node:obj
            edit_poly_mod.SetEPolySelLevel #Vertex
            subObjectLevel = 1

            local face_count = edit_poly_mod.GetNumFaces node:obj
            local center_face_id = 0

            for face_id = 1 to face_count while center_face_id == 0 do
            (
                local face_degree = edit_poly_mod.GetFaceDegree face_id node:obj
                local border_found = false

                for side_id = 1 to face_degree while not border_found do
                (
                    local edge_id = edit_poly_mod.GetFaceEdge face_id side_id node:obj
                    local adjacent_face_a = edit_poly_mod.GetEdgeFace edge_id 1 node:obj
                    local adjacent_face_b = edit_poly_mod.GetEdgeFace edge_id 2 node:obj

                    if adjacent_face_a == 0 or adjacent_face_b == 0 then
                    (
                        border_found = true
                    )
                )

                if not border_found then
                (
                    center_face_id = face_id
                )
            )

            if center_face_id == 0 then
            (
                logMsg "02 FAILED | Could not resolve the center face of the incoming cross."
            )
            else
            (
                local fold_data = #()
                local build_ok = true

                for face_id = 1 to face_count while build_ok do
                (
                    if face_id != center_face_id then
                    (
                        local face_degree = edit_poly_mod.GetFaceDegree face_id node:obj
                        local shared_edge_id = 0

                        for side_id = 1 to face_degree while shared_edge_id == 0 do
                        (
                            local edge_id = edit_poly_mod.GetFaceEdge face_id side_id node:obj
                            local adjacent_face_a = edit_poly_mod.GetEdgeFace edge_id 1 node:obj
                            local adjacent_face_b = edit_poly_mod.GetEdgeFace edge_id 2 node:obj

                            if adjacent_face_a == center_face_id or adjacent_face_b == center_face_id then
                            (
                                shared_edge_id = edge_id
                            )
                        )

                        if shared_edge_id == 0 then
                        (
                            logMsg ("02 FAILED | Face " + (face_id as string) + " has no edge shared with center face.")
                            build_ok = false
                        )
                        else
                        (
                            local shared_vertex_a = edit_poly_mod.GetEdgeVertex shared_edge_id 1 node:obj
                            local shared_vertex_b = edit_poly_mod.GetEdgeVertex shared_edge_id 2 node:obj
                            local outer_vertices = #()

                            for corner_id = 1 to face_degree do
                            (
                                local vertex_id = edit_poly_mod.GetFaceVertex face_id corner_id node:obj

                                if vertex_id != shared_vertex_a and vertex_id != shared_vertex_b then
                                (
                                    append outer_vertices vertex_id
                                )
                            )

                            if outer_vertices.count != 2 then
                            (
                                logMsg ("02 FAILED | Face " + (face_id as string) + " did not resolve exactly two outer vertices.")
                                build_ok = false
                            )
                            else
                            (
                                local shared_position_a = edit_poly_mod.GetVertex shared_vertex_a node:obj
                                local shared_position_b = edit_poly_mod.GetVertex shared_vertex_b node:obj
                                local outer_position_a = edit_poly_mod.GetVertex outer_vertices[1] node:obj
                                local outer_position_b = edit_poly_mod.GetVertex outer_vertices[2] node:obj
                                local shared_center = (shared_position_a + shared_position_b) / 2.0
                                local outer_center = (outer_position_a + outer_position_b) / 2.0
                                local wall_height = distance shared_position_a shared_position_b
                                local move_delta = (shared_center - outer_center) + [0.0, 0.0, wall_height]

                                append fold_data #(outer_vertices, move_delta, face_id)
                            )
                        )
                    )
                )

                if build_ok and fold_data.count != 4 then
                (
                    logMsg ("02 FAILED | Expected four arm faces, found:" + (fold_data.count as string))
                    build_ok = false
                )

                for fold_item in fold_data while build_ok do
                (
                    local outer_vertices = fold_item[1]
                    local move_delta = fold_item[2]
                    local face_id = fold_item[3]
                    local vertex_bits = #{}

                    for vertex_id in outer_vertices do
                    (
                        vertex_bits[vertex_id] = true
                    )

                    local old_selection = edit_poly_mod.GetSelection #Vertex node:obj
                    if old_selection.numberSet > 0 then
                    (
                        edit_poly_mod.Select #Vertex old_selection select:false node:obj
                    )

                    edit_poly_mod.Select #Vertex vertex_bits node:obj
                    local stored_selection = edit_poly_mod.GetSelection #Vertex node:obj

                    if stored_selection != vertex_bits then
                    (
                        logMsg ("02 FAILED | Vertex selection was not stored for face " + (face_id as string))
                        build_ok = false
                    )
                    else
                    (
                        edit_poly_mod.MoveSelection move_delta
                        edit_poly_mod.Commit()
                        edit_poly_mod.RefreshScreen()

                        logMsg ("02 FOLD | face:" + (face_id as string) + " verts:" + (outer_vertices as string) + " delta:" + (move_delta as string))
                    )
                )

                if build_ok then
                (
                    local edge_count = edit_poly_mod.GetNumEdges node:obj
                    local vertical_edge_count = 0

                    for edge_id = 1 to edge_count do
                    (
                        local vertex_a = edit_poly_mod.GetEdgeVertex edge_id 1 node:obj
                        local vertex_b = edit_poly_mod.GetEdgeVertex edge_id 2 node:obj
                        local position_a = edit_poly_mod.GetVertex vertex_a node:obj
                        local position_b = edit_poly_mod.GetVertex vertex_b node:obj

                        if position_a.x == position_b.x and position_a.y == position_b.y and position_a.z != position_b.z then
                        (
                            vertical_edge_count += 1
                        )
                    )

                    local vertex_count = edit_poly_mod.GetNumVertices node:obj
                    local duplicate_pair_count = 0

                    for vertex_a = 1 to (vertex_count - 1) do
                    (
                        local position_a = edit_poly_mod.GetVertex vertex_a node:obj

                        for vertex_b = (vertex_a + 1) to vertex_count do
                        (
                            local position_b = edit_poly_mod.GetVertex vertex_b node:obj

                            if position_a == position_b then
                            (
                                duplicate_pair_count += 1
                            )
                        )
                    )

                    logMsg ("02 RESULT | verticalEdges:" + (vertical_edge_count as string) + " duplicatePairs:" + (duplicate_pair_count as string))

                    if vertical_edge_count == 8 and duplicate_pair_count == 4 then
                    (
                        logMsg "Stage 02 SUCCESS | Open unwelded box created."
                        result_value = true
                    )
                    else
                    (
                        logMsg "02 FAILED | Expected 8 vertical edges and 4 exact duplicate corner pairs."
                    )
                )
            )

            edit_poly_mod.RefreshScreen()
            completeRedraw()
        )

        result_value
        -- return
    )

    -- -------------------------------------------------------------------------
    -- STAGE 03: WELD RESULT
    -- -------------------------------------------------------------------------
    /*
    Welds the four exact duplicate top-corner pairs of the open box.
    Re-resolves current vertex IDs after every commit so stale topology IDs are never reused.
    */
    function runStage03 =
    (
        local obj = getTestObject()
        if obj == undefined then
        (
            logMsg "03 FAILED | Missing target object."
            return false
        )

        for stack_mod in obj.modifiers do
        (
            if stack_mod.name == "03 WELD RESULT" then
            (
                logMsg "03 FAILED | Modifier already exists. Run the earlier stages from a clean setup."
                return false
            )
        )

        local result_value = false

        undo "03 Weld Result" on
        (
            logMsg "Executing Stage 03: WELD RESULT..."

            local edit_poly_mod = Edit_Poly()
            edit_poly_mod.name = "03 WELD RESULT"
            edit_poly_mod.showCage = off
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            addModifier obj edit_poly_mod

            select obj
            max modify mode
            edit_poly_mod.SetPrimaryNode obj
            modPanel.setCurrentObject edit_poly_mod node:obj
            edit_poly_mod.SetEPolySelLevel #Vertex
            subObjectLevel = 1

            local vertex_count_before = edit_poly_mod.GetNumVertices node:obj
            local edge_count_before = edit_poly_mod.GetNumEdges node:obj
            local face_count_before = edit_poly_mod.GetNumFaces node:obj
            local duplicate_positions = #()

            -- Stage 02 intentionally leaves four exact duplicate top-corner pairs.
            -- Store each duplicate position once before any weld changes vertex IDs.
            for vertex_a = 1 to (vertex_count_before - 1) do
            (
                local position_a = edit_poly_mod.GetVertex vertex_a node:obj

                for vertex_b = (vertex_a + 1) to vertex_count_before do
                (
                    local position_b = edit_poly_mod.GetVertex vertex_b node:obj

                    if position_a == position_b then
                    (
                        local already_stored = false

                        for stored_position in duplicate_positions while not already_stored do
                        (
                            if stored_position == position_a then
                            (
                                already_stored = true
                            )
                        )

                        if not already_stored then
                        (
                            append duplicate_positions position_a
                        )
                    )
                )
            )

            logMsg ("03 INPUT | verts:" + (vertex_count_before as string) + " edges:" + (edge_count_before as string) + " faces:" + (face_count_before as string) + " duplicatePositions:" + (duplicate_positions.count as string))

            if duplicate_positions.count != 4 then
            (
                logMsg ("03 FAILED | Expected exactly 4 duplicate top-corner positions, found:" + (duplicate_positions.count as string))
            )
            else
            (
                local weld_ok = true
                local welded_pair_count = 0

                for duplicate_position in duplicate_positions while weld_ok do
                (
                    local current_vertex_count = edit_poly_mod.GetNumVertices node:obj
                    local current_pair = #()

                    for vertex_id = 1 to current_vertex_count do
                    (
                        if edit_poly_mod.GetVertex vertex_id node:obj == duplicate_position then
                        (
                            append current_pair vertex_id
                        )
                    )

                    if current_pair.count != 2 then
                    (
                        logMsg ("03 FAILED | Expected two vertices at position:" + (duplicate_position as string) + " found:" + (current_pair.count as string) + " IDs:" + (current_pair as string))
                        weld_ok = false
                    )
                    else
                    (
                        local vertex_count_pre_weld = current_vertex_count

                        logMsg ("03 WELD | position:" + (duplicate_position as string) + " pair:" + (current_pair as string))

                        edit_poly_mod.WeldVertices current_pair[1] current_pair[2] node:obj
                        edit_poly_mod.Commit()
                        edit_poly_mod.RefreshScreen()

                        local vertex_count_post_weld = edit_poly_mod.GetNumVertices node:obj
                        local survivor_count = 0

                        for vertex_id = 1 to vertex_count_post_weld do
                        (
                            if edit_poly_mod.GetVertex vertex_id node:obj == duplicate_position then
                            (
                                survivor_count += 1
                            )
                        )

                        if vertex_count_post_weld != (vertex_count_pre_weld - 1) or survivor_count != 1 then
                        (
                            logMsg ("03 FAILED | Weld verification failed | verts:" + (vertex_count_pre_weld as string) + "->" + (vertex_count_post_weld as string) + " survivors:" + (survivor_count as string))
                            weld_ok = false
                        )
                        else
                        (
                            welded_pair_count += 1
                        )
                    )
                )

                completeRedraw()

                local vertex_count_after = edit_poly_mod.GetNumVertices node:obj
                local edge_count_after = edit_poly_mod.GetNumEdges node:obj
                local face_count_after = edit_poly_mod.GetNumFaces node:obj

                logMsg ("03 RESULT | verts:" + (vertex_count_before as string) + "->" + (vertex_count_after as string) + " edges:" + (edge_count_before as string) + "->" + (edge_count_after as string) + " faces:" + (face_count_before as string) + "->" + (face_count_after as string))

                if weld_ok and welded_pair_count == 4 and vertex_count_after == 8 and edge_count_after == 12 and face_count_after == 5 then
                (
                    logMsg "Stage 03 SUCCESS | Four open-box corner pairs welded."
                    result_value = true
                )
                else if weld_ok then
                (
                    logMsg "03 FAILED | Expected welded open box topology: verts:8 edges:12 faces:5."
                )
            )
        )

        result_value
        -- return
    )

    -- -------------------------------------------------------------------------
    -- STAGE 04: ADD LOOPS
    -- -------------------------------------------------------------------------
    /*
    Adds two continuous horizontal loops around the already welded open box.
    Resolves the four shared vertical corner edges from wall-face topology, not world orientation.
    */
    function runStage04 =
    (
        local obj = getTestObject()
        if obj == undefined then
        (
            logMsg "04 FAILED | Missing target object."
            return false
        )

        for stack_mod in obj.modifiers do
        (
            if stack_mod.name == "04 ADD LOOPS" then
            (
                logMsg "04 FAILED | Modifier already exists. Run the earlier stages from a clean setup."
                return false
            )
        )

        local result_value = false

        undo "04 Add Loops" on
        (
            logMsg "Executing Stage 04: ADD LOOPS..."

            local edit_poly_mod = Edit_Poly()
            edit_poly_mod.name = "04 ADD LOOPS"
            edit_poly_mod.showCage = off
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            addModifier obj edit_poly_mod

            select obj
            max modify mode
            edit_poly_mod.SetPrimaryNode obj
            modPanel.setCurrentObject edit_poly_mod node:obj
            edit_poly_mod.SetEPolySelLevel #Edge
            subObjectLevel = 2

            local vertex_count_before = edit_poly_mod.GetNumVertices node:obj
            local edge_count_before = edit_poly_mod.GetNumEdges node:obj
            local face_count_before = edit_poly_mod.GetNumFaces node:obj
            local center_face_id = 0

            -- The bottom center face is the only face with no border edge.
            for face_id = 1 to face_count_before while center_face_id == 0 do
            (
                local face_degree = edit_poly_mod.GetFaceDegree face_id node:obj
                local has_border_edge = false

                for side_id = 1 to face_degree while not has_border_edge do
                (
                    local edge_id = edit_poly_mod.GetFaceEdge face_id side_id node:obj
                    local adjacent_face_a = edit_poly_mod.GetEdgeFace edge_id 1 node:obj
                    local adjacent_face_b = edit_poly_mod.GetEdgeFace edge_id 2 node:obj

                    if adjacent_face_a == 0 or adjacent_face_b == 0 then
                    (
                        has_border_edge = true
                    )
                )

                if not has_border_edge then
                (
                    center_face_id = face_id
                )
            )

            if center_face_id == 0 then
            (
                logMsg "04 FAILED | Could not resolve the center face."
            )
            else
            (
                local connect_edges = #{}
                local wall_face_count = 0
                local topology_ok = true

                for face_id = 1 to face_count_before while topology_ok do
                (
                    if face_id != center_face_id then
                    (
                        local face_degree = edit_poly_mod.GetFaceDegree face_id node:obj

                        if face_degree != 4 then
                        (
                            logMsg ("04 FAILED | Wall candidate face is not a quad | face:" + (face_id as string))
                            topology_ok = false
                        )
                        else
                        (
                            local shared_edge_id = 0

                            for side_id = 1 to face_degree while shared_edge_id == 0 do
                            (
                                local edge_id = edit_poly_mod.GetFaceEdge face_id side_id node:obj
                                local adjacent_face_a = edit_poly_mod.GetEdgeFace edge_id 1 node:obj
                                local adjacent_face_b = edit_poly_mod.GetEdgeFace edge_id 2 node:obj

                                if adjacent_face_a == center_face_id or adjacent_face_b == center_face_id then
                                (
                                    shared_edge_id = edge_id
                                )
                            )

                            if shared_edge_id == 0 then
                            (
                                logMsg ("04 FAILED | Wall face has no edge shared with center | face:" + (face_id as string))
                                topology_ok = false
                            )
                            else
                            (
                                wall_face_count += 1

                                local shared_vertex_a = edit_poly_mod.GetEdgeVertex shared_edge_id 1 node:obj
                                local shared_vertex_b = edit_poly_mod.GetEdgeVertex shared_edge_id 2 node:obj
                                local wall_side_edges = #()

                                for side_id = 1 to face_degree do
                                (
                                    local edge_id = edit_poly_mod.GetFaceEdge face_id side_id node:obj

                                    if edge_id != shared_edge_id then
                                    (
                                        local edge_vertex_a = edit_poly_mod.GetEdgeVertex edge_id 1 node:obj
                                        local edge_vertex_b = edit_poly_mod.GetEdgeVertex edge_id 2 node:obj
                                        local touches_shared_a = edge_vertex_a == shared_vertex_a or edge_vertex_b == shared_vertex_a
                                        local touches_shared_b = edge_vertex_a == shared_vertex_b or edge_vertex_b == shared_vertex_b

                                        if (touches_shared_a and not touches_shared_b) or (touches_shared_b and not touches_shared_a) then
                                        (
                                            append wall_side_edges edge_id
                                        )
                                    )
                                )

                                if wall_side_edges.count != 2 then
                                (
                                    logMsg ("04 FAILED | Could not resolve two side edges | face:" + (face_id as string) + " found:" + (wall_side_edges.count as string))
                                    topology_ok = false
                                )
                                else
                                (
                                    connect_edges[wall_side_edges[1]] = true
                                    connect_edges[wall_side_edges[2]] = true
                                    logMsg ("04 WALL | face:" + (face_id as string) + " sideEdges:" + (wall_side_edges as string))
                                )
                            )
                        )
                    )
                )

                logMsg ("04 INPUT | verts:" + (vertex_count_before as string) + " edges:" + (edge_count_before as string) + " faces:" + (face_count_before as string) + " centerFace:" + (center_face_id as string) + " wallFaces:" + (wall_face_count as string) + " connectEdges:" + (connect_edges.numberSet as string))

                -- Adjacent welded walls share the same four corner edges, so the
                -- eight per-wall side-edge references collapse to four unique edges.
                if topology_ok and wall_face_count == 4 and connect_edges.numberSet == 4 then
                (
                    local old_selection = edit_poly_mod.GetSelection #Edge node:obj

                    if old_selection.numberSet > 0 then
                    (
                        edit_poly_mod.Select #Edge old_selection select:false node:obj
                    )

                    edit_poly_mod.Select #Edge connect_edges node:obj

                    local stored_selection = edit_poly_mod.GetSelection #Edge node:obj

                    if stored_selection != connect_edges then
                    (
                        logMsg "04 FAILED | Edge selection was not stored in Edit Poly."
                    )
                    else
                    (
                        edit_poly_mod.connectEdgeSegments = 2
                        edit_poly_mod.connectEdgePinch = 0
                        edit_poly_mod.connectEdgeSlide = 0
                        edit_poly_mod.SetOperation #ConnectEdges
                        edit_poly_mod.Commit()
                        edit_poly_mod.RefreshScreen()
                        completeRedraw()

                        local vertex_count_after = edit_poly_mod.GetNumVertices node:obj
                        local edge_count_after = edit_poly_mod.GetNumEdges node:obj
                        local face_count_after = edit_poly_mod.GetNumFaces node:obj

                        logMsg ("04 RESULT | verts:" + (vertex_count_before as string) + "->" + (vertex_count_after as string) + " edges:" + (edge_count_before as string) + "->" + (edge_count_after as string) + " faces:" + (face_count_before as string) + "->" + (face_count_after as string))

                        if vertex_count_after == 16 and edge_count_after == 28 and face_count_after == 13 then
                        (
                            logMsg "Stage 04 SUCCESS | Two continuous loops added to welded box."
                            result_value = true
                        )
                        else
                        (
                            logMsg "04 FAILED | Expected final topology: verts:16 edges:28 faces:13."
                        )
                    )
                )
                else
                (
                    if topology_ok then
                    (
                        logMsg "04 FAILED | Expected four wall faces and four unique welded corner edges."
                    )
                )
            )
        )

        result_value
        -- return
    )

    -- -------------------------------------------------------------------------
    -- STAGE 05: CONNECT SIDES VERTICALLY
    -- -------------------------------------------------------------------------
    /*
    Adds one centered vertical cut through one wall side of the already looped box.
    Resolves one wall strip from the bottom face and connects only that strip.
    */
    function runStage05 =
    (
        local obj = getTestObject()
        if obj == undefined then
        (
            logMsg "05 FAILED | Missing target object."
            return false
        )

        for stack_mod in obj.modifiers do
        (
            if stack_mod.name == "05 CONNECT SIDES VERTICALLY" then
            (
                logMsg "05 FAILED | Modifier already exists. Run the earlier stages from a clean setup."
                return false
            )
        )

        local result_value = false

        undo "05 Connect Sides Vertically" on
        (
            logMsg "Executing Stage 05: CONNECT SIDES VERTICALLY..."

            local edit_poly_mod = Edit_Poly()
            edit_poly_mod.name = "05 CONNECT SIDES VERTICALLY"
            edit_poly_mod.showCage = off
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            addModifier obj edit_poly_mod

            select obj
            max modify mode
            edit_poly_mod.SetPrimaryNode obj
            modPanel.setCurrentObject edit_poly_mod node:obj
            edit_poly_mod.SetEPolySelLevel #Edge
            subObjectLevel = 2

            local vertex_count_before = edit_poly_mod.GetNumVertices node:obj
            local edge_count_before = edit_poly_mod.GetNumEdges node:obj
            local face_count_before = edit_poly_mod.GetNumFaces node:obj
            local minimum_z = undefined

            for vertex_id = 1 to vertex_count_before do
            (
                local vertex_position = edit_poly_mod.GetVertex vertex_id node:obj

                if minimum_z == undefined or vertex_position.z < minimum_z then
                (
                    minimum_z = vertex_position.z
                )
            )

            local bottom_face_id = 0

            for face_id = 1 to face_count_before while bottom_face_id == 0 do
            (
                local face_degree = edit_poly_mod.GetFaceDegree face_id node:obj

                if face_degree == 4 then
                (
                    local all_at_minimum_z = true

                    for corner_id = 1 to face_degree while all_at_minimum_z do
                    (
                        local vertex_id = edit_poly_mod.GetFaceVertex face_id corner_id node:obj
                        local vertex_position = edit_poly_mod.GetVertex vertex_id node:obj

                        if vertex_position.z != minimum_z then
                        (
                            all_at_minimum_z = false
                        )
                    )

                    if all_at_minimum_z then
                    (
                        bottom_face_id = face_id
                    )
                )
            )

            if bottom_face_id == 0 then
            (
                logMsg "05 FAILED | Could not resolve the bottom face."
            )
            else
            (
                local bottom_face_degree = edit_poly_mod.GetFaceDegree bottom_face_id node:obj
                local strip_edges = #()
                local topology_ok = true
                local selected_bottom_edge_id = 0
                local current_face_id = 0

                -- Use one topology-resolved side of the bottom face only.
                for bottom_side_id = 1 to bottom_face_degree while selected_bottom_edge_id == 0 do
                (
                    local candidate_bottom_edge_id = edit_poly_mod.GetFaceEdge bottom_face_id bottom_side_id node:obj
                    local adjacent_face_a = edit_poly_mod.GetEdgeFace candidate_bottom_edge_id 1 node:obj
                    local adjacent_face_b = edit_poly_mod.GetEdgeFace candidate_bottom_edge_id 2 node:obj
                    local candidate_wall_face_id = 0

                    if adjacent_face_a == bottom_face_id then
                    (
                        candidate_wall_face_id = adjacent_face_b
                    )
                    else if adjacent_face_b == bottom_face_id then
                    (
                        candidate_wall_face_id = adjacent_face_a
                    )

                    if candidate_wall_face_id != 0 then
                    (
                        selected_bottom_edge_id = candidate_bottom_edge_id
                        current_face_id = candidate_wall_face_id
                    )
                )

                if selected_bottom_edge_id == 0 or current_face_id == 0 then
                (
                    logMsg "05 FAILED | Could not resolve one wall strip from the bottom face."
                    topology_ok = false
                )
                else
                (
                    append strip_edges selected_bottom_edge_id

                    local incoming_edge_id = selected_bottom_edge_id
                    local incoming_vertex_a = edit_poly_mod.GetEdgeVertex incoming_edge_id 1 node:obj
                    local incoming_vertex_b = edit_poly_mod.GetEdgeVertex incoming_edge_id 2 node:obj
                    local strip_face_count = 0
                    local trace_guard = 0

                    while current_face_id != 0 and topology_ok do
                    (
                        trace_guard += 1

                        if trace_guard > 8 then
                        (
                            logMsg "05 FAILED | Wall-strip trace exceeded safety limit."
                            topology_ok = false
                        )
                        else
                        (
                            local current_face_degree = edit_poly_mod.GetFaceDegree current_face_id node:obj

                            if current_face_degree != 4 then
                            (
                                logMsg ("05 FAILED | Wall-strip face is not a quad | face:" + (current_face_id as string))
                                topology_ok = false
                            )
                            else
                            (
                                strip_face_count += 1
                                local opposite_edge_id = 0

                                for side_id = 1 to current_face_degree while opposite_edge_id == 0 do
                                (
                                    local candidate_edge_id = edit_poly_mod.GetFaceEdge current_face_id side_id node:obj

                                    if candidate_edge_id != incoming_edge_id then
                                    (
                                        local candidate_vertex_a = edit_poly_mod.GetEdgeVertex candidate_edge_id 1 node:obj
                                        local candidate_vertex_b = edit_poly_mod.GetEdgeVertex candidate_edge_id 2 node:obj
                                        local shares_incoming_vertex =
                                            candidate_vertex_a == incoming_vertex_a or
                                            candidate_vertex_a == incoming_vertex_b or
                                            candidate_vertex_b == incoming_vertex_a or
                                            candidate_vertex_b == incoming_vertex_b

                                        if not shares_incoming_vertex then
                                        (
                                            opposite_edge_id = candidate_edge_id
                                        )
                                    )
                                )

                                if opposite_edge_id == 0 then
                                (
                                    logMsg ("05 FAILED | Could not resolve opposite horizontal edge | face:" + (current_face_id as string))
                                    topology_ok = false
                                )
                                else
                                (
                                    append strip_edges opposite_edge_id

                                    local opposite_face_a = edit_poly_mod.GetEdgeFace opposite_edge_id 1 node:obj
                                    local opposite_face_b = edit_poly_mod.GetEdgeFace opposite_edge_id 2 node:obj
                                    local next_face_id = 0

                                    if opposite_face_a == current_face_id then
                                    (
                                        next_face_id = opposite_face_b
                                    )
                                    else if opposite_face_b == current_face_id then
                                    (
                                        next_face_id = opposite_face_a
                                    )
                                    else
                                    (
                                        logMsg ("05 FAILED | Opposite edge is not attached to current wall face | edge:" + (opposite_edge_id as string))
                                        topology_ok = false
                                    )

                                    if topology_ok then
                                    (
                                        incoming_edge_id = opposite_edge_id
                                        incoming_vertex_a = edit_poly_mod.GetEdgeVertex incoming_edge_id 1 node:obj
                                        incoming_vertex_b = edit_poly_mod.GetEdgeVertex incoming_edge_id 2 node:obj
                                        current_face_id = next_face_id
                                    )
                                )
                            )
                        )
                    )

                    if topology_ok and (strip_face_count != 3 or strip_edges.count != 4) then
                    (
                        logMsg ("05 FAILED | Expected one strip with 3 wall faces and 4 horizontal edges | faces:" + (strip_face_count as string) + " edges:" + (strip_edges.count as string))
                        topology_ok = false
                    )
                )

                logMsg ("05 INPUT | verts:" + (vertex_count_before as string) + " edges:" + (edge_count_before as string) + " faces:" + (face_count_before as string) + " bottomFace:" + (bottom_face_id as string) + " stripEdges:" + (strip_edges as string))

                if topology_ok and strip_edges.count == 4 then
                (
                    local connect_edges = #{}

                    for edge_id in strip_edges do
                    (
                        connect_edges[edge_id] = true
                    )

                    local old_selection = edit_poly_mod.GetSelection #Edge node:obj

                    if old_selection.numberSet > 0 then
                    (
                        edit_poly_mod.Select #Edge old_selection select:false node:obj
                    )

                    edit_poly_mod.Select #Edge connect_edges node:obj
                    local stored_selection = edit_poly_mod.GetSelection #Edge node:obj

                    if stored_selection != connect_edges then
                    (
                        logMsg "05 FAILED | Single-strip edge selection was not stored in Edit Poly."
                    )
                    else
                    (
                        edit_poly_mod.connectEdgeSegments = 1
                        edit_poly_mod.connectEdgePinch = 0
                        edit_poly_mod.connectEdgeSlide = 0
                        edit_poly_mod.SetOperation #ConnectEdges
                        edit_poly_mod.Commit()
                        edit_poly_mod.RefreshScreen()
                        completeRedraw()

                        local vertex_count_after = edit_poly_mod.GetNumVertices node:obj
                        local edge_count_after = edit_poly_mod.GetNumEdges node:obj
                        local face_count_after = edit_poly_mod.GetNumFaces node:obj

                        logMsg ("05 RESULT | verts:" + (vertex_count_before as string) + "->" + (vertex_count_after as string) + " edges:" + (edge_count_before as string) + "->" + (edge_count_after as string) + " faces:" + (face_count_before as string) + "->" + (face_count_after as string))

                        if vertex_count_after == 20 and edge_count_after == 35 and face_count_after == 16 then
                        (
                            logMsg "Stage 05 SUCCESS | One wall side received one centered vertical connection."
                            result_value = true
                        )
                        else
                        (
                            logMsg "05 FAILED | Expected single-side topology: verts:20 edges:35 faces:16."
                        )
                    )
                )
            )
        )

        result_value
        -- return
    )

    -- -------------------------------------------------------------------------
    -- STAGE 06: INSERT VERTICES
    -- -------------------------------------------------------------------------
    /*
    LMB inserts one centered vertex on every current horizontal edge.
    RMB inserts two evenly spaced vertices on every current horizontal edge.
    Horizontal edges are detected directly from the current Edit Poly topology by exact endpoint Z.
    */
    function findEdgeByEndpointPositions edit_poly_mod obj endpoint_a endpoint_b =
    (
        local current_edge_count = edit_poly_mod.GetNumEdges node:obj
        local found_edge_id = 0

        for edge_id = 1 to current_edge_count while found_edge_id == 0 do
        (
            local vertex_a = edit_poly_mod.GetEdgeVertex edge_id 1 node:obj
            local vertex_b = edit_poly_mod.GetEdgeVertex edge_id 2 node:obj
            local position_a = edit_poly_mod.GetVertex vertex_a node:obj
            local position_b = edit_poly_mod.GetVertex vertex_b node:obj
            local forward_match = position_a == endpoint_a and position_b == endpoint_b
            local reverse_match = position_a == endpoint_b and position_b == endpoint_a

            if forward_match or reverse_match then
            (
                found_edge_id = edge_id
            )
        )

        found_edge_id
        -- return
    )

    function runStage06 vertices_per_edge =
    (
        if vertices_per_edge != 1 and vertices_per_edge != 2 then
        (
            logMsg "06 FAILED | vertices_per_edge must be 1 or 2."
            return false
        )

        local obj = getTestObject()
        if obj == undefined then
        (
            logMsg "06 FAILED | Missing target object."
            return false
        )

        for stack_mod in obj.modifiers do
        (
            if stack_mod.name == "06 INSERT VERTICES" then
            (
                logMsg "06 FAILED | Modifier already exists. Run the earlier stages from a clean setup."
                return false
            )
        )

        local result_value = false

        undo "06 Insert Vertices" on
        (
            logMsg ("Executing Stage 06: INSERT VERTICES | verticesPerEdge:" + (vertices_per_edge as string))

            local edit_poly_mod = Edit_Poly()
            edit_poly_mod.name = "06 INSERT VERTICES"
            edit_poly_mod.showCage = off
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            addModifier obj edit_poly_mod

            select obj
            max modify mode
            edit_poly_mod.SetPrimaryNode obj
            modPanel.setCurrentObject edit_poly_mod node:obj
            edit_poly_mod.SetEPolySelLevel #Edge
            subObjectLevel = 2

            local vertex_count_before = edit_poly_mod.GetNumVertices node:obj
            local edge_count_before = edit_poly_mod.GetNumEdges node:obj
            local face_count_before = edit_poly_mod.GetNumFaces node:obj
            local horizontal_edge_positions = #()

            -- Store geometric identity only. Edge IDs are deliberately not cached across DivideEdge commits.
            for edge_id = 1 to edge_count_before do
            (
                local vertex_a = edit_poly_mod.GetEdgeVertex edge_id 1 node:obj
                local vertex_b = edit_poly_mod.GetEdgeVertex edge_id 2 node:obj
                local position_a = edit_poly_mod.GetVertex vertex_a node:obj
                local position_b = edit_poly_mod.GetVertex vertex_b node:obj

                if position_a != position_b and position_a.z == position_b.z then
                (
                    append horizontal_edge_positions #(position_a, position_b)
                )
            )

            logMsg ("06 INPUT | verts:" + (vertex_count_before as string) + " edges:" + (edge_count_before as string) + " faces:" + (face_count_before as string) + " horizontalEdges:" + (horizontal_edge_positions.count as string) + " verticesPerEdge:" + (vertices_per_edge as string))

            if horizontal_edge_positions.count == 0 then
            (
                logMsg "06 FAILED | No horizontal edges were found."
            )
            else
            (
                local insert_ok = true
                local inserted_vertex_count = 0

                for edge_positions in horizontal_edge_positions while insert_ok do
                (
                    local endpoint_a = edge_positions[1]
                    local endpoint_b = edge_positions[2]
                    local current_edge_id = findEdgeByEndpointPositions edit_poly_mod obj endpoint_a endpoint_b

                    if current_edge_id == 0 then
                    (
                        logMsg ("06 FAILED | Could not re-resolve current horizontal edge | endpoints:" + (edge_positions as string))
                        insert_ok = false
                    )
                    else if vertices_per_edge == 1 then
                    (
                        local vertex_count_pre_insert = edit_poly_mod.GetNumVertices node:obj

                        edit_poly_mod.DivideEdge current_edge_id 0.5 node:obj
                        edit_poly_mod.Commit()

                        local vertex_count_post_insert = edit_poly_mod.GetNumVertices node:obj

                        if vertex_count_post_insert != (vertex_count_pre_insert + 1) then
                        (
                            logMsg ("06 FAILED | DivideEdge did not add exactly one vertex | edge:" + (current_edge_id as string) + " verts:" + (vertex_count_pre_insert as string) + "->" + (vertex_count_post_insert as string))
                            insert_ok = false
                        )
                        else
                        (
                            inserted_vertex_count += 1
                        )
                    )
                    else
                    (
                        local current_vertex_a = edit_poly_mod.GetEdgeVertex current_edge_id 1 node:obj
                        local current_vertex_b = edit_poly_mod.GetEdgeVertex current_edge_id 2 node:obj
                        local current_position_a = edit_poly_mod.GetVertex current_vertex_a node:obj
                        local current_position_b = edit_poly_mod.GetVertex current_vertex_b node:obj
                        local first_fraction = 1.0 / 3.0
                        local first_position = current_position_a + ((current_position_b - current_position_a) * first_fraction)
                        local vertex_count_pre_first_insert = edit_poly_mod.GetNumVertices node:obj

                        edit_poly_mod.DivideEdge current_edge_id first_fraction node:obj
                        edit_poly_mod.Commit()

                        local vertex_count_post_first_insert = edit_poly_mod.GetNumVertices node:obj

                        if vertex_count_post_first_insert != (vertex_count_pre_first_insert + 1) then
                        (
                            logMsg ("06 FAILED | First DivideEdge did not add exactly one vertex | edge:" + (current_edge_id as string) + " verts:" + (vertex_count_pre_first_insert as string) + "->" + (vertex_count_post_first_insert as string))
                            insert_ok = false
                        )
                        else
                        (
                            inserted_vertex_count += 1

                            -- The first split changed topology. Re-resolve the remaining segment geometrically.
                            local remaining_edge_id = findEdgeByEndpointPositions edit_poly_mod obj first_position current_position_b

                            if remaining_edge_id == 0 then
                            (
                                logMsg ("06 FAILED | Could not re-resolve second segment after first insertion | endpoints:#(" + (first_position as string) + "," + (current_position_b as string) + ")")
                                insert_ok = false
                            )
                            else
                            (
                                local vertex_count_pre_second_insert = edit_poly_mod.GetNumVertices node:obj

                                edit_poly_mod.DivideEdge remaining_edge_id 0.5 node:obj
                                edit_poly_mod.Commit()

                                local vertex_count_post_second_insert = edit_poly_mod.GetNumVertices node:obj

                                if vertex_count_post_second_insert != (vertex_count_pre_second_insert + 1) then
                                (
                                    logMsg ("06 FAILED | Second DivideEdge did not add exactly one vertex | edge:" + (remaining_edge_id as string) + " verts:" + (vertex_count_pre_second_insert as string) + "->" + (vertex_count_post_second_insert as string))
                                    insert_ok = false
                                )
                                else
                                (
                                    inserted_vertex_count += 1
                                )
                            )
                        )
                    )
                )

                edit_poly_mod.RefreshScreen()
                completeRedraw()

                local vertex_count_after = edit_poly_mod.GetNumVertices node:obj
                local edge_count_after = edit_poly_mod.GetNumEdges node:obj
                local face_count_after = edit_poly_mod.GetNumFaces node:obj
                local expected_insert_count = horizontal_edge_positions.count * vertices_per_edge

                logMsg ("06 RESULT | inserted:" + (inserted_vertex_count as string) + "/" + (expected_insert_count as string) + " verts:" + (vertex_count_before as string) + "->" + (vertex_count_after as string) + " edges:" + (edge_count_before as string) + "->" + (edge_count_after as string) + " faces:" + (face_count_before as string) + "->" + (face_count_after as string))

                if insert_ok and inserted_vertex_count == expected_insert_count and vertex_count_after == (vertex_count_before + expected_insert_count) and edge_count_after == (edge_count_before + expected_insert_count) and face_count_after == face_count_before then
                (
                    logMsg ("Stage 06 SUCCESS | Inserted " + (vertices_per_edge as string) + " vertex/vertices on every horizontal edge.")
                    result_value = true
                )
                else if insert_ok then
                (
                    logMsg "06 FAILED | Final topology did not match the expected inserted-vertex count."
                )
            )
        )

        result_value
        -- return
    )



    -- -------------------------------------------------------------------------
    -- STAGE 07: CONNECT 2 EDGE VERTS
    -- -------------------------------------------------------------------------
    /*
    Connects inserted vertices across each vertical wall face.
    Stage 06 LMB produces one pair per face; RMB produces two corresponding pairs.
    Geometric positions are cached, then current vertex IDs are re-resolved before each connect.
    */
    function getInteriorRowPositions row_positions =
    (
        local interior_positions = #()

        if row_positions.count < 3 then
        (
            return interior_positions
        )

        local endpoint_index_a = 1
        local endpoint_index_b = 2
        local maximum_distance = distance row_positions[1] row_positions[2]

        for position_index_a = 1 to (row_positions.count - 1) do
        (
            for position_index_b = (position_index_a + 1) to row_positions.count do
            (
                local pair_distance = distance row_positions[position_index_a] row_positions[position_index_b]

                if pair_distance > maximum_distance then
                (
                    maximum_distance = pair_distance
                    endpoint_index_a = position_index_a
                    endpoint_index_b = position_index_b
                )
            )
        )

        for position_index = 1 to row_positions.count do
        (
            if position_index != endpoint_index_a and position_index != endpoint_index_b then
            (
                append interior_positions row_positions[position_index]
            )
        )

        interior_positions
        -- return
    )

    function findVertexByPosition edit_poly_mod obj target_position =
    (
        local current_vertex_count = edit_poly_mod.GetNumVertices node:obj
        local found_vertex_id = 0
        local match_count = 0

        for vertex_id = 1 to current_vertex_count do
        (
            if edit_poly_mod.GetVertex vertex_id node:obj == target_position then
            (
                found_vertex_id = vertex_id
                match_count += 1
            )
        )

        if match_count == 1 then found_vertex_id else 0
        -- return
    )

    function runStage07 =
    (
        local obj = getTestObject()
        if obj == undefined then
        (
            logMsg "07 FAILED | Missing target object."
            return false
        )

        for stack_mod in obj.modifiers do
        (
            if stack_mod.name == "07 CONNECT 2 EDGE VERTS" then
            (
                logMsg "07 FAILED | Modifier already exists. Run the earlier stages from a clean setup."
                return false
            )
        )

        local result_value = false

        undo "07 Connect 2 Edge Verts" on
        (
            logMsg "Executing Stage 07: CONNECT 2 EDGE VERTS..."

            local edit_poly_mod = Edit_Poly()
            edit_poly_mod.name = "07 CONNECT 2 EDGE VERTS"
            edit_poly_mod.showCage = off
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            addModifier obj edit_poly_mod

            select obj
            max modify mode
            edit_poly_mod.SetPrimaryNode obj
            modPanel.setCurrentObject edit_poly_mod node:obj
            edit_poly_mod.SetEPolySelLevel #Vertex
            subObjectLevel = 1

            local vertex_count_before = edit_poly_mod.GetNumVertices node:obj
            local edge_count_before = edit_poly_mod.GetNumEdges node:obj
            local face_count_before = edit_poly_mod.GetNumFaces node:obj
            local connection_position_pairs = #()
            local topology_ok = true

            -- Collect only geometry identities before any topology-changing connect operation.
            for face_id = 1 to face_count_before while topology_ok do
            (
                local face_degree = edit_poly_mod.GetFaceDegree face_id node:obj

                if face_degree < 3 then
                (
                    logMsg ("07 FAILED | Face has fewer than three vertices | face:" + (face_id as string))
                    topology_ok = false
                )
                else
                (
                    local face_positions = #()
                    local face_minimum_z = undefined
                    local face_maximum_z = undefined

                    for corner_id = 1 to face_degree do
                    (
                        local vertex_id = edit_poly_mod.GetFaceVertex face_id corner_id node:obj
                        local vertex_position = edit_poly_mod.GetVertex vertex_id node:obj
                        append face_positions vertex_position

                        if face_minimum_z == undefined or vertex_position.z < face_minimum_z then
                        (
                            face_minimum_z = vertex_position.z
                        )

                        if face_maximum_z == undefined or vertex_position.z > face_maximum_z then
                        (
                            face_maximum_z = vertex_position.z
                        )
                    )

                    -- Skip horizontal faces. Wall faces span two Z levels.
                    if face_minimum_z != face_maximum_z then
                    (
                        local bottom_row_positions = #()
                        local top_row_positions = #()

                        for vertex_position in face_positions do
                        (
                            if vertex_position.z == face_minimum_z then
                            (
                                append bottom_row_positions vertex_position
                            )
                            else if vertex_position.z == face_maximum_z then
                            (
                                append top_row_positions vertex_position
                            )
                        )

                        local bottom_interior_positions = getInteriorRowPositions bottom_row_positions
                        local top_interior_positions = getInteriorRowPositions top_row_positions

                        if bottom_interior_positions.count != top_interior_positions.count then
                        (
                            logMsg ("07 FAILED | Opposite horizontal rows contain different inserted-vertex counts | face:" + (face_id as string))
                            topology_ok = false
                        )
                        else
                        (
                            for bottom_position in bottom_interior_positions while topology_ok do
                            (
                                local matching_top_position = undefined
                                local matching_top_count = 0

                                for top_position in top_interior_positions do
                                (
                                    if top_position.x == bottom_position.x and top_position.y == bottom_position.y then
                                    (
                                        matching_top_position = top_position
                                        matching_top_count += 1
                                    )
                                )

                                if matching_top_count != 1 then
                                (
                                    logMsg ("07 FAILED | Could not resolve exactly one vertically aligned inserted vertex | face:" + (face_id as string) + " bottom:" + (bottom_position as string))
                                    topology_ok = false
                                )
                                else
                                (
                                    local pair_already_stored = false

                                    for stored_pair in connection_position_pairs while not pair_already_stored do
                                    (
                                        if (stored_pair[1] == bottom_position and stored_pair[2] == matching_top_position) or
                                           (stored_pair[1] == matching_top_position and stored_pair[2] == bottom_position) then
                                        (
                                            pair_already_stored = true
                                        )
                                    )

                                    if not pair_already_stored then
                                    (
                                        append connection_position_pairs #(bottom_position, matching_top_position)
                                    )
                                )
                            )
                        )
                    )
                )
            )

            logMsg ("07 INPUT | verts:" + (vertex_count_before as string) + " edges:" + (edge_count_before as string) + " faces:" + (face_count_before as string) + " connectionPairs:" + (connection_position_pairs.count as string))

            if topology_ok and connection_position_pairs.count == 0 then
            (
                logMsg "07 FAILED | No inserted edge-vertex pairs were found to connect."
            )
            else if topology_ok then
            (
                local connect_ok = true
                local connected_pair_count = 0

                for position_pair in connection_position_pairs while connect_ok do
                (
                    -- Previous connects changed topology. Resolve both current IDs fresh by position.
                    local vertex_id_a = findVertexByPosition edit_poly_mod obj position_pair[1]
                    local vertex_id_b = findVertexByPosition edit_poly_mod obj position_pair[2]

                    if vertex_id_a == 0 or vertex_id_b == 0 or vertex_id_a == vertex_id_b then
                    (
                        logMsg ("07 FAILED | Could not re-resolve both current vertex IDs | pair:" + (position_pair as string))
                        connect_ok = false
                    )
                    else
                    (
                        local vertex_bits = #{}
                        vertex_bits[vertex_id_a] = true
                        vertex_bits[vertex_id_b] = true

                        local old_selection = edit_poly_mod.GetSelection #Vertex node:obj
                        if old_selection.numberSet > 0 then
                        (
                            edit_poly_mod.Select #Vertex old_selection select:false node:obj
                        )

                        edit_poly_mod.Select #Vertex vertex_bits node:obj
                        local stored_selection = edit_poly_mod.GetSelection #Vertex node:obj

                        if stored_selection != vertex_bits then
                        (
                            logMsg ("07 FAILED | Vertex pair selection was not stored | pair:" + (position_pair as string))
                            connect_ok = false
                        )
                        else
                        (
                            local vertex_count_pre_connect = edit_poly_mod.GetNumVertices node:obj
                            local edge_count_pre_connect = edit_poly_mod.GetNumEdges node:obj
                            local face_count_pre_connect = edit_poly_mod.GetNumFaces node:obj

                            edit_poly_mod.SetOperation #ConnectVertices
                            edit_poly_mod.Commit()

                            local vertex_count_post_connect = edit_poly_mod.GetNumVertices node:obj
                            local edge_count_post_connect = edit_poly_mod.GetNumEdges node:obj
                            local face_count_post_connect = edit_poly_mod.GetNumFaces node:obj

                            if vertex_count_post_connect != vertex_count_pre_connect or
                               edge_count_post_connect != (edge_count_pre_connect + 1) or
                               face_count_post_connect != (face_count_pre_connect + 1) then
                            (
                                logMsg ("07 FAILED | ConnectVertices did not create exactly one edge and one face | pair:" + (position_pair as string) + " verts:" + (vertex_count_pre_connect as string) + "->" + (vertex_count_post_connect as string) + " edges:" + (edge_count_pre_connect as string) + "->" + (edge_count_post_connect as string) + " faces:" + (face_count_pre_connect as string) + "->" + (face_count_post_connect as string))
                                connect_ok = false
                            )
                            else
                            (
                                connected_pair_count += 1
                            )
                        )
                    )
                )

                edit_poly_mod.RefreshScreen()
                completeRedraw()

                local vertex_count_after = edit_poly_mod.GetNumVertices node:obj
                local edge_count_after = edit_poly_mod.GetNumEdges node:obj
                local face_count_after = edit_poly_mod.GetNumFaces node:obj

                logMsg ("07 RESULT | connected:" + (connected_pair_count as string) + "/" + (connection_position_pairs.count as string) + " verts:" + (vertex_count_before as string) + "->" + (vertex_count_after as string) + " edges:" + (edge_count_before as string) + "->" + (edge_count_after as string) + " faces:" + (face_count_before as string) + "->" + (face_count_after as string))

                if connect_ok and connected_pair_count == connection_position_pairs.count and
                   vertex_count_after == vertex_count_before and
                   edge_count_after == (edge_count_before + connection_position_pairs.count) and
                   face_count_after == (face_count_before + connection_position_pairs.count) then
                (
                    logMsg "Stage 07 SUCCESS | Inserted edge vertices connected across the wall faces."
                    result_value = true
                )
                else if connect_ok then
                (
                    logMsg "07 FAILED | Final topology did not match the expected connected-pair count."
                )
            )
        )

        result_value
        -- return
    )


    -- -------------------------------------------------------------------------
    -- STAGE 08: REMOVE UP FACE
    -- -------------------------------------------------------------------------
    /*
    Removes the single face whose geometric normal points upward in local Z.
    Computes each polygon normal from its current ordered vertices so collinear
    inserted edge vertices do not invalidate the normal test.
    */
    function runStage08 =
    (
        local obj = getTestObject()
        if obj == undefined then
        (
            logMsg "08 FAILED | Missing target object."
            return false
        )

        for stack_mod in obj.modifiers do
        (
            if stack_mod.name == "08 REMOVE UP FACE" then
            (
                logMsg "08 FAILED | Modifier already exists. Run the earlier stages from a clean setup."
                return false
            )
        )

        local result_value = false

        undo "08 Remove Up Face" on
        (
            logMsg "Executing Stage 08: REMOVE UP FACE..."

            local edit_poly_mod = Edit_Poly()
            edit_poly_mod.name = "08 REMOVE UP FACE"
            edit_poly_mod.showCage = off
            edit_poly_mod.useStackSelection = false
            edit_poly_mod.selectMode = 0
            addModifier obj edit_poly_mod

            select obj
            max modify mode
            edit_poly_mod.SetPrimaryNode obj
            modPanel.setCurrentObject edit_poly_mod node:obj
            edit_poly_mod.SetEPolySelLevel #Face
            subObjectLevel = 4

            local vertex_count_before = edit_poly_mod.GetNumVertices node:obj
            local edge_count_before = edit_poly_mod.GetNumEdges node:obj
            local face_count_before = edit_poly_mod.GetNumFaces node:obj
            local upward_faces = #{}
            local topology_ok = true

            for face_id = 1 to face_count_before while topology_ok do
            (
                local face_degree = edit_poly_mod.GetFaceDegree face_id node:obj

                if face_degree < 3 then
                (
                    logMsg ("08 FAILED | Face has fewer than three vertices | face:" + (face_id as string))
                    topology_ok = false
                )
                else
                (
                    local face_normal_sum = [0.0, 0.0, 0.0]

                    for corner_id = 1 to face_degree do
                    (
                        local next_corner_id = corner_id + 1
                        if next_corner_id > face_degree then next_corner_id = 1

                        local current_vertex_id = edit_poly_mod.GetFaceVertex face_id corner_id node:obj
                        local next_vertex_id = edit_poly_mod.GetFaceVertex face_id next_corner_id node:obj
                        local current_position = edit_poly_mod.GetVertex current_vertex_id node:obj
                        local next_position = edit_poly_mod.GetVertex next_vertex_id node:obj

                        face_normal_sum += cross current_position next_position
                    )

                    if length face_normal_sum == 0.0 then
                    (
                        logMsg ("08 FAILED | Degenerate face normal | face:" + (face_id as string))
                        topology_ok = false
                    )
                    else if face_normal_sum.z > 0.0 then
                    (
                        upward_faces[face_id] = true
                        logMsg ("08 UP FACE | face:" + (face_id as string) + " normalSum:" + (face_normal_sum as string))
                    )
                )
            )

            logMsg ("08 INPUT | verts:" + (vertex_count_before as string) + " edges:" + (edge_count_before as string) + " faces:" + (face_count_before as string) + " upwardFaces:" + (upward_faces.numberSet as string))

            if topology_ok then
            (
                if upward_faces.numberSet != 1 then
                (
                    logMsg ("08 FAILED | Expected exactly one upward-facing face, found:" + (upward_faces.numberSet as string))
                )
                else
                (
                    edit_poly_mod.Select #Face upward_faces node:obj
                    local stored_selection = edit_poly_mod.GetSelection #Face node:obj

                    if stored_selection != upward_faces then
                    (
                        logMsg "08 FAILED | Upward face selection was not stored in Edit Poly."
                    )
                    else
                    (
                        edit_poly_mod.SetOperation #DeleteFace
                        edit_poly_mod.Commit()
                        edit_poly_mod.RefreshScreen()
                        completeRedraw()

                        local vertex_count_after = edit_poly_mod.GetNumVertices node:obj
                        local edge_count_after = edit_poly_mod.GetNumEdges node:obj
                        local face_count_after = edit_poly_mod.GetNumFaces node:obj

                        logMsg ("08 RESULT | verts:" + (vertex_count_before as string) + "->" + (vertex_count_after as string) + " edges:" + (edge_count_before as string) + "->" + (edge_count_after as string) + " faces:" + (face_count_before as string) + "->" + (face_count_after as string))

                        if vertex_count_after == vertex_count_before and edge_count_after == edge_count_before and face_count_after == (face_count_before - 1) then
                        (
                            logMsg "Stage 08 SUCCESS | Upward-facing face removed."
                            result_value = true
                        )
                        else
                        (
                            logMsg "08 FAILED | Expected only the upward face count to decrease by one."
                        )
                    )
                )
            )
        )

        result_value
        -- return
    )

    -- -------------------------------------------------------------------------
    -- MANUAL VERTEX MOVE DIAGNOSTIC
    -- -------------------------------------------------------------------------
    /*
    Moves a supplied Edit Poly vertex selection radially away from the live bounding-box center.
    The move distance is a caller-supplied fraction of the current bounding-box maximum dimension.
    */
    function moveEditPolyVerticesOutwardByBBoxFraction edit_poly_mod obj selected_vertices bbox_fraction =
    (
        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then return false
        if obj == undefined or not isValidNode obj then return false
        if selected_vertices == undefined or classOf selected_vertices != BitArray or selected_vertices.numberSet == 0 then return false
        if bbox_fraction <= 0.0 then return false

        edit_poly_mod.SetPrimaryNode obj

        local vertex_count = edit_poly_mod.GetNumVertices node:obj

        if vertex_count < 1 then return false

        local first_position = edit_poly_mod.GetVertex 1 node:obj
        local bbox_minimum = first_position
        local bbox_maximum = first_position

        for vertex_id = 2 to vertex_count do
        (
            local vertex_position = edit_poly_mod.GetVertex vertex_id node:obj

            if vertex_position.x < bbox_minimum.x then bbox_minimum.x = vertex_position.x
            if vertex_position.y < bbox_minimum.y then bbox_minimum.y = vertex_position.y
            if vertex_position.z < bbox_minimum.z then bbox_minimum.z = vertex_position.z

            if vertex_position.x > bbox_maximum.x then bbox_maximum.x = vertex_position.x
            if vertex_position.y > bbox_maximum.y then bbox_maximum.y = vertex_position.y
            if vertex_position.z > bbox_maximum.z then bbox_maximum.z = vertex_position.z
        )

        local bbox_size = bbox_maximum - bbox_minimum
        local bbox_reference_size = bbox_size.x

        if bbox_size.y > bbox_reference_size then bbox_reference_size = bbox_size.y
        if bbox_size.z > bbox_reference_size then bbox_reference_size = bbox_size.z
        if bbox_reference_size <= 0.0 then return false

        local bbox_center = (bbox_minimum + bbox_maximum) / 2.0
        local move_distance = bbox_reference_size * bbox_fraction
        local move_records = #()

        for vertex_id in selected_vertices do
        (
            if vertex_id < 1 or vertex_id > vertex_count then return false

            local vertex_position = edit_poly_mod.GetVertex vertex_id node:obj
            local outward_vector = vertex_position - bbox_center
            local outward_length = length outward_vector

            if outward_length == 0.0 then return false

            local move_delta = (outward_vector / outward_length) * move_distance
            append move_records #(vertex_id, vertex_position, move_delta)
        )

        local move_ok = true

        undo "Move Selected Vertices Out" on
        (
            local current_selection = edit_poly_mod.GetSelection #Vertex node:obj

            if current_selection.numberSet > 0 then
            (
                edit_poly_mod.Select #Vertex current_selection select:false node:obj
            )

            for move_record in move_records while move_ok do
            (
                local vertex_id = move_record[1]
                local original_position = move_record[2]
                local move_delta = move_record[3]
                local vertex_bits = #{}
                vertex_bits[vertex_id] = true

                edit_poly_mod.Select #Vertex vertex_bits node:obj

                if edit_poly_mod.GetSelection #Vertex node:obj != vertex_bits then
                (
                    move_ok = false
                )
                else
                (
                    edit_poly_mod.MoveSelection move_delta
                    edit_poly_mod.Commit()

                    local moved_position = edit_poly_mod.GetVertex vertex_id node:obj
                    local expected_position = original_position + move_delta

                    if moved_position != expected_position then
                    (
                        move_ok = false
                    )
                )

                local isolated_selection = edit_poly_mod.GetSelection #Vertex node:obj
                if isolated_selection.numberSet > 0 then
                (
                    edit_poly_mod.Select #Vertex isolated_selection select:false node:obj
                )
            )

            edit_poly_mod.Select #Vertex selected_vertices select:true node:obj
            edit_poly_mod.RefreshScreen()
            completeRedraw()
        )

        move_ok
        -- return
    )

    /*
    Resolves the current test-object Edit Poly vertex selection and moves it outward by 25% of bbox size.
    Keeps UI/context validation separate from the reusable vertex-move method.
    */
    function moveSelectedVerticesOutward =
    (
        local obj = getTestObject()

        if obj == undefined then
        (
            logMsg "MOVE SELECTED VERTS OUT FAILED | Missing target object."
            return false
        )

        local edit_poly_mod = modPanel.getCurrentObject()

        if edit_poly_mod == undefined or classOf edit_poly_mod != Edit_Poly then
        (
            logMsg "MOVE SELECTED VERTS OUT FAILED | Make an Edit Poly modifier current in the Modify panel."
            return false
        )

        local belongs_to_test_object = false

        for stack_mod in obj.modifiers while not belongs_to_test_object do
        (
            if stack_mod == edit_poly_mod then belongs_to_test_object = true
        )

        if not belongs_to_test_object then
        (
            logMsg "MOVE SELECTED VERTS OUT FAILED | The current Edit Poly does not belong to EPOLY_STACK_TEST."
            return false
        )

        edit_poly_mod.SetPrimaryNode obj
        local selected_vertices = edit_poly_mod.GetSelection #Vertex node:obj

        if selected_vertices == undefined or selected_vertices.numberSet == 0 then
        (
            logMsg "MOVE SELECTED VERTS OUT FAILED | Select one or more vertices in the current Edit Poly modifier."
            return false
        )

        local bbox_fraction = 0.25
        local move_ok = moveEditPolyVerticesOutwardByBBoxFraction edit_poly_mod obj selected_vertices bbox_fraction

        if move_ok then
        (
            logMsg ("MOVE SELECTED VERTS OUT SUCCESS | modifier:" + edit_poly_mod.name + " bboxFraction:" + (bbox_fraction as string) + " moved:" + (selected_vertices.numberSet as string))
        )
        else
        (
            logMsg "MOVE SELECTED VERTS OUT FAILED | Reusable bbox-relative move operation did not complete."
        )

        move_ok
        -- return
    )

    -- -------------------------------------------------------------------------
    -- UI CONTROLLERS & ENGINE COUPLING
    -- -------------------------------------------------------------------------
    on btn_stg00 pressed do runStage00()
    on btn_stg01 pressed do runStage01()
    on btn_stg02 pressed do runStage02()
    on btn_stg03 pressed do runStage03()

on btn_stg04 pressed do runStage04()
on btn_stg05 pressed do runStage05()
on btn_stg06 pressed do runStage06 1
on btn_stg06 rightclick do runStage06 2
on btn_stg07 pressed do runStage07()
on btn_stg08 pressed do runStage08()
on btn_move_selected_out pressed do moveSelectedVerticesOutward()
on btn_all pressed do
(
-- Complete clean run sequence with conditional pipeline enforcement
if runStage00() then
if runStage01() then
if runStage02() then
if runStage03() then
if runStage04() then
if runStage05() then
if runStage06 1 then
if runStage07() then
if runStage08() then
logMsg ">>> PIPELINE COMPLETE: All tests passed cleanly without stack collapse! <<<"
)
on btn_rst pressed do
(
local obj = getTestObject()
if obj != undefined then delete obj
logMsg "Scene cleared completely."
)
)
if epoly_stack_test_dump_logger != undefined then
(
    epoly_stack_test_dump_logger.log ("EPoly-Stack-Test | RUN START | fileVersion:" + (epoly_stack_test_file_version as string) + " projectVersion:" + (epoly_stack_test_file_project_version as string))
    epoly_stack_test_dump_logger.log ("EPoly-Stack-Test | LOG FILE | " + epoly_stack_test_dump_file_path)
)

createDialog EPolyStackTestRollout
windows.processPostedMessages()




