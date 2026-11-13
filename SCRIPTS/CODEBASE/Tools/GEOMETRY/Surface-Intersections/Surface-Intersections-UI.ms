/*
Surface-Intersections-UI
File version: 0.71 | Project version: 1.01
Frontend source-priority dialog with optional mouse-release SMART updates.
Crash recovery: single managed editor; runtime UI cloning is disabled.
Loads tool-local helper forks; does not open the dialog when fileIn'd.
*/


global si_project_version
global si_surface_intersections_directory
global si_surface_intersections_main_path
global SurfaceIntersections


global si_ui_file_version = "0.71"
global si_ui_project_version = "1.01"
global si_ui_directory = getFilenamePath (getSourceFileName())
global si_ui_ini_path = si_ui_directory + "Surface-Intersections-UI.ini"
global si_ui_ini_section = "UI"
global si_ui_source_nodes
global si_ui_clip_modes
global si_ui_view_source_indices = #()
global si_ui_view_result_nodes = #()
global si_ui_view_slice_mods = #()
global si_ui_context_ctrl_pressed = false
global si_ui_context_item_id = 0
global si_ui_tree_context_menu = undefined
global si_ui_tree_remove_menu_item = undefined
global si_ui_tree_remove_result_menu_item = undefined
global si_ui_tree_add_menu_item = undefined
global si_ui_context_source_nodes = #()

/* Preserve the ordered source list and paired kept-side modes when reloading the UI. */
if si_ui_source_nodes == undefined then
(
    si_ui_source_nodes = #()
)
if si_ui_clip_modes == undefined then
(
    si_ui_clip_modes = #()
)
global si_ui_position_precision_mm = 0.1
global si_ui_last_mode = #manual
global si_ui_intersection_mode = #poly
global si_ui_delete_trimmed = true
global si_ui_only_final_result = true
global si_ui_symmetry_enabled = false
global si_ui_symmetry_axis_mask = 1
global si_ui_loading_settings = false
global si_ui_syncing_controls = false
global si_ui_smart_enabled = false
/* Clean up old UI-owned monitors when this script is reloaded in the same Max session. */
global si_ui_smart_callback
if si_ui_smart_callback != undefined then
(
    si_ui_smart_callback = undefined
    gc light:true
)
global si_ui_smart_timer
if si_ui_smart_timer != undefined then
(
    try (si_ui_smart_timer.Stop(); si_ui_smart_timer.Dispose()) catch ()
    si_ui_smart_timer = undefined
)
global si_ui_smart_snapshots = #()
global si_ui_smart_pending_roots = #()
global si_ui_smart_seen_events = false
global si_ui_smart_busy = false
/* Relative slider drag values are intentionally transient; the actual quaternion is on the Slice gizmo. */
global si_ui_slice_drag_values = #(0.0, 0.0, 0.0)
global si_ui_slice_active_mod = undefined
global si_ui_slice_resetting = false


if si_project_version == undefined then
(
    si_project_version = si_ui_project_version
)
else if (si_project_version as float) < (si_ui_project_version as float) then
(
    si_project_version = si_ui_project_version
)


global si_ui_title = "Surface Intersections " + (si_project_version as string)


/*
Loads helper forks packaged inside the Surface-Intersections tool folder.
No shared Codebase/UI files are required at runtime.
*/
function siUiLoadFramework =
(
    local framework_directory = si_ui_directory + "Surface-Intersections-UI\\"
    local helper_files = #("IniSettings.ms", "RolloutState.ms", "SIRegisteredDialogOffset.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms")
    local ready = true


    for helper_name in helper_files while ready do
    (
        local helper_path = framework_directory + helper_name
        if doesFileExist helper_path then
        (
            try
            (
                fileIn helper_path
            )
            catch
            (
                format "SI UI FRAMEWORK FAILED | path:% | error:%\n" helper_path (getCurrentException())
                ready = false
            )
        )
        else
        (
            format "SI UI FRAMEWORK FAILED | Missing shared helper: %\n" helper_path
            ready = false
        )
    )


    ready
    -- return
)


global si_ui_framework_ready = siUiLoadFramework()


/* Node-owned setup: real references survive source renames and scene saves. */
global si_ui_bound_result
global si_ui_had_binding = false
global si_ui_result_tooltip
global si_result_setup_definition = attributes SurfaceIntersectionsSetup version:1 attribID:#(0x61274a39, 0x29b570e1)
(
    parameters setup
    (
        schema_version type:#integer default:1
        draft_sources type:#nodeTab tabSize:0 tabSizeVariable:true
        draft_sides type:#stringTab tabSize:0 tabSizeVariable:true
        applied_sources type:#nodeTab tabSize:0 tabSizeVariable:true
        applied_sides type:#stringTab tabSize:0 tabSizeVariable:true
        precision_mm type:#float default:0.01
        applied_precision_mm type:#float default:0.01
        priority_clipping type:#boolean default:true
        intersection_mode type:#string default:"poly"
        update_mode type:#string default:"manual"
        requested_mode type:#string default:"manual"
    )
)

global si_ui_tree_nodes = #()
global si_ui_selected_id = 0
global si_ui_selected_ids = #()
global si_ui_anchor_id = 0
global si_ui_visible_ids = #()
global si_ui_tree_mouse_down = false
global si_ui_selecting_scene = false
global siUiSyncSceneSelection
callbacks.removeScripts id:#siSurfaceSelectionUi
global siUiRefreshRows
global siUiPersistSettings
global siUiStoreObjectSetup
global siUiLoadSettings
global siUiLayout
global siUiBindResult
global siUiGetGenerateAction
global siUiUpdateGenerateState
global siUiSyncSymmetryControls
global siUiApplySymmetryControls
global siSurfaceIntersectionsRollout

/*
Recognizes this tool's persisted marker values after Max decodes numeric strings.
*/
function siUiHasMarker target_node marker_name =
(
    local marker_value = if isValidNode target_node then getUserProp target_node marker_name else undefined
    marker_value == 1 or marker_value == "1" or marker_value == true
    -- return
)

/*
Finds a catalog by its identity on a selected result, or accepts the catalog itself.
*/
function siUiFindCatalog target_node =
(
    local found = undefined
    if isValidNode target_node then
    (
        if siUiHasMarker target_node "SI_HierarchyCatalog" then found = target_node
        else
        (
            local graph_key = getUserProp target_node "SI_HierarchyKey"
            if graph_key != undefined then
            (
                for candidate in ($* as array) while found == undefined do
                (
                    if (siUiHasMarker candidate "SI_HierarchyCatalog") and (getUserProp candidate "SI_HierarchyKey") == graph_key then found = candidate
                )
            )
        )
    )
    found
    -- return
)

/*
Keeps the legacy source list as a view of original leaves for Debug and migration.
*/
function siUiSyncOriginalSources =
(
    local reachable = #()
    for item_id in siHierarchy.root_ids do siHierarchy.collectIds item_id reachable
    si_ui_source_nodes = for item_id in reachable where siHierarchy.items[item_id].kind == #source and isValidNode siHierarchy.items[item_id].scene_node collect siHierarchy.items[item_id].scene_node
    si_ui_clip_modes = for item_id in reachable where siHierarchy.items[item_id].kind == #source and isValidNode siHierarchy.items[item_id].scene_node collect siHierarchy.items[item_id].keep_mode
    true
    -- return
)

/*
Stores the complete forest; no original source receives setup attributes.
*/
function siUiStoreObjectSetup =
(
    if not si_ui_loading_settings then siHierarchy.saveCatalog() else false
    -- return
)

/*
Restores a saved hierarchy or migrates a legacy result into one explicit group.
*/
function siUiBindResult target_node save_current:true =
(
    local loaded = false
    local catalog_node = siUiFindCatalog target_node
    if isValidNode catalog_node then loaded = siHierarchy.loadCatalog catalog_node
    else if isValidNode target_node then
    (
        local controller_node = target_node
        local owner_key = getUserProp target_node "SI_ProcessOwner"
        if owner_key != undefined then
        (
            for candidate in ($* as array) where ((getHandleByAnim candidate) as string) == (owner_key as string) do controller_node = candidate
        )
        local old_setup = custAttributes.get controller_node si_result_setup_definition baseObject:false
        if old_setup != undefined then
        (
            local migrated = SIHierarchy_v()
            migrated.addSources (old_setup.applied_sources as array)
            if migrated.root_ids.count >= 2 then
            (
                local group_id = migrated.groupRoots (copy migrated.root_ids #noMap)
                migrated.items[group_id].controller_node = controller_node
                local engine_value = migrated.getEngine group_id
                migrated.items[group_id].scene_node = engine_value.trimmed_result_node
                migrated.items[group_id].precision_mm = old_setup.applied_precision_mm
                migrated.items[group_id].delete_trimmed = (getUserProp controller_node "SI_DeleteTrimmed") != "false"
                migrated.latest_id = group_id
                siHierarchy = migrated
                loaded = true
            )
        )
    )
    if loaded then
    (
        si_ui_selected_id = siHierarchy.latest_id
        si_ui_selected_ids = if si_ui_selected_id > 0 then #(si_ui_selected_id) else #()
        si_ui_anchor_id = si_ui_selected_id
        siUiSyncOriginalSources()
    )
    loaded
    -- return
)

/*
Reads persistent project options without generating or rebuilding dependencies.
*/
function siUiLoadSettings =
(
    si_ui_loading_settings = true
    local precision_text = IniSettings.getString si_ui_ini_path si_ui_ini_section "Precision" default_value:"0.1"
    si_ui_position_precision_mm = case precision_text of
    (
        "1": 1.0
        "1.0": 1.0
        "0.1": 0.1
        default: 0.1
    )
    siSurfaceIntersectionsRollout.ddlPrecision.selection = if si_ui_position_precision_mm == 1.0 then 1 else if si_ui_position_precision_mm == 0.1 then 2 else 3
    si_ui_delete_trimmed = (IniSettings.getString si_ui_ini_path si_ui_ini_section "DeleteTrimmed" default_value:"true") != "false"
    si_ui_only_final_result = (IniSettings.getString si_ui_ini_path si_ui_ini_section "OnlyFinalResult" default_value:"true") != "false"
    si_ui_symmetry_enabled = (IniSettings.getString si_ui_ini_path si_ui_ini_section "SymmetryEnabled" default_value:"false") == "true"
    si_ui_smart_enabled = (IniSettings.getString si_ui_ini_path si_ui_ini_section "SmartTransformEnabled" default_value:"false") == "true"
    si_ui_last_mode = if si_ui_smart_enabled then #smart else #manual
    local saved_mask = IniSettings.getString si_ui_ini_path si_ui_ini_section "SymmetryMask" default_value:"1"
    si_ui_symmetry_axis_mask = saved_mask as integer
    if si_ui_symmetry_axis_mask == undefined or si_ui_symmetry_axis_mask < 0 or si_ui_symmetry_axis_mask > 7 then si_ui_symmetry_axis_mask = 1
    siSurfaceIntersectionsRollout.chkDeleteTrimmed.checked = si_ui_delete_trimmed
    siSurfaceIntersectionsRollout.chkOnlyFinalResult.checked = si_ui_only_final_result
    siSurfaceIntersectionsRollout.chkSymmetry.checked = si_ui_symmetry_enabled
    siSurfaceIntersectionsRollout.chkSmartUpdate.checked = si_ui_smart_enabled
    siSurfaceIntersectionsRollout.chkSymmetryX.checked = (bit.and si_ui_symmetry_axis_mask 1) != 0
    siSurfaceIntersectionsRollout.chkSymmetryY.checked = (bit.and si_ui_symmetry_axis_mask 2) != 0
    siSurfaceIntersectionsRollout.chkSymmetryZ.checked = (bit.and si_ui_symmetry_axis_mask 4) != 0
    si_ui_loading_settings = false
    true
    -- return
)

/*
Persists options and the ordered forest after deliberate UI edits.
*/
function siUiPersistSettings =
(
    if not si_ui_loading_settings then
    (
        IniSettings.setString si_ui_ini_path si_ui_ini_section "Precision" (si_ui_position_precision_mm as string)
        IniSettings.setString si_ui_ini_path si_ui_ini_section "DeleteTrimmed" (si_ui_delete_trimmed as string)
        IniSettings.setString si_ui_ini_path si_ui_ini_section "OnlyFinalResult" (si_ui_only_final_result as string)
        IniSettings.setString si_ui_ini_path si_ui_ini_section "SymmetryEnabled" (si_ui_symmetry_enabled as string)
        IniSettings.setString si_ui_ini_path si_ui_ini_section "SymmetryMask" (si_ui_symmetry_axis_mask as string)
        IniSettings.setString si_ui_ini_path si_ui_ini_section "SmartTransformEnabled" (si_ui_smart_enabled as string)
        siHierarchy.saveCatalog()
    )
    true
    -- return
)

/*
Returns a vivid, repeatable candidate color; coprime channel periods avoid repeats.
Result nodes are assigned only once and their wirecolors remain scene-persistent.
*/
function siUiCandidateResultColor candidate_index =
(
    color (80 + (mod (candidate_index * 71) 149)) (80 + (mod (candidate_index * 89) 151)) (80 + (mod (candidate_index * 113) 157))
    -- return
)

/*
Assigns a unique wirecolor only to a new result; never changes original sources.
Scans existing tool-colored outputs across all saved hierarchies for collisions.
*/
function siUiEnsureResultWireColor result_node =
(
    if not (isValidNode result_node) then return false
    if siUiHasMarker result_node "SI_HierarchyResultColor" then return true

    local occupied_colors = #()
    for scene_node in ($* as array) do
    (
        if scene_node != result_node and (siUiHasMarker scene_node "SI_HierarchyResultColor") then
        (
            appendIfUnique occupied_colors scene_node.wirecolor
        )
    )
    local color_index = 1
    local chosen_color = siUiCandidateResultColor color_index
    while (findItem occupied_colors chosen_color) > 0 and color_index < 100000 do
    (
        color_index += 1
        chosen_color = siUiCandidateResultColor color_index
    )
    if (findItem occupied_colors chosen_color) > 0 then
    (
        format "SI UI COLOR FAILED | No unique color available for %\n" result_node.name
        return false
    )
    result_node.wirecolor = chosen_color
    setUserProp result_node "SI_HierarchyResultColor" "1"
    true
    -- return
)

/*
Returns a valid reachable tree-row ID, including group descendants.
Detached, invalid, or deleted items are excluded from the multiselection model.
*/
function siUiIsVisibleTreeId item_id =
(
    item_id > 0 and item_id <= siHierarchy.items.count and (findItem si_ui_visible_ids item_id) > 0
    -- return
)

/*
Highlights every selected row while leaving result label colors unchanged.
Native focus stays on the last selected row for keyboard navigation.
*/
function siUiPaintTreeSelection =
(
    local tree_control = siSurfaceIntersectionsRollout.treeSources
    local selected_background = (dotNetClass "System.Drawing.Color").FromArgb 62 80 112
    local prior_sync = si_ui_syncing_controls
    si_ui_syncing_controls = true
    for item_id in si_ui_visible_ids do
    (
        local tree_node = si_ui_tree_nodes[item_id]
        if tree_node != undefined then
        (
            tree_node.BackColor = if (findItem si_ui_selected_ids item_id) > 0 then selected_background else tree_control.BackColor
        )
    )
    if siUiIsVisibleTreeId si_ui_selected_id then tree_control.SelectedNode = si_ui_tree_nodes[si_ui_selected_id]
    else tree_control.SelectedNode = undefined
    si_ui_syncing_controls = prior_sync
    true
    -- return
)

/*
Returns the scene-target IDs for highlighted rows, expanding all nested parents.
Native group helpers are containers, so only their descendants are selected.
*/
function siUiGetSceneSelectionIds selected_ids hierarchy_value:siHierarchy visible_ids:si_ui_visible_ids =
(
    local target_ids = #()
    for item_id in selected_ids do
    (
        if item_id > 0 and item_id <= hierarchy_value.items.count and (findItem visible_ids item_id) > 0 then
        (
            local branch_ids = #()
            local item_value = hierarchy_value.items[item_id]
            if item_value.child_ids.count > 0 then hierarchy_value.collectIds item_id branch_ids
            else append branch_ids item_id

            for branch_id in branch_ids do
            (
                if branch_id > 0 and branch_id <= hierarchy_value.items.count and (findItem visible_ids branch_id) > 0 then
                (
                    if hierarchy_value.items[branch_id].kind != #scene_group then appendIfUnique target_ids branch_id
                )
            )
        )
    )
    target_ids
    -- return
)

/*
Selects highlighted leaf nodes, complete generated-result branches and native group members.
Only scene selection changes; source identity, hierarchy and visibility stay untouched.
*/
function siUiSelectTreeObjects =
(
    local scene_nodes = #()
    local target_ids = siUiGetSceneSelectionIds si_ui_selected_ids
    for item_id in target_ids do
    (
        local target_node = siHierarchy.items[item_id].scene_node
        if isValidNode target_node then appendIfUnique scene_nodes target_node
    )
    local prior_selecting = si_ui_selecting_scene
    si_ui_selecting_scene = true
    try
    (
        if scene_nodes.count > 0 then select scene_nodes else clearSelection()
    )
    catch
    (
        si_ui_selecting_scene = prior_selecting
        format "SI TREE SELECTION FAILED | %\n" (getCurrentException())
        throw()
    )
    si_ui_selecting_scene = prior_selecting
    scene_nodes.count
    -- return
)

/*
Normalizes selected hierarchy IDs to the highest selected ancestors.
Scene-sync and Generate reuse this rule without changing the actual TreeView highlights.
*/
function siUiNormalizeSceneSelection selected_ids hierarchy_value:siHierarchy =
(
    local normalized_ids = #()
    for item_id in selected_ids do
    (
        local parent_id = hierarchy_value.getParentId item_id
        local has_selected_ancestor = false
        while parent_id > 0 and not has_selected_ancestor do
        (
            has_selected_ancestor = (findItem selected_ids parent_id) > 0
            if not has_selected_ancestor then parent_id = hierarchy_value.getParentId parent_id
        )
        if not has_selected_ancestor then appendIfUnique normalized_ids item_id
    )
    normalized_ids
    -- return
)

/*
Resolves generation from the highest selected top-level inputs.
Empty selection groups all existing roots, including independent generated result groups.
*/
function siUiGetGenerateAction hierarchy_value:siHierarchy selected_ids:si_ui_selected_ids =
(
    local action_kind = #invalid
    local input_ids = #()
    local message_value = "Highlight two top-level inputs or clear tree selection to generate the next level."
    local requested_ids = siUiNormalizeSceneSelection selected_ids hierarchy_value:hierarchy_value
    if requested_ids.count >= 2 then
    (
        input_ids = for item_id in hierarchy_value.root_ids where (findItem requested_ids item_id) > 0 collect item_id
        if input_ids.count == requested_ids.count then action_kind = #group
        else
        (
            input_ids = #()
            message_value = "Generate requires top-level inputs; nested rows must belong to an explicitly selected parent."
        )
    )
    else if requested_ids.count == 1 and (findItem hierarchy_value.root_ids requested_ids[1]) > 0 and hierarchy_value.items[requested_ids[1]].kind == #scene_group and (hierarchy_value.countSceneGroupSurfaces requested_ids[1]) >= 2 then
    (
        action_kind = #group
        input_ids = #(requested_ids[1])
    )
    else if requested_ids.count == 0 and hierarchy_value.root_ids.count == 1 and hierarchy_value.items[hierarchy_value.root_ids[1]].kind == #scene_group and (hierarchy_value.countSceneGroupSurfaces hierarchy_value.root_ids[1]) >= 2 then
    (
        action_kind = #group
        input_ids = #(hierarchy_value.root_ids[1])
    )
    else if hierarchy_value.root_ids.count >= 2 and (requested_ids.count == 0 or (requested_ids.count == 1 and (findItem hierarchy_value.root_ids requested_ids[1]) > 0)) then
    (
        local has_generated_root = false
        for root_id in hierarchy_value.root_ids while not has_generated_root do
        (
            local item_value = hierarchy_value.items[root_id]
            has_generated_root = item_value.kind == #group
        )
        /* Zero highlights deliberately combine current mid-result roots into a new parent. */
        if requested_ids.count == 0 or not has_generated_root then
        (
            input_ids = copy hierarchy_value.root_ids #noMap
            action_kind = #group
        )
    )
    #(action_kind,input_ids,message_value)
    -- return
)

/*
Resolves RMB GENERATE independently of highlighted tree rows.
Two or more top-level roots become one final operation; an existing sole result rebuilds in place.
*/
function siUiGetFinalGenerateAction hierarchy_value:siHierarchy =
(
    local action_kind = #invalid
    local input_ids = #()
    local message_value = "FINAL requires two or more top-level inputs, or an existing top-level result."
    if hierarchy_value != undefined then
    (
        if hierarchy_value.root_ids.count >= 2 then
        (
            action_kind = #wrap
            input_ids = copy hierarchy_value.root_ids #noMap
            message_value = "Intersect all top-level group results and other root inputs."
        )
        else if hierarchy_value.root_ids.count == 1 then
        (
            local root_id = hierarchy_value.root_ids[1]
            if root_id >= 1 and root_id <= hierarchy_value.items.count then
            (
                local root_item = hierarchy_value.items[root_id]
                if root_item.kind == #group then
                (
                    action_kind = #update
                    input_ids = #(root_id)
                    message_value = "Rebuild the existing final result in place."
                )
                else if root_item.kind == #scene_group and (hierarchy_value.countSceneGroupSurfaces root_id) >= 2 then
                (
                    action_kind = #wrap
                    input_ids = #(root_id)
                    message_value = "Generate the final result from the native scene group."
                )
            )
        )
    )
    #(action_kind,input_ids,message_value)
    -- return
)

/*
Resolves selected result groups or all roots with an empty highlight.
A selected child addresses its nearest generated parent result.
*/
function siUiGetUpdateTargets =
(
    local candidates = #()
    local reachable_ids = #()
    for root_id in siHierarchy.root_ids do siHierarchy.collectIds root_id reachable_ids
    for item_id in si_ui_selected_ids do
    (
        if (findItem reachable_ids item_id) > 0 then
        (
            local target_id = item_id
            while target_id > 0 and siHierarchy.items[target_id].kind != #group do
            (
                target_id = siHierarchy.getParentId target_id
            )
            if target_id > 0 then appendIfUnique candidates target_id
        )
    )
    if candidates.count == 0 and si_ui_selected_ids.count == 0 then
    (
        candidates = for root_id in siHierarchy.root_ids where siHierarchy.items[root_id].kind == #group collect root_id
    )
    local update_ids = #()
    for item_id in candidates do
    (
        local parent_id = siHierarchy.getParentId item_id
        local covered = false
        while parent_id > 0 and not covered do
        (
            covered = (findItem candidates parent_id) > 0
            if not covered then parent_id = siHierarchy.getParentId parent_id
        )
        if not covered then append update_ids item_id
    )
    update_ids
    -- return
)

/*
Keeps Generate and Update independently enabled according to their exact targets.
*/
function siUiUpdateGenerateState =
(
    local action_data = siUiGetGenerateAction()
    local final_action = siUiGetFinalGenerateAction()
    local update_ids = siUiGetUpdateTargets()
    /* Keep RMB Final available even when the current highlight makes LMB Generate invalid. */
    siSurfaceIntersectionsRollout.btnGenerate.enabled = action_data[1] == #group or final_action[1] != #invalid
    siSurfaceIntersectionsRollout.btnUpdate.enabled = update_ids.count > 0
    siSurfaceIntersectionsRollout.lblStatus.text = if action_data[1] == #group then
    (
        (action_data[2].count as string) + " inputs ready to generate"
    )
    else if update_ids.count > 0 then
    (
        (update_ids.count as string) + " result group(s) ready to update"
    )
    else if final_action[1] != #invalid then final_action[3]
    else action_data[3]
    action_data[1] == #group or final_action[1] != #invalid or update_ids.count > 0
    -- return
)

/*
Updates the focused item's editable options without changing checked source rows.
The selection array controls viewport selection; the focus ID controls editing.
*/
function siUiSyncTreeFocus =
(
    local focus_id = si_ui_selected_id
    local valid_focus = siUiIsVisibleTreeId focus_id
    local prior_sync = si_ui_syncing_controls
    si_ui_syncing_controls = true
    if valid_focus then
    (
        local item_value = siHierarchy.items[focus_id]
        siSurfaceIntersectionsRollout.ddlSide.selection = findItem #(#auto,#negative,#positive,#off) item_value.keep_mode
        if item_value.kind == #group then
        (
            si_ui_position_precision_mm = item_value.precision_mm
            si_ui_delete_trimmed = item_value.delete_trimmed
            siSurfaceIntersectionsRollout.ddlPrecision.selection = if item_value.precision_mm == 1.0 then 1 else if item_value.precision_mm == 0.1 then 2 else 3
            siSurfaceIntersectionsRollout.chkDeleteTrimmed.checked = item_value.delete_trimmed
        )
        siSurfaceIntersectionsRollout.btnResult.Text = if isValidNode item_value.scene_node then item_value.scene_node.name else "Missing object"
    )
    else siSurfaceIntersectionsRollout.btnResult.Text = "Right-click here to load a saved hierarchy"
    siUiUpdateGenerateState()
    siUiSyncSymmetryControls()
    siSurfaceIntersectionsRollout.ddlSide.enabled = valid_focus
    si_ui_syncing_controls = prior_sync
    true
    -- return
)

/*
Mirrors selected scene nodes to the highest matching hierarchy rows.
Prevents native group/member co-selection from disabling valid Generate inputs.
*/
function siUiSyncSceneSelection =
(
    if not si_ui_selecting_scene and not si_ui_syncing_controls and siSurfaceIntersectionsRollout != undefined and siSurfaceIntersectionsRollout.isDisplayed and si_ui_tree_nodes.count == siHierarchy.items.count then
    (
        local scene_nodes = selection as array
        local selected_ids = #()
        for item_id in si_ui_visible_ids do
        (
            local target_node = siHierarchy.items[item_id].scene_node
            if isValidNode target_node and (findItem scene_nodes target_node) > 0 then append selected_ids item_id
        )
        selected_ids = siUiNormalizeSceneSelection selected_ids
        local selection_changed = selected_ids.count != si_ui_selected_ids.count
        for item_id in selected_ids while not selection_changed do selection_changed = (findItem si_ui_selected_ids item_id) == 0
        if selection_changed then
        (
            si_ui_selected_ids = selected_ids
            if (findItem selected_ids si_ui_selected_id) == 0 then si_ui_selected_id = if selected_ids.count > 0 then selected_ids[selected_ids.count] else 0
            si_ui_anchor_id = si_ui_selected_id
            siUiPaintTreeSelection()
            siUiSyncTreeFocus()
            if si_ui_selected_id > 0 then si_ui_tree_nodes[si_ui_selected_id].EnsureVisible()
        )
    )
    true
    -- return
)

/*
Returns the clicked hierarchy item and all listed descendants, including collapsed rows.
The hierarchy model determines membership; expansion and checkbox states are ignored.
*/
function siUiGetTreeBranchIds item_id =
(
    local branch_ids = #()
    if siUiIsVisibleTreeId item_id then
    (
        local collected_ids = #()
        if siHierarchy.collectIds item_id collected_ids then
        (
            for descendant_id in collected_ids do
            (
                if siUiIsVisibleTreeId descendant_id then appendIfUnique branch_ids descendant_id
            )
        )
    )
    branch_ids
    -- return
)

/*
Adds a complete hierarchy branch, or removes it when every branch row was selected.
Other selected branches remain selected; a source leaf retains single-row Ctrl-toggle.
*/
function siUiToggleTreeBranch selected_ids item_id =
(
    local updated_ids = copy selected_ids #noMap
    local branch_ids = siUiGetTreeBranchIds item_id
    local fully_selected = branch_ids.count > 0
    for descendant_id in branch_ids while fully_selected do
    (
        fully_selected = (findItem updated_ids descendant_id) > 0
    )
    for descendant_id in branch_ids do
    (
        if fully_selected then
        (
            local existing_index = findItem updated_ids descendant_id
            if existing_index > 0 then deleteItem updated_ids existing_index
        )
        else appendIfUnique updated_ids descendant_id
    )
    updated_ids
    -- return
)

/*
Replaces the row highlight on LMB, or toggles just that row on CTRL+LMB.
Scene hierarchy expansion is separate from the highlighted TreeView rows.
*/
function siUiComputeTreeClickIds selected_ids item_id ctrl_pressed:false =
(
    local updated_ids = if ctrl_pressed then (copy selected_ids #noMap) else #()
    local existing_index = findItem updated_ids item_id
    if ctrl_pressed and existing_index > 0 then deleteItem updated_ids existing_index
    else appendIfUnique updated_ids item_id
    updated_ids
    -- return
)

/*
Updates one TreeView item highlight and mirrors the corresponding scene selection.
No branch rows are implicitly highlighted; CTRL+LMB toggles just the clicked item.
*/
function siUiChooseTreeRow item_id ctrl_pressed:false shift_pressed:false =
(
    if not (siUiIsVisibleTreeId item_id) then return false
    si_ui_selected_ids = siUiComputeTreeClickIds si_ui_selected_ids item_id ctrl_pressed:ctrl_pressed
    si_ui_anchor_id = item_id
    si_ui_selected_id = if (findItem si_ui_selected_ids item_id) > 0 then item_id else (if si_ui_selected_ids.count > 0 then si_ui_selected_ids[si_ui_selected_ids.count] else 0)
    siUiPaintTreeSelection()
    siUiSyncTreeFocus()
    siUiSelectTreeObjects()
    true
    -- return
)

/*
Reads actual viewport visibility without changing the source, group head, or result.
A hidden layer/category/frozen display can keep an object invisible despite its node flag.
*/
function siUiNodeIsVisible target_node =
(
    if isValidNode target_node then (not target_node.isHiddenInVpt) else false
    -- return
)

/*
Synchronizes tree checkboxes from actual viewport visibility.
This never generates geometry, changes hierarchy membership, or selects nodes.
*/
function siUiSyncVisibilityChecks =
(
    local previous_sync = si_ui_syncing_controls
    if siSurfaceIntersectionsRollout != undefined and siSurfaceIntersectionsRollout.isDisplayed then
    (
        si_ui_syncing_controls = true
        for item_id in si_ui_visible_ids do
        (
            if item_id > 0 and item_id <= si_ui_tree_nodes.count then
            (
                local tree_node = si_ui_tree_nodes[item_id]
                if tree_node != undefined then
                (
                    tree_node.Checked = siUiNodeIsVisible siHierarchy.items[item_id].scene_node
                )
            )
        )
        si_ui_syncing_controls = previous_sync
    )
    true
    -- return
)

/*
Collects only clicked/highlighted scene nodes as visibility targets.
Only a closed native 3ds Max group head expands to its actual member hierarchy.
*/
function siUiGetVisibilityTargetIds clicked_id hierarchy_value:siHierarchy selected_ids:si_ui_selected_ids visible_ids:si_ui_visible_ids =
(
    local target_ids = #()
    local requested_ids = if (findItem selected_ids clicked_id) > 0 then (copy selected_ids #noMap) else #(clicked_id)
    for item_id in requested_ids do
    (
        if item_id > 0 and item_id <= hierarchy_value.items.count and (findItem visible_ids item_id) > 0 then
        (
            local item_value = hierarchy_value.items[item_id]
            if item_value.kind == #scene_group and isValidNode item_value.scene_node and isGroupHead item_value.scene_node and not (isOpenGroupHead item_value.scene_node) then
            (
                local descendant_ids = #()
                hierarchy_value.collectIds item_id descendant_ids
                for descendant_id in descendant_ids where (findItem visible_ids descendant_id) > 0 do appendIfUnique target_ids descendant_id
            )
            else appendIfUnique target_ids item_id
        )
    )
    target_ids
    -- return
)

/*
Applies the checkbox state to clicked/highlighted nodes and closed native group members.
Generated result children and other scene layers remain unchanged.
*/
function siUiSetTreeVisibility clicked_id requested_visible =
(
    local changed_count = 0
    local target_ids = siUiGetVisibilityTargetIds clicked_id
    local target_nodes = #()
    for item_id in target_ids do
    (
        local target_node = siHierarchy.items[item_id].scene_node
        if isValidNode target_node then appendIfUnique target_nodes target_node
    )
    undo "Surface Intersections Visibility" on
    (
        for target_node in target_nodes do
        (
            target_node.isNodeHidden = not requested_visible
            changed_count += 1
            if requested_visible and not (siUiNodeIsVisible target_node) then
            (
                format "SI VISIBILITY | Node remains invisible due to its layer, category or display state: %\n" target_node.name
            )
        )
    )
    siUiSyncVisibilityChecks()
    changed_count
    -- return
)

/*
Returns a native scene-group caption with brackets only while its Max group is open.
Generated result names and their pending markers retain their existing form.
*/
function siUiGetTreeCaption item_id hierarchy_value:siHierarchy =
(
    local item_value = hierarchy_value.items[item_id]
    local caption = if isValidNode item_value.scene_node then item_value.scene_node.name else (if item_value.kind == #group then ("Group " + (item_id as string) + " <missing>") else (if item_value.kind == #scene_group then "<missing group>" else "<missing source>"))
    if item_value.kind == #scene_group and isValidNode item_value.scene_node and (isOpenGroupHead item_value.scene_node) then caption = "[" + caption + "]"
    if item_value.kind == #group and item_value.pending then caption += " *"
    caption
    -- return
)

/*
Returns fixed pink text for native scene-group rows in the TreeView.
Generated intersection-result rows keep their distinct scene wirecolors.
*/
function siUiGetNativeGroupTextColor =
(
    (dotNetClass "System.Drawing.Color").FromArgb 240 118 177
    -- return
)

/*
Fits displayed captions to the visible tree width, including indentation and vertical scrollbar.
Preserves full names in tooltips and keeps the vertical scrollbar enabled.
*/
function siUiFitTreeCaptions =
(
    local tree_control = siSurfaceIntersectionsRollout.treeSources
    local text_renderer = dotNetClass "System.Windows.Forms.TextRenderer"
    local scrollbar_width = (dotNetClass "System.Windows.Forms.SystemInformation").VerticalScrollBarWidth
    local available_client_width = tree_control.ClientSize.Width
    if available_client_width < 1 then available_client_width = tree_control.width
    for item_id in si_ui_visible_ids do
    (
        local tree_node = si_ui_tree_nodes[item_id]
        if tree_node != undefined then
        (
            local full_caption = siUiGetTreeCaption item_id
            local has_brackets = siHierarchy.items[item_id].kind == #scene_group and full_caption.count >= 2 and (substring full_caption 1 1) == "[" and (substring full_caption full_caption.count 1) == "]"
            local caption_body = if has_brackets then (substring full_caption 2 (full_caption.count - 2)) else full_caption
            local reserved_width = ((tree_node.Level + 1) * tree_control.Indent) + scrollbar_width + 38
            local available_text_width = amax 20 (available_client_width - reserved_width)
            local display_caption = full_caption
            if (text_renderer.MeasureText display_caption tree_control.Font).Width > available_text_width then
            (
                local left_count = 0
                local right_count = caption_body.count
                while left_count < right_count do
                (
                    local middle_count = ((left_count + right_count + 1) / 2) as integer
                    local candidate_caption = if has_brackets then ("[" + (substring caption_body 1 middle_count) + "...]") else ((substring caption_body 1 middle_count) + "...")
                    if (text_renderer.MeasureText candidate_caption tree_control.Font).Width <= available_text_width then
                    (
                        left_count = middle_count
                    )
                    else right_count = middle_count - 1
                )
                display_caption = if has_brackets then ("[" + (substring caption_body 1 left_count) + "...]") else ((substring caption_body 1 left_count) + "...")
            )
            tree_node.Text = display_caption
            tree_node.ToolTipText = full_caption
        )
    )
    true
    -- return
)

/*
Builds one .NET tree branch using stable integer IDs in the node Name property.
*/
function siUiAppendTreeNode item_id parent_node =
(
    local item_value = siHierarchy.items[item_id]
    local caption = siUiGetTreeCaption item_id
    local tree_node = dotNetObject "System.Windows.Forms.TreeNode" caption
    append si_ui_visible_ids item_id
    tree_node.Name = item_id as string
    tree_node.Checked = siUiNodeIsVisible item_value.scene_node
    tree_node.ToolTipText = "Checked = visible in viewport. Click the checkbox to show or hide this scene object."
    if item_value.kind == #group and isValidNode item_value.scene_node then
    (
        siUiEnsureResultWireColor item_value.scene_node
        local wire_color = item_value.scene_node.wirecolor
        tree_node.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb (wire_color.r as integer) (wire_color.g as integer) (wire_color.b as integer)
    )
    else if item_value.kind == #group then tree_node.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 100 200 100
    else if item_value.kind == #scene_group then tree_node.ForeColor = siUiGetNativeGroupTextColor()
    else tree_node.ForeColor = (dotNetClass "System.Drawing.Color").Gainsboro
    if parent_node == undefined then siSurfaceIntersectionsRollout.treeSources.Nodes.Add tree_node else parent_node.Nodes.Add tree_node
    si_ui_tree_nodes[item_id] = tree_node
    for child_id in item_value.child_ids do siUiAppendTreeNode child_id tree_node
    tree_node.Expand()
    tree_node
    -- return
)

/*
Refreshes hierarchy presentation only; geometry never regenerates from tree events.
*/
function siUiRefreshRows =
(
    si_ui_syncing_controls = true
    local tree_control = siSurfaceIntersectionsRollout.treeSources
    tree_control.BeginUpdate()
    tree_control.Nodes.Clear()
    si_ui_tree_nodes = #()
    si_ui_tree_nodes.count = siHierarchy.items.count
    si_ui_visible_ids = #()
    for item_id in siHierarchy.root_ids do siUiAppendTreeNode item_id undefined
    siUiFitTreeCaptions()
    siUiSyncVisibilityChecks()
    si_ui_selected_ids = for item_id in si_ui_selected_ids where (siUiIsVisibleTreeId item_id) collect item_id
    if not (siUiIsVisibleTreeId si_ui_selected_id) then si_ui_selected_id = if si_ui_selected_ids.count > 0 then si_ui_selected_ids[si_ui_selected_ids.count] else 0
    if not (siUiIsVisibleTreeId si_ui_anchor_id) then si_ui_anchor_id = si_ui_selected_id
    siUiPaintTreeSelection()
    tree_control.EndUpdate()
    siSurfaceIntersectionsRollout.btnSelectSurfaceResult.enabled = siHierarchy.latest_id > 0 and siHierarchy.latest_id <= siHierarchy.items.count and isValidNode siHierarchy.items[siHierarchy.latest_id].scene_node
    siSurfaceIntersectionsRollout.ddlSide.enabled = si_ui_selected_id > 0
    siSurfaceIntersectionsRollout.lblStatus.text = (siHierarchy.root_ids.count as string) + " top-level items | checkboxes: visibility"
    if si_ui_selected_id > 0 and si_ui_selected_id <= siHierarchy.items.count then
    (
        local item_value = siHierarchy.items[si_ui_selected_id]
        siSurfaceIntersectionsRollout.ddlSide.selection = findItem #(#auto,#negative,#positive,#off) item_value.keep_mode
        if item_value.kind == #group then
        (
            siSurfaceIntersectionsRollout.btnResult.Text = "Group " + (si_ui_selected_id as string) + " | " + (item_value.child_ids.count as string) + " inputs"
        )
        else siSurfaceIntersectionsRollout.btnResult.Text = "Source " + (si_ui_selected_id as string)
    )
    else siSurfaceIntersectionsRollout.btnResult.Text = "Right-click here to load a saved hierarchy"
    siUiSyncOriginalSources()
    siUiUpdateGenerateState()
    if si_ui_smart_enabled and not si_ui_smart_busy and si_ui_smart_callback != undefined then siUiSmartCaptureSources()
    si_ui_syncing_controls = false
    true
    -- return
)

/*
Appends valid original scene selections without adopting generated output as a leaf.
*/
function siUiAppendSelection source_values:(selection as array) =
(
    local added_count = siHierarchy.addSources source_values
    siUiRefreshRows()
    siUiPersistSettings()
    added_count
    -- return
)

/*
Refresh replaces loose source rows while retaining all generated root groups.
*/
function siUiRefreshListFromSelection source_values:(selection as array) =
(
    siHierarchy.root_ids = for item_id in siHierarchy.root_ids where siHierarchy.items[item_id].kind == #group collect item_id
    siHierarchy.addSources source_values
    si_ui_selected_id = 0
    si_ui_selected_ids = #()
    si_ui_anchor_id = 0
    siUiRefreshRows()
    siUiPersistSettings()
    true
    -- return
)

/*
Moves the focused item among its siblings, including a group's child input order.
*/
function siUiMoveSourceWithControl movement ctrl_pressed:false =
(
    if si_ui_selected_id > 0 then siHierarchy.moveItem si_ui_selected_id movement to_boundary:ctrl_pressed
    siUiRefreshRows()
    siUiPersistSettings()
    true
    -- return
)

/*
Prunes selected original source leaves in one postorder pass, collapsing undersized groups.
Returns #(surviving_item_id, was_changed) without altering original scene objects.
*/
function siUiPruneSelectedSources item_id removed_ids =
(
    local item_value = siHierarchy.items[item_id]
    local surviving_id = item_id
    local was_changed = false
    if item_value.kind == #source or item_value.kind == #scene_group and (findItem removed_ids item_id) > 0 then
    (
        if (findItem removed_ids item_id) > 0 then
        (
            surviving_id = 0
            was_changed = true
        )
    )
    else
    (
        local surviving_children = #()
        for child_id in item_value.child_ids do
        (
            local child_result = siUiPruneSelectedSources child_id removed_ids
            if child_result[1] > 0 then append surviving_children child_result[1]
            if child_result[2] then was_changed = true
        )
        local min_children = if item_value.kind == #scene_group then 1 else 2
        if item_value.kind == #group and surviving_children.count == 1 and siHierarchy.items[surviving_children[1]].kind == #scene_group then min_children = 1
        if surviving_children.count < min_children then
        (
            surviving_id = if surviving_children.count == 1 then surviving_children[1] else 0
            was_changed = true
        )
        else if was_changed then
        (
            item_value.child_ids = surviving_children
            item_value.pending = true
        )
    )
    #(surviving_id, was_changed)
    -- return
)

/*
Removes all highlighted source rows together when the clicked row belongs to the selection.
Updates each affected group once and keeps generated scene objects intact.
*/
function siUiRemoveSources item_id:0 =
(
    local removed = false
    local requested_ids = if (findItem si_ui_selected_ids item_id) > 0 then copy si_ui_selected_ids #noMap else #(item_id)
    local removed_ids = #()
    for target_id in requested_ids do
    (
        if siUiIsVisibleTreeId target_id then
        (
            if siHierarchy.items[target_id].kind == #source or siHierarchy.items[target_id].kind == #scene_group then appendIfUnique removed_ids target_id
        )
    )
    if removed_ids.count > 0 then
    (
        local prior_roots = copy siHierarchy.root_ids #noMap
        local prior_latest = siHierarchy.latest_id
        local prior_children = #()
        local prior_pending = #()
        for item_value in siHierarchy.items do
        (
            append prior_children (copy item_value.child_ids #noMap)
            append prior_pending item_value.pending
        )
        local surviving_roots = #()
        for root_id in siHierarchy.root_ids do
        (
            local root_result = siUiPruneSelectedSources root_id removed_ids
            if root_result[1] > 0 then append surviving_roots root_result[1]
        )
        siHierarchy.root_ids = surviving_roots
        local active_ids = #()
        for root_id in siHierarchy.root_ids do siHierarchy.collectIds root_id active_ids
        if (findItem active_ids siHierarchy.latest_id) == 0 then
        (
            siHierarchy.latest_id = 0
            for root_id in siHierarchy.root_ids where siHierarchy.items[root_id].kind == #group do siHierarchy.latest_id = root_id
        )
        if siHierarchy.isValidForest() then
        (
            try
            (
                if not siHierarchy.syncRootSymmetry() then format "SI REMOVE SYMMETRY FAILED | count:%\n" removed_ids.count
            )
            catch
            (
                format "SI REMOVE SYMMETRY FAILED | count:% | error:%\n" removed_ids.count (getCurrentException())
            )
                si_ui_selected_id = 0
            si_ui_selected_ids = #()
            si_ui_anchor_id = 0
            siUiRefreshRows()
            siUiPersistSettings()
            removed = true
            format "SI REMOVE | removed source rows:%\n" removed_ids.count
        )
        else
        (
            format "SI REMOVE FAILED | Invalid hierarchy after pruning: %\n" siHierarchy.last_error
            siHierarchy.root_ids = prior_roots
            siHierarchy.latest_id = prior_latest
            for item_index = 1 to siHierarchy.items.count do
            (
                siHierarchy.items[item_index].child_ids = prior_children[item_index]
                siHierarchy.items[item_index].pending = prior_pending[item_index]
            )
        )
    )
    else format "SI REMOVE FAILED | No source rows available in the selected tree items.\n"
    removed
    -- return
)

/*
Runs the context-menu Remove action for the highlighted source rows or clicked source.
*/
function siUiOnRemoveContextClick sender event_args =
(
    local item_id = si_ui_context_item_id
    si_ui_context_item_id = 0
    si_ui_context_source_nodes = #()
    if item_id > 0 then siUiRemoveSources item_id:item_id else false
    -- return
)

/*
Removes one generated intersection output and its hierarchy wrapper via the backend.
All original source objects, native group heads, and other generated results remain intact.
*/
function siUiRemoveResult item_id =
(
    local removed = false
    if siUiIsVisibleTreeId item_id and siHierarchy.items[item_id].kind == #group then
    (
        if queryBox "Remove the selected intersection result?\n\nIts input surfaces and child results will be retained." title:"Surface Intersections - Remove Result" then
        (
            local parent_id = siHierarchy.getParentId item_id
            local child_ids = copy siHierarchy.items[item_id].child_ids #noMap
            removed = siHierarchy.removeResultItem item_id only_final:si_ui_only_final_result
            if removed then
            (
                si_ui_selected_ids = #()
                si_ui_selected_id = if parent_id > 0 then parent_id else (if child_ids.count > 0 then child_ids[1] else 0)
                if si_ui_selected_id > 0 then si_ui_selected_ids = #(si_ui_selected_id)
                si_ui_anchor_id = si_ui_selected_id
                siUiRefreshRows()
                siUiPersistSettings()
            )
            else
            (
                format "SI REMOVE RESULT FAILED | group:% | %\n" item_id siHierarchy.last_error
                siSurfaceIntersectionsRollout.lblStatus.text = "Remove Result failed: " + siHierarchy.last_error
            )
        )
    )
    removed
    -- return
)

/*
Invokes Remove Result only for the right-clicked generated operation.
An existing multi-row selection never broadens the deletion target.
*/
function siUiOnRemoveResultContextClick sender event_args =
(
    local item_id = si_ui_context_item_id
    si_ui_context_item_id = 0
    si_ui_context_source_nodes = #()
    if item_id > 0 then siUiRemoveResult item_id else false
    -- return
)

/*
Adds selected original scene geometry to the right-clicked result group.
Keeps the existing hierarchy and defers regeneration to UPDATE.
*/
function siUiAddSelectionToGroup group_id source_values:(selection as array) =
(
    local added_count = siHierarchy.addSelectionToGroup group_id source_values
    if added_count > 0 then
    (
        si_ui_selected_id = group_id
        si_ui_selected_ids = #(group_id)
        si_ui_anchor_id = group_id
        siUiRefreshRows()
        siUiPersistSettings()
        format "SI ADD TO GROUP | group:% added:% | Use UPDATE to rebuild.\n" group_id added_count
    )
    else format "SI ADD TO GROUP SKIPPED | group:% | %\n" group_id siHierarchy.last_error
    added_count
    -- return
)

/*
Uses the scene selection captured when the result context menu was opened.
*/
function siUiOnAddSelectionContextClick sender event_args =
(
    local group_id = si_ui_context_item_id
    local source_nodes = copy si_ui_context_source_nodes #noMap
    si_ui_context_item_id = 0
    si_ui_context_source_nodes = #()
    if group_id > 0 then siUiAddSelectionToGroup group_id source_values:source_nodes else 0
    -- return
)

/*
Generates only a new group from checked or highlighted top-level inputs.
On failure, restores the prior hierarchy without keeping a false result.
*/
function siUiGenerate =
(
    local prior_roots = copy siHierarchy.root_ids #noMap
    local prior_count = siHierarchy.items.count
    local group_id = 0
    local action_data = siUiGetGenerateAction()
    if action_data[1] == #group then
    (
        group_id = siHierarchy.groupRoots action_data[2]
        if group_id > 0 then
        (
            siHierarchy.items[group_id].symmetry_enabled = si_ui_symmetry_enabled
            siHierarchy.items[group_id].symmetry_mask = si_ui_symmetry_axis_mask
        )
    )
    else siHierarchy.last_error = action_data[3]
    local generated = undefined
    if group_id > 0 then
    (
        generated = siHierarchy.generateGroup group_id precision_mm:si_ui_position_precision_mm delete_trimmed:si_ui_delete_trimmed only_final:si_ui_only_final_result
    )
    if not (isValidNode generated) and group_id > 0 then
    (
        local failed_item = siHierarchy.items[group_id]
        if failed_item.engine != undefined and isValidNode failed_item.engine.result_node then failed_item.engine.deleteGeneratedResults()
        siHierarchy.root_ids = prior_roots
        siHierarchy.items.count = prior_count
    )
    if isValidNode generated then
    (
        si_ui_selected_id = group_id
        si_ui_selected_ids = #(group_id)
        si_ui_anchor_id = group_id
        SurfaceIntersections = siHierarchy.items[group_id].engine
        si_ui_bound_result = SurfaceIntersections.result_node
        select generated
        siUiPersistSettings()
    )
    siUiRefreshRows()
    if not (isValidNode generated) then
    (
        siSurfaceIntersectionsRollout.lblStatus.text = "Generation failed: " + siHierarchy.last_error
        format "SI GENERATE FAILED | %\n" siHierarchy.last_error
    )
    isValidNode generated
    -- return
)

/*
RMB GENERATE builds one final parent from all top-level inputs, ignoring tree highlights.
Existing sole final result groups regenerate in place; failed new parents restore the prior forest.
*/
function siUiGenerateFinal =
(
    local action_data = siUiGetFinalGenerateAction()
    local operation_kind = action_data[1]
    if operation_kind == #invalid then
    (
        siHierarchy.last_error = action_data[3]
        siSurfaceIntersectionsRollout.lblStatus.text = action_data[3]
        format "SI GENERATE FINAL SKIPPED | %\n" siHierarchy.last_error
        return false
    )

    local prior_roots = copy siHierarchy.root_ids #noMap
    local prior_count = siHierarchy.items.count
    local prior_latest = siHierarchy.latest_id
    local prior_children = for item_value in siHierarchy.items collect (copy item_value.child_ids #noMap)
    local prior_pending = for item_value in siHierarchy.items collect item_value.pending
    local group_id = 0
    local created_new = operation_kind == #wrap
    local generated = undefined
    local precision_value = si_ui_position_precision_mm
    local trim_value = si_ui_delete_trimmed

    if created_new then
    (
        group_id = siHierarchy.groupRoots action_data[2]
        if group_id > 0 then
        (
            siHierarchy.items[group_id].symmetry_enabled = si_ui_symmetry_enabled
            siHierarchy.items[group_id].symmetry_mask = si_ui_symmetry_axis_mask
        )
    )
    else
    (
        group_id = action_data[2][1]
        precision_value = siHierarchy.items[group_id].precision_mm
        trim_value = siHierarchy.items[group_id].delete_trimmed
    )

    if group_id > 0 then
    (
        generated = siHierarchy.generateGroup group_id precision_mm:precision_value delete_trimmed:trim_value only_final:si_ui_only_final_result
    )

    if not (isValidNode generated) and created_new then
    (
        if group_id > 0 then
        (
            local failed_item = siHierarchy.items[group_id]
            if failed_item.engine != undefined and isValidNode failed_item.engine.result_node then
            (
                local cleanup_ok = false
                try
                (
                    cleanup_ok = failed_item.engine.deleteGeneratedResults()
                )
                catch
                (
                    format "SI GENERATE FINAL CLEANUP FAILED | %\n" (getCurrentException())
                )
                if not cleanup_ok then format "SI GENERATE FINAL CLEANUP FAILED | Temporary parent output needs inspection.\n"
            )
        )
        siHierarchy.root_ids = prior_roots
        siHierarchy.items.count = prior_count
        siHierarchy.latest_id = prior_latest
        /* Native group membership may have been re-scanned during the unsuccessful rebuild. */
        for item_index = 1 to prior_count do
        (
            siHierarchy.items[item_index].child_ids = prior_children[item_index]
            siHierarchy.items[item_index].pending = prior_pending[item_index]
        )
        /* A failed parent must not remain in the persisted catalog. */
        if siHierarchy.isValidForest() then siHierarchy.saveCatalog()
    )

    if isValidNode generated then
    (
        si_ui_selected_id = group_id
        si_ui_selected_ids = #(group_id)
        si_ui_anchor_id = group_id
        SurfaceIntersections = siHierarchy.items[group_id].engine
        si_ui_bound_result = SurfaceIntersections.result_node
        local previous_selecting = si_ui_selecting_scene
        si_ui_selecting_scene = true
        try
        (
            select generated
        )
        catch
        (
            format "SI GENERATE FINAL SELECTION FAILED | %\n" (getCurrentException())
        )
        si_ui_selecting_scene = previous_selecting
        siUiPersistSettings()
        format "SI GENERATE FINAL OK | group:% roots:% reused:%\n" group_id action_data[2].count (not created_new)
    )
    siUiRefreshRows()
    if not (isValidNode generated) then
    (
        siSurfaceIntersectionsRollout.lblStatus.text = "Final generation failed: " + siHierarchy.last_error
        format "SI GENERATE FINAL FAILED | %\n" siHierarchy.last_error
    )
    isValidNode generated
    -- return
)

/*
Rebuilds selected result groups, or all top-level results if nothing is selected.
Nested dependencies are rebuilt by generateGroup; successful prior work survives a later failure.
*/
function siUiUpdate =
(
    local update_ids = siUiGetUpdateTargets()
    local explicit_selection = si_ui_selected_ids.count > 0
    local completed_count = 0
    local failed_id = 0
    local appended_count = 0
    /* Only an explicitly targeted single group may accept new viewport-selected geometry. */
    if update_ids.count == 1 and explicit_selection then
    (
        local target_id = update_ids[1]
        local targeted_group = (findItem si_ui_selected_ids target_id) > 0
        if targeted_group then
        (
            local selected_sources = selection as array
            local original_sources = for target_node in selected_sources where (isValidNode target_node and superClassOf target_node == GeometryClass and (getUserProp target_node "SI_ProcessOwner") == undefined) collect target_node
            if original_sources.count > 0 then
            (
                appended_count = siHierarchy.addSelectionToGroup target_id original_sources
                if appended_count > 0 then
                (
                    /* Save new membership before rebuilding so failures remain retryable. */
                    siUiPersistSettings()
                    format "SI UPDATE | group:% appended:% original surfaces before rebuild.\n" target_id appended_count
                )
            )
        )
    )
    if update_ids.count == 0 then
    (
        siHierarchy.last_error = "Select a result group, or clear the selection to update all results."
        format "SI UPDATE SKIPPED | %\n" siHierarchy.last_error
    )
    else
    (
        for item_id in update_ids while failed_id == 0 do
        (
            local item_value = siHierarchy.items[item_id]
            local precision_value = item_value.precision_mm
            local trim_value = item_value.delete_trimmed
            if explicit_selection and update_ids.count == 1 and (findItem si_ui_selected_ids item_id) > 0 then
            (
                precision_value = si_ui_position_precision_mm
                trim_value = si_ui_delete_trimmed
            )
            local generated = siHierarchy.generateGroup item_id precision_mm:precision_value delete_trimmed:trim_value only_final:si_ui_only_final_result
            if isValidNode generated then
            (
                completed_count += 1
                SurfaceIntersections = siHierarchy.items[item_id].engine
                si_ui_bound_result = SurfaceIntersections.result_node
            )
            else failed_id = item_id
        )
        if completed_count > 0 then siUiPersistSettings()
    )
    siUiRefreshRows()
    if failed_id > 0 then
    (
        siSurfaceIntersectionsRollout.lblStatus.text = "Update failed at group " + (failed_id as string) + ": " + siHierarchy.last_error
        format "SI UPDATE FAILED | group:% | completed:% | error:%\n" failed_id completed_count siHierarchy.last_error
    )
    else if update_ids.count == 0 then
    (
        siSurfaceIntersectionsRollout.lblStatus.text = siHierarchy.last_error
    )
    else
    (
        siSurfaceIntersectionsRollout.lblStatus.text = (completed_count as string) + " result group(s) updated"
        if appended_count > 0 and update_ids.count == 1 then
        (
            local result_node = siHierarchy.items[update_ids[1]].scene_node
            if isValidNode result_node then select result_node
        )
        format "SI UPDATE OK | rebuilt:% | appended sources:%\n" completed_count appended_count
    )
    update_ids.count > 0 and failed_id == 0
    -- return
)

/*
Compares actual transform rows rather than Matrix3 object references.
MaxScript's Matrix3 equality compares references, not the matrix contents.
*/
function siUiSmartSameTransform first_tm second_tm =
(
    (first_tm.row1 == second_tm.row1) and (first_tm.row2 == second_tm.row2) and (first_tm.row3 == second_tm.row3) and (first_tm.row4 == second_tm.row4)
    -- return
)

/*
Lists the highest generated result groups affected by a changed source or scene head.
The current hierarchy supplies parent links; no objects or meshes are modified here.
*/
function siUiSmartGetAffectedRoots changed_ids hierarchy_value:siHierarchy =
(
    local group_ids = #()
    for changed_id in changed_ids do
    (
        if changed_id > 0 and changed_id <= hierarchy_value.items.count then
        (
            local parent_id = hierarchy_value.getParentId changed_id
            while parent_id > 0 do
            (
                if hierarchy_value.items[parent_id].kind == #group then appendIfUnique group_ids parent_id
                parent_id = hierarchy_value.getParentId parent_id
            )
        )
    )
    local root_ids = #()
    for group_id in group_ids do
    (
        local parent_id = hierarchy_value.getParentId group_id
        local has_affected_parent = false
        while parent_id > 0 and not has_affected_parent do
        (
            has_affected_parent = (findItem group_ids parent_id) > 0
            if not has_affected_parent then parent_id = hierarchy_value.getParentId parent_id
        )
        if not has_affected_parent then appendIfUnique root_ids group_id
    )
    root_ids
    -- return
)

/*
Captures only original source and native group transforms for later comparison.
This is a lightweight baseline; it does not snapshot or evaluate geometry.
*/
function siUiSmartCaptureSources =
(
    local snapshots = #()
    if siHierarchy != undefined then
    (
        local reachable_ids = #()
        for root_id in siHierarchy.root_ids do siHierarchy.collectIds root_id reachable_ids
        for item_id in reachable_ids do
        (
            local item_value = siHierarchy.items[item_id]
            if (item_value.kind == #source or item_value.kind == #scene_group) and isValidNode item_value.scene_node then
            (
                append snapshots #(item_id, item_value.scene_node, (copy item_value.scene_node.transform))
            )
        )
    )
    si_ui_smart_snapshots = snapshots
    snapshots.count
    -- return
)

/*
Finds actual source transform changes after the node-event mouse-up batch.
Flags all affected ancestors without starting any geometry calculation.
*/
function siUiSmartCollectDirty =
(
    local changed_ids = #()
    if siHierarchy != undefined and not si_ui_smart_busy then
    (
        for snapshot in si_ui_smart_snapshots do
        (
            local item_id = snapshot[1]
            local source_node = snapshot[2]
            if isValidNode source_node and item_id <= siHierarchy.items.count then
            (
                if (siHierarchy.items[item_id].scene_node == source_node) and (not (siUiSmartSameTransform source_node.transform snapshot[3])) then
                (
                    appendIfUnique changed_ids item_id
                    snapshot[3] = copy source_node.transform
                )
            )
        )
        local affected_roots = siUiSmartGetAffectedRoots changed_ids
        for item_id in changed_ids do
        (
            local parent_id = siHierarchy.getParentId item_id
            while parent_id > 0 do
            (
                if siHierarchy.items[parent_id].kind == #group then siHierarchy.items[parent_id].pending = true
                parent_id = siHierarchy.getParentId parent_id
            )
        )
        for root_id in affected_roots do appendIfUnique si_ui_smart_pending_roots root_id
    )
    si_ui_smart_pending_roots.count > 0
    -- return
)

/*
Records the existence of a release-gated node event; never evaluates geometry.
Autodesk's NodeEventCallback all-handler receives event name and AnimHandle IDs.
*/
function siUiSmartNodeEvent event_name node_handles =
(
    if si_ui_smart_enabled and not si_ui_smart_busy then si_ui_smart_seen_events = true
    true
    -- return
)

/*
Ends one batch after Max releases the mouse and schedules one deferred rebuild.
No update is started from an event callback or while a drag is in progress.
*/
function siUiSmartBatchEnd event_name node_handles =
(
    if si_ui_smart_enabled and not si_ui_smart_busy and si_ui_smart_seen_events then
    (
        si_ui_smart_seen_events = false
        if siUiSmartCollectDirty() and si_ui_smart_timer != undefined then
        (
            si_ui_smart_timer.Stop()
            si_ui_smart_timer.Start()
        )
    )
    true
    -- return
)

/*
Regenerates only affected top-level results once outside the mouse-up callback.
Nested dirty dependencies rebuild first through the existing generateGroup pipeline.
*/
function siUiSmartFlush =
(
    local completed_count = 0
    if si_ui_smart_enabled and not si_ui_smart_busy and si_ui_smart_pending_roots.count > 0 and siHierarchy != undefined then
    (
        si_ui_smart_busy = true
        local requested_roots = copy si_ui_smart_pending_roots #noMap
        si_ui_smart_pending_roots = #()
        try
        (
            for root_id in requested_roots do
            (
                if root_id > 0 and root_id <= siHierarchy.items.count and siHierarchy.items[root_id].kind == #group then
            (
                local item_value = siHierarchy.items[root_id]
                local generated = undefined
                try
                (
                    generated = siHierarchy.generateGroup root_id precision_mm:item_value.precision_mm delete_trimmed:item_value.delete_trimmed only_final:si_ui_only_final_result
                )
                catch
                (
                    siHierarchy.last_error = getCurrentException()
                )
                if isValidNode generated then
                (
                    completed_count += 1
                    SurfaceIntersections = siHierarchy.items[root_id].engine
                    si_ui_bound_result = SurfaceIntersections.result_node
                )
                else
                (
                    format "SI SMART UPDATE FAILED | group:% | %\n" root_id siHierarchy.last_error
                )
                )
            )
            if completed_count > 0 then siUiPersistSettings()
        )
        catch
        (
            format "SI SMART UPDATE FAILED | %\n" (getCurrentException())
        )
        try (siUiSmartCaptureSources()) catch ()
        si_ui_smart_busy = false
        try (siUiRefreshRows()) catch (format "SI SMART UI REFRESH FAILED | %\n" (getCurrentException()))
        format "SI SMART UPDATE | release-triggered roots:% rebuilt:%\n" requested_roots.count completed_count
    )
    completed_count
    -- return
)

/*
Runs one queued update after the mouse-up callback has fully returned.
The WinForms timer is one-shot and is never a periodic polling loop.
*/
function siUiSmartTimerTick timer_sender timer_event =
(
    if si_ui_smart_timer != undefined then si_ui_smart_timer.Stop()
    siUiSmartFlush()
    -- return
)

/*
Detaches this rollout's event callback and timer without changing source geometry.
This also prevents orphaned callbacks after closing or reloading the dialog.
*/
function siUiSmartStop =
(
    if si_ui_smart_timer != undefined then
    (
        si_ui_smart_timer.Stop()
        si_ui_smart_timer.Dispose()
        si_ui_smart_timer = undefined
    )
    if si_ui_smart_callback != undefined then
    (
        si_ui_smart_callback = undefined
        gc light:true
    )
    si_ui_smart_seen_events = false
    si_ui_smart_pending_roots = #()
    si_ui_smart_snapshots = #()
    true
    -- return
)

/*
Installs one native callback that fires at mouse release and a one-shot UI timer.
Manual mode keeps the callback unregistered and has no background processing.
*/
function siUiSmartStart =
(
    siUiSmartStop()
    local started = false
    if si_ui_smart_enabled and siSurfaceIntersectionsRollout != undefined and siSurfaceIntersectionsRollout.isDisplayed then
    (
        try
        (
            siUiSmartCaptureSources()
            si_ui_smart_timer = dotNetObject "System.Windows.Forms.Timer"
            si_ui_smart_timer.Interval = 10
            dotNet.addEventHandler si_ui_smart_timer "Tick" siUiSmartTimerTick
            si_ui_smart_callback = NodeEventCallback mouseUp:true all:siUiSmartNodeEvent callbackEnd:siUiSmartBatchEnd
            started = si_ui_smart_callback != undefined
        )
        catch
        (
            format "SI SMART UPDATE START FAILED | %\n" (getCurrentException())
            siUiSmartStop()
        )
    )
    started
    -- return
)

/*
Selects every original input leaf without changing checks or generating results.
*/
function siUiSelectAllSources =
(
    siUiSyncOriginalSources()
    if si_ui_source_nodes.count > 0 then select si_ui_source_nodes
    true
    -- return
)

/*
Returns top-level generated result IDs targeted by the current tree highlight.
Only an entirely empty highlight falls back to all root groups.
*/
function siUiGetSymmetryTargets =
(
    local target_ids = #()
    if si_ui_selected_ids.count > 0 then
    (
        for item_id in siHierarchy.root_ids where (findItem si_ui_selected_ids item_id) > 0 do
        (
            if siHierarchy.items[item_id].kind == #group then append target_ids item_id
        )
    )
    else
    (
        for item_id in siHierarchy.root_ids where siHierarchy.items[item_id].kind == #group do append target_ids item_id
    )
    target_ids
    -- return
)

/*
Displays the first highlighted root's saved axes, otherwise current session defaults.
Multiple highlighted roots receive the same settings only when user changes controls.
*/
function siUiSyncSymmetryControls =
(
    local first_root = 0
    for item_id in siHierarchy.root_ids while first_root == 0 do
    (
        if (findItem si_ui_selected_ids item_id) > 0 and siHierarchy.items[item_id].kind == #group then first_root = item_id
    )
    if first_root > 0 then
    (
        si_ui_symmetry_enabled = siHierarchy.items[first_root].symmetry_enabled
        si_ui_symmetry_axis_mask = siHierarchy.items[first_root].symmetry_mask
    )
    local previous_sync = si_ui_syncing_controls
    si_ui_syncing_controls = true
    siSurfaceIntersectionsRollout.chkSymmetry.checked = si_ui_symmetry_enabled
    siSurfaceIntersectionsRollout.chkSymmetryX.checked = (bit.and si_ui_symmetry_axis_mask 1) != 0
    siSurfaceIntersectionsRollout.chkSymmetryY.checked = (bit.and si_ui_symmetry_axis_mask 2) != 0
    siSurfaceIntersectionsRollout.chkSymmetryZ.checked = (bit.and si_ui_symmetry_axis_mask 4) != 0
    si_ui_syncing_controls = previous_sync
    true
    -- return
)

/*
Applies the current Symmetry/axis controls to selected root results or all roots.
Only tagged modifiers are managed; generated geometry is never rebuilt here.
*/
function siUiApplySymmetryControls =
(
    si_ui_symmetry_enabled = siSurfaceIntersectionsRollout.chkSymmetry.checked
    local requested_mask = 0
    if siSurfaceIntersectionsRollout.chkSymmetryX.checked then requested_mask += 1
    if siSurfaceIntersectionsRollout.chkSymmetryY.checked then requested_mask += 2
    if siSurfaceIntersectionsRollout.chkSymmetryZ.checked then requested_mask += 4
    si_ui_symmetry_axis_mask = requested_mask
    local target_ids = siUiGetSymmetryTargets()
    local changed = false
    if target_ids.count > 0 then
    (
        for item_id in target_ids do
        (
            siHierarchy.items[item_id].symmetry_enabled = si_ui_symmetry_enabled
            siHierarchy.items[item_id].symmetry_mask = requested_mask
        )
        try
        (
            if siHierarchy.syncRootSymmetry() then
            (
                siUiPersistSettings()
                changed = true
            )
            else siSurfaceIntersectionsRollout.lblStatus.text = "Symmetry could not be applied to all roots"
        )
        catch
        (
            siSurfaceIntersectionsRollout.lblStatus.text = "Symmetry failed: see Listener"
            format "SI SYMMETRY FAILED | %\n" (getCurrentException())
        )
    )
    else
    (
        siUiPersistSettings()
        siSurfaceIntersectionsRollout.lblStatus.text = if si_ui_selected_ids.count > 0 then "Select top-level result rows for Symmetry" else "Symmetry ready for next generated group"
    )
    changed
    -- return
)

/*
Expands the tree above two fixed rows of source actions and selection controls.
At the minimum dialog height both rows retain their bottom spacing.
*/
function siUiLayout dialog_height =
(
    local ui_height = amax 620 dialog_height
    siSurfaceIntersectionsRollout.treeSources.height = ui_height - 430
    siSurfaceIntersectionsRollout.btnUseSelection.pos = [12,ui_height - 76]
    siSurfaceIntersectionsRollout.btnRefreshList.pos = [100,ui_height - 76]
    siSurfaceIntersectionsRollout.btnUp.pos = [188,ui_height - 76]
    siSurfaceIntersectionsRollout.btnDown.pos = [228,ui_height - 76]
    siSurfaceIntersectionsRollout.btnSelectSurfaceResult.pos = [12,ui_height - 36]
    siSurfaceIntersectionsRollout.btnSelectAllSources.pos = [148,ui_height - 36]
    true
    -- return
)
/*
Applies the existing dark .NET action style and semantic foreground colors.
*/
function siUiStyleColoredButton button_control caption_value text_color =
(
    button_control.Text = caption_value
    button_control.UseVisualStyleBackColor = false
    button_control.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
    button_control.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 68 68 68
    button_control.ForeColor = text_color
    button_control.FlatAppearance.BorderColor = (dotNetClass "System.Drawing.Color").FromArgb 120 120 120
    button_control.FlatAppearance.BorderSize = 1
    button_control.FlatAppearance.MouseOverBackColor = (dotNetClass "System.Drawing.Color").FromArgb 78 78 78
    button_control.FlatAppearance.MouseDownBackColor = (dotNetClass "System.Drawing.Color").FromArgb 55 55 55
    button_control.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 9.0 (dotNetClass "System.Drawing.FontStyle").Bold
    button_control.AutoEllipsis = true
    true
    -- return
)

rollout siSurfaceIntersectionsRollout si_ui_title width:288 height:852 autoLayoutOnResize:false
(
    dotNetControl btnTitle "System.Windows.Forms.Button" pos:[12,6] width:264 height:18
    button btnResetResults "RESET RESULTS" pos:[12,36] width:264 height:24 tooltip:"Delete generated hierarchy results while retaining original source surfaces."
    dropdownList ddlPrecision "postion preccision" pos:[12,68] width:128 height:44 items:#("1mm","0.1mm","0.01mm") selection:2
    dropdownList ddlSide "Keep side" pos:[148,68] width:128 height:44 items:#("Auto (larger)","Negative normal","Positive normal","No clipping") selection:1
    groupBox grpResult "RESULT" pos:[6,120] width:276 height:180
    checkBox chkDeleteTrimmed "TRIM RESULT" pos:[12,140] width:128 height:20 checked:true
    checkBox chkOnlyFinalResult "ONLY FINAL RESULT" pos:[148,140] width:128 height:20 checked:true tooltip:"Hide dependency results beneath each generated root; retain all hierarchy data."
    dotNetControl btnRefreshList "System.Windows.Forms.Button" pos:[100,776] width:80 height:28
    dotNetControl btnUseSelection "System.Windows.Forms.Button" pos:[12,776] width:80 height:28
    dotNetControl btnUp "System.Windows.Forms.Button" pos:[188,776] width:34 height:28
    dotNetControl btnDown "System.Windows.Forms.Button" pos:[228,776] width:48 height:28
    checkButton chkSymmetry "Symmetry" pos:[12,218] width:132 height:28 checked:false tooltip:"Apply tool-owned Symmetry to highlighted top-level result(s), or all roots when no tree row is highlighted."
    checkButton chkSymmetryX "X" pos:[148,218] width:40 height:28 checked:false highlightColor:(color 245 92 92) tooltip:"Enable X-axis native Symmetry."
    checkButton chkSymmetryY "Y" pos:[192,218] width:40 height:28 checked:false highlightColor:(color 104 214 112) tooltip:"Enable Y-axis native Symmetry."
    checkButton chkSymmetryZ "Z" pos:[236,218] width:40 height:28 checked:false highlightColor:(color 99 163 255) tooltip:"Enable Z-axis native Symmetry. Multiple axes create separate modifiers."
    checkButton chkSmartUpdate "SMART UPDATE  •  MOUSE RELEASE" pos:[12,306] width:264 height:24 checked:false highlightColor:(color 78 155 226) tooltip:"Rebuild affected results after releasing Move, Rotate, or Scale. No updates while dragging."
    label lblStatus "" pos:[12,254] width:264 height:1 visible:false
    dotNetControl btnGenerate "System.Windows.Forms.Button" pos:[12,172] width:128 height:36
    dotNetControl btnUpdate "System.Windows.Forms.Button" pos:[148,172] width:128 height:36
    dotNetControl btnResult "System.Windows.Forms.Button" pos:[12,254] width:264 height:28
    dotNetControl treeSources "System.Windows.Forms.TreeView" pos:[12,342] width:264 height:422
    dotNetControl btnSelectSurfaceResult "System.Windows.Forms.Button" pos:[12,816] width:128 height:24
    dotNetControl btnSelectAllSources "System.Windows.Forms.Button" pos:[148,816] width:128 height:24

    on siSurfaceIntersectionsRollout open do
    (
        si_ui_syncing_controls = true
        siUiStyleColoredButton btnGenerate "GENERATE" ((dotNetClass "System.Drawing.Color").FromArgb 100 200 100)
        siUiStyleColoredButton btnUpdate "UPDATE" ((dotNetClass "System.Drawing.Color").FromArgb 96 180 255)
        siUiStyleColoredButton btnSelectSurfaceResult "LATEST" ((dotNetClass "System.Drawing.Color").FromArgb 244 166 74)
        siUiStyleColoredButton btnSelectAllSources "SOURCES" ((dotNetClass "System.Drawing.Color").FromArgb 244 166 74)
        siUiStyleColoredButton btnRefreshList "REFRESH" ((dotNetClass "System.Drawing.Color").FromArgb 96 180 255)
        siUiStyleColoredButton btnUseSelection "ADD" ((dotNetClass "System.Drawing.Color").FromArgb 244 166 74)
        siUiStyleColoredButton btnUp "↑" ((dotNetClass "System.Drawing.Color").Gainsboro)
        siUiStyleColoredButton btnDown "↓" ((dotNetClass "System.Drawing.Color").Gainsboro)
        btnUp.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
        btnDown.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
        btnUp.AutoEllipsis = false
        btnDown.AutoEllipsis = false
        btnRefreshList.AutoEllipsis = false
        btnUseSelection.AutoEllipsis = false
        btnRefreshList.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
        btnUseSelection.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter
        siUiStyleColoredButton btnResult "Load hierarchy: right-click" ((dotNetClass "System.Drawing.Color").Gainsboro)
        ToolTitleButton.setupToolTitleButton btnTitle "Surface Intersections"
        ToolTitleButton.resizeToolTitleButton btnTitle (siSurfaceIntersectionsRollout.width - 24)
        treeSources.CheckBoxes = true
        treeSources.HideSelection = false
        treeSources.ShowNodeToolTips = true
        treeSources.FullRowSelect = true
        treeSources.Indent = 14
        treeSources.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 42 42 42
        treeSources.ForeColor = (dotNetClass "System.Drawing.Color").Gainsboro
        treeSources.LineColor = (dotNetClass "System.Drawing.Color").DimGray
        treeSources.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 9.0
        si_ui_context_item_id = 0
        si_ui_tree_context_menu = dotNetObject "System.Windows.Forms.ContextMenuStrip"
        si_ui_tree_remove_menu_item = dotNetObject "System.Windows.Forms.ToolStripMenuItem" "Remove"
        si_ui_tree_remove_result_menu_item = dotNetObject "System.Windows.Forms.ToolStripMenuItem" "Remove Result"
        si_ui_tree_add_menu_item = dotNetObject "System.Windows.Forms.ToolStripMenuItem" "Add Selection"
        si_ui_tree_context_menu.Items.Add si_ui_tree_remove_menu_item
        si_ui_tree_context_menu.Items.Add si_ui_tree_remove_result_menu_item
        si_ui_tree_context_menu.Items.Add si_ui_tree_add_menu_item
        dotNet.addEventHandler si_ui_tree_remove_menu_item "Click" siUiOnRemoveContextClick
        dotNet.addEventHandler si_ui_tree_remove_result_menu_item "Click" siUiOnRemoveResultContextClick
        dotNet.addEventHandler si_ui_tree_add_menu_item "Click" siUiOnAddSelectionContextClick
        si_ui_result_tooltip = dotNetObject "System.Windows.Forms.ToolTip"
        si_ui_result_tooltip.SetToolTip btnGenerate "LMB: Generate from Ctrl-highlighted top-level inputs, or all roots when none is selected.\n\nRMB: Generate FINAL from all top-level roots, or rebuild the sole final result."
        si_ui_result_tooltip.SetToolTip btnUpdate "Rebuild highlighted result groups; with no selection, rebuild every top-level result and its dependencies."
        si_ui_result_tooltip.SetToolTip btnRefreshList "Replace loose source rows from scene selection; preserve result groups."
        si_ui_result_tooltip.SetToolTip btnUseSelection "Append new selected source surfaces without replacing existing hierarchy rows."
        si_ui_result_tooltip.SetToolTip btnUp "Move focused input up among siblings; Ctrl moves to top."
        si_ui_result_tooltip.SetToolTip btnDown "Move focused input down among siblings; Ctrl moves to bottom."
        si_ui_result_tooltip.SetToolTip btnSelectSurfaceResult "Select the latest generated result."
        si_ui_result_tooltip.SetToolTip btnSelectAllSources "Select all original source surfaces."
        si_ui_result_tooltip.SetToolTip btnResult "LMB: Select focused object.\n\nRMB: Load selected saved hierarchy.\n\nCTRL + LMB: Start a new hierarchy, retaining the current scene outputs."
        siUiLoadSettings()
        local restored = false
        if selection.count == 1 then restored = siUiBindResult selection[1]
        if not restored and siHierarchy.items.count == 0 then
        (
            local valid_catalogs = for candidate in ($* as array) where (siUiHasMarker candidate "SI_HierarchyCatalog") collect candidate
            if valid_catalogs.count == 1 then restored = siHierarchy.loadCatalog valid_catalogs[1]
        )
        if not restored and siHierarchy.items.count == 0 then
        (
            siHierarchy.addSources si_ui_source_nodes
            if siHierarchy.items.count == 0 then siHierarchy.addSources (selection as array)
        )
        si_ui_selected_id = siHierarchy.latest_id
        si_ui_selected_ids = if si_ui_selected_id > 0 then #(si_ui_selected_id) else #()
        si_ui_anchor_id = si_ui_selected_id
        siUiRefreshRows()
        callbacks.removeScripts id:#siSurfaceVisibilityUi
        callbacks.addScript #nodeHide "siUiSyncVisibilityChecks()" id:#siSurfaceVisibilityUi
        callbacks.addScript #nodeUnhide "siUiSyncVisibilityChecks()" id:#siSurfaceVisibilityUi
        callbacks.removeScripts id:#siSurfaceSelectionUi
        callbacks.addScript #selectionSetChanged "siUiSyncSceneSelection()" id:#siSurfaceSelectionUi persistent:false
        siUiSyncSceneSelection()
        siUiLayout (getDialogSize siSurfaceIntersectionsRollout).y
        if si_ui_smart_enabled then
        (
            if not (siUiSmartStart()) then
            (
                si_ui_smart_enabled = false
                chkSmartUpdate.checked = false
                siUiPersistSettings()
            )
        )
    )

    on treeSources AfterCheck sender event_args do
    (
        if not si_ui_syncing_controls then
        (
            siUiSetTreeVisibility (event_args.Node.Name as integer) event_args.Node.Checked
        )
    )

    on treeSources MouseEnter sender event_args do
    (
        if not si_ui_syncing_controls then
        (
            siUiFitTreeCaptions()
            siUiSyncVisibilityChecks()
        )
    )

    on treeSources MouseDown sender event_args do
    (
        si_ui_tree_mouse_down = true
        if event_args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right then
        (
            si_ui_context_item_id = 0
            si_ui_context_source_nodes = #()
        )
    )

    on treeSources NodeMouseClick sender event_args do
    (
        if not si_ui_syncing_controls then
        (
            if event_args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left then
            (
                /* Ignore checkbox/expander clicks; only the row text selects scene objects. */
                if event_args.X >= event_args.Node.Bounds.X then
                (
                    siUiChooseTreeRow (event_args.Node.Name as integer) ctrl_pressed:keyboard.controlPressed shift_pressed:keyboard.shiftPressed
                )
            )
            else if event_args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right then
            (
                local item_id = event_args.Node.Name as integer
                if siUiIsVisibleTreeId item_id then
                (
                    si_ui_context_item_id = item_id
                    si_ui_context_source_nodes = selection as array
                    si_ui_tree_remove_menu_item.Visible = siHierarchy.items[item_id].kind == #source or siHierarchy.items[item_id].kind == #scene_group
                    si_ui_tree_remove_result_menu_item.Visible = siHierarchy.items[item_id].kind == #group
                    si_ui_tree_add_menu_item.Visible = siHierarchy.items[item_id].kind == #group
                    si_ui_tree_context_menu.Show treeSources (dotNetObject "System.Drawing.Point" event_args.X event_args.Y)
                )
            )
        )
    )

    on treeSources MouseUp sender event_args do
    (
        si_ui_tree_mouse_down = false
    )

    on treeSources AfterSelect sender event_args do
    (
        /* Keyboard arrow selection is handled here; mouse selection is handled by NodeMouseClick. */
        if not si_ui_syncing_controls and not si_ui_tree_mouse_down then
        (
            siUiChooseTreeRow (event_args.Node.Name as integer) ctrl_pressed:keyboard.controlPressed shift_pressed:keyboard.shiftPressed
        )
    )

    on btnGenerate Click sender event_args do
    (
        /* RMB FINAL availability must not enable an otherwise invalid LMB operation. */
        local action_data = siUiGetGenerateAction()
        if action_data[1] == #group then siUiGenerate()
    )
    on btnGenerate MouseUp sender event_args do
    (
        if event_args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right then
        (
            siUiGenerateFinal()
        )
    )
    on btnUpdate Click sender event_args do siUiUpdate()
    on btnUseSelection Click sender event_args do siUiAppendSelection()
    on btnRefreshList Click sender event_args do siUiRefreshListFromSelection()
    on chkSmartUpdate changed new_state do
    (
        if not si_ui_syncing_controls then
        (
            si_ui_smart_enabled = new_state
            si_ui_last_mode = if new_state then #smart else #manual
            if new_state then
            (
                if not (siUiSmartStart()) then
                (
                    si_ui_smart_enabled = false
                    chkSmartUpdate.checked = false
                )
            )
            else siUiSmartStop()
            siUiPersistSettings()
        )
    )
    on chkSymmetry changed new_state do
    (
        if not si_ui_syncing_controls then siUiApplySymmetryControls()
    )
    on chkSymmetryX changed new_state do
    (
        if not si_ui_syncing_controls then siUiApplySymmetryControls()
    )
    on chkSymmetryY changed new_state do
    (
        if not si_ui_syncing_controls then siUiApplySymmetryControls()
    )
    on chkSymmetryZ changed new_state do
    (
        if not si_ui_syncing_controls then siUiApplySymmetryControls()
    )
    on btnUp Click sender event_args do siUiMoveSourceWithControl -1 ctrl_pressed:keyboard.controlPressed
    on btnDown Click sender event_args do siUiMoveSourceWithControl 1 ctrl_pressed:keyboard.controlPressed
    on btnSelectAllSources Click sender event_args do siUiSelectAllSources()
    on btnSelectSurfaceResult Click sender event_args do
    (
        if siHierarchy.latest_id > 0 then
        (
            local latest_node = siHierarchy.items[siHierarchy.latest_id].scene_node
            if isValidNode latest_node then select latest_node
        )
    )
    on ddlSide selected option_index do
    (
        if not si_ui_syncing_controls then
        (
            local selected_ids = if si_ui_selected_ids.count > 0 then si_ui_selected_ids else #(si_ui_selected_id)
            for item_id in selected_ids where item_id > 0 do siHierarchy.items[item_id].keep_mode = #(#auto,#negative,#positive,#off)[option_index]
            for item_value in siHierarchy.items where item_value.kind == #group do item_value.pending = true
            siUiRefreshRows()
            siUiPersistSettings()
        )
    )
    on ddlPrecision selected option_index do
    (
        if not si_ui_syncing_controls then
        (
            si_ui_position_precision_mm = #(1.0,0.1,0.01)[option_index]
            siUiPersistSettings()
        )
    )
    on chkDeleteTrimmed changed new_state do
    (
        if not si_ui_syncing_controls then
        (
            si_ui_delete_trimmed = new_state
            siUiPersistSettings()
        )
    )
    on chkOnlyFinalResult changed new_state do
    (
        if not si_ui_syncing_controls then
        (
            si_ui_only_final_result = new_state
            siUiPersistSettings()
        )
    )
    on btnResult MouseUp sender event_args do
    (
        if event_args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right then
        (
            if selection.count == 1 then
            (
                if not (siUiBindResult selection[1]) then format "SI HIERARCHY | Select a saved hierarchy result.\n"
            )
            siUiRefreshRows()
        )
        else if keyboard.controlPressed then
        (
            siHierarchy.saveCatalog()
            siHierarchy = SIHierarchy_v()
                si_ui_selected_id = 0
            si_ui_source_nodes = #()
            siUiRefreshRows()
        )
        else if si_ui_selected_id > 0 and isValidNode siHierarchy.items[si_ui_selected_id].scene_node then select siHierarchy.items[si_ui_selected_id].scene_node
    )
    on btnResetResults pressed do
    (
        if queryBox "Delete this hierarchy's generated results?\n\nOriginal source surfaces will be retained." title:"Surface Intersections - Reset" then
        (
            if siHierarchy.resetResults() then
            (
                si_ui_selected_id = 0
                si_ui_selected_ids = #()
                si_ui_anchor_id = 0
                        siUiRefreshRows()
            )
        )
    )
    on btnTitle Click sender event_args do
    (
        siUiPersistSettings()
        DialogHost.saveDialogState siSurfaceIntersectionsRollout si_ui_ini_path si_ui_ini_section min_height:620
        restartTool si_surface_intersections_main_path "Surface-Intersections"
    )
    on siSurfaceIntersectionsRollout moved dialog_pos do DialogHost.saveDialogPosition siSurfaceIntersectionsRollout si_ui_ini_path si_ui_ini_section
    on siSurfaceIntersectionsRollout resized dialog_size do
    (
        siUiLayout dialog_size.y
        DialogHost.saveDialogState siSurfaceIntersectionsRollout si_ui_ini_path si_ui_ini_section min_height:620
    )
    on siSurfaceIntersectionsRollout close do
    (
        siUiSmartStop()
        callbacks.removeScripts id:#siSurfaceSelectionUi
        callbacks.removeScripts id:#siSurfaceVisibilityUi
        siUiPersistSettings()
        DialogHost.saveDialogState siSurfaceIntersectionsRollout si_ui_ini_path si_ui_ini_section min_height:620
    )
)

/*
Opens one managed static TreeView editor; no runtime rollout cloning is used.
*/
function siOpenSurfaceIntersectionsUI =
(
    local opened = false
    if si_ui_framework_ready and siHierarchy != undefined then
    (
        si_surface_intersections_main_path = si_ui_directory + "Surface-Intersections.ms"
        opened = DialogHost.createManagedDialog siSurfaceIntersectionsRollout si_ui_ini_path si_ui_ini_section tool_key:"Surface-Intersections" default_width:288 default_height:852 min_height:620
        if opened then windows.processPostedMessages()
    )
    else format "SI HIERARCHY UI FAILED | Missing backend or UI framework.\n"
    opened
    -- return
)







