# MaxScript DUMP DEV Logger

Use this rule for MaxScript DEV-mode debugging and diagnostic instrumentation.

`DUMP` means a simple development logger whose output is mirrored to both:

1. the 3ds Max Listener;
2. one repository-local dump file.

The Listener line and dump-file line must contain the same diagnostic data.

## DEV-only purpose

- DUMP is development/debug instrumentation, not production feature logic.
- DEV mode may add DUMP logging when it materially helps diagnose or verify behavior.
- AUDIT mode may inspect existing DUMP output, but remains read-only unless the user explicitly authorizes file changes.
- Do not make functional behavior depend on DUMP being enabled.
- Removing or disabling DUMP must not change the tool's actual behavior.

## Canonical implementation

Use the reusable implementation:

`Modules/DUMP/DUMP.ms`

It defines the reusable struct type:

```maxscript
DumpDevLoggerStruct
```

Create the DUMP instance inside the logical tool/project scope rather than as a cross-project global when practical:

```maxscript
local DUMP = DumpDevLoggerStruct()
```

## Dump-file location

The dump file must live inside the active project repository, normally under the project root `logs` folder.

Recommended naming:

```text
<project-root>\logs\<tool-name>-DUMP.txt
```

For a single-tool repository this is also acceptable:

```text
<project-root>\logs\DUMP.txt
```

The tool/project entry point must pass the dump path explicitly.

DUMP must not search parent directories, infer the project root by walking upward, or depend on a Toolset/manager to discover its path. This preserves downward dependency direction.

## Clear-on-run lifecycle

Each logical tool run/reload starts a fresh dump.

Call `DUMP.start dump_file_path` once during tool initialization:

```maxscript
local DUMP = DumpDevLoggerStruct()
local dump_file = pathConfig.appendPath project_root @"logs\MyTool-DUMP.txt"

DUMP.start dump_file
```

`start()` creates the log directory if needed and truncates the dump file to zero length before any new diagnostic output is written.

Do not clear the dump file inside normal `DUMP.log` calls.

Do not repeatedly call `start()` during one run unless intentionally beginning a completely new diagnostic session.

If a tool is reloaded, the new run calls `start()` again and replaces the previous run's dump with a clean file.

## Logging

Use:

```maxscript
DUMP.log "message"
DUMP.log some_value
DUMP.log some_array
```

`DUMP.log value` converts the supplied value to one line of text, prints that line to the Listener, and appends the same line to the configured dump file.

The canonical implementation opens, appends, and closes the dump file for each log call. This favors diagnostic reliability: recent lines remain on disk even if 3ds Max later crashes.

## Return contract

All canonical DUMP methods return booleans:

- `true` = requested logger operation completed;
- `false` = logger is disabled, not initialized, has an unusable path, or cannot open/create the dump file.

Do not return status strings such as `"ok"`, `"failed"`, or `"error"`.

## Error behavior

Do not use DUMP to hide exceptions or convert real runtime errors into harmless-looking log messages.

DUMP is diagnostic output only. Existing shared error-handling rules still apply.

If the dump file cannot be written, do not claim that logging succeeded.

## Minimal integration pattern

```maxscript
(
    fileIn dump_module_path

    local DUMP = DumpDevLoggerStruct()
    local dump_file = pathConfig.appendPath project_root @"logs\MyTool-DUMP.txt"

    if DUMP.start dump_file then
    (
        DUMP.log "tool run started"
    )

    -- Tool code follows.
)
```

The entry point owns `project_root` and the dump-file path. The DUMP module stays independent of parent Tools/Toolsets and repository layout.
