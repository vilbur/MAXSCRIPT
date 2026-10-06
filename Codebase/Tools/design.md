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
