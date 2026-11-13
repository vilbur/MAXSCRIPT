# Registered Dialog Position Offset Fix — design and fork guide

**Status:** v0.04 working baseline, confirmed by the user on 2026-11-01.  
**Language:** MAXScript, intended for 3ds Max 2023 and 2026.  
**Scope:** Floating registered dialogs and ordinary unregistered dialogs; no dependency on `Dialog_v`.

## Goal

3ds Max changes the coordinates and window frame when a rollout is registered as a floating CUI toolbar. Saving a registered position and later passing those coordinates directly to `CreateDialog` can make the dialog move. Repeated native Register/Unregister operations can also accumulate movement and change the reported size.

The helper makes the correction reusable by other tools, stores position/size/state in an INI, and keeps the test UI independent of the backend.

## Files and ownership

| File | Contains | May be loaded by another tool? |
|---|---|---|
| `Registered-Dialog-Pre-Registration-Offset.ms` | Struct `RegisteredDialogPreRegistrationOffset_v`, global instance, CUI and INI methods | **Yes** |
| `Registered-Dialog-Pre-Registration-Offset-Test.ms` | Four-button rollout and three Listener regression tests | No — use only to test the helper |
| `AGENTS.md` | Guardrails for future modifications/forks | Reference document |

The test file loads the reusable helper with `fileIn` using its own directory. A production tool should load the helper directly and retain ownership of its rollout lifecycle.

## Hardcoded transition corrections

The values originate from the working older framework's `_fixDialogPosOnDocking()` method:

| Operation | Raw correction to `GetDialogPos` | Exact point of application |
|---|---|---|
| Register | `[6, -2]` | On the still-unregistered dialog, **before** `cui.RegisterDialogBar` |
| Unregister | `[-8, 0]` | On the now-unregistered dialog, **after** `cui.UnRegisterDialogBar` |

The measured **native CUI movement**, without these corrections, was `[6,29]` on registration and `[-4,-27]` on unregistration in the earlier 3ds Max 2026 experiment. Native movement is not itself a correction.

For an ordinary starting raw position `[220,180]`, the expected arithmetic is:

| Step | Position |
|---|---:|
| Unregistered start | `[220,180]` |
| Apply Register correction `[6,-2]` | `[226,178]` |
| Native register movement `[6,29]` | `[232,207]` |
| Native unregister movement `[-4,-27]` | `[228,180]` |
| Apply Unregister correction `[-8,0]` | `[220,180]` |

Thus the complete cycle returns the unregistered raw position to its starting value. Registered and unregistered raw positions do **not** need to be numerically equal at the intermediate step.

### Implementation sequence

```maxscript
-- REGISTER: the rollout is still unregistered here.
RegisteredDialogPreRegistrationOffset.fixDialogPosOnDocking tool_rollout #REGISTER
cui.RegisterDialogBar tool_rollout style:#(#cui_dock_vert, #cui_floatable, #cui_handles)
cui.FloatDialogBar tool_rollout

-- UNREGISTER: do this before calling SetDialogPos.
cui.UnRegisterDialogBar tool_rollout
RegisteredDialogPreRegistrationOffset.fixDialogPosOnDocking tool_rollout #UNREGISTER
```

The low-level example shows the required order; production code should usually call `registerDialog` / `unregisterDialog` instead of reproducing these steps.

## State and INI format

`captureGeometry rollout_ref` produces `#(raw_position, raw_size, state)`.

Each tool chooses its own INI section, allowing many independently named dialogs to share one file:

```ini
[MyTool]
PosX=220
PosY=180
Width=360
Height=236
SavedState=unregistered
```

`SavedState` is either `unregistered` or `registered_floating`. `saveGeometry` records the geometry before the caller destroys the window. `restoreGeometry` reads that state, applies registered-position preparation if needed, and compares actual versus saved raw position and size in the Listener.

The backend also caches the original unregistered size per rollout so repeated transitions do not keep the registered frame-size increase. If a registered restore reports a size mismatch, it retries with the previously measured `[16,39]` frame delta and logs the result. That size delta may depend on host UI behavior and should be checked when integrating a fork.

## Reusing the shared helper

Load the backend from a path supplied by your tool or its installer:

```maxscript
fileIn helper_path

-- After CreateDialog or when the user enables the toolbar:
RegisteredDialogPreRegistrationOffset.registerDialog my_rollout

-- When the user disables the toolbar:
RegisteredDialogPreRegistrationOffset.unregisterDialog my_rollout

-- Save BEFORE unregister/destroy:
RegisteredDialogPreRegistrationOffset.saveGeometry my_rollout ini_path "MyTool"

-- After recreating the rollout with CreateDialog:
if hasINISetting ini_path "MyTool" "SavedState" then
(
    RegisteredDialogPreRegistrationOffset.restoreGeometry my_rollout ini_path "MyTool"
)
```

`helper_path`, `ini_path`, and `my_rollout` are supplied by the hosting tool. Do not make the helper depend on the test file's directory or `rdpf_pre_test_rollout`. Use another section such as `"MaterialManager"` for a second dialog.

### Forking for a different tool

Two supported approaches:

1. **Shared integration (preferred):** Keep one authoritative backend in `Functions/UI` and `fileIn` it from the tool. No fork is needed when the corrections and CUI style remain identical.
2. **Independent fork:** Copy only the backend `.ms` into the new tool, rename `RegisteredDialogPreRegistrationOffset_v` and `RegisteredDialogPreRegistrationOffset` consistently, and configure that tool's source path, INI section, and CUI registration style. Keep the fork's tests separate. Do not change the shared stable implementation just to satisfy one tool's custom framing.

Avoid reloading a shared helper after a tool has already registered rollouts: a new struct instance resets the in-memory per-rollout size cache. Initialize shared helpers during tool startup and then reuse the instance.

## Regression tests and acceptance

Open `Registered-Dialog-Pre-Registration-Offset-Test.ms` in 3ds Max. The UI intentionally has only four buttons: REGISTER, UNREGISTER, SAVE, LOAD.

Run in the MAXScript Listener:

```maxscript
testPreRegistrationOffset()
testRegistrationTransitionNoDrift cycle_count:5
testPreRegistrationSaveLoad cycle_count:5
```

Run the save/load test in both supported floating states. Expected acceptance: each cycle reports `PASS`; the unregistered raw position and size return to their original values; saved geometry loads with zero residual; there is no accumulating displacement. Verify on each target Max version and display-scaling setup. The user's v0.04 success report validates the working baseline in their environment, not every monitor/DPI configuration.

## Current limitations

- `getDialogState` detects a docked registered bar, but docking-edge persistence is **not** implemented by this version. `registerDialog`, `unregisterDialog`, and INI state restoration are intended for unregistered and registered/floating rollouts.
- Changing titlebar style, CUI style, Windows scaling, or monitor arrangement can change physical window-frame offsets. Recalibrate before modifying the constants.
- The helper does not create or destroy production rollouts; the hosting tool owns those operations.
