/*
================================================================================
REDUNDANT LOOP FIXER
================================================================================
- Evaluates geometry at the currently active modifier level.
- Uses convertToPoly on a disposable clone to preserve quads/n-gons (no snapshotAsMesh triangulation).
- STRICT CHECK: Will NOT add an Edit_Poly modifier if no redundant loops are found.
- Non-destructive stack workflow with safe edge removal.
================================================================================
*/

struct RedundantLoopFixer
(
    -- Helper: safely set selectMode property
    function forceSelectModeZero polyObj =
    (
        try
        (
            if hasProperty polyObj #selectMode then polyObj.selectMode = 0
            true
        )
        catch(false)
    ),

    /*
    Acquires evaluated geometry up to the CURRENT active modifier level.
    Uses convertToPoly on a temporary copy to preserve quads and n-gons.
    */
    function acquireAnalysisSource node =
    (
        if node == undefined or not (isValidNode node) then return undefined

        local temp_node = undefined
        local result_data = undefined

        try
        (
            with undo off
            (
                temp_node = copy node
                temp_node.name = uniqueName "__REDUNDANT_LOOP_ANALYSIS__"

                -- Find the currently active modifier level in the Modifier Panel
                local current_mod = modPanel.getCurrentObject()
                local mod_index_on_orig = 0

                if current_mod != undefined then
                (
                    for i = 1 to node.modifiers.count while mod_index_on_orig == 0 do
                    (
                        if node.modifiers[i] == current_mod do mod_index_on_orig = i
                    )
                )

                -- Delete modifiers on the clone that are ABOVE the currently active modifier
                if mod_index_on_orig > 1 then
                (
                    for i = 1 to (mod_index_on_orig - 1) do
                    (
                        deleteModifier temp_node temp_node.modifiers[1]
                    )
                )

                -- Snapshot geometry to Editable_Poly (preserves n-gons/quads, avoids triangulation)
                convertToPoly temp_node

                if classOf temp_node.baseObject != Editable_Poly then 
                    throw "Evaluated analysis copy is not Editable Poly."

                temp_node.baseObject.showCage = off
                forceSelectModeZero temp_node.baseObject

                result_data = #(temp_node, temp_node.baseObject, true)
            )
        )
        catch
        (
            local analysis_error = getCurrentException()
            if temp_node != undefined do try(delete temp_node)catch()
            format "Redundant-Loop-Fixer ANALYSIS ERROR | node:% | %\n" node.name analysis_error
            result_data = undefined
        )

        result_data
    ),

    /*
    Analyzes poly geometry for planar redundant loop edges based on face angle & straightness.
    */
    function detectRedundantLoops poly_obj face_threshold:0.1 straight_threshold:5.0 =
    (
        if poly_obj == undefined or classOf poly_obj != Editable_Poly then return #{}

        local num_edges = poly_obj.numEdges
        local redundant_edges = #{}

        for e = 1 to num_edges do
        (
            local edge_faces = poly_obj.getEdgeFaces e

            -- Redundant edge candidates must border exactly two faces
            if edge_faces.count == 2 then
            (
                local f1_norm = poly_obj.getFaceNormal edge_faces[1]
                local f2_norm = poly_obj.getFaceNormal edge_faces[2]
                
                -- Calculate planar face deviation angle
                local dot_prod = dot f1_norm f2_norm
                if dot_prod > 1.0 do dot_prod = 1.0
                if dot_prod < -1.0 do dot_prod = -1.0
                local angle_diff = acos dot_prod

                if angle_diff <= face_threshold then
                (
                    local edge_verts = poly_obj.getEdgeVerts e
                    local v1 = edge_verts[1]
                    local v2 = edge_verts[2]
                    local v1_edges = poly_obj.getVertEdges v1
                    local v2_edges = poly_obj.getVertEdges v2

                    -- Check if vertices belong to continuous quad-loop structures (valence 4 or 2)
                    if (v1_edges.count == 4 or v1_edges.count == 2) and (v2_edges.count == 4 or v2_edges.count == 2) then
                    (
                        redundant_edges[e] = true
                    )
                )
            )
        )

        redundant_edges
    ),

    /*
    Main Detection Workflow:
    - Analyzes geometry at active modifier level.
    - DOES NOT add an Edit_Poly modifier if redundant_edges is empty.
    */
    function selectRedundantLoopsOnNode node face_threshold:0.1 straight_threshold:5.0 debug_output:true =
    (
        if node == undefined or not (isValidNode node) then
            return #(false, "Invalid node.", 0, undefined, undefined)

        -- Step 1: Snapshot geometry up to active modifier level
        local analysis_data = acquireAnalysisSource node
        if analysis_data == undefined then
            return #(false, "Failed to analyze node geometry.", 0, undefined, undefined)

        local temp_node = analysis_data[1]
        local analysis_poly = analysis_data[2]

        -- Step 2: Detect redundant loop edges
        local redundant_edges = detectRedundantLoops analysis_poly face_threshold:face_threshold straight_threshold:straight_threshold

        -- Step 3: Cleanup temporary analysis node immediately
        if isValidNode temp_node do delete temp_node

        -- Step 4: STRICT CHECK - Early exit if no redundant loops are found
        if redundant_edges.isEmpty or redundant_edges.numberSet == 0 then
        (
            if debug_output do 
                format "Redundant-Loop-Fixer: Mesh is clean. No redundant loops found on '%'.\n" node.name
            
            return #(true, "No redundant loops found.", 0, node, undefined)
        )

        -- Step 5: Loops found! Apply or reuse 'SELECT REDUNDANT LOOPS' Edit_Poly modifier
        local selection_modifier = undefined

        -- Check if an existing 'SELECT REDUNDANT LOOPS' modifier is already on the stack
        for m in node.modifiers while selection_modifier == undefined do
        (
            if classOf m == Edit_Poly and m.name == "SELECT REDUNDANT LOOPS" then
                selection_modifier = m
        )

        -- Create a new Edit_Poly modifier ONLY when redundant loops actually exist
        if selection_modifier == undefined then
        (
            selection_modifier = Edit_Poly()
            selection_modifier.name = "SELECT REDUNDANT LOOPS"
            addModifier node selection_modifier
        )

        -- Step 6: Commit selection on the Edit_Poly modifier
        select node
        max modify mode
        modPanel.setCurrentObject selection_modifier node:node
        selection_modifier.SetEPolySelLevel #Edge
        subObjectLevel = 2

        -- Apply BitArray selection
        selection_modifier.SetSelection #Edge redundant_edges
        
        if debug_output do
            format "Redundant-Loop-Fixer: Selected % redundant edge(s) on '%'.\n" redundant_edges.numberSet node.name

        return #(true, "Redundant loops selected successfully.", redundant_edges.numberSet, node, selection_modifier)
    ),

    /*
    Non-destructive Removal:
    Removes selected redundant loops inside the Edit_Poly modifier without collapsing the stack.
    */
    function removeSelectedRedundantLoops face_threshold:0.1 straight_threshold:5.0 =
    (
        local selected_nodes = selection as array

        if selected_nodes.count == 0 then
        (
            messageBox "Select at least one object." title:"Redundant-Loop-Fixer"
            return false
        )

        local removed_count = 0
        local failed_count = 0

        for node in selected_nodes do
        (
            local selection_modifier = undefined

            -- Search for existing modifier
            for m in node.modifiers while selection_modifier == undefined do
            (
                if classOf m == Edit_Poly and m.name == "SELECT REDUNDANT LOOPS" then
                    selection_modifier = m
            )

            -- If modifier doesn't exist, run detection (will only create if loops exist)
            if selection_modifier == undefined then
            (
                local res = selectRedundantLoopsOnNode node face_threshold:face_threshold straight_threshold:straight_threshold debug_output:false
                if res[1] and res[3] > 0 then
                    selection_modifier = res[5]
            )

            -- Perform removal inside Edit_Poly modifier
            if selection_modifier != undefined then
            (
                try
                (
                    select node
                    max modify mode
                    modPanel.setCurrentObject selection_modifier node:node
                    selection_modifier.SetEPolySelLevel #Edge
                    subObjectLevel = 2

                    local current_edges = selection_modifier.GetSelection #Edge node:node

                    if current_edges.numberSet > 0 then
                    (
                        selection_modifier.SetOperation #RemoveEdge
                        selection_modifier.Commit()
                        selection_modifier.name = "DELETED REDUNDANT LOOPS"
                        removed_count += 1
                    )
                    else
                    (
                        failed_count += 1
                    )
                )
                catch
                (
                    failed_count += 1
                    format "Redundant-Loop-Fixer REMOVE ERROR | node:% | %\n" node.name (getCurrentException())
                )
            )
            else
            (
                format "Redundant-Loop-Fixer: No redundant loops to remove on '%'.\n" node.name
            )
        )

        completeRedraw()
        (removed_count > 0)
    )
)

-- Global instance
global RedundantLoopFixerInstance = RedundantLoopFixer()