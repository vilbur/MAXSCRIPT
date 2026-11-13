## v0.092 — Startup failure and Hatch settings copy

**Status: INIT STABLE**, user-designated on 2026-10-29. Preserve this release as the initialization baseline for startup, rollout creation and repeated reopening. Geometry stability remains tracked separately from this designation.

The startup logger opens its file with `mode:"a"`, the supported MAXScript append mode. On rollout opening, `setHatchSettings` shallow-copies the incoming 9/13/15-value array using `copy scene_values #noMap` before appending migration defaults; the caller's array is not changed. Plain mapped `copy` returns `OK` for arrays, so reading `.count` from that result aborts initialization. The actual failure was captured by the corrected log in 3ds Max 2026.

## v0.091 — Startup exception capture

Wrap rollout-open initialization and dialog creation in narrow error handlers. On a MAXScript exception, append its full exception text under an `ERROR-*` stage in the startup log, write it to Listener, and rethrow. This captures script exceptions; native process termination may prevent any catch from running.

## v0.090 — Startup diagnostic log

At tool evaluation, append timestamped markers to `Tank-Panel-Generator-Startup.log` in the same folder as `Tank-Panel-Generator.ms`. Record entry, each dependency load, prior-state capture, major rollout-open operations, dialog create/register boundaries, posted-message processing, grid/material-row initialization and final completion. Logging is best-effort: report logger errors to Listener and keep normal startup behavior. Inspect the final marker after a native exit to locate the last reached startup phase.

## v0.089 — Native spinner startup safety

Native MAXScript SpinnerControl declarations use finite, proven bounds of -1,000,000 to 1,000,000 for signed distances and 0 to 1,000,000 for nonnegative distances. Do not use ±1.0e30 in rollout spinner declarations: v0.088 instantiated those bounds across visible controls and 36 hidden per-ID controls during rollout creation and 3ds Max terminated before the dialog opened.

This UI safety bound does not round, rescale or otherwise alter stored scene-unit values. The shared SIZE mm/cm/m conversion remains the display/edit boundary, and backend geometry continues using scene units. The test suite scans the entry source before loading it and rejects unsafe native spinner declarations.

## v0.088 — One unit selector, Hatch seams and module ends

Every dimensional editor field uses Main Module SIZE mm/cm/m. Internal geometry, INI/presets and node records remain scene-unit values. Read/display conversions divide by the selected physical unit scale; edited values multiply by it. Unit switching updates the UI and editor preferences only, preserving node/modifier identities and physical dimensions. Segment counts, material IDs, end flags and the legacy Chamfer profile-depth ratio are unitless. Distance spinner ranges permit display conversion without a unit-specific positive minimum; the backend still requires positive Radius/Length.

Hatch keeps the original radial/axial geometry while relabeling: `Inset radius` is the old radial Thickness; `Thickness` is the old axial Depth. Preserve old storage keys for compatibility. `outerRadius = Radius + InsetRadius`; End radius is nonnegative and strictly below outerRadius. The profile's outer axial lip and first radial segment use the same material ID so the radius corner is excluded from material-boundary chamfering. Subsequent radial seams retain distinct IDs.

| Label | Native cap Chamfer property | Default |
|---|---|---|
| Seam Width | amount | 1 |
| Seam Stich Width | insetAmount | 0 |
| Seam Depth | insetoffset | 5 |
| Seam Segments | insetsegments | 0 |
| Segments Top | segments | 0 |
| Seam Material | materialID | 99 |

Always manage addinset=true and setmaterial=true internally. Keep the former dimensionless Chamfer depth ratio internal; Seam Depth controls insetoffset, a physical distance. Add 4px extra vertical spacing between profile, radial seam pattern, seam dimensions, segment counts and material groups. Standalone and linked Hatches both use owned Chamfer above Lathe. The seam material has a dedicated sparse-ID palette slot when it is not one of the existing band IDs.

Cap Enter/Cap Exit mean Hatches at the module's negative/positive local-Y ends, not Lathe revolution caps. Default is Exit=true, Enter=false. Each end is centered on the module's bent local cylinder axis through Z=-Radius, using the full module objectTransform including object offset and scale. Reverse Enter's Y/Z frame so positive profile Thickness points outward. Explicitly set native Lathe axis.position=[0,0,0] and axis.rotation=(quat -90 [1,0,0]) after adding it.

Each cap stores SPG_CapSide=Enter/Exit; legacy single caps without the marker are Exit. Reject duplicates, more than two owned caps or foreign stacks. Reuse node identity per enabled end, and delete only validated exact owned disabled nodes. SPG_HatchManaged=1 on the module persists a generated-but-all-disabled state; loading/restarting retains that binding so enabling an end can work live again. Never-generated modules still require Generate Hatch.

Settings snapshots retain indices 1–9, adding 10=SeamDepth,11=SeamSegments,12=TopSegments,13=SeamMaterial,14=Enter,15=Exit. Read 9/13/15-value legacy/new records. All dimensional entries stay in scene units; missing SeamDepth migrates consistently through the caller's selected unit scale. Old preset keys remain canonical; six new keys belong to All/Hatch scopes. Missing legacy end flags reset to Exit-only and missing new seam counts/material use 0/0/99.

Part 63 runs against the loaded current main UI (`TPG_HatchOptionsRegressionOnly=true` before loading the test), preserves its saved settings, and tests unit round trips plus owned temporary transformed Hatch ends. Existing Part 57 now expects standalone Chamfer+Lathe. Arithmetic/static checks and independent review completed; native Max 2023/2026 execution and visual QA are pending. v0.083 remains stable.

## v0.087 — Thickness seam-wall removal before welding

The two side walls created by Shell at the flat plane's left/right X ends become overlapping internal polygons at the cylinder closure. Remove them immediately after baking thickness, before assigning cell IDs and before Bend. In this generator-owned flat source, those walls have exact X-axis normals; front/back skins have Z normals and the two axial end rims have Y normals. Delete only the X-facing walls. Check their count against `2 * TotalRows * LengthSegments` before the batch.

Topology boundary: the existing post-Shell dead-structure preflight occurs before reading seam face IDs. Collect all target faces, delete once with delIsoVerts:false, discard those face IDs, then compact dead structures if present before any new cell/material/map-channel face data is collected. This extra cleanup marks the transition from completed deletion into new topology analysis. No cleanup is added inside either batch or the procedural weld/extrusion stages.

Final order: baked flat thickness → seam-wall deletion → optional pre-Bend Seams → Bend → procedural weld → extrusion. Front/back skins and axial rims remain. The procedural weld closes the matching front/back seam vertices after Bend. Objects generated before v0.087 must be structurally regenerated once with Generate/Update; Height/Inset/Taper-only edits retain the old base by design.

Part 62 (`TPG_ThicknessSeamRegressionOnly=true`) checks thick source-face classes, welded vertex/triangle counts, and Group/Local extrusion. Native runtime testing is pending; v0.083 remains stable.

## v0.086 — Pre-extrusion weld of the bent mesh

Evaluation order inside the existing TPG Extrusion modifier is now: receive the already bent TriMesh → weld all vertices using the saved physical position precision → collect material/cell face regions → Inset → Height/Taper. This merges the coincident closure vertices of the cylindrical sheet before extrusion. It also runs for zero-valued rules so the evaluated bent shell is welded before any later edits.

Use native meshop.weldVertsByThreshold on the existing copy of the incoming mesh. SPG_PositionPrecisionMM supplies the distance in millimeters; convert via units.decodeValue before calling MeshOp. Missing legacy precision defaults to the established 0.01mm. Do not add an unrelated epsilon, round vertex coordinates or modify the original flat base/Bend. Threshold welding is the explicitly requested geometry operation.

Topology boundary: cache no vertex/edge/face IDs before welding. The native weld completes before original_face_count and map-channel 99 face-region reads. The face/corner correspondence for each later Inset/Extrude stage is still collected and discarded within that stage. All polyop.collapseDeadStructs calls remain in their pre-existing base-building boundary; none is added to the welding/extrusion pipeline. MeshOp preserves the map channel's per-face corner data; Part 61 verifies those tags and material IDs on the actual seam fixture.

Regression: set TPG_BentWeldRegressionOnly=true, then run Tank-Panel-Generator-Test.ms. Part 61 verifies the welded output, saved threshold, both extrusion modes, Inset/Taper and unchanged source base/modifier instances. Native runtime is pending. v0.083 remains stable.

## v0.084 — Auto Length subdivision contract

The existing Main Module SUBDIVISION row has Around and Length dropdowns beneath the Radius/Length columns. Length offers Auto followed by the existing manual counts. Existing positive saved counts stay manual; fresh INI settings default to Auto. No additional controls or dialog/grid resizing are required.

Auto aims for approximately square polygons in the *flat base object*. A polygon width is `2*pi*Radius / (Columns * RepeatAround * ArcSegments)`. A logical panel length is `Length / Rows`. Choose `max(1, floor(panelLength / polygonWidth + 0.5))` Length subdivisions per panel. Integer rounding is required by this explicit count-selection contract; do not round dimensions or positions. Repeat Length extends both total length and rows, leaving the ratio unchanged. Recompute on each structural Generate/Update so changes in dimensions, grid, repeat or arc subdivision affect Auto.

Serialization: UI/INI/presets use LengthSegments=0 as Auto and positive counts as manual. Backend generateModule accepts length_segments:0, resolves it before creating the flat plane and writes actual SPG_LengthSegments plus optional SPG_LengthSegmentsAuto=1/0. Object reload selects Auto only when its explicit flag is 1; absent legacy flags mean manual. Extrusion-only updates continue to validate against the actual saved topology count. Preserve logical masks, IDs and rules: subdivisions do not create extra logical panels. The source-node and owned modifier update contract is unchanged.

Part 60 exercises full generation and metadata, manual/legacy behavior, Repeat Length, scale-invariance, counts beyond 32, a bound update, and preset scopes. Run `TPG_LengthSubdivisionRegressionOnly = true`, then evaluate `Tank-Panel-Generator-Test.ms`. Native 3ds Max execution is pending. v0.083 remains stable.

## CURRENT STABLE BASELINE — v0.083 (user-approved 2026-10-27)

The user designated v0.083 as stable. It is the current baseline for subsequent development, superseding v0.079. This is a documentation-only status update: source code and version numbers are unchanged. No additional native 3ds Max runtime tests were executed for this designation. Earlier development/stable entries below are historical records.

## v0.083 — Equal spacing across tapered ring subdivisions

User clarification: the requested equal distance is between subdivision edges across the tapered polygon, not the lower-to-upper border gap.

For nonzero Taper, keep the existing tapered endpoints but redistribute intermediate upper vertices on each cross-sectional ring, including interior Length-subdivision rows. Solve equal **straight-line chord lengths**, which measure the separation between corresponding parallel axial subdivision edges. Simply equalizing polyline travel distance is insufficient across bent facets. New points lie on the pre-redistribution top polyline; reconnecting them changes the intermediate top facet planes. Keep the lower mesh untouched. Inset-only and zero-Taper paths remain unchanged.

The source is TPG's cylindrical sheet with local Y as its length axis. Original region triangle edges with equal endpoint Y define ring adjacency. Triangulation diagonals span different rows and are excluded. Walk degree-one open chains; closed full-circumference rings have no taper-trimmed ends and are not redistributed. The code deliberately does not interpret arbitrary user Edit Poly topology or world-space geometry.

The spacing solver uses explicit `position_precision` (default `units.decodeValue "0.01mm"`) as a residual bound. It solves interior positions by successive line/sphere intersections and a bounded spacing search, verifies the final spacing spread before applying that ring, and reports failure if it cannot converge. It does not round, snap or clamp vertex positions. The existing procedural modifier's copy-mesh transaction retains the incoming mesh if an operation fails.

Compound topology boundary: collect original faces/vertex IDs, edge records and ring adjacency before MeshOp; perform zero-outline native extrusion; consume face/corner correspondence to map source to upper vertex IDs; apply boundary offsets and ring redistribution without another topology operation; discard all cached IDs. No collapseDeadStructs is introduced and no base-object index cleanup is performed.

Part 59 uses the supplied 4x3 pattern, Repeat Around=2, Radius=1000, Length=7000, Arc subdivision=4 and Length subdivision=2. It checks both repeated Material-ID-4 panels, all three ring rows and signed/zero Height in Group/Local modes with signed Taper and Inset=0/50. Run `TPG_TaperSpacingRegressionOnly = true`, then evaluate `Tank-Panel-Generator-Test.ms`. Part 58 remains a planar corner/border control. Native execution is pending.

## v0.082 — Taper top loop parallel to source border

A positive Taper offsets each extruded top boundary **inward by that scene-unit distance**, with each upper edge parallel to its original lower border edge; negative Taper offsets outward. Build source boundary topology from one-use triangle edges, not individual triangulation diagonals or world-axis heuristics. Interior vertices of each selected face region do not move laterally. This works for faceted bent panels and both Group direction and Local normals height extrusion. An Inset still builds its own zero-height rim first, so Taper acts on the inset perimeter when Inset is nonzero.

Do not pass Taper to native `meshop.extrudeFaces` as outline. Instead cache source face/vertex IDs and boundary offset vectors, extrude with outline 0 and original Height/mode, then apply the offsets to newly generated upper boundary vertices only. Preserve lower loop, source base, Bend, scripted TPG Extrusion class ID, material IDs, saved rule arrays and optional Seams/Chamfer modifiers. No hidden position snapping or invented geometry tolerance is introduced; Part 58 uses the existing explicit 0.01mm regression tolerance.

## v0.081 — Hatch UX and spline generation (development)


The PANELS section retains live per-ID Height, Inset and Taper controls but no redundant Extrude action button. Editing these numeric controls continues to update the existing TPG Extrusion procedural modifier immediately, and main Generate/Update handles structural changes.


The HATCH section exposes a `.NET System.Windows.Forms.Button` named `Generate Hatch`. It explicitly generates output, including when a cylindrical module has not been generated. In standalone mode it creates an editable native `SplineShape` cross-section in the XY plane using Hatch radii/depth/seam controls, then adds one native 360-degree `Lathe` modifier with Use Shape IDs; the source spline remains editable in the stack. Changes to a previously generated standalone hatch update only the tagged source, preserving its node identity; foreign stack changes block edits. A bound module instead receives the existing linked child cap with its Lathe and owned Chamfer. No unrequested module is created by Generate Hatch. Native 3ds Max Part 57 verifies standalone behavior.


## v0.080 — Base Thickness (development)


Main Module exposes Base Thickness in the currently selected SIZE unit. A zero value keeps the original single flat polygon sheet. Positive thickness adds an inward (local negative Z) back surface and perimeter edges to the *flat plane* by temporarily applying native Shell, then immediately collapses to Editable Poly before attaching any TPG Seams, Bend or TPG Extrusion modifiers. The original +Z front face plane stays at z=0; source radius/dimensions and logical top-face Material IDs remain unchanged.


Extrusion may target only the original top panel faces; back and perimeter faces receive neutral private map tag [0,0,0]. Thickness persists in `SPG_BaseThickness`, the same INI (BaseThickness key) and All/Panels presets. Old data and presets without this property are treated as zero thickness. Altering thickness is a structural regeneration of the bound node, not an extrusion-only modifier refresh. The base remains one Editable Poly, and the temporary Shell never appears in the final stack. Confirm this with native Part 56 and inspect normal/nonzero extrusion on thick objects before production use.


## CURRENT STABLE BASELINE — v0.079 (user-confirmed 2026-10-27)


This is the accepted stable TPG release for future development. Marking it stable records the user's release designation; it does not assert a new native 3ds Max regression result. All future experimental changes must preserve a rollback path to this exact v0.079 source.


## v0.079 — Self-contained installation


The project directory includes Lib/IniSettings.ms, Lib/RolloutState.ms, Lib/DialogHost.ms, Lib/ScriptReload.ms, and Lib/ToolTitleButton.ms. These are private forks of the shared UI helpers. The entry script loads them relative to getSourceFileName; no external MaxScript-root configuration, CODEBASE folder, or UI source checkout is required. Moving the project is supported only if its Lib/ folder stays beside the main entry .ms file. The obsolete shared-root resolver is not used or distributed as an active source. Part 36 remains a recommended native regression check when validating the installation on a new machine.


﻿## v0.078 — Finishing Chamfer material mode and Segments


The separate topmost, tool-owned native modifier is displayed as `TPG_Chamfer`. Its Material Option is 2, Segment count defaults to 1 and is user-editable through a 0–100 integer spinner in the independently collapsible Chamfer section. Changes edit that modifier in place and propagate through INI, object properties and the Chamfer/full preset scopes. Pre-Bend `TPG Seams` keeps Material Option 1, Add Inset and Segments 0. The project remains in development; native MaxScript runtime regression Part 55 must validate live scenes.


## v0.074 — Native Seams below Bend and native finishing Chamfer


Stable baseline: **v0.073**, explicitly confirmed by user. v0.074 is a development candidate pending a 3ds Max 2026 runtime regression with Seams and TPG Extrusion both enabled.


- Seams: tool-owned native Chamfer applies before Bend. It uses exactly the supplied material-boundary reference (`materialoption=1`, `selectionoption=5`, `useminangle=false`, `addinset=true`, `segments=0`, `insetamount=0`) and exposes Amount + Inset Offset.
- Finishing Chamfer: separately tool-owned native Chamfer at the top of the stack, exposing a smaller Amount; the UI clamps the finishing amount below the smallest nonzero active extrusion height/inset/taper magnitude.
- Stack order (top to bottom): TPG Chamfer (optional), TPG Extrusion, Bend, TPG Seams (optional), Editable Poly. Both native modifiers may be disabled without removing the rest of the stack; v0.073 two-modifier objects continue loading.
- Each native modifier gets an exact AppData ownership marker and must remain at its designated index. Modified/foreign stacks refuse update; the tool never claims a native Chamfer by display name.
- UI settings are stored in the generator INI and on the generated node. New independent Seams and Chamfer scopes are included in preset save/load.
- The extrusion path ignores native-generated seam triangles whose private channel 99 vertices contain mixed logical cell tags. It still extrudes consistently tagged original panel triangles.


Verification: static source tests pass locally. **Native MaxScript Part 55 must be run by the user** to prove the lower Chamfer preserves map channel 99 and procedural extrusion can create new faces. Never label v0.074 stable solely based on static checks.


## v0.073 — Local normals extrusion design and implementation plan


Historical note from before user confirmation: v0.071 was stable. **User has since confirmed v0.073 as stable** on 2026-10-25.


Stable MVP remains user-designated v0.071. Development starts from the complete v0.072 source, preserving scoped preset loading.


Goal: add a module-wide Group direction / Local normals dropdown above the per-ID extrusion rows. Group direction remains the legacy default. Local normals uses the native MeshOp local-normal direction and must match the supplied CORRECT EXTRUDE fixture (boundary displacement 50 / 86.60254; middle 115.470054 for height 100).


Approach: reuse documented meshop.extrudeFaces dir:#independent for Local normals, retaining dir:#common for Group direction. No custom vertex-normal solver or radial/cylinder-axis special case. Preserve the existing inset stage and height/taper call, all material IDs, and the existing TPG Extrusion modifier identity.


Persistence: ExtrusionMode strings Group/Local in the existing INI; SPG_ExtrusionMode on generated nodes. Missing old data defaults to Group. Invalid explicit values are rejected. Include this setting in Load All and Load Extrude only. Old presets loaded in these two modes explicitly reset to Group; Panels/Hatch loads preserve the current mode.


Compound topology boundary: existing input face IDs are collected before any inset/extrude stage; MeshOp preserves those original face IDs through both stages. Only the direction parameter of the height/taper operation changes. No new compaction, base-object edits or cached vertex IDs are introduced.


Implementation sequence:
- [x] Add numbered full-pipeline regression stages to Tank-Panel-Generator-Test.ms with independent analytic expectations, signed heights, flat/bent input, adjacent regions, inset/taper, mode round trip and preset compatibility.
- [x] Add validated mode serialization plus optional mode arguments to generation/update and the native direction switch in Tank-Panel-Generator-FN.ms.
- [x] Add dropdown, layout/visibility, INI/object restoration and update-only handler in Tank-Panel-Generator.ms.
- [ ] Verify changed syntax, persistence routing and exact preservation of v0.072 behavior; archive the previous complete release and upload the canonical files in place.


Verification: use the existing explicit 0.01mm position tolerance. Native test execution is pending while the Max connector reports Session terminated / HTTP 429; static checks and diagnostic-oracle checks must be reported separately. Never promote v0.073 to stable without user confirmation.


## v0.071 — Fixed Material ID button click registration


- The twelve native rollout `dotNetControl` buttons use declared rollout `on ... Click` handlers, all routing to the existing `extrudeRowIdClick` function.
- Avoid attaching a rollout-local callback dynamically with `dotNet.addEventHandler`, which caused a `dotNetControl`-to-`dotNetObject` conversion error in 3ds Max 2026.
- No row spacing, color, ID semantics or geometry changes.


## v0.070 — Correct preset manager rollout lifecycle


- The rollout-local `preset_manager` starts undefined, then is instantiated as the first statement of the owning rollout's `open` callback.
- Construction occurs after rollout state initialization but before `refreshPresetNames()`, which requires a populated manager.
- Replaces v0.069's premature assignment to the unopened rollout instance.


## v0.069 — Rollout-safe preset manager initialization


- `surfacePanelGeneratorRollout.preset_manager` starts undefined and is assigned immediately after the rollout definition, using the owning script block's `ini_path` and `ini_section` locals.
- The preset manager therefore exists before `createDialog` invokes rollout-open callbacks, without the rollout compiler capturing unavailable outer locals.


## v0.068 — Preset constructor exported from the function script


- `Tank-Panel-Generator-FN.ms` explicitly assigns `::TPGPresetManager_v = TPGPresetManager_v` after declaring the struct. This publishes the constructor across `fileIn`'s nested scope, and the main script forward declaration allows the rollout to reference it at compile time.
- Both pieces are needed: the v0.067 main-script declaration alone left the constructor undefined at runtime.
- Generator geometry and modifier stack are unchanged. Full 3ds Max UI runtime validation remains outstanding.


## v0.067 — Presets loader compile hotfix


- The entry script declares global `TPGPresetManager_v` before compilation of the owning rollout, which initializes the preset manager after the dependent function script is loaded.
- No generator geometry, UI layout, storage format, or modifier-stack behavior changes in this hotfix. The user-confirmed stable MVP remains v0.065; v0.067 requires full UI runtime verification.
- The separate native Edit Poly experimental candidate remains unpromoted.


## DEVELOPMENT v0.066 — Presets, per-ID UI, object-offset orientation


- Baseline is the user-confirmed stable MVP **v0.065**. v0.066 is a development candidate pending full runtime verification.
- EXTRUDE per-ID row keeps 28px pitch and swaps displayed columns to **HEIGHT | INSET | TAPER**; ID 1..N appears in a colored, full-height clickable 28px button without inter-row vertical padding.
- A collapsible **PRESETS** root section sits immediately below PANELS/Extrude and before MATERIAL. Name field, preset dropdown and Save/Load/Rename/Delete handle named snapshots of full generator settings. Presets omit dialog location/collapse states and target-object references.
- Presets live in the existing `Tank-Panel-Generator.ini` as numeric `TPG_Preset_<id>` sections referenced by `TPG_Presets/IDs`. Numeric sections keep arbitrary user-entered names out of INI section keys. Preset load refreshes the editor and bound generator through existing update code.
- Generated TPG_Module uses `objectOffsetRot = (quat 0 0 -1 0)` and identity node `rotation = (quat 0 0 0 1)`, maintaining the Editable Poly > Bend > TPG Extrusion stack.
- Test: `TPG-v066-Regression.ms` exercises presets, node/object offset quaternion, and per-ID row layout. Native preset tests were blocked by the 3ds Max bridge safe mode and require authorized verification before promoting v0.066 to stable.


## CURRENT STABLE MVP — v0.065 (user-confirmed 2026-10-25)


TPG v0.065 is the accepted stable MVP and the baseline for future development. This supersedes the previous v0.059 stable designation. Preserve the v0.065 inset geometry and existing functionality when making subsequent changes. This designation changes documentation only; source versions and recorded test results remain unchanged.


## v0.065 — topology-derived facet-preserving inset (2026-10-25)


### Cause and geometry contract


The modifier's incoming TriMesh uses object coordinates: Bend leaves the cylinder axis along Y. The node's 90-degree rotation places that axis along displayed Z. v0.064 classified triangle edges using equal Z, then zeroed Z in its tangent and shifted Z extrema. Consequently it treated longitudinal edges as transverse edges and moved the centre seam off the source surface. The WALL-FIXER report's “obj” coordinates already include this node rotation; its “world” column applies it again. Tests 44–46 used a Z-axis synthetic patch and missed the actual generator representation.


The corrected operation counts undirected edge incidence inside each logical panel's selected triangles. Only edges used once form its boundary; triangle diagonals and internal facet seams are excluded. Directed incoming/outgoing boundary links determine the two incident border edges at each vertex. Each edge's inward vector is the cross product of its incident facet normal and its directed edge. The intersection of equal-distance boundary offsets gives displacement
`(inward_a + inward_b) * inset / (1 + dot inward_a inward_b)`.
For TPG's rectangular, developable panel facets, corner vectors lie in one facet, straight side vertices follow that facet, and axial-border seam vertices move along the seam. Interior vertices stay unchanged. No world-axis classification, coordinate equality, fixed vertex indices, positional snapping or hidden tolerance is used by the operation.


This retains native Inset's local offset semantics. It does not add clipping/remeshing or collision prevention for inset amounts that consume a panel or extend past its first facet/subdivision; such over-large amounts can invert faces, as with native Inset. The regression checks for inverted and degenerate faces within the tested valid inset ranges.


### Topology and preservation


The compound stage caches selected triangle IDs/corners and derives boundary targets before zero-height/zero-outline MeshOp extrusion. The original top-face IDs/corner correspondence map those targets onto the duplicated boundary vertices immediately after extrusion. No compaction/reindexing occurs inside that stage; all helper caches are discarded when it returns. The input is a TriMesh, so no Editable Poly dead-structure cleanup belongs in this stage. Per-panel regions continue to come from map channel 99; adjacent panels with the same material remain separate inset regions.


The persistent TPG Extrusion class ID, base object, Bend, material IDs, mask/repeat/subdivision options, zero-inset Height/Taper code and UI are preserved. Non-manifold or branching boundaries produce explicit diagnostics. The obsolete world-Z helper and its misleading Part 44 test are retired; Parts 45–46 remain supplementary tests.


### Runnable full-pipeline regression


In 3ds Max, run the canonical test file with this one-shot switch (replace the directory with the actual project location):


```maxscript
global TPG_InsetRegressionOnly = true
fileIn @"G:\AI\AGENTS\Maxscript\CODEBASE\Generators\Tank-Panel-Generator\Tank-Panel-Generator-Test.ms"
```


Parts 47–50 run directly from that file. They generate with nonzero Insets through `generateModule`, compare fresh Generate against subsequent `updateExtrusionOnly`, independently derive expected positions from the flat source grid and bent edges, verify all top corners against original facet planes, and check each rim quad's source plane, coplanarity, winding and Material ID. Eight configurations cover the reported case, open outer corners, same-ID neighbours, mixed-ID neighbours, all panels, one panel spanning the open circumferential seam, repeats and a rotated node. Subdivisions vary in both directions; Insets include fractional and different per-ID values.


Signed Height/Taper edits and return to inset-only verify stable base/Bend/extrusion identities and no accumulated drift. Native Edit Poly Group Inset—the operation used by the inspected `inset_faces.ms`—is the independent reference for the reported case. Test-only native modifier context is restored. Named undo entries and fixture nodes remain for inspection; generator binding is restored. Default execution without the switch retains the legacy UI suite before the new integration stages.


### Verified runtime results


Executed in connected 3ds Max 2026, PID 3592, with Tank-Panel-Generator.max open:
- Old v0.064 fails the new reported-case check at F57 corner 1: position error 100.0 mm.
- Eight full pipeline fixtures pass: 48 active panel instances, 2,364 top-face corner checks, 556 rim-quad checks.
- Maximum position error: 0.000488281 mm; maximum plane error: 0.000256062 mm. Explicit regression distance tolerance: 0.01 mm, converted through scene units.
- Native reference: 75 vertices / 116 triangles, matching TPG; maximum vertex-set difference 0.00000762939 mm.
- Signed Height/Taper round trip and persistent stack identity pass.
- Original reproduction's new boundary matches the supplied expected XY values, with displayed Z approximately -100 and -1650; raw floating-point rotation residuals are preserved.
- The historical suite was attempted but stopped at existing Part 12: MAXScript array identity comparison rejects two arrays with identical contents. Direct element checks confirmed makeCellIds returns six ID-1 values. Parts 47-50 run independently and pass; the remaining historical UI suite is not claimed as passing.


> **Current candidate: v0.064. Stable rollback baseline: v0.059 (2026-10-24).** The procedural extrusion is a development candidate requiring full generator/scene tests.


## v0.064 — inset all four source-panel boundary edges


- The v0.063 planar projection depended on MeshOp already displacing a vertex horizontally. At source corner vertices 53, 57, 58, 62, the outline moved them only in the longitudinal direction (141.42 for a requested inset of 100), so neither lateral edge inset.
- Capture source top faces and original vertex positions, build transverse same-local-Z adjacency, and identify the two boundary endpoints on each longitudinal ring. Compute lateral inward movement along the source facet tangent, and separately inset the two longitudinal ends exactly by the entered amount.
- MeshOp `extrudeFaces` now runs with zero outline solely to create rim topology. The generated top vertices are then set to the calculated positions; the existing persistent `TPG Extrusion` modifier and sheet/Bend generator remain unchanged.
- Regression Parts 44–46 cover measured four corners, axial-only points, planar fidelity and triangulated cylinder-facet edges. The isolated Parts 44–46 were executed successfully in 3ds Max 2026; full test suite and scene-reload checks still need native verification.


## v0.063 — inset corners constrained to the source facet


- Keep the current Bend-based generator and permanent `TPG Extrusion` modifier. The separately requested Lathe/profile generator is not part of this targeted inset correction.
- For each positive-Inset logical panel, capture the incoming source triangles' corner positions and facet normals before the MeshOp zero-height inset.
- After the MeshOp inset, project each displaced top corner's transverse movement onto its corresponding source triangle's plane. Normalize the projected transverse displacement to preserve the requested inset amount, retaining the original longitudinal movement.
- Do not recreate the persistent extrusion, Bend, base or bound node when Height/Inset/Taper changes. Preserve region isolation, face materials, map channel 99 and the existing migration behavior.
- Part 44 encodes the reported V53 and V57 offsets and the axial-only control point. The real native Edit Poly Inset Groups implementation in `inset_faces.ms` is the comparison reference. Planar projection is an interim MeshOp correction, not a full reimplementation of native Edit Poly Group Inset.
- No native 3ds Max geometry validation was available for v0.063; retain stable v0.059 until visual and saved-scene checks pass.


## v0.062 — persistent procedural TPG Extrusion


- New object stack from bottom to top: Editable Poly base sheet, 360-degree Bend, scripted SimpleMeshMod **TPG Extrusion**. This replaces the previous committed native Edit Poly operations for newly generated objects.
- Each base face stores its expanded logical cell ID and enabled state in private map channel 99. The procedural modifier reads it after Bend, forms per-cell groups for positive Inset or per-ID groups for zero Inset, and operates on the incoming TriMesh with MeshOp. Output geometry is recalculated without changing modifier identity.
- Height/Inset/Taper UI changes save only their rule-table metadata and increment the existing `TPG Extrusion.refresh_counter` parameter. They must preserve the node, baseObject, Bend and the **exact same extrusion modifier instance** across repeated edits.
- v0.061 native Edit Poly scenes are supported through a one-time migration on first numeric edit: tag the existing original base face mapping, disable old Edit Poly, insert new procedural extrusion, remove the legacy modifier only after the replacement has been inserted successfully.
- **Scene-load contract:** because `TPG Extrusion` is a scripted modifier, register its class by loading `Tank-Panel-Generator-FN.ms` each 3ds Max session before opening saved scenes that contain it. A proper scripted-plugin startup installer remains a separate follow-up.
- The procedural MeshOp implementation uses triangular evaluated geometry, unlike v0.061 polygonal Edit Poly. Native evaluation, negative heights, inset boundaries, taper and scene reopen must be tested before promoting this version to stable. The known stable baseline remains v0.059.


## v0.061 — version synchronization and rollout hotfixes


- Keep the main script, generator function file, persisted generator version and test suite synchronized at 0.061.
- Preserve the fixed v0.060 forward declaration for `extrusionSettingsChanged()` and removal of the accidental patch marker from the generator function file.
- The dialog title must continue deriving its displayed version from `project_version`; no hardcoded title string.


## v0.060 — extrusion-only live rule changes


- Height, Inset and Taper spinner changes and the Extrude action must update only the generator-owned `TPG Extrusion` Edit Poly. They may replace that owned modifier after successful evaluation, but must preserve the same scene node, Editable Poly base and `TPG:Bend` instance.
- Build face-region selections from the existing baseObject's face centers and saved grid metadata, caching the immutable logical-cell face map for subsequent spinner edits. Invalidate on node, base-object, layout or face-count change. Never reconstruct the plane or reassign the base face materials for a rule-only change. Positive Inset remains per logical panel; zero Inset may group same-ID panels.
- Keep the old owned Edit Poly disabled while the new Edit Poly is fully prepared and committed; only then remove the old modifier. If a native geometry operation fails, remove the candidate and reactivate the previous modifier.
- Save changed rule tables as object properties. Do not rebuild a linked hatch for a rule-only edit. Radius, length, grid, repeat and subdivision changes still call full Generate.
- `partOfTest42()` checks the original node handle, base object, Bend, rule persistence and face topology while changing Height, Inset and Taper; it also checks refusal of negative Inset. Run it inside 3ds Max before designating v0.060 stable.


## v0.059 — logical-panel inset isolation (2026-10-24)


Positive Inset must shrink **each enabled logical panel independently**, even when adjoining panels have the same Material ID. Material IDs remain global controls for numerical Inset/Height/Taper settings, but must not determine the boundary of an inset. A logical panel may contain multiple subdivided faces; process those faces as one panel region, never inset every subdivision face independently.


- Preserve the Editable Poly → Bend → Edit Poly stack and all base face IDs for the full compound Edit Poly operation.
- For each positive-Inset ID, retain one face BitArray per enabled tiled logical panel and apply grouped zero-height bevel, signed extrusion and taper to that panel region separately. This prevents neighboring same-ID faces from extending the inset boundary.
- For zero-Inset IDs, keep the previous grouped same-ID extrusion/taper behavior. No UI, rule-persistence, material palette or dialog-position changes.
- Part 41 compares nine adjacent same-ID panels against nine distinct-ID panels with identical Inset values. Both must produce the same topology count; the former must not merge the inset into a perimeter around all nine cells.
- Static validation may inspect grouping, but native 3ds Max geometry and visual tests remain required.


## v0.058 — registered floating dialog position correction (2026-10-24)


The active development baseline is v0.057. Keep its Reset button, fixed painting controls, material rules, generator stack, and UI dimensions unchanged.


- Save `PosX` and `PosY` as actual registered screen coordinates from the `moved` event or `DialogHost.saveDialogPosition`/`saveDialogState`.
- When recreating the owning dockable dialog, first unregister/destroy its previous CUI instance, load the current INI screen position, and pass `saved_pos - [6,29]` to `createDialog`. Register through the canonical `DialogHost.registerDockableDialog` and call `cui.FloatDialogBar`. Never call `setDialogPos` on a registered dialog.
- Suppress `moved`-event INI writes during the recreation sequence so the intermediate corrected creation coordinates do not replace the intended screen coordinates.
- Run one 500ms post-registration timer and print the saved position, actual restored position, remaining offset and within-1px result to the 3ds Max Listener. This check reports discrepancies without silently moving a registered CUI bar.
- `partOfTest40` checks correction arithmetic and that persistent `PosX`/`PosY` remain actual coordinates. The test suite and dialog version are v0.058; full native reopen/restart verification remains pending. The shared UI `DialogHost.ms` is unchanged.


## v0.057 — Material ID reset and default (2026-10-24)


- Exactly nine paint buttons (IDs 1–9); replace All/None with one **Reset** button.
- Newly created or expanded grid cells default to Material ID **1**. Existing saved or loaded IDs remain unchanged.
- Reset assigns ID 1 to every cell, including disabled cells, without changing enabled masks, selections or per-ID extrusion rules. Repaint existing grid controls in place; do not reconstruct the grid for an ID-only change.
- Part 12 verifies new/default IDs; Part 39 verifies Reset and preserved control identity.


## v0.056 — current UI contract (2026-10-24)


The stable MVP baseline is v0.055. v0.056 changes the owning UI and its regression tests only; geometry generation and the Editable Poly → Bend → Edit Poly stack retain their v0.055 behavior.


- The top-level PANELS section has a **Grid** caption for its Rows/Columns dropdowns. Every ComboBox has a WinForms tooltip; rows/columns explicitly state which grid dimension they control.
- The Extrude group lives **directly inside the PANELS rollout**, below the panel grid and nine-button ID palette. Inset, Height and Taper use native MAXScript spinner controls. There is no nested Extrude subrollout, inner scroll bar or dynamic rollout destruction/creation.
- Twelve static native spinner rows are reused as display slots. If more than twelve unique Material IDs are assigned to grid cells, Previous/Next switches the visible page; full 32-ID rule arrays and saved values are never truncated. Disabled grid cells still contribute their Material IDs. The section grows with the number of visible rows.
- Painting or changing a cell's Material ID must update its existing .NET grid button in place. A full grid-control rebuild is reserved for changes to logical row/column counts and explicit whole-grid operations. When the distinct used-ID list changes, update inline native spinner bindings and section positions without recreating grid buttons.
- Regression Part 38 asserts .NET cell-control identity across a Material ID assignment. Existing Parts 21/22/26/30 cover dropdown tooltips, layout, direct native spinners and high-ID pages. Runtime testing is left to 3ds Max, without using the Max MCP bridge.


## v0.055 — full-domain Edit Poly face selections (2026-10-24)


Root cause reproduced in 3ds Max 2026: SetSelection accepts a short BitArray but stores an empty selection. Padding the same selection to GetNumFaces stores it correctly. Extrusion then changes 12 faces to 16 and preserves face 1. Pad the per-ID face BitArray before every inset, extrusion, outline and zero-height bevel; pad side-material selections to the current full face count. Re-size after topology changes. No shared Codebase files changed.


Native isolated tests passed inset (20 faces), signed extrusion (24 faces) and taper with top face 2 retained. Original production generation reproduced the inset-selection failure. Part 37 adds a complete 96-face generator regression with inset, positive/negative height and elevated/zero-height taper. Raw source execution was blocked by plugin SAFE_MODE; no security settings were changed. Normal fileIn of the synchronized v0.055 source then succeeded. The end-to-end 96-face compound generation completed with 168 output faces and the two-modifier stack. The first final count assertion read zero with an inactive modifier context; Part 37 now activates the result Edit Poly before reading its native face count. Full test-suite and visual shape review remain pending.


## v0.054 — location-independent dependency discovery (2026-10-24)


The tool package can be moved to any folder. Tank-Panel-Generator-Dependencies.ms validates the shared UI and Epoly files, searches source ancestors, and reuses a configured shared Maxscript root. If none is available, select that root once. Store only this installation setting in the userScripts Tank-Panel-Generator-dependencies.ini; ordinary tool/UI settings remain beside the entry script. Both entry and standalone FN loading use the resolver. No shared library files are changed.


Part 36 covers nested and external tool locations and missing dependencies. Native testing attempted but blocked by BRIDGE_DOWN (selected Max process unavailable); runtime verification remains pending. The outstanding extrusion-selection issue is separate and remains unresolved.


## v0.053 — evaluate the new stack before the topology gate (2026-10-24)


The v0.052 report records base:96, Edit Poly:0, evaluated triangles:192 and an active Edit Poly. The previous gate read the native count before its diagnostic snapshot and never re-read it after evaluation. This is evidence of a missing evaluation boundary, but does not by itself prove which evaluation step initializes Edit Poly on the affected installation.


- Evaluate a temporary mesh snapshot and request a complete viewport redraw before the authoritative native polygon-count check. Keep Editable Poly → Bend → Edit Poly and the exact count requirement. The triangulated snapshot never supplies polygon IDs or replaces the base.
- Print native counts before/after evaluation and the evaluated triangle count. Include both native counts in the saved failure report.
- Restore selection/panel focus after a caught generation failure, remove an uncommitted temporary node and rethrow the original error. Update last_node/last_bend_mod only after successful generation.
- Extend test Part 35 with the reported 96-polygon layout after the existing cold-start fixture.
- Static validation only. No 3ds Max execution, no runtime pass claim and no confirmed resolution yet. Shared Epoly source is unchanged.


# Tank Panel Generator — Design / UI Contract


**Project version:** v0.056 (inline Extrude controls / in-place grid painting)


## Purpose


The module starts as an Editable Poly flat sheet with a Bend modifier producing cylindrical geometry. Logical panels have Around and Length counts; repeats tile the panel pattern around the circumference and along the module length. Subdivisions in both directions produce additional polygons *within* each logical panel without changing the paint grid. The unbent source pattern retains its physical proportions, but its *display preview* uses at least 50% of the grid host's horizontal width; when a tall/narrow pattern requires that floor, only the preview's horizontal scale is increased. The grid host remains 264px high. The default floating dialog is 288 × 1440 px: its width is unchanged, the Panels grid is always 252 × 264 px, and panel aspect ratio is preserved within that host.


## UI contract


Default/locked dialog width is **288 px**, with the original horizontal layout. Root groupboxes sit at 6px horizontal inset and occupy the dialog width minus 12px. Nested groupboxes use a 12px inset; grid and ID-row controls use 18px inset and expand with the host. Preserve right margins and avoid any `.width` assignment to native spinners.


Four independent top-level collapsible sections, in order:


1. **Main Module:** Radius and Length spinners have separate visible uppercase RADIUS and LENGTH labels aligned above their fields; the unit switcher remains alongside them. Around/Length repeat captions retain their meaning and follow underneath; Radius div. / Length div. / `postion preccision` remain on the same row. The wide Generate/Update button sits directly in Main Module, without a nested Generated Object rollout.
2. **Panels:** Logical panel counts and All/None controls sit directly under the Panels header, followed by the aspect-correct painting grid. There is **no LAYOUT sub-section**. Beneath the grid, exactly nine equal-width material ID buttons (1–9) fill a single row; there is no ID dropdown. Ctrl-click on individual panels toggles a cyan selection outline without changing their IDs or enabled states. Clicking a palette button assigns its ID to all selected panels (or changes the active single-cell brush when no selection exists).
3. **Material:** A full-width, independently expandable root section, visible even when Panels is collapsed. Multi-ID/Grey assignment and the saved mode are unchanged.
4. **Hatch:** A separate Lathe/Chamfer cap generator with independently owned modifiers.


**Extrude:** Below the ID strip, rows of native Inset/Height/Taper MAXScript spinners live directly in PANELS, one visible row per used Material ID (including IDs assigned to disabled cells). The fixed twelve-slot editor pages through larger sets of IDs without a nested rollout or scrollable subrollout. A wide Extrude button follows below. Thickness, Depth and New ID default-height dropdown are removed. The physical default for newly created per-ID Height is **1 cm**, converted through `units.decodeValue "1cm"`; old saved per-ID Height values remain intact.


## Grouped extrusion semantics


For each Material ID, collect the faces of all enabled matching logical panels, across repeats and subdivision directions. Connected same-ID faces remain a **Group**, not independent polygons; there are no internal inset borders between same-ID neighbours.


1. **Inset** builds a rim on the bent surface using a zero-height grouped bevel in Edit Poly above Bend.
2. **Height** uses signed grouped Edit Poly extrusion along the bent region normal. **Taper** applies signed equal-distance Outline to the elevated top. Zero-height taper uses a zero-height grouped bevel.
3. Historic Thickness/Offset data stays serialized but does not affect geometry.


Base topology remains flat. Preserve cached source face IDs and read back native top selections between compound stages; never compact during these operations.


## ID palette and persistence


Material ID 1 is muted grey, followed by muted red, green, blue, yellow, magenta, cyan and deterministic variants. Swatches display IDs 1..9 in one full-width line, with no dropdown. Historical IDs above nine and their stored rule arrays are preserved without automatic renumbering. A normal swatch click synchronises the painting brush and Height/Inset/Taper controls. With Ctrl-selected cells, a swatch assigns its ID to all those cells, and each modified Extrude field applies to every distinct material ID represented in the selection. ID properties serialize as lists alongside the existing mask, cell IDs, and geometry values. New IDs use a fixed physical default Height of 1 cm; persist the per-ID Height/Inset/Taper arrays and the subdivision dropdown choices.


## Unit, precision and modifier constraints


Geometric values remain in 3ds Max scene units. Fresh dialogs default to centimetres (the previous saved unit is honoured). Unit switching is display-only and must preserve backend values. `postion preccision` has the shared 1mm / 0.1mm / 0.01mm choices, and is used only for the explicit point-comparison contract. Max CUI owns outer dialog dimensions (do not call `setDialogSize` after registration); preserve .NET title restart button, INI position/height, left/right dockability and per-tool exact modifier ownership. Keep 3ds Max shared Codebase Functions/Operations/Tools/Toolsets read-only.


## Test requirements


- Fresh and legacy INI loading must preserve geometry and material mode; the ID picker is removed and the swatch row contains exactly nine equal-width buttons.
- Verify four independent root sections in order, with Material still visible when Panels is collapsed and with no nested Layout rollout.
- Verify all three spinners share one row in the order Inset, Height, Taper, with labels aligned above; verify the old Thickness/Depth/New ID widgets are absent and the nine material buttons can mass-assign IDs to selected panels.
- Verify root/nested groupboxes, grid, palette, and .NET controls use the dialog's horizontal width without clipping, while native spinners keep fixed widths.
- Verify preview aspect, no scrollbars, exactly 264px grid height regardless of available dialog height, CUI restart, non-destructive module regeneration, grouped ID extrusion and independent Hatch modifier ownership. Repeat Around must not alter the physical Radius; source pattern width shrinks by 1/repeat, source sheet stays 2*pi*Radius wide, the Bend completes a full 360-degree circle, and a cap follows the same Radius.


**Runtime status:** Static source validation only; execute test script in 3ds Max before production use.


## Rename and compatibility (v0.025)


The canonical Google Drive project folder, stable script entry point and companion script names are `Tank-Panel-Generator`, replacing `Surface-Panel-Generator`. Dialog titles, undo captions and new node names use the Tank branding. The saved settings file is `Tank-Panel-Generator.ini`, initially copied from the legacy `Surface-Panel-Generator.ini` if the new INI does not exist. The previous INI is retained without deletion.


The existing MAXScript API names (`SurfacePanelGenerator`, `CapHatchGenerator`) and `SPG_` scene user-property keys are intentionally unchanged to preserve in-session references, saved scene data and existing scripts. New owner markers use `Tank-Panel-Generator`; ownership validation accepts both new and legacy values. The older `Surface-Panel-Generator` dialog registration is closed during migration. Historical archived releases keep their original names.


## Dependency diagnostic update (v0.026)


The entry script requires `Tank-Panel-Generator-FN.ms` and `Tank-Panel-Generator-Cap-FN.ms` in the same directory. It never loads the old `Surface-Panel-Generator-FN.ms` files. When a dependency is absent, the error reports the running tool version, exact entry path and missing dependency, and tells the operator to synchronize the full renamed folder. The integration test checks all three required entry/dependency filenames before touching scene geometry. Old scene metadata and INI migration remain unchanged.


## Material mode persistence (v0.027)


The **Material** control saves the last successful Multi-ID or Grey selection as `MaterialMode=Multi` or `MaterialMode=Gray` in `Tank-Panel-Generator.ini`. Loading a new session restores the saved mode before any generation. Legacy INIs without this key default to Multi-ID; unrecognized values produce a Listener diagnostic and fall back to Multi-ID. The selection is stored only after successful material application to a bound object. Bend, cap ownership and scene-data compatibility are unchanged; the grouped inset implementation is updated.


**Runtime status:** Static validation only; run test stage 25 in 3ds Max to confirm both modes survive reloads.


## UI layout update (v0.027)


The previously prepared v0.027 material mode persistence change is included in the same unpublished revision. Layout now uses four root sections (Main Module / Panels / Material / Hatch), direct Panels painting controls, a 32-ID dropdown and one 9-swatch row, while Extrude uses two columns for Height/Inset and a following Taper row. Generate is placed directly under Main Module, the preview height ceiling doubles to 728px, initial units default to centimetres, and grouped Inset is now generated before Height extrusion. No shared-Codebase files were changed.


## Enlarged visible painting grid (v0.028)


The previous v0.027 release increased the grid host ceiling to 728px but left the default dialog width at 288px. Because the unbent preview fits its true sheet aspect into the host, the narrower dimension still limited the actual painted cells. The v0.028 wide-dialog experiment was reverted in v0.029; the default dialog is **288px wide and 1440px tall**, allowing a **252 × 728px** grid host with Main Module/Panels/Material expanded and Hatch collapsed. No width scaling is applied; only the grid element's maximum height is doubled. Existing INI-persisted dialog heights remain authoritative and users can reduce the height; grid dimensions still adapt to the available window and do not add scrollbars. Part 28 verifies the 252 × 728px tall/wide layout and aspect-ratio preservation.


## Grid height only (v0.029)


Revert the unrequested v0.028 dialog-width enlargement to **288 px**. Keep the current 1440 px default window height to provide vertical room, but enlarge **only the Panels painting grid** to a maximum height of **728 px** (twice the historical 364 px ceiling). The grid host remains **252 px wide**, and panel geometry and material controls do not change. The aspect-correct preview remains centred and has no internal scrollbars. Part 28 verifies 252 × 728 px in a 288 × 1440 px layout.


## Ctrl selection and bulk editing (v0.030)


- **Ctrl+left-click / Ctrl+right-click** on a panel toggles its cyan selected outline. This does not edit the panel material ID, mask/enabled state or generated geometry; no refresh occurs for selection-only operations. Ctrl+click a selected cell again to deselect it.
- Ordinary LMB paint dragging and RMB disable dragging are unchanged. A new grid size clears the transient selection; simple redraws do not.
- Nine **full-width, equally spaced Material ID buttons 1–9** replace the former dropdown-plus-buttons strip. Clicking one swatch paints its ID on every Ctrl-selected cell and enables those cells. Selection remains visible for subsequent work. Without a selection it changes only the active paint ID.
- **Height**, **Inset**, and **Taper** have explicit labels and native control tooltips explaining each operation; the Extrude action has a tooltip. With selected panels, changing one spinner applies *only that parameter* to each **distinct Material ID** present in those panels. This preserves the other parameters for those IDs.
- Extrusion rule values belong to **Material IDs globally**, not individual panels. If an ID also occurs on nonselected panels, changing that ID's extrusion parameter affects them as well. Assign a separate ID first if isolated per-panel extrusion is desired.
- Existing cell IDs above 9 remain in saved data and can still be selected in the grid for bulk extrusion edits; the nine palette buttons are the only active ID choices for painting. The dialog stays **288 px wide**, with the Panels preview host **252 px wide** and up to **728 px high**.
- Selection is UI-only and is intentionally not serialized. Tests cover Ctrl selection state, unchanged ID/mask on selection, bulk per-ID Inset, bulk palette assignments, nine-button sizing and removal of the dropdown. Static checks do not substitute for a 3ds Max runtime pass.


## Fixed painting grid height (v0.031)


The **Panels** grid host is exactly **264 px high** at all dialog heights, replacing the previous responsive 112–728 px behavior. Extrude spinners are vertically separated from the uppercase HEIGHT, INSET and TAPER labels, with the label above each editing field; each spinner has its own native MaxScript tooltip. Its width stays **252 px** at the original **288 px** dialog width. Parent Panels group height and the following palette/Extrude controls reflow relative to the fixed grid height. Preserve the existing proportional panel rendering, no scrollbars, UI interactions, geometry and saved preferences. The dialog width/height themselves are not changed. Static tests assert 264px instead of the old 728px limit.


## Palette callback hotfix (v0.032)


Predeclare the rollout-local `rebuildGrid` function in the existing forward-declarations list. The palette-click callback calls `rebuildGrid()` before its source definition; without explicit predeclaration, MaxScript can capture `undefined`, causing `Call needs function or class` when selecting a Material ID. Preserve the 264px grid, dialog layout, Ctrl-selection, Materials, Extrude and geometry. The palette-click regression test exercises swatch click and repaint.


## Repeat palette click fix (v0.033)


On clicking a Material ID button a second time, paletteButtonClick calls saveUiState() when the selected cells already have that ID. This function was declared later in the rollout, so the earlier event handler resolved the call as undefined. It is now included in the forward-declarations list, and the UI test exercises the no-change click branch. No layout, saved-data, geometry, or material behavior was otherwise changed.


## Fixed Radius with Repeat Around (v0.035)


`Radius` is the radius of the **finished** 360-degree module. The unbent source sheet spans **2*pi*Radius** in width regardless of Around repeat count. The source pattern repeats `N` times across that same circumference, so one original source-panel width is `(2*pi*Radius)/(columns*N)` and an entire source pattern occupies `2*pi*Radius/N`. Geometry still uses one tool-owned 360-degree Bend; the number of around divisions and their Material IDs continue to repeat as before. The panel editor's preview scales with this narrower source pattern, and changing the Repeat Around dropdown refreshes that preview and the bound geometry without altering Radius. Cap Hatch also uses the unchanged Radius. Repeat Length still increases overall module length, as previously designed. Historical `SPG_ExpandedRadius` is retained as a metadata key but now correctly stores the finished Radius, not Radius multiplied by Around repeats. Runtime regression Part 29 measures the pre-Bend plane for Around repetitions 1, 2 and 4, including constant circumference and matching source-panel widths.


## Native spinner X origin correction (v0.036)


All 13 native MAXScript spinners use an explicit **+64px X position offset** to compensate for the visually hidden native control origin. This is applied both to spinner declarations and runtime positions in Main Module (Radius, Length), Extrude (Inset, Height, Taper), and Hatch (eight numeric fields). The Hatch seam-count ComboBox is not a spinner and remains at its existing position; labels and non-spinner controls remain unchanged. The 288px dialog width, 252 × 264px Panels grid, spinner widths, all geometry and persisted values are unchanged. Native 3ds Max runtime inspection is required to verify visual positioning.


## Minimum painted-grid width (v0.037)


The **painted cells**, not the `.NET` grid host, must occupy at least **50%** of `dn_grid_host.ClientSize.Width`. First compute the normal aspect-fit scale from the physical source panel size and the host width/height. Set the displayed aggregate grid width to the greater of the naturally fitted width and 50% of host width. If the minimum wins, stretch **only the rendered cell X dimension** to achieve it; retain the naturally fitted cell height. Always centre both axes, keep every cell within the existing 252 × 264px grid host with no scrollbars, and retain actual geometric panel dimensions, Material IDs, click handling and INI values unchanged. When the natural grid width is already at least 50%, preserve physical proportions exactly. Regression tests must verify both the 50% minimum and the unchanged vertical fit rather than requiring identical X/Y scale when the floor engages.


## Main Module and persistent per-ID editing (v0.038)


Main Module keeps RADIUS and LENGTH headings above its dimension spinners. Remove auxiliary Around/Length and Radius div./Length div. labels; the Repeat row has a single leading Repeat label followed by two 58px dropdowns, and the final Main Module input row has the leading SUBDIVISION label followed by two 58px subdivision dropdowns. Unit, repeat, panel-count and subdivision dropdowns use the same 58px width as Radius/Length spinners. Remove the position precision dropdown and label from the UI, use a constant `0.01` internally for generation; historical PositionPrecision INI keys can remain but are ignored. The panel grid host remains 252 × 264px with the 50% rendered-grid width minimum.


Extrude shows one colored ID and independently editable Inset, Height, Taper NumericUpDown per distinct `cell_ids` entry, including disabled cells. Editing one field changes only that Material ID, not the active brush or Ctrl-selection. Hidden IDs are not deleted: all existing `rule_depths`, `rule_insets`, and `rule_tapers` arrays remain in `Tank-Panel-Generator.ini`; `RuleCount` stores their full length to prevent truncation on restart, even if a previously used high-numbered ID is absent from the current panel layout. Reassigning that ID restores the stored values. The editor only rebuilds rows when the used-ID set changes, or when explicitly refreshed after legacy control updates. Maximum nine rows are displayed without scrolling; further IDs are scrollable within the extrude editor, not the painting grid. Geometry ownership and material palette remain unchanged.


## Material extrusion slider controls (v0.039)


Replace each dynamic per-ID `NumericUpDown` with a `.NET System.Windows.Forms.TrackBar`. Each row has a small, colored ID label (remaining ~10% of the editor width) and three sliders for **Inset, Height, Taper**, each `floor(0.30 * dn_rule_rows.ClientSize.Width)` pixels wide, with 0–10 inclusive and a step/tick frequency of 1. Below each slider is a compact readout displaying the underlying *exact stored value*. Layout follows editor width changes and scrollbar appearance; each ID row uses 50px height and the editor displays up to nine rows before locally scrolling. Slider changes affect only that specific material ID and persist through the existing `rule_insets`, `rule_depths`, and `rule_tapers` arrays in `Tank-Panel-Generator.ini`.


Existing values outside 0–10 (including signed Taper or Height, decimals, and greater than 10) must **never be clamped, rounded or rewritten just by opening, refreshing, resizing, or rebuilding the UI**. Only the thumb is projected to the nearest available stop for display, while the separate readout displays the exact stored value. A deliberate slider move writes its integer 0–10 position as that property's new value; unused Material ID settings remain untouched until edited. Geometry and the 252 × 264px panel preview are unchanged.


## v0.041 — startup grid rendering


Based on restored v0.039. After createManagedDialog and posted-message processing, rebuild the grid and refresh its host. Initial grid count and bounds must be checked before palette callbacks. Preserve the v0.039 units and slider widths; do not restore the abandoned v0.040 changes. Live startup rendering is pending 3ds Max verification.




## v0.042 — reverse longitudinal material order


Map the first source row to negative local sheet Y and subsequent rows towards positive Y before Bend, reversing the previous longitudinal order. Use this same face-to-cell mapping for material IDs, masks and extrusion rules. Keep circumference order, palette colors, grid data and saved arrays unchanged. Part 31 checks initial-face material IDs with subdivisions and Around repeats.


## v0.043 — Main Module table


Use three columns: an 88px leading SIZE mm/cm/m selector (or Repeat/Subdivision caption), followed by 58px Radius and Length value fields at X=114 and X=194. Preserve +64px native spinner origins; align all three value rows and their headings. Remove Dimensions and standalone units controls. Main Module height is 224px, with normal-height controls and 34px row spacing. Save unit schema 2 and map unsupported legacy display units to metres without changing saved scene-space dimensions. Keep current per-ID slider widths and all v0.042 geometry.


## v0.044 — taper outline and height stages


For nonzero Taper, apply the same zero-height grouped bevel as Inset with outline=-Taper, then translate the current top-face vertices by signed Height along local sheet Z using polyop.moveVert on the base Editable Poly (useSoftSel:false). No combined nonzero-height bevel remains. Preserve cached original face IDs across the entire grouped operation; existing preflight compaction remains before caching and no compaction occurs between these stages. Taper zero retains native grouped extrusion. Part 32 measures all four border offsets with explicit 0.01mm precision; runtime confirmation is pending.


## v0.045 — native per-ID spinners


Replace all per-ID sliders/readouts with true MAXScript SpinnerControl fields, built via RolloutCreator inside sr_rule_rows. One child rollout contains every used ID and its colored badge plus Inset, Height, Taper. Each field has width/fieldWidth 58 at declaration, a +64px native origin correction and 28px row spacing. Keep up to nine visible rows with native subrollout scrolling. Preserve all INI arrays, hidden IDs, signed Height/Taper and fractional values; Inset stays nonnegative. Edits affect exactly the owning material ID. Native row creation is guarded against initialization callbacks. Existing SIZE units, grid startup and geometry remain unchanged. Runtime verification pending.


## v0.046 — object-backed generator editing


Main Module includes Load selected object above Generate. The operator selects one generated module, loads its stored properties, and resumes edits on the same scene node. Loading only restores editor state and binding; it never rebuilds mesh geometry. Generation remains the commit point for geometry data in SPG_* properties. Save editor unit, active paint ID and Hatch preferences alongside that record. Existing generated child Hatch data takes precedence over draft cap preferences. An absent cap clears previous cap references.


Read all user properties with getUserPropVal asString:true, then parse only expected numeric/mask/list formats; never evaluate stored object text. Validate the detached snapshot before applying UI state. Reject corrupt cardinalities, invalid IDs, negative inset, unsupported schemas, ambiguous caps or foreign modifier stacks with a diagnostic. Optional legacy rule fields have zero defaults. Arrays retain unused high IDs. Encode float rule arrays and dimensions using nine significant digits to preserve single-precision values.


New generation writes SPG_DataSchema=1 and SPG_GeneratorVersion=0.046. AppData slot 1847365210 identifies the exact generated modifier role (TPG:Bend, TPG:Lathe or TPG:Chamfer) across scene saves. A marker alone does not authorize changing other stack entries. Legacy compatibility requires a complete generator-owned record and its exclusive generated stack: one 360-degree, direction-zero, axis-zero Bend; or one generated child cap with Chamfer above Lathe and all cap settings. Never resolve ownership by display name or serialized session handles. Additional user modifiers block editing.


Part 33 exercises object restoration without session bindings, signed fractional high-ID values, a leading-zero mask, rejected corrupt metadata and the original node identity on continued update. Main Module grows by 30px for the load button. Other UI layout and geometry algorithms remain unchanged. Full scene save/reopen and live UI tests are pending native 3ds Max verification.


Existing child Hatch records override draft cap preferences before parsing drafts. Validate their complete profile with makeSeamRadii before binding; Part 33 covers invalid cap profiles and stale draft precedence. Static code review found no remaining important issue; native runtime verification remains pending.


## v0.047 — native row initialization lifecycle


Initialize ID badge .NET properties only in the generated child rollout open handler. Declare initial spinner values in their range parameters; guard native callbacks until owner_rollout exists. Do not write badge TextAlign/colors immediately after addSubRollout, when child .NET instances can still be null. Part 4 asserts badge initialization before any palette rebuild.


## v0.048 — native Extrude visibility


Create native rows only after ui_ready is set following managed window creation and posted-message processing. Child rollout has explicit width 236 and height 8+28*rowCount. ID labels and spinners are all native controls; no child .NET initialization remains. Keep native scrolling and stored values. Startup tests assert installed child count, used-ID row count and child height. Runtime confirmation pending.


## v0.049 — extrusion above Bend


Evaluation order is Editable Poly base → Bend → Edit Poly extrusion. In the Max stack UI, Edit Poly is at the top. Base topology contains only the subdivided sheet and material IDs. All enabled per-ID Inset, Height and Taper operations are committed in the owned Edit Poly after Bend. Inset uses a zero-height grouped bevel; signed Height uses grouped extrusion on the bent surface; signed Taper uses an equal-distance Outline of the elevated top (or zero-height bevel when Height is zero). Native top selection is read back between stages. No local-sheet-Z displacement remains.


Use the canonical shared `../CODEBASE/Functions/Epoly/EpolyCore.ms` and `EpolyFaces.ms` dependencies; synchronize those existing files alongside the project directory. Shared sources are unchanged. New records use SPG_DataSchema=2 and persistent TPG:Extrusion / TPG:Bend modifier roles. Read schema 1 and legacy single-Bend objects without modifying them; Generate rebuilds their stored settings into the new stack on the same node. Additional or reordered foreign modifiers block regeneration.


Validation: updated Parts 3, 6, 24, 27, 29, 32, 33 and 34 inspect the new stack, flat base, evaluated extrusion topology, grouped regions, signed post-Bend taper distances and object reload. Static source validation only. Native tests and visual geometry checks remain pending because the Max MCP endpoint returns 429.


## v0.050 — cold Edit Poly context initialization


Immediately after adding the owned Bend and Edit Poly, temporarily select the generated node, open Modify mode, activate its exact Edit Poly instance, and enter Face sub-object level. The native Edit Poly interface must expose precisely the base sheet's existing faces before any per-ID extrusion starts; abort with both counts if it cannot. Restore the scene selection, original command panel and previous stack focus after generation.


Part 35 exercises generation from a cold Create-panel context with no selected nodes and verifies extrusion topology and UI context restoration. A prior standalone 3ds Max diagnostic yielded `context:true selection:false requested:#{} stored:undefined faces:0`; runtime verification of this updated path remains pending while the MCP endpoint responds HTTP 429.


## v0.051 — native Edit Poly insertion


Insert Edit Poly with `modPanel.addModToSelection` on the generated node, with Bend selected in the Modify panel and sub-object mode disabled for insertion. Verify the resulting top-to-bottom stack is Edit Poly, Bend. Then activate Edit Poly Face level and Sub-Object selection mode before invoking the canonical Epoly operations. The previous `addModifier generated_node extrusion_mod` path is retired. Part 35 runs before the other generator tests and prints the base and post-extrusion face counts. Actual 3ds Max verification is still required.


## v0.052 — Google Drive diagnostic capture


When Edit Poly reports a polygon count different from the flat source mesh, log both counts and the triangulated face count of the evaluated node snapshot. Also log whether the owned Edit Poly is the current Modify-panel object and its selection mode. Save the raw diagnostic to `TPG-Topology-Debug.txt` beside the project source for later Drive-based inspection. The mismatch remains a fatal condition to prevent using stale face IDs or falsely marking an extrusion as completed; do not modify shared Epoly Functions or alter the stack topology without a confirmed native cause.










## v0.072 — Independent preset sections


- Choosing a preset from the Presets dropdown immediately invokes the complete existing Load All path; rebuilding the dropdown after Save/Rename/Delete does not apply a preset.
- The Load button retains its left-click Load All behavior. Right-click opens a native four-item menu for Load All, Load Panels Layout, Load Extrude Settings and Load Hatch Settings.
- Panels Layout loads Rows, Columns, Repeat Around/Length, Mask, CellIDs, MaterialMode, ActiveRuleID, Radius, Length, both segment counts, and dimension-unit fields. This may rebuild the existing bound module, but never creates a new one.
- Extrude Settings loads RuleCount plus Depths, Thicknesses, Offsets, Insets and Tapers. The backend still stores obsolete historical fields for backward compatibility; the active inset/height/taper values refresh only the existing extrusion modifier on a bound module.
- Hatch Settings loads only the nine Cap Hatch settings, refreshing an already-bound cap without generating an unsolicited hatch. It leaves module layout and extrusion arrays unchanged.
- Load All restores the union of those groups. All modes preserve user window position and collapse states. Saved preset INI schema and names remain backward compatible with v0.071.
- This is a code-level candidate until checked in a running 3ds Max dialog (menu invocation, dropdown interaction, partial reload, scene evaluation).




## v0.075 — MAXScript structure method binding fix


In `SurfacePanelGenerator_v`, `getOwnedStackParts()` must precede `canReplaceBoundNode()`, which must precede `syncChamferStack()`. MaxScript can bind forward-referenced structure functions to `undefined` when compiling, producing `Call needs function or class, got: undefined`. Keep this dependency order when rearranging the implementation. v0.073 is still the last user-confirmed stable MVP; v0.075 is an updated development release pending native regression Part 55.


## v0.076 — Extrude Material ID button host


The per-ID extrusion editor's colored ID buttons are created as child `System.Windows.Forms.Button` instances of one visible `dn_extrude_id_host` WinForms Panel. They are no longer standalone `dotNetControl` declarations with `visible:false` during CUI dialog creation. `rebuildMaterialRows` creates and binds twelve reusable buttons once; `layoutMaterialSpinners` repositions the host and each button, while native Height/Inset/Taper spinners retain their established positions and the +64px native origin correction. The ID host is brought to the front after every layout to prevent painting behind other rollout controls. Part 55 and startup UI verification remain required in 3ds Max.
