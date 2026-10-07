\\\# MaxScript Project Settings


\\\#\\\# Agent files


Keep AI-agent configuration and instruction files in Markdown (\\\`.md\\\`) format by default. Use another format only when the file must be machine-readable or executable.


\\\#\\\# Google Drive repository


Treat the designated Google Drive repository as the primary source of truth for all project files.


The current stable Google Drive repository state is the baseline for future development.


\\\#\\\#\\\# Before editing


1\\. Read only the latest repository copy of the exact file or files required for the task.    
2\\. Use the latest version of every relevant project file as the current codebase.    
3\\. Check relevant project chats or project files when needed to identify newer work, but do not replace a newer canonical repository copy with an older chat attachment.    
4\\. Preserve changes made from other project chats or workflows.    
5\\. Re-read the canonical repository file before writing when another workflow may have changed it during the task.    
6\\. Do not scan the entire repository unless the task actually requires it.    
7\\. Ignore unrelated README files, checksums, documentation, tests, manifests, and other repository files unless the task specifically involves them.


\\\#\\\#\\\# Updating files


1\\. Modify the existing canonical file.    
2\\. Replace the contents of the same Google Drive file using its existing file ID.    
3\\. Keep the canonical filename unchanged unless a rename is explicitly requested.    
4\\. Do not upload duplicate files.    
5\\. Do not create file or folder names with suffixes such as \\\`(1)\\\`, \\\`(2)\\\`, \\\`copy\\\`, or similar.    
6\\. Do not create ZIPs or downloadable copies when the canonical Google Drive file has been updated directly unless explicitly requested.    
7\\. Update only files that were modified by the requested task.


\\\#\\\#\\\# Duplicate suffix cleanup


\\- Treat automatic duplicate suffixes such as \\\`(1)\\\`, \\\`(2)\\\`, \\\`copy\\\`, or similar as accidental unless the project explicitly requires them.    
\\- Before creating a file or folder, check for the exact canonical name in the intended parent and reuse or update the canonical item when appropriate.    
\\- If a suffixed file or folder exists and the unsuffixed canonical name does not exist in the same parent, remove the accidental suffix by renaming that same item in place. Preserve its Drive ID, contents, and parent location.    
\\- If both the canonical unsuffixed item and a suffixed item exist, do not delete, merge, or overwrite either one until their purpose and contents have been checked.    
\\- Do not use duplicate suffixes to avoid a naming conflict that should instead be resolved by updating, moving, or explicitly renaming the canonical item.


\\\#\\\#\\\# Efficiency


1\\. Read only files relevant to the requested task.    
2\\. Read or update independent files in parallel when possible.    
3\\. Reuse resolved file and project-version information during the current task instead of checking Google Drive repeatedly.    
4\\. Avoid unnecessary download-and-reupload workflows when the existing Drive file can be replaced directly.


\\\#\\\#\\\# Minimal changes


For simple edits such as changing a string, label, tooltip text, color value, numeric constant, or other small literal:


1\\. Use the shortest safe path.    
2\\. Read only the exact canonical file or files that contain the value.    
3\\. Make only the requested replacement and required version updates.    
4\\. Do not perform architecture analysis, broad repository scans, unrelated tests, or extra refactoring unless the change requires them.    
5\\. If the same source is embedded in a bundled runtime file, update that required bundle copy and no unrelated files.    
6\\. Prefer direct in-place Google Drive updates over additional validation or copy workflows for trivial edits.


\\\#\\\#\\\# Local Google Drive paths


\\\`C:\\\\GoogleDrive\\\` is a link to \\\`G:\\\\GoogleDrive\\\`.


Treat both paths as referring to the same Google Drive content.


\\\#\\\# Tool folder and canonical entry filename


For every MaxScript tool stored in its own folder, the canonical main/entry script must have exactly the same base name as its parent folder.


Required pattern:


\\\`<Tool-Name>\\<Tool-Name>.ms\\\`


Rules:


\\- Treat the matching-name `.ms` file as the stable canonical launch/entry file for the tool.    
\\- Keep the parent-folder name and canonical entry-file name synchronized when a tool is created or renamed.    
\\- Versioned development or history copies may coexist when required by the project's versioning workflow, but they must not replace the canonical matching-name entry file.    
\\- The canonical entry file remains unversioned in its filename; its internal file/project version values continue to follow the project's versioning rules.    
\\- Do not use generic canonical entry filenames such as `main.ms`, `tool.ms`, `launcher.ms`, or a version-suffixed main filename unless the current project explicitly overrides this rule.


\\\#\\\# Versioning


\\\#\\\#\\\# Versioned script files


Every new code or script version must be saved as a new file with a version suffix.


\\- Never overwrite the previous versioned script file with the new version.    
\\- Keep the previous version available as its own file.    
\\- Increment the version in the filename using the project's existing versioning scheme.    
\\- This rule applies to versioned code/script releases. Stable shared instruction and configuration files such as \\\`AGENTS.md\\\` remain canonical files and are updated in place unless explicitly versioned.


Each code file has:


\\- Its own internal file version.    
\\- A shared project-version value.


On every code change:


1\\. Treat version values as ordered version identifiers.    
2\\. The increment step is determined by the current decimal precision: two decimal digits use \\`0.01\\`, three decimal digits use \\`0.001\\`, four decimal digits use \\`0.0001\\`, and so on.    
3\\. Examples: \\`1.01 \\+ 0.01 \\= 1.02\\`; \\`1.014 \\+ 0.001 \\= 1.015\\`; \\`1.0147 \\+ 0.0001 \\= 1.0148\\`.    
4\\. Increment the shared project version exactly once per change set using that step.    
5\\. Preserve the established decimal precision, including trailing zeroes where they are part of the version format.    
6\\. Carry normally across decimal boundaries while preserving that precision, for example \\`1.019 \\-\\> 1.020 \\-\\> 1.021\\`.    
7\\. A single three-decimal change set must never jump from \\`1.014\\` to \\`1.024\\`; the correct next version is \\`1.015\\`.    
8\\. Do not round, truncate, or reformat a version in a way that changes the intended increment sequence.    
9\\. Apply this rule to both modified file versions and the shared project version.    
10\\. Store the new shared project version in every modified code file.    
11\\. Do not change the internal version or stored project-version value in files whose code was not modified.    
12\\. When loading files, a file may update the global project version only when its stored project version is higher than the current global project version.    
13\\. The highest loaded project version always wins.    
14\\. The UI must display the global project version, never a hardcoded file version.


\\\#\\\# Editable Poly


For every Editable Poly used by the tool, always set \\\`.showCage \\= off\\\`.


\\\#\\\#\\\# Epoly shared references


When developing or debugging methods for \\\`Editable\\\_Poly\\\` or \\\`Edit\\\_Poly\\\`, first check the shared Epoly folder:


\\\`\\\\AI\\\\AGENTS\\\\Maxscript\\\\Epoly\\\\\\\`


The folder may contain working MaxScript snippets, reusable methods, selection routines, helper modules, and known-good examples for Epoly operations.


1\\. Read only the Epoly files or subfolders relevant to the current method.    
2\\. Prefer an existing verified working snippet or reusable method over reimplementing the same behavior from scratch.    
3\\. Treat shared Epoly code as reference/source material and adapt it only where the current project requires different behavior.    
4\\. Do not modify shared Epoly files unless the task explicitly requires changing the shared implementation.    
5\\. Keep the distinction between \\\`Editable\\\_Poly\\\` base-object APIs and \\\`Edit\\\_Poly\\\` modifier APIs. Do not assume a method or sub-object ID is interchangeable between them.


\\\#\\\# Select / delete controls


For controls where \\\`LMB\\\` selects geometry components and \\\`RMB\\\` removes or fixes those same components, use one consistent modifier workflow across the project.


1\\. \\\`LMB\\\` performs non-destructive detection.    
2\\. When the object has modifiers, test evaluated geometry with a snapshot before writing component selections.    
3\\. Store the selection in an Edit Poly modifier named \\\`SELECT \\\<FUNCTION\\\>\\\`.    
4\\. If that exact \\\`SELECT \\\<FUNCTION\\\>\\\` modifier already exists, reuse it. Do not delete it, rebuild it, or add a second copy.    
5\\. Keep \\\`showCage \\= off\\\` on every \\\`SELECT ...\\\` and \\\`DELETED ...\\\` modifier.    
6\\. \\\`RMB\\\` operates only on the components stored by the matching \\\`SELECT \\\<FUNCTION\\\>\\\` modifier, revalidating them against current evaluated geometry when needed.    
7\\. If \\\`RMB\\\` is used before \\\`LMB\\\`, run the same non-destructive detection first so the operation still uses the dedicated modifier path.    
8\\. After the \\\`RMB\\\` operation is committed, rename the working modifier to \\\`DELETED \\\<FUNCTION\\\>\\\`.    
9\\. Do not consume arbitrary component selections from unrelated Edit Poly modifiers or the Editable Poly base for these controls.    
10\\. Preserve unrelated user modifiers and modifier-stack order.


\\\#\\\# Tooltips


Keep tooltips concise and explain the control's action, result, or requirement.


Do not repeat information already clear from the control label.


Write one sentence per line whenever possible. Split longer text into short paragraphs separated by a blank line.


Keep event names uppercase, including \\\`LMB\\\`, \\\`RMB\\\`, \\\`MMB\\\`, \\\`CTRL+LMB\\\`, \\\`SHIFT+LMB\\\`, \\\`ALT+LMB\\\`, and similar combinations.


Describe each event in a separate paragraph with a blank line between events.


Disabled controls may display tooltips.


\\\#\\\# UI


Keep spinners reasonably wide.


If a spinner represents a unit value, append a visible units label next to it.


\\\#\\\# Change log


Maintain a \\\`changes.md\\\` file for each project. Record project changes there as they are made.


Keep entries concise and include the date plus the files or behavior changed.


Do not use \\\`changes.md\\\` as a version authority. Canonical project files remain authoritative for project versions.


\\\#\\\# TODO rules


Follow \\\`maxscript-todo-rules.md\\\` for TODO queue order and TODO mass-processing behavior.