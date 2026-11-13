/*
Spline Editor - Tool-specific spline visibility coordination, no UI.
File version: 0.002 | Project version: 0.003
*/

struct SplineEditor_v
(
    file_version = "0.002",
    project_version = "0.003",

    /*
    Resolves one selected Editable Spline base object in the current edit context.
    Returns a shape node or undefined after reporting an invalid context.
    */
    function getTargetNode require_level:true =
    (
        local target_node = undefined

        if selection.count != 1 then
        (
            format "Spline Editor | Expected exactly one selected shape, got % nodes.\n" selection.count
        )
        else
        (
            local candidate_node = selection[1]
            local base_class = classOf candidate_node.baseObject

            if base_class != SplineShape then
            (
                format "Spline Editor | Node '%' base class is %, expected Editable Spline (SplineShape).\n" candidate_node.name base_class
            )
            else if require_level and ((subObjectLevel == undefined) or (subObjectLevel < 1) or (subObjectLevel > 3)) then
            (
                format "Spline Editor | Requires spline sub-object level 1, 2, or 3; actual level is %.\n" subObjectLevel
            )
            else
            (
                target_node = candidate_node
            )
        )

        target_node
        -- return
    ),

    /*
    Counts selected spline knots, segments or whole splines at a given level.
    An empty valid selection returns zero, not a failed read.
    */
    function getSelectedCount target_node edit_level =
    (
        local selected_count = 0

        case edit_level of
        (
            1:
            (
                for spline_index = 1 to (numSplines target_node) do
                (
                    selected_count += (getKnotSelection target_node spline_index).count
                )
            )
            2:
            (
                for spline_index = 1 to (numSplines target_node) do
                (
                    selected_count += (getSegSelection target_node spline_index).count
                )
            )
            3:
            (
                selected_count = (getSplineSelection target_node).count
            )
        )

        selected_count
        -- return
    ),

    /*
    Hides the active, nonempty sub-object selection with the native Shape API.
    Vertex hiding affects connected segments as documented by Autodesk.
    */
    function hideSelected =
    (
        local target_node = getTargetNode()
        local operation_ok = false

        if target_node != undefined then
        (
            local edit_level = subObjectLevel
            local selected_count = getSelectedCount target_node edit_level

            if selected_count == 0 then
            (
                format "Spline Editor | Hide Selected: no components selected on '%'.\n" target_node.name
            )
            else
            (
                case edit_level of
                (
                    1: (hideSelectedVerts target_node)
                    2: (hideSelectedSegments target_node)
                    3: (hideSelectedSplines target_node)
                )
                updateShape target_node
                operation_ok = true
            )
        )

        operation_ok
        -- return
    ),

    /*
    Hides the complementary selection, then restores the exact original IDs.
    If an edit or restoration fails, report it and never claim full success.
    */
    function hideUnselected =
    (
        local target_node = getTargetNode()
        local operation_ok = false

        if target_node != undefined then
        (
            local edit_level = subObjectLevel
            local spline_count = numSplines target_node
            local selected_count = getSelectedCount target_node edit_level

            if selected_count == 0 then
            (
                format "Spline Editor | Hide Unselected: no selection on '%'.\n" target_node.name
            )
            else
            (
                local original_sets = #()
                local inverse_sets = #()
                local list_count = if edit_level == 3 then 1 else spline_count
                local inverse_count = 0

                original_sets.count = list_count
                inverse_sets.count = list_count

                for set_index = 1 to list_count do
                (
                    local original_ids = case edit_level of
                    (
                        1: (getKnotSelection target_node set_index)
                        2: (getSegSelection target_node set_index)
                        3: (getSplineSelection target_node)
                    )
                    local component_count = case edit_level of
                    (
                        1: (numKnots target_node set_index)
                        2: (numSegments target_node set_index)
                        3: spline_count
                    )
                    local inverse_ids = for component_id = 1 to component_count where (findItem original_ids component_id == 0) collect component_id

                    original_sets[set_index] = original_ids
                    inverse_sets[set_index] = inverse_ids
                    inverse_count += inverse_ids.count
                )

                if inverse_count == 0 then
                (
                    format "Spline Editor | Hide Unselected: all components selected on '%'.\n" target_node.name
                )
                else
                (
                    local hide_ok = false
                    local restore_ok = false

                    try
                    (
                        for set_index = 1 to list_count do
                        (
                            case edit_level of
                            (
                                1: (setKnotSelection target_node set_index inverse_sets[set_index])
                                2: (setSegSelection target_node set_index inverse_sets[set_index])
                                3: (setSplineSelection target_node inverse_sets[set_index])
                            )
                        )

                        case edit_level of
                        (
                            1: (hideSelectedVerts target_node)
                            2: (hideSelectedSegments target_node)
                            3: (hideSelectedSplines target_node)
                        )

                        hide_ok = true
                    )
                    catch
                    (
                        format "Spline Editor | Hide Unselected failed on '%' at level %: %\n" target_node.name edit_level (getCurrentException())
                    )

                    try
                    (
                        for set_index = 1 to list_count do
                        (
                            case edit_level of
                            (
                                1: (setKnotSelection target_node set_index original_sets[set_index])
                                2: (setSegSelection target_node set_index original_sets[set_index])
                                3: (setSplineSelection target_node original_sets[set_index])
                            )
                        )
                        restore_ok = true
                    )
                    catch
                    (
                        format "Spline Editor | Selection restore failed on '%' at level %: %\n" target_node.name edit_level (getCurrentException())
                    )

                    if hide_ok and restore_ok then
                    (
                        updateShape target_node
                        operation_ok = true
                    )
                    else
                    (
                        format "Spline Editor | Hide Unselected incomplete for '%': hide_ok:% restore_ok:%.\n" target_node.name hide_ok restore_ok
                    )
                )
            )
        )

        operation_ok
        -- return
    ),

    /*
    Reveals hidden segments without requiring sub-object mode.
    Applies directly to the selected Editable Spline base object.
    */
    function unhideAll =
    (
        local target_node = getTargetNode require_level:false
        local operation_ok = false

        if target_node != undefined then
        (
            unhideSegments target_node
            updateShape target_node
            operation_ok = true
        )

        operation_ok
        -- return
    ),

    /*
    Validates an operation's required base-object sub-object level and selection.
    Reports the actual context and required level at the failure site.
    */
    function getNodeForLevel required_level require_selection:true =
    (
        local target_node = getTargetNode require_level:false
        if target_node != undefined then
        (
            if subObjectLevel != required_level then
            (
                format "Spline Editor | Expected sub-object level %, actual %, node '%'.\n" required_level subObjectLevel target_node.name
                target_node = undefined
            )
            else if require_selection and (getSelectedCount target_node required_level) == 0 then
            (
                format "Spline Editor | No components selected for level % on '%'.\n" required_level target_node.name
                target_node = undefined
            )
        )
        target_node
        -- return
    ),

    /*
    Runs the native Fuse or Weld operation with the selected knots.
    For Weld, uses the caller's explicit distance, in current system units.
    */
    function editKnots action_key weld_threshold:0.0 =
    (
        local target_node = getNodeForLevel 1
        local operation_ok = false
        if target_node != undefined then
        (
            if action_key == #fuse then
            (
                splineOps.fuse target_node
                updateShape target_node
                operation_ok = true
            )
            else if action_key == #weld then
            (
                if weld_threshold < 0.0 then
                (
                    format "Spline Editor | Invalid weld distance: %, expected >= 0.\n" weld_threshold
                )
                else
                (
                    local before_count = numKnots target_node
                    weldSpline target_node weld_threshold
                    updateShape target_node
                    local after_count = numKnots target_node
                    operation_ok = after_count < before_count
                    if not operation_ok then
                    (
                        format "Spline Editor | Weld did not merge knots on '%'. Before:% after:% distance:% system units.\n" target_node.name before_count after_count weld_threshold
                    )
                )
            )
        )
        operation_ok
        -- return
    ),

    /*
    Starts interactive Cross Insert at the vertex sub-object level.
    The Modify panel owns its threshold; no unsupported setter is called.
    */
    function startCrossInsert =
    (
        local target_node = getNodeForLevel 1 require_selection:false
        if target_node != undefined then
        (
            splineOps.startCrossInsert target_node
            true
        )
        else false
        -- return
    ),

    /*
    Applies an explicitly chosen number of new knots to selected segments.
    Uses descending original segment indices to avoid topology index drift.
    */
    function divideSelected division_count =
    (
        local target_node = getNodeForLevel 2
        local operation_ok = false
        if target_node != undefined then
        (
            if division_count < 1 or division_count > 100 then
            (
                format "Spline Editor | Divide count must be 1..100; actual:%.\n" division_count
            )
            else
            (
                local spline_count = numSplines target_node
                local original_sets = #()
                local original_segment_counts = #()
                original_sets.count = spline_count
                original_segment_counts.count = spline_count
                for spline_index = 1 to spline_count do
                (
                    original_sets[spline_index] = getSegSelection target_node spline_index
                    original_segment_counts[spline_index] = numSegments target_node spline_index
                )
                local division_ok = true
                for spline_index = 1 to spline_count while division_ok do
                (
                    local selected_ids = original_sets[spline_index]
                    for selected_index = selected_ids.count to 1 by -1 while division_ok do
                    (
                        local segment_index = selected_ids[selected_index]
                        for division_index = division_count to 1 by -1 while division_ok do
                        (
                            local segment_fraction = (division_index as float) / ((division_count + 1) as float)
                            local new_knot_id = refineSegment target_node spline_index segment_index segment_fraction
                            if (classOf new_knot_id != Integer) or (new_knot_id < 1) then
                            (
                                format "Spline Editor | Refine failed node:% spline:% segment:% step:% result:%.\n" target_node.name spline_index segment_index division_index new_knot_id
                                division_ok = false
                            )
                        )
                    )
                )
                updateShape target_node
                for spline_index = 1 to spline_count while division_ok do
                (
                    local expected_count = original_segment_counts[spline_index] + (original_sets[spline_index].count * division_count)
                    local actual_count = numSegments target_node spline_index
                    if actual_count != expected_count then
                    (
                        format "Spline Editor | Divide topology mismatch node:% spline:% expected:% actual:% selected:% subdivisions:%.\n" target_node.name spline_index expected_count actual_count original_sets[spline_index] division_count
                        division_ok = false
                    )
                )
                operation_ok = division_ok
            )
        )
        operation_ok
        -- return
    ),

    /*
    Enters native interactive Attach, Attach Multiple, or Detach dialog.
    Reports launch rather than claiming that the user completed a dialog.
    */
    function startNativeAction action_key =
    (
        local target_node = getTargetNode require_level:false
        local action_ok = false
        if target_node != undefined then
        (
            case action_key of
            (
                #attach: (splineOps.startAttach target_node; action_ok = true)
                #attachMultiple: (splineOps.attachMultiple target_node; action_ok = true)
                #detachDialog:
                (
                    if (subObjectLevel != undefined) and (subObjectLevel >= 1) and (subObjectLevel <= 3) and (getSelectedCount target_node subObjectLevel) > 0 then
                    (
                        splineOps.detach target_node
                        action_ok = true
                    )
                    else
                    (
                        format "Spline Editor | Detach dialog needs selected sub-objects on '%'. Level:%\n" target_node.name subObjectLevel
                    )
                )
                default: (format "Spline Editor | Unknown native action %.\n" action_key)
            )
        )
        action_ok
        -- return
    ),

    /*
    Explodes selected spline sub-objects using the native command.
    Verifies a changed spline count and preserves native dialog choices.
    */
    function explodeSelected =
    (
        local target_node = getNodeForLevel 3
        local operation_ok = false
        if target_node != undefined then
        (
            local before_count = numSplines target_node
            local before_shapes = shapes.count
            splineOps.explode target_node
            local after_count = numSplines target_node
            local after_shapes = shapes.count
            operation_ok = (after_count != before_count) or (after_shapes > before_shapes)
            if not operation_ok then
            (
                format "Spline Editor | Explode invoked; spline count unchanged on '%': %; native mode may have created separate objects.\n" target_node.name after_count
            )
        )
        operation_ok
        -- return
    ),

    /*
    Copies selected spline curves to another existing SplineShape node.
    Preserves corner/Bezier tangent vectors, closure and segment Material IDs.
    */
    function copySplineCurve source_node target_node spline_index =
    (
        local target_index = addNewSpline target_node
        local knot_count = numKnots source_node spline_index
        for knot_index = 1 to knot_count do
        (
            local knot_type = getKnotType source_node spline_index knot_index
            local segment_type = if knot_index <= (numSegments source_node spline_index) then (getSegmentType source_node spline_index knot_index) else #line
            local knot_position = getKnotPoint source_node spline_index knot_index
            if knot_type == #bezier or knot_type == #bezierCorner then
            (
                local in_vec = getInVec source_node spline_index knot_index
                local out_vec = getOutVec source_node spline_index knot_index
                addKnot target_node target_index knot_type segment_type knot_position in_vec out_vec
            )
            else
            (
                addKnot target_node target_index knot_type segment_type knot_position
            )
        )
        if isClosed source_node spline_index then
        (
            close target_node target_index
        )
        for segment_index = 1 to (numSegments source_node spline_index) do
        (
            setMaterialID target_node target_index segment_index (getMaterialID source_node spline_index segment_index)
        )
        target_index
        -- return
    ),

    /*
    Creates independent copies of the selected splines inside the same shape.
    Reads from a duplicate source to prevent topology index changes while copying.
    */
    function duplicateSplinesInside =
    (
        local target_node = getNodeForLevel 3
        local operation_ok = false
        if target_node != undefined then
        (
            local selected_ids = getSplineSelection target_node
            local source_node = copy target_node
            local before_count = numSplines target_node
            local copied_count = 0
            try
            (
                for spline_index in selected_ids do
                (
                    copySplineCurve source_node target_node spline_index
                    copied_count += 1
                )
                updateShape target_node
                operation_ok = (numSplines target_node == before_count + selected_ids.count) and (copied_count == selected_ids.count)
                if not operation_ok then
                (
                    format "Spline Editor | Spline copy incomplete node:% expected:% actual:% copied:%.\n" target_node.name (before_count + selected_ids.count) (numSplines target_node) copied_count
                )
            )
            catch
            (
                format "Spline Editor | Spline copy exception node:% copied:% error:%.\n" target_node.name copied_count (getCurrentException())
            )
            delete source_node
        )
        operation_ok
        -- return
    ),

    /*
    Builds a new object holding selected whole splines; optionally moves them.
    The original is unchanged for Copy mode; Move deletes only after clone verifies.
    */
    function detachToObject copy_mode =
    (
        local target_node = getNodeForLevel 3
        local operation_ok = false
        if target_node != undefined then
        (
            local selected_ids = getSplineSelection target_node
            local original_count = numSplines target_node
            local detached_node = copy target_node
            detached_node.name = uniqueName (target_node.name + "_Detached")
            local isolate_ok = true
            try
            (
                for spline_index = original_count to 1 by -1 do
                (
                    if findItem selected_ids spline_index == 0 then
                    (
                        deleteSpline detached_node spline_index
                    )
                )
                updateShape detached_node
                isolate_ok = (numSplines detached_node == selected_ids.count)
                if not isolate_ok then
                (
                    format "Spline Editor | Detach copy mismatch node:% expected:% actual:%.\n" target_node.name selected_ids.count (numSplines detached_node)
                )
                if isolate_ok and (not copy_mode) then
                (
                    for selected_index = selected_ids.count to 1 by -1 do
                    (
                        deleteSpline target_node selected_ids[selected_index]
                    )
                    updateShape target_node
                    isolate_ok = (numSplines target_node == original_count - selected_ids.count)
                    if not isolate_ok then
                    (
                        format "Spline Editor | Detach move mismatch node:% expected:% actual:%.\n" target_node.name (original_count - selected_ids.count) (numSplines target_node)
                    )
                )
                operation_ok = isolate_ok
            )
            catch
            (
                format "Spline Editor | Detach object failed node:% copy:% error:%.\n" target_node.name copy_mode (getCurrentException())
            )
            if not operation_ok then
            (
                format "Spline Editor | Detach object incomplete for %. New object removed; use Undo if source was changed.\n" target_node.name
                delete detached_node
            )
            if operation_ok then
            (
                select detached_node
            )
        )
        operation_ok
        -- return
    ),

    /*
    Attaches all selected Editable Spline objects to the first selected node.
    Original sources are deleted only if each add operation is verified.
    */
    function attachSelectedObjects =
    (
        local operation_ok = false
        local selected_nodes = selection as array
        if selected_nodes.count < 2 then
        (
            format "Spline Editor | Attach Selected requires 2+ Editable Spline objects, got %.\n" selected_nodes.count
        )
        else
        (
            local all_valid = true
            for shape_node in selected_nodes do
            (
                if not isValidNode shape_node or classOf shape_node.baseObject != SplineShape then
                (
                    format "Spline Editor | Attach Selected requires Editable Spline nodes, invalid node:%.\n" shape_node
                    all_valid = false
                )
            )
            if all_valid then
            (
                local target_node = selected_nodes[1]
                local attached_count = 0
                try
                (
                    for selected_index = 2 to selected_nodes.count do
                    (
                        local source_node = selected_nodes[selected_index]
                        local before_count = numSplines target_node
                        addAndWeld target_node source_node 0.0
                        updateShape target_node
                        local after_count = numSplines target_node
                        if after_count <= before_count then
                        (
                            format "Spline Editor | Attach failed target:% source:% before:% after:%. Original source preserved.\n" target_node.name source_node.name before_count after_count
                        )
                        else
                        (
                            attached_count += 1
                        )
                    )
                    if attached_count == selected_nodes.count - 1 then
                    (
                        for selected_index = 2 to selected_nodes.count do
                        (
                            delete selected_nodes[selected_index]
                        )
                        select target_node
                        operation_ok = true
                    )
                    else
                    (
                        format "Spline Editor | Partial attach on '%': %/% sources; originals retained. Undo before retry.\n" target_node.name attached_count (selected_nodes.count - 1)
                    )
                )
                catch
                (
                    format "Spline Editor | Attach Selected exception target:% attached:%/% error:%. Undo partial changes before retry.\n" target_node.name attached_count (selected_nodes.count - 1) (getCurrentException())
                )
            )
        )
        operation_ok
        -- return
    ),

    /*
    Assigns sequential 1-based Material IDs to selected or all spline curves.
    Each segment of the same spline receives the same Material ID.
    */
    function assignSplineMaterialIDs all_splines:false =
    (
        local target_node = getTargetNode require_level:false
        local operation_ok = false
        if target_node != undefined then
        (
            local chosen_splines = #()
            if all_splines then
            (
                chosen_splines = for spline_index = 1 to (numSplines target_node) collect spline_index
            )
            else
            (
                chosen_splines = getSplineSelection target_node
            )
            if not all_splines and subObjectLevel != 3 then
            (
                format "Spline Editor | Selected-splines ID assignment requires Spline level 3; actual %.\n" subObjectLevel
            )
            else if chosen_splines.count == 0 then
            (
                format "Spline Editor | Material ID: no selected splines on '%'.\n" target_node.name
            )
            else if chosen_splines.count > 65535 then
            (
                format "Spline Editor | Material ID: too many splines (%), max 65535.\n" chosen_splines.count
            )
            else
            (
                operation_ok = true
                for sequence_index = 1 to chosen_splines.count do
                (
                    local spline_index = chosen_splines[sequence_index]
                    for segment_index = 1 to (numSegments target_node spline_index) do
                    (
                        setMaterialID target_node spline_index segment_index sequence_index
                        local actual_id = getMaterialID target_node spline_index segment_index
                        if actual_id != sequence_index then
                        (
                            format "Spline Editor | Material ID mismatch node:% spline:% segment:% expected:% actual:%.\n" target_node.name spline_index segment_index sequence_index actual_id
                            operation_ok = false
                        )
                    )
                )
                updateShape target_node
            )
        )
        operation_ok
        -- return
    ),

    on create do
    (
    )
)

global SplineEditor
SplineEditor = SplineEditor_v()
