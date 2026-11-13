## Development v1.01 — CUI docking contract

The owner rollout is registered as a CUI dialog bar using the existing tool-local `SIRegisteredDialogOffset` fork and `style:#(#cui_dock_vert,#cui_floatable,#cui_handles)`: allow floating and docking left/right only, with no default dock. The dialog host must **always** finish successful creation with `.dialogBar=true`, even after restoring a legacy `SavedState=unregistered` record. Persist `DockSide` in the existing UI INI; on re-entry use native `cui.DockDialogBar` to restore left/right, otherwise float. While docked, never rewrite the last floating screen coordinates and size. This avoids desktop-dependent docking geometry corrupting future floating restoration. Unregister a CUI bar before `destroyDialog` or reload. A strict floating position correction may log a warning while leaving a successfully registered tool usable. Keep all v1.00 SMART callback lifecycles, backend v0.46 geometry, 288px fixed width and vertically resizable tree intact.

## Development v1.00 — Mouse-release SMART transform updates

SMART mode is an **optional UI-owned node event monitor**, not a change to the geometry backend. It uses `NodeEventCallback mouseUp:true` with `all`/`callbackEnd` to receive a batch only after the user's mouse release. Events themselves do not recompute geometry. For each reachable `#source` or `#scene_group` node, compare all four rows of its world `Matrix3` with a copied baseline; a net-zero drag has no effect. Mark every generated ancestor of a changed item pending and deduplicate affected top-level result roots. A one-shot `System.Windows.Forms.Timer` invokes existing `siHierarchy.generateGroup` after the callback returns, reusing the retained result objects and rebuilding the existing dependent hierarchy bottom-up. Manual UPDATE stays independent; no background polling, no 2-second debounce and no update while a drag is in progress. Scene selection and hide changes cannot mark an unchanged transform dirty. Native group members are captured and may be affected by a group-head transform. Subobject transforms and modifier geometry changes without node transforms are excluded from this initial opt-in mode. Timer/callback lifetime is bound to the open rollout and the user's SMART toggle; ini persistence is independent of the scene's serialized hierarchy.

**Acceptance:** static structure, synthetic hierarchy targeting and native callback constructor can be verified without modifying the scene. The actual mouse release and downstream geometry update require a manual transform gesture in a disposable or saved test scene. Any node-event notifications that 3ds Max does not deliver for a specific transform tool will require explicit follow-up; do not claim guaranteed TransformFinish semantics from NodeEventCallback.

## Current development — project 0.99: remove result and native group visibility

A generated intersection's TreeView right-click menu exposes **Remove Result**. Removal validates the forest splice before deleting the exact operation-owned result, restores any direct native group-head links, promotes child inputs into the removed operation's previous position, and marks surviving parent operations pending for the next explicit update. The source nodes, native groups, unrelated results and their scene-node identities remain untouched. A full reset is not performed. The saved catalog is refreshed, or discarded if no generated results remain. Partial cleanup failure must not claim removal and must retain the hierarchy for retry.

Tree visibility checkboxes operate on the clicked or highlighted item nodes only. Generated intersection groups do not change descendants' own visibility flags. The one recursive case is an original 3ds Max **closed** native group head (`#scene_group`): its checkbox toggles the head and all listed descendants. Open native groups do not cascade. No visibility action triggers generation.

## Current development — project 0.98

A subprecision crossing can leave an uncut triangle corner connecting the two sides of a trim. The cutter checks for a short connection between usable segments with the same rounded endpoint. In a patch without a usable cut segment, it evaluates the crossing with exact side signs, then applies the existing cleanup at the selected position precision. It uses the surviving cell only when exactly one side collapses. The short connection stays internal to region separation.

## Current development — project 0.97: TreeView scene-selection semantics

LMB highlights exactly one TreeView row; CTRL+LMB adds or toggles only the clicked highlighted row. Shift no longer activates a range. Highlighted rows remain parent-level choices for Generate/Update, while scene selection expands their target nodes: a generated-result parent selects itself plus all nested result/source objects; a native 3ds Max scene group selects every nested object but excludes each group-head helper. Duplicate scene targets are ignored. This is a selection-only change, not a hierarchy mutation.

Native `#scene_group` captions are wrapped as `[Name]` only when `isOpenGroupHead` is true; closed groups show `Name`. Tree caption fitting preserves brackets when present and the full name remains available in tooltips. All native group rows display fixed pink RGB (240,118,177), independently of helper wirecolor. Generated `#group` results retain their distinct wirecolors. Group captions refresh when the pointer enters the TreeView. Visibility checkboxes, saved group identity, ordering, and geometry are untouched.

UI file 0.68 stores project 0.97, while backend file 0.44 retains project 0.96. The UI displays the highest loaded global project version. v0.91 remains the confirmed stable baseline. The v0.97 model regression is ready; actual 3ds Max mouse interaction and group-open/closed states still require runtime verification.

## Current development — project 0.96: nested-result sheet identity

The backend now retains evaluated source element identity during final polygon assembly. A generated intermediate mesh may contain separate open sheets whose seam vertices occupy identical positions. Those positions must not turn separate elements into a single non-manifold edge when the mesh becomes an input to a parent intersection.

Each source cache is partitioned by original triangle vertex IDs and shared edges. Retained convex cells are assigned to the corresponding source element using their center, the existing convex-patch containment test, matching normal direction and the closest supporting plane within the explicitly selected position precision. Visible polygon reconstruction and vertex reuse run separately for each element. No source coordinates are moved and no private tolerance is introduced. Within one original element, ordinary vertex reuse still applies.

Verified through MCP in rover-285.max: Generate from the two selected intermediate roots succeeds, creates a visible 57-polygon parent with the two intermediate results as children, and Update preserves that result's node identity. All twelve geometry/data checks pass, including the new independent-sheet regression. The dedicated geometry_qa endpoint was blocked by safe mode and is not counted as a pass.

Backend 0.44 and Curve-Cut-Test 0.16 store project 0.96; unchanged UI 0.67 continues to display the highest loaded project version. **v0.91 remains the user-confirmed stable baseline.**

## Current development — project 0.95: native scene-group display and visibility

Native scene groups (`#scene_group`, representing real 3ds Max group-head helpers) display as `[Group Name]` in the TreeView. Their labels mirror the helper node's actual `wirecolor` (typically pink), without altering it. Generated operation groups (`#group`) retain their existing colored result names. The caption-fitting algorithm preserves both brackets when truncating native group names and keeps full captions in tooltips. Missing native helpers receive a pink fallback text color only.

A checkbox click on any targeted native or generated group now applies the requested viewport hidden state to the group and **every descendant**, independent of whether Ctrl is pressed. The clicked row or explicitly highlighted rows determine the target branches. Leaf sources remain individually addressable. Target hierarchy IDs and scene nodes are deduplicated; one undoable operation modifies only node-level visibility and leaves layer visibility, grouping and geometry unchanged. Ctrl+click on row text still selects whole branches and is unrelated to checkbox behavior. The UI 0.67/project 0.95 update is layout-neutral; backend 0.43 and confirmed stable baseline v0.91 remain unchanged. Native interactive verification is still required.

## Current development — project 0.94: next-level Generate and Ctrl-only visibility cascade

An empty TreeView selection with at least two top-level hierarchy roots now makes the normal left-click GENERATE action create a parent result, regardless of whether the roots are loose sources, native group heads, or existing intermediate operation results. Nested generated groups are evaluated postorder and contribute their existing result meshes to the parent; they are not flattened into raw original sources. Repeating LMB with a sole top-level result does not wrap it again. Independently, RMB FINAL retains its v0.93 all-roots behavior and single-final-root Update path.

Ctrl+click on a result/native group keeps its v0.92 complete-branch TreeView and viewport selection. For generation only, a selected parent covers its highlighted descendants; two or more selected top-level groups are valid inputs in source order. A nested selection with no selected top-level parent remains invalid. Do not mutate the highlighted rows, source scene selection, or scene visibility when normalizing Generate inputs.

TreeView checkbox clicks use the explicit highlighted nodes (or clicked node) without implicit hierarchy expansion. **Only Ctrl+checkbox clicks** propagate the requested visibility to descendants of generated and native scene groups. The operation is undoable and changes only each exact referenced node's hidden flag. Checkbox state remains a readback of effective viewport visibility; geometry is rebuilt only by explicit Generate/Update. Keep backend 0.43, version 0.91 STABLE reference, current 288 px layout and catalog schema untouched. UI 0.66 / project 0.94 development. Mouse-event and geometry integration remain unverified in 3ds Max.

## Current development — project 0.93: Generate FINAL via GENERATE right-click

RMB on the existing GENERATE button builds a final parent intersection from **all top-level hierarchy roots** in their current priority order, regardless of TreeView highlighting. For root `#group` inputs, the existing postorder hierarchy engine evaluates each child group's generated Editable Poly result and passes that evaluated result to the new parent (never flatten child operations into original source leaves). Native `#scene_group` inputs expand their original geometry leaves and root `#source` inputs remain direct. When one top-level generated group already exists, RMB rebuilds it in place without adding another wrapper. Do not modify normal left-click Generate, Update, geometry evaluation, saved catalog schema, node identity or native source group links. Failures in creating a new final parent must restore the original forest roots and discard the new parent without deleting preexisting child group results. UI 0.65, backend 0.43 unchanged; v0.91 remains user-confirmed STABLE.

## Stable release — project 0.91: usable continuation sections

A section endpoint must be distinct by the selected position identity and more than position_precision from the current cursor before it can steer cut extension. This applies the existing usable-cut span rule consistently to generated section segments; a rounding-cell boundary must not turn a sub-precision stub into a false branching continuation. Preserve genuine branch diagnostics, raw source geometry and on-demand generation. **Project v0.91 is the user-confirmed stable baseline (2026-11-02)**, superseding v0.86. The recorded CABIN native generation and 11 existing geometry/data checks support the scoped stability designation.

## Current development — project 0.87: bidirectional selection

While the editor is open, scene selection changes highlight exactly the matching listed node rows. Unlisted nodes remain selected in the scene and are ignored by the tree. An empty matching selection clears tree highlights. Refresh highlight colors, focus, property controls and action availability without selecting nodes, changing visibility or generating geometry. Tree-originated selection writes are guarded against callback feedback so existing Ctrl/Shift semantics remain intact. Use a single tool-owned nonpersistent selectionSetChanged callback, removed on close/reload; no geometry monitoring or polling is enabled. v0.86 remains stable.

## Release status

**v0.91 is the user-confirmed stable baseline (2026-11-02).** Backend 0.43; UI 0.63. It supersedes the v0.86 baseline and retains native group hierarchy, RESULT layout, on-demand generation, parent Update after SIDE transforms, and v0.91 continuation-stub correction for CABIN Generate. Existing v0.91 runtime verification is documented in `changes.md`; the stable-status change itself does not introduce new geometry behavior.

## Stable baseline — project 0.86: precision-collapsed split sides

During finite cutting, one cleaned split side may legitimately be empty under the existing explicit position-precision contract. When the other side is a valid polygon, use that surviving cleaned cell and continue instead of treating the collapsed side as a fatal topology failure. Both sides invalid still fails. This allows parent results to publish after native group transforms while retaining original source transforms, result-node identity, selected precision and on-demand Update semantics.

## Current development — project 0.83: native scene groups as input hierarchy

Native 3ds Max Group heads (`isGroupHead`) are now imported as a dedicated `#scene_group` hierarchy kind. A scene-group branch stores the original head helper and original member objects; it must not be sent to `snapshotAsMesh`. Generation expands only geometry leaves in source order into the current cumulative processing engine. A single native group with at least two geometry members is a valid sole input for creating a new generated result wrapper. Existing result groups and their child mesh results continue to use `#group`.

A successful result generation links each directly contained native scene-group head under its owning result node, retaining the native member hierarchy and preserving the group's world transform. The TreeView reflects the generated result > native group head > original members structure. The `#scene_group` kind, source head and original-parent references are persisted in the existing catalog tables, without changing the catalog schema version. Explicit Update re-scans native group memberships and marks affected generated groups pending. Before RESET deletes generated results, native group heads are detached to their original parents. A failure to restore a group blocks deletion of generated result objects.

The 288px UI layout remains unchanged. Group-scope geometry, catalog round-trip and group parenting require live 3ds Max scratch-scene testing before v0.83 is regarded as stable. User-confirmed stable baseline remains v0.80.

## Current development — project 0.82: single-root Generate default

The implicit all-roots Generate path accepts zero or one distinct checked/highlighted item. A selected item must be a top-level root. Preserve the requirement for at least two roots and no existing valid top-level result; preserve explicit multi-root grouping and Update behavior. v0.80 remains the stable baseline.

## Current release status and v0.81 Generate default

**v0.80 is the user-confirmed stable baseline (2026-11-01).** v0.81 is the next development release. With zero checks and highlights, Generate may use all top-level roots in order only when there are at least two roots and no root group has a valid result node. Existing explicit selection/check behavior takes priority. Do not regroup existing results implicitly or run generation live. Preserve the v0.80 RESULT section layout and unchanged geometry backend.

## Current development — project 0.80: RESULT section below dropdowns

Place the former bottom controls inside a visual RESULT group immediately below the dropdown row: trim options, Generate/Update, Symmetry axes and result information. Below that section place Add/Refresh/Up/Down, Latest/Sources and the vertically expanding tree. All controls retain their action contracts; this is visual grouping and placement only.

## Current development — project 0.79: reference UI arrangement

Use the supplied reference arrangement within the existing 288px client width: dropdowns; Add/Refresh and .NET Up/Down; Latest/Sources; vertically expanding hierarchy tree; trim options; Generate/Update; Symmetry with X/Y/Z; result information. Default height 852px, minimum 620px. Anchor the controls below the tree to the bottom while its height absorbs resizing. This is a placement/size change only; preserve the existing controls and every action contract.

## Current development — project 0.78: added-source rebuilds preserve evaluated geometry

Adding a source changes group membership and marks the operation and its ancestors pending. Mesh geometry waits for explicit Update, which must rebuild all current inputs and N-1 cumulative stages into the existing output node. A failed rebuild retains the prior successful mesh and pending state.

Source patch reconstruction may dissolve a hidden shared diagonal only when its triangles are actually coplanar. Position identity precision must not flatten a warped evaluated source into a different supporting plane: that can turn a newly added source into invalid cuts and prevent publication. Preserve raw source positions, caller precision, hidden-edge output rules and native modifier stacks. v0.66 remains the user-confirmed stable reference.

## Current development — project 0.67: root result Symmetry and X/Y/Z controls

Symmetry and X/Y/Z use native `checkButton` controls on their own row, below the separate 72×24 Refresh/Add row. Checked axes produce independent tagged native Symmetry modifiers (X=0, Y=1, Z=2); multiple axes produce a modifier stack. The hierarchy's highlighted top-level result group(s) are explicit targets. When no tree row is highlighted, all top-level generated groups are targets; a source/child-only selection is never treated as an all-groups command. Grouping checkboxes remain unrelated.

Each group saves a Boolean Symmetry state and 3-bit axis mask on its result node; the existing catalog schema is retained. Only generated top-level group results keep enabled tool-owned Symmetry. Owned child modifiers are disabled before child input evaluation and removed **after successful** evaluation. Failed updates restore existing enabled modifier instances without destroying mirror gizmos. Artist-created Symmetry instances are never claimed or deleted. If an artist modifier is enabled on a child group result, parent intersection reports a failure until the user disables it. Original sources, raw geometry and v0.66 stable precision behavior remain unchanged. Runtime Max tests pending.

## Release status

**v0.66 is the user-confirmed stable baseline (2026-10-31).** Future changes must preserve its verified hierarchy grouping and TOP–FRONT extension behavior. This designation changes documentation only; project and code versions remain unchanged.

## Stable baseline — project 0.66: terminal direction uses usable cuts

The extension graph and polygon cutter must use the same explicit minimum segment-length contract. Before endpoint-degree tests, omit segments whose length is no greater than the caller's position_precision, exactly as the polygon-cut stage already does. This prevents a sub-precision reversed terminal stub from steering the continuation backward or introducing construction knots into the result. The original source positions and selected precision remain unchanged. Keep all prior on-demand hierarchy/UI behavior and result modifier stacks.

## Current development — project 0.65: precision-collapsed polygon boundaries

Final polygon cleanup can remove a hidden diagonal point from a construction sliver whose remaining two corners occupy adjacent quantization cells. Such a loop cannot form a polygon. Before rejecting it, use its longest raw span and require every raw point to lie within that finite span under the existing explicit position-precision segment contract. Only then omit the collapsed construction boundary and log its raw area and precision. Non-collinear invalid regions still abort. No new area epsilon or geometry snapping is introduced. Keep the v0.64 hierarchy UI, manual generation, native result modifier stacks and disabled automatic Slice behavior.

## Current development — project 0.64: Generate follows tree selection (2026-10-31)

The user identifies v0.60 as the last working grouping workflow. Preserve that checkbox path and the newer compact UI, colors and multi-selection. Generate now resolves a single explicit action: two or more checked roots take priority; otherwise two or more highlighted top-level rows create a group; a single focused group updates in place. Mixed parent/child or non-root multi-selection is rejected with a useful message rather than updating only the final focused group. One shared action resolver drives Generate, its caption and status from focus, check and refresh events.

The v0.63 multi-selection could highlight two result groups while Generate silently updated only the focused one; the native UI regression reproduces that failure and passes after this change. Also accept numeric `1`, string `"1"` and Boolean true as saved catalog/color markers: Max decodes `setUserProp ... "1"` as Integer on readback. This restores result-to-catalog lookup and avoids repeated wirecolor initialization. Existing result colors are retained; newly initialized results still use unique colors. No geometry algorithm, modifier stack or source object changes. UI 0.42 / shared project 0.64; backend FN 0.32 unchanged.

Verification in 3ds Max 2026: four hierarchy checks plus tree selection/color check pass. Native geometry test now adds an enabled native Symmetry modifier to the final result and verifies the same instance remains enabled after parent/dependency regeneration and catalog restoration. It still verifies area 650 before applying Symmetry, exact child-mesh inputs, output identity and source-safe cleanup. UI test covers checkbox child groups, Ctrl-selected parent groups, invalid ancestor/descendant rejection and catalog lookup. The current recovered scene also generated successfully before this fix; the regression was isolated to how highlighted inputs were interpreted, not a blanket backend failure. Full application restart/reopen remains unverified.

## Current development — project 0.63: multi-selection and result wirecolors (2026-10-31)

- UI 0.40 -> 0.41; shared project 0.62 -> 0.63; backend FN 0.32 and entry 0.09 unchanged. Keep the 72 x 24 px Add/Refresh buttons on the same row.
- .NET TreeView supports single row click, Ctrl-click additive/toggle selection, Shift-click visible-range selection, and Ctrl+Shift union. Selection is independent of checked nodes used for Generate Group; checkboxes and expanders do not change scene selection. Keyboard navigation also selects scene nodes. The last selected result is the focused operation for Update Selected Group.
- Each highlighted source maps to its exact original node and each result group maps to its exact generated Editable Poly, without implicitly selecting all descendants. Invalid/deleted nodes are excluded. Scene selection follows each tree selection gesture; geometry never regenerates automatically.
- On first encounter, each generated result receives a unique, vivid wirecolor not already assigned to another tagged tool result. A `SI_HierarchyResultColor` user property identifies initialized results; subsequent UI refreshes/reopens retain their persisted wirecolor. The corresponding result TreeView item reads that exact RGB color for its foreground. Source nodes are never recolored.
- Use `siTreeSelectionColorsTestRun()` after loading the tool in a scratch scene with results; the test changes/restores selection only and checks colored result rows and multi-selection. Interactive Windows TreeView click ordering and large production scenes still require verification.

## Current development — project 0.62: matching Add / Refresh action buttons (2026-10-31)

UI-only change from canonical v0.61: UI 0.39 -> 0.40; shared project 0.61 -> 0.62. Place the orange **Add** and blue **Refresh** WinForms buttons on exactly the same action row (y = 248 px). Both are now 72 × 24 px; Refresh starts at x = 148 and Add at x = 224, leaving a 4 px gap and no overlap with Debug at x = 296. Keep their existing Click handlers, colors, dark button style, and no-live-generation behavior unchanged. The 360 px rollout, 12 px horizontal margins, options row, resizable tree, saved hierarchy, entry v0.09 and backend FN v0.32 remain unchanged. Add a read-only action-buttons regression test v0.02. No geometry or scene test is run as part of this UI change.

## Current development — project 0.61: visible action buttons and orange Add (2026-10-31)

UI-only polish on the canonical project 0.60 hierarchy editor: UI 0.38 -> 0.39, project 0.60 -> 0.61. The backend FN 0.32, entry 0.09, source groups, and geometry algorithms are unchanged. Replace the native cramped 32 × 24 Add control with a 60 × 36 WinForms button bearing orange RGB(244,166,74) text; preserve append-only source behavior. Refresh remains a blue RGB(96,180,255) WinForms button but grows from 55 to 80 px wide so the bold label is readable. Both use the shared dark button style, centered text, and existing click semantics.

Expand the fixed editor width from 288 to 360 px to retain one action row with useful button widths and 12 px side gutters. Shift the status/result/tree block down 12 px to maintain clearance under the taller Add button. Keep the same 620 px default and 548 px minimum height and the vertically resizable tree. Do not add dynamic multi-window cloning or automatic regeneration. The new read-only `test/Surface-Intersections-Action-Buttons-Test.ms` validates button captions, RGB values, minimum sizes, and dialog geometry. Live visual inspection is pending, especially in the user’s 3ds Max theme/DPI configuration.

## Current development — project 0.60: explicit trim hierarchy and .NET TreeView (2026-10-31)

**Contract:** Build an ordered forest of source leaves and generated operation groups. Check two or more top-level rows and Generate Group to wrap only those inputs. Seven sources can form Group A from three and Group B from four, then a parent operation whose two inputs are the actual A/B result meshes. Do not flatten the parent back into seven original sources. Within a group, the established cumulative polygon cutter processes child inputs in their displayed sibling order; Up/Down (Ctrl: top/bottom) can change that order. Select one group to Update Selected Group. One checked row does not override that selected update target. Checkboxes clear after generation; nested children are inspectable and reorderable but cannot be checked into an ancestor or sibling group. Remove dissolves a top-level group or removes a loose row without deleting scene geometry.

**Architecture:** FN 0.32 adds `SIHierarchyItem_v` and `SIHierarchy_v` around the unchanged FN 0.31 geometry engine. Each operation owns an independent backend instance and native controller/result pair. Dependency evaluation is postorder and explicit only; repeated updates preserve output node identity. Missing source references fail before their operation publishes a result; cycles and shared descendants are rejected. Updating a nested group marks its ancestors pending. UI 0.38 is one static managed rollout with a WinForms TreeView; no dynamic UI cloning or multiple runtime windows. Project 0.60; entry 0.09 unchanged; v0.52 remains last confirmed stable.

**Persistence and ownership:** An invisible non-renderable spline catalog stores real node references, child IDs, roots, modes and per-group precision/deletion options. Output nodes carry a catalog identity string for selection-based recovery. The catalog is separate from all result controllers, avoiding self-reference cycles. Rebinding does not regenerate. Reset removes this catalog's generated nodes only and retains originals; surviving exact-owned meshes remain removable if their controller was deleted. Refresh replaces loose input rows from scene selection while retaining generated groups. CTRL-click on the result button starts a separate forest and retains current outputs. Right-click on it loads the selected saved hierarchy. Legacy saved flat results can migrate into one group.

**Visibility/options:** ONLY FINAL RESULT hides dependency results beneath each current root; it retains their meshes and metadata. OFF displays reachable operation results. It never changes original-source visibility. Original-source layers and native modifiers remain untouched; automatic endpoint Slice stays disabled. All geometry changes require Generate / Update. A local DUMP logger fork preserves Debug without a central Codebase dependency.

**Plan and verification:** Model-first test for three/four/parent membership and cycle rejection; native seven-surface test for parent input identity, real trim area (650 from child areas 300/400), output reuse, catalog readback, ordering, missing-source failure and source-safe cleanup; real TreeView check/Generate events for root counts 7 -> 5 -> 2 -> 1 and input counts 3/4/2; deleted-controller Reset and single-checked-row update regressions. All four hierarchy tests and the existing seven geometry/manual-update checks passed in 3ds Max 2026. Save/load refers to catalog readback in this session; a full Max restart/reopen of a user's production hierarchy has not been claimed. Existing complex geometry and precision limitations remain.

## Current development — v0.59 crash recovery (2026-10-31)

This release replaces unsafe v0.58 multi-window prototype with one managed compact editor. The v0.58 rollout calls `siMultiCanBindResult` before declaring the helper and may fail on startup; the dynamic text clone path is also removed until an independently designed, tested per-window context exists. A New Window control is **not** presented, rather than pretending multiple instances are supported. The original result-controller rebind and Ctrl-click New Setup workflows remain available sequentially.

Compact UI is retained (two option checkboxes on one row; six list actions on one row; hidden Slice jog controls and manual-mode label; consistent 12px gutters; default/minimum height 620/548px). Backend FN 0.31 is unchanged; no geometry or source object changes are made by this UI fix. UI 0.37 / project 0.59; last confirmed stable baseline v0.52.

Validation: start a **fresh** 3ds Max session and load the canonical entry only after making a safe backup of work. Run the included read-only `siRecoveryUiTestRun()`; visually check layout and safe saved-result binding, then separately verify Generate/Reset in a disposable test scene. **No live runtime crash-reproduction has been claimed for this patch.**

## 2026-10-31 — Compact editor and independent stream windows (project 0.58)

- UI 0.35 -> 0.36; backend 0.30 -> 0.31; shared project 0.57 -> 0.58. Current polygon-cut geometry is unchanged.
- Hide the obsolete Slice X/Y/Z sliders, Slice label, and manual-update note. Keep old callbacks inactive and automatic Slice generation disabled. Place Delete Trimmed and ONLY FINAL RESULT on a single options row.
- Arrange Up, Down, Remove, Refresh, Add and Debug in one compact 24-pixel row with 12-pixel side gutters, while preserving orange selection, blue Refresh, green Generate and existing source right-click commands. Reduce default/minimum rollout heights to 620/548 px and keep the source list vertically resizable above the bottom selection row.
- Add a New Window button. Each new window has separately named UI state, rollout, source list, trim settings, result controller and backend instance. Position/height and INI settings use a window-specific section. Two windows may use overlapping source objects, but the same saved result controller cannot be bound to two windows simultaneously. Closing one window does not delete its results or other windows.
- Correct backend instance-specific precision writes (this.position_precision_mm). This is not a numerical-geometry change; it prevents one window from changing another window's precision. Exclude outputs owned by another window from Add.
- Static source, layout, version, and generated-clone delimiter checks pass. The interactive multiwindow operation and generated-result integration require runtime validation in 3ds Max; no production scene geometry was modified during development.

## Current development — project 0.57: convex containment fix (2026-10-31)

A rotated convex polygon can contain collinear boundary corners after cumulative cuts. The former triangle-fan containment test could produce a tiny nonzero determinant for a zero-area fan triangle and falsely accept a point outside the finite polygon. This created a false intersection beyond a surface border, causing `traceCutEndpoint` to fail. The UI was only the caller; its v0.56 behavior is retained unchanged.

Use the polygon's plane and oriented boundary halfspaces directly, with the existing explicit positional precision. Skip exactly zero-length edges; reject zero-normal polygons and off-plane points. Preserve raw coordinates, source nodes, the Slice-disabled policy and on-demand generation. Backend 0.30 and regression test 0.10 carry project 0.57; entry 0.09 and UI 0.35 are unchanged. v0.52 remains the confirmed stable baseline.

Verification: a deterministic rotated five-corner polygon with a collinear boundary reproduces the old false positive for an outside point 20 units beyond its boundary. The new test rejects outside/off-plane points and accepts interior/border points in both winding directions. Existing geometry, extended cut, temporary native polygon, manual-update and collapsed-edge tests pass. Four-source cumulative checks with the rounded outlines from the supplied error log pass with deletion ON/OFF. The original four side-surface objects are absent from the currently connected scene; their exact full-precision scene rerun is not claimed. The previously recorded 1 mm issue is not certified resolved.

## Current development — project 0.56: color-coded selection and Refresh buttons (2026-10-31)

**Status: UI-only development; 3ds Max visual verification pending.** Based on the canonical project 0.55 (UI 0.34, backend 0.29), the three color-coded controls now use WinForms buttons instead of native rollout buttons because native button text color is not exposed. **Select Latest** and **Select All Sources** display orange foreground text (RGB 244,166,74), and **Refresh** displays blue foreground text (RGB 96,180,255). All three retain their positions, sizes, enable rules, tooltips, and original Click actions; the background, borders, hover, and press colors follow the existing standard dark action-button style. Generate remains green. No scene operations, input-selection policy, geometry, layering, or Reset behavior changes. UI version 0.35; shared project version 0.56. Backend 0.29 is unchanged; v0.52 remains the last user-confirmed stable baseline.

**Acceptance:** Load the tool in 3ds Max and confirm orange text on both bottom selection controls and blue text on Refresh. Verify disabled Select Latest is not clickable when no result exists, Select All Sources still selects original inputs, Refresh replaces draft rows from current selection without regeneration, and the dialog still resizes correctly. Run `test/Surface-Intersections-Button-Colors-Test.ms` to inspect the .NET foreground and action properties without changing the scene.

## Current development — project 0.55: selection Refresh and Reset (2026-10-31)

**Status: DEVELOPMENT / integration verification pending.** Latest Drive base is project **0.54** (backend FN 0.29, UI 0.33). This UI-only update increments UI to **0.34** and project to **0.55**. The previous 0.52 stable baseline and v0.54 polygon extension algorithm remain unchanged.

**Refresh list:** Replace the existing Clear List button, its native right-click command, and confirmation dialog with **Refresh**, which replaces the complete draft source order from the *current* selected original geometry. It does not append (the independent **Add** action continues to append). Skip invalid/deleted nodes, duplicate selections and all tool-generated outputs including results of other setups. When a source is retained, keep its previously selected clip-side option; new sources default to Auto. An empty selection clears the draft list only. Results remain as published until explicit Generate / Update or Reset; Refresh never builds geometry.

**Reset:** Before deleting results, capture the current selection. When the current setup owns results, require confirmation, invoke the existing owner-verified cleanup of generated surfaces, curve controller, pair/stage curves and owned endpoint-Slice instances, and only after **successful** cleanup rebuild the draft list from the captured selection. Selected results deleted by Reset must not be reintroduced. Other setups and original sources remain untouched. If no owned output exists, Reset simply refreshes the list. Cancelled/failed Reset must not replace the draft list. Result layers can remain empty according to the v0.53 layer policy.

**Acceptance:** With A+B currently generated, select C and D and click Refresh: list becomes C,D, original A+B result remains until Generate; reselect A and Add: list becomes C,D,A. Then select C,D and Reset: owned result nodes are deleted, source list becomes C,D, no intersection is generated automatically. Repeat with only the result selected, an empty selection, another setup's result selected, and a cancelled deletion. Confirm no original scene nodes are deleted and no invalid node becomes a source. Run `test/Surface-Intersections-Selection-Refresh-Test.ms` for the read-only source filtering checks.

## Current development — project 0.54: extend open cuts to the surface border (2026-10-31)

The requested replacement for endpoint Slice is an actual polygon cut continued from each free intersection endpoint along its terminal edge. Each target surface is handled independently. A plane through that edge and perpendicular to its incident face traces the connected surface section to its first border; this is a straight continuation on planar faces and follows the same plane across adjacent facets. Unconnected surface islands are not crossed. Closed cuts and endpoints already at borders remain unchanged. Ambiguous branches or a closed continuation fail explicitly rather than choosing a destructive route.

Existing Slice implementation remains available behind `endpoint_slice_enabled = false`; Generate / Update disables only this setup's owned Slice instances and creates none. Manual modifiers are untouched. Larger-region deletion uses the completed cut as its barrier; Delete Trimmed OFF keeps both regions with the same topology. No live regeneration or new precision settings are introduced. v0.52 remains the user-confirmed stable baseline.

Implementation completed: reproduce unequal-width retention with a failing area test; trace connected endpoint sections using existing patch/chord primitives; use the completed finite segments for polygon cuts, region barriers and published curves; gate automatic Slice while keeping exact-owned instances disabled. Backend 0.29 and regression test 0.09 carry shared project 0.54; unchanged UI remains 0.33. v0.53 layer behavior is preserved.

Verification: unequal widths with one/both endpoints interior, reciprocal larger-region retention, OFF area conservation, adjacent noncoplanar facets, closed cuts, nonintersecting inputs, disconnected and point-touching islands pass data checks. A temporary native two-surface fixture verifies actual border vertices and curve endpoints, native polygon creation, owned Slice disabled and manual Slice untouched. The reopened two-source cabin fixture passes native reconstruction at 0.01 mm with Delete Trimmed ON/OFF. The previous geometry, manual-update and collapsed-edge checks pass. Near-duplicate source corners are excluded only after hidden-edge dissolution; a positive-area skinny hidden fan is preserved and retains its full area. Broader CAD robustness and the previously recorded 1 mm issue are not certified by this release.

## Current development — project 0.53: source-nested result layers and startup reference validation (2026-10-31)

**Status: DEVELOPMENT / runtime validation pending.** Starting from the current v0.52 STABLE build (entry 0.09, FN 0.27, UI 0.32), this change makes backend FN **0.28**, UI **0.33**, project **0.53**; polygon intersection mathematics and on-demand Generate / Update remain unchanged.

**Layer contract:** Results are never placed into source layers. Each source layer receives a distinct child results layer named `SI_RESULTS_<controllerHandle>_<sourceLayerName>` per saved setup, using documented LayerManager/LayerProperties APIs. The hidden controller curve belongs under the first source layer. Each cumulative step surface belongs under the source layer of the newly introduced surface; pair-inspection curves use the second source in their pair. With ONLY FINAL RESULT ON, the last surface belongs under the last source layer. An output node cannot belong to several layers at once, so this stable stage-based assignment is explicit. Existing source layer hierarchy, objects, and scene-parent transforms remain untouched. Reusing an existing output and reopening a saved setup reuses the same nested layer. A failed layer operation is logged and does not falsely classify the output as layered; successful cut geometry is not discarded solely because a layer operation failed. Result layers may remain empty after Reset; the tool never deletes source layers.

**Startup validation:** Before initial selection/load and on saved-result rebind, every draft and applied source reference is checked with `isValidNode` and `GeometryClass` before dereferencing. Invalid/deleted input references are discarded with matching side entries, survivors retain their order and side settings; deleted controller reference is cleared safely. No source nodes are modified or deleted, and the UI never auto-generates on open. The old generated result is kept until the artist explicitly updates it.

**Acceptance:** In a scratch scene place A/B in different nested source layers, Generate, inspect results child layers and correct source membership, repeat with three sources and both final-only modes, reopen and rebind, regenerate and confirm no duplicate child layers. Delete B and reopen: the stale reference must be rejected without an exception, surviving source/mode pairing retained and old output untouched. Run `test/Surface-Intersections-Layers-Test.ms` on existing sources/results. The LayerProperties calls are supported in 3ds Max 2015+; a live 3ds Max runtime test is still needed.

# Surface-Intersections — Design

**STABLE BASELINE: project 0.52 — confirmed by the user on 2026-10-31.** Entry **0.09**, backend **0.27**, UI **0.32**, regression test **0.08**. This supersedes the earlier 0.48 stable designation and includes on-demand generation, endpoint Slice placement, polygon-boundary fixes and empty-cell filtering. Earlier stable milestones remain in the history. Existing verification scope and known limitations, including the separate 1 mm curve issue, remain in effect.


**Current stable implementation (2026-10-31, project 0.52):** non-destructive, cumulative, **POLY-only** cutting of finite source surfaces along the actual intersection curves, with optional smaller-region deletion. A single final Editable Poly is published by default. The user reports that intersection cutting now works; 3ds Max 2026 tests for this revision verify the supplied two-surface scene, correct visible-edge cut topology, and both Delete Trimmed states. The limitations listed below remain in effect.

**Repository:** `AI/AGENTS/Maxscript/Codebase/Tools/GEOMETRY/Surface-Intersections/`

**Latest source versions inspected:** entry file **0.09**, backend **0.27**, UI **0.32**, shared project version **0.52**. These are observations from Google Drive at the time of this document revision, not permanent version authority. Reopen the canonical files before the next change.

**Reading guide:** The **Current design contract** below supersedes older behavior descriptions. Sections 1–25 and the later project-version additions preserve historical design decisions and implementation evolution; do not treat their superseded statements about MESH/POLY modes, cumulative toggles, Slice creation, or output stacks as current requirements. The v0.44 and v0.45 verification evidence below supersedes earlier statements that these fixtures have not been tested. **v0.52 is the current STABLE baseline. Earlier development and stable status statements below are historical.**



## Current development — project 0.47: context-menu source ordering (2026-10-31)

**Status: DEVELOPMENT / runtime validation pending.** UI v0.30 and shared project v0.47; geometry backend FN v0.22 is unchanged. v0.45 remains the user-confirmed **STABLE** geometry baseline.

In the source-list right-click menu, add **Move Up (Ctrl: Top)** and **Move Down (Ctrl: Bottom)**. Normal selection moves the chosen sources one position using the existing ordering logic; holding **Ctrl** either when opening the menu or while invoking its command moves all selected sources to the absolute first or last positions. The existing Up/Down buttons also accept Ctrl for absolute moves. Multiple selected sources form a stable ordered group: selected relative order and unselected relative order are preserved, and each source's `#auto/#negative/#positive/#off` kept-side option stays paired with its source node.

Only editable source rows participate. Read-only generated `[RESULT]` rows are not reordered or inserted as source inputs. The selected source rows stay selected after a boundary move; the current generated result is unchanged until **Generate / Update**. Remove Selected Surfaces and Clear Source List stay in the popup. No source node, generated output, or external scene geometry is deleted by reordering.

**Acceptance:** given sources A, B, C, D, E and selected B/D, Ctrl+Up yields B, D, A, C, E and Ctrl+Down yields A, C, E, B, D. Both preserve B/D kept-side modes and selected rows. Standard Up/Down should still move one position. Verify selection mappings with `[RESULT]` rows interleaved, scene save/rebind, and the resulting cumulative output after explicit Generate. `test/Surface-Intersections-Source-Order-Test.ms` exercises the pure stable partition non-destructively; the menu and keyboard modifier need a real 3ds Max check.

## Current development — project 0.46: append-only source list (2026-10-31)

**Status: DEVELOPMENT / runtime validation pending.** Source-list UI v0.29, project v0.46, backend FN v0.22 unchanged. Project v0.45 remains the last user-confirmed **STABLE** geometry baseline; this edit does not modify the polygon cutter.

**Source-list input contract:** `Add` appends unique, valid selected scene geometry nodes to the end of the existing ordered source list, preserving all earlier nodes, order, and kept-side modes. Normal and Ctrl-click have identical append semantics. The internal initial-selection helper must not replace a populated list. Generated result nodes are excluded from source inputs. Adding one or several sources never generates or changes results until **Generate / Update** is pressed. Re-adding any existing node is a no-op, not a new duplicate.

**Two valid work patterns:** (1) select and add A, B, C, D, then Generate once; (2) add A and B, Generate A+B, add C, Generate A+B+C, add D and E, Generate A+B+C+D+E. Each generation recomputes from the ordered original source references and the current cumulative in-memory polygon-patch pipeline; it does **not** re-import the last generated Editable Poly as a source. The existing `ONLY FINAL RESULT` checkbox controls how many result nodes are published, not which intermediate cumulative cuts are evaluated. The `Delete Trimmed` option is unchanged.

**Independent list controls:** `Remove` deletes selected **source rows only**, and `Clear List` removes all source rows after confirmation. Right-clicking the native MultiListBox opens **Remove Selected Surfaces** and **Clear Source List...**. The MultiListBox right-click callback does not provide a clicked row index, so removal acts on the currently selected source rows; generated result rows cannot be removed this way. None of these actions delete or modify original scene objects, and they leave previously generated outputs intact until a subsequent explicit Generate / Update or output Reset. `Reset` continues to manage only owned generated outputs; it does not clear source inputs.

**Validation plan:** add A+B, Generate; append C, Generate; append D+E, Generate; repeat A (no duplicates); select source rows, right-click Remove and verify the paired clip modes remain aligned; Clear List and cancel/confirm; test with a selected result row, which must not remove any source. Confirm previous outputs and source nodes persist when source rows change; the outputs reflect a new list only after Generate / Update. Perform these in a scratch 3ds Max scene and verify the released v0.45 polygon-cut fixture still passes.

## Stable verification status — project 0.45 (2026-10-31)

**Release status: STABLE (user-confirmed).** The working intersection and polygon-cut output of the current canonical backend is the approved baseline. Keep the source version values unchanged for this documentation-only milestone. Future code work must branch from the latest canonical files and preserve this behavior or explicitly describe a regression.

**Recorded 3ds Max 2026 checks:** the supplied two-surface fixture generated 70 vertices and 39 polygon faces with two connected surface elements. The output contained all 13 tested visible-edge intersection segments, with no arbitrary face-center, midpoint, or hidden-diagonal cut vertices. Delete Trimmed OFF produced 98 vertices / 65 faces; returning ON restored 70 / 39. The focused scene and data regression checks passed, and refresh preserved final result identity. These results come from existing repository verification, not a new test performed during this documentation update.

**Boundaries of STABLE:** scope is the tested finite-surface polygon intersection workflow. Broader multi-source, concave, coplanar overlap, branching or self-intersecting networks, scene reopen and asynchronous live updates are not certified by these tests. Current no-new-Slice policy remains in force.

## Current design contract — project 0.49

### Goal and source safety

For an ordered list of **two or more finite, open source surfaces**, the tool computes intersection curves and uses those curves to **split the generated Editable Poly topology of both intersecting surfaces**. Source nodes, their modifier stacks, and their topology are not modified. The generated surface must not be merely unchanged source copies attached into one object; a successful non-tangential intersection must produce real cut edges and faces.

### Polygon topology and intersections

- **POLY is the only processing mode.** No MESH/POLY radio buttons. `snapshotAsMesh` may still carry evaluated source geometry internally, but its triangular seams are not authoritative Editable Poly topology.
- Reconstruct visible polygon boundaries across shared, mutually hidden coplanar triangulation seams. **Never introduce a vertex merely because an intersection crosses a hidden source diagonal.** Preserve true boundary vertices and add vertices where a real cut requires them.
- Use the actual **finite polygon intersection curve** as the cutting reference on *each* surface. The curve must become a topological edge in the generated Editable Poly, not just a companion spline.
- A short finite curve that ends inside a polygon may require invisible **support seam** geometry to form valid polygon faces. Only the real finite intersection segment is displayed as a visible cut edge; hidden construction and triangulation edges must remain hidden. The v0.44 cutter partitions each convex patch along all actual finite segment directions, including a bent seam inside one patch. These supporting lines create convex cells; only the finite curve blocks region connectivity. Actual curve junctions are authoritative when nearly parallel lines make recomputed intersections unstable.
- Preserve polygon faces, including n-gons. Do not force quads, add face centers, split edges at arbitrary midpoints, or publish hidden construction-cell seams. A new output vertex must be a true cut crossing of a visible polygon edge; evaluated hidden diagonals must not create cut vertices. Existing source vertices on retained geometry remain.

### Processing, deletion, and output options

- **Cumulative is unconditional:** `A + B -> (A+B) + C -> ((A+B)+C) + D`. Remove the old cumulative checkbox. Every stage uses the prior stage's **in-memory surviving polygon patches**, not a mesh snapshot of the generated result object.
- **Delete Trimmed — ON by default.** When a finite, boundary-to-boundary intersection truly divides each surface, retain the larger-area region **independently for each surface** and remove its smaller region. Area is compared in world space. Equal-area ties use deterministic orientation. Off or a partial/nonseparating cut must not delete an arbitrary fragment.
- **Delete Trimmed — OFF.** Make the same real polygon cuts on both surfaces, but keep **both** sides. Their combined area must agree with the uncut patch within the chosen positional precision.
- **ONLY FINAL RESULT — ON by default.** Compute all cumulative stages internally but publish just the latest visible Editable Poly. Keep the separate **hidden spline controller** needed for source references, persistence and live updates: final-only means one *visible surface result*, not literally one scene node. Do not generate intermediate surface nodes or pair-curve inspection nodes in this mode. When OFF, publish the cumulative stage surfaces and pair inspection curves for debugging/selection.
- Source order, per-source kept side, `postion preccision` (1 / 0.1 / 0.01 mm), manual/live/freeze updates, Select Latest, Select All Sources, Use / Add, Debug and Reset retain their established functions. Original sources and outputs belonging to other setups must never be deleted.
- Persist `DeleteTrimmed` and `OnlyFinalResult` in the project-local INI and on the saved setup (`SI_DeleteTrimmed`, `SI_OnlyFinalResult`). Legacy cumulative/mode fields may remain in stored schemas for compatibility, but always resolve to cumulative + POLY.

### Endpoint Slice policy — project 0.49

The user explicitly re-enables automatic endpoint Slice placement as part of Generate / Update. For an open finite intersection ending on the border of one source but inside the other, append one native Slice instance to the wider source and the final result. Set `Slice_Type = 2`, operate on polygons, and put its gizmo pivot at the non-border terminal cut vertex. Choose the world-aligned plane whose normal has the largest absolute component along the outgoing terminal segment; flip the plane for the opposite end so it removes the overhanging side. Both hosts use the same exact modifier instance and identical world-space plane, with per-node contexts compensating for different object transforms. Existing manual Slice modifiers are never adopted, moved or deleted automatically. Slice rows appear below their result and open that exact modifier in the Modify panel. The old rotation jog sliders remain disabled; edit the selected native modifier instead.

### Validation, failure handling, and known limits

- For every reported non-tangential source intersection, verify that each affected surface has a real topological split. Compare the area before/after a split; report face counts, split counts, and precise coordinates for unsupported cases. An unmodified attached copy **does not constitute success**.
- A tangent intersection coincident with a pre-existing polygon boundary may require no new edge. A partial/open-ended cut may be retained on both sides; arbitrary nonseparating geometry must never cause smaller-region deletion.
- Unsupported cases such as multiple non-collinear cut branches on one convex patch, concave/nonconvex unions, coplanar overlapping faces and arbitrary holes are **not fully supported**. Report and avoid publishing misleading geometry rather than silently claiming a successful cut.
- **Historical failure (before v0.43):** the intersection curve was correct, but the generated surface contained uncut source copies. **Current status (stable v0.45):** the user confirms intersection cutting works; the stored 3ds Max 2026 scene and focused regression checks verified real visible-edge topology on the tested two-surface fixture. This is a scoped runtime pass, not a claim of generalized CAD robustness.

### 3ds Max acceptance test

Use two offset, perpendicular source quads, one with a hidden triangulation diagonal. Generate with **Delete Trimmed OFF** and inspect the resulting Editable Poly's actual edges and faces: each intersected surface must be split precisely along the visible intersection curve, while both complete surface areas remain. Toggle **Delete Trimmed ON** and verify independent larger-region retention (for example 70% of A and 80% of B). Confirm there is **no new vertex at the invisible diagonal crossing** and no automatically added Slice modifier. Repeat in both ONLY FINAL RESULT modes, regenerate after moving a source, and confirm original source objects are unchanged. Run `test/Surface-Intersections-Curve-Cut-Test.ms` in a scratch Max scene; the data-only regression test is complementary, not a replacement for inspected scene topology.

---

## Historical design and implementation evolution

The following numbered sections document how the tool evolved through v0.45. Superseded plans are retained for reference; the current stable design contract above has precedence.

## 1. Problem and goals


Given two or more finite, open/one-sided source surfaces in 3ds Max, compute the **finite intersection network** among their evaluated geometries. Keep it dynamic: editing mesh vertices/topology or transforming a source updates the result in place, without changing the source geometry. Long term, make two optional outputs:


1. **Curves output (current prototype):** a spline network following all intersections of selected surfaces, usable for inspection or later modeling operations.
2. **Geometry output (future):** trimmed surface patches or a coherent mesh constructed from the original surfaces, respecting which regions to keep. This requires explicit region-selection/inside-outside policy, not merely intersection segments.


A native **Surface modifier** applied to output curves is a separate *experimental* path. It needs a valid patch network and may not form faces from raw intersection lines. Do not conflate “12 cube edges found” with “six valid surface patches created.”


## 2. Existing code and runtime lifecycle


The tool now has three independently loadable source files: `Surface-Intersections.ms` (entry loader v0.07), `Surface-Intersections-FN.ms` (backend v0.01 with global `SurfaceIntersections`, declared using `SurfaceIntersections_v`), and `Surface-Intersections-UI.ms` (frontend v0.01). The script can execute on the current selection if at least two valid sources are selected. Its public methods include:


| API | Purpose |
| --- | --- |
| `SurfaceIntersections.startLive source_values position_precision_mm:0.01` | Build a result and link input nodes for live updates. |
| `SurfaceIntersections.run position_precision_mm:0.01` | Start from scene selection. |
| `SurfaceIntersections.createFromSelection source_values position_precision_mm:0.01` | Create an unmonitored, static spline. |
| `SurfaceIntersections.refresh()` | Recompute linked result in-place unless frozen. |
| `SurfaceIntersections.setMode #live/#manual/#freeze` | Control automatic and explicit regeneration. |
| `SurfaceIntersections.stop()` | Detach monitoring; leave existing result geometry in the scene. |


**Processing sequence**


```text
ordered geometry nodes (N >= 2) with per-source clip-side modes
    -> snapshotAsMesh evaluated triangles, in world coordinates
    -> for each source pair, each triangle pair
       -> axis-aligned bounding-box rejection
       -> finite, noncoplanar triangle/triangle crossing
       -> handle an edge exactly in the opposing triangle plane
    -> for each surface pair, clip by earlier planar cutter footprints / kept sides
    -> deduplicate intersection segments with explicit endpoint identity precision
    -> build chains from endpoint-degree graph
    -> remove straight-through knots at hidden triangulation edges (preserve bends/branches)
    -> create/update one SplineShape: Surface_Intersections
```


For curve updates, the *result node* is reused. Existing modifiers on that node remain attached; spline/knot/segment indices may change, so topology-dependent modifier data can become invalid. The current script manages one active live link in a 3ds Max session. Previously generated result nodes may remain but do not stay linked when a new link is started.


### Live updates


`NodeEventCallback` handles geometry, topology, structure, controller and deletion events; a `when transform` handler monitors source object transforms. Handlers mark the result dirty, and a Windows Forms timer coalesces rebuilds (350 ms interval; node event callback uses mouse-up/delay behavior). Rebuilding inside the callback directly would risk recursion and expensive repeated evaluation. A failure is logged and may disable live monitoring by switching to Manual mode.


Modes:


- `#live`: automatic delayed recalculation on observed source changes.
- `#manual`: recalculate only on `refresh()`.
- `#freeze`: prevent refresh to preserve an output snapshot.


**Persistence limitation:** callback links are in-process state, not stored procedural dependencies in a `.max` scene. After reopening, the saved output curve object may exist, but link monitoring needs rebuilding. Undo/redo and deleted inputs need dedicated 3ds Max runtime regression coverage.


## 3. Numeric and geometric contracts


Inputs must be evaluated finite geometry, not assumed infinite construction planes. The current implementation uses mesh triangulation and `snapshotAsMesh`, bounding-box rejection and barycentric/plane tests. It is not a robust generic CAD intersection kernel.


- Position identity is specified in millimeters, **1.0 / 0.1 / 0.01 mm**, default 0.01 mm, converted via `units.decodeValue` to scene units.
- Temporary endpoint positions are quantized for *comparison*; actual resulting curve positions are not intentionally snapped or truncated.
- v0.05 added exact clipping of an edge lying completely in an opposing triangle plane, conditioned on intersecting (nonparallel) triangle planes. This addresses the missing shared-boundary edges from the earlier six-plane report.
- Truly coplanar triangle/triangle area overlap is still excluded. Degenerate triangles, tangent intersections and near-coincident floating-point cases have no general robustness guarantee.
- Do not introduce arbitrary hidden tolerances to satisfy a test. Preserve raw expected/actual positions in error logs, and handle failure distinctly from valid zero intersections.


Current implementation complexity is approximately pairwise in evaluated triangle counts; it has no spatial index. High-density source meshes are expensive.


## 4. Six-plane regression fixture and diagnostics


The primary fixture creates six independent, one-sided 100x100 Planes at x/y/z = ±50. One input is converted to Editable Poly; another has an Edit Poly modifier. Adjacent planes meet along a **complete 100-scene-unit edge**; three opposite pairs do not intersect. There are 15 possible source pairs: **12 expected full intersection edges** and **3 nonintersecting opposite pairs**.


Earlier user-provided runtime report, before the shared-edge correction, showed only 5 resulting spline curves and several adjacent source-pair `segments: 0`. The Surface modifier subsequently evaluated to **0 vertices / 0 faces** and logged two failed checks. These were *observations from the earlier version*, not proof that the latest v0.05 correction or the Surface modifier workflow now passes.


The regression tests are:


- `test/Surface-Intersections-Test.ms` — simpler test with six planes and a moved TOP; deletes scene nodes without resetting scene settings.
- `test/Surface-Intersections-Curves-Test.ms` — checks six planes, all 12 expected endpoints, evaluated source vertices, spline knots, same result identity after moving TOP by [0,0,-15], and live-mode reenable.
- `test/Surface-Intersections-Surface-Test.ms` — adds `Surface()` above the intersection spline, inspects evaluated vertices/faces before/after TOP movement, and correctly fails if no patch mesh is produced.
- `test/Surface-Intersections-Diagnostics.ms` — common fixture, assertions, raw coordinate logging and output summaries; can be loaded without automatically starting a test.


All three executable tests delete all scene nodes, including hidden/frozen objects, without resetting the Max scene or its units, animation range, and render settings. Object deletion is destructive; run only in a scratch session. Logs are written to `test/logs/Surface-Intersections-Curves-Debug.txt` and `...Surface-Debug.txt` with `SI DEBUG | ...` records and raw vertex/knot coordinates; logs are not a source of code versions.


### Acceptance checklist


**Curve engine:** all 12 cube edge intersections found with correct endpoints and no spurious opposite pairs; stable result node handle after source movement; knot positions change; live tracking actually reacts to mouse-up, transform, vertex editing, and relevant undo/redo in 3ds Max. Test behavior for many-to-one branches and intersections not coincident with existing mesh edges.


**Surface output (separate gate):** evaluated face count above zero, geometry follows moved source, patch connectivity and normals are correct. If the native modifier returns zero faces with correct intersection edges, that is **not** necessarily a curve-engine failure; investigate patch-network representation and modifier requirements.


**Scene safety:** never reset scene in production. Test scripts delete every scene node deliberately (without a full scene reset) and must warn users that existing objects will be lost. Do not silently modify source nodes or collapse their modifier stacks.


## 5. Proposed development path (not yet implemented)


### A. Make the curve network structurally robust


Improve segment joining at T/Y/X junctions, preserve component provenance (source object/triangle pair), remove overlapping collinear fragments safely, represent per-edge adjacency rather than a single arbitrary chain at junctions, and exercise displaced/rotated/curved source meshes. Investigate numerical robustness under system/display unit changes without unapproved tolerances.


### B. Separate geometric results from presentation


Expose a pure intersection graph (3D vertices, edges, provenance, branch degree, source ownership) to multiple output builders. Continue supporting a `SplineShape` for curve output. A graph layer is more useful than interpreting a chain of independently disconnected splines as a patch cage.


### C. Direct mesh output


Intersect and split source triangles, decide which clipped patches to keep via an explicit user-selectable trim/region rule, merge compatible vertices, preserve planar regions where possible, orient faces consistently, and construct a mesh/polygon object. Handle open boundaries and holes explicitly. Avoid promising a watertight solid for arbitrary input surfaces.


### D. Native Surface-modifier output (optional investigation)


Derive ordered per-patch 3/4-sided spline boundaries with compatible endpoints/tangents, rather than feeding arbitrary intersection lines to `Surface()`. If native patch requirements cannot be met generally, keep it as a narrow optional output, not the main geometry solution.


### E. Production UI and persistence


The shared Tools package is now split into `Surface-Intersections.ms` (loader), `Surface-Intersections-FN.ms` (backend) and `Surface-Intersections-UI.ms` (dialog). Expose source selection, precision (`postion preccision` label per shared rule), output type, live/manual/freeze, refresh and status. Persist UI state separately. Consider re-linking on scene load with stable source identifiers and validation rather than transient callbacks only; do not automatically rebind ambiguous source nodes.


## 6. Out of scope or unverified


No direct output mesh yet. No permanent source->result dependency survives scene reload. No robust coplanar face overlap, general trim-region selection, reliable patch creation, or guaranteed identical curve topology across rebuilds. Performance and callback behavior across 3ds Max 2023/2026 and undo/redo are not certified by a real production test suite. A Python or static geometry dry-run is not equivalent to executing MaxScript in 3ds Max.


## 7. Documentation and versioning rules


Current Google Drive canonical files win over old chat downloads. The shared project version uses highest-loaded semantics. On a future code change, bump each edited code file's internal version by its established precision step and bump the shared project version once, assigning the new project version only to modified code files; unchanged code retains its values. Documentation-only additions **do not increment script versions**. See root and `test/AGENTS.md` for test safety, debug logs and strict protected shared-Codebase authorization.

## 8. Source priority and hidden-edge knot policy (shared 0.10)

- The order of selected source nodes defines priority: the top row has the highest priority. When processing sources i/j (i < j), any planar source before i may clip their line segments. Reordering changes the outcome only after Generate / Update; Rebuild maintains the existing output node identity when an active link exists.
- Per-source cutter side: Auto (toward the average source-center), Negative normal, Positive normal, or Off. AUTO is a heuristic: for arbitrary open surfaces, explicitly choose kept sides. The finite polygon footprint must cover a crossing before it can trim. A nonplanar source cannot act as a half-space cutter; that cutter is skipped and reported.
- Precision is a user-selected 1 mm / 0.1 mm / 0.01 mm endpoint-matching option. Geometry is kept at native world-space positions; the tolerance is used in footprint checks and duplicate/hidden-edge classification.
- Each `snapshotAsMesh` face records edge visibility (`getEdgeVis`). A curve's interior knot is omitted only if it lies on a hidden source-mesh edge and is collinear with its two neighbors while its graph degree is exactly two. Do not remove true bends, intersections, endpoints, or branches.
- This is **curve clipping**, not cutting or trimming the underlying source surface meshes. The 3ds Max Surface modifier still requires its own coherent spline patch network and remains experimental.
- User interface: native dockable rollout with source priority list, Up/Down, per-source kept side, precision, Generate/Update, refresh and update modes. The backend and UI can be loaded independently. Settings are stored next to the tool in `Surface-Intersections-UI.ini`.
- Regression test: after six cube faces are created and TOP moves to z=35 from z=50, all curve knots must lie within BOTTOM z=-50 and TOP z=35 (at the configured position precision). Full runtime behavior and the UI still require in-3ds Max verification.


## 9. MESH/POLY and source-list controls (project 0.19)

- UI 0.08, backend FN 0.03; the existing 0.18 endpoint-trimming changes are retained. Entry loader unchanged.
- MESH is the default and retains triangle-crossing knots. POLY uses the same evaluated triangle intersection engine, removing only redundant degree-two knots on hidden edges. Visible edges from any source protect coincident knots. Bends beyond the existing position precision, branches and open endpoints remain; closed chains also simplify their seam knot.
- IntersectionMode is persisted in the existing UI INI. Mode changes schedule a refresh in Live; Manual requires Refresh or Generate / Update, and Freeze retains the current result.
- The ordered multiListBox is at the bottom and expands vertically. The default dialog height is 660 px, minimum 620 px. Source references and paired kept-side values remain retained.
- Selected list rows select their valid scene nodes; scene selection never replaces the list implicitly. Remove deletes selected rows and paired settings only, preserving the order of remaining rows and all scene objects. Generate / Update applies the edited source set to the linked result, matching the existing reorder workflow.
- Data-only test: test/Surface-Intersections-Poly-Test.ms, run after loading the tool. Uses a separate backend instance, creates/deletes no scene objects, and checks hidden/visible knots, bends, branches, endpoints, closed seams and empty data. It does not replace the evaluated-mesh integration tests.
- Static delimiter/declaration checks passed. MAXScript runtime and visual verification remain pending because the MCP session is terminated.



## 10. On-demand debug capture (project 0.23)

The Debug button, next to Use Selection, calls siUiWriteDebug(). It passes the project-local output path and canonical Codebase/Tools/DUMP/DUMP.ms logger path to SurfaceIntersections.writeDebug. Each click starts a clean logs/Surface-Intersections-Debug.txt, not an append-only history. It records current list order separately from applied source order; valid sources from both are captured once, with world positions, evaluated mesh vertices, triangle indices/edge visibility, units, precision, mode and dirty state. Every current result spline and world-space knot is listed. Data is mirrored to Listener through the shared DUMP logger. Capturing does not regenerate or modify scene geometry. Missing inputs/results are explicit; exceptions mark the capture incomplete.

For subsequent debugging, read the latest synced logs/Surface-Intersections-Debug.txt before drawing conclusions about the user's scene. No log exists until the user clicks Debug or calls siUiWriteDebug(). Check its timestamp/project version and END/FAILED marker; do not treat a missing or incomplete log as a successful capture. Static checks only; runtime remains pending.



## 11. Result-owned editing (project 0.24)

UI 0.13 attaches SurfaceIntersectionsSetup custom attributes to the result node (baseObject:false), with a stable attribute ID and schema version 1. nodeTab references preserve source identity through renames; arrays retain draft order/sides separately from applied order/sides and applied precision. Scalar controls and requested/actual update modes are stored alongside them. Saving the .max scene persists this data. INI stores defaults and dialog placement, not scene references.

The current editor controls one result at a time. Generate / Update retains that node. The full-width .NET result button is directly below Generate: left-click selects the result, right-click loads the selected saved result, Ctrl-left-click starts an unbound setup. Switching stops the previous live monitor but keeps its curve and data. Opening prefers a single selected saved result, otherwise the previous valid binding. It restores references and monitoring without explicitly regenerating; pending source edits still need Generate. Missing sources are retained as deleted rows and force Manual mode. A deleted bound result cannot silently become a new output.

This supersedes earlier persistence limitations: source references now survive scene saves, but automatic monitoring starts only when the result is bound in the tool. Multiple simultaneous live editors remain unsupported. Custom attribute and callback behavior requires runtime verification.

Manual acceptance: generate A, record its handle, change/reorder sources and generate again (same handle); Ctrl-click result button, create B; select A and right-click result button (A's sources/settings return); rename a source, save/reopen scene, select A and open tool (same reference, new name); remove a source and verify deleted row/Manual. Check pending edits survive switching without changing the applied source list. Check result button/list clearance at minimum height. Run Debug after binding A to capture the restored source set and knots. Do not use destructive fixture scripts in a working scene.

## 12. Cumulative trimming (project 0.26)

This section supersedes the historical source-priority-only description. The first source starts the working result. Starting at stage 2, the new source clips every existing surviving patch using its own kept-side setting. Independently, the new source's original patches are clipped by the entire *pre-stage* surviving result, using the per-source kept-side setting of each earlier surface. The two reciprocal passes read the same old result and commit together. Each following source then operates on the accumulated result, while original source nodes remain untouched.

The resulting per-source patch sets continue to feed the intersection-curve generator and the experimental direct-trimesh builder. The current `priority_clipping` backend property and persisted PriorityClipping INI/custom-attribute setting now enable cumulative trimming. Turning it off keeps original patches. `#off` means that particular source cannot act as a cutter, but it remains a valid target.

The Auto kept-side choice still uses the average center of all inputs, not a stage-specific center. Explicit Positive/Negative should be used for ambiguous cases. This is finite polygon-patch trimming, not boolean solid CSG or guaranteed watertight mesh generation. Coplanar overlap and result-owned trimmed mesh persistence remain limitations.

Data-only test: `test/Surface-Intersections-Cumulative-Test.ms` exercises reciprocal two-surface trimming, clipping of both earlier survivors by a third surface at a negative X coordinate, clipping the third surface against the previous result, and `#off` behavior. This test does not modify scene objects. Full runtime verification remains pending.
## 13. Select All Sources and dialog placement (project 0.28)

The `Select All Sources` button sits immediately below the ordered multiListBox. It selects all valid, currently listed source objects in the scene and highlights their corresponding rows. Deleted source references remain listed but are not selected. This action does not add/remove/reorder sources, change per-source trim sides, regenerate geometry, or alter the existing result. The button is disabled when no valid source object remains.

The source list continues to occupy the remaining vertical space above the fixed bottom button, with 12 px spacing and padding. The existing project-local `Surface-Intersections-UI.ini` stores floating-dialog location and height using the current DialogHost helper. Moving/closing continues to save its position; the title-button restart additionally saves current dialog state *before* reloading the entry script, ensuring the new dialog reads the latest coordinates. First launch restores the saved coordinates via `DialogHost.createManagedDialog`.

Acceptance in 3ds Max: add several sources, click Select All Sources, verify all valid source nodes and corresponding rows are selected while clip modes and ordering remain unchanged; verify deleted entries are ignored. Move the floating dialog, click its blue title button to restart, and verify the location and height are preserved. Close and reopen the entry script and verify location again. Test at default and minimum dialog height.

## 14. Slice gizmo local-rotation sliders (project 0.29)

The Surface-Intersections dialog now includes a compact, three-row, full-width Slice gizmo control with one native horizontal slider per axis X, Y and Z. All three range from -180° to +180°, center on zero, and act as relative local-axis jog controls. During dragging, only the change since the prior slider position is applied to the target modifier's `slice_plane.rotation` quaternion. After releasing, the slider returns to zero *without undoing* the rotation. The original quaternion is never replaced with Euler angles. Right-click/other operations on the source list do not affect these controls.

The target is the currently active `SliceModifier` in the 3ds Max Modify panel when available; otherwise the first `SliceModifier` in the single selected scene object's modifier stack. If neither exists, controls do not create a modifier and report the missing target through status. The UI handler delegates modifier selection and quaternion rotation to two backend methods (`getSliceGizmoModifier`, `rotateSliceGizmoLocal`). The backend does not depend on UI controls. Changes to the Slice gizmo retain the modifier and source object identity.

The three sliders are vertically stacked above the growing source-list area, leaving the existing Select All Sources button anchored to the bottom. Dialog default/minimum heights are now 820/812 px to preserve a usable list; existing smaller saved INI height values are raised to the minimum while the saved floating position is retained. Live runtime confirmation is required for local-axis behavior, scene undo, the Modify-panel fallback and UI event ordering.

## 15. Generated result Slice modifier (project 0.30)

The primary Slice target of the X/Y/Z jog controls is the generated **trimmed mesh result** (`Surface_Intersections_Trimmed`, backend `trimmed_result_node`), not any original source object or the separate curve result. On initial creation and every refresh, `makeTrimmedResult` reuses an existing Slice modifier on that result mesh or applies one if the result has none. It never stacks duplicate Slice modifiers. The mesh base object remains editable/rebuildable below its modifier stack.

`getSliceGizmoModifier` resolves the linked trimmed result modifier first, adding one if a valid existing mesh result lacks it. If there is no linked trimmed result, the prior compatibility behavior remains: an active Slice modifier in the Modify panel, otherwise the first Slice modifier in the selected node's stack. Add failures are reported to the MAXScript Listener, and original source nodes are never modified.

Manual acceptance: Generate / Update with two valid sources and check that `Surface_Intersections_Trimmed` has exactly one Slice modifier. Drag X/Y/Z and check that its Slice Plane gizmo rotates without moving a source node. Click Refresh repeatedly and confirm the existing modifier and its rotation survive without duplicates. Reopen the tool with a result already generated and confirm the sliders still resolve it. Confirm the separate curve result remains a spline. Test in 3ds Max; static inspection is not runtime certification.

## 16. Editable Poly topology and result buttons (project 0.30)

The generated surface is a true `Editable_Poly` base object, not an `Editable_Mesh` triangulation. `buildTrimmedPoly` creates one Editable Poly polygon for each finite surviving convex working patch. Vertices of neighboring patches from the same source are reused, while surfaces from different sources remain separate elements (no arbitrary cross-surface welding). Some polygons remain triangles if the underlying evaluated input patch is triangular; this version does not automatically dissolve all coplanar boundaries or manufacture missing topology.

The polygon mesh is constructed on a temporary scene node before commit. MAXScript's writable `.baseObject` allows the existing `Surface_Intersections_Trimmed` node to receive the new poly base without collapsing its modifiers. The same result node, Slice modifier, and Slice gizmo rotation therefore remain linked across refreshes. The builder reports invalid polygon creation and abandons the pending geometry rather than claiming a successful update.

Two buttons directly below the tool title are `Select Surface` and `Reset`. The first selects the current generated trimmed-poly result. `Reset` asks for confirmation, detaches monitoring, deletes **only** the two currently linked output nodes (curve and trimmed surface), and preserves the scene's source nodes. The source list is kept for a new Generate operation. Unbound results from earlier setups and unrelated scene objects are never deleted by Reset. If either deletion fails, references to remaining outputs are retained and a Listener message reports the failure.

Manual acceptance in a scratch scene: Generate with non-coplanar sources; inspect that the surface result's base is Editable Poly and that at least one trimmed polygon has 4+ sides when the patch geometry permits. Check shared source vertices and separate source elements. Select Surface should select the exact generated poly. Drag the Slice X/Y/Z sliders; refresh and confirm same node and Slice modifier with unchanged rotation. Reset must delete exactly the currently linked curve and poly nodes, leave all source objects intact, and permit Generate from the retained source list. Canceling Reset must change nothing. Restore scene/INI and test after tool restart. No real 3ds Max execution was available during static validation.

## 17. Intermediate result step inspection (project 0.31)

The sequential cumulative surface-trimming process now preserves every intermediate state as its own **Editable Poly** output: `Surface_Intersections_Step_01`, `Surface_Intersections_Step_02`, and so on. Step 1 contains the first source surface; Step 2 is the cumulative result of the first two sources; each later step includes the next source and all prior surviving pieces. Steps 2 and later also have separate `..._Curves` spline results containing the intersection lines among the surfaces in that stage. This allows inspecting actual progressively trimmed geometry and its intersections, rather than only the final output.

The UI has a compact **Inspect Step** dropdown below the title action buttons. `Final result` shows the tool's original generated surface and curve objects; choosing a numbered step hides other results, reveals that step's surface and curve objects, and selects the stage surface for Editable Poly inspection. The stage objects remain independent, scene-native nodes (not subobjects or snapshot arrays). Original sources and the existing final result remain unchanged.

A source-order/precision/clip-side refresh recomputes each step and updates existing stage node identities where possible; stage surfaces do not get extra Slice modifiers. The final result retains its Slice modifier and its own editable polygon topology. Each stage node carries owner-result handle, stage index and kind in user properties so `restoreStageNodes` can reattach intermediate results to the correct bound setup on scene reload. Reset deletes the current setup's linked intermediate stages along with its final spline and surface, but never input objects or another setup's result nodes. New Setup deliberately retains previous results and clears only the active link.

Stage geometry currently inherits the existing convex-patch clipping limitations: coplanar polygon overlap, arbitrary holes, watertight joining and topology-index stability are not guaranteed. Runtime tests in 3ds Max remain pending; a static check does not certify that the stage polygons or curves are valid for all inputs.

Manual acceptance: with four input planes, Generate should create four distinct step surface nodes and three distinct step curve nodes plus the original final two objects. Use the dropdown to inspect Step 1, Step 2, Step 3, Step 4 and Final, checking cumulative differences and selection. Move one source, Refresh, and confirm the old step node handles remain stable and results update. Swap source order and confirm stage labels and geometry change accordingly. Reopen the tool by selecting its saved curve result; linked stage nodes should be rediscovered. Reset should delete only the nine generated nodes (four steps, three step curves, two final outputs), preserving all sources and any unrelated nodes. Check minimum-height UI, empty selections, and disabled priority clipping.

## 18. Pairwise intersection curves only (project 0.32)

This section supersedes the v0.31 intermediate-step output workflow above. **Do not generate cumulative step surface objects** (`Surface_Intersections_Step_*`) or their step curves. Preserve the **single final Editable Poly** `Surface_Intersections_Trimmed`, its modifier stack and Slice gizmo; also preserve the original `Surface_Intersections` spline result because it owns the persistent source setup.

For geometry inspection only, compute one separate spline shape per ordered pair of **original evaluated source surfaces**, named `Surface_Intersections_Pair_01_02`, `..._01_03`, etc. Pair curves represent the finite raw intersections of that specific pair, not accumulated trim stages; nonintersecting pairs may yield an empty spline shape. The final Editable Poly still uses the entire existing cumulative clipping algorithm and remains displayed during pair inspection. The existing final combined curves appear when `Final result` is selected. Selecting another pair shows only its intersection curve and the always-visible final surface.

The UI dropdown is now **Inspect Pair**, not Inspect Step. Pair curves are tagged to the result handle and pair indices, allowing recovery after reopening a saved setup; existing pair nodes are updated in place on refresh. Legacy v0.31 step objects are **not silently deleted during regeneration**, because they may have been edited by the user; recognized old step objects are hidden on rebind, and a confirmed **Reset** can clean up only the current setup's owned legacy step nodes, pair curves, and final results. This scope excludes all source objects and other setups. `Use Selection` filters out tool-generated pair curves and recognized legacy steps.

Runtime acceptance in a scratch scene: with two source planes, Generate creates one pair-curve node, `Surface_Intersections`, and a single `Surface_Intersections_Trimmed` Editable Poly; there must be no new `Surface_Intersections_Step_*` nodes. With three source planes, there are three pair curves (including empty intersections), not three intermediate surface copies. Inspect Pair should select the chosen curve, hide other pair curves while leaving `Surface_Intersections_Trimmed` visible. Refresh must preserve pair node identities and the final trimmed surface's Slice modifier. Restart, rebind, Reset and changed source order require testing in 3ds Max; static review is not runtime certification.

## 19. Source-derived names and Slice end-pivot (project 0.33)

The linked **final** curve and trimmed Editable Poly result are automatically named from the original applied source nodes in their existing priority order. For two nodes named `surface_A` and `surface_B`, the curve becomes `surface_A+surface_B-curve` and the trimmed surface becomes `surface_A+surface_B`. More than two input nodes are joined with `+`. Rename occurs after successful Generate / Update, Refresh, and when rebinding a saved setup. No object is replaced or reparented and any native 3ds Max unique-name adjustment remains possible if names collide. Pair-inspection curves keep their existing separate names.

The final output curve may contain multiple splines. The Slice Plane gizmo origin follows the **last knot of the first open spline with at least two knots**. `getKnotPoint` is read under `in coordsys world`, then transformed into the Slice modifier's sub-object context using `worldPoint * getModContextTM(surfaceNode,sliceModifier) * inverse(surfaceNode.objectTransform)`. Assign only `slice_plane.position` on the existing modifier, not the node pivot or gizmo quaternion rotation. Placement is applied on Generate / Update, Refresh and saved-setup binding. A closed-only/empty curve has no endpoint, so retain the prior Slice position and report a skip in the Listener. Source nodes, final surface topology and pair inspection continue unchanged.

Runtime acceptance: create two orthogonal planes with distinct names, Generate, confirm both names and that the Slice gizmo center lies on the last knot of the first open result spline in world space; move/rotate one input, Refresh, confirm the gizmo tracks the new endpoint while retaining the X/Y/Z slider rotation. Test displaced and transformed final objects, multiple splines, no open splines, source rename, reordered/multi-source lists, bound-result reloading, and name collisions. Static validation alone does not certify correct 3ds Max behavior.


## 20. Visible-edge intersection and quad-only surface topology (project 0.34)

The source import uses `snapshotAsMesh` only as an evaluated geometry carrier. A hidden shared triangle diagonal (`getEdgeVis false` on both sides) between two coplanar, consistently wound triangles is removed by merging them into one convex four-corner working patch. Each reconstructed patch remembers its visible/invisible boundary flags for raw source-pair inspection. Any non-coplanar, nonconvex, inconsistent or unmatched triangle remains a working triangle and preserves its original edge visibility, not an invented quad.

All final cumulative and original pair-curve intersections use polygon-boundary tests, not triangle/triangle edge tests. For raw pairs, only edges flagged visible in the evaluated original source mesh can create a crossing candidate. Hidden triangulation diagonals are never a valid intersection endpoint. An actual intersection of two face interiors is still computed by intersecting visible boundary edges with the other finite polygon; this is not a rule to require pre-existing edges to overlap. Cumulative patch output uses newly created clip boundaries as real edges. Coplanar face-area overlap remains unsupported.

`buildTrimmedPoly` emits four-corner polygons only. Source quads survive as intact polygon faces. A trimmed convex patch with three or five-plus vertices is divided into quads using polygon centroid and edge midpoints. Every emitted face must pass `polyop.getFaceDeg == 4`; failure aborts the pending output. Internal MAXScript polygon point tests may use triangle fans, but no triangle fans are published to Editable Poly. This technique does not yet guarantee all-quad edge-flow optimality, regular grids, UV continuity, or a manifold boundary at every mixed quad/trimmed patch edge; adjoining faces may require topology stitching in a subsequent refinement. No source node is collapsed or modified.

The final `Surface_Intersections_Trimmed` Editable Poly retains its existing node identity, Slice modifier, source-derived name and gizmo location; the curve result retains its name and live link. The UI version is unchanged (0.22), because no controls changed. FN 0.11 -> 0.12, shared project 0.33 -> 0.34.

Acceptance (requires 3ds Max): Two crossing 1x1 plane quads should generate a continuous endpoint-to-endpoint curve, not a knot at either hidden triangle diagonal. Every output face must report degree 4. For a source quad not trimmed, check that it stays a single quad. Test clipped triangle/n-gon patches, deforming input meshes, recalculations, source names, and gizmo endpoint position. Verify that original objects and other setups' results are never touched. Static source/model checks do not count as runtime validation.

## 21. Editable Poly edge visibility retention (project 0.35)

The evaluated `snapshotAsMesh` data includes triangular faces and each face's three `getEdgeVis` flags. The triangle cache also now retains original mesh vertex IDs to avoid erroneously reconstructing a quad from overlapping but unconnected shells. Source quads may be reconstructed only across a shared, mutually invisible triangle edge. Original source nodes are never modified.

A four-sided Editable Poly output still needs temporary midpoint/centroid quad subdivisions when a trimmed patch has fewer or more than four corners. Those construction edges are **not** meaningful source topology. After all polygons exist on the pending Editable Poly, `restoreResultEdgeVisibility` classifies every `polyop.getEdgeVerts` edge by its world-space endpoints: a segment contained in a source `getEdgeVis=true` edge or a generated finite intersection segment remains **visible**; other generated edges become **invisible** using `polyop.setEdgeVis`. Both sets are verified by `polyop.getEdgeVis`. On failure, the temporary output is rejected before committing to the linked node. The original physical boundary may be segmented into shorter, collinear edges by trimming/quad splitting; visibility and geometric contour are kept rather than an identical vertex count.

This preserves the user's visible contour while keeping strict four-sided output polygons; it does not promise that MAX's internally triangulated render mesh contains no triangles. Acceptance in 3ds Max: two orthogonal Editable Poly quad sources, some hidden source edges, an input triangle pair evaluated from an n-gon, a visible user edge bisected by trimming, repeated refresh and Slice rotation. Inspect output with `polyop.getFaceDeg`, `polyop.getEdgeVis` and viewport Edged Faces. Check that real source edges and genuine intersection cuts remain visible, internal diagonals and quad center seams are hidden, and the linked result node/modifier persist. No runtime test was available during the source edit.

## 22. Ordered processing stack with result objects (project 0.36)

This section supersedes the v0.32 restriction against intermediate surface results. In the current workflow, *each completed trim operation must be a separate Editable Poly scene node*, interleaved into the original source list as a read-only result row. Given sources A, B, C, D the UI becomes:

```text
1. [SOURCE] A
2. [SOURCE] B
   1. [RESULT] A+B
3. [SOURCE] C
   2. [RESULT] A+B+C
4. [SOURCE] D
   3. [RESULT] A+B+C+D [LATEST]
```

A+B is passed to the next operation **as the complete prior cumulative patch geometry**, not by `snapshotAsMesh` of its generated scene node. Thus each source is evaluated once from its original source node, and result→result cycles/callback feedback are avoided. `buildCumulativePatches` saves working patch sets after each new source, while `updateProcessResults` publishes quads via the v0.35 edge-visibility-aware Editable Poly builder. Earlier result surfaces remain selectable, independently inspectable scene nodes; the latest surface is the active `trimmed_result_node` and retains its Slice gizmo positioning, naming, and modifier stack. The existing source-pair curve inspection and final curve result remain separate.

UI row selection maps display indices back to underlying original source references. Reordering, Remove, per-source kept sides and node-owned saved settings operate on original inputs only. Clicking a `[RESULT]` row reveals/selects its surface and hides other intermediate results; `Select Latest` reveals/selects the final process result. Normal `Use / Add` replaces source list from scene selection, Ctrl-click appends new unique selected original geometry nodes. When a new source is appended, `Generate / Update` rebuilds the processing sequence and appends another result object; Live updates subsequently refresh existing result nodes where possible.

Every processing surface carries `SI_ProcessOwner`, `SI_ProcessIndex` and `SI_ProcessKind` user properties for linked scene-reload recovery. Retired results following a reduction of source count are hidden rather than silently deleted; confirmed Reset may delete owned outputs but never original inputs. The final spline remains the setup owner and preserves the previous custom-attribute schema. Previous v0.31 stage copies remain legacy output nodes, not stack inputs.

Runtime acceptance: (1) A and B generate one quad/result plus the final curve; (2) Ctrl+Use / Add a C source and Generate: original A+B handle stays and A+B+C is a new latest surface; (3) select either `[RESULT]` row and verify it selects the corresponding scene object and displays that stage; (4) Select Latest selects A+B+C, with Slice modifier on the latest result; (5) move B, Refresh, and confirm both stage surface geometries update without spawning duplicates; (6) save/open the scene, bind its final curve and verify stack rows restore; (7) remove C, Generate, verify retired output is hidden but not deleted; (8) Reset deletes only this setup's owned output nodes, leaving all original source objects intact. Test face degree four and visible source edges on every stage. MAXScript runtime testing has not yet occurred.


## 23. Grouped selection controls (project 0.37)

The two scene-selection actions, **Select Latest** and **Select All Sources**, now sit side by side on one fixed row immediately below the resizable process stack. Select Latest shows and selects the newest cumulative Editable Poly result; Select All Sources selects original source nodes and their source rows. These are selection-only operations and do not modify input order, clipping, source geometry, or intermediate results.

The **Reset** command is now a full-width button below the title, separated from the grouped selection controls. The process list retains its existing position and height calculation, while the selection row remains anchored at the dialog's bottom on resize. No other control positions, callbacks, or saved state structures have changed. The backend remains FN 0.14; UI 0.23 -> 0.24. Runtime UI verification in 3ds Max remains pending.

## 24. Keep larger portion after finite surface intersection (project 0.38)

AUTO in the source-side dropdown now means **keep the larger area / remove the smaller area** for each pairwise trim operation, not orient toward the average source center. Area is calculated from the actual surviving, convex world-space patch polygons **summed over the entire source surface**. A perfectly even division has no unique smaller portion; AUTO keeps the positive cutter-plane side consistently. Explicit Positive and Negative retain their existing meanings; Off still disables that source's clipping effect.

When cutter patches are coplanar and consistently wound, a **real finite polygon-to-polygon intersection** must first exist. Once that is confirmed, the cutter's supporting plane divides the whole target surface, not just the vertical prism over the cutter's finite footprint. This addresses an observed failure mode: the old algorithm preserved "outside-footprint" portions beyond the cutter's edges and the result could look untrimmed. For nonplanar cutters, the established finite-footprint method remains, comparing the two candidate outputs by retained area for AUTO; arbitrary curved-region topologies remain experimental.

The reciprocal cumulative operation remains unchanged: at each step, the incoming surface cuts every pre-stage accumulated source patch set, while the previous complete result cuts the incoming source. Each generated process-stack surface is built from that operation's clipped patches (not from a snapshot of a result scene node). The source input nodes and their modifier stacks are never changed. Newly generated planar cut segments are tracked separately from source-visible edges so newly created trimmed boundaries are visible; hidden source triangulation and construction-only edges remain hidden. The final result and each intermediate surface continue to contain quad Editable Poly faces with visible source edges and actual cuts highlighted. The result name, curve, Slice modifier and grouped selection controls are unchanged.

Runtime acceptance: In a scratch scene, intersect two offset orthogonal finite planes such that one is divided into 20% and 80% regions. Generate; both surfaces should retain their respective larger regions (independently measured). Repeat with source order reversed and with intersecting planes centered at equal halves; confirm deterministic positive tie handling. Confirm a far-away nonintersecting plane trims nothing even if its infinite extension crosses another source. Verify result surface areas, quad degrees, source-edge visibility, A+B/C stack snapshots, Refresh identity, and source safety. Testing in 3ds Max is pending; static or Python geometric calculations cannot validate MaxScript runtime behavior.

## 24. Forward-call order safety (project 0.39)

MAXScript struct methods must not call an as-yet-undefined method name as an unqualified function. In v0.38, `setInspectionProcess()` was before `applyOutputVisibility()`, causing the runtime `Call needs function or class, got: undefined` on selecting an intermediate or latest process result (previous line 2611). The declarations are now ordered visibility before process-selection. Similarly, `stop()` is now declared before `deleteGeneratedResults()` uses it on Reset. No geometry, node identity, stack or UI behavior was intentionally changed. Backend FN 0.16; project 0.39; UI unchanged at 0.25. Static check passed; execute in 3ds Max to verify.

## 25. Deleted cached SplineShape recovery (project 0.40)

`makeSplineResult` can receive an old `result_shape` scene-node reference from the main live link or pair-inspection curve cache. In MAXScript a deleted scene node is not the same as `undefined`; `result_shape != undefined` is insufficient to guarantee validity. The backend now checks `isValidNode` before `numSplines`, `deleteSpline`, `addNewSpline`, or `updateShape` are invoked. If the cached shape no longer exists, it is cleared and the original `keep_empty` / nonempty segment policy decides whether to create a replacement spline node. A valid existing result is still updated in place, with the same modifier stack. Existing UI bindings, geometry, quad topology, slice behavior and original sources are unaffected.

Runtime acceptance in a scratch scene: make an empty SplineShape, retain it as a variable, delete it, and call `SurfaceIntersections.makeSplineResult #() precision result_shape:deleted_node keep_empty:true`. The call must return a valid newly-created spline node without an exception. Verify a valid cached spline shape is updated in place, and that an empty call without `keep_empty` returns `undefined`. Verify normal Generate/Refresh and pair-curve regeneration after deleting an output manually. No 3ds Max runtime test was available at patch time.


## 25. POLY-only finite intersections, Delete Trimmed (project 0.41)

The source processing stack is always cumulative: the previous stage patch set is used as the next stage input. Prior UI Cumulative and MESH/POLY controls have been removed. The backend defaults to POLY only and ignores the historical `priority_clipping` false path. The existing scene-owned source order, kept-side modes, pair inspection, output objects and Slice modifier remain.

The `Delete Trimmed` checkbox is enabled by default; off means cut the two finite surfaces along intersection curves, retaining both sides. On means remove the smaller-area side of each surface only when the actual finite intersection traverses a polygon from one boundary to the other. One open-ended/internal cut cannot divide a surface into two independent regions: in that case both portions are retained and the reason is logged. The tool never invents an infinite geometry-deleting extension of the finite curve.

`buildVisibleSourcePatches` now joins consistently coplanar convex evaluated triangle regions along shared mutually hidden seams into complete polygon boundaries by source vertex IDs. Actual finite intersection segment endpoints (including interior ones) are the only intersection knots inserted into the cut seam; hidden source triangulation diagonals never define curve endpoints. A topologically necessary invisible support seam can connect that finite cut to the original polygon perimeter; the visible edge is only the finite intersection. Quad-only output construction and EdgeVis restoration continue. Source objects are never edited. Concave and non-collinear multi-cut cases remain unsupported/partial, and must fail without incorrect face deletion.

Persistence: `SI_DeleteTrimmed` result user property and `DeleteTrimmed` INI key; old setup CA fields `priority_clipping` and `intersection_mode` remain for schema compatibility but are always stored true/POLY. New backend 0.18; UI 0.26; shared project 0.41. Test file `test/Surface-Intersections-Poly-Cut-Test.ms` is data-only and non-destructive. Geometry and MAXScript compilation inside 3ds Max are not yet certified.


## ONLY FINAL RESULT (project 0.42)

The `ONLY FINAL RESULT` checkbox (uppercase, checked by default) changes output publication, not the cumulative trimming algorithm. It publishes one **visible** final Editable Poly at the end of the processing stack; all cumulative patch stages still exist in memory for the next cut. Intermediate result nodes and pair-inspection curves are skipped, and tool-owned earlier outputs are removed after successful final construction. When the checkbox is cleared, each cumulative stage and pair inspection curve is materialized as before. When switching from final-only to full-stack mode, the prior last-result node is reserved for the new last stage to preserve its Slice modifier and identity.

The `Surface-Intersections` spline driver remains **hidden** in final-only mode. It contains saved source references, updates, and curve-derived Slice alignment. Consequently, final-only does **not** produce literally one scene node; it produces one visible trimmed surface plus an internal hidden controller. The generated result object is selectable and can be used to reload the setup because its `SI_ProcessOwner` points to that controller.

The option is persisted to `Surface-Intersections-UI.ini` (`OnlyFinalResult`) and to `SI_OnlyFinalResult` on the controller. Existing scenes default to enabled unless explicitly disabled. Unowned or original source objects must not be deleted. Testing in 3ds Max must verify toggling both directions, final node identity, source rebind after reopening, cleanup of owned nodes, and no dangling selection references after updates.

## Polygon intersection cut / Slice debugging (project 0.43 — implementation notes)

The actual finite polygon intersection segment is authoritative for the cut direction. A validated split generates two polygon boundaries with a shared topological seam; the same two fragments are passed to `buildTrimmedPoly`, so successful generation must not yield two unchanged attached source copies. Source-hidden triangulation edges are never candidate cut boundaries and are not a reason to discard a real intersection. For a shorter-than-chord finite curve, only the real segment is marked visible; invisible support edges close the polygon faces.

Only a true boundary-to-boundary finite cut may trigger smaller-area deletion. If Delete Trimmed is off, both split polygon regions survive. If an interior finite cut cannot be represented as two valid polygon regions, the program reports the error and does not publish an incorrect new result. The working algorithm still does **not** support all possible multibranch/concave/multi-direction curves on one polygon.

During debugging, generated results do not get a new Slice modifier or automatic Slice gizmo movement. The X/Y/Z Slice controls are disabled. Old Slice modifiers on already-generated nodes remain unless explicitly removed by the artist; Reset and fresh Generate create Slice-free outputs.

Acceptance: with two offset perpendicular quad source surfaces, inspect the final Editable Poly's topological edges at the true intersection. Delete OFF should preserve the full areas but produce two polygon regions on each source; Delete ON should retain the 70% and 80% larger pieces respectively. A real finite cut touching an invisible diagonal must not be dropped, and an extra vertex must not be introduced merely from the hidden diagonal crossing. Confirm no new Slice modifier appears on freshly generated results. Execute `test/Surface-Intersections-Curve-Cut-Test.ms` in 3ds Max for the data-only checks; the MCP bridge is currently unavailable.


## Piecewise curve cuts and whole-surface regions — project 0.44

Backend file 0.21 replaces the collinear-only cut path with finite-segment cell construction. The actual intersection endpoints are supplied to the polygon split, so nearly parallel supporting lines reuse known curve junctions rather than producing a second inaccurate point. Original surface vertices are not changed. Before deletion, the cell areas are compared with the original area using the existing position-precision/perimeter allowance; an invalid construction blocks publication.

Region connectivity is measured over shared edge intervals, across all original patches of a source. Only the real finite curve blocks a connection; invisible supporting extensions remain traversable. AUTO keeps the largest connected region independently within each original connected source component. A partial cut that does not disconnect a surface retains both sides; a disconnected component untouched by the cutter is preserved. Explicit Positive/Negative retain planar-cutter side behavior. Nonplanar explicit-side semantics remain limited; AUTO is the verified path for the supplied scene.

Before Editable Poly construction, adjacent cells receive matching edge corners. Multi-cell sources then use the same midpoint/centroid quad subdivision on all cells, including four-corner cells, preventing the T-junctions previously caused by mixing unchanged quads with subdivided neighbors. Construction-only edges remain hidden. Native IDs are created as one compound phase; dead topology is checked only after that phase, before fresh topology inspection. Source representations and modifier stacks are never compacted or edited.

Observed 3ds Max 2026 verification in `max/Surface Intersections.max`: original source handles 94811 (surface-1) and 94514 (surface-2); original areas approximately 7,613,570 and 5,081,070 scene units squared; retained areas approximately 7,412,260 and 4,597,080. Generated result: 336 quad faces, two connected surface elements, all 26 original finite intersection segments covered by result edges, zero unresolved cut errors. Manual Refresh succeeds and preserves the result node handle. These are rounded documentation values; the tests calculate with unrounded coordinates.

`test/Surface-Intersections-Curve-Cut-Test.ms` file 0.02 / project 0.44 adds a two-facet bent seam (expected retained area 60 of 100), reciprocal 80% retention, area conservation with Delete Trimmed OFF, and an untouched disconnected component. The optional `siCurveCutSceneTestRun()` reads the already-generated two-source scene to check quad degrees, two connected elements, full cut-edge coverage, and reduced areas of both sources. Both focused gates passed in Max. Broader multi-source, concave, coplanar-overlap, branching/self-intersecting, scene-reopen and asynchronous live-update behavior remain outside this verification.



## Visible-edge-only polygon output — project 0.45

User requirement: eliminate redundant vertices and new face-interior construction vertices; cut only the visible polygon edges. This supersedes the earlier quad-only output requirement. Backend 0.22 / project 0.45; regression test 0.03; UI unchanged. Project 0.44 was the prior user-confirmed stable baseline; project **0.45** is now the user-confirmed **STABLE** release (2026-10-31).

The cutter still computes temporary cells and whole-surface connected-region areas internally. Before publishing Editable Poly topology, it conforms shared cell boundaries, joins cells across construction seams and hidden source diagonals, and traces the resulting source-polygon boundaries. Only visible original boundaries and actual cut barriers separate published faces. The removed midpoint/centroid quad generator is no longer used or retained. Native construction is still one complete phase followed by the existing dead-topology synchronization boundary; sources and their modifier stacks are never compacted.

Evaluated warped quads can contain two noncoplanar triangles separated by an invisible diagonal. That diagonal must not introduce a new polygon cut vertex. Degree-two hidden-diagonal knots are removed from the published cut network and polygon boundaries, connecting the real visible-edge crossings directly. Thus the published polygon cut follows polygon semantics, rather than reproducing every bend in the evaluated hidden triangulation. This intentionally changes the interpolation within warped polygons. New cut vertices are validated against real visible source edges. Original source vertices remain authoritative. Unsupported branching/holes or non-visible endpoints are not covered by this fixture; boundary tracing reports an ambiguous boundary instead of inventing support vertices.

3ds Max 2026 verification on the same supplied geometry, now named Ellipse005 and Ellipse007: v0.44 produced 424 vertices / 336 quad faces, including 328 artificial midpoint/center vertices and 26 additional hidden-diagonal cut vertices across the two surfaces. Project 0.45 produces 70 vertices / 39 polygon faces, two connected surface elements, 13 of 13 visible-edge cut segments covered by visible output edges, and one controller spline with 14 knots. Every output vertex matches an existing visible-source-edge endpoint or a real visible-edge crossing. Delete Trimmed OFF regenerates successfully with 98 vertices / 65 faces; ON returns to 70 / 39. Both refreshes preserve result node identity. Focused data tests and the updated scene test pass. The scene test checks polygon validity (degree at least three), connectivity, visible cut coverage, and zero artificial or hidden-diagonal vertices; it no longer requires all quads.


## Generate / Update only — project 0.48

The user requires on-demand generation only. Backend 0.23, UI 0.31, test 0.04; shared project 0.48. The stable geometry baseline remains 0.45. Geometry algorithms, source ordering, trimming, visible-edge topology, and output node identity are unchanged.

Generate / Update is the only UI regeneration action. The former Refresh, Live, Manual and Freeze buttons are replaced by an informational label in the same row. UI defaults, INI loading, saved scene binding and persisted requested modes all resolve to manual. Old live/freeze values cannot reactivate monitoring. Editing source geometry, options or draft source order does not regenerate the output until Generate / Update is pressed.

The public legacy startLive name remains compatible but performs a single generation and leaves manual mode. setMode accepts legacy symbols but normalizes valid modes to manual and detaches previous resources. attachMonitoring only detaches old watchers; it registers no NodeEventCallback, transform handler, or timer. markDirty ignores notifications. The obsolete timer callback stops a remaining timer without calling refresh. The public refresh API remains for explicit programmatic generation; no UI control other than Generate invokes regeneration.

The active Max instance was switched to manual immediately. Native backend checks verify no watchers/timer, live/freeze compatibility normalization, and no scheduling by stale source notifications. Existing focused polygon geometry checks still pass. The regression file includes siDemandUpdateTestRun(), which runs without scene changes or changing the active setup. Static checks also ensure there are no automatic scheduling registrations or separate UI Refresh controls.



## Endpoint Slice implementation and verification — project 0.49

Files: FN 0.24, UI 0.32, regression test 0.05; shared project 0.49. The user confirms 0.48 as stable before this feature. Generate / Update remains the only tool regeneration action. Adding an owned Slice modifier to a source is an explicit exception to older source-stack invariants: original source geometry, transforms and existing modifiers remain unchanged, but a tool-owned shared Slice may be appended to the wider source.

The plan is derived from the evaluated finite source-pair cut, using triangle vertex-ID adjacency to identify genuine outer borders. Visible interior polygon edges are not outer borders; hidden mesh diagonals do not become borders. Closed chains and endpoints already on both borders need no Slice. An endpoint interior to both sources is ambiguous and is reported without choosing a source arbitrarily. Multiple eligible open ends can produce multiple separately owned Slice instances. The current implementation publishes them on the final result and their corresponding wider source; complex multi-source interactions are not certified by the two-source fixture.

Owned modifiers carry the `SI_EndpointSlice` custom attribute with stable owner/source/result identity strings and endpoint key, pivot and axis data. Node user properties retain matching identities. Ownership is never recovered from a display name or class. Keys avoid modifier-to-host node references, which would create native reference dependency loops. Exact attached nodes are resolved with `refs.dependentNodes`. Before caching source geometry on a subsequent Generate, only the current setup's exact owned Slice instances are temporarily disabled; their prior enabled values are restored on success or exception. This prevents recursive clipping and false border detection. Existing owned instances are reused; obsolete ones and Reset remove only exact owned references from their recorded hosts. Manual modifiers remain intact. No callbacks or live timers are registered.

World alignment uses `setModContextTM node slice_mod (node.objectTransform * inverse world_plane)` with an identity shared gizmo transform and translated world plane. Native Slice PlanarX/Y/Z selects the dominant world-axis normal; PlanarFlipX/Y/Z implements the outward sign. `Slice_Type = 2` and `Faces___Polygons_Toggle = 1`. UI result rows receive child `[SLICE]` rows; source row indices remain separate, protecting Add/Remove/reorder behavior. Clicking a Slice row selects its result and the exact modifier instance in the Modify panel without regenerating.

Reference inspection: `Surface Intersections Slice example.max` uses a world-X plane at approximately [2179.36, 837.812, 3577.81]. Its manual FRONT Slice is separate; the manual TOP and result share a different instance. These example modifiers were preserved. For native tests, two temporary copies were offset by [6000,0,0], with only the copied FRONT's example Slice disabled. The tool detected FRONT as the wider source and generated one shared Slice at [8179.36,837.812,3577.81], matching the reference offset. FRONT's world X maximum changed from approximately 8325.6 to 8179.36; the final result maximum was also 8179.36. Type 2, both world pivots/bases, exact instance sharing, duplicate-free regeneration and result identity passed. The tool remained manual. The `[SLICE]` row opened the exact shared instance. Reset removed the owned Slice from both hosts and preserved manual modifiers. Temporary test nodes were deleted and the original example binding restored. No original example Slice was edited or removed.

Focused polygon geometry, on-demand, endpoint-plan, and native Slice regressions passed in 3ds Max 2026. `siEndpointSlicePlanTestRun()` is data-only; `siEndpointSliceSceneTestRun()` requires an already-generated one-Slice test fixture and explicitly refreshes it once. Scene-file save/reopen of the new ownership data and arbitrary multi-source/branch/closed-surface cases remain unverified.


## Precision-safe polygon boundary reconstruction — project 0.50

Backend 0.25, regression test 0.06, shared project 0.50; UI remains 0.32 and reads the global version. Stable baseline 0.48 remains recorded. The supplied failure was reproduced in `Surface Intersections.max` with source order 02-surf-cabin-TOP + 01-surf-cabin-FRONT and the selected 0.1mm precision. Polygon construction failed at 0.1mm and 1mm, while 0.01mm succeeded. The selected setting is not overridden.

Root cause: distinct temporary support cells can share the same position-identity vertices at a supported coarser precision. They contributed duplicate directed boundary edges and internal reverse edges, so a region vertex could appear to have two outgoing boundaries. Support-line hits on original visible edges could also remain as unsupported construction corners rather than the actual edge/cut crossing. Re-intersecting the surviving temporary cells introduced false branches into the two-source output curve.

The publisher now resolves a construction boundary hit to existing source endpoints or true cut endpoints on its original visible edge, never to a new rounded position. If an edge has several candidate cut points, the closest actual crossing is selected; this is polygon-boundary routing, not a new snapping tolerance. It removes repeated consecutive vertex IDs and zero-length boundaries, cancels opposite edges internal to the same region, and emits each directed boundary once per region. Source positions, user precision, input transforms and the underlying cutting calculations are unchanged. Unsupported boundaries still fail with raw vertex/candidate coordinates, also exposed in `last_polygon_report`.

For exactly two sources, the published cut network is taken from the original finite source-pair polygon intersection. Temporary support-cell geometry is not re-intersected to define the curve. The existing multi-source curve path is unchanged and is not covered by this two-source fix.

Observed Max verification: both source polygon arrays reconstruct successfully at 1mm, 0.1mm and 0.01mm with Delete Trimmed ON (12 / 40 source polygon regions) and OFF (24 / 40). The actual reported 0.1mm generation then completed successfully and produced one owned shared endpoint Slice in manual mode. The expanded native regression invocation subsequently lost its MCP connection; its completion and its final vertex/branch assertions could not be confirmed. Static checks passed. Do not describe that interrupted suite as a pass.

`siPrecisionBoundaryTestRun source_values` performs native output construction, checks authoritative output vertices and absence of false curve branches, and deletes only its own pending test outputs. Optional `precision_values:` and `delete_values:` allow one bounded scenario per MCP call, e.g. `siPrecisionBoundaryTestRun SurfaceIntersections.source_nodes precision_values:#(0.1) delete_values:#(true)`. Default execution of the test file remains data-only; this native scenario is explicit. The reported scene is the regression fixture; no general coplanar, concave or arbitrary multi-source certification is implied.


## Cancel residual zero-area support loops — project 0.51

Backend 0.26, regression test 0.07, shared project 0.51; UI remains unchanged. Stable baseline remains 0.48. The new reported failure (`region:3 corners:1`) was reproduced at the selected 0.01mm precision in `Surface Intersections Slice example.max`, using 01-surf-cabin-TOP and 02-surf-cabin-FRONT.

The rejected loop had two raw vertices, approximately [169.598,671.904,4004.56] and [160.813,671.882,4004.68], and exactly zero polygon area. It was a forward/backward construction edge surviving the earlier duplicate pass, not a valid face that should have been simplified away. The fix normalizes duplicate/zero-length directed boundaries first, then cancels any remaining opposite edge pair inside the same resolved region before tracing polygons. Opposite edges between different regions remain genuine cut seams and are not canceled. Positive-area or otherwise unsupported polygon boundaries still fail; no area tolerance or precision override was added.

`cancelCollapsedRegionEdges` is shared by polygon construction and a data-only regression. The regression retains a four-edge outer loop while removing its duplicate/backtracking support excursion and a zero-length edge. A second case proves that an opposite edge pair across two different regions remains intact. Degenerate-loop diagnostics now preserve raw area and raw boundary points.

Observed native verification: both source polygon outputs reconstruct (12 and 40 polygons); explicit Generate and backend Refresh succeed at the reported 0.01mm setting, with manual mode retained and no polygon failure diagnostic. Full native output/vertex/curve checks pass at 0.01mm and 0.1mm with Delete Trimmed ON and OFF. Data-only geometry, on-demand, endpoint-plan and collapsed-edge regressions pass. The 1mm expanded curve check still fails on a separate short false branch near [561.101,675.225,3997.24]; polygon output builds there, but the full curve regression is not a pass. This pre-existing coarsest-precision curve issue remains open and must not be hidden by dropping an edge or changing the user's precision. A trial change to plane classification did not resolve it and was reverted; it is not part of this revision.


## Reject empty cut cells before region adjacency — project 0.52

Backend 0.27, regression test 0.08, shared project 0.52; UI remains 0.32 and stable baseline remains 0.48. The reported `Unknown property: x in undefined` at patchesShareUncutEdge/getPatchBounds was reproduced against the current 01-surf-cabin-TOP and 02-surf-cabin-FRONT geometry in `Surface Intersections Slice example.max` at 0.01mm.

A diagnostic preflight identified region entry 74 with zero corners. insertActualCutKnots had cleaned a collapsed construction fragment to `#()`, but cutPatchSetByActualCurves appended that empty array to cut_cells and still assigned it a source origin. labelCutRegions then compared it with a valid polygon; getPatchBounds returned undefined corners for the empty polygon, and the subsequent .x access failed.

The cut-cell factory now appends a polygon and its source-origin index only when knot insertion returns at least three corners. A legitimately cleaned empty fragment is omitted and logged with source patch index, original/cleaned corner counts, and active precision. Further knot-insertion passes stop on that empty fragment. A result with one or two corners is an invalid contract and aborts explicitly. `collapsed_cell_count` records omissions and resets for each generation. The existing whole-patch area-conservation check remains in place; no new snapping, precision override, or area tolerance is introduced.

The region graph also validates its polygon inputs once before adjacency processing and reports an explicit patch index/corner count if invalid data reaches it. It does not fabricate a bounding box, treat a failed geometry read as a valid disconnection, or hide the operation behind an empty catch.

Native reproduction and verification: the original code raised the .x error; the diagnostic probe identified `patch:74 corners:0`; the corrected factory omitted exactly one cell. Native result construction, Generate / Update and explicit Refresh all succeed. The generated base contains 36 polygon faces in this current fixture. Retained patch sets contain no entries with fewer than three corners, and manual update mode is preserved. Data-only polygon geometry, on-demand and collapsed-region-edge tests pass. `siEmptyWorkingCellTestRun source_values position_precision_mm:0.01` reproduces the affected fixture, requires at least one real cleanup collapse, checks every retained polygon and builds/deletes only its own temporary output. It does not replace the active result or delete source nodes. The previously documented separate 1mm curve-branch issue is unchanged.




















