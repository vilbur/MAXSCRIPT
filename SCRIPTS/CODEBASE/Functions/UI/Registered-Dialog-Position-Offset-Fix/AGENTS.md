# Agent instructions — Registered Dialog Position Offset Fix

## Project and stable baseline

This folder contains a framework-independent MaxScript helper for preserving the position of floating registered dialogs when they are registered, unregistered, saved, and restored.

The user confirmed the **v0.04 implementation works perfectly on 2026-11-01**. Treat this as the working baseline. The exact Max version, DPI setting, and monitor configuration of that confirmation were not recorded; do not claim universal verification on both 3ds Max 2023 and 2026.

| File | Responsibility |
|---|---|
| `Registered-Dialog-Pre-Registration-Offset.ms` | Reusable struct, registration transitions, position corrections, and INI persistence |
| `Registered-Dialog-Pre-Registration-Offset-Test.ms` | Standalone test rollout with exactly four buttons and Listener regression functions |
| `design.md` | Design, API, coordinate calculations, and integration/fork guide |

The reusable struct is `RegisteredDialogPreRegistrationOffset_v`, and the global instance is `RegisteredDialogPreRegistrationOffset`. The backend must not depend on the test rollout, its controls, or its INI filename.

## Invariants — do not change without new measurements

The following corrections come directly from the older working `Dialog_v._fixDialogPosOnDocking()` implementation and were explicitly approved for this project:

| Transition | Correction | Timing |
|---|---|---|
| `#REGISTER` | `[6, -2]` | `SetDialogPos` **before** `cui.RegisterDialogBar` |
| `#UNREGISTER` | `[-8, 0]` | `SetDialogPos` **after** `cui.UnRegisterDialogBar` |

**Never call `SetDialogPos` while the dialog is registered.** Always preserve the two distinct call sites. Do not replace the corrections with the measured native CUI movement (`[6,29]` and `[-4,-27]`); those are different quantities.

Keep `on create do` last in a struct. Maintain camelCase function names, snake_case variables, full `function` declarations, multiline block comments, brackets on new lines, and `if ... then` (never `if ... do`). Use only documented MaxScript APIs.

## Safe reuse and forking

1. **Preferred reuse:** `fileIn` the backend `.ms` file once, then call its public methods using the tool's rollout reference. Never `fileIn` the `-Test.ms` file inside production tools.
2. **Independent dialogs:** Pass the actual rollout, an INI path, and a unique `section_name` to `saveGeometry` and `restoreGeometry`. The backend's remembered unregistered geometry is indexed by rollout reference.
3. **Lifecycle:** Save while the rollout still exists and before unregistering/destroying it. After `CreateDialog`, call `restoreGeometry` to restore its saved state.
4. **Fork when behavior must differ:** Copy the backend into that tool's own folder. Rename both the `_v` struct and its matching global instance to prevent two loaded forks from replacing each other's state. Record what changed and keep the original file unchanged.
5. **CUI style:** The backend defaults to `#(#cui_dock_vert, #cui_floatable, #cui_handles)`. If a fork changes the CUI style, Windows scaling, or window framing, measure the raw offsets again before editing constants.
6. **Scope:** The current save/restore contract supports **unregistered** and **registered/floating** states. Docked edge positions are managed by CUI; do not claim that docking-side restoration is implemented.

## Public methods to preserve

```maxscript
RegisteredDialogPreRegistrationOffset.registerDialog rollout_ref
RegisteredDialogPreRegistrationOffset.unregisterDialog rollout_ref
RegisteredDialogPreRegistrationOffset.saveGeometry rollout_ref ini_path section_name
RegisteredDialogPreRegistrationOffset.restoreGeometry rollout_ref ini_path section_name

-- Lower-level transition correction:
RegisteredDialogPreRegistrationOffset.fixDialogPosOnDocking rollout_ref #REGISTER
RegisteredDialogPreRegistrationOffset.fixDialogPosOnDocking rollout_ref #UNREGISTER
```

Do not call the low-level correction on its own while registered. Prefer the high-level registration methods, which call it in the correct order. `unregisterDialog` accepts `restore_unregistered_size:true` as an optional parameter.

## Required regression tests before changing code

The test rollout must continue to expose only **REGISTER, UNREGISTER, SAVE, LOAD**. Keep test functions callable from the MAXScript Listener, not as extra UI buttons.

```maxscript
testPreRegistrationOffset()
testRegistrationTransitionNoDrift cycle_count:5
testPreRegistrationSaveLoad cycle_count:5
```

Test the repeated save/load loop separately while unregistered and while registered/floating. Check Listener output for raw position, size, state, and residuals. Runtime tests must be executed in 3ds Max; structural checks alone are not proof that screen positioning is correct.

## Google Drive maintenance

Google Drive is the authoritative copy. Update the existing files **in place**, preserving IDs and names; do not create `(... 1)` duplicates, ZIP archives, or new versioned source filenames unless explicitly requested. Preserve unrelated UI behavior. After changes, verify Drive metadata and file content/size and report actual runtime test status honestly.
