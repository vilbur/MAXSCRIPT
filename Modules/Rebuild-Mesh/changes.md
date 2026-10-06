# Rebuild Mesh changes

## 2026-10-05
- Rebuild-Mesh.ms 0.17: added one centralized Editable Poly dead-topology synchronization helper using `polyop.getHasDeadStructs` and conditional `polyop.collapseDeadStructs`; component IDs are read only after controlled phase-boundary synchronization.
- The evaluated source is synchronized before the first face-ID phase and again after the zero-area delete/collapse phase, before rebuilding vertex/face ID maps. Analyzer and selected-distance Editable Poly paths synchronize before reading counts, selections, or component IDs; Edit Poly modifier contexts never collapse the base object.
- Zero-area face detection now runs directly on the same newly added Edit Poly modifier that receives the DeleteFace selection. Raw Editable Poly face IDs are no longer transferred into Edit Poly selection.
- Output construction stores the actual vertex IDs returned by `polyop.createVert` instead of assuming canonical array indices equal Editable Poly vertex IDs. Cached output face/vertex IDs exist only inside one compound creation/map phase; maps are assigned before `polyop.deleteIsoVerts`, then dead topology is synchronized and all output ID caches are discarded. Legacy output creation follows the same post-delete synchronization rule.
- Editable Poly analysis selection is written to the same base `Editable_Poly` object that was analyzed. Removed the unsafe `polyop.getNumFaces` range test from triangulation repair; the current returned face ID is validated with `polyop.getFaceDeg` instead.
- CREATE TEST MESH now uses actual vertex IDs returned by `polyop.createVert`, then intentionally creates one dead isolated vertex and verifies controlled synchronization clears dead structures only after cached face IDs are finished and discarded.
- Saved matching versioned snapshot Rebuild-Mesh_0.17.ms.

## 2026-09-29
- Rebuild-Mesh.ms 0.16: prepared vertex merging now chooses a surviving source vertex by geometry priority instead of source-array order: geometric border corner > other geometric border vertex > H/V-edge vertex > fallback. H/V edges are evaluated in world space; horizontal means constant Z and vertical means world Z.
- Original boundaries are detected from face-edge usage after a temporary threshold grouping, so duplicated internal seams that become shared at the current threshold are not treated as outer borders. Boundary source positions are preserved as merge targets; no averaging and no Editable Poly weld operation is used.
- When several possible surviving vertices are within threshold, target priority wins before distance; equal-priority targets use nearest distance and then original vertex ID as deterministic tie-breakers.
- ANALYZE MESH now mirrors the same target priority and selects only vertices that will collapse. The surviving target vertices stay unselected so the destination is visible. Added a data-only regression where a lower-ID interior vertex is within 1 mm of a higher-ID outer border corner; the border corner must win.
- Saved matching versioned snapshot Rebuild-Mesh_0.16.ms.
- Rebuild-Mesh.ms 0.15: added ANALYZE MESH. It simulates the same pre-creation canonical vertex merge used by rebuild at the current Weld threshold and visibly selects every live Editable Poly / Edit Poly vertex participating in a merged group; it does not weld or modify topology.
- Added GET SELECTED VERT DISTANCE. With exactly two vertices selected, it measures their world-space distance in millimeters, prints the result, and copies the value into Weld threshold.
- Extended the existing 0.5 mm seam test instructions so both analysis controls can be verified before rebuilding.
- Saved matching versioned snapshot Rebuild-Mesh_0.15.ms.
- Rebuild-Mesh.ms 0.14: vertex distance merging is now a strict pre-creation data pass. All source vertices used by surviving polygons are mapped to prepared canonical vertex IDs before any rebuilt vertex or polygon is created.
- Added/retained `Weld threshold (mm)` with a 1.0 mm default. Distance checks are performed in world space; nearby source positions share one prepared output vertex.
- The rebuilt mesh creation path does not call any vertex weld operation. It only creates the prepared canonical vertices and connects them with polygon records; face cleanup and triangulation operate on the prepared data.
- Existing 0.5 mm regression seam now explicitly verifies that the pair maps to one prepared vertex before output creation.
- Saved matching versioned snapshot Rebuild-Mesh_0.14.ms.

## 2026-09-28
- Rebuild-Mesh.ms 0.09: after exact-position reweld, straight global degree-two boundary vertices are removed by rebuilding A-V-B as A-B without moving neighboring points. Any face that collapses to zero area is deleted.
- Non-zero-area n-gons that still contain collinear triangle candidates are retriangulated and given the healthiest available non-adjacent diagonal, following the shared Degenerate Face Selector strategy.
- UV/map rebuilding now tracks surviving source-corner IDs so removed straight geometry corners do not desynchronize map faces.
- RESTART now saves dialog state, searches the current script folder for a newer matching versioned script, and loads the newest version when present. Rebuild Maps state and dialog position persist in Rebuild-Mesh.ini.
- Saved matching versioned snapshot Rebuild-Mesh_0.09.ms.
- Rebuild-Mesh.ms 0.08: replaced triangulation/hidden-edge inference with face-safe rebuild. Evaluated polygons are read directly from a temporary collapsed Editable Poly copy, treated as isolated face islands, then merged only at bit-exact coincident positions (logical 0.0 weld).
- Face vertex order is preserved; connected neighbors are reoriented only when required for consistent shared-edge winding. Duplicate and degenerate polygons are skipped without moving valid face points.
- Source transform, pivot, layer and node behavior remain preserved; source stack stays untouched. Saved matching versioned snapshot Rebuild-Mesh_0.08.ms.
- Rebuild-Mesh.ms 0.07: rebuilt polygon winding now follows the source/neighbor face normal direction.
- Source face positions remain authoritative while duplicate vertices, duplicate faces, degenerate faces, and redundant straight edge vertices are cleaned during rebuild.
- Saved matching versioned snapshot Rebuild-Mesh_0.07.ms.

- Rebuild-Mesh.ms 0.10: the first topology-changing action on the disposable evaluated copy is now deletion of degenerate/sliver faces using the uploaded Degenerate Face Selector area / longest-edge quality test and Edit Poly DeleteFace workflow. Exact weld, duplicate cleanup, 2-edge straight-vertex removal and triangulation repair run only after that pass.
- Listener now reports source face count before the degenerate pass, faces deleted in the first pass, and face count after the pass. Existing latest-version RESTART and INI dialog-state persistence are preserved.
- Saved matching versioned snapshot Rebuild-Mesh_0.10.ms.

- Rebuild-Mesh.ms 0.11: fixed the array-clone bug behind `-- No "put" function for OK`. MAXScript `copy` was being applied to face-record arrays and returned `OK`; face records and fallback vertex loops are now rebuilt explicitly as arrays while node `copy` remains unchanged.
- Saved matching versioned snapshot Rebuild-Mesh_0.11.ms.

- Rebuild-Mesh.ms 0.12: valid polygons are no longer deleted just because one internal triangulation triangle is degenerate. The first deletion pass now removes only complete zero-area polygons.
- After the exact-position merge, a repeated canonical vertex is treated as a zero-area ear only when one of the two closed cycles has zero area and the opposite cycle has real area. Only that zero-area ear is removed; the valid polygon cycle survives and is flagged for retriangulation.
- Added a regression case matching the reported failure pattern: a valid 6-vertex polygon with one duplicate-position vertex and a zero-area internal ear must rebuild as a valid polygon instead of being deleted.
- Saved matching versioned snapshot Rebuild-Mesh_0.12.ms.
