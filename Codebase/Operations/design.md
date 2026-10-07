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


### Preset Manager


**Purpose:**  
Provide one reusable named-preset persistence workflow without owning any Tool semantics or UI. A caller supplies an INI path, a namespace prefix, a preset name, and opaque string key/value pairs.


**Inputs:**  
`ini_path` is the caller-owned INI file. `preset_name` is a non-empty user-facing name that cannot contain INI-section delimiters. `section_prefix` isolates one caller's preset namespace and defaults to `Preset`. Preset payloads are arrays of `#(key_string, value_string)` pairs.


**Function dependencies:**  
Uses native MAXScript `getINISetting`, `setINISetting`, `hasINISetting`, and `delIniSetting` only. The Operation does not depend on rollout controls, dialogs, Toolsets, or Tool-specific data structures.


**Workflow:**  
1. Normalize and validate the preset name, namespace, and payload entries.  
2. Store presets in sections named `<section_prefix>|<preset_name>` with one private format marker.  
3. Saving replaces the complete section so keys removed by the caller cannot survive as stale preset data.  
4. When replacing an existing preset, retain its previous entries and restore them if the replacement write fails.  
5. Loading returns only caller-owned entries and hides the internal format marker.  
6. Listing returns alphabetically sorted valid preset names in only the requested namespace.  
7. Renaming copies the exact preset payload to a new validated name, refuses an existing destination name, removes the old preset only after the new preset is valid, and rolls back the new preset if old-section removal fails.  
8. Removing deletes only the requested preset section and verifies that it no longer exists.


**Output:**  
Save, rename, existence, and remove operations return Boolean success/failure. Listing returns an Array of preset-name strings. Loading returns an Array of string key/value pairs for an existing preset and `undefined` when the named preset is invalid or absent. Empty presets are supported because the private format marker creates a valid section even when no caller entries exist.


**Failure behavior:**  
Invalid paths, names, namespaces, or payload shapes fail before changing stored data. Failed section writes return `false`; when an existing preset was being replaced, the Operation attempts to restore the previous section and reports a rollback failure to the Listener if restoration also fails. Rename never overwrites another preset; if the new section was created but removal of the old section fails, rename removes the temporary new section and returns failure.


**Edge cases / constraints:**  
Preset payloads are deliberately opaque strings. Typed decoding, application of loaded values, confirmations, dropdown synchronization, and other user interaction belong to the calling Tool. The reserved internal format key cannot be supplied as caller data.


### Edit Poly Move Vertices

**Purpose:**  
Provide one stable reusable operation for moving existing vertices through an `Edit_Poly` modifier without editing the base `Editable_Poly` and without changing topology. The canonical movement sequence is `Select #Vertex -> MoveSelection -> Commit()`.

**Inputs:**  
`node_value` is the node that owns the exact `Edit_Poly` instance. `edit_poly_mod` is that exact modifier instance. `vertex_bits` is a non-empty BitArray of live modifier vertex IDs. `move_delta` is one Point3 delta in the modifier/node object space. For different per-vertex deltas, `move_records` is an Array of unique `#(vertex_id, point3_delta)` pairs.

**Function dependencies:**  
Uses the native `EditPolyMod` methods exposed by `Edit_Poly`: `GetNumVertices`, `GetVertex`, `GetSelection`, `Select`, `SetPrimaryNode`, `GetPrimaryNode`, `GetEPolySelLevel`, `SetEPolySelLevel`, `MoveSelection`, `Commit`, and optional `RefreshScreen`. It does not call `polyop` and does not touch the base object's topology.

**Workflow:**  
1. Verify the exact modifier belongs to the supplied node and validate every requested vertex ID before changing geometry.  
2. Snapshot the current Edit Poly vertex selection plus the modifier state that the operation changes.  
3. Set the supplied node as primary, force local modifier selection (`useStackSelection = false`, `selectMode = 0`), set the Edit Poly level to `#Vertex`, and keep cage display off.  
4. Clear the current modifier vertex selection and select exactly the requested vertex BitArray. Verify it with `GetSelection`.  
5. For a shared delta, call `MoveSelection` once for the complete selected BitArray, then `Commit()` once.  
6. For different deltas, isolate one prevalidated vertex at a time, call `MoveSelection` with that vertex's delta, and `Commit()` before moving the next vertex.  
7. Verify every moved vertex with `GetVertex` against its exact pre-move position plus the requested delta.  
8. Restore the original vertex selection and the saved modifier state. Refresh only once at the end when requested.

**Output:**  
The public move functions return Boolean `true` after a complete verified move. They return `false` only for invalid input detected before geometry is changed. Unexpected native, post-move verification, or state-restoration failures throw after cleanup so a partial or uncertain edit cannot be reported as normal success/failure.

**Failure behavior:**  
Invalid node/modifier ownership, empty or invalid selections, out-of-range IDs, duplicate IDs in per-vertex records, non-Point3 deltas, or an already-active uncommitted Edit Poly operation fail before moving anything. Native exceptions and verification failures preserve the original exception/failure signal after attempting state restoration. The operation never fabricates an empty selection or valid-looking result after a failed native read.

**Edge cases / constraints:**  
This Operation is specifically for an `Edit_Poly` modifier. It does not use `polyop.moveVert` on the base object. Vertex movement does not add/remove/merge/split topology, so the operation does not call `polyop.collapseDeadStructs`; component IDs remain stable through the move. For one common delta, always batch the full BitArray into one selection/move/commit. Use the per-vertex record path only when vertices genuinely require different deltas. The operation does not own an undo block; callers may wrap a logical multi-step use in one undo context.
