\# Operations Design


Use this file as the source of truth for feature design at the Operations layer.


Record the intended behavior of reusable Operations here before or while implementing them. Operations compose Functions into complete logical procedures, so this file should describe workflow and result contracts rather than UI.


\#\# What belongs here


For each Operation feature, record:


\- purpose;  
\- required Function dependencies;  
\- input contract;  
\- execution order;  
\- validation and branching rules;  
\- output or result contract;  
\- failure behavior;  
\- important edge cases or constraints.


\#\# Feature design template


\#\#\# \<Operation feature name\>


\*\*Purpose:\*\*    
\<What complete logical procedure this Operation provides.\>


\*\*Inputs:\*\*    
\<Required parameters and accepted values.\>


\*\*Function dependencies:\*\*    
\<Functions called by this Operation.\>


\*\*Workflow:\*\*    
\<Required sequence, branching, and validation.\>


\*\*Output:\*\*    
\<Return value or result contract.\>


\*\*Failure behavior:\*\*    
\<How failures are detected and reported.\>


\*\*Edge cases / constraints:\*\*    
\<Important limits or unsupported cases.\>


\#\# Feature designs


Add approved Operation designs below this heading.


### Preset Manager


**Purpose:**  
Provide one reusable named-preset persistence workflow without owning any Tool semantics or UI. A caller supplies an INI path, a namespace prefix, a preset name, and opaque string key/value pairs.


**Inputs:**  
`ini_path` is the caller-owned INI file. `preset_name` is a non-empty user-facing name that cannot contain INI-section delimiters. `section_prefix` isolates one caller's preset namespace and defaults to `Preset`. Preset payloads are arrays of `#(key_string, value_string)` pairs.


**Function dependencies:**  
Uses native MAXScript `getINISetting`, `setINISetting`, `hasINISetting`, and `delIniSetting` only. The Operation does not depend on rollout controls, dialogs, Toolsets, or Tool-specific data structures.


**Workflow:**  
1. Normalize and validate the preset name, namespace, and payload entries.  
2. Store presets in sections named `<section_prefix>|<preset_name>` with one private format marker.  
3. Saving replaces the complete section so keys removed by the caller cannot survive as stale preset data.  
4. When replacing an existing preset, retain its previous entries and restore them if the replacement write fails.  
5. Loading returns only caller-owned entries and hides the internal format marker.  
6. Listing returns alphabetically sorted valid preset names in only the requested namespace.  
7. Renaming copies the exact preset payload to a new validated name, refuses an existing destination name, removes the old preset only after the new preset is valid, and rolls back the new preset if old-section removal fails.  
8. Removing deletes only the requested preset section and verifies that it no longer exists.


**Output:**  
Save, rename, existence, and remove operations return Boolean success/failure. Listing returns an Array of preset-name strings. Loading returns an Array of string key/value pairs for an existing preset and `undefined` when the named preset is invalid or absent. Empty presets are supported because the private format marker creates a valid section even when no caller entries exist.


**Failure behavior:**  
Invalid paths, names, namespaces, or payload shapes fail before changing stored data. Failed section writes return `false`; when an existing preset was being replaced, the Operation attempts to restore the previous section and reports a rollback failure to the Listener if restoration also fails. Rename never overwrites another preset; if the new section was created but removal of the old section fails, rename removes the temporary new section and returns failure.


**Edge cases / constraints:**  
Preset payloads are deliberately opaque strings. Typed decoding, application of loaded values, confirmations, dropdown synchronization, and other user interaction belong to the calling Tool. The reserved internal format key cannot be supplied as caller data.