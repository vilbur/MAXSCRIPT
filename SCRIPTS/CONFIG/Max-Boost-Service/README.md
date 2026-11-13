# Max Boost Service 0.01

Central service host for Autodesk 3ds Max 2023/2026.

## Included service
Selection → **Reinstance modifiers on object copy** (checkbox).

The original `instanceModifiersOnCopy.ms` was copied unchanged from the existing source repository.
The original clone-batching callback (`waitForNodesCloned.ms`) is copied as a namespaced
service module, retaining the 1000 ms batch timer and its `#postNodesCloned` event.
Its final dispatch calls the original `instanceModifiersOnCopy` function, not the old
`CALLBACKMANAGER.exe` dispatcher, so it can run independently of the old macroscript.

## Placement
Place `Max-Boost-Service/` next to the canonical `UI/Default/` folder, e.g.

`G:\AI\AGENTS\Maxscript\Max-Boost-Service\Max-Boost-Service.ms`

The shared UI files are loaded from `..\UI\Default` and are not duplicated here.

Run the main `.ms` file. Closing the UI leaves the callback running.
The setting is stored in `Max-Boost-Service.ini` beside the main script.
The default is OFF until enabled.

Run `Max-Boost-Service-Test.ms` in a disposable scene for an interactive copy test.
Do not simultaneously enable the legacy `modifiers_auto_instance` macroscript;
it would register a separate clone listener and prompt twice.

A machine-local 3ds Max startup loader is not installed in v0.01.
