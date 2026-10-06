# MaxScript Project Architecture

Use these rules for MaxScript projects that are larger than a single simple rollout.

The goal is to keep features isolated, make debugging local, and reduce the risk that work on one part of the tool breaks unrelated functionality.

## Core architecture

- Separate UI code from functional and geometry-processing code.
- UI files should create controls, handle events, display state, and call public functions from functional modules.
- Do not place substantial processing algorithms directly inside rollout event handlers.
- Keep responsibilities separated so that a change normally affects only a small number of files.

## Feature modules

Treat each substantial feature or procedure as an independent module.

A feature module should:

- perform one clearly defined responsibility;
- be as standalone as practical;
- avoid dependencies on unrelated rollouts or modules;
- expose a small and clear public interface;
- avoid project-wide global state unless the feature genuinely requires it;
- remain usable and testable without starting the entire application.

Prefer one folder per substantial feature module when the module contains multiple related files.

The module folder may contain:

- the functional MaxScript file;
- a small test UI;
- test data or test helpers that belong only to that feature.

Do not put project-wide logs inside module folders.

## Standalone baseline

Treat a working feature module as a reusable baseline.

Do not embed project-specific debugger frameworks, temporary diagnostics, orchestration code, or unrelated helpers into a stable standalone module.

When debugging support is needed, keep it outside the functional core whenever practical.

A module should remain understandable and usable without the full project around it.

## Test UI

For substantial standalone modules, prefer a small dedicated test rollout or test UI that can execute the module directly.

Use the test UI to:

- reproduce the feature quickly;
- run the module without the full application;
- inspect inputs and outputs;
- isolate failures from unrelated rollouts.

Keep the test UI small.

Do not turn the test UI into another application layer.

Do not require the production module to depend on the test UI.

## Rollout files

Keep each substantial rollout in its own file whenever practical.

A rollout file should primarily:

- define controls;
- connect UI events;
- read and display state;
- call public functions from feature modules.

Avoid duplicating feature logic across multiple rollouts.

If several rollouts use the same operation, move that operation into a shared functional module instead of copying it.

## Main and orchestration rollouts

A larger project may contain a main or orchestration rollout that combines multiple smaller rollouts or modules.

The orchestration layer may:

- create and arrange child rollouts;
- coordinate high-level workflow;
- route shared commands;
- synchronize state that genuinely belongs to multiple features.

Keep orchestration logic separate from low-level feature implementation.

Do not move feature-specific processing into the main rollout merely because the main rollout can access everything.

## Shared state and exceptions

Some components intentionally need shared state, including:

- global options;
- project-wide configuration;
- helper rollouts;
- debug rollouts;
- orchestration rollouts.

Treat these as explicit exceptions to normal module isolation.

Keep shared state in a clearly defined location and expose it through a small interface when practical.

Do not create new global dependencies when local module state is sufficient.

## Project logs

Use one `logs` folder in the project root for runtime log files.

Example:

```text
Project/
├─ logs/
├─ Feature-A/
├─ Feature-B/
├─ Main-UI.ms
└─ ...
```

Each module may write to its own log file inside the shared `logs` folder.

Prefer names that identify the source module clearly.

Logging must not make a functional module dependent on a debugger framework.

The module's core behavior must continue to work when logging is disabled or unavailable.

## File ownership

A file should have a clear responsibility.

Prefer:

- one UI file per substantial rollout;
- one functional module for one feature or closely related procedure set;
- dedicated shared modules only for genuinely shared behavior;
- separate test UI files for isolated module debugging.

Avoid large files that mix unrelated UI, geometry processing, configuration, logging, and orchestration.

## Change isolation

When modifying a project:

1. Identify the feature or rollout responsible for the requested behavior.
2. Read only the canonical files required for that feature.
3. Change the smallest practical file set.
4. Preserve public interfaces unless a change is required.
5. Test the feature in isolation when a standalone test UI exists.
6. Update only the modified canonical files on Google Drive.
7. Verify those updates succeeded.

Do not refactor unrelated modules while fixing one feature.

Do not rewrite stable modules merely to make their style more uniform.

## Dependency direction

Dependencies must point downward through the architecture. Higher layers may discover, load, configure, and call lower layers. Lower layers must not discover, load, or depend on higher layers.

```text
Toolset / Main / Orchestration
        |
        v
Tool / Feature UI
        |
        v
Operation / Feature Module
        |
        v
Function / Small Shared Utility
```

Reverse dependencies are not allowed.

- A Tool must not search parent folders for a Toolset, manager, orchestration file, or application entry point.
- A Tool must not `fileIn` or require a parent Toolset/manager to become usable.
- A Tool must not know the parent Toolset's filename, folder name, directory layout, globals, or implementation details.
- An Operation must not depend on a Tool or Toolset.
- A Function or shared utility must not depend on Operations, Tools, Toolsets, or rollout/UI state.
- Lower layers must remain runnable and testable without higher layers being present.

When a higher-level service or configuration is needed, inject it downward explicitly through parameters, callbacks, interfaces, or a genuinely shared lower-level service. Do not make the lower layer locate its parent by traversing directories.

Forbidden example:

```text
Tool -> walk parent directories -> find Manager.ms -> fileIn Manager.ms
```

Correct ownership:

```text
Manager / Toolset -> loads Tool
Tool -> uses only its downward dependencies
```

## Refactoring existing projects

When converting an existing larger script to this architecture:

- refactor incrementally;
- move one feature or rollout at a time;
- preserve existing behavior first;
- establish a stable module boundary before continuing;
- do not split code only for the sake of having more files;
- stop when further separation would add complexity without improving isolation.

The objective is safer maintenance, not maximum file count.
