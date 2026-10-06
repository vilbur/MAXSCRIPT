\# MaxScript UI Rules




Use these rules when creating or modifying MaxScript user interfaces.




\#\# General




\- Keep UI code valid for the supported 3ds Max versions.  
\- Use native MaxScript controls where they are sufficient.  
\- Use .NET controls only when native controls cannot provide the required appearance or behavior.  
\- Do not invent MaxScript or .NET methods, properties, events, or constructors.  
\- Preserve existing working UI behavior unless the task explicitly changes it.  
\- Keep UI code separate from processing logic when practical.  
\- Avoid unnecessary dependencies.




\#\# Mandatory minimum UI baseline — first version




These defaults are required from the **first runnable UI version** of every new MaxScript tool UI unless the project explicitly overrides them. They are not a final polish pass.




\- Before writing the first dialog/rollout code, read this file plus `UI/Default/README.md`, and start from the canonical `UI/Default/Default-UI-Template.ms` scaffold.  
\- Do not first create a stripped-down, unpersisted, or differently styled prototype with the intention of adding the shared UI defaults later.  
\- Every standalone tool dialog or owning rollout must use the canonical `.NET tool title button` from its first version. LMB on it performs the shared restart action.  
\- Every standalone tool dialog or owning rollout must use INI-backed UI state persistence from its first version. Persist relevant control values, selected modes/options, dialog position, and the supported dialog size state.  
\- Every standalone tool dialog or owning rollout must use a stable, version-independent dialog-owner key from its first version. Before creating the dialog, destroy any registered dialog for that same tool key, including dialogs created by older versioned script files.  
\- The dialog-owner key identifies the tool, not the build. Never include a file version, project version, or build number in that key.  
\- Use the canonical `IniSettings.ms`, `RolloutState.ms`, `DialogHost.ms`, `ScriptReload.ms`, and `ToolTitleButton.ms` helpers where their responsibility applies; do not duplicate those helper implementations inside each tool.  
\- Apply the shared 12 px sizing grid, standard 24 px control height, default 96 × 24 px button size, preferred widths, spacing, and resizing rules from the first UI version.  
\- Embedded child/subrollouts inside one owning dialog do not duplicate the `tool title button`; they inherit the owning UI shell and must still follow the shared sizing/state rules and persist their own relevant control state.  
\- A rollout that can run as an independent dialog receives the full baseline.  
\- Omitting any baseline default requires an explicit project/user requirement. Do not treat lack of a request as permission to omit it.




\#\# Naming and code style




\- Use \`camelCase\` for function names.  
\- Use \`snake\_case\` for variables.  
\- Put opening brackets on a new line.  
\- Use \`then\` for \`if\` expressions; do not use \`do\` for \`if\` expressions.  
\- Do not assign variables using names reserved or read-only in MaxScript.  
\- Add a short block comment before every function, with the description on the first line.  
\- Use explicit and descriptive control names.  
\- Avoid inline comments when a short one-line block comment is clearer.




\#\# Rollouts and dialogs




\- Before creating any standalone tool dialog or owning rollout, destroy all previously registered dialogs for the same stable tool key. This is mandatory, not conditional.  
\- Loading or restarting a newer version of a tool must close the still-open dialog from the older version before the new dialog is created. Only one owning dialog for a tool may remain open across versions.  
\- Use the shared `DialogHost.createManagedDialog` ownership/registry path for owning dialogs unless the project explicitly requires another host. Do not bypass it with a direct `createDialog` that leaves older registered versions alive.  
\- Keep the dialog-owner key stable across versions and unique to the tool. Never put the version number in the key.  
\- Remember dialog position when the tool is expected to be used repeatedly.  
\- Restore the saved position safely; fall back to a valid default if the stored position is invalid.  
\- Keep dialog dimensions usable at common Windows display scaling values.  
\- Prefer resizable layouts for tools containing lists, trees, logs, or other content that benefits from extra space.  
\- Do not allow resizing to make required controls inaccessible or overlap.  
\- Always include the current tool version number in the native dialog/tool title when that title is visible.  
\- Keep the displayed native title version synchronized with the actual running script version.  
\- The `tool title button` is exempt from the version-in-title rule: its label is always the tool/dialog name only.  
\- Every standalone tool dialog or owning rollout must use the canonical `tool title button` by default from its first UI version.  
\- LMB on the `tool title button` is the default restart action. Do not substitute a bottom `Restart` button unless the project explicitly requests a different UI pattern.  
\- Embedded child/subrollouts inside the same owning dialog do not duplicate the `tool title button`.  
\- Restart behavior must first search the current script's directory for a newer versioned file belonging to the same tool.  
\- If a newer matching versioned file exists, load the newest version.  
\- If no newer matching versioned file exists, reload the currently running script.  
\- Keep the restart/reload behavior generic and reusable; do not hard-code one project name, exact version, or absolute path.




## Dialog visibility and message processing




- A newly created dialog must become visible immediately; it must not wait for a viewport click or another unrelated UI event before painting.
- If the script continues doing work immediately after `createDialog`, call `windows.processPostedMessages()` once after dialog creation so 3ds Max can process the pending window paint/activation messages.
- Do not call `windows.processPostedMessages()` repeatedly without a reason. It processes the application message queue and can make UI actions/re-entrancy possible while the script is still running.
- Prefer returning control to 3ds Max after creating the dialog instead of starting a long blocking operation in the same call stack. Start long work from a button, timer, or another deliberate UI action when practical.
- During a genuinely long blocking operation where the dialog must remain responsive, process posted messages only at controlled intervals, not on every tiny inner-loop iteration.
- Test dialog creation from a cold/open state and verify that it paints and becomes usable without clicking the viewport.




Recommended immediate-paint pattern:




```maxscript
createDialog my_rollout
windows.processPostedMessages()
```




\#\# Rollout title crash safety




\- Treat rollout \`.title\` mutation during dialog lifecycle as a hard-crash hazard in 3ds Max, not as a normal recoverable MaxScript error.  
\- Do not assign to a rollout's \`.title\` from \`open\`, \`resized\`, \`moved\`, \`close\`, or other rollout/dialog lifecycle callbacks.  
\- Do not retitle an already opening or active rollout as part of normal version-display or initialization logic.  
\- Define the final rollout title directly in the rollout declaration and leave it unchanged while the dialog is opening or active.  
\- If the displayed title must include a dynamic version or other runtime-derived text, resolve that value before the rollout is defined, then build the rollout declaration/title from the already-resolved value.  
\- Do not move title initialization into a lifecycle callback as a workaround for load-order or versioning problems.  
\- A failure here may terminate 3ds Max without a MaxScript exception. When isolating a hard crash in UI lifecycle code, use logging markers immediately before and after suspicious statements; reaching the marker before a statement but not the marker after it is evidence that the statement may be crossing into a native crash path.




Safe pattern:




\`\`\`maxscript  
global my\_tool\_version \= "0.73"  
global my\_tool\_title \= "Tool Name " \+ my\_tool\_version




rollout myRollout my\_tool\_title  
(  
)  
\`\`\`




Unsafe pattern:




\`\`\`maxscript  
on myRollout open do  
(  
    myRollout.title \= "Tool Name " \+ my\_tool\_version  
)  
\`\`\`




\#\# Layout




\- Align related controls consistently.  
\- Use consistent margins, spacing, control heights, and label widths.  
\- Make subrollout slots fill the full usable width of their parent rollout.  
\- Make every subrollout slot approximately one closed-rollout header height taller than its content; use about \`24 px\` additional height.  
\- Group controls by task, not by implementation detail.  
\- Keep primary actions visually easy to find.  
\- Avoid overly wide dialogs when controls can be arranged vertically or in logical groups.  
\- Avoid dense layouts with controls touching each other.  
\- Keep text labels short and unambiguous.  
\- Use tooltips for behavior that is not obvious from the label.




\#\# Preferred UI sizing




\- Use a **12 px base grid** for dialog and control dimensions.  
\- Default button size: **96 × 24 px**.  
\- Standard control height: **24 px**.  
\- Preferred control widths: **72, 96, 144, 192, 288 px**.  
\- Preferred dialog widths: **336, 384, 480, 576 px**.  
\- Standard spacing: **12 px**.  
\- Use **6 px** only for compact half-grid spacing when 12 px is too large.  
\- Prefer widths, heights, margins, and spacing divisible by **12**.




\#\# Buttons and actions




\- Keep button captions action-oriented and concise.  
\- Use consistent button height within the same UI section.  
\- Use left-click for the primary action.  
\- Use right-click only for a clearly related secondary action.  
\- When a button supports both left-click and right-click actions, make that behavior discoverable with a tooltip or nearby UI hint.  
\- Do not add test or debug buttons to production UI unless explicitly requested.




\#\# Native controls




\- Prefer native rollout controls for standard spinners, checkboxes, radio buttons, dropdowns, list boxes, labels, and buttons when styling requirements permit.  
\- Use \`multiListBox\` when multiple items may be selected instead of creating many individual checkbuttons.  
\- Keep spinner ranges realistic and prevent invalid values where possible.  
\- Use checkbuttons only when their pressed/unpressed visual state meaningfully represents a persistent mode.




\#\# .NET controls




\- Use .NET controls when custom colors, fonts, drawing, richer events, or advanced widgets are needed.  
\- Keep .NET initialization isolated in functions where practical.  
\- Use valid .NET types available to 3ds Max's MaxScript/.NET bridge.  
\- Prefer canonical reusable UI templates for common styled controls when an appropriate shared template exists.  
\- Do not make general UI rules depend on one project-specific or tool-specific template filename or helper function.  
\- When changing a shared default appearance, update the appropriate canonical shared template instead of creating competing project-specific variants.  
\- Dispose or detach custom .NET resources when they are no longer needed if they can leak resources or retain callbacks.  
\- Avoid heavy custom painting unless native properties cannot achieve the required result.  
\- Keep custom drawing deterministic and lightweight.




\#\# Default .NET button style




\- Use this style as the default for all new WinForms `.NET` buttons unless a control explicitly requires a special semantic color.  
\- Control: `System.Windows.Forms.Button`.  
\- Set `UseVisualStyleBackColor = false`.  
\- Set `FlatStyle = Flat`.  
\- Background: RGB `68, 68, 68`.  
\- Text: RGB `190, 190, 190`.  
\- Border: RGB `120, 120, 120`.  
\- Border width: `1 px`.  
\- Hover background: RGB `78, 78, 78`.  
\- Pressed background: RGB `55, 55, 55`.  
\- Font: `Segoe UI`, size `9.0`, style `Bold`.  
\- Use these exact colors for the standard/default button appearance.  
\- Do not invent slightly different gray values for individual ordinary buttons.  
\- Special-purpose controls may override only the foreground/text color when their semantic color is intentionally defined. Keep the standard background, border, hover, pressed, and font styling unchanged.  
\- Keep the canonical shared default-button template synchronized with these values.




Equivalent MaxScript styling:




```maxscript
btn.UseVisualStyleBackColor = false
btn.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat

btn.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 68 68 68
btn.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 190 190 190

btn.FlatAppearance.BorderColor = (dotNetClass "System.Drawing.Color").FromArgb 120 120 120
btn.FlatAppearance.BorderSize = 1

btn.FlatAppearance.MouseOverBackColor = (dotNetClass "System.Drawing.Color").FromArgb 78 78 78
btn.FlatAppearance.MouseDownBackColor = (dotNetClass "System.Drawing.Color").FromArgb 55 55 55

btn.Font = dotNetObject \\
    "System.Drawing.Font" \\
    "Segoe UI" \\
    9.0 \\
    (dotNetClass "System.Drawing.FontStyle").Bold
```




\#\# Tool title button




\- This is the mandatory default title/restart control for every standalone tool dialog or owning rollout from the first runnable UI version unless explicitly overridden.  
\- Call this reusable UI pattern **`tool title button`** in comments, function names, and documentation.  
\- Use it at the top of a dialog or docked tool UI as an interactive replacement for a normal visible tool title.  
\- Control type: `.NET System.Windows.Forms.Button`.  
\- Treat the `tool title button` as a special-purpose control that intentionally overrides the ordinary default `.NET` button style.  
\- Button text must be the **tool/dialog name only**.  
\- Never append a file version, project version, build number, or other version text to the `tool title button` label.  
\- Set `UseVisualStyleBackColor = false`.  
\- Set `FlatStyle = Flat`.  
\- Background: RGB `45, 45, 48`, matching the current production host title button.  
\- Text: RGB `62, 158, 255`.  
\- Border width: `0 px`.  
\- Hover background: RGB `45, 45, 48`.  
\- Pressed background: RGB `45, 45, 48`.  
\- Do not allow the normal bright Windows hover or pressed highlight.  
\- Default height: **24 px**.  
\- Fill the available dialog width. With standard `12 px` side margins, use `dialog_width - 24 px`.  
\- Resize the `tool title button` horizontally whenever the owning dialog width changes.  
\- Use reusable function names containing `ToolTitleButton`, for example `setupToolTitleButton` and `resizeToolTitleButton`.  
\- Provide the reusable function `restartTool current_script file_prefix` for restarting the owning tool.  
\- **LMB on the `tool title button` must call `restartTool`.**  
\- `restartTool` must load the newest matching versioned script when one exists and otherwise reload the currently running script.  
\- Use the canonical shared `tool title button` helper/template when available instead of duplicating the styling and restart logic in each tool.




Equivalent MaxScript styling:




```maxscript
button_control.UseVisualStyleBackColor = false
button_control.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat

button_control.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 45 45 48
button_control.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 62 158 255

button_control.FlatAppearance.BorderSize = 0
button_control.FlatAppearance.MouseOverBackColor = button_control.BackColor
button_control.FlatAppearance.MouseDownBackColor = button_control.BackColor
```




\#\# Dark UI styling




\- Match the 3ds Max dark UI as closely as practical when creating custom .NET controls.  
\- Use dark backgrounds and restrained contrast.  
\- Use gray text by default unless another color communicates meaning.  
\- Use bold text only for emphasis, status, or primary controls.  
\- Avoid highly saturated colors unless they indicate a meaningful state.  
\- Keep hover, pressed, disabled, and focused states visually distinct.  
\- Do not sacrifice text readability for styling.




\#\# Fonts




\- Prefer fonts already available through Windows and 3ds Max.  
\- Keep font sizes close to native 3ds Max UI unless the task explicitly needs larger text.  
\- Use bold selectively.  
\- Do not distribute font files with tools.




\#\# Events




\- Keep event handlers short.  
\- Move non-trivial work into named functions instead of placing large blocks directly inside UI event handlers.  
\- Prevent recursive event loops when controls update each other.  
\- When selection changes update the UI, guard against invalid or deleted scene nodes.  
\- Avoid unnecessary polling when an event-driven update is available.




\#\# State and settings




\- Persist user-facing settings when repeated re-entry would be annoying.  
\- Use INI files or object user properties when appropriate to the scope of the setting.  
\- Store per-object values on the object when the value logically belongs to that object.  
\- Store global tool preferences in the tool configuration file.  
\- Validate loaded settings before assigning them to controls.  
\- Keep defaults usable even when no settings file exists.




\#\# Default dialog persistence




For every MaxScript dialog/rollout covered by the mandatory UI baseline, persist UI state in an INI file from the first runnable UI version unless the project explicitly requires another storage method.




Persist when relevant:




\- control values;  
\- selected modes and options;  
\- dialog position;  
\- dialog height;  
\- dialog width only when horizontal resizing is intentionally supported.




Validate restored values before applying them.




If the INI file or a stored value is missing or invalid, use safe defaults.




\#\# Default dialog resizing




For standard multi-rollout tools:




\- keep dialog width locked by default;  
\- allow vertical resizing by default;  
\- remember the last valid dialog position;  
\- remember the last valid dialog height;  
\- prevent vertical resizing from hiding required controls or producing invalid rollout sizes.




Allow horizontal resizing only when the UI specifically benefits from it, such as wide lists, trees, tables, or log views.




When a dialog contains multiple rollouts, resize the rollout/subrollout area rather than arbitrarily stretching fixed controls.




\#\# Progress and long operations




\- Show progress for operations that can take noticeable time.  
\- Keep progress messages concise and meaningful.  
\- Avoid excessive listener output during normal use.  
\- Support quiet mode when repetitive operations would otherwise produce too much output.  
\- Restore the UI to a usable state after errors or cancellation.




\#\# Error handling




\- Validate scene selection and required object types before running actions.  
\- Give useful error messages that state what is wrong and what the user needs to select or change.  
\- Do not silently swallow errors that leave the UI in an unknown state.  
\- Avoid modal message boxes for routine status information.  
\- Use modal dialogs only when the user must make a decision or acknowledge an important problem.




\#\# Editable Poly support




\- UI actions that operate on geometry must work with both \`Editable Poly\` and \`Edit Poly\` whenever the underlying operation is expected to support both.  
\- Do not implement geometry features only for \`Editable Mesh\` when the project standard requires Poly support.




\#\# Testing




\- Include test code for new UI components or behaviors.  
\- Test dialog creation more than once to catch duplicate rollout or callback problems.  
\- With an older version's dialog still open, load the next version and verify that the older dialog is destroyed automatically and exactly one dialog for that tool remains.  
\- Test common interaction states: default, hover, pressed, disabled, invalid selection, and dialog reopen.  
\- Test remembered settings and dialog position after reopening the tool.  
\- Test that the native dialog/tool title shows the actual running version number when it is visible.  
\- For a `tool title button`, verify that the label contains only the tool/dialog name and no version text.  
\- For a `tool title button`, verify RGB `45, 45, 48` for normal, hover, and pressed backgrounds; RGB `62, 158, 255` text; `0 px` border; and `24 px` height.  
\- Resize the dialog horizontally and verify that the `tool title button` continues to fill the usable width.  
\- Test `restartTool` behavior for both cases: a newer matching versioned script exists, and no newer version exists.  
\- Verify that LMB on the `tool title button` calls `restartTool`.  
\- Test both \`Editable Poly\` and \`Edit Poly\` when UI actions operate on geometry.  
\- Remove temporary test UI from production code unless explicitly requested.




\#\# Modification rules




\- When editing an existing UI file, read the current canonical file first.  
\- Change only what is necessary for the requested UI modification.  
\- Preserve unrelated controls, events, settings, and behavior.  
\- Update only files that were actually modified.  
\- Keep the canonical filename unchanged unless a rename is explicitly requested.
