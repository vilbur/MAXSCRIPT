# House Mesh Cleanup — Workflow & Pipeline



## Main Pipeline



<a id="pipeline-model-setup"></a>
### MODEL SETUP



- <a href="#tool-setup-new-model"><span style="color:rgb(65,128,255)">SETUP NEW MODEL</span></a>
- <a href="#tool-create-parent-layer"><span style="color:rgb(65,128,255)">CREATE PARENT LAYER</span></a>
- <a href="#tool-create-model-node"><span style="color:rgb(65,128,255)">CREATE MODEL NODE</span></a>
- <a href="#tool-sync-model-identity"><span style="color:rgb(65,128,255)">SYNC LAYER / MODEL NODE / PRESET NAME</span></a>



<br>



<a id="pipeline-pre-process"></a>
### PRE-PROCESS



- <a href="#tool-check-fix-ortho"><span style="color:#ff9800"><strong>CHECK / FIX ORTHO</strong></span></a>
- <a href="#tool-check-horizontal-vertical-edges"><span style="color:#ff9800"><strong>CHECK HORIZONTAL / VERTICAL EDGES</strong></span></a>
- <a href="#tool-explode-walls"><span style="color:rgb(65,128,255)">EXPLODE WALLS</span></a>



<br>



<a id="pipeline-slicing-topology-cleanup"></a>
### SLICING / TOPOLOGY CLEANUP



- <a href="#tool-slice-horizontal-vertical"><span style="color:rgb(65,128,255)">SLICE HORIZONTAL / VERTICAL</span></a>
- <a href="#tool-slice-cleanup"><span style="color:#ff9800"><strong>SLICE CLEANUP</strong></span></a>
    - <a href="#tool-two-edge-verts-fix"><span style="color:#a89f94"><strong>2-EDGE VERTS FIX</strong></span></a>
    - <a href="#tool-degenerate-faces-fix"><span style="color:#a89f94"><strong>DEGENERATE FACES FIX</strong></span></a>
    - <a href="#tool-select-weld-border"><span style="color:#a89f94"><strong>SELECT + WELD BORDER</strong></span></a> — EACH WELD VERTEX PAIR MUST COME FROM DIFFERENT WALLS



<br>



<a id="pipeline-extrude-prepare"></a>
### EXTRUDE PREPARE



- <a href="#tool-attach-walls"><span style="color:rgb(65,128,255)">ATTACH WALLS TO ONE OBJECT</span></a>
- <a href="#tool-floors-material-id"><span style="color:rgb(65,128,255)">FLOORS — ASSIGN MATERIAL ID PER FLOOR</span></a>
- <a href="#tool-detach-by-floor"><span style="color:rgb(65,128,255)">DETACH BY FLOOR</span></a>
- <a href="#tool-corner-cleanup"><span style="color:#ff9800"><strong>CORNER CLEANUP / MATCH WALL TOPOLOGY PER FLOOR</strong></span></a>
- <a href="#tool-rebuild-mesh"><span style="color:rgb(65,128,255)">REBUILD MESH</span></a>
- <a href="#tool-extrude-source-check"><span style="color:#ff9800"><strong>EXTRUDE SOURCE CHECK</strong></span></a>
- <a href="#tool-assign-extrude-material-groups"><span style="color:rgb(65,128,255)">ASSIGN EXTRUDE MATERIAL GROUPS</span></a>
- <a href="#tool-explode-by-material"><span style="color:rgb(65,128,255)">EXPLODE BY MATERIAL</span></a>



<br>



<a id="pipeline-extrude-walls"></a>
### EXTRUDE WALLS



- <a href="#tool-walls-extrude"><span style="color:rgb(65,128,255)">WALLS EXTRUDE</span></a>
- <a href="#tool-wall-geometry-check"><span style="color:#ff9800"><strong>WALL GEOMETRY CHECK</strong></span></a>
- <a href="#tool-finish-walls-fix-corners"><span style="color:#ff9800"><strong>FINISH WALLS — FIX CORNERS</strong></span></a>



<br>



<a id="pipeline-post-process-ready"></a>
### POST-PROCESS CHECK / READY


- <a href="#tool-ready"><span style="color:#4caf50"><strong>READY</strong></span></a> — CHECKING READY RUNS STL CHECK AUTOMATICALLY; READY IS SET ONLY WHEN STL CHECK PASSES WITHOUT ERRORS


<br>


<br>
<br>





## Pipeline / Tool Map



### <a href="#pipeline-model-setup"><span style="color:rgb(65,128,255)">MODEL SETUP</span></a>



- <a id="tool-setup-new-model"></a>**SETUP NEW MODEL** → `Scene-Model-Manager.ms`
- <a id="tool-create-parent-layer"></a>**CREATE PARENT LAYER** → `Scene-Model-Manager.ms` + automatic same-name layer detection
- <a id="tool-create-model-node"></a>**CREATE MODEL NODE** → `Scene-Model-Manager.ms` + automatic `Text` node detection
- <a id="tool-sync-model-identity"></a>**SYNC LAYER / MODEL NODE / PRESET NAME** → automatic checklist identity validation



<br>



### <a href="#pipeline-pre-process"><span style="color:rgb(65,128,255)">PRE-PROCESS</span></a>



- <a id="tool-check-fix-ortho"></a><span style="color:#ff9800"><strong>CHECK / FIX ORTHO</strong></span> → `Vertex Level Aligner`
- <a id="tool-check-horizontal-vertical-edges"></a><span style="color:#ff9800"><strong>CHECK HORIZONTAL / VERTICAL EDGES</strong></span> → `TBD`
- <a id="tool-explode-walls"></a>**EXPLODE WALLS** → `TBD`



<br>



### <a href="#pipeline-slicing-topology-cleanup"><span style="color:rgb(65,128,255)">SLICING / TOPOLOGY CLEANUP</span></a>



- <a id="tool-slice-horizontal-vertical"></a>**SLICE HORIZONTAL / VERTICAL** → `Slice modifier`
- <a id="tool-slice-cleanup"></a><span style="color:#ff9800"><strong>SLICE CLEANUP</strong></span> → `SLICE CLEANUP`
    - <a id="tool-two-edge-verts-fix"></a><span style="color:#a89f94"><strong>2-EDGE VERTS FIX</strong></span> → `TBD`
    - <a id="tool-degenerate-faces-fix"></a><span style="color:#a89f94"><strong>DEGENERATE FACES FIX</strong></span> → `TBD`
    - <a id="tool-select-weld-border"></a><span style="color:#a89f94"><strong>SELECT + WELD BORDER</strong></span> → `CROSS-WALL BORDER WELD`



<br>



### <a href="#pipeline-extrude-prepare"><span style="color:rgb(65,128,255)">EXTRUDE PREPARE</span></a>



- <a id="tool-attach-walls"></a>**ATTACH WALLS TO ONE OBJECT** → `Attach Walls`
- <a id="tool-floors-material-id"></a>**FLOORS — ASSIGN MATERIAL ID PER FLOOR** → `Volume Select + Material ID`
- <a id="tool-detach-by-floor"></a>**DETACH BY FLOOR** → `TBD`
- <a id="tool-corner-cleanup"></a><span style="color:#ff9800"><strong>CORNER CLEANUP / MATCH WALL TOPOLOGY PER FLOOR</strong></span> → `CORNER CLEANUP`
- <a id="tool-rebuild-mesh"></a>**REBUILD MESH** → `Rebuild Mesh`
- <a id="tool-extrude-source-check"></a><span style="color:#ff9800"><strong>EXTRUDE SOURCE CHECK</strong></span> → `TBD`
- <a id="tool-assign-extrude-material-groups"></a>**ASSIGN EXTRUDE MATERIAL GROUPS** → `Material ID assignment`
- <a id="tool-explode-by-material"></a>**EXPLODE BY MATERIAL** → `Explode by Material`



<br>



### <a href="#pipeline-extrude-walls"><span style="color:rgb(65,128,255)">EXTRUDE WALLS</span></a>



- <a id="tool-walls-extrude"></a>**WALLS EXTRUDE** → `Walls Extrude`
- <a id="tool-wall-geometry-check"></a><span style="color:#ff9800"><strong>WALL GEOMETRY CHECK</strong></span> → `Wall Geometry Check`
- <a id="tool-finish-walls-fix-corners"></a><span style="color:#ff9800"><strong>FINISH WALLS — FIX CORNERS</strong></span> → `TBD`



<br>



### <a href="#pipeline-post-process-ready"><span style="color:rgb(65,128,255)">POST-PROCESS CHECK / READY</span></a>


- <a id="tool-ready"></a><span style="color:#4caf50"><strong>READY</strong></span> → `STL Check`



---




# Detailed Workflow Steps




# 1. Model Setup




Create and identify the building block before any geometry cleanup begins.

This MODEL SETUP stage is configured in `Scene-Model-Manager.ms`. Layer, model-node, and pipeline-preset identity together represent the model assignment, so no separate assignment checklist step is needed.




## Setup New Model




Assign the selected building a clear block identity, for example `Block A`, `Block B`, or `Block C`.




The block identity is the common name used by the workflow and by the checklist state.




## Create Parent Layer




Create a dedicated parent layer for the block and place the selected model objects into it.




The layer is the scene-level container for the block throughout the workflow.

`CREATE PARENT LAYER` is checked automatically when a layer whose name exactly matches the active model / pipeline preset name exists in the scene.




## Create Model Node




Create the model node / workflow identity associated with the block.




The node represents the block that the Wall Cleaner workflow is operating on and gives later rollout tools one explicit model target.

`CREATE MODEL NODE` is checked automatically when a scene node satisfies both conditions:

- `classOf node == Text`
- `node.text == model name`




## Keep Identities Synchronized




Keep these identities synchronized when the block is renamed:


- parent layer name
- model-node identity
- workflow / preset name




The setup must make it unambiguous which model the checklist and later automated actions belong to.

`SYNC LAYER / MODEL NODE / PRESET NAME` is checked automatically only when all three matching identities exist for the same model name:

- a layer with the model name
- a `Text` model node whose `.text` equals the model name
- the pipeline preset with that model name




---




# 2. Ortho Preparation




## <span style="color:#ff9800">CHECK / FIX ORTHO</span>




Before topology work, inspect the building geometry and correct geometry that should be orthogonal.




Check whether walls, openings, cornices, corners and other architectural elements that should be orthogonal are actually orthogonal.




Preserve intentional non-orthogonal geometry such as terrain, slopes or explicitly angled architecture.




Use **Vertex Level Aligner** where appropriate.




Topology tools should not be used to compensate for geometry that is already incorrectly aligned.




## <span style="color:#ff9800">CHECK HORIZONTAL / VERTICAL EDGES</span>




This is a visual diagnostic step for finding edges that should be horizontal or vertical but are not.




The intended workflow is:




1. Select edges that are strictly horizontal.
2. Add edges that are strictly vertical.
3. Inspect that the expected horizontal / vertical geometry is included.
4. Invert the edge selection.
5. The remaining selected edges are the suspicious / non-orthogonal edges to inspect.




The important result is the inverted selection: only edges that do not belong to the expected horizontal / vertical set remain selected.




This step is diagnostic only. It must not automatically modify geometry.




Intentional angled edges must be ignored or excluded when appropriate.




---




# 3. Explode Walls




Explode the building into individual walls.




Each wall should behave as a separate planar wall element with one main wall normal.




This makes slicing and cleanup more predictable.




---




# 4. Slice Walls




All wall cutting is performed with the **Slice modifier**.




The preferred order depends on wall proportions:




- Wide wall → Vertical first, then Horizontal.
- Tall wall → Horizontal first, then Vertical.




Slices should follow meaningful architectural edges such as windows, doors, cornices, floor transitions and structural boundaries.




Every Slice is immediately followed by the complete **SLICE CLEANUP** routine.




---




# 5. <span style="color:#ff9800">SLICE CLEANUP</span>




`SLICE CLEANUP` is one closed subprocess and should eventually be callable as one MaxScript routine.




## Routine




- SLICE HORIZONTAL / VERTICAL
- <span style="color:#ff9800"><strong>SLICE CLEANUP</strong></span>
    - <span style="color:#a89f94"><strong>2-EDGE VERTS FIX</strong></span>
    - <span style="color:#a89f94"><strong>DEGENERATE FACES FIX</strong></span>
    - <span style="color:#a89f94"><strong>SELECT + WELD BORDER</strong></span>




**Weld safety rule:** each welded vertex pair must contain vertices originating from **different walls**.




The cleanup must never weld two vertices that belong to the same wall merely because they fall inside the weld threshold.




Default weld threshold: `0.001`.




## Rule




Whenever any new Slice is created anywhere in the workflow, run the full `SLICE CLEANUP` routine immediately afterward.




This includes slices created while matching wall corners.




## Two-Edge Vertices




Slice operations can create redundant vertices sitting on otherwise straight edges.




Remove vertices that:




- do not hold necessary topology
- do not represent an opening or architectural transition
- do not change the intended shape
- are only artifacts of slicing




## Degenerate Face Cleanup




Slice operations can create:




- degenerated faces
- extremely thin faces
- near-zero-width faces
- duplicated or nearly overlapping cuts




Clean these as early as possible after slicing.




## Select + Weld Border




Never inherit an unknown vertex selection from an earlier operation or modifier.




Before every weld:




1. Clear the previous vertex selection.
2. Build a fresh selection from border vertices.
3. Find candidate vertex pairs inside the weld threshold.
4. Accept a pair only when its two vertices originate from different walls.
5. Weld only those accepted cross-wall border pairs.




This prevents the cleanup from collapsing or modifying topology inside a single wall.




## Weld Threshold




Default minimum threshold:




`0.001`




The value should be set directly by MaxScript.




UI spinner display precision must not be treated as the source of truth for the internally stored weld threshold.




## Original Border Rule




Cleanup may simplify internal topology, but it must not unintentionally alter the intended original wall outline.




---




# 6. Attach Walls To One Object




After initial wall slicing and cleanup, attach the walls back into one object.




The walls may still remain separate elements inside the same object.




Keeping one building object makes floor assignment easier before detaching the floors again.




---




# 7. Floors — Assign Material ID Per Floor




Assign a dedicated **Material ID to each floor**.




Volume Select may be used to create the selection, but the important persistent result is the Material ID assignment.




The purpose is to make the floor boundaries explicit before corner topology is resolved.




Different floors often contain different window and door layouts. Their horizontal topology should not unnecessarily propagate into one another.




---




# 8. Detach By Floor




Detach the building according to the floor Material IDs.




Each floor becomes an independent topology-repair unit.




Now corner cleanup can be performed floor by floor without forcing lower-floor segmentation into upper floors or vice versa.




---




# 9. <span style="color:#ff9800">CORNER CLEANUP / MATCH WALL TOPOLOGY PER FLOOR</span>




This is a complete cleanup section for joining neighboring walls that have different topology.




Typical case:




- Wall A has no opening and therefore almost no horizontal segmentation.
- Wall B contains windows and doors and therefore has several horizontal edges.




The goal is not to blindly copy all topology from one wall to the other. The goal is to create compatible corner edge chains that can be welded cleanly.




## Corner Cleanup Subprocess




<span style="color:#ff9800"><strong>COMPARE CORNER EDGE CHAINS</strong></span>  
↓  
<span style="color:#ff9800"><strong>FIND MISSING / REDUNDANT CORNER VERTICES</strong></span>  
↓  
SLICE SPARSE WALL WHERE NEEDED  
↓  
<span style="color:#ff9800"><strong>SLICE CLEANUP</strong></span>  
↓  
<span style="color:#ff9800"><strong>REMOVE REDUNDANT CORNER EDGES / TWO-EDGE VERTICES</strong></span>  
↓  
MATCH CORNER CHAINS  
↓  
PREPARE BORDER WELD SELECTION  
↓  
WELD CORNER BORDERS  
↓  
<span style="color:#ff9800"><strong>VERTICAL CORNER T-JUNCTION CHECK</strong></span>  
↓  
REPEAT WHERE NEEDED




## Decision Rule




For every unmatched corner level:




### Needed topology




If an incoming horizontal edge represents necessary topology:




- Slice the neighboring sparse wall.
- Run the complete `SLICE CLEANUP` routine immediately.
- Create the matching corner vertex.
- Match the corner chain.
- Weld the borders.




### Redundant topology




If the incoming edge is only local or unnecessary at the shared corner:




- Remove the redundant edge or two-edge vertex where safe.
- Preserve the wall shape.
- Match the remaining corner chain.
- Weld the borders.




## <span style="color:#ff9800">Vertical Corner T-Junction Check</span>




Look for:




- open border segments inside a vertical corner
- unmatched intermediate vertices
- broken vertical edge chains
- border fragments that should already be welded
- hidden T-junctions caused by different segmentation between neighboring walls




Goal:




> Neighboring wall borders form a compatible, continuous and welded corner chain without unnecessary topology.




---




# 10. Rebuild Mesh




Run **Rebuild Mesh** after corner cleanup and before the extrude source check.




If the routine behaves correctly, it may clean remaining topology problems such as residual T-junctions, invalid local topology and redundant fragments.




It must preserve the intended building outline.




---




# 11. <span style="color:#ff9800">Extrude Source Check</span>




Before extrusion, verify that every floor shell is clean.




Check for:




- T-junctions
- open borders where none should exist
- degenerate faces
- redundant thin faces
- unnecessary two-edge vertices
- broken vertical corners
- unexpected topology
- accidental geometry changes




This confirms that the source walls are clean before converting the shell into thick walls.




---




# 12. Assign Extrude Material Groups




Separate geometry into logical extrusion groups using Material IDs or another explicit grouping method.




Examples:




- individual floors
- balcony parapets
- wall bands
- architectural wall sections
- other independently extrudable parts




Each group should represent one logical extrusion unit.




---




# 13. Explode By Material




Detach the extrusion groups according to their assigned materials.




Each resulting part should be cleanly and independently extrudable.




---




# 14. Walls Extrude




Apply the Walls Extrude workflow.




At this point the input shell should already be clean, welded, floor-isolated, free of corner T-junctions and logically grouped.




---




# 15. <span style="color:#ff9800">Wall Geometry Check</span>




After extrusion, automatically search for suspicious geometry.




The wall geometry check should evaluate face normals and select suspicious faces.




Look for:




- normals deviating unexpectedly from the expected wall direction
- sloped faces where orthogonal faces are expected
- tiny distorted faces around broken corners
- malformed extrusion regions
- locally inconsistent geometry




Preferred output:




- face selection
- optional vertex selection
- optional diagnostic Material IDs




The goal is to avoid manually checking hundreds or thousands of wall corners.




---




# 16. Fix / Finish




If the wall geometry check passes:




- run final wall fixes
- perform finishing cleanup
- repair remaining local errors
- rerun diagnostics where needed




After this step the geometry is ready for the next production stage.




---




# 17. <span style="color:#4caf50">READY — Automatic STL Check</span>


`READY` is the final post-process validation item.


When READY is checked, run **STL Check automatically** on the final model geometry.


READY may be marked complete only when STL Check finishes successfully and reports no errors.


Run STL Check in its full validation mode so the final validation includes:


- open edges or borders
- double faces
- spike geometry
- multiple-edge errors


The open-edge part of STL Check is also the closed-mesh validation: any unintended open border prevents READY.


If STL Check finds any error, READY remains unchecked.


If the check cannot run, READY remains unchecked and the failure must be reported rather than treated as a pass.


---


# Fixed Workflow Rules




## <span style="color:#ff9800">Rule 0 — Model Setup First</span>




Create and identify the block, parent layer and model node before PRE-PROCESS begins.


Keep the layer name, model-node identity and workflow / preset name synchronized.




## <span style="color:#ff9800">Rule 1 — Ortho + Edge Check First</span>




Do not start topology cleanup until geometry that should be orthogonal has been checked, corrected, and the horizontal / vertical edge diagnostic has been reviewed.




## <span style="color:#ff9800">Rule 2 — Every Slice Runs SLICE CLEANUP</span>




Every Slice is immediately followed by the full `SLICE CLEANUP` subprocess.




## <span style="color:#ff9800">Rule 3 — Border Weld Is Explicit And Cross-Wall Only</span>




Never silently reuse an unknown vertex selection from an earlier workflow step.




For `SLICE CLEANUP`, weld only border vertex pairs where the two vertices originate from different walls.




## Rule 4 — Weld Threshold




Default minimum weld threshold:




`0.001`




## <span style="color:#ff9800">Rule 5 — Preserve Original Outline</span>




Cleanup operations must not unintentionally change the intended building outline.




## <span style="color:#ff9800">Rule 6 — Resolve Corners Per Floor</span>




Attach the building first, assign Material ID per floor, detach by floor, then resolve wall-corner topology independently inside each floor.




## <span style="color:#ff9800">Rule 7 — Diagnose Before Finish</span>




Walls Extrude is always followed by the wall geometry check before final Fix / Finish.




## <span style="color:#ff9800">Rule 8 — READY Runs Final STL Validation</span>


READY is not a manual pass-through state.


Checking READY automatically runs STL Check on the final model geometry.


READY is stored only when STL Check completes successfully and finds no errors, including no open-edge errors.


The pipeline reaches READY only after this automatic validation passes.

---




# Automation Direction




The MaxScript implementation should evolve from a passive checklist into a workflow controller.




Each step can eventually expose:




- status
- manual confirmation where needed
- optional automatic action
- validation result
- warning state
- ability to rerun the current step without silently affecting unrelated steps




The most important reusable subprocesses are:




1. `SLICE CLEANUP`
2. `CORNER CLEANUP / MATCH WALL TOPOLOGY PER FLOOR`
3. `EXTRUDE SOURCE CHECK`
4. `WALL GEOMETRY CHECK`
5. `READY / AUTOMATIC STL CHECK`




The controller should avoid automatic loops where one tool repeatedly recreates a problem fixed by another tool.