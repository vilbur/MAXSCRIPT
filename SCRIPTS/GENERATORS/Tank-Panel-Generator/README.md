# Tank-Panel-Generator
**INIT STABLE v0.092 — user-approved 2026-10-29:** Fixed the reproduced 3ds Max 2026 startup crash. The logger now creates its file using `mode:"a"`; its first successful trace located the Hatch settings error (`copy` of an array returned `OK`). Hatch settings now use `copy scene_values #noMap`. The dialog completed startup and reopened successfully in Max 2026. v0.092 is the designated initialization-stable baseline. Run Part 4 of `Tank-Panel-Generator-Test.ms` for the legacy Hatch snapshot regression. Geometry tests remain separate; v0.083 retains its previous overall stable designation.

**Development v0.091:** Startup logging now captures MAXScript exceptions from rollout initialization and dialog creation, writes the full exception text to `Tank-Panel-Generator-Startup.log`, and echoes it to the Listener before rethrowing.

**Development v0.090:** Appends timestamped startup-stage markers to `Tank-Panel-Generator-Startup.log` beside the main script, including dependency loads, rollout open steps, dialog creation/registration, posted messages and grid setup. If Max exits during initialization, the last marker identifies the stage reached.

**Development v0.089:** Fixes the v0.088 native 3ds Max crash during tool initialization. Native MAXScript spinner bounds are restored to the proven ±1,000,000 range; shared SIZE unit conversion and all v0.088 Hatch features remain unchanged. The test suite now rejects unsafe 1.0e30 native spinner declarations before loading the entry script. Native 3ds Max confirmation is pending; v0.083 remains stable.

**Development v0.088:** One SIZE unit selector now controls every distance field. Hatch adds the requested seam width/stitch/depth, segment and material controls, excludes the radius corner from seam chamfering, and aligns owned Hatches at selectable module **Cap Enter / Cap Exit** ends. Exit-only is the default; both ends and all options persist. Reload `Tank-Panel-Generator.ms`, set `TPG_HatchOptionsRegressionOnly = true`, then run the test file for Part 63. Native 3ds Max testing is pending; v0.083 remains stable.


**Development v0.087:** Thickness end walls at the cylinder seam are removed before Bend and welding, keeping front/back skins and axial rims. **Existing thick modules need one Generate/Update** to rebuild their base. Test with `TPG_ThicknessSeamRegressionOnly = true`, then run `Tank-Panel-Generator-Test.ms`. Native 3ds Max validation is pending; v0.083 remains stable.


**Development v0.086:** Coincident vertices of the bent mesh are welded before Inset/extrusion, using the saved position precision (normally 0.01mm). The flat editable base and Bend are preserved. Set `TPG_BentWeldRegressionOnly = true`, then run `Tank-Panel-Generator-Test.ms` for Part 61. Native 3ds Max testing is pending; v0.083 remains stable.


**Development v0.084:** Main Module → SUBDIVISION → Length now offers Auto plus manual counts. Auto chooses Length subdivisions for approximately square quads in the flat base, recalculating from dimensions, grid counts, Repeat Around and Around subdivisions. Existing manual settings remain manual; fresh settings default to Auto. Set `TPG_LengthSubdivisionRegressionOnly = true`, then run `Tank-Panel-Generator-Test.ms` for Part 60. Native 3ds Max validation is pending; v0.083 remains stable.


**Stable v0.083 — user-approved 2026-10-27:** Nonzero Taper redistributes the bent ring subdivisions to keep parallel axial edges evenly spaced, including interior Length-subdivision rows. Taper endpoints and the lower mesh stay fixed. New isolated test: set `TPG_TaperSpacingRegressionOnly = true`, then run `Tank-Panel-Generator-Test.ms`. Native 3ds Max validation has not been independently executed. v0.083 is the current stable baseline by user designation.


**Development v0.082:** Taper offsets the new upper perimeter into signed, equal-distance loops parallel to the source-panel border; Inset and Height retain their prior semantics. Part 58 provides isolated Taper-loop tests. Native 3ds Max validation pending.

**Development v0.081:** Removed the separate Extrude action. Height/Inset/Taper changes already refresh TPG Extrusion automatically. The .NET Generate Hatch button now creates a standalone editable SplineShape profile with a native Lathe even before any module exists; with an existing bound module, it uses the linked cap generator.


**Development v0.080:** Added Base Thickness to the flat Editable Poly source (native Shell baked before Bend). Default 0 keeps v0.079 output. Previous stable release: **v0.079**, user-approved; native v0.080 regression pending.


**Previous stable release: v0.079** — user-confirmed 2026-10-27; standalone project folder.
Run `Tank-Panel-Generator.ms` in 3ds Max. Keep `Tank-Panel-Generator-FN.ms`, `Tank-Panel-Generator-Cap-FN.ms`, and the full `Lib` subfolder beside the main script.
The five project-owned `Lib` helpers replace the old shared UI root and old dependency resolver. No selection of `CODEBASE` or `UI` is required. You can move the entire TPG folder without changing script paths.
To validate, run `Tank-Panel-Generator-Test.ms` in 3ds Max. Part 36 verifies bundled UI helpers. The separate Chamfer/Seams regression uses `TPG_SeamsRegressionOnly = true` before loading the test.


Release designation is user-approved. This does not imply an independently executed 3ds Max regression run.





