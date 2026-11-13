# Modifier Set Stack — standalone first prototype

Project version **0.076**, initial independent file version **0.010**.

## Installation (3ds Max)

Keep these three files in the **same folder**:

- `Modifier-Set-Stack.ms` — entry script (run this file)
- `Modifier-Set-Stack-FN.ms` — persistent scene data and modifier operations
- `Modifier-Set-Stack-UI.ms` — remote interface

In 3ds Max, run `Scripting > Run Script > Modifier-Set-Stack.ms`.

## First test

1. Create one Box and add Volume Select, Material, and Push modifiers.
2. Select only the Box. The LIVE STACK lists actual `node.modifiers`, not TreeView sub-anim tracks such as Center/Gizmo.
3. Select one or several entries in LIVE STACK. With scope **Selected**, edit parameters in the Volume Select / Material / Push rollouts.
4. Enter a set name and click **+ Set**. Select LIVE STACK rows, then **Assign selected** to create memberships.
5. Choose a set and scope **Current Set** to edit all modifiers of one type in that set; scope **All of Type** edits that modifier type throughout the selected object's stack.
6. Use ON/OFF/Toggle to change modifier enabled states. Changes affect real modifiers and any instances of them.
7. Save and reload the scene. Set membership is stored in rootNode custom attributes; UI indexes/anim handles are recreated for each refresh.

To run the automatic smoke test, open `Tests/Modifier-Set-Stack-Test.ms` in the MAXScript editor and evaluate it. The test creates and deletes a temporary Box without resetting the scene, tests reference mapping and group membership, and writes Volume Select, Material and Push properties. **Save your current scene first.**

## Scope and limits of prototype

- One selected scene node at a time. Multi-object combined native Modify-panel stack not implemented.
- "Selected" refers to rows selected in the remote lists. **Use Active Native Modifier** imports the one native active modifier. Importing a native multi-modifier TreeView selection needs further runtime validation.
- Dynamic UI editors are implemented for Volume Select, MaterialModifier, and Push; other modifier types are listed and can be grouped/enabled but have no typed editor yet.
- Values are read without writing; differing values are reported as MIXED. Editing a control changes all targeted modifiers.
- Group flags are stored per scene-set; ON/OFF actions currently target only the chosen object's modifiers.
- Callback readiness is self-contained and based on #selectionSetChanged / #modPanelObjPostChange / modPanel.getCurrentObject(). The live list can refresh before Modify-panel readiness; delayed callback updates it afterward.
- The original Material ID Manager / `Modifier-Sets.ms` canonical production script is untouched.
- Static delimiter checks passed, but **runtime 3ds Max testing has not been performed** (live MCP session was unavailable).

## Symmetry — world-space mirror-plane alignment

Symmetry support was introduced at **project v0.086** (modified backend/UI/test files v0.020; unchanged entry file retains its own previous version). It is available in a dedicated **Symmetry** subrollout of Modifier Set Stack.

- **World X / Y / Z:** enter the desired absolute world position. All three coordinates are in the current scene units.
- **Read first plane:** reads the world-space Mirror origin of the first Symmetry target without changing the scene.
- **Align scope:** align only the Symmetry modifiers resolved by the existing Selected / Current Set / All of Type scope on the single selected object.
- **All selected objects:** align every Symmetry modifier on every selected object, regardless of set membership. It also works when multiple objects are selected, even though the general LIVE STACK editor still targets a single object.
- **postion preccision:** controls final position verification (1 mm, 0.1 mm, or 0.01 mm), default 0.01 mm; it never snaps or rounds the actual plane positions.

**Instance-safe approach:** changes only the per-node `getModContextTM` / `setModContextTM` translation of each Symmetry modifier context, preserving the Symmetry modifier reference, shared Mirror subanim, axis, rotation and scale. Because the same modifier may have different local contexts on different nodes, direct writes to `Symmetry.mirror.position` would not generally place the planes together in world space.

A batch is preflighted before editing. After alignment, every target is verified in world coordinates, including a second verification pass after all instance contexts have been written. A failure attempts to restore every original context and reports a diagnostic to the MAXScript Listener. The whole successful operation is grouped into one Undo step.

**Tests:** `Tests/Modifier-Set-Stack-Test.ms` includes a Symmetry test with a shared modifier across two differently transformed nodes, multiple modifiers on one node, an independent modifier, and invalid-target rejection. These tests still require actual execution in 3ds Max; only static validation has been performed here.
