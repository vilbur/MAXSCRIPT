# Material Library Manager — v0.01

Batch-import MaterialX folders through Autodesk's general MaterialX importer, create instanced preview geometry, save native MAT libraries by category, and generate a portable HTML catalog.

## Start

In 3ds Max 2026 use **Scripting > Run Script** and choose `Material-Library-Manager.ms`.
Keep the three production MS files together in this folder.

The tool uses the existing canonical `UI/Default` helpers: IniSettings.ms, RolloutState.ms, DialogHost.ms, ScriptReload.ms and ToolTitleButton.ms.
If they cannot be resolved from the normal codebase layout, the first launch asks for that shared folder and remembers it in `Material-Library-Manager.ini` beside the main script.
No shared helper is copied or changed.

Material import requires Autodesk's MaterialX plugin supplied with USD for 3ds Max. The verified general API is `MtlXIOUtil.importMtlx absolute_file_path`.
The tool does not substitute `MAXToAOps.ImportMaterials` for AMD/general MaterialX files.

## Workflow

1. **Browse** for the material library root. Output initially uses that same folder; a separate output Browse is available.
2. **Scan**, choose a category, then select documents. CTRL/SHIFT allow multiple selection; Select all selects the visible category.
3. Choose Sphere, Teapot, Knot, Custom or Placeholder. Pick an unmanaged scene geometry node for Custom. Placeholder currently means a renderable box, as a proposed first-version default.
4. Set primitive size, center-to-center spacing and columns. Size and spacing use scene units. Custom keeps the source geometry dimensions.
5. **Import selected** imports every returned material and assigns one managed preview per material. Failed documents remain marked FAILED and are logged with their source path.
6. **Save category libraries** writes only categories whose scanned documents are all successfully imported. Existing outputs are skipped unless **Overwrite outputs** is enabled.
7. **Export HTML catalog** writes all scanned documents, including materials without images. Catalog generation does not require importing or the MaterialX plugin.

Accepted layouts include MTLX at the selected root, `root/material/MTLX`, and `root/category/material/MTLX`. Deeper category ancestry is retained as a category path. No extra Materials input folder is required.

## Output

Output defaults directly to the selected material root:

- `Material-Library-Catalog.html` — dark, searchable catalog with collapsible category sections, local image previews and relative MTLX/image links.
- `<root-folder-name>.mat` — uncategorized/root materials.
- `Category--<category>.mat` — categorized materials. Nested category separators are URL-encoded in filenames to avoid ambiguous flattening.

Recognized images include exact document/material-basename PNG/JPG/JPEG/WEBP files, then filenames containing preview, thumbnail or render. Texture maps are not chosen merely because they are images.

Keep the HTML with the complete source material folder tree when copying to Android. Open it in a browser; no server or external JavaScript library is required. Android file providers can restrict access to sibling local images; opening from an extracted local folder is preferable. Actual Android-browser behavior is untested.

MAT files reference the original texture assets; they do not package them. Keep those assets accessible at their existing paths. Renderer compatibility depends on support for the imported Physical Material/OSL graph; visual equivalence is not guaranteed.

## Preview management

Select material documents to scope Select/Hide/Show/Replace/Remove. These commands only operate on nodes marked as owned by this tool and the selected root.
Arrange previews lays out all managed nodes for the current root.
Changing the Preview dropdown affects new imports; use Replace preview geometry to apply it to existing managed nodes.

Generated previews share geometry within the chosen template batch and keep separate material assignments. Custom geometry remains instanced from the picked source. Built-in templates are removed after cloning; editing a preview's shared object affects its geometry instances.
Reimport preserves existing preview nodes and transforms. It updates source/material identities and removes stale material identities only after importing the document successfully.
Each category is placed on an MLM layer. Replacement preserves that layer, transform, hidden state and material.
Reopening and Scan recover imported materials from complete managed document records in the scene. Failed or incomplete records are not eligible for library output.

Settings, paths and dialog geometry are persisted in the unversioned INI next to the entry script. Custom-node picking is intentionally session-only; pick again after restarting the tool. Title-button LMB reloads the tool using the shared restart helper. Native title shows the highest loaded project version.

## Tests and verification

Run `tests/Material-Library-Manager-Test.ms` in a disposable scene.
It creates filesystem fixtures under a unique Windows temporary directory and leaves its objects/results for inspection.
It exercises discovery, optional categories, same-named materials, geometry instances, independent assignments, repeated source identity, HTML links, MAT roundtrip, and managed removal scope.
When the real importer is available, it additionally exercises a two-material document, repeat import, scan recovery, incomplete-category blocking, invalid XML, and missing texture diagnostics.
Importer tests print SKIPPED when the dependency is absent.
Named undo stages leave unrelated objects and the custom source intact.

Delivery verification: focused static checks and separate source review completed. The connected 3ds Max session was unavailable, so the test script and UI were not executed or compiled in Max. This is a first implementation, not a runtime-validated stable release.

## Current limits

- Texture preflight checks filename inputs in the selected document, including fileprefix ancestry and `<UDIM>` tiles; it does not recursively validate filename inputs inside referenced external documents or custom search-path tokens. Autodesk's importer diagnostics still apply.
- Unsupported shader nodes can produce importer warnings; a nonempty result does not prove identical rendering. Direct surfacematerial counts are checked for obvious partial results.
- A document failing during scene assignment can leave partial preview changes for inspection/Undo. Its records are marked incomplete and cannot be exported as a complete category after Scan.
- Removing preview nodes does not remove original files or material-library outputs. Rescan after removing nodes changes recovered readiness; in-memory imported material records remain available until Scan/restart.
- Dialog position/docking uses the existing shared DialogHost implementation. Its registered-window offset is not calibrated by this tool; exact restoration across DPI/display setups requires runtime verification.
