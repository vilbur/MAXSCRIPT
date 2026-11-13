## v0.092 — Fix initialization crash (2026-10-29)

- **Status: INIT STABLE**, user-designated on 2026-10-29. This is the preserved baseline for tool initialization and repeated dialog reopening; it does not replace the separate v0.083 overall geometry-stable designation.
- Corrected startup logging to use MAXScript's string append mode (`mode:"a"`), so a fresh `Tank-Panel-Generator-Startup.log` is created.
- The log identified `Unknown property: "count" in OK` during Hatch settings restoration. `copy scene_values` was a mapped array operation returning `OK`; `copy scene_values #noMap` now gives an independent array for legacy 9/13-value expansion.
- Added a Part 4 regression for legacy Hatch settings without mutating its input. In 3ds Max 2026, the previous entry crashed the process; the corrected entry opened, completed startup, showed 12 grid controls, and reopened successfully with one registered dialog. Geometry generation was not tested in this change.
- Archived v0.091 before replacing the canonical entry. The complete v0.092 project is preserved as `Versions/v0.092-INIT-STABLE`; v0.083 retains its designated overall stable status.

## v0.091 — Log startup exceptions (2026-10-29)

- Catch MAXScript exceptions during rollout-open initialization and dialog creation, append their full text to `Tank-Panel-Generator-Startup.log`, echo the error to Listener, then rethrow to preserve failure behavior.

## v0.090 — Startup stage logging (2026-10-29)

- Added best-effort timestamped logging to `Tank-Panel-Generator-Startup.log` beside the main script.
- Markers bracket dependency loading, prior-state capture, rollout open initialization, dialog creation and CUI registration, posted-message processing, material-row/grid initialization and script completion.
- Logging failures are reported to the Listener and do not block tool startup.
- Native crash localization requires a fresh 3ds Max launch; the last log marker identifies the last completed boundary.

## v0.089 — Native spinner initialization crash fix (2026-10-28)

- Restored every native MAXScript float spinner declaration from ±1.0e30 to the previously working ±1,000,000 bounds. The extreme v0.088 bounds were instantiated for the visible controls and 36 hidden per-ID controls during rollout creation, crossing into a native 3ds Max crash path before the dialog opened.
- Shared SIZE mm/cm/m display conversion and all v0.088 Hatch settings remain in place. Stored scene-unit values and geometry calculations are unchanged; only native UI control bounds changed.
- Added an entry-source preflight to the test suite that rejects any native spinner declaration containing 1.0e30 before the main script can be loaded.
- Static startup-range regression passes. Native 3ds Max startup confirmation remains pending. Archived v0.088; v0.083 remains the user-designated stable baseline.

## v0.088 — Shared tool units and Hatch seam/end controls (2026-10-28)

- All dimensional editor fields now follow Main Module SIZE mm/cm/m: Hatch, per-ID Height/Inset/Taper, module Seams and finishing Chamfer. INI/preset/node values stay in scene units; changing SIZE updates displays without regenerating geometry. Counts, IDs and the legacy internal Chamfer profile-depth ratio remain unitless.
- Hatch labels: Thickness → Inset radius, Depth (axial) → Thickness. Outer radius remains Radius + Inset radius; End radius must be strictly smaller. Historical CapThickness/CapDepth keys retain their meanings and scene-unit data.
- Exposed native cap seam controls: amount/Seam Width, insetAmount/Seam Stich Width, insetoffset/Seam Depth, insetsegments/Seam Segments, segments/Segments Top, materialID/Seam Material. Defaults are 1/0/5/0/0/99; addinset and setmaterial are always true internally. Layout has 4px extra gaps between related control groups. New options persist in INI, All/Hatch presets and node snapshots.
- Standalone Hatch now has owned Chamfer above Lathe, matching linked Hatch seam options; legacy one-Lathe standalone nodes are accepted for migration. Sparse material ID 99 gets one actual material slot rather than allocating 99 materials.
- Outer axial lip and first radial profile band share their material ID, excluding the outer-radius corner from different-material seam chamfer selection. Other radial seam transitions retain distinct IDs.
- Linked Hatch placement follows the module object transform (including objectOffsetRot/scale) and the bent cylinder axis at local Z=-Radius. Lathe axis is explicitly placed at the profile origin. Enter reverses the profile axis so thickness points outward at both ends.
- Added Cap Enter/Cap Exit checkboxes for module end placement (user confirmed these do not mean Lathe capStart/capEnd). Exit-only is the default. Each end has independent ownership metadata; disabled ends remove only exact validated owned nodes. SPG_HatchManaged retains management when both ends are off and across reload/restart.
- Read legacy 9-value Hatch drafts and new 15-value snapshots. Missing new seam-depth values consistently default to five selected SIZE units in UI migration. Legacy presets reset missing counts/IDs/end flags to the new defaults instead of inheriting a previous two-end configuration.
- Updated existing Hatch tests and added isolated Part 63 for real-UI unit round trips, native seam settings/material slot, outer-corner exclusion, transformed end placement, toggles and ownership. Reload the main script, set TPG_HatchOptionsRegressionOnly=true, then run Tank-Panel-Generator-Test.ms.
- Independent float32 unit/basis/material-group arithmetic and static source checks passed. A separate code review found two migration/reload issues, now corrected. Native 3ds Max execution, Lathe/Chamfer evaluation and visual alignment remain pending. Archived v0.087; v0.083 remains user-designated stable.

## v0.087 — Remove thickness walls at the cylinder seam (2026-10-28)

- After baking Shell into the flat Editable Poly, remove the two X-facing thickness end walls as one face-deletion batch. These are the walls that would overlap when Bend closes the cylinder. Keep Z-facing front/back skins and Y-facing axial rims.
- Order is now: bake thickness → remove seam end walls → Bend → weld incoming mesh → Inset/Height/Taper. Existing thick modules require one Generate/Update to rebuild the flat base; extrusion-only refresh does not migrate old source topology.
- Validate the expected two end walls per longitudinal subdivision before deletion. Run the existing topology preflight before reading face IDs, discard deletion indices immediately afterward, and compact dead topology once if necessary before rebuilding cell/material/map-channel data. No compaction occurs inside a face loop or the later weld/extrusion stages.
- Added isolated Part 62 for 2mm/8mm thick modules: preserve 48 front + 48 back + 24 axial-rim quads, remove every seam wall, then expect a 120-vertex/240-triangle welded shell and working Group/Local extrusion.
- Static checks only; native 3ds Max execution pending. Archived v0.086. v0.083 remains the user-designated stable baseline.

## v0.086 — Weld bent mesh before extrusion (2026-10-28)

- Added one native meshop.weldVertsByThreshold pass to the incoming bent TriMesh before collecting face regions or caching topology IDs. This closes coincident cylinder seam vertices before Inset/Height/Taper, including when the current rules have zero extrusion.
- Threshold uses SPG_PositionPrecisionMM converted explicitly from millimeters to scene units; legacy records missing the field use the existing 0.01mm default. Invalid precision aborts with a diagnostic.
- Welding affects the procedural modifier's mesh copy. The original flat Editable Poly, Bend, modifier class/instances and source map-channel 99 logical-cell ownership are preserved; face/vertex IDs are read afresh only after welding. No base-object collapseDeadStructs call or mesh compaction is inserted into the compound extrusion stages.
- Added isolated Part 61: a 65-vertex open bent grid must evaluate to 60 vertices after seam welding, with unchanged face count, materials and map tags. It also checks 0.05mm seam gaps against 0.01/0.1mm saved precision, Group/Local extrusion with Inset/Taper and original base/stack identity.
- Static checks only; native 3ds Max testing remains pending. Run TPG_BentWeldRegressionOnly=true before evaluating Tank-Panel-Generator-Test.ms. Archived v0.085 before replacement. v0.083 remains the user-designated stable baseline.

## v0.085 — Hatch spline-node segment queries (2026-10-28)

- Fixed linked-cap failure at the material-band setup and the identical standalone-Hatch call: numSegments now receives the newly created spline node before Lathe/Chamfer are added. The captured count is reused after modifier insertion/node replacement; no spline query is sent to the Editable Spline base-object wrapper.
- Cap module internal version 0.003 → 0.004; changed files carry project version 0.085. Generator geometry and Auto Length logic are unchanged.
- Corrected Parts 17/57 to inspect a temporary, modifier-free spline node instead of calling spline methods on baseObject. Part 57 also creates a linked cap, checks five material bands in both modes, and remains isolated from the unrelated Inset/Normal runners when TPG_HatchRegressionOnly=true.
- Static checks and Drive readback only; native 3ds Max testing has not been run. Archived v0.084 before replacement. v0.083 remains the user-designated stable release.

## v0.084 — Auto Length subdivisions (development, 2026-10-27)

- Extended the existing Length subdivision dropdown with Auto and retained numeric/manual choices. Existing saved counts are preserved; fresh settings select Auto.
- Auto resolves the nearest positive integer subdivisions per logical panel from `(Length / Rows) / ((2*pi*Radius) / (Columns * RepeatAround * ArcSegments))`. This targets square quads in the flat Editable Poly base before Seams/Bend/Extrusion. Repeat Length changes both total rows and length equally, so does not affect this per-panel count. Counts are not silently capped at the manual dropdown's 32 choices.
- INI and existing All/Panels preset scopes store LengthSegments=0 for Auto; numeric values stay manual. Generated objects store the actual positive SPG_LengthSegments for topology checks and SPG_LengthSegmentsAuto=1/0 for mode restoration. Legacy objects missing the flag load as manual.
- Added isolated Part 60 for actual base-face counts, scaled dimensions, long/short panels, Around subdivisions, Repeat Length, manual and legacy restoration, Auto bound-node regeneration, and scoped preset/INI round trips. Native runtime/UI execution is pending; arithmetic and static checks only.
- Archived v0.083 source/docs and available Lib contents before replacement. v0.083 remains the current user-approved stable release.

## v0.083 — STABLE RELEASE (user-approved 2026-10-27)

The user designated v0.083 as stable. It is the current baseline for subsequent development, superseding v0.079. This is a documentation-only status update: source code and version numbers are unchanged. No additional native 3ds Max runtime tests were executed for this designation. Earlier development/stable entries below are historical records.

## v0.083 — Equal Taper subdivision spacing (development, 2026-10-27)

- Fixed uneven ring subdivision spacing: v0.082 tapered only the ends of each cross-section, leaving its middle vertices unmoved. The supplied Group/Height=100/Inset=50/Taper=100 diagnostic measures approximately 111.05 / 261.05 / 261.05 / 111.05 between parallel axial edges.
- For nonzero Taper, redistribute upper ring vertices along the bent cross-section polyline between fixed tapered endpoints, solving for equal straight-line (chord) distances. Includes interior Length-subdivision rows and both Group/Local modes. Lower mesh, Inset-only and zero-Taper behavior stay unchanged.
- Reuse the source topology collected for boundary offsets. Ring adjacency follows exact local-Y row coordinates of TPG's cylindrical source; no world-axis/proximity lookup, topology reindexing or scene modifier replacement. Position precision is explicitly 0.01mm, used only as the numerical spacing residual limit, without snapping stored positions.
- Moving intermediate ring vertices reconnects the tapered surface facets; their old individual planes are not retained. Endpoints and sampled positions remain on the pre-redistribution top profile. This supersedes v0.082's interior-vertex and per-segment parallel-border contract for nonzero Taper.
- Added isolated Part 59 covering 24 full-generation configurations (signed Taper, zero/positive/negative Height, Inset 0/50, Group/Local), with two repeated panels and all three ring rows. Invoke with TPG_TaperSpacingRegressionOnly=true. This flag bypasses the unrelated legacy Inset/Normal runners.
- Numerical reproduction fails on the supplied v0.082 coordinates. Corrected diagnostic spacings are approximately 185.283 / 185.283 / 185.283 / 185.279. Independent float64 and float32 numerical checks pass 144 scaled/curved/signed ring cases. These checks do not execute MAXScript.
- Archived the active v0.082 source/docs and available Lib contents under Versions/v0.082. Native 3ds Max regression remains pending; v0.079 stays the user-designated stable release.

## v0.082 — Facet-preserving Taper parallel border loops (development, 2026-10-27)

- Taper now offsets the top border loops by signed equal-distance vectors parallel to the source face-region perimeter. MeshOp extrusion uses **zero outline**; Taper no longer delegates outlining to `meshop.extrudeFaces`.
- Shared border topology routine collects one-use boundary edges (excluding triangulation diagonals), constructs inward facet directions and corner miters, and moves the **newly created upper perimeter vertices only**. Interior top vertices retain the native Group/Local-normal Height displacement; lower border vertices remain fixed.
- Inset uses the same border-vector calculation as before, preserving its positive-distance semantics and zero-height rim. Signed Taper positive goes inward, negative outward. Heights and Taper=0 retain native MeshOp extrusion movement, map-channel 99 region ownership and original stack identities.
- The compound topology stage caches face/corner IDs before MeshOp extrusion, consumes them directly afterward, and discards them. No source Editable Poly or modifier identity is replaced.
- Part 58 adds 12 isolated signed/zero Taper × zero/nonzero Height × Group/Local-normal configurations on a subdivided square with an interior vertex, checking exact top border targets against 0.01mm and unchanged lower vertices. Native 3ds Max runtime execution is pending.
- Archived v0.081 in `Versions/v0.081`; v0.079 remains the last explicitly user-designated stable version.

## v0.081 — Hatch generation and Extrude button removal (development, 2026-10-27)


- Removed the redundant Extrude .NET button, its tooltip, Click handler, styling and layout space. Per-Material-ID Height/Inset/Taper spinner changes continue to update the persistent TPG Extrusion automatically.
- Replaced the native Hatch generate button with a prominent styled .NET `Generate Hatch` button (Click event). The Hatch action is no longer blocked when no module is bound.
- Without a module, Generate Hatch creates an editable `SplineShape` profile with exactly one native, generator-tagged Lathe modifier; the current profile, seam and subdivision controls drive its shape. Repeated Generate Hatch updates only the exact tagged standalone Hatch without changing its scene node.
- With a bound module, Generate Hatch preserves existing linked-cap generation (spline profile, native Lathe and owned cap Chamfer). Existing linked-cap update remains active. The new standalone Hatch does not silently attach to unrelated modules.
- Part 57 tests standalone creation and repeat update; Part 4 checks that Extrude button is absent and Generate Hatch is available. Static Drive inspection passed; native 3ds Max runtime remains pending. v0.079 remains the last user-approved stable baseline; v0.080 is archived in Versions/v0.080.


## v0.080 — Base Thickness in flat source mesh (development, 2026-10-27)


- Added a native Base Thickness spinner to Main Module, with dimension-unit conversion, INI, preset and object property persistence (`SPG_BaseThickness`). Defaults to 0 for legacy compatibility.
- Thickening occurs on the flat plane before Seams, Bend and TPG Extrusion: native Shell with `innerAmount=Thickness`, `outerAmount=0` is immediately baked into Editable Poly. The final stack contains no Shell modifier.
- Original +Z panel faces retain Material IDs and private map channel 99 logical-cell tags. New back/edge faces receive neutral tag [0,0,0] so the procedural extrusion never selects them. The generator continues to support zero thickness as before.
- New isolated Part 56 tests shell collapse, 2mm and 4mm base geometry, tags and user-property persistence, and in-place bound-node update. Native 3ds Max 2023/2026 testing has not been run.
- Previous stable v0.079 is archived before promotion. This is not yet designated stable.


## v0.079 — STABLE RELEASE (user-approved 2026-10-27)


**Status:** v0.079 is the current stable TPG baseline by explicit user designation. Source code and behavior unchanged; native 3ds Max regression has not been independently executed during this status update.


### Bundled local UI library (2026-10-27)


- Forked the five UI helpers IniSettings, RolloutState, DialogHost, ScriptReload, and ToolTitleButton from the shared Codebase into Tank-Panel-Generator/Lib/.
- Removed external shared-root discovery, Epoly dependency checks, and path selection from the startup.
- The main script now loads all UI helpers relative to its own folder and reports a missing local Lib file by exact path.
- Prior dependency resolver is retired from active files. Move/copy the complete TPG directory together.
- Part 36 now loads and validates all five local helpers. No geometry, modifier, material, preset or other UI behavior changed.
- v0.078 archived before release. Only static verification performed; live 3ds Max regression pending.


﻿## v0.078 — TPG Chamfer material option and Segments (2026-10-25)


- Set only the finishing `TPG_Chamfer` native Chamfer to `materialoption = 2`; the separate pre-Bend Seams Chamfer keeps material option 1 and Segments 0.
- Added Chamfer **Segments** spinner (integer 0–100, default 1). It updates the existing owned Chamfer modifier in place, without rebuilding the base mesh or replacing extrusion.
- Persist Segments in the main INI, full/Chamfer presets, and bound object user properties; older presets default to 1. Existing generated objects without the property recover the current native modifier value.
- Rename the tool-owned finishing modifier to `TPG_Chamfer` so `$.modifiers[#TPG_Chamfer]` addresses the requested instance by name; internal ownership continues to use AppData, not names.
- Extended Part 55 regression to check defaults, scoped modification, instance identity and object-property round trips. Static source verification completed; native 3ds Max runtime execution pending.


## v0.074 — Native Seams and finishing Chamfer (2026-10-25) — candidate


- Fixed missing extrude-row Material ID buttons on first dialog opening: the end-of-creation hook now rebuilds the twelve native ID/spinner slots after `ui_ready` becomes true, before drawing the grid. Previously the initial rebuild returned early and the row buttons retained `visible:false`.
- v0.073 is the user-confirmed stable baseline and remains recoverable. Added independently collapsible Seams and Chamfer sections.
- When Seams is enabled, a native Chamfer named `TPG Seams` goes **below Bend** and filters material boundaries. The user reference settings are applied exactly (Amount 10 and Inset Offset 20 by default, 0 Segments).
- When finishing Chamfer is enabled, native `TPG Chamfer` goes **above TPG Extrusion**. Its Amount is capped below active nonzero Height, Inset and Taper values.
- Optional native Chamfers and their settings are saved to object properties and full/scoped presets. Bound-node safety checks permit only the exact tagged stack.
- Extrusion keeps channel-99 face ownership checks and excludes mixed-cell seam triangles; new Max runtime Part 55 tests enabled extrusion + Seams and verifies no modifier replacement during live Height edits.
- Static tests pass; 3ds Max execution **not performed**, so this revision is a candidate, not a new stable designation.


## v0.073 — Local normals extrusion (2026-10-25)


- Continued from v0.072, preserving automatic preset loading and its four scoped Load menu options. v0.071 remains the user-designated stable MVP.
- Added Group direction / Local normals above Extrude rows. Group direction retains the existing native cluster-normal operation. Local normals selects the documented native MeshOp independent-normal direction on the same TPG Extrusion modifier.
- Mode switches use the existing extrusion-only update; ordinary switches do not recreate the base, Bend or TPG Extrusion. Inset geometry code is unchanged.
- Persisted ExtrusionMode in INI, object metadata and All/Extrude presets. Old scenes and old All/Extrude presets default to Group; Panels/Hatch preset loads preserve the current extrusion mode.
- Added Parts 51–54 in Tank-Panel-Generator-Test.ms: reference and negative height, flat surface, adjacent panels, inset, nonzero taper, signed plane offsets, mode round trips, modifier identity, direct generation, legacy objects and scoped presets. Run with TPG_NormalRegressionOnly=true. The existing TPG_InsetRegressionOnly flag still runs only Parts 47–50.
- Verification: lexical/static checks and independent numerical comparison with the uploaded diagnostics passed. The CORRECT EXTRUDE coordinates match the analytic oracle within 0.01 units; the uploaded Group result fails it by up to 51.763809 units. These are diagnostic-data checks, not execution of v0.073.
- Native 3ds Max and UI regression execution NOT RUN: the connector returned Session terminated and then HTTP 429. In particular, equivalence of native MeshOp local-normal corner compensation to the reference remains runtime-unverified. v0.073 is a development candidate, not a new stable designation.
- Previous complete v0.072 root source set archived in Versions/v0.072 before publication. Shared codebase sources unchanged.


## v0.071 — Native .NET button event binding (2026-10-25)


- Replaced dynamic `dotNet.addEventHandler` calls on the twelve rollout-owned Material ID `.NET Button` controls with declared `on ... Click` handlers.
- The dynamic call used a rollout-local function and a `dotNetControl` wrapper where an event-handler target could not be converted to a .NET object; native rollout handlers preserve ID click behavior without that conversion.
- Preserve 28px rows, Material ID colors, spinner geometry and existing preset/geometry settings. Full 3ds Max startup and click testing follows publication.


## v0.070 — Initialize presets in rollout open event (2026-10-25)


- Instantiate `preset_manager` at the start of `on surfacePanelGeneratorRollout open`, after 3ds Max initializes rollout-local fields and before any preset dropdown is refreshed.
- The v0.069 assignment before `createDialog` was reset when 3ds Max opened the rollout, leaving `preset_manager` undefined. This resolves the `getPresetNames` property error.
- Verified the constructor-in-open lifecycle independently in a temporary 3ds Max rollout; full tool startup verification follows publication.


## v0.069 — Rollout preset initialization scope (2026-10-25)


- Initialize the preset manager on the rollout instance after its definition, rather than in a rollout-local declaration that captures outer `ini_path`/`ini_section` values.
- This addresses the runtime `Code block not created, unable to access code block local or parameter: ini_path` error that became visible after resolving the constructor symbol.
- Preserve the v0.068 constructor export and all existing generator/geometry behavior. Full UI startup requires native revalidation.


## v0.068 — Preset constructor scope fix (2026-10-25)


- Corrected the runtime error at the main rollout's `preset_manager` initializer. The previous v0.067 entry-point declaration removed the compile error, but left `TPGPresetManager_v` undefined after loading the separate function file inside a scoped block.
- `Tank-Panel-Generator-FN.ms` now explicitly exports its locally compiled struct constructor with `::TPGPresetManager_v = TPGPresetManager_v` after the struct definition. The main entry point retains its global forward declaration.
- No preset INI format, geometry, object or modifier behavior changes. Native full-UI launch verification is still required after synchronization.


## v0.067 — Presets loader compile hotfix (2026-10-25)


- Declared `TPGPresetManager_v` as a global before the main rollout is compiled. The constructor is defined when `Tank-Panel-Generator-FN.ms` is loaded, but its use in a rollout-local initializer must also be visible to MAXScript's compiler.
- Changed only the entry point's symbol binding and project version. Preset storage, generated mesh topology, extrusion, and modifier stack behavior are unchanged.
- Verified the forward-declared constructor/rollout pattern in connected 3ds Max 2026; the complete generator UI was not opened by this test.
- Archived the prior v0.066 source in `Versions/v0.066/` before publishing. The separate native Edit Poly candidate is not promoted into this hotfix.


## v0.066 — Development candidate (2026-10-25)


- Extrude UI columns changed from INSET | HEIGHT | TAPER to HEIGHT | INSET | TAPER. Row pitch remains 28px.
- Replaced 12 native material-ID row labels with zero-gap, full-row-height colored .NET buttons. Clicking IDs 1..9 selects the paint ID without editing cell assignment.
- Added collapsible PRESETS section between PANELS/Extrude and MATERIAL: save, load, rename and delete named snapshots of all generator settings except dialog layout state.
- Added `TPGPresetManager_v` storage using the existing TPG INI, preserving stable numerical preset identifiers and per-ID rule arrays.
- Module output orientation now uses `objectOffsetRot = (quat 0 0 -1 0)` with identity node rotation while keeping the original modifier stack.
- Added a dedicated v0.066 MaxScript regression and a static structure test. Runtime save/load tests were blocked by the 3ds Max bridge safe mode; release remains unverified.


## CURRENT STABLE MVP — v0.065 (user-confirmed 2026-10-25)


TPG v0.065 is the accepted stable MVP and the baseline for future development. This supersedes the previous v0.059 stable designation. Preserve the v0.065 inset geometry and existing functionality when making subsequent changes. This designation changes documentation only; source versions and recorded test results remain unchanged.


## v0.065 — actual source-boundary inset (2026-10-25)


- Replaced v0.064's wrong-axis/equal-Z triangle-neighbour classification with oriented, one-use boundary edges and incident-facet inward offsets. Internal diagonals/seams no longer drive corner selection; both sides and axial borders remain on their source facets.
- Preserve TPG Extrusion, Bend/base identity, material rules, UI and non-inset operations. FN internal version 0.024 → 0.025; main/test/project metadata 0.064 → 0.065.
- Added runnable complete-generation Parts 47–50 and the one-shot TPG_InsetRegressionOnly flag. Retired misleading helper-only Part 44; retained supplementary Parts 45–46.
- 3ds Max 2026: eight full-generation/update configurations passed, covering 2,364 top corners and 556 rim quads; maximum position/plane errors 0.000488281/0.000256062 mm against explicit 0.01 mm tolerance. Native Group Inset reference matches 75v/116f with maximum vertex difference 0.00000762939 mm. Signed Height/Taper and stack-identity round trip pass.
- New regression correctly rejects old v0.064 with a 100 mm corner error. The historical suite stops at pre-existing Part 12 array-identity comparison; direct element checks pass. The remaining legacy UI suite is not claimed as passing. See design.md for exact geometry contract, runtime checks and runnable command, including native-style oversized-inset limitations.
- Archived all eight prior canonical release files under Versions/v0.064 before replacement. Shared Codebase and reference inset_faces.ms are unchanged.


## v0.064 — complete four-edge inset for bent panels (2026-10-25)


- Fixed the remaining v0.063 defect at vertices 53, 57, 58 and 62: the negative MeshOp outline produced no lateral movement and moved corner Z by approximately 141.42 instead of 100.
- Compute the top vertices from the original source cell edges. The two lateral boundaries move inward along their source facets, and both longitudinal edges inset by exactly the requested amount. Use zero-outline MeshOp extrusion for rim topology only.
- Updated regression Part 44 for all four corners and Part 46 for a triangulated faceted cylinder patch; Part 45 retains source-face-planarity checks. The isolated Parts 44–46 ran successfully in 3ds Max 2026; full generator tests remain pending.
- Preserve `TPG Extrusion` modifier identity, original Bend/base, material rules and archived v0.059 stable baseline. No external Codebase or `inset_faces.ms` files modified.


## v0.063 — planar inset-corner candidate (2026-10-25)


- Addressed corner artifacts from `meshop.extrudeFaces` with negative outline by constraining inset-corner motion to the source cylinder facet plane.
- Kept `TPG Extrusion` as a persistent SimpleMeshMod and left the Bend-based base generator intact. The native Edit Poly Group Inset plugin (`inset_faces.ms`) supplied the geometric reference; the interim correction uses MeshOp plus planar projection.
- Added Part 44 using measured problematic left/right corners and a control point, plus Part 45 exercising MeshOp on two triangles in a 45-degree plane. Numerically checked the corner projections; native 3ds Max scene evaluation and the full test suite remain unverified. v0.059 remains stable.


## v0.061 — synchronized version after v0.060 hotfixes (2026-10-25)


- Bumped canonical `Tank-Panel-Generator.ms`, `Tank-Panel-Generator-FN.ms`, generated object metadata, and the test suite to project version `0.061`; advanced the changed function file version to `0.021`.
- v0.060 had two corrected load-time errors: an accidental leading `+` in the function source and a missing rollout-local forward declaration for `extrusionSettingsChanged()`. Those corrections are retained.
- Archived the complete previous eight-file v0.060 release in `Versions/v0.060`. v0.059 remains the user-designated stable MVP. Native 3ds Max runtime verification of v0.061 is pending.


## v0.060 — fast Height / Inset / Taper editing (2026-10-24)


- New `SurfacePanelGenerator.updateExtrusionOnly`: preserve the original bound node, Editable Poly base and Bend; rebuild only the marked `TPG Extrusion` Edit Poly. Cache immutable base-face mapping across successive rule edits.
- Spinner changes to Height, Inset and Taper now take this fast path. Extrude button uses the same path; structural Generate remains unchanged.
- Old extrusion stays disabled as a rollback candidate until the new modifier finishes its native Edit Poly operations. Preserve the previous owned extrusion on geometry failure.
- Update `SPG_RuleDepths`, `SPG_RuleInsets`, `SPG_RuleTapers` directly without touching the module's materials or cap.
- Added Part 42 to verify node/base/Bend identity, new extrusion and refusal of invalid Inset; native 3ds Max execution is pending. v0.059 remains the stable baseline in Versions/v0.059; v0.060 is not yet user-designated stable.


## PREVIOUS STABLE MVP — v0.059 (user-designated 2026-10-24)


- v0.059 is the accepted stable development baseline for future Tank Panel Generator changes.
- Stable status is a user designation; no production code was changed and no additional 3ds Max runtime test was performed for this designation.
- Proposed future Inset/Taper optimization is not included in this baseline.


## v0.059 — isolate Inset per logical panel (2026-10-24)


- Fixed positive Inset merging neighboring panels that have the same Material ID. Every enabled logical panel now gets its own inward inset boundary while retaining shared per-ID values.
- Kept the existing grouped same-ID extrusion when Inset is zero; preserved the modifier stack, UI, settings and material rules.
- Added regression Part 41 comparing same-ID and distinct-ID adjacent inset topology. Native 3ds Max test pending.
- Updated `Tank-Panel-Generator-FN.ms`, `Tank-Panel-Generator.ms`, `Tank-Panel-Generator-Test.ms`, `design.md`, and `changes.md`.


## v0.058 — floating CUI dialog position restore (2026-10-24)


- Base this change on the current v0.057 source, preserving Reset and the existing panel/material editor.
- Registered dialog creation now subtracts the measured `[6,29]` CUI offset from the saved actual screen position before `createDialog`, then registers/floats the dialog through shared DialogHost operations.
- Prevent transient position writes during dialog reconstruction; continue saving the actual registered position on movement, close and title-button restart.
- Add a one-shot 500ms Listener diagnostic for `saved`, `restored`, and `remaining offset` (PASS within one pixel). Add Part 40 for correction arithmetic and actual position persistence. Static validation only; no 3ds Max MCP/runtime testing.
- The shared `UI/Default/DialogHost.ms` remains read-only; all changes stay in this project.


## v0.057 — default ID 1 and grid Reset (2026-10-24)


- Keep exactly nine Material ID palette buttons (1–9). Replace All/None with Reset.
- Fresh and expanded cells default to ID 1; saved/historical IDs remain intact. Reset assigns ID 1 throughout the grid, preserving enabled mask, Ctrl-selection and all per-ID extrusion rules. Repaint existing .NET grid controls without reconstructing them.
- Update Parts 12 and 39; static checks only, no 3ds Max runtime execution.


## v0.056 — inline Extrude controls and in-place Material ID painting (2026-10-24)


- Keep v0.055 as the stable MVP baseline. Move the native per-Material-ID Inset, Height and Taper spinners directly into the PANELS root rollout, beneath the paint grid and ID palette; remove the scrollable Extrude subrollout. Twelve native rows are reused, with Previous/Next pages for more than twelve distinct assigned IDs. All historical and unused Material ID rule values remain in the underlying arrays.
- Rename the panel-count caption from "Panels" to "Grid" and provide explicit WinForms tooltips on the Grid Rows/Columns dropdowns (and the other existing dropdowns).
- On palette Material ID assignment, repaint only the affected grid cells and update the affected native row bindings. Do not destroy/recreate the grid buttons. Recalculate section height only when the set of used Material IDs changes.
- Extend regression coverage with Part 38 for grid-control identity during Material ID assignment; Parts 21/22/26/30 cover inline native controls, layout, tooltip text and high-ID paging. Static checks performed; native 3ds Max execution intentionally not performed. Unchanged generator geometry and modifier code stays at v0.055.


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


# Tank Panel Generator — v0.052 (2026-10-24)


- Instrument the still-failing Edit Poly face-count precondition with both polygon counts, evaluated stack triangle count, active Modify-panel modifier state and Edit Poly selection mode.
- On mismatch, write `TPG-Topology-Debug.txt` beside the executing source to allow collecting native evidence via synchronized Google Drive without any 3ds Max MCP connection.
- Preserve the abort on missing or incompatible input topology; no speculative geometry conversion or shared Codebase modifications.
- Continue to run cold-start Part 35 first. The native geometry failure remains unresolved pending the recorded counts.
- Preserve v0.051 in `Versions/v0.051`.


---


# Tank Panel Generator — v0.051 (2026-10-24)


- Insert the owned Edit Poly through `modPanel.addModToSelection` while the generated node and Bend modifier are active in Modify mode; this follows Autodesk's documented selection-aware insertion path.
- Enable Edit Poly Sub-Object selection mode before selecting faces, preserving the exact base → Bend → Edit Poly stack.
- Pass a named BitArray to the in/out `SetSelection` parameter when clearing the face selection.
- Run cold-start integration Part 35 before other generator tests and log base/final face counts. Native confirmation remains pending because 3ds Max MCP returns HTTP 429.
- Archive v0.050 under `Versions/v0.050`; leave shared Epoly Functions untouched.


---


# Tank Panel Generator — v0.050 (2026-10-24)


- Initialise the owned Edit Poly modifier in the active Modify context before selecting faces and performing grouped extrusion above Bend.
- Validate the modifier's initial face count against the source Editable Poly; report both counts if modifier evaluation is unavailable instead of reporting a misleading extrusion failure.
- Restore the prior scene selection, command panel and Modify-panel stack focus after generation.
- Add Part 35 to reproduce extrusion from a cold Create panel and verify restored UI context. Native 3ds Max verification pending (MCP bridge HTTP 429).
- Keep previous v0.049 in `Versions/v0.049`; canonical Epoly shared helpers remain read-only.


---


# Tank Panel Generator — v0.048 (2026-10-24)


- Defer native Extrude child creation until managed parent creation and posted-message processing finish. Explicitly set child width/height so rows occupy visible space.
- Use native ID labels alongside native spinners, removing child .NET badge initialization. Palette swatch colors remain unchanged.
- Startup tests require one installed child rollout, all used-ID rows and sufficient child height.
- Static checks only; live UI verification blocked by MCP 429.


---


# Tank Panel Generator — v0.047 (2026-10-24)


- Fix null ID badge TextAlign error during native child rollout creation. Initialize Text/TextAlign/colors in the child rollout open handler, after its .NET controls exist.
- Initialize native spinner values in their declarations and guard callbacks until the owner reference is installed.
- Part 4 checks ID badge text/alignment immediately after startup. Geometry and object-data persistence unchanged.
- Static checks only; native runtime confirmation pending.


---


# Tank Panel Generator — v0.046 (2026-10-24)


- Add Main Module Load selected object. Read stored grid/mask/IDs, all per-ID rule arrays, dimensions, repeats, subdivisions and material mode before changing editor state. Load without generating geometry; future edits update the same node.
- Save SIZE display unit, paint ID and cap editor settings on the bound module. Reload an unambiguous generated child Hatch with its exact Lathe/Chamfer references; clear the previous module cap binding when absent.
- Persist schema/version and AppData ownership markers on newly generated Bend/Lathe/Chamfer instances. Legacy records use a documented complete-record/stack validation contract; foreign stack entries reject loading.
- Read user properties as strings without evaluating stored text. Validate schema, counts and values; reject corrupt records. Preserve leading-zero masks and hidden rule IDs. Use nine significant digits for single-precision rule/dimension/cap values.
- Add Part 33: detached read without session references, mask/ID/rule restoration, invalid record rejection, unchanged node/transform on load and continued same-node update.
- Validate the complete restored Hatch profile before binding; valid child data overrides stale draft preferences. Part 33 covers both cases.
- Static checks and code review completed. Live testing remains blocked by MCP 429; run the supplied test suite in 3ds Max.


---


# Tank Panel Generator — v0.045 (2026-10-24)


- Replace per-ID TrackBars with native MAXScript float spinners in one scrollable child rollout, built with Autodesk RolloutCreator. Each used ID retains its colored badge and independent Inset/Height/Taper fields.
- Native fields are 58px wide at normal height, with +64px spinner X-origin correction; no runtime spinner width writes. Compact 28px rows retain nine visible rows and local scrolling.
- Preserve fractional, negative Height/Taper and >10 values directly in spinner fields and all existing INI arrays. Hidden IDs retain their values. Update Parts 26 and 30.
- Geometry and unit behavior unchanged. Static checks only; live UI validation blocked by MCP 429.


---


# Tank Panel Generator — v0.044 (2026-10-24)


- Separate Taper outline from Height: use the same zero-height grouped bevel as Inset, then move the top-face vertices in local sheet Z with soft selection disabled. Preserve signed taper and height.
- Keep initial face IDs valid across inset/taper/height and grouped ID processing; no intermediate dead-topology compaction.
- Add Part 32: measure all four border offsets on a 100 x 1000 region, both Height/Taper signs, subdivisions and optional Inset, using explicit 0.01mm comparison precision.
- Native API calls verified against Autodesk documentation. Static checks only; live geometry test blocked by MCP 429. Uniform outline remains pending runtime confirmation.


---


# Tank Panel Generator — v0.043 (2026-10-24)


- Replace Dimensions and standalone units with SIZE mm/cm/m in the first table column.
- Align Radius/Length, Repeat and Subdivision into two consistent value columns; compact Main Module vertical spacing.
- Save DimensionUnitSchema=2; migrate legacy Scene/in/ft to metre display while preserving stored system-unit dimensions.
- Keep v0.039 slider widths, startup rendering fix and reversed longitudinal mapping. Update unit/table regression tests.
- Static checks only; native 3ds Max verification pending.


---


# Tank Panel Generator — v0.042 (2026-10-24)


- Reverse source-row mapping along module length. Material IDs, enabled mask and per-ID extrusion follow the same reversed rows. Around direction, palette slots, preview data and persisted arrays remain unchanged.
- Add Part 31: material direction on pre-Bend faces with Around repeats and subdivisions.
- Static validation only; live 3ds Max verification pending.


---


# Tank Panel Generator — v0.041 (2026-10-24)


- Based on restored v0.039; the abandoned v0.040 SIZE/slider changes remain reverted.
- Rebuild and refresh the Panels grid after managed CUI window creation and posted sizing, so startup does not depend on an ID click.
- Test Part 4 checks initial cell count and bounds before invoking palette/rebuild callbacks.
- Static validation only; live MCP returned 429, so startup rendering remains to be confirmed in 3ds Max.


---


# Tank Panel Generator — v0.039


- Replace every per-Material-ID Extrude Inset, Height and Taper NumericUpDown with a horizontal TrackBar slider.
- Set each slider to integer positions **0–10 inclusive**, step 1, and width **30% of the editor client width**; the remaining ~10% holds the colored Material ID.
- Show original numeric values directly beneath the sliders; the exact previously saved fractional, signed, or >10 values remain unchanged until the user moves an individual slider. Slider movement changes only that Material ID and persists in the existing INI arrays.
- Increase per-ID row height to 50px for the tick marks/readouts and retain nine visible rows with local scrolling. Preserve the module layout, Material ID palette, Radius/Repeat geometry, panel grid and previously archived ID values.
- Update regression test checks for slider ranges, width, readouts and out-of-range persistence. Static checks only; native 3ds Max execution is still pending.


---


﻿# Tank Panel Generator — v0.038


- Remove Main Module auxiliary Around, Length, Radius div., and Length div. labels. Keep RADIUS and LENGTH headings. Place SUBDIVISION as the leading label of the last input row; keep Repeat and subdivision selectors alongside it, with uniform 58px dropdown widths matching the Radius/Length spinner fields. Position precision is fixed internally to `0.01` and has no visible control.
- Replace the single active-ID Extrude row with dynamically generated, color-coded rows for all distinct Material IDs assigned in the source panel grid. Each ID has independently editable Inset, Height and Taper numeric spinners. Rows update when IDs are added or disappear; more than nine rows scroll locally.
- Persist the complete per-ID extrusion arrays in the INI, plus the new `RuleCount` key. Disappearing IDs retain all saved values and recover them when reassigned, including IDs above the nine-color palette range.
- Preserve panel preview size and geometry, repeat/Radius semantics, material colors, and scene-owned modifiers. Static checks only; native 3ds Max runtime testing outstanding.


---


﻿# Tank Panel Generator — v0.037


- Enforce a minimum **50% of the Panels grid container's width** for the rendered panel buttons, avoiding unreadably thin columns in tall source patterns.
- Fit to the original physical aspect first; when it produces a narrower grid, widen only the **displayed X dimension**, preserving cell heights and centring. Leave actual geometry, Radius, Repeat Around, IDs and extrusion rules unchanged.
- Preserve the 288px dialog, the 252 × 264px grid host and no-scrollbar behavior. Update test Parts 19 and 28 to verify minimum rendered width, vertical sizing and clipping.
- Static structural checks; no live 3ds Max UI execution performed.


---


﻿# Tank Panel Generator — v0.036


- Apply **+64 px horizontal origin offset** to all 13 native MaxScript spinners in Main Module, Extrude, and Hatch, both at declaration time and on each layout resize.
- Preserve spinner widths and heights; keep labels, dropdowns (including Hatch Seams), buttons, dimensions, 288px dialog width and fixed 252 × 264px panel grid unchanged.
- Update regression assertions to account for the invisible spinner origin correction, including every Hatch spinner and the unchanged Seams ComboBox.
- Static checks only; the actual 3ds Max UI layout has not yet been visually verified.


---


﻿# Tank Panel Generator — v0.035


- Keep Radius as the **final cylindrical radius** independent of Repeat Around. Flat source sheet width is always `2*pi*radius`; repeating Around fits more tiles into that fixed width instead of enlarging it.
- Compute source panel width and painting-preview aspect using `(2*pi*radius)/(columns*repeat_around)`; maintain Bend at 360 degrees and preserve existing per-ID, repeat-length and extrusion behavior.
- Correct `SPG_ExpandedRadius` metadata and attached Cap Hatch generation to use Radius rather than Radius multiplied by Repeat Around.
- Make Repeat Around changes reflow the proportional panel preview immediately and continue updating the bound module.
- Extend regression tests to verify stable radius/plane circumference for 1, 2 and 4 Around repeats, source panel scaling, original identity and metadata checks, and preview proportions.
- No dialog width, grid dimensions, Material/Extrude controls or shared Codebase assets changed. Static validation only; native 3ds Max runtime still pending.


---


﻿# Tank Panel Generator — v0.034


- Arrange native Extrude spinners on one horizontal row in the order Inset | Height | Taper, with labels directly above each field.
- Use three equally spaced 84px slots within the existing 252px content width; retain each spinner's native 69px width and tooltip.
- Add separate uppercase RADIUS and LENGTH labels above the Main Module dimension spinners; shift main fields and group height down by 20px to avoid overlaps with existing Around/Length repeat captions.
- Reduce the Extrude group height to 104px, adjust the enclosing Panels section, and keep the full-width Extrude button immediately beneath the spinner row.
- Preserve the 288px dialog width, fixed 252 × 264px grid, Ctrl-selection, ID palette and geometry.
- Update the UI regression tests for Extrude row equality/order and Main Module dimension-label placement, visibility and alignment. Static checks only; native runtime testing pending.


---


﻿# Tank Panel Generator — v0.033


- Fix a runtime undefined-function error at v0.032 main script line 857: a repeated Material ID click calls saveUiState() before its rollout-local function definition.
- Add saveUiState to the existing forward declarations after auditing other call-before-definition sites.
- Extend Part 23 with a repeat palette click to exercise the no-change persistence branch.
- Preserve the 288px dialog, 252 × 264px panel grid and Extrude controls. Static checks passed, 3ds Max execution still outstanding.


---


﻿# Tank Panel Generator — v0.032


- Fix runtime error at `Tank-Panel-Generator.ms` line 608: `rebuildGrid()` was invoked in the earlier palette-click callback without a rollout-local forward declaration, resolving to `undefined`.
- Add `rebuildGrid` to the existing rollout-local forward-declarations list, without changing painting or geometry logic.
- Extend the UI integration test to assert availability of the rebuild callback; the existing palette click regression covers repainting after material assignment.
- Grid host remains 252 × 264px and the dialog remains 288px wide; Extrude labels and tooltips remain unchanged.
- Static checks passed; 3ds Max runtime still needs confirmation.


---


# Tank Panel Generator — v0.031


- Set only the **Panels grid layout host** to a fixed **264 px height** (grid_host_height = 264), replacing responsive 112–728 px sizing.
- Keep the grid width 252 px, the dialog width 288 px, all other control layouts and behaviors, aspect-correct panel rendering and no-scrollbar behavior unchanged.
- Put uppercase HEIGHT, INSET and TAPER labels visibly above the spinners (rather than overlapping native spinner fields). Keep the two-column Height/Inset row and Taper below, expand only the Extrude group and parent Panels group enough to fit, and provide field-specific native tooltips.
- Update UI regression assertions for exactly 264px grid and visible Extrude labels above their spinners.
- Static source/structure checks completed; 3ds Max runtime has not been executed.


---


# Tank Panel Generator — v0.030


- Ctrl-click toggles a cyan selection border on panel grid cells without changing their material IDs or enabled state. Selections survive grid redraws and support bulk editing.
- Clicking one of the nine full-width ID buttons paints all selected cells with that ID. Remove the ID dropdown completely; keep historical ID data and extrusion rules.
- Changing Height, Inset or Taper for a nonempty selection writes that single parameter to each distinct material ID represented in the selection; nonselected panels sharing those IDs use the same settings.
- Extrude fields retain their labels and now have descriptive native tooltips. Grid, palette and Extrude button hints explain Ctrl selection and mass operations.
- Dialog width and grid-height limits are unchanged (288 px dialog, 252 px grid, up to 728 px tall). No geometry algorithm or shared MaxScript codebase updates.
- Integration tests updated for nine-button palette and bulk selection semantics.
- **Validation:** static source and structural checks; 3ds Max runtime not executed.


---


# Tank Panel Generator — v0.029


- Maximize the usable horizontal width of docked/floating CUI sections, groupboxes, the grid, palette, Material and Hatch controls.
- Four root sections: **Main Module / Panels / Material / Hatch**. Remove nested **LAYOUT** and the one-control **Generated Object** rollout; Generate / Update remains directly within Main Module.
- Double the painting preview's maximum height from 364 to **728 px**, increasing useful grid area when dialog space permits; keep no inner scrollbars.
- Set the **fresh-session dimension unit to cm**; preserve unit choices explicitly saved by existing users.
- Active Material-ID dropdown exposes **1–32**; show exactly nine ID swatches (1–9) beside the dropdown on one row. Do not discard pre-existing higher-ID scene data.
- Simplify Extrude to three controls: **Height + Inset** in row one, **Taper** in row two. Remove Thickness, Depth and the New ID default-depth dropdown. New per-ID Height defaults to **one physical centimetre**, while saved Height values are retained.
- Fix **Inset** to create a real, flat grouped rim *before* Height/Taper extrusion using a documented zero-height `polyop.bevelFaces` call, not the context-sensitive `buttonOp #Inset`. Report failed native inset topology rather than claiming success.
- Preserve historical RuleThicknesses/RuleOffsets metadata for backwards compatibility but intentionally stop using those legacy values to change geometry.
- Retain Material Multi-ID / Grey INI persistence. Keep the generated Bend and independent Hatch Lathe/Chamfer ownership unchanged.
- Revise UI regression stages 4, 21–23 and 26; add **Part 27** for inspectable grouped inset geometry and ignored legacy extrusion values.
- Archive all original v0.026 sources in `Versions/v0.026/` and leave protected shared Codebase files unmodified.


**Validation:** Static checks only. The 3ds Max MCP bridge returned HTTP 429; run `Tank-Panel-Generator-Test.ms` in 3ds Max to verify the grouped inset on live geometry.


## v0.028 — visible grid enlargement


- Increase the default owning dialog from **288 × 1120px** to **576 × 1440px**, not merely the grid height ceiling, so the aspect-correct painted grid can display at approximately **200%** of its former linear size.
- In the expanded default layout, the grid host reaches **540px wide × 728px high**; keep the aspect correct, no internal scrolling and vertical resizing.
- Respect existing saved dialog heights. Very short monitor heights or a smaller restored window still limit the available grid.
- Add regression **Part 28** to validate the enlarged host and preserved source-panel aspect.
- Previous unpublished v0.027 and backed-up v0.026 remain preserved in Versions; no source-panel or cap geometry changes in v0.028.


**Validation:** Static validation only; live 3ds Max execution remains unverified.


## v0.029 — grid height only; dialog width restored


- Revert the dialog and CUI default width from 576px to its former **288px**.
- Retain the existing 1440px default dialog height and allow only the **Panels painting grid** to reach **728px** vertically (2× the old 364px limit). The grid remains 252px wide.
- Preserve the layout, Material and Extrude behavior from v0.028. No geometry-module or shared-code changes.
- Part 28 checks the 288px dialog / 252 × 728px grid layout and preserves the cell aspect ratio.
- Static checks completed; 3ds Max execution is still required.




## v0.049 — extrusion above Bend


Evaluation order is Editable Poly base → Bend → Edit Poly extrusion. In the Max stack UI, Edit Poly is at the top. Base topology contains only the subdivided sheet and material IDs. All enabled per-ID Inset, Height and Taper operations are committed in the owned Edit Poly after Bend. Inset uses a zero-height grouped bevel; signed Height uses grouped extrusion on the bent surface; signed Taper uses an equal-distance Outline of the elevated top (or zero-height bevel when Height is zero). Native top selection is read back between stages. No local-sheet-Z displacement remains.


Use the canonical shared `../CODEBASE/Functions/Epoly/EpolyCore.ms` and `EpolyFaces.ms` dependencies; synchronize those existing files alongside the project directory. Shared sources are unchanged. New records use SPG_DataSchema=2 and persistent TPG:Extrusion / TPG:Bend modifier roles. Read schema 1 and legacy single-Bend objects without modifying them; Generate rebuilds their stored settings into the new stack on the same node. Additional or reordered foreign modifiers block regeneration.


Validation: updated Parts 3, 6, 24, 27, 29, 32, 33 and 34 inspect the new stack, flat base, evaluated extrusion topology, grouped regions, signed post-Bend taper distances and object reload. Static source validation only. Native tests and visual geometry checks remain pending because the Max MCP endpoint returns 429.








## v0.062 — persistent TPG Extrusion and in-place parameter edits (2026-10-25)


- Height, Inset and Taper now update the **existing** generator-owned `TPG Extrusion` modifier using a refresh parameter; ordinary updates never delete/recreate that modifier, rebake the base geometry, or reassign Bend.
- New generation creates `Editable Poly → Bend → TPG Extrusion`, where `TPG Extrusion` is a `simpleMeshMod` scripted procedural modifier. It reads the saved rule tables and regenerates its output from the incoming bent TriMesh. Private map channel 99 identifies original logical cells and their enabled state; positive inset runs per cell, zero inset per Material ID.
- Existing 0.061 Edit Poly extrusions are migrated **once** on their first numeric update, preserving the bound node, base object and Bend. Subsequent numeric edits only increment the persistent extrusion refresh parameter. The legacy Edit Poly is removed only in that one-time migration.
- Updated the shared generator and tests to v0.062; regression Part 42 asserts that two updates retain the exact same extrusion modifier instance. Migrated old topology uses triangulated MeshOp extrusion, so visual equivalence and all regressions still require native 3ds Max 2026 testing. The scripted modifier must be registered by loading `Tank-Panel-Generator-FN.ms` when starting a new Max session to resolve scenes that contain it.
- The complete v0.061 source was archived under `Versions/v0.061` before editing. v0.059 remains the user-designated stable baseline; **v0.062 is a development candidate, not native-runtime verified**.




## v0.072 — Scoped preset loading and right-click menu (2026-10-25)


- Preset dropdown selection now immediately applies **Load All**; programmatic list refresh during Save/Rename/Delete remains guarded to avoid unintended loads.
- Native **Load** button remains left-click **Load All**. Right-click opens **Load All**, **Load Panels Layout**, **Load Extrude Settings**, and **Load Hatch Settings**.
- The preset manager restores only the selected INI key group. Panels includes module dimensions, grid/pattern and material assignment; Extrude includes complete per-ID rule arrays; Hatch includes cap controls. A full load restores all existing preset fields.
- Partial extrusion loading refreshes only the owned extrusion; hatch loading updates only an already-existing hatch; panels and full loads use the existing module refresh. Preset names and window/section geometry remain unchanged.
- Extended the independent preset regression with panels/extrude/hatch/all isolation checks. Native 3ds Max interaction and geometry checks remain pending.
- Archived the prior canonical v0.071 release under `Versions/v0.071/` before promotion.




## v0.075 — Fix undefined validator call during Seams/Chamfer generation (2026-10-25)


- Fixed MaxScript struct method binding: `syncChamferStack()` used to call `canReplaceBoundNode()` before its declaration, which bound the call to `undefined`. The method is now defined immediately after `getOwnedStackParts()`, before its first call.
- The user-visible error was rethrown in `generateModule` (previously FN.ms line 1576), not raised by that line itself.
- No changes to generated topology, Chamfer parameters, inset behavior, Material ID buttons, or preset structure.
- Added a failing-then-passing regression to `seams_chamfer_static.test.mjs`. Native 3ds Max 2026 Part 55 still requires a user runtime run; v0.073 remains the user-confirmed stable baseline.


## v0.076 — Render missing Extrude Material ID buttons (2026-10-25)


- Replaced twelve independently hidden rollout `.NET Button` controls with twelve explicit child buttons inside one `dn_extrude_id_host` WinForms Panel. The screenshot of v0.075 showed a completely empty ID column alongside correctly visible Height/Inset/Taper spinners.
- The ID host is positioned at the left edge of the native spinner rows, sized to the number of visible Material IDs, brought to the front, and hidden with the Panels section. Child buttons preserve individual Material ID colors, active-ID border, page mapping and ID click behavior.
- Removed the unused fixed rollout .NET button event handlers. Every hosted child now binds its Click handler once during first row initialization, matching the existing grid's runtime .NET child-event pattern.
- Regression checks cover the parent host, dynamic child creation, click binding, row layout, and removal of the hidden standalone .NET controls; all existing geometry and native spinner checks remain.
- Native 3ds Max visual/UI verification has not been performed. v0.073 is the last user-confirmed stable MVP.
