\# Operations Design

Use this file as the source of truth for feature design at the Operations layer.

Record the intended behavior of reusable Operations here before or while implementing them. Operations compose Functions into complete logical procedures, so this file should describe workflow and result contracts rather than UI.

\#\# What belongs here

For each Operation feature, record:

\- purpose;  
\- required Function dependencies;  
\- input contract;  
\- execution order;  
\- validation and branching rules;  
\- output or result contract;  
\- failure behavior;  
\- important edge cases or constraints.

\#\# Feature design template

\#\#\# \<Operation feature name\>

\*\*Purpose:\*\*    
\<What complete logical procedure this Operation provides.\>

\*\*Inputs:\*\*    
\<Required parameters and accepted values.\>

\*\*Function dependencies:\*\*    
\<Functions called by this Operation.\>

\*\*Workflow:\*\*    
\<Required sequence, branching, and validation.\>

\*\*Output:\*\*    
\<Return value or result contract.\>

\*\*Failure behavior:\*\*    
\<How failures are detected and reported.\>

\*\*Edge cases / constraints:\*\*    
\<Important limits or unsupported cases.\>

\#\# Feature designs

Add approved Operation designs below this heading.

### Vertex Color Painter

**Purpose:**  
Provide one reusable stateful EPoly color-paint operation for diagnostic Tools. One `VertexColorPainter_v` instance binds to one node and one topology level, caches component/map correspondence, and paints direct channel 0 or a PaintLayerMod without embedding any diagnostic classification rules.

**Inputs:**  
Target setup uses `setTarget target_node target_stack_index`. `target_stack_index == 0` means the Editable Poly base object. Positive indices currently require an `Edit_Poly` modifier and identify the polygon topology that all later component IDs belong to. Paint methods then receive only component IDs and colors: `paintCorner geo_vertex_id face_id color_value`, `paintVertex geo_vertex_id color_value`, `paintVertices vertex_ids color_value`, `paintEdge edge_id color_value`, `paintFace face_id color_value`, and bulk `paintCorners paint_data`.

**Function dependencies:**  
Uses native `polyop` map/topology methods for direct Editable Poly channel-0 work. Positive Edit Poly targets are evaluated on a temporary copied node stripped above the bound modifier and collapsed to Editable Poly; polygon topology is cached from that safe temporary result without requiring Modify-panel context. `snapshotAsMesh` stores the matching evaluated geometry snapshot, modifier-stack APIs manage exact PaintLayer placement/removal, and the native `PaintLayerMod` / `VertexPaintState` interface stores evaluated-stack colors.

**Workflow:**  
1. `setTarget()` validates the node and exact topology level, stores the node plus target modifier reference, and calls `refresh()`.  
2. `refresh()` rebuilds vertex/edge/face adjacency caches and one evaluated mesh snapshot. Base targets read the base Editable Poly directly. Positive Edit Poly targets build both polygon caches and the snapshot from one temporary evaluated Editable Poly copy at the exact bound stack level. Base targets also cache face-map and geo-to-map correspondence when channel 0 already exists.  
3. `beginPaint()` captures viewport display state. Base mode captures reversible channel-0 state and prepares channel 0 if needed. Modifier mode inserts the operation-owned PaintLayerMod immediately above the bound Edit Poly and acquires one VertexPaintState.  
4. Paint methods validate IDs against the same cached topology. `paintCorner()` is the exact primitive: base mode resolves `(geo_vertex_id, face_id)` to one map vertex; modifier mode uses `SetFaceVertColor`. Vertex, edge, face, and bulk methods are built on the same cached topology contract.  
5. `endPaint()` applies/releases the cached VertexPaintState once and redraws.  
6. `invalidate()` marks IDs/cache stale after an external topology edit; `refresh()` must rebuild before further paint.  
7. `clearPaint()` restores the original direct map colors/support or removes only the exact operation-owned PaintLayerMod and restores display state.

**Output:**  
Target/cache and paint methods return Boolean success/failure except explicit lookup/count properties. The instance exposes `source_node`, synchronized `stack_index`, `map_channel`, cached topology arrays, and `evaluated_mesh` for callers that intentionally reuse the same analysis state. The canonical shared instance is `VertexColorPainter`; additional independent sessions may be created with `VertexColorPainter_v()`.

**Failure behavior:**  
Invalid nodes, unsupported positive stack targets, stale/missing target modifiers, invalid component IDs, failure to evaluate/collapse the temporary target copy, failed snapshots, failed PaintState acquisition/application, or unsafe restore topology return failure and report a Listener message where useful. The Operation does not fabricate empty valid-looking topology after a failed read. Direct restore refuses stale geometry/map topology instead of applying old map IDs.

**Edge cases / constraints:**  
Positive stack targets currently require `Edit_Poly` so public vertex/edge/face IDs stay in one polygon-topology domain; arbitrary topology-changing non-EPoly modifiers are not exposed as Editable Poly face IDs. Direct `EditPolyMod.GetNum*` topology reads are not used for cache construction because they can return unusable counts outside the active Modify-panel context; the temporary evaluated Editable Poly copy is the authoritative polygon cache source. The cached `evaluated_mesh` is implementation/analysis data only and its triangle face IDs must never be substituted for cached polygon face IDs. Dead base Editable Poly topology may be compacted only when no modifier stack exists; the base object is never compacted underneath active modifiers. Existing unrelated PaintLayerMod / VertexPaint instances are never adopted or deleted.

