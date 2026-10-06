# Vertex Color Painter

Reusable MaxScript Operation for vertex-color painting on an Editable Poly base or on evaluated modifier-stack topology through `PaintLayerMod`.

## Location

`Codebase/Operations/Vertex-Color-Painter/`

## Main files

- `Vertex-Color-Painter.ms` — production Operation.
- `Vertex-Color-Painter-Test.ms` — executable regression test.
- `design.md` — behavior and integration contract.
- `AGENTS.md` — package-specific development rules.
- `changes.md` — implementation history.
- `_Versions/` — immutable version snapshots.

## Typical use

```maxscript
VertexColorPainter.setTarget source_node stack_index
VertexColorPainter.paintVertices vertex_ids (color 255 128 0)
VertexColorPainter.paintCorner vertex_id face_id (color 255 0 0)
```

When the session ends:

```maxscript
VertexColorPainter.clearPaint()
```

If external code changes topology while the painter remains bound:

```maxscript
VertexColorPainter.invalidate()
VertexColorPainter.refresh()
```

See `design.md` for topology-domain, ownership, cleanup, and integration rules.
