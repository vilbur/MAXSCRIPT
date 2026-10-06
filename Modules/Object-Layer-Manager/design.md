# Object Layer Manager — Design

## Purpose

Object Layer Manager is a compact 3ds Max layer-management tool for architectural scenes. Its primary job is to expose the existing scene-layer hierarchy as a fast, dockable UI where the user can move the current selection into a layer, toggle layer visibility, temporarily isolate a layer, and choose which part of the hierarchy is displayed.

The current canonical implementation lives in `Object-Layer-Manager.ms`. Structural controls use native MAXScript controls, while the Default and generated layer action buttons use lightweight `System.Windows.Forms.Button` controls so their captions can use a larger font.

## Core UX

The tool window is intentionally narrow and hierarchy-focused.

- Fixed width: `256 px`.
- Vertical resizing is allowed; horizontal resizing is locked.
- The dialog may float or dock on the left/right side of 3ds Max.
- Top/bottom docking is not part of the design.
- The hierarchy subrollout consumes the remaining vertical height between the fixed header controls and the bottom `Restart` button.
- The window title is `Object-Layer-Manager | v<project version>`, matching the canonical script filename basename exactly.

The fixed controls at the top are, in order:

1. `Refresh Layers` and `New Layer` on one native `across:2` row with equal widths.
2. Full-width `Sync` button.
3. `Source` dropdown.
4. `Default` layer button.

The top action row uses native rollout `across:2` layout, so Refresh and New Layer remain two equal columns and are not manually overlaid during vertical resize. `Sync` occupies its own full-width row directly below them.

The main hierarchy `subRollout` fills the vertical space below those controls. A full-width `Restart` button stays fixed at the bottom of the 256 px dialog.

## New Layer

`New Layer` operates on the current scene selection. It collects all valid selected nodes, counts which scene layer each selected node currently belongs to, and treats the layer with the highest selected-node count as the current layer. If counts tie, the first tied layer encountered in selection order wins.

- **LMB:** create the new layer nested under that current layer.
- **RMB:** create the new layer next to that current layer by using the current layer's parent. If the current layer is top-level, the new layer is also top-level.

The name prompt is a native modal MAXScript dialog with a single-line `editText`, prefilled as `{Current-Layer}-NEW` using the user-facing current layer name for both LMB and RMB creation. The user may edit this before creation; Cancel/Escape aborts without scene changes. Empty names and existing layer names are rejected.

Creation is one undoable operation: create the new layer, apply the LMB nested parent or RMB sibling parent with `LayerProperties.setParent()` when a parent exists, and move all selected nodes into it. After a successful create, the Source list and visible hierarchy are refreshed without changing the current Source when it is still valid.

## Sync

`Sync` has explicit direction by mouse button so conflicting manager/scene states never need precedence guessing.

- **LMB — Manager → Scene:** for every currently displayed branch rollout, `rollout.open` is written to the matching scene layer's `layer.on` state. Open rollout = layer ON; rolled-up rollout = layer OFF. Leaf layers have no rollout state to push; their button actions already modify scene state directly.
- **RMB — Scene → Manager:** every scene branch layer copies `layer.on` into remembered manager rollout state, including branches outside the current Source view. Currently displayed branch rollouts are updated immediately through their `open` property, so later Source changes also inherit the synchronized scene state. The synchronized open/closed table survives Refresh and Restart.

After either direction, visible layer-button appearance is refreshed from scene state. Sync does not alter layer hierarchy, object membership, or the current Source. Manager → Scene is one undoable scene-state operation; Scene → Manager changes UI/persistence only.

## Source Layer Dropdown

The Source dropdown controls where the displayed hierarchy begins.

The first item is always blank. A blank source means: show the scene from the very top hierarchy level.

`Default` is never listed in the Source dropdown.

Named entries are ordered as follows:

1. Top-level parent layers that have children, alphabetically.
2. Every remaining non-Default layer, alphabetically.

Selecting a named source displays that layer as the visible root and recursively displays its descendants.

Selecting the blank source displays every non-Default top-level layer as a root.

Refreshing the layer list preserves the currently selected source when that layer still exists. If it no longer exists, the source falls back to the blank top-level entry.

## Default Layer

3ds Max native layer `0` is presented to the user as `Default`.

`Default` is intentionally outside the generated hierarchy. Its control is fixed above all dynamic rollouts, immediately below the Source dropdown.

The Default button uses the same layer actions as generated layer buttons.

## Hierarchy Rendering

The UI mirrors the real 3ds Max layer parent/child structure by using `LayerProperties.getParent()`, `getChild()`, and `getNumChildren()`.

### Branch layers

A layer that has one or more child layers is represented by its own rollout.

The rollout title is the layer display name. Inside that rollout, the first button represents the branch layer itself.

Child branch layers are recursively inserted into a nested `subRollout` belonging to their parent rollout.

### Leaf layers

A bottom-level layer with no children does **not** get its own rollout.

It is represented directly by a `.NET` layer-action button inside its parent rollout. This keeps the hierarchy compact and avoids unnecessary rollout headers at the bottom of the tree.

### Dynamic layout

Generated rollout widths become narrower with nesting depth, with minimum widths enforced so controls remain usable.

Rollout content height is calculated from:

- the branch layer's own button;
- one button row for each leaf child;
- nested rollout-header/content height for branch children.

The hierarchy is rebuilt when the source changes or the user presses `Refresh Layers`. Branch rollout open/closed state is remembered by native layer name and restored after rebuilds and script reloads.

## Layer Button Behavior

Every layer button uses the layer name as its caption. Layer action buttons keep the established row heights (`32 px` for Default and `30 px` for generated hierarchy buttons), request a `9 pt` Windows UI font, and use a borderless dark appearance. Visible/ON layers use the normal dark background with light text. A layer that is OFF (`layer.on == false`) or hidden (`layer.isHidden == true`) keeps the button clickable but uses a grayed background/text treatment. The last layer button whose **LMB** move completed successfully is shown with a bold 9 pt font independently of that gray state; all other visible layer buttons use the regular 9 pt font. The font and color styling are applied through guarded helpers so a Windows/.NET styling failure cannot abort dialog creation.

The interaction contract is consistent for Default, branch-layer buttons, and leaf-layer buttons:

- **LMB:** Move the current visible valid selection to that layer. After a successful move, that layer becomes the bold last-used button and the previous last-used button returns to regular weight.
- **RMB:** If the clicked layer is currently visible through its chain, hide only that clicked layer. If it is hidden or blocked by a hidden parent, show the clicked layer and only the required ancestors; sibling layer flags remain untouched.
- **SHIFT + RMB:** Temporarily isolate that layer.
- **CTRL + RMB:** Open the layer actions context menu with Add Selection, Show/Hide Layer (Parents on Show), and Temporary Isolate.

Tooltips must describe each callback on its own paragraph using the same LMB/RMB/SHIFT + RMB/CTRL + RMB terminology.

### Move selection

Only valid, visible selected nodes are moved. The operation is undoable.

The target layer must already exist. Missing/deleted layer references fail with a clear user-facing message rather than creating a replacement layer implicitly.

### Visibility toggle

RMB resolves only the clicked layer plus every real parent above it, stopping before the special `Default` / native `0` root. It never traverses children or siblings. When the complete clicked-layer path is visible, RMB hides **only the clicked layer**. When the clicked layer is hidden or blocked by a hidden parent, RMB clears `isHidden` only on the clicked layer and its required ancestor path so it can become visible. Sibling flags are preserved in both directions. Default itself still toggles only Default. Each visibility action is undoable.

### Temporary isolation

SHIFT + RMB captures the current hidden state of every scene layer, then hides all layers except the chosen target.

The next temporary-isolation action restores the captured visibility snapshot rather than creating another stacked isolation state.

Closing the tool also restores an active temporary isolation state.

## Persistence

Settings are stored in `Object-Layer-Manager.ini` beside `Object-Layer-Manager.ms`.

Settings are scene-specific. The INI section is based on the current scene filename, with a trailing numeric revision and its preceding `_`, `-`, or space removed when present.

Persisted state includes:

- selected source layer;
- floating dialog X/Y position;
- floating dialog height;
- branch rollout open/closed state, keyed by native layer name;
- last native layer successfully targeted by a layer-button LMB action, used to restore bold font emphasis after Refresh/Restart when that layer is visible.

Width is not persisted because the dialog is intentionally fixed at `256 px`.

Missing or invalid settings always fall back to safe defaults.

## Restart Behavior

The bottom `Restart` button reloads the canonical `Object-Layer-Manager.ms` from the current tool directory. Reload uses the same normal startup path as manually executing the script again, so the existing early dialog teardown runs before the new rollout definition is created.

Restart must not mutate the rollout title or bypass the crash-safe teardown order. If the canonical script file is missing, the tool reports the missing path instead of attempting a partial restart.

## Refresh Behavior

`Refresh Layers` performs two jobs:

1. Rebuild the Source dropdown from the current scene layers.
2. Rebuild the dynamic rollout hierarchy from the resolved source.
3. Reapply layer-button normal/gray appearance from current `layer.on` / `layer.isHidden` scene state.

The refresh must not modify scene topology or create/delete layers.

Dynamic layer-name references are rebuilt together with the rollout hierarchy so stale buttons cannot target an old layer index after refresh.

## Window Lifecycle and Crash Safety

The UI is designed to survive repeated execution/reload inside 3ds Max without leaving stale dialogs or generated rollouts behind.

Current crash-safety rules:

- The main rollout title is a **literal string in the rollout declaration**.
- Do not compute a dynamic title immediately before rollout definition; this pre-rollout title-resolution path has also been observed to hard-crash 3ds Max.
- `.title` is never assigned from `open`, `close`, `moved`, `resized`, or another dialog lifecycle callback.
- Lightweight `.NET` buttons are permitted for layer actions; the post-mortem established that the hard crash was caused by lifecycle-time rollout-title mutation, not by the buttons themselves.
- Do not share and manually dispose one global `System.Drawing.Font` across the layer buttons. 3ds Max produced `.NET runtime exception: Parameter is not valid` when assigning that shared font during rollout `open`. Each button now gets its own guarded font instance.
- Old dialog teardown happens before rollout/helper redefinition.
- Existing dynamic child rollouts are detached while their parent dialog is still alive.
- A registered CUI dialog bar is unregistered before the native dialog is destroyed.
- The rollout close handler does not recursively remove subrollouts during native window destruction.
- Dialog position/size is not queried from an already-closing native window.
- Generated rollout names use a monotonically increasing counter so repeated rebuilds/reloads do not reuse live rollout names.
- Temporary isolation is restored when the dialog closes.

These constraints take priority over visual customization. `.NET` UI additions beyond the existing lightweight layer buttons should still be introduced narrowly and regression-tested, but the existing button styling is part of the intended production design.

## Rollout Title Safety

A 3ds Max hard-crash was isolated to assigning `asc_main_rollout.title` from the rollout `open` handler during dialog creation. This can terminate 3ds Max without producing a MaxScript exception.

Therefore the title contract is strict:

- keep the displayed version synchronized by updating the literal rollout caption when the project version changes;
- declare the final `Object-Layer-Manager | v<project version>` caption as a literal string in the rollout declaration;
- do not compute the title in a pre-rollout runtime block;
- never assign `.title` from `open`, `close`, `moved`, `resized`, or similar lifecycle callbacks;
- do not retitle an already-active rollout as part of reload or initialization.

## Docking and Resize Rules

The floating dialog is created with a resizing frame using `lockWidth:true` and `lockHeight:false`.

CUI registration allows:

- left docking;
- right docking;
- floating;
- dock handles.

The registered size keeps width fixed at `256 px` with a minimum height of `240 px`; height may grow as needed.

On vertical resize, the `Restart` button follows the bottom edge and the hierarchy area expands/contracts between it and the fixed header controls. Width remains fixed at `256 px`. The resize callback changes only hierarchy height and Restart Y position; it does not recursively rewrite dynamic rollout/control widths.

## Internal Structure

The current tool is a single canonical MaxScript containing several responsibilities:

- scene/object preparation and selection helpers inherited from the original Arch Scene Cleaner codebase;
- layer lookup, sorting, display-name, move, visibility, isolation, and manager/scene synchronization helpers;
- source-layer and hierarchy helpers;
- dynamic rollout creation/install/remove logic;
- main Object Layer Manager rollout and dialog lifecycle.

For the layer UI itself, dependency direction is effectively:

`Main rollout -> hierarchy builder -> layer operations -> 3ds Max LayerManager`

Dynamic hierarchy state is represented as rollout-tree arrays containing the rollout definition, child rollout trees, and native layer name.

`asc_dynamic_layer_names` is the shared lookup table used by generated button handlers so layer names are stored as string values rather than injected into generated MaxScript source.

## Important Invariants

The following behavior should be preserved unless the design is intentionally changed:

- `New Layer` uses LMB for a nested child and RMB for a sibling next to the layer containing most selected objects; both pre-fill `{Current-Layer}-NEW`.
- `Default` stays outside the dynamic hierarchy.
- `Default` never appears in the Source dropdown.
- Blank Source means all top-level non-Default layers.
- Leaf layers are buttons, not rollouts.
- Branch layers are rollouts.
- Child branch layers are nested recursively under their real parent.
- Layer button caption equals the user-facing layer name.
- Exactly the visible layer button matching the last successful LMB target uses bold 9 pt text; other layer buttons remain regular 9 pt. Context-menu Add Selection does not change this LMB-only marker.
- LMB/RMB/SHIFT + RMB/CTRL + RMB behavior is identical across all layer buttons; normal RMB hides only the clicked layer when visible, and on show clears only the clicked layer plus required ancestors, never siblings or children.
- Branch rollout open/closed state is scene-specific and survives hierarchy rebuilds and script reloads. Sync RMB may intentionally replace that remembered manager state from `layer.on`.
- Sync LMB maps visible branch `rollout.open` state to `layer.on`; Sync RMB maps `layer.on` back to visible branch `rollout.open`.
- Layer buttons are grayed when their scene layer is OFF or hidden, without disabling mouse interaction.
- Dialog width remains fixed at `256 px`.
- Only left/right docking is supported.
- Main hierarchy slot fills all remaining vertical space above the bottom `Restart` button. Fixed widths are declared once and are not rewritten during resize events.
- `Restart` stays fixed to the dialog bottom and reloads the canonical script through the normal teardown/startup path.
- Default and generated layer-action buttons use `System.Windows.Forms.Button`; the 9 pt font plus borderless dark background/light-text styling are applied per control through guarded helpers with safe fallback.
- Main rollout title is literal in the rollout declaration; it is neither dynamically resolved before definition nor mutated afterward.
- Refresh/reload must not leave stale dynamic rollouts, CUI registration, or temporary isolation behind.

## Testing

`Object-Layer-Manager-Test.ms` is the project regression/smoke-test script.

Testing should concentrate on the failure-prone UI lifecycle and hierarchy behavior:

- safe initial dialog creation;
- New Layer majority-current-layer selection, LMB nested placement, RMB sibling placement, name prompt, and hierarchy refresh;
- source dropdown ordering and blank-source behavior;
- recursive branch nesting;
- leaf-button flattening;
- Default remaining outside the hierarchy;
- hierarchy refresh without stale rollout references, while preserving branch rollout open/closed state;
- last-used LMB layer-button font emphasis, including restoration after hierarchy rebuild;
- fixed 256 px width and vertical resize behavior;
- left/right CUI registration;
- RMB tree behavior using sibling layers, including hiding only the clicked layer and showing only the clicked layer plus required ancestors;
- Sync Manager → Scene and Scene → Manager mapping between `rollout.open` and `layer.on`;
- gray button feedback for OFF/hidden scene layers while preserving clickability;
- safe teardown/reload without a 3ds Max application crash.

Scene-changing test stages should remain undoable and leave the final scene available for visual inspection.

## Non-Goals

The current design does not attempt to:

- horizontally resize the UI;
- create a replacement layer when a referenced layer disappears;
- provide top or bottom docking;
- display Default inside the generated hierarchy;
- create rollout headers for leaf layers;
