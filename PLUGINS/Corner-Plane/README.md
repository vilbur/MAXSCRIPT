# Corner Plane v0.003

A scripted **Geometry** plugin that directly extends the native Autodesk 3ds Max `Plane` primitive through `extends:Plane`. It does **not** create a separate mesh or add modifiers.

## Install

Place `Corner-Plane.ms` in the 3ds Max startup scripts folder (for example via `getDir #startupScripts`), restart 3ds Max, then select **Create > Geometry > Vilbur > Corner Plane**. Alternatively, run `Corner-Plane.ms` once from the MAXScript Editor for the current session.

Create by clicking the desired pivot corner and dragging the rectangle to the opposing corner. Width, Length, segmentation, and mapping options are editable in the custom Modify panel. The signed drag direction is saved with each object, so changing dimensions grows away from the current pivot corner.

## Flip Pivot Horizontally

Select a Corner Plane, open **Modify > Corner Plane > Pivot**, and click **Flip Pivot Horizontal**.

- The pivot jumps from the current horizontal corner to the other horizontal corner.
- The Plane remains in the same world-space location; its width, length, segmentation, and mapping are unchanged.
- Clicking the button again flips the pivot back.
- Changing Width after flipping grows the plane away from the new pivot corner.
- For instanced nodes sharing one Corner Plane base object, the command updates the pivot on each dependent node so that all instances retain the same local growth direction.
- The signed growth direction is saved with the object. No additional per-object flip parameter is necessary.
- The command is available from MAXScript as `cp_test.baseObject.flipPivotHorizontally()` and returns a Boolean.
- This moves the actual node pivot; it does not mirror the plane, use a modifier, or change its geometry.

The plugin uses a fixed `classID` and `on attachedToNode`/parameter update handlers to maintain a node's `objectOffsetPos`. Standard native Plane geometry lives in the underlying delegate. No callback is installed and no XForm modifier is added.

## Quick creation

After loading the plugin:

```maxscript
cp_test = CornerPlane_CP corner_width:200 corner_length:120 pos:[0,0,0]
```

## Test

Run `Corner-Plane-Test.ms` after `Corner-Plane.ms` in an unsaved/test scene. It creates a named test object, checks local bounding extents, modifies dimensions, rotates it, flips its pivot both ways, and checks resize-from-flipped-pivot behavior. Each scene-changing stage is an undo step. The test fixture is intentionally left in the scene.

## Limitations / verification

- Autodesk documents `plugin geometry ... extends:Plane` and `node.objectOffsetPos` independently. This v0.003 implementation has **not yet been runtime-tested in 3ds Max**. In particular, node-offset behavior during interactive creation and load should be tested before production use.
- `replaceUI:true` hides the delegate's default UI in Modify, but Autodesk notes that native delegate controls may remain visible in Create. Editing the underlying delegate parameters directly (rather than the Corner Plane parameters) bypasses the corner-offset handlers. Use the custom Corner Plane rollout for Width and Length.
- Instanced objects share the plugin's width/length and direction, with offset synchronization propagated to all dependent nodes.
- Animating dimensions is disabled in this first version because node object offsets are not provided as an animatable delegated parameter.
- Native Plane `renderScale`, `density` and real-world mapping size are not exposed by the custom rollout in this first version. They remain properties of the delegate, if accessed through MAXScript.
