\# Tools Design


Use this file as the source of truth for feature design at the Tools layer.


Record the intended design of user-facing Tools here. A Tool exposes Operations through a focused UI and keeps frontend and backend responsibilities separated.


\#\# What belongs here


For each Tool feature, record:


\- purpose and user-facing behavior;  
\- Operations it uses;  
\- Tool backend responsibilities;  
\- Tool frontend / UI responsibilities;  
\- controls and interactions;  
\- state or settings owned by the Tool;  
\- expected result and error presentation;  
\- important edge cases or constraints.


\#\# Feature design template


\#\#\# \<Tool name\>


\*\*Purpose:\*\*    
\<What the Tool lets the user do.\>


\*\*Operations used:\*\*    
\<Operations called by the Tool backend.\>


\*\*Backend design:\*\*    
\<Responsibilities of \`\<ToolName\>-FN.ms\`.\>


\*\*UI design:\*\*    
\<Responsibilities of \`\<ToolName\>-UI.ms\`, including controls and interactions.\>


\*\*Main entry behavior:\*\*    
\<What \`\<ToolName\>.ms\` loads and executes.\>


\*\*State / settings:\*\*    
\<Persistent or temporary Tool-specific state.\>


\*\*Edge cases / constraints:\*\*    
\<Important limits, validation, or interaction rules.\>


\#\# Feature designs


Add approved Tool designs below this heading.  


\#\#\# Rotate Selection To Ortho


\*\*Purpose:\*\*    
Rotate the current object selection back to the nearest world X or Y direction from a user-picked pivot and XY direction vector.


\*\*Operations used:\*\*    
No shared Operation dependency is required in version 0.01. The Tool backend owns this Tool-specific hierarchy, helper, layer, orthogonal-angle, and animation coordination.


\*\*Backend design:\*\*    
`Rotate-Selection-To-Ortho-FN.ms` resolves the nearest orthogonal correction around world Z, creates the Point helper, adds it to `_HELPERS>Rotation`, links selected hierarchy roots while preserving world transforms, and keys original/corrected helper orientation on frames 1/0.


\*\*UI design:\*\*    
`Rotate-Selection-To-Ortho-UI.ms` provides one primary action. LMB first picks the rotation pivot, then a second world-space point defining the XY direction. It reports validation errors and selects the created helper after success.


\*\*Main entry behavior:\*\*    
`Rotate-Selection-To-Ortho.ms` loads the backend and frontend from the same Tool directory and opens the standalone dialog.


\*\*State / settings:\*\*    
The standalone dialog position is stored in an INI file under the 3ds Max user scripts directory. The selected geometry remains bound below the created Point helper.


\*\*Edge cases / constraints:\*\*    
The picked direction is projected to world XY. Therefore the orthogonal correction rotates the helper around world Z. A zero-length XY vector is rejected. When both an ancestor and descendant are selected, only the selected hierarchy root is reparented so the internal hierarchy is preserved.


### Redundant Loop Fixer


**Purpose:**  
Select redundant internal divider edge loops while excluding every loop launched from a border corner or border branch before generic loop partitioning.


**Operations used:**  
The Tool builds internal non-crease, non-zero-length candidate edges, classifies all border-corner / border-branch vertices first, independently traces every candidate branch leaving those corner vertices, subtracts the resulting border-corner loop edges from the candidate set, builds the remaining closest-to-straight loop records, filters them by the user `ANGLE`, stores the surviving edge set in `SELECT REDUNDANT LOOPS`, and can remove that stored set through the existing RMB workflow.


**Backend design:**  
A candidate edge must be internal, non-crease, non-zero-length, and have exactly two adjacent faces. Face coplanarity is not a selection criterion. Border handling is a pre-pass: find all border corners/branches, then for each corner trace every incident candidate edge outward independently. This prevents horizontal and vertical loops leaving one corner from being merged by generic seed order. Border-corner tracing follows closest-to-straight continuation with a fixed maximum turn of 45°, so a 90° turn never joins perpendicular loops. The union of border-corner loop edges is removed before normal loop records are built. Terminal-valence, transverse-edge, T-junction, welded-branch, and other branch-shape heuristics do not gate production selection.


**UI design:**  
`ANGLE` controls the maximum accepted turn of the remaining production loops. `GET ANGLE` measures the deviation from straight of exactly two selected edges and writes it to `ANGLE`. `SELECT \ REMOVE` uses the spinner value for LMB production selection and the existing stored-selection RMB removal. `SELECT FORCE` uses the same production path with a fixed 45° final threshold. Debug button 1 selects the generic candidate-loop partition, debug button 2 independently finds all border corners first and selects every loop traced outward from them, and debug button 3 removes current debug loops whose turn exceeds `ANGLE`.


**Main entry behavior:**  
The existing standalone/host registration behavior is preserved.


**State / settings:**  
`ANGLE` and standalone dialog position remain persisted in the existing INI file.


**Edge cases / constraints:**  
Border and crease edges are not candidate edges themselves. Multiple candidate loops may leave the same border corner; each outgoing candidate edge starts its own border-corner trace. Border-corner traces stop rather than taking a 90° continuation. Straight-through border vertices are not corner seeds.


### Preset Manager


**Purpose:**  
Provide a standalone DEV sandbox rollout for the reusable Preset Manager Operation. The Tool demonstrates the complete user-facing new/resave/load/rename/remove dropdown pattern and can verify the workflow itself without depending on a parent Toolset.


**Operations used:**  
Uses `Codebase/Operations/Preset-Manager/Preset-Manager.ms` for all named-preset persistence. The Tool never reimplements section replacement, preset enumeration, existence checks, preset rename, or preset removal.


**Backend design:**  
`Preset-Manager-FN.ms` translates the sandbox's checkbox, amount, mode, and text values to/from the Operation's generic string key/value contract. It also owns `runSelfTest()`, which checks save, existence, list, load, overwrite/stale-key removal, Operation rename, Tool rename, invalid-name rejection, typed wrapper decoding, remove, and cleanup.


**UI design:**  
`Preset-Manager-UI.ms` provides the canonical tool title button, a neutral `<Preset>` dropdown, `RESAVE \\ REMOVE`, `NEW \\ RENAME`, sandbox value controls, `RUN SELF TEST`, and status text. LMB on `RESAVE \\ REMOVE` writes directly back to the selected preset; when the neutral item is selected it creates a new preset. RMB removes the selected preset after confirmation. LMB on `NEW \\ RENAME` always creates a new preset. RMB asks for a new name for the selected preset, starts with the current name, and refuses to overwrite another existing preset. Selecting a named preset asks before applying it. Dropdown refresh is guarded so programmatic selection changes never load a preset accidentally.


**Main entry behavior:**  
`Preset-Manager.ms` resolves and loads the shared Default UI helpers, the reusable Preset Manager Operation, the Tool backend, and the Tool frontend, then opens one managed standalone dialog. The Tool remains independent of any Toolset or manager.


**State / settings:**  
`Preset-Manager.ini` lives beside the owning main script. `MainUI` stores dialog geometry and the last sandbox control values. Named sandbox presets use their own `SandboxPreset|<name>` sections in the same INI. The native dialog title displays the highest loaded shared Preset Manager project version.


**Edge cases / constraints:**  
The sandbox UI is a reference/test Tool, not part of the Operation contract. Self-test data uses reserved test names and is removed before the test returns. The Tool frontend owns prompts and confirmations; the backend and Operation do not reference rollout controls or create dialogs.