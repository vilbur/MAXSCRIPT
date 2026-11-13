# Tank Panel Generator — Project Agent Rules


This file applies only to the `Tank-Panel-Generator` project directory. It supplements, and never overrides, the shared MaxScript agent source.


## Mandatory source of truth


1. Start with the shared [MaxScript AGENTS.md](https://drive.google.com/file/d/1oN1nKq44nn0jG5g7SgokuxkzIppaRZAW/view) from [shared agent folder](https://drive.google.com/drive/folders/1RSsBtOAOPHmiT6SeVaYqhuvyqQZ36FFA), **before editing code**.
2. Read relevant shared rule files: `maxscript-ui-rules.md`, `maxscript-syntax-safety.md`, `maxscript-project-settings.md`, `maxscript-project-architecture.md`, `maxscript-protected-identifiers.md`, `maxscript-unit-precision.md`, and `maxscript-modifier-rules.md` when touching a modifier stack.
3. Read local [design.md](./design.md), and always inspect the current files in the [project's canonical Drive root](https://drive.google.com/drive/folders/1FZ_DLOKMxgUEXRdelJp27bZz3Fe7KEF2). Never base an update on an older chat attachment when a newer Drive file exists.
4. Shared `Maxscript/Codebase/{Functions,Operations,Tools,Toolsets}` content is **read-only by default**. This project's changes never authorise modifying those protected shared assets.


## Canonical project files


- `Tank-Panel-Generator.ms` — stable entry point, owning dockable UI, settings and UI event handlers.
- `Tank-Panel-Generator-FN.ms` — source-panel geometry, pre-Bend dimensions, ID extrusion and materials.
- `Tank-Panel-Generator-Cap-FN.ms` — separately owned Lathe/Chamfer cap hatch.
- `Tank-Panel-Generator-Test.ms` — integration and regression tests in 3ds Max.
- `design.md` — current feature/UI contracts and intentional limitations.
- `changes.md` — release notes.
- `Versions/v0.XXX/` — complete prior releases, preserving historical scripts.


## Change discipline


- Preserve the canonical filenames and keep active scripts in the repository root; archive the prior release before promoting a new one. Increment project/file versions by `0.001` for each change set.
- Modify only necessary project files. Keep geometry algorithms out of rollout event handlers; reuse the existing functional modules, and never change a user-created modifier based only on its name.
- For UI changes, preserve the title/restart button, INI-backed settings and floating position, dockable left/right bar registration, and safe CUI lifecycle. Never call `setDialogSize` on a registered dialog bar or mutate a rollout title after opening.
- Use MAXScript syntax (`function`, `if ... then`) and descriptive identifiers; `modifier` is reserved. Never use an empty catch for operation-critical failures. Document and test any .NET-to-MAXScript conversions.
- Dimension conversion must preserve scene-space geometry values; do not invent unit rounding or hidden tolerances. The `postion preccision` selection remains explicit and is only used where position-based comparisons require it.
- Test new controls, palette selection, click handling, material ID depth editing, panel grid hit-testing, resizing, persistence and repeated UI restarts. Static checks do **not** prove the script runs in 3ds Max; report runtime testing separately.


## Current requirements (v0.049)


- All native MaxScript spinners require a +64px offset on their declared and runtime X positions to compensate for their invisible native origin. Do not apply that offset to labels, dropdowns, buttons, or groupboxes; in the Hatch controls loop, exclude the seam-count ComboBox.
- The Main Module Radius and Length spinners require visible uppercase RADIUS and LENGTH labels aligned above the fields, separate from the Around/Length repeat labels. Both dimension labels follow Main Module collapse visibility. Use the full available width of the dockable CUI layout. The default dialog remains 288 px wide (locked CUI width) and 1440 px tall; keep the Panels grid host exactly 264 px high, not responsive to dialog height. Do not enlarge the dialog or grid width. Keep the .NET title/restart button and safe CUI registration.
- Four independent top-level collapsible sections in order: **Main Module**, **Panels**, **Material**, **Hatch**. Generate is directly inside Main Module, with no nested Generated Object rollout. Material remains visible when Panels is collapsed.
- **Panels** directly owns Around/Length panel counts, All/None painting controls and a preview that preserves source proportions unless the rendered grid width would be below 50% of the container; in that case expand only displayed X to the 50% minimum without changing cell height, host dimensions, geometry or material assignments. The old nested **LAYOUT** section and its INI collapse key are retired.
- Exactly **nine equal-width swatch buttons (IDs 1–9)** fill the palette row; there is **no ID dropdown**. Ctrl-click on grid cells toggles a cyan multi-selection outline without changing their IDs or enabled state. A swatch click mass-assigns its ID to selected cells; without a selection it sets the active paint ID. Preserve historical IDs and saved rules above nine without remapping.
- Main Module has no Around/Length repeat labels, no Radius div./Length div. labels, and no visible position precision selector. A single SUBDIVISION label leads the last input row with two 58px dropdowns. Main Module dropdowns and radius/length spinners have equal 58px width; internal generation uses fixed position precision 0.01.
- **Extrude** controls have explicit labels and descriptive tooltips. With grid cells selected, changing one Height, Inset, or Taper spinner applies that one setting to each distinct ID present in those cells; IDs retain global per-ID semantics (other panels sharing an ID receive the same extrusion setting). **Extrude** exposes only Inset, Height and Taper, all on one horizontal row in that left-to-right order, with visible labels above each spinner and a full-width Extrude button beneath. Remove redundant Thickness/Depth and the New ID height dropdown. Newly created IDs default to exactly `units.decodeValue "1cm"`, while saved per-ID heights remain intact. Never write to native spinner `.width` at runtime.
- Group adjacent same-ID logical panels for grouped extrusion and inset, never by individual polygon. Preserve signed Height, nonnegative Inset and signed Taper; historical Thickness and Depth values remain serialized but are no longer applied to geometry. Changes persist in INI and regenerate a previously bound module only.
- Radius defines the final module cylinder radius and must remain constant when Repeat Around changes. Repeat Around subdivides one fixed 2*pi*Radius circumference into repeated copies; rescale the source panel pattern and preview horizontally by 1/repeat and keep the cap at the Radius value. Repeat Length retains its existing module-length extension behavior.
- Preserve the fixed 264px preview height and 252px default grid host width, no inner scrollbars, the `postion preccision` shared setting under Main Module, MaterialMode persistence, and independent Cap Hatch Lathe/Chamfer modifier ownership.
- Inset, Height and Taper execute in the owned Edit Poly above Bend through canonical Epoly operations. See v0.049 below; historical pre-Bend sections are superseded.
- Fresh UI defaults to centimetres; existing saved explicit unit settings and saved dialog heights remain unchanged.
- Never modify shared Codebase sources unless a later user request explicitly authorises the protected file.


## Delivery


Publish the current source, updated tests and docs in the canonical root; keep historical versions in `Versions/`. Verify the live Drive folder after upload and explicitly state whether 3ds Max runtime tests actually ran.


## Per-ID extrusion editor v0.038


Replace the single visible Extrude Height/Inset/Taper control row with one compact editor row per distinct Material ID assigned in the current source grid, including disabled cells. Each row displays the ID and independently edits Inset, Height and Taper through a .NET numeric spinner. Rebuild rows on changes to the used-ID set, keep at most 9 visible rows plus local scrolling as needed, and maintain the INI-backed per-ID rule arrays. Never remove or reset extrusion values for IDs no longer visible or assigned; persist full `RuleCount` to avoid truncation of high-numbered IDs when the project reloads. Editing one row must not change any other ID or repaint selected cells. Preserve the rest of the UI, grid size and material semantics.


## v0.039 — per-ID slider controls


In the dynamic Extrude editor, show one row per Material ID currently in the panel layout. Replace the three .NET NumericUpDown editors with three TrackBars in order Inset, Height, Taper. Each has 0..10 inclusive stops, one-unit TickFrequency/SmallChange/LargeChange and width 30% of the current editor client width, accounting for a vertical scrollbar. The first ~10% of width remains the colored ID label. Provide an exact numeric readout beneath every slider. Preserve arbitrary previously saved fractional/signed/out-of-range per-ID extrusion values in the arrays/INI until the user explicitly moves that slider; do not silently clamp real geometry based on its displayed thumb position. Keep used-ID row refresh, INI RuleCount, fixed 252×264px painting grid, and existing geometry ownership unchanged.


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
