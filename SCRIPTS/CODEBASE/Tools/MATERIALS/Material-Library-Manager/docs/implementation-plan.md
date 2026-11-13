# First version implementation plan

Approved scope: design.md plus the subsequent conversation confirming root-level HTML and MAT output.

1. Verify Autodesk general MaterialX import signature from shipped plugin source; inspect canonical shared UI helpers. No shared library changes.
2. Write staged MAXScript tests for discovery, mixed categories, identity, independent material assignments on geometry instances, repeat import, library roundtrip, malformed input and managed-node scope. Runtime execution requires an available Max session.
3. Implement tool-specific backend coordination in Material-Library-Manager-FN.ms: scan, validated import, managed previews, category saving, portable HTML export. Use native .NET APIs directly where no canonical Function exists.
4. Adapt Default-UI-Template.ms into Material-Library-Manager-UI.ms using canonical shared helpers, persistent controls, root/output Browse, category filtering, selectable documents, preview management and status reporting.
5. Implement sibling-file loader and explicit shared UI dependency resolution. New code starts at file/project version 0.01; highest loaded project value wins.
6. Static review and separate reviewer pass; save canonical files directly to Drive and verify readback. Never claim unavailable runtime tests passed.

Decisions: Output defaults to chosen input root (latest user requirement). Placeholder is a renderable box, labeled as a proposed default, so every imported material can be assigned visibly. No approximate position matching. Save category only when all scanned documents in that category imported successfully. Overwrite disabled by default. Source files untouched.
