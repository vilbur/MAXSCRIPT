## 2026-11-11 — Restore CUI docking and remembered left/right side (project 1.01)

- UI **0.70 → 0.71**, `Surface-Intersections-UI/DialogHost.ms` **0.01 → 0.02**; project **1.00 → 1.01** development. Backend **0.46**, CUI offset helper, actual source/result geometry, SMART mouse-release updates, saved hierarchy, and 288px layout are unchanged. Stable baseline remains **0.91**.
- Retain the tool-local CUI `style:#(#cui_dock_vert,#cui_floatable,#cui_handles)` and default floating dialog. Fix the restore path that previously left saved `SavedState=unregistered` rollouts unregistered, preventing user docking after reopening. Verify `.dialogBar` and the requested CUI dock state before reporting a successful open.
- Save `DockSide=floating|left|right` in the existing version-independent UI INI. Restore left/right with the native `cui.DockDialogBar` API. When docked, save only the dock side, preserving the last known registered floating position and dimensions. On a float, restore the existing corrected geometry through the unchanged fork helper.
- Record dock-state changes on move/resize, save before restart/close, unregister before destroying/reloading, and preserve a usable registered dialog if strict pixel-perfect geometry restoration fails on a different DPI or display. No initial forced side docking is applied when the setting is absent.
- Verification: native 3ds Max 2026 disposable-rollout CUI float→left→right→float→unregister cycle passed. Tool-host persistence/reopen test is in `test/Surface-Intersections-Docking-Test.ms`; interactive user-tool docking acceptance remains to be confirmed.

## 2026-11-09 — SMART mouse-release transform updates (project 1.00)

- **Project 0.99 -> 1.00; UI 0.69 -> 0.70.** Backend v0.46 and existing intersection, source/group hierarchy, Remove Result and FINAL actions are unchanged. Stable baseline remains v0.91.
- Added native **SMART UPDATE • MOUSE RELEASE** toggle between RESULT header and TreeView (288px width preserved; TreeView moves 30px down and its height is reduced by 30px). Off by default; saves to `SmartTransformEnabled` in existing UI INI.
- Register one UI-owned `NodeEventCallback mouseUp:true` only when SMART is on and the dialog is displayed. Watch source and native group transform snapshots; compare four Matrix3 rows rather than matrix reference identity. A queued node batch after mouse release marks only actual changed source ancestors pending. Use one-shot WinForms Timer to regenerate affected top-level group roots through the existing recursive `generateGroup`, rather than doing geometry work inside a callback or during mouse dragging.
- On toggle off, close and script reload, dispose timer and release callback. Prevent recursive callbacks during regeneration, restore monitoring baseline and preserve manual Generate/Update. The live synthetic and gesture runtime test are separate: release timing and full mesh result still need interactive validation.

## 2026-11-09 — Remove Result context action and closed-native-group visibility (project 0.99)

- UI 0.68 -> 0.69; backend 0.45 -> 0.46, project 0.98 -> 0.99. Preserve v0.98's short-cut geometry fix, entry scripts, UI layout, persistent scene-catalog schema and existing Generate/Update behavior. Stable baseline remains 0.91.
- Right-clicking a generated intersection result row offers **Remove Result**. The backend validates a source-preserving splice before deletion, detaches the result's directly linked native group helpers with their world transforms intact, deletes only that operation's owned output through the established deletion method, promotes the preserved child input rows to the same hierarchy level, marks any ancestor result pending, updates the saved catalog, and retains other generated results. Only the clicked result is targeted; the action requires confirmation. Failure leaves the hierarchy in place and reports the error.
- Visibility checkbox edits now affect only the clicked/highlighted scene objects. Generated result groups do **not** cascade visibility to children. A native **closed** 3ds Max group head remains the only cascading exception, toggling its listed members and nested native groups; an open group toggles only its own head. Visibility does not rebuild geometry.
- Added a non-destructive synthetic removal-plan and checkbox regression. Full live generation/deletion/parent-link checks require a disposable 3ds Max scene.

## 2026-11-09 — Close short cut gaps at hidden triangle corners (project 0.98)

- Backend 0.44 → 0.45 and Curve-Cut-Test 0.16 → 0.17. The stable baseline remains 0.91.
- In rover-285.max, the TOP/FRONT cut missed a 0.039 mm crossing at 0.1 mm precision. The uncut triangle joined both trim regions and kept the smaller TOP strip.
- When two usable spans meet at the same rounded endpoint across a patch with no usable cut span, resolve the short crossing before applying normal cleanup. Use the surviving cell only if exactly one side collapses at the selected precision.
- MCP verified Update on the original result node. The rebuilt result has 52 polygons and none of the five original selected face centers lies on it. All 13 regression checks passed.

## 2026-11-08 — Reset TreeView click selection and pin scene-group text pink (project 0.97)

- UI 0.67 -> 0.68; shared project 0.96 -> 0.97. Backend 0.44 and canonical entry unchanged; stable baseline remains 0.91.
- LMB selects the clicked row; CTRL+LMB adds/removes only that row. Scene selection expands result parents to all nested objects, and expands native group heads to their children only, excluding helper heads and duplicate targets. Shift-range and Ctrl-branch row highlighting are removed; Generate/Update still consume selected parent rows.
- Native scene group captions show square brackets only while their 3ds Max group is open. TreeView text is fixed pink RGB (240,118,177), independent of group helper wirecolor; generated result colors remain unique. Caption truncation handles both bracketed and plain names, and caption state refreshes on mouse entry.
- Updated the Tree-Branch-Selection model regression for v0.97. Native 3ds Max mouse and group-open tests remain pending because the MCP bridge connection was unavailable; do not count static checks as runtime verification.

## 2026-11-08 — Preserve independent sheets in nested result assembly (project 0.96)

- Backend 0.43 -> 0.44; Curve-Cut-Test 0.15 -> 0.16; shared project 0.95 -> 0.96. UI 0.67 and entry remain unchanged. **v0.91 remains the user-confirmed stable baseline.**
- Reproduced in rover-285.max through MCP: the two highlighted intermediate roots (11 and 12) resolve correctly, and clipping completes without cut errors, but parent polygon creation fails after 24 faces on a five-vertex polygon. Coordinate-only vertex reuse within one input mesh merges independent input sheets; an existing two-face seam then receives a third face.
- Cache evaluated source triangle components using original shared vertex IDs. Before visible-region reconstruction and Editable Poly vertex reuse, partition retained cells by their original source component. Locate cells with the existing convex-patch test and supporting-plane distance at the explicit selected position precision. Coincident coordinates do not connect separate components. Source evaluation, cumulative trim order, cut-extension logic, hierarchy schema, UI and on-demand behavior remain unchanged.
- Add siNestedResultElementsTestRun(): two connected triangles and an independent sheet share geometric edge coordinates. Backend 0.43 fails; 0.44 produces 3 faces, 7 vertices, 2 elements and the expected total area 150. The test deletes only its own temporary output.
- MCP verification: all 12 geometry/data regressions pass. Actual selected-root Generate creates parent 13 with children #(11,12), a visible 57-polygon result; Update succeeds in place with the same node and face count. Intermediate node transforms are unchanged. No scene reset or .max save performed.
- The optional dedicated geometry_qa endpoint was blocked by MCP safe mode; no topology-QA pass is claimed from that endpoint.

## 2026-11-08 — Native group brackets, group-head wirecolor and default cascade (project 0.95)

- UI 0.66 -> 0.67, project 0.94 -> 0.95 development. **v0.91 remains the user-confirmed stable baseline.** The backend 0.43, result geometry, native group relationships, saved catalog schema, 288 px layout, Generate and Update behavior are unchanged.
- TreeView native `#scene_group` captions use `[Group Name]` with full untruncated names in tooltips. Caption fitting preserves the closing `]` even for long names. Generated `#group` result names and their existing unique wirecolors do not change.
- A native group-head row's foreground reflects its actual helper node `wirecolor` (usually pink), rather than a hardcoded blue. Missing group nodes display a pink fallback but are not recolored. Original group helpers and scene source objects are never modified to set a color.
- Checkbox propagation now always includes every nested member of clicked/selected generated `#group` and native `#scene_group` branches, regardless of Ctrl state. Leaf-source clicks remain limited to the clicked/explicitly highlighted leaves. Deduplicate targets, use one undoable operation and continue to mirror effective viewport visibility; group selection Ctrl+click and Generate remain independent.
- Add a model-only regression for group/leaf visibility targeting, nested and multi-highlight cases, caption formatting and .NET color conversion. Runtime interactive checkbox and actual wirecolor checks remain pending for user acceptance.

## 2026-11-08 — Generate next-level mid-results and Ctrl-only visibility cascade (project 0.94)

- UI 0.65 -> 0.66; project 0.93 -> 0.94 development. **v0.91 remains the user-confirmed stable baseline.** Backend 0.43, entry, persistent catalog schema, scene-group links, 288 px layout, existing RMB FINAL and intersection algorithm remain unchanged.
- Enable normal LMB GENERATE with **zero TreeView highlights** whenever two or more independent top-level roots exist, even if those roots already have generated intermediate result meshes. Use `groupRoots` and the existing recursive `generateGroup` without importing the child groups' original sources as direct parent inputs. One sole existing result root is not wrapped again.
- Treat Ctrl-clicked groups' highlighted descendants as covered by the highest selected ancestor *for Generate resolution only*. Preserve their visible TreeView/scene selection and previous Ctrl-branch toggle behavior. Multiple selected top-level group results produce one new parent in root order; an uncovered nested or mixed-depth row remains invalid. One highlighted generated root does not implicitly regroup all other results.
- Make visibility propagation explicit: ordinary checkbox clicks toggle only the clicked node or highlighted rows; **Ctrl+checkbox** includes recursively collected children for every targeted `#group`/`#scene_group`. Deduplicate hierarchy IDs and scene nodes. Only local hide flags change in one undo step; visibility and geometry remain separate.
- Add non-destructive model-only regression for empty-selection next-level generation, Ctrl-selected branches, invalid nested selections, ordered roots and both visibility modes. Static checks completed; real generated geometry and mouse event timing still require native 3ds Max interaction before v0.94 can be regarded as stable.

## 2026-11-08 — Generate FINAL from all top-level groups with GENERATE RMB (project 0.93)

- UI 0.64 -> 0.65, project 0.92 -> 0.93 development. Stable baseline remains v0.91. The backend 0.43, entry, saved catalog schema, scene-group ownership and geometry algorithms are unchanged.
- Right-click **GENERATE** to collect every current root in source priority order, regardless of highlighted/checked tree rows. When multiple roots exist, use `SIHierarchy_v.groupRoots` and `generateGroup` to create one final parent operation. Each nested generated-result group is evaluated as its own result mesh by the existing postorder backend; a native scene-group helper is expanded to its original geometry. Loose roots are included rather than silently omitted.
- When the forest already has one top-level generated result, rebuild it **in place** without adding a redundant wrapper. A sole native scene group containing two or more surfaces is also valid. When no final target is possible, give an explicit status rather than generating nothing.
- Keep GENERATE enabled for a valid RMB final operation even when the current selection would disable its normal left-click action. Keep left-click's original selection-targeting behavior unchanged and use a separate `MouseUp` right-button handler and tooltips.
- A failed new parent restores roots/latest/item count and attempts to clean only the newly created parent's owned result. Previously generated child groups and original source geometry remain. Static and model-only regression checks cover both initial wrapping and repeated right-click idempotency. Full 3ds Max integration test remains necessary before calling v0.93 stable.

## 2026-11-02 — Ctrl+click selects complete TreeView hierarchy (project 0.92)

- UI 0.63 -> 0.64; project 0.91 -> 0.92 development. **v0.91 remains the user-confirmed stable baseline.** Backend 0.43 and the canonical entry remain unchanged.
- Ctrl+clicking a group (generated result `#group` or native group head `#scene_group`) selects its row and every listed descendant, including collapsed branches, and propagates their scene-node selection through the existing guarded TreeView selection path. A leaf Ctrl+click keeps its previous single-row toggle. Repeating Ctrl+click on a fully selected branch deselects the complete branch; partial selection first expands to the full branch. Selection of unrelated branches remains additive.
- Preserve normal single-row click, Shift/Ctrl+Shift range handling, viewport visibility checkboxes, scene-to-tree synchronization, Generate/Update target validation, current 288px layout, and all backend geometry. Selecting an ancestor and child explicitly does not turn into a valid new GENERATE root selection.
- Add a read-only hierarchy-selection regression that checks complete branch membership, additive selection, whole-branch deselection, partial expansion, and leaf toggles. Live interactive mouse testing remains required before marking v0.92 stable.

## 2026-11-02 — Mark Surface Intersections project 0.91 STABLE

- **User-confirmed stable baseline: v0.91**, superseding v0.86. UI file 0.62 -> 0.63 updates release metadata only; backend 0.43, entry 0.09, geometry processing, UI callbacks, native group handling, and layout remain unchanged.
- The previous v0.91 development entry records 11 passing geometry/data checks and an actual CABIN Generate test in 3ds Max 2026 (TOP + FRONT + BUMPER, 0.1 mm, 52 base polygons). These are existing recorded results, not new tests run for this stable designation.
- README and design now identify v0.91 as stable. No new geometry or scene mutations are introduced by this release-status synchronization.

## 2026-11-02 — Generate CABIN without a false continuation branch (project 0.91)

- Backend 0.42 -> 0.43; curve-cut test 0.14 -> 0.15. UI 0.62 unchanged; v0.86 remains the user-confirmed stable baseline.
- Reproduced in rover-279.max on native CABIN (TOP, FRONT, BUMPER) at 0.1mm. Generation reached stage 3, then traceCutEndpoint rejected two apparent outgoing section points: one was only 0.000246041 scene-mm from the cursor, the other approximately 2.9998mm away.
- The tiny point straddled a quantization-cell boundary, so position identity classified it as distinct. Require a section continuation to exceed the selected position_precision, matching the existing usable-cut segment contract. Ignore the unresolved stub without changing source positions, selected precision, or genuine branch failures.
- Add siContinuationStubTestRun with the actual 24 source triangles and terminal points from the failure. It fails before the change and passes after it. All eleven geometry/data checks pass in Max 2026.
- Actual Generate now creates visible TOP+FRONT+BUMPER with 52 base polygons. CABIN member world transforms are unchanged; the existing SIDE result remains in the hierarchy.

## 2026-11-02 — Restore Generate with automatically selected scene-group descendants (project 0.90)

- UI 0.61 -> 0.62, project 0.89 -> 0.90. The backend 0.42, dialog-position helper, Generate handler, 288px layout and saved hierarchy schema are unchanged.
- Regression identified in the scene-selection synchronization introduced at v0.87: when a native group head and its member nodes are selected together, tree highlights can include a parent and its own children. `siUiGetGenerateAction` rejects that as a mixed ancestor/descendant request, disabling GENERATE despite valid top-level input groups.
- Normalize only **automatic scene-originated** TreeView highlights by removing a selected descendant when its ancestor is also present; do not change scene selection. Deliberate mixed parent/child selections made directly in the TreeView continue to be rejected. Keep multi-root source processing order and direct click behavior unchanged.
- Add read-only `siGenerateSelectionTestRun()` to check parent/child collapse and report the current Generate action/availability. Static regression checks pass; 3ds Max runtime execution unavailable because the connected bridge session terminated.

## 2026-11-01 — Fork confirmed registered-dialog position correction (project 0.89)

- Fork the separate **Registered-Dialog-Position-Offset-Fix** project's confirmed v0.04 backend into `Surface-Intersections-UI/SIRegisteredDialogOffset.ms`, renaming the struct/global to `SIRegisteredDialogOffset_v` / `SIRegisteredDialogOffset`. Keep source corrections `[6,-2]` before registering and `[-8,0]` after unregistering. The reference project and original code remain unchanged.
- UI 0.60 → 0.61; DialogHost fork v0.01; project 0.88 → 0.89. Preserve every 288px rollout control, callback, geometry backend 0.42 and scene model. The CUI helper handles state/size/position in the existing tool INI; legacy PosX/PosY/Height values migrate from previously registered floating coordinates, and initialization movement no longer overwrites saved geometry.
- Do not call `setDialogPos` while registered. Skip saving transient positions during registration/destruction and docked movement; CUI owns docked edge locations. Position-offset measurements are environment-specific; regression test must be executed in 3ds Max before claiming a runtime pass.

## 2026-11-01 — Selection/action rows below tree and cascading group visibility (project 0.88)

- UI 0.59 -> 0.60 and project 0.87 -> 0.88. Backend 0.42, canonical entry, geometry processing, 288 px width, native Symmetry controls, live scene-selection synchronization and catalog schema remain unchanged. v0.86 remains user-confirmed stable.
- Tree begins at y=312 beneath RESULT. At default and all vertically resized heights, ADD / REFRESH / ↑ / ↓ sit 12 px below the expanding tree; LATEST / SOURCES remain the next row, 12 px below the first and 12 px above the dialog bottom. Tree height is dialog height - 400; minimum height is 620 px.
- A checkbox on a result group (#group) or native scene group (#scene_group) applies the requested visibility to that item and all its hierarchy descendants. Multi-highlight clicks expand each highlighted group, deduplicate overlapping tree IDs and actual nodes, and apply one undoable visibility operation. Leaf-only clicks still affect a single node. Layer/category display state is left untouched; checkbox readback remains based on effective viewport visibility.
- Add a focused layout and group-visibility regression test. Full production-scene UI behavior requires interactive verification in 3ds Max.

## 2026-11-01 — Synchronize scene selection into the tree (project 0.87)

- UI 0.58 -> 0.59; tree selection/color test 0.02 -> 0.03. Backend 0.42 unchanged; v0.86 remains the user-confirmed stable baseline.
- Register one nonpersistent selectionSetChanged callback while the dialog is open and filter selected nodes against the current listed objects. Mirror single/multiple selection, clearing and selections containing only unlisted nodes into tree highlights, focus and action state without changing scene selection or geometry.
- Preserve tree-originated single/Ctrl/Shift gestures with a reentrancy guard around the existing scene-selection write. Ignore transient tree rebuilds. Remove the exact callback on close and before reload; synchronize the initial selection on open. No timer, polling or mesh regeneration is added.
- Add siSceneSelectionSyncTestRun with temporary listed/unlisted source planes, native select/clear events, Ctrl gestures and scene-selection preservation. Replace the older color test's obsolete exact-version gate with a capability check.
- Both selection/color and native selection-sync regressions pass. The real native SIDE group maps to its listed head and members. Close/reopen detaches and reinstates the callback correctly; result-node identity and face count remain unchanged.

## 2026-11-01 — Mark v0.86 stable

- User confirmed v0.86 as the stable baseline following successful parent Update after moving/scaling the SIDE group.
- Stable components: backend 0.42, UI 0.58, entry 0.09. Update README and design release status only; no code, geometry or version values changed.

## 2026-11-01 — Complete Update after SIDE group transforms (project 0.86)

- Backend 0.41 -> 0.42; curve-cut test 0.13 -> 0.14. UI 0.58 and its current layout/visibility behavior remain unchanged. v0.80 remains the user-confirmed stable baseline.
- Reproduce in Surface Intersections Slice example-002.max: SIDE's child operation rebuilds with its moved/nonuniformly scaled native group, but the parent operation fails with SI CUT INVALID (positive corners:3, negative corners:0). The old parent mesh is retained because generation failed, giving the appearance that Update ignored the transform.
- cleanWorkingPatch deliberately returns no cell when a fragment collapses under the caller's position precision. Accept that existing contract when the other split side is valid: retain the cleaned surviving side, count/log the collapsed side, and continue the finite cut. Preserve the fatal path when neither side is valid. No new epsilon, precision changes, source transforms or native topology operations are introduced.
- Added a data-only regression using the actual failing thin SIDE triangle and cutting plane. It fails before the fix and passes afterward.
- Actual Update at 0.1mm succeeds: same parent node, 43 base polygons, bounds now extending to Y=4855.3 rather than the stale Y=3681.75; SIDE members and native group world transforms remain unchanged.
- Ten geometry/data checks and three hierarchy checks pass in Max 2026.

## 2026-11-01 — Tree visibility checkboxes and selection row beneath the tree (project 0.85)

- UI 0.57 -> 0.58, project 0.84 -> 0.85. Backend 0.41 unchanged; user-confirmed stable baseline remains 0.80.
- Move LATEST/SOURCES from above the TreeView to the fixed row beneath it. Tree begins at y=350, with height absorbing vertical resize; buttons remain 12 px below the tree and 12 px above the client bottom at default/min/max heights. Preserve all other control positions and 288 px width.
- Tree checkbox state now reflects actual `isHiddenInVpt` visibility of each referenced source, scene-group helper, or generated result. Clicking a checkbox changes only the referenced scene node's `isNodeHidden` flag (or all highlighted rows), in one undoable operation. Do not unhide layers, change geometry or change hierarchy membership. Warn when other viewport display conditions prevent visibility.
- Remove checkbox membership from Generate/Update and kept-side editing. Highlighted rows continue to drive operations; zero/one-root implicit Generate and single native-group Generate are retained. Blank selection updates all top-level generated results.
- Synchronize visibility from scene on tree rebuild, on hide/unhide callbacks and mouse entry. Remove callbacks when the dialog closes. Geometry engine and saved scene catalog schema are unchanged. Native interactive test pending; static tests and read-only runtime layout smoke checks documented separately.

## 2026-11-01 — Native Symmetry X/Y/Z checkbuttons (project 0.84)

- UI 0.56 -> 0.57, project 0.83 -> 0.84. Backend 0.41 and the 288px RESULT section layout are unchanged. v0.80 remains the last user-confirmed stable baseline.
- Replace the three WinForms checkbox-as-button axes with native MaxScript `checkButton` controls at their identical positions and sizes. Keep independent X/Y/Z mask bits (1/2/4), existing saved INI and group settings, and the `siUiApplySymmetryControls()` / `siUiSyncSymmetryControls()` behavior.
- Use native `changed` handlers rather than .NET `CheckedChanged`, native per-axis tooltips, and red/green/blue `highlightColor` when pressed. Remove the obsolete WinForms axis styling. Native buttons follow the 3ds Max text theme; custom RGB font coloring is not supported by this control.
- Add a non-destructive read-only native-UI regression for checkbutton control types, positions, state toggle, and mask. Static checks pass; runtime/visual MaxScript verification remains pending.

## 2026-11-01 — Native scene-group support (project 0.83)

- Backend 0.40 -> 0.41, UI 0.55 -> 0.56, project 0.82 -> 0.83; preserve the current 288px RESULT section layout. User-confirmed stable baseline remains 0.80.
- Import native 3ds Max group heads as `#scene_group` hierarchy branches, preserving child/group references while flattening only original geometry inputs during cumulative generation. The group helper itself is never sampled as a mesh.
- Permit GENERATE for a single native group containing at least two geometric surfaces. After generation, link the native group head beneath the generated result in the scene, and display the matching hierarchy in the TreeView.
- On explicit UPDATE, reconcile newly added/removed native members. Persist group head identity and its previous scene parent in the existing catalog. On RESET, restore prior parent links before deleting any generated result objects.
- Added `Surface-Intersections-Scene-Group-Test.ms` to cover native import, two-to-three surface update, stable result identity, catalog load, and safe reset. Static source/layout checks pass; full native runtime geometry tests remain pending.

## 2026-11-01 — Generate all with one root selected (project 0.82)

- UI 0.54 -> 0.55; hierarchy test 0.04 -> 0.05. Backend 0.40 and RESULT layout unchanged; v0.80 remains stable.
- Extend the implicit all-roots Generate action to a single highlighted or checked top-level item. Combine checks/highlights to require at most one distinct selected item; nested selections and differing checked/highlighted items do not qualify. Explicit multi-root grouping remains unchanged. At least two roots and no existing top-level result remain required.
- Native regression fails before the change for both single highlight and single check. Empty selection, single highlight, single check and hierarchy model checks pass after the change; existing results still prevent implicit regrouping.

## 2026-11-01 — Stable v0.80; Generate all initial roots (project 0.81)

- User marked v0.80 stable, including the RESULT section arrangement. Record it as the current stable reference; retain v0.66 as historical geometry baseline.
- UI 0.53 -> 0.54; hierarchy test 0.03 -> 0.04; project 0.81. Backend 0.40 unchanged.
- With neither checked nor highlighted rows, Generate uses all top-level roots in order when there are at least two and no existing valid top-level group result. Explicit checked/highlighted inputs retain precedence; an existing result prevents implicit regrouping.
- Added siEmptySelectionGenerateTestRun: actual Generate from three unchecked/unhighlighted source roots succeeds, consumes all three and refuses implicit regrouping after a result exists. The regression fails before the UI change and passes after it. Five focused hierarchy checks pass in Max 2026.

## 2026-11-01 — Move bottom controls into RESULT section (project 0.80)

- UI 0.52 -> 0.53. Add a visual RESULT group directly below the dropdowns; move trim options, Generate/Update, Symmetry axes and result information into it in their existing order.
- Move Add/Refresh/Up/Down and Latest/Sources below RESULT, followed by the expanding tree. No bottom action strip remains. Keep existing control types, sizes, callbacks and backend 0.40 unchanged.
- Native loading and minimum/default-height layout checks pass; result node and mesh face count remain unchanged. Stable baseline remains v0.66.

## 2026-11-01 — Match supplied UI layout (project 0.79)

- UI 0.51 -> 0.52; project 0.79. Backend 0.40 unchanged.
- Change control positions/sizes only: Add/Refresh plus existing .NET arrow Up/Down, Latest/Sources above the tree, trim options below the tree, then Generate/Update, Symmetry axes and the result-info button. Default client size 288 x 852; retain the 620 minimum and vertical resizing.
- Keep control types, captions, colors, tooltips, handlers, selection, persistence and every geometry operation unchanged. The entire rollout event-handler section is byte-identical.
- Verify non-overlapping layout at heights 620/852/1000 and unchanged result-node identity/face count. No generation or geometry test is needed for this layout-only change. Stable baseline remains v0.66.

## 2026-11-01 — Rebuild groups containing newly added sources (project 0.78)

- Preserve v0.77 membership/pending handling: the next Update consumes every current child, builds N-1 cumulative stages and updates the existing result node. Backend 0.39 -> 0.40; curve-cut test 0.12 -> 0.13; hierarchy test 0.02 -> 0.03. UI 0.51 remains unchanged.
- Reproduced the reported apparent stale mesh: the tree already contained TOP, FRONT and BUMPER, while the last successful mesh was TOP+FRONT. At the saved 0.1mm precision the three-source rebuild aborted with two SI CUT INVALID reports, so the existing mesh was correctly retained.
- Root cause: buildVisibleSourcePatches used position identity precision as permission to flatten slightly warped evaluated triangle pairs into a supporting polygon. Keep their original triangulated geometry unless they are actually coplanar. Position identity still uses the explicit selected precision; no source vertex is moved, no tolerance is increased and no automatic finer-precision fallback is added. Final polygon reconstruction continues to remove hidden construction diagonals.
- Native actual Update now succeeds at the saved 0.1mm: TOP+FRONT+BUMPER, three sources, two cumulative steps, 52 polygons, same scene-node handle.
- Add siWarpedSourcePatchTestRun (planar versus warped source pairs; fails before this fix) and siHierarchyAddedSourceTestRun (generate two sources, append the third without live mesh changes, Update, assert area 300 and stable output identity).
- Nine geometry/data checks, four hierarchy checks and the existing root Symmetry modifier check pass. The legacy siSymmetryAxesTestRun returns false because it hardcodes UI 0.43/project 0.67 and old layout expectations; retain it unchanged as a known outdated test. Stable baseline remains v0.66.

## 2026-10-31 — Symmetry checkbuttons and independent axes (project 0.67)

- Branch from user-confirmed stable project **0.66** (backend 0.34, UI 0.42). Advance backend to **0.35**, UI to **0.43**, project to **0.67**. Preserve v0.66 TOP–FRONT continuation/precision fix, hierarchy grouping and all existing result identities.
- Use three separate rows: Up/Down/Remove/Debug; Refresh/Add (72×24 each); Symmetry plus native X/Y/Z checkbuttons. Dialog 360×676 by default, minimum height 620; vertical tree resizing and existing button colors retained.
- A selected highlighted top-level result group (or multiple highlighted top-level result groups) receives Symmetry settings. When **no tree row** is selected, apply to all generated top-level groups. A selection containing only source/nested rows must not silently target all. Checked rows for grouping remain independent from highlighted selection.
- A native Symmetry modifier supports only one axis at a time. Add one **tagged tool-owned Symmetry** per checked axis (X=.axis 0, Y=1, Z=2); X+Y+Z creates three separate modifiers. Existing exact owned axis instances and their mirror gizmos are reused. Artist-created Symmetry modifiers are not modified or deleted. An enabled artist-created Symmetry on a nested child causes an explicit failure rather than quietly affecting a parent intersection.
- Before any Generate/Update, temporarily disable exact-owned modifiers for all groups so parent inputs are unsymmetrized. After a successful update, apply/re-enable the configured axes on the top-level result objects and remove only exact-owned Symmetry modifiers from lower levels. On generation failure, restore prior enabled states without deleting the existing gizmos.
- Persist per-group toggle and axis mask as result-node user properties, with global UI defaults in the local INI, without changing the existing catalog attribute schema. The backend is otherwise unchanged from stable v0.66; no Slice modifiers or automatic generation are reintroduced.
- Added read-only `siSymmetryAxesTestRun()` / `siSymmetryRootTestRun <item_id>` tests. Structural/source checks passed; runtime/native UI verification still required in 3ds Max. Development build, **v0.66 remains user-confirmed stable**.

## 2026-10-31 — Mark v0.66 stable

- User confirmed v0.66 as the stable baseline after the TOP–FRONT extension correction.
- Mark README and design accordingly. No code, geometry, tests, or version values changed.

## 2026-10-31 — Preserve forward TOP–FRONT extension (project 0.66)

- FN 0.33 -> 0.34; curve-cut test 0.11 -> 0.12. Preserve UI 0.42, hierarchy state and native modifier stacks.
- Compare the canonical v0.60 backend revision against current: traceCutEndpoint and extendCutSegmentsToBorder were unchanged. In the reported source geometry, 0.1mm extended FRONT toward x=2300; 0.01mm retained a reversed terminal stub whose endpoints straddle adjacent quantization cells, so continuation incorrectly crossed the surface toward x=0.
- Apply the cutter's existing segment-length > position_precision rule before degree/direction resolution and before returning completed cuts. Sub-precision stubs were already skipped by polygon cutting; they must not remain in the extension graph or construction-knot set. Do not change precision, snap source geometry, add a tolerance, or add Slice modifiers.
- Regression siTerminalStubExtensionTestRun fails before this fix and passes after it. Native fresh three-source generation and actual Group 8 Update both create 52 polygons and extend FRONT to the right border, matching the working v0.60 direction.
- Eight data/geometry checks plus five hierarchy/UI checks pass in Max 2026. Retain v0.65's diagnosed collapsed-region guard for other construction slivers.

## 2026-10-31 — Rebuild precision-collapsed cut slivers (project 0.65)

- FN 0.32 -> 0.33; curve-cut test 0.10 -> 0.11. UI 0.42 and entry remain unchanged.
- Reproduced the reported region 36 failure in the active seven-source scene: the raw loop has area 0.00372131, two terminal points straddle adjacent 0.01mm quantization cells, and removal of the hidden diagonal corner leaves two visible corners.
- When a simplified loop has fewer than three corners, test every raw corner against its longest raw span using the existing explicit position-precision segment contract. Discard only a construction boundary that is collinear at that precision, with raw area and precision diagnostics. A non-collinear invalid loop still fails. No area threshold, new epsilon, source snapping, hidden-diagonal vertices, or automatic Slice is added.
- Fresh native generation from the exact failing two sources now creates a valid mesh; the three-source group creates a visible 64-face Editable Poly. Add the optional siSourcePolygonGenerateTestRun source_values position_precision_mm:0.01 regression, which leaves its owned output for inspection. Loading the test file defines this function; the normal entry does not load tests.

## 2026-10-31 — Restore Generate from highlighted tree groups (project 0.64)

- UI 0.41 -> 0.42; hierarchy test 0.01 -> 0.02; tree selection/color test 0.01 -> 0.02; shared project 0.64. Backend FN 0.32 and entry 0.09 remain unchanged. Preserve newer UI sizes/colors and native Symmetry stacks; v0.60 remains the reference for the previously working grouping flow.
- Reproduce the no-visible-change case: highlight two generated root groups with Ctrl, press Generate, and v0.63 updates only the focused group instead of creating their parent. Resolve inputs from checked roots first or highlighted roots otherwise. Keep the single focused-group Update path and reject invalid ancestor/child combinations without mutating the forest.
- Use one Generate action resolver for click execution and UI presentation. Keep source/input order from the hierarchy, independent of selection-click order.
- Fix saved numeric-marker recognition for hierarchy catalog and result color tags. Native readback returns Integer 1 for the stored text `"1"`; accept both representations, preserving existing wirecolors and allowing selected results to locate their saved catalog.
- Native regression: checkbox grouping, Ctrl-selected parent generation, catalog lookup, invalid-input rejection, output reuse and source-safe cleanup pass. An enabled native Symmetry modifier survives regeneration as the exact same instance. Four hierarchy tests and the selection/color test pass; no application restart/reopen claim.

## 2026-10-31 — Tree multi-selection and per-result wirecolors (project 0.63)

- UI 0.40 -> 0.41, project 0.62 -> 0.63; backend FN 0.32 and canonical entry unchanged.
- Ctrl/Shift selection model with independent scene selection, separate Generate Group checkboxes, result foreground colors matching scene wirecolors, and stable one-time vivid colors per result. Do not recolor source nodes or regenerate geometry on selection.
- Add read-only scene-selection regression `test/Surface-Intersections-Tree-Selection-Colors-Test.ms` v0.01; restore artist selection after testing. Preserve the v0.62 compact 72 x 24 button layout.

## 2026-10-31 — Align Add / Refresh to 72 × 24 px (project 0.62)

- UI 0.39 -> 0.40; project 0.61 -> 0.62. Backend FN 0.32 and entry 0.09 remain unchanged.
- Keep both colored WinForms controls on y = 248: Refresh pos [148,248] size 72 × 24 px; Add pos [224,248] size 72 × 24 px. Leave a 4 px gap. No other action button is moved.
- Preserve blue Refresh, orange Add, dark style, tooltips, existing handlers, selection/hierarchy and manual-update behavior. No geometry code or native source objects changed.
- Update read-only `test/Surface-Intersections-Action-Buttons-Test.ms` to v0.02; check exact sizes, common y, 4 px separation, no Debug overlap and original RGB colors. Static tests pass; runtime visual testing remains pending.

## Current development — project 0.61: visible action buttons and orange Add (2026-10-31)

UI-only polish on the canonical project 0.60 hierarchy editor: UI 0.38 -> 0.39, project 0.60 -> 0.61. The backend FN 0.32, entry 0.09, source groups, and geometry algorithms are unchanged. Replace the native cramped 32 × 24 Add control with a 60 × 36 WinForms button bearing orange RGB(244,166,74) text; preserve append-only source behavior. Refresh remains a blue RGB(96,180,255) WinForms button but grows from 55 to 80 px wide so the bold label is readable. Both use the shared dark button style, centered text, and existing click semantics.

Expand the fixed editor width from 288 to 360 px to retain one action row with useful button widths and 12 px side gutters. Shift the status/result/tree block down 12 px to maintain clearance under the taller Add button. Keep the same 620 px default and 548 px minimum height and the vertically resizable tree. Do not add dynamic multi-window cloning or automatic regeneration. The new read-only `test/Surface-Intersections-Action-Buttons-Test.ms` validates button captions, RGB values, minimum sizes, and dialog geometry. Live visual inspection is pending, especially in the user’s 3ds Max theme/DPI configuration.

## 2026-10-31 — Explicit result hierarchy in a .NET TreeView (project 0.60)

- Update from canonical v0.59. FN 0.31 -> 0.32; UI 0.37 -> 0.38; shared project 0.60; entry unchanged. The existing polygon intersection algorithms remain unchanged.
- Replace the flat list with a static WinForms TreeView. Checked top-level inputs create an explicit result group; select one group to update it. Expand results to inspect original surfaces and child operations. Up/Down reorders siblings; Remove dissolves top-level groups without deleting scene geometry. Refresh retains generated groups while replacing loose source rows from selection.
- Generate independent three- and four-surface results, then combine those two actual output meshes in a parent intersection. Dependency updates are on demand, preserve native result identity and mark higher ancestors pending when updating a child alone. Reject cycles, shared descendants and mixed ancestor/descendant grouping.
- Store source/result/controller references, roots, membership and group options on a separate hidden scene catalog. Support rebinding from a selected result and migration of legacy flat results. Retain separate forests through the result button's CTRL-click/right-click workflows, without runtime multi-window cloning.
- Keep automatic Slice disabled, native source stacks unchanged and v0.53 result layers. ONLY FINAL RESULT now hides child operation results while keeping current root results visible. Reset cleans exact-owned results even when a hidden controller was manually deleted. Add a tool-local canonical DUMP logger fork.
- Added `test/Surface-Intersections-Hierarchy-Test.ms` 0.01. Model, native geometry, .NET event workflow and missing-controller cleanup tests pass; existing seven geometry/manual-update checks also pass. Verified native parent area 650, child mesh inputs, stable node handles and catalog readback. Full application restart/scene reopen remains unverified. No production scene was reset; tests deleted only their own nodes. v0.52 remains the last confirmed stable baseline.

## 2026-10-31 — v0.59 crash recovery: single compact editor

- UI 0.36 -> 0.37, shared project 0.58 -> 0.59; backend FN 0.31 and entry 0.09 stay byte-for-byte unchanged.
- Fix the reported startup `Call needs function or class, got: undefined` in `siUiBindResult`: remove the `siMultiCanBindResult` forward call added in v0.58.
- Remove the v0.58 dynamic multi-window UI cloning code, backend registration/unregistration and New Window button. The experimental runtime `execute` path may destabilize 3ds Max, and no safe two-window acceptance test has been completed. Restore one managed editor per tool while retaining support for multiple saved setups via the existing new-setup/bind controls.
- Retain the compact layout: hidden disabled Slice controls and manual-update label, side-by-side Delete Trimmed / Only Final Result, single-row Up/Down/Remove/Refresh/Add/Debug, 12px side gutters, 620px default / 548px minimum height, and the colored action labels. Expand Reset across the full top row.
- Preserve original-source safety, explicit Generate / Update, result identity, result child layers, Reset/Refresh behavior and validated startup references. Do not modify intersection mathematics or source geometries.
- Static verification: no `siMulti*` / `btnNewInstance` references, no runtime script cloning, structurally balanced code, exact backend checksum unchanged. The read-only UI smoke test is included; **interactive runtime/crash regression in a fresh 3ds Max session is pending**. v0.52 remains last user-confirmed stable release; v0.58 must not be used.

## 2026-10-31 — Compact editor and independent stream windows (project 0.58)

- UI 0.35 -> 0.36; backend 0.30 -> 0.31; shared project 0.57 -> 0.58. Current polygon-cut geometry is unchanged.
- Hide the obsolete Slice X/Y/Z sliders, Slice label, and manual-update note. Keep old callbacks inactive and automatic Slice generation disabled. Place Delete Trimmed and ONLY FINAL RESULT on a single options row.
- Arrange Up, Down, Remove, Refresh, Add and Debug in one compact 24-pixel row with 12-pixel side gutters, while preserving orange selection, blue Refresh, green Generate and existing source right-click commands. Reduce default/minimum rollout heights to 620/548 px and keep the source list vertically resizable above the bottom selection row.
- Add a New Window button. Each new window has separately named UI state, rollout, source list, trim settings, result controller and backend instance. Position/height and INI settings use a window-specific section. Two windows may use overlapping source objects, but the same saved result controller cannot be bound to two windows simultaneously. Closing one window does not delete its results or other windows.
- Correct backend instance-specific precision writes (this.position_precision_mm). This is not a numerical-geometry change; it prevents one window from changing another window's precision. Exclude outputs owned by another window from Add.
- Static source, layout, version, and generated-clone delimiter checks pass. The interactive multiwindow operation and generated-result integration require runtime validation in 3ds Max; no production scene geometry was modified during development.

## 2026-10-31 — Fix false finite containment behind endpoint extension error (project 0.57)

- FN 0.29 -> 0.30; Curve-Cut-Test 0.09 -> 0.10; shared project 0.57. Keep UI 0.35 / project 0.56 and entry 0.09 unchanged, preserving current UI colors, Refresh and Reset behavior.
- Root cause: triangle-fan containment on a rotated polygon with an extra collinear corner accepted a point outside the finite surface due to a numerically unstable near-degenerate triangle. The resulting intersection endpoint lay beyond the border and caused `SI EXTENSION FAILED | Continuation did not reach a border`. The error originates in geometry, not the UI handler.
- Test convex containment using the polygon plane and oriented edge halfspaces at the existing selected positional precision. No tolerance loosening, coordinate snapping, source modification or failure suppression.
- Added `siConvexContainmentTestRun()` (observed failing before fix and passing after) and `siCumulativeContainmentTestRun()` using the error log's rounded four-source outlines. All existing data checks and the temporary native extended-cut fixture pass; current UI/manual-update behavior remains unchanged. Original four side-surface nodes are not present in the connected scene, so an exact scene reproduction is unverified.

## 2026-10-31 — Orange selection labels and blue Refresh (project 0.56)

- UI 0.34 -> 0.35; shared project 0.55 -> 0.56. Backend FN 0.29 and entry 0.09 are unchanged; v0.52 remains last user-confirmed stable baseline.
- Convert native **Select Latest**, **Select All Sources** and **Refresh** controls to WinForms buttons to support reliable semantic font colors. Selection actions use orange RGB(244,166,74); Refresh uses blue RGB(96,180,255). Keep the existing dark background, border, hover/press states and Segoe UI 9pt font. Generate remains green.
- Preserve each action's callback, dimensions, positioning, enabled-state handling, and tooltips using the existing WinForms ToolTip owner. Do not change input list editing, Reset, manual generation, source-nested layers, or polygon geometry.
- Add non-destructive `test/Surface-Intersections-Button-Colors-Test.ms` to inspect foreground colors, text and .NET control properties after loading. Static source checks passed; the 3ds Max bridge was unavailable for visual/runtime confirmation.

## 2026-10-31 — Refresh list from selection and Reset output cleanup (project 0.55)

- UI 0.33 -> 0.34; shared project 0.54 -> 0.55. Backend FN 0.29, entry 0.09, geometry cutting, source-nested layer assignment and manual Generate policy remain unchanged. v0.52 is still the last user-confirmed stable baseline.
- Replace the **Clear List** button and right-click **Clear Source List...** action with **Refresh** / **Refresh List from Selection**. Refresh replaces the draft list with unique, valid, currently selected original geometry nodes, in scene selection order. Empty selection produces an empty list, with no confirmation or deletion. Existing kept-side values are preserved for nodes retained from the old list; new nodes default to Auto. Generated results, controller, deleted refs and tool-owned output nodes from other setups are excluded.
- **Add** retains append-only semantics. Refresh changes draft input only; no geometry regeneration, no result deletion, and no automatic intersection generation.
- **Reset** captures the current scene selection, confirms deletion when owned results exist, invokes the existing owner-checked `deleteGeneratedResults()` (including owned result nodes and Slice cleanup), and only on successful completion replaces the source list from the captured selection. Cancel/failure leaves the list alone; no result present means Reset simply refreshes selection. This avoids referencing selected result nodes after they have been deleted. Original source objects and other setups' results are never removed.
- New read-only regression tests cover selection replacement, duplicate suppression, keep-side pairing, invalid and generated-input rejection, and empty selection. Integration test: generate A+B, select C+D, Reset, confirm only the owned A+B outputs are deleted, list is C,D and no automatic Generate happens. Repeat with empty selection and a cancelled reset.

## 2026-10-31 — Extend open intersection cuts to borders; disable automatic Slice (project 0.54)

- FN 0.28 -> 0.29; Curve-Cut-Test 0.08 -> 0.09; shared project 0.54. UI 0.33 and entry 0.09 unchanged. Preserve v0.53 result-layer and startup-reference behavior; v0.52 remains the confirmed stable baseline.
- Reproduced unequal-width failure: a wider 100-unit-area surface retained 100 instead of the expected larger 70-unit region because the finite intersection did not separate it. Continue degree-one cut endpoints through the connected surface section to the border, starting along the terminal edge. Use these finite extensions in actual polygon splitting, region separation and the published curve. Reciprocal target surfaces are processed independently; Delete Trimmed OFF preserves complete area.
- Keep legacy Slice code behind `endpoint_slice_enabled = false`. Generate / Update creates no Slice and disables this setup's exact-owned instances. Manual modifiers remain untouched.
- Reject ambiguous branches or closed continuations explicitly. Restrict section tracing to the terminal polygon's edge-connected component, preserving disconnected and point-touching islands. Exclude reconstructed source patches with fewer than three distinct corners at selected precision or zero normal after hidden-edge dissolution; preserve positive-area skinny triangulation and do not move source vertices or change precision.
- Verification: new unequal-width data test failed before implementation, then passed alongside native temporary polygon tests, existing geometry/manual/collapsed-edge checks, one-/two-ended extensions, adjacent facets, closed/no-cut inputs, point-touch isolation and skinny-fan area. Native tests verify border vertices, extended curve endpoints, owned Slice disabling and manual Slice preservation. Reopened cabin sources pass native reconstruction at 0.01 mm with Delete Trimmed ON/OFF; the three-source BUMPER/TOP/FRONT order also passes at 0.01 mm with deletion ON. Previously recorded 1 mm limitation is not certified resolved.
- Run the scene-safe data queue in `test/Surface-Intersections-Curve-Cut-Test.ms`; explicitly call `siExtendedCutNativeTestRun()` for the temporary native fixture. It deletes only its own temporary nodes and restores selection.

## 2026-10-31 — Stable baseline confirmed (project 0.52)

- User confirms the current canonical project 0.52 as stable; it supersedes the earlier 0.48 stable designation.
- Entry 0.09; backend 0.27; UI 0.32; regression test 0.08.
- Documentation-only status update. No code or version values changed. Existing verification scope and known limitations remain recorded, including the separate 1 mm curve issue.

## 2026-10-31 — Prevent undefined bounds from an empty cut cell (project 0.52)

- FN 0.26 -> 0.27; regression test 0.07 -> 0.08; shared project 0.52. UI unchanged; stable baseline remains 0.48.
- Reproduced the reported `.x in undefined` error. Region adjacency received entry 74 with zero corners because knot cleanup returned an empty construction fragment that was still appended to the cut-cell list.
- Append cut cells and their source-origin mappings together only for valid polygons. Omit/log cleanup-empty fragments, stop further enrichment on them, and report malformed one-/two-corner returns explicitly. Count omissions per generation; retain the existing area-conservation check and selected precision.
- Validate region inputs once at the graph boundary so invalid polygon data produces an actionable patch/corner diagnostic instead of an undefined bounding-box access.
- Max runtime: exactly one cleanup-empty cell omitted; native construction, Generate and Refresh succeed at 0.01mm, producing 36 base polygon faces. The dedicated empty-cell fixture, existing geometry, manual-update and collapsed-edge checks pass. The separate 1mm curve-branch limitation is unchanged.

## 2026-10-31 — Cancel backtracking support loops before polygon tracing (project 0.51)

- FN 0.25 -> 0.26; test 0.06 -> 0.07; shared project 0.51. UI stays 0.32; stable baseline remains 0.48.
- Reproduced `SI POLYGON FAILED | region:3 corners:1` at 0.01mm. The raw boundary was a two-point loop with exactly zero area, caused by a residual opposite support-edge pair after deduplication.
- Normalize duplicate/zero-length region edges, then cancel remaining opposite edges only within the same region before tracing. Preserve true seams between separate regions. Do not suppress positive-area invalid polygons, loosen a tolerance, or override precision. Include raw area/points in degenerate diagnostics.
- Native Generate and Refresh now succeed for the reported case. Output reconstruction/vertex/curve checks pass at 0.01mm and 0.1mm with Delete Trimmed ON/OFF; data geometry, manual-update, Slice-plan and new collapsed-edge tests pass.
- Known unresolved regression: the 1mm curve check finds a separate short false branch, although polygon construction succeeds. This is recorded as a failure, not a complete suite pass. No speculative plane-classification change is included.

## 2026-10-31 — Fix polygon-boundary ambiguity at 0.1mm precision (project 0.50)

- FN 0.24 -> 0.25; regression test 0.05 -> 0.06; shared project 0.50. UI unchanged at 0.32; user-confirmed stable baseline remains 0.48.
- Reproduced the supplied failure at the selected 0.1mm precision (also at 1mm); the same scene built at 0.01mm. Temporary cells collapsing to the same identity produced duplicate/opposite boundary edges and unsupported construction corners.
- Reconstruct published boundaries from authoritative source/cut vertices, route support hits on original edges to their real cut crossings, normalize consecutive IDs, cancel same-region internal reverse edges and deduplicate directed boundaries. Add raw candidate-coordinate diagnostics. Do not change the selected precision or underlying cut calculations.
- For two sources, publish the original finite polygon intersection network instead of re-intersecting temporary surviving cells and manufacturing non-visible branch endpoints. Existing multi-source behavior is unchanged.
- Max verification: polygon reconstruction succeeds for both sources at all three precisions with Delete Trimmed ON and OFF; the reported 0.1mm generation completes with one shared endpoint Slice and manual updates. MCP disconnected during the expanded native regression; its completion is unconfirmed. Static checks pass. Added a precision/ON-OFF regression with bounded optional per-scenario calls.

## 2026-10-31 — Shared endpoint Slice on wider source and result (project 0.49)

- User confirms project **0.48 as STABLE**. Record FN 0.23, UI 0.31 and test 0.04 as that baseline; the new feature advances FN to 0.24, UI to 0.32, test to 0.05, shared project to 0.49.
- When a finite open cut ends on one source border and inside the wider source, add one exact shared Slice instance to that source and the final result. Set `Slice_Type = 2`, polygon operation, terminal-vertex pivot, dominant world-axis plane and outward flip. No Slice is needed for a closed cut or an end on both borders.
- Per-node modifier contexts keep the instanced Slice in the same world-space plane despite different source/result transforms. Persistent identity-key attributes track exact ownership without reference loops; user-created modifiers are never adopted by name/class. Generate ignores only its own Slice during source caching, reuses matching instances and removes obsolete owned ones. Reset cleans owned source instances too. Updates remain manual.
- Show Slice child rows directly below result rows; selecting one opens its exact native modifier in the Modify panel. Slice rows are not editable source-list entries.
- Inspected the provided Slice example. Native tests on temporary copies matched its X plane and pivot (with the test offset), clipped the wider source/result at the same X position, reused the same modifier/result on regeneration, opened the correct list-row modifier, and cleaned only owned instances on Reset. Original example objects/modifiers were preserved and the binding restored.
- Existing geometry and on-demand regressions plus new plan/native Slice checks pass. File reopen and general multi-source endpoint interactions are not certified by this test.

## 2026-10-31 — Generate / Update only; disable live regeneration (project 0.48)

- FN 0.22 -> 0.23; UI 0.30 -> 0.31; curve-cut test 0.03 -> 0.04. Stable geometry baseline 0.45 and the v0.47 source-list improvements are preserved.
- Remove automatic callback/timer registration. Old queued source notifications cannot schedule generation, and an obsolete timer tick never calls refresh. Legacy startLive generates once; setMode normalizes saved live/freeze requests to manual.
- UI defaults, INI settings and restored scene setup always use manual updates. Replace Refresh/Live/Manual/Freeze buttons with a Generate / Update-only note. Source and option edits wait for Generate / Update.
- Changed the currently connected Max tool to manual immediately. Runtime data checks pass for no monitoring resources, legacy-mode normalization, ignored dirty notifications, and existing polygon-cut regressions. No geometry algorithms changed.

## 2026-10-31 — Right-click source ordering with Ctrl boundary moves (project 0.47)

- UI v0.29 -> v0.30; shared project v0.46 -> v0.47. Stable polygon-cut backend FN v0.22 unchanged.
- Add **Move Up (Ctrl: Top)** and **Move Down (Ctrl: Bottom)** to the existing native source-list context menu. The normal action moves selected source rows one step; Ctrl at right-click or menu activation moves the stable selection group to the top/bottom.
- Support Ctrl+Up and Ctrl+Down through existing Up/Down buttons as well. Preserve selection, relative order, per-source kept-side values and source/result row separation. Reorder only the draft source list; regenerate only after Generate / Update.
- Add a non-destructive data-only regression test of stable grouping, paired modes, boundary no-ops and unchanged input arrays. 3ds Max right-click and key-modifier interaction is not runtime-verified in this change.

## 2026-10-31 — Append-only source collection and context removal (project 0.46)

- UI 0.28 -> 0.29; project 0.45 -> 0.46. Backend FN 0.22, entry 0.09, polygon cutting, `Delete Trimmed`, and `ONLY FINAL RESULT` are unchanged; stable geometry baseline 0.45 is retained.
- `Add` always appends unique, valid selected source nodes without replacing previous sources or requiring Ctrl. Initial list loading is guarded against replacing existing entries.
- Add independent `Clear List` button (confirmed, source-list-only) next to `Remove`. Both operate on draft list membership without changing original scene objects or deleting previously generated results; Reset continues to manage generated outputs.
- Add native MultiListBox right-click menu: **Remove Selected Surfaces** and **Clear Source List...**. Removal targets only selected source rows, not read-only result rows. Reordering and per-source kept-side modes remain paired.
- Both batch (A+B+C+D in one Generate) and incremental (A+B -> A+B+C -> A+B+C+D+E) workflows use the existing cumulative in-memory geometry pipeline. No auto-regenerate on Add; Generate / Update commits the edited source list.
- New scene-safe optional source-list regression function tests append order, duplicate rejection and side pairing using two selected existing geometry nodes, restoring the prior UI draft state. Context-menu actions and multi-source geometry remain for direct 3ds Max runtime verification.

## 2026-10-31 — STABLE baseline promoted to latest project 0.45 (documentation only)

- User confirms intersection cutting is working. Mark the **latest canonical project 0.45** as **STABLE**, superseding the earlier stable designation of project 0.44 while preserving v0.44 in the history.
- Latest inspected versions remain: entry 0.09, backend FN 0.22, UI 0.28, curve-cut test 0.03; **no MaxScript files or project version numbers are changed** by this release-status update.
- The previous 3ds Max 2026 regression results for v0.45 support the scoped stable status: 70 vertices / 39 polygon faces in the final Delete ON result; 98 / 65 with Delete OFF; two connected surface elements; 13/13 visible-edge cut segments covered; no hidden-diagonal or construction-only vertices; refresh preserves output identity.
- Stable status does **not** extend to unverified complex multi-source, coplanar, concave, branching, file-reopen or asynchronous live-update cases. The temporary no-new-Slice debugging policy remains unchanged.
- Updated canonical `design.md` and `changes.md` only. This is a documentation/status milestone, **not** a new code build or an additional runtime test.

## 2026-10-30 — Visible-edge polygon cuts without redundant vertices (project 0.45)

- FN 0.21 -> 0.22; test 0.02 -> 0.03. Stable baseline 0.44 remains recorded; this is the next development revision.
- Remove forced midpoint/centroid quad subdivision. Merge temporary cell seams and hidden source diagonals into polygon boundaries; allow n-gons. Preserve visible original polygon edges and real cut vertices.
- Remove cut knots caused solely by invisible diagonals, including diagonals in evaluated nonplanar quads. The published spline and polygon cut connect visible-edge crossings directly; interpolation inside warped polygons therefore follows visible polygon topology.
- Max runtime: result reduced from 424 vertices / 336 faces to 70 vertices / 39 faces, with two connected surface elements. All 13 visible-edge cut segments are covered by visible topology; the spline has 14 knots. No output vertex is an arbitrary face center, midpoint, or hidden-diagonal hit.
- Delete Trimmed OFF and ON both refresh successfully and preserve result identity (OFF 98 vertices / 65 faces; ON 70 / 39). Existing data tests and the revised scene regression pass. Native output topology still uses the established construction/inspection synchronization boundary. Source objects remain unchanged.

## 2026-10-30 — Stable baseline confirmed (project 0.44)

- User confirmed the current version as stable. Project 0.44 is the baseline for future development.
- Entry 0.09; backend 0.21; UI 0.28; curve-cut regression test 0.02.
- Documentation-only designation. Code and version values are unchanged; existing verification evidence and known limitations remain recorded below.

## 2026-10-30 — Trim both surfaces along bent intersection curves (project 0.44)

- Backend FN 0.20 -> 0.21. Reproduced the supplied test scene in 3ds Max 2026: 13 unresolved cuts with the old collinear-only path, and a new bent-seam data regression retained 100 instead of the expected 60.
- Partition patches along every actual finite curve segment, then use connected regions across the complete source surface to remove the smaller portion. Nonseparating finite curves retain both sides; untouched disconnected components survive. Known finite curve junctions prevent numerical gaps at nearly parallel supporting lines. Existing explicit planar side modes remain supported.
- Conform shared cell edges before uniform quad construction, preventing disconnected face islands/T-junctions. Sources, their handles and modifier stacks remain unchanged. Added one native dead-topology synchronization check after complete output construction.
- Test file 0.01 -> 0.02 / project 0.44: bent-curve, reciprocal trimming, Delete OFF area conservation, disconnected-source preservation, and an optional read-only check of the generated fixture. Existing straight/partial-cut tests and the new data checks pass in Max.
- Supplied scene result: 336 quad faces, two connected elements, all 26 real cut segments covered, no cut errors. Both source areas decrease; approximate retained/original areas: surface-1 7,412,260 / 7,613,570; surface-2 4,597,080 / 5,081,070. Manual Refresh preserves the result handle. No automatic Slice creation. General multi-source/branching/coplanar/reopen/live behavior is not certified by these focused tests.
- UI file stays 0.28 / stored project 0.43; the higher backend project 0.44 drives the global UI version.

## 2026-10-30 — Cut actual intersection topology; disable Slice for debugging (project 0.43)

- FN 0.19 → 0.20: remove a global hidden-triangulation-edge rejection that skipped an entire legitimate polygon cut when any intersection endpoint happened to touch an invisible original mesh diagonal. Source polygons are already reconstructed from visible boundaries, so those hidden edges must not decide whether a real intersection cuts the polygon.
- For every finite real intersection, derive the cutting chord from that intersection segment and split both source surfaces into new polygon regions. Validate that both regions are nonempty and their areas sum to the original polygon area before committing the cut. Hide only any supporting portion of the chord outside the real finite intersection. Delete the smaller region only for a complete separating cut when Delete Trimmed is ON; otherwise retain both faces.
- Report the number of actual polygon splits and any invalid/unsupported cuts. If a required interior cut cannot be constructed, block result regeneration rather than publishing another unchanged attachment of the source surfaces. A tangent line already on an existing polygon boundary does not require a new split.
- Disable automatic Slice modifier creation, Slice-pivot positioning, and UI slider interactions during topology debugging. Existing modifiers on old result nodes are not removed automatically; reusing such nodes keeps their stacks intact.
- UI 0.27 → 0.28; shared project 0.42 → 0.43. New data-only regression test covers two orthogonal quads, Delete ON/OFF, 70/30 and 80/20, partial finite cut and a real endpoint coincident with a hidden source diagonal. **3ds Max runtime verification is outstanding.**

## 2026-10-30 — ONLY FINAL RESULT output mode (project 0.42)

- UI 0.26 -> 0.27: `ONLY FINAL RESULT` checkbox below `Delete Trimmed`, default true. Saved in the existing project-local INI and on the saved controller using `SI_OnlyFinalResult`; older scene setups default true. When selected, the stack displays only the final result row, the pair inspector is disabled, and Generate selects the final surface rather than the hidden driver.
- Backend FN 0.18 -> 0.19: retains the full cumulative in-memory cutting pipeline but builds only the last Editable Poly step when final-only is enabled. It reuses the existing final node and Slice modifier, removes prior owned process-stage nodes and owned pair curves, and hides the persistent controller spline that stores live/source setup. The controller is an internal dependency, **so this is one visible trimmed output, not literally one scene node**.
- Turning the option off recreates intermediate results and pair curves; an existing final-only result is reused at the last step rather than inadvertently overwritten as step one. All deletions check owner handles and avoid original inputs. Failed cleanup is reported, not counted as success.
- Scene rebind supports selecting the final Editable Poly: the UI resolves its saved `SI_ProcessOwner` to the controller. The original owner curve's custom attributes remain canonical.
- Static source, version, pair-mode and layout checks are included; in-application runtime verification is outstanding.

# Surface-Intersections — Changes

## 2026-10-30 — POLY-only finite cuts and optional smaller-region deletion (project 0.41)

- FN 0.17 -> 0.18; UI 0.25 -> 0.26. Cumulative process stack is permanent. Remove the Cumulative toggle and the MESH/POLY radio buttons. `#poly` is the default and only active output topology mode.
- New **Delete Trimmed** checkbox, enabled by default, persisted in `Surface-Intersections-UI.ini` (`DeleteTrimmed`) and per saved curve result (`SI_DeleteTrimmed` user property). Legacy saved options for priority/mode are ignored and stored as true/POLY for backwards compatibility.
- Reconstruct evaluated source polygons by dissolving coplanar, convex, mutually hidden triangle seams with matching source mesh vertex IDs. Reject concave or inconsistent merges; never consider a hidden diagonal as a true visible boundary.
- Build cuts from actual finite polygon-to-polygon intersection segments. The internal seam may extend invisibly to create valid Editable Poly topology, but only the real finite intersection segment is marked visible. Actual curve endpoints are inserted on those seams; hidden triangulation crossings are not treated as vertices.
- When Delete Trimmed is OFF, keep positive and negative pieces. When ON, delete the smaller side only for a finite boundary-to-boundary separating cut; partial/nonseparating cuts retain both portions. Preserve manual side overrides. Never use an infinite cutter plane to delete geometry outside the finite intersection.
- Append source/result steps to the existing process list and reuse each stage's surviving working patches; original source geometry stays untouched. The process output, Slice modifier, pair curves and names remain as before.
- Data-only test `test/Surface-Intersections-Poly-Cut-Test.ms` covers 70/30 and 80/20 removal, Delete OFF retained area, no crossing, partial nonseparating line, and reconstructed quad diagonal. **No actual 3ds Max runtime check has been completed.**
- Limitations: multi-direction cuts through one convex patch, concave source polygon unions, and interior finite cut endpoints are not a fully general constrained polygon mesh-cut kernel. Unsupported cuts preserve material and report a Listener diagnostic rather than silently deleting the wrong region. Internal support seam edges are hidden, not absent from Editable Poly topology.


## 2026-10-30 — Deleted result spline reference recovery (project 0.40)

- Backend FN 0.16 -> 0.17: guard `makeSplineResult` against cached MAXNodes that have already been deleted, fixing the reported `Attempt to access deleted scene object` at previous backend line 1150/1151. MAXScript deleted nodes are still `!= undefined`; use `isValidNode` before `numSplines` and spline deletion.
- Discard only the invalid cached reference. Preserve the existing node identity for valid splines; create a new node for missing/deleted targets only when the original nonempty/`keep_empty` policy allows it. Pair curve cache also uses this same safe builder.
- UI v0.25 remains unchanged. No trimming, source geometry, Slice, surface topology or process-stack changes. Static review performed; regression execution in 3ds Max remains pending.
- Local release only; the protected canonical shared Codebase was not overwritten.


- Backend FN 0.14 -> 0.15: replace AUTO's reference-center orientation with a per-operation area comparison of the two sides, retaining the larger total patch area and discarding the smaller (deterministic positive-side tie-breaker).
- For a consistently wound planar cutter, require a real **finite surface intersection** first, then split the full target patch set by the cutter's supporting plane. This removes unwanted fragments outside the cutter's rectangular footprint that the older finite-footprint-only method left untrimmed.
- Both reciprocal cuts use the same rule: the incoming surface trims the previous cumulative result, and the pre-stage result trims the incoming surface. Published A+B, A+B+C, etc. use the cut patch sets; generated results are never re-snapshotted as source inputs.
- Keep #positive/#negative explicit overrides and #off (no trimming). Nonplanar cutter patch sets retain finite-footprint clipping but AUTO chooses whichever output has more area. An exactly equal split keeps the positive side consistently.
- UI 0.24 -> 0.25: change the existing AUTO label to **Auto (keep larger area)** without changing persisted enum values, control placement, or the grouped selection buttons. Source edge visibility, quad output, names, Slice modifier and result-node identity are unchanged.
- Static checks and analytical geometry regression cases only; real 3ds Max execution is still required. A finite crossing that does not geometrically separate the face may need more sophisticated region topology.

# Surface-Intersections — Changes

## 2026-10-30 — Forward-reference runtime error fix (project 0.39)

- Backend FN 0.15 → 0.16: fix `Type error: Call needs function or class, got: undefined` at the old line 2611 during process-result selection. `setInspectionProcess()` called `applyOutputVisibility()` before the latter was declared. Declare `applyOutputVisibility()` first.
- Fix the same latent forward-call ordering in Reset (`deleteGeneratedResults()` called `stop()` before declaration). Keep exact method bodies, scene safeguards, selected results, trimming and edge visibility unchanged.
- UI remains 0.25 (unchanged); active project version rises to 0.39 through backend. Static forward-reference audit passed; live 3ds Max runtime verification is pending.


## 2026-10-30 — Group selection buttons (project 0.37)

- UI 0.23 -> 0.24: move **Select Latest** next to **Select All Sources** in a single 24-pixel-high fixed row directly below the resizable process stack. Both keep their existing selection callbacks.
- Place **Reset** as a full-width top-row button; no changes to geometry, source rows, backend FN 0.14, persistence, modifier stack, or UI window size.
- Static position/bounds, version and source contract checks passed. Runtime UI validation in 3ds Max remains pending.


## 2026-10-29 — Cumulative processing stack and Select Latest (project 0.36)

- Backend FN 0.13 -> 0.14: retain one distinct Editable Poly surface for every completed two-input operation in an ordered cumulative source chain: `A+B`, `(A+B)+C`, `((A+B)+C)+D`. Each source beyond the second trims the previous surviving patch sets; the previous output is the next step's geometry input. No generated scene node is recursively evaluated as an input or registered as a live callback source.
- Stage geometry is built through the existing v0.35 quad/visible-edge pipeline, retaining a separate surface node per result, source-derived prefix names and owner/index user properties for save/reopen recovery. Existing active result nodes are reused where possible; the final one remains `trimmed_result_node` with Slice and curve-end placement. Extra outputs are not silently deleted when inputs are removed; they are retired, hidden, and cleaned up only with confirmed Reset.
- UI 0.22 -> 0.23: interleave read-only `[RESULT]` rows with editable `[SOURCE]` rows in the resizable source multiListBox; the latest surface is marked `[LATEST]`. Selecting a result row selects and reveals that scene object. `Select Latest` always selects and displays the newest final surface.
- `Use / Add`: normal click retains replacement of original source order; Ctrl-click appends new selected geometry objects without duplicating existing sources. Results shown as stack rows are implicit upstream geometry, not independently inserted source references, preventing feedback loops.
- Preserve original source-row reordering, Remove, kept sides, INI settings, pair inspection, output-based saved setup, Reset ownership checks and source integrity. Intermediate surfaces keep stable handles on refresh where possible. Static syntax/structural checks pass; **not runtime tested in 3ds Max**.


## 2026-10-29 — Preserve source edge visibility in generated Editable Poly (project 0.35)

- Backend FN 0.12 -> 0.13: preserve original snapshot face vertex-ID topology as a fifth triangle-cache field; only reconstruct original quads where two true mesh faces share a mutually invisible edge with reversed vertex IDs (not merely coincident positions).
- Build a list of actual visible source-edge segments and finite final intersection segments. The Editable Poly quad builder now explicitly sets `polyop.setEdgeVis` **true** for output edges lying on these boundaries and **false** for hidden triangulation edges and the temporary midpoint/centroid quad-subdivision seams. It verifies both visible and hidden flags with `polyop.getEdgeVis` before committing; a failure aborts the new poly rather than leaving an incorrectly visible result.
- Keep generated quads and existing result node/Slice modifier, source-based naming, pair-inspection curves, cumulative clipping and unchanged UI 0.22. No existing source object or its edge flags are modified. The visible line of a genuine source edge may be split into multiple shorter edges after a trim or quad subdivision.
- Scope: edge visibility of **Editable Poly base object** is preserved. Internally 3ds Max may triangulate polygons for rendering; this is not the same as exposed visible edges. Intersections from source polygon boundaries are finite. Nonconvex polygons, coplanar overlap, and Slice modifier evaluated-mesh topology remain subject to runtime tests.
- Static tests: topology-ID pairing; original quad boundary visible; hidden source diagonal not visible; synthetic quad fan edge hidden; actual trim cut visible; MAXScript delimiter and API-name review. **3ds Max runtime not connected; in-application test pending.**


## 2026-10-29 — Visible source edges and strictly quad surface (project 0.34)

- Backend FN 0.11 -> 0.12: reconstruct original coplanar quads across hidden triangulation diagonals from evaluated source meshes and preserve per-boundary visibility.
- Generate final and per-source-pair curves using only visible original polygon edges, not invisible internal triangle edges; keep finite face-interior intersection calculation.
- Build the Editable Poly final surface using only degree-four polygons: preserve existing quads, subdivide triangular/n-gon clipped patches into quad fans, and verify every produced face degree.
- Keep the same final output names, source set, node identities, live monitoring, Slice modifier and curve-end gizmo location. UI 0.22 unchanged.
- Requires 3ds Max runtime acceptance, including edge visibility on evaluated modifier stacks and mixed quad/trimmed-fragment connectivity.

## 2026-10-29 — Source names and Slice gizmo endpoint (project 0.33)

- Backend FN 0.10 -> 0.11: name the linked result curve `{source_A}+{source_B}-curve` and the final surface `{source_A}+{source_B}` (plus additional source names when present). Apply after successful generation and refresh without replacing nodes.
- Move the Slice Plane gizmo position, **not** the Editable Poly object pivot, to the final knot of the first open result spline; use documented modifier-context world-to-local transform. Keep the existing Slice rotation. Leave the position unchanged if no open curve endpoint exists.
- UI 0.21 -> 0.22: reapply result names and Slice position after binding a saved curve result. No layout changes.
- Static contract checks only; the 3ds Max runtime bridge is unavailable for end-position/rotation regression tests.

## 2026-10-29 — Pairwise intersections without intermediate surfaces (project 0.32)

- Backend FN 0.09 -> 0.10: remove all intermediate cumulative stage snapshots and Editable Poly step generation; retain one final `Surface_Intersections_Trimmed` with its Slice modifier and the persistent `Surface_Intersections` spline result.
- Generate separate raw finite-intersection spline objects from each two-source pair (`Surface_Intersections_Pair_XX_YY`) for inspection, based on original evaluated source geometry. Existing pair nodes update in place; results are tagged with owner handle and source indices for recovery after scene reload.
- UI 0.20 -> 0.21: replace **Inspect Step** with **Inspect Pair**. The selected pair curve is visible/selected while `Surface_Intersections_Trimmed` remains visible; Final result restores combined curves. Do not add new step objects.
- Preserve legacy v0.31 step objects without silent deletion during Generate/Refresh. Confirmed Reset handles only the current setup's tagged pair, legacy step, and final outputs, without touching sources.
- Static validations only; test inside 3ds Max is pending.

## 2026-10-29 — Independent cumulative stage objects (project 0.31)

- Backend FN 0.08 -> 0.09: retain a snapshot of each cumulative polygon-patch stage and publish a distinct Editable Poly scene node per stage. Produce independent stage curve objects from Step 2 onward to inspect the intersections at each point in the source order.
- The original final result and its Slice modifier remain separate. Recompute intermediate outputs on refresh and reuse node identities, with step ownership and index stored as user properties for rebinding after reload.
- Add stage-specific visibility/inspection controls and extend Reset to delete only the current setup's stage objects alongside its final curve and surface; input source nodes remain untouched.
- UI 0.19 -> 0.20: add an **Inspect Step** dropdown beneath the title actions; selecting a step shows and selects its surface, while **Final result** returns to the original final output. Increase vertical dialog minimum/default height by 40 px and preserve INI position.
- Static code checks complete; 3ds Max runtime unavailable (connection terminated). Snapshot fidelity, scene persistence, modifier-stack behavior and topology validation remain pending.

## 2026-10-29 — Editable Poly surface, Slice and result controls (project 0.30)

- Backend FN 0.07 -> 0.08: build true Editable Poly polygon faces from surviving convex patches; retain source-specific shared vertices and separate source elements, without collapsing all topology to triangle fans.
- Preserve the existing trimmed result node and its modifier stack by swapping the fully built Editable Poly base object; keep the Slice modifier and gizmo rotation on every successful refresh.
- Automatically add a Slice modifier to the linked surface result if missing, but never add a duplicate or change any source object.
- Add `deleteGeneratedResults()` for safe, confirmed deletion of the current curve and surface outputs only; detach live monitoring first, preserve original input nodes, and report deletion failures.
- UI 0.18 -> 0.19: `Select Surface` and `Reset` buttons immediately beneath the title; reflow the other controls and retain dialog position/resize persistence and existing source list behavior.
- Static checks completed. Geometry, Edit Poly topology, Slice modifiers and reset safety require real 3ds Max testing.

## 2026-10-29 — Slice gizmo X/Y/Z local-rotation sliders (project 0.29)

- UI 0.17 -> 0.18: three compact full-width native horizontal sliders in separate X, Y, Z rows above the source list; range -180°..+180°, 0° centered. Sliders act as incremental local-axis jog controls and recenter on release without reverting rotation.
- Backend 0.06 -> 0.07: resolve active Modify-panel Slice modifier, otherwise search the selected object's modifier stack; update the gizmo's quaternion rotation directly without resetting it or creating a modifier.
- Preserve existing source-list and Select All Sources actions; resize height to default 820, minimum 812; preserve current INI dialog-location behavior.
- Static code/layout checks complete; 3ds Max runtime testing pending. Previous backend/UI releases archived in `_Versions/`.


## 2026-10-29 — Select All Sources and dialog-position persistence (project 0.28)

- UI 0.16 -> 0.17: add a bottom `Select All Sources` button that selects all valid source nodes and their rows without editing source order, clip modes, geometry or result.
- Reserve a fixed bottom row below the resizable list with 12 px spacing; disable the button when the list has no valid scene nodes.
- Explicitly save INI dialog position and height before title-button restart. Existing managed-dialog startup restores the saved position.
- Previous UI 0.16 retained in `_Versions/`; backend and shared UI helper source unchanged.
- Static layout and code checks passed; runtime behavior still needs testing in 3ds Max.


## 2026-10-28 — Cumulative surface trimming (project 0.26)

- Backend FN 0.05 -> 0.06: the incoming surface trims the complete previous result; the same previous result trims the incoming source, then both passes commit together.
- Preserve source-owned surviving patch sets for the existing curve and experimental mesh builders.
- UI 0.14 -> 0.15: label now describes cumulative trimming; existing settings keys and object setup schema stay compatible.
- Added scene-safe, data-only cumulative regression test. Static checks only; 3ds Max runtime not connected.
- Existing limitations concerning coplanar overlap and trimmed mesh result persistence are unchanged.


## 2026-10-20 — Result-owned setup (project 0.24)

- UI 0.12 -> 0.13. One active editor binds to one result; Generate updates that same object.
- Node custom attributes retain real source references, pending/applied orders and kept sides, precision, priority clipping, MESH/POLY and update modes. Scene save persists them; INI remains the default for new setups.
- Result .NET button below Generate: click selects; right-click loads a selected saved result; Ctrl-click starts another setup while retaining the previous result. Switching detaches previous monitoring.
- Opening restores a selected saved result or the previous session binding. Missing sources restore Manual; deleted results require an explicit new setup.
- List moves to y=424; default/minimum heights 692/652. No runtime checkbox width assignment.
- Static checks only. 3ds Max connection reports Session terminated; save/reopen, reference persistence and UI/runtime verification remain pending.

## 2026-10-20 — Clean debug capture (project 0.23)

- UI 0.11 -> 0.12, backend FN 0.03 -> 0.04. Debug button shares the Use Selection row.
- Each click overwrites logs/Surface-Intersections-Debug.txt through the canonical DUMP logger and mirrors the report to Listener.
- Records UI and linked source order, handles/names, kept sides, modes, precision, units, object world positions, evaluated world vertices, triangle edge visibility, and every result spline/knot world position.
- Read-only capture: no regeneration, selection edits or source geometry changes. Failures are reported and incomplete captures are marked FAILED.
- Static checks passed; runtime unavailable. Invoke siUiWriteDebug() after loading the updated tool to test.


## 2026-10-20 — Remove unsupported runtime control widths (project 0.22)

- UI 0.10 -> 0.11: remove redundant runtime width assignments from siUiLayout, including the unsupported CheckBoxControl.width assignment reported at line 377.
- Keep all widths in the existing control declarations; preserve positions and vertical list resizing.
- Static check confirms no runtime width setters remain in the layout; runtime verification pending.


## 2026-10-20 — Straight rows and checkbox clearance (project 0.21)

- UI 0.09 -> 0.10: precision, kept-side and status use full-width rows; checkbox has a dedicated row with clearance above and below.
- MESH/POLY is directly above Generate / Update. Source list remains last and expands with dialog height.
- Control declarations follow visual order; explicit layout disables automatic relayout and sets consistent widths.
- Static delimiter checks and 17 declared control rectangle checks passed. Runtime overlap report cannot be visually verified while MCP reports Session terminated.


## 2026-10-20 — Compact control rows (project 0.20)

- UI 0.08 -> 0.09: aligned controls into compact rows; Generate / Update spans the full row directly above the source list.
- Use Selection spans its row; initial control positions match the resize layout. Backend unchanged.
- Static layout review only; 3ds Max visual verification pending.


## 2026-10-20 — MESH/POLY and bottom source list (project 0.19)

- UI 0.07 -> 0.08; backend FN 0.02 -> 0.03. Preserve backend project 0.18 endpoint trimming.
- Persisted MESH/POLY radio buttons; POLY protects visible-edge knots and handles closed seams while removing redundant hidden-edge knots. MESH retains triangulation knots.
- Taller bottom multiListBox, Remove selected rows, and list-to-scene selection. Scene objects are not deleted; apply edited source sets with Generate / Update.
- Added scene-safe data-only Poly-Test 0.01. Static delimiter/declaration checks passed; runtime tests not executed (MCP Session terminated).


## 2026-10-20 — Green Generate button (project 0.17)

- UI file 0.06 -> 0.07: Generate / Update uses a WinForms button with green text and the shared standard action-button styling.
- Click retains the existing siUiGenerate action, layout and enabled-state behavior.
- Static callback/style check passed; runtime verification remains unavailable.


## 2026-10-20 — Source list spacing (project 0.16)

- UI file 0.05 -> 0.06: moved the source multiListBox down 12 px and reduced its calculated height by 12 px; button positions unchanged.
- Verified the default and minimum layout calculations. Runtime UI verification remains unavailable.


## 2026-10-20 — Retain sources and enable multiple source rows (project 0.15)

- UI file 0.04 -> 0.05; preserve the updated shared-framework UI.
- Initialize source references and kept-side modes only when undefined, preserving list order across UI reloads. Use Selection explicitly replaces the list.
- Use native multiListBox with BitArray selection and selectionEnd handling.
- Up/Down moves selected rows together while preserving relative order and paired modes; movement stops at list boundaries.
- Kept-side changes apply to all selected rows; mixed modes display no selected dropdown item.
- Static checks and 508 group-movement model cases passed. MAXScript runtime verification unavailable: MCP session terminated.


## 2026-10-19 — UI compile fix (project 0.12)

- Updated UI file 0.01 -> 0.02; other source versions unchanged.
- Expanded dropdown case branches and separated numeric labels from values to prevent MAXScript's Bad number or time syntax error.
- Resolve the native dialog title after promoting the global project version.
- Reproduced the original precision expression compile error in 3ds Max 2026. Corrected UI loaded successfully; precision mapping assertions passed for 1mm, 0.1mm and 0.01mm.
- Geometry and destructive Surface/Curves tests were not run for this UI-only fix.


## 2026-10-19 — Ordered intersections and hidden-edge knot cleanup

- Introduced a three-source Tool package: entry `Surface-Intersections.ms` v0.07, backend `Surface-Intersections-FN.ms` v0.01, and UI `Surface-Intersections-UI.ms` v0.01. Shared project 0.10.
- Higher-priority finite planar sources trim lower-priority surface-pair curves on a selected kept side (Auto, Negative, Positive, Off). Nonplanar sources are skipped as priority cutters. Original source objects remain unmodified.
- Added a dockable source-order dialog with Up/Down, halfspace selection, precision, and live/manual/freeze controls.
- In evaluated mesh caches, record hidden edge visibility. Remove only straight-through degree-two spline knots intersecting a hidden source triangulation edge.
- `test/Surface-Intersections-Test.ms` v0.08 validates top/bottom limits after moving TOP inward; existing tests still delete scene nodes without resetting Max.
- Static checks and a simple planar geometric clipping calculation passed; **actual 3ds Max tests are pending**.


## 2026-10-19 — Delete scene nodes instead of resetting tests

- Test scripts now delete all scene nodes with `$* as array` and `delete`, including hidden/frozen nodes, instead of `resetMaxFile #noPrompt`.
- Preserve scene-level settings; log deleted-node count and verify that no scene nodes remain.
- `Surface-Intersections-Test.ms`: file v0.07.
- `Surface-Intersections-Diagnostics.ms`: file v0.04.
- `Surface-Intersections-Curves-Test.ms` and `Surface-Intersections-Surface-Test.ms`: file v0.03.
- Shared project version advanced to 0.09; production engine unchanged (v0.06).
- Runtime execution in 3ds Max remains unverified for this change.

## 2026-10-19 — Design and agent instructions

- Added root `AGENTS.md` with canonical source-of-truth, shared Tools read-only authorization, geometry invariants, source-safety, versioning and live-session behavior.
- Added `test/AGENTS.md` with no-prompt reset warning, six-plane cube acceptance criteria, independent curve vs Surface modifier tests, and diagnostic logging requirements.
- Added `doc/AGENTS.md` to distinguish verified behavior from plans and keep the human guide aligned with the canonical script.
- Added root `design.md` describing the current live curve prototype, known experimental mesh path, six-plane regression evidence and development roadmap.
- No MaxScript code changed. File/project script versions remain as stored in the canonical files.




























